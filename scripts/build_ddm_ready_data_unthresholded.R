#!/usr/bin/env Rscript

# =========================================================================
# BUILD UNTHRESHOLDED DDM-READY DATA FROM RAW TRIAL FILE
# =========================================================================
# This script creates ddm_ready_data_unthresholded.csv from 
# bap_beh_trialdata_v3.csv WITHOUT applying RT lower-bound thresholds
# (except optionally removing RT <= 0).
#
# RT Definitions:
#   - cue-locked RT = same_diff_resp_secs (measured from response prompt onset)
#   - probe-offset-locked RT = cue_locked + 0.25s (GripRelaxTime)
#   - probe-onset-locked RT = cue_locked + 0.25s + 0.10s (probe duration)
# =========================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

# =========================================================================
# CONFIGURATION
# =========================================================================

# Input path: allow override via env var, default to project convention
# Also check common absolute path locations
default_paths <- c(
  "data/bap_beh_trialdata_v3.csv",
  "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v3.csv"
)
RAW_DATA_PATH <- Sys.getenv("BAP_BEH_TRIALDATA_PATH", unset = "")
if (RAW_DATA_PATH == "") {
  # Try to find existing file
  for (path in default_paths) {
    if (file.exists(path)) {
      RAW_DATA_PATH <- path
      break
    }
  }
  if (RAW_DATA_PATH == "") {
    RAW_DATA_PATH <- default_paths[1]  # Use relative path as final default
  }
}

# Output paths
OUTPUT_DIR <- "output/rt_threshold_analysis"
LOG_DIR <- file.path(OUTPUT_DIR, "logs")
DATA_DIR <- "data"

# Create directories
dirs_to_create <- c(OUTPUT_DIR, LOG_DIR, DATA_DIR)
for (dir in dirs_to_create) {
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
}

# Output files
OUTPUT_UNTHRESHOLDED <- file.path(DATA_DIR, "ddm_ready_data_unthresholded.csv")
OUTPUT_THRESHOLDED <- file.path(DATA_DIR, "ddm_ready_data.csv")  # Only if flag set
AUDIT_FILE <- file.path(OUTPUT_DIR, "data_audit_unthresholded.csv")
COMPARE_FILE <- file.path(OUTPUT_DIR, "data_audit_compare_old_vs_new.csv")

# Configuration flags
DROP_NONPOS_RT <- as.logical(as.integer(Sys.getenv("DDM_DROP_NONPOS_RT", unset = "1")))
WRITE_THRESHOLDED <- as.logical(as.integer(Sys.getenv("DDM_WRITE_THRESHOLDED", unset = "0")))

# Timing constants (from task design)
GRIP_RELAX_TIME <- 0.250  # seconds (delay between probe offset and response prompt)
PROBE_DURATION <- 0.100   # seconds (probe duration, same for both modalities)

# Log file
TIMESTAMP <- format(Sys.time(), "%Y%m%d_%H%M%S")
LOG_FILE <- file.path(LOG_DIR, paste0("build_ddm_ready_unthresholded_", TIMESTAMP, ".log"))

# Start logging
log_con <- file(LOG_FILE, open = "wt")
sink(log_con, type = "output", split = TRUE)

cat("================================================================================\n")
cat("BUILD UNTHRESHOLDED DDM-READY DATA\n")
cat("================================================================================\n")
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Input file:", RAW_DATA_PATH, "\n")
cat("Output file (unthresholded):", OUTPUT_UNTHRESHOLDED, "\n")
cat("Drop RT <= 0:", DROP_NONPOS_RT, "\n")
cat("Write thresholded version:", WRITE_THRESHOLDED, "\n")
cat("Log file:", LOG_FILE, "\n")
cat("================================================================================\n\n")

# =========================================================================
# STEP 1: LOAD RAW DATA
# =========================================================================

cat("STEP 1: Loading raw data...\n")

if (!file.exists(RAW_DATA_PATH)) {
  stop("ERROR: Raw data file not found: ", RAW_DATA_PATH)
}

raw_data <- read_csv(RAW_DATA_PATH, show_col_types = FALSE)

cat("  Total rows loaded:", nrow(raw_data), "\n")
cat("  Unique subjects:", length(unique(raw_data$subject_id)), "\n")
cat("  Columns:", ncol(raw_data), "\n")
cat("  Column names:", paste(names(raw_data), collapse = ", "), "\n\n")

