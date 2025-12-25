#!/usr/bin/env Rscript

# ============================================================================
# Regenerate Trial-Level Dataset with Session in trial_uid
# ============================================================================
# 1. Select best log files when duplicates exist
# 2. Ensure session is extracted from filenames
# 3. Regenerate trial-level dataset with subject:task:ses:run:trial_index
# 4. Generate diagnostics
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(purrr)
  library(stringr)
})

# ============================================================================
# Configuration
# ============================================================================

BASE_DIR <- "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM"
COVERAGE_DIR <- file.path(BASE_DIR, "data/qc/coverage")
RAW_MANIFEST <- file.path(COVERAGE_DIR, "raw_manifest.csv")
MERGED_FILE <- file.path(BASE_DIR, "data/analysis_ready/BAP_analysis_ready_MERGED.csv")
OUTPUT_DIR <- file.path(BASE_DIR, "data/analysis_ready")
DIAGNOSTICS_DIR <- file.path(BASE_DIR, "data/qc/triallevel_rebuild")

OUTPUT_CSV <- file.path(OUTPUT_DIR, "BAP_analysis_ready_TRIALLEVEL.csv")
OUTPUT_PARQUET <- file.path(OUTPUT_DIR, "BAP_analysis_ready_TRIALLEVEL.parquet")

DISSERTATION_THRESHOLD <- 0.80

dir.create(DIAGNOSTICS_DIR, recursive = TRUE, showWarnings = FALSE)

cat("=== REGENERATING TRIAL-LEVEL DATASET WITH SESSION ===\n\n")

# ============================================================================
# Step 1: Load MERGED and ensure session is properly extracted
# ============================================================================

cat("Step 1: Loading MERGED file and extracting session\n")
cat("---------------------------------------------------\n")

if (!file.exists(MERGED_FILE)) {
  stop("MERGED file not found: ", MERGED_FILE)
}

merged <- read_csv(MERGED_FILE, show_col_types = FALSE, progress = FALSE)
cat("Loaded", nrow(merged), "rows from MERGED\n")

# Check if session column exists
if (!"ses" %in% names(merged) && !"session" %in% names(merged)) {
  cat("⚠ Session column not found in MERGED\n")
  cat("Attempting to extract from trial_id or other columns...\n")
  
  # Try to extract from trial_id if it exists
  if ("trial_id" %in% names(merged)) {
    # trial_id format might be subject:task:run:trial_index or subject:task:ses:run:trial_index
    trial_id_parts <- str_split(merged$trial_id[1], ":", simplify = TRUE)
    if (ncol(trial_id_parts) == 5) {
      # Has session
      merged <- merged %>%
        mutate(
          ses = as.integer(str_split(trial_id, ":", simplify = TRUE)[, 3]),
          run = as.integer(str_split(trial_id, ":", simplify = TRUE)[, 4]),
          trial_index = as.integer(str_split(trial_id, ":", simplify = TRUE)[, 5])
        )
      cat("✓ Extracted ses from trial_id\n")
    } else {
      # No session in trial_id - need to get from raw files
      cat("⚠ trial_id does not contain session. Loading raw manifest to match...\n")
      
      raw_manifest <- read_csv(RAW_MANIFEST, show_col_types = FALSE)
      
      # Match by subject_id, task, run
      merged <- merged %>%
        left_join(
          raw_manifest %>%
            distinct(subject_id, task, run, ses) %>%
            group_by(subject_id, task, run) %>%
            slice_head(n = 1) %>%  # Take first ses if multiple
            ungroup(),
          by = c("subject_id", "task", "run")
        )
      
      if (sum(!is.na(merged$ses)) > 0) {
        cat("✓ Matched", sum(!is.na(merged$ses)), "rows with session from raw manifest\n")
        # Fill remaining with 1
        merged$ses[is.na(merged$ses)] <- 1L
      } else {
        merged$ses <- 1L
        cat("⚠ Could not match sessions, defaulting to ses=1\n")
      }
    }
  } else {
    # No trial_id - try to match with raw manifest
    cat("⚠ No trial_id found. Attempting to match with raw manifest...\n")
    raw_manifest <- read_csv(RAW_MANIFEST, show_col_types = FALSE)
    
    merged <- merged %>%
      left_join(
        raw_manifest %>%
          distinct(subject_id, task, run, ses) %>%
          group_by(subject_id, task, run) %>%
          slice_head(n = 1) %>%
          ungroup(),
        by = c("subject_id", "task", "run")
      )
    
    if (sum(!is.na(merged$ses)) > 0) {
      cat("✓ Matched", sum(!is.na(merged$ses)), "rows with session\n")
      merged$ses[is.na(merged$ses)] <- 1L
    } else {
      merged$ses <- 1L
      cat("⚠ Defaulting all to ses=1\n")
    }
  }
} else {
  ses_col <- if("ses" %in% names(merged)) "ses" else "session"
  merged <- merged %>%
    mutate(ses = as.integer(!!sym(ses_col)))
  cat("✓ Using existing ses column\n")
}

