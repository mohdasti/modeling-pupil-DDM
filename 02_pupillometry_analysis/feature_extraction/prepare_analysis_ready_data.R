#!/usr/bin/env Rscript

# ============================================================================
# Prepare Analysis-Ready Data from Merged Flat Files
# ============================================================================
# Creates BAP_analysis_ready_PUPIL.csv and BAP_analysis_ready_BEHAVIORAL.csv
# from merged flat CSV files
# Updated for post-audit pipeline (handles NaN values, uses quality metrics)
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
})

cat("=== PREPARE ANALYSIS-READY DATA ===\n")
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# ============================================================================
# CONFIGURATION
# ============================================================================

# Paths
processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
behavioral_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"
output_dir <- "data/analysis_ready"

# Create output directory
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# 1. LOAD MERGED FLAT FILES
# ============================================================================

cat("1. Loading merged flat files...\n")

# Find merged flat files (prefer merged over regular)
flat_files_merged <- list.files(processed_dir, pattern = "_flat_merged\\.csv$", full.names = TRUE)
flat_files_reg <- list.files(processed_dir, pattern = "_flat\\.csv$", full.names = TRUE)

# Remove duplicates (prefer merged versions)
if (length(flat_files_merged) > 0 && length(flat_files_reg) > 0) {
  merged_ids <- gsub("_flat_merged\\.csv$", "", basename(flat_files_merged))
  reg_ids <- gsub("_flat\\.csv$", "", basename(flat_files_reg))
  reg_to_keep <- !reg_ids %in% merged_ids
  flat_files <- c(flat_files_merged, flat_files_reg[reg_to_keep])
  cat("  Using", length(flat_files_merged), "merged files +", sum(reg_to_keep), "regular files\n")
} else {
  flat_files <- c(flat_files_merged, flat_files_reg)
}

if(length(flat_files) == 0) {
  stop("ERROR: No flat files found in ", processed_dir)
}

cat("  Found", length(flat_files), "flat files\n")

# Load all flat files
cat("  Loading files...\n")
pupil_data_raw <- map_dfr(flat_files, function(f) {
  cat("    Loading:", basename(f), "\n")
  read_csv(f, show_col_types = FALSE, progress = FALSE)
})

cat("  Loaded", nrow(pupil_data_raw), "total samples\n\n")

# ============================================================================
# 2. CREATE TRIAL-LEVEL PUPIL SUMMARY
# ============================================================================
# UPDATED: Calculate Total AUC and Cognitive AUC (Zenon et al. 2014 method)
# instead of simple mean-based metrics
# ============================================================================

cat("2. Creating trial-level pupil summary with AUC metrics...\n")

# Helper function to calculate AUC using trapezoidal integration
# Updated to match Zenon et al. (2014) method
calculate_auc <- function(time_series, data_series, start_time, end_time) {
  # Filter data for the specified window
  # Ensure time_series and data_series are numeric and of equal length
  # Filter out NA values from data_series as it would invalidate AUC for that trial
  valid_indices <- !is.na(data_series) & (time_series >= start_time & time_series <= end_time)
  
  if (sum(valid_indices) < 2) { # Need at least 2 points for trapezoidal rule
    return(NA_real_)
  }
  
  t <- time_series[valid_indices]
  y <- data_series[valid_indices]
  
  # Sort by time to ensure correct trapezoidal calculation
  order_idx <- order(t)
  t <- t[order_idx]
  y <- y[order_idx]
  
  # Calculate AUC using trapezoidal rule (matching provided code)
  auc_val <- sum(0.5 * (y[-length(y)] + y[-1]) * diff(t), na.rm = TRUE)
  return(auc_val)
}

# UPDATED: Handle NaN values (zeros converted to NaN in MATLAB pipeline)
# UPDATED: Use baseline_quality and overall_quality from MATLAB pipeline if available
# UPDATED: Calculate Total AUC and Cognitive AUC (Zenon et al. 2014 method)
# - Total AUC: Raw pupil data from squeeze onset to trial-specific response onset
# - Cognitive AUC: Baseline-corrected pupil from 300ms after stimulus to trial-specific response onset

