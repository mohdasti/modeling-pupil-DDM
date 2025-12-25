# ============================================================================
# Diagnostic Script: Why did the preprocessing merge fail for recoverable trials?
# ============================================================================
# This script investigates why 131 recoverable trials failed to merge during
# preprocessing, so we can fix the merge logic.
# ============================================================================

library(dplyr)
library(readr)

cat("=== DIAGNOSING MERGE FAILURES ===\n\n")

# Set paths (same as previous script)
processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
behavioral_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"

# Load one example merged file to check structure
flat_files_merged <- list.files(processed_dir, pattern = "_flat_merged\\.csv$", full.names = TRUE)
if (length(flat_files_merged) == 0) stop("No merged files found")

# Load behavioral data
behavioral <- read_csv(behavioral_file, show_col_types = FALSE) %>%
  mutate(
    sub_behav = as.character(subject_id),
    task_behav = case_when(
      task_modality == "aud" ~ "ADT",
      task_modality == "vis" ~ "VDT",
      TRUE ~ as.character(task_modality)
    ),
    run_behav = run_num,
    trial_index_behav = trial_num,
    trial_in_run_behav = trial_num,  # Behavioral trial_num is the within-run trial number
    gf_trPer_behav = grip_targ_prop_mvc,
    stimLev_behav = stim_level_index,
    isOddball_behav = as.integer(stim_is_diff)
  ) %>%
  group_by(sub_behav, task_behav, run_behav, trial_index_behav) %>%
  summarise(
    trial_in_run_behav = first(na.omit(trial_in_run_behav)),
    gf_trPer_behav = first(na.omit(gf_trPer_behav)),
    stimLev_behav = first(na.omit(stimLev_behav)),
    isOddball_behav = first(na.omit(isOddball_behav)),
    .groups = "drop"
  )

# Focus on subjects with recoverable trials (from previous diagnostic)
recoverable_subjects <- c("BAP147", "BAP183", "BAP171", "BAP157", "BAP166")

cat("Investigating merge failures for recoverable trials...\n\n")

for (subj in recoverable_subjects) {
  cat(sprintf("\n=== SUBJECT: %s ===\n", subj))
  
  # Find merged file for this subject
  subj_files <- flat_files_merged[grepl(subj, basename(flat_files_merged))]
  if (length(subj_files) == 0) {
    cat("  No merged files found\n")
    next
  }
  
  # Load merged file
  merged_data <- read_csv(subj_files[1], show_col_types = FALSE)
  
  # Get behavioral data for this subject
  behav_subj <- behavioral %>% filter(sub_behav == subj)
  
  if (nrow(behav_subj) == 0) {
    cat("  No behavioral data found\n")
    next
  }
  
  # Normalize merged data columns
  merged_norm <- merged_data %>%
    mutate(
      sub = if ("sub" %in% names(.)) as.character(sub) else if ("subject_id" %in% names(.)) as.character(subject_id) else NA_character_,
      task = if ("task" %in% names(.)) {
        case_when(
          task == "aud" ~ "ADT",
          task == "vis" ~ "VDT",
          TRUE ~ as.character(task)
        )
      } else NA_character_,
      run = if ("run" %in% names(.)) run else if ("run_num" %in% names(.)) run_num else NA_integer_,
      trial_index = coalesce(
        if ("trial_index" %in% names(.)) trial_index else NA_integer_,
        if ("trial" %in% names(.)) trial else NA_integer_
      ),
      trial_in_run = if ("trial_in_run" %in% names(.)) trial_in_run else NA_integer_,
      has_behavioral_data = if ("has_behavioral_data" %in% names(.)) has_behavioral_data else NA,
      gf_trPer = coalesce(
        if ("gf_trPer" %in% names(.)) gf_trPer else NA_real_,
        if ("grip_targ_prop_mvc" %in% names(.)) grip_targ_prop_mvc else NA_real_
      )
    ) %>%
    filter(!is.na(sub), !is.na(task), !is.na(run)) %>%
    distinct(sub, task, run, trial_index, trial_in_run, .keep_all = TRUE)
  
  # Check which trials are missing behavioral data
  missing_behav <- merged_norm %>%
    filter(is.na(has_behavioral_data) | !has_behavioral_data | is.na(gf_trPer))
  
  if (nrow(missing_behav) == 0) {
    cat("  All trials have behavioral data - no issues\n")
    next
  }
  
  cat(sprintf("  Trials in merged file: %d\n", nrow(merged_norm)))
  cat(sprintf("  Trials missing behavioral data: %d\n", nrow(missing_behav)))
  
  # Try to match missing trials with behavioral data using different keys
  cat("\n  Attempting matches:\n")
  
  # Method 1: (run, trial_in_run) - what preprocessing uses
  match1 <- missing_behav %>%
    left_join(
      behav_subj,
      by = c("task" = "task_behav", "run" = "run_behav", "trial_in_run" = "trial_in_run_behav")
    )
  n_match1 <- sum(!is.na(match1$gf_trPer_behav))
  cat(sprintf("    Method 1 (run, trial_in_run): %d matches\n", n_match1))
  
  # Method 2: (run, trial_index) - what diagnostic uses
  match2 <- missing_behav %>%
    left_join(
      behav_subj,
      by = c("task" = "task_behav", "run" = "run_behav", "trial_index" = "trial_index_behav")
    )
  n_match2 <- sum(!is.na(match2$gf_trPer_behav))
  cat(sprintf("    Method 2 (run, trial_index): %d matches\n", n_match2))
  
  # Method 3: Check if trial_in_run exists and is valid
  cat(sprintf("    trial_in_run available: %d/%d (%.1f%%)\n",
              sum(!is.na(missing_behav$trial_in_run)), nrow(missing_behav),
              100 * mean(!is.na(missing_behav$trial_in_run))))
  
  # Show examples of mismatches
  if (n_match2 > n_match1) {
    cat("\n  ⚠️  ISSUE FOUND: Method 2 (trial_index) finds more matches than Method 1 (trial_in_run)\n")
    cat("     This suggests trial_in_run may not align with behavioral trial_num\n")
    
    # Show specific examples
    examples <- match2 %>%
      filter(!is.na(gf_trPer_behav) & (is.na(trial_in_run) | is.na(match1$gf_trPer_behav))) %>%
      select(sub, task, run, trial_index, trial_in_run, gf_trPer_behav) %>%
      head(5)
    
    if (nrow(examples) > 0) {
      cat("\n  Example mismatches:\n")
      print(examples)
    }
  }
  
  # Check run alignment
  pupil_runs <- unique(merged_norm$run)
  behav_runs <- unique(behav_subj$run_behav)
  cat(sprintf("\n  Run alignment:\n"))
  cat(sprintf("    Pupil runs: %s\n", paste(sort(pupil_runs), collapse = ", ")))
  cat(sprintf("    Behavioral runs: %s\n", paste(sort(behav_runs), collapse = ", ")))
  cat(sprintf("    Overlapping runs: %d\n", length(intersect(pupil_runs, behav_runs))))
}

cat("\n=== DIAGNOSIS COMPLETE ===\n")
cat("\nRECOMMENDATIONS:\n")
cat("  1. If Method 2 (trial_index) finds more matches, the merge should use trial_index instead of trial_in_run\n")
cat("  2. If trial_in_run is often NA, the MATLAB pipeline may not be exporting it correctly\n")
cat("  3. If runs don't align, there may be a run numbering mismatch\n")

