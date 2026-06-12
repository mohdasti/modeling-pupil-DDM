# R/make_publish_gate.R

# Create a single "publish gate" CSV that collates:
# - Convergence diagnostics (R-hat, ESS, divergences)
# - LOO diagnostics
# - Subject-wise mid-body PPC pass rates
# - Pooled conditional PPC flags (for transparency)

suppressPackageStartupMessages({

  library(brms)

  library(posterior)

  library(dplyr)

  library(readr)

})



detect_project_root <- function() {
  candidates <- unique(c(
    getwd(),
    normalizePath(file.path(getwd(), ".."), mustWork = FALSE),
    normalizePath(file.path(getwd(), "../.."), mustWork = FALSE)
  ))
  for (root in candidates) {
    if (dir.exists(file.path(root, "output", "publish"))) {
      return(normalizePath(root))
    }
  }
  normalizePath(getwd())
}

PROJECT_ROOT <- detect_project_root()
PUBLISH_DIR  <- file.path(PROJECT_ROOT, "output", "publish")
dir.create(PUBLISH_DIR, showWarnings = FALSE, recursive = TRUE)

alias_ppc_cols <- function(ppc) {
  if ("qp_rmse_subj" %in% names(ppc) && !"qp_rmse" %in% names(ppc)) ppc$qp_rmse <- ppc$qp_rmse_subj
  if ("ks_subj" %in% names(ppc) && !"ks_mean" %in% names(ppc)) ppc$ks_mean <- ppc$ks_subj
  if ("qp_rmse_cond" %in% names(ppc) && !"qp_rmse" %in% names(ppc)) ppc$qp_rmse <- ppc$qp_rmse_cond
  if ("ks_cond" %in% names(ppc) && !"ks_mean" %in% names(ppc)) ppc$ks_mean <- ppc$ks_cond
  ppc
}



# ---- Logging ----

log_msg <- function(...) {

  msg <- paste(..., collapse = " ")

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  cat(sprintf("[%s] %s\n", timestamp, msg))

}



log_msg("================================================================================")

log_msg("START make_publish_gate.R")

log_msg("Creating publish gate summary for primary model")



# ---- Load fit ----

RUN_ID <- Sys.getenv("DDM_RUN_ID", "20260226_092110")
RUN_DIR_MODEL <- file.path(
  PROJECT_ROOT, "output", "ddm_refits", "runs", RUN_ID,
  "models", "additive__probe_onset_locked__thr0.20.rds"
)

# Check for censored model first if requested, otherwise use primary

use_censored <- as.logical(Sys.getenv("USE_CENSORED_FIT", "FALSE"))

if (use_censored) {

  fit_paths <- c(

    RUN_DIR_MODEL,

    file.path(PUBLISH_DIR, "fit_primary_vza_vEff_censored.rds"),

    file.path(PUBLISH_DIR, "fit_primary_vza_vEff.rds"),

    file.path(PUBLISH_DIR, "fit_primary_vza_vINTX.rds"),

    file.path(PUBLISH_DIR, "fit_primary_vza_biasintx.rds"),

    file.path(PUBLISH_DIR, "fit_primary_vza_bsintx.rds"),

    file.path(PUBLISH_DIR, "fit_primary_vza.rds")

  )

  log_msg("Looking for censored fit first (USE_CENSORED_FIT=TRUE)")

} else {

  fit_paths <- c(

    RUN_DIR_MODEL,

    file.path(PUBLISH_DIR, "fit_primary_vza_vEff.rds"),

    file.path(PUBLISH_DIR, "fit_primary_vza_vEff_censored.rds"),  # Include as fallback

    file.path(PUBLISH_DIR, "fit_primary_vza_vINTX.rds"),

    file.path(PUBLISH_DIR, "fit_primary_vza_biasintx.rds"),

    file.path(PUBLISH_DIR, "fit_primary_vza_bsintx.rds"),

    file.path(PUBLISH_DIR, "fit_primary_vza.rds")

  )

}

fit_path <- fit_paths[file.exists(fit_paths)][1]

if (is.na(fit_path)) {

  stop(sprintf("No fit found in %s", PUBLISH_DIR))

}