# =========================================================================
# STEP 2: INITIAL DATA INSPECTION
# =========================================================================

cat("STEP 2: Initial data inspection...\n")

# Check required columns
required_cols <- c("subject_id", "task_modality", "same_diff_resp_secs", 
                   "resp_is_diff", "resp_is_correct", "grip_targ_prop_mvc",
                   "stim_offset", "stim_is_diff")
missing_cols <- setdiff(required_cols, names(raw_data))
if (length(missing_cols) > 0) {
  stop("ERROR: Missing required columns: ", paste(missing_cols, collapse = ", "))
}

# Initial counts
n_total <- nrow(raw_data)
n_missing_rt <- sum(is.na(raw_data$same_diff_resp_secs))
n_missing_resp <- sum(is.na(raw_data$resp_is_diff))
n_missing_acc <- sum(is.na(raw_data$resp_is_correct))

cat("  Total trials:", n_total, "\n")
cat("  Missing RT:", n_missing_rt, "\n")
cat("  Missing response:", n_missing_resp, "\n")
cat("  Missing accuracy:", n_missing_acc, "\n\n")

# =========================================================================
# STEP 3: CREATE DDM-READY DATASET
# =========================================================================

cat("STEP 3: Creating DDM-ready dataset...\n")

# Start with all valid rows (non-missing RT and response)
ddm_data <- raw_data %>%
  filter(
    !is.na(same_diff_resp_secs),
    !is.na(resp_is_diff),
    !is.na(resp_is_correct)
  )

cat("  After removing missing RT/response:", nrow(ddm_data), "trials\n")

# Apply minimal filtering: RT <= 0 (if flag set)
if (DROP_NONPOS_RT) {
  n_before_drop <- nrow(ddm_data)
  ddm_data <- ddm_data %>% filter(same_diff_resp_secs > 0)
  n_dropped_nonpos <- n_before_drop - nrow(ddm_data)
  cat("  Dropped RT <= 0:", n_dropped_nonpos, "trials\n")
} else {
  n_dropped_nonpos <- 0
  cat("  Keeping all RT values (including <= 0)\n")
}

# Create derived variables
ddm_data <- ddm_data %>%
  mutate(
    # Subject ID (ensure consistent format)
    subject_id = as.character(subject_id),
    
    # Task: keep original modality codes (aud/vis) to match existing convention
    task = task_modality,
    
    # Trial number (use trial_num if available, otherwise create sequential)
    trial_num = if ("trial_num" %in% names(.)) trial_num else row_number(),
    
    # Run number (if available)
    run = if ("run_num" %in% names(.)) run_num else NA_integer_,
    
    # Stimulus variables
    stim_offset = stim_offset,
    stim_level_index = if ("stim_level_index" %in% names(.)) stim_level_index else NA_integer_,
    is_standard = (stim_offset == 0),
    stim_is_diff = stim_is_diff,
    
    # Response variables
    resp_is_diff = resp_is_diff,
    choice_binary = as.integer(resp_is_diff),  # 1 = "different", 0 = "same"
    accuracy = as.integer(resp_is_correct),
    
    # Effort condition: map grip_targ_prop_mvc
    effort_condition = case_when(
      abs(grip_targ_prop_mvc - 0.05) < 0.001 ~ "Low",
      abs(grip_targ_prop_mvc - 0.40) < 0.001 ~ "High",
      TRUE ~ NA_character_
    ),
    effort_condition = factor(effort_condition, levels = c("Low", "High")),
    
    # Difficulty level: create deterministic mapping from stim_level_index
    # If stim_level_index exists, use it; otherwise use stim_offset
    difficulty_level = case_when(
      !is.na(stim_level_index) ~ case_when(
        stim_level_index == 0 ~ "Standard",
        stim_level_index %in% c(1, 2) ~ "Hard",
        stim_level_index %in% c(3, 4) ~ "Easy",
        TRUE ~ "Unknown"
      ),
      !is.na(stim_offset) ~ case_when(
        stim_offset == 0 ~ "Standard",
        stim_offset %in% c(0.06, 0.12, 16.0) ~ "Hard",
        stim_offset %in% c(0.24, 0.48, 32.0, 64.0) ~ "Easy",
        TRUE ~ "Unknown"
      ),
      TRUE ~ "Unknown"
    ),
    difficulty_level = factor(difficulty_level, 
                              levels = c("Standard", "Hard", "Easy", "Unknown")),
    
    # RT definitions
    rt = same_diff_resp_secs,  # cue-locked RT (primary)
    rt_cue_locked = same_diff_resp_secs,
    rt_probe_offset_locked = rt_cue_locked + GRIP_RELAX_TIME,
    rt_probe_onset_locked = rt_probe_offset_locked + PROBE_DURATION,
    rt_is_negative = (rt < 0)
  )

