#!/usr/bin/env Rscript
# ============================================================================
# Make Quick-Share v6: Complete Pipeline
# ============================================================================
# Reproducible pipeline for AUC features + waveforms + QC reports
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

cat("=== MAKING QUICK-SHARE v6: COMPLETE PIPELINE ===\n\n")

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
V6_MERGED <- file.path(V6_ROOT, "merged")
V6_ANALYSIS <- file.path(V6_ROOT, "analysis")
V6_WAVEFORMS <- file.path(V6_ROOT, "waveforms")
V6_QC <- file.path(V6_ROOT, "qc")
V6_FIGS <- file.path(V6_ROOT, "figs")

# Input files
V5_CH2 <- file.path(V5_ROOT, "analysis", "ch2_analysis_ready.csv")
V5_CH3 <- file.path(V5_ROOT, "analysis", "ch3_ddm_ready.csv")
V4_MERGED <- file.path(V4_ROOT, "merged", "BAP_triallevel_merged_v2.csv")

dir.create(V6_ROOT, recursive = TRUE, showWarnings = FALSE)
dir.create(V6_MERGED, recursive = TRUE, showWarnings = FALSE)
dir.create(V6_ANALYSIS, recursive = TRUE, showWarnings = FALSE)
dir.create(V6_WAVEFORMS, recursive = TRUE, showWarnings = FALSE)
dir.create(V6_QC, recursive = TRUE, showWarnings = FALSE)
dir.create(V6_FIGS, recursive = TRUE, showWarnings = FALSE)

cat("Repo root: ", REPO_ROOT, "\n", sep = "")
cat("Processed dir: ", PROCESSED_DIR, "\n", sep = "")
cat("Output dir: ", V6_ROOT, "\n\n", sep = "")

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------

FS_TARGET <- 250
FS_CH2_WAVEFORM <- 50
FS_CH3_WAVEFORM <- 250  # Keep 250Hz for Ch3
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
# Helper: Get first existing column from candidates (case-insensitive)
# ----------------------------------------------------------------------------

get_first_existing_col <- function(df, candidates) {
  col_names <- names(df)
  for (cand in candidates) {
    # Case-insensitive match
    matches <- col_names[tolower(col_names) == tolower(cand)]
    if (length(matches) > 0) {
      return(matches[1])
    }
  }
  return(NULL)
}

# ----------------------------------------------------------------------------
# Helper: Extract event timing (PTB if available, else labels, else defaults)
# ----------------------------------------------------------------------------

