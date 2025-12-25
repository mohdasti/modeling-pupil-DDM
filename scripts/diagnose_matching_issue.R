#!/usr/bin/env Rscript

# ============================================================================
# Diagnose Matching Issue Between Behavioral and MERGED
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(arrow)
})

BEHAVIORAL_FILE <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"
MERGED_FILE <- "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM/data/analysis_ready/BAP_analysis_ready_MERGED_scanner_ses23.parquet"

cat("=== MATCHING DIAGNOSIS ===\n\n")

# Load data
beh <- read_csv(BEHAVIORAL_FILE, show_col_types = FALSE)
merged <- read_parquet(MERGED_FILE)

cat("1. RUN DISTRIBUTION (CRITICAL):\n")
cat("Behavioral runs:", paste(sort(unique(beh$run_num)), collapse = ", "), "\n")
cat("MERGED runs:", paste(sort(unique(merged$run)), collapse = ", "), "\n")
cat("\n⚠️ ISSUE: MERGED only has runs 2-3, but behavioral has runs 1-5!\n\n")

cat("2. TRIAL NUMBERING SCHEME:\n")
cat("Behavioral trial_num range:", min(beh$trial_num, na.rm = TRUE), "to", max(beh$trial_num, na.rm = TRUE), "\n")
cat("MERGED trial_index range:", min(merged$trial_index, na.rm = TRUE), "to", max(merged$trial_index, na.rm = TRUE), "\n")
cat("\n⚠️ ISSUE: MERGED trial_index goes up to 92, but behavioral trial_num only 1-30!\n")
cat("This suggests MERGED trial_index might be cumulative or use different scheme.\n\n")

# Check specific subject
cat("3. EXAMPLE: BAP001, ADT, ses2\n")
beh_bap001 <- beh %>%
  filter(subject_id == "BAP001", task_modality == "aud", session_num == 2) %>%
  arrange(run_num, trial_num)

merged_bap001 <- merged %>%
  filter(subject_id == "BAP001", task == "ADT", ses == 2) %>%
  arrange(run, trial_index)

cat("Behavioral - trials by run:\n")
print(beh_bap001 %>%
  group_by(run_num) %>%
  summarise(
    min_trial = min(trial_num),
    max_trial = max(trial_num),
    n_trials = n(),
    .groups = "drop"
  ))

cat("\nMERGED - trials by run:\n")
print(merged_bap001 %>%
  group_by(run) %>%
  summarise(
    min_trial = min(trial_index),
    max_trial = max(trial_index),
    n_trials = n(),
    .groups = "drop"
  ))

# Check if trial_index is cumulative across runs
cat("\n4. CHECKING IF trial_index IS CUMULATIVE:\n")
merged_test <- merged %>%
  filter(subject_id == "BAP001", task == "ADT", ses == 2) %>%
  arrange(run, trial_index)

if (nrow(merged_test) > 0) {
  cat("First few MERGED trial_index values by run:\n")
  for (r in unique(merged_test$run)) {
    trials_in_run <- merged_test %>% filter(run == r) %>% pull(trial_index) %>% head(5)
    cat("  Run", r, ":", paste(trials_in_run, collapse = ", "), "\n")
  }
  
  # Check if trial_index resets per run or is cumulative
  run1_max <- if(1 %in% merged_test$run) max(merged_test$trial_index[merged_test$run == 1]) else 0
  run2_min <- if(2 %in% merged_test$run) min(merged_test$trial_index[merged_test$run == 2]) else NA
  
  if (!is.na(run2_min) && run2_min > run1_max) {
    cat("\n⚠️ trial_index appears CUMULATIVE (doesn't reset per run)\n")
    cat("   Run 1 max:", run1_max, ", Run 2 min:", run2_min, "\n")
  } else {
    cat("\n✓ trial_index appears to reset per run\n")
  }
}

# Check for duplicates in behavioral
cat("\n5. BEHAVIORAL FILE DUPLICATES:\n")
beh_unique <- beh %>%
  distinct(subject_id, task_modality, session_num, run_num, trial_num)

cat("Behavioral total rows:", nrow(beh), "\n")
cat("Behavioral unique (subj×task×ses×run×trial):", nrow(beh_unique), "\n")
cat("Duplicates:", nrow(beh) - nrow(beh_unique), "\n")

if (nrow(beh) != nrow(beh_unique)) {
  cat("\n⚠️ Behavioral file has", nrow(beh) - nrow(beh_unique), "duplicate rows!\n")
  cat("Sample duplicates:\n")
  duplicates <- beh %>%
    group_by(subject_id, task_modality, session_num, run_num, trial_num) %>%
    filter(n() > 1) %>%
    slice_head(n = 1) %>%
    ungroup() %>%
    head(5)
  print(duplicates %>% select(subject_id, task_modality, session_num, run_num, trial_num))
}

# Try matching without run constraint
cat("\n6. MATCHING WITHOUT RUN CONSTRAINT:\n")
beh_keys_no_run <- beh_unique %>%
  mutate(
    task = case_when(
      task_modality == "aud" ~ "ADT",
      task_modality == "vis" ~ "VDT",
      TRUE ~ task_modality
    )
  ) %>%
  distinct(subject_id, task, session_num, trial_num)

merged_keys_no_run <- merged %>%
  distinct(subject_id, task, ses, trial_index)

# Match on subject, task, ses, trial (ignoring run)
matches_no_run <- beh_keys_no_run %>%
  inner_join(
    merged_keys_no_run,
    by = c("subject_id" = "subject_id", 
           "task" = "task",
           "session_num" = "ses",
           "trial_num" = "trial_index")
  )

cat("Matches when ignoring run:", nrow(matches_no_run), "\n")
cat("This suggests trial numbering might match, but run numbers don't!\n")

cat("\n=== RECOMMENDATION ===\n")
cat("The issue is likely:\n")
cat("1. MERGED only has runs 2-3, missing runs 1, 4, 5\n")
cat("2. Trial numbering scheme might differ (cumulative vs per-run)\n")
cat("3. Need to verify if trial_index in MERGED corresponds to trial_num in behavioral\n")
cat("   when matched by (subject, task, ses) regardless of run\n")

