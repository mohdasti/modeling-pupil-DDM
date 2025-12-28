# Quick test to verify the waveform extraction fix works

library(dplyr)
library(data.table)

LATEST_BUILD <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/build_20251225_154443"
REPO_ROOT <- normalizePath(".")
MERGED_FILE <- file.path(REPO_ROOT, "quick_share_v7", "merged", "BAP_triallevel_merged_v4.csv")

cat("Testing waveform extraction fix...\n\n")

# Load one trial
merged_v4 <- fread(MERGED_FILE)
waveform_trials <- merged_v4 %>%
  filter(auc_available == TRUE, !is.na(effort)) %>%
  slice(1)

cat("Test trial: ", waveform_trials$trial_uid[1], "\n\n")

# Find matching flat file
flat_files <- list.files(LATEST_BUILD, 
                        pattern = paste0("^", waveform_trials$sub[1], "_", waveform_trials$task[1], "_flat\\.csv$"), 
                        full.names = TRUE)

if (length(flat_files) == 0) stop("No matching flat file")

cat("Loading flat file...\n")
df <- fread(flat_files[1], showProgress = FALSE, data.table = FALSE)

# Filter to matching trial
df_trial <- df %>%
  filter(
    session_used == waveform_trials$session_used[1],
    run_used == waveform_trials$run_used[1],
    trial_index == waveform_trials$trial_index[1]
  )

cat("Trial samples: ", nrow(df_trial), "\n")
cat("Has seg_start_rel_used: ", "seg_start_rel_used" %in% names(df_trial), "\n")

if ("seg_start_rel_used" %in% names(df_trial) && !all(is.na(df_trial$seg_start_rel_used))) {
  seg_start_rel <- first(df_trial$seg_start_rel_used[!is.na(df_trial$seg_start_rel_used)])
  cat("seg_start_rel_used: ", seg_start_rel, "\n")
  
  time_min <- min(df_trial$time, na.rm = TRUE)
  cat("min(time): ", time_min, "\n")
  
  squeeze_onset <- time_min - seg_start_rel
  cat("squeeze_onset = min(time) - seg_start_rel = ", time_min, " - ", seg_start_rel, " = ", squeeze_onset, "\n")
  
  t_rel <- df_trial$time - squeeze_onset
  cat("\nt_rel range: ", min(t_rel, na.rm = TRUE), " to ", max(t_rel, na.rm = TRUE), "\n")
  
  wave_mask <- t_rel >= -0.5 & t_rel <= 7.7
  cat("Samples in extended window: ", sum(wave_mask), "\n")
  
  if (sum(wave_mask) >= 2) {
    cat("\n✓ SUCCESS: Trial has sufficient data for waveform extraction\n")
  } else {
    cat("\n✗ FAIL: Not enough samples in window\n")
  }
} else {
  cat("✗ seg_start_rel_used not available\n")
}

