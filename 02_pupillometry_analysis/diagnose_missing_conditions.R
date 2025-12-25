# ============================================================================
# Diagnostic Script: Check if Missing-Condition Trials Exist in Behavioral File
# ============================================================================
# Run this in RStudio Console to check if the 657k missing-condition trials
# actually have valid data in the behavioral CSV that could be recovered.
# ============================================================================

library(dplyr)
library(readr)

cat("=== DIAGNOSING MISSING CONDITIONS ===\n\n")

# ============================================================================
# STEP 1: Set your file paths (UPDATE THESE!)
# ============================================================================

# Path to directory with merged flat files (from your report params)
processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"

# Path to behavioral CSV file
behavioral_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"

cat("Checking file paths...\n")
if (!dir.exists(processed_dir)) {
  stop("ERROR: processed_dir does not exist: ", processed_dir)
}
if (!file.exists(behavioral_file)) {
  stop("ERROR: behavioral_file does not exist: ", behavioral_file)
}
cat("✓ File paths are valid\n\n")

# ============================================================================
# STEP 2: Load merged flat files (same as report does)
# ============================================================================

cat("Loading merged flat files from:", processed_dir, "\n")
flat_files_merged <- list.files(processed_dir, pattern = "_flat_merged\\.csv$", full.names = TRUE)

if (length(flat_files_merged) == 0) {
  stop("ERROR: No *_flat_merged.csv files found in ", processed_dir)
}

cat(sprintf("Found %d merged flat files\n", length(flat_files_merged)))

# Load all merged files
cat("Reading merged files (this may take a minute)...\n")
pupil_data <- flat_files_merged %>%
  purrr::map_dfr(~{
    tryCatch({
      read_csv(.x, show_col_types = FALSE)
    }, error = function(e) {
      cat(sprintf("Warning: Error reading %s: %s\n", basename(.x), e$message))
      return(tibble())
    })
  })

cat(sprintf("Loaded %d total rows from merged files\n\n", nrow(pupil_data)))

# ============================================================================
# STEP 3: Identify unique trials and their condition status
# ============================================================================

cat("Identifying trials with missing conditions...\n")

# Normalize columns (same logic as report)
trials <- pupil_data %>%
  mutate(
    sub = if ("sub" %in% names(.)) as.character(sub) else if ("subject_id" %in% names(.)) as.character(subject_id) else NA_character_,
    task = if ("task" %in% names(.)) {
      case_when(
        task == "aud" ~ "ADT",
        task == "vis" ~ "VDT",
        TRUE ~ as.character(task)
      )
    } else if ("task_modality" %in% names(.)) {
      case_when(
        task_modality == "aud" ~ "ADT",
        task_modality == "vis" ~ "VDT",
        TRUE ~ as.character(task_modality)
      )
    } else NA_character_,
    run = if ("run" %in% names(.)) run else if ("run_num" %in% names(.)) run_num else NA_integer_,
    trial_index = coalesce(
      if ("trial_index" %in% names(.)) trial_index else NA_integer_,
      if ("trial_in_run" %in% names(.)) trial_in_run else NA_integer_,
      if ("trial" %in% names(.)) trial else NA_integer_,
      if ("trial_num" %in% names(.)) trial_num else NA_integer_
    ),
    gf_trPer = coalesce(
      if ("gf_trPer" %in% names(.)) gf_trPer else NA_real_,
      if ("grip_targ_prop_mvc" %in% names(.)) grip_targ_prop_mvc else NA_real_
    ),
    stimLev = if ("stimLev" %in% names(.)) stimLev else if ("stim_level_index" %in% names(.)) stim_level_index else NA_real_,
    isOddball = if ("isOddball" %in% names(.)) isOddball else if ("stim_is_diff" %in% names(.)) as.integer(stim_is_diff) else NA_integer_,
    force_condition = if ("force_condition" %in% names(.)) force_condition else NA_character_
  ) %>%
  filter(!is.na(sub), !is.na(task), !is.na(run), !is.na(trial_index)) %>%
  distinct(sub, task, run, trial_index, .keep_all = TRUE) %>%
  mutate(
    # Determine if conditions are missing (same logic as report)
    has_effort = !is.na(gf_trPer) & gf_trPer %in% c(0.05, 0.4, 0.40) | 
                 !is.na(force_condition) & force_condition %in% c("Low_Force_5pct", "High_Force_40pct"),
    has_difficulty = !is.na(isOddball) | (!is.na(stimLev) & stimLev > 0),
    missing_condition = !has_effort | !has_difficulty
  )

cat(sprintf("Total unique trials: %d\n", nrow(trials)))
cat(sprintf("Trials with missing conditions: %d (%.1f%%)\n\n", 
            sum(trials$missing_condition), 
            100 * mean(trials$missing_condition)))

# ============================================================================
# STEP 4: Load behavioral file and normalize
# ============================================================================

cat("Loading behavioral file...\n")
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
    gf_trPer_behav = grip_targ_prop_mvc,
    stimLev_behav = stim_level_index,
    isOddball_behav = as.integer(stim_is_diff)
  ) %>%
  # Deduplicate to trial level
  group_by(sub_behav, task_behav, run_behav, trial_index_behav) %>%
  summarise(
    gf_trPer_behav = first(na.omit(gf_trPer_behav)),
    stimLev_behav = first(na.omit(stimLev_behav)),
    isOddball_behav = first(na.omit(isOddball_behav)),
    .groups = "drop"
  )

