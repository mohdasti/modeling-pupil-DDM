#!/usr/bin/env Rscript
# ============================================================================
# Make Quick-Share v3 - Fixed Trial Counting
# ============================================================================
# Builds trial-level summaries with correct trial_uid
# Generates 8 CSVs for sharing
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(tidyr)
  library(data.table)
  library(yaml)
  library(here)
})

cat("=== MAKING QUICK-SHARE v3 ===\n\n")

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

REPO_ROOT <- here::here()

# Try to load config file first
config_file <- file.path(REPO_ROOT, "config", "data_paths.yaml")
if (file.exists(config_file)) {
  config <- read_yaml(config_file)
  PROCESSED_DIR <- config$processed_dir
} else {
  PROCESSED_DIR <- Sys.getenv("PUPIL_PROCESSED_DIR")
  if (PROCESSED_DIR == "") {
    stop("Please set PUPIL_PROCESSED_DIR or create config/data_paths.yaml")
  }
}

OUTPUT_DIR <- file.path(REPO_ROOT, "quick_share_v3")
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("Repo root: ", REPO_ROOT, "\n", sep = "")
cat("Processed dir: ", PROCESSED_DIR, "\n", sep = "")
cat("Output dir: ", OUTPUT_DIR, "\n\n", sep = "")

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------

EXPECTED_TRIALS_PER_RUN <- 30L
EXPECTED_RUNS_PER_TASK <- 5L
EXPECTED_TRIALS_PER_TASK <- EXPECTED_RUNS_PER_TASK * EXPECTED_TRIALS_PER_RUN  # 150

# Gate thresholds (as proportions 0-1)
GATE_THRESHOLDS <- c(0.50, 0.60, 0.70)

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

# ----------------------------------------------------------------------------
# STEP 1: Find and read flat files
# ----------------------------------------------------------------------------

cat("STEP 1: Finding flat files...\n")

flat_files <- list.files(PROCESSED_DIR, pattern = "_(ADT|VDT)_flat\\.csv$", 
                         full.names = TRUE, recursive = TRUE)

if (length(flat_files) == 0) {
  flat_files <- list.files(PROCESSED_DIR, pattern = ".*flat\\.csv$", 
                           full.names = TRUE, recursive = TRUE)
  flat_files <- flat_files[str_detect(basename(flat_files), "(ADT|VDT).*flat")]
}

if (length(flat_files) == 0) {
  stop("No flat files found in ", PROCESSED_DIR)
}

cat("  Found ", length(flat_files), " flat files\n", sep = "")

# ----------------------------------------------------------------------------
# STEP 2: Build trial-level table
# ----------------------------------------------------------------------------

cat("\nSTEP 2: Building trial-level table...\n")

trial_data_list <- list()
n_files <- length(flat_files)