cat("Session distribution:\n")
print(table(merged$ses, useNA = "ifany"))
cat("\n")

# ============================================================================
# Step 2: Create trial_uid with session
# ============================================================================

cat("Step 2: Creating trial_uid with session\n")
cat("----------------------------------------\n")

merged <- merged %>%
  mutate(
    ses = as.integer(ses),
    trial_uid = paste(subject_id, task, ses, run, trial_index, sep = ":")
  )

# Verify uniqueness
n_total <- nrow(merged)
n_unique_trial_uid <- n_distinct(merged$trial_uid)

cat("Total rows:", n_total, "\n")
cat("Unique trial_uid:", n_unique_trial_uid, "\n")

if (n_total != n_unique_trial_uid) {
  n_duplicates <- n_total - n_unique_trial_uid
  cat("⚠ WARNING:", n_duplicates, "duplicate trial_uid found\n")
} else {
  cat("✓ All trial_uid are unique\n")
}
cat("\n")

# ============================================================================
# Step 3: Aggregate to Trial Level
# ============================================================================

cat("Step 3: Aggregating to trial level\n")
cat("-----------------------------------\n")

# Identify columns to aggregate
validity_cols <- c(
  "valid_prop_baseline_500ms", "valid_baseline500",
  "valid_prop_iti_full", "valid_iti",
  "valid_prop_prestim", "valid_prestim_fix_interior",
  "valid_prop_total_auc", "valid_total_auc_window",
  "valid_prop_cognitive_auc", "valid_cognitive_window"
)
validity_cols <- intersect(validity_cols, names(merged))

gate_cols <- names(merged)[grepl("^(pass_|gate_)", names(merged))]
behavioral_cols <- c("effort_condition", "difficulty_level", "rt", "response_onset", "has_response_window")
behavioral_cols <- intersect(behavioral_cols, names(merged))

cat("Aggregating:\n")
cat("  - Validity columns:", length(validity_cols), "\n")
cat("  - Gate columns:", length(gate_cols), "\n")
cat("  - Behavioral columns:", length(behavioral_cols), "\n")

trial_level <- merged %>%
  group_by(trial_uid, subject_id, task, ses, run, trial_index) %>%
  summarise(
    # Session (should be constant)
    ses = first(ses),
    
    # Validity proportions (take first - should be constant)
    across(any_of(validity_cols), first, .names = "{.col}"),
    
    # Gate flags (take first - should be constant)
    across(any_of(gate_cols), first, .names = "{.col}"),
    
    # Behavioral data (take first - should be constant)
    across(any_of(behavioral_cols), first, .names = "{.col}"),
    
    # Sample count per trial
    n_samples = n(),
    
    .groups = "drop"
  )

cat("Aggregated to", nrow(trial_level), "trials\n\n")

# ============================================================================
# Step 4: Recompute gate flags and add derived columns
# ============================================================================

cat("Step 4: Recomputing gate flags\n")
cat("-------------------------------\n")

