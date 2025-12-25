#!/usr/bin/env Rscript
# ============================================================================
# Make Quick-Share v6: AUC Features + Waveform Summaries
# ============================================================================
# Computes pupil AUC features and condition-mean waveforms for Ch2/Ch3
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(tidyr)
  library(yaml)
  library(here)
  library(data.table)
  library(ggplot2)
})

cat("=== MAKING QUICK-SHARE v6: AUC + WAVEFORMS ===\n\n")

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
V4_ROOT <- file.path(REPO_ROOT, "quick_share_v4")
V6_ROOT <- file.path(REPO_ROOT, "quick_share_v6")
V6_ANALYSIS <- file.path(V6_ROOT, "analysis")
V6_QC <- file.path(V6_ROOT, "qc")
V6_INTERMEDIATE <- file.path(V6_ROOT, "intermediate")

# Input files
V5_CH2 <- file.path(V5_ROOT, "analysis", "ch2_analysis_ready.csv")
V5_CH3 <- file.path(V5_ROOT, "analysis", "ch3_ddm_ready.csv")
V4_MERGED <- file.path(V4_ROOT, "merged", "BAP_triallevel_merged_v2.csv")

dir.create(V6_ROOT, recursive = TRUE, showWarnings = FALSE)
dir.create(V6_ANALYSIS, recursive = TRUE, showWarnings = FALSE)
dir.create(V6_QC, recursive = TRUE, showWarnings = FALSE)
dir.create(V6_INTERMEDIATE, recursive = TRUE, showWarnings = FALSE)

cat("Repo root: ", REPO_ROOT, "\n", sep = "")
cat("Processed dir: ", PROCESSED_DIR, "\n", sep = "")
cat("Output dir: ", V6_ROOT, "\n\n", sep = "")

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------

FS_TARGET <- 250
FS_CH2_WAVEFORM <- 50
FS_CH3_WAVEFORM <- 100  # 250Hz too big, use 100Hz
WINDOW_START <- -3.0
MIN_BASELINE_SAMPLES <- 10L
B0_WIN <- c(-0.5, 0.0)  # Trial baseline
B1_WIN <- c(-0.5, 0.0)  # Target baseline (relative to target onset)
COG_WIN_POST_TARGET <- c(0.3, 1.3)  # Cognitive window after target
TARGET_ONSET_DEFAULT <- 4.35
RESP_START_DEFAULT <- 4.70

# ----------------------------------------------------------------------------
# Helper: Compute trapezoidal AUC
# ----------------------------------------------------------------------------

compute_auc <- function(time, value) {
  valid <- !is.na(time) & !is.na(value) & is.finite(value)
  if (sum(valid) < 2) return(NA_real_)
  
  time_clean <- time[valid]
  value_clean <- value[valid]
  
  ord <- order(time_clean)
  time_clean <- time_clean[ord]
  value_clean <- value_clean[ord]
  
  n <- length(time_clean)
  if (n < 2) return(NA_real_)
  
  dt <- diff(time_clean)
  means <- (value_clean[-n] + value_clean[-1]) / 2
  sum(dt * means)
}

# ----------------------------------------------------------------------------
# Helper: Extract event timing (PTB if available, else defaults)
# ----------------------------------------------------------------------------

