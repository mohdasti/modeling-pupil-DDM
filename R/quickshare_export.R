#!/usr/bin/env Rscript
# ============================================================================
# Quick-Share: Export QC Summaries
# ============================================================================
# Reads trial-level QC dataset and generates 8 CSV summaries
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(tidyr)
  library(here)
  library(broom)
})

cat("=== QUICK-SHARE EXPORT ===\n\n")

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

REPO_ROOT <- here::here()
INPUT_FILE <- file.path(REPO_ROOT, "derived", "triallevel_qc.csv")
OUTPUT_DIR <- file.path(REPO_ROOT, "quick_share_v3")
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("Repo root: ", REPO_ROOT, "\n", sep = "")
cat("Input file: ", INPUT_FILE, "\n", sep = "")
cat("Output dir: ", OUTPUT_DIR, "\n\n", sep = "")

# Check input file exists
if (!file.exists(INPUT_FILE)) {
  stop("Input file not found: ", INPUT_FILE, 
       "\nPlease run R/quickshare_build_triallevel.R first.")
}

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------

GATE_THRESHOLDS <- c(50, 60, 70)  # Percentages
EXPECTED_TRIALS_PER_RUN <- 30L
EXPECTED_RUNS_PER_SESSION <- 5L

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
# STEP 1: Load trial-level data
# ----------------------------------------------------------------------------

cat("STEP 1: Loading trial-level data...\n")

trial_data <- read_csv(INPUT_FILE, show_col_types = FALSE)

cat("  ✓ Loaded ", nrow(trial_data), " trials\n", sep = "")

# Validation
if (nrow(trial_data) == 0) {
  stop("CRITICAL ERROR: Trial data is empty.")
}

# ----------------------------------------------------------------------------
# STEP 2: Compute gates
# ----------------------------------------------------------------------------

cat("\nSTEP 2: Computing gates...\n")

for (th in GATE_THRESHOLDS) {
  col_name <- paste0("pass_t", sprintf("%03d", th))
  trial_data[[col_name]] <- 
    !is.na(trial_data$pct_non_nan_baseline) & trial_data$pct_non_nan_baseline >= th &
    !is.na(trial_data$pct_non_nan_cogwin) & trial_data$pct_non_nan_cogwin >= th &
    !is.na(trial_data$pct_non_nan_overall) & trial_data$pct_non_nan_overall >= th &
    trial_data$any_timebase_bug == 0L &
    trial_data$window_oob_any == 0L &
    trial_data$all_nan_any == 0L &
    is.finite(trial_data$pct_non_nan_baseline) &
    is.finite(trial_data$pct_non_nan_cogwin) &
    is.finite(trial_data$pct_non_nan_overall)
}

cat("  ✓ Gates computed\n")

# Validation: At least one gate must have passes
total_passes_60 <- sum(trial_data$pass_t060, na.rm = TRUE)
if (total_passes_60 == 0) {
  stop("CRITICAL ERROR: Zero trials pass gate at threshold 60. Check window validity computation.")
}
cat("  ✓ Validation passed: ", total_passes_60, " trials pass threshold 60\n", sep = "")

# ----------------------------------------------------------------------------
# STEP 3: Generate outputs
# ----------------------------------------------------------------------------

cat("\nSTEP 3: Generating outputs...\n")

# 01_file_provenance.csv
file_provenance <- trial_data %>%
  summarise(
    n_subjects = n_distinct(subject),
    n_tasks = n_distinct(task),
    n_sessions = n_distinct(session_used),
    n_runs = n_distinct(subject, task, session_used, run_used),
    n_trials = n(),
    git_hash = get_git_hash(),
    generated_time = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  )

write_csv(file_provenance, file.path(OUTPUT_DIR, "01_file_provenance.csv"))
cat("  ✓ 01_file_provenance.csv\n")

# 02_design_expected_vs_observed.csv
design_table <- trial_data %>%
  group_by(subject, task, session_used) %>%
  summarise(
    expected_runs = EXPECTED_RUNS_PER_SESSION,
    expected_trials = EXPECTED_RUNS_PER_SESSION * EXPECTED_TRIALS_PER_RUN,
    observed_runs = n_distinct(run_used),
    observed_trials = n_distinct(trial_index),
    missing_runs = expected_runs - observed_runs,
    missing_trials = expected_trials - observed_trials,
    .groups = "drop"
  )