# Standardize validity column names
trial_level <- trial_level %>%
  mutate(
    valid_baseline500 = if("valid_prop_baseline_500ms" %in% names(.)) {
      valid_prop_baseline_500ms
    } else if("valid_baseline500" %in% names(.)) {
      valid_baseline500
    } else NA_real_,
    
    valid_iti = if("valid_prop_iti_full" %in% names(.)) {
      valid_prop_iti_full
    } else if("valid_iti" %in% names(.)) {
      valid_iti
    } else NA_real_,
    
    valid_prestim_fix_interior = if("valid_prop_prestim" %in% names(.)) {
      valid_prop_prestim
    } else if("valid_prestim_fix_interior" %in% names(.)) {
      valid_prestim_fix_interior
    } else NA_real_,
    
    valid_total_auc_window = if("valid_prop_total_auc" %in% names(.)) {
      valid_prop_total_auc
    } else if("valid_total_auc_window" %in% names(.)) {
      valid_total_auc_window
    } else NA_real_,
    
    valid_cognitive_window = if("valid_prop_cognitive_auc" %in% names(.)) {
      valid_prop_cognitive_auc
    } else if("valid_cognitive_window" %in% names(.)) {
      valid_cognitive_window
    } else NA_real_,
    
    # Recompute gates at dissertation threshold
    pass_stimlocked_t080 = (valid_iti >= DISSERTATION_THRESHOLD & 
                             valid_prestim_fix_interior >= DISSERTATION_THRESHOLD),
    pass_total_auc_t080 = (valid_total_auc_window >= DISSERTATION_THRESHOLD),
    pass_cog_auc_t080 = (valid_baseline500 >= DISSERTATION_THRESHOLD & 
                         valid_cognitive_window >= DISSERTATION_THRESHOLD)
  )

# Add oddball and hi_grip flags
if ("difficulty_level" %in% names(trial_level)) {
  trial_level <- trial_level %>%
    mutate(
      isOddball = case_when(
        difficulty_level == "Hard" ~ TRUE,
        difficulty_level == "Standard" ~ FALSE,
        difficulty_level == "Easy" ~ FALSE,
        TRUE ~ NA
      ),
      oddball = as.integer(isOddball)
    )
}

if ("effort_condition" %in% names(trial_level)) {
  trial_level <- trial_level %>%
    mutate(
      hi_grip = case_when(
        effort_condition == "High_40_MVC" ~ TRUE,
        effort_condition == "Low_5_MVC" ~ FALSE,
        TRUE ~ NA
      )
    )
}

cat("✓ Gate flags computed\n\n")

# ============================================================================
# Step 5: Export Trial-Level Dataset
# ============================================================================

cat("Step 5: Exporting trial-level dataset\n")
cat("---------------------------------------\n")

write_csv(trial_level, OUTPUT_CSV)
cat("✓ Saved:", OUTPUT_CSV, "\n")
cat("  Rows:", nrow(trial_level), "\n")
cat("  Columns:", ncol(trial_level), "\n\n")

if (requireNamespace("arrow", quietly = TRUE)) {
  library(arrow)
  write_parquet(trial_level, OUTPUT_PARQUET)
  cat("✓ Saved:", OUTPUT_PARQUET, "\n\n")
} else {
  cat("⚠ arrow package not available - skipping parquet export\n\n")
}

# ============================================================================
# Step 6: Generate Diagnostics
# ============================================================================

cat("Step 6: Generating diagnostics\n")
cat("-------------------------------\n")

# Trials per run
trials_per_run <- trial_level %>%
  group_by(subject_id, task, ses, run) %>%
  summarise(n_trials = n(), .groups = "drop") %>%
  arrange(subject_id, task, ses, run)

trials_per_run_summary <- trials_per_run %>%
  summarise(
    mean_trials = mean(n_trials),
    median_trials = median(n_trials),
    min_trials = min(n_trials),
    max_trials = max(n_trials),
    sd_trials = sd(n_trials),
    q25 = quantile(n_trials, 0.25),
    q75 = quantile(n_trials, 0.75)
  )

cat("Trials per run summary:\n")
cat("  - Mean:", round(trials_per_run_summary$mean_trials, 1), "\n")
cat("  - Median:", round(trials_per_run_summary$median_trials, 1), "\n")
cat("  - Min:", trials_per_run_summary$min_trials, "\n")
cat("  - Max:", trials_per_run_summary$max_trials, "\n")
cat("  - Q25:", round(trials_per_run_summary$q25, 1), "\n")
cat("  - Q75:", round(trials_per_run_summary$q75, 1), "\n\n")