extract_event_timing <- function(df, sub, task, session_used, run_used) {
  target_onset_rel <- TARGET_ONSET_DEFAULT
  resp_start_rel <- RESP_START_DEFAULT
  timing_source <- "default"
  
  # Try PTB columns
  if ("trial_start_time_ptb" %in% names(df) && 
      "target_onset_time_ptb" %in% names(df)) {
    trial_st <- first(df$trial_start_time_ptb[!is.na(df$trial_start_time_ptb)])
    target_st <- first(df$target_onset_time_ptb[!is.na(df$target_onset_time_ptb)])
    
    if (!is.na(trial_st) && !is.na(target_st)) {
      target_onset_rel <- target_st - trial_st
      timing_source <- "ptb"
    }
  }
  
  if ("resp1_start_time_ptb" %in% names(df) || "resp1ST" %in% names(df)) {
    resp_col <- if ("resp1_start_time_ptb" %in% names(df)) "resp1_start_time_ptb" else "resp1ST"
    trial_st <- first(df$trial_start_time_ptb[!is.na(df$trial_start_time_ptb)])
    resp_st <- first(df[[resp_col]][!is.na(df[[resp_col]])])
    
    if (!is.na(trial_st) && !is.na(resp_st)) {
      resp_start_rel <- resp_st - trial_st
      if (timing_source == "default") timing_source <- "ptb"
    }
  }
  
  list(
    t_trial_onset = 0.0,
    t_target_onset_rel = target_onset_rel,
    t_resp_start_rel = resp_start_rel,
    timing_source = timing_source
  )
}

# ----------------------------------------------------------------------------
# Helper: Process one flat file for AUC
# ----------------------------------------------------------------------------