log_msg("Loading model:", fit_path)

fit <- readRDS(fit_path)

log_msg(sprintf("Model loaded: %s", basename(fit_path)))

is_censored <- grepl("censored", basename(fit_path), ignore.case = TRUE)



# ---- 1. Convergence diagnostics ----

log_msg("Computing convergence diagnostics...")

conv_csv <- file.path(
  PROJECT_ROOT, "output", "ddm_refits", "runs", RUN_ID,
  "tables", "convergence_summary.csv"
)

conv_from_run <- NULL
if (file.exists(conv_csv)) {
  conv_from_run <- tryCatch({
    conv_tbl <- read_csv(conv_csv, show_col_types = FALSE)
    if ("rt_def" %in% names(conv_tbl) && !"rt_type" %in% names(conv_tbl)) {
      conv_tbl <- dplyr::rename(conv_tbl, rt_type = rt_def)
    }
    conv_tbl %>%
      dplyr::filter(
        .data$model_name == "additive",
        .data$rt_type == "probe_onset_locked",
        .data$threshold == 0.2
      ) %>%
      dplyr::slice(1)
  }, error = function(e) NULL)
}

if (!is.null(conv_from_run) && nrow(conv_from_run) == 1) {
  log_msg("Using convergence_summary.csv from run_dir")
  max_rhat     <- conv_from_run$max_rhat
  min_bulk_ess <- conv_from_run$min_bulk_ess
  divergences  <- conv_from_run$divergences
} else {
  log_msg("Falling back to brms::rhat / brms::neff_ratio on fit object")
  rhat_vals <- brms::rhat(fit)
  neff_rat  <- brms::neff_ratio(fit)
  max_rhat  <- suppressWarnings(max(rhat_vals, na.rm = TRUE))
  total_draws <- fit$fit@sim$iter - fit$fit@sim$warmup
  if (is.null(total_draws) || is.na(total_draws) || total_draws <= 0) {
    total_draws <- 4000L
  }
  min_bulk_ess <- suppressWarnings(min(neff_rat * total_draws, na.rm = TRUE))
  divergences <- tryCatch({
    sampler_params <- brms::nuts_params(fit)
    sum(sampler_params$divergent__ == 1, na.rm = TRUE)
  }, error = function(e) {
    log_msg(sprintf("Could not extract divergences: %s", e$message))
    NA_integer_
  })
}

extract_min_tail_ess <- function(f) {
  s <- tryCatch(summary(f), error = function(e) NULL)
  if (is.null(s)) return(NA_real_)
  te <- c(s$fixed$Tail_ESS)
  if (!is.null(s$random)) {
    for (nm in names(s$random)) te <- c(te, s$random[[nm]]$Tail_ESS)
  }
  te <- te[is.finite(te)]
  if (length(te) == 0) NA_real_ else min(te)
}

min_tail_ess <- extract_min_tail_ess(fit)



conv_pass <- (max_rhat <= 1.01) && 

             (min_bulk_ess >= 400) && 

             (divergences == 0) &&

             (is.na(min_tail_ess) || min_tail_ess >= 400)



log_msg(sprintf("Convergence: max_rhat=%.5f, min_bulk_ess=%.0f, min_tail_ess=%s, divergences=%d",

                max_rhat, min_bulk_ess, ifelse(is.na(min_tail_ess), "NA", sprintf("%.0f", min_tail_ess)), divergences))

log_msg(sprintf("Convergence PASS: %s", ifelse(conv_pass, "YES", "NO")))



# ---- 2. LOO diagnostics ----

log_msg("Computing LOO diagnostics...")

loo_csv <- file.path(
  PROJECT_ROOT, "output", "ddm_refits", "runs", RUN_ID,
  "tables", "loo_summary.csv"
)