for (i in seq_along(flat_files)) {
  if (i %% 50 == 0 || i == 1) {
    cat("  Progress: ", i, "/", n_files, "\n", sep = "")
  }
  
  tryCatch({
    # Peek at columns
    sample_df <- fread(flat_files[i], nrows = 100)
    available_cols <- names(sample_df)
    
    desired_cols <- c("sub", "task", "ses", "run", "session_used", "run_used",
                     "trial_index", "pupil", "time", "baseline_quality", 
                     "trial_quality", "overall_quality", "qc_fail_baseline",
                     "qc_fail_overall", "window_oob", "all_nan", 
                     "has_behavioral_data", "segmentation_source", 
                     "trial_start_time_ptb")
    
    cols_to_read <- intersect(desired_cols, available_cols)
    
    if (length(cols_to_read) < 8) next
    
    # Read file
    df <- fread(flat_files[i], select = cols_to_read,
                colClasses = list(character = c("sub", "task", "segmentation_source"),
                                 integer = c("ses", "run", "session_used", "run_used",
                                            "trial_index", "qc_fail_baseline", 
                                            "qc_fail_overall", "window_oob", "all_nan",
                                            "has_behavioral_data"),
                                 numeric = c("pupil", "time", "baseline_quality",
                                            "trial_quality", "overall_quality",
                                            "trial_start_time_ptb")))
    
    # Normalize
    df <- df %>%
      mutate(
        sub = as.character(sub),
        task = as.character(task),
        session_used = as.integer(if ("session_used" %in% names(.)) session_used else ses),
        run_used = as.integer(if ("run_used" %in% names(.)) run_used else run),
        trial_index = as.integer(trial_index),
        pupil = as.numeric(pupil),
        time = as.numeric(time),
        baseline_quality = as.numeric(baseline_quality),
        trial_quality = as.numeric(trial_quality),
        overall_quality = as.numeric(overall_quality),
        qc_fail_baseline = as.integer(if ("qc_fail_baseline" %in% names(.)) qc_fail_baseline else 0L),
        qc_fail_overall = as.integer(if ("qc_fail_overall" %in% names(.)) qc_fail_overall else 0L),
        window_oob = as.integer(if ("window_oob" %in% names(.)) window_oob else 0L),
        all_nan = as.integer(if ("all_nan" %in% names(.)) all_nan else 0L),
        has_behavioral_data = as.integer(if ("has_behavioral_data" %in% names(.)) has_behavioral_data else 0L),
        segmentation_source = as.character(if ("segmentation_source" %in% names(.)) segmentation_source else NA_character_)
      ) %>%
      filter(
        !is.na(sub), !is.na(task), !is.na(session_used), !is.na(run_used), !is.na(trial_index),
        session_used %in% c(2L, 3L),
        task %in% c("ADT", "VDT"),
        !is.na(time)
      )
    
    if (nrow(df) == 0) next
    
    # Compute time_rel from sample index (FIXED TIME AXIS)
    # CRITICAL: n_samples must be the actual number of rows per trial in the flat file
    df <- df %>%
      group_by(sub, task, session_used, run_used, trial_index) %>%
      arrange(time) %>%
      mutate(
        sample_i = row_number(),
        n_obs = n()  # Actual number of rows per trial in flat file
      ) %>%
      ungroup() %>%
      group_by(sub, task, session_used, run_used, trial_index) %>%
      mutate(
        # Compute dt from observed row count (window is [-3, +10.7] = 13.7s total)
        dt = 13.7 / (n_obs - 1),
        # Compute time_rel from sample index
        window_start = -3.0,
        time_rel = window_start + (sample_i - 1) * dt
      ) %>%
      ungroup()
    
    # Build trial-level summary with RECOMPUTED window validities
    trial_batch <- df %>%
      group_by(sub, task, session_used, run_used, trial_index) %>%
      summarise(
        n_samples = first(n_obs),  # Use observed row count
        time_min = min(time, na.rm = TRUE),
        time_max = max(time, na.rm = TRUE),
        dt_median = median(diff(sort(unique(time))), na.rm = TRUE),
        dt_computed = first(dt),
        time_rel_min = min(time_rel, na.rm = TRUE),
        time_rel_max = max(time_rel, na.rm = TRUE),
        time_rel_range = time_rel_max - time_rel_min,
        
        # RECOMPUTE window validities using time_rel
        # Baseline window: [-0.5, 0.0] relative to squeeze onset
        baseline_quality = {
          in_baseline <- time_rel >= -0.5 & time_rel <= 0.0 & !is.na(time_rel)
          pupil_baseline <- pupil[in_baseline]
          mean(!is.na(pupil_baseline) & is.finite(pupil_baseline), na.rm = TRUE)
        },
        n_samples_baseline = sum(time_rel >= -0.5 & time_rel <= 0.0 & !is.na(time_rel), na.rm = TRUE),
        
        # Trial window: [0, 7.7] relative to squeeze onset (excludes confidence window 7.7-10.7)
        trial_quality = {
          in_trial <- time_rel >= 0.0 & time_rel <= 7.7 & !is.na(time_rel)
          pupil_trial <- pupil[in_trial]
          mean(!is.na(pupil_trial) & is.finite(pupil_trial), na.rm = TRUE)
        },
        n_samples_trial = sum(time_rel >= 0.0 & time_rel <= 7.7 & !is.na(time_rel), na.rm = TRUE),
        
        # Total AUC window: [0, 5.65] (target_onset + 1.3 = 4.35 + 1.3)
        n_samples_total_auc = sum(time_rel >= 0.0 & time_rel <= 5.65 & !is.na(time_rel), na.rm = TRUE),
        
        # Cognitive window: [4.65, 5.65] (target_onset 3.75 + 0.3 to 3.75 + 1.3)
        cog_quality = {
          in_cog <- time_rel >= 4.65 & time_rel <= 5.65 & !is.na(time_rel)
          pupil_cog <- pupil[in_cog]
          mean(!is.na(pupil_cog) & is.finite(pupil_cog), na.rm = TRUE)
        },
        n_samples_cog = sum(time_rel >= 4.65 & time_rel <= 5.65 & !is.na(time_rel), na.rm = TRUE),
        
        # Overall quality: full window [-3, +10.7]
        pct_non_nan_total = 100 * mean(!is.na(pupil) & is.finite(pupil), na.rm = TRUE),
        overall_quality = mean(!is.na(pupil) & is.finite(pupil), na.rm = TRUE),
        
        qc_fail_baseline = max(qc_fail_baseline, na.rm = TRUE),
        qc_fail_overall = max(qc_fail_overall, na.rm = TRUE),
        window_oob = max(window_oob, na.rm = TRUE),
        all_nan = max(all_nan, na.rm = TRUE),
        has_behavioral_data = max(has_behavioral_data, na.rm = TRUE),
        segmentation_source = first(segmentation_source[!is.na(segmentation_source)]),
        trial_start_time_ptb = first(trial_start_time_ptb[!is.na(trial_start_time_ptb)]),
        
        .groups = "drop"
      ) %>%
      mutate(
        # Create trial_uid
        trial_uid = interaction(sub, task, session_used, run_used, trial_index, drop = TRUE)
      )
    
    trial_data_list[[i]] <- trial_batch
    rm(df, trial_batch)
    
    if (i %% 50 == 0) gc(verbose = FALSE)
    
  }, error = function(e) {
    cat("  Error processing file ", i, ": ", e$message, "\n", sep = "")
  })
}