process_flat_file_auc_v6 <- function(flat_path) {
  fn <- basename(flat_path)
  
  df <- fread(flat_path, showProgress = FALSE, data.table = FALSE)
  
  # Standardize columns
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
  
  meta <- df %>%
    distinct(sub, task, session_used, run_used) %>%
    slice(1)
  
  if (nrow(meta) != 1) return(tibble())
  
  # Extract event timing
  events <- extract_event_timing(df, meta$sub, meta$task, meta$session_used, meta$run_used)
  
  # Process each trial
  trial_features <- df %>%
    group_by(trial_index) %>%
    group_map(~ {
      trial_num <- .y$trial_index
      
      n_samples <- nrow(.x)
      if (n_samples < 2) {
        return(tibble(
          sub = meta$sub, task = meta$task, session_used = meta$session_used,
          run_used = meta$run_used, trial_index = trial_num,
          auc_total = NA_real_, auc_cog_fixed1s = NA_real_, cog_mean_fixed1s = NA_real_,
          n_valid_B0 = 0L, n_valid_B1 = 0L, n_valid_total_window = 0L, n_valid_cog_window = 0L,
          auc_missing_reason = "insufficient_samples", timing_source = events$timing_source
        ))
      }
      
      # Reconstruct time_rel
      time_diffs <- diff(sort(unique(.x$time)))
      dt_median <- median(time_diffs[time_diffs > 0], na.rm = TRUE)
      fs_est <- if_else(is.na(dt_median) || dt_median <= 0, FS_TARGET, 1.0 / dt_median)
      
      sample_i <- seq_len(n_samples)
      time_rel <- WINDOW_START + (sample_i - 1) / fs_est
      
      if (min(.x$time, na.rm = TRUE) >= WINDOW_START - 0.1 && 
          max(.x$time, na.rm = TRUE) <= WINDOW_START + 15) {
        time_rel <- .x$time
      }
      
      pupil_vals <- .x$pupil
      
      # Baseline B0: [-0.5, 0]
      b0_mask <- time_rel >= B0_WIN[1] & time_rel <= B0_WIN[2]
      b0_pupil <- pupil_vals[b0_mask]
      n_valid_B0 <- sum(!is.na(b0_pupil) & is.finite(b0_pupil))
      
      if (n_valid_B0 < MIN_BASELINE_SAMPLES) {
        return(tibble(
          sub = meta$sub, task = meta$task, session_used = meta$session_used,
          run_used = meta$run_used, trial_index = trial_num,
          auc_total = NA_real_, auc_cog_fixed1s = NA_real_, cog_mean_fixed1s = NA_real_,
          n_valid_B0 = n_valid_B0, n_valid_B1 = 0L, n_valid_total_window = 0L, n_valid_cog_window = 0L,
          auc_missing_reason = "B0_insufficient_samples", timing_source = events$timing_source
        ))
      }
      
      b0_mean <- mean(b0_pupil[!is.na(b0_pupil) & is.finite(b0_pupil)], na.rm = TRUE)
      
      # Baseline B1: [target_onset - 0.5, target_onset]
      b1_start <- events$t_target_onset_rel + B1_WIN[1]
      b1_end <- events$t_target_onset_rel + B1_WIN[2]
      b1_mask <- time_rel >= b1_start & time_rel <= b1_end
      b1_pupil <- pupil_vals[b1_mask]
      n_valid_B1 <- sum(!is.na(b1_pupil) & is.finite(b1_pupil))
      
      if (n_valid_B1 < MIN_BASELINE_SAMPLES) {
        return(tibble(
          sub = meta$sub, task = meta$task, session_used = meta$session_used,
          run_used = meta$run_used, trial_index = trial_num,
          auc_total = NA_real_, auc_cog_fixed1s = NA_real_, cog_mean_fixed1s = NA_real_,
          n_valid_B0 = n_valid_B0, n_valid_B1 = n_valid_B1, n_valid_total_window = 0L, n_valid_cog_window = 0L,
          auc_missing_reason = "B1_insufficient_samples", timing_source = events$timing_source
        ))
      }
      
      b1_mean <- mean(b1_pupil[!is.na(b1_pupil) & is.finite(b1_pupil)], na.rm = TRUE)
      
      # Total AUC: baseline-corrected (B0) from 0 to resp_start
      total_mask <- time_rel >= 0 & time_rel <= events$t_resp_start_rel
      total_pupil <- pupil_vals[total_mask]
      total_time <- time_rel[total_mask]
      n_valid_total <- sum(!is.na(total_pupil) & is.finite(total_pupil))
      
      auc_total <- NA_real_
      if (n_valid_total >= 2) {
        # Total AUC uses baseline-corrected waveform (pupil - B0_mean)
        total_pupil_corrected <- total_pupil - b0_mean
        auc_total <- compute_auc(total_time, total_pupil_corrected)
      }
      
      # Cognitive AUC: target-locked baseline-corrected from (target_onset + 0.3) to resp_start
      cog_win_start <- events$t_target_onset_rel + COG_WIN_POST_TARGET[1]
      cog_win_end <- min(events$t_target_onset_rel + COG_WIN_POST_TARGET[2], events$t_resp_start_rel)
      
      if (cog_win_end <= cog_win_start) {
        return(tibble(
          sub = meta$sub, task = meta$task, session_used = meta$session_used,
          run_used = meta$run_used, trial_index = trial_num,
          auc_total = auc_total, auc_cog_fixed1s = NA_real_, cog_mean_fixed1s = NA_real_,
          n_valid_B0 = n_valid_B0, n_valid_B1 = n_valid_B1, n_valid_total_window = n_valid_total, n_valid_cog_window = 0L,
          auc_missing_reason = "cog_window_invalid", timing_source = events$timing_source
        ))
      }
      
      cog_mask <- time_rel >= cog_win_start & time_rel <= cog_win_end
      cog_pupil <- pupil_vals[cog_mask]
      cog_time <- time_rel[cog_mask]
      n_valid_cog <- sum(!is.na(cog_pupil) & is.finite(cog_pupil))
      
      auc_cog_fixed1s <- NA_real_
      cog_mean_fixed1s <- NA_real_
      
      if (n_valid_cog >= 2) {
        cog_pupil_corrected <- cog_pupil - b1_mean
        auc_cog_fixed1s <- compute_auc(cog_time, cog_pupil_corrected)
        cog_mean_fixed1s <- mean(cog_pupil_corrected[!is.na(cog_pupil_corrected) & is.finite(cog_pupil_corrected)], na.rm = TRUE)
      }
      
      auc_missing_reason <- "ok"
      if (is.na(auc_total)) auc_missing_reason <- "total_auc_failed"
      if (is.na(auc_cog_fixed1s)) auc_missing_reason <- "cog_auc_failed"
      
      tibble(
        sub = meta$sub, task = meta$task, session_used = meta$session_used,
        run_used = meta$run_used, trial_index = trial_num,
        auc_total = auc_total, auc_cog_fixed1s = auc_cog_fixed1s, cog_mean_fixed1s = cog_mean_fixed1s,
        n_valid_B0 = n_valid_B0, n_valid_B1 = n_valid_B1, n_valid_total_window = n_valid_total, n_valid_cog_window = n_valid_cog,
        auc_missing_reason = auc_missing_reason, timing_source = events$timing_source,
        t_target_onset_rel = events$t_target_onset_rel, t_resp_start_rel = events$t_resp_start_rel
      )
    }, .keep = TRUE) %>%
    bind_rows()
  
  trial_features
}