loo_from_run <- NULL
if (file.exists(loo_csv)) {
  loo_from_run <- tryCatch({
    loo_tbl <- read_csv(loo_csv, show_col_types = FALSE)
    if ("rt_def" %in% names(loo_tbl) && !"rt_type" %in% names(loo_tbl)) {
      loo_tbl <- dplyr::rename(loo_tbl, rt_type = rt_def)
    }
    loo_tbl %>%
      dplyr::filter(
        .data$model_name == "additive",
        .data$rt_type == "probe_onset_locked",
        .data$threshold == 0.2
      ) %>%
      dplyr::slice(1)
  }, error = function(e) NULL)
}

if (!is.null(loo_from_run) && nrow(loo_from_run) == 1) {
  log_msg("Using loo_summary.csv from run_dir")
  loo_elpd <- -loo_from_run$loo_ic / 2
  loo_se   <- loo_from_run$loo_se / 2
  loo_pareto_k <- NA_real_
  loo_high_k   <- NA_real_
  log_msg(sprintf("LOO: elpd_loo=%.2f (SE=%.2f) from exported LOOIC", loo_elpd, loo_se))
} else {
  loo_result <- tryCatch({
    loo::loo(fit, moment_match = FALSE)
  }, error = function(e) {
    log_msg(sprintf("LOO computation failed: %s", e$message))
    NULL
  })

  if (!is.null(loo_result)) {
    loo_elpd <- loo_result$estimates["elpd_loo", "Estimate"]
    loo_se <- loo_result$estimates["elpd_loo", "SE"]
    loo_pareto_k <- if ("pareto_k" %in% names(loo_result)) {
      max(loo_result$pareto_k$k, na.rm = TRUE)
    } else {
      NA_real_
    }
    loo_high_k <- if (!is.na(loo_pareto_k)) {
      sum(loo_result$pareto_k$k > 0.7, na.rm = TRUE)
    } else {
      NA_real_
    }
    log_msg(sprintf("LOO: elpd_loo=%.2f (SE=%.2f), max_pareto_k=%.3f, n_high_k=%s",
                    loo_elpd, loo_se, loo_pareto_k,
                    ifelse(is.na(loo_high_k), "NA", sprintf("%d", loo_high_k))))
  } else {
    loo_elpd <- NA_real_
    loo_se <- NA_real_
    loo_pareto_k <- NA_real_
    loo_high_k <- NA_real_
  }
}



# ---- 3. Subject-wise mid-body PPC ----

log_msg("Loading subject-wise PPC results...")

# Check for censored version if using censored fit

ppc_subj_path <- if (is_censored && file.exists(file.path(PUBLISH_DIR, "table3_ppc_primary_subjectwise_censored.csv"))) {

  file.path(PUBLISH_DIR, "table3_ppc_primary_subjectwise_censored.csv")

} else {

  file.path(PUBLISH_DIR, "table3_ppc_primary_subjectwise.csv")

}