cat(sprintf("Loaded %d unique trials from behavioral file\n\n", nrow(behavioral)))

# ============================================================================
# STEP 5: Check if missing-condition trials exist in behavioral file
# ============================================================================

cat("Checking if missing-condition trials exist in behavioral file...\n")

missing_trials <- trials %>% filter(missing_condition)

# Try to match on (sub, task, run, trial_index)
matched <- missing_trials %>%
  left_join(
    behavioral,
    by = c("sub" = "sub_behav", "task" = "task_behav", 
           "run" = "run_behav", "trial_index" = "trial_index_behav")
  )

# ============================================================================
# STEP 6: Report results
# ============================================================================

cat("\n=== DIAGNOSTIC RESULTS ===\n\n")

summary_stats <- matched %>%
  summarise(
    n_missing_trials = n(),
    n_found_in_behav = sum(!is.na(gf_trPer_behav) | !is.na(stimLev_behav)),
    n_have_gf_trPer = sum(!is.na(gf_trPer_behav) & gf_trPer_behav %in% c(0.05, 0.4, 0.40)),
    n_have_stimLev = sum(!is.na(stimLev_behav) & stimLev_behav > 0),
    n_have_both_valid = sum(
      !is.na(gf_trPer_behav) & gf_trPer_behav %in% c(0.05, 0.4, 0.40) &
      (!is.na(stimLev_behav) | !is.na(isOddball_behav))
    )
  )

cat("SUMMARY:\n")
cat(sprintf("  Missing-condition trials in pupil data: %d\n", summary_stats$n_missing_trials))
cat(sprintf("  Found matching row in behavioral file: %d (%.1f%%)\n", 
            summary_stats$n_found_in_behav,
            100 * summary_stats$n_found_in_behav / summary_stats$n_missing_trials))
cat(sprintf("  Have valid gf_trPer (0.05 or 0.4): %d (%.1f%%)\n",
            summary_stats$n_have_gf_trPer,
            100 * summary_stats$n_have_gf_trPer / summary_stats$n_missing_trials))
cat(sprintf("  Have valid stimLev (> 0): %d (%.1f%%)\n",
            summary_stats$n_have_stimLev,
            100 * summary_stats$n_have_stimLev / summary_stats$n_missing_trials))
cat(sprintf("  Have BOTH valid (recoverable): %d (%.1f%%)\n",
            summary_stats$n_have_both_valid,
            100 * summary_stats$n_have_both_valid / summary_stats$n_missing_trials))

# ============================================================================
# STEP 7: Show examples by subject
# ============================================================================

cat("\n=== EXAMPLES BY SUBJECT ===\n\n")

subject_summary <- matched %>%
  filter(!is.na(gf_trPer_behav) | !is.na(stimLev_behav)) %>%
  group_by(sub, task) %>%
  summarise(
    n_missing = n(),
    n_recoverable = sum(
      !is.na(gf_trPer_behav) & gf_trPer_behav %in% c(0.05, 0.4, 0.40) &
      (!is.na(stimLev_behav) | !is.na(isOddball_behav))
    ),
    .groups = "drop"
  ) %>%
  arrange(desc(n_recoverable))

if (nrow(subject_summary) > 0) {
  cat("Top subjects with recoverable trials:\n")
  print(head(subject_summary, 20))
} else {
  cat("No recoverable trials found in behavioral file.\n")
}

# ============================================================================
# STEP 8: Check for potential merge key mismatches
# ============================================================================

cat("\n=== CHECKING FOR MERGE KEY MISMATCHES ===\n\n")

# Sample a few subjects to check run/trial alignment
sample_subjects <- unique(missing_trials$sub)[1:min(3, length(unique(missing_trials$sub)))]

for (s in sample_subjects) {
  cat(sprintf("\nSubject: %s\n", s))
  
  pupil_runs <- missing_trials %>%
    filter(sub == s) %>%
    distinct(task, run, trial_index) %>%
    arrange(task, run, trial_index)
  
  behav_runs <- behavioral %>%
    filter(sub_behav == s) %>%
    distinct(task_behav, run_behav, trial_index_behav) %>%
    arrange(task_behav, run_behav, trial_index_behav)
  
  cat(sprintf("  Pupil data: %d unique (task, run, trial_index) combinations\n", nrow(pupil_runs)))
  cat(sprintf("  Behavioral data: %d unique (task, run, trial_index) combinations\n", nrow(behav_runs)))
  
  # Check overlap
  overlap <- pupil_runs %>%
    inner_join(
      behav_runs,
      by = c("task" = "task_behav", "run" = "run_behav", "trial_index" = "trial_index_behav")
    )
  
  cat(sprintf("  Overlapping keys: %d (%.1f%% of pupil, %.1f%% of behavioral)\n",
              nrow(overlap),
              100 * nrow(overlap) / nrow(pupil_runs),
              100 * nrow(overlap) / nrow(behav_runs)))
}

cat("\n=== DIAGNOSIS COMPLETE ===\n")
cat("\nINTERPRETATION:\n")
cat("  - If 'Have BOTH valid' is high (>10%%), the merge in preprocessing likely failed.\n")
cat("  - If 'Have BOTH valid' is very low (<1%%), these trials genuinely lack behavioral data.\n")
cat("  - Check 'Overlapping keys' to see if run/trial_index alignment is the issue.\n")



