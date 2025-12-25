#!/usr/bin/env Rscript

# ============================================================================
# Rebuild Analysis-Ready Datasets with Scanner Ses-2/3 Only
# ============================================================================
# This script rebuilds MERGED and TRIALLEVEL datasets using only
# InsideScanner ses-2/3 data (excluding practice/test logs)
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(purrr)
  library(stringr)
})

BASE_DIR <- "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM"
COVERAGE_DIR <- file.path(BASE_DIR, "data/qc/coverage")
ANALYSIS_READY_DIR <- file.path(BASE_DIR, "data/analysis_ready")
QC_DIR <- file.path(BASE_DIR, "data/qc")

cat("=== REBUILDING SCANNER SES-2/3 DATASETS ===\n\n")

# ============================================================================
# Step 1: Regenerate raw_manifest with strict filtering
# ============================================================================

cat("Step 1: Regenerating raw_manifest with strict filtering\n")
cat("-------------------------------------------------------\n")

source(file.path(BASE_DIR, "scripts/check_data_coverage.R"))

# Verify the manifest was regenerated
raw_manifest_file <- file.path(COVERAGE_DIR, "raw_manifest.csv")
if (!file.exists(raw_manifest_file)) {
  stop("raw_manifest.csv not found. Run check_data_coverage.R first.")
}

raw_manifest <- read_csv(raw_manifest_file, show_col_types = FALSE)

# Verify filtering worked
ses_dist <- table(raw_manifest$ses, useNA = "ifany")
cat("\nSession distribution in raw_manifest:\n")
print(ses_dist)

if (any(names(ses_dist) %in% c("1", 1))) {
  stop("ERROR: raw_manifest still contains ses=1. Filtering failed.")
}

if (!all(unique(raw_manifest$ses) %in% c(2, 3))) {
  stop("ERROR: raw_manifest contains sessions other than 2 or 3.")
}

cat("✓ raw_manifest validated: only ses 2 and 3\n\n")

# ============================================================================
# Step 2: Load MERGED and filter to scanner ses-2/3
# ============================================================================

cat("Step 2: Filtering MERGED to scanner ses-2/3\n")
cat("--------------------------------------------\n")

merged_file <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_MERGED.csv")
if (!file.exists(merged_file)) {
  stop("MERGED file not found: ", merged_file)
}

cat("Loading MERGED file (this may take a moment)...\n")
merged <- read_csv(merged_file, show_col_types = FALSE, progress = FALSE)
cat("Loaded", nrow(merged), "rows\n")

# Filter to ses 2 or 3
# First, ensure ses column exists and is properly extracted
if (!"ses" %in% names(merged)) {
  # Try to extract from trial_id or other columns
  if ("trial_id" %in% names(merged)) {
    # trial_id format: subject:task:ses:run:trial_index or subject:task:run:trial_index
    trial_id_parts <- str_split(merged$trial_id[1], ":", simplify = TRUE)
    if (ncol(trial_id_parts) >= 3) {
      merged <- merged %>%
        mutate(ses = as.integer(str_split(trial_id, ":", simplify = TRUE)[, 3]))
    } else {
      # No ses in trial_id - match with raw_manifest
      cat("Extracting ses from raw_manifest...\n")
      merged <- merged %>%
        left_join(
          raw_manifest %>%
            distinct(subject_id, task, run, ses),
          by = c("subject_id", "task", "run")
        )
    }
  } else {
    # Match with raw_manifest
    cat("Extracting ses from raw_manifest...\n")
    merged <- merged %>%
      left_join(
        raw_manifest %>%
          distinct(subject_id, task, run, ses),
        by = c("subject_id", "task", "run")
      )
  }
}

# Filter to ses 2 or 3
merged_filtered <- merged %>%
  filter(ses %in% c(2, 3))

cat("Filtered MERGED:\n")
cat("  - Original rows:", nrow(merged), "\n")
cat("  - Filtered rows:", nrow(merged_filtered), "\n")
cat("  - Removed:", nrow(merged) - nrow(merged_filtered), "rows (ses=1 or missing)\n\n")

# Save filtered MERGED
output_merged_csv <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_MERGED_scanner_ses23.csv")
output_merged_parquet <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_MERGED_scanner_ses23.parquet")

write_csv(merged_filtered, output_merged_csv)
cat("✓ Saved:", output_merged_csv, "\n")

if (requireNamespace("arrow", quietly = TRUE)) {
  library(arrow)
  write_parquet(merged_filtered, output_merged_parquet)
  cat("✓ Saved:", output_merged_parquet, "\n")
}

