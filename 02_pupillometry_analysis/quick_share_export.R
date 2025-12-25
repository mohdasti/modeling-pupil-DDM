#!/usr/bin/env Rscript
# ============================================================================
# Quick-Share QC Export - Fixed for Trial Counting Bug
# ============================================================================
# Generates compact QC export from MATLAB flat files
# CRITICAL: Uses (sub, task, session_used, run_used, trial_index) as trial key
# Output: data/qc/quick_share_latest/ (8 CSVs)
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(tidyr)
  library(yaml)
})

cat("=== QUICK-SHARE QC EXPORT (FIXED) ===\n\n")

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

REPO_ROOT <- if (file.exists("02_pupillometry_analysis")) {
  normalizePath(getwd())
} else if (file.exists("../02_pupillometry_analysis")) {
  normalizePath("..")
} else {
  normalizePath(getwd())
}

# Load config
config_file <- file.path(REPO_ROOT, "config", "data_paths.yaml")
if (!file.exists(config_file)) {
  config_file_example <- file.path(REPO_ROOT, "config", "data_paths.yaml.example")
  if (file.exists(config_file_example)) {
    stop("Please copy config/data_paths.yaml.example to config/data_paths.yaml and update paths")
  } else {
    stop("Cannot find config/data_paths.yaml or config/data_paths.yaml.example")
  }
}

config <- read_yaml(config_file)
PROCESSED_DIR <- config$processed_dir
BEHAVIORAL_CSV <- if (!is.null(config$behavioral_csv) && nzchar(config$behavioral_csv)) {
  config$behavioral_csv
} else {
  NULL
}

OUTPUT_DIR <- file.path(REPO_ROOT, "data", "qc", "quick_share_latest")
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("Repo root: ", REPO_ROOT, "\n", sep = "")
cat("Processed dir: ", PROCESSED_DIR, "\n", sep = "")
cat("Output dir: ", OUTPUT_DIR, "\n", sep = "")
if (!is.null(BEHAVIORAL_CSV)) {
  cat("Behavioral CSV: ", BEHAVIORAL_CSV, "\n", sep = "")
} else {
  cat("Behavioral CSV: Not available\n")
}
cat("\n")

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------

fs <- 250  # Sampling rate
t0 <- -3.0  # Trial start time (seconds relative to squeeze onset)

# Fixed phase boundaries (seconds relative to squeeze onset)
phase_windows <- list(
  ITI_Baseline     = c(-3.0, 0.0),
  Squeeze          = c(0.0, 5.9),
  PostSqueezeBlank = c(5.9, 6.4),
  PreStimFix       = c(6.4, 6.9),
  Stimulus         = c(6.9, 7.6),
  PostStimFix      = c(7.6, 8.1),
  Response         = c(8.1, 10.7)
)

# Chapter 2 cognitive windows
target_onset <- 6.9
baseline_cog <- c(target_onset - 0.5, target_onset)      # 6.4-6.9
post_target  <- c(target_onset + 0.3, target_onset + 1.3) # 7.2-8.2

# Prestim dip window
dip_window <- c(0.0, 3.0)  # Early squeeze period

# Gate thresholds
gate_thresholds <- c(0.40, 0.50, 0.60, 0.70)

# ----------------------------------------------------------------------------
# Helper Functions
# ----------------------------------------------------------------------------

get_git_hash <- function() {
  hash <- tryCatch(
    system("git rev-parse --short HEAD", intern = TRUE),
    error = function(e) NA_character_
  )
  if (length(hash) == 0) NA_character_ else hash[[1]]
}

safe_quantile <- function(x, prob) {
  if (all(is.na(x)) || length(x) == 0) return(NA_real_)
  as.numeric(quantile(x, prob, na.rm = TRUE, names = FALSE))
}