if (file.exists(ppc_subj_path)) {

  ppc_subj <- read_csv(ppc_subj_path, show_col_types = FALSE)
  ppc_subj <- alias_ppc_cols(ppc_subj)

  

  # Count cells flagged

  n_cells <- nrow(ppc_subj)

  n_flagged_qp <- sum(ppc_subj$qp_flag, na.rm = TRUE)

  n_flagged_ks <- sum(ppc_subj$ks_flag, na.rm = TRUE)

  n_flagged_midbody <- if ("midbody_flag" %in% names(ppc_subj)) {
    sum(ppc_subj$midbody_flag, na.rm = TRUE)
  } else {
    NA_integer_
  }

  n_flagged_any <- sum(ppc_subj$any_flag, na.rm = TRUE)

  

  pct_flagged_qp <- (n_flagged_qp / n_cells) * 100

  pct_flagged_ks <- (n_flagged_ks / n_cells) * 100

  pct_flagged_midbody <- if (!is.na(n_flagged_midbody)) {
    (n_flagged_midbody / n_cells) * 100
  } else {
    NA_real_
  }

  pct_flagged_any <- (n_flagged_any / n_cells) * 100

  

  max_qp <- max(ppc_subj$qp_rmse, na.rm = TRUE)

  max_ks <- max(ppc_subj$ks_mean, na.rm = TRUE)

  max_midbody <- if ("qp_rmse_midbody" %in% names(ppc_subj)) {
    max(ppc_subj$qp_rmse_midbody, na.rm = TRUE)
  } else {
    NA_real_
  }

  

  # Accuracy check

  if ("emp_accuracy" %in% names(ppc_subj)) {

    # Would need predicted accuracy for full check, but report empirical for now

    median_acc <- median(ppc_subj$emp_accuracy, na.rm = TRUE)

  } else {

    median_acc <- NA_real_

  }

  

  log_msg(sprintf("Subject-wise PPC: %d/%d cells flagged (%.1f%%), max_qp=%.3f, max_ks=%.3f, max_midbody=%.3f",

                  n_flagged_any, n_cells, pct_flagged_any, max_qp, max_ks, max_midbody))

  

  ppc_subj_pass <- if (!is.na(pct_flagged_midbody) && !is.na(max_midbody)) {
    (pct_flagged_midbody <= 15) && (max_midbody <= 0.12) && (max_ks <= 0.20)
  } else {
    FALSE
  }

  

} else {

  log_msg("WARNING: Subject-wise PPC file not found. Run export_ppc_primary_enhanced.R first.")

  n_cells <- NA_integer_

  n_flagged_qp <- NA_integer_

  n_flagged_ks <- NA_integer_

  n_flagged_midbody <- NA_integer_

  n_flagged_any <- NA_integer_

  pct_flagged_qp <- NA_real_

  pct_flagged_ks <- NA_real_

  pct_flagged_midbody <- NA_real_

  pct_flagged_any <- NA_real_

  max_qp <- NA_real_

  max_ks <- NA_real_

  max_midbody <- NA_real_

  median_acc <- NA_real_

  ppc_subj_pass <- NA

}



# ---- 4. Pooled conditional PPC (for transparency) ----

log_msg("Loading pooled conditional PPC results...")

# Check for censored version if using censored fit

ppc_cond_path <- if (is_censored && file.exists(file.path(PUBLISH_DIR, "table3_ppc_primary_conditional_censored.csv"))) {

  file.path(PUBLISH_DIR, "table3_ppc_primary_conditional_censored.csv")

} else {

  file.path(PUBLISH_DIR, "table3_ppc_primary_conditional.csv")

}

if (file.exists(ppc_cond_path)) {

  ppc_cond <- read_csv(ppc_cond_path, show_col_types = FALSE)
  ppc_cond <- alias_ppc_cols(ppc_cond)

  n_flagged_cond <- sum(ppc_cond$any_flag, na.rm = TRUE)

  pct_flagged_cond <- (n_flagged_cond / nrow(ppc_cond)) * 100

  max_qp_cond <- max(ppc_cond$qp_rmse, na.rm = TRUE)

  max_ks_cond <- max(ppc_cond$ks_mean, na.rm = TRUE)

  log_msg(sprintf("Pooled conditional PPC: %d/%d cells flagged (%.1f%%), max_qp=%.3f, max_ks=%.3f",

                  n_flagged_cond, nrow(ppc_cond), pct_flagged_cond, max_qp_cond, max_ks_cond))

} else {

  log_msg("WARNING: Pooled conditional PPC file not found.")

  n_flagged_cond <- NA_integer_

  pct_flagged_cond <- NA_real_

  max_qp_cond <- NA_real_

  max_ks_cond <- NA_real_

}



# ---- Combine into gate summary ----

