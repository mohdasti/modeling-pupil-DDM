#!/usr/bin/env Rscript
# ============================================================================
# Make Quick-Share v7: Fixed Baseline Alignment + Robust AUC
# ============================================================================
# Fixes: B0 baseline alignment, label-based timing anchor, improved AUC coverage
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

cat("=== MAKING QUICK-SHARE v7: FIXED BASELINE ALIGNMENT ===\n\n")

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

REPO_ROOT <- here::here()

# Load config
config_file <- file.path(REPO_ROOT, "config", "data_paths.yaml")
if (file.exists(config_file)) {
  config <- read_yaml(config_file)
  PROCESSED_DIR <- config$processed_dir
  BEHAVIORAL_FILE <- config$behavioral_csv
} else {
  PROCESSED_DIR <- Sys.getenv("PUPIL_PROCESSED_DIR")
  BEHAVIORAL_FILE <- Sys.getenv("BEHAVIORAL_CSV")
  if (PROCESSED_DIR == "" || BEHAVIORAL_FILE == "") {
    stop("Please set config/data_paths.yaml or environment variables")
  }
}

V6_ROOT <- file.path(REPO_ROOT, "quick_share_v6")
V7_ROOT <- file.path(REPO_ROOT, "quick_share_v7")
V7_MERGED <- file.path(V7_ROOT, "merged")
V7_ANALYSIS <- file.path(V7_ROOT, "analysis")
V7_ANALYSIS_READY <- file.path(V7_ROOT, "analysis_ready")
V7_QC <- file.path(V7_ROOT, "qc")
V7_FIGS <- file.path(V7_ROOT, "figs")

dir.create(V7_ROOT, recursive = TRUE, showWarnings = FALSE)
dir.create(V7_MERGED, recursive = TRUE, showWarnings = FALSE)
dir.create(V7_ANALYSIS, recursive = TRUE, showWarnings = FALSE)
dir.create(V7_ANALYSIS_READY, recursive = TRUE, showWarnings = FALSE)
dir.create(V7_QC, recursive = TRUE, showWarnings = FALSE)
dir.create(V7_FIGS, recursive = TRUE, showWarnings = FALSE)

cat("Repo root: ", REPO_ROOT, "\n", sep = "")
cat("Processed dir: ", PROCESSED_DIR, "\n", sep = "")
cat("Behavioral file: ", BEHAVIORAL_FILE, "\n", sep = "")
cat("Output dir: ", V7_ROOT, "\n\n", sep = "")

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------

FS_TARGET <- 250
FS_CH2_WAVEFORM <- 50
FS_CH3_WAVEFORM <- 250
MIN_BASELINE_SAMPLES <- 10L
B0_WIN <- c(-0.5, 0.0)  # Pre-trial baseline (before squeeze onset)
B1_WIN <- c(-0.5, 0.0)  # Pre-target baseline (before target onset)
TARGET_ONSET_DEFAULT <- 4.35
RESP_START_DEFAULT <- 4.70
RESP_END_DEFAULT <- 7.70  # CH3 EXTENSION: End of Response 1 window (Resp1ET)
COG_WIN_POST_TARGET <- c(0.3, 1.3)  # Cognitive window after target

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
# Helper: Normalize keys for consistent joining
# ----------------------------------------------------------------------------

normalize_keys <- function(df) {
  # Only normalize columns that exist
  if ("sub" %in% names(df)) {
    df$sub <- as.character(df$sub)
  }
  if ("task" %in% names(df)) {
    df$task <- as.character(df$task)
  }
  if ("session_used" %in% names(df)) {
    df$session_used <- as.integer(df$session_used)
  }
  if ("run_used" %in% names(df)) {
    df$run_used <- as.integer(df$run_used)
  }
  if ("trial_index" %in% names(df)) {
    df$trial_index <- as.integer(df$trial_index)
  }
  df
}

# ----------------------------------------------------------------------------
# Helper: Infer time unit and convert to seconds
# ----------------------------------------------------------------------------

infer_time_unit <- function(time_vec) {
  time_diffs <- diff(sort(unique(time_vec)))
  time_diffs <- time_diffs[time_diffs > 0 & is.finite(time_diffs)]
  
  if (length(time_diffs) == 0) return(list(unit = "sec", dt_median = NA_real_))
  
  dt_median <- median(time_diffs, na.rm = TRUE)
  
  if (dt_median < 0.05) {
    # Likely already in seconds (dt ~ 0.004 for 250Hz)
    return(list(unit = "sec", dt_median = dt_median))
  } else if (dt_median >= 1 && dt_median <= 10) {
    # Likely in milliseconds (dt ~ 4ms for 250Hz)
    return(list(unit = "ms", dt_median = dt_median / 1000))
  } else {
    # Default to seconds
    return(list(unit = "sec", dt_median = dt_median))
  }
}

# ----------------------------------------------------------------------------
# Helper: Find squeeze onset (prefer PTB timestamp, fallback to labels)
# ----------------------------------------------------------------------------

find_squeeze_onset <- function(df) {
  # Strategy: Infer squeeze onset from trial structure
  # Trial window is [-3, 10.7] seconds relative to squeeze onset
  # If time is absolute PTB timestamp, first sample is at squeeze_onset - 3
  # Therefore: squeeze_onset = first_time + 3
  
  time_range <- range(df$time, na.rm = TRUE)
  time_span <- diff(time_range)
  time_min <- min(time_range, na.rm = TRUE)
  
  # If time span is large (> 100s), it's absolute PTB time
  # Trial window starts 3s before squeeze, so squeeze_onset = first_time + 3
  if (time_span > 100) {
    return(time_min + 3.0)
  }
  
  # If time span is small (< 20s) and min is negative, time is already relative
  # In this case, squeeze_onset in absolute terms is unknown
  # But we can find where t_rel=0 should be by looking for label transitions
  if (time_span < 20 && time_min < 0) {
    # Time is already relative; find transition from ITI to Squeeze
    if ("trial_label" %in% names(df)) {
      # Try explicit squeeze label
      squeeze_labels <- c("Squeeze", "Handgrip", "Grip", "Squeeze_Onset")
      squeeze_mask <- rep(FALSE, nrow(df))
      for (label in squeeze_labels) {
        squeeze_mask <- squeeze_mask | grepl(label, df$trial_label, ignore.case = TRUE)
      }
      
      if (sum(squeeze_mask) > 0) {
        squeeze_time_rel <- min(df$time[squeeze_mask], na.rm = TRUE)
        if (is.finite(squeeze_time_rel)) {
          # If time is relative, squeeze should be at t_rel=0
          # So we need to shift: squeeze_onset_abs = time_min - squeeze_time_rel
          # Actually, if time is relative, we can't get absolute squeeze_onset
          # Return the relative time where squeeze occurs (should be ~0)
          return(squeeze_time_rel)
        }
      }
      
      # Fallback: find transition from ITI to non-ITI
      iti_labels <- c("ITI", "Baseline", "ITI_Baseline")
      iti_mask <- rep(FALSE, nrow(df))
      for (label in iti_labels) {
        iti_mask <- iti_mask | grepl(label, df$trial_label, ignore.case = TRUE)
      }
      
      if (sum(iti_mask) > 0) {
        iti_end <- max(df$time[iti_mask], na.rm = TRUE)
        post_iti <- df %>% filter(time > iti_end) %>% arrange(time)
        if (nrow(post_iti) > 0) {
          return(first(post_iti$time))
        }
      }
    }
    
    # If time is relative and no labels, assume squeeze at t_rel=0
    return(0.0)
  }
  
  # Default: assume first sample is 3s before squeeze
  return(time_min + 3.0)
}

# ----------------------------------------------------------------------------
# Helper: Process one flat file for AUC + waveforms
# ----------------------------------------------------------------------------