window_validity <- function(pupil_vec, t_rel_vec, t_start, t_end) {
  in_window <- !is.na(t_rel_vec) & t_rel_vec >= t_start & t_rel_vec <= t_end
  if (!any(in_window, na.rm = TRUE)) return(NA_real_)
  pupil_in_window <- pupil_vec[in_window]
  if (all(is.na(pupil_in_window)) || all(!is.finite(pupil_in_window))) return(NA_real_)
  mean(!is.na(pupil_in_window) & is.finite(pupil_in_window), na.rm = TRUE)
}

window_mean <- function(pupil_vec, t_rel_vec, t_start, t_end) {
  in_window <- !is.na(t_rel_vec) & t_rel_vec >= t_start & t_rel_vec <= t_end
  if (!any(in_window, na.rm = TRUE)) return(NA_real_)
  pupil_in_window <- pupil_vec[in_window]
  pupil_finite <- pupil_in_window[is.finite(pupil_in_window)]
  if (length(pupil_finite) == 0) return(NA_real_)
  mean(pupil_finite, na.rm = TRUE)
}

window_min <- function(pupil_vec, t_rel_vec, t_start, t_end) {
  in_window <- !is.na(t_rel_vec) & t_rel_vec >= t_start & t_rel_vec <= t_end
  if (!any(in_window, na.rm = TRUE)) return(NA_real_)
  pupil_in_window <- pupil_vec[in_window]
  pupil_finite <- pupil_in_window[is.finite(pupil_in_window)]
  if (length(pupil_finite) == 0) return(NA_real_)
  min(pupil_finite, na.rm = TRUE)
}

# ----------------------------------------------------------------------------
# STEP 1: Load and process flat files
# ----------------------------------------------------------------------------

cat("STEP 1: Loading flat files...\n")

flat_files <- list.files(PROCESSED_DIR, pattern = "_flat\\.csv$", full.names = TRUE, recursive = TRUE)
if (length(flat_files) == 0) {
  stop("No *_flat.csv files found in ", PROCESSED_DIR)
}

cat("  Found ", length(flat_files), " flat files\n", sep = "")

# Process files one at a time
trial_data_list <- list()

for (i in seq_along(flat_files)) {
  if (i %% 50 == 0) cat("    Progress: ", i, "/", length(flat_files), "\n", sep = "")
  
  fn <- basename(flat_files[i])
  df <- read_csv(flat_files[i], show_col_types = FALSE, progress = FALSE)
  
  # Normalize columns
  df <- df %>%
    mutate(
      sub = as.character(sub),
      task = as.character(task),
      session_used = as.integer(session_used),
      run_used = as.integer(run_used),
      trial_index = as.integer(trial_index),
      time = as.numeric(time),
      pupil = as.numeric(pupil),
      trial_label = as.character(trial_label %||% NA_character_),
      has_behavioral_data = as.integer(has_behavioral_data %||% 0L)
    ) %>%
    filter(
      !is.na(sub), !is.na(task), !is.na(session_used), !is.na(run_used), !is.na(trial_index),
      session_used %in% c(2L, 3L),  # Hard filter: sessions 2-3 only
      task %in% c("ADT", "VDT"),
      !is.na(time)
    )
  
  if (nrow(df) == 0) next
  
  # Build trial-relative time robustly
  # Sort by time within each trial, then compute t_rel from sample index
  df <- df %>%
    group_by(sub, task, session_used, run_used, trial_index) %>%
    arrange(time) %>%
    mutate(
      sample_i = row_number(),
      t_rel = t0 + (sample_i - 1) / fs
    ) %>%
    ungroup()
  
  # Aggregate to trial level (CRITICAL: key is sub, task, session_used, run_used, trial_index)
  trial_summary <- df %>%
    group_by(sub, task, session_used, run_used, trial_index) %>%
    summarise(
      has_behavioral_data = any(has_behavioral_data == 1L, na.rm = TRUE),
      n_samples_total = n(),
      
      # Overall validity
      pct_non_nan_overall = mean(!is.na(pupil) & is.finite(pupil), na.rm = TRUE),
      
      # Phase window validities
      pct_non_nan_ITI_Baseline = window_validity(pupil, t_rel, phase_windows$ITI_Baseline[1], phase_windows$ITI_Baseline[2]),
      pct_non_nan_PreStimFix = window_validity(pupil, t_rel, phase_windows$PreStimFix[1], phase_windows$PreStimFix[2]),
      pct_non_nan_Stimulus = window_validity(pupil, t_rel, phase_windows$Stimulus[1], phase_windows$Stimulus[2]),
      pct_non_nan_Response = window_validity(pupil, t_rel, phase_windows$Response[1], phase_windows$Response[2]),
      
      # Chapter 2 cognitive windows
      pct_non_nan_baseline_cog = window_validity(pupil, t_rel, baseline_cog[1], baseline_cog[2]),
      pct_non_nan_post_target = window_validity(pupil, t_rel, post_target[1], post_target[2]),
      
      # Chapter 2 means
      mean_baseline_cog = window_mean(pupil, t_rel, baseline_cog[1], baseline_cog[2]),
      mean_post_target = window_mean(pupil, t_rel, post_target[1], post_target[2]),
      delta_post_minus_base = mean_post_target - mean_baseline_cog,
      
      # Prestim dip diagnostics
      baseline_mean_for_dip = window_mean(pupil, t_rel, phase_windows$ITI_Baseline[1], -0.5),
      dip_min = window_min(pupil, t_rel, dip_window[1], dip_window[2]),
      dip_amp = if (!is.na(baseline_mean_for_dip) && !is.na(dip_min)) {
        baseline_mean_for_dip - dip_min
      } else NA_real_,
      
      .groups = "drop"
    )
  
  trial_data_list[[i]] <- trial_summary
  rm(df, trial_summary)
  gc(verbose = FALSE)
}

