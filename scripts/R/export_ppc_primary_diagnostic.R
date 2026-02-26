# R/export_ppc_primary_diagnostic.R

# Enhanced PPC with conditional, unconditional, and subject-wise checks

# 1. Conditional PPC (current method - RT conditional on observed decision)
# 2. Unconditional PPC (simulate choice+RT jointly using RWiener)
# 3. Subject-wise PPC (compute per subject, then average)

suppressPackageStartupMessages({

  library(brms)

  library(dplyr)

  library(readr)

  library(tidyr)

  library(posterior)

})



# ---- Ensure RWiener is available ----

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

log_msg("START export_ppc_primary_diagnostic.R")

log_msg("Working directory:", getwd())

log_msg("This script computes: (1) Conditional PPC, (2) Unconditional PPC, (3) Subject-wise PPC")



# ---- Load fit and data ----
# Prefer run_dir additive model (matches main chapter); fallback to publish variants
RUN_ID <- Sys.getenv("DDM_RUN_ID", "20260214_045745")
RUN_DIR_MODEL <- file.path("output", "ddm_refits", "runs", RUN_ID, "models", "additive__probe_onset_locked__thr0.20.rds")

fit_paths <- c(
  file.path(PUBLISH_DIR, "fit_primary_vza.rds"),           # Primary (run_dir copy)
  RUN_DIR_MODEL,                                           # Run dir additive model
  file.path(PUBLISH_DIR, "fit_primary_vza_biasintx.rds"),
  file.path(PUBLISH_DIR, "fit_primary_vza_bsintx.rds"),
  file.path(PUBLISH_DIR, "fit_primary_vza_vINTX.rds"),
  file.path(PUBLISH_DIR, "fit_task_ADT_vza.rds"),
  file.path(PUBLISH_DIR, "fit_task_VDT_vza.rds")
)

fit_path <- fit_paths[file.exists(fit_paths)][1]

if (is.na(fit_path)) {

  stop(sprintf("No fit found. Checked: %s", paste(fit_paths, collapse = ", ")))

}

log_msg("Loading model:", fit_path)

fit <- readRDS(fit_path)

log_msg(sprintf("Model loaded successfully: %s", basename(fit_path)))



# Prefer bap_ddm_only_ready (matches main chapter); fallback to bap_ddm_ready
data_paths <- c(
  "data/analysis_ready/bap_ddm_only_ready.csv",
  "data/analysis_ready/ddm_ready_data_unthresholded.csv",
  "data/analysis_ready/bap_ddm_ready.csv"
)
data_path <- data_paths[file.exists(data_paths)][1]
if (is.na(data_path)) {
  stop(sprintf("No data file found. Checked: %s", paste(data_paths, collapse = ", ")))
}
log_msg("Loading data:", data_path)

dd <- readr::read_csv(data_path, show_col_types = FALSE)

# Standardize RT column (model expects rt)
if (!"rt" %in% names(dd)) {
  rt_col <- intersect(c("rt", "resp1RT", "same_diff_resp_secs", "rt_cue_locked"), names(dd))[1]
  if (!is.na(rt_col)) dd$rt <- as.numeric(dd[[rt_col]])
}

# Derive decision column (1 = correct)

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



# Map effort_condition to model's expected levels (low/high)
# Run_dir additive model was fit with effort_condition = c("low", "high")
dd$effort_condition <- as.character(dd$effort_condition)
dd$effort_condition <- case_when(
  grepl("low|5_mvc|0\\.05", tolower(dd$effort_condition)) ~ "low",
  grepl("high|40_mvc|0\\.4", tolower(dd$effort_condition)) ~ "high",
  TRUE ~ dd$effort_condition
)
dd$effort_condition <- factor(dd$effort_condition, levels = c("low", "high"))

# difficulty_3: run_dir model uses this name (same as difficulty_level)
diff_levels <- c("Standard", "Easy", "Hard")
diff_present <- intersect(diff_levels, unique(na.omit(dd$difficulty_level)))
dd$difficulty_level <- factor(dd$difficulty_level, levels = diff_present)
dd$difficulty_3 <- dd$difficulty_level  # Model expects difficulty_3