# Log unexpected values
unexpected_grip <- ddm_data %>%
  filter(is.na(effort_condition)) %>%
  distinct(grip_targ_prop_mvc) %>%
  pull(grip_targ_prop_mvc)

if (length(unexpected_grip) > 0) {
  cat("  WARNING: Unexpected grip_targ_prop_mvc values:", 
      paste(unexpected_grip, collapse = ", "), "\n")
}

unexpected_difficulty <- ddm_data %>%
  filter(difficulty_level == "Unknown") %>%
  nrow()

if (unexpected_difficulty > 0) {
  cat("  WARNING:", unexpected_difficulty, "trials with unknown difficulty_level\n")
}

# Select final columns (match expected output format)
ddm_final <- ddm_data %>%
  select(
    subject_id,
    trial_num,
    task,
    effort_condition,
    difficulty_level,
    is_standard,
    stim_is_diff,
    resp_is_diff,
    choice_binary,
    rt_cue_locked,
    rt_probe_offset_locked,
    rt_probe_onset_locked,
    rt = rt_cue_locked,  # Primary RT column (cue-locked)
    rt_is_negative
  )

cat("  Final dataset:", nrow(ddm_final), "trials\n")
cat("  Final columns:", ncol(ddm_final), "\n\n")

# =========================================================================
# STEP 4: COMPREHENSIVE LOGGING
# =========================================================================

cat("STEP 4: Generating comprehensive logs...\n")

# Summary statistics
summary_stats <- list(
  timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  input_file = RAW_DATA_PATH,
  output_file = OUTPUT_UNTHRESHOLDED,
  n_total_raw = n_total,
  n_missing_rt = n_missing_rt,
  n_missing_resp = n_missing_resp,
  n_missing_acc = n_missing_acc,
  n_after_missing_filter = nrow(ddm_data) + n_dropped_nonpos,
  n_dropped_nonpos_rt = n_dropped_nonpos,
  n_final = nrow(ddm_final),
  n_subjects = length(unique(ddm_final$subject_id)),
  drop_nonpos_rt = DROP_NONPOS_RT
)

# Subject count
summary_stats$n_subjects <- length(unique(ddm_final$subject_id))

# Task breakdown
task_counts <- ddm_final %>%
  count(task, name = "n_trials")
summary_stats$n_auditory <- if ("aud" %in% task_counts$task) {
  task_counts$n_trials[task_counts$task == "aud"]
} else 0
summary_stats$n_visual <- if ("vis" %in% task_counts$task) {
  task_counts$n_trials[task_counts$task == "vis"]
} else 0

# Effort breakdown
effort_counts <- ddm_final %>%
  count(effort_condition, name = "n_trials")
summary_stats$n_low_effort <- effort_counts$n_trials[effort_counts$effort_condition == "Low"]
summary_stats$n_high_effort <- effort_counts$n_trials[effort_counts$effort_condition == "High"]

# RT quantiles
rt_quantiles <- quantile(ddm_final$rt, 
                        probs = c(0, 0.001, 0.01, 0.05, 0.10, 0.50, 0.90, 0.95, 0.99, 1),
                        na.rm = TRUE)
summary_stats$rt_min <- rt_quantiles["0%"]
summary_stats$rt_p001 <- rt_quantiles["0.1%"]
summary_stats$rt_p01 <- rt_quantiles["1%"]
summary_stats$rt_p05 <- rt_quantiles["5%"]
summary_stats$rt_p10 <- rt_quantiles["10%"]
summary_stats$rt_median <- rt_quantiles["50%"]
summary_stats$rt_p90 <- rt_quantiles["90%"]
summary_stats$rt_p95 <- rt_quantiles["95%"]
summary_stats$rt_p99 <- rt_quantiles["99%"]
summary_stats$rt_max <- rt_quantiles["100%"]