# ----------------------------------------------------------------------------
# STEP 1: Load inputs
# ----------------------------------------------------------------------------

cat("STEP 1: Loading inputs...\n")

if (!file.exists(V5_CH2)) {
  stop("Missing: ", V5_CH2, "\nRun scripts/qc_build_quickshare_v5.R first.")
}
if (!file.exists(V5_CH3)) {
  stop("Missing: ", V5_CH3, "\nRun scripts/qc_build_quickshare_v5.R first.")
}
if (!file.exists(V4_MERGED)) {
  stop("Missing: ", V4_MERGED, "\nRun scripts/make_merged_quickshare_v4.R first.")
}

ch2_base <- read_csv(V5_CH2, show_col_types = FALSE)
ch3_base <- read_csv(V5_CH3, show_col_types = FALSE)
merged_base <- read_csv(V4_MERGED, show_col_types = FALSE)

cat("  ✓ Ch2 base: ", nrow(ch2_base), " trials\n", sep = "")
cat("  ✓ Ch3 base: ", nrow(ch3_base), " trials\n", sep = "")
cat("  ✓ Merged base: ", nrow(merged_base), " trials\n\n", sep = "")

# ----------------------------------------------------------------------------
# STEP 2: Compute AUC features from flat files
# ----------------------------------------------------------------------------

cat("STEP 2: Computing AUC features from flat files...\n")
cat("  (This may take several minutes)\n\n")

flat_files <- list.files(
  PROCESSED_DIR,
  pattern = ".*_(ADT|VDT)_flat\\.csv$",
  full.names = TRUE,
  recursive = TRUE
)

if (length(flat_files) == 0) {
  stop("No flat CSV files found in ", PROCESSED_DIR)
}

cat("  Found ", length(flat_files), " flat files\n", sep = "")

all_auc_features <- map_dfr(flat_files, process_flat_file_auc_v6, .progress = "text")

cat("\n  ✓ Processed ", nrow(all_auc_features), " trials\n", sep = "")

# Save intermediate
write_csv(all_auc_features, file.path(V6_INTERMEDIATE, "pupil_auc_trial_level.csv"))
cat("  ✓ Saved intermediate: intermediate/pupil_auc_trial_level.csv\n\n")

# ----------------------------------------------------------------------------
# STEP 3: Join AUC to Ch2/Ch3 datasets
# ----------------------------------------------------------------------------

cat("STEP 3: Joining AUC features to Ch2/Ch3 datasets...\n")

# Create trial_uid for joining
all_auc_features <- all_auc_features %>%
  mutate(trial_uid = paste(sub, task, session_used, run_used, trial_index, sep = ":"))

# Check for duplicates in AUC features and deduplicate
n_duplicates_auc <- sum(duplicated(all_auc_features$trial_uid))
if (n_duplicates_auc > 0) {
  cat("  ⚠ Found ", n_duplicates_auc, " duplicate trial_uid in AUC features; deduplicating...\n", sep = "")
  all_auc_features <- all_auc_features %>%
    group_by(trial_uid) %>%
    slice(1) %>%  # Take first occurrence
    ungroup()
}