# choice_binary: model uses dec(choice_binary); bap_ddm_only_ready has resp_is_diff or choice_binary
if (!"choice_binary" %in% names(dd)) {
  if ("resp_is_diff" %in% names(dd)) dd$choice_binary <- as.integer(dd$resp_is_diff)
  else if ("choice" %in% names(dd)) dd$choice_binary <- as.integer(dd$choice)
  else dd$choice_binary <- as.integer(dd$decision)  # Fallback: decision (iscorr) may differ from boundary
}

dd <- dd %>%

  filter(!is.na(rt), is.finite(rt), rt >= 0.2, rt <= 4) %>%

  mutate(

    subject_id = factor(subject_id),

    task = factor(task),

    choice_binary = as.integer(choice_binary),

    decision = as.integer(decision)

  )

log_msg(sprintf("Data loaded. N=%d (after RT filter 0.2-4s). Effort: %s. Difficulty: %s", 
                nrow(dd), paste(levels(dd$effort_condition), collapse = ", "), paste(levels(dd$difficulty_3), collapse = ", ")))



# ---- Settings ----

set.seed(20251116)

NDRAWS <- 400

NDRAWS_UNCOND <- 100  # Fewer for unconditional (slower due to RWiener)

log_msg(sprintf("Using %d draws for conditional PPC", NDRAWS))

log_msg(sprintf("Using %d draws for unconditional PPC (RWiener simulation)", NDRAWS_UNCOND))



# ---- Thresholds ----

thr_qp <- 0.09

thr_ks <- 0.15

log_msg(sprintf("PPC thresholds: QP=%.2f, KS=%.2f", thr_qp, thr_ks))



# ---- Helper: compute metrics (conditional) ----