# First, calculate baseline B0 and create pupil_isolated for each trial
pupil_data_with_baseline <- pupil_data_raw %>%
  group_by(sub, task, run, trial_index) %>%
  mutate(
    # Pre-trial baseline (B₀): 500ms window before trial onset (squeeze onset = 0)
    baseline_B0 = mean(pupil[time >= -0.5 & time < 0 & !is.na(pupil)], na.rm = TRUE),
    # Create baseline-corrected pupil trace (pupil_isolated) for Cognitive AUC
    # Apply global baseline correction throughout to converge all conditions at squeeze onset (time = 0)
    pupil_isolated = pupil - baseline_B0
  ) %>%
  ungroup()

# Get trial-specific response onset times (response window start + RT if available)
# Response window starts at 4.7s (Response_Different phase start)
trial_response_onsets <- pupil_data_with_baseline %>%
  group_by(sub, task, run, trial_index) %>%
  summarise(
    # Get RT if available (from merged behavioral data)
    rt = if("resp1RT" %in% names(pupil_data_with_baseline)) {
      first(na.omit(resp1RT))
    } else {
      NA_real_
    },
    response_onset = if("resp1RT" %in% names(pupil_data_with_baseline)) {
      rt_val <- first(na.omit(resp1RT))
      if(!is.na(rt_val) && rt_val > 0 && rt_val < 5.0) {
        4.7 + rt_val  # Response window start (4.7s) + RT
      } else {
        4.7  # Fallback to fixed window start
      }
    } else {
      4.7  # Default to fixed window start if RT not available
    },
    .groups = "drop"
  )

# Calculate AUC metrics per trial
pupil_summary_per_trial <- pupil_data_with_baseline %>%
  left_join(trial_response_onsets, by = c("sub", "task", "run", "trial_index")) %>%
  group_by(sub, task, run, trial_index) %>%
  summarise(
    # Baseline B0 (already calculated above)
    baseline_B0 = first(baseline_B0),
    
    # Total AUC: Raw pupil data from squeeze onset (0s) to trial-specific response onset
    # NO baseline correction (uses raw pupil data)
    total_auc = calculate_auc(
      time_series = time,
      data_series = pupil,  # Raw pupil data
      start_time = 0.0,      # Trial onset (squeeze onset)
      end_time = first(response_onset)  # Trial-specific response onset
    ),
    
    # Cognitive AUC: Baseline-corrected pupil from 300ms after TARGET stimulus onset to trial-specific response onset
    # Target stimulus is the second stimulus: Standard (100ms) + ISI (500ms) + Target (100ms)
    # Target stimulus onset = 3.75s (stimulus phase start) + 0.1s (Standard) + 0.5s (ISI) = 4.35s
    # 300ms after target onset = 4.35 + 0.3 = 4.65s
    # Uses pupil_isolated (baseline-corrected trace)
    cognitive_auc = calculate_auc(
      time_series = time,
      data_series = pupil_isolated,  # Baseline-corrected pupil
      start_time = 4.35 + 0.3,  # 300ms after TARGET stimulus onset (4.65s)
      end_time = first(response_onset)  # Trial-specific response onset (4.7s + RT if available)
    ),
    
    # Keep old metrics for backward compatibility (but mark as deprecated)
    tonic_arousal = mean(pupil[trial_label == "ITI_Baseline" & !is.na(pupil)], na.rm = TRUE),
    effort_arousal_pupil = mean(pupil[trial_label == "Pre_Stimulus_Fixation" & !is.na(pupil)], na.rm = TRUE),
    
    # UPDATED: Check for valid (non-NaN) data instead of > 0 (zeros are now NaN)
    quality_iti = mean(!is.na(pupil[trial_label == "ITI_Baseline"]), na.rm = TRUE),
    quality_prestim = mean(!is.na(pupil[trial_label == "Pre_Stimulus_Fixation"]), na.rm = TRUE),
    
    # Use MATLAB pipeline quality metrics if available (more accurate)
    baseline_quality = if("baseline_quality" %in% names(pupil_data_raw)) dplyr::first(na.omit(baseline_quality)) else NA_real_,
    overall_quality = if("overall_quality" %in% names(pupil_data_raw)) dplyr::first(na.omit(overall_quality)) else NA_real_,
    
    .groups = "drop"
  ) %>%
  mutate(
    # Keep old metric for backward compatibility
    effort_arousal_change = effort_arousal_pupil - tonic_arousal,
    
    # Prefer MATLAB pipeline quality metrics if available
    quality_iti = ifelse(!is.na(baseline_quality), baseline_quality, quality_iti),
    quality_prestim = ifelse(!is.na(overall_quality), overall_quality, quality_prestim)
  )