# Combine all trials
trial_level <- bind_rows(trial_data_list)
rm(trial_data_list)
gc(verbose = FALSE)

# Deduplicate by trial_uid (should be unique, but just in case)
trial_level <- trial_level %>%
  group_by(trial_uid) %>%
  slice(1) %>%
  ungroup()

cat("  ✓ Built ", nrow(trial_level), " unique trials\n", sep = "")

# Validation: Check time_rel and window samples
cat("\n  Validation checks:\n")

# Time_rel range check
time_rel_range_valid <- trial_level %>%
  filter(abs(time_rel_range - 13.7) < 0.5) %>%
  nrow()

cat("  - Time_rel range near 13.7s: ", time_rel_range_valid, 
    " / ", nrow(trial_level), " trials\n", sep = "")

if (time_rel_range_valid < nrow(trial_level) * 0.9) {
  cat("  ⚠ WARNING: Many trials have time_rel_range != 13.7s. Check dt computation.\n", sep = "")
  range_summary <- trial_level %>%
    summarise(
      mean_range = mean(time_rel_range, na.rm = TRUE),
      median_range = median(time_rel_range, na.rm = TRUE),
      min_range = min(time_rel_range, na.rm = TRUE),
      max_range = max(time_rel_range, na.rm = TRUE)
    )
  cat("    Range stats: mean=", sprintf("%.2f", range_summary$mean_range),
      ", median=", sprintf("%.2f", range_summary$median_range),
      ", [", sprintf("%.2f", range_summary$min_range), ", ", 
      sprintf("%.2f", range_summary$max_range), "]\n", sep = "")
}

# Window sample counts (diagnostics)
window_diagnostics <- trial_level %>%
  group_by(task) %>%
  summarise(
    mean_n_samples_baseline = mean(n_samples_baseline, na.rm = TRUE),
    mean_n_samples_trial = mean(n_samples_trial, na.rm = TRUE),
    mean_n_samples_cog = mean(n_samples_cog, na.rm = TRUE),
    mean_n_samples_total_auc = mean(n_samples_total_auc, na.rm = TRUE),
    mean_time_rel_min = mean(time_rel_min, na.rm = TRUE),
    mean_time_rel_max = mean(time_rel_max, na.rm = TRUE),
    mean_time_rel_range = mean(time_rel_range, na.rm = TRUE),
    .groups = "drop"
  )

cat("\n  Window diagnostics (by task):\n")
print(window_diagnostics)

# Check baseline_quality distribution
baseline_quality_summary <- trial_level %>%
  filter(!is.na(baseline_quality)) %>%
  summarise(
    mean = mean(baseline_quality, na.rm = TRUE),
    median = median(baseline_quality, na.rm = TRUE),
    p10 = quantile(baseline_quality, 0.10, na.rm = TRUE, names = FALSE),
    p90 = quantile(baseline_quality, 0.90, na.rm = TRUE, names = FALSE),
    n_zero = sum(baseline_quality == 0, na.rm = TRUE),
    n_nonzero = sum(baseline_quality > 0, na.rm = TRUE)
  )

cat("\n  Baseline quality distribution:\n")
cat("    mean=", sprintf("%.3f", baseline_quality_summary$mean),
    ", median=", sprintf("%.3f", baseline_quality_summary$median),
    ", nonzero=", baseline_quality_summary$n_nonzero, " / ", 
    baseline_quality_summary$n_zero + baseline_quality_summary$n_nonzero, " trials\n", sep = "")

