# R/export_ppc_primary_heavy.R

# Heavy posterior predictive checks for primary v+z+a model

# Uses RWiener for proper simulation of RT + decisions (separate correct/error analysis)

suppressPackageStartupMessages({

  library(brms)

  library(dplyr)

  library(readr)

  library(tidyr)

})



# ---- Ensure RWiener is available ----

if (!requireNamespace("RWiener", quietly = TRUE)) {

  log_msg("Installing RWiener package...")

  install.packages("RWiener", repos = "https://cloud.r-project.org")

}

library(RWiener)  # rwiener(n, alpha, tau, beta, delta)



PUBLISH_DIR <- "output/publish"

dir.create(PUBLISH_DIR, showWarnings = FALSE, recursive = TRUE)



# ---- Logging ----

log_msg <- function(...) {

  msg <- paste(..., collapse = " ")

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  cat(sprintf("[%s] %s\n", timestamp, msg))

}



log_msg("================================================================================")

log_msg("START export_ppc_primary_heavy.R")

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

thr <- list(acc = 0.05, qp = 0.09, ks = 0.15, caf = 0.07)

log_msg("PPC thresholds:", paste(sprintf("%s=%.2f", names(thr), unlist(thr)), collapse = ", "))



# ---- Helper: get population-level dpars per cell (no subject RE) ----

get_dpars <- function(newdata, ndraws = 200) {

  # Population-level only (re_formula = NA)

  v    <- posterior_linpred(fit, newdata = newdata, dpar = "mu",

                            re_formula = NA, ndraws = ndraws)

  bs   <- posterior_linpred(fit, newdata = newdata, dpar = "bs",

                            re_formula = NA, ndraws = ndraws)

  ndt  <- posterior_linpred(fit, newdata = newdata, dpar = "ndt",

                            re_formula = NA, ndraws = ndraws)

  bias <- posterior_linpred(fit, newdata = newdata, dpar = "bias",

                            re_formula = NA, ndraws = ndraws)

  

  # Transform links: bs/ndt are log-link, bias is logit-link

  list(

    v    = v[, 1],                               # identity (drift)

    a    = exp(bs[, 1]),                         # boundary (alpha in RWiener)

    t0   = exp(ndt[, 1]),                        # non-decision time (tau in RWiener)

    z    = 1 / (1 + exp(-bias[, 1]))             # bias/starting point (beta in RWiener; invlogit)

  )

}



# ---- Metrics per cell ----

metrics_list <- list()

set.seed(20251116)

ppc_start <- Sys.time()