cat("  Created", nrow(pupil_summary_per_trial), "trial-level summaries\n\n")

# ============================================================================
# 3. LOAD AND PREPARE BEHAVIORAL DATA
# ============================================================================

cat("3. Loading behavioral data...\n")

if(!file.exists(behavioral_file)) {
  stop("ERROR: Behavioral file not found: ", behavioral_file)
}

behavioral_data_raw <- read_csv(behavioral_file, show_col_types = FALSE)
cat("  Loaded", nrow(behavioral_data_raw), "behavioral trials\n")

# Map column names to expected format
behavioral_data_per_trial <- behavioral_data_raw %>%
  mutate(
    # Map subject identifier
    sub = if ("sub" %in% names(.)) sub else if ("subject_id" %in% names(.)) as.character(subject_id) else NA_character_,
    # Map task (convert "aud"/"vis" to "ADT"/"VDT")
    task = if ("task" %in% names(.)) {
      dplyr::if_else(task == "aud", "ADT", 
                    dplyr::if_else(task == "vis", "VDT", as.character(task)))
    } else if ("task_modality" %in% names(.)) {
      dplyr::case_when(
        task_modality == "aud" ~ "ADT",
        task_modality == "vis" ~ "VDT",
        TRUE ~ as.character(task_modality)
      )
    } else NA_character_,
    # Map run number
    run = if ("run" %in% names(.)) run else if ("run_num" %in% names(.)) run_num else NA_integer_,
    # Map trial number - UPDATED: Use trial_in_run if available, otherwise trial
    trial_index = if ("trial_in_run" %in% names(.)) trial_in_run 
                  else if ("trial" %in% names(.)) trial 
                  else if ("trial_num" %in% names(.)) trial_num 
                  else NA_integer_,
    # Map RT
    rt = if ("rt" %in% names(.)) rt else if ("resp1RT" %in% names(.)) resp1RT else if ("same_diff_resp_secs" %in% names(.)) same_diff_resp_secs else NA_real_,
    # Map accuracy
    accuracy = if ("accuracy" %in% names(.)) accuracy else if ("iscorr" %in% names(.)) iscorr else if ("resp_is_correct" %in% names(.)) as.integer(resp_is_correct) else NA_integer_,
    # Map grip force
    gf_trPer = if ("gf_trPer" %in% names(.)) gf_trPer else if ("grip_targ_prop_mvc" %in% names(.)) grip_targ_prop_mvc else NA_real_,
    # Map stimulus level
    stimLev = if ("stimLev" %in% names(.)) stimLev else if ("stim_level_index" %in% names(.)) stim_level_index else NA_real_,
    # Map oddball status
    isOddball = if ("isOddball" %in% names(.)) isOddball else if ("stim_is_diff" %in% names(.)) as.integer(stim_is_diff) else NA_integer_
  ) %>%
  select(sub, task, run, trial_index, rt, accuracy, gf_trPer, stimLev, isOddball) %>%
  filter(!is.na(sub), !is.na(task), !is.na(run), !is.na(trial_index))

cat("  Prepared", nrow(behavioral_data_per_trial), "behavioral trials\n\n")

