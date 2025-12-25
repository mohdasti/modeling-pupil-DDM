#!/usr/bin/env Rscript
# ============================================================================
# Generate Waveform Summaries for Chapter 2
# ============================================================================
# Creates downsampled (50 Hz) condition mean waveforms from flat files
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(tidyr)
  library(here)
  library(yaml)
  library(data.table)
})

cat("=== GENERATING WAVEFORM SUMMARIES ===\n\n")

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

REPO_ROOT <- here::here()

# Load config
config_file <- file.path(REPO_ROOT, "config", "data_paths.yaml")
if (file.exists(config_file)) {
  config <- read_yaml(config_file)
  PROCESSED_DIR <- config$processed_dir
} else {
  PROCESSED_DIR <- Sys.getenv("PUPIL_PROCESSED_DIR")
  if (PROCESSED_DIR == "") {
    stop("Please set config/data_paths.yaml or PUPIL_PROCESSED_DIR env var")
  }
}

V5_ROOT <- file.path(REPO_ROOT, "quick_share_v5")
V5_ANALYSIS <- file.path(V5_ROOT, "analysis")
V5_MERGED <- file.path(V5_ROOT, "merged", "BAP_triallevel_merged_v3.csv")

FS_TARGET <- 250  # Original sampling rate
FS_DOWNSAMPLE <- 50  # Target downsampled rate
WINDOW_START <- -3.0
DOWNSAMPLE_FACTOR <- FS_TARGET / FS_DOWNSAMPLE  # 5x downsampling

cat("Processed dir: ", PROCESSED_DIR, "\n", sep = "")
cat("Output dir: ", V5_ANALYSIS, "\n\n", sep = "")

# ----------------------------------------------------------------------------
# Helper: Downsample to 50 Hz
# ----------------------------------------------------------------------------

downsample_to_50hz <- function(df, time_col = "time_rel", pupil_col = "pupil") {
  if (nrow(df) == 0) return(df)
  
  # Sort by time
  df <- df %>% arrange(.data[[time_col]])
  
  # Create sample index
  df$sample_idx <- seq_len(nrow(df))
  
  # Keep every Nth sample (where N = DOWNSAMPLE_FACTOR)
  keep_idx <- seq(1, nrow(df), by = round(DOWNSAMPLE_FACTOR))
  df[keep_idx, ]
}

# ----------------------------------------------------------------------------
# Helper: Process one flat file for waveforms
# ----------------------------------------------------------------------------

process_flat_for_waveforms <- function(flat_path, merged_v3) {
  fn <- basename(flat_path)
  
  # Read file
  df <- fread(flat_path, showProgress = FALSE, data.table = FALSE)
  
  # Standardize columns (same as AUC script)
  col_map <- list(
    sub = c("sub", "subject", "subject_id"),
    task = c("task", "task_name", "task_modality"),
    session_used = c("session_used", "ses", "session", "session_num"),
    run_used = c("run_used", "run", "run_num"),
    trial_index = c("trial_index", "trial_in_run_raw", "trial_in_run", "trial_num"),
    time = c("time", "time_ptb", "trial_pupilTime"),
    pupil = c("pupil", "pupilSize", "pupil_diameter")
  )
  
  for (target in names(col_map)) {
    candidates <- col_map[[target]]
    for (cand in candidates) {
      if (cand %in% names(df)) {
        df[[target]] <- df[[cand]]
        break
      }
    }
  }
  
  # Standardize
  df <- df %>%
    mutate(
      sub = as.character(sub),
      task = as.character(task),
      session_used = as.integer(session_used),
      run_used = as.integer(run_used),
      trial_index = as.integer(trial_index),
      time = as.numeric(time),
      pupil = as.numeric(pupil)
    ) %>%
    mutate(pupil = if_else(is.nan(pupil), NA_real_, pupil)) %>%
    filter(session_used %in% c(2L, 3L)) %>%
    arrange(trial_index, time)
  
  if (nrow(df) == 0) return(tibble())
  
  # Get metadata
  meta <- df %>%
    distinct(sub, task, session_used, run_used) %>%
    slice(1)
  
  if (nrow(meta) != 1) return(tibble())
  
  # Join with merged_v3 to get effort and quality flags
  trial_meta <- merged_v3 %>%
    filter(
      sub == meta$sub,
      task == meta$task,
      session_used == meta$session_used,
      run_used == meta$run_used
    ) %>%
    select(trial_index, effort, stimulus_intensity, isOddball,
           gate_primary_060, total_auc, cog_auc_fixed1s) %>%
    mutate(effort = if_else(is.na(effort), "Unknown", as.character(effort)))
  
  # Process each trial
  waveforms <- df %>%
    group_by(trial_index) %>%
    group_map(~ {
      trial_num <- .y$trial_index
      
      # Get trial metadata
      trial_info <- trial_meta %>% filter(trial_index == trial_num)
      if (nrow(trial_info) == 0) return(tibble())
      
      # Skip if quality doesn't pass
      if (!trial_info$gate_primary_060[1]) return(tibble())
      
      # Reconstruct time_rel
      n_samples <- nrow(.x)
      if (n_samples < 2) return(tibble())
      
      time_diffs <- diff(sort(unique(.x$time)))
      dt_median <- median(time_diffs[time_diffs > 0], na.rm = TRUE)
      fs_est <- if_else(is.na(dt_median) || dt_median <= 0, FS_TARGET, 1.0 / dt_median)
      
      sample_i <- seq_len(n_samples)
      time_rel <- WINDOW_START + (sample_i - 1) / fs_est
      
      if (min(.x$time, na.rm = TRUE) >= WINDOW_START - 0.1 && 
          max(.x$time, na.rm = TRUE) <= WINDOW_START + 15) {
        time_rel <- .x$time
      }
      
      # Compute baselines
      b0_mask <- time_rel >= -0.5 & time_rel <= 0.0
      b0_mean <- mean(.x$pupil[b0_mask], na.rm = TRUE)
      
      # Target baseline (assume target at ~6.9s)
      target_onset <- 6.9
      target_base_mask <- time_rel >= (target_onset - 0.5) & time_rel <= target_onset
      target_base_mean <- mean(.x$pupil[target_base_mask], na.rm = TRUE)
      
      # Create waveform data
      waveform_df <- tibble(
        sub = meta$sub,
        task = meta$task,
        session_used = meta$session_used,
        run_used = meta$run_used,
        trial_index = trial_num,
        effort = trial_info$effort[1],
        stimulus_intensity = trial_info$stimulus_intensity[1],
        isOddball = trial_info$isOddball[1],
        time_s = time_rel,
        pupil_raw = .x$pupil,
        pupil_b0_corrected = .x$pupil - b0_mean,
        pupil_target_corrected = .x$pupil - target_base_mean
      )
      
      # Downsample to 50 Hz
      waveform_df <- downsample_to_50hz(waveform_df, "time_s", "pupil_raw")
      
      waveform_df
    }, .keep = TRUE) %>%
    bind_rows()
  
  waveforms
}