trial_data <- bind_rows(trial_data_list)
rm(trial_data_list)
gc(verbose = FALSE)

cat("  ✓ Loaded ", nrow(trial_data), " trials\n", sep = "")

# CRITICAL ASSERTION: Check median n_trials per run
run_counts <- trial_data %>%
  group_by(sub, task, session_used, run_used) %>%
  summarise(n_trials = n_distinct(trial_index), .groups = "drop")  # Use trial_index, not trial_label!

median_trials_per_run <- median(run_counts$n_trials, na.rm = TRUE)
cat("  Median trials per run: ", median_trials_per_run, "\n", sep = "")

if (median_trials_per_run < 28 || median_trials_per_run > 30) {
  cat("\n*** ERROR: Median trials per run is ", median_trials_per_run, 
      " (expected 28-30)\n", sep = "")
  cat("First 10 offending runs:\n")
  print(run_counts %>%
    filter(n_trials < 28 | n_trials > 30) %>%
    slice_head(n = 10))
  stop("Trial count assertion failed.")
}

# Check for 60-trials bug
runs_with_60 <- sum(run_counts$n_trials == 60, na.rm = TRUE)
if (runs_with_60 > 0) {
  cat("\n*** WARNING: Found ", runs_with_60, " runs with exactly 60 trials (possible double-counting bug)\n", sep = "")
}

# ----------------------------------------------------------------------------
# STEP 2: Load behavioral data (if available)
# ----------------------------------------------------------------------------

behavioral_trials <- tibble()
has_behavioral_conditions <- FALSE

