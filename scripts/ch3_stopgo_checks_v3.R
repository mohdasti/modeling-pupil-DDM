#!/usr/bin/env Rscript
# ============================================================================
# Chapter 3 STOP/GO Checks (v3)
# ============================================================================
# Validates that CH3 extension and new features are working correctly
# Outputs: qc/ch3_extension_v3/STOP_GO_ch3_v3.csv
# ============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(readr)
})

REPO_ROOT <- normalizePath(".")
QUICK_SHARE_DIR <- file.path(REPO_ROOT, "quick_share_v7")
MERGED_FILE <- file.path(QUICK_SHARE_DIR, "merged", "BAP_triallevel_merged_v4.csv")
CH3_FILE <- file.path(QUICK_SHARE_DIR, "analysis_ready", "ch3_triallevel.csv")
WAVEFORM_FILE <- file.path(QUICK_SHARE_DIR, "analysis", "pupil_waveforms_condition_mean.csv")
TIMING_FILE <- file.path(QUICK_SHARE_DIR, "qc", "ch3_extension_v3", "timing_sanity_summary.csv")

QC_DIR <- file.path(QUICK_SHARE_DIR, "qc", "ch3_extension_v3")
dir.create(QC_DIR, recursive = TRUE, showWarnings = FALSE)

cat("=== CH3 Extension STOP/GO Checks (v3) ===\n\n")

checks <- list()

# Check 1: Join match rate
cat("Check 1: Join match rate\n")
if (file.exists(MERGED_FILE)) {
  merged <- fread(MERGED_FILE)
  n_total <- nrow(merged)
  n_matched <- sum(!is.na(merged$n_valid_B0))
  match_rate <- n_matched / n_total
  
  checks$join_match_rate <- list(
    check_name = "join_match_rate",
    status = if (match_rate >= 0.95) "GO" else if (match_rate >= 0.90) "WARN" else "STOP",
    value = match_rate,
    threshold = 0.95,
    message = paste0("Join match rate: ", sprintf("%.1f", 100*match_rate), "% (required: >=95%)")
  )
  cat("  ", checks$join_match_rate$status, ": ", checks$join_match_rate$message, "\n")
} else {
  checks$join_match_rate <- list(
    check_name = "join_match_rate",
    status = "STOP",
    value = NA_real_,
    threshold = 0.95,
    message = "merged_v4.csv not found"
  )
  cat("  STOP: merged_v4.csv not found\n")
}

# Check 2: Waveform extension
cat("\nCheck 2: Waveform data extension\n")
if (file.exists(WAVEFORM_FILE)) {
  waveform <- fread(WAVEFORM_FILE)
  ch3_waveform <- waveform %>% filter(chapter == "ch3")
  max_t_rel <- max(ch3_waveform$t_rel, na.rm = TRUE)
  
  checks$waveform_extension <- list(
    check_name = "waveform_extension",
    status = if (max_t_rel >= 7.65) "GO" else "STOP",
    value = max_t_rel,
    threshold = 7.65,
    message = paste0("Waveform extends to ", sprintf("%.2f", max_t_rel), "s (required: >=7.65s)")
  )
  cat("  ", checks$waveform_extension$status, ": ", checks$waveform_extension$message, "\n")
  
  # Check by task
  for (task_val in unique(ch3_waveform$task)) {
    task_max <- ch3_waveform %>% filter(task == task_val) %>% pull(t_rel) %>% max(na.rm = TRUE)
    check_name <- paste0("waveform_extension_", task_val)
    checks[[check_name]] <- list(
      check_name = check_name,
      status = if (task_max >= 7.65) "GO" else "STOP",
      value = task_max,
      threshold = 7.65,
      message = paste0("Task ", task_val, ": ", sprintf("%.2f", task_max), "s")
    )
    cat("    ", task_val, ": ", sprintf("%.2f", task_max), "s\n")
  }
} else {
  checks$waveform_extension <- list(
    check_name = "waveform_extension",
    status = "STOP",
    value = NA_real_,
    threshold = 7.65,
    message = "waveform file not found"
  )
  cat("  STOP: waveform file not found\n")
}