cat("\n")

# ============================================================================
# Step 3: Rebuild TRIALLEVEL from filtered MERGED
# ============================================================================

cat("Step 3: Rebuilding TRIALLEVEL from filtered MERGED\n")
cat("---------------------------------------------------\n")

# Create trial_uid with session
merged_filtered <- merged_filtered %>%
  mutate(
    ses = as.integer(ses),
    trial_uid = paste(subject_id, task, ses, run, trial_index, sep = ":")
  )

# Verify uniqueness
n_total <- nrow(merged_filtered)
n_unique_trial_uid <- n_distinct(merged_filtered$trial_uid)

cat("Total rows:", n_total, "\n")
cat("Unique trial_uid:", n_unique_trial_uid, "\n")

if (n_total != n_unique_trial_uid) {
  cat("⚠ WARNING:", n_total - n_unique_trial_uid, "duplicate trial_uid found\n")
} else {
  cat("✓ All trial_uid are unique\n")
}

# Aggregate to trial level
validity_cols <- c(
  "valid_prop_baseline_500ms", "valid_baseline500",
  "valid_prop_iti_full", "valid_iti",
  "valid_prop_prestim", "valid_prestim_fix_interior",
  "valid_prop_total_auc", "valid_total_auc_window",
  "valid_prop_cognitive_auc", "valid_cognitive_window"
)
validity_cols <- intersect(validity_cols, names(merged_filtered))

gate_cols <- names(merged_filtered)[grepl("^(pass_|gate_)", names(merged_filtered))]
behavioral_cols <- c("effort_condition", "difficulty_level", "rt", "response_onset", "has_response_window")
behavioral_cols <- intersect(behavioral_cols, names(merged_filtered))

cat("\nAggregating to trial level...\n")
cat("  - Validity columns:", length(validity_cols), "\n")
cat("  - Gate columns:", length(gate_cols), "\n")
cat("  - Behavioral columns:", length(behavioral_cols), "\n")

trial_level <- merged_filtered %>%
  group_by(trial_uid, subject_id, task, ses, run, trial_index) %>%
  summarise(
    ses = first(ses),
    across(any_of(validity_cols), first, .names = "{.col}"),
    across(any_of(gate_cols), first, .names = "{.col}"),
    across(any_of(behavioral_cols), first, .names = "{.col}"),
    n_samples = n(),
    .groups = "drop"
  )

cat("Aggregated to", nrow(trial_level), "trials\n")

# Recompute gates at threshold 0.80
DISSERTATION_THRESHOLD <- 0.80

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
    
    # Recompute gates
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

# Save TRIALLEVEL
output_triallevel_csv <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_TRIALLEVEL_scanner_ses23.csv")
output_triallevel_parquet <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_TRIALLEVEL_scanner_ses23.parquet")

write_csv(trial_level, output_triallevel_csv)
cat("✓ Saved:", output_triallevel_csv, "\n")
cat("  Rows:", nrow(trial_level), "\n")
cat("  Columns:", ncol(trial_level), "\n\n")

if (requireNamespace("arrow", quietly = TRUE)) {
  library(arrow)
  write_parquet(trial_level, output_triallevel_parquet)
  cat("✓ Saved:", output_triallevel_parquet, "\n\n")
}

# ============================================================================
# Step 4: Generate validation summary
# ============================================================================

cat("Step 4: Validation Summary\n")
cat("---------------------------\n")

cat("Session distribution in TRIALLEVEL:\n")
print(table(trial_level$ses, useNA = "ifany"))

cat("\nTrials per subject×task:\n")
trials_per_subj_task <- trial_level %>%
  group_by(subject_id, task) %>%
  summarise(n_trials = n(), .groups = "drop")

cat("  - Min:", min(trials_per_subj_task$n_trials), "\n")
cat("  - Median:", median(trials_per_subj_task$n_trials), "\n")
cat("  - Max:", max(trials_per_subj_task$n_trials), "\n")

cat("\nUnique subjects:", n_distinct(trial_level$subject_id), "\n")
cat("Total trials:", nrow(trial_level), "\n")

cat("\n✓ Dataset rebuild complete!\n")
cat("\nOutput files:\n")
cat("  -", output_merged_csv, "\n")
if (file.exists(output_merged_parquet)) {
  cat("  -", output_merged_parquet, "\n")
}
cat("  -", output_triallevel_csv, "\n")
if (file.exists(output_triallevel_parquet)) {
  cat("  -", output_triallevel_parquet, "\n")
}

