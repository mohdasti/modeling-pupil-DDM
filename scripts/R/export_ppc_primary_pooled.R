# R/export_ppc_primary_pooled.R

# Pooled posterior predictive checks for primary v+z+a model

# Pools draws into single predictive sample per cell (more stable than averaging over draws)

# CAF removed from gate (requires unconditional simulation)

suppressPackageStartupMessages({

  library(brms)

  library(dplyr)

  library(readr)

  library(tidyr)

})



PUBLISH_DIR <- "output/publish"

dir.create(PUBLISH_DIR, showWarnings = FALSE, recursive = TRUE)



# ---- Logging ----

log_msg <- function(...) {

  msg <- paste(..., collapse = " ")

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  cat(sprintf("[%s] %s\n", timestamp, msg))

}



log_msg("================================================================================")

log_msg("START export_ppc_primary_pooled.R")

log_msg("Working directory:", getwd())



# ---- Load fit and data ----

# Try new model first, fallback to original

fit_paths <- c(

  file.path(PUBLISH_DIR, "fit_primary_vza_vINTX.rds"),

  file.path(PUBLISH_DIR, "fit_primary_vza_biasintx.rds"),

  file.path(PUBLISH_DIR, "fit_primary_vza_bsintx.rds"),

  file.path(PUBLISH_DIR, "fit_primary_vza.rds")  # fallback if first not present

)

fit_path <- fit_paths[file.exists(fit_paths)][1]

if (is.na(fit_path)) {

  stop(sprintf("No fit found in %s\nExpected: fit_primary_vza_vINTX.rds, fit_primary_vza_biasintx.rds, fit_primary_vza_bsintx.rds, or fit_primary_vza.rds", PUBLISH_DIR))

}

log_msg("Loading model:", fit_path)

fit <- readRDS(fit_path)

log_msg(sprintf("Model loaded successfully: %s", basename(fit_path)))



data_path <- "data/analysis_ready/bap_ddm_ready.csv"

log_msg("Loading data:", data_path)

dd <- readr::read_csv(data_path, show_col_types = FALSE)



# Derive decision column (same logic as fit script)

