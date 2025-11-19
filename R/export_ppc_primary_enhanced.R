# R/export_ppc_primary_enhanced.R

# Enhanced PPC with:
# 1. Pooled conditional (existing method)
# 2. Pooled unconditional (simulate choice+RT jointly)
# 3. Subject-wise conditional (per subject, then average)
# 4. Mid-body PPC (30/50/70 quantiles only)

suppressPackageStartupMessages({

  library(brms)

  library(dplyr)

  library(readr)

  library(tidyr)

  library(posterior)

})



# ---- Ensure RWiener is available for unconditional ----

if (!requireNamespace("RWiener", quietly = TRUE)) {

  stop("RWiener package required for unconditional PPC. Install with: install.packages('RWiener')")

}

library(RWiener)



PUBLISH_DIR <- "output/publish"

dir.create(PUBLISH_DIR, showWarnings = FALSE, recursive = TRUE)



# ---- Logging ----

log_msg <- function(...) {

  msg <- paste(..., collapse = " ")

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  cat(sprintf("[%s] %s\n", timestamp, msg))

}



log_msg("================================================================================")

log_msg("START export_ppc_primary_enhanced.R")

log_msg("Working directory:", getwd())

log_msg("Computing: (1) Pooled conditional, (2) Pooled unconditional, (3) Subject-wise, (4) Mid-body")



# ---- Load fit and data ----

# Check for censored model first if requested via environment variable, otherwise use primary

use_censored <- as.logical(Sys.getenv("USE_CENSORED_FIT", "FALSE"))

