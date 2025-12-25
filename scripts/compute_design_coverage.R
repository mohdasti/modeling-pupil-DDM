#!/usr/bin/env Rscript

# ============================================================================
# Compute Design Coverage: Expected vs Observed
# ============================================================================
# Compares expected design counts with observed processed data
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

# ============================================================================
# Configuration
# ============================================================================

BASE_DIR <- "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM"
COVERAGE_DIR <- file.path(BASE_DIR, "data/qc/coverage")
PROCESSED_MANIFEST <- file.path(COVERAGE_DIR, "processed_manifest.csv")
TRIALLEVEL_FILE <- file.path(BASE_DIR, "data/analysis_ready/BAP_analysis_ready_TRIALLEVEL.csv")

cat("=== COMPUTING DESIGN COVERAGE ===\n\n")

# ============================================================================
# Load Data
# ============================================================================

cat("Loading manifests...\n")
processed_manifest <- read_csv(PROCESSED_MANIFEST, show_col_types = FALSE)
cat("Loaded processed manifest:", nrow(processed_manifest), "units\n\n")

# Also load TRIALLEVEL for trial counts
trial_level <- read_csv(TRIALLEVEL_FILE, show_col_types = FALSE, progress = FALSE)
cat("Loaded TRIALLEVEL:", nrow(trial_level), "trials\n\n")

# ============================================================================
# A) Compute Expected Counts
# ============================================================================

cat("A) Computing expected counts under design\n")
cat("------------------------------------------\n")

# Count unique subjects in processed data
n_subjects_processed <- n_distinct(processed_manifest$subject_id)
cat("Number of subjects in processed data:", n_subjects_processed, "\n")

# Design assumptions
n_tasks <- 2  # ADT and VDT
n_runs_per_design <- 5
n_trials_per_subject_task <- 150  # Typical design assumption

# Compute expected
expected_units <- n_subjects_processed * n_tasks * n_runs_per_design
expected_trials <- n_subjects_processed * n_tasks * n_trials_per_subject_task

cat("Design assumptions:\n")
cat("  - Tasks per subject:", n_tasks, "\n")
cat("  - Runs per subject×task:", n_runs_per_design, "\n")
cat("  - Trials per subject×task:", n_trials_per_subject_task, "\n\n")

cat("Expected counts:\n")
cat("  - Expected units (subject×task×ses×run):", expected_units, "\n")
cat("  - Expected trials:", expected_trials, "\n\n")

# ============================================================================
# B) Compute Observed Counts
# ============================================================================

cat("B) Computing observed counts from processed data\n")
cat("-------------------------------------------------\n")

# Observed units
observed_units <- nrow(processed_manifest)
cat("Observed units:", observed_units, "\n")

# Observed trials (from processed_manifest)
observed_trials_from_manifest <- sum(processed_manifest$n_trials, na.rm = TRUE)
cat("Observed trials (from manifest):", observed_trials_from_manifest, "\n")

# Also check TRIALLEVEL directly
observed_trials_from_triallevel <- nrow(trial_level)
cat("Observed trials (from TRIALLEVEL):", observed_trials_from_triallevel, "\n\n")

# Use TRIALLEVEL count as ground truth
observed_trials <- observed_trials_from_triallevel

# ============================================================================
# C) Compute Coverage Percentages
# ============================================================================

cat("C) Computing coverage percentages\n")
cat("----------------------------------\n")

units_coverage_pct <- round(100 * observed_units / expected_units, 2)
trials_coverage_pct <- round(100 * observed_trials / expected_trials, 2)

cat("Coverage:\n")
cat("  - Units: ", observed_units, " / ", expected_units, " (", units_coverage_pct, "%)\n", sep = "")
cat("  - Trials: ", observed_trials, " / ", expected_trials, " (", trials_coverage_pct, "%)\n\n", sep = "")

# ============================================================================
# Trials per Subject×Task Summary
# ============================================================================

cat("Computing trials per subject×task summary...\n")