# ============================================================================
# 4. MERGE PUPIL AND BEHAVIORAL DATA
# ============================================================================

cat("4. Merging pupil and behavioral data...\n")

full_dataset <- behavioral_data_per_trial %>%
  left_join(
    pupil_summary_per_trial,
    by = c("sub", "task", "run", "trial_index")
  ) %>%
  mutate(
    subject_id = as.character(sub),
    effort_condition = factor(case_when(
      gf_trPer == 0.05 ~ "Low_5_MVC",
      gf_trPer == 0.40 ~ "High_40_MVC",
      TRUE ~ NA_character_
    )),
    # UPDATED: Proper difficulty level mapping (Standard, Easy, Hard)
    difficulty_level = factor(case_when(
      isOddball == 0 ~ "Standard",  # Standard trials
      isOddball == 1 & stimLev %in% c(8, 16, 0.06, 0.12) ~ "Hard",  # Oddball with low stim levels
      isOddball == 1 & stimLev %in% c(32, 64, 0.24, 0.48) ~ "Easy",  # Oddball with high stim levels
      stimLev %in% c(8, 16, 0.06, 0.12) ~ "Hard",  # Low stim levels (if oddball status missing)
      stimLev %in% c(32, 64, 0.24, 0.48) ~ "Easy",  # High stim levels (if oddball status missing)
      TRUE ~ NA_character_
    ), levels = c("Standard", "Easy", "Hard"))
  ) %>%
  select(
    subject_id, task, run, trial_index,
    effort_condition, difficulty_level,
    rt, accuracy,
    # Primary metrics: Total AUC and Cognitive AUC (Zenon et al. 2014)
    total_auc, cognitive_auc,
    # Baseline values for reference
    baseline_B0, baseline_pre_stim,
    # Legacy metrics (kept for backward compatibility)
    tonic_arousal, effort_arousal_change,
    # Quality metrics
    quality_iti, quality_prestim
  ) %>%
  filter(!is.na(rt), !is.na(accuracy), !is.na(effort_condition), !is.na(difficulty_level))

cat("  Merged dataset:", nrow(full_dataset), "trials\n\n")

# ============================================================================
# 5. CREATE SEPARATE BEHAVIORAL AND PUPIL DATASETS
# ============================================================================

cat("5. Creating analysis-ready datasets...\n")

# Behavioral dataset (all trials)
behavioral_dataset <- full_dataset %>%
  select(subject_id, task, run, trial_index, effort_condition, difficulty_level, rt, accuracy)

output_path_behav <- file.path(output_dir, "BAP_analysis_ready_BEHAVIORAL.csv")
write_csv(behavioral_dataset, output_path_behav)
cat("  ✓ Saved:", output_path_behav, "(", nrow(behavioral_dataset), "trials)\n")

# Pupil dataset (high-quality trials only - 80% threshold)
pupil_dataset <- full_dataset %>%
  filter(quality_iti >= 0.80 & quality_prestim >= 0.80)

output_path_pupil <- file.path(output_dir, "BAP_analysis_ready_PUPIL.csv")
write_csv(pupil_dataset, output_path_pupil)
cat("  ✓ Saved:", output_path_pupil, "(", nrow(pupil_dataset), "trials)\n")

# ============================================================================
# 6. SANITY CHECKS: FILTER TO SUBJECTS WITH COMPLETE DATA
# ============================================================================

cat("\n6. Applying sanity checks: filtering to subjects with complete data...\n")

# Check for subjects with at least 5 runs for at least one task
subject_task_runs <- full_dataset %>%
  group_by(subject_id, task) %>%
  summarise(n_runs = length(unique(run)), .groups = "drop") %>%
  filter(n_runs >= 5)  # At least 5 runs (sessions) for a task

valid_subjects <- unique(subject_task_runs$subject_id)
cat("  Subjects with >= 5 runs for at least one task:", length(valid_subjects), "\n")