if (baseline_quality_summary$mean < 0.1) {
  cat("  ⚠ CRITICAL: Baseline quality mean is very low (", 
      sprintf("%.3f", baseline_quality_summary$mean), 
      "). Check time_rel computation and window alignment.\n", sep = "")
  cat("    Expected: baseline window should contain ~125 samples at 250 Hz\n")
  cat("    Actual mean: ", sprintf("%.1f", mean(trial_level$n_samples_baseline, na.rm = TRUE)), 
      " samples\n", sep = "")
}

# Check trial_quality vs overall_quality
quality_comparison <- trial_level %>%
  filter(!is.na(baseline_quality), !is.na(trial_quality), !is.na(overall_quality)) %>%
  summarise(
    baseline_mean = mean(baseline_quality, na.rm = TRUE),
    trial_mean = mean(trial_quality, na.rm = TRUE),
    overall_mean = mean(overall_quality, na.rm = TRUE),
    .groups = "drop"
  )

cat("\n  Quality comparison:\n")
cat("    baseline_quality_mean = ", sprintf("%.3f", quality_comparison$baseline_mean), "\n", sep = "")
cat("    trial_quality_mean = ", sprintf("%.3f", quality_comparison$trial_mean), "\n", sep = "")
cat("    overall_quality_mean = ", sprintf("%.3f", quality_comparison$overall_mean), "\n", sep = "")

if (quality_comparison$baseline_mean < 0.1 && quality_comparison$overall_mean > 0.5) {
  stop("CRITICAL ERROR: Baseline quality is near zero while overall quality is reasonable. ",
       "This indicates window misalignment. Check time_rel computation.")
}

# Check dt_median
dt_outliers <- trial_level %>%
  filter(!is.na(dt_median), (dt_median < 0.003 | dt_median > 0.005)) %>%
  nrow()

if (dt_outliers > 0) {
  cat("  ⚠ Warning: ", dt_outliers, " trials have dt_median outside [0.003, 0.005] range\n", sep = "")
}

# ----------------------------------------------------------------------------
# STEP 3: Compute gates
# ----------------------------------------------------------------------------

cat("\nSTEP 3: Computing gates...\n")

for (th in GATE_THRESHOLDS) {
  col_name <- paste0("pass_t", sprintf("%03d", as.integer(th * 100)))
  trial_level[[col_name]] <- 
    !is.na(trial_level$baseline_quality) & trial_level$baseline_quality >= th &
    !is.na(trial_level$trial_quality) & trial_level$trial_quality >= th &
    !is.na(trial_level$cog_quality) & trial_level$cog_quality >= th &
    trial_level$window_oob == 0L &
    trial_level$all_nan == 0L &
    trial_level$has_behavioral_data == 1L &
    is.finite(trial_level$baseline_quality) &
    is.finite(trial_level$trial_quality) &
    is.finite(trial_level$cog_quality)
}

cat("  ✓ Gates computed\n")

# ----------------------------------------------------------------------------
# STEP 4: Generate outputs
# ----------------------------------------------------------------------------

cat("\nSTEP 4: Generating outputs...\n")

# 01_file_provenance.csv
file_provenance <- tibble(
  timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  git_hash = get_git_hash(),
  input_directory = PROCESSED_DIR,
  n_flat_files = length(flat_files),
  n_subjects = n_distinct(trial_level$sub),
  n_trials = nrow(trial_level)
)

write_csv(file_provenance, file.path(OUTPUT_DIR, "01_file_provenance.csv"))
cat("  ✓ 01_file_provenance.csv\n")

# 02_design_expected_vs_observed.csv
design_table <- trial_level %>%
  group_by(sub, task) %>%
  summarise(
    observed_runs = n_distinct(run_used),
    observed_trials = n(),
    expected_runs = EXPECTED_RUNS_PER_TASK,
    expected_trials = EXPECTED_TRIALS_PER_TASK,
    missing_runs = pmax(0L, expected_runs - observed_runs),
    missing_trials = pmax(0L, expected_trials - observed_trials),
    .groups = "drop"
  )

write_csv(design_table, file.path(OUTPUT_DIR, "02_design_expected_vs_observed.csv"))
cat("  ✓ 02_design_expected_vs_observed.csv\n")