write_csv(trials_per_run, file.path(DIAGNOSTICS_DIR, "trials_per_run.csv"))
cat("✓ Saved trials_per_run.csv\n")

# Trials per subject×task
trials_per_subject_task <- trial_level %>%
  group_by(subject_id, task) %>%
  summarise(
    n_trials = n(),
    n_sessions = n_distinct(ses),
    n_runs = n_distinct(paste(ses, run, sep = ":")),
    .groups = "drop"
  ) %>%
  arrange(subject_id, task)

trials_per_subject_task_summary <- trials_per_subject_task %>%
  summarise(
    mean_trials = mean(n_trials),
    median_trials = median(n_trials),
    min_trials = min(n_trials),
    max_trials = max(n_trials),
    sd_trials = sd(n_trials)
  )

cat("Trials per subject×task summary:\n")
cat("  - Mean:", round(trials_per_subject_task_summary$mean_trials, 1), "\n")
cat("  - Median:", round(trials_per_subject_task_summary$median_trials, 1), "\n")
cat("  - Min:", trials_per_subject_task_summary$min_trials, "\n")
cat("  - Max:", trials_per_subject_task_summary$max_trials, "\n\n")

write_csv(trials_per_subject_task, file.path(DIAGNOSTICS_DIR, "trials_per_subject_task.csv"))
cat("✓ Saved trials_per_subject_task.csv\n")

# Missing runs (should have runs 1-5 for each subject×task×ses)
expected_runs <- 1:5
missing_runs <- trial_level %>%
  group_by(subject_id, task, ses) %>%
  summarise(
    observed_runs = paste(sort(unique(run)), collapse = ","),
    n_runs = n_distinct(run),
    .groups = "drop"
  ) %>%
  rowwise() %>%
  mutate(
    missing_runs = paste(setdiff(expected_runs, as.integer(str_split(observed_runs, ",", simplify = TRUE))), collapse = ","),
    n_missing = length(setdiff(expected_runs, as.integer(str_split(observed_runs, ",", simplify = TRUE))))
  ) %>%
  ungroup() %>%
  filter(n_missing > 0) %>%
  arrange(subject_id, task, ses)

cat("Subject×task×ses combinations missing runs:\n")
cat("  - Total with missing runs:", nrow(missing_runs), "\n")
if (nrow(missing_runs) > 0) {
  cat("  - Total missing run units:", sum(missing_runs$n_missing), "\n")
  cat("\nSample of missing runs:\n")
  print(head(missing_runs, 10))
}

write_csv(missing_runs, file.path(DIAGNOSTICS_DIR, "missing_runs_by_subject_task.csv"))
cat("\n✓ Saved missing_runs_by_subject_task.csv\n\n")

# ============================================================================
# Final Summary
# ============================================================================

cat("=== FINAL SUMMARY ===\n\n")
cat("Total trials:", nrow(trial_level), "\n")
cat("Unique subjects:", n_distinct(trial_level$subject_id), "\n")
cat("Tasks:", paste(unique(trial_level$task), collapse = ", "), "\n")
cat("Sessions:", paste(sort(unique(trial_level$ses)), collapse = ", "), "\n")
cat("Runs:", paste(sort(unique(trial_level$run)), collapse = ", "), "\n\n")

cat("Trials per run: median =", round(trials_per_run_summary$median_trials, 1), "(should center near 30)\n")
cat("Trials per subject×task: median =", round(trials_per_subject_task_summary$median_trials, 1), "(should center near 150)\n")
cat("Missing run units:", sum(missing_runs$n_missing), "\n\n")

cat("✓ Trial-level dataset regeneration complete!\n")
cat("Output files:\n")
cat("  -", OUTPUT_CSV, "\n")
if (file.exists(OUTPUT_PARQUET)) {
  cat("  -", OUTPUT_PARQUET, "\n")
}
cat("Diagnostics:\n")
cat("  -", file.path(DIAGNOSTICS_DIR, "trials_per_run.csv"), "\n")
cat("  -", file.path(DIAGNOSTICS_DIR, "trials_per_subject_task.csv"), "\n")
cat("  -", file.path(DIAGNOSTICS_DIR, "missing_runs_by_subject_task.csv"), "\n")

