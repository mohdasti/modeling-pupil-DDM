#!/usr/bin/env Rscript

# ============================================================================
# Investigate Original vs New Dataset
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(arrow)
})

cat("=== INVESTIGATING ORIGINAL VS NEW DATASET ===\n\n")

# Check original TRIALLEVEL (before our changes)
original_file <- "data/analysis_ready/BAP_analysis_ready_TRIALLEVEL_scanner_ses23.csv"
new_file <- "data/analysis_ready/BAP_analysis_ready_TRIALLEVEL.csv"
behavioral_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"

if (file.exists(original_file)) {
  cat("1. ORIGINAL TRIALLEVEL (scanner_ses23):\n")
  cat("----------------------------------------\n")
  orig <- read_csv(original_file, show_col_types = FALSE)
  cat("Total trials:", nrow(orig), "\n")
  cat("Unique subjects:", n_distinct(orig$subject_id), "\n")
  cat("Sessions:", paste(sort(unique(orig$ses)), collapse = ", "), "\n")
  cat("Runs:", paste(sort(unique(orig$run)), collapse = ", "), "\n")
  cat("Tasks:", paste(sort(unique(orig$task)), collapse = ", "), "\n\n")
  
  # Check trial_uid format
  if ("trial_uid" %in% names(orig)) {
    cat("Sample trial_uid from original:\n")
    print(head(unique(orig$trial_uid), 5))
  } else if ("trial_id" %in% names(orig)) {
    cat("Sample trial_id from original:\n")
    print(head(unique(orig$trial_id), 5))
  }
  cat("\n")
} else {
  cat("1. Original file not found:", original_file, "\n\n")
}

# Check new TRIALLEVEL
if (file.exists(new_file)) {
  cat("2. NEW TRIALLEVEL (after our changes):\n")
  cat("--------------------------------------\n")
  new <- read_csv(new_file, show_col_types = FALSE)
  cat("Total trials:", nrow(new), "\n")
  cat("Unique subjects:", n_distinct(new$subject_id), "\n")
  cat("Sessions:", paste(sort(unique(new$ses)), collapse = ", "), "\n")
  cat("Runs:", paste(sort(unique(new$run)), collapse = ", "), "\n")
  cat("Tasks:", paste(sort(unique(new$task)), collapse = ", "), "\n\n")
  
  if ("trial_uid" %in% names(new)) {
    cat("Sample trial_uid from new:\n")
    print(head(unique(new$trial_uid), 5))
  }
  cat("\n")
}

# Compare if both exist
if (file.exists(original_file) && file.exists(new_file)) {
  cat("3. COMPARISON:\n")
  cat("-------------\n")
  
  # Create comparable keys
  if ("trial_uid" %in% names(orig) && "trial_uid" %in% names(new)) {
    orig_keys <- unique(orig$trial_uid)
    new_keys <- unique(new$trial_uid)
    
    cat("Original unique trials:", length(orig_keys), "\n")
    cat("New unique trials:", length(new_keys), "\n")
    cat("Overlap:", length(intersect(orig_keys, new_keys)), "\n")
    cat("Only in original:", length(setdiff(orig_keys, new_keys)), "\n")
    cat("Only in new:", length(setdiff(new_keys, orig_keys)), "\n\n")
    
    # Check what's missing
    missing_from_new <- setdiff(orig_keys, new_keys)
    if (length(missing_from_new) > 0) {
      cat("Sample trials missing from new dataset:\n")
      print(head(missing_from_new, 10))
      cat("\n")
    }
  }
}

# Check behavioral ground truth
cat("4. BEHAVIORAL GROUND TRUTH:\n")
cat("---------------------------\n")
beh <- read_csv(behavioral_file, show_col_types = FALSE)
beh_keys <- beh %>%
  mutate(
    task = case_when(
      task_modality == "aud" ~ "ADT",
      task_modality == "vis" ~ "VDT",
      TRUE ~ task_modality
    )
  ) %>%
  distinct(subject_id, task, session_num, run_num, trial_num) %>%
  mutate(trial_uid = paste(subject_id, task, session_num, run_num, trial_num, sep = ":"))

cat("Behavioral unique trials:", nrow(beh_keys), "\n")
cat("Sessions:", paste(sort(unique(beh_keys$session_num)), collapse = ", "), "\n")
cat("Runs:", paste(sort(unique(beh_keys$run_num)), collapse = ", "), "\n\n")

# Check what MERGED actually contains (before filtering)
cat("5. MERGED (before filtering) - what trials does it actually have?\n")
cat("----------------------------------------------------------------\n")
merged_backup <- "data/analysis_ready/BAP_analysis_ready_MERGED_scanner_ses23.parquet"
if (file.exists(merged_backup)) {
  merged <- read_parquet(merged_backup)
  
  # Create trial keys from MERGED
  merged_trials <- merged %>%
    distinct(subject_id, task, ses, run, trial_index) %>%
    mutate(
      # Try to create trial_uid - but run might be wrong
      trial_uid_w_run = paste(subject_id, task, ses, run, trial_index, sep = ":"),
      trial_uid_no_run = paste(subject_id, task, ses, trial_index, sep = ":")
    )
  
  cat("MERGED unique (subject×task×ses×run×trial):", nrow(merged_trials), "\n")
  cat("MERGED sessions:", paste(sort(unique(merged$ses)), collapse = ", "), "\n")
  cat("MERGED runs:", paste(sort(unique(merged$run)), collapse = ", "), "\n")
  cat("\n⚠️ Remember: MERGED 'run' equals 'ses' (it's mislabeled)\n\n")
  
  # Try matching MERGED to behavioral (ignoring run)
  merged_match_no_run <- merged_trials %>%
    mutate(
      task = case_when(
        task == "aud" ~ "ADT",
        task == "vis" ~ "VDT",
        TRUE ~ task
      )
    ) %>%
    inner_join(
      beh_keys %>% mutate(ses = session_num),
      by = c("subject_id", "task", "ses", "trial_index" = "trial_num")
    )
  
  cat("MERGED trials that match behavioral (ignoring run):", nrow(merged_match_no_run), "\n")
  cat("This is what we should have in the final dataset!\n\n")
}

cat("=== KEY QUESTION ===\n")
cat("If practice sessions had NO eye tracker, they shouldn't be in MERGED at all.\n")
cat("So the original 3,357 trials should ALL be valid scanner sessions.\n")
cat("Why are we only getting 1,809 now? Are we being too restrictive?\n")

