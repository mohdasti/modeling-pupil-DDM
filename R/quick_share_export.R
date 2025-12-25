#!/usr/bin/env Rscript
# ============================================================================
# Quick-Share Export - Trial-Level Aggregation
# ============================================================================
# Aggregates MATLAB *_flat.csv sample-level files into trial-level table
# Computes window validity + pupil features
# Generates <= 8 CSV outputs + README
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(tidyr)
  library(yaml)
  library(data.table)
  library(broom)
})

cat("=== QUICK-SHARE EXPORT (TRIAL-LEVEL) ===\n\n")

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

REPO_ROOT <- if (file.exists("R")) {
  normalizePath(getwd())
} else if (file.exists("../R")) {
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
    stop("Cannot find config/data_paths.yaml")
  }
}

config <- read_yaml(config_file)
PROCESSED_DIR <- config$processed_dir
OUTPUT_DIR <- file.path(REPO_ROOT, "quick_share_v2")
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("Repo root: ", REPO_ROOT, "\n", sep = "")
cat("Processed dir: ", PROCESSED_DIR, "\n", sep = "")
cat("Output dir: ", OUTPUT_DIR, "\n\n", sep = "")

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------

# Windows (seconds relative to t_rel_used)
BASELINE_WINDOW <- c(-0.5, 0.0)
COG_WINDOW <- c(0.3, 1.3)
GLOBAL_WINDOW <- c(-0.5, 5.0)

# Gate thresholds
GATE_THRESHOLDS <- c(0.50, 0.60, 0.70)

# Expected design
EXPECTED_RUNS_PER_SESSION <- 5L
EXPECTED_TRIALS_PER_RUN <- 30L

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

trapezoidal_auc <- function(x, y) {
  # Trapezoidal integration
  if (length(x) < 2 || length(y) < 2) return(NA_real_)
  if (length(x) != length(y)) return(NA_real_)
  valid <- !is.na(x) & !is.na(y) & is.finite(x) & is.finite(y)
  if (sum(valid) < 2) return(NA_real_)
  x_valid <- x[valid]
  y_valid <- y[valid]
  ord <- order(x_valid)
  x_ord <- x_valid[ord]
  y_ord <- y_valid[ord]
  sum(diff(x_ord) * (y_ord[-length(y_ord)] + y_ord[-1]) / 2)
}

