# R/export_ppc_primary_subjectaware.R

# Subject-aware posterior predictive checks for primary v+z+a model

# Uses brms native posterior_predict() with random effects (re_formula = NULL)

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

log_msg("START export_ppc_primary_subjectaware.R")

log_msg("Working directory:", getwd())



# ---- Load fit and data ----

fit_path <- file.path(PUBLISH_DIR, "fit_primary_vza.rds")

if (!file.exists(fit_path)) {

  stop(sprintf("Model file not found: %s\nRun R/fit_primary_vza.R first.", fit_path))

}

log_msg("Loading model:", fit_path)

fit <- readRDS(fit_path)



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



# ---- Thresholds ----

thr <- list(qp = 0.09, ks = 0.15, caf = 0.07)

log_msg("PPC thresholds:", paste(sprintf("%s=%.2f", names(thr), unlist(thr)), collapse = ", "))

log_msg("(Accuracy diff omitted - conditional PPC on observed decisions)")



# ---- Settings ----

set.seed(20251116)

NDRAWS <- 300

log_msg(sprintf("Using %d draws per cell", NDRAWS))



# ---- Helper: compute metrics for a cell ----

calc_metrics <- function(cell_df) {

  # Skip empty cells

  if (nrow(cell_df) == 0 || all(is.na(cell_df$rt)) || all(is.na(cell_df$decision))) {

    return(tibble(

      qp_rmse = NA_real_,

      ks_mean = NA_real_,

      caf_rmse = NA_real_

    ))

  }

  

  # Posterior predictive RTs including subject RE; conditional on decision

  # re_formula = NULL includes all random effects

  pp <- tryCatch({

    posterior_predict(fit, newdata = cell_df, ndraws = NDRAWS, re_formula = NULL)

  }, error = function(e) {

    log_msg(sprintf("    Error in posterior_predict: %s", e$message))

    return(NULL)

  })

  

  if (is.null(pp) || ncol(pp) == 0) {

    return(tibble(

      qp_rmse = NA_real_,

      ks_mean = NA_real_,

      caf_rmse = NA_real_

    ))

  }

  

  # Empirical RTs

  emp_rt <- cell_df$rt[!is.na(cell_df$rt) & !is.na(cell_df$decision)]

  emp_rt_cor <- emp_rt[cell_df$decision[!is.na(cell_df$rt) & !is.na(cell_df$decision)] == 1]

  emp_rt_err <- emp_rt[cell_df$decision[!is.na(cell_df$rt) & !is.na(cell_df$decision)] == 0]

  

  # Split predicted by the same trial indices

  # posterior_predict returns [draw x trials] RTs aligned with newdata rows

  valid_idx <- !is.na(cell_df$rt) & !is.na(cell_df$decision)

  pred_cor <- pp[, cell_df$decision[valid_idx] == 1, drop = FALSE]

  pred_err <- pp[, cell_df$decision[valid_idx] == 0, drop = FALSE]

  

  qps <- c(.1, .3, .5, .7, .9)

  qp_rmse <- NA_real_

  ks_max <- NA_real_

  comp <- list()

  

  # Correct responses

  if (length(emp_rt_cor) > 10 && ncol(pred_cor) > 10) {

    emp_qc <- quantile(emp_rt_cor, probs = qps, na.rm = TRUE)

    prd_qc <- apply(pred_cor, 1, function(x) {

      x_clean <- x[!is.na(x) & is.finite(x)]

      if (length(x_clean) < 2) return(rep(NA, length(qps)))

      quantile(x_clean, probs = qps, na.rm = TRUE)

    })

    rmse_c <- sqrt(mean((rowMeans(prd_qc, na.rm = TRUE) - emp_qc)^2, na.rm = TRUE))

    # KS: average over draws

    ks_c <- mean(apply(pred_cor, 1, function(x) {

      x_clean <- x[!is.na(x) & is.finite(x)]

      if (length(x_clean) < 2 || length(emp_rt_cor) < 2) return(NA)

      suppressWarnings(ks.test(x_clean, emp_rt_cor)$statistic)

    }), na.rm = TRUE)

    comp$rmse_c <- rmse_c

    comp$ks_c <- as.numeric(ks_c)

  }

  

  # Error responses

  if (length(emp_rt_err) > 10 && ncol(pred_err) > 10) {

    emp_qe <- quantile(emp_rt_err, probs = qps, na.rm = TRUE)

    prd_qe <- apply(pred_err, 1, function(x) {

      x_clean <- x[!is.na(x) & is.finite(x)]

      if (length(x_clean) < 2) return(rep(NA, length(qps)))

      quantile(x_clean, probs = qps, na.rm = TRUE)

    })

    rmse_e <- sqrt(mean((rowMeans(prd_qe, na.rm = TRUE) - emp_qe)^2, na.rm = TRUE))

    ks_e <- mean(apply(pred_err, 1, function(x) {

      x_clean <- x[!is.na(x) & is.finite(x)]

      if (length(x_clean) < 2 || length(emp_rt_err) < 2) return(NA)

      suppressWarnings(ks.test(x_clean, emp_rt_err)$statistic)

    }), na.rm = TRUE)

    comp$rmse_e <- rmse_e

    comp$ks_e <- as.numeric(ks_e)

  }

  

  # Pool QP and KS (weighted by empirical counts)

  w_c <- sum(cell_df$decision == 1, na.rm = TRUE)

  w_e <- sum(cell_df$decision == 0, na.rm = TRUE)

  

  if (!is.null(comp$rmse_c) && !is.null(comp$rmse_e)) {

    qp_rmse <- (w_c * comp$rmse_c + w_e * comp$rmse_e) / (w_c + w_e)

    ks_max <- max(comp$ks_c, comp$ks_e, na.rm = TRUE)

  } else if (!is.null(comp$rmse_c)) {

    qp_rmse <- comp$rmse_c

    ks_max <- comp$ks_c

  } else if (!is.null(comp$rmse_e)) {

    qp_rmse <- comp$rmse_e

    ks_max <- comp$ks_e

  }

  

  # CAF: empirical RT quintile bins, compare binwise accuracy

  cuts <- tryCatch({

    quantile(emp_rt, probs = seq(0, 1, length.out = 6), na.rm = TRUE)

  }, error = function(e) return(NA))

  

  caf_rmse <- NA_real_

  if (!any(is.na(cuts))) {

    cuts[1] <- cuts[1] - 0.001

    cuts[length(cuts)] <- cuts[length(cuts)] + 0.001

    

    bin_emp <- cut(emp_rt, cuts, include.lowest = TRUE, labels = FALSE)

    valid_bin <- !is.na(bin_emp)

    caf_emp <- tapply(cell_df$decision[!is.na(cell_df$rt) & !is.na(cell_df$decision)][valid_bin], 

                      bin_emp[valid_bin], 

                      function(x) mean(x == 1, na.rm = TRUE))

    

    # For predicted, use mean RT over draws per trial

    prd_rt_mean <- colMeans(pp, na.rm = TRUE)

    bin_prd <- cut(prd_rt_mean[valid_idx], cuts, include.lowest = TRUE, labels = FALSE)

    valid_bin_prd <- !is.na(bin_prd)

    caf_prd <- tapply(cell_df$decision[valid_idx][valid_bin_prd], 

                      bin_prd[valid_bin_prd], 

                      function(x) mean(x == 1, na.rm = TRUE))

    

    # Align and compute RMSE

    common_bins <- intersect(names(caf_emp), names(caf_prd))

    if (length(common_bins) > 0) {

      caf_rmse <- sqrt(mean((caf_prd[common_bins] - caf_emp[common_bins])^2, na.rm = TRUE))

    }

  }

  

  tibble(

    qp_rmse = qp_rmse,

    ks_mean = ks_max,

    caf_rmse = caf_rmse

  )

}



