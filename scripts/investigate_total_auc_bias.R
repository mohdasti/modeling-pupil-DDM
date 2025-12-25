#!/usr/bin/env Rscript

# ============================================================================
# Investigate Total AUC Task Bias
# ============================================================================
# Investigates why pass_total_auc differs between ADT and VDT tasks
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(purrr)
})

# ============================================================================
# Configuration
# ============================================================================

BASE_DIR <- "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM"
TRIALLEVEL_FILE <- file.path(BASE_DIR, "data/analysis_ready/BAP_analysis_ready_TRIALLEVEL.csv")
OUTPUT_DIR <- file.path(BASE_DIR, "data/qc/bias")

dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

THRESHOLD_GRID <- c(0.60, 0.70, 0.75, 0.80, 0.85)

cat("=== INVESTIGATING TOTAL AUC TASK BIAS ===\n\n")

# ============================================================================
# Load Data
# ============================================================================

cat("Loading TRIALLEVEL data...\n")
trial_level <- read_csv(TRIALLEVEL_FILE, show_col_types = FALSE, progress = FALSE)
cat("Loaded", nrow(trial_level), "trials\n\n")

# ============================================================================
# TASK 1: Compute Validity Distributions by Task
# ============================================================================

cat("TASK 1: Computing validity distributions by task\n")
cat("------------------------------------------------\n")

# Identify validity columns
validity_cols <- list(
  valid_total_auc = c("valid_total_auc_window", "valid_prop_total_auc"),
  valid_cognitive = c("valid_cognitive_window", "valid_prop_cognitive_auc"),
  valid_baseline = c("valid_baseline500", "valid_prop_baseline_500ms")
)

# Find which columns actually exist
validity_actual <- list()
for (name in names(validity_cols)) {
  found <- intersect(validity_cols[[name]], names(trial_level))
  if (length(found) > 0) {
    validity_actual[[name]] <- found[1]
  }
}

cat("Found validity columns:\n")
for (name in names(validity_actual)) {
  cat("  -", name, ":", validity_actual[[name]], "\n")
}

# Check for sample count columns
sample_count_cols <- names(trial_level)[grepl("sample|n_samples|count", names(trial_level), ignore.case = TRUE)]
cat("\nSample count columns found:", length(sample_count_cols), "\n")
if (length(sample_count_cols) > 0) {
  cat("  ", paste(head(sample_count_cols, 5), collapse = ", "), "\n")
}

# Compute distributions by task
validity_by_task <- trial_level %>%
  group_by(task) %>%
  summarise(
    # Total AUC validity
    across(any_of(validity_actual$valid_total_auc), 
           list(
             mean = ~ mean(.x, na.rm = TRUE),
             median = ~ median(.x, na.rm = TRUE),
             sd = ~ sd(.x, na.rm = TRUE),
             min = ~ min(.x, na.rm = TRUE),
             max = ~ max(.x, na.rm = TRUE),
             q25 = ~ quantile(.x, 0.25, na.rm = TRUE),
             q75 = ~ quantile(.x, 0.75, na.rm = TRUE),
             n_valid = ~ sum(!is.na(.x)),
             n_missing = ~ sum(is.na(.x))
           ),
           .names = "total_auc_{.fn}"),
    
    # Cognitive validity
    across(any_of(validity_actual$valid_cognitive), 
           list(
             mean = ~ mean(.x, na.rm = TRUE),
             median = ~ median(.x, na.rm = TRUE),
             sd = ~ sd(.x, na.rm = TRUE),
             n_valid = ~ sum(!is.na(.x))
           ),
           .names = "cognitive_{.fn}"),
    
    # Baseline validity
    across(any_of(validity_actual$valid_baseline), 
           list(
             mean = ~ mean(.x, na.rm = TRUE),
             median = ~ median(.x, na.rm = TRUE),
             sd = ~ sd(.x, na.rm = TRUE),
             n_valid = ~ sum(!is.na(.x))
           ),
           .names = "baseline_{.fn}"),
    
    # Sample counts
    across(any_of(sample_count_cols),
           list(
             mean = ~ mean(.x, na.rm = TRUE),
             median = ~ median(.x, na.rm = TRUE),
             sd = ~ sd(.x, na.rm = TRUE)
           ),
           .names = "samples_{.fn}"),
    
    n_trials = n(),
    .groups = "drop"
  )