trials_per_subject_task <- trial_level %>%
  group_by(subject_id, task) %>%
  summarise(
    n_trials = n(),
    .groups = "drop"
  )

trials_summary <- trials_per_subject_task %>%
  summarise(
    min_trials = min(n_trials),
    median_trials = median(n_trials),
    max_trials = max(n_trials),
    mean_trials = mean(n_trials),
    sd_trials = sd(n_trials),
    n_subject_task_combos = n()
  )

cat("\nTrials per subject×task:\n")
cat("  - Min:", trials_summary$min_trials, "\n")
cat("  - Median:", trials_summary$median_trials, "\n")
cat("  - Max:", trials_summary$max_trials, "\n")
cat("  - Mean:", round(trials_summary$mean_trials, 1), "\n")
cat("  - SD:", round(trials_summary$sd_trials, 1), "\n")
cat("  - Total subject×task combinations:", trials_summary$n_subject_task_combos, "\n\n")

# ============================================================================
# Create Summary Tables
# ============================================================================

# Expected vs Observed table
expected_vs_observed <- tibble(
  metric = c("units", "trials"),
  expected = c(expected_units, expected_trials),
  observed = c(observed_units, observed_trials),
  coverage_pct = c(units_coverage_pct, trials_coverage_pct),
  missing = c(expected_units - observed_units, expected_trials - observed_trials),
  missing_pct = c(round(100 * (expected_units - observed_units) / expected_units, 2),
                  round(100 * (expected_trials - observed_trials) / expected_trials, 2))
)

cat("Expected vs Observed Summary:\n")
print(expected_vs_observed)
cat("\n")

# Trials per subject×task (detailed)
trials_per_subject_task_detailed <- trials_per_subject_task %>%
  arrange(subject_id, task) %>%
  mutate(
    expected_trials_per_combo = n_trials_per_subject_task,
    coverage_pct = round(100 * n_trials / expected_trials_per_combo, 2)
  )

# ============================================================================
# Save Outputs
# ============================================================================

cat("Saving output files...\n")

# Save expected vs observed
write_csv(expected_vs_observed, file.path(COVERAGE_DIR, "design_expected_vs_observed.csv"))
cat("✓ Saved design_expected_vs_observed.csv\n")

# Save trials per subject×task
write_csv(trials_per_subject_task_detailed, file.path(COVERAGE_DIR, "trials_per_subject_task_observed.csv"))
cat("✓ Saved trials_per_subject_task_observed.csv\n\n")

# ============================================================================
# Additional Analysis
# ============================================================================

cat("Additional analysis:\n")
cat("--------------------\n")

# Check if all subjects have both tasks
subjects_by_task <- trial_level %>%
  group_by(subject_id) %>%
  summarise(
    tasks = paste(sort(unique(task)), collapse = ", "),
    n_tasks = n_distinct(task),
    .groups = "drop"
  )

subjects_both_tasks <- sum(subjects_by_task$n_tasks == 2)
subjects_one_task <- sum(subjects_by_task$n_tasks == 1)

cat("Subjects with both tasks (ADT + VDT):", subjects_both_tasks, "\n")
cat("Subjects with one task only:", subjects_one_task, "\n")

# Check runs per subject×task
runs_per_subject_task <- processed_manifest %>%
  group_by(subject_id, task) %>%
  summarise(
    n_runs = n(),
    runs = paste(sort(unique(run)), collapse = ", "),
    .groups = "drop"
  )

runs_summary <- runs_per_subject_task %>%
  summarise(
    min_runs = min(n_runs),
    median_runs = median(n_runs),
    max_runs = max(n_runs),
    mean_runs = mean(n_runs)
  )

cat("\nRuns per subject×task:\n")
cat("  - Min:", runs_summary$min_runs, "\n")
cat("  - Median:", runs_summary$median_runs, "\n")
cat("  - Max:", runs_summary$max_runs, "\n")
cat("  - Mean:", round(runs_summary$mean_runs, 1), "\n\n")

cat("✓ Analysis complete!\n")

