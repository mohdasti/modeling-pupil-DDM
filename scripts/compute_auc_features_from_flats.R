#!/usr/bin/env Rscript
# ============================================================================
# Compute AUC Features from Sample-Level Flat Files
# ============================================================================
# Extracts trial-level pupil AUC features (Total AUC, Cognitive/TEPR AUC)
# from 250 Hz sample-level flat files and merges into trial-level dataset.
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(tidyr)
  library(yaml)
  library(here)
  library(data.table)  # For fast CSV reading
})

cat("=== COMPUTING AUC FEATURES FROM FLAT FILES ===\n\n")

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
V5_QC <- file.path(V5_ROOT, "qc")
V5_FIGURES <- file.path(V5_ROOT, "figures")
V4_MERGED <- file.path(REPO_ROOT, "quick_share_v4", "merged", "BAP_triallevel_merged_v2.csv")

dir.create(V5_ANALYSIS, recursive = TRUE, showWarnings = FALSE)
dir.create(V5_QC, recursive = TRUE, showWarnings = FALSE)
dir.create(V5_FIGURES, recursive = TRUE, showWarnings = FALSE)

cat("Repo root: ", REPO_ROOT, "\n", sep = "")
cat("Processed dir: ", PROCESSED_DIR, "\n", sep = "")
cat("Output dir: ", V5_ROOT, "\n\n", sep = "")

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------

FS_TARGET <- 250  # Target sampling rate (Hz)
WINDOW_START <- -3.0  # Window start time (seconds relative to trial onset)
MIN_BASELINE_SAMPLES <- 10L  # Minimum valid samples required in baseline
TRIAL_BASELINE_WIN <- c(-0.5, 0.0)  # Trial baseline window (B0)
TARGET_BASELINE_WIN <- c(-0.5, 0.0)  # Target baseline window (relative to target onset)
COG_WIN_POST_TARGET <- c(0.3, 1.3)  # Cognitive window after target onset (seconds)
TOTAL_AUC_END_REL <- 7.7  # End of total AUC window (relative to trial onset)
# Note: Actual end is trial-specific: 4.7s + RT, but we cap at 7.7s for safety

# ----------------------------------------------------------------------------
# Helper: Compute trapezoidal AUC
# ----------------------------------------------------------------------------

compute_auc <- function(time, value) {
  # Remove NA values
  valid <- !is.na(time) & !is.na(value)
  if (sum(valid) < 2) return(NA_real_)
  
  time_clean <- time[valid]
  value_clean <- value[valid]
  
  # Sort by time
  ord <- order(time_clean)
  time_clean <- time_clean[ord]
  value_clean <- value_clean[ord]
  
  # Trapezoidal integration
  n <- length(time_clean)
  if (n < 2) return(NA_real_)
  
  dt <- diff(time_clean)
  means <- (value_clean[-n] + value_clean[-1]) / 2
  sum(dt * means)
}

# ----------------------------------------------------------------------------
# Helper: Extract event timing from flat file metadata or compute from time
# ----------------------------------------------------------------------------

extract_event_timing <- function(df, sub, task, session_used, run_used) {
  # Event timing based on documented trial structure (AUC_CALCULATION_METHOD.md):
  # - Trial onset (squeeze/grip gauge): t=0
  # - Target onset: 4.35s (3.75s stimulus phase start + 0.1s Standard + 0.5s ISI)
  # - Response window start: 4.7s (Response_Different phase start)
  # - Response onset: 4.7s + RT (trial-specific, if RT available)
  
  target_onset_rel <- 4.35  # Target stimulus onset
  resp_start_rel <- 4.7     # Response window start (fixed)
  
  # If we have trial_start_time_ptb and target_onset columns, use them
  if ("trial_start_time_ptb" %in% names(df) && 
      "target_onset_time_ptb" %in% names(df)) {
    # Compute relative times
    trial_st <- first(df$trial_start_time_ptb[!is.na(df$trial_start_time_ptb)])
    target_st <- first(df$target_onset_time_ptb[!is.na(df$target_onset_time_ptb)])
    
    if (!is.na(trial_st) && !is.na(target_st)) {
      target_onset_rel <- target_st - trial_st
    }
  }
  
  # Check for Resp1ST or similar
  if ("resp1_start_time_ptb" %in% names(df)) {
    trial_st <- first(df$trial_start_time_ptb[!is.na(df$trial_start_time_ptb)])
    resp_st <- first(df$resp1_start_time_ptb[!is.na(df$resp1_start_time_ptb)])
    
    if (!is.na(trial_st) && !is.na(resp_st)) {
      resp_start_rel <- resp_st - trial_st
    }
  }
  
  list(
    t_trial_onset = 0.0,
    t_target_onset_rel = target_onset_rel,
    t_resp_start_rel = resp_start_rel
  )
}

