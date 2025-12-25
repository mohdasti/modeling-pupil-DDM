#!/usr/bin/env Rscript

# ============================================================================
# Identify Canonical Sessions per Subject×Task
# ============================================================================
# Selects the "real task session" (typically ses 2 or 3) for each subject×task
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
RAW_MANIFEST <- file.path(COVERAGE_DIR, "raw_manifest.csv")
OUTPUT_FILE <- file.path(COVERAGE_DIR, "canonical_session_by_subject_task.csv")

cat("=== IDENTIFYING CANONICAL SESSIONS ===\n\n")

# ============================================================================
# Load Raw Manifest
# ============================================================================

cat("Loading raw manifest...\n")
raw_manifest <- read_csv(RAW_MANIFEST, show_col_types = FALSE)
cat("Loaded", nrow(raw_manifest), "raw files\n\n")

# ============================================================================
# Step 1: Restrict to runs in {1,2,3,4,5}
# ============================================================================

cat("Step 1: Restricting to runs 1-5\n")
cat("--------------------------------\n")

raw_filtered <- raw_manifest %>%
  filter(run %in% c(1, 2, 3, 4, 5))

cat("Files after filtering to runs 1-5:", nrow(raw_filtered), "\n")
cat("Files removed:", nrow(raw_manifest) - nrow(raw_filtered), "\n\n")

# ============================================================================
# Step 2: Compute stats per (subject_id, task, ses)
# ============================================================================

cat("Step 2: Computing stats per (subject_id, task, ses)\n")
cat("----------------------------------------------------\n")

session_stats <- raw_filtered %>%
  group_by(subject_id, task, ses) %>%
  summarise(
    n_unique_runs = n_distinct(run),
    n_files = n(),
    runs = paste(sort(unique(run)), collapse = ","),
    .groups = "drop"
  ) %>%
  arrange(subject_id, task, ses)

cat("Found", nrow(session_stats), "unique (subject_id, task, ses) combinations\n\n")

# Show sample
cat("Sample of session stats:\n")
print(head(session_stats, 10))
cat("\n")

# ============================================================================
# Step 3: Choose canonical session per (subject_id, task)
# ============================================================================

cat("Step 3: Choosing canonical session per (subject_id, task)\n")
cat("----------------------------------------------------------\n")

canonical_sessions <- session_stats %>%
  group_by(subject_id, task) %>%
  arrange(
    desc(n_unique_runs),  # Max unique runs first
    desc(n_files),         # Then max files
    desc(ses %in% c(2, 3)), # Prefer ses 2 or 3
    desc(ses)              # Then higher ses
  ) %>%
  slice_head(n = 1) %>%
  ungroup() %>%
  select(subject_id, task, canonical_ses = ses, n_unique_runs, n_files, runs) %>%
  arrange(subject_id, task)

cat("Selected canonical sessions for", nrow(canonical_sessions), "subject×task combinations\n\n")

# Show sample
cat("Sample of canonical sessions:\n")
print(head(canonical_sessions, 10))
cat("\n")

# ============================================================================
# Step 4: Report ses=1 selections
# ============================================================================

cat("Step 4: Reporting ses=1 selections\n")
cat("-----------------------------------\n")

ses1_selections <- canonical_sessions %>%
  filter(canonical_ses == 1)

n_ses1 <- nrow(ses1_selections)
n_total <- nrow(canonical_sessions)
ses1_pct <- round(100 * n_ses1 / n_total, 2)

cat("Subject×task pairs with canonical_ses = 1:", n_ses1, "\n")
cat("Total subject×task pairs:", n_total, "\n")
cat("Percentage with ses=1:", ses1_pct, "%\n\n")

if (n_ses1 > 0) {
  cat("⚠ WARNING: Found", n_ses1, "subject×task pairs with ses=1 (should be near zero)\n")
  cat("\nSubject×task pairs with ses=1:\n")
  print(ses1_selections)
  cat("\n")
  
  # Show why ses=1 was chosen (check if it had more runs/files)
  ses1_details <- session_stats %>%
    semi_join(ses1_selections, by = c("subject_id", "task")) %>%
    group_by(subject_id, task) %>%
    arrange(desc(n_unique_runs), desc(n_files)) %>%
    slice_head(n = 3) %>%
    ungroup()
  
  cat("Session options for ses=1 cases (showing top 3 per subject×task):\n")
  print(ses1_details)
  cat("\n")
} else {
  cat("✓ No subject×task pairs selected ses=1\n\n")
}

# ============================================================================
# Summary Statistics
# ============================================================================

cat("Summary Statistics:\n")
cat("-------------------\n")

# Distribution of canonical sessions
ses_distribution <- canonical_sessions %>%
  count(canonical_ses, name = "n_subject_task_pairs") %>%
  arrange(desc(n_subject_task_pairs))

cat("Distribution of canonical sessions:\n")
print(ses_distribution)
cat("\n")

# Stats on runs per canonical session
runs_summary <- canonical_sessions %>%
  group_by(canonical_ses) %>%
  summarise(
    mean_runs = mean(n_unique_runs),
    median_runs = median(n_unique_runs),
    min_runs = min(n_unique_runs),
    max_runs = max(n_unique_runs),
    .groups = "drop"
  )

cat("Runs per canonical session:\n")
print(runs_summary)
cat("\n")

# ============================================================================
# Save Output
# ============================================================================

cat("Saving output...\n")
write_csv(canonical_sessions, OUTPUT_FILE)
cat("✓ Saved canonical_session_by_subject_task.csv\n\n")

cat("=== SUMMARY ===\n")
cat("Total subject×task pairs:", n_total, "\n")
cat("Canonical sessions selected:\n")
for (i in 1:nrow(ses_distribution)) {
  cat("  - ses", ses_distribution$canonical_ses[i], ":", ses_distribution$n_subject_task_pairs[i], "pairs\n")
}
cat("\nSubject×task pairs with ses=1:", n_ses1, "(", ses1_pct, "%)\n")
if (n_ses1 > 0) {
  cat("⚠ This should be near zero - review these cases\n")
} else {
  cat("✓ All canonical sessions are ses 2 or higher\n")
}

cat("\n✓ Analysis complete!\n")

