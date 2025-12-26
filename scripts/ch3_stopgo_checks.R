#!/usr/bin/env Rscript
# ============================================================================
# CH3 Extension STOP/GO Checks
# ============================================================================
# Validates that trial extension to Resp1ET worked correctly
# ============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(readr)
})

REPO_ROOT <- normalizePath(".")
QUICK_SHARE_DIR <- file.path(REPO_ROOT, "quick_share_v7")
QC_DIR <- file.path(QUICK_SHARE_DIR, "qc")
WAVEFORM_FILE <- file.path(QUICK_SHARE_DIR, "analysis", "pupil_waveforms_condition_mean.csv")
PEAK_SUMMARY_FILE <- file.path(QC_DIR, "ch3_time_to_peak_summary.csv")
WINDOW_COVERAGE_FILE <- file.path(QC_DIR, "ch3_window_coverage.csv")
TIMING_SUMMARY_FILE <- file.path(QC_DIR, "timing_sanity_summary.csv")

dir.create(QC_DIR, recursive = TRUE, showWarnings = FALSE)

cat("=== CH3 Extension STOP/GO Checks ===\n\n")

EXPECTED_TARGET_ONSET <- 4.35
EXPECTED_RESP_END <- 7.70
MIN_WAVEFORM_TIME <- 7.65
MIN_COVERAGE_W2_0 <- 70  # Minimum % coverage for W2.0

# Initialize results
stop_go_checks <- data.frame(
  check_name = character(),
  status = character(),
  passed = logical(),
  message = character(),
  stringsAsFactors = FALSE
)

# Check 1: Waveform data extension
cat("Check 1: Waveform data extension\n")
if (file.exists(WAVEFORM_FILE)) {
  waveform_data <- fread(WAVEFORM_FILE)
  waveform_ch3 <- waveform_data %>% filter(chapter == "ch3")
  max_time_rel <- max(waveform_ch3$t_rel, na.rm = TRUE)
  
  passed <- max_time_rel >= MIN_WAVEFORM_TIME
  status <- ifelse(passed, "GO", "STOP")
  message <- sprintf("Waveform extends to %.2fs from squeeze (required: >=%.2fs)", 
                     max_time_rel, MIN_WAVEFORM_TIME)
  
  stop_go_checks <- rbind(stop_go_checks, data.frame(
    check_name = "waveform_extension",
    status = status,
    passed = passed,
    message = message,
    stringsAsFactors = FALSE
  ))
  cat("  ", status, ": ", message, "\n")
  
  # Check by task
  for (t in unique(waveform_ch3$task)) {
    wf_task <- waveform_ch3 %>% filter(task == t)
    max_time_task <- max(wf_task$t_rel, na.rm = TRUE)
    passed_task <- max_time_task >= MIN_WAVEFORM_TIME
    cat("    Task ", t, ": ", sprintf("%.2fs", max_time_task), 
        ifelse(passed_task, " ✓", " ✗"), "\n", sep = "")
    
    if (!passed_task) {
      stop_go_checks <- rbind(stop_go_checks, data.frame(
        check_name = paste0("waveform_extension_", t),
        status = "STOP",
        passed = FALSE,
        message = sprintf("Task %s extends only to %.2fs", t, max_time_task),
        stringsAsFactors = FALSE
      ))
    }
  }
} else {
  stop_go_checks <- rbind(stop_go_checks, data.frame(
    check_name = "waveform_extension",
    status = "STOP",
    passed = FALSE,
    message = "Waveform file not found",
    stringsAsFactors = FALSE
  ))
  cat("  STOP: Waveform file not found\n")
}

# Check 2: Time-to-peak summary exists and is non-empty
cat("\nCheck 2: Time-to-peak summary\n")
if (file.exists(PEAK_SUMMARY_FILE)) {
  peak_summary <- fread(PEAK_SUMMARY_FILE)
  passed <- nrow(peak_summary) > 0
  status <- ifelse(passed, "GO", "STOP")
  message <- ifelse(passed, 
                    sprintf("Time-to-peak summary has %d entries", nrow(peak_summary)),
                    "Time-to-peak summary is empty")
  
  stop_go_checks <- rbind(stop_go_checks, data.frame(
    check_name = "time_to_peak_summary",
    status = status,
    passed = passed,
    message = message,
    stringsAsFactors = FALSE
  ))
  cat("  ", status, ": ", message, "\n")
} else {
  stop_go_checks <- rbind(stop_go_checks, data.frame(
    check_name = "time_to_peak_summary",
    status = "STOP",
    passed = FALSE,
    message = "Time-to-peak summary file not found",
    stringsAsFactors = FALSE
  ))
  cat("  STOP: Time-to-peak summary file not found\n")
}