ch2_base <- ch2_base %>%
  mutate(trial_uid = if ("trial_uid" %in% names(.)) trial_uid else paste(sub, task, session_used, run_used, trial_index, sep = ":"))

ch3_base <- ch3_base %>%
  mutate(trial_uid = if ("trial_uid" %in% names(.)) trial_uid else paste(sub, task, session_used, run_used, trial_index, sep = ":"))

# Check for duplicates in base datasets
n_duplicates_ch2 <- sum(duplicated(ch2_base$trial_uid))
n_duplicates_ch3 <- sum(duplicated(ch3_base$trial_uid))
if (n_duplicates_ch2 > 0 || n_duplicates_ch3 > 0) {
  cat("  ⚠ Found duplicates in base datasets (Ch2: ", n_duplicates_ch2, ", Ch3: ", n_duplicates_ch3, ")\n", sep = "")
}

# Join AUC (explicitly set relationship to avoid warning)
auc_features_unique <- all_auc_features %>%
  select(trial_uid, auc_total, auc_cog_fixed1s, cog_mean_fixed1s,
         n_valid_B0, n_valid_B1, n_valid_total_window, n_valid_cog_window,
         auc_missing_reason, timing_source) %>%
  distinct(trial_uid, .keep_all = TRUE)

ch2_with_auc <- ch2_base %>%
  left_join(
    auc_features_unique,
    by = "trial_uid",
    relationship = "many-to-one"
  ) %>%
  mutate(
    auc_available = !is.na(auc_total) & !is.na(auc_cog_fixed1s)
  )

ch3_with_auc <- ch3_base %>%
  left_join(
    auc_features_unique,
    by = "trial_uid",
    relationship = "many-to-one"
  ) %>%
  mutate(
    auc_available = !is.na(auc_total) & !is.na(auc_cog_fixed1s)
  )

write_csv(ch2_with_auc, file.path(V6_ANALYSIS, "ch2_analysis_ready_with_auc.csv"))
write_csv(ch3_with_auc, file.path(V6_ANALYSIS, "ch3_ddm_ready_with_auc.csv"))

cat("  ✓ Saved: analysis/ch2_analysis_ready_with_auc.csv\n")
cat("  ✓ Saved: analysis/ch3_ddm_ready_with_auc.csv\n\n")

# ----------------------------------------------------------------------------
# STEP 4: Generate waveform summaries
# ----------------------------------------------------------------------------

cat("STEP 4: Generating waveform summaries...\n")
cat("  (Processing flat files for waveforms; may take time)\n\n")