# RT threshold counts
summary_stats$n_rt_le_0 <- sum(ddm_final$rt <= 0, na.rm = TRUE)
summary_stats$n_rt_lt_005 <- sum(ddm_final$rt < 0.05, na.rm = TRUE)
summary_stats$n_rt_lt_010 <- sum(ddm_final$rt < 0.10, na.rm = TRUE)
summary_stats$n_rt_lt_015 <- sum(ddm_final$rt < 0.15, na.rm = TRUE)
summary_stats$n_rt_lt_020 <- sum(ddm_final$rt < 0.20, na.rm = TRUE)

# Standard trial counts
summary_stats$n_standard_trials <- sum(ddm_final$is_standard, na.rm = TRUE)
summary_stats$n_nonstandard_trials <- sum(!ddm_final$is_standard, na.rm = TRUE)

# Print summary
cat("\n  SUMMARY STATISTICS:\n")
cat("  --------------------\n")
cat("  Total trials:", summary_stats$n_final, "\n")
cat("  Unique subjects:", summary_stats$n_subjects, "\n")
cat("  Auditory (aud) trials:", summary_stats$n_auditory, "\n")
cat("  Visual (vis) trials:", summary_stats$n_visual, "\n")
cat("  Low effort:", summary_stats$n_low_effort, "\n")
cat("  High effort:", summary_stats$n_high_effort, "\n")
cat("  Standard trials:", summary_stats$n_standard_trials, "\n")
cat("  Non-standard trials:", summary_stats$n_nonstandard_trials, "\n")
cat("\n  RT QUANTILES (seconds):\n")
cat("    Min:", round(summary_stats$rt_min, 4), "\n")
cat("    0.1%:", round(summary_stats$rt_p001, 4), "\n")
cat("    1%:", round(summary_stats$rt_p01, 4), "\n")
cat("    5%:", round(summary_stats$rt_p05, 4), "\n")
cat("    10%:", round(summary_stats$rt_p10, 4), "\n")
cat("    Median:", round(summary_stats$rt_median, 4), "\n")
cat("    90%:", round(summary_stats$rt_p90, 4), "\n")
cat("    95%:", round(summary_stats$rt_p95, 4), "\n")
cat("    99%:", round(summary_stats$rt_p99, 4), "\n")
cat("    Max:", round(summary_stats$rt_max, 4), "\n")
cat("\n  RT THRESHOLD COUNTS:\n")
cat("    RT <= 0:", summary_stats$n_rt_le_0, "\n")
cat("    RT < 0.05s:", summary_stats$n_rt_lt_005, "\n")
cat("    RT < 0.10s:", summary_stats$n_rt_lt_010, "\n")
cat("    RT < 0.15s:", summary_stats$n_rt_lt_015, "\n")
cat("    RT < 0.20s:", summary_stats$n_rt_lt_020, "\n\n")

# =========================================================================
# STEP 5: ACCEPTANCE CHECKS
# =========================================================================

cat("STEP 5: Running acceptance checks...\n")

# Check 1: Must contain RT values below 0.15 seconds
if (summary_stats$n_rt_lt_015 == 0) {
  cat("  WARNING: No RT values below 0.15 seconds found!\n")
  cat("  This may indicate the raw data was already thresholded.\n")
} else {
  cat("  ✓ PASS: Found", summary_stats$n_rt_lt_015, "trials with RT < 0.15s\n")
}

# Check 2: rt_probe_onset_locked - rt must equal 0.35 (within tolerance)
rt_diff_check <- abs(ddm_final$rt_probe_onset_locked - ddm_final$rt - 0.35) < 0.001
if (all(rt_diff_check, na.rm = TRUE)) {
  cat("  ✓ PASS: rt_probe_onset_locked - rt = 0.35 for all rows\n")
} else {
  n_fail <- sum(!rt_diff_check, na.rm = TRUE)
  cat("  ✗ FAIL:", n_fail, "rows have rt_probe_onset_locked - rt != 0.35\n")
  cat("  First few failures:\n")
  failures <- ddm_final[!rt_diff_check, ][1:min(5, n_fail), ]
  print(failures[, c("subject_id", "trial_num", "rt", "rt_probe_onset_locked")])
}