cat("\nValidity distributions by task:\n")
print(validity_by_task)
cat("\n")

# Save
write_csv(validity_by_task, file.path(OUTPUT_DIR, "total_auc_validity_by_task.csv"))
cat("✓ Saved total_auc_validity_by_task.csv\n\n")

# ============================================================================
# TASK 2: Compute Pass Rates by Task and Threshold
# ============================================================================

cat("TASK 2: Computing pass rates by task and threshold\n")
cat("---------------------------------------------------\n")

# Get validity column for total AUC
valid_total_auc_col <- validity_actual$valid_total_auc

if (is.null(valid_total_auc_col)) {
  stop("Could not find valid_total_auc column")
}

pass_rate_results <- list()

for (thr in THRESHOLD_GRID) {
  # Compute pass rate at this threshold
  trial_level$pass_at_thr <- trial_level[[valid_total_auc_col]] >= thr
  
  pass_by_task <- trial_level %>%
    group_by(task) %>%
    summarise(
      n_total = sum(!is.na(pass_at_thr)),
      n_pass = sum(pass_at_thr, na.rm = TRUE),
      pass_rate = mean(pass_at_thr, na.rm = TRUE),
      .groups = "drop"
    )
  
  # Compute difference
  if (nrow(pass_by_task) > 1) {
    max_pass <- max(pass_by_task$pass_rate, na.rm = TRUE)
    min_pass <- min(pass_by_task$pass_rate, na.rm = TRUE)
    diff_pct <- 100 * (max_pass - min_pass)
    
    pass_rate_results[[length(pass_rate_results) + 1]] <- tibble(
      threshold = thr,
      task = pass_by_task$task,
      n_total = pass_by_task$n_total,
      n_pass = pass_by_task$n_pass,
      pass_rate = pass_by_task$pass_rate,
      pass_rate_pct = 100 * pass_by_task$pass_rate
    ) %>%
      bind_rows(
        tibble(
          threshold = thr,
          task = "DIFFERENCE",
          n_total = NA_integer_,
          n_pass = NA_integer_,
          pass_rate = diff_pct / 100,
          pass_rate_pct = diff_pct
        )
      )
  }
}

pass_rate_table <- bind_rows(pass_rate_results)

cat("\nPass rates by task and threshold:\n")
print(pass_rate_table)
cat("\n")

# Save
write_csv(pass_rate_table, file.path(OUTPUT_DIR, "pass_rate_by_task_threshold.csv"))
cat("✓ Saved pass_rate_by_task_threshold.csv\n\n")

# ============================================================================
# TASK 3: Check Window Construction
# ============================================================================

cat("TASK 3: Checking window construction\n")
cat("------------------------------------\n")

# Check for window timing columns
window_cols <- names(trial_level)[grepl("window|time|duration|length|start|end|onset", names(trial_level), ignore.case = TRUE)]
cat("Window/timing columns found:", length(window_cols), "\n")
if (length(window_cols) > 0) {
  cat("  ", paste(head(window_cols, 10), collapse = ", "), "\n\n")
}