if (!is.null(BEHAVIORAL_CSV) && file.exists(BEHAVIORAL_CSV)) {
  cat("\nSTEP 2: Loading behavioral data...\n")
  beh_raw <- read_csv(BEHAVIORAL_CSV, show_col_types = FALSE)
  
  # Normalize to match trial key: (sub, task, session_used, run_used, trial_index)
  if ("sub" %in% names(beh_raw)) {
    beh_raw$sub <- as.character(beh_raw$sub)
  } else if ("subject_id" %in% names(beh_raw)) {
    beh_raw$sub <- as.character(beh_raw$subject_id)
  }
  
  if ("task" %in% names(beh_raw)) {
    beh_raw$task <- as.character(beh_raw$task)
  } else if ("task_modality" %in% names(beh_raw)) {
    beh_raw$task <- ifelse(beh_raw$task_modality == "aud", "ADT",
                          ifelse(beh_raw$task_modality == "vis", "VDT", NA_character_))
  }
  
  if ("session_used" %in% names(beh_raw)) {
    beh_raw$session_used <- as.integer(beh_raw$session_used)
  } else if ("session" %in% names(beh_raw)) {
    beh_raw$session_used <- as.integer(beh_raw$session)
  } else if ("ses" %in% names(beh_raw)) {
    beh_raw$session_used <- as.integer(beh_raw$ses)
  }
  
  if ("run_used" %in% names(beh_raw)) {
    beh_raw$run_used <- as.integer(beh_raw$run_used)
  } else if ("run" %in% names(beh_raw)) {
    beh_raw$run_used <- as.integer(beh_raw$run)
  }
  
  if ("trial_index" %in% names(beh_raw)) {
    beh_raw$trial_index <- as.integer(beh_raw$trial_index)
  } else if ("trial_in_run_raw" %in% names(beh_raw)) {
    beh_raw$trial_index <- as.integer(beh_raw$trial_in_run_raw)
  } else if ("trial_num" %in% names(beh_raw)) {
    beh_raw$trial_index <- as.integer(beh_raw$trial_num)
  } else {
    beh_raw$trial_index <- NA_integer_
  }
  
  # Check for condition columns
  has_grip_mvc <- "grip_targ_prop_mvc" %in% names(beh_raw)
  has_isOddball <- "isOddball" %in% names(beh_raw)
  has_stim_is_diff <- "stim_is_diff" %in% names(beh_raw)
  has_behavioral_conditions <- has_grip_mvc || has_isOddball || has_stim_is_diff
  
  # Filter and create condition columns
  behavioral_trials <- beh_raw %>%
    filter(
      !is.na(sub), !is.na(task), !is.na(session_used), !is.na(run_used), !is.na(trial_index),
      session_used %in% c(2L, 3L),
      task %in% c("ADT", "VDT")
    ) %>%
    mutate(
      effort = if (has_grip_mvc) {
        ifelse(grip_targ_prop_mvc == 0.05, "Low",
               ifelse(grip_targ_prop_mvc == 0.40, "High", NA_character_))
      } else NA_character_,
      oddball = if (has_isOddball) {
        as.integer(isOddball)
      } else if (has_stim_is_diff) {
        as.integer(stim_is_diff)
      } else NA_integer_
    ) %>%
    select(sub, task, session_used, run_used, trial_index, effort, oddball)
  
  cat("  ✓ Loaded ", nrow(behavioral_trials), " behavioral trials\n", sep = "")
  if (has_behavioral_conditions) {
    cat("  ✓ Behavioral condition columns found\n", sep = "")
  } else {
    cat("  ⚠ Behavioral condition columns not found\n", sep = "")
  }
  
  # Merge with trial_data
  trial_data <- trial_data %>%
    left_join(behavioral_trials, by = c("sub", "task", "session_used", "run_used", "trial_index"))
}

# ----------------------------------------------------------------------------
# STEP 3: Compute gates
# ----------------------------------------------------------------------------

cat("\nSTEP 3: Computing gates...\n")

# Compute gate pass/fail for each threshold
for (th in gate_thresholds) {
  trial_data[[paste0("pass_baseline_cog_", sprintf("%.2f", th))]] <- 
    !is.na(trial_data$pct_non_nan_baseline_cog) & trial_data$pct_non_nan_baseline_cog >= th
  
  trial_data[[paste0("pass_post_target_", sprintf("%.2f", th))]] <- 
    !is.na(trial_data$pct_non_nan_post_target) & trial_data$pct_non_nan_post_target >= th
  
  trial_data[[paste0("pass_overall_", sprintf("%.2f", th))]] <- 
    !is.na(trial_data$pct_non_nan_overall) & trial_data$pct_non_nan_overall >= th
}

