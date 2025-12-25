# ============================================================================
# BAP Pupillometry Pipeline - Stage 2 (R) Rebuild
# ============================================================================
# This script rebuilds the R stage of the pupillometry pipeline to:
# 1) Use MATLAB flat files (*_flat.csv) as the ONLY pupil source
# 2) Merge pupil ↔ behavioral using robust trial keys
# 3) Add hard falsification checks
# 4) Export trial-level datasets and QC artifacts
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(arrow)  # For parquet export
})

# ============================================================================
# CONFIGURATION
# ============================================================================

# Paths - use environment variables or defaults
BAP_PROCESSED_DIR <- Sys.getenv("BAP_PROCESSED_DIR", 
  unset = "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed")
BEHAVIORAL_FILE <- Sys.getenv("BAP_BEHAVIORAL_FILE",
  unset = "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv")

# Output directories
OUTPUT_BASE <- "data"
INTERMEDIATE_DIR <- file.path(OUTPUT_BASE, "intermediate")
QC_DIR <- file.path(OUTPUT_BASE, "qc", "merge_audit")
ANALYSIS_READY_DIR <- file.path(OUTPUT_BASE, "analysis_ready")
QC_ANALYSIS_DIR <- file.path(OUTPUT_BASE, "qc", "analysis_ready_audit")