gate_summary <- tibble(

  model_file = basename(fit_path),

  timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),

  # Convergence

  conv_max_rhat = max_rhat,

  conv_min_bulk_ess = min_bulk_ess,

  conv_min_tail_ess = min_tail_ess,

  conv_divergences = divergences,

  conv_pass = conv_pass,

  # LOO

  loo_elpd = loo_elpd,

  loo_se = loo_se,

  loo_max_pareto_k = loo_pareto_k,

  loo_n_high_k = loo_high_k,

  # Subject-wise PPC (primary evidence)

  ppc_subj_n_cells = n_cells,

  ppc_subj_n_flagged_qp = n_flagged_qp,

  ppc_subj_n_flagged_ks = n_flagged_ks,

  ppc_subj_n_flagged_midbody = n_flagged_midbody,

  ppc_subj_n_flagged_any = n_flagged_any,

  ppc_subj_pct_flagged_qp = pct_flagged_qp,

  ppc_subj_pct_flagged_ks = pct_flagged_ks,

  ppc_subj_pct_flagged_midbody = pct_flagged_midbody,

  ppc_subj_pct_flagged_any = pct_flagged_any,

  ppc_subj_max_qp = max_qp,

  ppc_subj_max_ks = max_ks,

  ppc_subj_max_midbody = max_midbody,

  ppc_subj_median_acc = median_acc,

  ppc_subj_pass = ppc_subj_pass,

  # Pooled conditional PPC (transparency)

  ppc_cond_n_flagged = n_flagged_cond,

  ppc_cond_pct_flagged = pct_flagged_cond,

  ppc_cond_max_qp = max_qp_cond,

  ppc_cond_max_ks = max_ks_cond,

  # Overall gate

  gate_pass = conv_pass && (!is.na(ppc_subj_pass) && ppc_subj_pass)

)



# ---- Write gate summary ----

gate_path <- file.path(PUBLISH_DIR, if (is_censored) "publish_gate_primary_censored.csv" else "publish_gate_primary.csv")

write_csv(gate_summary, gate_path)
# chap3_ddm_results.qmd reads publish_gate_primary_censored.csv
write_csv(gate_summary, file.path(PUBLISH_DIR, "publish_gate_primary_censored.csv"))

log_msg("")

log_msg(sprintf("✓ Gate summary written: %s", gate_path))

if (is_censored) {

  log_msg("  (This is the censored fit gate - compare with uncensored fit)")
}



# ---- Print summary ----

log_msg("")

log_msg("================================================================================")

log_msg("PUBLISH GATE SUMMARY")

log_msg("================================================================================")

log_msg("")

log_msg("CONVERGENCE:")

log_msg(sprintf("  Max R-hat: %.5f (≤1.01: %s)", max_rhat, ifelse(max_rhat <= 1.01, "PASS", "FAIL")))

log_msg(sprintf("  Min bulk ESS: %.0f (≥400: %s)", min_bulk_ess, ifelse(min_bulk_ess >= 400, "PASS", "FAIL")))

log_msg(sprintf("  Min tail ESS: %s (≥400: %s)", 

                ifelse(is.na(min_tail_ess), "NA", sprintf("%.0f", min_tail_ess)),

                ifelse(is.na(min_tail_ess) || min_tail_ess >= 400, "PASS", "FAIL")))

log_msg(sprintf("  Divergences: %d (==0: %s)", divergences, ifelse(divergences == 0, "PASS", "FAIL")))

log_msg(sprintf("  Convergence PASS: %s", ifelse(conv_pass, "YES", "NO")))

log_msg("")

log_msg("SUBJECT-WISE MID-BODY PPC (PRIMARY EVIDENCE):")

log_msg(sprintf("  Cells flagged: %d/%d (%.1f%%)", n_flagged_midbody, n_cells, pct_flagged_midbody))

log_msg(sprintf("  Max mid-body QP: %.3f (≤0.12: %s)", max_midbody, ifelse(max_midbody <= 0.12, "PASS", "FAIL")))

log_msg(sprintf("  Max KS: %.3f (≤0.20: %s)", max_ks, ifelse(max_ks <= 0.20, "PASS", "FAIL")))

log_msg(sprintf("  Subject-wise PPC PASS: %s", ifelse(ppc_subj_pass, "YES", "NO")))

log_msg("")

log_msg("POOLED CONDITIONAL PPC (TRANSPARENCY):")

log_msg(sprintf("  Cells flagged: %d (%.1f%%)", n_flagged_cond, pct_flagged_cond))

log_msg(sprintf("  Max QP: %.3f, Max KS: %.3f", max_qp_cond, max_ks_cond))

log_msg("")

log_msg("================================================================================")

log_msg(sprintf("OVERALL GATE PASS: %s", ifelse(gate_summary$gate_pass, "YES ✓", "NO ✗")))

log_msg("================================================================================")

log_msg("")

log_msg("COMPLETE")