# Helper: Process one flat file for waveforms
process_flat_file_waveforms <- function(flat_path, merged_with_auc) {
  fn <- basename(flat_path)
  
  df <- fread(flat_path, showProgress = FALSE, data.table = FALSE)
  
  # Standardize columns (same as AUC function)
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
  
  meta <- df %>%
    distinct(sub, task, session_used, run_used) %>%
    slice(1)
  
  if (nrow(meta) != 1) return(tibble())
  
      # Get trial metadata from merged data
      trial_meta <- merged_with_auc %>%
        filter(
          sub == meta$sub,
          task == meta$task,
          session_used == meta$session_used,
          run_used == meta$run_used
        ) %>%
        select(trial_index, effort, isOddball, auc_available, n_valid_B0) %>%
        mutate(
          effort = if_else(is.na(effort), "Unknown", as.character(effort)),
          isOddball = if_else(is.na(isOddball), 0L, as.integer(isOddball))
        )
  
  # Extract event timing
  events <- extract_event_timing(df, meta$sub, meta$task, meta$session_used, meta$run_used)
  
  # Process each trial for waveforms
  waveforms <- df %>%
    group_by(trial_index) %>%
    group_map(~ {
      trial_num <- .y$trial_index
      
      trial_info <- trial_meta %>% filter(trial_index == trial_num)
      if (nrow(trial_info) == 0) return(tibble())
      
      # Only include trials with valid AUC (waveform gate)
      if (!trial_info$auc_available[1] || trial_info$n_valid_B0[1] < MIN_BASELINE_SAMPLES) {
        return(tibble())
      }
      
      n_samples <- nrow(.x)
      if (n_samples < 2) return(tibble())
      
      # Reconstruct time_rel
      time_diffs <- diff(sort(unique(.x$time)))
      dt_median <- median(time_diffs[time_diffs > 0], na.rm = TRUE)
      fs_est <- if_else(is.na(dt_median) || dt_median <= 0, FS_TARGET, 1.0 / dt_median)
      
      sample_i <- seq_len(n_samples)
      time_rel <- WINDOW_START + (sample_i - 1) / fs_est
      
      if (min(.x$time, na.rm = TRUE) >= WINDOW_START - 0.1 && 
          max(.x$time, na.rm = TRUE) <= WINDOW_START + 15) {
        time_rel <- .x$time
      }
      
      # Compute B0 baseline
      b0_mask <- time_rel >= B0_WIN[1] & time_rel <= B0_WIN[2]
      b0_mean <- mean(.x$pupil[b0_mask], na.rm = TRUE)
      
      # Baseline-corrected waveform
      pupil_corrected <- .x$pupil - b0_mean
      
      # Filter to waveform window: -0.5s to resp_start
      wave_mask <- time_rel >= -0.5 & time_rel <= events$t_resp_start_rel
      
      tibble(
        sub = meta$sub,
        task = meta$task,
        effort = trial_info$effort[1],
        isOddball = trial_info$isOddball[1],
        trial_index = trial_num,
        t = time_rel[wave_mask],
        pupil_corrected = pupil_corrected[wave_mask]
      )
    }, .keep = TRUE) %>%
    bind_rows()
  
  waveforms
}

# Process all flat files for waveforms (only trials with valid AUC)
cat("  Processing ", length(flat_files), " flat files for waveforms...\n", sep = "")

# Join merged data with AUC to get waveform gate info
merged_with_auc_for_waveforms <- merged_base %>%
  left_join(
    all_auc_features %>%
      select(sub, task, session_used, run_used, trial_index, n_valid_B0) %>%
      mutate(
        auc_available = TRUE,  # Only trials in all_auc_features have AUC computed
        n_valid_B0 = if_else(is.na(n_valid_B0), 0L, n_valid_B0)
      ),
    by = c("sub", "task", "session_used", "run_used", "trial_index")
  ) %>%
  mutate(
    auc_available = if_else(is.na(auc_available), FALSE, auc_available),
    n_valid_B0 = if_else(is.na(n_valid_B0), 0L, n_valid_B0)
  )

all_waveforms <- map_dfr(
  flat_files,
  ~ process_flat_file_waveforms(.x, merged_with_auc_for_waveforms),
  .progress = "text"
)

cat("\n  ✓ Extracted ", nrow(all_waveforms), " waveform samples\n", sep = "")

