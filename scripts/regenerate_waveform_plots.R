#!/usr/bin/env Rscript
# ============================================================================
# Regenerate Waveform Plots (STEP 5 + STEP 7 from make_quick_share_v6.R)
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

cat("=== REGENERATING WAVEFORM PLOTS ===\n\n")

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

V6_ROOT <- file.path(REPO_ROOT, "quick_share_v6")
V6_MERGED <- file.path(V6_ROOT, "merged")
V6_WAVEFORMS <- file.path(V6_ROOT, "waveforms")
V6_FIGS <- file.path(V6_ROOT, "figs")

# Constants
FS_TARGET <- 250
FS_CH2_WAVEFORM <- 50
FS_CH3_WAVEFORM <- 250
WINDOW_START <- -3.0
MIN_BASELINE_SAMPLES <- 10L
B0_WIN <- c(-0.5, 0.0)
TARGET_ONSET_DEFAULT <- 4.35
RESP_START_DEFAULT <- 4.70

# Load merged v3 for trial metadata
merged_v3_path <- file.path(V6_MERGED, "BAP_triallevel_merged_v3.csv")
if (!file.exists(merged_v3_path)) {
  stop("Missing merged v3 file: ", merged_v3_path, "\nRun full pipeline first.")
}

merged_v3 <- read_csv(merged_v3_path, show_col_types = FALSE)
cat("  ✓ Loaded merged v3: ", nrow(merged_v3), " trials\n", sep = "")

# Prepare metadata for waveform filtering
merged_with_auc_for_waveforms <- merged_v3 %>%
  select(sub, task, session_used, run_used, trial_index, effort, isOddball, auc_available, b0_n_valid) %>%
  mutate(
    auc_available = if_else(is.na(auc_available), FALSE, auc_available),
    b0_n_valid = if_else(is.na(b0_n_valid), 0L, b0_n_valid)
  ) %>%
  # Filter out trials with missing effort
  filter(!is.na(effort))

cat("  ✓ Trials with valid effort: ", nrow(merged_with_auc_for_waveforms), "\n\n", sep = "")

# ----------------------------------------------------------------------------
# Helper: Extract event timing (simplified version)
# ----------------------------------------------------------------------------

extract_event_timing <- function(df, sub, task, session_used, run_used) {
  target_onset_rel <- TARGET_ONSET_DEFAULT
  resp_start_rel <- RESP_START_DEFAULT
  
  # Try PTB columns
  trial_start_col <- NULL
  target_onset_col <- NULL
  resp_start_col <- NULL
  
  col_names <- names(df)
  
  for (cand in c("trial_start_time_ptb", "trialStartPTB", "trial_start_ptb")) {
    matches <- col_names[tolower(col_names) == tolower(cand)]
    if (length(matches) > 0) {
      trial_start_col <- matches[1]
      break
    }
  }
  
  for (cand in c("target_onset_time_ptb", "targetOnsetPTB", "target_onset_ptb", "A/V_ST")) {
    matches <- col_names[tolower(col_names) == tolower(cand)]
    if (length(matches) > 0) {
      target_onset_col <- matches[1]
      break
    }
  }
  
  for (cand in c("resp1_start_time_ptb", "resp1ST", "resp_start_time_ptb")) {
    matches <- col_names[tolower(col_names) == tolower(cand)]
    if (length(matches) > 0) {
      resp_start_col <- matches[1]
      break
    }
  }
  
  if (!is.null(trial_start_col) && !is.null(target_onset_col)) {
    trial_st <- first(df[[trial_start_col]][!is.na(df[[trial_start_col]])])
    target_st <- first(df[[target_onset_col]][!is.na(df[[target_onset_col]])])
    if (!is.na(trial_st) && !is.na(target_st) && is.finite(trial_st) && is.finite(target_st)) {
      target_onset_rel <- target_st - trial_st
    }
  }
  
  if (!is.null(trial_start_col) && !is.null(resp_start_col)) {
    trial_st <- first(df[[trial_start_col]][!is.na(df[[trial_start_col]])])
    resp_st <- first(df[[resp_start_col]][!is.na(df[[resp_start_col]])])
    if (!is.na(trial_st) && !is.na(resp_st) && is.finite(trial_st) && is.finite(resp_st)) {
      resp_start_rel <- resp_st - trial_st
    }
  }
  
  list(
    t_target_onset_rel = target_onset_rel,
    t_resp_start_rel = resp_start_rel
  )
}

# ----------------------------------------------------------------------------
# Helper: Process one flat file for waveforms
# ----------------------------------------------------------------------------

process_flat_file_waveforms <- function(flat_path, merged_with_auc) {
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
  
  # Get trial metadata from merged data (filtered to valid effort)
  trial_meta <- merged_with_auc %>%
    filter(
      sub == meta$sub,
      task == meta$task,
      session_used == meta$session_used,
      run_used == meta$run_used
    ) %>%
    select(trial_index, effort, isOddball, auc_available, b0_n_valid) %>%
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
      
      # Skip if effort is missing (required for condition grouping)
      if (nrow(trial_info) == 0 || is.na(trial_info$effort[1])) {
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

# ----------------------------------------------------------------------------
# STEP 5: Generate waveform summaries
# ----------------------------------------------------------------------------

cat("STEP 5: Generating waveform summaries...\n")
cat("  (Processing flat files for waveforms; may take time)\n\n")

flat_files <- list.files(
  PROCESSED_DIR,
  pattern = ".*_(ADT|VDT)_flat\\.csv$",
  full.names = TRUE,
  recursive = TRUE
)

if (length(flat_files) == 0) {
  stop("No flat CSV files found in ", PROCESSED_DIR)
}

cat("  Processing ", length(flat_files), " flat files for waveforms...\n", sep = "")

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
# STEP 7: Generate plots
# ----------------------------------------------------------------------------

cat("STEP 7: Generating plots...\n")

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

cat("\n=== WAVEFORM PLOTS REGENERATED ===\n")