# ----------------------------------------------------------------------------
# STEP 1: Load merged v3 for metadata
# ----------------------------------------------------------------------------

cat("STEP 1: Loading merged v3 for metadata...\n")

if (!file.exists(V5_MERGED)) {
  stop("Merged v3 file not found: ", V5_MERGED)
}

merged_v3 <- read_csv(V5_MERGED, show_col_types = FALSE)
cat("  ✓ Loaded ", nrow(merged_v3), " trials\n\n", sep = "")

# ----------------------------------------------------------------------------
# STEP 2: Find flat files
# ----------------------------------------------------------------------------

cat("STEP 2: Finding flat files...\n")

flat_files <- list.files(
  PROCESSED_DIR,
  pattern = ".*_(ADT|VDT)_flat\\.csv$",
  full.names = TRUE,
  recursive = TRUE
)

if (length(flat_files) == 0) {
  stop("No flat CSV files found in ", PROCESSED_DIR)
}

cat("  Found ", length(flat_files), " flat files\n\n", sep = "")

# ----------------------------------------------------------------------------
# STEP 3: Process files and extract waveforms (sample subset for speed)
# ----------------------------------------------------------------------------

cat("STEP 3: Processing flat files for waveforms...\n")
cat("  NOTE: Processing all files may take time. Consider sampling if needed.\n\n")

# Process files (you may want to sample for testing)
# For full processing, use: all_waveforms <- map_dfr(flat_files, ...)
# For testing, sample: sample_files <- sample(flat_files, min(10, length(flat_files)))

all_waveforms <- map_dfr(flat_files, 
                         ~ process_flat_for_waveforms(.x, merged_v3),
                         .progress = "text")

cat("\n  ✓ Extracted ", nrow(all_waveforms), " waveform samples\n\n", sep = "")

# ----------------------------------------------------------------------------
# STEP 4: Compute condition means
# ----------------------------------------------------------------------------

cat("STEP 4: Computing condition means...\n")

# Trial-locked baseline-corrected waveforms
waveform_means_trial <- all_waveforms %>%
  filter(!is.na(pupil_b0_corrected)) %>%
  group_by(task, effort, time_s) %>%
  summarise(
    mean = mean(pupil_b0_corrected, na.rm = TRUE),
    se = sd(pupil_b0_corrected, na.rm = TRUE) / sqrt(n()),
    n_trials = n(),
    .groups = "drop"
  ) %>%
  mutate(align_type = "trial_locked")

# Target-locked baseline-corrected waveforms
# Shift time to be relative to target onset (~6.9s)
waveform_means_target <- all_waveforms %>%
  filter(!is.na(pupil_target_corrected)) %>%
  mutate(time_rel_target = time_s - 6.9) %>%
  filter(time_rel_target >= -1.0 & time_rel_target <= 2.0) %>%
  group_by(task, effort, time_rel_target) %>%
  summarise(
    mean = mean(pupil_target_corrected, na.rm = TRUE),
    se = sd(pupil_target_corrected, na.rm = TRUE) / sqrt(n()),
    n_trials = n(),
    .groups = "drop"
  ) %>%
  rename(time_s = time_rel_target) %>%
  mutate(align_type = "target_locked")

# Combine
waveform_summary <- bind_rows(
  waveform_means_trial,
  waveform_means_target
) %>%
  arrange(task, effort, align_type, time_s)

write_csv(waveform_summary, file.path(V5_ANALYSIS, "ch2_waveform_means_50hz.csv"))
cat("  ✓ Saved: analysis/ch2_waveform_means_50hz.csv\n")
cat("  Rows: ", nrow(waveform_summary), "\n\n", sep = "")

cat("=== WAVEFORM SUMMARY GENERATION COMPLETE ===\n")