# Check 3: Time-to-peak summary
cat("\nCheck 3: Time-to-peak summary\n")
peak_file <- file.path(QC_DIR, "ch3_time_to_peak_summary.csv")
if (file.exists(peak_file)) {
  peak_data <- fread(peak_file)
  has_data <- nrow(peak_data) > 0 && any(!is.na(peak_data$time_to_peak)) && 
              all(is.finite(peak_data$time_to_peak))
  
  checks$time_to_peak_summary <- list(
    check_name = "time_to_peak_summary",
    status = if (has_data) "GO" else "STOP",
    value = if (has_data) nrow(peak_data) else 0L,
    threshold = 1L,
    message = if (has_data) {
      max_peak <- max(peak_data$time_to_peak, na.rm = TRUE)
      paste0("Time-to-peak summary exists with ", nrow(peak_data), " entries, max peak: ", 
             sprintf("%.2f", max_peak), "s")
    } else {
      "Time-to-peak summary is empty or invalid"
    }
  )
  cat("  ", checks$time_to_peak_summary$status, ": ", checks$time_to_peak_summary$message, "\n")
} else {
  checks$time_to_peak_summary <- list(
    check_name = "time_to_peak_summary",
    status = "STOP",
    value = 0L,
    threshold = 1L,
    message = "time_to_peak_summary.csv not found"
  )
  cat("  STOP: time_to_peak_summary.csv not found\n")
}

# Check 4: Window coverage
cat("\nCheck 4: Window coverage\n")
coverage_file <- file.path(QC_DIR, "ch3_window_coverage.csv")
if (file.exists(coverage_file)) {
  coverage <- fread(coverage_file)
  
  # Check W2.0 coverage (minimum acceptable)
  w2_0_coverage <- coverage %>% filter(window == "W2.0")
  has_w2_0 <- any(w2_0_coverage$coverage == TRUE)
  
  checks$window_coverage_w2_0 <- list(
    check_name = "window_coverage_w2_0",
    status = if (has_w2_0) "GO" else "STOP",
    value = as.integer(has_w2_0),
    threshold = 1L,
    message = if (has_w2_0) "W2.0 window has coverage" else "W2.0 window lacks data coverage"
  )
  cat("  W2.0: ", if (has_w2_0) "✓" else "✗", "\n")
  
  # Check W3.0 coverage (preferred)
  w3_0_coverage <- coverage %>% filter(window == "W3.0")
  has_w3_0 <- any(w3_0_coverage$coverage == TRUE)
  checks$window_coverage_w3_0 <- list(
    check_name = "window_coverage_w3_0",
    status = if (has_w3_0) "GO" else "WARN",
    value = as.integer(has_w3_0),
    threshold = 1L,
    message = if (has_w3_0) "W3.0 window has coverage" else "W3.0 window lacks data coverage"
  )
  cat("  W3.0: ", if (has_w3_0) "✓" else "✗", "\n")
} else {
  checks$window_coverage_w2_0 <- list(
    check_name = "window_coverage_w2_0",
    status = "STOP",
    value = 0L,
    threshold = 1L,
    message = "window_coverage.csv not found"
  )
  cat("  STOP: window_coverage.csv not found\n")
}

# Check 5: New W1.3 features
cat("\nCheck 5: New W1.3 features (cog_auc_w1p3, cog_mean_w1p3)\n")
if (file.exists(CH3_FILE)) {
  ch3_data <- fread(CH3_FILE)
  
  # Check cog_auc_w1p3
  if ("cog_auc_w1p3" %in% names(ch3_data)) {
    n_w1p3 <- sum(!is.na(ch3_data$cog_auc_w1p3))
    pct_w1p3 <- 100 * n_w1p3 / nrow(ch3_data)
    checks$cog_auc_w1p3_coverage <- list(
      check_name = "cog_auc_w1p3_coverage",
      status = if (pct_w1p3 >= 40) "GO" else if (pct_w1p3 >= 30) "WARN" else "STOP",
      value = pct_w1p3,
      threshold = 40.0,
      message = paste0("cog_auc_w1p3: ", sprintf("%.1f", pct_w1p3), "% non-NA (target: >=40%)")
    )
    cat("  cog_auc_w1p3: ", sprintf("%.1f", pct_w1p3), "% non-NA\n")
  } else {
    checks$cog_auc_w1p3_coverage <- list(
      check_name = "cog_auc_w1p3_coverage",
      status = "STOP",
      value = 0.0,
      threshold = 40.0,
      message = "cog_auc_w1p3 column not found"
    )
    cat("  STOP: cog_auc_w1p3 column not found\n")
  }
  
  # Check cog_mean_w1p3
  if ("cog_mean_w1p3" %in% names(ch3_data)) {
    n_mean_w1p3 <- sum(!is.na(ch3_data$cog_mean_w1p3))
    pct_mean_w1p3 <- 100 * n_mean_w1p3 / nrow(ch3_data)
    checks$cog_mean_w1p3_coverage <- list(
      check_name = "cog_mean_w1p3_coverage",
      status = if (pct_mean_w1p3 >= 40) "GO" else if (pct_mean_w1p3 >= 30) "WARN" else "STOP",
      value = pct_mean_w1p3,
      threshold = 40.0,
      message = paste0("cog_mean_w1p3: ", sprintf("%.1f", pct_mean_w1p3), "% non-NA (target: >=40%)")
    )
    cat("  cog_mean_w1p3: ", sprintf("%.1f", pct_mean_w1p3), "% non-NA\n")
  } else {
    checks$cog_mean_w1p3_coverage <- list(
      check_name = "cog_mean_w1p3_coverage",
      status = "STOP",
      value = 0.0,
      threshold = 40.0,
      message = "cog_mean_w1p3 column not found"
    )
    cat("  STOP: cog_mean_w1p3 column not found\n")
  }
} else {
  checks$cog_auc_w1p3_coverage <- list(
    check_name = "cog_auc_w1p3_coverage",
    status = "STOP",
    value = 0.0,
    threshold = 40.0,
    message = "ch3_triallevel.csv not found"
  )
}