# Check 3: choice_binary must match resp_is_diff exactly
choice_check <- (ddm_final$choice_binary == as.integer(ddm_final$resp_is_diff))
if (all(choice_check, na.rm = TRUE)) {
  cat("  ✓ PASS: choice_binary matches resp_is_diff exactly\n")
} else {
  n_fail <- sum(!choice_check, na.rm = TRUE)
  cat("  ✗ FAIL:", n_fail, "rows have choice_binary != resp_is_diff\n")
  cat("  Cross-tabulation:\n")
  print(table(ddm_final$choice_binary, ddm_final$resp_is_diff, useNA = "ifany"))
}

cat("\n")

# =========================================================================
# STEP 6: SAVE OUTPUT FILES
# =========================================================================

cat("STEP 6: Saving output files...\n")

# Save unthresholded dataset
write_csv(ddm_final, OUTPUT_UNTHRESHOLDED)
cat("  ✓ Saved:", OUTPUT_UNTHRESHOLDED, "\n")

# Save audit file
audit_df <- data.frame(
  metric = names(summary_stats),
  value = unlist(summary_stats),
  stringsAsFactors = FALSE
)
write_csv(audit_df, AUDIT_FILE)
cat("  ✓ Saved:", AUDIT_FILE, "\n")

# Save thresholded version if requested
if (WRITE_THRESHOLDED) {
  ddm_thresholded <- ddm_final %>% filter(rt >= 0.200)  # 200ms threshold
  write_csv(ddm_thresholded, OUTPUT_THRESHOLDED)
  cat("  ✓ Saved:", OUTPUT_THRESHOLDED, "\n")
  cat("    Thresholded trials:", nrow(ddm_thresholded), "\n")
}

# =========================================================================
# STEP 7: COMPARISON WITH OLD DATA (if exists)
# =========================================================================

OLD_DATA_PATH <- file.path(DATA_DIR, "ddm_ready_data.csv")
if (file.exists(OLD_DATA_PATH)) {
  cat("\nSTEP 7: Comparing with existing ddm_ready_data.csv...\n")
  
  old_data <- read_csv(OLD_DATA_PATH, show_col_types = FALSE)
  
  compare_stats <- data.frame(
    metric = c("n_trials", "n_subjects", "rt_min", "rt_p05", "rt_median", "rt_p95", "rt_max"),
    old_value = c(
      nrow(old_data),
      length(unique(old_data$subject_id)),
      min(old_data$rt, na.rm = TRUE),
      quantile(old_data$rt, 0.05, na.rm = TRUE),
      median(old_data$rt, na.rm = TRUE),
      quantile(old_data$rt, 0.95, na.rm = TRUE),
      max(old_data$rt, na.rm = TRUE)
    ),
    new_value = c(
      nrow(ddm_final),
      length(unique(ddm_final$subject_id)),
      min(ddm_final$rt, na.rm = TRUE),
      quantile(ddm_final$rt, 0.05, na.rm = TRUE),
      median(ddm_final$rt, na.rm = TRUE),
      quantile(ddm_final$rt, 0.95, na.rm = TRUE),
      max(ddm_final$rt, na.rm = TRUE)
    ),
    stringsAsFactors = FALSE
  )
  
  compare_stats$difference <- compare_stats$new_value - compare_stats$old_value
  
  write_csv(compare_stats, COMPARE_FILE)
  cat("  ✓ Saved comparison:", COMPARE_FILE, "\n")
  cat("\n  Comparison summary:\n")
  print(compare_stats)
}

# =========================================================================
# FINAL SUMMARY
# =========================================================================

cat("\n================================================================================\n")
cat("BUILD COMPLETE\n")
cat("================================================================================\n")
cat("Output file:", OUTPUT_UNTHRESHOLDED, "\n")
cat("Total trials:", nrow(ddm_final), "\n")
cat("RT range: [", round(min(ddm_final$rt, na.rm = TRUE), 4), ", ", 
    round(max(ddm_final$rt, na.rm = TRUE), 4), "] seconds\n")
cat("Trials with RT < 0.15s:", summary_stats$n_rt_lt_015, "\n")
cat("Log file:", LOG_FILE, "\n")
cat("================================================================================\n")

# Close log file
sink(type = "output")
close(log_con)

cat("\n✅ Script completed successfully!\n")
cat("   Log saved to:", LOG_FILE, "\n")