extract_event_timing <- function(df, sub, task, session_used, run_used) {
  target_onset_rel <- TARGET_ONSET_DEFAULT
  resp_start_rel <- RESP_START_DEFAULT
  timing_source <- "default"
  
  # Try PTB columns (robust column name matching)
  trial_start_col <- get_first_existing_col(df, c(
    "trial_start_time_ptb", "trialStartPTB", "trial_start_ptb", 
    "trial_start_time", "trialStartTime"
  ))
  
  target_onset_col <- get_first_existing_col(df, c(
    "target_onset_time_ptb", "targetOnsetPTB", "target_onset_ptb",
    "probe_onset_time_ptb", "stim_onset_time_ptb", "target_onset",
    "A/V_ST", "AV_ST", "sound_start_time_ptb"
  ))
  
  resp_start_col <- get_first_existing_col(df, c(
    "resp1_start_time_ptb", "resp1ST", "resp_start_time_ptb",
    "response_onset_time_ptb", "resp_onset_ptb", "resp_start",
    "Resp1StartTimeP", "resp1_start"
  ))
  
  # Try PTB extraction
  if (!is.null(trial_start_col) && !is.null(target_onset_col)) {
    trial_st <- first(df[[trial_start_col]][!is.na(df[[trial_start_col]])])
    target_st <- first(df[[target_onset_col]][!is.na(df[[target_onset_col]])])
    
    if (!is.na(trial_st) && !is.na(target_st) && is.finite(trial_st) && is.finite(target_st)) {
      target_onset_rel <- target_st - trial_st
      timing_source <- "ptb"
    }
  }
  
  if (!is.null(trial_start_col) && !is.null(resp_start_col)) {
    trial_st <- first(df[[trial_start_col]][!is.na(df[[trial_start_col]])])
    resp_st <- first(df[[resp_start_col]][!is.na(df[[resp_start_col]])])
    
    if (!is.na(trial_st) && !is.na(resp_st) && is.finite(trial_st) && is.finite(resp_st)) {
      resp_start_rel <- resp_st - trial_st
      if (timing_source == "default") timing_source <- "ptb"
    }
  }
  
  # If PTB failed, try label-based extraction
  if (timing_source == "default" && "trial_label" %in% names(df)) {
    # Get unique labels to understand structure
    unique_labels <- unique(df$trial_label[!is.na(df$trial_label)])
    
    # Try to find target/probe onset from label transitions
    # Common label patterns: "Stimulus", "Target", "Probe", "Post_Stimulus_Fixation"
    target_labels <- c("Stimulus", "Target", "Probe", "Post_Stimulus_Fixation", 
                       "Pre_Stimulus_Fixation", "Stimulus_Presentation")
    
    # Find first occurrence of target-related label
    target_label_found <- FALSE
    for (tlab in target_labels) {
      if (any(grepl(tlab, unique_labels, ignore.case = TRUE))) {
        # Find first time where this label appears
        target_mask <- grepl(tlab, df$trial_label, ignore.case = TRUE)
        if (sum(target_mask) > 0) {
          target_time <- min(df$time[target_mask], na.rm = TRUE)
          if (is.finite(target_time)) {
            # Assume trial starts at time = 0 or min(time)
            trial_start_time <- min(df$time, na.rm = TRUE)
            target_onset_rel <- target_time - trial_start_time
            target_label_found <- TRUE
            timing_source <- "labels"
            break
          }
        }
      }
    }
    
    # Try to find response window start
    resp_labels <- c("Response", "Response_Window", "Resp1", "Response_1")
    for (rlab in resp_labels) {
      if (any(grepl(rlab, unique_labels, ignore.case = TRUE))) {
        resp_mask <- grepl(rlab, df$trial_label, ignore.case = TRUE)
        if (sum(resp_mask) > 0) {
          resp_time <- min(df$time[resp_mask], na.rm = TRUE)
          if (is.finite(resp_time)) {
            trial_start_time <- min(df$time, na.rm = TRUE)
            resp_start_rel <- resp_time - trial_start_time
            if (timing_source == "default") timing_source <- "labels"
            break
          }
        }
      }
    }
  }
  
  # Sanity check: if extracted values are unreasonable, fall back to defaults
  if (target_onset_rel < 0 || target_onset_rel > 10 || 
      resp_start_rel < 0 || resp_start_rel > 15 ||
      resp_start_rel <= target_onset_rel) {
    target_onset_rel <- TARGET_ONSET_DEFAULT
    resp_start_rel <- RESP_START_DEFAULT
    timing_source <- "default"
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
          total_auc = NA_real_, cog_auc_fixed1s = NA_real_, cog_auc_respwin = NA_real_,
          cog_mean_fixed1s = NA_real_,
          b0_n_valid = 0L, b1_n_valid = 0L, posttarget_n_valid = 0L,
          auc_missing_reason = "insufficient_samples", timing_source = events$timing_source,
          t_target_onset_rel = events$t_target_onset_rel, t_resp_start_rel = events$t_resp_start_rel
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
      b0_n_valid <- sum(!is.na(b0_pupil) & is.finite(b0_pupil))
      
      if (b0_n_valid < MIN_BASELINE_SAMPLES) {
        return(tibble(
          sub = meta$sub, task = meta$task, session_used = meta$session_used,
          run_used = meta$run_used, trial_index = trial_num,
          total_auc = NA_real_, cog_auc_fixed1s = NA_real_, cog_auc_respwin = NA_real_,
          cog_mean_fixed1s = NA_real_,
          b0_n_valid = b0_n_valid, b1_n_valid = 0L, posttarget_n_valid = 0L,
          auc_missing_reason = "B0_insufficient_samples", timing_source = events$timing_source,
          t_target_onset_rel = events$t_target_onset_rel, t_resp_start_rel = events$t_resp_start_rel
        ))
      }
      
      b0_mean <- mean(b0_pupil[!is.na(b0_pupil) & is.finite(b0_pupil)], na.rm = TRUE)
      
      # Baseline B1: [target_onset - 0.5, target_onset]
      b1_start <- events$t_target_onset_rel + B1_WIN[1]
      b1_end <- events$t_target_onset_rel + B1_WIN[2]
      b1_mask <- time_rel >= b1_start & time_rel <= b1_end
      b1_pupil <- pupil_vals[b1_mask]
      b1_n_valid <- sum(!is.na(b1_pupil) & is.finite(b1_pupil))
      
      if (b1_n_valid < MIN_BASELINE_SAMPLES) {
        return(tibble(
          sub = meta$sub, task = meta$task, session_used = meta$session_used,
          run_used = meta$run_used, trial_index = trial_num,
          total_auc = NA_real_, cog_auc_fixed1s = NA_real_, cog_auc_respwin = NA_real_,
          cog_mean_fixed1s = NA_real_,
          b0_n_valid = b0_n_valid, b1_n_valid = b1_n_valid, posttarget_n_valid = 0L,
          auc_missing_reason = "B1_insufficient_samples", timing_source = events$timing_source,
          t_target_onset_rel = events$t_target_onset_rel, t_resp_start_rel = events$t_resp_start_rel
        ))
      }
      
      b1_mean <- mean(b1_pupil[!is.na(b1_pupil) & is.finite(b1_pupil)], na.rm = TRUE)
      
      # Total AUC: baseline-corrected (B0) from 0 to resp_start
      total_mask <- time_rel >= 0 & time_rel <= events$t_resp_start_rel
      total_pupil <- pupil_vals[total_mask]
      total_time <- time_rel[total_mask]
      
      total_auc <- NA_real_
      if (sum(!is.na(total_pupil) & is.finite(total_pupil)) >= 2) {
        total_pupil_corrected <- total_pupil - b0_mean
        total_auc <- compute_auc(total_time, total_pupil_corrected)
      }
      
      # Cognitive AUC: target-locked baseline-corrected from (target_onset + 0.3) to resp_start
      cog_win_start <- events$t_target_onset_rel + COG_WIN_POST_TARGET[1]
      cog_win_end <- min(events$t_target_onset_rel + COG_WIN_POST_TARGET[2], events$t_resp_start_rel)
      
      cog_auc_fixed1s <- NA_real_
      cog_auc_respwin <- NA_real_
      cog_mean_fixed1s <- NA_real_
      posttarget_n_valid <- 0L
      
      if (cog_win_end > cog_win_start) {
        cog_mask <- time_rel >= cog_win_start & time_rel <= cog_win_end
        cog_pupil <- pupil_vals[cog_mask]
        cog_time <- time_rel[cog_mask]
        posttarget_n_valid <- sum(!is.na(cog_pupil) & is.finite(cog_pupil))
        
        if (posttarget_n_valid >= 2) {
          cog_pupil_corrected <- cog_pupil - b1_mean
          cog_auc_fixed1s <- compute_auc(cog_time, cog_pupil_corrected)
          cog_mean_fixed1s <- mean(cog_pupil_corrected[!is.na(cog_pupil_corrected) & is.finite(cog_pupil_corrected)], na.rm = TRUE)
        }
        
        # Also compute cognitive AUC to response window start (if different from fixed1s)
        if (events$t_resp_start_rel > cog_win_end) {
          cog_mask_respwin <- time_rel >= cog_win_start & time_rel <= events$t_resp_start_rel
          cog_pupil_respwin <- pupil_vals[cog_mask_respwin]
          cog_time_respwin <- time_rel[cog_mask_respwin]
          
          if (sum(!is.na(cog_pupil_respwin) & is.finite(cog_pupil_respwin)) >= 2) {
            cog_pupil_respwin_corrected <- cog_pupil_respwin - b1_mean
            cog_auc_respwin <- compute_auc(cog_time_respwin, cog_pupil_respwin_corrected)
          }
        } else {
          cog_auc_respwin <- cog_auc_fixed1s
        }
      }
      
      auc_missing_reason <- "ok"
      if (is.na(total_auc)) auc_missing_reason <- "total_auc_failed"
      if (is.na(cog_auc_fixed1s)) auc_missing_reason <- "cog_auc_failed"
      if (cog_win_end <= cog_win_start) auc_missing_reason <- "cog_window_invalid"
      
      tibble(
        sub = meta$sub, task = meta$task, session_used = meta$session_used,
        run_used = meta$run_used, trial_index = trial_num,
        total_auc = total_auc, cog_auc_fixed1s = cog_auc_fixed1s, cog_auc_respwin = cog_auc_respwin,
        cog_mean_fixed1s = cog_mean_fixed1s,
        b0_n_valid = b0_n_valid, b1_n_valid = b1_n_valid, posttarget_n_valid = posttarget_n_valid,
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

# Deduplicate by trial_uid
all_auc_features <- all_auc_features %>%
  mutate(trial_uid = paste(sub, task, session_used, run_used, trial_index, sep = ":")) %>%
  group_by(trial_uid) %>%
  slice(1) %>%
  ungroup()

cat("  ✓ Deduplicated to ", nrow(all_auc_features), " unique trials\n\n", sep = "")

# Save intermediate
write_csv(all_auc_features, file.path(V6_ANALYSIS, "pupil_auc_trial_level.csv"))
cat("  ✓ Saved: analysis/pupil_auc_trial_level.csv\n\n")

# ----------------------------------------------------------------------------
# STEP 3: Merge AUC into trial-level merged dataset
# ----------------------------------------------------------------------------

cat("STEP 3: Merging AUC into trial-level dataset...\n")

merged_base <- merged_base %>%
  mutate(trial_uid = if ("trial_uid" %in% names(.)) trial_uid else paste(sub, task, session_used, run_used, trial_index, sep = ":"))

# Ensure all_auc_features has trial_uid
if (nrow(all_auc_features) > 0 && !"trial_uid" %in% names(all_auc_features)) {
  all_auc_features <- all_auc_features %>%
    mutate(trial_uid = paste(sub, task, session_used, run_used, trial_index, sep = ":"))
}

# Ensure one row per trial (deduplicate by trial_uid)
# Priority: ptb > labels > default for timing_source
auc_features_unique <- all_auc_features %>%
  mutate(
    timing_priority = case_when(
      timing_source == "ptb" ~ 1L,
      timing_source == "labels" ~ 2L,
      TRUE ~ 3L
    )
  ) %>%
  arrange(trial_uid, timing_priority, desc(b0_n_valid), desc(b1_n_valid)) %>%
  group_by(trial_uid) %>%
  slice(1) %>%
  ungroup() %>%
  select(-timing_priority) %>%
  select(any_of(c("trial_uid", "total_auc", "cog_auc_fixed1s", "cog_auc_respwin", "cog_mean_fixed1s",
                  "b0_n_valid", "b1_n_valid", "posttarget_n_valid",
                  "auc_missing_reason", "timing_source", "t_target_onset_rel", "t_resp_start_rel")))

merged_v3 <- merged_base %>%
  left_join(auc_features_unique, by = "trial_uid", relationship = "many-to-one")

# Ensure AUC and timing columns exist (in case join didn't add them)
if (!"total_auc" %in% names(merged_v3)) {
  merged_v3$total_auc <- NA_real_
}
if (!"cog_auc_fixed1s" %in% names(merged_v3)) {
  merged_v3$cog_auc_fixed1s <- NA_real_
}
if (!"t_target_onset_rel" %in% names(merged_v3)) {
  merged_v3$t_target_onset_rel <- NA_real_
}
if (!"t_resp_start_rel" %in% names(merged_v3)) {
  merged_v3$t_resp_start_rel <- NA_real_
}
if (!"timing_source" %in% names(merged_v3)) {
  merged_v3$timing_source <- NA_character_
}

# Fill in defaults for missing timing
merged_v3 <- merged_v3 %>%
  mutate(
    t_target_onset_rel = if_else(is.na(t_target_onset_rel), TARGET_ONSET_DEFAULT, t_target_onset_rel),
    t_resp_start_rel = if_else(is.na(t_resp_start_rel), RESP_START_DEFAULT, t_resp_start_rel),
    timing_source = if_else(is.na(timing_source), "default", timing_source),
    auc_available = !is.na(total_auc) & !is.na(cog_auc_fixed1s)
  )

write_csv(merged_v3, file.path(V6_MERGED, "BAP_triallevel_merged_v3.csv"))
cat("  ✓ Saved: merged/BAP_triallevel_merged_v3.csv\n\n")

# ----------------------------------------------------------------------------
# STEP 4: Join AUC to Ch2/Ch3 datasets
# ----------------------------------------------------------------------------

cat("STEP 4: Joining AUC features to Ch2/Ch3 datasets...\n")

ch2_base <- ch2_base %>%
  mutate(trial_uid = if ("trial_uid" %in% names(.)) trial_uid else paste(sub, task, session_used, run_used, trial_index, sep = ":"))

ch3_base <- ch3_base %>%
  mutate(trial_uid = if ("trial_uid" %in% names(.)) trial_uid else paste(sub, task, session_used, run_used, trial_index, sep = ":"))

ch2_with_auc <- ch2_base %>%
  left_join(auc_features_unique, by = "trial_uid", relationship = "many-to-one")

# Ensure AUC columns exist (in case join didn't add them)
if (!"total_auc" %in% names(ch2_with_auc)) {
  ch2_with_auc$total_auc <- NA_real_
}
if (!"cog_auc_fixed1s" %in% names(ch2_with_auc)) {
  ch2_with_auc$cog_auc_fixed1s <- NA_real_
}

ch2_with_auc <- ch2_with_auc %>%
  mutate(auc_available = !is.na(total_auc) & !is.na(cog_auc_fixed1s))

ch3_with_auc <- ch3_base %>%
  left_join(auc_features_unique, by = "trial_uid", relationship = "many-to-one")

# Ensure AUC columns exist (in case join didn't add them)
if (!"total_auc" %in% names(ch3_with_auc)) {
  ch3_with_auc$total_auc <- NA_real_
}
if (!"cog_auc_fixed1s" %in% names(ch3_with_auc)) {
  ch3_with_auc$cog_auc_fixed1s <- NA_real_
}

ch3_with_auc <- ch3_with_auc %>%
  mutate(auc_available = !is.na(total_auc) & !is.na(cog_auc_fixed1s))

write_csv(ch2_with_auc, file.path(V6_ANALYSIS, "ch2_analysis_ready_with_auc.csv"))
write_csv(ch3_with_auc, file.path(V6_ANALYSIS, "ch3_ddm_ready_with_auc.csv"))

cat("  ✓ Saved: analysis/ch2_analysis_ready_with_auc.csv\n")
cat("  ✓ Saved: analysis/ch3_ddm_ready_with_auc.csv\n\n")

# ----------------------------------------------------------------------------
# STEP 5: Generate waveform summaries
# ----------------------------------------------------------------------------

cat("STEP 5: Generating waveform summaries...\n")
cat("  (Processing flat files for waveforms; may take time)\n\n")

# Helper: Process one flat file for waveforms
process_flat_file_waveforms <- function(flat_path, merged_with_auc) {
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
    select(trial_index, effort, isOddball, auc_available, b0_n_valid) %>%
    # Filter out trials with missing effort (required for condition grouping)
    filter(!is.na(effort)) %>%
    mutate(
      effort = as.character(effort),
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
      auc_avail <- if ("auc_available" %in% names(trial_info)) trial_info$auc_available[1] else FALSE
      b0_valid <- if ("b0_n_valid" %in% names(trial_info)) trial_info$b0_n_valid[1] else 0L
      
      if (!auc_avail || b0_valid < MIN_BASELINE_SAMPLES) {
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
      
      # Skip if effort is missing (required for condition grouping)
      if (nrow(trial_info) == 0 || is.na(trial_info$effort[1])) {
        return(tibble())
      }
      
      tibble(
        sub = meta$sub,
        task = meta$task,
        effort = as.character(trial_info$effort[1]),
        isOddball = if ("isOddball" %in% names(trial_info)) trial_info$isOddball[1] else 0L,
        trial_index = trial_num,
        t = time_rel[wave_mask],
        pupil_corrected = pupil_corrected[wave_mask]
      )
    }, .keep = TRUE) %>%
    bind_rows()
  
  waveforms
}

# Process all flat files for waveforms
cat("  Processing ", length(flat_files), " flat files for waveforms...\n", sep = "")

# Join merged data with AUC to get waveform gate info
merged_with_auc_for_waveforms <- merged_v3 %>%
  select(sub, task, session_used, run_used, trial_index, effort, isOddball, auc_available, b0_n_valid) %>%
  mutate(
    auc_available = if_else(is.na(auc_available), FALSE, auc_available),
    b0_n_valid = if_else(is.na(b0_n_valid), 0L, b0_n_valid)
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
    filter(!is.na(pupil_corrected), !is.na(effort), effort != "Unknown") %>%
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
    filter(!is.na(pupil_corrected), !is.na(effort), effort != "Unknown") %>%
    group_by(task, effort, isOddball, trial_index) %>%
    group_map(~ {
      if (nrow(.x) < 2) return(tibble())
      
      # Interpolate to 250Hz grid
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

write_csv(waveform_ch2, file.path(V6_WAVEFORMS, "pupil_waveforms_condition_mean_ch2_50hz.csv"))
write_csv(waveform_ch3, file.path(V6_WAVEFORMS, "pupil_waveforms_condition_mean_ch3_250hz.csv"))

cat("  ✓ Saved: waveforms/pupil_waveforms_condition_mean_ch2_50hz.csv\n")
cat("  ✓ Saved: waveforms/pupil_waveforms_condition_mean_ch3_250hz.csv\n")
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
# STEP 6: Generate QC outputs
# ----------------------------------------------------------------------------

cat("STEP 6: Generating QC outputs...\n")

# A) AUC missingness reasons
auc_missingness_reasons <- all_auc_features %>%
  filter(is.na(total_auc) | is.na(cog_auc_fixed1s)) %>%
  count(task, auc_missing_reason, sort = TRUE) %>%
  rename(n_trials = n)

write_csv(auc_missingness_reasons, file.path(V6_QC, "auc_missingness_reasons.csv"))
cat("  ✓ Saved: qc/auc_missingness_reasons.csv\n")

# B) AUC missingness by condition
if (file.exists(V4_MERGED)) {
  merged_for_missingness <- merged_base %>%
    select(sub, task, session_used, run_used, trial_index, effort, stimulus_intensity, isOddball) %>%
    mutate(
      effort_group = if_else(is.na(effort), "Unknown", as.character(effort)),
      intensity_bin = case_when(
        is.na(stimulus_intensity) ~ "NA",
        stimulus_intensity == 0 ~ "0",
        stimulus_intensity <= 2 ~ "1-2",
        stimulus_intensity <= 4 ~ "3-4",
        TRUE ~ ">4"
      )
    )
  
  auc_missingness_by_condition <- all_auc_features %>%
    left_join(
      merged_for_missingness,
      by = c("sub", "task", "session_used", "run_used", "trial_index")
    ) %>%
    mutate(
      missing_total = is.na(total_auc),
      missing_cog = is.na(cog_auc_fixed1s)
    ) %>%
    group_by(task, effort_group, isOddball) %>%
    summarise(
      n_trials = n(),
      n_missing_total = sum(missing_total),
      n_missing_cog = sum(missing_cog),
      pct_missing_total = 100 * n_missing_total / n_trials,
      pct_missing_cog = 100 * n_missing_cog / n_trials,
      .groups = "drop"
    ) %>%
    arrange(task, effort_group, isOddball)
  
  write_csv(auc_missingness_by_condition, file.path(V6_QC, "auc_missingness_by_condition.csv"))
  cat("  ✓ Saved: qc/auc_missingness_by_condition.csv\n")
} else {
  cat("  ⚠ Skipped auc_missingness_by_condition.csv (merged file not found)\n")
}

# C) Timing coverage
timing_coverage <- all_auc_features %>%
  group_by(task, session_used, run_used) %>%
  summarise(
    n_trials = n(),
    n_ptb = sum(timing_source == "ptb", na.rm = TRUE),
    n_labels = sum(timing_source == "labels", na.rm = TRUE),
    n_default = sum(timing_source == "default", na.rm = TRUE),
    pct_ptb = 100 * n_ptb / n_trials,
    pct_labels = 100 * n_labels / n_trials,
    pct_default = 100 * n_default / n_trials,
    t_target_onset_min = min(t_target_onset_rel, na.rm = TRUE),
    t_target_onset_median = median(t_target_onset_rel, na.rm = TRUE),
    t_target_onset_max = max(t_target_onset_rel, na.rm = TRUE),
    t_resp_start_min = min(t_resp_start_rel, na.rm = TRUE),
    t_resp_start_median = median(t_resp_start_rel, na.rm = TRUE),
    t_resp_start_max = max(t_resp_start_rel, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(timing_coverage, file.path(V6_QC, "timing_event_time_coverage.csv"))
cat("  ✓ Saved: qc/timing_event_time_coverage.csv\n")

# D) Gate pass rates
gate_rates <- merged_v3 %>%
  filter(has_behavioral_data) %>%
  mutate(
    pass_primary_050 = if ("pass_primary_050" %in% names(.)) pass_primary_050 else NA,
    pass_primary_060 = if ("pass_primary_060" %in% names(.)) pass_primary_060 else NA,
    pass_primary_070 = if ("pass_primary_070" %in% names(.)) pass_primary_070 else NA
  ) %>%
  group_by(task) %>%
  summarise(
    n_total = n(),
    pass_050 = sum(pass_primary_050, na.rm = TRUE),
    pass_060 = sum(pass_primary_060, na.rm = TRUE),
    pass_070 = sum(pass_primary_070, na.rm = TRUE),
    auc_ready = sum(auc_available, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    pct_pass_050 = 100 * pass_050 / n_total,
    pct_pass_060 = 100 * pass_060 / n_total,
    pct_pass_070 = 100 * pass_070 / n_total,
    pct_auc_ready = 100 * auc_ready / n_total
  )

write_csv(gate_rates, file.path(V6_QC, "gate_pass_rates_overview.csv"))
cat("  ✓ Saved: qc/gate_pass_rates_overview.csv\n\n")

# ----------------------------------------------------------------------------
# STEP 7: Generate plots
# ----------------------------------------------------------------------------

cat("STEP 7: Generating plots...\n")

# Plot 1: Gate pass rates
if (nrow(gate_rates) > 0) {
  p_gates <- gate_rates %>%
    select(task, pct_pass_050, pct_pass_060, pct_pass_070, pct_auc_ready) %>%
    pivot_longer(cols = starts_with("pct_"), names_to = "gate", values_to = "pct") %>%
    mutate(gate = str_remove(gate, "pct_")) %>%
    ggplot(aes(x = gate, y = pct, fill = task)) +
    geom_col(position = "dodge") +
    labs(x = "Gate/Threshold", y = "Pass Rate (%)", fill = "Task") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  ggsave(file.path(V6_FIGS, "gate_pass_rates_overview.png"), 
         p_gates, width = 8, height = 5, dpi = 100)
  cat("  ✓ Saved: figs/gate_pass_rates_overview.png\n")
}

# Plot 2: AUC distributions
if (nrow(ch2_with_auc) > 0 && sum(!is.na(ch2_with_auc$total_auc)) > 0) {
  p_auc_dist <- ch2_with_auc %>%
    filter(!is.na(total_auc), !is.na(effort)) %>%
    ggplot(aes(x = total_auc, fill = task)) +
    geom_histogram(alpha = 0.7, bins = 50) +
    facet_wrap(~ effort, scales = "free_y") +
    labs(x = "Total AUC (baseline-corrected)", y = "Count", fill = "Task") +
    theme_minimal()
  
  ggsave(file.path(V6_FIGS, "auc_distributions.png"), 
         p_auc_dist, width = 10, height = 6, dpi = 100)
  cat("  ✓ Saved: figs/auc_distributions.png\n")
}

# Plot 3: Waveform panels (Ch2)
if (nrow(waveform_ch2) > 0) {
  p_waveform_ch2 <- waveform_ch2 %>%
    # Filter out any "Unknown" effort (shouldn't exist, but safety check)
    filter(effort != "Unknown", !is.na(effort)) %>%
    mutate(
      condition = paste0(if_else(isOddball == 1, "Easy", "Standard"), " / ", effort)
    ) %>%
    ggplot(aes(x = t, y = mean_pupil, color = condition, fill = condition)) +
    geom_ribbon(aes(ymin = mean_pupil - sem_pupil, ymax = mean_pupil + sem_pupil), 
                alpha = 0.2, color = NA) +
    geom_line(linewidth = 1) +
    facet_wrap(~ task, scales = "free") +
    labs(x = "Time Relative to Squeeze Onset (s)", 
         y = "Baseline-Corrected Pupil", 
         color = "Condition", fill = "Condition") +
    theme_minimal() +
    geom_vline(xintercept = 0, linetype = "dashed", color = "grey40") +
    geom_vline(xintercept = 4.35, linetype = "dashed", color = "grey40") +
    geom_vline(xintercept = 4.7, linetype = "dashed", color = "grey40")
  
  ggsave(file.path(V6_FIGS, "waveform_panels_ch2.png"), 
         p_waveform_ch2, width = 12, height = 6, dpi = 100)
  cat("  ✓ Saved: figs/waveform_panels_ch2.png\n")
}

# Plot 4: Waveform panels (Ch3)
if (nrow(waveform_ch3) > 0) {
  p_waveform_ch3 <- waveform_ch3 %>%
    # Filter out any "Unknown" effort (shouldn't exist, but safety check)
    filter(effort != "Unknown", !is.na(effort)) %>%
    mutate(
      condition = paste0(if_else(isOddball == 1, "Easy", "Standard"), " / ", effort)
    ) %>%
    ggplot(aes(x = t, y = mean_pupil, color = condition, fill = condition)) +
    geom_ribbon(aes(ymin = mean_pupil - sem_pupil, ymax = mean_pupil + sem_pupil), 
                alpha = 0.2, color = NA) +
    geom_line(linewidth = 1) +
    facet_wrap(~ task, scales = "free") +
    labs(x = "Time Relative to Squeeze Onset (s)", 
         y = "Baseline-Corrected Pupil", 
         color = "Condition", fill = "Condition") +
    theme_minimal() +
    geom_vline(xintercept = 0, linetype = "dashed", color = "grey40") +
    geom_vline(xintercept = 4.35, linetype = "dashed", color = "grey40") +
    geom_vline(xintercept = 4.7, linetype = "dashed", color = "grey40")
  
  ggsave(file.path(V6_FIGS, "waveform_panels_ch3.png"), 
         p_waveform_ch3, width = 12, height = 6, dpi = 100)
  cat("  ✓ Saved: figs/waveform_panels_ch3.png\n")
}

cat("\n")

# ----------------------------------------------------------------------------
# STEP 8: Final summary
# ----------------------------------------------------------------------------

cat("STEP 8: Final summary...\n\n")

# Behavioral join rate
n_behavioral <- sum(merged_v3$has_behavioral_data, na.rm = TRUE)
pct_behavioral <- 100 * n_behavioral / nrow(merged_v3)
cat("Behavioral join rate: ", n_behavioral, " / ", nrow(merged_v3),
    " (", sprintf("%.1f", pct_behavioral), "%)\n", sep = "")

# Ch2/Ch3 trial counts
cat("\nCh2/Ch3 trial counts:\n")
cat("  Ch2: ", nrow(ch2_with_auc), " trials\n", sep = "")
cat("  Ch3: ", nrow(ch3_with_auc), " trials\n", sep = "")

# AUC availability
auc_by_task <- all_auc_features %>%
  group_by(task) %>%
  summarise(
    n_total = n(),
    n_with_total = sum(!is.na(total_auc)),
    n_with_cog = sum(!is.na(cog_auc_fixed1s)),
    pct_total = 100 * n_with_total / n_total,
    pct_cog = 100 * n_with_cog / n_total,
    .groups = "drop"
  )

cat("\nAUC availability by task:\n")
print(auc_by_task)

# Timing coverage
n_ptb <- sum(all_auc_features$timing_source == "ptb", na.rm = TRUE)
n_labels <- sum(all_auc_features$timing_source == "labels", na.rm = TRUE)
n_default <- sum(all_auc_features$timing_source == "default", na.rm = TRUE)
n_total <- nrow(all_auc_features)

cat("\nTiming source coverage:\n")
cat("  PTB-derived: ", n_ptb, " (", sprintf("%.1f", 100 * n_ptb / n_total), "%)\n", sep = "")
cat("  Label-based: ", n_labels, " (", sprintf("%.1f", 100 * n_labels / n_total), "%)\n", sep = "")
cat("  Default (4.35s/4.7s): ", n_default, " (", sprintf("%.1f", 100 * n_default / n_total), "%)\n", sep = "")

# Recommended columns
cat("\nRecommended columns for modeling:\n")
cat("  Chapter 2:\n")
cat("    - Behavioral: effort, stimulus_intensity, isOddball, choice_num, choice_label, rt, correct_final\n")
cat("    - Pupil: total_auc, cog_auc_fixed1s, cog_mean_fixed1s\n")
cat("    - QC: auc_available, b0_n_valid, b1_n_valid, pass_primary_060\n")
cat("  Chapter 3 (DDM):\n")
cat("    - Behavioral: choice_num (0=SAME, 1=DIFFERENT), rt (seconds), stimulus_intensity, isOddball\n")
cat("    - Pupil: total_auc, cog_auc_fixed1s, cog_mean_fixed1s\n")
cat("    - QC: auc_available, b0_n_valid, b1_n_valid, ch3_ddm_ready\n")

# File sizes
ch2_size <- file.size(file.path(V6_ANALYSIS, "ch2_analysis_ready_with_auc.csv")) / 1e6
ch3_size <- file.size(file.path(V6_ANALYSIS, "ch3_ddm_ready_with_auc.csv")) / 1e6
merged_size <- file.size(file.path(V6_MERGED, "BAP_triallevel_merged_v3.csv")) / 1e6

cat("\nFile sizes:\n")
cat("  ch2_analysis_ready_with_auc.csv: ", sprintf("%.2f", ch2_size), " MB\n", sep = "")
cat("  ch3_ddm_ready_with_auc.csv: ", sprintf("%.2f", ch3_size), " MB\n", sep = "")
cat("  BAP_triallevel_merged_v3.csv: ", sprintf("%.2f", merged_size), " MB\n", sep = "")

if (max(ch2_size, ch3_size, merged_size) > 20) {
  cat("  ⚠ WARNING: Some files exceed 20MB\n")
} else {
  cat("  ✓ All files < 20MB\n")
}

cat("\n=== QUICK-SHARE v6 COMPLETE ===\n")