for (i in seq_len(nrow(cells))) {

  cell <- cells[i, ]

  cell_name <- paste(cell$task, cell$effort_condition, cell$difficulty_level, sep = ".")

  log_msg(sprintf("Processing cell %d/%d: %s (n=%d)", 

                  i, nrow(cells), cell_name, cell$n))

  

  cell_df <- dd %>%

    filter(task == cell$task,

           effort_condition == cell$effort_condition,

           difficulty_level == cell$difficulty_level)

  

  # Skip empty cells

  if (nrow(cell_df) == 0 || all(is.na(cell_df$rt)) || all(is.na(cell_df$decision))) {

    log_msg(sprintf("  Skipping empty cell: %s", cell_name))

    metrics_list[[i]] <- tibble(

      task = cell$task, 

      effort_condition = cell$effort_condition, 

      difficulty_level = cell$difficulty_level,

      emp_acc = NA_real_, 

      pred_acc = NA_real_, 

      acc_abs_diff = NA_real_,

      qp_rmse = NA_real_, 

      ks_mean = NA_real_, 

      caf_rmse = NA_real_

    )

    next

  }

  

  # Empirical summary

  emp_rt  <- cell_df$rt[!is.na(cell_df$rt) & !is.na(cell_df$decision)]

  emp_acc <- mean(cell_df$decision == 1, na.rm = TRUE)

  

  # Get population-level dpars for this cell

  tryCatch({

    dp <- get_dpars(cell, ndraws = 200)

  }, error = function(e) {

    log_msg(sprintf("  Error getting dpars for %s: %s", cell_name, e$message))

    stop(e)

  })

  

  # Simulate RT + response per draw

  n_sim <- min(max(2000, length(emp_rt)), 5000)

  log_msg(sprintf("  Simulating %d trials per draw (%d draws)", n_sim, length(dp$v)))

  

  # Collect simulations (rt + correct flag)

  sim_rts  <- numeric()

  sim_corr <- logical()

  

  for (d in seq_along(dp$v)) {

    tryCatch({

      sim <- RWiener::rwiener(

        n = n_sim, 

        alpha = dp$a[d],    # boundary

        tau = dp$t0[d],     # non-decision time

        beta = dp$z[d],     # bias (starting point)

        delta = dp$v[d]     # drift

      )

      # RWiener returns resp "upper"/"lower"; treat "upper" as correct boundary

      sim_rts  <- c(sim_rts, sim$q)

      sim_corr <- c(sim_corr, sim$resp == "upper")

    }, error = function(e) {

      log_msg(sprintf("    Warning: rwiener failed for draw %d: %s", d, e$message))

    })

  }

  

  if (length(sim_rts) == 0) {

    log_msg(sprintf("  No valid simulations for %s", cell_name))

    metrics_list[[i]] <- tibble(

      task = cell$task, 

      effort_condition = cell$effort_condition, 

      difficulty_level = cell$difficulty_level,

      emp_acc = emp_acc, 

      pred_acc = NA_real_, 

      acc_abs_diff = NA_real_,

      qp_rmse = NA_real_, 

      ks_mean = NA_real_, 

      caf_rmse = NA_real_

    )

    next

  }

  

  # Predicted accuracy

  pred_acc <- mean(sim_corr, na.rm = TRUE)

  

  # QP RMSE: compare RT quantiles for correct and error separately, then pool

  qps <- c(.1, .3, .5, .7, .9)

  

  # Empirical correct/error RTs

  emp_rt_cor  <- emp_rt[cell_df$decision[!is.na(cell_df$rt) & !is.na(cell_df$decision)] == 1]

  emp_rt_err  <- emp_rt[cell_df$decision[!is.na(cell_df$rt) & !is.na(cell_df$decision)] == 0]

  pred_rt_cor <- sim_rts[sim_corr]

  pred_rt_err <- sim_rts[!sim_corr]

  

  # Guard against all-correct or all-error empirical cells

  qp_rmse <- NA_real_

  ks_max  <- NA_real_

  comp <- list()

  

  if (length(emp_rt_cor) > 10 && length(pred_rt_cor) > 10) {

    emp_qc <- quantile(emp_rt_cor, probs = qps, na.rm = TRUE)

    prd_qc <- quantile(pred_rt_cor, probs = qps, na.rm = TRUE)

    rmse_c <- sqrt(mean((prd_qc - emp_qc)^2, na.rm = TRUE))

    ks_c   <- suppressWarnings(ks.test(pred_rt_cor, emp_rt_cor)$statistic)

    comp$rmse_c <- rmse_c

    comp$ks_c <- as.numeric(ks_c)

  }

  

  if (length(emp_rt_err) > 10 && length(pred_rt_err) > 10) {

    emp_qe <- quantile(emp_rt_err, probs = qps, na.rm = TRUE)

    prd_qe <- quantile(pred_rt_err, probs = qps, na.rm = TRUE)

    rmse_e <- sqrt(mean((prd_qe - emp_qe)^2, na.rm = TRUE))

    ks_e   <- suppressWarnings(ks.test(pred_rt_err, emp_rt_err)$statistic)

    comp$rmse_e <- rmse_e

    comp$ks_e <- as.numeric(ks_e)

  }

  

  # Pool (weight by empirical counts)

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

  } else {

    qp_rmse <- NA_real_

    ks_max <- NA_real_

  }

  

  # CAF RMSE: bin by empirical RT quintiles, compare accuracy per bin

  cuts <- quantile(emp_rt, probs = seq(0, 1, length.out = 6), na.rm = TRUE)

  cuts[1] <- cuts[1] - 0.001  # Ensure all values included

  cuts[length(cuts)] <- cuts[length(cuts)] + 0.001

  

  # Empirical CAF

  valid_emp <- !is.na(cell_df$rt) & !is.na(cell_df$decision) & cell_df$rt >= min(cuts) & cell_df$rt <= max(cuts)

  bin_emp <- cut(cell_df$rt[valid_emp], cuts, include.lowest = TRUE, labels = FALSE)

  caf_emp <- tapply(cell_df$decision[valid_emp], bin_emp, 

                    function(x) mean(x == 1, na.rm = TRUE))

  

  # Predicted CAF

  valid_prd <- !is.na(sim_rts) & sim_rts >= min(cuts) & sim_rts <= max(cuts)

  bin_prd <- cut(sim_rts[valid_prd], cuts, include.lowest = TRUE, labels = FALSE)

  caf_prd <- tapply(sim_corr[valid_prd], bin_prd, 

                    function(x) mean(x, na.rm = TRUE))

  

  # Align lengths for comparison

  common_bins <- intersect(names(caf_emp), names(caf_prd))

  caf_rmse <- if (length(common_bins) > 0) {

    sqrt(mean((caf_prd[common_bins] - caf_emp[common_bins])^2, na.rm = TRUE))

  } else {

    NA_real_

  }

  

  tib <- tibble(

    task = cell$task, 

    effort_condition = cell$effort_condition, 

    difficulty_level = cell$difficulty_level,

    emp_acc = emp_acc, 

    pred_acc = pred_acc, 

    acc_abs_diff = abs(emp_acc - pred_acc),

    qp_rmse = qp_rmse, 

    ks_mean = ks_max, 

    caf_rmse = as.numeric(caf_rmse)

  )

  metrics_list[[i]] <- tib

  log_msg(sprintf("  Completed: acc_diff=%.3f, qp_rmse=%.3f, ks=%.3f, caf_rmse=%.3f",

                  tib$acc_abs_diff, 

                  ifelse(is.na(tib$qp_rmse), NA, tib$qp_rmse),

                  ifelse(is.na(tib$ks_mean), NA, tib$ks_mean),

                  ifelse(is.na(tib$caf_rmse), NA, tib$caf_rmse)))

}



