#!/usr/bin/env Rscript

# ============================================================================
# Thorough Matching Diagnosis
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(arrow)
})

BEHAVIORAL_FILE <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"
MERGED_FILE <- "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM/data/analysis_ready/BAP_analysis_ready_MERGED_scanner_ses23.parquet"

cat("=== THOROUGH MATCHING DIAGNOSIS ===\n\n")

# Load data
beh <- read_csv(BEHAVIORAL_FILE, show_col_types = FALSE)
merged <- read_parquet(MERGED_FILE)

cat("1. RUN DISTRIBUTION:\n")
cat("Behavioral runs:", paste(sort(unique(beh$run_num)), collapse = ", "), "\n")
cat("MERGED runs:", paste(sort(unique(merged$run)), collapse = ", "), "\n\n")

cat("2. CHECKING IF RUN == SES IN MERGED:\n")
run_ses_combo <- merged %>%
  distinct(subject_id, task, ses, run) %>%
  mutate(run_equals_ses = (run == ses))

cat("Cases where run == ses:", sum(run_ses_combo$run_equals_ses), "\n")
cat("Cases where run != ses:", sum(!run_ses_combo$run_equals_ses), "\n")

if (any(!run_ses_combo$run_equals_ses)) {
  cat("\nCases where run != ses:\n")
  print(run_ses_combo %>% filter(!run_equals_ses) %>% head(10))
} else {
  cat("\n⚠️ ALL runs equal ses! This suggests run might be mislabeled as session.\n")
}

cat("\n3. MERGED RUN DISTRIBUTION BY SUBJECT×TASK×SES:\n")
run_dist <- merged %>%
  group_by(subject_id, task, ses) %>%
  summarise(
    runs = paste(sort(unique(run)), collapse = ","),
    n_runs = n_distinct(run),
    .groups = "drop"
  )

cat("Subjects with 1 run:", sum(run_dist$n_runs == 1), "\n")
cat("Subjects with 2 runs:", sum(run_dist$n_runs == 2), "\n")
cat("Subjects with 3+ runs:", sum(run_dist$n_runs >= 3), "\n\n")

cat("Sample run distributions:\n")
print(head(run_dist, 15))

cat("\n4. TESTING MATCH WITH DIFFERENT STRATEGIES:\n")

# Strategy 1: Exact match (current - fails)
beh_keys_exact <- beh %>%
  mutate(
    task = case_when(task_modality == "aud" ~ "ADT", task_modality == "vis" ~ "VDT", TRUE ~ task_modality)
  ) %>%
  distinct(subject_id, task, session_num, run_num, trial_num) %>%
  mutate(key = paste(subject_id, task, session_num, run_num, trial_num, sep = ":"))

merged_keys_exact <- merged %>%
  distinct(subject_id, task, ses, run, trial_index) %>%
  mutate(key = paste(subject_id, task, ses, run, trial_index, sep = ":"))

matches_exact <- length(intersect(beh_keys_exact$key, merged_keys_exact$key))
cat("Strategy 1 (exact match):", matches_exact, "matches\n")

# Strategy 2: Match ignoring run (treat MERGED run as potentially wrong)
beh_keys_no_run <- beh %>%
  mutate(
    task = case_when(task_modality == "aud" ~ "ADT", task_modality == "vis" ~ "VDT", TRUE ~ task_modality)
  ) %>%
  distinct(subject_id, task, session_num, trial_num) %>%
  mutate(key = paste(subject_id, task, session_num, trial_num, sep = ":"))

merged_keys_no_run <- merged %>%
  distinct(subject_id, task, ses, trial_index) %>%
  mutate(key = paste(subject_id, task, ses, trial_index, sep = ":"))

matches_no_run <- length(intersect(beh_keys_no_run$key, merged_keys_no_run$key))
cat("Strategy 2 (ignore run):", matches_no_run, "matches\n")

# Strategy 3: Match assuming MERGED run is actually session (if run==ses)
if (all(run_ses_combo$run_equals_ses)) {
  cat("Strategy 3: Cannot test - all runs equal ses\n")
} else {
  # Try matching where we use MERGED run as a wildcard
  cat("Strategy 3: Not applicable\n")
}

# Strategy 4: Match by (subject, task, ses) and check if trial numbers align
cat("\n5. CHECKING TRIAL NUMBER ALIGNMENT:\n")
# Pick a subject that exists in both
test_subjects <- intersect(unique(beh$subject_id), unique(merged$subject_id))[1:3]

for (subj in test_subjects) {
  beh_subj <- beh %>%
    filter(subject_id == subj, task_modality == "aud", session_num == 2) %>%
    arrange(run_num, trial_num) %>%
    distinct(subject_id, task_modality, session_num, run_num, trial_num)
  
  merged_subj <- merged %>%
    filter(subject_id == subj, task == "ADT", ses == 2) %>%
    arrange(run, trial_index) %>%
    distinct(subject_id, task, ses, run, trial_index)
  
  if (nrow(beh_subj) > 0 && nrow(merged_subj) > 0) {
    cat("\nSubject:", subj, "ADT ses2\n")
    cat("Behavioral trials:", nrow(beh_subj), "across runs", paste(unique(beh_subj$run_num), collapse = ","), "\n")
    cat("MERGED trials:", nrow(merged_subj), "with run values", paste(unique(merged_subj$run), collapse = ","), "\n")
    
    # Check if trial numbers overlap
    beh_trials <- unique(beh_subj$trial_num)
    merged_trials <- unique(merged_subj$trial_index)
    overlap_trials <- intersect(beh_trials, merged_trials)
    
    cat("Trial number overlap:", length(overlap_trials), "out of", 
        length(beh_trials), "behavioral and", length(merged_trials), "MERGED\n")
    
    if (length(overlap_trials) > 0) {
      cat("Overlapping trial numbers:", paste(head(overlap_trials, 10), collapse = ", "), "\n")
    }
  }
}

cat("\n=== RECOMMENDATION ===\n")
cat("If matches_no_run (", matches_no_run, ") >> matches_exact (", matches_exact, "),\n")
cat("then the issue is likely that MERGED run numbers don't match behavioral run_num.\n")
cat("Possible causes:\n")
cat("1. MERGED run was extracted incorrectly from filenames\n")
cat("2. MERGED run represents something different (e.g., file sequence, not actual run)\n")
cat("3. MERGED only contains a subset of runs (runs 2-3) and run numbers are correct\n")
cat("\nNext step: Match ignoring run, then investigate why run numbers differ.\n")