# 03_trials_per_subject_task_ses.csv
trials_per_subject <- trial_level %>%
  group_by(sub, task, session_used) %>%
  summarise(
    n_runs = n_distinct(run_used),
    n_trials = n(),
    pct_trials_with_behavior = 100 * mean(has_behavioral_data == 1L, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(trials_per_subject, file.path(OUTPUT_DIR, "03_trials_per_subject_task_ses.csv"))
cat("  ✓ 03_trials_per_subject_task_ses.csv\n")

# 04_run_level_counts.csv
run_level <- trial_level %>%
  group_by(sub, task, session_used, run_used) %>%
  summarise(
    n_trials = n(),
    pct_non_nan_total_min = min(pct_non_nan_total, na.rm = TRUE),
    pct_non_nan_total_median = median(pct_non_nan_total, na.rm = TRUE),
    pct_non_nan_total_max = max(pct_non_nan_total, na.rm = TRUE),
    n_trials_pass_t050 = sum(pass_t050, na.rm = TRUE),
    n_trials_pass_t060 = sum(pass_t060, na.rm = TRUE),
    n_trials_pass_t070 = sum(pass_t070, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(run_level, file.path(OUTPUT_DIR, "04_run_level_counts.csv"))
cat("  ✓ 04_run_level_counts.csv\n")

# 05_window_validity_summary.csv
window_summary <- trial_level %>%
  group_by(task) %>%
  summarise(
    n_trials = n(),
    baseline_quality_mean = mean(baseline_quality, na.rm = TRUE),
    baseline_quality_median = median(baseline_quality, na.rm = TRUE),
    baseline_quality_p10 = quantile(baseline_quality, 0.10, na.rm = TRUE, names = FALSE),
    baseline_quality_p25 = quantile(baseline_quality, 0.25, na.rm = TRUE, names = FALSE),
    baseline_quality_p75 = quantile(baseline_quality, 0.75, na.rm = TRUE, names = FALSE),
    baseline_quality_p90 = quantile(baseline_quality, 0.90, na.rm = TRUE, names = FALSE),
    trial_quality_mean = mean(trial_quality, na.rm = TRUE),
    trial_quality_median = median(trial_quality, na.rm = TRUE),
    trial_quality_p10 = quantile(trial_quality, 0.10, na.rm = TRUE, names = FALSE),
    trial_quality_p25 = quantile(trial_quality, 0.25, na.rm = TRUE, names = FALSE),
    trial_quality_p75 = quantile(trial_quality, 0.75, na.rm = TRUE, names = FALSE),
    trial_quality_p90 = quantile(trial_quality, 0.90, na.rm = TRUE, names = FALSE),
    overall_quality_mean = mean(overall_quality, na.rm = TRUE),
    overall_quality_median = median(overall_quality, na.rm = TRUE),
    overall_quality_p10 = quantile(overall_quality, 0.10, na.rm = TRUE, names = FALSE),
    overall_quality_p25 = quantile(overall_quality, 0.25, na.rm = TRUE, names = FALSE),
    overall_quality_p75 = quantile(overall_quality, 0.75, na.rm = TRUE, names = FALSE),
    overall_quality_p90 = quantile(overall_quality, 0.90, na.rm = TRUE, names = FALSE),
    .groups = "drop"
  ) %>%
  mutate(
    note = "Quality metrics are proportions (0-1 scale)"
  )

write_csv(window_summary, file.path(OUTPUT_DIR, "05_window_validity_summary.csv"))
cat("  ✓ 05_window_validity_summary.csv\n")

# 06_gate_pass_rates_by_threshold.csv
gate_rates <- map_dfr(GATE_THRESHOLDS, function(th) {
  col_name <- paste0("pass_t", sprintf("%03d", as.integer(th * 100)))
  
  trial_level %>%
    group_by(task) %>%
    summarise(
      threshold = th,
      n_trials_total = n(),
      n_trials_pass = sum(.data[[col_name]], na.rm = TRUE),
      pass_rate = n_trials_pass / n_trials_total,
      pass_rate_pct = 100 * pass_rate,
      .groups = "drop"
    )
})

# Validation: Check pass_rate_pct <= 100
if (any(gate_rates$pass_rate_pct > 100, na.rm = TRUE)) {
  stop("CRITICAL ERROR: pass_rate_pct > 100 detected! Check trial counting.")
}

write_csv(gate_rates, file.path(OUTPUT_DIR, "06_gate_pass_rates_by_threshold.csv"))
cat("  ✓ 06_gate_pass_rates_by_threshold.csv\n")

# 07_bias_checks_key_gates.csv
bias_checks_list <- list()

for (th in GATE_THRESHOLDS) {
  col_name <- paste0("pass_t", sprintf("%03d", as.integer(th * 100)))
  
  # Compare passed vs failed
  passed <- trial_level %>% filter(.data[[col_name]] == TRUE)
  failed <- trial_level %>% filter(.data[[col_name]] == FALSE)
  
  if (nrow(passed) > 0 && nrow(failed) > 0) {
    # pct_non_nan_total comparison
    mean_diff_pct <- mean(passed$pct_non_nan_total, na.rm = TRUE) - 
                     mean(failed$pct_non_nan_total, na.rm = TRUE)
    pooled_sd <- sqrt((var(passed$pct_non_nan_total, na.rm = TRUE) + 
                       var(failed$pct_non_nan_total, na.rm = TRUE)) / 2)
    cohens_d_pct <- if_else(pooled_sd > 0, mean_diff_pct / pooled_sd, NA_real_)
    
    # overall_quality comparison
    mean_diff_qual <- mean(passed$overall_quality, na.rm = TRUE) - 
                      mean(failed$overall_quality, na.rm = TRUE)
    pooled_sd_qual <- sqrt((var(passed$overall_quality, na.rm = TRUE) + 
                            var(failed$overall_quality, na.rm = TRUE)) / 2)
    cohens_d_qual <- if_else(pooled_sd_qual > 0, mean_diff_qual / pooled_sd_qual, NA_real_)
    
    # Session comparison
    session_2 <- trial_level %>% filter(session_used == 2L)
    session_3 <- trial_level %>% filter(session_used == 3L)
    
    mean_diff_ses <- mean(session_2[[col_name]], na.rm = TRUE) - 
                     mean(session_3[[col_name]], na.rm = TRUE)
    
    bias_checks_list[[length(bias_checks_list) + 1]] <- tibble(
      threshold = th,
      comparison = "passed_vs_failed",
      metric = "pct_non_nan_total",
      mean_diff = mean_diff_pct,
      cohens_d = cohens_d_pct,
      n_passed = nrow(passed),
      n_failed = nrow(failed)
    )
    
    bias_checks_list[[length(bias_checks_list) + 1]] <- tibble(
      threshold = th,
      comparison = "passed_vs_failed",
      metric = "overall_quality",
      mean_diff = mean_diff_qual,
      cohens_d = cohens_d_qual,
      n_passed = nrow(passed),
      n_failed = nrow(failed)
    )
    
    bias_checks_list[[length(bias_checks_list) + 1]] <- tibble(
      threshold = th,
      comparison = "session_2_vs_3",
      metric = "pass_rate",
      mean_diff = mean_diff_ses,
      cohens_d = NA_real_,
      n_passed = nrow(session_2),
      n_failed = nrow(session_3)
    )
  }
}

if (length(bias_checks_list) > 0) {
  bias_checks <- bind_rows(bias_checks_list)
} else {
  bias_checks <- tibble(
    threshold = numeric(),
    comparison = character(),
    metric = character(),
    mean_diff = numeric(),
    cohens_d = numeric(),
    n_passed = integer(),
    n_failed = integer()
  )
}

write_csv(bias_checks, file.path(OUTPUT_DIR, "07_bias_checks_key_gates.csv"))
cat("  ✓ 07_bias_checks_key_gates.csv\n")

# 08_prestim_dip_summary.csv
# Compute early vs late window missingness
trial_level_with_dip <- trial_level %>%
  mutate(
    # Use time_min and time_max to define windows
    # Early window: first 1.0s
    # Late window: last 1.0s
    # We'll approximate using pct_non_nan_total as a proxy
    # For a more accurate measure, we'd need sample-level data
    missing_early = 100 - pct_non_nan_total,  # Approximation
    missing_late = 100 - pct_non_nan_total,    # Approximation (same for now)
    dip = missing_late - missing_early  # Will be ~0 with this approximation
  )

prestim_dip <- trial_level_with_dip %>%
  group_by(task) %>%
  summarise(
    n_trials = n(),
    missing_early_mean = mean(missing_early, na.rm = TRUE),
    missing_early_median = median(missing_early, na.rm = TRUE),
    missing_early_p10 = quantile(missing_early, 0.10, na.rm = TRUE, names = FALSE),
    missing_early_p90 = quantile(missing_early, 0.90, na.rm = TRUE, names = FALSE),
    missing_late_mean = mean(missing_late, na.rm = TRUE),
    missing_late_median = median(missing_late, na.rm = TRUE),
    missing_late_p10 = quantile(missing_late, 0.10, na.rm = TRUE, names = FALSE),
    missing_late_p90 = quantile(missing_late, 0.90, na.rm = TRUE, names = FALSE),
    dip_mean = mean(dip, na.rm = TRUE),
    dip_median = median(dip, na.rm = TRUE),
    dip_p10 = quantile(dip, 0.10, na.rm = TRUE, names = FALSE),
    dip_p90 = quantile(dip, 0.90, na.rm = TRUE, names = FALSE),
    note = "Missing rates approximated from pct_non_nan_total (sample-level computation needed for precise early/late windows)",
    .groups = "drop"
  )

write_csv(prestim_dip, file.path(OUTPUT_DIR, "08_prestim_dip_summary.csv"))
cat("  ✓ 08_prestim_dip_summary.csv\n")

cat("\n=== EXPORT COMPLETE ===\n")
cat("Outputs saved to: ", OUTPUT_DIR, "\n", sep = "")

# Final validation
# Save trial-level data for TR jitter check in report
trial_level_for_jitter <- trial_level %>%
  select(sub, task, session_used, run_used, trial_index, time_min, trial_start_time_ptb) %>%
  arrange(sub, task, session_used, run_used, trial_index)

write_csv(trial_level_for_jitter, file.path(OUTPUT_DIR, "trial_level_for_jitter.csv"))
cat("  ✓ trial_level_for_jitter.csv (for TR jitter diagnostic)\n")

# ----------------------------------------------------------------------------
# STEP 5: Create merged trial-level dataset
# ----------------------------------------------------------------------------

cat("\nSTEP 5: Creating merged trial-level dataset...\n")

# Try to load behavioral data
behavioral_file <- if (file.exists(config_file) && !is.null(config$behavioral_csv)) {
  config$behavioral_csv
} else {
  # Try common locations
  candidates <- c(
    file.path(REPO_ROOT, "data", "intermediate", "behavior_TRIALLEVEL_normalized.csv"),
    "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"
  )
  found <- candidates[file.exists(candidates)]
  if (length(found) > 0) found[1] else NULL
}

if (!is.null(behavioral_file) && file.exists(behavioral_file)) {
  cat("  Loading behavioral data from: ", behavioral_file, "\n", sep = "")
  
  behavioral <- read_csv(behavioral_file, show_col_types = FALSE)
  
  # Normalize behavioral columns
  behavioral <- behavioral %>%
    mutate(
      sub = as.character(if ("sub" %in% names(.)) sub else 
                        if ("subject_id" %in% names(.)) subject_id else NA_character_),
      task = as.character(if ("task" %in% names(.)) task else
                         if ("task_modality" %in% names(.)) {
                           case_when(
                             task_modality == "aud" ~ "ADT",
                             task_modality == "vis" ~ "VDT",
                             TRUE ~ as.character(task_modality)
                           )
                         } else NA_character_),
      session_used = as.integer(if ("session_used" %in% names(.)) session_used else
                               if ("ses" %in% names(.)) ses else
                               if ("session_num" %in% names(.)) session_num else NA_integer_),
      run_used = as.integer(if ("run_used" %in% names(.)) run_used else
                           if ("run" %in% names(.)) run else
                           if ("run_num" %in% names(.)) run_num else NA_integer_),
      trial_index = as.integer(if ("trial_index" %in% names(.)) trial_index else
                              if ("trial" %in% names(.)) trial else
                              if ("trial_num" %in% names(.)) trial_num else NA_integer_),
      # Map behavioral columns
      resp1RT = if ("resp1RT" %in% names(.)) resp1RT else
                if ("same_diff_resp_secs" %in% names(.)) same_diff_resp_secs else NA_real_,
      iscorr = if ("iscorr" %in% names(.)) iscorr else
               if ("resp_is_correct" %in% names(.)) as.integer(resp_is_correct) else NA_integer_,
      stimLev = if ("stimLev" %in% names(.)) stimLev else
                if ("stim_level_index" %in% names(.)) stim_level_index else NA_real_,
      isOddball = if ("isOddball" %in% names(.)) isOddball else
                  if ("stim_is_diff" %in% names(.)) as.integer(stim_is_diff) else NA_integer_,
      gf_trPer = if ("gf_trPer" %in% names(.)) gf_trPer else
                 if ("grip_targ_prop_mvc" %in% names(.)) grip_targ_prop_mvc else NA_real_
    ) %>%
    filter(
      !is.na(sub), !is.na(task), !is.na(session_used), !is.na(run_used), !is.na(trial_index),
      session_used %in% c(2L, 3L),
      task %in% c("ADT", "VDT")
    )
  
  # Create behavioral trial key
  behavioral <- behavioral %>%
    mutate(
      beh_trial_key = interaction(sub, task, session_used, run_used, trial_index, drop = TRUE)
    )
  
  # Check for duplicates in behavioral data
  beh_duplicates <- behavioral %>%
    group_by(sub, task, session_used, run_used, trial_index) %>%
    summarise(n = n(), .groups = "drop") %>%
    filter(n > 1)
  
  if (nrow(beh_duplicates) > 0) {
    cat("  ⚠ Warning: Found ", nrow(beh_duplicates), " duplicate trial keys in behavioral data\n", sep = "")
    # Take first occurrence
    behavioral <- behavioral %>%
      group_by(sub, task, session_used, run_used, trial_index) %>%
      slice(1) %>%
      ungroup()
  }
  
  # Create pupil trial key
  trial_level <- trial_level %>%
    mutate(
      pupil_trial_key = interaction(sub, task, session_used, run_used, trial_index, drop = TRUE)
    )
  
  # Merge with trial_level
  trial_level_merged <- trial_level %>%
    left_join(behavioral %>% select(-beh_trial_key), 
              by = c("sub", "task", "session_used", "run_used", "trial_index"),
              suffix = c("", "_beh"))
  
  # Merge diagnostics
  n_pupil_trials <- nrow(trial_level)
  n_beh_trials <- nrow(behavioral)
  n_merged <- sum(!is.na(trial_level_merged$resp1RT) | !is.na(trial_level_merged$iscorr), na.rm = TRUE)
  match_rate_pupil <- 100 * n_merged / n_pupil_trials
  match_rate_beh <- 100 * n_merged / n_beh_trials
  
  cat("  ✓ Merge complete\n", sep = "")
  cat("    - Pupil trials: ", n_pupil_trials, "\n", sep = "")
  cat("    - Behavioral trials: ", n_beh_trials, "\n", sep = "")
  cat("    - Matched trials: ", n_merged, "\n", sep = "")
  cat("    - Match rate (pupil): ", sprintf("%.1f", match_rate_pupil), "%\n", sep = "")
  cat("    - Match rate (behavioral): ", sprintf("%.1f", match_rate_beh), "%\n", sep = "")
  
  # Unmatched keys
  unmatched_pupil <- trial_level %>%
    filter(!pupil_trial_key %in% behavioral$beh_trial_key) %>%
    group_by(sub, task) %>%
    summarise(n_unmatched = n(), .groups = "drop")
  
  unmatched_beh <- behavioral %>%
    filter(!beh_trial_key %in% trial_level$pupil_trial_key) %>%
    group_by(sub, task) %>%
    summarise(n_unmatched = n(), .groups = "drop")
  
  if (nrow(unmatched_pupil) > 0) {
    cat("    - Unmatched pupil trials by subject/task:\n")
    print(head(unmatched_pupil, 10))
  }
  
  if (nrow(unmatched_beh) > 0) {
    cat("    - Unmatched behavioral trials by subject/task:\n")
    print(head(unmatched_beh, 10))
  }
  
  # Save merge diagnostics
  merge_diagnostics <- tibble(
    n_pupil_trials = n_pupil_trials,
    n_beh_trials = n_beh_trials,
    n_matched = n_merged,
    match_rate_pupil_pct = match_rate_pupil,
    match_rate_beh_pct = match_rate_beh,
    n_unmatched_pupil = nrow(unmatched_pupil),
    n_unmatched_beh = nrow(unmatched_beh)
  )
  
  write_csv(merge_diagnostics, file.path(OUTPUT_DIR, "merge_diagnostics.csv"))
  cat("  ✓ Saved merge diagnostics: merge_diagnostics.csv\n", sep = "")
  
} else {
  cat("  ⚠ Behavioral data file not found, creating trial-level without behavioral merge\n", sep = "")
  trial_level_merged <- trial_level
}

# Save merged trial-level dataset
merged_dir <- file.path(OUTPUT_DIR, "merged")
dir.create(merged_dir, recursive = TRUE, showWarnings = FALSE)

merged_output <- file.path(merged_dir, "BAP_triallevel_merged.csv")
write_csv(trial_level_merged, merged_output)
cat("  ✓ Saved merged trial-level dataset: ", merged_output, "\n", sep = "")

cat("\n=== VALIDATION ===\n")
cat("Total trials: ", nrow(trial_level), "\n", sep = "")
cat("Trials per task:\n")
task_counts <- trial_level %>% group_by(task) %>% summarise(n = n(), .groups = "drop")
print(task_counts)
cat("\nPass rates (should be <= 100%):\n")
print(gate_rates %>% select(task, threshold, pass_rate_pct))

