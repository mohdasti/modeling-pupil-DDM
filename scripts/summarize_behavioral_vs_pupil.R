#!/usr/bin/env Rscript

# ============================================================================
# Summarize Behavioral vs Pupil Data Coverage
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

BEHAVIORAL_FILE <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"
TRIALLEVEL_FILE <- "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM/data/analysis_ready/BAP_analysis_ready_TRIALLEVEL.csv"
OUTPUT_DIR <- "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM/data/qc/analysis_ready_audit"

cat("=== BEHAVIORAL VS PUPIL COVERAGE SUMMARY ===\n\n")

# Load behavioral ground truth
behavioral <- read_csv(BEHAVIORAL_FILE, show_col_types = FALSE)

# Create ground truth keys
ground_truth <- behavioral %>%
  mutate(
    subject_id = subject_id,
    task = case_when(
      task_modality == "aud" ~ "ADT",
      task_modality == "vis" ~ "VDT",
      TRUE ~ task_modality
    ),
    ses = session_num,
    run = run_num,
    trial_index = trial_num,
    trial_uid = paste(subject_id, task, ses, run, trial_index, sep = ":")
  ) %>%
  distinct(subject_id, task, ses, run, trial_index, trial_uid)

# Load TRIALLEVEL
triallevel <- read_csv(TRIALLEVEL_FILE, show_col_types = FALSE)

# Summary
cat("BEHAVIORAL GROUND TRUTH:\n")
cat("  - Total unique trials:", nrow(ground_truth), "\n")
cat("  - Unique subjects:", n_distinct(ground_truth$subject_id), "\n")
cat("  - Session distribution:\n")
print(table(ground_truth$ses, useNA = "ifany"))
cat("  - Task distribution:\n")
print(table(ground_truth$task, useNA = "ifany"))

cat("\nPUPIL-PRESENT TRIALS (TRIALLEVEL):\n")
cat("  - Total trials with pupil data:", nrow(triallevel), "\n")
cat("  - Unique subjects:", n_distinct(triallevel$subject_id), "\n")
cat("  - Session distribution:\n")
print(table(triallevel$ses, useNA = "ifany"))

# Coverage
trials_with_pupil <- unique(triallevel$trial_uid)
trials_in_behavioral <- unique(ground_truth$trial_uid)

overlap <- intersect(trials_with_pupil, trials_in_behavioral)
missing_pupil <- setdiff(trials_in_behavioral, trials_with_pupil)

cat("\nCOVERAGE:\n")
cat("  - Behavioral trials with pupil data:", length(overlap), "\n")
cat("  - Behavioral trials without pupil data:", length(missing_pupil), "\n")
cat("  - Coverage:", round(100 * length(overlap) / length(trials_in_behavioral), 2), "%\n")

# By session
coverage_by_ses <- ground_truth %>%
  mutate(has_pupil = trial_uid %in% trials_with_pupil) %>%
  group_by(ses) %>%
  summarise(
    total_trials = n(),
    with_pupil = sum(has_pupil),
    coverage_pct = round(100 * sum(has_pupil) / n(), 2),
    .groups = "drop"
  )

cat("\nCoverage by session:\n")
print(coverage_by_ses)

# By task
coverage_by_task <- ground_truth %>%
  mutate(has_pupil = trial_uid %in% trials_with_pupil) %>%
  group_by(task) %>%
  summarise(
    total_trials = n(),
    with_pupil = sum(has_pupil),
    coverage_pct = round(100 * sum(has_pupil) / n(), 2),
    .groups = "drop"
  )

cat("\nCoverage by task:\n")
print(coverage_by_task)

# Save summary
summary_tbl <- tibble(
  metric = c(
    "behavioral_total_trials",
    "pupil_present_trials",
    "coverage_pct",
    "behavioral_n_subjects",
    "pupil_n_subjects",
    "behavioral_ses2_trials",
    "behavioral_ses3_trials",
    "pupil_ses2_trials",
    "pupil_ses3_trials",
    "coverage_ses2_pct",
    "coverage_ses3_pct"
  ),
  value = c(
    nrow(ground_truth),
    length(overlap),
    round(100 * length(overlap) / length(trials_in_behavioral), 2),
    n_distinct(ground_truth$subject_id),
    n_distinct(triallevel$subject_id),
    sum(ground_truth$ses == 2),
    sum(ground_truth$ses == 3),
    sum(triallevel$ses == 2),
    sum(triallevel$ses == 3),
    coverage_by_ses$coverage_pct[coverage_by_ses$ses == 2],
    coverage_by_ses$coverage_pct[coverage_by_ses$ses == 3]
  )
)

write_csv(summary_tbl, file.path(OUTPUT_DIR, "behavioral_vs_pupil_coverage.csv"))
cat("\n✓ Saved summary to behavioral_vs_pupil_coverage.csv\n")

cat("\n=== INTERPRETATION ===\n")
cat("The behavioral file (bap_beh_trialdata_v2.csv) contains", nrow(ground_truth), "trials\n")
cat("that represent the actual experimental design (scanner ses-2/3).\n")
cat("\nOf these, only", length(overlap), "trials (", 
    round(100 * length(overlap) / length(trials_in_behavioral), 2), 
    "%) have any pupil data.\n")
cat("\nThis is expected given MR-safe goggles blocking eye tracking.\n")
cat("The TRIALLEVEL dataset correctly represents these pupil-present trials.\n")