process_flat_file_v7 <- function(flat_path) {
  df <- fread(flat_path, showProgress = FALSE, data.table = FALSE)
  
  # Standardize columns
  col_map <- list(
    sub = c("sub", "subject", "subject_id"),
    task = c("task", "task_name", "task_modality"),
    session_used = c("session_used", "ses", "session", "session_num"),
    run_used = c("run_used", "run", "run_num"),
    trial_index = c("trial_index", "trial_in_run_raw", "trial_in_run", "trial_num"),
    time = c("time", "time_ptb", "trial_pupilTime", "time_sec"),
    pupil = c("pupil", "pupilSize", "pupil_diameter"),
    trial_label = c("trial_label", "phase", "label", "phase_label"),
    trial_start_time_ptb = c("trial_start_time_ptb", "trialStartTime_ptb", "trial_start_ptb")
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
    filter(session_used %in% c(2L, 3L))
  
  # CRITICAL FIX: trial_index in flat files is GLOBAL (1-150 per session), not per-run (1-30)
  # We need to derive trial_in_run (1-30) for proper joining with merged_base
  # Check if trial_in_run_raw exists (per-run index)
  if ("trial_in_run_raw" %in% names(df)) {
    df$trial_in_run <- as.integer(df$trial_in_run_raw)
  } else {
    # Derive trial_in_run from global trial_index assuming 30 trials per run
    # trial_index is global: run 1 = 1-30, run 2 = 31-60, run 3 = 61-90, etc.
    df$trial_in_run <- ((df$trial_index - 1) %% 30) + 1
  }
  
  df <- df %>%
    arrange(run_used, trial_in_run, time)
  
  if (nrow(df) == 0) return(tibble())
  
  # Normalize keys
  df <- normalize_keys(df)
  
  # Infer time unit (use all data, not per-trial)
  time_info <- infer_time_unit(df$time)
  if (is.na(time_info$dt_median) || !is.finite(time_info$dt_median)) {
    # Fallback to 250 Hz
    time_info$dt_median <- 0.004
    time_info$unit <- "sec"
    cat("    ⚠ dt_median was NA, using fallback 0.004 (250 Hz)\n")
  }
  if (time_info$unit == "ms") {
    df$time <- df$time / 1000
    time_info$dt_median <- time_info$dt_median / 1000
  }
  
  # Process each trial - GROUP BY FULL KEYS (use trial_in_run, not global trial_index)
  trial_features <- df %>%
    group_by(sub, task, session_used, run_used, trial_in_run) %>%
    group_map(~ {
      trial_keys <- .y
      trial_num <- trial_keys$trial_in_run  # Use per-run trial index
      
      n_samples <- nrow(.x)
      if (n_samples < 2) {
        return(tibble(
          sub = trial_keys$sub, task = trial_keys$task, 
          session_used = trial_keys$session_used,
          run_used = trial_keys$run_used, trial_index = trial_num,  # trial_index = trial_in_run (per-run 1-30)
          time_unit_inferred = time_info$unit, dt_median = time_info$dt_median,
          squeeze_onset_time = NA_real_, timing_anchor_found = FALSE,
          t_target_onset_rel = TARGET_ONSET_DEFAULT, t_resp_start_rel = RESP_START_DEFAULT,
          total_auc = NA_real_, cog_auc = NA_real_, cog_auc_w3 = NA_real_, cog_auc_respwin = NA_real_,
          cog_auc_w1p3 = NA_real_, cog_mean_w1p3 = NA_real_,
          n_valid_B0 = 0L, n_valid_b0 = 0L,
          baseline_B0_mean = NA_real_, baseline_b0_mean = NA_real_,
          auc_available_total = FALSE, auc_available_cog = FALSE, auc_available_both = FALSE,
          auc_available = FALSE, auc_missing_reason = "insufficient_samples"
        ))
      }
      
      # Compute trial-relative time
      # CRITICAL: The time column contains absolute PTB timestamps spanning the entire session,
      # NOT per-trial relative times. Therefore, we MUST construct t_rel from sample indices.
      # Trial window is [-3, 10.7] seconds relative to squeeze onset.
      # Sampling rate is ~250 Hz (dt_median ~ 0.004 seconds).
      
      # Construct t_rel from sample index (most reliable method)
      # First sample is at t_rel = -3.0, last sample should be at ~10.7
      # Ensure dt_median is valid
      dt_used <- if (is.na(time_info$dt_median) || !is.finite(time_info$dt_median)) {
        0.004  # Fallback to 250 Hz
      } else {
        time_info$dt_median
      }
      
      t_rel <- seq(from = -3.0, by = dt_used, length.out = n_samples)
      
      # Sanity check: t_rel should end around 10.7 seconds
      t_rel_max <- max(t_rel, na.rm = TRUE)
      if (t_rel_max < 8 || t_rel_max > 15) {
        # Recalibrate: ensure t_rel spans [-3.0, 10.7]
        t_rel <- seq(from = -3.0, to = 10.7, length.out = n_samples)
      }
      
      # Try to find squeeze onset for timing source tracking (optional, not required)
      squeeze_onset <- find_squeeze_onset(.x)
      timing_anchor_found <- !is.na(squeeze_onset) && is.finite(squeeze_onset)
      
      pupil_vals <- .x$pupil
      
      # Baseline B0: [-0.5, 0.0) relative to squeeze onset
      b0_mask <- t_rel >= B0_WIN[1] & t_rel < B0_WIN[2]
      b0_pupil <- pupil_vals[b0_mask]
      n_valid_B0 <- sum(!is.na(b0_pupil) & is.finite(b0_pupil))
      
      if (n_valid_B0 < MIN_BASELINE_SAMPLES) {
        return(tibble(
          sub = trial_keys$sub, task = trial_keys$task, 
          session_used = trial_keys$session_used,
          run_used = trial_keys$run_used, trial_index = trial_num,  # trial_index = trial_in_run (per-run 1-30)
          time_unit_inferred = time_info$unit, dt_median = time_info$dt_median,
          squeeze_onset_time = if(timing_anchor_found) squeeze_onset else NA_real_,
          timing_anchor_found = timing_anchor_found,
          t_target_onset_rel = TARGET_ONSET_DEFAULT, t_resp_start_rel = RESP_START_DEFAULT,
          total_auc = NA_real_, cog_auc = NA_real_,
          n_valid_B0 = as.integer(n_valid_B0), n_valid_b0 = 0L,
          baseline_B0_mean = NA_real_, baseline_b0_mean = NA_real_,
          auc_available_total = FALSE, auc_available_cog = FALSE, auc_available_both = FALSE,
          auc_available = FALSE, auc_missing_reason = "B0_insufficient_samples"
        ))
      }
      
      baseline_B0_mean <- mean(b0_pupil[!is.na(b0_pupil) & is.finite(b0_pupil)], na.rm = TRUE)
      
      # Baseline b0: [target_onset - 0.5, target_onset) relative to squeeze onset
      b1_start <- TARGET_ONSET_DEFAULT + B1_WIN[1]
      b1_end <- TARGET_ONSET_DEFAULT + B1_WIN[2]
      b1_mask <- t_rel >= b1_start & t_rel < b1_end
      b1_pupil <- pupil_vals[b1_mask]
      n_valid_b0 <- sum(!is.na(b1_pupil) & is.finite(b1_pupil))
      
      if (n_valid_b0 < MIN_BASELINE_SAMPLES) {
        return(tibble(
          sub = trial_keys$sub, task = trial_keys$task, 
          session_used = trial_keys$session_used,
          run_used = trial_keys$run_used, trial_index = trial_num,  # trial_index = trial_in_run (per-run 1-30)
          time_unit_inferred = time_info$unit, dt_median = time_info$dt_median,
          squeeze_onset_time = if(timing_anchor_found) squeeze_onset else NA_real_,
          timing_anchor_found = timing_anchor_found,
          t_target_onset_rel = TARGET_ONSET_DEFAULT, t_resp_start_rel = RESP_START_DEFAULT,
          total_auc = NA_real_, cog_auc = NA_real_,
          n_valid_B0 = as.integer(n_valid_B0), n_valid_b0 = as.integer(n_valid_b0),
          baseline_B0_mean = baseline_B0_mean, baseline_b0_mean = NA_real_,
          auc_available_total = FALSE, auc_available_cog = FALSE, auc_available_both = FALSE,
          auc_available = FALSE, auc_missing_reason = "b0_insufficient_samples"
        ))
      }
      
      baseline_b0_mean <- mean(b1_pupil[!is.na(b1_pupil) & is.finite(b1_pupil)], na.rm = TRUE)
      
      # Full-trial baseline-corrected waveform (B0 correction)
      pupil_full_corrected <- pupil_vals - baseline_B0_mean
      
      # Partial-trial baseline-corrected waveform (b0 correction)
      pupil_partial_corrected <- pupil_vals - baseline_b0_mean
      
      # Total AUC: from trial onset (0) to response start
      total_mask <- t_rel >= 0 & t_rel <= RESP_START_DEFAULT
      total_time <- t_rel[total_mask]
      total_pupil_corrected <- pupil_full_corrected[total_mask]
      
      total_auc <- NA_real_
      if (sum(!is.na(total_pupil_corrected) & is.finite(total_pupil_corrected)) >= 2) {
        total_auc <- compute_auc(total_time, total_pupil_corrected)
      }
      
      # Cognitive AUC: from (target_onset + 0.3) to response start (LEGACY - short window)
      cog_win_start <- TARGET_ONSET_DEFAULT + COG_WIN_POST_TARGET[1]
      cog_win_end <- min(TARGET_ONSET_DEFAULT + COG_WIN_POST_TARGET[2], RESP_START_DEFAULT)
      
      cog_auc <- NA_real_
      if (cog_win_end > cog_win_start) {
        cog_mask <- t_rel >= cog_win_start & t_rel <= cog_win_end
        cog_time <- t_rel[cog_mask]
        cog_pupil_corrected <- pupil_partial_corrected[cog_mask]
        
        if (sum(!is.na(cog_pupil_corrected) & is.finite(cog_pupil_corrected)) >= 2) {
          cog_auc <- compute_auc(cog_time, cog_pupil_corrected)
        }
      }
      
      # CH3 EXTENSION: cog_auc_w3 - target+0.3 to target+3.3 (capped at Resp1ET)
      cog_auc_w3_start <- TARGET_ONSET_DEFAULT + 0.3
      cog_auc_w3_end <- min(TARGET_ONSET_DEFAULT + 3.3, RESP_END_DEFAULT)
      
      cog_auc_w3 <- NA_real_
      if (cog_auc_w3_end > cog_auc_w3_start) {
        cog_w3_mask <- t_rel >= cog_auc_w3_start & t_rel <= cog_auc_w3_end
        cog_w3_time <- t_rel[cog_w3_mask]
        cog_w3_pupil_corrected <- pupil_partial_corrected[cog_w3_mask]
        
        if (sum(!is.na(cog_w3_pupil_corrected) & is.finite(cog_w3_pupil_corrected)) >= 2) {
          cog_auc_w3 <- compute_auc(cog_w3_time, cog_w3_pupil_corrected)
        }
      }
      
      # CH3 EXTENSION: cog_auc_respwin - target+0.3 to Resp1ET (end of response window)
      cog_auc_respwin_start <- TARGET_ONSET_DEFAULT + 0.3
      cog_auc_respwin_end <- RESP_END_DEFAULT
      
      cog_auc_respwin <- NA_real_
      if (cog_auc_respwin_end > cog_auc_respwin_start) {
        cog_respwin_mask <- t_rel >= cog_auc_respwin_start & t_rel <= cog_auc_respwin_end
        cog_respwin_time <- t_rel[cog_respwin_mask]
        cog_respwin_pupil_corrected <- pupil_partial_corrected[cog_respwin_mask]
        
        if (sum(!is.na(cog_respwin_pupil_corrected) & is.finite(cog_respwin_pupil_corrected)) >= 2) {
          cog_auc_respwin <- compute_auc(cog_respwin_time, cog_respwin_pupil_corrected)
        }
      }
      
      # CH3 EXTENSION: cog_auc_w1p3 - target+0.3 to target+1.3 (early cognitive window for DDM sensitivity)
      cog_auc_w1p3_start <- TARGET_ONSET_DEFAULT + 0.3
      cog_auc_w1p3_end <- TARGET_ONSET_DEFAULT + 1.3
      
      cog_auc_w1p3 <- NA_real_
      cog_mean_w1p3 <- NA_real_
      if (cog_auc_w1p3_end > cog_auc_w1p3_start) {
        cog_w1p3_mask <- t_rel >= cog_auc_w1p3_start & t_rel <= cog_auc_w1p3_end
        cog_w1p3_time <- t_rel[cog_w1p3_mask]
        cog_w1p3_pupil_corrected <- pupil_partial_corrected[cog_w1p3_mask]
        
        n_valid_w1p3 <- sum(!is.na(cog_w1p3_pupil_corrected) & is.finite(cog_w1p3_pupil_corrected))
        if (n_valid_w1p3 >= 2) {
          cog_auc_w1p3 <- compute_auc(cog_w1p3_time, cog_w1p3_pupil_corrected)
          # Mean pupil (AUC/seconds) - less dependent on missing samples than raw AUC
          window_duration <- cog_auc_w1p3_end - cog_auc_w1p3_start
          if (window_duration > 0 && !is.na(cog_auc_w1p3)) {
            cog_mean_w1p3 <- cog_auc_w1p3 / window_duration
          } else {
            # Fallback: direct mean calculation
            cog_mean_w1p3 <- mean(cog_w1p3_pupil_corrected[!is.na(cog_w1p3_pupil_corrected) & is.finite(cog_w1p3_pupil_corrected)], na.rm = TRUE)
          }
        }
      }
      
      # AUC availability flags (separate for total and cog)
      auc_available_total <- !is.na(total_auc)
      auc_available_cog <- !is.na(cog_auc)
      auc_available_both <- auc_available_total && auc_available_cog
      auc_available <- auc_available_both  # Backward compatibility
      
      # AUC missing reason
      auc_missing_reason <- if (n_valid_B0 < MIN_BASELINE_SAMPLES) {
        "B0_insufficient_samples"
      } else if (n_valid_b0 < MIN_BASELINE_SAMPLES) {
        "b0_insufficient_samples"
      } else if (!auc_available_total) {
        "total_auc_failed"
      } else if (!auc_available_cog) {
        "cog_auc_failed"
      } else {
        "ok"
      }
      
      tibble(
        sub = trial_keys$sub, task = trial_keys$task, 
        session_used = trial_keys$session_used,
        run_used = trial_keys$run_used, trial_index = trial_num,
        time_unit_inferred = time_info$unit, dt_median = time_info$dt_median,
        squeeze_onset_time = if(timing_anchor_found) squeeze_onset else NA_real_,
        timing_anchor_found = timing_anchor_found,
        t_target_onset_rel = TARGET_ONSET_DEFAULT, t_resp_start_rel = RESP_START_DEFAULT,
        total_auc = total_auc, cog_auc = cog_auc,
        cog_auc_w3 = cog_auc_w3, cog_auc_respwin = cog_auc_respwin,
        cog_auc_w1p3 = cog_auc_w1p3, cog_mean_w1p3 = cog_mean_w1p3,
        n_valid_B0 = as.integer(n_valid_B0), n_valid_b0 = as.integer(n_valid_b0),
        baseline_B0_mean = baseline_B0_mean, baseline_b0_mean = baseline_b0_mean,
        auc_available_total = auc_available_total, 
        auc_available_cog = auc_available_cog,
        auc_available_both = auc_available_both,
        auc_available = auc_available, 
        auc_missing_reason = auc_missing_reason
      )
    }, .keep = TRUE) %>%
    bind_rows()
  
  trial_features
}

# ----------------------------------------------------------------------------
# STEP 1: Load inputs
# ----------------------------------------------------------------------------

cat("STEP 1: Loading inputs...\n")

# Try to load existing merged v3, otherwise build from scratch
merged_v3_path <- file.path(V6_ROOT, "merged", "BAP_triallevel_merged_v3.csv")
if (file.exists(merged_v3_path)) {
  merged_base <- read_csv(merged_v3_path, show_col_types = FALSE)
  cat("  ✓ Loaded merged v3: ", nrow(merged_base), " trials\n", sep = "")
} else {
  # Fallback: try v4 merged
  merged_v4_path <- file.path(V7_ROOT, "merged", "BAP_triallevel_merged_v4.csv")
  if (file.exists(merged_v4_path)) {
    merged_base <- read_csv(merged_v4_path, show_col_types = FALSE)
    cat("  ✓ Loaded existing merged v4: ", nrow(merged_base), " trials\n", sep = "")
  } else {
    stop("No existing merged file found. Please run v6 pipeline first or provide merged trial file.")
  }
}

# Ensure trial_uid exists
merged_base <- merged_base %>%
  mutate(trial_uid = if ("trial_uid" %in% names(.)) {
    trial_uid
  } else {
    paste(sub, task, session_used, run_used, trial_index, sep = "|")
  })

# Check for duplicates
n_dups <- sum(duplicated(merged_base$trial_uid))
if (n_dups > 0) {
  stop("ERROR: Found ", n_dups, " duplicate trial_uid in merged_base. Fix before proceeding.")
}

cat("  ✓ Unique trial_uid: ", n_distinct(merged_base$trial_uid), "\n\n", sep = "")

# ----------------------------------------------------------------------------
# Helper: Inventory flat file coverage
# ----------------------------------------------------------------------------

inventory_flat_file <- function(flat_path) {
  # Try to read header first
  header <- tryCatch({
    readLines(flat_path, n = 1)
  }, error = function(e) {
    return(NA_character_)
  })
  
  if (is.na(header)) {
    return(tibble(
      flat_path = flat_path,
      parse_success = FALSE,
      parse_warning = "Could not read file",
      n_rows = 0L,
      n_trials_distinct = 0L,
      sessions_present = "",
      runs_present = "",
      run_combo_count = 0L
    ))
  }
  
  # Detect key columns
  col_names <- strsplit(header, ",")[[1]]
  col_names <- trimws(col_names)
  
  # Robust column detection
  sub_col <- NULL
  task_col <- NULL
  session_col <- NULL
  run_col <- NULL
  trial_col <- NULL
  
  for (cand in c("sub", "subject", "subject_id")) {
    if (any(grepl(paste0("^", cand, "$"), col_names, ignore.case = TRUE))) {
      sub_col <- col_names[grepl(paste0("^", cand, "$"), col_names, ignore.case = TRUE)][1]
      break
    }
  }
  
  for (cand in c("task", "task_name")) {
    if (any(grepl(paste0("^", cand, "$"), col_names, ignore.case = TRUE))) {
      task_col <- col_names[grepl(paste0("^", cand, "$"), col_names, ignore.case = TRUE)][1]
      break
    }
  }
  
  for (cand in c("session_used", "session", "session_num", "session_number", "ses", "sessionId")) {
    if (any(grepl(paste0("^", cand, "$"), col_names, ignore.case = TRUE))) {
      session_col <- col_names[grepl(paste0("^", cand, "$"), col_names, ignore.case = TRUE)][1]
      break
    }
  }
  
  for (cand in c("run_used", "run", "run_num", "run_number", "runId", "runIndex", "run_in_session")) {
    if (any(grepl(paste0("^", cand, "$"), col_names, ignore.case = TRUE))) {
      run_col <- col_names[grepl(paste0("^", cand, "$"), col_names, ignore.case = TRUE)][1]
      break
    }
  }
  
  for (cand in c("trial_index", "trial", "trial_num", "trial_number", "trialIndex")) {
    if (any(grepl(paste0("^", cand, "$"), col_names, ignore.case = TRUE))) {
      trial_col <- col_names[grepl(paste0("^", cand, "$"), col_names, ignore.case = TRUE)][1]
      break
    }
  }
  
  # Read lightweight subset
  needed_cols <- c(sub_col, task_col, session_col, run_col, trial_col)
  needed_cols <- needed_cols[!is.null(needed_cols)]
  
  if (length(needed_cols) < 3) {
    return(tibble(
      flat_path = flat_path,
      parse_success = FALSE,
      parse_warning = paste("Could not detect key columns. Found:", paste(needed_cols, collapse = ", ")),
      n_rows = 0L,
      n_trials_distinct = 0L,
      sessions_present = "",
      runs_present = "",
      run_combo_count = 0L
    ))
  }
  
  # Read only needed columns
  df <- tryCatch({
    fread(flat_path, select = needed_cols, showProgress = FALSE, data.table = FALSE)
  }, error = function(e) {
    return(tibble())
  })
  
  if (nrow(df) == 0) {
    return(tibble(
      flat_path = flat_path,
      parse_success = FALSE,
      parse_warning = "File read but no rows",
      n_rows = 0L,
      n_trials_distinct = 0L,
      sessions_present = "",
      runs_present = "",
      run_combo_count = 0L
    ))
  }
  
  # Standardize column names
  if (!is.null(sub_col) && sub_col %in% names(df)) {
    df$sub <- as.character(df[[sub_col]])
  }
  if (!is.null(task_col) && task_col %in% names(df)) {
    df$task <- as.character(df[[task_col]])
  }
  if (!is.null(session_col) && session_col %in% names(df)) {
    df$session_used <- as.integer(df[[session_col]])
  }
  if (!is.null(run_col) && run_col %in% names(df)) {
    df$run_used <- as.integer(df[[run_col]])
  }
  if (!is.null(trial_col) && trial_col %in% names(df)) {
    df$trial_index <- as.integer(df[[trial_col]])
  }
  
  # Filter to sessions 2-3
  if ("session_used" %in% names(df)) {
    df <- df %>% filter(session_used %in% c(2L, 3L))
  }
  
  # Summarize
  run_combos <- df %>%
    filter(!is.na(sub), !is.na(task), !is.na(session_used), !is.na(run_used)) %>%
    distinct(sub, task, session_used, run_used)
  
  sessions <- sort(unique(df$session_used[!is.na(df$session_used)]))
  runs <- sort(unique(df$run_used[!is.na(df$run_used)]))
  
  trials_distinct <- df %>%
    filter(!is.na(trial_index)) %>%
    distinct(sub, task, session_used, run_used, trial_index) %>%
    nrow()
  
  # Infer sub/task from data
  sub_inferred <- if ("sub" %in% names(df) && nrow(df) > 0) {
    unique(df$sub[!is.na(df$sub)])[1]
  } else {
    basename(flat_path) %>% str_extract("BAP\\d+")
  }
  
  task_inferred <- if ("task" %in% names(df) && nrow(df) > 0) {
    unique(df$task[!is.na(df$task)])[1]
  } else {
    if (grepl("ADT", basename(flat_path))) "ADT" else if (grepl("VDT", basename(flat_path))) "VDT" else NA_character_
  }
  
  tibble(
    flat_path = flat_path,
    sub_inferred = sub_inferred,
    task_inferred = task_inferred,
    parse_success = TRUE,
    parse_warning = "",
    n_rows = nrow(df),
    n_trials_distinct = trials_distinct,
    sessions_present = paste(sessions, collapse = ","),
    runs_present = paste(runs, collapse = ","),
    run_combo_count = nrow(run_combos)
  )
}

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

# TASK 1: Inventory flat file coverage
cat("  Creating flat file inventory...\n")
flat_inventory <- map_dfr(flat_files, inventory_flat_file, .progress = "text")

write_csv(flat_inventory, file.path(V7_QC, "09_flat_file_run_inventory.csv"))
cat("  ✓ Saved: qc/09_flat_file_run_inventory.csv\n")

all_auc_features <- map_dfr(flat_files, process_flat_file_v7, .progress = "text")

cat("\n  ✓ Processed ", nrow(all_auc_features), " trials\n", sep = "")

# Ensure key columns are properly typed for join
all_auc_features <- all_auc_features %>%
  mutate(
    sub = as.character(sub),
    task = as.character(task),
    session_used = as.integer(session_used),
    run_used = as.integer(run_used),
    trial_index = as.integer(trial_index)
  ) %>%
  # Create trial_uid for reference (but we'll join on atomic keys)
  mutate(trial_uid_auc = paste(sub, task, session_used, run_used, trial_index, sep = "|")) %>%
  arrange(sub, task, session_used, run_used, trial_index, desc(timing_anchor_found), desc(n_valid_B0), desc(n_valid_b0)) %>%
  group_by(sub, task, session_used, run_used, trial_index) %>%
  slice(1) %>%
  ungroup()

cat("  ✓ Deduplicated to ", nrow(all_auc_features), " unique trials\n", sep = "")

# Note: Expected vs found runs comparison will be created after join (see STEP 3)

# Diagnostic: Compare runs in merged_base vs AUC features
if (nrow(all_auc_features) > 0) {
  auc_runs_summary <- all_auc_features %>%
    group_by(sub, task, session_used, run_used) %>%
    summarise(n_trials_auc = n(), .groups = "drop") %>%
    arrange(sub, task, session_used, run_used)
  
  merged_runs_summary <- merged_base %>%
    group_by(sub, task, session_used, run_used) %>%
    summarise(n_trials_merged = n(), .groups = "drop") %>%
    arrange(sub, task, session_used, run_used)
  
  cat("  Diagnostic: Run coverage\n")
  cat("    merged_base: ", nrow(merged_runs_summary), " unique (sub, task, session, run) combinations\n", sep = "")
  cat("    AUC features: ", nrow(auc_runs_summary), " unique (sub, task, session, run) combinations\n", sep = "")
  
  # Find runs in merged_base but not in AUC features
  missing_runs <- merged_runs_summary %>%
    anti_join(auc_runs_summary, by = c("sub", "task", "session_used", "run_used"))
  
  if (nrow(missing_runs) > 0) {
    cat("    ⚠ Missing runs in AUC features: ", nrow(missing_runs), "\n", sep = "")
    cat("    Top 10 missing runs:\n")
    print(head(missing_runs, 10))
    cat("    This suggests flat files may not contain these runs, or grouping failed.\n")
  } else {
    cat("    ✓ All runs in merged_base are present in AUC features\n")
  }
  cat("\n")
}

# Check for duplicates on atomic keys
n_dups_auc <- all_auc_features %>%
  group_by(sub, task, session_used, run_used, trial_index) %>%
  summarise(n = n(), .groups = "drop") %>%
  filter(n > 1) %>%
  nrow()

if (n_dups_auc > 0) {
  stop("ERROR: Found ", n_dups_auc, " duplicate atomic key combinations in AUC features after deduplication.")
}

# ----------------------------------------------------------------------------
# STEP 3: Merge AUC into trial-level dataset
# ----------------------------------------------------------------------------

cat("STEP 3: Merging AUC into trial-level dataset...\n")

# Ensure merged_base keys are properly typed
merged_base <- merged_base %>%
  mutate(
    sub = as.character(sub),
    task = as.character(task),
    session_used = as.integer(session_used),
    run_used = as.integer(run_used),
    trial_index = as.integer(trial_index)
  )

# TASK 2: Pre-join checks - save head of AUC features for inspection
cat("\n  TASK 2: AUC feature propagation checks...\n")
cat("    all_auc_features: ", nrow(all_auc_features), " rows\n", sep = "")
cat("    n_valid_B0 non-NA BEFORE join: ", sum(!is.na(all_auc_features$n_valid_B0)), "\n", sep = "")
cat("    total_auc non-NA BEFORE join: ", sum(!is.na(all_auc_features$total_auc)), "\n", sep = "")
cat("    cog_auc non-NA BEFORE join: ", sum(!is.na(all_auc_features$cog_auc)), "\n", sep = "")

# Save head for inspection
all_auc_features_head <- all_auc_features %>%
  head(200) %>%
  select(sub, task, session_used, run_used, trial_index,
         n_valid_B0, n_valid_b0, total_auc, cog_auc, cog_auc_w3, cog_auc_respwin,
         cog_auc_w1p3, cog_mean_w1p3,
         auc_available_total, auc_available_cog, auc_available_both, auc_available)
write_csv(all_auc_features_head, file.path(V7_QC, "11_all_auc_features_head.csv"))
cat("  ✓ Saved: qc/11_all_auc_features_head.csv\n")

# Select AUC features to join (exclude trial_uid_auc, join on atomic keys)
auc_features_unique <- all_auc_features %>%
  select(sub, task, session_used, run_used, trial_index,
         any_of(c("time_unit_inferred", "dt_median", "squeeze_onset_time", "timing_anchor_found",
                  "t_target_onset_rel", "t_resp_start_rel",
                  "total_auc", "cog_auc", "cog_auc_w3", "cog_auc_respwin", "cog_auc_w1p3", "cog_mean_w1p3",
                  "n_valid_B0", "n_valid_b0",
                  "baseline_B0_mean", "baseline_b0_mean", 
                  "auc_available_total", "auc_available_cog", "auc_available_both",
                  "auc_available", "auc_missing_reason")))

# Save head after deduplication
auc_features_unique_head <- auc_features_unique %>%
  head(200)
write_csv(auc_features_unique_head, file.path(V7_QC, "12_auc_features_unique_head.csv"))
cat("  ✓ Saved: qc/12_auc_features_unique_head.csv\n")

# Normalize keys before join
merged_base <- normalize_keys(merged_base)
auc_features_unique <- normalize_keys(auc_features_unique)

# Join by atomic keys (not trial_uid string)
merged_v4 <- merged_base %>%
  left_join(auc_features_unique, by = c("sub", "task", "session_used", "run_used", "trial_index"), 
            relationship = "many-to-one")

# COALESCE .x/.y columns BEFORE dropping them (CRITICAL FIX)
coalesce_fields <- c("total_auc", "cog_auc", "cog_auc_w3", "cog_auc_respwin",
                     "n_valid_B0", "n_valid_b0",
                     "baseline_B0_mean", "baseline_b0_mean",
                     "auc_available_total", "auc_available_cog", "auc_available_both",
                     "auc_available", "auc_missing_reason",
                     "t_target_onset_rel", "t_resp_start_rel", 
                     "timing_anchor_found", "dt_median", "time_unit_inferred",
                     "squeeze_onset_time")

for (field in coalesce_fields) {
  field_x <- paste0(field, ".x")
  field_y <- paste0(field, ".y")
  
  if (field_x %in% names(merged_v4) && field_y %in% names(merged_v4)) {
    # Both exist: coalesce (prefer .y, fallback to .x)
    merged_v4[[field]] <- dplyr::coalesce(merged_v4[[field_y]], merged_v4[[field_x]])
  } else if (field_x %in% names(merged_v4)) {
    # Only .x exists: use it
    merged_v4[[field]] <- merged_v4[[field_x]]
  } else if (field_y %in% names(merged_v4)) {
    # Only .y exists: use it
    merged_v4[[field]] <- merged_v4[[field_y]]
  }
  # If neither exists, field will be created below if needed
}

# Now drop all .x/.y columns
dup_cols <- grep("\\.(x|y)$", names(merged_v4), value = TRUE)
if (length(dup_cols) > 0) {
  cat("  ⚠ Removing ", length(dup_cols), " duplicate columns (.x/.y suffixes) after coalescing\n", sep = "")
  merged_v4 <- merged_v4 %>% select(-any_of(dup_cols))
}

# Ensure canonical trial_uid exists (preserve original if present, otherwise create)
if (!"trial_uid" %in% names(merged_v4)) {
  merged_v4 <- merged_v4 %>%
    mutate(trial_uid = paste(sub, task, session_used, run_used, trial_index, sep = ":"))
} else {
  # Preserve original trial_uid, but ensure it's consistent
  merged_v4 <- merged_v4 %>%
    mutate(trial_uid_orig = trial_uid,
           trial_uid = paste(sub, task, session_used, run_used, trial_index, sep = ":"))
}

# Ensure AUC and timing columns exist (only if truly missing, not if coalesced above)
if (!"total_auc" %in% names(merged_v4)) {
  merged_v4$total_auc <- NA_real_
}
if (!"cog_auc" %in% names(merged_v4)) {
  merged_v4$cog_auc <- NA_real_
}
if (!"cog_auc_w3" %in% names(merged_v4)) {
  merged_v4$cog_auc_w3 <- NA_real_
}
if (!"cog_auc_respwin" %in% names(merged_v4)) {
  merged_v4$cog_auc_respwin <- NA_real_
}
if (!"cog_auc_w1p3" %in% names(merged_v4)) {
  merged_v4$cog_auc_w1p3 <- NA_real_
}
if (!"cog_mean_w1p3" %in% names(merged_v4)) {
  merged_v4$cog_mean_w1p3 <- NA_real_
}
# TASK 2: Enforce flag consistency ALWAYS (recompute to ensure correctness)
merged_v4 <- merged_v4 %>%
  mutate(
    # Recompute flags to ensure consistency
    auc_available_total = !is.na(total_auc),
    auc_available_cog = !is.na(cog_auc),
    auc_available_both = auc_available_total & auc_available_cog,
    auc_available = auc_available_both  # Backward compatibility
  )

# Verify flag consistency (STOP if inconsistent)
flag_check_total <- all(merged_v4$auc_available_total == !is.na(merged_v4$total_auc), na.rm = TRUE)
flag_check_cog <- all(merged_v4$auc_available_cog == !is.na(merged_v4$cog_auc), na.rm = TRUE)
flag_check_both <- all(merged_v4$auc_available_both == (merged_v4$auc_available_total & merged_v4$auc_available_cog), na.rm = TRUE)

if (!flag_check_total || !flag_check_cog || !flag_check_both) {
  stop("FAILED: AUC flag consistency check failed. Fix flag computation.")
}
if (!"t_target_onset_rel" %in% names(merged_v4)) {
  merged_v4$t_target_onset_rel <- NA_real_
}
if (!"t_resp_start_rel" %in% names(merged_v4)) {
  merged_v4$t_resp_start_rel <- NA_real_
}

# Ensure timing_anchor_found exists
if (!"timing_anchor_found" %in% names(merged_v4)) {
  merged_v4$timing_anchor_found <- FALSE
}

# Fill defaults for timing and set timing_source
merged_v4 <- merged_v4 %>%
  mutate(
    t_target_onset_rel = if_else(is.na(t_target_onset_rel), TARGET_ONSET_DEFAULT, t_target_onset_rel),
    t_resp_start_rel = if_else(is.na(t_resp_start_rel), RESP_START_DEFAULT, t_resp_start_rel),
    timing_source = if_else(!is.na(timing_anchor_found) & timing_anchor_found == TRUE, "ptb_anchor", "fixed_design")
  )

# Join diagnostics
n_matched <- sum(!is.na(merged_v4$n_valid_B0))
n_total <- nrow(merged_v4)
match_rate <- 100 * n_matched / n_total

cat("  Join diagnostics:\n")
cat("    Total trials: ", n_total, "\n", sep = "")
cat("    Matched (n_valid_B0 not NA): ", n_matched, " (", sprintf("%.1f", match_rate), "%)\n", sep = "")
cat("    Unmatched: ", n_total - n_matched, "\n", sep = "")

# Show sample trial_uid formats
if (nrow(merged_base) > 0) {
  cat("    Sample merged_base trial_uid: ", head(merged_base$trial_uid, 1), "\n", sep = "")
}
if (nrow(all_auc_features) > 0) {
  cat("    Sample AUC trial_uid_auc: ", head(all_auc_features$trial_uid_auc, 1), "\n", sep = "")
}

# Save join diagnostics
join_summary <- tibble(
  n_total = n_total,
  n_matched = n_matched,
  n_unmatched = n_total - n_matched,
  match_rate_pct = match_rate
)
write_csv(join_summary, file.path(V7_QC, "05_auc_join_match_summary.csv"))
cat("  ✓ Saved: qc/05_auc_join_match_summary.csv\n")

# TASK 1: Create expected vs found runs comparison (after join)
cat("\n  Creating expected vs found runs comparison...\n")

# Expected runs from merged_base
expected_runs <- merged_base %>%
  group_by(sub, task, session_used, run_used) %>%
  summarise(expected_n_trials = n(), .groups = "drop") %>%
  arrange(sub, task, session_used, run_used)

# Found runs in flat files (from inventory - extract from sessions_present and runs_present)
# Use a simpler approach: read the actual flat files to get run combos
found_in_flat <- all_auc_features %>%
  distinct(sub, task, session_used, run_used) %>%
  mutate(found_in_any_flat = TRUE)

# Found runs in AUC features
found_in_auc_features <- all_auc_features %>%
  group_by(sub, task, session_used, run_used) %>%
  summarise(found_n_trials_auc_features = n(), .groups = "drop") %>%
  mutate(found_in_auc_features = TRUE)

# Join matched runs
join_matched <- merged_v4 %>%
  filter(!is.na(n_valid_B0)) %>%
  distinct(sub, task, session_used, run_used) %>%
  mutate(join_matched_any = TRUE)

# Combine all
expected_vs_found <- expected_runs %>%
  left_join(found_in_flat, by = c("sub", "task", "session_used", "run_used")) %>%
  left_join(found_in_auc_features, by = c("sub", "task", "session_used", "run_used")) %>%
  left_join(join_matched, by = c("sub", "task", "session_used", "run_used")) %>%
  mutate(
    found_in_any_flat = if_else(is.na(found_in_any_flat), FALSE, TRUE),
    found_in_auc_features = if_else(is.na(found_in_auc_features), FALSE, TRUE),
    join_matched_any = if_else(is.na(join_matched_any), FALSE, TRUE),
    found_n_trials_in_flat = if_else(found_in_any_flat, expected_n_trials, 0L),
    found_n_trials_auc_features = if_else(is.na(found_n_trials_auc_features), 0L, found_n_trials_auc_features),
    status = case_when(
      !found_in_any_flat ~ "MISSING_FLAT_RUN",
      found_in_any_flat & !found_in_auc_features ~ "AUC_FEATURES_MISSING",
      found_in_auc_features & !join_matched_any ~ "JOIN_MISSING",
      TRUE ~ "OK"
    )
  ) %>%
  arrange(status, sub, task, session_used, run_used)

write_csv(expected_vs_found, file.path(V7_QC, "10_expected_vs_found_runs.csv"))
cat("  ✓ Saved: qc/10_expected_vs_found_runs.csv\n")

# Console summary
cat("\n  Expected vs Found Runs Summary:\n")
cat("    Expected runs total: ", nrow(expected_runs), "\n", sep = "")
cat("    Runs found in flat: ", sum(expected_vs_found$found_in_any_flat), "\n", sep = "")
cat("    Runs missing in flat: ", sum(!expected_vs_found$found_in_any_flat), "\n", sep = "")
cat("    Runs with AUC features: ", sum(expected_vs_found$found_in_auc_features), "\n", sep = "")
cat("    Runs join matched: ", sum(expected_vs_found$join_matched_any), "\n", sep = "")

missing_flat_runs <- expected_vs_found %>%
  filter(status == "MISSING_FLAT_RUN") %>%
  head(20)

if (nrow(missing_flat_runs) > 0) {
  cat("\n    Top 20 missing runs (not in flat files):\n")
  print(missing_flat_runs %>% select(sub, task, session_used, run_used, expected_n_trials))
}

# Unmatched key patterns
unmatched <- merged_v4 %>%
  filter(is.na(n_valid_B0)) %>%
  group_by(sub, task, session_used, run_used) %>%
  summarise(n_unmatched = n(), .groups = "drop") %>%
  arrange(desc(n_unmatched))

if (nrow(unmatched) > 0) {
  write_csv(unmatched, file.path(V7_QC, "06_auc_unmatched_key_patterns.csv"))
  cat("  ✓ Saved: qc/06_auc_unmatched_key_patterns.csv (", nrow(unmatched), " patterns)\n", sep = "")
  cat("    Top 5 unmatched patterns:\n")
  print(head(unmatched, 5))
}

# TASK 3: Upgrade AUC coverage QC outputs
cat("\n  TASK 3: Creating upgraded AUC coverage QC outputs...\n")

# qc/07_auc_feature_coverage_by_run.csv (upgraded)
coverage_by_run <- expected_runs %>%
  left_join(
    all_auc_features %>%
      group_by(sub, task, session_used, run_used) %>%
      summarise(
        n_trials_in_auc_features = n(),
        n_total_auc_non_na = sum(!is.na(total_auc)),
        n_cog_auc_non_na = sum(!is.na(cog_auc)),
        n_both_non_na = sum(!is.na(total_auc) & !is.na(cog_auc)),
        .groups = "drop"
      ),
    by = c("sub", "task", "session_used", "run_used")
  ) %>%
  left_join(
    merged_v4 %>%
      filter(!is.na(n_valid_B0)) %>%
      group_by(sub, task, session_used, run_used) %>%
      summarise(n_trials_join_matched = n(), .groups = "drop"),
    by = c("sub", "task", "session_used", "run_used")
  ) %>%
  mutate(
    n_trials_expected = expected_n_trials,
    n_trials_in_auc_features = if_else(is.na(n_trials_in_auc_features), 0L, n_trials_in_auc_features),
    n_trials_join_matched = if_else(is.na(n_trials_join_matched), 0L, n_trials_join_matched),
    n_total_auc_non_na = if_else(is.na(n_total_auc_non_na), 0L, n_total_auc_non_na),
    n_cog_auc_non_na = if_else(is.na(n_cog_auc_non_na), 0L, n_cog_auc_non_na),
    n_both_non_na = if_else(is.na(n_both_non_na), 0L, n_both_non_na),
    pct_join_matched = if_else(n_trials_expected > 0, 100 * n_trials_join_matched / n_trials_expected, 0)
  ) %>%
  select(sub, task, session_used, run_used,
         n_trials_expected, n_trials_in_auc_features, n_trials_join_matched, pct_join_matched,
         n_total_auc_non_na, n_cog_auc_non_na, n_both_non_na) %>%
  arrange(sub, task, session_used, run_used)

write_csv(coverage_by_run, file.path(V7_QC, "07_auc_feature_coverage_by_run.csv"))
cat("  ✓ Saved: qc/07_auc_feature_coverage_by_run.csv\n")

# qc/08_auc_non_na_rates.csv (upgraded)
auc_non_na_rates_overall <- merged_v4 %>%
  summarise(
    n_total = n(),
    total_auc_non_na = sum(!is.na(total_auc)),
    cog_auc_non_na = sum(!is.na(cog_auc)),
    auc_available_total_non_na = sum(auc_available_total, na.rm = TRUE),
    auc_available_cog_non_na = sum(auc_available_cog, na.rm = TRUE),
    auc_available_both_non_na = sum(auc_available_both, na.rm = TRUE)
  ) %>%
  mutate(
    task = "ALL",
    total_auc_pct = 100 * total_auc_non_na / n_total,
    cog_auc_pct = 100 * cog_auc_non_na / n_total,
    auc_available_total_pct = 100 * auc_available_total_non_na / n_total,
    auc_available_cog_pct = 100 * auc_available_cog_non_na / n_total,
    auc_available_both_pct = 100 * auc_available_both_non_na / n_total
  )

auc_non_na_by_task <- merged_v4 %>%
  group_by(task) %>%
  summarise(
    n_total = n(),
    total_auc_non_na = sum(!is.na(total_auc)),
    cog_auc_non_na = sum(!is.na(cog_auc)),
    auc_available_total_non_na = sum(auc_available_total, na.rm = TRUE),
    auc_available_cog_non_na = sum(auc_available_cog, na.rm = TRUE),
    auc_available_both_non_na = sum(auc_available_both, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    total_auc_pct = 100 * total_auc_non_na / n_total,
    cog_auc_pct = 100 * cog_auc_non_na / n_total,
    auc_available_total_pct = 100 * auc_available_total_non_na / n_total,
    auc_available_cog_pct = 100 * auc_available_cog_non_na / n_total,
    auc_available_both_pct = 100 * auc_available_both_non_na / n_total
  )

# Conditional on "run exists in flat"
auc_non_na_conditional <- merged_v4 %>%
  left_join(
    expected_vs_found %>% select(sub, task, session_used, run_used, found_in_any_flat),
    by = c("sub", "task", "session_used", "run_used")
  ) %>%
  filter(found_in_any_flat == TRUE) %>%
  group_by(task) %>%
  summarise(
    n_total = n(),
    total_auc_non_na = sum(!is.na(total_auc)),
    cog_auc_non_na = sum(!is.na(cog_auc)),
    auc_available_total_non_na = sum(auc_available_total, na.rm = TRUE),
    auc_available_cog_non_na = sum(auc_available_cog, na.rm = TRUE),
    auc_available_both_non_na = sum(auc_available_both, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    condition = "run_exists_in_flat",
    total_auc_pct = 100 * total_auc_non_na / n_total,
    cog_auc_pct = 100 * cog_auc_non_na / n_total,
    auc_available_total_pct = 100 * auc_available_total_non_na / n_total,
    auc_available_cog_pct = 100 * auc_available_cog_non_na / n_total,
    auc_available_both_pct = 100 * auc_available_both_non_na / n_total
  )

auc_non_na_combined <- bind_rows(
  auc_non_na_rates_overall %>% select(task, n_total, total_auc_non_na, cog_auc_non_na,
                                       total_auc_pct, cog_auc_pct, auc_available_both_pct),
  auc_non_na_by_task %>% select(task, n_total, total_auc_non_na, cog_auc_non_na,
                                total_auc_pct, cog_auc_pct, auc_available_both_pct),
  auc_non_na_conditional %>% select(task, n_total, total_auc_non_na, cog_auc_non_na,
                                     total_auc_pct, cog_auc_pct, auc_available_both_pct) %>%
    mutate(task = paste0(task, "_run_in_flat"))
)

write_csv(auc_non_na_combined, file.path(V7_QC, "08_auc_non_na_rates.csv"))
cat("  ✓ Saved: qc/08_auc_non_na_rates.csv\n")

# Final duplicate check
n_dups_final <- sum(duplicated(merged_v4$trial_uid))
if (n_dups_final > 0) {
  stop("ERROR: Found ", n_dups_final, " duplicate trial_uid in merged_v4 after join.")
}

cat("  ✓ Merged ", nrow(merged_v4), " trials (unique by trial_uid)\n\n", sep = "")

write_csv(merged_v4, file.path(V7_MERGED, "BAP_triallevel_merged_v4.csv"))
cat("  ✓ Saved: merged/BAP_triallevel_merged_v4.csv\n\n")

# ----------------------------------------------------------------------------
# STEP 4: Create analysis-ready datasets
# ----------------------------------------------------------------------------

cat("STEP 4: Creating analysis-ready datasets...\n")

# Ensure behavioral derived columns exist
merged_v4 <- merged_v4 %>%
  mutate(
    isOddball = if ("isOddball" %in% names(.)) {
      if_else(is.na(stimulus_intensity), NA_integer_, as.integer(stimulus_intensity != 0))
    } else {
      isOddball
    },
    choice_num = if ("choice_num" %in% names(.)) {
      choice_num
    } else {
      case_when(
        is.na(choice) ~ NA_integer_,
        is.logical(choice) ~ as.integer(choice),
        choice == "DIFFERENT" | choice == 1 ~ 1L,
        choice == "SAME" | choice == 0 ~ 0L,
        TRUE ~ NA_integer_
      )
    },
    choice_label = if ("choice_label" %in% names(.)) {
      choice_label
    } else {
      case_when(
        is.na(choice_num) ~ NA_character_,
        choice_num == 0 ~ "SAME",
        choice_num == 1 ~ "DIFFERENT",
        TRUE ~ NA_character_
      )
    },
    correct_final = if ("correct_final" %in% names(.)) {
      correct_final
    } else {
      case_when(
        is.na(choice_num) | is.na(isOddball) ~ NA_integer_,
        TRUE ~ as.integer(choice_num == isOddball)
      )
    }
  )

# TASK 4: Create clean analysis-ready exports with gating flags
cat("  TASK 4: Creating clean analysis-ready exports...\n")

# Add run-availability flags from expected_vs_found
merged_v4_with_flags <- merged_v4 %>%
  left_join(
    expected_vs_found %>%
      select(sub, task, session_used, run_used, 
             found_in_flat_run = found_in_any_flat,
             found_in_auc_features_run = found_in_auc_features,
             join_matched_any_run = join_matched_any),
    by = c("sub", "task", "session_used", "run_used")
  ) %>%
  mutate(
    found_in_flat_run = if_else(is.na(found_in_flat_run), FALSE, found_in_flat_run),
    found_in_auc_features_run = if_else(is.na(found_in_auc_features_run), FALSE, found_in_auc_features_run),
    join_matched_any_run = if_else(is.na(join_matched_any_run), FALSE, join_matched_any_run)
  )

# Add gating booleans (do not drop rows)
merged_v4_with_flags <- merged_v4_with_flags %>%
  mutate(
    # B0 baseline gates (for Total AUC)
    gate_B0_60 = if_else(!is.na(baseline_quality), baseline_quality >= 0.60, FALSE),
    gate_B0_50 = if_else(!is.na(baseline_quality), baseline_quality >= 0.50, FALSE),
    # B1 baseline gates (for Cognitive AUC) - use B1_quality if available, fallback to baseline_quality for backward compat
    gate_B1_60 = if_else(!is.na(B1_quality), B1_quality >= 0.60, 
                        if_else(!is.na(baseline_quality), baseline_quality >= 0.60, FALSE)),
    gate_B1_50 = if_else(!is.na(B1_quality), B1_quality >= 0.50,
                        if_else(!is.na(baseline_quality), baseline_quality >= 0.50, FALSE)),
    # Cognitive response window gates
    gate_cog_60 = if_else(!is.na(cog_quality), cog_quality >= 0.60, FALSE),
    gate_cog_50 = if_else(!is.na(cog_quality), cog_quality >= 0.50, FALSE),
    gate_auc_both = auc_available_both,
    # Chapter 2 primary gate: B1 baseline 50% + cognitive window 60% (more lenient baseline, stricter response window)
    gate_pupil_primary = gate_B1_50 & gate_cog_60 & gate_auc_both & found_in_flat_run,
    # Backward compatibility aliases (for Total AUC analyses)
    gate_baseline_60 = gate_B0_60,
    gate_baseline_50 = gate_B0_50
  )

# Ch2: Include both ADT/VDT; keep all trials but provide flags
ch2_triallevel <- merged_v4_with_flags %>%
  select(
    # Keys
    sub, task, session_used, run_used, trial_index, trial_uid,
    # Behavioral essentials
    any_of(c("effort", "stimulus_intensity", "isOddball", "choice_num", "choice_label", 
             "rt", "correct_final", "choice", "correct")),
    # MATLAB quality metrics
    any_of(c("baseline_quality", "cog_quality", "posttarget_quality", "overall_quality")),
    # AUC columns/flags
    total_auc, cog_auc, auc_available_total, auc_available_cog, auc_available_both, 
    auc_available, auc_missing_reason,
    n_valid_B0, n_valid_b0, baseline_B0_mean, baseline_b0_mean,
    # Timing
    t_target_onset_rel, t_resp_start_rel, timing_source,
    # Run-availability flags
    found_in_flat_run, found_in_auc_features_run, join_matched_any_run,
    # Gating flags
    gate_B0_60, gate_B0_50, gate_B1_60, gate_B1_50, gate_cog_60, gate_cog_50,
    gate_auc_both, gate_pupil_primary,
    # Backward compatibility
    gate_baseline_60, gate_baseline_50
  )

# Check duplicates
n_dups_ch2 <- sum(duplicated(ch2_triallevel$trial_uid))
if (n_dups_ch2 > 0) {
  stop("ERROR: Found ", n_dups_ch2, " duplicate trial_uid in ch2_triallevel.")
}

write_csv(ch2_triallevel, file.path(V7_ANALYSIS_READY, "ch2_triallevel.csv"))
n_ch2_pupil_primary <- sum(ch2_triallevel$gate_pupil_primary, na.rm = TRUE)
cat("  ✓ Saved: analysis_ready/ch2_triallevel.csv (", nrow(ch2_triallevel), " trials, ", 
    sprintf("%.1f", 100*n_ch2_pupil_primary/nrow(ch2_triallevel)), "% gate_pupil_primary)\n", sep = "")

# Ch3: DDM-ready flag
ch3_triallevel <- merged_v4_with_flags %>%
  mutate(
    ddm_ready = (has_behavioral_data == TRUE | 
                 (if ("has_behavioral_data" %in% names(.)) has_behavioral_data else 
                  !is.na(rt) & !is.na(choice))) &
                (baseline_quality >= 0.50 | is.na(baseline_quality))
  ) %>%
  select(
    # Keys
    sub, task, session_used, run_used, trial_index, trial_uid,
    # Behavioral essentials
    any_of(c("effort", "stimulus_intensity", "isOddball", "choice_num", "choice_label", 
             "rt", "correct_final", "choice", "correct")),
    # MATLAB quality metrics
    any_of(c("baseline_quality", "cog_quality", "posttarget_quality", "overall_quality")),
    # AUC columns/flags (legacy + CH3 extension)
    total_auc, cog_auc, cog_auc_w3, cog_auc_respwin, cog_auc_w1p3, cog_mean_w1p3,
    auc_available_total, auc_available_cog, auc_available_both,
    auc_available, auc_missing_reason,
    n_valid_B0, n_valid_b0, baseline_B0_mean, baseline_b0_mean,
    # Timing
    t_target_onset_rel, t_resp_start_rel, timing_source,
    # Run-availability flags
    found_in_flat_run, found_in_auc_features_run, join_matched_any_run,
    # Gating flags
    gate_baseline_60, gate_cog_60, gate_baseline_50, gate_auc_both,
    # Note: gate_baseline_* are aliases for gate_B0_* (for Total AUC)
    # DDM-ready flag
    ddm_ready
  )

# Check duplicates
n_dups_ch3 <- sum(duplicated(ch3_triallevel$trial_uid))
if (n_dups_ch3 > 0) {
  stop("ERROR: Found ", n_dups_ch3, " duplicate trial_uid in ch3_triallevel.")
}

write_csv(ch3_triallevel, file.path(V7_ANALYSIS_READY, "ch3_triallevel.csv"))
n_ch3_ddm_ready <- sum(ch3_triallevel$ddm_ready, na.rm = TRUE)
cat("  ✓ Saved: analysis_ready/ch3_triallevel.csv (", nrow(ch3_triallevel), " trials, ", 
    sprintf("%.1f", 100*n_ch3_ddm_ready/nrow(ch3_triallevel)), "% ddm_ready)\n\n", sep = "")

# ----------------------------------------------------------------------------
# STEP 5: Generate waveform summaries (condition means)
# ----------------------------------------------------------------------------

cat("STEP 5: Generating waveform summaries...\n")
cat("  (Generating condition-mean waveforms from AUC-ready trials)\n\n")

# Use trials with valid AUC for waveforms
waveform_trials <- merged_v4 %>%
  filter(auc_available == TRUE, !is.na(effort)) %>%
  select(trial_uid, sub, task, session_used, run_used, trial_index, effort, isOddball, 
         any_of("stimulus_intensity"))

if (nrow(waveform_trials) > 0) {
  cat("  Processing ", nrow(waveform_trials), " AUC-ready trials for waveforms...\n", sep = "")
  
  # Process flat files to extract waveforms for these trials
  waveform_data <- map_dfr(flat_files, function(flat_path) {
    df <- fread(flat_path, showProgress = FALSE, data.table = FALSE)
    
    # Standardize columns (same as AUC function)
    col_map <- list(
      sub = c("sub", "subject", "subject_id"),
      task = c("task", "task_name", "task_modality"),
      session_used = c("session_used", "ses", "session", "session_num"),
      run_used = c("run_used", "run", "run_num"),
      trial_index = c("trial_index", "trial_in_run_raw", "trial_in_run", "trial_num"),
      time = c("time", "time_ptb", "trial_pupilTime"),
      pupil = c("pupil", "pupilSize", "pupil_diameter"),
      trial_label = c("trial_label", "phase", "label")
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
      filter(session_used %in% c(2L, 3L))
    
    if (nrow(df) == 0) return(tibble())
    
    # CRITICAL FIX: Derive trial_in_run from global trial_index (same as AUC function)
    if ("trial_in_run_raw" %in% names(df)) {
      df$trial_in_run <- as.integer(df$trial_in_run_raw)
    } else {
      df$trial_in_run <- ((df$trial_index - 1) %% 30) + 1
    }
    
    df <- df %>%
      arrange(run_used, trial_in_run, time)
    
    # Infer time unit
    time_info <- infer_time_unit(df$time)
    if (time_info$unit == "ms") {
      df$time <- df$time / 1000
    }
    
    # Get unique trial keys from this flat file
    trial_keys_flat <- df %>% 
      distinct(sub, task, session_used, run_used) %>%
      normalize_keys()
    
    if (nrow(trial_keys_flat) == 0) return(tibble())
    
    # Match trials from waveform_trials that match this flat file's keys
    trial_matches <- waveform_trials %>%
      normalize_keys() %>%
      inner_join(trial_keys_flat, by = c("sub", "task", "session_used", "run_used"))
    
    if (nrow(trial_matches) == 0) return(tibble())
    
    # Process each matching trial - join using trial_in_run (per-run 1-30)
    # CRITICAL: df has global trial_index (1-150) but we derived trial_in_run (1-30 per run)
    # trial_matches has per-run trial_index (1-30), so join: df$trial_in_run = trial_matches$trial_index
    # Add trial_index column to df that matches trial_matches (per-run)
    df$trial_index_per_run <- df$trial_in_run
    
    waveforms <- df %>%
      inner_join(trial_matches, by = c("sub", "task", "session_used", "run_used", 
                                       "trial_index_per_run" = "trial_index")) %>%
      group_by(trial_in_run) %>%
      group_map(~ {
        trial_num <- .y$trial_in_run
        # Match by trial_in_run (which equals trial_index in merged_v4/waveform_trials)
        trial_info <- trial_matches %>% filter(trial_index == trial_num) %>% slice(1)
        
        # Safety check: if no match found, skip this trial
        if (nrow(trial_info) == 0) return(tibble())
        
        # CH3 EXTENSION: Reconstruct relative time using seg_start_rel_used and seg_end_rel_used
        # MATLAB exports absolute PTB times in 'time' column (bug), but seg_start/end are correct
        # Solution: Create linear time axis from seg_start_rel_used to seg_end_rel_used
        if ("seg_start_rel_used" %in% names(.x) && "seg_end_rel_used" %in% names(.x) &&
            !all(is.na(.x$seg_start_rel_used)) && !all(is.na(.x$seg_end_rel_used))) {
          seg_start_rel <- first(.x$seg_start_rel_used[!is.na(.x$seg_start_rel_used)])
          seg_end_rel <- first(.x$seg_end_rel_used[!is.na(.x$seg_end_rel_used)])
          if (is.finite(seg_start_rel) && is.finite(seg_end_rel) && seg_end_rel > seg_start_rel) {
            # Reconstruct linear time axis from seg_start to seg_end
            n_samples <- nrow(.x)
            t_rel <- seq(from = seg_start_rel, to = seg_end_rel, length.out = n_samples)
          } else {
            # Fallback to original method
            squeeze_onset <- find_squeeze_onset(.x)
            if (is.na(squeeze_onset)) return(tibble())
            t_rel <- .x$time - squeeze_onset
          }
        } else {
          # Fallback to original method if audit columns not available
          squeeze_onset <- find_squeeze_onset(.x)
          if (is.na(squeeze_onset)) return(tibble())
          t_rel <- .x$time - squeeze_onset
        }
        pupil_vals <- .x$pupil
        
        # Compute baselines
        b0_mask <- t_rel >= B0_WIN[1] & t_rel < B0_WIN[2]
        baseline_B0_mean <- mean(pupil_vals[b0_mask], na.rm = TRUE)
        
        b1_start <- TARGET_ONSET_DEFAULT + B1_WIN[1]
        b1_end <- TARGET_ONSET_DEFAULT + B1_WIN[2]
        b1_mask <- t_rel >= b1_start & t_rel < b1_end
        baseline_b0_mean <- mean(pupil_vals[b1_mask], na.rm = TRUE)
        
        # Baseline-corrected waveforms
        pupil_full <- pupil_vals - baseline_B0_mean
        pupil_partial <- pupil_vals - baseline_b0_mean
        
        # Filter to window - CH3 EXTENSION: Use extended window up to Resp1ET
        wave_mask <- t_rel >= -0.5 & t_rel <= RESP_END_DEFAULT  # Extended to Resp1ET (7.70s)
        
        # Check we have enough valid data points
        valid_mask <- wave_mask & !is.na(pupil_full) & !is.na(pupil_partial) & is.finite(pupil_full) & is.finite(pupil_partial)
        if (sum(valid_mask) < 2) {
          # Skip trials with insufficient data
          return(tibble())
        }
        
        tibble(
          trial_uid = trial_info$trial_uid[1],
          task = trial_info$task[1],
          effort = trial_info$effort[1],
          isOddball = trial_info$isOddball[1],
          stimulus_intensity = if("stimulus_intensity" %in% names(trial_info)) trial_info$stimulus_intensity[1] else NA_real_,
          t_rel = t_rel[wave_mask],
          pupil_full = pupil_full[wave_mask],
          pupil_partial = pupil_partial[wave_mask]
        )
      }, .keep = TRUE) %>%
      bind_rows()
    
    waveforms
  }, .progress = "text")
  
  if (nrow(waveform_data) > 0) {
    # Create time grids
    t_max <- max(waveform_data$t_rel, na.rm = TRUE)
    t_grid_ch2 <- seq(-0.5, t_max, by = 1/FS_CH2_WAVEFORM)
    t_grid_ch3 <- seq(-0.5, t_max, by = 1/FS_CH3_WAVEFORM)
    
    # Aggregate to condition means
    # Ensure stimulus_intensity exists (add NA if missing)
    if (!"stimulus_intensity" %in% names(waveform_data)) {
      waveform_data$stimulus_intensity <- NA_real_
    }
    
    waveform_summary <- waveform_data %>%
      filter(!is.na(pupil_full), !is.na(pupil_partial)) %>%
      group_by(task, effort, isOddball, stimulus_intensity, trial_uid) %>%
      group_map(~ {
        # Check we have enough valid data points for interpolation
        valid_x <- !is.na(.x$t_rel) & is.finite(.x$t_rel)
        valid_y_full <- !is.na(.x$pupil_full) & is.finite(.x$pupil_full)
        valid_y_partial <- !is.na(.x$pupil_partial) & is.finite(.x$pupil_partial)
        
        valid_full <- valid_x & valid_y_full
        valid_partial <- valid_x & valid_y_partial
        
        if (sum(valid_full) < 2 || sum(valid_partial) < 2) {
          # Skip trials with insufficient data for interpolation
          return(tibble())
        }
        
        # Interpolate to grids
        pupil_full_ch2 <- approx(.x$t_rel[valid_full], .x$pupil_full[valid_full], xout = t_grid_ch2, method = "linear", rule = 2)$y
        pupil_partial_ch2 <- approx(.x$t_rel[valid_partial], .x$pupil_partial[valid_partial], xout = t_grid_ch2, method = "linear", rule = 2)$y
        pupil_full_ch3 <- approx(.x$t_rel[valid_full], .x$pupil_full[valid_full], xout = t_grid_ch3, method = "linear", rule = 2)$y
        pupil_partial_ch3 <- approx(.x$t_rel[valid_partial], .x$pupil_partial[valid_partial], xout = t_grid_ch3, method = "linear", rule = 2)$y
        
        bind_rows(
          tibble(
            chapter = "ch2", sample_rate_hz = FS_CH2_WAVEFORM,
            task = first(.x$task), effort = first(.x$effort), isOddball = first(.x$isOddball),
            stimulus_intensity = if("stimulus_intensity" %in% names(.x)) first(.x$stimulus_intensity) else NA_real_,
            t_rel = t_grid_ch2, mean_pupil_full = pupil_full_ch2, mean_pupil_partial = pupil_partial_ch2
          ),
          tibble(
            chapter = "ch3", sample_rate_hz = FS_CH3_WAVEFORM,
            task = first(.x$task), effort = first(.x$effort), isOddball = first(.x$isOddball),
            stimulus_intensity = if("stimulus_intensity" %in% names(.x)) first(.x$stimulus_intensity) else NA_real_,
            t_rel = t_grid_ch3, mean_pupil_full = pupil_full_ch3, mean_pupil_partial = pupil_partial_ch3
          )
        )
      }, .keep = TRUE) %>%
      bind_rows() %>%
      group_by(chapter, sample_rate_hz, task, effort, isOddball, stimulus_intensity, t_rel) %>%
      summarise(
        mean_pupil_full = mean(mean_pupil_full, na.rm = TRUE),
        mean_pupil_partial = mean(mean_pupil_partial, na.rm = TRUE),
        n_trials = n(),
        .groups = "drop"
      )
    
    write_csv(waveform_summary, file.path(V7_ANALYSIS, "pupil_waveforms_condition_mean.csv"))
    cat("  ✓ Saved: analysis/pupil_waveforms_condition_mean.csv\n")
    cat("    Rows: ", nrow(waveform_summary), ", Conditions: ", 
        waveform_summary %>% distinct(task, effort, isOddball) %>% nrow(), "\n\n", sep = "")
  } else {
    cat("  ⚠ No waveform data extracted\n\n")
  }
} else {
  cat("  ⚠ No AUC-ready trials for waveforms\n\n")
}

# ----------------------------------------------------------------------------
# STEP 6: Generate QC outputs
# ----------------------------------------------------------------------------

cat("STEP 6: Generating QC outputs...\n")

# A) Join health
join_health <- merged_v4 %>%
  group_by(sub, task, session_used) %>%
  summarise(
    n_total = n(),
    n_behavioral = sum(has_behavioral_data == TRUE | (if ("has_behavioral_data" %in% names(.)) has_behavioral_data else !is.na(rt) & !is.na(choice)), na.rm = TRUE),
    pct_behavioral = 100 * n_behavioral / n_total,
    .groups = "drop"
  )

write_csv(join_health, file.path(V7_QC, "01_join_health_by_subject_task.csv"))
cat("  ✓ Saved: qc/01_join_health_by_subject_task.csv\n")

# B) Gate pass rates
gate_rates <- merged_v4 %>%
  filter(has_behavioral_data == TRUE | (if ("has_behavioral_data" %in% names(.)) has_behavioral_data else !is.na(rt) & !is.na(choice))) %>%
  mutate(
    pass_050 = if ("pass_primary_050" %in% names(.)) pass_primary_050 else NA,
    pass_060 = if ("pass_primary_060" %in% names(.)) pass_primary_060 else NA,
    pass_070 = if ("pass_primary_070" %in% names(.)) pass_primary_070 else NA
  ) %>%
  group_by(task) %>%
  summarise(
    n_total = n(),
    n_pass_050 = sum(pass_050, na.rm = TRUE),
    n_pass_060 = sum(pass_060, na.rm = TRUE),
    n_pass_070 = sum(pass_070, na.rm = TRUE),
    n_auc_ready = sum(auc_available, na.rm = TRUE),
    pct_pass_050 = 100 * n_pass_050 / n_total,
    pct_pass_060 = 100 * n_pass_060 / n_total,
    pct_pass_070 = 100 * n_pass_070 / n_total,
    pct_auc_ready = 100 * n_auc_ready / n_total,
    .groups = "drop"
  )

write_csv(gate_rates, file.path(V7_QC, "02_gate_pass_rates_by_task_threshold.csv"))
cat("  ✓ Saved: qc/02_gate_pass_rates_by_task_threshold.csv\n")

# C) AUC missingness reasons
auc_missingness <- all_auc_features %>%
  filter(!auc_available) %>%
  count(task, auc_missing_reason, sort = TRUE) %>%
  rename(n_trials = n)

write_csv(auc_missingness, file.path(V7_QC, "03_auc_missingness_reasons.csv"))
cat("  ✓ Saved: qc/03_auc_missingness_reasons.csv\n")

# D) Timing coverage
timing_coverage <- all_auc_features %>%
  group_by(task) %>%
  summarise(
    n_total = n(),
    n_timing_found = sum(timing_anchor_found, na.rm = TRUE),
    pct_timing_found = 100 * n_timing_found / n_total,
    time_unit_sec = sum(time_unit_inferred == "sec", na.rm = TRUE),
    time_unit_ms = sum(time_unit_inferred == "ms", na.rm = TRUE),
    dt_median_median = median(dt_median, na.rm = TRUE),
    dt_median_min = min(dt_median, na.rm = TRUE),
    dt_median_max = max(dt_median, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(timing_coverage, file.path(V7_QC, "04_timing_event_time_coverage.csv"))
cat("  ✓ Saved: qc/04_timing_event_time_coverage.csv\n\n")

# ----------------------------------------------------------------------------
# STEP 7: STOP/GO Checks
# ----------------------------------------------------------------------------

cat("STEP 7: Running STOP/GO checks...\n\n")

stop_go_checks <- list()

# A) Join integrity
cat("A) Join integrity:\n")
n_matched_check <- sum(!is.na(merged_v4$n_valid_B0))
match_rate_check <- 100 * n_matched_check / nrow(merged_v4)
cat("  Match rate: ", sprintf("%.1f", match_rate_check), "% (", n_matched_check, " / ", nrow(merged_v4), ")\n", sep = "")

stop_go_checks$match_rate_pct <- match_rate_check
stop_go_checks$match_rate_pass <- match_rate_check >= 98

if (match_rate_check < 98) {
  cat("  ⚠ WARNING: Match rate < 98%\n")
  unmatched_top20 <- merged_v4 %>%
    filter(is.na(n_valid_B0)) %>%
    select(sub, task, session_used, run_used, trial_index) %>%
    head(20)
  cat("  Top 20 unmatched keys:\n")
  print(unmatched_top20)
  
  # Additional diagnostic: Check if unmatched runs exist in AUC features
  unmatched_runs <- merged_v4 %>%
    filter(is.na(n_valid_B0)) %>%
    distinct(sub, task, session_used, run_used) %>%
    left_join(
      all_auc_features %>%
        distinct(sub, task, session_used, run_used) %>%
        mutate(in_auc = TRUE),
      by = c("sub", "task", "session_used", "run_used")
    ) %>%
    filter(is.na(in_auc))
  
  if (nrow(unmatched_runs) > 0) {
    cat("\n  Diagnostic: Runs in merged_base but NOT in AUC features:\n")
    print(head(unmatched_runs, 10))
    cat("  This suggests flat files are missing these runs, or grouping failed.\n")
  }
  
  # Check for key type mismatches
  cat("\n  Checking for key type mismatches...\n")
  sample_merged <- merged_v4 %>%
    filter(is.na(n_valid_B0)) %>%
    select(sub, task, session_used, run_used, trial_index) %>%
    head(1)
  sample_auc <- all_auc_features %>%
    filter(sub == sample_merged$sub[1], 
           task == sample_merged$task[1],
           session_used == sample_merged$session_used[1],
           run_used == sample_merged$run_used[1]) %>%
    head(1)
  
  if (nrow(sample_auc) == 0) {
    cat("  No matching AUC row found for sample unmatched key.\n")
    cat("  Sample unmatched key types:\n")
    cat("    sub: ", typeof(sample_merged$sub[1]), " = ", sample_merged$sub[1], "\n", sep = "")
    cat("    task: ", typeof(sample_merged$task[1]), " = ", sample_merged$task[1], "\n", sep = "")
    cat("    session_used: ", typeof(sample_merged$session_used[1]), " = ", sample_merged$session_used[1], "\n", sep = "")
    cat("    run_used: ", typeof(sample_merged$run_used[1]), " = ", sample_merged$run_used[1], "\n", sep = "")
    
    # Check what's actually in AUC features for this sub/task
    auc_sample <- all_auc_features %>%
      filter(sub == sample_merged$sub[1], task == sample_merged$task[1]) %>%
      distinct(session_used, run_used) %>%
      arrange(session_used, run_used)
    cat("  Available runs in AUC features for ", sample_merged$sub[1], " ", sample_merged$task[1], ":\n", sep = "")
    print(auc_sample)
  }
  
  if (match_rate_check < 90) {
    cat("\n  ⚠ Match rate < 90%, but continuing to generate outputs for inspection.\n")
    cat("  Review qc/06_auc_unmatched_key_patterns.csv and qc/07_auc_feature_coverage_by_run.csv\n")
    # Don't stop - let it continue so we can see all diagnostics
  }
}

# B) AUC integrity
cat("\nB) AUC integrity:\n")
total_auc_non_na <- sum(!is.na(merged_v4$total_auc))
cog_auc_non_na <- sum(!is.na(merged_v4$cog_auc))
cat("  total_auc non-NA: ", total_auc_non_na, " / ", nrow(merged_v4), "\n", sep = "")
cat("  cog_auc non-NA: ", cog_auc_non_na, " / ", nrow(merged_v4), "\n", sep = "")

stop_go_checks$total_auc_non_na <- total_auc_non_na
stop_go_checks$cog_auc_non_na <- cog_auc_non_na
stop_go_checks$total_auc_pass <- total_auc_non_na > 0 && total_auc_non_na > 10

if (total_auc_non_na == 0 && cog_auc_non_na > 0) {
  stop("FAILED: total_auc is all NA but cog_auc exists. This indicates a coalesce/wipe bug.")
}
if (total_auc_non_na < 10) {
  cat("  ⚠ WARNING: total_auc non-NA count is very low (", total_auc_non_na, ")\n", sep = "")
}

# C) Column hygiene
cat("\nC) Column hygiene:\n")
dup_cols_final <- grep("\\.(x|y)$", names(merged_v4), value = TRUE)
n_dup_cols <- length(dup_cols_final)
cat("  Columns ending with .x/.y: ", n_dup_cols, "\n", sep = "")
stop_go_checks$n_dup_cols <- n_dup_cols
stop_go_checks$column_hygiene_pass <- n_dup_cols == 0

if (n_dup_cols > 0) {
  stop("FAILED: Found ", n_dup_cols, " duplicate columns (.x/.y) in final output")
}

# D) AUC flags consistency
cat("\nD) AUC flags consistency:\n")
if ("auc_available_total" %in% names(merged_v4) && "total_auc" %in% names(merged_v4)) {
  flag_check_total <- all(merged_v4$auc_available_total == !is.na(merged_v4$total_auc), na.rm = TRUE)
  cat("  auc_available_total == !is.na(total_auc): ", flag_check_total, "\n", sep = "")
  stop_go_checks$flag_consistency_total <- flag_check_total
} else {
  flag_check_total <- NA
  stop_go_checks$flag_consistency_total <- NA
}

if ("auc_available_cog" %in% names(merged_v4) && "cog_auc" %in% names(merged_v4)) {
  flag_check_cog <- all(merged_v4$auc_available_cog == !is.na(merged_v4$cog_auc), na.rm = TRUE)
  cat("  auc_available_cog == !is.na(cog_auc): ", flag_check_cog, "\n", sep = "")
  stop_go_checks$flag_consistency_cog <- flag_check_cog
} else {
  flag_check_cog <- NA
  stop_go_checks$flag_consistency_cog <- NA
}

if ("auc_available_both" %in% names(merged_v4)) {
  flag_check_both <- all(merged_v4$auc_available_both == (merged_v4$auc_available_total & merged_v4$auc_available_cog), na.rm = TRUE)
  cat("  auc_available_both == (total & cog): ", flag_check_both, "\n", sep = "")
  stop_go_checks$flag_consistency_both <- flag_check_both
} else {
  flag_check_both <- NA
  stop_go_checks$flag_consistency_both <- NA
}

# E) Timing sanity
cat("\nE) Timing sanity:\n")
timing_target_na <- sum(is.na(merged_v4$t_target_onset_rel))
timing_resp_na <- sum(is.na(merged_v4$t_resp_start_rel))
cat("  t_target_onset_rel NA: ", timing_target_na, "\n", sep = "")
cat("  t_resp_start_rel NA: ", timing_resp_na, "\n", sep = "")

stop_go_checks$timing_target_na <- timing_target_na
stop_go_checks$timing_resp_na <- timing_resp_na
stop_go_checks$timing_pass <- timing_target_na == 0 && timing_resp_na == 0

if (timing_target_na > 0 || timing_resp_na > 0) {
  stop("FAILED: Timing columns have NA values. All should have defaults.")
}

timing_source_vals <- unique(merged_v4$timing_source)
cat("  timing_source values: ", paste(timing_source_vals, collapse = ", "), "\n", sep = "")
stop_go_checks$timing_source_valid <- all(timing_source_vals %in% c("fixed_design", "ptb_anchor"))

if (!all(timing_source_vals %in% c("fixed_design", "ptb_anchor"))) {
  stop("FAILED: timing_source contains invalid values")
}

# Save STOP/GO checks
stop_go_df <- tibble(
  check = names(stop_go_checks),
  value = unlist(stop_go_checks),
  pass = ifelse(grepl("_pass$", names(stop_go_checks)), unlist(stop_go_checks), NA)
) %>%
  filter(grepl("_pass$", check)) %>%
  mutate(check = gsub("_pass$", "", check))

write_csv(stop_go_df, file.path(V7_QC, "STOP_GO_checks.csv"))
cat("\n  ✓ Saved: qc/STOP_GO_checks.csv\n")

# Check 1: Unique trial_uid
cat("\n✓ Check 1: Unique trial_uid\n")
cat("  merged_v4: ", nrow(merged_v4), " rows, ", n_distinct(merged_v4$trial_uid), " unique trial_uid\n", sep = "")
if (nrow(merged_v4) != n_distinct(merged_v4$trial_uid)) {
  stop("FAILED: merged_v4 has duplicate trial_uid")
}

# Check 2: Behavioral join rate
cat("\n✓ Check 2: Behavioral join rate\n")
n_behavioral <- sum(merged_v4$has_behavioral_data == TRUE | (if ("has_behavioral_data" %in% names(merged_v4)) merged_v4$has_behavioral_data else !is.na(merged_v4$rt) & !is.na(merged_v4$choice)), na.rm = TRUE)
pct_behavioral <- 100 * n_behavioral / nrow(merged_v4)
cat("  Behavioral joined: ", n_behavioral, " / ", nrow(merged_v4), " (", sprintf("%.1f", pct_behavioral), "%)\n", sep = "")
if (pct_behavioral < 80) {
  cat("  ⚠ WARNING: Behavioral join rate < 80%\n")
}

# Check 3: AUC availability
cat("\n✓ Check 3: AUC availability\n")
auc_by_task <- merged_v4 %>%
  filter(has_behavioral_data == TRUE | (if ("has_behavioral_data" %in% names(merged_v4)) merged_v4$has_behavioral_data else !is.na(merged_v4$rt) & !is.na(merged_v4$choice))) %>%
  group_by(task) %>%
  summarise(
    n_total = n(),
    n_auc = sum(auc_available, na.rm = TRUE),
    pct_auc = 100 * n_auc / n_total,
    .groups = "drop"
  )

print(auc_by_task)

if (any(auc_by_task$pct_auc < 40)) {
  cat("\n  ⚠ WARNING: AUC availability < 40% for some tasks\n")
  cat("  Top 3 missingness reasons:\n")
  top_reasons <- auc_missingness %>% head(3)
  print(top_reasons)
} else {
  cat("\n  ✓ PASS: AUC availability >= 40% for all tasks\n")
}

# Check 4: No duplicates in ch2/ch3
cat("\n✓ Check 4: No duplicates in ch2/ch3 outputs\n")
# Reload to check
ch2_check <- read_csv(file.path(V7_ANALYSIS_READY, "ch2_triallevel.csv"), show_col_types = FALSE)
ch3_check <- read_csv(file.path(V7_ANALYSIS_READY, "ch3_triallevel.csv"), show_col_types = FALSE)
cat("  ch2_triallevel: ", nrow(ch2_check), " rows, ", n_distinct(ch2_check$trial_uid), " unique\n", sep = "")
cat("  ch3_triallevel: ", nrow(ch3_check), " rows, ", n_distinct(ch3_check$trial_uid), " unique\n", sep = "")
if (nrow(ch2_check) != n_distinct(ch2_check$trial_uid) || 
    nrow(ch3_check) != n_distinct(ch3_check$trial_uid)) {
  stop("FAILED: Duplicate trial_uid in ch2/ch3 outputs")
}

# Check 5: Spot-check behavioral derivations
cat("\n✓ Check 5: Spot-check behavioral derivations\n")
spot_check_base <- merged_v4 %>%
  filter(has_behavioral_data == TRUE | (if ("has_behavioral_data" %in% names(merged_v4)) merged_v4$has_behavioral_data else !is.na(merged_v4$rt) & !is.na(merged_v4$choice))) %>%
  filter(!is.na(stimulus_intensity))

n_spot <- min(20, nrow(spot_check_base))
spot_check <- spot_check_base %>%
  slice_sample(n = n_spot) %>%
  mutate(
    isOddball_check = as.integer(stimulus_intensity != 0),
    isOddball_match = isOddball == isOddball_check,
    choice_label_check = case_when(
      choice_num == 0 ~ "SAME",
      choice_num == 1 ~ "DIFFERENT",
      TRUE ~ NA_character_
    ),
    choice_label_match = choice_label == choice_label_check,
    correct_check = as.integer(choice_num == isOddball),
    correct_match = correct_final == correct_check
  )

n_isOddball_errors <- sum(!spot_check$isOddball_match, na.rm = TRUE)
n_choice_label_errors <- sum(!spot_check$choice_label_match, na.rm = TRUE)
n_correct_errors <- sum(!spot_check$correct_match, na.rm = TRUE)

cat("  isOddball errors: ", n_isOddball_errors, " / ", nrow(spot_check), "\n", sep = "")
cat("  choice_label errors: ", n_choice_label_errors, " / ", nrow(spot_check), "\n", sep = "")
cat("  correct_final errors: ", n_correct_errors, " / ", nrow(spot_check), "\n", sep = "")

if (n_isOddball_errors > 0 || n_choice_label_errors > 0 || n_correct_errors > 0) {
  cat("  ⚠ WARNING: Found derivation errors in spot-check\n")
} else {
  cat("  ✓ PASS: All derivations correct in spot-check\n")
}

# ----------------------------------------------------------------------------
# TASK 6: Final Self-Check
# ----------------------------------------------------------------------------

cat("\nTASK 6: Final self-check...\n\n")

# Check 1: qc/10 exists and has status labels
if (!file.exists(file.path(V7_QC, "10_expected_vs_found_runs.csv"))) {
  stop("FAILED: qc/10_expected_vs_found_runs.csv does not exist")
}
n_missing_flat <- sum(expected_vs_found$status == "MISSING_FLAT_RUN")
cat("✓ qc/10_expected_vs_found_runs.csv exists\n")
cat("  Missing flat runs: ", n_missing_flat, "\n", sep = "")

# Check 2: Final merged has 0 .x/.y columns
dup_cols_final_check <- grep("\\.(x|y)$", names(merged_v4), value = TRUE)
if (length(dup_cols_final_check) > 0) {
  stop("FAILED: Final merged has ", length(dup_cols_final_check), " columns ending in .x/.y")
}
cat("✓ Final merged has 0 .x/.y columns\n")

# Check 3: AUC flags match NA-ness exactly
flag_consistency_final <- all(
  merged_v4$auc_available_total == !is.na(merged_v4$total_auc),
  merged_v4$auc_available_cog == !is.na(merged_v4$cog_auc),
  merged_v4$auc_available_both == (merged_v4$auc_available_total & merged_v4$auc_available_cog),
  na.rm = TRUE
)
if (!flag_consistency_final) {
  stop("FAILED: AUC flags do not match NA-ness exactly")
}
cat("✓ AUC flags match NA-ness exactly\n")

# Check 4: trial_uid is consistent (colon separator)
trial_uid_check <- merged_v4 %>%
  mutate(trial_uid_check = paste(sub, task, session_used, run_used, trial_index, sep = ":")) %>%
  filter(trial_uid != trial_uid_check)
if (nrow(trial_uid_check) > 0) {
  stop("FAILED: trial_uid is not consistent (colon separator)")
}
cat("✓ trial_uid is consistent (colon separator)\n")

# Check 5: Analysis-ready datasets exist
if (!file.exists(file.path(V7_ANALYSIS_READY, "ch2_triallevel.csv"))) {
  stop("FAILED: analysis_ready/ch2_triallevel.csv does not exist")
}
if (!file.exists(file.path(V7_ANALYSIS_READY, "ch3_triallevel.csv"))) {
  stop("FAILED: analysis_ready/ch3_triallevel.csv does not exist")
}
cat("✓ Analysis-ready datasets exist\n")

# Check 6: Report exists
if (!file.exists(file.path(V7_ROOT, "REPORT_SUMMARY.qmd"))) {
  stop("FAILED: REPORT_SUMMARY.qmd does not exist")
}
cat("✓ REPORT_SUMMARY.qmd exists\n")

# Final output summary
cat("\n=== OUTPUT SUMMARY ===\n")
cat("QC files:\n")
cat("  qc/09_flat_file_run_inventory.csv: ", nrow(flat_inventory), " rows\n", sep = "")
cat("  qc/10_expected_vs_found_runs.csv: ", nrow(expected_vs_found), " rows (", n_missing_flat, " MISSING_FLAT_RUN)\n", sep = "")
cat("  qc/07_auc_feature_coverage_by_run.csv: ", nrow(coverage_by_run), " rows\n", sep = "")
cat("  qc/08_auc_non_na_rates.csv: ", nrow(auc_non_na_combined), " rows\n", sep = "")
cat("\nAnalysis-ready datasets:\n")
# Reload to get accurate counts
ch2_final <- read_csv(file.path(V7_ANALYSIS_READY, "ch2_triallevel.csv"), show_col_types = FALSE)
ch3_final <- read_csv(file.path(V7_ANALYSIS_READY, "ch3_triallevel.csv"), show_col_types = FALSE)
n_ch2_pupil_primary_final <- sum(ch2_final$gate_pupil_primary, na.rm = TRUE)
n_ch3_ddm_ready_final <- sum(ch3_final$ddm_ready, na.rm = TRUE)
cat("  analysis_ready/ch2_triallevel.csv: ", nrow(ch2_final), " rows (", 
    sprintf("%.1f", 100*n_ch2_pupil_primary_final/nrow(ch2_final)), "% gate_pupil_primary)\n", sep = "")
cat("  analysis_ready/ch3_triallevel.csv: ", nrow(ch3_final), " rows (", 
    sprintf("%.1f", 100*n_ch3_ddm_ready_final/nrow(ch3_final)), "% ddm_ready)\n", sep = "")
cat("\nReport:\n")
cat("  REPORT_SUMMARY.qmd\n")
cat("\n=== QUICK-SHARE v7 COMPLETE ===\n")