# ----------------------------------------------------------------------------
# Helper: Process one flat file and compute AUC features
# ----------------------------------------------------------------------------

process_flat_file_auc <- function(flat_path) {
  fn <- basename(flat_path)
  cat("  Processing: ", fn, "\n", sep = "")
  
  # Read file efficiently
  df <- fread(flat_path, showProgress = FALSE, data.table = FALSE)
  
  # Standardize column names
  col_map <- list(
    sub = c("sub", "subject", "subject_id"),
    task = c("task", "task_name", "task_modality"),
    session_used = c("session_used", "ses", "session", "session_num"),
    run_used = c("run_used", "run", "run_num"),
    trial_index = c("trial_index", "trial_in_run_raw", "trial_in_run", "trial_num"),
    time = c("time", "time_ptb", "trial_pupilTime"),
    pupil = c("pupil", "pupilSize", "pupil_diameter")
  )
  
  # Map columns
  for (target in names(col_map)) {
    candidates <- col_map[[target]]
    found <- FALSE
    for (cand in candidates) {
      if (cand %in% names(df)) {
        df[[target]] <- df[[cand]]
        found <- TRUE
        break
      }
    }
    if (!found && target %in% c("sub", "task", "session_used", "run_used", "trial_index", "time", "pupil")) {
      stop("Required column not found in ", fn, ": ", target)
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
    # Convert NaN to NA
    mutate(pupil = if_else(is.nan(pupil), NA_real_, pupil)) %>%
    # Filter to sessions 2-3 only
    filter(session_used %in% c(2L, 3L)) %>%
    # Sort by trial and time
    arrange(trial_index, time)
  
  if (nrow(df) == 0) {
    cat("    ⚠ No data after filtering\n")
    return(tibble())
  }
  
  # Get unique subject/task/session/run (should be one per file)
  meta <- df %>%
    distinct(sub, task, session_used, run_used) %>%
    slice(1)
  
  if (nrow(meta) != 1) {
    cat("    ⚠ Multiple subject-task-session-run combos in file\n")
    return(tibble())
  }
  
  # Extract event timing
  events <- extract_event_timing(df, meta$sub, meta$task, meta$session_used, meta$run_used)
  
  # Process each trial
  trial_features <- df %>%
    group_by(trial_index) %>%
    group_map(~ {
      trial_num <- .y$trial_index
      
      # Reconstruct time_rel from sample index
      n_samples <- nrow(.x)
      if (n_samples < 2) {
        return(tibble(
          sub = meta$sub,
          task = meta$task,
          session_used = meta$session_used,
          run_used = meta$run_used,
          trial_index = trial_num,
          total_auc = NA_real_,
          cog_auc_fixed1s = NA_real_,
          cog_mean_fixed1s = NA_real_,
          n_valid_b0 = 0L,
          n_valid_target_base = 0L,
          n_valid_total_window = 0L,
          n_valid_cog_window = 0L,
          auc_missing_reason = "insufficient_samples"
        ))
      }
      
      # Estimate sampling rate from time differences
      time_diffs <- diff(sort(unique(.x$time)))
      dt_median <- median(time_diffs[time_diffs > 0], na.rm = TRUE)
      fs_est <- if_else(is.na(dt_median) || dt_median <= 0, FS_TARGET, 1.0 / dt_median)
      
      # Create time_rel: assume window starts at WINDOW_START
      # time_rel = WINDOW_START + (sample_i - 1) / fs
      sample_i <- seq_len(n_samples)
      time_rel <- WINDOW_START + (sample_i - 1) / fs_est
      
      # If we have a time column that looks like relative time, use it
      if (min(.x$time, na.rm = TRUE) >= WINDOW_START - 0.1 && 
          max(.x$time, na.rm = TRUE) <= WINDOW_START + 15) {
        time_rel <- .x$time
      }
      
      # Extract pupil values
      pupil_vals <- .x$pupil
      
      # Compute trial baseline B0: [-0.5, 0]
      b0_mask <- time_rel >= TRIAL_BASELINE_WIN[1] & time_rel <= TRIAL_BASELINE_WIN[2]
      b0_pupil <- pupil_vals[b0_mask]
      b0_time <- time_rel[b0_mask]
      n_valid_b0 <- sum(!is.na(b0_pupil) & is.finite(b0_pupil))
      
      if (n_valid_b0 < MIN_BASELINE_SAMPLES) {
        return(tibble(
          sub = meta$sub,
          task = meta$task,
          session_used = meta$session_used,
          run_used = meta$run_used,
          trial_index = trial_num,
          total_auc = NA_real_,
          cog_auc_fixed1s = NA_real_,
          cog_mean_fixed1s = NA_real_,
          n_valid_b0 = n_valid_b0,
          n_valid_target_base = 0L,
          n_valid_total_window = 0L,
          n_valid_cog_window = 0L,
          auc_missing_reason = "insufficient_b0_samples"
        ))
      }
      
      b0_mean <- mean(b0_pupil[!is.na(b0_pupil) & is.finite(b0_pupil)], na.rm = TRUE)
      
      # Compute target baseline: [target_onset - 0.5, target_onset]
      target_base_start <- events$t_target_onset_rel + TARGET_BASELINE_WIN[1]
      target_base_end <- events$t_target_onset_rel + TARGET_BASELINE_WIN[2]
      target_base_mask <- time_rel >= target_base_start & time_rel <= target_base_end
      target_base_pupil <- pupil_vals[target_base_mask]
      target_base_time <- time_rel[target_base_mask]
      n_valid_target_base <- sum(!is.na(target_base_pupil) & is.finite(target_base_pupil))
      
      if (n_valid_target_base < MIN_BASELINE_SAMPLES) {
        return(tibble(
          sub = meta$sub,
          task = meta$task,
          session_used = meta$session_used,
          run_used = meta$run_used,
          trial_index = trial_num,
          total_auc = NA_real_,
          cog_auc_fixed1s = NA_real_,
          cog_mean_fixed1s = NA_real_,
          n_valid_b0 = n_valid_b0,
          n_valid_target_base = n_valid_target_base,
          n_valid_total_window = 0L,
          n_valid_cog_window = 0L,
          auc_missing_reason = "insufficient_target_base_samples"
        ))
      }
      
      target_base_mean <- mean(target_base_pupil[!is.na(target_base_pupil) & is.finite(target_base_pupil)], na.rm = TRUE)
      
      # Total AUC: RAW pupil data from 0 to resp_start (NO baseline correction for Total AUC)
      # Per AUC_CALCULATION_METHOD.md: Total AUC uses raw pupil, not baseline-corrected
      total_win_end <- min(events$t_resp_start_rel, TOTAL_AUC_END_REL)
      total_mask <- time_rel >= 0 & time_rel <= total_win_end
      total_pupil <- pupil_vals[total_mask]
      total_time <- time_rel[total_mask]
      n_valid_total <- sum(!is.na(total_pupil) & is.finite(total_pupil))
      
      total_auc <- NA_real_
      if (n_valid_total >= 2) {
        # Total AUC uses RAW pupil (no baseline correction)
        total_auc <- compute_auc(total_time, total_pupil)
      }
      
      # Cognitive AUC (fixed 1s window): [target_onset + 0.3, target_onset + 1.3]
      # Per AUC_CALCULATION_METHOD.md: Cognitive window starts at 4.65s (4.35s + 0.3s)
      cog_win_start <- events$t_target_onset_rel + COG_WIN_POST_TARGET[1]  # 4.35 + 0.3 = 4.65
      cog_win_end <- min(events$t_target_onset_rel + COG_WIN_POST_TARGET[2], events$t_resp_start_rel)
      
      if (cog_win_end <= cog_win_start) {
        return(tibble(
          sub = meta$sub,
          task = meta$task,
          session_used = meta$session_used,
          run_used = meta$run_used,
          trial_index = trial_num,
          total_auc = total_auc,
          cog_auc_fixed1s = NA_real_,
          cog_mean_fixed1s = NA_real_,
          n_valid_b0 = n_valid_b0,
          n_valid_target_base = n_valid_target_base,
          n_valid_total_window = n_valid_total,
          n_valid_cog_window = 0L,
          auc_missing_reason = "cog_window_invalid"
        ))
      }
      
      cog_mask <- time_rel >= cog_win_start & time_rel <= cog_win_end
      cog_pupil <- pupil_vals[cog_mask]
      cog_time <- time_rel[cog_mask]
      n_valid_cog <- sum(!is.na(cog_pupil) & is.finite(cog_pupil))
      
      cog_auc_fixed1s <- NA_real_
      cog_mean_fixed1s <- NA_real_
      
      if (n_valid_cog >= 2) {
        cog_pupil_corrected <- cog_pupil - target_base_mean
        cog_auc_fixed1s <- compute_auc(cog_time, cog_pupil_corrected)
        cog_mean_fixed1s <- mean(cog_pupil_corrected[!is.na(cog_pupil_corrected) & is.finite(cog_pupil_corrected)], na.rm = TRUE)
      }
      
      # Determine missing reason if any
      auc_missing_reason <- "ok"
      if (is.na(total_auc)) auc_missing_reason <- "total_auc_failed"
      if (is.na(cog_auc_fixed1s)) auc_missing_reason <- "cog_auc_failed"
      
      tibble(
        sub = meta$sub,
        task = meta$task,
        session_used = meta$session_used,
        run_used = meta$run_used,
        trial_index = trial_num,
        total_auc = total_auc,
        cog_auc_fixed1s = cog_auc_fixed1s,
        cog_mean_fixed1s = cog_mean_fixed1s,
        n_valid_b0 = n_valid_b0,
        n_valid_target_base = n_valid_target_base,
        n_valid_total_window = n_valid_total,
        n_valid_cog_window = n_valid_cog,
        auc_missing_reason = auc_missing_reason,
        t_target_onset_rel = events$t_target_onset_rel,
        t_resp_start_rel = events$t_resp_start_rel
      )
    }, .keep = TRUE) %>%
    bind_rows()
  
  trial_features
}

# ----------------------------------------------------------------------------
# STEP 1: Find all flat files
# ----------------------------------------------------------------------------

cat("STEP 1: Finding flat files...\n")

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
# STEP 2: Process all flat files and compute AUC features
# ----------------------------------------------------------------------------

cat("STEP 2: Processing flat files and computing AUC features...\n")
cat("  (This may take several minutes)\n\n")

all_auc_features <- map_dfr(flat_files, process_flat_file_auc, .progress = "text")

cat("\n  ✓ Processed ", nrow(all_auc_features), " trials\n", sep = "")

# Save raw AUC features
write_csv(all_auc_features, file.path(V5_ANALYSIS, "pupil_auc_trial_level.csv"))
cat("  ✓ Saved: analysis/pupil_auc_trial_level.csv\n\n")

# ----------------------------------------------------------------------------
# STEP 3: Event timing QC
# ----------------------------------------------------------------------------

cat("STEP 3: Event timing QC...\n")

event_timing_qc <- all_auc_features %>%
  group_by(task) %>%
  summarise(
    n_trials = n(),
    t_target_onset_min = min(t_target_onset_rel, na.rm = TRUE),
    t_target_onset_median = median(t_target_onset_rel, na.rm = TRUE),
    t_target_onset_max = max(t_target_onset_rel, na.rm = TRUE),
    t_resp_start_min = min(t_resp_start_rel, na.rm = TRUE),
    t_resp_start_median = median(t_resp_start_rel, na.rm = TRUE),
    t_resp_start_max = max(t_resp_start_rel, na.rm = TRUE),
    resp_minus_target_min = min(t_resp_start_rel - t_target_onset_rel, na.rm = TRUE),
    resp_minus_target_median = median(t_resp_start_rel - t_target_onset_rel, na.rm = TRUE),
    resp_minus_target_max = max(t_resp_start_rel - t_target_onset_rel, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(event_timing_qc, file.path(V5_QC, "qc_event_time_ranges.csv"))
cat("  ✓ Saved: qc/qc_event_time_ranges.csv\n\n")

# ----------------------------------------------------------------------------
# STEP 4: AUC missingness QC
# ----------------------------------------------------------------------------

cat("STEP 4: AUC missingness QC...\n")

# Load merged v2 to get effort/intensity for missingness analysis
if (file.exists(V4_MERGED)) {
  merged_v2 <- read_csv(V4_MERGED, show_col_types = FALSE)
  
  # Join AUC features with merged data to get effort/intensity
  auc_with_meta <- all_auc_features %>%
    left_join(
      merged_v2 %>%
        select(sub, task, session_used, run_used, trial_index, 
               effort, stimulus_intensity) %>%
        mutate(
          effort_group = if_else(is.na(effort), "Unknown", as.character(effort)),
          intensity_bin = case_when(
            is.na(stimulus_intensity) ~ "NA",
            stimulus_intensity == 0 ~ "0",
            stimulus_intensity <= 2 ~ "1-2",
            stimulus_intensity <= 4 ~ "3-4",
            TRUE ~ ">4"
          )
        ),
      by = c("sub", "task", "session_used", "run_used", "trial_index")
    )
  
  auc_missingness <- auc_with_meta %>%
    group_by(task, effort_group, intensity_bin) %>%
    summarise(
      n_trials = n(),
      n_missing_total_auc = sum(is.na(total_auc)),
      n_missing_cog_auc = sum(is.na(cog_auc_fixed1s)),
      pct_missing_total = 100 * n_missing_total_auc / n_trials,
      pct_missing_cog = 100 * n_missing_cog_auc / n_trials,
      .groups = "drop"
    ) %>%
    arrange(task, effort_group, intensity_bin)
  
  # Top missingness reasons
  missing_reasons <- auc_with_meta %>%
    filter(is.na(total_auc) | is.na(cog_auc_fixed1s)) %>%
    count(task, auc_missing_reason, sort = TRUE)
  
  write_csv(auc_missingness, file.path(V5_QC, "qc_auc_missingness_by_condition.csv"))
  write_csv(missing_reasons, file.path(V5_QC, "qc_auc_missingness_reasons.csv"))
  cat("  ✓ Saved: qc/qc_auc_missingness_by_condition.csv\n")
  cat("  ✓ Saved: qc/qc_auc_missingness_reasons.csv\n\n")
} else {
  cat("  ⚠ Merged v2 file not found; skipping missingness by condition\n\n")
}

# ----------------------------------------------------------------------------
# STEP 5: Merge AUC features into trial-level merged dataset
# ----------------------------------------------------------------------------

cat("STEP 5: Merging AUC features into trial-level dataset...\n")

if (!file.exists(V4_MERGED)) {
  stop("Merged v2 file not found: ", V4_MERGED,
       "\nPlease run scripts/make_merged_quickshare_v4.R first.")
}

merged_v2 <- read_csv(V4_MERGED, show_col_types = FALSE)
cat("  ✓ Loaded merged v2: ", nrow(merged_v2), " trials\n", sep = "")

# Create trial_uid for joining
all_auc_features <- all_auc_features %>%
  mutate(trial_uid = paste(sub, task, session_used, run_used, trial_index, sep = ":"))

merged_v2 <- merged_v2 %>%
  mutate(trial_uid = paste(sub, task, session_used, run_used, trial_index, sep = ":"))

# Left join AUC features
merged_v3 <- merged_v2 %>%
  left_join(
    all_auc_features %>%
      select(trial_uid, total_auc, cog_auc_fixed1s, cog_mean_fixed1s,
             n_valid_b0, n_valid_target_base, n_valid_total_window, n_valid_cog_window,
             auc_missing_reason, t_target_onset_rel, t_resp_start_rel),
    by = "trial_uid"
  )

# Save merged v3
write_csv(merged_v3, file.path(V5_ROOT, "merged", "BAP_triallevel_merged_v3.csv"))
cat("  ✓ Saved: merged/BAP_triallevel_merged_v3.csv\n")

# Coverage report
n_with_auc <- sum(!is.na(merged_v3$total_auc))
pct_auc <- 100 * n_with_auc / nrow(merged_v3)
cat("  Coverage: ", n_with_auc, " / ", nrow(merged_v3), 
    " trials (", sprintf("%.1f", pct_auc), "%)\n\n", sep = "")

cat("=== AUC FEATURE EXTRACTION COMPLETE ===\n")