# Check 6: Timing sanity
cat("\nCheck 6: Timing sanity\n")
if (file.exists(TIMING_FILE)) {
  timing <- fread(TIMING_FILE)
  target_onsets <- timing$target_onset_median
  target_deviations <- abs(target_onsets - 4.35)
  max_deviation <- max(target_deviations, na.rm = TRUE)
  
  checks$timing_sanity <- list(
    check_name = "timing_sanity",
    status = if (max_deviation <= 0.05) "GO" else "WARN",
    value = max_deviation,
    threshold = 0.05,
    message = paste0("Target onset medians near expected 4.35s (max deviation: ", 
                     sprintf("%.3f", max_deviation), "s)")
  )
  cat("  ", checks$timing_sanity$status, ": ", checks$timing_sanity$message, "\n")
  for (i in 1:nrow(timing)) {
    cat("    Task ", timing$task[i], ": ", sprintf("%.3f", timing$target_onset_median[i]), 
        "s (deviation: ", sprintf("%.3f", target_deviations[i]), "s)\n", sep = "")
  }
} else {
  checks$timing_sanity <- list(
    check_name = "timing_sanity",
    status = "WARN",
    value = NA_real_,
    threshold = 0.05,
    message = "timing_sanity_summary.csv not found"
  )
  cat("  WARN: timing_sanity_summary.csv not found\n")
}

# Check 7: Duplicate trial_uid
cat("\nCheck 7: Duplicate trial_uid\n")
if (file.exists(CH3_FILE)) {
  ch3_data <- fread(CH3_FILE)
  n_dups <- sum(duplicated(ch3_data$trial_uid))
  
  checks$trial_uid_unique <- list(
    check_name = "trial_uid_unique",
    status = if (n_dups == 0) "GO" else "STOP",
    value = n_dups,
    threshold = 0L,
    message = paste0("Duplicate trial_uid: ", n_dups, " (required: 0)")
  )
  cat("  ", checks$trial_uid_unique$status, ": ", checks$trial_uid_unique$message, "\n")
} else {
  checks$trial_uid_unique <- list(
    check_name = "trial_uid_unique",
    status = "STOP",
    value = NA_integer_,
    threshold = 0L,
    message = "ch3_triallevel.csv not found"
  )
}

# Compile results
check_results <- bind_rows(lapply(checks, function(x) {
  tibble(
    check_name = x$check_name,
    status = x$status,
    value = x$value,
    threshold = x$threshold,
    message = x$message
  )
}))

# Overall status
n_go <- sum(check_results$status == "GO", na.rm = TRUE)
n_warn <- sum(check_results$status == "WARN", na.rm = TRUE)
n_stop <- sum(check_results$status == "STOP", na.rm = TRUE)
n_total <- nrow(check_results)

overall_status <- if (n_stop > 0) "STOP" else if (n_warn > 0) "GO_WARNINGS" else "GO"

cat("\n=== Overall Status ===\n")
cat("Status:", overall_status, "\n")
cat("Passed:", n_go, "/", n_total, "checks\n")
cat("Warnings:", n_warn, "\n")
cat("Failed:", n_stop, "\n")

if (n_stop > 0) {
  failed_checks <- check_results %>% filter(status == "STOP")
  cat("\nFailed checks:\n")
  for (i in 1:nrow(failed_checks)) {
    cat("  - ", failed_checks$check_name[i], ": ", failed_checks$message[i], "\n", sep = "")
  }
}

# Save results
write_csv(check_results, file.path(QC_DIR, "STOP_GO_ch3_v3.csv"))
cat("\n✓ Saved: qc/ch3_extension_v3/STOP_GO_ch3_v3.csv\n")

cat("\n=== Analysis Complete ===\n")