# Check for response_onset (should define end of total_auc window)
if ("response_onset" %in% names(trial_level)) {
  cat("Found response_onset column\n")
  
  window_length_by_task <- trial_level %>%
    filter(!is.na(response_onset)) %>%
    group_by(task) %>%
    summarise(
      mean_response_onset = mean(response_onset, na.rm = TRUE),
      median_response_onset = median(response_onset, na.rm = TRUE),
      sd_response_onset = sd(response_onset, na.rm = TRUE),
      min_response_onset = min(response_onset, na.rm = TRUE),
      max_response_onset = max(response_onset, na.rm = TRUE),
      n_trials = n(),
      .groups = "drop"
    )
  
  cat("\nResponse onset (window end) by task:\n")
  print(window_length_by_task)
  cat("\n")
  
  # If we have sample counts, estimate window length in samples
  if ("n_samples" %in% names(trial_level)) {
    # Assuming 250 Hz sampling rate (from documentation)
    sampling_rate <- 250  # Hz
    
    window_length_by_task <- window_length_by_task %>%
      mutate(
        # Estimate samples in window (response_onset * sampling_rate)
        mean_samples_in_window = mean_response_onset * sampling_rate,
        median_samples_in_window = median_response_onset * sampling_rate
      )
    
    # Also check actual sample counts
    sample_stats_by_task <- trial_level %>%
      filter(!is.na(n_samples)) %>%
      group_by(task) %>%
      summarise(
        mean_n_samples = mean(n_samples, na.rm = TRUE),
        median_n_samples = median(n_samples, na.rm = TRUE),
        sd_n_samples = sd(n_samples, na.rm = TRUE),
        .groups = "drop"
      )
    
    cat("Sample counts by task:\n")
    print(sample_stats_by_task)
    cat("\n")
    
    window_length_by_task <- window_length_by_task %>%
      left_join(sample_stats_by_task, by = "task")
  }
  
  write_csv(window_length_by_task, file.path(OUTPUT_DIR, "window_length_by_task.csv"))
  cat("✓ Saved window_length_by_task.csv\n\n")
} else {
  cat("⚠ response_onset column not found - cannot compute window lengths\n\n")
  
  # Create placeholder
  window_length_by_task <- trial_level %>%
    group_by(task) %>%
    summarise(
      note = "response_onset not available",
      n_trials = n(),
      .groups = "drop"
    )
  
  write_csv(window_length_by_task, file.path(OUTPUT_DIR, "window_length_by_task.csv"))
}

# Check for task-specific events that might affect window
cat("Checking for task-specific columns that might affect windows...\n")
task_specific_cols <- names(trial_level)[grepl("task|adt|vdt|auditory|visual", names(trial_level), ignore.case = TRUE)]
cat("Task-related columns:", length(task_specific_cols), "\n")
if (length(task_specific_cols) > 0 && length(task_specific_cols) <= 20) {
  cat("  ", paste(task_specific_cols, collapse = ", "), "\n")
}

# Check if validity differs by task even at very lenient thresholds
cat("\nChecking validity at lenient thresholds...\n")
for (thr in c(0.50, 0.60)) {
  pass_at_thr <- trial_level[[valid_total_auc_col]] >= thr
  pass_by_task_lenient <- trial_level %>%
    mutate(pass = pass_at_thr) %>%
    group_by(task) %>%
    summarise(
      pass_rate = mean(pass, na.rm = TRUE),
      n_pass = sum(pass, na.rm = TRUE),
      n_total = sum(!is.na(pass)),
      .groups = "drop"
    )
  
  if (nrow(pass_by_task_lenient) > 1) {
    diff_pct <- 100 * (max(pass_by_task_lenient$pass_rate) - min(pass_by_task_lenient$pass_rate))
    cat(sprintf("  Threshold %.2f: pass rate difference = %.1f percentage points\n", thr, diff_pct))
    print(pass_by_task_lenient)
    cat("\n")
  }
}

# ============================================================================
# Summary
# ============================================================================

cat("\n=== SUMMARY ===\n\n")

# Extract key differences
if (nrow(validity_by_task) > 1) {
  total_auc_mean_diff <- abs(validity_by_task$total_auc_mean[1] - validity_by_task$total_auc_mean[2])
  cat("Total AUC validity mean difference:", round(total_auc_mean_diff, 3), "\n")
  
  total_auc_median_diff <- abs(validity_by_task$total_auc_median[1] - validity_by_task$total_auc_median[2])
  cat("Total AUC validity median difference:", round(total_auc_median_diff, 3), "\n")
}

# Check pass rate difference at 0.80
pass_at_080 <- pass_rate_table %>%
  filter(threshold == 0.80, task != "DIFFERENCE")
if (nrow(pass_at_080) > 1) {
  diff_080 <- max(pass_at_080$pass_rate_pct) - min(pass_at_080$pass_rate_pct)
  cat("Pass rate difference at 0.80 threshold:", round(diff_080, 1), "percentage points\n")
}

cat("\n✓ Investigation complete!\n")
cat("Output files saved to:", OUTPUT_DIR, "\n")