write_csv(design_table, file.path(OUTPUT_DIR, "02_design_expected_vs_observed.csv"))
cat("  ✓ 02_design_expected_vs_observed.csv\n")

# 03_trials_per_subject_task_ses.csv
trials_per_subject <- trial_data %>%
  group_by(subject, task, session_used) %>%
  summarise(
    n_trials = n_distinct(trial_index),
    n_pass_t050 = sum(pass_t050, na.rm = TRUE),
    n_pass_t060 = sum(pass_t060, na.rm = TRUE),
    n_pass_t070 = sum(pass_t070, na.rm = TRUE),
    mean_pct_non_nan_baseline = mean(pct_non_nan_baseline, na.rm = TRUE),
    mean_pct_non_nan_cogwin = mean(pct_non_nan_cogwin, na.rm = TRUE),
    mean_pct_non_nan_overall = mean(pct_non_nan_overall, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(trials_per_subject, file.path(OUTPUT_DIR, "03_trials_per_subject_task_ses.csv"))
cat("  ✓ 03_trials_per_subject_task_ses.csv\n")

# 04_run_level_counts.csv
run_level <- trial_data %>%
  group_by(subject, task, session_used, run_used) %>%
  summarise(
    n_trials = n_distinct(trial_index),
    n_trials_pass_t050 = sum(pass_t050, na.rm = TRUE),
    n_trials_pass_t060 = sum(pass_t060, na.rm = TRUE),
    n_trials_pass_t070 = sum(pass_t070, na.rm = TRUE),
    mean_pct_non_nan_baseline = mean(pct_non_nan_baseline, na.rm = TRUE),
    mean_pct_non_nan_cogwin = mean(pct_non_nan_cogwin, na.rm = TRUE),
    mean_pct_non_nan_overall = mean(pct_non_nan_overall, na.rm = TRUE),
    pct_any_timebase_bug = 100 * mean(any_timebase_bug == 1L, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(run_level, file.path(OUTPUT_DIR, "04_run_level_counts.csv"))
cat("  ✓ 04_run_level_counts.csv\n")

# 05_window_validity_summary.csv
window_summary <- trial_data %>%
  group_by(task, session_used) %>%
  summarise(
    n_trials = n_distinct(trial_index),
    baseline_mean = mean(pct_non_nan_baseline, na.rm = TRUE),
    baseline_median = median(pct_non_nan_baseline, na.rm = TRUE),
    baseline_p10 = quantile(pct_non_nan_baseline, 0.10, na.rm = TRUE, names = FALSE),
    baseline_p25 = quantile(pct_non_nan_baseline, 0.25, na.rm = TRUE, names = FALSE),
    baseline_p75 = quantile(pct_non_nan_baseline, 0.75, na.rm = TRUE, names = FALSE),
    baseline_p90 = quantile(pct_non_nan_baseline, 0.90, na.rm = TRUE, names = FALSE),
    cogwin_mean = mean(pct_non_nan_cogwin, na.rm = TRUE),
    cogwin_median = median(pct_non_nan_cogwin, na.rm = TRUE),
    cogwin_p10 = quantile(pct_non_nan_cogwin, 0.10, na.rm = TRUE, names = FALSE),
    cogwin_p25 = quantile(pct_non_nan_cogwin, 0.25, na.rm = TRUE, names = FALSE),
    cogwin_p75 = quantile(pct_non_nan_cogwin, 0.75, na.rm = TRUE, names = FALSE),
    cogwin_p90 = quantile(pct_non_nan_cogwin, 0.90, na.rm = TRUE, names = FALSE),
    overall_mean = mean(pct_non_nan_overall, na.rm = TRUE),
    overall_median = median(pct_non_nan_overall, na.rm = TRUE),
    overall_p10 = quantile(pct_non_nan_overall, 0.10, na.rm = TRUE, names = FALSE),
    overall_p25 = quantile(pct_non_nan_overall, 0.25, na.rm = TRUE, names = FALSE),
    overall_p75 = quantile(pct_non_nan_overall, 0.75, na.rm = TRUE, names = FALSE),
    overall_p90 = quantile(pct_non_nan_overall, 0.90, na.rm = TRUE, names = FALSE),
    .groups = "drop"
  )

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

write_csv(gate_rates, file.path(OUTPUT_DIR, "06_gate_pass_rates_by_threshold.csv"))
cat("  ✓ 06_gate_pass_rates_by_threshold.csv\n")

# 07_bias_checks_key_gates.csv
# Check if behavioral data is available
has_behavioral <- any(trial_data$has_behavioral_data == 1L, na.rm = TRUE)

if (has_behavioral) {
  # Try to load behavioral data if available
  # For now, just use task + session
  bias_checks_list <- list()
  
  for (th in c(50, 60)) {
    col_name <- paste0("pass_t", sprintf("%03d", th))
    
    # Create outcome column explicitly to avoid .data issues
    model_data <- trial_data %>%
      filter(!is.na(.data[[col_name]])) %>%
      mutate(
        task_f = factor(task),
        session_f = factor(session_used),
        outcome = .data[[col_name]]  # Extract to regular column
      )
    
    if (nrow(model_data) > 0) {
      tryCatch({
        model <- glm(outcome ~ task_f + session_f,
                     data = model_data, family = binomial())
        
        coef_summary <- broom::tidy(model) %>%
          mutate(
            threshold = th,
            outcome = "pass_t",
            interpretation = case_when(
              term == "(Intercept)" ~ "Baseline log-odds",
              str_detect(term, "task_f") ~ paste0("Task effect: ", str_extract(term, "VDT|ADT")),
              str_detect(term, "session_f") ~ paste0("Session effect: ", str_extract(term, "\\d+")),
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
    term = "BEHAVIOR_NOT_AVAILABLE",
    estimate = NA_real_,
    std.error = NA_real_,
    p.value = NA_real_,
    interpretation = "Behavioral data (effort/intensity/modality/RT) not available. Cannot compute bias checks until behavioral merge is available."
  )
}

write_csv(bias_checks, file.path(OUTPUT_DIR, "07_bias_checks_key_gates.csv"))
cat("  ✓ 07_bias_checks_key_gates.csv\n")

# 08_prestim_dip_summary.csv
if (any(!is.na(trial_data$pct_non_nan_prestim))) {
  prestim_dip <- trial_data %>%
    group_by(task) %>%
    summarise(
      n_trials = n_distinct(trial_index),
      frac_prestim_lt50 = mean(pct_non_nan_prestim < 50, na.rm = TRUE),
      frac_prestim_lt60 = mean(pct_non_nan_prestim < 60, na.rm = TRUE),
      prestim_mean = mean(pct_non_nan_prestim, na.rm = TRUE),
      prestim_median = median(pct_non_nan_prestim, na.rm = TRUE),
      status = "computed",
      .groups = "drop"
    )
} else {
  prestim_dip <- tibble(
    task = unique(trial_data$task),
    n_trials = NA_integer_,
    frac_prestim_lt50 = NA_real_,
    frac_prestim_lt60 = NA_real_,
    prestim_mean = NA_real_,
    prestim_median = NA_real_,
    status = "not computed - prestim window not defined in trial labels"
  )
}

write_csv(prestim_dip, file.path(OUTPUT_DIR, "08_prestim_dip_summary.csv"))
cat("  ✓ 08_prestim_dip_summary.csv\n")

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------

cat("\n=== EXPORT COMPLETE ===\n")
cat("Outputs saved to: ", OUTPUT_DIR, "\n", sep = "")

# Console summary
cat("\n=== SUMMARY ===\n")
cat("Trials with baseline > 0: ", sum(trial_data$pct_non_nan_baseline > 0, na.rm = TRUE), 
    " (", sprintf("%.1f", 100 * mean(trial_data$pct_non_nan_baseline > 0, na.rm = TRUE)), "%)\n", sep = "")
cat("Trials with cogwin defined: ", sum(!is.na(trial_data$pct_non_nan_cogwin)), 
    " (", sprintf("%.1f", 100 * mean(!is.na(trial_data$pct_non_nan_cogwin))), "%)\n", sep = "")

for (th in GATE_THRESHOLDS) {
  col_name <- paste0("pass_t", sprintf("%03d", th))
  n_pass <- sum(trial_data[[col_name]], na.rm = TRUE)
  pct_pass <- 100 * n_pass / nrow(trial_data)
  cat("Pass rate at threshold ", th, ": ", n_pass, " (", sprintf("%.1f", pct_pass), "%)\n", sep = "")
}