# ---- Compute metrics per cell ----

log_msg("Computing PPC metrics per cell (subject-aware)...")

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

  

  metrics <- calc_metrics(cell_df)

  res_list[[i]] <- bind_cols(cell, metrics)

  log_msg(sprintf("  Completed: qp_rmse=%.3f, ks=%.3f, caf_rmse=%.3f",

                  ifelse(is.na(metrics$qp_rmse), NA, metrics$qp_rmse),

                  ifelse(is.na(metrics$ks_mean), NA, metrics$ks_mean),

                  ifelse(is.na(metrics$caf_rmse), NA, metrics$caf_rmse)))

}



ppc_time <- as.numeric(difftime(Sys.time(), ppc_start, units = "secs"))

log_msg(sprintf("PPC computation completed in %.1f seconds (%.1f minutes)", 

                ppc_time, ppc_time / 60))



# ---- Combine results ----

res <- bind_rows(res_list) %>%

  mutate(

    qp_flag = ifelse(is.na(qp_rmse), FALSE, qp_rmse > thr$qp),

    ks_flag = ifelse(is.na(ks_mean), FALSE, ks_mean > thr$ks),

    caf_flag = ifelse(is.na(caf_rmse), FALSE, caf_rmse > thr$caf),

    any_flag = qp_flag | ks_flag | caf_flag

  )



# ---- Write output ----

ppc_csv <- file.path(PUBLISH_DIR, "table3_ppc_primary_subjectaware.csv")

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

log_msg("PPC SUMMARY (subject-aware):")

log_msg(msg)

writeLines(msg, file.path(PUBLISH_DIR, "ppc_passfail_subjectaware.txt"))

log_msg(sprintf("✓ Pass/fail summary written: output/publish/ppc_passfail_subjectaware.txt"))



log_msg("")

log_msg("================================================================================")

log_msg("COMPLETE")