# Create directories
dir.create(INTERMEDIATE_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(QC_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(ANALYSIS_READY_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(QC_ANALYSIS_DIR, recursive = TRUE, showWarnings = FALSE)

cat("=== BAP PUPILLOMETRY PIPELINE - STAGE 2 (R) REBUILD ===\n\n")
cat("MATLAB processed dir:", BAP_PROCESSED_DIR, "\n")
cat("Behavioral file:", BEHAVIORAL_FILE, "\n")
cat("Output base:", OUTPUT_BASE, "\n\n")

# ============================================================================
# STEP A: DISCOVERY + SCHEMA NORMALIZATION
# ============================================================================

cat("STEP A: Discovery + Schema Normalization\n")
cat("----------------------------------------\n")

# Find all flat files
flat_files <- list.files(BAP_PROCESSED_DIR, pattern = ".*_(ADT|VDT)_flat\\.csv$", 
                         full.names = TRUE, recursive = TRUE)

if (length(flat_files) == 0) {
  stop("ERROR: No flat CSV files found in ", BAP_PROCESSED_DIR)
}

cat(sprintf("Found %d flat files\n", length(flat_files)))

# Inspect first file to understand schema
sample_file <- flat_files[1]
cat("Inspecting sample file:", basename(sample_file), "\n")
sample_data <- read_csv(sample_file, n_max = 100, show_col_types = FALSE)
cat("Columns in flat file:\n")
cat(paste(names(sample_data), collapse = ", "), "\n\n")

# Identify column mappings (flexible to handle variations)
identify_column <- function(df, candidates) {
  for (cand in candidates) {
    if (cand %in% names(df)) return(cand)
  }
  return(NA_character_)
}

# Map known column name variations (MATLAB pipeline uses specific names)
col_subject <- identify_column(sample_data, c("sub", "subject", "subject_id"))
col_task <- identify_column(sample_data, c("task", "task_modality", "task_name"))
col_session <- identify_column(sample_data, c("ses", "session", "session_num", "session_index"))
col_run <- identify_column(sample_data, c("run", "run_num", "run_index"))
col_trial_in_run <- identify_column(sample_data, c("trial_in_run_raw", "trial_in_run", "trial", "trial_num"))
col_time <- identify_column(sample_data, c("time", "trial_pupilTime", "timestamp"))
col_pupil <- identify_column(sample_data, c("pupil", "pupilSize", "pupil_diameter"))

cat("Column mappings:\n")
cat("  subject:", col_subject, "\n")
cat("  task:", col_task, "\n")
cat("  session:", col_session, "\n")
cat("  run:", col_run, "\n")
cat("  trial_in_run:", col_trial_in_run, "\n")
cat("  time:", col_time, "\n")
cat("  pupil:", col_pupil, "\n\n")

# Check for segmentation and window columns
has_segmentation <- "segmentation_source" %in% names(sample_data)
has_window_oob <- "window_oob" %in% names(sample_data)
cat("Has segmentation_source:", has_segmentation, "\n")
cat("Has window_oob:", has_window_oob, "\n\n")

# Load all flat files and normalize schema
cat("Loading and normalizing all flat files...\n")
pupil_raw <- map_dfr(flat_files, ~{
  cat("  Loading:", basename(.x), "\n")
  df <- read_csv(.x, show_col_types = FALSE)
  
  # Normalize column names - handle missing columns gracefully
  df_norm <- df
  
  # Map subject_id
  if (!is.na(col_subject) && col_subject %in% names(df)) {
    df_norm$subject_id <- as.character(df_norm[[col_subject]])
  } else {
    df_norm$subject_id <- NA_character_
  }
  
  # Map task
  if (!is.na(col_task) && col_task %in% names(df)) {
    df_norm$task <- as.character(df_norm[[col_task]])
  } else {
    df_norm$task <- NA_character_
  }
  
  # Map session
  if (!is.na(col_session) && col_session %in% names(df)) {
    df_norm$session <- as.integer(df_norm[[col_session]])
  } else {
    df_norm$session <- NA_integer_
  }
  
  # Map run
  if (!is.na(col_run) && col_run %in% names(df)) {
    df_norm$run <- as.integer(df_norm[[col_run]])
  } else {
    df_norm$run <- NA_integer_
  }
  
  # Map trial_in_run (prefer trial_in_run_raw)
  if (!is.na(col_trial_in_run) && col_trial_in_run %in% names(df)) {
    df_norm$trial_in_run <- as.integer(df_norm[[col_trial_in_run]])
  } else {
    df_norm$trial_in_run <- NA_integer_
  }
  
  # Map pupil
  if (!is.na(col_pupil) && col_pupil %in% names(df)) {
    df_norm$pupil <- as.numeric(df_norm[[col_pupil]])
  } else {
    df_norm$pupil <- NA_real_
  }
  
  # Map time
  if (!is.na(col_time) && col_time %in% names(df)) {
    df_norm$time <- as.numeric(df_norm[[col_time]])
  } else {
    df_norm$time <- NA_real_
  }
  
  # Preserve QC flags if present
  if (has_segmentation && "segmentation_source" %in% names(df)) {
    df_norm$segmentation_source <- as.character(df_norm$segmentation_source)
  } else {
    df_norm$segmentation_source <- NA_character_
  }
  
  if (has_window_oob && "window_oob" %in% names(df)) {
    df_norm$window_oob <- as.logical(df_norm$window_oob)
  } else {
    df_norm$window_oob <- NA
  }
  
  # Preserve window validity columns if present
  if ("baseline_valid" %in% names(df)) {
    df_norm$baseline_valid <- as.numeric(df_norm$baseline_valid)
  }
  if ("cog_valid" %in% names(df)) {
    df_norm$cog_valid <- as.numeric(df_norm$cog_valid)
  }
  if ("stimlocked_valid" %in% names(df)) {
    df_norm$stimlocked_valid <- as.numeric(df_norm$stimlocked_valid)
  }
  
  # Extract from filename (scalar values, evaluated once per file)
  filename_base <- basename(.x)
  subject_from_file <- str_extract(filename_base, "BAP\\d+")
  task_from_file <- if_else(str_detect(filename_base, "ADT"), "ADT",
                           if_else(str_detect(filename_base, "VDT"), "VDT", NA_character_))
  
  df_norm <- df_norm %>%
    # Extract subject ID from filename if missing
    mutate(
      subject_id = if_else(is.na(subject_id) | subject_id == "" | subject_id == "NA", 
        subject_from_file, subject_id)
    ) %>%
    # Extract task from filename if missing
    mutate(
      task = if_else(is.na(task) | task == "" | task == "NA",
        task_from_file, task)
    ) %>%
    # Select only normalized columns + any window validity columns
    select(any_of(c("subject_id", "task", "session", "run", "trial_in_run", 
                    "pupil", "time", "segmentation_source", "window_oob",
                    "baseline_valid", "cog_valid", "stimlocked_valid"))) %>%
    # Filter out rows with missing critical identifiers
    filter(!is.na(subject_id), !is.na(task), subject_id != "", task != "")
  
  return(df_norm)
})

cat(sprintf("Loaded %d rows from %d files\n", nrow(pupil_raw), length(flat_files)))

# Create trial_uid
pupil_raw <- pupil_raw %>%
  mutate(
    trial_uid = paste0(subject_id, ":", task, ":ses", session, ":run", run, ":t", trial_in_run)
  )

# Schema validation: Assert session ∈ {2,3}; run ∈ {1..5}; trial_in_run ∈ {1..30}
schema_violations <- pupil_raw %>%
  filter(
    !session %in% c(2, 3) | 
    !run %in% 1:5 | 
    !trial_in_run %in% 1:30 |
    is.na(subject_id) | is.na(task) | is.na(session) | is.na(run) | is.na(trial_in_run)
  ) %>%
  distinct(subject_id, task, session, run, trial_in_run, .keep_all = TRUE) %>%
  mutate(
    violation_type = case_when(
      !session %in% c(2, 3) ~ "invalid_session",
      !run %in% 1:5 ~ "invalid_run",
      !trial_in_run %in% 1:30 ~ "invalid_trial_in_run",
      is.na(subject_id) ~ "missing_subject_id",
      is.na(task) ~ "missing_task",
      is.na(session) ~ "missing_session",
      is.na(run) ~ "missing_run",
      is.na(trial_in_run) ~ "missing_trial_in_run",
      TRUE ~ "other"
    )
  )

if (nrow(schema_violations) > 0) {
  cat(sprintf("WARNING: Found %d schema violations\n", nrow(schema_violations)))
  write_csv(schema_violations, file.path(QC_DIR, "pupil_schema_violations.csv"))
  cat("  Written to:", file.path(QC_DIR, "pupil_schema_violations.csv"), "\n")
  
  # Filter out violations
  pupil_raw <- pupil_raw %>%
    filter(
      session %in% c(2, 3),
      run %in% 1:5,
      trial_in_run %in% 1:30,
      !is.na(subject_id), !is.na(task), !is.na(session), !is.na(run), !is.na(trial_in_run)
    )
  cat(sprintf("  Filtered to %d valid rows\n", nrow(pupil_raw)))
} else {
  cat("✓ All rows pass schema validation\n")
}

cat("\n")

# ============================================================================
# STEP B: BUILD TRIAL-LEVEL PUPIL SUMMARY
# ============================================================================

cat("STEP B: Build Trial-Level Pupil Summary\n")
cat("----------------------------------------\n")

# Helper function to compute window validity
window_validity <- function(time, pupil, start, end) {
  in_window <- !is.na(time) & time >= start & time <= end
  if (sum(in_window) == 0) return(NA_real_)
  mean(!is.na(pupil[in_window]), na.rm = TRUE)
}

# Aggregate sample-level data to trial level
pupil_trial <- pupil_raw %>%
  group_by(subject_id, task, session, run, trial_in_run, trial_uid) %>%
  summarise(
    n_samples = n(),
    # Compute window validity proportions from sample-level data
    # Baseline window: -0.5 to 0.0s (pre-event)
    baseline_valid = window_validity(time, pupil, -0.5, 0.0),
    # Cognitive window: 4.65s to end of trial (or max time if response_onset not available)
    # For now, use a fixed window 4.65 to 7.7s (typical trial end)
    cog_valid = window_validity(time, pupil, 4.65, 7.7),
    # Stimulus-locked validity: 0.0 to 4.65s (pre-target to target onset)
    stimlocked_valid = window_validity(time, pupil, 0.0, 4.65),
    # Pupil features
    baseline_mean = mean(pupil[!is.na(time) & time < 0], na.rm = TRUE),  # Pre-event baseline
    # Total AUC: approximate as sum over all time
    total_auc = if (any(!is.na(time) & !is.na(pupil))) {
      time_range <- max(time, na.rm = TRUE) - min(time, na.rm = TRUE)
      if (time_range > 0) {
        sum(pupil, na.rm = TRUE) * time_range / n()
      } else NA_real_
    } else NA_real_,
    # Cognitive AUC fixed window: 4.65 to 6.65s (2 second post-target)
    cog_auc_fixed = if (any(!is.na(time) & time >= 4.65 & time <= 6.65)) {
      cog_window_pupil <- pupil[!is.na(time) & time >= 4.65 & time <= 6.65 & !is.na(pupil)]
      if (length(cog_window_pupil) > 0) {
        sum(cog_window_pupil, na.rm = TRUE) * 2.0 / length(cog_window_pupil)
      } else NA_real_
    } else NA_real_,
    # Preserve flags
    segmentation_source = first(segmentation_source),
    window_oob = any(window_oob, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  ungroup()

cat(sprintf("Aggregated to %d trials\n", nrow(pupil_trial)))

# Export trial-level pupil data
pupil_trial_csv <- file.path(INTERMEDIATE_DIR, "pupil_TRIALLEVEL_from_matlab.csv")
pupil_trial_parquet <- file.path(INTERMEDIATE_DIR, "pupil_TRIALLEVEL_from_matlab.parquet")

write_csv(pupil_trial, pupil_trial_csv)
write_parquet(pupil_trial, pupil_trial_parquet)

cat("  Exported to:\n")
cat("    ", pupil_trial_csv, "\n")
cat("    ", pupil_trial_parquet, "\n\n")

# ============================================================================
# STEP C: BEHAVIORAL NORMALIZATION
# ============================================================================

cat("STEP C: Behavioral Normalization\n")
cat("--------------------------------\n")

if (!file.exists(BEHAVIORAL_FILE)) {
  stop("ERROR: Behavioral file not found: ", BEHAVIORAL_FILE)
}

behavioral_raw <- read_csv(BEHAVIORAL_FILE, show_col_types = FALSE)
cat(sprintf("Loaded %d rows from behavioral file\n", nrow(behavioral_raw)))
cat("Behavioral columns:", paste(names(behavioral_raw), collapse = ", "), "\n\n")

# Normalize behavioral columns
behavioral_norm <- behavioral_raw %>%
  mutate(
    subject_id = as.character(subject_id),
    task = case_when(
      task_modality == "aud" ~ "ADT",
      task_modality == "vis" ~ "VDT",
      TRUE ~ as.character(task_modality)
    ),
    session = as.integer(session_num),
    run = as.integer(run_num),
    trial_in_run = as.integer(trial_num),
    intensity = stim_level_index,  # Continuous intensity
    effort = case_when(
      grip_targ_prop_mvc == 0.05 ~ "Low",
      grip_targ_prop_mvc == 0.40 ~ "High",
      TRUE ~ NA_character_
    ),
    choice = resp_is_diff,  # Assuming this is the choice
    correct = resp_is_correct,
    rt = same_diff_resp_secs
  ) %>%
  # Filter to sessions 2-3 and tasks ADT/VDT only
  filter(
    session %in% c(2, 3),
    task %in% c("ADT", "VDT")
  ) %>%
  select(subject_id, task, session, run, trial_in_run, intensity, effort, choice, correct, rt)

cat(sprintf("Normalized to %d trials (sessions 2-3, ADT/VDT only)\n", nrow(behavioral_norm)))

# Export normalized behavioral data
behavioral_norm_csv <- file.path(INTERMEDIATE_DIR, "behavior_TRIALLEVEL_normalized.csv")
write_csv(behavioral_norm, behavioral_norm_csv)

cat("  Exported to:", behavioral_norm_csv, "\n\n")

# ============================================================================
# STEP D: MERGE + MERGE QC
# ============================================================================

cat("STEP D: Merge + Merge QC\n")
cat("------------------------\n")

# Inner join on (subject_id, task, session, run, trial_in_run)
merged <- pupil_trial %>%
  inner_join(behavioral_norm, 
             by = c("subject_id", "task", "session", "run", "trial_in_run"),
             suffix = c("_pupil", "_behav"))

cat(sprintf("Merged dataset: %d trials\n", nrow(merged)))

# Anti-joins for QC
pupil_no_behavior <- pupil_trial %>%
  anti_join(behavioral_norm, 
            by = c("subject_id", "task", "session", "run", "trial_in_run"))

behavior_no_pupil <- behavioral_norm %>%
  anti_join(pupil_trial,
            by = c("subject_id", "task", "session", "run", "trial_in_run"))

cat(sprintf("Pupil-only trials: %d\n", nrow(pupil_no_behavior)))
cat(sprintf("Behavior-only trials: %d\n", nrow(behavior_no_pupil)))

# Match rate by subject/task/session/run
match_rate <- merged %>%
  group_by(subject_id, task, session, run) %>%
  summarise(
    n_merged = n(),
    .groups = "drop"
  ) %>%
  left_join(
    behavioral_norm %>%
      group_by(subject_id, task, session, run) %>%
      summarise(n_behavior = n(), .groups = "drop"),
    by = c("subject_id", "task", "session", "run")
  ) %>%
  left_join(
    pupil_trial %>%
      group_by(subject_id, task, session, run) %>%
      summarise(n_pupil = n(), .groups = "drop"),
    by = c("subject_id", "task", "session", "run")
  ) %>%
  mutate(
    match_rate = n_merged / pmax(n_behavior, n_pupil, na.rm = TRUE),
    n_behavior = replace_na(n_behavior, 0),
    n_pupil = replace_na(n_pupil, 0)
  )

write_csv(match_rate, file.path(QC_DIR, "match_rate_by_subject_task_session_run.csv"))
cat("  Match rate summary written\n")

# Export anti-joins
write_csv(pupil_no_behavior, file.path(QC_DIR, "pupil_no_behavior.csv"))
write_csv(behavior_no_pupil, file.path(QC_DIR, "behavior_no_pupil.csv"))
cat("  Anti-join tables written\n")

# Duplicate trial_uid check
duplicate_check <- merged %>%
  group_by(trial_uid) %>%
  summarise(n = n(), .groups = "drop") %>%
  filter(n > 1)

if (nrow(duplicate_check) > 0) {
  cat(sprintf("WARNING: Found %d duplicate trial_uid values\n", nrow(duplicate_check)))
  write_csv(duplicate_check, file.path(QC_DIR, "duplicate_trial_uid_checks.csv"))
} else {
  cat("✓ No duplicate trial_uid values\n")
  write_csv(tibble(trial_uid = character(), n = integer()), 
            file.path(QC_DIR, "duplicate_trial_uid_checks.csv"))
}

# Design expected vs observed (assume 5 runs × 30 trials/run = 150 trials per subject-task-session)
design_check <- merged %>%
  group_by(subject_id, task, session) %>%
  summarise(
    n_runs_observed = n_distinct(run),
    n_trials_observed = n(),
    n_runs_expected = 5,
    n_trials_expected = 150,
    .groups = "drop"
  ) %>%
  mutate(
    runs_deviation = n_runs_observed - n_runs_expected,
    trials_deviation = n_trials_observed - n_trials_expected
  )

write_csv(design_check, file.path(QC_DIR, "design_expected_vs_observed.csv"))
cat("  Design check written\n\n")

# ============================================================================
# STEP E: HARD FALSIFICATION CHECKS
# ============================================================================

cat("STEP E: Hard Falsification Checks\n")
cat("----------------------------------\n")

# 1) RT-window plausibility
# Check RT falls inside [0.2, 3.0] sec and is not systematically outside trial window
rt_plausibility <- merged %>%
  group_by(subject_id, task, session, run) %>%
  summarise(
    n_trials = n(),
    n_valid_rt = sum(!is.na(rt) & rt >= 0.2 & rt <= 3.0, na.rm = TRUE),
    pct_valid_rt = n_valid_rt / n_trials * 100,
    rt_median = median(rt, na.rm = TRUE),
    rt_min = min(rt, na.rm = TRUE),
    rt_max = max(rt, na.rm = TRUE),
    run_status = if_else(pct_valid_rt < 90, "FAIL_ALIGNMENT", "PASS"),
    .groups = "drop"
  )

write_csv(rt_plausibility, file.path(QC_DIR, "rt_plausibility_by_run.csv"))
cat("  RT plausibility check written\n")

failed_runs <- rt_plausibility %>% filter(run_status == "FAIL_ALIGNMENT")
if (nrow(failed_runs) > 0) {
  cat(sprintf("WARNING: %d runs failed RT plausibility check\n", nrow(failed_runs)))
} else {
  cat("✓ All runs pass RT plausibility check\n")
}

# 2) Intensity completeness
intensity_integrity <- merged %>%
  group_by(subject_id, task, session, run) %>%
  summarise(
    n_trials = n(),
    n_missing_intensity = sum(is.na(intensity)),
    n_unique_intensity = n_distinct(intensity, na.rm = TRUE),
    intensity_constant = n_unique_intensity <= 1,
    intensity_degenerate = n_unique_intensity == 0,
    run_status_intensity = if_else(n_missing_intensity > 0 | intensity_degenerate, 
                                   "FAIL_ALIGNMENT", "PASS"),
    .groups = "drop"
  )

write_csv(intensity_integrity, file.path(QC_DIR, "intensity_integrity_by_run.csv"))
cat("  Intensity integrity check written\n")

failed_intensity <- intensity_integrity %>% filter(run_status_intensity == "FAIL_ALIGNMENT")
if (nrow(failed_intensity) > 0) {
  cat(sprintf("WARNING: %d runs failed intensity integrity check\n", nrow(failed_intensity)))
} else {
  cat("✓ All runs pass intensity integrity check\n")
}

# Combine falsification results
falsification_summary <- rt_plausibility %>%
  full_join(intensity_integrity, 
            by = c("subject_id", "task", "session", "run")) %>%
  mutate(
    run_status = case_when(
      run_status == "FAIL_ALIGNMENT" | run_status_intensity == "FAIL_ALIGNMENT" ~ "FAIL_ALIGNMENT",
      TRUE ~ "PASS"
    )
  )

# Mark failed runs in merged dataset
merged <- merged %>%
  left_join(
    falsification_summary %>% 
      select(subject_id, task, session, run, run_status),
    by = c("subject_id", "task", "session", "run")
  ) %>%
  mutate(run_status = replace_na(run_status, "PASS"))

# Filter out failed runs for analysis-ready export
merged_clean <- merged %>% filter(run_status == "PASS")
cat(sprintf("\nAfter falsification filtering: %d trials (removed %d from failed runs)\n",
            nrow(merged_clean), nrow(merged) - nrow(merged_clean)))

cat("\n")

# ============================================================================
# STEP F: EXPORT ANALYSIS-READY DATASETS
# ============================================================================

cat("STEP F: Export Analysis-Ready Datasets\n")
cat("---------------------------------------\n")

# Add gate columns for Chapter 2/3 analysis
merged_clean <- merged_clean %>%
  mutate(
    # Chapter 2 gates
    ch2_primary = baseline_valid >= 0.60 & cog_valid >= 0.60,
    ch2_sens_050 = baseline_valid >= 0.50 & cog_valid >= 0.50,
    ch2_sens_070 = baseline_valid >= 0.70 & cog_valid >= 0.70,
    # Chapter 3 DDM-ready (behavioral RT filter + minimal pupil tier)
    ch3_ddm_ready = !is.na(rt) & rt >= 0.2 & rt <= 3.0 & 
                    baseline_valid >= 0.50 & cog_valid >= 0.50
  )

# Export full trial-level dataset
bap_triallevel_csv <- file.path(ANALYSIS_READY_DIR, "BAP_TRIALLEVEL.csv")
bap_triallevel_parquet <- file.path(ANALYSIS_READY_DIR, "BAP_TRIALLEVEL.parquet")

write_csv(merged_clean, bap_triallevel_csv)
write_parquet(merged_clean, bap_triallevel_parquet)

cat("  Exported BAP_TRIALLEVEL:\n")
cat("    ", bap_triallevel_csv, "\n")
cat("    ", bap_triallevel_parquet, "\n")

# Export DDM-ready subset
ddm_ready <- merged_clean %>% filter(ch3_ddm_ready)
ddm_ready_csv <- file.path(ANALYSIS_READY_DIR, "BAP_TRIALLEVEL_DDM_READY.csv")
write_csv(ddm_ready, ddm_ready_csv)

cat("  Exported BAP_TRIALLEVEL_DDM_READY:\n")
cat("    ", ddm_ready_csv, "\n")
cat(sprintf("    (%d trials)\n", nrow(ddm_ready)))

# Missingness-as-outcome tables
missingness_summary <- merged_clean %>%
  group_by(task, effort, intensity) %>%
  summarise(
    n_total = n(),
    ch2_primary_pass = sum(ch2_primary, na.rm = TRUE),
    ch2_primary_fail = n_total - ch2_primary_pass,
    ch2_sens_050_pass = sum(ch2_sens_050, na.rm = TRUE),
    ch2_sens_050_fail = n_total - ch2_sens_050_pass,
    ch2_sens_070_pass = sum(ch2_sens_070, na.rm = TRUE),
    ch2_sens_070_fail = n_total - ch2_sens_070_pass,
    ch3_ddm_ready_pass = sum(ch3_ddm_ready, na.rm = TRUE),
    ch3_ddm_ready_fail = n_total - ch3_ddm_ready_pass,
    .groups = "drop"
  ) %>%
  mutate(
    ch2_primary_pass_rate = ch2_primary_pass / n_total,
    ch2_sens_050_pass_rate = ch2_sens_050_pass / n_total,
    ch2_sens_070_pass_rate = ch2_sens_070_pass / n_total,
    ch3_ddm_ready_pass_rate = ch3_ddm_ready_pass / n_total
  )

write_csv(missingness_summary, file.path(QC_ANALYSIS_DIR, "missingness_as_outcome.csv"))
cat("  Missingness-as-outcome table written\n\n")

# ============================================================================
# STEP G: FINAL REPORT
# ============================================================================

cat("STEP G: Generate Final Report\n")
cat("------------------------------\n")

# Generate summary statistics
final_summary <- list(
  contamination_detected = nrow(schema_violations %>% filter(session == 1 | str_detect(violation_type, "session"))) > 0,
  alignment_failures = nrow(falsification_summary %>% filter(run_status == "FAIL_ALIGNMENT")),
  n_subjects = n_distinct(merged_clean$subject_id),
  n_trials_total = nrow(merged_clean),
  n_trials_by_task = merged_clean %>% count(task, name = "n_trials"),
  gate_retention = list(
    ch2_primary = sum(merged_clean$ch2_primary, na.rm = TRUE),
    ch2_sens_050 = sum(merged_clean$ch2_sens_050, na.rm = TRUE),
    ch2_sens_070 = sum(merged_clean$ch2_sens_070, na.rm = TRUE),
    ch3_ddm_ready = sum(merged_clean$ch3_ddm_ready, na.rm = TRUE)
  ),
  final_outputs = list(
    triallevel_csv = bap_triallevel_csv,
    triallevel_parquet = bap_triallevel_parquet,
    ddm_ready_csv = ddm_ready_csv
  )
)

# Write markdown report
report_path <- file.path(QC_ANALYSIS_DIR, "final_readiness_report.md")
cat("Writing final report to:", report_path, "\n")

report_content <- paste0(
  "# BAP Pupillometry Pipeline - Final Readiness Report\n\n",
  "Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n",
  "## Contamination Checks\n\n",
  "- **Session 1/Practice contamination**: ", 
  if (final_summary$contamination_detected) "**FAIL** - Contamination detected" else "**PASS** - No contamination", "\n",
  "- **Alignment failures**: ", final_summary$alignment_failures, " runs failed falsification checks\n\n",
  "## Final Dataset Statistics\n\n",
  "- **N subjects**: ", final_summary$n_subjects, "\n",
  "- **N trials (total)**: ", final_summary$n_trials_total, "\n",
  "- **N trials by task**:\n",
  paste0("  - ", final_summary$n_trials_by_task$task, ": ", 
         final_summary$n_trials_by_task$n_trials, collapse = "\n"), "\n\n",
  "## Gate Retention\n\n",
  "- **ch2_primary** (baseline≥0.60 & cog≥0.60): ", final_summary$gate_retention$ch2_primary, " trials\n",
  "- **ch2_sens_050** (baseline≥0.50 & cog≥0.50): ", final_summary$gate_retention$ch2_sens_050, " trials\n",
  "- **ch2_sens_070** (baseline≥0.70 & cog≥0.70): ", final_summary$gate_retention$ch2_sens_070, " trials\n",
  "- **ch3_ddm_ready** (RT filter + minimal pupil): ", final_summary$gate_retention$ch3_ddm_ready, " trials\n\n",
  "## Final Outputs\n\n",
  "- **Trial-level dataset (CSV)**: `", final_summary$final_outputs$triallevel_csv, "`\n",
  "- **Trial-level dataset (Parquet)**: `", final_summary$final_outputs$triallevel_parquet, "`\n",
  "- **DDM-ready dataset (CSV)**: `", final_summary$final_outputs$ddm_ready_csv, "`\n\n",
  "## Merge Match Rates\n\n",
  "See: `data/qc/merge_audit/match_rate_by_subject_task_session_run.csv`\n\n",
  "## Falsification Results\n\n",
  "See: `data/qc/merge_audit/rt_plausibility_by_run.csv`\n",
  "See: `data/qc/merge_audit/intensity_integrity_by_run.csv`\n\n",
  "## Overall Status\n\n",
  if (final_summary$contamination_detected || final_summary$alignment_failures > 0) {
    "**FAIL** - Issues detected. Review QC artifacts."
  } else {
    "**PASS** - All checks passed. Datasets ready for analysis."
  }, "\n"
)

writeLines(report_content, report_path)

# Print summary to console
cat("\n=== FINAL SUMMARY ===\n")
cat("Contamination detected:", if (final_summary$contamination_detected) "YES" else "NO", "\n")
cat("Alignment failures:", final_summary$alignment_failures, "\n")
cat("N subjects:", final_summary$n_subjects, "\n")
cat("N trials (total):", final_summary$n_trials_total, "\n")
cat("\nGate retention:\n")
cat("  ch2_primary:", final_summary$gate_retention$ch2_primary, "\n")
cat("  ch2_sens_050:", final_summary$gate_retention$ch2_sens_050, "\n")
cat("  ch2_sens_070:", final_summary$gate_retention$ch2_sens_070, "\n")
cat("  ch3_ddm_ready:", final_summary$gate_retention$ch3_ddm_ready, "\n")
cat("\nFinal outputs:\n")
cat("  ", bap_triallevel_csv, "\n")
cat("  ", bap_triallevel_parquet, "\n")
cat("  ", ddm_ready_csv, "\n")
cat("\nOverall status:", 
    if (final_summary$contamination_detected || final_summary$alignment_failures > 0) "FAIL" else "PASS", "\n")

cat("\n=== PIPELINE COMPLETE ===\n")

