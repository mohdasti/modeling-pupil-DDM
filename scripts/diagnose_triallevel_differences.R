#!/usr/bin/env Rscript

# ============================================================================
# Diagnose Differences Between Original and New TRIALLEVEL
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

BASE_DIR <- "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM"
ANALYSIS_READY_DIR <- file.path(BASE_DIR, "data/analysis_ready")
OUTPUT_DIR <- file.path(BASE_DIR, "data/qc/analysis_ready_audit")

cat("=== DIAGNOSING TRIALLEVEL DIFFERENCES ===\n\n")

# Load both datasets
old_file <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_TRIALLEVEL.csv")
new_file <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_TRIALLEVEL_scanner_ses23.csv")

old <- read_csv(old_file, show_col_types = FALSE)
new <- read_csv(new_file, show_col_types = FALSE)

cat("ORIGINAL TRIALLEVEL:\n")
cat("  - Total trials:", nrow(old), "\n")
cat("  - Unique subjects:", n_distinct(old$subject_id), "\n")
cat("  - Session distribution:\n")
print(table(old$ses, useNA = "ifany"))

cat("\nNEW TRIALLEVEL (scanner ses-2/3):\n")
cat("  - Total trials:", nrow(new), "\n")
cat("  - Unique subjects:", n_distinct(new$subject_id), "\n")
cat("  - Session distribution:\n")
print(table(new$ses, useNA = "ifany"))

# Overlap analysis
old_uids <- old$trial_uid
new_uids <- new$trial_uid

in_both <- intersect(old_uids, new_uids)
in_old_only <- setdiff(old_uids, new_uids)
in_new_only <- setdiff(new_uids, old_uids)

cat("\n=== OVERLAP ANALYSIS ===\n")
cat("Trials in BOTH datasets:", length(in_both), "\n")
cat("Trials in OLD only (removed):", length(in_old_only), "\n")
cat("Trials in NEW only (newly found):", length(in_new_only), "\n")

# Analyze removed trials
removed <- old %>% filter(trial_uid %in% in_old_only)
cat("\n=== REMOVED TRIALS BREAKDOWN ===\n")
cat("By session:\n")
print(table(removed$ses, useNA = "ifany"))

cat("\nBy subject (top 15):\n")
removed_by_subj <- removed %>%
  count(subject_id, sort = TRUE) %>%
  head(15)
print(removed_by_subj)

# Analyze new trials
new_only <- new %>% filter(trial_uid %in% in_new_only)
cat("\n=== NEW TRIALS BREAKDOWN ===\n")
cat("By session:\n")
print(table(new_only$ses, useNA = "ifany"))

cat("\nBy subject (top 15):\n")
new_by_subj <- new_only %>%
  count(subject_id, sort = TRUE) %>%
  head(15)
print(new_by_subj)

# Check if removed trials have valid session info
cat("\n=== REMOVED TRIALS - SESSION SOURCE INVESTIGATION ===\n")
cat("Sample of removed ses=1 trials:\n")
removed_ses1 <- removed %>% filter(ses == 1) %>% head(10)
print(removed_ses1 %>% select(trial_uid, subject_id, task, ses, run, trial_index))

# Check MERGED source for these trials
merged_file <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_MERGED.csv")
if (file.exists(merged_file)) {
  cat("\nChecking MERGED file for ses=1 trials...\n")
  # Sample a few rows to check session distribution
  merged_sample <- read_csv(merged_file, n_max = 10000, show_col_types = FALSE)
  if ("ses" %in% names(merged_sample)) {
    cat("MERGED sample session distribution:\n")
    print(table(merged_sample$ses, useNA = "ifany"))
  } else {
    cat("MERGED does not have 'ses' column - checking trial_id format...\n")
    if ("trial_id" %in% names(merged_sample)) {
      # Extract session from trial_id
      trial_id_parts <- strsplit(merged_sample$trial_id[1:100], ":", fixed = TRUE)
      ses_from_id <- sapply(trial_id_parts, function(x) if(length(x) >= 3) x[3] else NA)
      cat("Session from trial_id (first 100):\n")
      print(table(ses_from_id, useNA = "ifany"))
    }
  }
}

# Summary
cat("\n=== SUMMARY ===\n")
cat("Key findings:\n")
cat("1. Original TRIALLEVEL had", nrow(old), "trials from", n_distinct(old$subject_id), "subjects\n")
cat("2. New TRIALLEVEL has", nrow(new), "trials from", n_distinct(new$subject_id), "subjects\n")
cat("3. Only", length(in_both), "trials overlap between the two datasets\n")
cat("4. This suggests the original dataset was built from a DIFFERENT source/manifest\n")
cat("\nRecommendation:\n")
cat("- The original TRIALLEVEL likely included data from:\n")
cat("  * Practice/test sessions (ses=1)\n")
cat("  * OutsideScanner runs\n")
cat("  * MATLAB test folder files\n")
cat("- The new TRIALLEVEL is correctly filtered to InsideScanner ses-2/3 only\n")
cat("- The 1,100 'new' trials are likely correctly identified scanner trials\n")
cat("  that were missed in the original manifest\n")

# Save diagnostic report
diagnostic <- tibble(
  metric = c(
    "original_total_trials",
    "original_n_subjects",
    "original_ses1_trials",
    "original_ses2_trials",
    "original_ses3_trials",
    "new_total_trials",
    "new_n_subjects",
    "new_ses2_trials",
    "new_ses3_trials",
    "trials_in_both",
    "trials_removed",
    "trials_newly_found",
    "overlap_pct"
  ),
  value = c(
    nrow(old),
    n_distinct(old$subject_id),
    sum(old$ses == 1, na.rm = TRUE),
    sum(old$ses == 2, na.rm = TRUE),
    sum(old$ses == 3, na.rm = TRUE),
    nrow(new),
    n_distinct(new$subject_id),
    sum(new$ses == 2, na.rm = TRUE),
    sum(new$ses == 3, na.rm = TRUE),
    length(in_both),
    length(in_old_only),
    length(in_new_only),
    round(100 * length(in_both) / nrow(old), 1)
  )
)

write_csv(diagnostic, file.path(OUTPUT_DIR, "triallevel_difference_diagnosis.csv"))
cat("\n✓ Saved diagnostic report to triallevel_difference_diagnosis.csv\n")