# Check 3: Window coverage
cat("\nCheck 3: Window coverage\n")
if (file.exists(WINDOW_COVERAGE_FILE)) {
  window_coverage <- fread(WINDOW_COVERAGE_FILE)
  # Check W2.0 coverage (simplified check - would need trial-level validation for exact %)
  w2_0_coverage <- window_coverage %>% filter(window == "W2.0")
  passed <- nrow(w2_0_coverage) > 0 && all(w2_0_coverage$has_coverage, na.rm = TRUE)
  
  # Note: This is a simplified check. Full coverage % would require trial-level validation
  status <- ifelse(passed, "GO", "STOP")
  message <- ifelse(passed,
                    "W2.0 window has data coverage (exact % requires trial-level validation)",
                    "W2.0 window lacks data coverage")
  
  stop_go_checks <- rbind(stop_go_checks, data.frame(
    check_name = "window_coverage_w2_0",
    status = status,
    passed = passed,
    message = message,
    stringsAsFactors = FALSE
  ))
  cat("  ", status, ": ", message, "\n")
  
  # Report all windows
  for (w in unique(window_coverage$window)) {
    w_data <- window_coverage %>% filter(window == w)
    cat("    ", w, ": ", ifelse(all(w_data$has_coverage, na.rm = TRUE), "✓", "✗"), "\n", sep = "")
  }
} else {
  stop_go_checks <- rbind(stop_go_checks, data.frame(
    check_name = "window_coverage_w2_0",
    status = "STOP",
    passed = FALSE,
    message = "Window coverage file not found",
    stringsAsFactors = FALSE
  ))
  cat("  STOP: Window coverage file not found\n")
}

# Check 4: Timing sanity (target onset near expected 4.35s, resp end near 7.70s)
cat("\nCheck 4: Timing sanity\n")
if (file.exists(TIMING_SUMMARY_FILE)) {
  timing_summary <- fread(TIMING_SUMMARY_FILE)
  target_onset_ok <- all(abs(timing_summary$target_onset_median - EXPECTED_TARGET_ONSET) < 0.05, na.rm = TRUE)
  
  # Check if we can infer resp_end from timing (would need additional column)
  # For now, just check target onset
  passed <- target_onset_ok
  status <- ifelse(passed, "GO", "STOP")
  message <- ifelse(passed,
                    sprintf("Target onset medians near expected %.2fs (all within 0.05s)", EXPECTED_TARGET_ONSET),
                    "Target onset medians deviate >0.05s from expected")
  
  stop_go_checks <- rbind(stop_go_checks, data.frame(
    check_name = "timing_sanity_target_onset",
    status = status,
    passed = passed,
    message = message,
    stringsAsFactors = FALSE
  ))
  cat("  ", status, ": ", message, "\n")
  
  for (i in 1:nrow(timing_summary)) {
    dev <- abs(timing_summary$target_onset_median[i] - EXPECTED_TARGET_ONSET)
    cat("    Task ", timing_summary$task[i], ": ", 
        sprintf("%.3fs (deviation: %.3fs)", timing_summary$target_onset_median[i], dev),
        ifelse(dev < 0.05, " ✓", " ✗"), "\n", sep = "")
  }
} else {
  stop_go_checks <- rbind(stop_go_checks, data.frame(
    check_name = "timing_sanity_target_onset",
    status = "STOP",
    passed = FALSE,
    message = "Timing summary file not found",
    stringsAsFactors = FALSE
  ))
  cat("  STOP: Timing summary file not found\n")
}

# Overall status
cat("\n=== Overall Status ===\n")
all_passed <- all(stop_go_checks$passed, na.rm = TRUE)
overall_status <- ifelse(all_passed, "GO", "STOP")
cat("Status: ", overall_status, "\n")
cat("Passed: ", sum(stop_go_checks$passed), "/", nrow(stop_go_checks), " checks\n\n")

if (!all_passed) {
  cat("Failed checks:\n")
  failed <- stop_go_checks %>% filter(!passed)
  for (i in 1:nrow(failed)) {
    cat("  - ", failed$check_name[i], ": ", failed$message[i], "\n", sep = "")
  }
}

# Save results
fwrite(stop_go_checks, file.path(QC_DIR, "STOP_GO_ch3_extension.csv"))
cat("\n✓ Saved STOP/GO checks to: ", file.path(QC_DIR, "STOP_GO_ch3_extension.csv"), "\n", sep = "")

# Exit with error code if STOP
if (!all_passed) {
  quit(status = 1)
}

