#!/usr/bin/env Rscript
# ============================================================================
# Add B1_quality to Merged Dataset
# ============================================================================
# This script adds B1_quality metric to the merged_v4 dataset by:
# 1. Loading the QC export (pupil_trial_coverage_prefilter.csv) which contains valid_baseline_B1
# 2. Renaming valid_baseline_B1 to B1_quality
# 3. Merging it into the existing merged_v4 file
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(here)
})

cat("=== ADDING B1_QUALITY TO MERGED DATASET ===\n\n")

# Configuration
REPO_ROOT <- here::here()
V7_ROOT <- file.path(REPO_ROOT, "data", "pupil_processed")
QC_DIR <- file.path(REPO_ROOT, "data", "qc")
MERGED_DIR <- file.path(V7_ROOT, "merged")

# Paths
qc_file <- file.path(QC_DIR, "pupil_trial_coverage_prefilter.csv")
merged_file <- file.path(MERGED_DIR, "BAP_triallevel_merged_v4.csv")
output_file <- file.path(MERGED_DIR, "BAP_triallevel_merged_v4.csv")

# Check if QC file exists
if (!file.exists(qc_file)) {
  stop("QC file not found: ", qc_file, 
       "\nPlease run 02_pupillometry_analysis/quality_control/build_pupil_trial_coverage_prefilter.R first.")
}

# Check if merged file exists
if (!file.exists(merged_file)) {
  stop("Merged file not found: ", merged_file,
       "\nPlease run scripts/make_quick_share_v7.R first.")
}

cat("1. Loading QC export...\n")
qc_data <- read_csv(qc_file, show_col_types = FALSE)

# Check if valid_baseline_B1 exists
if (!"valid_baseline_B1" %in% names(qc_data)) {
  stop("valid_baseline_B1 not found in QC export. ",
       "Please ensure build_pupil_trial_coverage_prefilter.R has been updated with B1_quality calculation.")
}

cat("  ✓ Loaded ", nrow(qc_data), " trials from QC export\n", sep = "")

# Prepare QC data for merging
# Map subject_id -> sub, and ensure trial_index matches
qc_for_merge <- qc_data %>%
  mutate(
    # Map subject_id to sub (if needed)
    sub = if ("sub" %in% names(.)) sub else subject_id,
    # Ensure trial_index exists
    trial_index = if ("trial_index" %in% names(.)) trial_index else trial_in_run,
    # Rename valid_baseline_B1 to B1_quality
    B1_quality = valid_baseline_B1
  ) %>%
  # Select only the columns we need for merging
  select(sub, task, run, trial_index, B1_quality) %>%
  # Handle session_used if it exists
  mutate(
    session_used = if ("session_used" %in% names(qc_data)) {
      qc_data$session_used
    } else if ("session" %in% names(qc_data)) {
      qc_data$session
    } else {
      NA_integer_
    }
  ) %>%
  # Remove any rows with missing keys
  filter(!is.na(sub), !is.na(task), !is.na(run), !is.na(trial_index)) %>%
  # Ensure proper types
  mutate(
    sub = as.character(sub),
    task = as.character(task),
    session_used = as.integer(session_used),
    run_used = as.integer(run),
    trial_index = as.integer(trial_index)
  ) %>%
  select(sub, task, session_used, run_used, trial_index, B1_quality) %>%
  # Deduplicate (keep first if duplicates)
  group_by(sub, task, session_used, run_used, trial_index) %>%
  slice(1) %>%
  ungroup()

cat("  ✓ Prepared ", nrow(qc_for_merge), " trials for merging\n", sep = "")

cat("\n2. Loading merged dataset...\n")
merged_data <- read_csv(merged_file, show_col_types = FALSE)
cat("  ✓ Loaded ", nrow(merged_data), " trials from merged file\n", sep = "")

# Ensure proper key types in merged data
merged_data <- merged_data %>%
  mutate(
    sub = as.character(sub),
    task = as.character(task),
    session_used = as.integer(session_used),
    run_used = as.integer(run_used),
    trial_index = as.integer(trial_index)
  )

cat("\n3. Merging B1_quality...\n")
merged_with_B1 <- merged_data %>%
  left_join(
    qc_for_merge,
    by = c("sub", "task", "session_used", "run_used", "trial_index")
  )

# Check merge success
n_with_B1 <- sum(!is.na(merged_with_B1$B1_quality))
pct_with_B1 <- 100 * n_with_B1 / nrow(merged_with_B1)

cat("  ✓ Merged B1_quality: ", n_with_B1, " / ", nrow(merged_with_B1), 
    " trials (", sprintf("%.1f", pct_with_B1), "%)\n", sep = "")

if (n_with_B1 == 0) {
  warning("WARNING: No trials matched! Check key alignment between QC export and merged file.")
  cat("\n  Sample keys from QC:\n")
  print(head(qc_for_merge %>% select(sub, task, session_used, run_used, trial_index)))
  cat("\n  Sample keys from merged:\n")
  print(head(merged_data %>% select(sub, task, session_used, run_used, trial_index)))
}

cat("\n4. Saving updated merged file...\n")

# Backup original
backup_file <- paste0(merged_file, ".backup_", format(Sys.time(), "%Y%m%d_%H%M%S"))
file.copy(merged_file, backup_file)
cat("  ✓ Backed up original to: ", basename(backup_file), "\n", sep = "")

# Save updated file
write_csv(merged_with_B1, output_file)
cat("  ✓ Saved updated merged file: ", basename(output_file), "\n", sep = "")

cat("\n=== COMPLETE ===\n")
cat("B1_quality has been added to the merged dataset.\n")
cat("You can now run scripts/make_quick_share_v7.R to regenerate analysis-ready datasets.\n\n")