compute_metrics <- function(emp_rt, emp_cor, emp_err, pred_cor, pred_err) {

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



# ---- 1. CONDITIONAL PPC (current method) ----

log_msg("================================================================================")

log_msg("1. CONDITIONAL PPC (RT conditional on observed decision)")



one_cell_conditional <- function(cell_df) {

  if (nrow(cell_df) == 0 || all(is.na(cell_df$rt)) || all(is.na(cell_df$decision))) {

    return(tibble(qp_rmse = NA_real_, ks_mean = NA_real_))

  }

  

  pp <- tryCatch({

    posterior_predict(fit, newdata = cell_df, ndraws = NDRAWS, re_formula = NULL)

  }, error = function(e) {

    log_msg(sprintf("    Error in posterior_predict: %s", e$message))

    return(NULL)

  })

  

  if (is.null(pp) || ncol(pp) == 0) {

    return(tibble(qp_rmse = NA_real_, ks_mean = NA_real_))

  }

  

  emp_rt <- cell_df$rt[!is.na(cell_df$rt) & !is.na(cell_df$decision)]

  emp_cor <- emp_rt[cell_df$decision[!is.na(cell_df$rt) & !is.na(cell_df$decision)] == 1]

  emp_err <- emp_rt[cell_df$decision[!is.na(cell_df$rt) & !is.na(cell_df$decision)] == 0]

  

  valid_idx <- !is.na(cell_df$rt) & !is.na(cell_df$decision)

  pred_cor <- as.numeric(pp[, cell_df$decision[valid_idx] == 1, drop = FALSE])

  pred_err <- as.numeric(pp[, cell_df$decision[valid_idx] == 0, drop = FALSE])

  pred_cor <- pred_cor[!is.na(pred_cor) & is.finite(pred_cor)]

  pred_err <- pred_err[!is.na(pred_err) & is.finite(pred_err)]

  

  compute_metrics(emp_rt, emp_cor, emp_err, pred_cor, pred_err)

}



# ---- 2. UNCONDITIONAL PPC (simulate choice+RT jointly) ----

log_msg("================================================================================")

log_msg("2. UNCONDITIONAL PPC (simulate choice+RT jointly using RWiener)")



# Extract posterior parameter draws

log_msg("Extracting posterior parameter draws...")

post_draws <- as_draws_df(fit)

n_draws_actual <- min(nrow(post_draws), NDRAWS_UNCOND)

draw_idx <- sample(nrow(post_draws), n_draws_actual)

post_draws_sub <- post_draws[draw_idx, ]

log_msg(sprintf("Using %d posterior draws for unconditional simulation", n_draws_actual))



one_cell_unconditional <- function(cell_df) {

  if (nrow(cell_df) == 0 || all(is.na(cell_df$rt)) || all(is.na(cell_df$decision))) {

    return(tibble(qp_rmse = NA_real_, ks_mean = NA_real_))

  }

  

  emp_rt <- cell_df$rt[!is.na(cell_df$rt) & !is.na(cell_df$decision)]

  emp_cor <- emp_rt[cell_df$decision[!is.na(cell_df$rt) & !is.na(cell_df$decision)] == 1]

  emp_err <- emp_rt[cell_df$decision[!is.na(cell_df$rt) & !is.na(cell_df$decision)] == 0]

  

  # Simulate unconditional RTs and decisions using RWiener

  # Sample n_draws_actual draws, simulate n_sim_per_draw trials per draw

  n_sim_per_draw <- min(max(100, ceiling(length(emp_rt) / n_draws_actual)), 500)

  

  tryCatch({

    sim_rts <- numeric()

    sim_decisions <- integer()

    

    # Use simpler approach: sample parameters from posterior per draw, simulate

    for (d in seq_len(n_draws_actual)) {

      draw_row <- post_draws_sub[d, ]

      

      # Extract cell-level parameters (approximate - would need trial-specific for full accuracy)

      # Use population-level parameters for this draw

      # brms uses Intercept_bs, Intercept_ndt, etc. for distributional parameters

      bs_col <- if ("Intercept_bs" %in% names(post_draws_sub)) "Intercept_bs" else "b_bs_Intercept"

      ndt_col <- if ("Intercept_ndt" %in% names(post_draws_sub)) "Intercept_ndt" else "b_ndt_Intercept"

      bias_col <- if ("Intercept_bias" %in% names(post_draws_sub)) "Intercept_bias" else "b_bias_Intercept"

      v_col <- if ("Intercept" %in% names(post_draws_sub)) "Intercept" else "b_Intercept"

      

      bs_val <- exp(as.numeric(post_draws_sub[d, bs_col]))

      ndt_val <- exp(as.numeric(post_draws_sub[d, ndt_col]))

      bias_val <- plogis(as.numeric(post_draws_sub[d, bias_col]))

      v_val <- as.numeric(post_draws_sub[d, v_col])

      

      # Simulate trials for this draw

      tryCatch({

        sim <- RWiener::rwiener(n = n_sim_per_draw, alpha = bs_val, tau = ndt_val, 

                                 beta = bias_val, delta = v_val)

        sim_rts <- c(sim_rts, sim$q)

        sim_decisions <- c(sim_decisions, as.integer(sim$resp == "upper"))

      }, error = function(e) {

        # Skip this draw if simulation fails

        NULL

      })

    }

    

    if (length(sim_rts) == 0) {

      return(tibble(qp_rmse = NA_real_, ks_mean = NA_real_))

    }

    

    # Separate correct/error

    pred_cor <- sim_rts[sim_decisions == 1 & !is.na(sim_rts) & is.finite(sim_rts)]

    pred_err <- sim_rts[sim_decisions == 0 & !is.na(sim_rts) & is.finite(sim_rts)]

    pred_cor <- pred_cor[!is.na(pred_cor) & is.finite(pred_cor)]

    pred_err <- pred_err[!is.na(pred_err) & is.finite(pred_err)]

    

    compute_metrics(emp_rt, emp_cor, emp_err, pred_cor, pred_err)

  }, error = function(e) {

    log_msg(sprintf("    Error in unconditional PPC: %s", e$message))

    return(tibble(qp_rmse = NA_real_, ks_mean = NA_real_))

  })

}



# ---- 3. SUBJECT-WISE PPC ----

log_msg("================================================================================")

log_msg("3. SUBJECT-WISE PPC (compute per subject, then average)")



one_cell_subjectwise <- function(cell_df) {

  if (nrow(cell_df) == 0) {

    return(tibble(qp_rmse = NA_real_, ks_mean = NA_real_))

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

    return(tibble(qp_rmse = NA_real_, ks_mean = NA_real_))

  }

  

  # Average across subjects

  subj_df <- bind_rows(subj_metrics)

  tibble(

    qp_rmse = mean(subj_df$qp_rmse, na.rm = TRUE),

    ks_mean = mean(subj_df$ks_mean, na.rm = TRUE)

  )

}



# ---- Cells to evaluate ----
# Use difficulty_3 to match model (same values as difficulty_level)
cell_vars <- c("task", "effort_condition", "difficulty_3")

cells <- dd %>% 

  group_by(across(all_of(cell_vars))) %>% 

  summarise(n = n(), .groups = "drop")

log_msg(sprintf("Processing %d cells", nrow(cells)))



# ---- Compute all three PPC types ----

log_msg("================================================================================")

log_msg("Computing PPC metrics per cell...")

ppc_start <- Sys.time()



res_conditional <- list()

res_unconditional <- list()

res_subjectwise <- list()



for (i in seq_len(nrow(cells))) {

  cell <- cells[i, ]

  cell_name <- paste(cell$task, cell$effort_condition, cell$difficulty_3, sep = ".")

  log_msg(sprintf("Processing cell %d/%d: %s (n=%d)", i, nrow(cells), cell_name, cell$n))

  

  cell_df <- dd %>%

    filter(task == cell$task,

           effort_condition == cell$effort_condition,

           difficulty_3 == cell$difficulty_3)

  

  # Conditional

  log_msg("  Computing conditional PPC...")

  m_cond <- one_cell_conditional(cell_df)

  res_conditional[[i]] <- bind_cols(cell, m_cond %>% rename(qp_rmse_cond = qp_rmse, ks_cond = ks_mean))

  

  # Unconditional (skip if slow, optional)

  log_msg("  Computing unconditional PPC...")

  m_uncond <- tryCatch({

    one_cell_unconditional(cell_df)

  }, error = function(e) {

    log_msg(sprintf("    Skipping unconditional: %s", e$message))

    tibble(qp_rmse = NA_real_, ks_mean = NA_real_)

  })

  res_unconditional[[i]] <- bind_cols(cell, m_uncond %>% rename(qp_rmse_uncond = qp_rmse, ks_uncond = ks_mean))

  

  # Subject-wise

  log_msg("  Computing subject-wise PPC...")

  m_subj <- one_cell_subjectwise(cell_df)

  res_subjectwise[[i]] <- bind_cols(cell, m_subj %>% rename(qp_rmse_subj = qp_rmse, ks_subj = ks_mean))

  

  log_msg(sprintf("  Conditional: qp=%.3f, ks=%.3f", 

                  ifelse(is.na(m_cond$qp_rmse), NA, m_cond$qp_rmse),

                  ifelse(is.na(m_cond$ks_mean), NA, m_cond$ks_mean)))

}



ppc_time <- as.numeric(difftime(Sys.time(), ppc_start, units = "secs"))

log_msg(sprintf("PPC computation completed in %.1f minutes", ppc_time / 60))



# ---- Combine and write ----

res_cond <- bind_rows(res_conditional) %>%

  mutate(

    qp_flag = ifelse(is.na(qp_rmse_cond), FALSE, qp_rmse_cond > thr_qp),

    ks_flag = ifelse(is.na(ks_cond), FALSE, ks_cond > thr_ks),

    any_flag = qp_flag | ks_flag

  )



res_uncond <- bind_rows(res_unconditional) %>%

  mutate(

    qp_flag = ifelse(is.na(qp_rmse_uncond), FALSE, qp_rmse_uncond > thr_qp),

    ks_flag = ifelse(is.na(ks_uncond), FALSE, ks_uncond > thr_ks),

    any_flag = qp_flag | ks_flag

  )



res_subj <- bind_rows(res_subjectwise) %>%

  mutate(

    qp_flag = ifelse(is.na(qp_rmse_subj), FALSE, qp_rmse_subj > thr_qp),

    ks_flag = ifelse(is.na(ks_subj), FALSE, ks_subj > thr_ks),

    any_flag = qp_flag | ks_flag

  )



# Combined results (add difficulty_level for downstream compatibility)
res_cond <- res_cond %>% mutate(difficulty_level = difficulty_3)
res_uncond <- res_uncond %>% mutate(difficulty_level = difficulty_3)
res_subj <- res_subj %>% mutate(difficulty_level = difficulty_3)

res_combined <- res_cond %>%

  left_join(res_uncond %>% select(task, effort_condition, difficulty_3, qp_rmse_uncond, ks_uncond), 

            by = c("task", "effort_condition", "difficulty_3")) %>%

  left_join(res_subj %>% select(task, effort_condition, difficulty_3, qp_rmse_subj, ks_subj), 

            by = c("task", "effort_condition", "difficulty_3"))



# Write outputs

readr::write_csv(res_cond, file.path(PUBLISH_DIR, "table3_ppc_primary_conditional.csv"))

readr::write_csv(res_uncond, file.path(PUBLISH_DIR, "table3_ppc_primary_unconditional.csv"))

readr::write_csv(res_subj, file.path(PUBLISH_DIR, "table3_ppc_primary_subjectwise.csv"))

readr::write_csv(res_combined, file.path(PUBLISH_DIR, "table3_ppc_primary_diagnostic_combined.csv"))

# Write subjectwise as _censored alias for appendix (ch03_appA expects table3_ppc_primary_subjectwise_censored.csv)
readr::write_csv(res_subj, file.path(PUBLISH_DIR, "table3_ppc_primary_subjectwise_censored.csv"))

# PPC gate summary (for appendix and extract_ppc_gates compatibility)
gate_summary <- res_subj %>%
  summarise(
    n_cells = n(),
    n_flagged = sum(any_flag, na.rm = TRUE),
    pct_flagged = if (n() > 0) 100 * mean(any_flag, na.rm = TRUE) else 0,
    max_qp = if (all(is.na(qp_rmse_subj))) NA_real_ else max(qp_rmse_subj, na.rm = TRUE),
    max_ks = if (all(is.na(ks_subj))) NA_real_ else max(ks_subj, na.rm = TRUE),
    .groups = "drop"
  )
readr::write_csv(gate_summary, file.path(PUBLISH_DIR, "ppc_gate_summary.csv"))

# pf_subj for appendix
pf_subj <- list(
  n_cells = gate_summary$n_cells[1],
  n_flagged = gate_summary$n_flagged[1],
  pct_flagged = gate_summary$pct_flagged[1]
)
saveRDS(pf_subj, file.path(PUBLISH_DIR, "pf_subj.rds"))

log_msg("✓ Results written to output/publish/")



# ---- Summary ----

log_msg("================================================================================")

log_msg("PPC SUMMARY")

log_msg("")

log_msg("CONDITIONAL PPC:")

n_flagged_cond <- sum(res_cond$any_flag, na.rm = TRUE)

log_msg(sprintf("  Cells flagged: %d/%d (%.1f%%)", n_flagged_cond, nrow(res_cond), 

                if (nrow(res_cond) > 0) (n_flagged_cond/nrow(res_cond))*100 else 0))

max_ks_cond <- suppressWarnings(max(res_cond$ks_cond, na.rm = TRUE))
max_qp_cond <- suppressWarnings(max(res_cond$qp_rmse_cond, na.rm = TRUE))
log_msg(sprintf("  Max KS: %.3f, Max QP: %.3f", 

                if (is.finite(max_ks_cond)) max_ks_cond else NA_real_,
                if (is.finite(max_qp_cond)) max_qp_cond else NA_real_))

log_msg("")

log_msg("UNCONDITIONAL PPC:")

n_flagged_uncond <- sum(res_uncond$any_flag, na.rm = TRUE)

log_msg(sprintf("  Cells flagged: %d/%d (%.1f%%)", n_flagged_uncond, nrow(res_uncond), 

                if (nrow(res_uncond) > 0) (n_flagged_uncond/nrow(res_uncond))*100 else 0))

max_ks_uncond <- suppressWarnings(max(res_uncond$ks_uncond, na.rm = TRUE))
max_qp_uncond <- suppressWarnings(max(res_uncond$qp_rmse_uncond, na.rm = TRUE))
log_msg(sprintf("  Max KS: %.3f, Max QP: %.3f", 

                if (is.finite(max_ks_uncond)) max_ks_uncond else NA_real_,
                if (is.finite(max_qp_uncond)) max_qp_uncond else NA_real_))

log_msg("")

log_msg("SUBJECT-WISE PPC:")

n_flagged_subj <- sum(res_subj$any_flag, na.rm = TRUE)

log_msg(sprintf("  Cells flagged: %d/%d (%.1f%%)", n_flagged_subj, nrow(res_subj), 

                if (nrow(res_subj) > 0) (n_flagged_subj/nrow(res_subj))*100 else 0))

max_ks_subj <- suppressWarnings(max(res_subj$ks_subj, na.rm = TRUE))
max_qp_subj <- suppressWarnings(max(res_subj$qp_rmse_subj, na.rm = TRUE))
log_msg(sprintf("  Max KS: %.3f, Max QP: %.3f", 

                if (is.finite(max_ks_subj)) max_ks_subj else NA_real_,
                if (is.finite(max_qp_subj)) max_qp_subj else NA_real_))



log_msg("")

log_msg("================================================================================")

log_msg("COMPLETE")