ppc_time <- as.numeric(difftime(Sys.time(), ppc_start, units = "secs"))

log_msg(sprintf("PPC computation completed in %.1f seconds (%.1f minutes)", 

                ppc_time, ppc_time / 60))



# ---- Combine results ----

metrics <- bind_rows(metrics_list) %>%

  mutate(

    acc_flag = ifelse(is.na(acc_abs_diff), FALSE, acc_abs_diff > thr$acc),

    qp_flag  = ifelse(is.na(qp_rmse), FALSE, qp_rmse > thr$qp),

    ks_flag  = ifelse(is.na(ks_mean), FALSE, ks_mean > thr$ks),

    caf_flag = ifelse(is.na(caf_rmse), FALSE, caf_rmse > thr$caf),

    any_flag = acc_flag | qp_flag | ks_flag | caf_flag

  )



# ---- Write output ----

ppc_csv <- file.path(PUBLISH_DIR, "table3_ppc_primary_correct_error.csv")

readr::write_csv(metrics, ppc_csv)

log_msg(sprintf("✓ PPC metrics written: %s", ppc_csv))



# ---- PASS/FAIL summary ----

n_flagged <- sum(metrics$any_flag, na.rm = TRUE)

n_total <- nrow(metrics[!is.na(metrics$any_flag), ])

pct_flagged <- if (n_total > 0) (n_flagged / n_total) * 100 else 0

max_ks <- max(metrics$ks_mean, na.rm = TRUE)

max_qp <- max(metrics$qp_rmse, na.rm = TRUE)

pass <- (pct_flagged <= 15) && 

        (!is.infinite(max_ks) && !is.na(max_ks) && max_ks <= 0.20) && 

        (!is.infinite(max_qp) && !is.na(max_qp) && max_qp <= 0.12)



msg <- if (pass) {

  sprintf("PASS: %.1f%% cells flagged (≤15%%). Max KS=%.3f, Max QP=%.3f", 

          pct_flagged, max_ks, max_qp)

} else {

  sprintf("FAIL: %.1f%% cells flagged (>15%%) or catastrophic outlier present. Max KS=%.3f, Max QP=%.3f", 

          pct_flagged, max_ks, max_qp)

}

log_msg("")

log_msg("PPC SUMMARY (correct/error separate):")

log_msg(msg)

writeLines(msg, file.path(PUBLISH_DIR, "ppc_passfail_correct_error.txt"))

log_msg(sprintf("✓ Pass/fail summary written: output/publish/ppc_passfail_correct_error.txt"))



log_msg("")

log_msg("================================================================================")

log_msg("COMPLETE")