cat("  ✓ Gates computed\n")

# ----------------------------------------------------------------------------
# STEP 4: Generate output CSVs
# ----------------------------------------------------------------------------

cat("\nSTEP 4: Generating output CSVs...\n")

# 1) 01_file_provenance.csv
file_provenance <- tibble()
for (f in flat_files) {
  info <- file.info(f)
  df_sample <- read_csv(f, n_max = 1, show_col_types = FALSE)
  file_provenance <- bind_rows(
    file_provenance,
    tibble(
      filename = basename(f),
      size_MB = round(info$size / 1024^2, 3),
      modified_time = format(info$mtime, "%Y-%m-%d %H:%M:%S"),
      n_cols = ncol(df_sample)
    )
  )
}

file_provenance <- bind_rows(
  file_provenance,
  tibble(
    filename = "SUMMARY",
    size_MB = sum(file_provenance$size_MB, na.rm = TRUE),
    modified_time = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    n_cols = NA_integer_
  )
)

write_csv(file_provenance, file.path(OUTPUT_DIR, "01_file_provenance.csv"))
cat("  ✓ 01_file_provenance.csv\n")

# 2) 02_design_expected_vs_observed.csv
design_table <- trial_data %>%
  group_by(sub, task, session_used) %>%
  summarise(
    expected_runs = 5L,
    expected_trials = 150L,
    observed_runs = n_distinct(run_used),
    observed_trials = n_distinct(trial_index),  # CRITICAL: distinct trial_index
    .groups = "drop"
  ) %>%
  mutate(pct_coverage = observed_trials / expected_trials)

write_csv(design_table, file.path(OUTPUT_DIR, "02_design_expected_vs_observed.csv"))
cat("  ✓ 02_design_expected_vs_observed.csv\n")

# 3) 03_trials_per_subject_task_ses.csv
trials_per_subject <- trial_data %>%
  group_by(sub, task, session_used) %>%
  summarise(
    observed_trials = n_distinct(trial_index),  # CRITICAL: distinct trial_index
    observed_runs = n_distinct(run_used),
    n_trials_with_behavioral = sum(has_behavioral_data, na.rm = TRUE),
    .groups = "drop"
  )

# Add gate pass counts
for (th in gate_thresholds) {
  th_str <- sprintf("%.2f", th)
  trials_per_subject[[paste0("n_pass_baseline_cog_", th_str)]] <- 
    trial_data %>%
    group_by(sub, task, session_used) %>%
    summarise(n = sum(.data[[paste0("pass_baseline_cog_", th_str)]], na.rm = TRUE), .groups = "drop") %>%
    pull(n)
  
  trials_per_subject[[paste0("n_pass_post_target_", th_str)]] <- 
    trial_data %>%
    group_by(sub, task, session_used) %>%
    summarise(n = sum(.data[[paste0("pass_post_target_", th_str)]], na.rm = TRUE), .groups = "drop") %>%
    pull(n)
  
  trials_per_subject[[paste0("n_pass_overall_", th_str)]] <- 
    trial_data %>%
    group_by(sub, task, session_used) %>%
    summarise(n = sum(.data[[paste0("pass_overall_", th_str)]], na.rm = TRUE), .groups = "drop") %>%
    pull(n)
}

write_csv(trials_per_subject, file.path(OUTPUT_DIR, "03_trials_per_subject_task_ses.csv"))
cat("  ✓ 03_trials_per_subject_task_ses.csv\n")