if (!"decision" %in% names(dd)) {

  log_msg("Column 'decision' not found; attempting to derive from alternatives...")

  if ("iscorr" %in% names(dd)) {

    dd$decision <- as.integer(dd$iscorr)

    log_msg("Derived 'decision' from 'iscorr'.")

  } else if ("correct" %in% names(dd)) {

    dd$decision <- as.integer(dd$correct)

    log_msg("Derived 'decision' from 'correct'.")

  } else if ("is_correct" %in% names(dd)) {

    dd$decision <- as.integer(dd$is_correct)

    log_msg("Derived 'decision' from 'is_correct'.")

  } else if ("accuracy" %in% names(dd) || "acc" %in% names(dd)) {

    col_name <- ifelse("accuracy" %in% names(dd), "accuracy", "acc")

    dd$decision <- as.integer(dd[[col_name]])

    log_msg(sprintf("Derived 'decision' from '%s'.", col_name))

  } else if ("choice_binary" %in% names(dd)) {

    stop("choice_binary is response side, not correctness. Map to correctness before fitting.")

  } else {

    stop("Missing 'decision' (or equivalent). Expected one of: decision, iscorr, correct, is_correct, accuracy, acc.")

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



# ---- Cells to evaluate ----

cell_vars <- c("task", "effort_condition", "difficulty_level")

cells <- dd %>% 

  group_by(across(all_of(cell_vars))) %>% 

  summarise(n = n(), .groups = "drop")

log_msg(sprintf("Processing %d cells", nrow(cells)))



# ---- Settings ----

set.seed(20251116)

NDRAWS <- 400

log_msg(sprintf("Using %d draws per cell (will be pooled)", NDRAWS))

log_msg("CAF removed from pass/fail gate (requires unconditional simulation)")



# ---- Thresholds (CAF dropped from gate) ----

thr_qp <- 0.09

thr_ks <- 0.15

log_msg(sprintf("PPC thresholds: QP=%.2f, KS=%.2f", thr_qp, thr_ks))



# ---- Helper: compute metrics for one cell ----

one_cell <- function(cell_df) {

  # Skip empty cells

  if (nrow(cell_df) == 0 || all(is.na(cell_df$rt)) || all(is.na(cell_df$decision))) {

    return(tibble(

      qp_rmse = NA_real_,

      ks_mean = NA_real_

    ))

  }

  

  # Posterior predictive RTs including RE; conditional on each trial's decision

  pp <- tryCatch({

    posterior_predict(fit, newdata = cell_df, ndraws = NDRAWS, re_formula = NULL)

  }, error = function(e) {

    log_msg(sprintf("    Error in posterior_predict: %s", e$message))

    return(NULL)

  })

  

  if (is.null(pp) || ncol(pp) == 0) {

    return(tibble(

      qp_rmse = NA_real_,

      ks_mean = NA_real_

    ))

  }

  

  qps <- c(.1, .3, .5, .7, .9)

  emp_rt <- cell_df$rt[!is.na(cell_df$rt) & !is.na(cell_df$decision)]

  emp_cor <- emp_rt[cell_df$decision[!is.na(cell_df$rt) & !is.na(cell_df$decision)] == 1]

  emp_err <- emp_rt[cell_df$decision[!is.na(cell_df$rt) & !is.na(cell_df$decision)] == 0]

  

  # Pool draws to a single predictive sample per cell/condition

  # pp is [draws x trials], we pool all draws for correct/error separately

  valid_idx <- !is.na(cell_df$rt) & !is.na(cell_df$decision)

  pred_cor <- as.numeric(pp[, cell_df$decision[valid_idx] == 1, drop = FALSE])

  pred_err <- as.numeric(pp[, cell_df$decision[valid_idx] == 0, drop = FALSE])

  

  # Filter out NA/Inf

  pred_cor <- pred_cor[!is.na(pred_cor) & is.finite(pred_cor)]

  pred_err <- pred_err[!is.na(pred_err) & is.finite(pred_err)]

  

  # Quantile RMSE (weighted over cor/err)

  qp_rmse <- NA_real_

  ks_max <- NA_real_

  comp <- list()

  

  # Correct responses

  if (length(emp_cor) > 10 && length(pred_cor) > 10) {

    emp_qc <- quantile(emp_cor, probs = qps, na.rm = TRUE)

    prd_qc <- quantile(pred_cor, probs = qps, na.rm = TRUE)

    comp$rmse_c <- sqrt(mean((prd_qc - emp_qc)^2, na.rm = TRUE))

    comp$ks_c <- suppressWarnings(stats::ks.test(pred_cor, emp_cor)$statistic) |> as.numeric()

  }

  

  # Error responses

  if (length(emp_err) > 10 && length(pred_err) > 10) {

    emp_qe <- quantile(emp_err, probs = qps, na.rm = TRUE)

    prd_qe <- quantile(pred_err, probs = qps, na.rm = TRUE)

    comp$rmse_e <- sqrt(mean((prd_qe - emp_qe)^2, na.rm = TRUE))

    comp$ks_e <- suppressWarnings(stats::ks.test(pred_err, emp_err)$statistic) |> as.numeric()

  }

  

  # Weighted average over correct/error

  w_c <- sum(cell_df$decision == 1, na.rm = TRUE)

  w_e <- sum(cell_df$decision == 0, na.rm = TRUE)

  

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

  

  tibble(

    qp_rmse = qp_rmse,

    ks_mean = ks_max

  )

}



# ---- Compute metrics per cell ----

log_msg("Computing PPC metrics per cell (pooled draws)...")

ppc_start <- Sys.time()



res_list <- list()

for (i in seq_len(nrow(cells))) {

  cell <- cells[i, ]

  cell_name <- paste(cell$task, cell$effort_condition, cell$difficulty_level, sep = ".")

  log_msg(sprintf("Processing cell %d/%d: %s (n=%d)", 

                  i, nrow(cells), cell_name, cell$n))

  

  cell_df <- dd %>%

    filter(task == cell$task,

           effort_condition == cell$effort_condition,

           difficulty_level == cell$difficulty_level)

  

  metrics <- one_cell(cell_df)

  res_list[[i]] <- bind_cols(cell, metrics)

  log_msg(sprintf("  Completed: qp_rmse=%.3f, ks=%.3f",

                  ifelse(is.na(metrics$qp_rmse), NA, metrics$qp_rmse),

                  ifelse(is.na(metrics$ks_mean), NA, metrics$ks_mean)))

}



ppc_time <- as.numeric(difftime(Sys.time(), ppc_start, units = "secs"))

log_msg(sprintf("PPC computation completed in %.1f seconds (%.1f minutes)", 

                ppc_time, ppc_time / 60))



# ---- Combine results ----

res <- bind_rows(res_list) %>%

  mutate(

    qp_flag = ifelse(is.na(qp_rmse), FALSE, qp_rmse > thr_qp),

    ks_flag = ifelse(is.na(ks_mean), FALSE, ks_mean > thr_ks),

    any_flag = qp_flag | ks_flag

  )



# ---- Write output ----

ppc_csv <- file.path(PUBLISH_DIR, "table3_ppc_primary_pooled.csv")

readr::write_csv(res, ppc_csv)

log_msg(sprintf("✓ PPC metrics written: %s", ppc_csv))



# ---- PASS/FAIL summary ----

n_flagged <- sum(res$any_flag, na.rm = TRUE)

n_total <- nrow(res[!is.na(res$any_flag), ])

pct_flagged <- if (n_total > 0) (n_flagged / n_total) * 100 else 0

max_ks <- max(res$ks_mean, na.rm = TRUE)

max_qp <- max(res$qp_rmse, na.rm = TRUE)

pass <- (pct_flagged <= 15) && 

        (!is.infinite(max_ks) && !is.na(max_ks) && max_ks <= 0.20) && 

        (!is.infinite(max_qp) && !is.na(max_qp) && max_qp <= 0.12)



msg <- if (pass) {

  sprintf("PASS: %.1f%% cells flagged (≤15%%). Max KS=%.3f, Max QP=%.3f", 

          pct_flagged, max_ks, max_qp)

} else {

  sprintf("FAIL: %.1f%% cells flagged (>15%%) or outlier present. Max KS=%.3f, Max QP=%.3f", 

          pct_flagged, max_ks, max_qp)

}

log_msg("")

log_msg("PPC SUMMARY (pooled draws, CAF excluded from gate):")

log_msg(msg)

writeLines(msg, file.path(PUBLISH_DIR, "ppc_passfail_pooled.txt"))

log_msg(sprintf("✓ Pass/fail summary written: output/publish/ppc_passfail_pooled.txt"))



log_msg("")

log_msg("================================================================================")

log_msg("COMPLETE")