# Aggregate to condition means
if (nrow(all_waveforms) > 0) {
  # Create time grids
  t_max <- max(all_waveforms$t, na.rm = TRUE)
  t_grid_ch2 <- seq(-0.5, t_max, by = 1/FS_CH2_WAVEFORM)
  t_grid_ch3 <- seq(-0.5, t_max, by = 1/FS_CH3_WAVEFORM)
  
  # Interpolate each trial to grid, then aggregate
  waveform_ch2 <- all_waveforms %>%
    filter(!is.na(pupil_corrected)) %>%
    group_by(task, effort, isOddball, trial_index) %>%
    group_map(~ {
      if (nrow(.x) < 2) return(tibble())
      
      # Interpolate to 50Hz grid
      pupil_interp <- approx(.x$t, .x$pupil_corrected, xout = t_grid_ch2, 
                             method = "linear", rule = 2)$y
      
      tibble(
        task = first(.x$task),
        effort = first(.x$effort),
        isOddball = first(.x$isOddball),
        t = t_grid_ch2,
        pupil_corrected = pupil_interp
      )
    }, .keep = TRUE) %>%
    bind_rows() %>%
    group_by(task, effort, isOddball, t) %>%
    summarise(
      mean_pupil = mean(pupil_corrected, na.rm = TRUE),
      sem_pupil = sd(pupil_corrected, na.rm = TRUE) / sqrt(n()),
      n_trials = n(),
      .groups = "drop"
    )
  
  waveform_ch3 <- all_waveforms %>%
    filter(!is.na(pupil_corrected)) %>%
    group_by(task, effort, isOddball, trial_index) %>%
    group_map(~ {
      if (nrow(.x) < 2) return(tibble())
      
      # Interpolate to 100Hz grid
      pupil_interp <- approx(.x$t, .x$pupil_corrected, xout = t_grid_ch3, 
                             method = "linear", rule = 2)$y
      
      tibble(
        task = first(.x$task),
        effort = first(.x$effort),
        isOddball = first(.x$isOddball),
        t = t_grid_ch3,
        pupil_corrected = pupil_interp
      )
    }, .keep = TRUE) %>%
    bind_rows() %>%
    group_by(task, effort, isOddball, t) %>%
    summarise(
      mean_pupil = mean(pupil_corrected, na.rm = TRUE),
      sem_pupil = sd(pupil_corrected, na.rm = TRUE) / sqrt(n()),
      n_trials = n(),
      .groups = "drop"
    )
} else {
  waveform_ch2 <- tibble(
    task = character(), effort = character(), isOddball = integer(),
    t = numeric(), mean_pupil = numeric(), sem_pupil = numeric(), n_trials = integer()
  )
  waveform_ch3 <- waveform_ch2
}

write_csv(waveform_ch2, file.path(V6_ANALYSIS, "pupil_waveforms_condition_mean_ch2_50hz.csv"))
write_csv(waveform_ch3, file.path(V6_ANALYSIS, "pupil_waveforms_condition_mean_ch3_250hz.csv"))

cat("  ✓ Saved: analysis/pupil_waveforms_condition_mean_ch2_50hz.csv\n")
cat("  ✓ Saved: analysis/pupil_waveforms_condition_mean_ch3_250hz.csv\n")
if (nrow(waveform_ch2) > 0) {
  n_cond_ch2 <- waveform_ch2 %>% distinct(task, effort, isOddball) %>% nrow()
  cat("    Ch2: ", nrow(waveform_ch2), " rows, ", n_cond_ch2, " conditions\n", sep = "")
} else {
  cat("    Ch2: 0 rows (no valid waveforms)\n", sep = "")
}
if (nrow(waveform_ch3) > 0) {
  n_cond_ch3 <- waveform_ch3 %>% distinct(task, effort, isOddball) %>% nrow()
  cat("    Ch3: ", nrow(waveform_ch3), " rows, ", n_cond_ch3, " conditions\n\n", sep = "")
} else {
  cat("    Ch3: 0 rows (no valid waveforms)\n\n", sep = "")
}

# ----------------------------------------------------------------------------
# STEP 5: Generate QC outputs
# ----------------------------------------------------------------------------

cat("STEP 5: Generating QC outputs...\n")

# Timing coverage
timing_coverage <- all_auc_features %>%
  group_by(task, session_used, run_used) %>%
  summarise(
    n_trials = n(),
    n_ptb = sum(timing_source == "ptb", na.rm = TRUE),
    n_default = sum(timing_source == "default", na.rm = TRUE),
    pct_ptb = 100 * n_ptb / n_trials,
    .groups = "drop"
  )