if(length(valid_subjects) == 0) {
  warning("WARNING: No subjects found with >= 5 runs for any task!")
  cat("  This may indicate a data issue. Proceeding with all subjects.\n")
} else {
  # Filter datasets to only include valid subjects
  behavioral_dataset <- behavioral_dataset %>%
    filter(subject_id %in% valid_subjects)
  
  pupil_dataset <- pupil_dataset %>%
    filter(subject_id %in% valid_subjects)
  
  # Re-save filtered datasets
  write_csv(behavioral_dataset, output_path_behav)
  write_csv(pupil_dataset, output_path_pupil)
  
  cat("  ✓ Filtered datasets to", length(valid_subjects), "subjects with complete data\n")
}

# Additional sanity checks
cat("\n7. Additional sanity checks...\n")

# Check difficulty level distribution
if("difficulty_level" %in% names(behavioral_dataset)) {
  diff_dist <- table(behavioral_dataset$difficulty_level, useNA = "always")
  cat("  Difficulty level distribution:\n")
  for(i in 1:length(diff_dist)) {
    cat(sprintf("    %s: %d trials\n", names(diff_dist)[i], diff_dist[i]))
  }
  
  # Check if all three levels are present
  expected_levels <- c("Standard", "Easy", "Hard")
  missing_levels <- setdiff(expected_levels, names(diff_dist))
  if(length(missing_levels) > 0) {
    warning("WARNING: Missing difficulty levels: ", paste(missing_levels, collapse = ", "))
  }
}

# Check effort condition distribution
if("effort_condition" %in% names(behavioral_dataset)) {
  effort_dist <- table(behavioral_dataset$effort_condition, useNA = "always")
  cat("  Effort condition distribution:\n")
  for(i in 1:length(effort_dist)) {
    cat(sprintf("    %s: %d trials\n", names(effort_dist)[i], effort_dist[i]))
  }
}

# Check task distribution
task_dist <- table(behavioral_dataset$task, useNA = "always")
cat("  Task distribution:\n")
for(i in 1:length(task_dist)) {
  cat(sprintf("    %s: %d trials\n", names(task_dist)[i], task_dist[i]))
}

# Check subject counts
cat("\n  Subject counts:\n")
cat("    Total subjects in behavioral data:", length(unique(behavioral_dataset$subject_id)), "\n")
cat("    Total subjects in pupil data:", length(unique(pupil_dataset$subject_id)), "\n")

# ============================================================================
# SUMMARY
# ============================================================================

cat("\n=== SUMMARY ===\n")
cat("Behavioral trials:", nrow(behavioral_dataset), "\n")
cat("Pupil trials (quality >= 80%):", nrow(pupil_dataset), "\n")
if(nrow(behavioral_dataset) > 0) {
  cat("Quality filtering:", round(100 * nrow(pupil_dataset) / nrow(behavioral_dataset), 1), "% of behavioral trials retained\n")
}
cat("Valid subjects (>= 5 runs for at least one task):", length(valid_subjects), "\n")

# AUC metrics summary
if("total_auc" %in% names(pupil_dataset)) {
  cat("\nAUC Metrics (Zenon et al. 2014 method):\n")
  cat("  Total AUC: M =", round(mean(pupil_dataset$total_auc, na.rm=TRUE), 3), 
      ", SD =", round(sd(pupil_dataset$total_auc, na.rm=TRUE), 3), "\n")
  cat("  Cognitive AUC: M =", round(mean(pupil_dataset$cognitive_auc, na.rm=TRUE), 3), 
      ", SD =", round(sd(pupil_dataset$cognitive_auc, na.rm=TRUE), 3), "\n")
  cat("  Trials with valid Total AUC:", sum(!is.na(pupil_dataset$total_auc)), "/", nrow(pupil_dataset), "\n")
  cat("  Trials with valid Cognitive AUC:", sum(!is.na(pupil_dataset$cognitive_auc)), "/", nrow(pupil_dataset), "\n")
}

cat("\n=== COMPLETE ===\n")
cat("Completed at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")