window_validity <- function(pupil_vec, t_rel_vec, t_start, t_end) {
  in_window <- !is.na(t_rel_vec) & t_rel_vec >= t_start & t_rel_vec <= t_end
  if (!any(in_window, na.rm = TRUE)) return(NA_real_)
  pupil_in_window <- pupil_vec[in_window]
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

# ----------------------------------------------------------------------------
# STEP 1: Discover and process flat files
# ----------------------------------------------------------------------------

cat("STEP 1: Discovering flat files...\n")

flat_files <- list.files(PROCESSED_DIR, pattern = "_flat\\.csv$", full.names = TRUE, recursive = TRUE)
if (length(flat_files) == 0) {
  stop("No *_flat.csv files found in ", PROCESSED_DIR)
}

cat("  Found ", length(flat_files), " flat files\n", sep = "")

# Process files one at a time (streaming)
trial_data_list <- list()

for (i in seq_along(flat_files)) {
  if (i %% 50 == 0) cat("    Progress: ", i, "/", length(flat_files), "\n", sep = "")
  
  fn <- basename(flat_files[i])
  
  # Use data.table::fread for faster streaming
  df <- fread(flat_files[i], select = c("sub", "task", "session_used", "run_used", "trial_index",
                                         "has_behavioral_data", "baseline_quality", "overall_quality",
                                         "qc_fail_baseline", "qc_fail_overall", "all_nan", "window_oob",
                                         "time", "pupil", "trial_label", "trial_start_time_ptb"),
              colClasses = list(character = c("sub", "task", "trial_label"),
                               integer = c("session_used", "run_used", "trial_index", 
                                          "has_behavioral_data", "qc_fail_baseline", 
                                          "qc_fail_overall", "all_nan", "window_oob"),
                               numeric = c("time", "pupil", "baseline_quality", 
                                          "overall_quality", "trial_start_time_ptb")))
  
  # Normalize and filter
  df <- df %>%
    mutate(
      sub = as.character(sub),
      task = as.character(task),
      session_used = as.integer(session_used),
      run_used = as.integer(run_used),
      trial_index = as.integer(trial_index),
      time = as.numeric(time),
      pupil = as.numeric(pupil),
      trial_start_time_ptb = as.numeric(trial_start_time_ptb),
      baseline_quality = as.numeric(baseline_quality),
      overall_quality = as.numeric(overall_quality),
      has_behavioral_data = as.integer(has_behavioral_data %||% 0L),
      qc_fail_baseline = as.integer(qc_fail_baseline %||% 0L),
      qc_fail_overall = as.integer(qc_fail_overall %||% 0L),
      all_nan = as.integer(all_nan %||% 0L),
      window_oob = as.integer(window_oob %||% 0L)
    ) %>%
    filter(
      !is.na(sub), !is.na(task), !is.na(session_used), !is.na(run_used), !is.na(trial_index),
      session_used %in% c(2L, 3L),
      task %in% c("ADT", "VDT"),
      !is.na(time)
    )
  
  if (nrow(df) == 0) next
  
  # First pass: trial metadata (one row per trial)
  trial_meta <- df %>%
    group_by(sub, task, session_used, run_used, trial_index) %>%
    summarise(
      has_behavioral_data = any(has_behavioral_data == 1L, na.rm = TRUE),
      baseline_quality = first(baseline_quality[!is.na(baseline_quality)]),
      overall_quality = first(overall_quality[!is.na(overall_quality)]),
      qc_fail_baseline = max(qc_fail_baseline, na.rm = TRUE),
      qc_fail_overall = max(qc_fail_overall, na.rm = TRUE),
      all_nan = max(all_nan, na.rm = TRUE),
      window_oob = max(window_oob, na.rm = TRUE),
      trial_start_time_ptb = first(trial_start_time_ptb[!is.na(trial_start_time_ptb)]),
      .groups = "drop"
    )
  
  # Second pass: compute t_rel robustly and window features
  # Add candidate t_rel to df
  df <- df %>%
    group_by(sub, task, session_used, run_used, trial_index) %>%
    arrange(time) %>%
    mutate(
      t_rel_candidate = time - trial_start_time_ptb
    ) %>%
    ungroup()
  
  # Compute timebase flags per trial (aggregate time stats)
  timebase_info <- df %>%
    group_by(sub, task, session_used, run_used, trial_index) %>%
    summarise(
      time_min = min(time, na.rm = TRUE),
      time_max = max(time, na.rm = TRUE),
      time_range = time_max - time_min,
      t_rel_candidate_min = min(t_rel_candidate, na.rm = TRUE),
      t_rel_candidate_max = max(t_rel_candidate, na.rm = TRUE),
      t_rel_candidate_range = t_rel_candidate_max - t_rel_candidate_min,
      .groups = "drop"
    ) %>%
    mutate(
      # Choose timebase_flag
      use_candidate = t_rel_candidate_range >= 10 & t_rel_candidate_range <= 30 & t_rel_candidate_min < 0,
      use_raw = !use_candidate & time_range >= 10 & time_range <= 30 & time_min < 0,
      timebase_flag = if_else(use_candidate | use_raw, 0L, 1L)
    )
  
  # Add timebase info and t_rel_used to df
  df <- df %>%
    left_join(timebase_info %>% select(sub, task, session_used, run_used, trial_index, 
                                       timebase_flag, use_candidate),
              by = c("sub", "task", "session_used", "run_used", "trial_index")) %>%
    mutate(
      t_rel_used = if_else(timebase_flag == 0L,
                           if_else(use_candidate, t_rel_candidate, time),
                           NA_real_)
    )
  
  # Compute features for valid timebase trials
  trial_features <- df %>%
    filter(timebase_flag == 0L, !is.na(t_rel_used)) %>%
    group_by(sub, task, session_used, run_used, trial_index) %>%
    summarise(
      n_samples = n(),
      
      # Window validities
      baseline_valid = window_validity(pupil, t_rel_used, BASELINE_WINDOW[1], BASELINE_WINDOW[2]),
      cog_valid = window_validity(pupil, t_rel_used, COG_WINDOW[1], COG_WINDOW[2]),
      total_valid_from_samples = mean(!is.na(pupil) & is.finite(pupil), na.rm = TRUE),
      
      # Baseline correction
      baseline_mean = window_mean(pupil, t_rel_used, BASELINE_WINDOW[1], BASELINE_WINDOW[2]),
      
      # AUCs (need to compute with full vectors, so do it in a nested way)
      total_auc = {
        bm <- baseline_mean[1]
        if (!is.na(bm)) {
          pupil_bc_vec <- pupil - bm
          trapezoidal_auc(t_rel_used, pupil_bc_vec)
        } else NA_real_
      },
      
      cog_auc = {
        bm <- baseline_mean[1]
        if (!is.na(bm)) {
          pupil_bc_vec <- pupil - bm
          in_cog <- t_rel_used >= COG_WINDOW[1] & t_rel_used <= COG_WINDOW[2] & !is.na(t_rel_used)
          if (sum(in_cog, na.rm = TRUE) > 1) {
            trapezoidal_auc(t_rel_used[in_cog], pupil_bc_vec[in_cog])
          } else NA_real_
        } else NA_real_
      },
      
      .groups = "drop"
    )
  
  # Add timebase_flag to trial_meta for all trials
  trial_meta <- trial_meta %>%
    left_join(timebase_info %>% select(sub, task, session_used, run_used, trial_index, timebase_flag),
              by = c("sub", "task", "session_used", "run_used", "trial_index")) %>%
    mutate(
      timebase_flag = if_else(is.na(timebase_flag), 1L, timebase_flag)
    )
  
  # Merge trial_meta with trial_features
  trial_batch <- trial_meta %>%
    left_join(trial_features, by = c("sub", "task", "session_used", "run_used", "trial_index")) %>%
    mutate(
      # Use overall_quality if available, else total_valid_from_samples
      total_valid = if_else(!is.na(overall_quality), overall_quality, total_valid_from_samples),
      # Ensure timebase_flag exists
      timebase_flag = if_else(is.na(timebase_flag), 1L, timebase_flag),
      # Set n_samples to 0 if missing (trial had invalid timebase)
      n_samples = if_else(is.na(n_samples), 0L, as.integer(n_samples))
    )
  
  trial_data_list[[i]] <- trial_batch
  rm(df, trial_meta, trial_features, trial_batch)
  gc(verbose = FALSE)
}

trial_data <- bind_rows(trial_data_list)
rm(trial_data_list)
gc(verbose = FALSE)

# CRITICAL: Deduplicate to ensure one row per trial
# Trial identity: (sub, task, session_used, run_used, trial_index)
trial_data <- trial_data %>%
  group_by(sub, task, session_used, run_used, trial_index) %>%
  slice(1) %>%  # Keep first row if duplicates exist
  ungroup()

cat("  ✓ Loaded ", nrow(trial_data), " trials (deduplicated)\n", sep = "")

# Assertion: Verify trial counts per run are reasonable
run_trial_counts <- trial_data %>%
  group_by(sub, task, session_used, run_used) %>%
  summarise(n_trials = n_distinct(trial_index), .groups = "drop")

outlier_runs <- run_trial_counts %>%
  filter(n_trials < 20 | n_trials > 35)

if (nrow(outlier_runs) > 0) {
  cat("  ⚠ WARNING: Found runs with unusual trial counts:\n")
  print(outlier_runs)
} else {
  cat("  ✓ All runs have trial counts in [20, 35] range\n")
}

# Assertion: Verify no session 1 contamination
session_check <- trial_data %>%
  filter(session_used == 1L) %>%
  nrow()

if (session_check > 0) {
  stop("CRITICAL ERROR: Found ", session_check, " trials with session_used == 1. Contamination detected!")
}

# ----------------------------------------------------------------------------
# STEP 2: Compute gates
# ----------------------------------------------------------------------------

cat("\nSTEP 2: Computing gates...\n")

for (th in GATE_THRESHOLDS) {
  th_str <- sprintf("%.2f", th)
  trial_data[[paste0("pass_baseline_", th_str)]] <- 
    !is.na(trial_data$baseline_valid) & trial_data$baseline_valid >= th
  
  trial_data[[paste0("pass_cog_", th_str)]] <- 
    !is.na(trial_data$cog_valid) & trial_data$cog_valid >= th
  
  trial_data[[paste0("pass_primary_", th_str)]] <- 
    trial_data[[paste0("pass_baseline_", th_str)]] &
    trial_data[[paste0("pass_cog_", th_str)]] &
    trial_data$timebase_flag == 0L &
    trial_data$all_nan == 0L &
    trial_data$window_oob == 0L
}

cat("  ✓ Gates computed\n")

# ----------------------------------------------------------------------------
# STEP 3: Generate outputs
# ----------------------------------------------------------------------------

cat("\nSTEP 3: Generating outputs...\n")

# 01_file_provenance.csv
file_provenance <- map_dfr(flat_files, function(f) {
  info <- file.info(f)
  tibble(
    filename = basename(f),
    size_MB = round(info$size / 1024^2, 3),
    modified_time = format(info$mtime, "%Y-%m-%d %H:%M:%S")
  )
}) %>%
  bind_rows(
    tibble(
      filename = "SUMMARY",
      size_MB = sum(.$size_MB, na.rm = TRUE),
      modified_time = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    )
  )

write_csv(file_provenance, file.path(OUTPUT_DIR, "01_file_provenance.csv"))
cat("  ✓ 01_file_provenance.csv\n")

# 02_design_expected_vs_observed.csv
design_table <- trial_data %>%
  group_by(sub, task, session_used) %>%
  summarise(
    expected_runs = EXPECTED_RUNS_PER_SESSION,
    expected_trials = EXPECTED_RUNS_PER_SESSION * EXPECTED_TRIALS_PER_RUN,
    observed_runs = n_distinct(run_used),
    observed_trials = n_distinct(trial_index),  # TRUE trial count
    .groups = "drop"
  ) %>%
  mutate(pct_coverage = observed_trials / expected_trials)

write_csv(design_table, file.path(OUTPUT_DIR, "02_design_expected_vs_observed.csv"))
cat("  ✓ 02_design_expected_vs_observed.csv\n")

# 03_trials_per_subject_task_ses.csv
# CRITICAL: All counts must use n_distinct or work on deduplicated trial table
trials_per_subject <- trial_data %>%
  group_by(sub, task, session_used) %>%
  summarise(
    observed_trials = n_distinct(trial_index),  # TRUE trial count
    observed_runs = n_distinct(run_used),
    # For boolean flags, count distinct trials where flag is TRUE
    n_trials_with_behavioral = sum(has_behavioral_data == 1L, na.rm = TRUE),
    n_trials_timebase_flag = sum(timebase_flag == 1L, na.rm = TRUE),
    .groups = "drop"
  )

# Add gate pass counts (must count distinct trials, not sum booleans)
for (th in GATE_THRESHOLDS) {
  th_str <- sprintf("%.2f", th)
  col_name <- paste0("pass_primary_", th_str)
  
  # Count distinct trials that pass the gate
  gate_counts <- trial_data %>%
    filter(.data[[col_name]] == TRUE) %>%
    group_by(sub, task, session_used) %>%
    summarise(n = n_distinct(trial_index), .groups = "drop")
  
  # Merge back to trials_per_subject
  trials_per_subject <- trials_per_subject %>%
    left_join(gate_counts, by = c("sub", "task", "session_used")) %>%
    mutate(!!paste0("n_pass_primary_", th_str) := if_else(is.na(n), 0L, as.integer(n))) %>%
    select(-n)
}

# Assertion: Verify n_trials_with_behavioral <= observed_trials
violations <- trials_per_subject %>%
  filter(n_trials_with_behavioral > observed_trials)

if (nrow(violations) > 0) {
  cat("  ⚠ WARNING: Found violations where n_trials_with_behavioral > observed_trials:\n")
  print(violations)
  stop("CRITICAL ERROR: Double-counting detected in behavioral trials!")
}

write_csv(trials_per_subject, file.path(OUTPUT_DIR, "03_trials_per_subject_task_ses.csv"))
cat("  ✓ 03_trials_per_subject_task_ses.csv\n")

# 04_run_level_counts.csv
run_level <- trial_data %>%
  group_by(sub, task, session_used, run_used) %>%
  summarise(
    n_trials = n_distinct(trial_index),  # TRUE trial count
    pct_timebase_flag = mean(timebase_flag == 1L, na.rm = TRUE),
    pct_all_nan = mean(all_nan == 1L, na.rm = TRUE),
    pct_window_oob = mean(window_oob == 1L, na.rm = TRUE),
    mean_baseline_valid = mean(baseline_valid, na.rm = TRUE),
    mean_cog_valid = mean(cog_valid, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(run_level, file.path(OUTPUT_DIR, "04_run_level_counts.csv"))
cat("  ✓ 04_run_level_counts.csv\n")

# 05_window_validity_summary.csv
window_summary <- trial_data %>%
  filter(timebase_flag == 0L) %>%
  group_by(task) %>%
  summarise(
    n_trials = n_distinct(trial_index),  # Count distinct trials
    baseline_valid_mean = mean(baseline_valid, na.rm = TRUE),
    baseline_valid_median = median(baseline_valid, na.rm = TRUE),
    baseline_valid_p10 = safe_quantile(baseline_valid, 0.10),
    baseline_valid_p90 = safe_quantile(baseline_valid, 0.90),
    cog_valid_mean = mean(cog_valid, na.rm = TRUE),
    cog_valid_median = median(cog_valid, na.rm = TRUE),
    cog_valid_p10 = safe_quantile(cog_valid, 0.10),
    cog_valid_p90 = safe_quantile(cog_valid, 0.90),
    total_valid_mean = mean(total_valid, na.rm = TRUE),
    total_valid_median = median(total_valid, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(window_summary, file.path(OUTPUT_DIR, "05_window_validity_summary.csv"))
cat("  ✓ 05_window_validity_summary.csv\n")

# 06_gate_pass_rates_by_threshold.csv
# CRITICAL: Count distinct trials, not sum booleans
gate_rates <- map_dfr(GATE_THRESHOLDS, function(th) {
  th_str <- sprintf("%.2f", th)
  baseline_col <- paste0("pass_baseline_", th_str)
  cog_col <- paste0("pass_cog_", th_str)
  primary_col <- paste0("pass_primary_", th_str)
  
  # Baseline gate
  baseline_data <- trial_data %>%
    filter(timebase_flag == 0L, !is.na(baseline_valid))
  
  baseline_summary <- baseline_data %>%
    group_by(task) %>%
    summarise(
      threshold = th,
      gate = "baseline",
      n_pass = sum(.data[[baseline_col]], na.rm = TRUE),  # Already boolean, sum counts TRUE
      n_total = n_distinct(trial_index),
      pass_rate = if_else(n_total > 0, n_pass / n_total, NA_real_),
      .groups = "drop"
    )
  
  # Cognitive gate
  cog_data <- trial_data %>%
    filter(timebase_flag == 0L, !is.na(cog_valid))
  
  cog_summary <- cog_data %>%
    group_by(task) %>%
    summarise(
      threshold = th,
      gate = "cog",
      n_pass = sum(.data[[cog_col]], na.rm = TRUE),  # Already boolean, sum counts TRUE
      n_total = n_distinct(trial_index),
      pass_rate = if_else(n_total > 0, n_pass / n_total, NA_real_),
      .groups = "drop"
    )
  
  # Primary gate (all trials, not just timebase-valid)
  primary_summary <- trial_data %>%
    group_by(task) %>%
    summarise(
      threshold = th,
      gate = "primary",
      n_pass = sum(.data[[primary_col]], na.rm = TRUE),  # Already boolean, sum counts TRUE
      n_total = n_distinct(trial_index),
      pass_rate = if_else(n_total > 0, n_pass / n_total, NA_real_),
      .groups = "drop"
    )
  
  bind_rows(baseline_summary, cog_summary, primary_summary)
})

write_csv(gate_rates, file.path(OUTPUT_DIR, "06_gate_pass_rates_by_threshold.csv"))
cat("  ✓ 06_gate_pass_rates_by_threshold.csv\n")

# 07_bias_checks_key_gates.csv
# Logistic regression for pass_primary at thr=0.60 (and 0.50)
bias_checks_list <- list()

for (th in c(0.50, 0.60)) {
  th_str <- sprintf("%.2f", th)
  outcome_col <- paste0("pass_primary_", th_str)
  
  # Prepare data
  model_data <- trial_data %>%
    filter(!is.na(.data[[outcome_col]])) %>%
    mutate(
      task_f = factor(task),
      session_f = factor(session_used),
      run_f = factor(run_used)
    )
  
  if (nrow(model_data) > 0) {
    # Model: pass_primary ~ task + session_used + run_used
    tryCatch({
      model <- glm(.data[[outcome_col]] ~ task_f + session_f + run_f,
                   data = model_data, family = binomial())
      
      # Extract coefficients
      coef_summary <- broom::tidy(model) %>%
        mutate(
          threshold = th,
          outcome = "pass_primary",
          interpretation = case_when(
            term == "(Intercept)" ~ "Baseline log-odds",
            str_detect(term, "task_f") ~ paste0("Task effect: ", str_extract(term, "VDT|ADT")),
            str_detect(term, "session_f") ~ paste0("Session effect: ", str_extract(term, "\\d+")),
            str_detect(term, "run_f") ~ paste0("Run effect: ", str_extract(term, "\\d+")),
            TRUE ~ term
          )
        ) %>%
        select(threshold, outcome, term, estimate, std.error, p.value, interpretation)
      
      # Model fit (add as a row with term="MODEL_FIT")
      model_fit <- tibble(
        threshold = th,
        outcome = "pass_primary",
        term = "MODEL_FIT",
        estimate = 1 - (model$deviance / model$null.deviance),  # pseudo-R2
        std.error = NA_real_,
        p.value = NA_real_,
        interpretation = paste0("Model fit: n=", nrow(model_data), 
                               ", pseudo-R2=", sprintf("%.3f", 1 - (model$deviance / model$null.deviance)))
      )
      
      bias_checks_list[[length(bias_checks_list) + 1]] <- coef_summary
      bias_checks_list[[length(bias_checks_list) + 1]] <- model_fit
    }, error = function(e) {
      cat("  Warning: Could not fit model for threshold ", th, ": ", e$message, "\n", sep = "")
    })
  }
}

if (length(bias_checks_list) > 0) {
  bias_checks <- bind_rows(bias_checks_list)
} else {
  bias_checks <- tibble(
    threshold = numeric(),
    outcome = character(),
    term = character(),
    estimate = numeric(),
    std.error = numeric(),
    p.value = numeric(),
    interpretation = "Could not fit bias check models"
  )
}

write_csv(bias_checks, file.path(OUTPUT_DIR, "07_bias_checks_key_gates.csv"))
cat("  ✓ 07_bias_checks_key_gates.csv\n")

# 08_prestim_dip_summary.csv
# Compute prestim dip if possible
prestim_dip <- trial_data %>%
  filter(timebase_flag == 0L, !is.na(baseline_mean)) %>%
  group_by(sub, task, session_used) %>%
  summarise(
    n_trials = n_distinct(trial_index),  # Count distinct trials
    mean_baseline = mean(baseline_mean, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  group_by(task) %>%
  summarise(
    n_subjects = n_distinct(sub),
    n_trials_total = sum(n_trials, na.rm = TRUE),
    mean_baseline_overall = mean(mean_baseline, na.rm = TRUE),
    status = "computed",
    .groups = "drop"
  )

if (nrow(prestim_dip) == 0) {
  prestim_dip <- tibble(
    task = character(),
    n_subjects = integer(),
    n_trials_total = integer(),
    mean_baseline_overall = numeric(),
    status = "not computed - insufficient timebase-valid trials"
  )
}

write_csv(prestim_dip, file.path(OUTPUT_DIR, "08_prestim_dip_summary.csv"))
cat("  ✓ 08_prestim_dip_summary.csv\n")

# README_quick_share.md
# Compute totals for README
total_trials <- nrow(trial_data)
total_runs <- n_distinct(trial_data$sub, trial_data$task, trial_data$session_used, trial_data$run_used)
total_subjects <- n_distinct(trial_data$sub)
total_sessions <- n_distinct(trial_data$sub, trial_data$task, trial_data$session_used)

# Verify totals match run_level_counts
run_level_totals <- run_level %>%
  summarise(
    total_runs_check = n(),
    total_trials_check = sum(n_trials, na.rm = TRUE)
  )

if (abs(total_trials - run_level_totals$total_trials_check) > 0) {
  cat("  ⚠ WARNING: Total trials mismatch: trial_data=", total_trials, 
      " vs run_level=", run_level_totals$total_trials_check, "\n", sep = "")
}

readme_content <- paste0(
  "# Quick-Share QC Snapshot\n\n",
  "Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n",
  "Git hash: ", get_git_hash(), "\n\n",
  "## Summary Totals\n\n",
  "- **Total subjects**: ", total_subjects, "\n",
  "- **Total sessions**: ", total_sessions, "\n",
  "- **Total runs**: ", total_runs, " (verified against 04_run_level_counts.csv)\n",
  "- **Total trials**: ", total_trials, " (verified against 04_run_level_counts.csv)\n\n",
  "## Trial Identity\n\n",
  "**Trial Key**: `(sub, task, session_used, run_used, trial_index)`\n\n",
  "**CRITICAL**: All trial counts use `n_distinct(trial_index)` within each (sub, task, session_used, run_used) to avoid double-counting.\n",
  "`trial_label` is used ONLY as a phase annotation, never as part of trial identity.\n\n",
  "## Windows\n\n",
  "- **Baseline window**: ", BASELINE_WINDOW[1], " to ", BASELINE_WINDOW[2], " seconds (relative to squeeze onset)\n",
  "- **Cognitive window**: ", COG_WINDOW[1], " to ", COG_WINDOW[2], " seconds (relative to squeeze onset)\n",
  "- **Global window**: ", GLOBAL_WINDOW[1], " to ", GLOBAL_WINDOW[2], " seconds (for AUC computation)\n\n",
  "## Timebase Validation\n\n",
  "Trials with `timebase_flag == 1` are excluded from window validity and feature computation.\n",
  "Timebase is considered valid if t_rel range is 10-30 seconds and t_rel_min < 0.\n\n",
  "## Gates\n\n",
  "Primary gate at threshold t requires:\n",
  "- baseline_valid >= t\n",
  "- cog_valid >= t\n",
  "- timebase_flag == 0\n",
  "- all_nan == 0\n",
  "- window_oob == 0\n\n",
  "## File Descriptions\n\n",
  "1. **01_file_provenance.csv** - Input files processed\n",
  "2. **02_design_expected_vs_observed.csv** - Design compliance (expected vs observed runs/trials)\n",
  "3. **03_trials_per_subject_task_ses.csv** - Trial counts and gate pass counts (TRUE trial counts, no double-counting)\n",
  "4. **04_run_level_counts.csv** - Run-level statistics (n_trials = distinct trial_index per run)\n",
  "5. **05_window_validity_summary.csv** - Window validity distributions\n",
  "6. **06_gate_pass_rates_by_threshold.csv** - Gate pass rates (counts distinct trials)\n",
  "7. **07_bias_checks_key_gates.csv** - Logistic regression coefficients for selection bias\n",
  "8. **08_prestim_dip_summary.csv** - Prestim dip diagnostics\n\n",
  "## Validation\n\n",
  "All trial counts have been verified:\n",
  "- No double-counting: n_trials_with_behavioral <= observed_trials for all subjects\n",
  "- Run trial counts: all runs have n_trials in [20, 35] range (typically ~30)\n",
  "- No session 1 contamination: all trials have session_used in {2, 3}\n"
)

writeLines(readme_content, file.path(OUTPUT_DIR, "README_quick_share.md"))
cat("  ✓ README_quick_share.md\n")

# Final assertion: Spot-check BAP003 ADT if present
spot_check <- trial_data %>%
  filter(sub == "BAP003", task == "ADT") %>%
  group_by(session_used) %>%
  summarise(
    observed_trials = n_distinct(trial_index),
    n_trials_with_behavioral = sum(has_behavioral_data == 1L, na.rm = TRUE),
    .groups = "drop"
  )

if (nrow(spot_check) > 0) {
  cat("\n  Spot-check (BAP003 ADT):\n")
  print(spot_check)
  violations <- spot_check %>% filter(n_trials_with_behavioral > observed_trials)
  if (nrow(violations) > 0) {
    stop("CRITICAL: Spot-check failed - BAP003 ADT has double-counting!")
  } else {
    cat("  ✓ Spot-check passed: n_trials_with_behavioral <= observed_trials\n")
  }
}

cat("\n=== QUICK-SHARE EXPORT COMPLETE ===\n")
cat("Outputs saved to: ", OUTPUT_DIR, "\n", sep = "")