write_csv(timing_coverage, file.path(V6_QC, "timing_event_time_coverage.csv"))
cat("  ✓ Saved: qc/timing_event_time_coverage.csv\n")

# AUC missingness reasons
auc_missingness <- all_auc_features %>%
  filter(is.na(auc_total) | is.na(auc_cog_fixed1s)) %>%
  count(task, auc_missing_reason, sort = TRUE) %>%
  rename(n_trials = n)

write_csv(auc_missingness, file.path(V6_QC, "auc_missingness_reasons.csv"))
cat("  ✓ Saved: qc/auc_missingness_reasons.csv\n")

# Gate pass rates
gate_rates <- merged_base %>%
  filter(has_behavioral_data) %>%
  group_by(task) %>%
  summarise(
    n_total = n(),
    pass_050 = sum(pass_primary_050, na.rm = TRUE),
    pass_060 = sum(pass_primary_060, na.rm = TRUE),
    pass_070 = sum(pass_primary_070, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    pct_pass_050 = 100 * pass_050 / n_total,
    pct_pass_060 = 100 * pass_060 / n_total,
    pct_pass_070 = 100 * pass_070 / n_total
  )

write_csv(gate_rates, file.path(V6_QC, "gate_pass_rates_overview.csv"))
cat("  ✓ Saved: qc/gate_pass_rates_overview.csv\n\n")

# ----------------------------------------------------------------------------
# STEP 6: Acceptance checks
# ----------------------------------------------------------------------------

cat("STEP 6: Acceptance checks...\n\n")

# Join rate
n_behavioral <- sum(merged_base$has_behavioral_data, na.rm = TRUE)
pct_behavioral <- 100 * n_behavioral / nrow(merged_base)
cat("  Behavioral join rate: ", n_behavioral, " / ", nrow(merged_base),
    " (", sprintf("%.1f", pct_behavioral), "%)\n", sep = "")

# AUC availability
auc_by_task <- all_auc_features %>%
  group_by(task) %>%
  summarise(
    n_total = n(),
    n_with_total = sum(!is.na(auc_total)),
    n_with_cog = sum(!is.na(auc_cog_fixed1s)),
    pct_total = 100 * n_with_total / n_total,
    pct_cog = 100 * n_with_cog / n_total,
    .groups = "drop"
  )

cat("\n  AUC availability by task:\n")
print(auc_by_task)

# Timing coverage
pct_ptb_overall <- 100 * sum(all_auc_features$timing_source == "ptb", na.rm = TRUE) / nrow(all_auc_features)
cat("\n  Timing coverage: ", sprintf("%.1f", pct_ptb_overall), "% using PTB event times\n", sep = "")

# Waveforms
if (exists("waveform_ch2") && nrow(waveform_ch2) > 0) {
  cat("\n  Waveforms:\n")
  cat("    Ch2 (50Hz): ", nrow(waveform_ch2), " rows\n", sep = "")
  cat("    Ch3 (100Hz): ", nrow(waveform_ch3), " rows\n", sep = "")
} else {
  cat("\n  Waveforms: Not generated (no valid trials)\n", sep = "")
}

# File sizes
ch2_size <- file.size(file.path(V6_ANALYSIS, "ch2_analysis_ready_with_auc.csv")) / 1e6
ch3_size <- file.size(file.path(V6_ANALYSIS, "ch3_ddm_ready_with_auc.csv")) / 1e6
cat("\n  File sizes:\n")
cat("    ch2_analysis_ready_with_auc.csv: ", sprintf("%.2f", ch2_size), " MB\n", sep = "")
cat("    ch3_ddm_ready_with_auc.csv: ", sprintf("%.2f", ch3_size), " MB\n", sep = "")

if (ch2_size > 20 || ch3_size > 20) {
  cat("  ⚠ WARNING: Some files exceed 20MB\n")
} else {
  cat("  ✓ All files < 20MB\n")
}

cat("\n=== QUICK-SHARE v6 COMPLETE ===\n")