if (use_censored) {

  fit_paths <- c(

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

    file.path(PUBLISH_DIR, "fit_primary_vza_vEff.rds"),

    file.path(PUBLISH_DIR, "fit_primary_vza_vEff_censored.rds"),  # Include censored as fallback

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

log_msg(sprintf("Model loaded successfully: %s", basename(fit_path)))

# Determine if this is censored fit for output naming

is_censored <- grepl("censored", basename(fit_path), ignore.case = TRUE)

if (is_censored) {

  log_msg("NOTE: Using censored fit (top 2% RTs filtered) - this is a robustness check")
}



data_path <- "data/analysis_ready/bap_ddm_ready.csv"

log_msg("Loading data:", data_path)

dd <- readr::read_csv(data_path, show_col_types = FALSE)



# Derive decision column

if (!"decision" %in% names(dd)) {

  if ("iscorr" %in% names(dd)) {

    dd$decision <- as.integer(dd$iscorr)

  } else if ("correct" %in% names(dd)) {

    dd$decision <- as.integer(dd$correct)

  } else if ("is_correct" %in% names(dd)) {

    dd$decision <- as.integer(dd$is_correct)

  } else if ("accuracy" %in% names(dd) || "acc" %in% names(dd)) {

    col_name <- ifelse("accuracy" %in% names(dd), "accuracy", "acc")

    dd$decision <- as.integer(dd[[col_name]])

  } else {

    stop("Missing 'decision' (or equivalent).")

  }

}



dd <- dd %>%

  mutate(

    subject_id = factor(subject_id),

    task = factor(task),

    effort_condition = factor(effort_condition, levels = c("Low_5_MVC", "High_MVC")),

    difficulty_level = factor(difficulty_level, levels = c("Standard", "Hard", "Easy")),

    decision = as.integer(decision)

  )

log_msg(sprintf("Data loaded. N=%d", nrow(dd)))



# ---- Settings ----

set.seed(20251116)

NDRAWS <- 400

NDRAWS_UNCOND <- 100  # Fewer for unconditional (slower)

log_msg(sprintf("Using %d draws for conditional PPC", NDRAWS))

log_msg(sprintf("Using %d draws for unconditional PPC", NDRAWS_UNCOND))



# ---- Thresholds ----

thr_qp <- 0.09

thr_ks <- 0.15

thr_acc <- 0.05  # Accuracy difference threshold

log_msg(sprintf("PPC thresholds: QP=%.2f, KS=%.2f, Accuracy=%.2f", thr_qp, thr_ks, thr_acc))



# ---- Helper: compute metrics (full quantiles) ----

compute_metrics_full <- function(emp_rt, emp_cor, emp_err, pred_cor, pred_err) {

  qps <- c(.1, .3, .5, .7, .9)

  qp_rmse <- NA_real_

  ks_max <- NA_real_

  comp <- list()

  

  if (length(emp_cor) > 10 && length(pred_cor) > 10) {

    emp_qc <- quantile(emp_cor, probs = qps, na.rm = TRUE)

    prd_qc <- quantile(pred_cor, probs = qps, na.rm = TRUE)

    comp$rmse_c <- sqrt(mean((prd_qc - emp_qc)^2, na.rm = TRUE))

    comp$ks_c <- suppressWarnings(stats::ks.test(pred_cor, emp_cor)$statistic) |> as.numeric()

  }

  

  if (length(emp_err) > 10 && length(pred_err) > 10) {

    emp_qe <- quantile(emp_err, probs = qps, na.rm = TRUE)

    prd_qe <- quantile(pred_err, probs = qps, na.rm = TRUE)

    comp$rmse_e <- sqrt(mean((prd_qe - emp_qe)^2, na.rm = TRUE))

    comp$ks_e <- suppressWarnings(stats::ks.test(pred_err, emp_err)$statistic) |> as.numeric()

  }

  

  w_c <- length(emp_cor)

  w_e <- length(emp_err)

  

  if (!is.null(comp$rmse_c) && !is.null(comp$rmse_e)) {

    qp_rmse <- (w_c * comp$rmse_c + w_e * comp$rmse_e) / (w_c + w_e)

    ks_max  <- max(comp$ks_c, comp$ks_e, na.rm = TRUE)

  } else if (!is.null(comp$rmse_c)) {

    qp_rmse <- comp$rmse_c

    ks_max <- comp$ks_c

  } else if (!is.null(comp$rmse_e)) {

    qp_rmse <- comp$rmse_e

    ks_max <- comp$ks_e

  }

  

  tibble(qp_rmse = qp_rmse, ks_mean = ks_max)

}



# ---- Helper: compute mid-body metrics (30/50/70 only) ----

compute_metrics_midbody <- function(emp_rt, emp_cor, emp_err, pred_cor, pred_err) {

  qps_mid <- c(.3, .5, .7)  # Mid-body only

  qp_rmse <- NA_real_

  comp <- list()

  

  if (length(emp_cor) > 10 && length(pred_cor) > 10) {

    emp_qc <- quantile(emp_cor, probs = qps_mid, na.rm = TRUE)

    prd_qc <- quantile(pred_cor, probs = qps_mid, na.rm = TRUE)

    comp$rmse_c <- sqrt(mean((prd_qc - emp_qc)^2, na.rm = TRUE))

  }

  

  if (length(emp_err) > 10 && length(pred_err) > 10) {

    emp_qe <- quantile(emp_err, probs = qps_mid, na.rm = TRUE)

    prd_qe <- quantile(pred_err, probs = qps_mid, na.rm = TRUE)

    comp$rmse_e <- sqrt(mean((prd_qe - emp_qe)^2, na.rm = TRUE))

  }

  

  w_c <- length(emp_cor)

  w_e <- length(emp_err)

  

  if (!is.null(comp$rmse_c) && !is.null(comp$rmse_e)) {

    qp_rmse <- (w_c * comp$rmse_c + w_e * comp$rmse_e) / (w_c + w_e)

  } else if (!is.null(comp$rmse_c)) {

    qp_rmse <- comp$rmse_c

  } else if (!is.null(comp$rmse_e)) {

    qp_rmse <- comp$rmse_e

  }

  

  tibble(qp_rmse_midbody = qp_rmse)

}



# ---- 1. POOLED CONDITIONAL PPC ----

log_msg("================================================================================")

log_msg("1. POOLED CONDITIONAL PPC (RT conditional on observed decision)")



one_cell_conditional <- function(cell_df) {

  if (nrow(cell_df) == 0 || all(is.na(cell_df$rt)) || all(is.na(cell_df$decision))) {

    return(tibble(qp_rmse = NA_real_, ks_mean = NA_real_, qp_rmse_midbody = NA_real_))

  }

  

  pp <- tryCatch({

    posterior_predict(fit, newdata = cell_df, ndraws = NDRAWS, re_formula = NULL)

  }, error = function(e) {

    log_msg(sprintf("    Error in posterior_predict: %s", e$message))

    return(NULL)

  })

  

  if (is.null(pp) || ncol(pp) == 0) {

    return(tibble(qp_rmse = NA_real_, ks_mean = NA_real_, qp_rmse_midbody = NA_real_))

  }

  

  emp_rt <- cell_df$rt[!is.na(cell_df$rt) & !is.na(cell_df$decision)]

  emp_cor <- emp_rt[cell_df$decision[!is.na(cell_df$rt) & !is.na(cell_df$decision)] == 1]

  emp_err <- emp_rt[cell_df$decision[!is.na(cell_df$rt) & !is.na(cell_df$decision)] == 0]

  

  valid_idx <- !is.na(cell_df$rt) & !is.na(cell_df$decision)

  pred_cor <- as.numeric(pp[, cell_df$decision[valid_idx] == 1, drop = FALSE])

  pred_err <- as.numeric(pp[, cell_df$decision[valid_idx] == 0, drop = FALSE])

  pred_cor <- pred_cor[!is.na(pred_cor) & is.finite(pred_cor)]

  pred_err <- pred_err[!is.na(pred_err) & is.finite(pred_err)]

  

  metrics_full <- compute_metrics_full(emp_rt, emp_cor, emp_err, pred_cor, pred_err)

  metrics_mid <- compute_metrics_midbody(emp_rt, emp_cor, emp_err, pred_cor, pred_err)

  

  bind_cols(metrics_full, metrics_mid)

}



# ---- 2. POOLED UNCONDITIONAL PPC ----

log_msg("================================================================================")

log_msg("2. POOLED UNCONDITIONAL PPC (simulate choice+RT jointly)")



# Extract posterior parameter draws

log_msg("Extracting posterior parameter draws...")

post_draws <- as_draws_df(fit)

n_draws_actual <- min(nrow(post_draws), NDRAWS_UNCOND)

draw_idx <- sample(nrow(post_draws), n_draws_actual)

post_draws_sub <- post_draws[draw_idx, ]

log_msg(sprintf("Using %d posterior draws for unconditional simulation", n_draws_actual))



one_cell_unconditional <- function(cell_df) {

  if (nrow(cell_df) == 0 || all(is.na(cell_df$rt)) || all(is.na(cell_df$decision))) {

    return(tibble(qp_rmse = NA_real_, ks_mean = NA_real_, qp_rmse_midbody = NA_real_))

  }

  

  emp_rt <- cell_df$rt[!is.na(cell_df$rt) & !is.na(cell_df$decision)]

  emp_cor <- emp_rt[cell_df$decision[!is.na(cell_df$rt) & !is.na(cell_df$decision)] == 1]

  emp_err <- emp_rt[cell_df$decision[!is.na(cell_df$rt) & !is.na(cell_df$decision)] == 0]

  

  n_sim_per_draw <- min(max(100, ceiling(length(emp_rt) / n_draws_actual)), 500)

  

  tryCatch({

    sim_rts <- numeric()

    sim_decisions <- integer()

    

    for (d in seq_len(n_draws_actual)) {

      # Extract parameters (handle both naming conventions)

      bs_col <- if ("Intercept_bs" %in% names(post_draws_sub)) "Intercept_bs" else "b_bs_Intercept"

      ndt_col <- if ("Intercept_ndt" %in% names(post_draws_sub)) "Intercept_ndt" else "b_ndt_Intercept"

      bias_col <- if ("Intercept_bias" %in% names(post_draws_sub)) "Intercept_bias" else "b_bias_Intercept"

      v_col <- if ("Intercept" %in% names(post_draws_sub)) "Intercept" else "b_Intercept"

      

      bs_val <- exp(as.numeric(post_draws_sub[d, bs_col]))

      ndt_val <- exp(as.numeric(post_draws_sub[d, ndt_col]))

      bias_val <- plogis(as.numeric(post_draws_sub[d, bias_col]))

      v_val <- as.numeric(post_draws_sub[d, v_col])

      

      tryCatch({

        sim <- RWiener::rwiener(n = n_sim_per_draw, alpha = bs_val, tau = ndt_val, 

                                 beta = bias_val, delta = v_val)

        sim_rts <- c(sim_rts, sim$q)

        sim_decisions <- c(sim_decisions, as.integer(sim$resp == "upper"))

      }, error = function(e) {

        NULL

      })

    }

    

    if (length(sim_rts) == 0) {

      return(tibble(qp_rmse = NA_real_, ks_mean = NA_real_, qp_rmse_midbody = NA_real_))

    }

    

    pred_cor <- sim_rts[sim_decisions == 1 & !is.na(sim_rts) & is.finite(sim_rts)]

    pred_err <- sim_rts[sim_decisions == 0 & !is.na(sim_rts) & is.finite(sim_rts)]

    pred_cor <- pred_cor[!is.na(pred_cor) & is.finite(pred_cor)]

    pred_err <- pred_err[!is.na(pred_err) & is.finite(pred_err)]

    

    metrics_full <- compute_metrics_full(emp_rt, emp_cor, emp_err, pred_cor, pred_err)

    metrics_mid <- compute_metrics_midbody(emp_rt, emp_cor, emp_err, pred_cor, pred_err)

    

    bind_cols(metrics_full, metrics_mid)

  }, error = function(e) {

    log_msg(sprintf("    Error in unconditional PPC: %s", e$message))

    return(tibble(qp_rmse = NA_real_, ks_mean = NA_real_, qp_rmse_midbody = NA_real_))

  })

}



# ---- 3. SUBJECT-WISE CONDITIONAL PPC ----

log_msg("================================================================================")

log_msg("3. SUBJECT-WISE CONDITIONAL PPC (per subject, then average)")



one_cell_subjectwise <- function(cell_df) {

  if (nrow(cell_df) == 0) {

    return(tibble(qp_rmse = NA_real_, ks_mean = NA_real_, qp_rmse_midbody = NA_real_))

  }

  

  subjects <- unique(cell_df$subject_id)

  subj_metrics <- list()

  

  for (subj in subjects) {

    subj_df <- cell_df %>% filter(subject_id == subj)

    if (nrow(subj_df) < 5) next  # Skip subjects with too few trials

    

    metrics <- one_cell_conditional(subj_df)

    if (!is.na(metrics$qp_rmse)) {

      subj_metrics[[length(subj_metrics) + 1]] <- metrics

    }

  }

  

  if (length(subj_metrics) == 0) {

    return(tibble(qp_rmse = NA_real_, ks_mean = NA_real_, qp_rmse_midbody = NA_real_))

  }

  

  # Average across subjects

  subj_df <- bind_rows(subj_metrics)

  tibble(

    qp_rmse = mean(subj_df$qp_rmse, na.rm = TRUE),

    ks_mean = mean(subj_df$ks_mean, na.rm = TRUE),

    qp_rmse_midbody = mean(subj_df$qp_rmse_midbody, na.rm = TRUE)

  )

}



# ---- Cells to evaluate ----

cell_vars <- c("task", "effort_condition", "difficulty_level")

cells <- dd %>% 

  group_by(across(all_of(cell_vars))) %>% 

  summarise(n = n(), .groups = "drop")

log_msg(sprintf("Processing %d cells", nrow(cells)))



# ---- Compute all PPC types ----

log_msg("================================================================================")

log_msg("Computing PPC metrics per cell...")

ppc_start <- Sys.time()



res_conditional <- list()

res_unconditional <- list()

res_subjectwise <- list()



for (i in seq_len(nrow(cells))) {

  cell <- cells[i, ]

  cell_name <- paste(cell$task, cell$effort_condition, cell$difficulty_level, sep = ".")

  log_msg(sprintf("Processing cell %d/%d: %s (n=%d)", i, nrow(cells), cell_name, cell$n))

  

  cell_df <- dd %>%

    filter(task == cell$task,

           effort_condition == cell$effort_condition,

           difficulty_level == cell$difficulty_level)

  

  # Empirical accuracy

  emp_acc <- mean(cell_df$decision == 1, na.rm = TRUE)

  

  # Conditional

  log_msg("  Computing conditional PPC...")

  m_cond <- one_cell_conditional(cell_df)

  res_conditional[[i]] <- bind_cols(cell, m_cond, emp_accuracy = emp_acc)

  

  # Unconditional

  log_msg("  Computing unconditional PPC...")

  m_uncond <- tryCatch({

    one_cell_unconditional(cell_df)

  }, error = function(e) {

    log_msg(sprintf("    Skipping unconditional: %s", e$message))

    tibble(qp_rmse = NA_real_, ks_mean = NA_real_, qp_rmse_midbody = NA_real_)

  })

  res_unconditional[[i]] <- bind_cols(cell, m_uncond, emp_accuracy = emp_acc)

  

  # Subject-wise

  log_msg("  Computing subject-wise PPC...")

  m_subj <- one_cell_subjectwise(cell_df)

  res_subjectwise[[i]] <- bind_cols(cell, m_subj, emp_accuracy = emp_acc)

  

  log_msg(sprintf("  Conditional: qp=%.3f, ks=%.3f, midbody=%.3f", 

                  ifelse(is.na(m_cond$qp_rmse), NA, m_cond$qp_rmse),

                  ifelse(is.na(m_cond$ks_mean), NA, m_cond$ks_mean),

                  ifelse(is.na(m_cond$qp_rmse_midbody), NA, m_cond$qp_rmse_midbody)))

}



ppc_time <- as.numeric(difftime(Sys.time(), ppc_start, units = "secs"))

log_msg(sprintf("PPC computation completed in %.1f minutes", ppc_time / 60))



# ---- Combine and write ----

res_cond <- bind_rows(res_conditional) %>%

  mutate(

    qp_flag = ifelse(is.na(qp_rmse), FALSE, qp_rmse > thr_qp),

    ks_flag = ifelse(is.na(ks_mean), FALSE, ks_mean > thr_ks),

    midbody_flag = ifelse(is.na(qp_rmse_midbody), FALSE, qp_rmse_midbody > thr_qp),

    any_flag = qp_flag | ks_flag

  )



res_uncond <- bind_rows(res_unconditional) %>%

  mutate(

    qp_flag = ifelse(is.na(qp_rmse), FALSE, qp_rmse > thr_qp),

    ks_flag = ifelse(is.na(ks_mean), FALSE, ks_mean > thr_ks),

    midbody_flag = ifelse(is.na(qp_rmse_midbody), FALSE, qp_rmse_midbody > thr_qp),

    any_flag = qp_flag | ks_flag

  )



res_subj <- bind_rows(res_subjectwise) %>%

  mutate(

    qp_flag = ifelse(is.na(qp_rmse), FALSE, qp_rmse > thr_qp),

    ks_flag = ifelse(is.na(ks_mean), FALSE, ks_mean > thr_ks),

    midbody_flag = ifelse(is.na(qp_rmse_midbody), FALSE, qp_rmse_midbody > thr_qp),

    any_flag = qp_flag | ks_flag

  )



# Write outputs (add suffix if censored)

suffix <- if (is_censored) "_censored" else ""

readr::write_csv(res_cond, file.path(PUBLISH_DIR, paste0("table3_ppc_primary_conditional", suffix, ".csv")))

readr::write_csv(res_uncond, file.path(PUBLISH_DIR, paste0("table3_ppc_primary_unconditional", suffix, ".csv")))

readr::write_csv(res_subj, file.path(PUBLISH_DIR, paste0("table3_ppc_primary_subjectwise", suffix, ".csv")))

log_msg("✓ Results written to output/publish/")

if (is_censored) {

  log_msg("  (Files suffixed with '_censored' for comparison with uncensored fit)")
}



# ---- Summary ----

log_msg("================================================================================")

log_msg("PPC SUMMARY")

log_msg("")

log_msg("POOLED CONDITIONAL PPC:")

n_flagged_cond <- sum(res_cond$any_flag, na.rm = TRUE)

log_msg(sprintf("  Cells flagged: %d/%d (%.1f%%)", n_flagged_cond, nrow(res_cond), 

                (n_flagged_cond/nrow(res_cond))*100))

log_msg(sprintf("  Max KS: %.3f, Max QP: %.3f, Max Midbody: %.3f", 

                max(res_cond$ks_mean, na.rm = TRUE), max(res_cond$qp_rmse, na.rm = TRUE),

                max(res_cond$qp_rmse_midbody, na.rm = TRUE)))

log_msg("")

log_msg("POOLED UNCONDITIONAL PPC:")

n_flagged_uncond <- sum(res_uncond$any_flag, na.rm = TRUE)

log_msg(sprintf("  Cells flagged: %d/%d (%.1f%%)", n_flagged_uncond, nrow(res_uncond), 

                (n_flagged_uncond/nrow(res_uncond))*100))

log_msg(sprintf("  Max KS: %.3f, Max QP: %.3f, Max Midbody: %.3f", 

                max(res_uncond$ks_mean, na.rm = TRUE), max(res_uncond$qp_rmse, na.rm = TRUE),

                max(res_uncond$qp_rmse_midbody, na.rm = TRUE)))

log_msg("")

log_msg("SUBJECT-WISE CONDITIONAL PPC:")

n_flagged_subj <- sum(res_subj$any_flag, na.rm = TRUE)

log_msg(sprintf("  Cells flagged: %d/%d (%.1f%%)", n_flagged_subj, nrow(res_subj), 

                (n_flagged_subj/nrow(res_subj))*100))

log_msg(sprintf("  Max KS: %.3f, Max QP: %.3f, Max Midbody: %.3f", 

                max(res_subj$ks_mean, na.rm = TRUE), max(res_subj$qp_rmse, na.rm = TRUE),

                max(res_subj$qp_rmse_midbody, na.rm = TRUE)))

log_msg("")

log_msg("================================================================================")

log_msg("COMPLETE")

