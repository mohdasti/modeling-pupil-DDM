# Quick test to see if waveform extraction works for one trial

library(dplyr)
library(readr)
library(data.table)
library(purrr)

REPO_ROOT <- normalizePath(".")
V7_ROOT <- file.path(REPO_ROOT, "quick_share_v7")
MERGED_FILE <- file.path(V7_ROOT, "merged", "BAP_triallevel_merged_v4.csv")
LATEST_BUILD <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/build_20251225_154443"

cat("Testing waveform extraction for one trial...\n\n")

# Load merged data
merged_v4 <- fread(MERGED_FILE)
waveform_trials <- merged_v4 %>%
  filter(auc_available == TRUE, !is.na(effort)) %>%
  select(trial_uid, sub, task, session_used, run_used, trial_index, effort, isOddball) %>%
  slice(1)  # Just test first trial

cat("Testing with trial: ", waveform_trials$trial_uid[1], "\n\n")

# Find matching flat file
flat_files <- list.files(LATEST_BUILD, pattern = paste0("^", waveform_trials$sub[1], "_", waveform_trials$task[1], "_flat\\.csv$"), full.names = TRUE)

if (length(flat_files) == 0) {
  stop("No matching flat file found")
}

cat("Found flat file: ", basename(flat_files[1]), "\n\n")

# Read flat file
df <- fread(flat_files[1], showProgress = FALSE, data.table = FALSE)

# Standardize columns (simplified version)
df <- df %>%
  filter(
    session_used == waveform_trials$session_used[1],
    run_used == waveform_trials$run_used[1],
    trial_index == waveform_trials$trial_index[1]
  )

cat("Found ", nrow(df), " samples for this trial\n")
cat("Time range: ", min(df$time, na.rm = TRUE), " to ", max(df$time, na.rm = TRUE), "\n")
cat("Pupil range: ", min(df$pupil, na.rm = TRUE), " to ", max(df$pupil, na.rm = TRUE), "\n\n")

if (nrow(df) == 0) {
  stop("No samples found for this trial in flat file")
}

# Try to compute t_rel (simplified - assume time is absolute PTB)
squeeze_onset <- min(df$time, na.rm = TRUE) + 3.0  # Trial starts 3s before squeeze
t_rel <- df$time - squeeze_onset

cat("Computed t_rel range: ", min(t_rel, na.rm = TRUE), " to ", max(t_rel, na.rm = TRUE), "\n\n")

# Check if we'd have data in the extended window
wave_mask <- t_rel >= -0.5 & t_rel <= 7.7
cat("Samples in extended window (-0.5 to 7.7s): ", sum(wave_mask), "\n")

if (sum(wave_mask) < 2) {
  cat("⚠ WARNING: Not enough samples in extended window!\n")
  cat("This would cause the trial to be skipped.\n")
} else {
  cat("✓ Sufficient samples for waveform extraction\n")
}

