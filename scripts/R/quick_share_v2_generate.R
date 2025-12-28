#!/usr/bin/env Rscript
# ============================================================================
# Quick-Share v2 Export - Trial-Level Aggregation
# ============================================================================
# Processes sample-level flat files into trial-level summaries
# Generates <= 8 CSVs + README for sharing
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

cat("=== QUICK-SHARE v2 EXPORT ===\n\n")

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

# Task timing constants
GRIP_DURATION <- 3.0
BLANK_DURATION <- 0.25
FIX_DURATION <- 0.50
GABOR_DUR <- 0.10
ISI_DURATION <- 0.50
TARGET_ONSET <- GRIP_DURATION + BLANK_DURATION + FIX_DURATION + GABOR_DUR + ISI_DURATION  # 4.35s

# Windows (relative to squeeze onset at t=0)
BASELINE_WIN <- c(-0.50, 0.00)
TOTAL_AUC_WIN <- c(0.00, TARGET_ONSET + 1.30)  # 0.00 to 5.65
COG_WIN <- c(TARGET_ONSET + 0.30, TARGET_ONSET + 1.30)  # 4.65 to 5.65

# Gate thresholds
GATE_THRESHOLDS <- c(50, 60, 70)

# Expected design
EXPECTED_RUNS_PER_SESSION <- 5L
EXPECTED_TRIALS_PER_RUN <- 30L
EXPECTED_TRIALS_PER_SESSION <- EXPECTED_RUNS_PER_SESSION * EXPECTED_TRIALS_PER_RUN

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