# 4) 04_run_level_counts.csv
run_level <- trial_data %>%
  group_by(sub, task, session_used, run_used) %>%
  summarise(
    n_trials = n_distinct(trial_index),  # CRITICAL: distinct trial_index
    pct_trials_any_pupil = mean(pct_non_nan_overall > 0, na.rm = TRUE),
    mean_pct_non_nan_overall = mean(pct_non_nan_overall, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(run_level, file.path(OUTPUT_DIR, "04_run_level_counts.csv"))
cat("  ✓ 04_run_level_counts.csv\n")

# 5) 05_window_validity_summary.csv
window_summary <- trial_data %>%
  group_by(task) %>%
  summarise(
    n_trials = n(),
    # Overall
    overall_mean = mean(pct_non_nan_overall, na.rm = TRUE),
    overall_median = median(pct_non_nan_overall, na.rm = TRUE),
    overall_p10 = safe_quantile(pct_non_nan_overall, 0.10),
    overall_p90 = safe_quantile(pct_non_nan_overall, 0.90),
    # Baseline cog
    baseline_cog_mean = mean(pct_non_nan_baseline_cog, na.rm = TRUE),
    baseline_cog_median = median(pct_non_nan_baseline_cog, na.rm = TRUE),
    baseline_cog_p10 = safe_quantile(pct_non_nan_baseline_cog, 0.10),
    baseline_cog_p90 = safe_quantile(pct_non_nan_baseline_cog, 0.90),
    # Post target
    post_target_mean = mean(pct_non_nan_post_target, na.rm = TRUE),
    post_target_median = median(pct_non_nan_post_target, na.rm = TRUE),
    post_target_p10 = safe_quantile(pct_non_nan_post_target, 0.10),
    post_target_p90 = safe_quantile(pct_non_nan_post_target, 0.90),
    .groups = "drop"
  )

write_csv(window_summary, file.path(OUTPUT_DIR, "05_window_validity_summary.csv"))
cat("  ✓ 05_window_validity_summary.csv\n")

# 6) 06_gate_pass_rates_by_threshold.csv
gate_rates <- map_dfr(gate_thresholds, function(th) {
  th_str <- sprintf("%.2f", th)
  trial_data %>%
    group_by(task) %>%
    summarise(
      threshold = th,
      gate = "baseline_cog",
      n_pass = sum(.data[[paste0("pass_baseline_cog_", th_str)]], na.rm = TRUE),
      n_total = sum(!is.na(pct_non_nan_baseline_cog)),
      pass_rate = if_else(n_total > 0, n_pass / n_total, NA_real_),
      .groups = "drop"
    ) %>%
    bind_rows(
      trial_data %>%
        group_by(task) %>%
        summarise(
          threshold = th,
          gate = "post_target",
          n_pass = sum(.data[[paste0("pass_post_target_", th_str)]], na.rm = TRUE),
          n_total = sum(!is.na(pct_non_nan_post_target)),
          pass_rate = if_else(n_total > 0, n_pass / n_total, NA_real_),
          .groups = "drop"
        )
    ) %>%
    bind_rows(
      trial_data %>%
        group_by(task) %>%
        summarise(
          threshold = th,
          gate = "overall",
          n_pass = sum(.data[[paste0("pass_overall_", th_str)]], na.rm = TRUE),
          n_total = sum(!is.na(pct_non_nan_overall)),
          pass_rate = if_else(n_total > 0, n_pass / n_total, NA_real_),
          .groups = "drop"
        )
    )
})

write_csv(gate_rates, file.path(OUTPUT_DIR, "06_gate_pass_rates_by_threshold.csv"))
cat("  ✓ 06_gate_pass_rates_by_threshold.csv\n")

# 7) 07_bias_checks_key_gates.csv
if (has_behavioral_conditions && nrow(behavioral_trials) > 0 && 
    ("effort" %in% names(trial_data) || "oddball" %in% names(trial_data))) {
  bias_checks <- map_dfr(c(0.60, 0.70), function(th) {
    th_str <- sprintf("%.2f", th)
    gate_col <- paste0("pass_baseline_cog_", th_str)
    
    if ("effort" %in% names(trial_data)) {
      by_effort <- trial_data %>%
        filter(!is.na(effort)) %>%
        group_by(task, effort) %>%
        summarise(
          threshold = th,
          gate = "baseline_cog",
          predictor = "effort",
          predictor_value = first(effort),
          n_pass = sum(.data[[gate_col]], na.rm = TRUE),
          n_total = sum(!is.na(pct_non_nan_baseline_cog)),
          pass_rate = if_else(n_total > 0, n_pass / n_total, NA_real_),
          .groups = "drop"
        ) %>%
        group_by(task, threshold, gate, predictor) %>%
        summarise(
          max_pass_rate = max(pass_rate, na.rm = TRUE),
          min_pass_rate = min(pass_rate, na.rm = TRUE),
          max_min_diff = max_pass_rate - min_pass_rate,
          .groups = "drop"
        )
    } else {
      by_effort <- tibble()
    }
    
    if ("oddball" %in% names(trial_data)) {
      by_oddball <- trial_data %>%
        filter(!is.na(oddball)) %>%
        group_by(task, oddball) %>%
        summarise(
          threshold = th,
          gate = "baseline_cog",
          predictor = "oddball",
          predictor_value = as.character(first(oddball)),
          n_pass = sum(.data[[gate_col]], na.rm = TRUE),
          n_total = sum(!is.na(pct_non_nan_baseline_cog)),
          pass_rate = if_else(n_total > 0, n_pass / n_total, NA_real_),
          .groups = "drop"
        ) %>%
        group_by(task, threshold, gate, predictor) %>%
        summarise(
          max_pass_rate = max(pass_rate, na.rm = TRUE),
          min_pass_rate = min(pass_rate, na.rm = TRUE),
          max_min_diff = max_pass_rate - min_pass_rate,
          .groups = "drop"
        )
    } else {
      by_oddball <- tibble()
    }
    
    bind_rows(by_effort, by_oddball)
  })
  
  if (nrow(bias_checks) > 0) {
    write_csv(bias_checks, file.path(OUTPUT_DIR, "07_bias_checks_key_gates.csv"))
    cat("  ✓ 07_bias_checks_key_gates.csv\n")
  } else {
    bias_checks <- tibble(
      note = "Behavioral condition columns found but no data after filtering"
    )
    write_csv(bias_checks, file.path(OUTPUT_DIR, "07_bias_checks_key_gates.csv"))
    cat("  ✓ 07_bias_checks_key_gates.csv (empty - no data)\n")
  }
} else {
  bias_checks <- tibble(
    note = "Behavioral condition columns not found; skipped"
  )
  write_csv(bias_checks, file.path(OUTPUT_DIR, "07_bias_checks_key_gates.csv"))
  cat("  ✓ 07_bias_checks_key_gates.csv (skipped - no behavioral conditions)\n")
}

# 8) 08_prestim_dip_summary.csv
prestim_dip <- trial_data %>%
  filter(!is.na(dip_amp)) %>%
  group_by(sub, task, session_used) %>%
  summarise(
    n_trials = n(),
    mean_dip_amp = mean(dip_amp, na.rm = TRUE),
    median_dip_amp = median(dip_amp, na.rm = TRUE),
    pct_negative_dip = mean(dip_amp < 0, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  group_by(task) %>%
  summarise(
    n_subjects = n_distinct(sub),
    n_trials_total = sum(n_trials, na.rm = TRUE),
    mean_dip_amp_overall = mean(mean_dip_amp, na.rm = TRUE),
    median_dip_amp_overall = median(median_dip_amp, na.rm = TRUE),
    pct_negative_dip_overall = mean(pct_negative_dip, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(prestim_dip, file.path(OUTPUT_DIR, "08_prestim_dip_summary.csv"))
cat("  ✓ 08_prestim_dip_summary.csv\n")

cat("\n=== QUICK-SHARE EXPORT COMPLETE ===\n")
cat("Outputs saved to: ", OUTPUT_DIR, "\n", sep = "")
cat("Median trials per run: ", median_trials_per_run, " (expected 28-30)\n", sep = "")