trapezoidal_auc <- function(x, y) {
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

window_validity_pct <- function(pupil_vec, t_rel_vec, t_start, t_end) {
  in_window <- !is.na(t_rel_vec) & t_rel_vec >= t_start & t_rel_vec <= t_end
  if (!any(in_window, na.rm = TRUE)) return(NA_real_)
  pupil_in_window <- pupil_vec[in_window]
  100 * mean(!is.na(pupil_in_window) & is.finite(pupil_in_window), na.rm = TRUE)
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

flat_files <- list.files(PROCESSED_DIR, pattern = "_(ADT|VDT)_flat\\.csv$", 
                         full.names = TRUE, recursive = TRUE)
if (length(flat_files) == 0) {
  stop("No *_ADT_flat.csv or *_VDT_flat.csv files found in ", PROCESSED_DIR)
}

cat("  Found ", length(flat_files), " flat files\n", sep = "")

# Process files one at a time
trial_data_list <- list()

for (i in seq_along(flat_files)) {
  if (i %% 50 == 0) cat("    Progress: ", i, "/", length(flat_files), "\n", sep = "")
  
  fn <- basename(flat_files[i])
  
  # Try to read with fread, handling missing columns gracefully
  tryCatch({
    # First, peek at column names
    sample_df <- fread(flat_files[i], nrows = 10)
    available_cols <- names(sample_df)
    
    # Define columns we want
    desired_cols <- c("sub", "task", "ses", "run", "session_used", "run_used", 
                     "trial_index", "trial_in_run_raw", "pupil", "time", 
                     "trial_label", "has_behavioral_data", "qc_fail_baseline", 
                     "qc_fail_overall", "overall_quality")
    
    cols_to_read <- intersect(desired_cols, available_cols)
    
    if (length(cols_to_read) < 5) {
      cat("    Warning: ", fn, " has too few expected columns, skipping\n", sep = "")
      next
    }
    
    # Read file
    df <- fread(flat_files[i], select = cols_to_read,
                colClasses = list(character = c("sub", "task", "trial_label"),
                                 integer = c("ses", "run", "session_used", "run_used", 
                                            "trial_index", "trial_in_run_raw",
                                            "has_behavioral_data", "qc_fail_baseline", 
                                            "qc_fail_overall"),
                                 numeric = c("pupil", "time", "overall_quality")))
    
    # Normalize columns
    df <- df %>%
      mutate(
        sub = as.character(sub),
        task = as.character(task),
        # Handle session key
        ses_key = if ("session_used" %in% names(.)) {
          as.integer(session_used)
        } else if ("ses" %in% names(.)) {
          as.integer(ses)
        } else {
          NA_integer_
        },
        # Handle run key
        run_key = if ("run_used" %in% names(.)) {
          as.integer(run_used)
        } else if ("run" %in% names(.)) {
          as.integer(run)
        } else {
          NA_integer_
        },
        trial_index = as.integer(trial_index),
        trial_in_run_raw = if ("trial_in_run_raw" %in% names(.)) {
          as.integer(trial_in_run_raw)
        } else {
          NA_integer_
        },
        pupil = as.numeric(pupil),
        time = as.numeric(time),
        has_behavioral_data = if ("has_behavioral_data" %in% names(.)) {
          as.integer(has_behavioral_data)
        } else {
          0L
        },
        qc_fail_baseline = if ("qc_fail_baseline" %in% names(.)) {
          as.integer(qc_fail_baseline)
        } else {
          NA_integer_
        },
        qc_fail_overall = if ("qc_fail_overall" %in% names(.)) {
          as.integer(qc_fail_overall)
        } else {
          NA_integer_
        },
        overall_quality = if ("overall_quality" %in% names(.)) {
          as.numeric(overall_quality)
        } else {
          NA_real_
        }
      ) %>%
      filter(
        !is.na(sub), !is.na(task), 
        !is.na(ses_key), !is.na(run_key), !is.na(trial_index),
        ses_key %in% c(2L, 3L),  # Only sessions 2-3
        task %in% c("ADT", "VDT"),
        !is.na(pupil) | !is.na(time)  # Need at least one
      )
    
    if (nrow(df) == 0) next
    
    # Compute trial-level metrics
    # For each trial, create t_rel from sample index
    df_with_trel <- df %>%
      group_by(sub, task, ses_key, run_key, trial_index) %>%
      arrange(time) %>%
      mutate(
        sample_i = row_number(),
        n_samples = n(),
        # Compute t_rel: window is [-3, +10.7] = 13.7s total
        dt = 13.7 / (n_samples - 1),
        t_rel = -3 + (sample_i - 1) * dt
      ) %>%
      ungroup()
    
    # Compute trial-level summaries
    trial_metrics <- df_with_trel %>%
      group_by(sub, task, ses_key, run_key, trial_index) %>%
      summarise(
        n_samples = first(n_samples),
        trial_in_run_raw = first(trial_in_run_raw[!is.na(trial_in_run_raw)]),
        has_behavioral_data = any(has_behavioral_data == 1L, na.rm = TRUE),
        qc_fail_baseline = if (any(!is.na(qc_fail_baseline))) {
          max(qc_fail_baseline, na.rm = TRUE)
        } else NA_integer_,
        qc_fail_overall = if (any(!is.na(qc_fail_overall))) {
          max(qc_fail_overall, na.rm = TRUE)
        } else NA_integer_,
        overall_quality = first(overall_quality[!is.na(overall_quality)]),
        
        # Window validities
        pct_non_nan_baseline = window_validity_pct(pupil, t_rel, BASELINE_WIN[1], BASELINE_WIN[2]),
        pct_non_nan_total = window_validity_pct(pupil, t_rel, TOTAL_AUC_WIN[1], TOTAL_AUC_WIN[2]),
        pct_non_nan_cog = window_validity_pct(pupil, t_rel, COG_WIN[1], COG_WIN[2]),
        
        # Baseline mean
        baseline_mean = window_mean(pupil, t_rel, BASELINE_WIN[1], BASELINE_WIN[2]),
        
        # AUCs (baseline-corrected) - compute from full vectors
        total_auc = {
          bm <- baseline_mean[1]
          if (!is.na(bm)) {
            pupil_vec <- pupil
            t_rel_vec <- t_rel
            pupil_bc <- pupil_vec - bm
            in_window <- !is.na(t_rel_vec) & t_rel_vec >= TOTAL_AUC_WIN[1] & t_rel_vec <= TOTAL_AUC_WIN[2]
            if (sum(in_window, na.rm = TRUE) > 1) {
              trapezoidal_auc(t_rel_vec[in_window], pupil_bc[in_window])
            } else NA_real_
          } else NA_real_
        },
        
        cog_auc = {
          bm <- baseline_mean[1]
          if (!is.na(bm)) {
            pupil_vec <- pupil
            t_rel_vec <- t_rel
            pupil_bc <- pupil_vec - bm
            in_cog <- !is.na(t_rel_vec) & t_rel_vec >= COG_WIN[1] & t_rel_vec <= COG_WIN[2]
            if (sum(in_cog, na.rm = TRUE) > 1) {
              trapezoidal_auc(t_rel_vec[in_cog], pupil_bc[in_cog])
            } else NA_real_
          } else NA_real_
        },
        
        .groups = "drop"
      )
    
    rm(df_with_trel)
    
    trial_data_list[[i]] <- trial_metrics
    rm(df, trial_metrics)
    gc(verbose = FALSE)
    
  }, error = function(e) {
    cat("    Error processing ", fn, ": ", e$message, "\n", sep = "")
  })
}

# Bind all trials
trial_data <- bind_rows(trial_data_list)
rm(trial_data_list)
gc(verbose = FALSE)

# Deduplicate (one row per trial)
trial_data <- trial_data %>%
  group_by(sub, task, ses_key, run_key, trial_index) %>%
  slice(1) %>%
  ungroup()

cat("  ✓ Loaded ", nrow(trial_data), " trials (deduplicated)\n", sep = "")

# Validation: Check for all zeros/NaN
if (nrow(trial_data) == 0) {
  stop("CRITICAL ERROR: No trials loaded. Check file paths and column names.")
}

if (all(is.na(trial_data$pct_non_nan_baseline)) && 
    all(is.na(trial_data$pct_non_nan_total)) && 
    all(is.na(trial_data$pct_non_nan_cog))) {
  stop("CRITICAL ERROR: All window validity metrics are NaN. Check t_rel computation.")
}

# ----------------------------------------------------------------------------
# STEP 2: Compute gates
# ----------------------------------------------------------------------------

cat("\nSTEP 2: Computing gates...\n")

for (th in GATE_THRESHOLDS) {
  col_name <- paste0("pass_t", sprintf("%03d", th))
  trial_data[[col_name]] <- 
    !is.na(trial_data$pct_non_nan_baseline) & trial_data$pct_non_nan_baseline >= th &
    !is.na(trial_data$pct_non_nan_cog) & trial_data$pct_non_nan_cog >= th &
    !is.na(trial_data$pct_non_nan_total) & trial_data$pct_non_nan_total >= th &
    is.finite(trial_data$pct_non_nan_baseline) &
    is.finite(trial_data$pct_non_nan_cog) &
    is.finite(trial_data$pct_non_nan_total)
}

cat("  ✓ Gates computed\n")

# Validation: At least one gate must have some passes
total_passes <- sum(trial_data$pass_t060, na.rm = TRUE)
if (total_passes == 0) {
  stop("CRITICAL ERROR: Zero trials pass gate at threshold 60. Check window validity computation.")
}

# ----------------------------------------------------------------------------
# STEP 3: Generate outputs
# ----------------------------------------------------------------------------

cat("\nSTEP 3: Generating outputs...\n")

# 01_file_provenance.csv
file_provenance <- map_dfr(flat_files, function(f) {
  info <- file.info(f)
  tibble(
    filename = basename(f),
    filepath = f,
    size_bytes = info$size,
    size_MB = round(info$size / 1024^2, 3),
    modified_time = format(info$mtime, "%Y-%m-%d %H:%M:%S")
  )
}) %>%
  bind_rows(
    tibble(
      filename = "SUMMARY",
      filepath = NA_character_,
      size_bytes = sum(.$size_bytes, na.rm = TRUE),
      size_MB = sum(.$size_MB, na.rm = TRUE),
      modified_time = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    )
  ) %>%
  mutate(git_hash = get_git_hash())

write_csv(file_provenance, file.path(OUTPUT_DIR, "01_file_provenance.csv"))
cat("  ✓ 01_file_provenance.csv\n")

# 02_design_expected_vs_observed.csv
design_table <- trial_data %>%
  group_by(sub, task) %>%
  summarise(
    expected_runs = EXPECTED_RUNS_PER_SESSION * 2,  # 2 sessions
    expected_trials = EXPECTED_TRIALS_PER_SESSION * 2,  # 2 sessions
    observed_runs = n_distinct(paste(ses_key, run_key)),
    observed_trials = n_distinct(paste(run_key, trial_index)),
    session_used = as.integer(names(sort(table(ses_key), decreasing = TRUE))[1]),  # mode
    missing_runs = expected_runs - observed_runs,
    missing_trials = expected_trials - observed_trials,
    .groups = "drop"
  )

write_csv(design_table, file.path(OUTPUT_DIR, "02_design_expected_vs_observed.csv"))
cat("  ✓ 02_design_expected_vs_observed.csv\n")

# 03_trials_per_subject_task_ses.csv
trials_per_subject <- trial_data %>%
  group_by(sub, task, ses_key) %>%
  summarise(
    n_runs = n_distinct(run_key),
    n_trials = n_distinct(trial_index),
    mean_pct_non_nan_baseline = mean(pct_non_nan_baseline, na.rm = TRUE),
    mean_pct_non_nan_total = mean(pct_non_nan_total, na.rm = TRUE),
    mean_pct_non_nan_cog = mean(pct_non_nan_cog, na.rm = TRUE),
    n_pass_t050 = sum(pass_t050, na.rm = TRUE),
    n_pass_t060 = sum(pass_t060, na.rm = TRUE),
    n_pass_t070 = sum(pass_t070, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(trials_per_subject, file.path(OUTPUT_DIR, "03_trials_per_subject_task_ses.csv"))
cat("  ✓ 03_trials_per_subject_task_ses.csv\n")

# 04_run_level_counts.csv
run_level <- trial_data %>%
  group_by(sub, task, ses_key, run_key) %>%
  summarise(
    n_trials = n_distinct(trial_index),
    n_trials_pass_t050 = sum(pass_t050, na.rm = TRUE),
    n_trials_pass_t060 = sum(pass_t060, na.rm = TRUE),
    n_trials_pass_t070 = sum(pass_t070, na.rm = TRUE),
    min_pct_non_nan_total = min(pct_non_nan_total, na.rm = TRUE),
    median_pct_non_nan_total = median(pct_non_nan_total, na.rm = TRUE),
    max_pct_non_nan_total = max(pct_non_nan_total, na.rm = TRUE),
    .groups = "drop"
  )

# Check for runs with unusual trial counts
outlier_runs <- run_level %>%
  filter(n_trials != EXPECTED_TRIALS_PER_RUN)

if (nrow(outlier_runs) > 0) {
  cat("  ⚠ WARNING: Found ", nrow(outlier_runs), " runs with n_trials != ", 
      EXPECTED_TRIALS_PER_RUN, ":\n", sep = "")
  print(head(outlier_runs %>% select(sub, task, ses_key, run_key, n_trials), 10))
}

write_csv(run_level, file.path(OUTPUT_DIR, "04_run_level_counts.csv"))
cat("  ✓ 04_run_level_counts.csv\n")

# 05_window_validity_summary.csv
window_summary <- trial_data %>%
  group_by(task) %>%
  summarise(
    n_trials = n_distinct(trial_index),
    baseline_mean = mean(pct_non_nan_baseline, na.rm = TRUE),
    baseline_median = median(pct_non_nan_baseline, na.rm = TRUE),
    baseline_p10 = quantile(pct_non_nan_baseline, 0.10, na.rm = TRUE, names = FALSE),
    baseline_p25 = quantile(pct_non_nan_baseline, 0.25, na.rm = TRUE, names = FALSE),
    baseline_p75 = quantile(pct_non_nan_baseline, 0.75, na.rm = TRUE, names = FALSE),
    baseline_p90 = quantile(pct_non_nan_baseline, 0.90, na.rm = TRUE, names = FALSE),
    total_mean = mean(pct_non_nan_total, na.rm = TRUE),
    total_median = median(pct_non_nan_total, na.rm = TRUE),
    total_p10 = quantile(pct_non_nan_total, 0.10, na.rm = TRUE, names = FALSE),
    total_p25 = quantile(pct_non_nan_total, 0.25, na.rm = TRUE, names = FALSE),
    total_p75 = quantile(pct_non_nan_total, 0.75, na.rm = TRUE, names = FALSE),
    total_p90 = quantile(pct_non_nan_total, 0.90, na.rm = TRUE, names = FALSE),
    cog_mean = mean(pct_non_nan_cog, na.rm = TRUE),
    cog_median = median(pct_non_nan_cog, na.rm = TRUE),
    cog_p10 = quantile(pct_non_nan_cog, 0.10, na.rm = TRUE, names = FALSE),
    cog_p25 = quantile(pct_non_nan_cog, 0.25, na.rm = TRUE, names = FALSE),
    cog_p75 = quantile(pct_non_nan_cog, 0.75, na.rm = TRUE, names = FALSE),
    cog_p90 = quantile(pct_non_nan_cog, 0.90, na.rm = TRUE, names = FALSE),
    .groups = "drop"
  )

# Validation: No NaNs unless task has zero rows
if (any(is.na(window_summary$baseline_mean) & window_summary$n_trials > 0)) {
  stop("CRITICAL ERROR: Window validity summary has NaNs for tasks with trials.")
}

write_csv(window_summary, file.path(OUTPUT_DIR, "05_window_validity_summary.csv"))
cat("  ✓ 05_window_validity_summary.csv\n")

# 06_gate_pass_rates_by_threshold.csv
gate_rates <- map_dfr(GATE_THRESHOLDS, function(th) {
  col_name <- paste0("pass_t", sprintf("%03d", th))
  
  trial_data %>%
    group_by(task) %>%
    summarise(
      threshold = th,
      n_trials_total = n_distinct(trial_index),
      n_trials_pass = sum(.data[[col_name]], na.rm = TRUE),
      pass_rate = if_else(n_trials_total > 0, n_trials_pass / n_trials_total, NA_real_),
      .groups = "drop"
    )
})

# Validation: Must be nonzero for at least one threshold
if (all(gate_rates$n_trials_pass == 0)) {
  stop("CRITICAL ERROR: All gate pass rates are zero. Check gate computation logic.")
}

write_csv(gate_rates, file.path(OUTPUT_DIR, "06_gate_pass_rates_by_threshold.csv"))
cat("  ✓ 06_gate_pass_rates_by_threshold.csv\n")

# 07_bias_checks_key_gates.csv
# Check if we have behavioral data or can merge
has_behavioral <- any(trial_data$has_behavioral_data == 1L, na.rm = TRUE)

if (has_behavioral) {
  # Run logistic regression
  bias_checks_list <- list()
  
  for (th in c(50, 60)) {
    col_name <- paste0("pass_t", sprintf("%03d", th))
    
    model_data <- trial_data %>%
      filter(!is.na(.data[[col_name]])) %>%
      mutate(
        task_f = factor(task),
        ses_f = factor(ses_key)
      )
    
    if (nrow(model_data) > 0) {
      tryCatch({
        model <- glm(.data[[col_name]] ~ task_f + ses_f,
                     data = model_data, family = binomial())
        
        coef_summary <- broom::tidy(model) %>%
          mutate(
            threshold = th,
            outcome = "pass_t",
            interpretation = case_when(
              term == "(Intercept)" ~ "Baseline log-odds",
              str_detect(term, "task_f") ~ paste0("Task effect: ", str_extract(term, "VDT|ADT")),
              str_detect(term, "ses_f") ~ paste0("Session effect: ", str_extract(term, "\\d+")),
              TRUE ~ term
            )
          ) %>%
          select(threshold, outcome, term, estimate, std.error, p.value, interpretation)
        
        model_fit <- tibble(
          threshold = th,
          outcome = "pass_t",
          term = "MODEL_FIT",
          estimate = 1 - (model$deviance / model$null.deviance),
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
} else {
  bias_checks <- tibble(
    threshold = NA_integer_,
    outcome = "pass_t",
    term = "BEHAVIOR_NOT_MERGED",
    estimate = NA_real_,
    std.error = NA_real_,
    p.value = NA_real_,
    interpretation = "Behavioral data not merged yet. Cannot compute bias checks until behavioral merge is available."
  )
}

write_csv(bias_checks, file.path(OUTPUT_DIR, "07_bias_checks_key_gates.csv"))
cat("  ✓ 07_bias_checks_key_gates.csv\n")

# 08_prestim_dip_summary.csv
prestim_dip <- trial_data %>%
  group_by(task) %>%
  summarise(
    n_trials = n_distinct(trial_index),
    frac_baseline_lt50 = mean(pct_non_nan_baseline < 50, na.rm = TRUE),
    frac_baseline_lt60 = mean(pct_non_nan_baseline < 60, na.rm = TRUE),
    baseline_mean_dist_mean = mean(baseline_mean, na.rm = TRUE),
    baseline_mean_dist_median = median(baseline_mean, na.rm = TRUE),
    baseline_mean_dist_p10 = quantile(baseline_mean, 0.10, na.rm = TRUE, names = FALSE),
    baseline_mean_dist_p90 = quantile(baseline_mean, 0.90, na.rm = TRUE, names = FALSE),
    baseline_mean_missing_pct = 100 * mean(is.na(baseline_mean)),
    .groups = "drop"
  )

write_csv(prestim_dip, file.path(OUTPUT_DIR, "08_prestim_dip_summary.csv"))
cat("  ✓ 08_prestim_dip_summary.csv\n")

# README_quick_share_v2.md
readme_content <- paste0(
  "# Quick-Share v2 QC Snapshot\n\n",
  "Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n",
  "Git hash: ", get_git_hash(), "\n\n",
  "## Summary Totals\n\n",
  "- **Total subjects**: ", n_distinct(trial_data$sub), "\n",
  "- **Total trials**: ", nrow(trial_data), "\n",
  "- **Total runs**: ", n_distinct(trial_data$sub, trial_data$task, trial_data$ses_key, trial_data$run_key), "\n\n",
  "## Trial Identity\n\n",
  "**Trial Key**: `(sub, task, ses_key, run_key, trial_index)`\n\n",
  "- `ses_key` = `session_used` if available, else `ses`\n",
  "- `run_key` = `run_used` if available, else `run`\n",
  "- `trial_index` is the true trial ID within run (NOT `trial_in_run_raw`)\n\n",
  "**CRITICAL**: All trial counts use `n_distinct(trial_index)` within each (sub, task, ses_key, run_key).\n",
  "Never count samples as trials.\n\n",
  "## Windows (Relative to Squeeze Onset at t=0)\n\n",
  "- **Baseline window**: ", BASELINE_WIN[1], " to ", BASELINE_WIN[2], " seconds\n",
  "- **Total AUC window**: ", TOTAL_AUC_WIN[1], " to ", TOTAL_AUC_WIN[2], " seconds\n",
  "- **Cognitive window**: ", COG_WIN[1], " to ", COG_WIN[2], " seconds (post-target)\n\n",
  "**Time computation**: `t_rel = -3 + (sample_i - 1) * dt` where `dt = 13.7 / (n_samples - 1)`\n",
  "(Window spans [-3, +10.7] = 13.7s total)\n\n",
  "## Gates\n\n",
  "Gate pass at threshold t requires:\n",
  "- `pct_non_nan_baseline >= t`\n",
  "- `pct_non_nan_cog >= t`\n",
  "- `pct_non_nan_total >= t`\n\n",
  "Thresholds: 50, 60, 70 (percentages)\n\n",
  "## File Descriptions\n\n",
  "1. **01_file_provenance.csv** - Input files processed, sizes, git hash\n",
  "2. **02_design_expected_vs_observed.csv** - Design compliance (expected vs observed runs/trials)\n",
  "3. **03_trials_per_subject_task_ses.csv** - Trial counts and gate pass counts per subject/task/session\n",
  "4. **04_run_level_counts.csv** - Run-level statistics (n_trials, pass counts, validity)\n",
  "5. **05_window_validity_summary.csv** - Window validity distributions (mean/median/percentiles)\n",
  "6. **06_gate_pass_rates_by_threshold.csv** - Gate pass rates by task and threshold\n",
  "7. **07_bias_checks_key_gates.csv** - Logistic regression coefficients for selection bias (or 'behavior not merged')\n",
  "8. **08_prestim_dip_summary.csv** - Prestim/baseline failure diagnostics\n"
)

writeLines(readme_content, file.path(OUTPUT_DIR, "README_quick_share_v2.md"))
cat("  ✓ README_quick_share_v2.md\n")

cat("\n=== QUICK-SHARE v2 EXPORT COMPLETE ===\n")
cat("Outputs saved to: ", OUTPUT_DIR, "\n", sep = "")

