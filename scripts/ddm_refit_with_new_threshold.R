# =========================================================================
# DDM REFITTING WITH NEW RT THRESHOLD
# =========================================================================
# This script refits DDM models using:
# 1. The chosen RT threshold (default: 200ms post-prompt)
# 2. Comparison of cue-locked vs probe-onset-locked RT definitions
# 3. Sensitivity analysis across thresholds
#
# RT Definitions:
#   - cue_locked: RT measured from response prompt onset (rt column)
#   - probe_offset_locked: cue_locked + 0.25s (GripRelaxTime)
#   - probe_onset_locked: cue_locked + 0.25s + 0.10s (probe duration)
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(dplyr)
  library(readr)
  library(tidyr)
  library(ggplot2)
  library(bayesplot)
})

# Ensure brms is loaded for get_prior()
if (!requireNamespace("brms", quietly = TRUE)) {
  stop("brms package is required")
}

# Load logging and validation utilities
source("R/utils/logging_validation.R")

# =========================================================================
# CONFIGURATION
# =========================================================================

# Analysis ID and output directory
# Allow override via environment variable or R variable to reuse existing run directory
# Check for R variable first (if set in interactive session), then environment variable
analysis_id <- if (exists("DDM_RUN_ID") && !is.null(DDM_RUN_ID) && DDM_RUN_ID != "") {
  DDM_RUN_ID
} else {
  Sys.getenv("DDM_RUN_ID", unset = format(Sys.time(), "%Y%m%d_%H%M%S"))
}
output_dir <- "output/ddm_refits"

# Input file configuration: default to unthresholded data, allow override via environment variable
# A) Unthresholded data path - prefer data/ (from build script), allow env override
DATA_UNTHR_DEFAULT <- "data/ddm_ready_data_unthresholded.csv"
DATA_UNTHR <- Sys.getenv("DDM_DATA_UNTHR", unset = "")
if (DATA_UNTHR == "") {
  DATA_UNTHR <- DATA_UNTHR_DEFAULT
}
INPUT_FILE_DEFAULT <- DATA_UNTHR  # Legacy; input_file_candidates used for actual loading
INPUT_FILE_OVERRIDE <- Sys.getenv("DDM_INPUT_FILE", unset = "")

# Input file paths: prefer data/ (from build_ddm_ready_data_unthresholded.R) over output/
# so the corrected difficulty mapping is used
input_file_candidates <- if (INPUT_FILE_OVERRIDE != "" && file.exists(INPUT_FILE_OVERRIDE)) {
  c(INPUT_FILE_OVERRIDE)
} else {
  c(
    "data/ddm_ready_data_unthresholded.csv",  # Primary: from build script (corrected mapping)
    "output/rt_threshold_analysis/ddm_ready_data_unthresholded.csv",
    "output/rt_threshold_analysis/ddm_ready_data.csv",
    "data/ddm_ready_data.csv"
  )
}

# RT timing constants from MATLAB task
# From cogdisc_task_v11c_1_eyetrack_AS.m: gaborDur=0.1, GripRelaxTime=0.25
PROBE_DUR_SEC <- 0.1
GRIP_RELAX_SEC <- 0.25
PROBE_ONSET_TO_PROMPT_SEC <- PROBE_DUR_SEC + GRIP_RELAX_SEC  # 0.35

# Output directories organized by analysis_id (run_id)
RUNS_BASE_DIR <- file.path(output_dir, "runs")
RUN_DIR <- file.path(RUNS_BASE_DIR, analysis_id)
MODELS_DIR <- file.path(RUN_DIR, "models")
SUMMARIES_DIR <- file.path(RUN_DIR, "summaries")
TABLES_DIR <- file.path(RUN_DIR, "tables")  # New: for QMD-ready exports
MANIFESTS_DIR <- file.path(RUN_DIR, "manifests")
LOG_DIR <- file.path(RUN_DIR, "logs")

# Legacy directories (for backward compatibility)
OUTPUT_DIR <- output_dir
RESULTS_DIR <- "output/results"
FIGURES_DIR <- "output/figures"
STANDARD_MODELS_DIR <- file.path(output_dir, "rt_threshold_analysis", "models")

# Create directories
dirs_to_create <- c(RUN_DIR, MODELS_DIR, SUMMARIES_DIR, TABLES_DIR, MANIFESTS_DIR, LOG_DIR, 
                    OUTPUT_DIR, RESULTS_DIR, FIGURES_DIR, STANDARD_MODELS_DIR)
for (dir in dirs_to_create) {
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
}

# Initialize run_index.csv
RUN_INDEX_FILE <- file.path(RUN_DIR, "run_index.csv")
run_index <- data.frame(
  analysis_id = character(0),
  model_name = character(0),
  threshold = numeric(0),
  rt_def = character(0),
  input_file = character(0),
  N_trials = integer(0),
  N_subjects = integer(0),
  min_rt_model = numeric(0),
  divergences = integer(0),
  treedepth_hits = integer(0),
  max_rhat = numeric(0),
  min_bulk_ess = numeric(0),
  min_tail_ess = numeric(0),
  time_elapsed_sec = numeric(0),
  output_rds_path = character(0),
  stringsAsFactors = FALSE
)
write_csv(run_index, RUN_INDEX_FILE)

# Thresholds for sensitivity analysis
# B) Make thresholds numeric (never store "0.20 s" in numeric column)
thresholds <- c(0.15, 0.20, 0.25)
SENS_THRESHOLDS <- thresholds
SENSITIVITY_THRESHOLDS <- thresholds  # Keep alias for backward compatibility
CHOSEN_THRESHOLD <- 0.200  # Default from evaluation

# MCMC settings
N_CHAINS <- 4
N_ITER <- 2000
N_WARMUP <- 1000
ADAPT_DELTA <- 0.95
MAX_TREEDEPTH <- 12

# Debug flags
DEBUG_QUICK <- FALSE
DRY_RUN <- as.logical(as.integer(Sys.getenv("DDM_DRY_RUN", unset = "0")))
SKIP_STANDARD_ONLY <- as.logical(as.integer(Sys.getenv("DDM_SKIP_STANDARD_ONLY", unset = "0")))
CONTINUE_ON_FAIL <- as.logical(as.integer(Sys.getenv("DDM_CONTINUE_ON_FAIL", unset = "0")))
MIN_TRIALS_PER_SUBJECT <- 20  # Minimum trials per subject after filtering

# Initialization settings
USE_SAFE_INIT <- FALSE
INIT_SD <- 0.1
INIT_ZERO <- as.logical(as.integer(Sys.getenv("DDM_INIT_ZERO", unset = "0")))

# Random-effects toggles
USE_BS_RANDOM_EFFECTS <- FALSE
USE_NDT_RANDOM_EFFECTS <- FALSE  # NDT typically intercept-only for stability in response-signal designs

# Legacy constants (for backward compatibility with existing code)
GRIP_RELAX_TIME <- GRIP_RELAX_SEC
PROBE_DURATION <- PROBE_DUR_SEC

# =========================================================================
# LOGGING INFRASTRUCTURE
# =========================================================================

# Create log file in run-specific directory
log_file <- file.path(LOG_DIR, paste0("ddm_refit_", analysis_id, ".log"))
log_con <- file(log_file, open = "wt")

# Track current step name for logging
CURRENT_STEP <- "INIT"

# Logging functions: write to both console and log file with timestamps
log_info <- function(msg, step = NULL) {
  if (is.null(step)) step <- CURRENT_STEP
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_line <- sprintf("[%s] [INFO] [%s] %s", timestamp, step, msg)
  cat(log_line, "\n")
  cat(log_line, "\n", file = log_con, append = TRUE)
  invisible(NULL)
}

log_warn <- function(msg, step = NULL) {
  if (is.null(step)) step <- CURRENT_STEP
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_line <- sprintf("[%s] [WARN] [%s] %s", timestamp, step, msg)
  cat(log_line, "\n")
  cat(log_line, "\n", file = log_con, append = TRUE)
  invisible(NULL)
}

log_error <- function(msg, step = NULL) {
  if (is.null(step)) step <- CURRENT_STEP
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_line <- sprintf("[%s] [ERROR] [%s] %s", timestamp, step, msg)
  cat(log_line, "\n")
  cat(log_line, "\n", file = log_con, append = TRUE)
  invisible(NULL)
}

# Set step context
set_step <- function(step_name) {
  CURRENT_STEP <<- step_name
  log_info(paste("=== Starting", step_name, "==="), step = "STEP")
}

# Initialize logging (also capture output to log file)
sink(log_con, type = "output", split = TRUE)

# Log session info at start
cat("\n=== Session Info ===\n", file = log_con, append = TRUE)
capture.output(print(sessionInfo()), file = log_con, append = TRUE)
cat("\n", file = log_con, append = TRUE)

# Report file path (in run directory)
REPORT_FILE <- file.path(RUN_DIR, paste0("run_report_", analysis_id, ".md"))
LOG_FILE <- log_file  # For backward compatibility

# =========================================================================
# UTILITY FUNCTIONS
# =========================================================================

# Pick input file: try multiple candidates in order
pick_input_file <- function() {
  for (candidate in input_file_candidates) {
    if (file.exists(candidate)) {
      log_info(paste("Using DATA_FILE:", candidate))
      
      # Log file fingerprint (size + modified time)
      file_info <- file.info(candidate)
      file_size_mb <- round(file_info$size / 1024 / 1024, 2)
      file_mtime <- format(file_info$mtime, "%Y-%m-%d %H:%M:%S")
      log_info(paste("  File fingerprint: size =", file_size_mb, "MB, modified =", file_mtime))
      
      return(candidate)
    }
  }
  
  # None found - list all tried paths
  log_error("No input file found. Tried the following paths:")
  for (candidate in input_file_candidates) {
    log_error(paste("  -", candidate))
  }
  log_error(paste("  Default expected:", INPUT_FILE_DEFAULT))
  log_error("  To override, set environment variable: DDM_INPUT_FILE=/path/to/file.csv")
  stop("Input file not found. Please ensure ddm_ready_data_unthresholded.csv exists or set DDM_INPUT_FILE.")
}

# Standardize DDM-ready data to common format
standardize_ddm_ready <- function(df) {
  log_info("Standardizing DDM-ready data format...")
  
  # Handle rt_cue: prefer rt_cue_locked, else rt
  if ("rt_cue_locked" %in% names(df)) {
    df$rt_cue <- df$rt_cue_locked
    log_info("Using rt_cue_locked as rt_cue")
  } else if ("rt" %in% names(df)) {
    df$rt_cue <- df$rt
    log_info("Using rt as rt_cue")
  } else {
    log_error("Neither rt_cue_locked nor rt found in data")
    log_error(paste("Available columns:", paste(names(df), collapse = ", ")))
    stop("Required RT column not found")
  }
  
  # Handle rt_probe_onset: prefer existing column, else compute
  if ("rt_probe_onset_locked" %in% names(df)) {
    df$rt_probe_onset <- df$rt_probe_onset_locked
    log_info("Using rt_probe_onset_locked as rt_probe_onset")
    
    # Verify offset is correct (~0.35s)
    offset_check <- df$rt_probe_onset - df$rt_cue
    median_offset <- median(offset_check, na.rm = TRUE)
    if (abs(median_offset - PROBE_ONSET_TO_PROMPT_SEC) > 0.02) {
      log_warn(paste("WARNING: rt_probe_onset_locked offset differs from expected 0.35s"))
      log_warn(paste("  Median offset:", round(median_offset, 4), "s"))
      log_warn(paste("  Expected:", PROBE_ONSET_TO_PROMPT_SEC, "s"))
      log_warn(paste("  Min offset:", round(min(offset_check, na.rm = TRUE), 4), "s"))
      log_warn(paste("  Max offset:", round(max(offset_check, na.rm = TRUE), 4), "s"))
    } else {
      log_info(paste("✓ Verified rt_probe_onset_locked offset:", round(median_offset, 4), "s"))
    }
  } else {
    # Compute rt_probe_onset (do NOT use rt_probe_offset_locked, do NOT include ISI)
    df$rt_probe_onset <- df$rt_cue + PROBE_ONSET_TO_PROMPT_SEC
    log_info(paste("Computed rt_probe_onset = rt_cue +", PROBE_ONSET_TO_PROMPT_SEC, "s (0.1 probe + 0.25 grip relax, NO ISI)"))
  }
  
  # Handle subject_id (ensure character)
  if (!"subject_id" %in% names(df)) {
    log_error("subject_id column not found")
    stop("Required column subject_id not found")
  }
  df$subject_id <- as.character(df$subject_id)
  
  # Handle task (factor with ADT/VDT if present)
  if (!"task" %in% names(df)) {
    log_error("task column not found")
    stop("Required column task not found")
  }
  # Normalize task values
  df$task <- tolower(as.character(df$task))
  if (any(grepl("^a", df$task, ignore.case = TRUE))) {
    df$task <- ifelse(grepl("^a", df$task, ignore.case = TRUE), "ADT", "VDT")
  } else if (any(grepl("^v", df$task, ignore.case = TRUE))) {
    df$task <- ifelse(grepl("^v", df$task, ignore.case = TRUE), "VDT", "ADT")
  }
  # Set explicit factor levels for stable coefficient names
  # Reference levels: task=ADT, effort_condition=low
  df$task <- factor(df$task, levels = c("ADT", "VDT"))
  
  # Handle effort_condition (factor with low/high)
  if (!"effort_condition" %in% names(df)) {
    log_error("effort_condition column not found")
    stop("Required column effort_condition not found")
  }
  df$effort_condition <- tolower(as.character(df$effort_condition))
  # Set explicit factor levels: low is reference
  df$effort_condition <- factor(df$effort_condition, levels = c("low", "high"))
  
  log_info("Factor reference levels: task=ADT, effort_condition=low")
  
  # Handle difficulty_3 (factor with Standard/Hard/Easy, baseline = Standard)
  if ("difficulty_level" %in% names(df)) {
    if (is.numeric(df$difficulty_level)) {
      # Collapse numeric 0..4 to 3 levels (stim_level_index: 0=Standard, 1-2=Hard, 3-4=Easy)
      df$difficulty_3 <- case_when(
        df$difficulty_level == 0 ~ "Standard",
        df$difficulty_level %in% c(1, 2) ~ "Hard",
        df$difficulty_level %in% c(3, 4) ~ "Easy",
        TRUE ~ "Standard"
      )
      log_info("Collapsed numeric difficulty_level to difficulty_3")
    } else {
      # Map string values directly
      df$difficulty_3 <- as.character(df$difficulty_level)
      df$difficulty_3 <- case_when(
        grepl("standard|baseline|0", df$difficulty_3, ignore.case = TRUE) ~ "Standard",
        grepl("easy|3|4", df$difficulty_3, ignore.case = TRUE) ~ "Easy",
        grepl("hard|1|2", df$difficulty_3, ignore.case = TRUE) ~ "Hard",
        TRUE ~ "Standard"
      )
      log_info("Mapped string difficulty_level to difficulty_3")
    }
  } else {
    log_error("difficulty_level column not found")
    stop("Required column difficulty_level not found")
  }
  df$difficulty_3 <- factor(df$difficulty_3, levels = c("Standard", "Hard", "Easy"))
  
  # Handle choice_binary (1 = "different" = upper boundary)
  if ("choice_binary" %in% names(df)) {
    df$choice_binary <- as.integer(df$choice_binary)
    log_info("Using existing choice_binary column")
  } else if ("resp_is_diff" %in% names(df)) {
    df$choice_binary <- as.integer(df$resp_is_diff)
    log_info("Created choice_binary from resp_is_diff")
  } else if ("choice" %in% names(df)) {
    df$choice_binary <- as.integer(df$choice)
    log_info("Created choice_binary from choice")
  } else {
    log_error("choice_binary, resp_is_diff, or choice column not found")
    log_error(paste("Available columns:", paste(names(df), collapse = ", ")))
    stop("Required choice column not found")
  }
  
  # Create dec_upper (copy of choice_binary)
  df$dec_upper <- df$choice_binary
  
  # Select and return standardized columns
  result <- df %>%
    select(subject_id, task, effort_condition, difficulty_3, 
           rt_cue, rt_probe_onset, choice_binary, dec_upper)
  
  log_info(paste("Standardized data:", nrow(result), "trials"))
  return(result)
}

# Validate DDM data with preflight checks
validate_ddm_data <- function(df) {
  log_info("Running preflight validation...")
  
  # Check required columns
  required_cols_base <- c("subject_id", "choice_binary", "task", "effort_condition")
  required_cols_rt <- c("rt_cue", "rt_probe_onset")
  required_cols_difficulty <- c("difficulty_3")
  
  missing_base <- setdiff(required_cols_base, names(df))
  missing_rt <- setdiff(required_cols_rt, names(df))
  missing_difficulty <- setdiff(required_cols_difficulty, names(df))
  
  if (length(missing_base) > 0 || length(missing_rt) > 0 || length(missing_difficulty) > 0) {
    log_error("Missing required columns:")
    if (length(missing_base) > 0) log_error(paste("  Base:", paste(missing_base, collapse = ", ")))
    if (length(missing_rt) > 0) log_error(paste("  RT:", paste(missing_rt, collapse = ", ")))
    if (length(missing_difficulty) > 0) log_error(paste("  Difficulty:", paste(missing_difficulty, collapse = ", ")))
    log_error(paste("Available columns:", paste(names(df), collapse = ", ")))
    stop("Preflight validation failed: missing columns")
  }
  log_info("✓ All required columns present")
  
  # Verify choice_binary matches resp_is_diff if resp_is_diff exists
  if ("resp_is_diff" %in% names(df)) {
    choice_check <- (df$choice_binary == as.integer(df$resp_is_diff))
    n_mismatch <- sum(!choice_check, na.rm = TRUE)
    if (n_mismatch > 0) {
      log_error(paste("choice_binary mismatch with resp_is_diff:", n_mismatch, "trials"))
      mismatch_table <- table(df$choice_binary, df$resp_is_diff, useNA = "ifany")
      log_error("Cross-tabulation:")
      print(mismatch_table)
      stop("Preflight validation failed: choice_binary mismatch")
    }
    log_info("✓ choice_binary matches resp_is_diff")
  }
  
  # Check for missing values
  required_cols <- c(required_cols_base, required_cols_rt, required_cols_difficulty)
  na_counts <- sapply(df[required_cols], function(x) sum(is.na(x)))
  if (any(na_counts > 0)) {
    log_error("Found missing values in required columns:")
    for (col in names(na_counts[na_counts > 0])) {
      log_error(paste("  ", col, ":", na_counts[col], "NA values"))
    }
    stop("Preflight validation failed: missing values")
  }
  log_info("✓ No missing values in required columns")
  
  # Check rt_cue > 0
  n_neg <- sum(df$rt_cue <= 0, na.rm = TRUE)
  if (n_neg > 0) {
    log_error(paste("Found", n_neg, "trials with rt_cue <= 0"))
    stop("Preflight validation failed: non-positive RT values")
  }
  
  # Warn if any rt_cue < 0.05
  n_very_fast <- sum(df$rt_cue < 0.05, na.rm = TRUE)
  if (n_very_fast > 0) {
    log_warn(paste("Found", n_very_fast, "trials with rt_cue < 0.05s"))
    log_warn(paste("Min rt_cue:", round(min(df$rt_cue, na.rm = TRUE), 4), "s"))
    log_warn("RT quantiles for rt_cue < 0.05s:")
    fast_rt <- df$rt_cue[df$rt_cue < 0.05]
    if (length(fast_rt) > 0) {
      fast_quantiles <- quantile(fast_rt, probs = c(0, 0.25, 0.5, 0.75, 1), na.rm = TRUE)
      for (i in seq_along(fast_quantiles)) {
        log_warn(paste("  ", names(fast_quantiles)[i], "=", round(fast_quantiles[i], 4), "s"))
      }
    }
  }
  
  # Check rt_cue <= 3.0 (response window is 3 sec)
  n_out_of_range <- sum(df$rt_cue > 3.0, na.rm = TRUE)
  if (n_out_of_range > 0) {
    log_warn(paste("Found", n_out_of_range, "trials with rt_cue > 3.0s (out of response window)"))
    log_warn(paste("Max rt_cue:", round(max(df$rt_cue, na.rm = TRUE), 4), "s"))
  }
  
  # Check choice_binary only 0/1
  invalid_choice <- sum(!df$choice_binary %in% c(0L, 1L), na.rm = TRUE)
  if (invalid_choice > 0) {
    log_error(paste("Found", invalid_choice, "trials with choice_binary not in {0, 1}"))
    log_error(paste("Unique values:", paste(unique(df$choice_binary), collapse = ", ")))
    stop("Preflight validation failed: invalid choice_binary values")
  }
  log_info("✓ choice_binary contains only 0/1")
  
  # Log comprehensive RT quantiles for rt_cue_locked (pre-filter)
  log_info("RT quantiles for rt_cue_locked (pre-filter):")
  rt_quantiles <- quantile(df$rt_cue, probs = c(0, 0.01, 0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99, 1), na.rm = TRUE)
  for (i in seq_along(rt_quantiles)) {
    log_info(sprintf("  %s = %.4f s", names(rt_quantiles)[i], rt_quantiles[i]))
  }
  
  # Log counts below each threshold (0.10, 0.15, 0.20, 0.25)
  log_info("Counts below thresholds (based on rt_cue_locked):")
  threshold_checkpoints <- c(0.10, 0.15, 0.20, 0.25)
  for (thresh in threshold_checkpoints) {
    n_below <- sum(df$rt_cue < thresh, na.rm = TRUE)
    pct_below <- 100 * n_below / nrow(df)
    log_info(sprintf("  rt_cue < %.2f s: %d trials (%.2f%%)", thresh, n_below, pct_below))
  }
  
  # Log percent of trials below sensitivity thresholds
  log_info("Percent of trials below sensitivity thresholds (based on rt_cue):")
  for (thresh in SENSITIVITY_THRESHOLDS) {
    pct_below <- 100 * sum(df$rt_cue < thresh, na.rm = TRUE) / nrow(df)
    log_info(sprintf("  rt_cue < %.3f s: %.2f%% (%d trials)", thresh, pct_below, sum(df$rt_cue < thresh, na.rm = TRUE)))
  }
  
  # Log compact summary table
  log_info("=== Data Summary ===")
  log_info(paste("N trials:", nrow(df)))
  log_info(paste("N subjects:", length(unique(df$subject_id))))
  
  # Counts by task × effort_condition × difficulty_3
  summary_table <- df %>%
    group_by(task, effort_condition, difficulty_3) %>%
    summarise(n = n(), .groups = "drop")
  log_info("Counts by task × effort_condition × difficulty_3:")
  for (i in 1:nrow(summary_table)) {
    log_info(sprintf("  %s × %s × %s: %d trials", 
                     summary_table$task[i], 
                     summary_table$effort_condition[i],
                     summary_table$difficulty_3[i],
                     summary_table$n[i]))
  }
  
  # RT statistics
  log_info("RT statistics:")
  log_info(paste("  rt_cue: min =", round(min(df$rt_cue, na.rm = TRUE), 4),
                 ", median =", round(median(df$rt_cue, na.rm = TRUE), 4),
                 ", max =", round(max(df$rt_cue, na.rm = TRUE), 4)))
  log_info(paste("  rt_probe_onset: min =", round(min(df$rt_probe_onset, na.rm = TRUE), 4),
                 ", median =", round(median(df$rt_probe_onset, na.rm = TRUE), 4),
                 ", max =", round(max(df$rt_probe_onset, na.rm = TRUE), 4)))
  
  log_info("✓ Preflight validation passed")
  return(invisible(df))
}

# =========================================================================
# RUN HEADER: System Information and Configuration
# =========================================================================

set_step("HEADER")

log_info("==================================================================================")
log_info("DDM REFITTING WITH NEW RT THRESHOLD")
log_info("==================================================================================")

# Analysis metadata
log_info(paste("Analysis ID:", analysis_id))
log_info(paste("Run directory:", RUN_DIR))

# Input file (will be set after pick_input_file)
log_info("Input file: (will be determined)")

# Git commit hash
git_commit <- tryCatch({
  result <- system("git rev-parse --short HEAD", intern = TRUE, ignore.stderr = TRUE)
  if (length(result) == 0 || result == "") "git unavailable" else result
}, error = function(e) "git unavailable")
log_info(paste("Git commit:", git_commit))

# System and package versions
log_info(paste("R version:", R.version.string))
log_info(paste("brms version:", as.character(packageVersion("brms"))))
log_info(paste("cmdstanr version:", tryCatch({
  as.character(packageVersion("cmdstanr"))
}, error = function(e) "not installed")))

# cmdstan path
cmdstan_path <- tryCatch({
  cmdstanr::cmdstan_path()
}, error = function(e) "not found")
log_info(paste("cmdstan path:", cmdstan_path))

# System resources
log_info(paste("Number of cores:", parallel::detectCores()))
log_info(paste("Threads per chain:", N_CHAINS))

# Configuration
log_info("==================================================================================")
log_info("CONFIGURATION")
log_info("==================================================================================")
log_info(paste("Chosen threshold:", CHOSEN_THRESHOLD, "seconds"))
log_info(paste("Sensitivity thresholds:", paste(SENSITIVITY_THRESHOLDS, collapse=", ")))
log_info(paste("Dry run mode:", DRY_RUN))
log_info(paste("Init zero mode:", INIT_ZERO))
log_info(paste("Skip standard-only models:", SKIP_STANDARD_ONLY))
log_info(paste("Continue on model failures:", CONTINUE_ON_FAIL))
log_info(paste("Log file:", LOG_FILE))
log_info(paste("Report file:", REPORT_FILE))
log_info("==================================================================================")
log_info("")

# =========================================================================
# RT FILTERING AND THRESHOLDING FUNCTIONS
# =========================================================================

# Apply RT filters (floor and ceiling)
apply_rt_filters <- function(df, rt_floor = 0, rt_ceiling = 3.0) {
  n_before <- nrow(df)
  
  # Filter by floor
  n_below_floor <- sum(df$rt_cue <= rt_floor, na.rm = TRUE)
  df <- df %>% filter(rt_cue > rt_floor)
  
  # Filter by ceiling
  n_above_ceiling <- sum(df$rt_cue > rt_ceiling, na.rm = TRUE)
  df <- df %>% filter(rt_cue <= rt_ceiling)
  
  n_after <- nrow(df)
  n_removed <- n_before - n_after
  
  if (n_removed > 0) {
    log_info(paste("RT filtering removed", n_removed, "trials:"))
    if (n_below_floor > 0) {
      log_info(paste("  ", n_below_floor, "trials with rt_cue <=", rt_floor, "s"))
    }
    if (n_above_ceiling > 0) {
      log_info(paste("  ", n_above_ceiling, "trials with rt_cue >", rt_ceiling, "s"))
    }
  }
  
  return(df)
}

# Apply threshold and create rt_model column
# Lower-bound exclusion is always applied to cue-locked RT (Methods), regardless of
# which RT column enters the DDM likelihood (probe-onset-locked, etc.).
apply_threshold_and_rt_def <- function(df, threshold, rt_def) {
  # First apply ceiling filter (on rt_cue)
  df_filtered <- apply_rt_filters(df, rt_floor = 0, rt_ceiling = 3.0)
  
  if (rt_def == "cue_locked") {
    rt_col <- "rt_cue"
  } else if (rt_def == "probe_onset_locked") {
    rt_col <- "rt_probe_onset"
  } else if (rt_def == "probe_offset_locked") {
    rt_col <- "rt_probe_offset"
  } else {
    log_error(paste("Unknown rt_def:", rt_def))
    log_error("Supported: 'cue_locked', 'probe_onset_locked', 'probe_offset_locked'")
    stop("Unknown rt_def")
  }
  
  if (!"rt_cue" %in% names(df_filtered)) {
    log_error(paste("RT column 'rt_cue' not found. Available columns:",
                    paste(names(df_filtered), collapse = ", ")))
    stop("RT column not found")
  }
  if (!rt_col %in% names(df_filtered)) {
    log_error(paste("RT column '", rt_col, "' not found. Available columns:",
                    paste(names(df_filtered), collapse = ", ")))
    stop("RT column not found")
  }
  
  # Always threshold on cue-locked RT; rt_model follows rt_def
  n_before_thresh <- nrow(df_filtered)
  df_thr <- df_filtered %>% filter(rt_cue >= threshold)
  n_after_thresh <- nrow(df_thr)
  
  # D) Log immediately after filtering
  min_rt_cue_after <- min(df_thr$rt_cue, na.rm = TRUE)
  p01_rt_cue_after <- quantile(df_thr$rt_cue, 0.01, na.rm = TRUE)
  median_rt_cue_after <- median(df_thr$rt_cue, na.rm = TRUE)
  min_rt_after <- min(df_thr[[rt_col]], na.rm = TRUE)
  p01_rt_after <- quantile(df_thr[[rt_col]], 0.01, na.rm = TRUE)
  median_rt_after <- median(df_thr[[rt_col]], na.rm = TRUE)
  
  log_info(paste("Threshold", threshold, "s (applied to cue-locked RT; model RT =", rt_col, "):"))
  log_info(paste("  - n_trials before:", n_before_thresh))
  log_info(paste("  - n_trials after:", n_after_thresh))
  log_info(paste("  - min rt_cue after filtering:", round(min_rt_cue_after, 4), "s"))
  log_info(paste("  - min", rt_col, "after filtering:", round(min_rt_after, 4), "s"))
  log_info(paste("  - 1% quantile", rt_col, "after filtering:", round(p01_rt_after, 4), "s"))
  log_info(paste("  - median", rt_col, "after filtering:", round(median_rt_after, 4), "s"))
  
  # Create rt_model based on rt_def (AFTER thresholding)
  # For cue_locked: use rt_cue directly
  # For probe_onset_locked: use rt_probe_onset directly (already computed in data)
  if (rt_def == "cue_locked") {
    df_thr$rt_model <- df_thr$rt_cue
  } else if (rt_def == "probe_onset_locked") {
    df_thr$rt_model <- df_thr$rt_probe_onset
  } else if (rt_def == "probe_offset_locked") {
    df_thr$rt_model <- df_thr$rt_probe_offset
  } else {
    log_error(paste("Unknown rt_def:", rt_def))
    log_error("Supported: 'cue_locked', 'probe_onset_locked', 'probe_offset_locked'")
    stop("Unknown rt_def")
  }
  
  # Log statistics: post-filter rt_cue and final rt_model
  min_rt_cue <- min(df_thr$rt_cue, na.rm = TRUE)
  median_rt_cue <- median(df_thr$rt_cue, na.rm = TRUE)
  max_rt_cue <- max(df_thr$rt_cue, na.rm = TRUE)
  min_rt_model <- min(df_thr$rt_model, na.rm = TRUE)
  median_rt_model <- median(df_thr$rt_model, na.rm = TRUE)
  max_rt_model <- max(df_thr$rt_model, na.rm = TRUE)
  n_subjects <- length(unique(df_thr$subject_id))
  
  log_info(paste("  Remaining subjects:", n_subjects))
  log_info(paste("  rt_cue (post-filter): min =", round(min_rt_cue, 4), 
                 ", median =", round(median_rt_cue, 4),
                 ", max =", round(max_rt_cue, 4), "s"))
  log_info(paste("  rt_model (", rt_def, "): min =", round(min_rt_model, 4),
                 ", median =", round(median_rt_model, 4),
                 ", max =", round(max_rt_model, 4), "s"))
  log_info(paste("  For threshold", threshold, "s and rt_def", rt_def, ":"))
  log_info(paste("    - N trials after filtering:", n_after_thresh))
  log_info(paste("    - min rt_cue_locked after filtering:", round(min_rt_cue, 4), "s"))
  log_info(paste("    - min final rt used in model:", round(min_rt_model, 4), "s"))
  
  # Check ndt upper bound
  ndt_ub <- min_rt_model - 0.01
  if (ndt_ub <= 0.05) {
    log_error(paste("ndt upper bound too small:", round(ndt_ub, 4), "s"))
    log_error(paste("  min_rt_model =", round(min_rt_model, 4), "s"))
    log_error("  This suggests the threshold is too low or data has very fast RTs")
    stop("ndt upper bound <= 0.05s. Increase threshold or check data quality.")
  }
  
  log_info(paste("  ndt_ub =", round(ndt_ub, 4), "s (min_rt_model - 0.01)"))
  
  return(df_thr)
}

# Create data manifest CSV
create_data_manifest <- function(df_thr, threshold, rt_def, input_file_path) {
  manifest <- data.frame(
    analysis_id = analysis_id,
    input_file = input_file_path,
    threshold = threshold,
    rt_def = rt_def,
    N_trials = nrow(df_thr),
    N_subjects = length(unique(df_thr$subject_id)),
    min_rt_cue = min(df_thr$rt_cue, na.rm = TRUE),
    median_rt_cue = median(df_thr$rt_cue, na.rm = TRUE),
    max_rt_cue = max(df_thr$rt_cue, na.rm = TRUE),
    min_rt_model = min(df_thr$rt_model, na.rm = TRUE),
    median_rt_model = median(df_thr$rt_model, na.rm = TRUE),
    max_rt_model = max(df_thr$rt_model, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
  
  # Save manifest in run-specific directory
  manifest_file <- file.path(MANIFESTS_DIR, paste0("manifest_", 
                                                    formatC(threshold, format="f", digits=2), 
                                                    "_", rt_def, ".csv"))
  write_csv(manifest, manifest_file)
  log_info(paste("  Saved manifest:", manifest_file))
  
  return(manifest)
}

# =========================================================================
# RT MAPPING FUNCTION (for backward compatibility with existing code)
# =========================================================================

# Map rt_type string to actual column name (using standardized column names)
# NOTE: This function now expects data to have rt_model column
map_rt_type_to_column <- function(rt_type, data) {
  # Handle backwards compatibility: "probe_locked" -> "probe_onset_locked"
  if (rt_type == "probe_locked") {
    log_warn("rt_type 'probe_locked' is ambiguous; using 'probe_onset_locked' (rt_cue + 0.35s)")
    rt_type <- "probe_onset_locked"
  }
  
  # Map to rt_model column (which is created by apply_threshold_and_rt_def)
  rt_col <- "rt_model"
  
  # Verify column exists
  if (!rt_col %in% names(data)) {
    log_error(paste("RT column '", rt_col, "' not found in data. Available columns: ", 
                    paste(names(data), collapse = ", ")))
    log_error("Data must be processed with apply_threshold_and_rt_def() first")
    stop("RT column not found")
  }
  
  return(list(rt_type = rt_type, rt_col = rt_col))
}

# =========================================================================
# STEP 1: LOAD DATA AND PREFLIGHT CHECKS
# =========================================================================

set_step("STEP1_LOAD_DATA")

# A) Log unthresholded data path configuration
log_step(paste("Unthresholded data path (DATA_UNTHR):", DATA_UNTHR))
if (file.exists(DATA_UNTHR)) {
  log_step(paste("✓ Unthresholded data file exists:", DATA_UNTHR))
} else {
  log_warn(paste("⚠ Unthresholded data file not found at:", DATA_UNTHR))
  log_warn("Will attempt to find alternative input file...")
}

# Pick input file and load data
input_file <- tryCatch({
  pick_input_file()
}, error = function(e) {
  log_error(e$message)
  stop("Failed to pick input file")
})

# Verify we're using unthresholded data if possible
if (input_file != DATA_UNTHR && file.exists(DATA_UNTHR)) {
  log_warn(paste("⚠ Using input file:", input_file))
  log_warn(paste("⚠ Expected unthresholded data:", DATA_UNTHR))
  log_warn("Sensitivity analysis requires unthresholded data!")
}

df_raw <- tryCatch({
  read_csv(input_file, show_col_types = FALSE)
}, error = function(e) {
  log_error(paste("Failed to read input file:", e$message))
  stop("Failed to read input file")
})

log_info(paste("Raw data loaded:", nrow(df_raw), "trials"))

# Log RT statistics from raw data
if ("rt" %in% names(df_raw)) {
  log_info(paste("Raw rt: min =", round(min(df_raw$rt, na.rm = TRUE), 4),
                 ", max =", round(max(df_raw$rt, na.rm = TRUE), 4), "s"))
}
if ("rt_cue_locked" %in% names(df_raw)) {
  log_info(paste("Raw rt_cue_locked: min =", round(min(df_raw$rt_cue_locked, na.rm = TRUE), 4),
                 ", max =", round(max(df_raw$rt_cue_locked, na.rm = TRUE), 4), "s"))
}
if ("rt_probe_onset_locked" %in% names(df_raw)) {
  log_info(paste("Raw rt_probe_onset_locked: min =", round(min(df_raw$rt_probe_onset_locked, na.rm = TRUE), 4),
                 ", max =", round(max(df_raw$rt_probe_onset_locked, na.rm = TRUE), 4), "s"))
}

# Standardize data format
ddm_data <- tryCatch({
  standardize_ddm_ready(df_raw)
}, error = function(e) {
  log_error(paste("Failed to standardize data:", e$message))
  stop("Failed to standardize data")
})

# Validate data
tryCatch({
  validate_ddm_data(ddm_data)
}, error = function(e) {
  log_error(paste("Preflight validation failed:", e$message))
  stop("Preflight validation failed")
})

# Additional checks for unthresholded data
min_rt_cue <- min(ddm_data$rt_cue, na.rm = TRUE)
log_info(paste("Min rt_cue:", round(min_rt_cue, 4), "s"))

if (min_rt_cue >= 0.20) {
  log_error(paste("Preflight check failed! Min rt_cue (", round(min_rt_cue, 4), 
                  "s) >= 0.20s. This suggests the data was already thresholded."))
  log_error("Sensitivity analysis requires unthresholded data with rt_cue < 0.15s.")
  stop("Preflight check failed: data appears pre-thresholded")
}

if (min_rt_cue >= 0.15) {
  log_warn(paste("Min rt_cue (", round(min_rt_cue, 4), 
                 "s) >= 0.15s. Sensitivity threshold 0.15s will have no effect."))
}

# =========================================================================
# CREATE BASE CLEAN DATASET (no RT threshold applied yet)
# =========================================================================
log_info("Creating base clean dataset (minimal filtering only)...")
n_before_base <- nrow(ddm_data)

# Base clean: remove only negative RTs and invalid choices
ddm_base <- ddm_data %>%
  filter(
    rt_cue > 0,  # Remove negative/zero RTs
    choice_binary %in% c(0L, 1L),  # Valid choices only
    !is.na(subject_id),
    !is.na(task),
    !is.na(effort_condition),
    !is.na(difficulty_3)
  )

n_after_base <- nrow(ddm_base)
n_removed_base <- n_before_base - n_after_base

log_info(paste("Base clean dataset:", n_after_base, "trials (removed", n_removed_base, "invalid trials)"))
log_info(paste("  Removed:", sum(ddm_data$rt_cue <= 0, na.rm = TRUE), "non-positive RTs"))
log_info(paste("  Removed:", sum(!ddm_data$choice_binary %in% c(0L, 1L), na.rm = TRUE), "invalid choices"))

# =========================================================================
# DESCRIPTIVE BEHAVIORAL TABLE (from unthresholded data)
# =========================================================================
log_info("Creating descriptive behavioral table from unthresholded data...")

descriptive_behavioral <- tryCatch({
  # Compute counts per condition
  counts_by_condition <- ddm_base %>%
    group_by(task, effort_condition, difficulty_3) %>%
    summarise(
      n_trials = n(),
      n_subjects = n_distinct(subject_id),
      .groups = "drop"
    )
  
  # Compute choice proportions (same/different)
  choice_props <- ddm_base %>%
    group_by(task, effort_condition, difficulty_3) %>%
    summarise(
      prop_different = mean(choice_binary == 1L, na.rm = TRUE),  # choice_binary == 1 means resp_is_diff == 1 (different)
      prop_same = mean(choice_binary == 0L, na.rm = TRUE),      # choice_binary == 0 means resp_is_diff == 0 (same)
      n_different = sum(choice_binary == 1L, na.rm = TRUE),
      n_same = sum(choice_binary == 0L, na.rm = TRUE),
      .groups = "drop"
    )
  
  # Validation: prop_same + prop_different should equal 1
  stopifnot(all(abs(choice_props$prop_same + choice_props$prop_different - 1) < 1e-8))
  
  # Compute RT quantiles for cue-locked RT
  rt_cue_quantiles <- ddm_base %>%
    group_by(task, effort_condition, difficulty_3) %>%
    summarise(
      rt_cue_min = min(rt_cue, na.rm = TRUE),
      rt_cue_q25 = quantile(rt_cue, 0.25, na.rm = TRUE),
      rt_cue_median = median(rt_cue, na.rm = TRUE),
      rt_cue_q75 = quantile(rt_cue, 0.75, na.rm = TRUE),
      rt_cue_max = max(rt_cue, na.rm = TRUE),
      .groups = "drop"
    )
  
  # Compute RT quantiles for probe-onset-locked RT
  rt_probe_quantiles <- ddm_base %>%
    group_by(task, effort_condition, difficulty_3) %>%
    summarise(
      rt_probe_onset_min = min(rt_probe_onset, na.rm = TRUE),
      rt_probe_onset_q25 = quantile(rt_probe_onset, 0.25, na.rm = TRUE),
      rt_probe_onset_median = median(rt_probe_onset, na.rm = TRUE),
      rt_probe_onset_q75 = quantile(rt_probe_onset, 0.75, na.rm = TRUE),
      rt_probe_onset_max = max(rt_probe_onset, na.rm = TRUE),
      .groups = "drop"
    )
  
  # Combine all tables
  descriptive_df <- counts_by_condition %>%
    left_join(choice_props, by = c("task", "effort_condition", "difficulty_3")) %>%
    left_join(rt_cue_quantiles, by = c("task", "effort_condition", "difficulty_3")) %>%
    left_join(rt_probe_quantiles, by = c("task", "effort_condition", "difficulty_3")) %>%
    arrange(task, effort_condition, difficulty_3)
  
  # Add metadata
  descriptive_df$data_source <- "ddm_ready_data_unthresholded.csv"
  descriptive_df$run_id <- analysis_id
  
  descriptive_df
}, error = function(e) {
  log_warn(paste("Failed to create descriptive behavioral table:", e$message))
  return(data.frame())
})

if (nrow(descriptive_behavioral) > 0) {
  descriptive_file <- file.path(TABLES_DIR, "descriptive_behavioral_by_condition.csv")
  write_csv(descriptive_behavioral, descriptive_file)
  log_info(paste("Saved descriptive behavioral table:", descriptive_file))
  log_info(paste("  Rows:", nrow(descriptive_behavioral), "(Task × Effort × Difficulty combinations)"))
} else {
  log_warn("descriptive_behavioral is empty; skipping export")
}

# Verify probe timing offset
delta_probe <- ddm_base$rt_probe_onset - ddm_base$rt_cue
median_delta <- median(delta_probe, na.rm = TRUE)
if (abs(median_delta - PROBE_ONSET_TO_PROMPT_SEC) > 0.01) {
  log_warn(paste("WARNING: Probe timing offset differs from expected 0.35s"))
  log_warn(paste("  Median offset:", round(median_delta, 4), "s (expected:", PROBE_ONSET_TO_PROMPT_SEC, "s)"))
  log_warn(paste("  Range:", round(min(delta_probe, na.rm = TRUE), 4), "to", round(max(delta_probe, na.rm = TRUE), 4), "s"))
} else {
  log_info(paste("✓ Verified probe timing offset:", round(median_delta, 4), "s"))
}

# Log RT quantiles from base clean dataset
rt_quantiles <- quantile(ddm_base$rt_cue, probs = c(0, 0.001, 0.01, 0.05, 0.10, 0.50, 0.90, 0.95, 0.99, 1), na.rm = TRUE)
log_info("RT quantiles (rt_cue, seconds) from base clean dataset:")
for (i in seq_along(rt_quantiles)) {
  log_info(paste("  ", names(rt_quantiles)[i], "=", round(rt_quantiles[i], 4), "s"))
}

# Count trials below thresholds (from base clean dataset)
log_info("Trials below thresholds (from base clean dataset):")
for (thresh in SENSITIVITY_THRESHOLDS) {
  n_below <- sum(ddm_base$rt_cue < thresh, na.rm = TRUE)
  pct_below <- 100 * n_below / nrow(ddm_base)
  log_info(paste("  rt_cue <", thresh, "s:", n_below, "trials (", round(pct_below, 2), "%)"))
}

# Store base clean dataset for sensitivity analysis
# NOTE: ddm_data will continue to be used for main analysis (backward compatibility)
# but sensitivity analysis should use ddm_base

# Check subjects with low trial counts
set_step("STEP1_TRIAL_COUNTS")
trial_counts <- ddm_data %>%
  group_by(subject_id) %>%
  summarise(n_trials = n(), .groups = "drop")
low_trial_subjects <- trial_counts %>% filter(n_trials < MIN_TRIALS_PER_SUBJECT)
if (nrow(low_trial_subjects) > 0) {
  log_warn(paste("Found", nrow(low_trial_subjects), 
                  "subjects with <", MIN_TRIALS_PER_SUBJECT, "trials after filtering"))
  log_warn("Subjects with low trial counts:")
  for (i in 1:min(10, nrow(low_trial_subjects))) {
    log_warn(paste("  Subject", low_trial_subjects$subject_id[i], ":", 
                   low_trial_subjects$n_trials[i], "trials"))
  }
  if (nrow(low_trial_subjects) > 10) {
    log_warn(paste("  ... and", nrow(low_trial_subjects) - 10, "more"))
  }
} else {
  log_info(paste("✓ All subjects have >=", MIN_TRIALS_PER_SUBJECT, "trials"))
}

log_info("")

# =========================================================================
# STEP 2: DEFINE MODEL SPECIFICATIONS
# =========================================================================

set_step("STEP2_MODEL_SPEC")
log_info(paste("RT constants: GripRelaxTime =", GRIP_RELAX_TIME, "s, ProbeDuration =", PROBE_DURATION, "s"))
log_info(paste("MCMC settings: chains =", N_CHAINS, ", iter =", N_ITER, ", warmup =", N_WARMUP))
log_info("Backend: cmdstanr")
log_info("Seed: (default)")
log_info("")

# Standardized priors for older adults + response-gated design
# IMPORTANT: Different NDT priors for cue-locked vs probe-onset-locked RT
# Cue-locked RT: ndt reflects motor + residual gating (~0.05-0.15s)
# Probe-onset-locked RT: ndt can be larger (~0.30-0.40s) because delay was added back

# Base priors for CUE-LOCKED RT (post-prompt)
create_base_priors_cuelocked <- function(ndt_ub) {
  ndt_ub_val <- as.numeric(ndt_ub)
  c(
    prior(normal(0, 1), class = "Intercept"),
    prior(normal(log(1.3), 0.25), class = "Intercept", dpar = "bs", 
          lb = log(0.3), ub = log(5)),
    eval(substitute(
      prior(normal(log(0.10), 0.15), class = "Intercept", dpar = "ndt",
            lb = log(0.02), ub = UB_VAL),
      list(UB_VAL = ndt_ub_val)
    )),
    prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
    prior(exponential(5), class = "sd"),
    if (USE_BS_RANDOM_EFFECTS) prior(exponential(10), class = "sd", dpar = "bs") else NULL,
    prior(exponential(5), class = "sd", dpar = "bias")
  )
}

# Base priors for PROBE-ONSET-LOCKED RT (RT + 0.35s)
create_base_priors_probeonsetlocked <- function(ndt_ub) {
  ndt_ub_val <- as.numeric(ndt_ub)
  c(
    prior(normal(0, 1), class = "Intercept"),
    prior(normal(log(1.3), 0.25), class = "Intercept", dpar = "bs",
          lb = log(0.3), ub = log(5)),
    eval(substitute(
      prior(normal(log(0.35), 0.15), class = "Intercept", dpar = "ndt",
            lb = log(0.02), ub = UB_VAL),
      list(UB_VAL = ndt_ub_val)
    )),
    prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
    prior(exponential(5), class = "sd"),
    if (USE_BS_RANDOM_EFFECTS) prior(exponential(10), class = "sd", dpar = "bs") else NULL,
    prior(exponential(5), class = "sd", dpar = "bias")
  )
}

# Priors for models with predictors (cue-locked)
# Note: bias formula includes task + effort_condition, so we need priors for those
create_priors_with_predictors_cuelocked <- function(ndt_ub) {
  c(
    create_base_priors_cuelocked(ndt_ub = ndt_ub),
    # Drift rate predictors
    prior(normal(0, 0.5), class = "b"),
    # Boundary separation predictors
    prior(normal(0, 0.20), class = "b", dpar = "bs"),
    # Bias predictors (task + effort_condition)
    prior(normal(0, 0.5), class = "b", dpar = "bias")
  )
}

# Priors for models with predictors (probe-onset-locked)
# Note: bias formula includes task + effort_condition, so we need priors for those
create_priors_with_predictors_probeonsetlocked <- function(ndt_ub) {
  c(
    create_base_priors_probeonsetlocked(ndt_ub = ndt_ub),
    # Drift rate predictors
    prior(normal(0, 0.5), class = "b"),
    # Boundary separation predictors
    prior(normal(0, 0.20), class = "b", dpar = "bs"),
    # Bias predictors (task + effort_condition)
    prior(normal(0, 0.5), class = "b", dpar = "bias")
  )
}

# Model formulas
# Causal logic: 
# - Bias (starting point) can depend on pre-trial factors: task, effort_condition
# - Bias CANNOT depend on difficulty_level (unknown before evidence accumulation)
# - NDT is intercept-only for stability (response-signal design)

bs_baseline_formula <- if (USE_BS_RANDOM_EFFECTS) {
  as.formula("bs ~ 1 + (1 | subject_id)")
} else {
  as.formula("bs ~ 1")
}

# Baseline: intercept-only drift, bias depends on task + effort (pre-trial factors)
formula_baseline <- bf(
  rt | dec(choice_binary) ~ 1 + (1 | subject_id),
  bs_baseline_formula,
  ndt ~ 1,  # Intercept-only: NDT typically fixed for stability in response-signal designs
  bias ~ task + effort_condition + (1 | subject_id)  # Pre-trial factors only (no difficulty)
)

bs_additive_formula <- if (USE_BS_RANDOM_EFFECTS) {
  as.formula("bs ~ 1 + effort_condition + difficulty_3 + (1 | subject_id)")
} else {
  as.formula("bs ~ 1 + effort_condition + difficulty_3")
}

# Additive: drift depends on effort + difficulty (evidence), bias depends on task + effort (pre-trial)
# IMPORTANT: bias does NOT include difficulty (unknown before evidence accumulation)
formula_additive <- bf(
  rt | dec(choice_binary) ~ 1 + effort_condition + difficulty_3 + (1 | subject_id),
  bs_additive_formula,
  ndt ~ 1,  # Intercept-only: NDT typically fixed for stability in response-signal designs
  bias ~ task + effort_condition + (1 | subject_id)  # Pre-trial factors only (NO difficulty)
)

cat("  Model specifications defined\n\n")

# Log final formulas for verification
cat("  Final model formulas:\n")
cat("  ---------------------\n")
cat("  Baseline model:\n")
cat("    Drift (v): rt | dec(choice_binary) ~ 1 + (1 | subject_id)\n")
cat("    Boundary (bs):", deparse(bs_baseline_formula), "\n")
cat("    NDT (t0): ndt ~ 1\n")
cat("    Bias (z): bias ~ task + effort_condition + (1 | subject_id)\n")
cat("\n  Additive model:\n")
cat("    Drift (v): rt | dec(choice_binary) ~ 1 + effort_condition + difficulty_3 + (1 | subject_id)\n")
cat("    Boundary (bs):", deparse(bs_additive_formula), "\n")
cat("    NDT (t0): ndt ~ 1\n")
cat("    Bias (z): bias ~ task + effort_condition + (1 | subject_id)\n")
cat("\n  Note: Bias excludes difficulty_3 (unknown before evidence accumulation)\n")
cat("        NDT is intercept-only for stability in response-signal designs\n\n")

# Helper function to check priors match model and log formula
check_priors_match <- function(formula, data, priors, family, model_name) {
  cat("  Checking priors for", model_name, "...\n")
  
  # Log the actual formula structure
  cat("    Formula structure:\n")
  cat("      Drift:", deparse(formula$formula), "\n")
  if (!is.null(formula$pforms)) {
    for (dpar in names(formula$pforms)) {
      cat("      ", dpar, ":", deparse(formula$pforms[[dpar]]), "\n")
    }
  }
  
  tryCatch({
    gp <- get_prior(formula = formula, data = data, family = family)
    cat("    Parameters expected by model:\n")
    print(gp[, c("prior", "class", "coef", "dpar")])
    cat("    Priors being used:\n")
    print(priors)
    cat("\n")
  }, error = function(e) {
    cat("    WARNING: Could not check priors:", e$message, "\n")
    cat("    Proceeding anyway...\n\n")
  })
}

# =========================================================================
# STEP 3: FIT PRIMARY MODELS (CUE-LOCKED VS PROBE-ONSET-LOCKED RT)
# =========================================================================

cat("STEP 3: Fitting primary models (comparing RT definitions)...\n\n")

# Optional: Smoke test
if (!DRY_RUN) {
  log_info("Running smoke test (fixed-effects-only)...")
  formula_smoke <- bf(
    rt | dec(choice_binary) ~ 1,
    bs ~ 1,
    ndt ~ 1,
    bias ~ 1
  )
  
  # Apply threshold for smoke test using rt_cue (standardized column name)
  # Use apply_rt_filters to ensure consistent filtering
  data_smoke_raw <- apply_rt_filters(ddm_data, rt_floor = CHOSEN_THRESHOLD, rt_ceiling = 3.0)
  data_smoke <- data_smoke_raw %>%
    slice_sample(n = min(1000, nrow(.)))
  
  # For smoke test, use rt_cue directly (no rt_model needed for simple test)
  # But brms formula expects 'rt', so we need to create it
  data_smoke$rt <- data_smoke$rt_cue
  
  min_rt_smoke <- min(data_smoke$rt, na.rm = TRUE)
  ndt_ub_smoke <- as.numeric(log(max(min_rt_smoke - 0.01, 0.05)))
  
  log_info(paste("Smoke test: min RT =", round(min_rt_smoke, 3), "s, NDT ub =", round(exp(ndt_ub_smoke), 3), "s"))
  log_info(paste("Smoke test: N trials =", nrow(data_smoke)))
  
  priors_smoke <- c(
    prior(normal(0, 1), class = "Intercept"),
    prior(normal(log(1.3), 0.25), class = "Intercept", dpar = "bs", 
          lb = log(0.3), ub = log(5)),
    eval(substitute(
      prior(normal(log(0.10), 0.15), class = "Intercept", dpar = "ndt",
            lb = log(0.02), ub = UB_VAL),
      list(UB_VAL = ndt_ub_smoke)
    )),
    prior(normal(0, 0.5), class = "Intercept", dpar = "bias")
  )
  
  smoke_test <- tryCatch({
    brm(
      formula = formula_smoke,
      data = data_smoke,
      family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
      prior = priors_smoke,
      chains = 2,
      iter = 400,
      warmup = 200,
      cores = 2,
      init = 0,
      control = list(adapt_delta = 0.99, max_treedepth = 15),
      backend = "cmdstanr",
      refresh = 50,
      silent = 2
    )
  }, error = function(e) {
    log_error(paste("SMOKE TEST FAILED:", e$message))
    return(NULL)
  })
  
  if (!is.null(smoke_test)) {
    log_info("✓ Smoke test passed")
    log_info("")
  } else {
    log_error("Smoke test failed; aborting pipeline.")
    stop("Smoke test failed; aborting pipeline.")
  }
  
  if (DEBUG_QUICK) {
    log_info("DEBUG_QUICK enabled: stopping after smoke test.")
    stop("DEBUG_QUICK enabled: stopping after smoke test.")
  }
}

# Track model fit statuses for run report
model_fit_status <- list()

# Helper function to log pre-fit statistics
log_prefit_stats <- function(data_fit, threshold, rt_def, model_name) {
  log_info("=== Pre-fit Statistics ===")
  log_info(paste("Model:", model_name))
  log_info(paste("Threshold:", threshold, "s"))
  log_info(paste("RT definition:", rt_def))
  log_info(paste("N trials:", nrow(data_fit)))
  log_info(paste("N subjects:", length(unique(data_fit$subject_id))))
  
  # RT statistics
  if ("rt_cue" %in% names(data_fit)) {
    log_info(paste("rt_cue: min =", round(min(data_fit$rt_cue, na.rm = TRUE), 4),
                   ", median =", round(median(data_fit$rt_cue, na.rm = TRUE), 4),
                   ", max =", round(max(data_fit$rt_cue, na.rm = TRUE), 4), "s"))
  }
  if ("rt_model" %in% names(data_fit)) {
    log_info(paste("rt_model: min =", round(min(data_fit$rt_model, na.rm = TRUE), 4),
                   ", median =", round(median(data_fit$rt_model, na.rm = TRUE), 4),
                   ", max =", round(max(data_fit$rt_model, na.rm = TRUE), 4), "s"))
  }
  
  # Counts by difficulty_3
  if ("difficulty_3" %in% names(data_fit)) {
    diff_counts <- table(data_fit$difficulty_3)
    log_info("Counts by difficulty_3:")
    for (i in seq_along(diff_counts)) {
      log_info(paste("  ", names(diff_counts)[i], ":", diff_counts[i]))
    }
  }
  
  # Counts by task × effort
  if ("task" %in% names(data_fit) && "effort_condition" %in% names(data_fit)) {
    task_effort_counts <- data_fit %>%
      group_by(task, effort_condition) %>%
      summarise(n = n(), .groups = "drop")
    log_info("Counts by task × effort_condition:")
    for (i in 1:nrow(task_effort_counts)) {
      log_info(paste("  ", task_effort_counts$task[i], "×", 
                     task_effort_counts$effort_condition[i], ":", 
                     task_effort_counts$n[i]))
    }
  }
  log_info("========================")
}

# Fit model function with enhanced error handling and logging
fit_model <- function(formula, data, rt_col, model_name, rt_type, use_predictors = FALSE, threshold = NA_real_) {
  set_step(paste("FIT_MODEL", model_name, rt_type))
  
  # Extract threshold from data if not provided
  if (is.na(threshold)) {
    # Try to infer from data (look for threshold in apply_threshold_and_rt_def output)
    threshold <- CHOSEN_THRESHOLD  # Default fallback
  }
  
  # Log pre-fit statistics
  log_prefit_stats(data, threshold, rt_type, model_name)
  
  log_info(paste("Fitting", model_name, "with", rt_type, "RT..."))
  
  # Data should already have rt_model column from apply_threshold_and_rt_def
  # Rename to 'rt' for brms formula
  data_fit <- data %>%
    mutate(rt = !!sym(rt_col)) %>%
    filter(!is.na(rt), rt > 0)
  
  min_rt_model <- min(data_fit$rt, na.rm = TRUE)
  ndt_ub_val <- min_rt_model - 0.01
  
  # Guard: ensure ndt_ub is reasonable
  if (ndt_ub_val <= 0.05) {
    log_error(paste("ndt upper bound too small:", round(ndt_ub_val, 4), "s"))
    log_error(paste("  min_rt_model =", round(min_rt_model, 4), "s"))
    stop("ndt upper bound <= 0.05s. This should have been caught earlier.")
  }
  
  ndt_ub <- as.numeric(log(ndt_ub_val))
  
  log_info(paste("Min rt_model:", round(min_rt_model, 3), "s"))
  log_info(paste("NDT upper bound:", round(ndt_ub_val, 3), "s (log scale:", round(ndt_ub, 4), ")"))
  
  is_cuelocked <- (rt_type == "cue_locked")
  
  # Create priors
  if (is_cuelocked) {
    if (use_predictors) {
      priors <- create_priors_with_predictors_cuelocked(ndt_ub = ndt_ub)
    } else {
      priors <- create_base_priors_cuelocked(ndt_ub = ndt_ub)
    }
  } else {
    if (use_predictors) {
      priors <- create_priors_with_predictors_probeonsetlocked(ndt_ub = ndt_ub)
    } else {
      priors <- create_base_priors_probeonsetlocked(ndt_ub = ndt_ub)
    }
  }
  
  log_info(paste("NDT upper bound (log scale):", round(ndt_ub, 4)))
  check_priors_match(formula, data_fit, priors, 
                     wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
                     paste0(model_name, "_", rt_type))
  
  if (DRY_RUN) {
    log_info("[DRY RUN] Skipping model fit")
    model_fit_status[[paste0(model_name, "_", rt_type)]] <<- list(
      status = "SKIPPED_DRY_RUN",
      model_name = model_name,
      rt_type = rt_type,
      error = NA_character_
    )
    return(NULL)
  }
  
  safe_init <- function(chain_id = 1) {
    if (is_cuelocked) {
      ndt_init <- log(0.08)
    } else {
      ndt_init <- log(0.30)
    }
    
    init_vals <- list(
      Intercept = 0,
      Intercept_bs = log(1.3),
      Intercept_ndt = ndt_init,
      Intercept_bias = 0,
      sd_subject_id__Intercept = INIT_SD,
      sd_subject_id__bias_Intercept = INIT_SD
    )
    
    # Add bias fixed effects (task + effort_condition)
    # Note: brms will create these automatically based on formula, but we can initialize them
    # The actual parameter names depend on factor levels, so we let brms handle it
    
    if (USE_BS_RANDOM_EFFECTS) {
      init_vals$sd_subject_id__bs_Intercept <- INIT_SD
    }
    
    init_vals
  }
  
  # Determine init strategy
  init_strategy <- if (INIT_ZERO) {
    0
  } else if (USE_SAFE_INIT) {
    safe_init
  } else {
    0
  }
  
  # Track warnings
  all_warnings <- character(0)
  bs_inf_warnings <- character(0)
  warning_handler <- function(w) {
    # Log all warnings
    log_warn(paste("Warning during model fit:", w$message))
    all_warnings <<- c(all_warnings, w$message)
    
    # Track bs=inf warnings separately
    if (grepl("boundary separation is inf", w$message, ignore.case = TRUE)) {
      bs_inf_warnings <<- c(bs_inf_warnings, w$message)
    }
  }
  
  # Record start time
  fit_start_time <- Sys.time()
  
  # Determine output path
  # Model file naming: <model_name>__<rt_def>__thr<thr>.rds
  output_rds_path <- file.path(MODELS_DIR, paste0(model_name, "__", rt_type, "__thr", 
                                                    formatC(threshold, format="f", digits=2), ".rds"))
  
  fit <- tryCatch({
    withCallingHandlers({
      brm(
        formula = formula,
        data = data_fit,
        family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
        prior = priors,
        chains = N_CHAINS,
        iter = N_ITER,
        warmup = N_WARMUP,
        cores = N_CHAINS,
        init = init_strategy,
        control = list(adapt_delta = ADAPT_DELTA, max_treedepth = MAX_TREEDEPTH),
        backend = "cmdstanr",
        file = output_rds_path,
        file_refit = "on_change",
        refresh = 100,
        silent = 0
      )
    }, warning = warning_handler)
  }, error = function(e) {
    error_msg <- e$message
    log_error(paste("ERROR:", error_msg))
    log_error("=")
    log_error("MODEL FIT FAILED")
    log_error(paste("Model:", model_name))
    log_error(paste("RT definition:", rt_type))
    log_error(paste("Error:", error_msg))
    log_error("=")
    
    model_fit_status[[paste0(model_name, "_", rt_type)]] <<- list(
      status = "FAILED",
      model_name = model_name,
      rt_type = rt_type,
      error = error_msg
    )
    
    if (!CONTINUE_ON_FAIL) {
      stop("Model fit failed and DDM_CONTINUE_ON_FAIL=0. Aborting pipeline.")
    }
    return(NULL)
  })
  
  # Hard fail check for bs=inf warnings
  if (length(bs_inf_warnings) > 10) {
    log_error("✗ HARD FAIL: Repeated 'boundary separation is inf' warnings detected")
    log_error(paste("Count:", length(bs_inf_warnings), "warnings"))
    log_error("Suggestion: Use stronger sd priors on bs random effects or set USE_BS_RANDOM_EFFECTS=FALSE")
    log_error("Example: prior(exponential(20), class = 'sd', dpar = 'bs')")
    
    model_fit_status[[paste0(model_name, "_", rt_type)]] <<- list(
      status = "FAILED_BS_INF",
      model_name = model_name,
      rt_type = rt_type,
      error = paste("Excessive bs=inf warnings (", length(bs_inf_warnings), ")")
    )
    
    stop("Aborting due to excessive bs=inf warnings. Fix model specification before proceeding.")
  } else if (length(bs_inf_warnings) > 0) {
    log_warn(paste("WARNING: Detected", length(bs_inf_warnings), "'boundary separation is inf' warning(s)"))
    log_warn("If this persists, consider stronger sd priors on bs random effects")
  }
  
  # Record end time and compute elapsed time
  fit_end_time <- Sys.time()
  time_elapsed_sec <- as.numeric(difftime(fit_end_time, fit_start_time, units = "secs"))
  
  if (!is.null(fit)) {
    rhat_vals <- brms::rhat(fit)
    neff_rat <- brms::neff_ratio(fit)
    max_rhat <- suppressWarnings(max(rhat_vals, na.rm = TRUE))
    min_neff_ratio <- suppressWarnings(min(neff_rat, na.rm = TRUE))
    
    # Extract divergences and treedepth hits
    divergences <- tryCatch({
      sampler_params <- brms::nuts_params(fit)
      sum(sampler_params$divergent__ == 1, na.rm = TRUE)
    }, error = function(e) {
      log_warn("Could not extract divergences")
      NA_integer_
    })
    
    n_treedepth <- tryCatch({
      sampler_params <- brms::nuts_params(fit)
      sum(sampler_params$treedepth__ == MAX_TREEDEPTH, na.rm = TRUE)
    }, error = function(e) {
      log_warn("Could not extract treedepth hits")
      NA_integer_
    })
    
    # Extract ESS values
    neff_vals <- brms::neff_ratio(fit)
    total_draws <- N_CHAINS * (N_ITER - N_WARMUP)
    bulk_ess_vals <- neff_vals * total_draws
    min_bulk_ess <- suppressWarnings(min(bulk_ess_vals, na.rm = TRUE))
    min_tail_ess <- min_bulk_ess  # Approximate; brms doesn't easily separate bulk/tail
    
    log_info(paste("Max R-hat:", round(max_rhat, 4)))
    log_info(paste("Min bulk ESS:", ifelse(is.na(min_bulk_ess), "N/A", round(min_bulk_ess))))
    log_info(paste("Min tail ESS:", ifelse(is.na(min_tail_ess), "N/A", round(min_tail_ess))))
    log_info(paste("Number of divergences:", ifelse(is.na(divergences), "0 (or N/A)", as.character(divergences))))
    log_info(paste("Time elapsed:", round(time_elapsed_sec, 2), "seconds"))
    
    if (max_rhat > 1.05) {
      log_warn("WARNING: Convergence issues detected")
      status <- "CONVERGED_WITH_WARNINGS"
    } else {
      log_info("✓ Converged")
      status <- "SUCCESS"
    }
    
    # Add to run_index
    run_index_row <- data.frame(
      analysis_id = analysis_id,
      model_name = model_name,
      threshold = as.numeric(threshold),  # Ensure numeric
      rt_def = rt_type,
      input_file = input_file,
      N_trials = nrow(data_fit),
      N_subjects = length(unique(data_fit$subject_id)),
      min_rt_model = min_rt_model,
      divergences = ifelse(is.na(divergences), 0L, as.integer(divergences)),
      treedepth_hits = ifelse(is.na(n_treedepth), 0L, as.integer(n_treedepth)),
      max_rhat = max_rhat,
      min_bulk_ess = ifelse(is.na(min_bulk_ess), NA_real_, min_bulk_ess),
      min_tail_ess = ifelse(is.na(min_tail_ess), NA_real_, min_tail_ess),
      time_elapsed_sec = time_elapsed_sec,
      output_rds_path = output_rds_path,
      stringsAsFactors = FALSE
    )
    
    # Append to run_index.csv
    if (file.exists(RUN_INDEX_FILE) && file.info(RUN_INDEX_FILE)$size > 0) {
      existing_index <- read_csv(RUN_INDEX_FILE, show_col_types = FALSE)
      # Ensure numeric columns are numeric in both data frames
      numeric_cols <- c("threshold", "N_trials", "N_subjects", "min_rt_model", 
                        "divergences", "treedepth_hits", "max_rhat", "min_bulk_ess", 
                        "min_tail_ess", "time_elapsed_sec")
      for (col in numeric_cols) {
        if (col %in% names(existing_index)) {
          existing_index[[col]] <- as.numeric(existing_index[[col]])
        }
        if (col %in% names(run_index_row)) {
          run_index_row[[col]] <- as.numeric(run_index_row[[col]])
        }
      }
      run_index <- bind_rows(existing_index, run_index_row)
    } else {
      run_index <- run_index_row
    }
    write_csv(run_index, RUN_INDEX_FILE)
    
    model_fit_status[[paste0(model_name, "_", rt_type)]] <<- list(
      status = status,
      model_name = model_name,
      rt_type = rt_type,
      max_rhat = max_rhat,
      min_neff_ratio = min_neff_ratio,
      error = NA_character_
    )
  } else {
    # Failed fit - still add to run_index with error info
          run_index_row <- data.frame(
            analysis_id = analysis_id,
            model_name = model_name,
            threshold = as.numeric(threshold),  # Ensure numeric
            rt_def = rt_type,
            input_file = input_file,
            N_trials = nrow(data_fit),
            N_subjects = length(unique(data_fit$subject_id)),
            min_rt_model = min_rt_model,
            divergences = NA_integer_,
            treedepth_hits = NA_integer_,
            max_rhat = NA_real_,
            min_bulk_ess = NA_real_,
            min_tail_ess = NA_real_,
            time_elapsed_sec = time_elapsed_sec,
            output_rds_path = output_rds_path,
            stringsAsFactors = FALSE
          )
    # Append to run_index.csv
    if (file.exists(RUN_INDEX_FILE) && file.info(RUN_INDEX_FILE)$size > 0) {
      existing_index <- read_csv(RUN_INDEX_FILE, show_col_types = FALSE)
      # Ensure numeric columns are numeric in both data frames
      numeric_cols <- c("threshold", "N_trials", "N_subjects", "min_rt_model", 
                        "divergences", "treedepth_hits", "max_rhat", "min_bulk_ess", 
                        "min_tail_ess", "time_elapsed_sec")
      for (col in numeric_cols) {
        if (col %in% names(existing_index)) {
          existing_index[[col]] <- as.numeric(existing_index[[col]])
        }
        if (col %in% names(run_index_row)) {
          run_index_row[[col]] <- as.numeric(run_index_row[[col]])
        }
      }
      run_index <- bind_rows(existing_index, run_index_row)
    } else {
      run_index <- run_index_row
    }
    write_csv(run_index, RUN_INDEX_FILE)
  }
  
  if (is.null(fit) || !inherits(fit, "brmsfit")) {
    if (!CONTINUE_ON_FAIL) {
      stop("Model fit failed; aborting pipeline.")
    }
  }
  
  return(fit)
}

# Apply chosen threshold for primary fits
set_step("STEP3_PRIMARY_FITS")
log_info(paste("Primary fits using threshold:", CHOSEN_THRESHOLD, "s"))

# Process data for cue_locked RT definition
log_info("Processing data for cue_locked RT definition...")
ddm_data_primary_cue <- apply_threshold_and_rt_def(ddm_data, CHOSEN_THRESHOLD, "cue_locked")
create_data_manifest(ddm_data_primary_cue, CHOSEN_THRESHOLD, "cue_locked", input_file)

# Process data for probe_onset_locked RT definition (same trials, different rt_model)
log_info("Processing data for probe_onset_locked RT definition...")
ddm_data_primary_probe <- apply_threshold_and_rt_def(ddm_data, CHOSEN_THRESHOLD, "probe_onset_locked")
create_data_manifest(ddm_data_primary_probe, CHOSEN_THRESHOLD, "probe_onset_locked", input_file)

# Map RT types to columns (both datasets now have rt_model column)
rt_map_cue <- map_rt_type_to_column("cue_locked", ddm_data_primary_cue)
rt_map_probe <- map_rt_type_to_column("probe_onset_locked", ddm_data_primary_probe)

# Fit baseline models
baseline_cue <- fit_model(
  formula_baseline, ddm_data_primary_cue, rt_map_cue$rt_col, 
  "baseline", rt_map_cue$rt_type, use_predictors = FALSE, threshold = CHOSEN_THRESHOLD
)

baseline_probe <- fit_model(
  formula_baseline, ddm_data_primary_probe, rt_map_probe$rt_col, 
  "baseline", rt_map_probe$rt_type, use_predictors = FALSE, threshold = CHOSEN_THRESHOLD
)

# Fit additive models
additive_cue <- fit_model(
  formula_additive, ddm_data_primary_cue, rt_map_cue$rt_col, 
  "additive", rt_map_cue$rt_type, use_predictors = TRUE, threshold = CHOSEN_THRESHOLD
)

additive_probe <- fit_model(
  formula_additive, ddm_data_primary_probe, rt_map_probe$rt_col, 
  "additive", rt_map_probe$rt_type, use_predictors = TRUE, threshold = CHOSEN_THRESHOLD
)

cat("\n")

# =========================================================================
# STEP 4: MODEL COMPARISON AND DIAGNOSTICS
# =========================================================================

if (!DRY_RUN) {
  cat("STEP 4: Comparing models and extracting diagnostics...\n\n")
  
  extract_model_summary <- function(fit, model_name, rt_type) {
    if (is.null(fit) || !inherits(fit, "brmsfit")) {
      log_warn(paste("extract_model_summary: fit is NULL or not brmsfit for", model_name, rt_type))
      return(NULL)
    }
    
    fixef_summary <- tryCatch({
      brms::fixef(fit, summary = TRUE) %>% as.data.frame()
    }, error = function(e) {
      log_error(paste("Failed to extract fixef for", model_name, rt_type, ":", e$message))
      return(NULL)
    })
    
    if (is.null(fixef_summary)) {
      return(NULL)
    }
    
    fixef_summary$term <- rownames(fixef_summary)
    fixef_summary$model <- model_name
    fixef_summary$rt_type <- rt_type
    
    rhat_vals <- tryCatch(brms::rhat(fit), error = function(e) {
      log_warn(paste("Failed to extract rhat for", model_name, rt_type))
      return(NA_real_)
    })
    neff_rat <- tryCatch(brms::neff_ratio(fit), error = function(e) {
      log_warn(paste("Failed to extract neff_ratio for", model_name, rt_type))
      return(NA_real_)
    })
    
    # Extract diagnostics
    sampler_params <- tryCatch(brms::nuts_params(fit), error = function(e) NULL)
    n_divergent <- if (!is.null(sampler_params)) {
      sum(sampler_params$divergent__ == 1, na.rm = TRUE)
    } else NA_integer_
    
    n_treedepth_hits <- if (!is.null(sampler_params)) {
      sum(sampler_params$treedepth__ == MAX_TREEDEPTH, na.rm = TRUE)
    } else NA_integer_
    
    total_draws <- N_CHAINS * (N_ITER - N_WARMUP)
    bulk_ess_all <- if (!is.null(neff_rat) && !all(is.na(neff_rat))) {
      neff_rat * total_draws
    } else NA_real_
    min_bulk_ess_all <- suppressWarnings(min(bulk_ess_all, na.rm = TRUE))
    min_tail_ess_all <- min_bulk_ess_all  # Approximate
    
    convergence <- data.frame(
      model = model_name,
      rt_type = rt_type,
      max_rhat = suppressWarnings(max(rhat_vals, na.rm = TRUE)),
      min_neff_ratio = suppressWarnings(min(neff_rat, na.rm = TRUE)),
      min_bulk_ess = min_bulk_ess_all,
      min_tail_ess = min_tail_ess_all,
      n_divergent = n_divergent,
      n_treedepth_hits = n_treedepth_hits,
      stringsAsFactors = FALSE
    )
    
    tryCatch({
      loo_result <- brms::loo(fit)
      convergence$loo_ic <- loo_result$estimates["looic", "Estimate"]
      convergence$loo_se <- loo_result$estimates["looic", "SE"]
    }, error = function(e) {
      convergence$loo_ic <- NA_real_
      convergence$loo_se <- NA_real_
    })
    
    return(list(fixef = fixef_summary, convergence = convergence))
  }
  
  summaries <- list()
  if (!is.null(baseline_cue)) {
    summaries[["baseline_cue"]] <- extract_model_summary(baseline_cue, "baseline", rt_map_cue$rt_type)
  }
  if (!is.null(baseline_probe)) {
    summaries[["baseline_probe"]] <- extract_model_summary(baseline_probe, "baseline", rt_map_probe$rt_type)
  }
  if (!is.null(additive_cue)) {
    summaries[["additive_cue"]] <- extract_model_summary(additive_cue, "additive", rt_map_cue$rt_type)
  }
  if (!is.null(additive_probe)) {
    summaries[["additive_probe"]] <- extract_model_summary(additive_probe, "additive", rt_map_probe$rt_type)
  }
  
  if (length(summaries) > 0) {
    fixef_all <- tryCatch({
      bind_rows(lapply(summaries, function(x) if (!is.null(x)) x$fixef else NULL))
    }, error = function(e) {
      log_error(paste("Failed to bind fixef summaries:", e$message))
      return(data.frame())
    })
    
    if (nrow(fixef_all) > 0) {
      fixef_file <- file.path(SUMMARIES_DIR, "ddm_fixef_comparison_rt_definitions.csv")
      write_csv(fixef_all, fixef_file)
      log_info(paste("Saved:", fixef_file))
      
      # Also save to legacy location for backward compatibility
      write_csv(fixef_all, file.path(RESULTS_DIR, "ddm_fixef_comparison_rt_definitions.csv"))
    }
    
    convergence_all <- tryCatch({
      bind_rows(lapply(summaries, function(x) if (!is.null(x)) x$convergence else NULL))
    }, error = function(e) {
      log_error(paste("Failed to bind convergence summaries:", e$message))
      return(data.frame())
    })
    
    if (nrow(convergence_all) > 0) {
      convergence_file <- file.path(SUMMARIES_DIR, "ddm_convergence_comparison.csv")
      write_csv(convergence_all, convergence_file)
      log_info(paste("Saved:", convergence_file))
      
      # Also save to legacy location
      write_csv(convergence_all, file.path(RESULTS_DIR, "ddm_convergence_comparison.csv"))
      
      cat("\n  Convergence comparison:\n")
      print(convergence_all)
    }
  } else {
    log_warn("No model summaries available; skipping comparison files")
  }
  
  # =========================================================================
  # EXPORT QMD-READY CSV FILES
  # =========================================================================
  
  if (exists("summaries") && length(summaries) > 0) {
    log_info("Exporting QMD-ready CSV files...")
    
    # 1. convergence_summary.csv: one row per (model_name, rt_def, threshold)
    convergence_summary_qmd <- tryCatch({
      # Read run_index to get threshold and file paths
      if (file.exists(RUN_INDEX_FILE) && file.info(RUN_INDEX_FILE)$size > 0) {
        run_index_df <- read_csv(RUN_INDEX_FILE, show_col_types = FALSE)
        
        # Merge with convergence data
        # Note: run_index_df has max_rhat and min_bulk_ess, which will conflict with convergence_all
        # After join, dplyr adds .x and .y suffixes - use run_index values (they're the same)
        convergence_with_paths <- convergence_all %>%
          left_join(
            run_index_df %>%
              filter(model_name %in% c("baseline", "additive")) %>%
              select(model_name, rt_def, threshold, N_trials, N_subjects, 
                     divergences, max_rhat, min_bulk_ess, output_rds_path),
            by = c("model" = "model_name", "rt_type" = "rt_def")
          ) %>%
          mutate(
            threshold = ifelse(is.na(threshold), CHOSEN_THRESHOLD, threshold),
            # After join, columns with same name get .x (from convergence_all) and .y (from run_index)
            # Use .y versions (from run_index) since they're the same and we need output_rds_path
            max_rhat_final = ifelse(!is.na(max_rhat.y), max_rhat.y, max_rhat.x),
            min_bulk_ess_final = ifelse(!is.na(min_bulk_ess.y), min_bulk_ess.y, min_bulk_ess.x)
          ) %>%
          select(model_name = model, rt_def = rt_type, threshold, N_trials, N_subjects,
                 max_rhat = max_rhat_final, min_bulk_ess = min_bulk_ess_final, 
                 divergences = n_divergent, output_rds_path)
        
        convergence_with_paths
      } else {
        # Fallback: use convergence_all without paths
        convergence_all %>%
          mutate(threshold = CHOSEN_THRESHOLD) %>%
          select(model_name = model, rt_def = rt_type, threshold,
                 max_rhat, min_bulk_ess, divergences = n_divergent)
      }
    }, error = function(e) {
      log_warn(paste("Failed to create convergence_summary:", e$message))
      return(data.frame())
    })
    
    if (nrow(convergence_summary_qmd) > 0) {
      convergence_qmd_file <- file.path(TABLES_DIR, "convergence_summary.csv")
      write_csv(convergence_summary_qmd, convergence_qmd_file)
      log_info(paste("Saved:", convergence_qmd_file))
    } else {
      log_warn("convergence_summary_qmd is empty; skipping convergence_summary.csv export")
      if (exists("convergence_all")) {
        log_info(paste("convergence_all has", nrow(convergence_all), "rows"))
      }
    }
    
    # 2. loo_summary.csv: loo-ic and loo-se per model
    loo_summary_qmd <- tryCatch({
      convergence_all %>%
        filter(!is.na(loo_ic)) %>%
        select(model_name = model, rt_def = rt_type, loo_ic, loo_se) %>%
        mutate(threshold = CHOSEN_THRESHOLD)
    }, error = function(e) {
      log_warn(paste("Failed to create loo_summary:", e$message))
      return(data.frame())
    })
    
    if (nrow(loo_summary_qmd) > 0) {
      loo_qmd_file <- file.path(TABLES_DIR, "loo_summary.csv")
      write_csv(loo_summary_qmd, loo_qmd_file)
      log_info(paste("Saved:", loo_qmd_file))
    }
    
    # 3. fixef_link_scale.csv: fixed effects on link scale (as brms reports)
    if (exists("fixef_all") && nrow(fixef_all) > 0) {
      fixef_link_file <- file.path(TABLES_DIR, "fixef_link_scale.csv")
      write_csv(fixef_all, fixef_link_file)
      log_info(paste("Saved:", fixef_link_file))
    }
    
    # 4. REMOVED: fixef_natural_scale.csv (incorrect term-by-term transformation)
    # Bias coefficients cannot be transformed term-by-term because they combine additively on logit scale.
    # Use predicted_parameters_by_condition.csv instead for interpretable natural-scale parameters.
    
    # 5. predicted_parameters_by_condition.csv: condition-level predictions on natural scale
    # Use the FINAL chosen model: additive + probe_onset_locked + CHOSEN_THRESHOLD
    predicted_params_qmd <- tryCatch({
      if (exists("additive_probe") && !is.null(additive_probe) && inherits(additive_probe, "brmsfit")) {
        log_info("Computing condition-level predictions from additive_probe model...")
        
        # Create prediction grid: Task × Effort × Difficulty
        pred_grid <- expand.grid(
          task = c("ADT", "VDT"),
          effort_condition = c("low", "high"),
          difficulty_3 = c("Standard", "Hard", "Easy"),
          stringsAsFactors = FALSE
        )
        pred_grid$task <- factor(pred_grid$task, levels = c("ADT", "VDT"))
        pred_grid$effort_condition <- factor(pred_grid$effort_condition, levels = c("low", "high"))
        pred_grid$difficulty_3 <- factor(pred_grid$difficulty_3, levels = c("Standard", "Hard", "Easy"))
        
        # Get posterior draws
        post_draws <- brms::as_draws_df(additive_probe)
        
        # Helper function to compute linear predictor for a condition
        compute_linpred <- function(row, coef_prefix, post_draws) {
          # Start with intercept
          intercept_col <- paste0("b_", coef_prefix, "Intercept")
          if (!intercept_col %in% names(post_draws)) {
            return(rep(NA_real_, nrow(post_draws)))
          }
          linpred <- post_draws[[intercept_col]]
          
          # Add task effect (VDT vs ADT)
          task_col <- paste0("b_", coef_prefix, "taskVDT")
          if (row$task == "VDT" && task_col %in% names(post_draws)) {
            linpred <- linpred + post_draws[[task_col]]
          }
          
          # Add effort effect (high vs low)
          effort_col <- paste0("b_", coef_prefix, "effort_conditionhigh")
          if (row$effort_condition == "high" && effort_col %in% names(post_draws)) {
            linpred <- linpred + post_draws[[effort_col]]
          }
          
          # Add difficulty effects (for drift and boundary separation, not bias)
          # Bias does not vary by difficulty because trials are randomized
          if ((coef_prefix == "" || coef_prefix == "bs_") && row$difficulty_3 != "Standard") {
            if (row$difficulty_3 == "Hard") {
              diff_col <- paste0("b_", coef_prefix, "difficulty_3Hard")
              if (diff_col %in% names(post_draws)) {
                linpred <- linpred + post_draws[[diff_col]]
              }
            } else if (row$difficulty_3 == "Easy") {
              diff_col <- paste0("b_", coef_prefix, "difficulty_3Easy")
              if (diff_col %in% names(post_draws)) {
                linpred <- linpred + post_draws[[diff_col]]
              }
            }
          }
          
          return(linpred)
        }
        
        # Get metadata for this model
        model_name_val <- "additive"
        rt_def_val <- rt_map_probe$rt_type  # "probe_onset_locked"
        threshold_val <- CHOSEN_THRESHOLD
        run_id_val <- analysis_id
        
        # Log model file used (if saved)
        model_file_name <- paste0("additive__", rt_def_val, "__thr", formatC(threshold_val, format="f", digits=2), ".rds")
        model_file_path <- file.path(MODELS_DIR, model_file_name)
        if (file.exists(model_file_path)) {
          log_info(paste("Using model file:", model_file_name))
        } else {
          log_info(paste("Model file not yet saved (will be:", model_file_name, ")"))
        }
        
        # Compute predictions for each condition
        pred_results <- list()
        for (i in 1:nrow(pred_grid)) {
          row <- pred_grid[i, ]
          
          # Drift (v): identity link
          v_draws <- compute_linpred(row, "", post_draws)
          
          # Boundary separation (a): exp(bs)
          bs_linpred <- compute_linpred(row, "bs_", post_draws)
          a_draws <- exp(bs_linpred)
          
          # Non-decision time (t0): exp(ndt)
          ndt_linpred <- compute_linpred(row, "ndt_", post_draws)
          t0_draws <- exp(ndt_linpred)
          
          # Starting point bias (z): inv_logit(bias)
          bias_linpred <- compute_linpred(row, "bias_", post_draws)
          z_draws <- plogis(bias_linpred)
          
          # Summarize draws
          pred_results[[i]] <- data.frame(
            model_name = model_name_val,
            rt_def = rt_def_val,
            threshold = threshold_val,
            run_id = run_id_val,
            task = as.character(row$task),
            effort_condition = as.character(row$effort_condition),
            difficulty_3 = as.character(row$difficulty_3),
            v_median = median(v_draws, na.rm = TRUE),
            v_q2.5 = quantile(v_draws, 0.025, na.rm = TRUE),
            v_q97.5 = quantile(v_draws, 0.975, na.rm = TRUE),
            a_median = median(a_draws, na.rm = TRUE),
            a_q2.5 = quantile(a_draws, 0.025, na.rm = TRUE),
            a_q97.5 = quantile(a_draws, 0.975, na.rm = TRUE),
            t0_median = median(t0_draws, na.rm = TRUE),
            t0_q2.5 = quantile(t0_draws, 0.025, na.rm = TRUE),
            t0_q97.5 = quantile(t0_draws, 0.975, na.rm = TRUE),
            z_median = median(z_draws, na.rm = TRUE),
            z_q2.5 = quantile(z_draws, 0.025, na.rm = TRUE),
            z_q97.5 = quantile(z_draws, 0.975, na.rm = TRUE),
            stringsAsFactors = FALSE
          )
        }
        
        bind_rows(pred_results)
      } else {
        log_warn("additive_probe model not available for condition-level predictions")
        data.frame()
      }
    }, error = function(e) {
      log_warn(paste("Failed to create predicted_parameters_by_condition:", e$message))
      return(data.frame())
    })
    
    if (nrow(predicted_params_qmd) > 0) {
      # =====================================================================
      # VALIDATION: Verify predicted parameters match model specification
      # =====================================================================
      log_info("Validating predicted_parameters_by_condition.csv...")
      
      # A. Structure checks
      expected_rows <- 2 * 2 * 3  # 2 tasks × 2 effort × 3 difficulty = 12
      if (nrow(predicted_params_qmd) != expected_rows) {
        log_error(paste("VALIDATION FAILED: Expected", expected_rows, "rows, got", nrow(predicted_params_qmd)))
        stop("predicted_params_qmd has wrong number of rows")
      }
      
      req_cols <- c("task", "effort_condition", "difficulty_3",
                    "v_median", "v_q2.5", "v_q97.5",
                    "a_median", "a_q2.5", "a_q97.5",
                    "t0_median", "t0_q2.5", "t0_q97.5",
                    "z_median", "z_q2.5", "z_q97.5")
      missing <- setdiff(req_cols, names(predicted_params_qmd))
      if (length(missing) > 0) {
        log_error(paste("VALIDATION FAILED: Missing columns:", paste(missing, collapse = ", ")))
        stop("predicted_params_qmd missing required columns")
      }
      
      # Quantile ordering checks
      check_q <- function(med, lo, hi, name) {
        bad <- which(!(lo <= med & med <= hi))
        if (length(bad) > 0) {
          log_error(paste("VALIDATION FAILED: Quantile ordering failed for", name, "in rows:", paste(bad, collapse = ", ")))
          stop(paste("Quantile ordering failed for", name))
        }
      }
      check_q(predicted_params_qmd$v_median,  predicted_params_qmd$v_q2.5,  predicted_params_qmd$v_q97.5,  "v")
      check_q(predicted_params_qmd$a_median,  predicted_params_qmd$a_q2.5,  predicted_params_qmd$a_q97.5,  "a")
      check_q(predicted_params_qmd$t0_median, predicted_params_qmd$t0_q2.5, predicted_params_qmd$t0_q97.5, "t0")
      check_q(predicted_params_qmd$z_median,  predicted_params_qmd$z_q2.5,  predicted_params_qmd$z_q97.5,  "z")
      
      # B. Design-consistency checks
      # 1. Boundary separation MUST vary by difficulty within effort
      a_var <- predicted_params_qmd %>%
        dplyr::group_by(effort_condition) %>%
        dplyr::summarise(n = dplyr::n_distinct(a_median), .groups = "drop")
      if (any(a_var$n <= 1)) {
        log_error(paste("VALIDATION FAILED: a_median does not vary by difficulty within effort:", 
                        paste(a_var$effort_condition[a_var$n <= 1], collapse = ", ")))
        stop("Boundary separation does not vary by difficulty - prediction bug!")
      }
      log_info(paste("  ✓ Boundary separation varies by difficulty (low effort:", 
                     a_var$n[a_var$effort_condition == "low"], "unique values; high effort:", 
                     a_var$n[a_var$effort_condition == "high"], "unique values)"))
      
      # 2. Bias must NOT vary by difficulty within task×effort
      z_var <- predicted_params_qmd %>%
        dplyr::group_by(task, effort_condition) %>%
        dplyr::summarise(n = dplyr::n_distinct(z_median), .groups = "drop")
      if (any(z_var$n != 1)) {
        log_error(paste("VALIDATION FAILED: z_median varies by difficulty (should not):", 
                        paste(paste(z_var$task[z_var$n != 1], z_var$effort_condition[z_var$n != 1], sep = "×"), 
                              collapse = ", ")))
        stop("Bias varies by difficulty - violates model specification!")
      }
      log_info("  ✓ Bias does not vary by difficulty (as expected)")
      
      # 3. v/a/t0 must be identical across tasks (task not in these formulas)
      tol <- 1e-8
      wide <- predicted_params_qmd %>%
        dplyr::select(task, effort_condition, difficulty_3, v_median, a_median, t0_median) %>%
        tidyr::pivot_wider(names_from = task, values_from = c(v_median, a_median, t0_median))
      
      v_diff <- abs(wide$v_median_ADT - wide$v_median_VDT)
      a_diff <- abs(wide$a_median_ADT - wide$a_median_VDT)
      t0_diff <- abs(wide$t0_median_ADT - wide$t0_median_VDT)
      
      if (any(v_diff > tol)) {
        log_error(paste("VALIDATION FAILED: v differs by task (max diff:", max(v_diff), ") but should not"))
        stop("Drift rate differs by task - violates model specification!")
      }
      if (any(a_diff > tol)) {
        log_error(paste("VALIDATION FAILED: a differs by task (max diff:", max(a_diff), ") but should not"))
        stop("Boundary separation differs by task - violates model specification!")
      }
      if (any(t0_diff > tol)) {
        log_error(paste("VALIDATION FAILED: t0 differs by task (max diff:", max(t0_diff), ") but should not"))
        stop("Non-decision time differs by task - violates model specification!")
      }
      log_info("  ✓ v/a/t0 are identical across tasks (as expected)")
      
      log_info("✓ All validations passed")
      
      predicted_params_file <- file.path(TABLES_DIR, "predicted_parameters_by_condition.csv")
      write_csv(predicted_params_qmd, predicted_params_file)
      log_info(paste("Saved:", predicted_params_file))
    } else {
      log_warn("predicted_params_qmd is empty; skipping predicted_parameters_by_condition.csv export")
    }
  }
}

# =========================================================================
# STEP 5: SENSITIVITY ANALYSIS ACROSS THRESHOLDS
# =========================================================================

cat("\nSTEP 5: Running sensitivity analysis across thresholds...\n\n")

# Create thresholded datasets for sensitivity analysis
set_step("STEP5_SENSITIVITY")

# A) Resolve unthresholded data path (use input_file if DATA_UNTHR missing; try fallbacks)
data_unthr_resolved <- NULL
if (file.exists(DATA_UNTHR)) {
  data_unthr_resolved <- DATA_UNTHR
} else if (exists("input_file") && !is.null(input_file) && file.exists(input_file)) {
  log_warn(paste("DATA_UNTHR not found at", DATA_UNTHR, "- using input_file:", input_file))
  data_unthr_resolved <- input_file
} else {
  for (c in input_file_candidates) {
    if (file.exists(c)) {
      log_warn(paste("Using fallback:", c))
      data_unthr_resolved <- c
      break
    }
  }
}
if (is.null(data_unthr_resolved) || !file.exists(data_unthr_resolved)) {
  log_error(paste("Unthresholded data file not found. Tried:", DATA_UNTHR, "and input_file"))
  stop("Unthresholded data file required for sensitivity analysis. Ensure data/ddm_ready_data_unthresholded.csv exists.")
}
log_step(paste("Loading unthresholded data from:", data_unthr_resolved))
log_step(paste("✓ Unthresholded data file exists:", data_unthr_resolved))

# Log min RT from unthresholded data (for sanity checks)
min_rt_unthr_cue <- min(ddm_base$rt_cue, na.rm = TRUE)
min_rt_unthr_probe <- if ("rt_probe_onset" %in% names(ddm_base)) {
  min(ddm_base$rt_probe_onset, na.rm = TRUE)
} else {
  NA_real_
}
log_step(paste("Min rt_cue in unthresholded data:", round(min_rt_unthr_cue, 4), "s"))
if (!is.na(min_rt_unthr_probe)) {
  log_step(paste("Min rt_probe_onset in unthresholded data:", round(min_rt_unthr_probe, 4), "s"))
}

# FIRST: Create sensitivity data summary table (BEFORE model fitting)
# This shows how data characteristics change across thresholds
log_info("Creating sensitivity data summary table...")
sensitivity_data_summary <- list()
threshold_count_table <- list()

# RT definitions to analyze
rt_defs <- c("cue_locked", "probe_onset_locked")

for (rt_def in rt_defs) {
  log_info(paste("=== Analyzing RT definition:", rt_def, "==="))
  
  # Determine RT column name for this definition
  if (rt_def == "cue_locked") {
    rt_col_name <- "rt_cue"
  } else if (rt_def == "probe_onset_locked") {
    rt_col_name <- "rt_probe_onset"
  } else {
    log_error(paste("Unknown rt_def:", rt_def))
    next
  }
  
  # Verify RT column exists
  if (!rt_col_name %in% names(ddm_base)) {
    log_warn(paste("RT column", rt_col_name, "not found, skipping", rt_def))
    next
  }
  
  for (thr in thresholds) {
    # B) Use numeric threshold, create label only for display
    threshold_label <- sprintf("%.2f s", thr)
    log_info(paste("Analyzing threshold:", threshold_label, "(numeric:", thr, ") for", rt_def))
    
    # Log BEFORE thresholding
    n_before <- nrow(ddm_base)
    min_rt_before <- min(ddm_base[[rt_col_name]], na.rm = TRUE)
    log_info(paste("  BEFORE thresholding:"))
    log_info(paste("    - N trials:", n_before))
    log_info(paste("    - Min", rt_col_name, ":", round(min_rt_before, 4), "s"))
    
    # C) Apply threshold to the correct RT variable per RT definition
    data_thresh <- apply_threshold_and_rt_def(ddm_base, thr, rt_def)
    
    # D) Logging is already done in apply_threshold_and_rt_def, but extract values for summary
    n_after <- nrow(data_thresh)
    min_rt_after <- min(data_thresh[[rt_col_name]], na.rm = TRUE)
    p01_rt_after <- quantile(data_thresh[[rt_col_name]], 0.01, na.rm = TRUE)
    median_rt_after <- median(data_thresh[[rt_col_name]], na.rm = TRUE)
    
    # Store in summary (for backward compatibility with existing code)
    sensitivity_data_summary[[paste(rt_def, thr, sep = "_")]] <- data.frame(
      rt_type = rt_def,
      threshold = thr,  # B) Numeric threshold, not "0.20 s"
      n_trials = n_after,
      n_subjects = length(unique(data_thresh$subject_id)),
      min_rt = min_rt_after,
      p01_rt = p01_rt_after,
      median_rt = median_rt_after,
      stringsAsFactors = FALSE
    )
    
    # E) Build threshold count table
    threshold_count_table[[paste(rt_def, thr, sep = "_")]] <- data.frame(
      rt_type = rt_def,
      threshold = thr,  # B) Numeric threshold
      n_trials = n_after,
      stringsAsFactors = FALSE
    )
  }
}

# E) Combine threshold count table and validate
if (length(threshold_count_table) > 0) {
  threshold_counts_df <- bind_rows(threshold_count_table)
  
  # Validate each rt_type subset
  for (rt_type in unique(threshold_counts_df$rt_type)) {
    subset_df <- threshold_counts_df %>% filter(rt_type == .env$rt_type)
    log_info(paste("Validating threshold counts for", rt_type))
    tryCatch({
      assert_reasonable_threshold_counts(subset_df)
      log_info(paste("✓ Validation passed for", rt_type))
    }, error = function(e) {
      log_error(paste("Validation failed for", rt_type, ":", e$message))
    }, warning = function(w) {
      log_warn(paste("Validation warning for", rt_type, ":", w$message))
    })
  }
  
  # Write threshold count table
  threshold_count_file <- file.path(TABLES_DIR, "ddm_sensitivity_threshold_counts.csv")
  write_csv_logged(threshold_counts_df, threshold_count_file)
} else {
  log_warn("threshold_count_table is empty")
}

# Combine sensitivity data summary (for backward compatibility)
if (length(sensitivity_data_summary) > 0) {
  sensitivity_data_df <- bind_rows(sensitivity_data_summary)
  
  # F) Sanity stop: Check if 0.15 and 0.20 produce identical n_trials
  for (rt_type in unique(sensitivity_data_df$rt_type)) {
    subset_df <- sensitivity_data_df %>% filter(rt_type == .env$rt_type)
    if (nrow(subset_df) >= 2) {
      thr_015 <- subset_df %>% filter(threshold == 0.15)
      thr_020 <- subset_df %>% filter(threshold == 0.20)
      
      if (nrow(thr_015) == 1 && nrow(thr_020) == 1) {
        if (thr_015$n_trials == thr_020$n_trials) {
          min_rt_raw <- if (rt_type == "cue_locked") min_rt_unthr_cue else min_rt_unthr_probe
          min_rt_after_015 <- thr_015$min_rt
          
          warning_msg <- paste0(
            "WARNING: Thresholds 0.15 and 0.20 produce identical n_trials (", thr_015$n_trials, ") for ", rt_type, ".\n",
            "  - Min RT in raw unthresholded data: ", round(min_rt_raw, 4), " s\n",
            "  - Min RT after filtering with 0.15: ", round(min_rt_after_015, 4), " s\n",
            "  This suggests you are not using unthresholded data or thresholds are not applied."
          )
          log_warn(warning_msg)
          warning(warning_msg)
        }
      }
    }
  }
  
  # Write sensitivity data summary (backward compatibility)
  sensitivity_data_file <- file.path(TABLES_DIR, "ddm_sensitivity_thresholds.csv")
  write_csv_logged(sensitivity_data_df, sensitivity_data_file)
  log_info("Sensitivity data summary:")
  print(sensitivity_data_df)
} else {
  log_warn("sensitivity_data_summary is empty")
  sensitivity_data_df <- data.frame()
}

log_info("")
log_info("Fitting baseline models across thresholds...")

sensitivity_results <- list()

for (thresh in SENSITIVITY_THRESHOLDS) {
  # Initialize all diagnostic variables at start of loop iteration (prevent scoping issues)
  n_treedepth_sens <- NA_integer_
  min_bulk_ess_sens <- NA_real_
  min_tail_ess_sens <- NA_real_
  divergences_sens <- NA_integer_
  max_rhat_sens <- NA_real_
  fit_start_time_sens <- NULL
  fit_end_time_sens <- NULL
  time_elapsed_sens <- NA_real_
  
  log_info(paste("Threshold:", thresh, "s"))
  
  # Process data for cue_locked (sensitivity analysis uses cue_locked only)
  # Use ddm_base (unthresholded base dataset)
  data_thresh_cue <- apply_threshold_and_rt_def(ddm_base, thresh, "cue_locked")
  create_data_manifest(data_thresh_cue, thresh, "cue_locked", input_file)
  
  # Log pre-fit statistics
  log_prefit_stats(data_thresh_cue, thresh, "cue_locked", "sensitivity_baseline")
  
  # Compute ndt_ub from rt_model
  min_rt_model <- min(data_thresh_cue$rt_model, na.rm = TRUE)
  ndt_ub_val <- min_rt_model - 0.01
  
  if (ndt_ub_val <= 0.05) {
    log_error(paste("ndt upper bound too small for threshold", thresh, "s:", round(ndt_ub_val, 4), "s"))
    stop("ndt upper bound <= 0.05s. Increase threshold or check data quality.")
  }
  
  ndt_ub_thresh <- as.numeric(log(ndt_ub_val))
  priors_sens <- create_base_priors_cuelocked(ndt_ub = ndt_ub_thresh)
  
  # Map RT column
  rt_map_sens <- map_rt_type_to_column("cue_locked", data_thresh_cue)
  
  # Determine output path
  # Model file naming: sensitivity_baseline__cue_locked__thr<X>.rds
  output_rds_path_sens <- file.path(MODELS_DIR, paste0("sensitivity_baseline__cue_locked__thr", 
                                                         formatC(thresh, format="f", digits=2), ".rds"))
  
  # Prepare data: rename rt_model to rt for brms formula (needed for both dry run and actual fit)
  data_sens_fit <- data_thresh_cue %>%
    mutate(rt = rt_model) %>%
    filter(!is.na(rt), rt > 0)
  
  if (DRY_RUN) {
    log_info("[DRY RUN] Skipping model fit")
    # Create minimal data.frame with same structure as successful fit (for bind_rows compatibility)
    sensitivity_results[[as.character(thresh)]] <- data.frame(
      threshold = thresh,
      n_trials = nrow(data_sens_fit),
      drift_intercept = NA_real_,
      drift_intercept_se = NA_real_,
      bs_intercept = NA_real_,
      bs_intercept_se = NA_real_,
      ndt_intercept = NA_real_,
      ndt_intercept_se = NA_real_,
      bias_intercept = NA_real_,
      bias_intercept_se = NA_real_,
      max_rhat = NA_real_,
      min_bulk_ess = NA_real_,
      min_tail_ess = NA_real_,
      n_divergent = NA_integer_,
      n_treedepth_hits = NA_integer_,
      stringsAsFactors = FALSE
    )
    next
  }
  
  safe_init_sens <- function(chain_id = 1) {
    init_vals <- list(
      Intercept = 0,
      Intercept_bs = log(1.3),
      Intercept_ndt = log(0.08),
      Intercept_bias = 0,
      sd_subject_id__Intercept = INIT_SD,
      sd_subject_id__bias_Intercept = INIT_SD
    )
    
    if (USE_BS_RANDOM_EFFECTS) {
      init_vals$sd_subject_id__bs_Intercept <- INIT_SD
    }
    
    init_vals
  }
  
  # Track warnings
  all_warnings_sens <- character(0)
  warning_handler_sens <- function(w) {
    log_warn(paste("Warning during sensitivity model fit:", w$message))
    all_warnings_sens <<- c(all_warnings_sens, w$message)
  }
  
  # Record start time
  fit_start_time_sens <- Sys.time()
  
  fit_sens <- tryCatch({
    withCallingHandlers({
      brm(
        formula = formula_baseline,
        data = data_sens_fit,
        family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
        prior = priors_sens,
        chains = N_CHAINS,
        iter = N_ITER,
        warmup = N_WARMUP,
        cores = N_CHAINS,
        init = if (USE_SAFE_INIT) safe_init_sens else 0,
        control = list(adapt_delta = ADAPT_DELTA, max_treedepth = MAX_TREEDEPTH),
        backend = "cmdstanr",
        file = output_rds_path_sens,
        file_refit = "on_change",
        refresh = 200,
        silent = 2
      )
    }, warning = warning_handler_sens)
  }, error = function(e) {
    log_error(paste("ERROR:", e$message))
    return(NULL)
  })
  
  # Record end time
  fit_end_time_sens <- Sys.time()
  # Ensure fit_start_time_sens exists (defensive check)
  if (!exists("fit_start_time_sens")) {
    fit_start_time_sens <- fit_end_time_sens  # Fallback: use end time if start time missing
    log_warn("fit_start_time_sens was not found; using fit_end_time_sens as fallback")
  }
  time_elapsed_sens <- as.numeric(difftime(fit_end_time_sens, fit_start_time_sens, units = "secs"))
  
  if (is.null(fit_sens) || !inherits(fit_sens, "brmsfit")) {
    # Add failed fit to run_index
    run_index_row_sens <- data.frame(
      analysis_id = analysis_id,
      model_name = "sensitivity_baseline",
      threshold = as.numeric(thresh),  # Ensure numeric
      rt_def = "cue_locked",
      input_file = input_file,
      N_trials = nrow(data_sens_fit),
      N_subjects = length(unique(data_sens_fit$subject_id)),
      min_rt_model = min_rt_model,
      divergences = NA_integer_,
      treedepth_hits = NA_integer_,
      max_rhat = NA_real_,
      min_bulk_ess = NA_real_,
      min_tail_ess = NA_real_,
      time_elapsed_sec = time_elapsed_sens,
      output_rds_path = output_rds_path_sens,
      stringsAsFactors = FALSE
    )
    if (file.exists(RUN_INDEX_FILE) && file.info(RUN_INDEX_FILE)$size > 0) {
      existing_index <- read_csv(RUN_INDEX_FILE, show_col_types = FALSE)
      # Ensure numeric columns are numeric in both data frames
      numeric_cols <- c("threshold", "N_trials", "N_subjects", "min_rt_model", 
                        "divergences", "treedepth_hits", "max_rhat", "min_bulk_ess", 
                        "min_tail_ess", "time_elapsed_sec")
      for (col in numeric_cols) {
        if (col %in% names(existing_index)) {
          existing_index[[col]] <- as.numeric(existing_index[[col]])
        }
        if (col %in% names(run_index_row_sens)) {
          run_index_row_sens[[col]] <- as.numeric(run_index_row_sens[[col]])
        }
      }
      run_index <- bind_rows(existing_index, run_index_row_sens)
    } else {
      run_index <- run_index_row_sens
    }
    write_csv(run_index, RUN_INDEX_FILE)
    
    stop("Sensitivity model fit failed; aborting pipeline.")
  }
  
  # Extract diagnostics (must be done before creating run_index_row_sens)
  rhat_vals_sens <- brms::rhat(fit_sens)
  max_rhat_sens <- suppressWarnings(max(rhat_vals_sens, na.rm = TRUE))
  
  sampler_params_sens <- tryCatch(brms::nuts_params(fit_sens), error = function(e) NULL)
  divergences_sens <- if (!is.null(sampler_params_sens)) {
    sum(sampler_params_sens$divergent__ == 1, na.rm = TRUE)
  } else NA_integer_
  
  n_treedepth_sens <- if (!is.null(sampler_params_sens)) {
    sum(sampler_params_sens$treedepth__ == MAX_TREEDEPTH, na.rm = TRUE)
  } else NA_integer_
  
  # Defensive check: ensure n_treedepth_sens exists
  if (!exists("n_treedepth_sens") || is.null(n_treedepth_sens)) {
    n_treedepth_sens <- NA_integer_
    log_warn("n_treedepth_sens was not properly initialized; setting to NA")
  }
  
  neff_sens <- tryCatch(brms::neff_ratio(fit_sens), error = function(e) {
    log_warn("Could not extract neff_ratio")
    return(NULL)
  })
  
  if (is.null(neff_sens)) {
    min_bulk_ess_sens <- NA_real_
    min_tail_ess_sens <- NA_real_
  } else {
    total_draws_sens <- N_CHAINS * (N_ITER - N_WARMUP)
    bulk_ess_sens <- neff_sens * total_draws_sens
    min_bulk_ess_sens <- suppressWarnings(min(bulk_ess_sens, na.rm = TRUE))
    min_tail_ess_sens <- min_bulk_ess_sens  # Approximate
  }
  
  # Defensive checks for all diagnostic variables before logging
  if (!exists("min_bulk_ess_sens")) min_bulk_ess_sens <- NA_real_
  if (!exists("min_tail_ess_sens")) min_tail_ess_sens <- NA_real_
  if (!exists("divergences_sens")) divergences_sens <- NA_integer_
  if (!exists("max_rhat_sens")) max_rhat_sens <- NA_real_
  
  log_info(paste("Max R-hat:", round(max_rhat_sens, 4)))
  log_info(paste("Divergences:", ifelse(is.na(divergences_sens), "N/A", divergences_sens)))
  log_info(paste("Treedepth hits:", ifelse(is.na(n_treedepth_sens), "N/A", n_treedepth_sens)))
  log_info(paste("Time elapsed:", round(time_elapsed_sens, 2), "seconds"))
  
  # Defensive checks before creating run_index_row_sens
  if (!exists("n_treedepth_sens")) {
    n_treedepth_sens <- NA_integer_
    log_warn("n_treedepth_sens not found before run_index creation; setting to NA")
  }
  if (!exists("min_bulk_ess_sens")) {
    min_bulk_ess_sens <- NA_real_
    log_warn("min_bulk_ess_sens not found before run_index creation; setting to NA")
  }
  if (!exists("min_tail_ess_sens")) {
    min_tail_ess_sens <- NA_real_
    log_warn("min_tail_ess_sens not found before run_index creation; setting to NA")
  }
  if (!exists("divergences_sens")) {
    divergences_sens <- NA_integer_
    log_warn("divergences_sens not found before run_index creation; setting to NA")
  }
  if (!exists("max_rhat_sens")) {
    max_rhat_sens <- NA_real_
    log_warn("max_rhat_sens not found before run_index creation; setting to NA")
  }
  
  # Add to run_index
  run_index_row_sens <- data.frame(
    analysis_id = analysis_id,
    model_name = "sensitivity_baseline",
    threshold = as.numeric(thresh),  # Ensure numeric
    rt_def = "cue_locked",
    input_file = input_file,
    N_trials = nrow(data_sens_fit),
    N_subjects = length(unique(data_sens_fit$subject_id)),
    min_rt_model = min_rt_model,
    divergences = ifelse(is.na(divergences_sens), 0L, as.integer(divergences_sens)),
    treedepth_hits = ifelse(is.na(n_treedepth_sens), 0L, as.integer(n_treedepth_sens)),
    max_rhat = max_rhat_sens,
    min_bulk_ess = ifelse(is.na(min_bulk_ess_sens), NA_real_, min_bulk_ess_sens),
    min_tail_ess = ifelse(is.na(min_tail_ess_sens), NA_real_, min_tail_ess_sens),
    time_elapsed_sec = time_elapsed_sens,
    output_rds_path = output_rds_path_sens,
    stringsAsFactors = FALSE
  )
  if (file.exists(RUN_INDEX_FILE) && file.info(RUN_INDEX_FILE)$size > 0) {
    existing_index <- read_csv(RUN_INDEX_FILE, show_col_types = FALSE)
    # Ensure numeric columns are numeric in both data frames
    numeric_cols <- c("threshold", "N_trials", "N_subjects", "min_rt_model", 
                      "divergences", "treedepth_hits", "max_rhat", "min_bulk_ess", 
                      "min_tail_ess", "time_elapsed_sec")
    for (col in numeric_cols) {
      if (col %in% names(existing_index)) {
        existing_index[[col]] <- as.numeric(existing_index[[col]])
      }
      if (col %in% names(run_index_row_sens)) {
        run_index_row_sens[[col]] <- as.numeric(run_index_row_sens[[col]])
      }
    }
    run_index <- bind_rows(existing_index, run_index_row_sens)
  } else {
    run_index <- run_index_row_sens
  }
  write_csv(run_index, RUN_INDEX_FILE)
  
  # Extract fixed effects (only if model fit succeeded)
  fixef_sens <- tryCatch({
    brms::fixef(fit_sens, summary = TRUE) %>% as.data.frame()
  }, error = function(e) {
    log_error(paste("Failed to extract fixef:", e$message))
    return(NULL)
  })
  
  if (is.null(fixef_sens)) {
    log_warn("Could not extract fixef; creating NA row for sensitivity_results")
    sensitivity_results[[as.character(thresh)]] <- data.frame(
      threshold = thresh,
      n_trials = nrow(data_sens_fit),
      looic = NA_real_,
      looic_se = NA_real_,
      drift_intercept = NA_real_,
      drift_intercept_se = NA_real_,
      bs_intercept = NA_real_,
      bs_intercept_se = NA_real_,
      ndt_intercept = NA_real_,
      ndt_intercept_se = NA_real_,
      bias_intercept = NA_real_,
      bias_intercept_se = NA_real_,
      max_rhat = ifelse(exists("max_rhat_sens"), max_rhat_sens, NA_real_),
      min_bulk_ess = ifelse(exists("min_bulk_ess_sens"), min_bulk_ess_sens, NA_real_),
      min_tail_ess = ifelse(exists("min_tail_ess_sens"), min_tail_ess_sens, NA_real_),
      n_divergent = ifelse(exists("divergences_sens"), divergences_sens, NA_integer_),
      n_treedepth_hits = ifelse(exists("n_treedepth_sens"), n_treedepth_sens, NA_integer_),
      stringsAsFactors = FALSE
    )
  } else {
    # Diagnostics already extracted above before run_index_row_sens creation
    # Defensive checks before creating sensitivity_results
    if (!exists("n_treedepth_sens")) n_treedepth_sens <- NA_integer_
    if (!exists("min_bulk_ess_sens")) min_bulk_ess_sens <- NA_real_
    if (!exists("min_tail_ess_sens")) min_tail_ess_sens <- NA_real_
    if (!exists("divergences_sens")) divergences_sens <- NA_integer_
    if (!exists("max_rhat_sens")) max_rhat_sens <- NA_real_
    # Note: n_divergent_sens was renamed to divergences_sens above
    n_divergent_sens <- divergences_sens
    
    # Compute LOOIC for sensitivity model
    looic_sens <- NA_real_
    looic_se_sens <- NA_real_
    tryCatch({
      loo_result_sens <- brms::loo(fit_sens)
      looic_sens <- loo_result_sens$estimates["looic", "Estimate"]
      looic_se_sens <- loo_result_sens$estimates["looic", "SE"]
      log_info(paste("LOOIC:", round(looic_sens, 1), "(SE:", round(looic_se_sens, 1), ")"))
    }, error = function(e) {
      log_warn(paste("Failed to compute LOOIC for sensitivity model:", e$message))
    })
    
    sensitivity_results[[as.character(thresh)]] <- data.frame(
      threshold = thresh,
      n_trials = nrow(data_sens_fit),
      looic = looic_sens,
      looic_se = looic_se_sens,
      drift_intercept = fixef_sens["Intercept", "Estimate"],
      drift_intercept_se = fixef_sens["Intercept", "Est.Error"],
      bs_intercept = exp(fixef_sens["bs_Intercept", "Estimate"]),
      bs_intercept_se = fixef_sens["bs_Intercept", "Est.Error"],
      ndt_intercept = exp(fixef_sens["ndt_Intercept", "Estimate"]),
      ndt_intercept_se = fixef_sens["ndt_Intercept", "Est.Error"],
      bias_intercept = plogis(fixef_sens["bias_Intercept", "Estimate"]),
      bias_intercept_se = fixef_sens["bias_Intercept", "Est.Error"],
      max_rhat = max_rhat_sens,
      min_bulk_ess = min_bulk_ess_sens,
      min_tail_ess = min_tail_ess_sens,
      n_divergent = n_divergent_sens,
      n_treedepth_hits = n_treedepth_sens,
      stringsAsFactors = FALSE
    )
  }
  
  log_info("✓ Fitted")
}

# Combine sensitivity results (with defensive check)
if (length(sensitivity_results) > 0) {
  sensitivity_df <- tryCatch({
    bind_rows(sensitivity_results)
  }, error = function(e) {
    log_error(paste("Failed to bind sensitivity_results:", e$message))
    log_error("sensitivity_results structure:")
    for (i in seq_along(sensitivity_results)) {
      log_error(paste("  Element", i, "columns:", paste(names(sensitivity_results[[i]]), collapse = ", ")))
    }
    return(data.frame())  # Return empty data.frame
  })
  
  if (nrow(sensitivity_df) > 0) {
    # Merge data summary (n_trials, min/max RT) with model results (LOOIC, parameters)
    # Merge by threshold to combine pre-fit data summary with post-fit model results
    if (exists("sensitivity_data_df") && nrow(sensitivity_data_df) > 0) {
      # Filter for cue_locked RT type (sensitivity analysis uses cue_locked)
      # Use correct column names: min_rt (not min_rt_cue), and use all_of() to avoid tidyselect warnings
      cols_to_select <- c("threshold", "n_trials", "n_subjects", "min_rt", "median_rt")
      available_cols <- intersect(cols_to_select, names(sensitivity_data_df))
      
      sensitivity_export <- sensitivity_data_df %>%
        filter(rt_type == "cue_locked") %>%
        select(all_of(available_cols)) %>%
        left_join(
          sensitivity_df %>% select(all_of(c("threshold", "looic", "looic_se"))),
          by = "threshold"
        ) %>%
        arrange(threshold)
    } else {
      # Fallback: use model results only
      sensitivity_export <- sensitivity_df %>%
        select(all_of(c("threshold", "n_trials", "looic", "looic_se"))) %>%
        arrange(threshold)
    }
    
    # Update the TABLES_DIR file (used by QMD) with merged data + LOOIC values
    sensitivity_file_qmd <- file.path(TABLES_DIR, "ddm_sensitivity_thresholds.csv")
    write_csv(sensitivity_export, sensitivity_file_qmd)
    log_info(paste("Saved QMD table (with LOOIC):", sensitivity_file_qmd))
    
    # Also save full results to SUMMARIES_DIR
    sensitivity_file <- file.path(SUMMARIES_DIR, "ddm_sensitivity_thresholds.csv")
    write_csv(sensitivity_df, sensitivity_file)
    log_info(paste("Saved full results:", sensitivity_file))
    
    # Also save to legacy location
    write_csv(sensitivity_df, file.path(RESULTS_DIR, "ddm_sensitivity_thresholds.csv"))
  } else {
    log_warn("sensitivity_df is empty; skipping CSV write")
  }
} else {
  log_warn("sensitivity_results is empty; skipping CSV write")
  sensitivity_df <- data.frame()  # Initialize empty for downstream checks
}

if (!DRY_RUN && exists("sensitivity_df") && nrow(sensitivity_df) > 0) {
  p_sens <- sensitivity_df %>%
    select(threshold, drift_intercept, bs_intercept, ndt_intercept, bias_intercept) %>%
    pivot_longer(cols = c(drift_intercept, bs_intercept, ndt_intercept, bias_intercept),
                 names_to = "parameter", values_to = "estimate") %>%
    ggplot(aes(x = threshold, y = estimate, color = parameter)) +
    geom_point(size = 3) +
    geom_line(alpha = 0.7) +
    facet_wrap(~ parameter, scales = "free_y") +
    labs(
      title = "DDM Parameter Stability Across RT Thresholds",
      x = "RT Threshold (seconds)",
      y = "Parameter Estimate",
      color = "Parameter"
    ) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "none")
  
  ggsave(file.path(FIGURES_DIR, "ddm_parameter_stability_thresholds.png"),
         p_sens, width = 10, height = 8, dpi = 300)
  cat("  Saved:", file.path(FIGURES_DIR, "ddm_parameter_stability_thresholds.png"), "\n")
}

# =========================================================================
# STEP 6: STANDARD-ONLY BIAS CALIBRATION MODEL
# =========================================================================

if (!SKIP_STANDARD_ONLY) {
  cat("\nSTEP 6: Fitting standard-only bias calibration models...\n\n")
  cat("  Purpose: Standard trials (Δ=0) provide leverage to identify response bias\n")
  cat("           under response-side coding, independent of evidence accumulation.\n\n")
  
  # Create standard-only data subset
  # Try multiple ways to identify Standard trials
  # Priority: is_standard == 1 (or TRUE), then difficulty_3 == "Standard"
  if ("is_standard" %in% names(ddm_data)) {
    # Handle both logical (TRUE) and numeric (1) encoding
    if (is.logical(ddm_data$is_standard)) {
      ddm_data_standard <- ddm_data %>% filter(is_standard == TRUE)
    } else if (is.numeric(ddm_data$is_standard)) {
      ddm_data_standard <- ddm_data %>% filter(is_standard == 1)
    } else {
      ddm_data_standard <- ddm_data %>% filter(as.logical(is_standard) | as.numeric(is_standard) == 1)
    }
    log_info("Using is_standard column to identify Standard trials")
  } else if ("difficulty_3" %in% names(ddm_data)) {
    ddm_data_standard <- ddm_data %>% filter(difficulty_3 == "Standard")
    log_info("Using difficulty_3 == 'Standard' to identify Standard trials")
  } else if ("difficulty_level" %in% names(ddm_data)) {
    # Check if difficulty_level is character and includes "Standard"
    if (is.character(ddm_data$difficulty_level) || is.factor(ddm_data$difficulty_level)) {
      ddm_data_standard <- ddm_data %>% filter(grepl("Standard|standard|0", as.character(difficulty_level)))
      log_info("Using difficulty_level labels to identify Standard trials")
    } else {
      log_error("Cannot identify Standard trials: need is_standard column or difficulty_level labels")
      stop("Cannot identify Standard trials")
    }
  } else {
    log_error("Cannot identify Standard trials; need is_standard or difficulty_level labels")
    stop("Cannot identify Standard trials")
  }
  
  log_info(paste("Standard-only trials (unthresholded):", nrow(ddm_data_standard)))
  log_info(paste("Standard-only subjects:", length(unique(ddm_data_standard$subject_id))))
  
  if (nrow(ddm_data_standard) == 0) {
    log_warn("No standard trials found. Skipping standard-only models.")
  } else {
    # Model specification for standard-only bias calibration
    # Note: Relaxed drift prior allows negative drift on Standard trials (no signal difference)
    # IMPORTANT: bias does NOT include difficulty (Standard trials have Δ=0, so difficulty is irrelevant)
    formula_standard_only <- bf(
      rt | dec(choice_binary) ~ 1 + (1 | subject_id),
      bs ~ 1 + (1 | subject_id),
      ndt ~ 1,
      bias ~ task + effort_condition + (1 | subject_id)  # Pre-trial factors only (NO difficulty)
    )
    
    log_info("Standard-only model formula:")
    log_info("  Drift (v): rt | dec(choice_binary) ~ 1 + (1 | subject_id)")
    log_info("  Boundary (bs): bs ~ 1 + (1 | subject_id)")
    log_info("  NDT (t0): ndt ~ 1")
    log_info("  Bias (z): bias ~ task + effort_condition + (1 | subject_id)")
    log_info("  Note: Relaxed drift prior (normal(0, 2)) allows negative drift on Standard trials")
    log_info("  Note: Bias does NOT include difficulty (Standard trials have Δ=0)")
    log_info("")
    
    # Create priors for standard-only model
    create_priors_standard_only <- function(ndt_ub) {
      ndt_ub_val <- as.numeric(ndt_ub)
      c(
        # Relaxed drift prior: allows negative drift on Standard trials (no signal difference)
        prior(normal(0, 2), class = "Intercept"),  # Relaxed for Standard trials
        # Boundary separation
        prior(normal(log(1.3), 0.25), class = "Intercept", dpar = "bs",
              lb = log(0.3), ub = log(5)),
        # NDT
        eval(substitute(
          prior(normal(log(0.10), 0.15), class = "Intercept", dpar = "ndt",
                lb = log(0.02), ub = UB_VAL),
          list(UB_VAL = ndt_ub_val)
        )),
        # Bias (task + effort_condition) - NO difficulty terms
        prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
        prior(normal(0, 0.5), class = "b", dpar = "bias"),  # For task and effort_condition
        # Random effects
        prior(exponential(5), class = "sd"),
        prior(exponential(5), class = "sd", dpar = "bs"),
        prior(exponential(5), class = "sd", dpar = "bias")
      )
    }
    
    # =========================================================================
    # CONTAINERS FOR STANDARD-ONLY MODEL EXPORTS
    # =========================================================================
    # Store fixef per run/threshold/RT definition to avoid scope/lifetime issues
    standard_fixef_list <- list()
    standard_diag_list <- list()
    standard_bycond_list <- list()  # Condition-level predictions
    standard_contrast_list <- list()  # Contrasts from posterior draws
    standard_only_results <- list()
    
    # Helper function to extract and tidy fixef from brms fit
    tidy_fixef <- function(fit, dpar, rt_type, threshold, model_label, n_trials, n_subjects) {
      if (is.null(fit) || !inherits(fit, "brmsfit")) {
        log_warn(paste("tidy_fixef: fit is NULL or not brmsfit for", model_label, rt_type, threshold))
        return(data.frame())
      }
      
      tryCatch({
        # Try to extract fixef with dpar specification
        fixef_raw <- tryCatch({
          brms::fixef(fit, summary = TRUE, dpar = dpar)
        }, error = function(e) {
          # Fallback: extract all fixef and filter by term prefix
          all_fixef <- brms::fixef(fit, summary = TRUE)
          if (dpar == "bias") {
            all_fixef[grepl("^bias_", rownames(all_fixef)), , drop = FALSE]
          } else if (dpar == "bs") {
            all_fixef[grepl("^bs_", rownames(all_fixef)), , drop = FALSE]
          } else if (dpar == "ndt") {
            all_fixef[grepl("^ndt_", rownames(all_fixef)), , drop = FALSE]
          } else {
            # For drift (mu), use terms that don't start with bs_, ndt_, bias_
            all_fixef[!grepl("^(bs_|ndt_|bias_)", rownames(all_fixef)), , drop = FALSE]
          }
        })
        
        if (is.null(fixef_raw) || nrow(fixef_raw) == 0) {
          log_warn(paste("No fixef found for", dpar, "in", model_label, rt_type, threshold))
          return(data.frame())
        }
        
        # Convert to tibble
        fixef_df <- as.data.frame(fixef_raw)
        fixef_df$term <- rownames(fixef_df)
        rownames(fixef_df) <- NULL
        
        # Add metadata columns
        fixef_df$model <- model_label
        fixef_df$dpar <- dpar
        fixef_df$rt_type <- rt_type
        fixef_df$threshold <- threshold
        fixef_df$n_trials <- n_trials
        fixef_df$n_subjects <- n_subjects
        fixef_df$run_id <- analysis_id
        
        # Ensure consistent column names
        if (!"Estimate" %in% names(fixef_df)) {
          if ("Estimate" %in% names(fixef_df)) {
            # Already correct
          } else {
            log_warn(paste("Unexpected fixef column names:", paste(names(fixef_df), collapse = ", ")))
          }
        }
        
        return(fixef_df)
      }, error = function(e) {
        log_error(paste("Failed to tidy fixef for", dpar, "in", model_label, rt_type, threshold, ":", e$message))
        return(data.frame())
      })
    }
    
    # RT definitions to test
    rt_defs_to_test <- c("cue_locked", "probe_onset_locked")
    
    # Thresholds to test
    thresholds_to_test <- c(CHOSEN_THRESHOLD, SENSITIVITY_THRESHOLDS)
    thresholds_to_test <- unique(thresholds_to_test)
    
    for (rt_def in rt_defs_to_test) {
      log_info(paste("RT definition:", rt_def))
      
      for (thresh in thresholds_to_test) {
        log_info(paste("  Threshold:", thresh, "s"))
        
        # Filter standard-only data by threshold using apply_threshold_and_rt_def
        # This ensures consistent thresholding and creates rt_model column
        data_standard_thresh <- apply_threshold_and_rt_def(ddm_data_standard, thresh, rt_def)
        
        # Create manifest for standard-only data
        create_data_manifest(data_standard_thresh, thresh, rt_def, input_file)
        
        n_trials <- nrow(data_standard_thresh)
        n_subjects <- length(unique(data_standard_thresh$subject_id))
        
        if (n_trials == 0) {
          log_warn("[SKIP] No trials after filtering")
          next
        }
        
        # Data already has rt_model column from apply_threshold_and_rt_def
        # Use rt_model for ndt bounds
        min_rt_model <- min(data_standard_thresh$rt_model, na.rm = TRUE)
        ndt_ub_val_standard <- min_rt_model - 0.01
        
        if (ndt_ub_val_standard <= 0.05) {
          log_error(paste("ndt upper bound too small for standard-only model:", round(ndt_ub_val_standard, 4), "s"))
          stop("ndt upper bound <= 0.05s for standard-only model.")
        }
        
        ndt_ub_standard <- as.numeric(log(ndt_ub_val_standard))
        
        priors_standard <- create_priors_standard_only(ndt_ub = ndt_ub_standard)
        
        if (DRY_RUN) {
          log_info("[DRY RUN] Skipping model fit")
          standard_only_results[[paste0(rt_def, "_", thresh)]] <- data.frame(
            rt_def = rt_def,
            threshold = thresh,
            n_trials = nrow(data_standard_thresh),
            n_subjects = length(unique(data_standard_thresh$subject_id)),
            min_rt_model = min(data_standard_thresh$rt_model, na.rm = TRUE),
            stringsAsFactors = FALSE
          )
          next
        }
        
        # Safe initialization
        safe_init_standard <- function(chain_id = 1) {
          list(
            Intercept = 0,
            Intercept_bs = log(1.3),
            Intercept_ndt = log(0.08),
            Intercept_bias = 0,
            sd_subject_id__Intercept = INIT_SD,
            sd_subject_id__bs_Intercept = INIT_SD,
            sd_subject_id__bias_Intercept = INIT_SD
          )
        }
        
        init_strategy_standard <- if (INIT_ZERO) {
          0
        } else if (USE_SAFE_INIT) {
          safe_init_standard
        } else {
          0
        }
        
        # Track warnings
        bs_inf_warnings_standard <- character(0)
        warning_handler_standard <- function(w) {
          if (grepl("boundary separation is inf", w$message, ignore.case = TRUE)) {
            bs_inf_warnings_standard <<- c(bs_inf_warnings_standard, w$message)
          }
        }
        
        # Map RT column (data already has rt_model from apply_threshold_and_rt_def)
        rt_map_standard <- map_rt_type_to_column(rt_def, data_standard_thresh)
        
        # Determine output path for standard-only model
        # Model file naming: standard_only__<rt_def>__thr<X>.rds
        output_rds_path_standard <- file.path(MODELS_DIR, paste0("standard_only__", rt_def, "__thr", 
                                                                  formatC(thresh, format="f", digits=2), ".rds"))
        
        # Prepare data for fitting: rename rt_model to rt (required by brms formula)
        # CRITICAL: Ensure choice_binary is integer 0/1 (not logical or factor)
        data_fit_standard <- data_standard_thresh %>%
          mutate(
            rt = !!sym(rt_map_standard$rt_col),
            choice_binary = as.integer(choice_binary)  # Ensure integer type
          )
        
        # Validate choice_binary is 0/1 integer
        if (!all(data_fit_standard$choice_binary %in% c(0L, 1L))) {
          log_error("choice_binary must be 0/1 integer after coercion")
          log_error(paste("Unique values:", paste(unique(data_fit_standard$choice_binary), collapse = ", ")))
          stop("Invalid choice_binary values")
        }
        
        # Record start time
        fit_start_time_standard <- Sys.time()
        
        # Fit model
        fit_standard <- tryCatch({
          withCallingHandlers({
            brm(
              formula = formula_standard_only,
              data = data_fit_standard,
              family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
              prior = priors_standard,
              chains = N_CHAINS,
              iter = N_ITER,
              warmup = N_WARMUP,
              cores = N_CHAINS,
              init = init_strategy_standard,
              control = list(adapt_delta = ADAPT_DELTA, max_treedepth = MAX_TREEDEPTH),
              backend = "cmdstanr",
              file = output_rds_path_standard,
              file_refit = "on_change",
              refresh = 200,
              silent = 2
            )
          }, warning = warning_handler_standard)
        }, error = function(e) {
          log_error(paste("ERROR:", e$message))
          return(NULL)
        })
        
        # Record end time
        fit_end_time_standard <- Sys.time()
        # Ensure fit_start_time_standard exists (defensive check)
        if (!exists("fit_start_time_standard")) {
          fit_start_time_standard <- fit_end_time_standard  # Fallback: use end time if start time missing
          log_warn("fit_start_time_standard was not found; using fit_end_time_standard as fallback")
        }
        time_elapsed_standard <- as.numeric(difftime(fit_end_time_standard, fit_start_time_standard, units = "secs"))
        
        # Initialize diagnostic variables to NA in case of failure
        n_treedepth_standard <- NA_integer_
        min_bulk_ess_standard <- NA_real_
        min_tail_ess_standard <- NA_real_
        divergences_standard <- NA_integer_
        max_rhat <- NA_real_
        
        # Check warnings
        if (length(bs_inf_warnings_standard) > 10) {
          log_error("✗ HARD FAIL: Excessive bs=inf warnings")
          stop("Aborting standard-only model due to excessive bs=inf warnings.")
        }
        
        if (is.null(fit_standard) || !inherits(fit_standard, "brmsfit")) {
          log_warn("✗ Model fit failed")
          
          # Ensure output_rds_path_standard exists (defensive check)
          if (!exists("output_rds_path_standard")) {
            output_rds_path_standard <- file.path(MODELS_DIR, paste0("standard_only__", rt_def, "__thr", 
                                                                    formatC(thresh, format="f", digits=2), ".rds"))
            log_warn("output_rds_path_standard was not found; creating default path")
          }
          
          # Add failed fit to run_index
          run_index_row_standard <- data.frame(
            analysis_id = analysis_id,
            model_name = "standard_only",
            threshold = as.numeric(thresh),  # Ensure numeric
            rt_def = rt_def,
            input_file = input_file,
            N_trials = n_trials,
            N_subjects = n_subjects,
            min_rt_model = min_rt_model,
            divergences = NA_integer_,
            treedepth_hits = NA_integer_,
            max_rhat = NA_real_,
            min_bulk_ess = NA_real_,
            min_tail_ess = NA_real_,
            time_elapsed_sec = time_elapsed_standard,
            output_rds_path = output_rds_path_standard,
            stringsAsFactors = FALSE
          )
          if (file.exists(RUN_INDEX_FILE) && file.info(RUN_INDEX_FILE)$size > 0) {
            existing_index <- read_csv(RUN_INDEX_FILE, show_col_types = FALSE)
            # Ensure numeric columns are numeric in both data frames
            numeric_cols <- c("threshold", "N_trials", "N_subjects", "min_rt_model", 
                              "divergences", "treedepth_hits", "max_rhat", "min_bulk_ess", 
                              "min_tail_ess", "time_elapsed_sec")
            for (col in numeric_cols) {
              if (col %in% names(existing_index)) {
                existing_index[[col]] <- as.numeric(existing_index[[col]])
              }
              if (col %in% names(run_index_row_standard)) {
                run_index_row_standard[[col]] <- as.numeric(run_index_row_standard[[col]])
              }
            }
            run_index <- bind_rows(existing_index, run_index_row_standard)
          } else {
            run_index <- run_index_row_standard
          }
          write_csv(run_index, RUN_INDEX_FILE)
          
          next
        }
        
        # Extract diagnostics
        rhat_vals <- brms::rhat(fit_standard)
        neff_vals <- brms::neff_ratio(fit_standard)
        max_rhat <- suppressWarnings(max(rhat_vals, na.rm = TRUE))
        min_neff_ratio <- suppressWarnings(min(neff_vals, na.rm = TRUE))
        
        # Extract divergences and treedepth hits
        sampler_params_standard <- tryCatch(brms::nuts_params(fit_standard), error = function(e) NULL)
        divergences_standard <- if (!is.null(sampler_params_standard)) {
          sum(sampler_params_standard$divergent__ == 1, na.rm = TRUE)
        } else NA_integer_
        
        n_treedepth_standard <- if (!is.null(sampler_params_standard)) {
          sum(sampler_params_standard$treedepth__ == MAX_TREEDEPTH, na.rm = TRUE)
        } else NA_integer_
        
        # Extract ESS values
        total_draws_standard <- N_CHAINS * (N_ITER - N_WARMUP)
        bulk_ess_standard <- neff_vals * total_draws_standard
        min_bulk_ess_standard <- suppressWarnings(min(bulk_ess_standard, na.rm = TRUE))
        min_tail_ess_standard <- min_bulk_ess_standard  # Approximate
        
        log_info(paste("Max R-hat:", round(max_rhat, 4)))
        log_info(paste("Min ESS ratio:", round(min_neff_ratio, 3)))
        log_info(paste("Min bulk ESS:", ifelse(is.na(min_bulk_ess_standard), "N/A", round(min_bulk_ess_standard))))
        log_info(paste("Min tail ESS:", ifelse(is.na(min_tail_ess_standard), "N/A", round(min_tail_ess_standard))))
        log_info(paste("Divergences:", ifelse(is.na(divergences_standard), "N/A", divergences_standard)))
        log_info(paste("Treedepth hits:", ifelse(is.na(n_treedepth_standard), "N/A", n_treedepth_standard)))
        log_info(paste("Time elapsed:", round(time_elapsed_standard, 2), "seconds"))
        
        # Get ESS values (using brms helper functions)
        # Note: brms::neff_ratio gives ESS ratios, multiply by total draws for absolute ESS
        total_draws <- N_CHAINS * (N_ITER - N_WARMUP)
        bulk_ess_min <- suppressWarnings(min(neff_vals * total_draws, na.rm = TRUE))
        tail_ess_min <- bulk_ess_min  # Approximate; brms doesn't separate bulk/tail easily
        
        # Extract fixed effects (with error handling)
        fixef_standard <- tryCatch({
          brms::fixef(fit_standard, summary = TRUE) %>% as.data.frame()
        }, error = function(e) {
          log_error(paste("Failed to extract fixef_standard:", e$message))
          return(NULL)
        })
        
        # =========================================================================
        # STORE FIXEF IMMEDIATELY AFTER EXTRACTION (prevent scope/lifetime issues)
        # =========================================================================
        key <- paste0("standard_only|", rt_def, "|thr_", formatC(thresh, format="f", digits=2))
        
        if (!is.null(fixef_standard) && !is.null(fit_standard)) {
          # Use tidy_fixef_wiener function to process fixef
          meta <- list(
            model = "standard_only_bias",
            rt_type = rt_def,
            threshold = thresh,
            n_trials = n_trials
          )
          
          # Note: n_subjects is added separately after tidy_fixef_wiener for backward compatibility
          
          tryCatch({
            fx_tidy <- tidy_fixef_wiener(fit_standard, meta)
            
            # Add n_subjects for backward compatibility with extraction code
            fx_tidy$n_subjects <- n_subjects
            
            # Store in list
            standard_fixef_list[[key]] <- fx_tidy
            
            # Log available bias terms
            bias_terms <- fx_tidy %>%
              filter(dpar == "bias") %>%
              pull(term)
            if (length(bias_terms) > 0) {
              log_info(paste("Standard-only bias fixef terms:", paste(bias_terms, collapse = ", ")))
            } else {
              log_warn(paste("No bias terms found in fixef for", key))
            }
          }, error = function(e) {
            log_error(paste("Failed to tidy fixef for", key, ":", e$message))
            # Store original fixef as fallback
            fx <- as.data.frame(fixef_standard)
            fx$term <- rownames(fx)
            rownames(fx) <- NULL
            fx$threshold <- thresh
            fx$rt_type <- rt_def
            fx$model <- "standard_only_bias"
            fx$n_trials <- n_trials
            standard_fixef_list[[key]] <- fx
          })
        } else {
          log_warn(paste("fixef_standard or fit_standard is NULL for", key, "; skipping fixef storage"))
        }
        
        # Store diagnostics
        standard_diag_list[[key]] <- data.frame(
          model = "standard_only",
          rt_type = rt_def,
          threshold = thresh,
          max_rhat = max_rhat,
          min_ess_ratio = min_neff_ratio,
          min_bulk_ess = min_bulk_ess_standard,
          min_tail_ess = min_tail_ess_standard,
          n_divergent = divergences_standard,
          n_treedepth_hits = n_treedepth_standard,
          converged = !is.na(max_rhat) && max_rhat < 1.01 && divergences_standard == 0,
          stringsAsFactors = FALSE
        )
        
        # =========================================================================
        # SAFE EXTRACTION OF BIAS PARAMETERS FOR SUMMARY (with name matching)
        # =========================================================================
        # Helper function to safely extract term estimates
        get_term_est <- function(df, candidates, label) {
          if (is.null(df) || nrow(df) == 0) {
            log_warn(paste("get_term_est: df is NULL or empty for", label))
            return(NA_real_)
          }
          
          # Try each candidate name
          for (cand in candidates) {
            if (cand %in% rownames(df)) {
              return(df[cand, "Estimate"])
            }
          }
          
          # None found - warn loudly with available terms
          available_terms <- rownames(df)
          log_warn(paste("get_term_est: No match found for", label))
          log_warn(paste("  Candidates tried:", paste(candidates, collapse = ", ")))
          log_warn(paste("  Available terms:", paste(available_terms, collapse = ", ")))
          return(NA_real_)
        }
        
        if (is.null(fixef_standard)) {
          log_warn("fixef_standard is NULL; setting bias parameters to NA")
          bias_intercept <- NA_real_
          bias_task_VDT_vs_ADT <- NA_real_
          bias_effort_high_vs_low <- NA_real_
          drift_intercept <- NA_real_
        } else {
          # Extract bias parameters using safe extractor
          bias_intercept_raw <- get_term_est(fixef_standard, 
                                            c("bias_Intercept", "Intercept"), 
                                            "bias_Intercept")
          bias_intercept <- if (!is.na(bias_intercept_raw)) plogis(bias_intercept_raw) else NA_real_
          
          # Task effect: VDT vs ADT (try multiple naming conventions)
          # Primary: bias_taskVDT (most common in brms with factor coding)
          bias_task_VDT_vs_ADT <- get_term_est(fixef_standard,
                                              c("bias_taskVDT", "bias_task_VDT", "bias_taskVDT", 
                                                "taskVDT", "bias_taskVisual", "bias_task_Visual", 
                                                "taskVisual", "bias_taskvis", "bias_task_vis"),
                                              "bias_task_VDT_vs_ADT")
          
          # Effort effect: high vs low (try multiple naming conventions)
          # Primary: bias_effort_conditionhigh (most common in brms with factor coding)
          bias_effort_high_vs_low <- get_term_est(fixef_standard,
                                                  c("bias_effort_conditionhigh", "bias_effort_condition_high",
                                                    "effort_conditionhigh", "effort_condition_high",
                                                    "bias_effortHigh", "bias_effort_High", "effortHigh"),
                                                  "bias_effort_high_vs_low")
          
          # Check for "Low" coding (some factor codings use low as the effect)
          if (is.na(bias_effort_high_vs_low)) {
            matched_low <- get_term_est(fixef_standard,
                                       c("bias_effort_conditionLow", "bias_effort_condition_Low",
                                         "effort_conditionLow", "effort_condition_Low"),
                                       "bias_effort_Low")
            if (!is.na(matched_low)) {
              bias_effort_high_vs_low <- -matched_low  # Negate: high vs low = -low vs high
              log_info(paste("Found effort effect coded as 'Low'; negated to get high vs low:", bias_effort_high_vs_low))
            }
          }
          
          drift_intercept <- get_term_est(fixef_standard,
                                         c("Intercept", "mu_Intercept"),
                                         "drift_Intercept")
          
          # Hard check: warn loudly if expected effects are missing
          if (is.na(bias_task_VDT_vs_ADT)) {
            log_warn(paste("WARNING: bias_task_VDT_vs_ADT is NA for", key))
            log_warn("  This may indicate the model did not include task in bias formula, or naming mismatch.")
          }
          if (is.na(bias_effort_high_vs_low)) {
            log_warn(paste("WARNING: bias_effort_high_vs_low is NA for", key))
            log_warn("  This may indicate the model did not include effort in bias formula, or naming mismatch.")
          }
        }
        
        # =========================================================================
        # COMPUTE CONDITION-LEVEL BIAS PREDICTIONS AND CONTRASTS FROM POSTERIOR DRAWS
        # =========================================================================
        # Use brms::posterior_linpred() to get proper posterior predictions
        # This ensures contrasts are computed from draws, not point estimates
        bias_by_condition <- NULL
        
        if (!is.null(fit_standard) && inherits(fit_standard, "brmsfit")) {
          tryCatch({
            # Create prediction grid: Task × Effort
            newdata <- expand.grid(
              task = c("ADT", "VDT"),
              effort_condition = c("low", "high"),
              stringsAsFactors = FALSE
            )
            newdata$task <- factor(newdata$task, levels = c("ADT", "VDT"))
            newdata$effort_condition <- factor(newdata$effort_condition, levels = c("low", "high"))
            
            # Get posterior predictions for bias
            # Use posterior_epred to get predictions on natural scale (z) directly
            # Or use posterior_linpred and transform manually
            z_draws_matrix <- tryCatch({
              # Try posterior_epred first (returns natural scale for bias with logit link)
              brms::posterior_epred(fit_standard, dpar = "bias", newdata = newdata)
            }, error = function(e1) {
              # Fallback: use posterior_linpred and transform manually
              tryCatch({
                linpred_draws <- brms::posterior_linpred(fit_standard, dpar = "bias", newdata = newdata)
                # Transform from logit scale to natural scale
                plogis(linpred_draws)
              }, error = function(e2) {
              # Final fallback: manual computation from coefficient draws
              log_warn(paste("posterior_epred and posterior_linpred failed, using manual computation:", e2$message))
              post_draws <- brms::as_draws_df(fit_standard)
              
              # Find bias coefficients
              bias_cols <- grep("^b_bias_", names(post_draws), value = TRUE)
              intercept_col <- grep("^b_bias_Intercept$", bias_cols, value = TRUE)[1]
              task_col <- grep("taskVDT|task_VDT", bias_cols, value = TRUE, ignore.case = TRUE)[1]
              effort_col <- grep("effort_conditionhigh|effort.*high", bias_cols, value = TRUE, ignore.case = TRUE)[1]
              
              if (is.na(intercept_col)) {
                stop("Could not find bias_Intercept")
              }
              
              intercept_draws <- post_draws[[intercept_col]]
              task_draws <- if (!is.na(task_col)) post_draws[[task_col]] else rep(0, length(intercept_draws))
              effort_draws <- if (!is.na(effort_col)) post_draws[[effort_col]] else rep(0, length(intercept_draws))
              
              # Compute z for each condition: ADT_low, ADT_high, VDT_low, VDT_high
              z_adt_low <- plogis(intercept_draws)
              z_adt_high <- plogis(intercept_draws + effort_draws)
              z_vdt_low <- plogis(intercept_draws + task_draws)
              z_vdt_high <- plogis(intercept_draws + task_draws + effort_draws)
              
              # Return as matrix: draws × conditions
              matrix(c(z_adt_low, z_adt_high, z_vdt_low, z_vdt_high), 
                     ncol = 4, nrow = length(intercept_draws))
              })
            })
            
            # z_draws_matrix should be: n_draws × n_conditions (4 conditions)
            if (is.matrix(z_draws_matrix) && ncol(z_draws_matrix) == 4) {
              n_draws <- nrow(z_draws_matrix)
              
              # Extract draws for each condition
              z_adt_low_draws <- z_draws_matrix[, 1]
              z_adt_high_draws <- z_draws_matrix[, 2]
              z_vdt_low_draws <- z_draws_matrix[, 3]
              z_vdt_high_draws <- z_draws_matrix[, 4]
              
              # Summarize each condition
              bias_by_condition <- data.frame(
                rt_def = rt_def,
                threshold = thresh,
                task = c("ADT", "ADT", "VDT", "VDT"),
                effort_condition = c("low", "high", "low", "high"),
                z_mean = c(
                  mean(z_adt_low_draws, na.rm = TRUE),
                  mean(z_adt_high_draws, na.rm = TRUE),
                  mean(z_vdt_low_draws, na.rm = TRUE),
                  mean(z_vdt_high_draws, na.rm = TRUE)
                ),
                z_median = c(
                  median(z_adt_low_draws, na.rm = TRUE),
                  median(z_adt_high_draws, na.rm = TRUE),
                  median(z_vdt_low_draws, na.rm = TRUE),
                  median(z_vdt_high_draws, na.rm = TRUE)
                ),
                z_q2.5 = c(
                  quantile(z_adt_low_draws, 0.025, na.rm = TRUE),
                  quantile(z_adt_high_draws, 0.025, na.rm = TRUE),
                  quantile(z_vdt_low_draws, 0.025, na.rm = TRUE),
                  quantile(z_vdt_high_draws, 0.025, na.rm = TRUE)
                ),
                z_q97.5 = c(
                  quantile(z_adt_low_draws, 0.975, na.rm = TRUE),
                  quantile(z_adt_high_draws, 0.975, na.rm = TRUE),
                  quantile(z_vdt_low_draws, 0.975, na.rm = TRUE),
                  quantile(z_vdt_high_draws, 0.975, na.rm = TRUE)
                ),
                stringsAsFactors = FALSE
              )
              
              # Replace any NaN with NA
              for (col in c("z_mean", "z_median", "z_q2.5", "z_q97.5")) {
                bias_by_condition[[col]][is.nan(bias_by_condition[[col]])] <- NA_real_
              }
              
              # =========================================================================
              # COMPUTE CONTRASTS FROM POSTERIOR DRAWS (not from means!)
              # =========================================================================
              # Validate draws before computing contrasts
              n_draws_valid <- length(z_adt_low_draws)
              if (n_draws_valid == 0 || any(is.na(z_adt_low_draws)) || any(is.na(z_adt_high_draws)) ||
                  any(is.na(z_vdt_low_draws)) || any(is.na(z_vdt_high_draws))) {
                log_error(paste("Invalid posterior draws for contrasts at", rt_def, thresh))
                log_error(paste("  Draw counts:", length(z_adt_low_draws), length(z_adt_high_draws), 
                               length(z_vdt_low_draws), length(z_vdt_high_draws)))
                log_error("Skipping contrast computation for this model")
                contrast_rows <- list()  # Empty list, will be skipped
              } else {
                # Task contrast: VDT - ADT (averaged across effort levels)
                task_contrast_draws <- (z_vdt_low_draws + z_vdt_high_draws) / 2 - 
                                        (z_adt_low_draws + z_adt_high_draws) / 2
                
                # Effort contrast: high - low (averaged across task levels)
                effort_contrast_draws <- (z_adt_high_draws + z_vdt_high_draws) / 2 - 
                                         (z_adt_low_draws + z_vdt_low_draws) / 2
                
                # Validate contrast draws
                if (any(is.na(task_contrast_draws)) || any(is.na(effort_contrast_draws))) {
                  log_error(paste("NA values in contrast draws at", rt_def, thresh))
                  log_error("Skipping contrast computation for this model")
                  contrast_rows <- list()
                } else {
                  # Summarize contrasts (using same format as post-processing script)
                  contrast_rows <- list(
                    # Task contrast (collapsed across effort)
                    data.frame(
                      rt_def = rt_def,
                      threshold = thresh,
                      contrast = "Visual_Auditory",
                      z_diff_mean = mean(task_contrast_draws, na.rm = TRUE),
                      z_diff_median = median(task_contrast_draws, na.rm = TRUE),
                      z_diff_q2.5 = quantile(task_contrast_draws, 0.025, na.rm = TRUE),
                      z_diff_q97.5 = quantile(task_contrast_draws, 0.975, na.rm = TRUE),
                      p_gt0 = mean(task_contrast_draws > 0, na.rm = TRUE),
                      stringsAsFactors = FALSE
                    ),
                    # Effort contrast (collapsed across task)
                    data.frame(
                      rt_def = rt_def,
                      threshold = thresh,
                      contrast = "Low_High",
                      z_diff_mean = mean(effort_contrast_draws, na.rm = TRUE),
                      z_diff_median = median(effort_contrast_draws, na.rm = TRUE),
                      z_diff_q2.5 = quantile(effort_contrast_draws, 0.025, na.rm = TRUE),
                      z_diff_q97.5 = quantile(effort_contrast_draws, 0.975, na.rm = TRUE),
                      p_gt0 = mean(effort_contrast_draws > 0, na.rm = TRUE),
                      stringsAsFactors = FALSE
                    )
                  )
                  
                  # Validate quantiles are not NA/NaN
                  for (i in seq_along(contrast_rows)) {
                    if (is.na(contrast_rows[[i]]$z_diff_q2.5) || is.na(contrast_rows[[i]]$z_diff_q97.5) ||
                        is.nan(contrast_rows[[i]]$z_diff_q2.5) || is.nan(contrast_rows[[i]]$z_diff_q97.5)) {
                      log_error(paste("NA/NaN quantiles computed for contrast", contrast_rows[[i]]$contrast, 
                                     "at", rt_def, thresh))
                      log_error(paste("  Task contrast draws: n=", length(task_contrast_draws),
                                     ", mean=", mean(task_contrast_draws, na.rm = TRUE)))
                      log_error(paste("  Effort contrast draws: n=", length(effort_contrast_draws),
                                     ", mean=", mean(effort_contrast_draws, na.rm = TRUE)))
                      contrast_rows <- list()  # Clear invalid contrasts
                      break
                    }
                  }
                }
              }
              
              # Store contrasts for this run (in outer-scope list) only if valid
              if (length(contrast_rows) > 0) {
                contrast_key <- paste0(rt_def, "__", formatC(thresh, format="f", digits=2))
                standard_contrast_list[[contrast_key]] <- bind_rows(contrast_rows)
                log_info("Computed condition-level bias predictions and contrasts from posterior draws")
                log_info(paste("  Contrasts:", paste(sapply(contrast_rows, function(x) x$contrast), collapse = ", ")))
              } else {
                log_warn(paste("No valid contrasts computed for", rt_def, "at threshold", thresh))
              }
            } else {
              log_warn(paste("z_draws_matrix has unexpected shape:", 
                            ifelse(is.matrix(z_draws_matrix), 
                                   paste(dim(z_draws_matrix), collapse = "x"), 
                                   "not a matrix")))
            }
          }, error = function(e) {
            log_error(paste("Failed to compute condition-level bias and contrasts:", e$message))
            log_error(paste("Error details:", deparse(e$call)))
            bias_by_condition <- NULL
          })
        }
        
        # Ensure output_rds_path_standard exists (defensive check)
        if (!exists("output_rds_path_standard")) {
          output_rds_path_standard <- file.path(MODELS_DIR, paste0("standard_only__", rt_def, "__thr", 
                                                                    formatC(thresh, format="f", digits=2), ".rds"))
          log_warn("output_rds_path_standard was not found before creating results; creating default path")
        }
        
        # Store bias_by_condition for later export
        # Note: contrasts are already stored in standard_contrast_list above during computation
        if (!is.null(bias_by_condition)) {
          cond_key <- paste0(rt_def, "__", formatC(thresh, format="f", digits=2))
          standard_bycond_list[[cond_key]] <- bias_by_condition
        }
        
        standard_only_results[[paste0(rt_def, "_", thresh)]] <- data.frame(
          rt_def = rt_def,
          threshold = thresh,
          n_trials = n_trials,
          n_subjects = n_subjects,
          max_rhat = max_rhat,
          min_neff_ratio = min_neff_ratio,
          min_bulk_ess = min_bulk_ess_standard,
          min_tail_ess = min_tail_ess_standard,
          n_divergent = divergences_standard,
          n_treedepth_hits = n_treedepth_standard,
          drift_intercept = drift_intercept,
          bias_intercept = bias_intercept,
          bias_task_VDT_vs_ADT = bias_task_VDT_vs_ADT,
          bias_effort_high_vs_low = bias_effort_high_vs_low,
          stringsAsFactors = FALSE
        )
        
        # Add to run_index
        run_index_row_standard <- data.frame(
          analysis_id = analysis_id,
          model_name = "standard_only",
          threshold = as.numeric(thresh),  # Ensure numeric
          rt_def = rt_def,
          input_file = input_file,
          N_trials = n_trials,
          N_subjects = n_subjects,
          min_rt_model = min_rt_model,
          divergences = ifelse(is.na(divergences_standard), 0L, as.integer(divergences_standard)),
          treedepth_hits = ifelse(is.na(n_treedepth_standard), 0L, as.integer(n_treedepth_standard)),
          max_rhat = max_rhat,
          min_bulk_ess = ifelse(is.na(min_bulk_ess_standard), NA_real_, min_bulk_ess_standard),
          min_tail_ess = ifelse(is.na(min_tail_ess_standard), NA_real_, min_tail_ess_standard),
          time_elapsed_sec = time_elapsed_standard,
          output_rds_path = output_rds_path_standard,
          stringsAsFactors = FALSE
        )
        if (file.exists(RUN_INDEX_FILE) && file.info(RUN_INDEX_FILE)$size > 0) {
          existing_index <- read_csv(RUN_INDEX_FILE, show_col_types = FALSE)
          # Ensure numeric columns are numeric in both data frames
          numeric_cols <- c("threshold", "N_trials", "N_subjects", "min_rt_model", 
                            "divergences", "treedepth_hits", "max_rhat", "min_bulk_ess", 
                            "min_tail_ess", "time_elapsed_sec")
          for (col in numeric_cols) {
            if (col %in% names(existing_index)) {
              existing_index[[col]] <- as.numeric(existing_index[[col]])
            }
            if (col %in% names(run_index_row_standard)) {
              run_index_row_standard[[col]] <- as.numeric(run_index_row_standard[[col]])
            }
          }
          run_index <- bind_rows(existing_index, run_index_row_standard)
        } else {
          run_index <- run_index_row_standard
        }
        write_csv(run_index, RUN_INDEX_FILE)
        
        log_info(paste("  ✓ Fitted (R-hat:", round(max_rhat, 4), ", ESS ratio:", round(min_neff_ratio, 3), ")"))
      }
    }
    
    # Save summary
    if (length(standard_only_results) > 0) {
      standard_only_df <- tryCatch({
        bind_rows(standard_only_results)
      }, error = function(e) {
        log_error(paste("Failed to bind standard_only_results:", e$message))
        log_error("standard_only_results structure:")
        for (i in seq_along(standard_only_results)) {
          log_error(paste("  Element", i, "columns:", paste(names(standard_only_results[[i]]), collapse = ", ")))
        }
        return(data.frame())  # Return empty data.frame
      })
      
      # =========================================================================
      # REGENERATE SUMMARY FROM FIXEF TABLE (ensures no NaN values)
      # =========================================================================
      # The summary CSV should be regenerated from fixef to ensure correct term names
      # and no NaN values
      if (length(standard_fixef_list) > 0 && nrow(standard_only_df) > 0) {
        # Try to regenerate summary from fixef if available
        summary_regenerated <- tryCatch({
          fixef_all_temp <- bind_rows(standard_fixef_list)
          
          # Extract task and effort effects for each run
          summary_from_fixef <- list()
          for (key in names(standard_fixef_list)) {
            fx <- standard_fixef_list[[key]]
            
            # Use raw_term if available (from tidy_fixef_wiener), otherwise fall back to term
            term_col <- if ("raw_term" %in% names(fx)) fx$raw_term else fx$term
            
            # Extract task effect (bias_taskVDT)
            # Search in raw_term (or term) for patterns, then match by dpar if available
            task_match <- grepl("^bias_taskVDT|^bias_task_VDT", term_col)
            if ("dpar" %in% names(fx)) {
              task_match <- task_match & fx$dpar == "bias"
            }
            task_term <- term_col[task_match][1]
            task_est <- if (length(task_term) > 0 && !is.na(task_term)) {
              fx$Estimate[term_col == task_term][1]
            } else NA_real_
            
            # Extract effort effect (bias_effort_conditionhigh)
            effort_match <- grepl("^bias_effort_conditionhigh|^bias_effort_condition_high", term_col)
            if ("dpar" %in% names(fx)) {
              effort_match <- effort_match & fx$dpar == "bias"
            }
            effort_term <- term_col[effort_match][1]
            effort_est <- if (length(effort_term) > 0 && !is.na(effort_term)) {
              fx$Estimate[term_col == effort_term][1]
            } else NA_real_
            
            # Check for "Low" coding
            if (is.na(effort_est)) {
              effort_low_match <- grepl("^bias_effort_conditionLow|^bias_effort_condition_Low", term_col)
              if ("dpar" %in% names(fx)) {
                effort_low_match <- effort_low_match & fx$dpar == "bias"
              }
              effort_low_term <- term_col[effort_low_match][1]
              if (length(effort_low_term) > 0 && !is.na(effort_low_term)) {
                effort_est <- -fx$Estimate[term_col == effort_low_term][1]  # Negate
              }
            }
            
            # Extract intercept (bias_Intercept)
            intercept_match <- grepl("^bias_Intercept$", term_col)
            if ("dpar" %in% names(fx)) {
              intercept_match <- intercept_match & fx$dpar == "bias"
            }
            intercept_term <- term_col[intercept_match][1]
            intercept_est <- if (length(intercept_term) > 0 && !is.na(intercept_term)) {
              plogis(fx$Estimate[term_col == intercept_term][1])  # Transform to natural scale
            } else NA_real_
            
            # Extract drift intercept (Intercept with dpar="v" or no dpar prefix)
            drift_match <- grepl("^Intercept$", term_col) & !grepl("bias|bs|ndt", term_col)
            if ("dpar" %in% names(fx)) {
              drift_match <- drift_match & (fx$dpar == "v" | is.na(fx$dpar))
            }
            drift_term <- term_col[drift_match][1]
            drift_est <- if (length(drift_term) > 0 && !is.na(drift_term)) {
              fx$Estimate[term_col == drift_term][1]
            } else NA_real_
            
            # Get metadata from fx
            rt_type_val <- unique(fx$rt_type)[1]
            threshold_val <- unique(fx$threshold)[1]
            n_trials_val <- unique(fx$n_trials)[1]
            n_subjects_val <- unique(fx$n_subjects)[1]
            
            # Get diagnostics from standard_diag_list
            diag_key <- paste0("standard_only|", rt_type_val, "|thr_", formatC(threshold_val, format="f", digits=2))
            max_rhat_val <- NA_real_
            min_bulk_ess_val <- NA_real_
            if (diag_key %in% names(standard_diag_list)) {
              max_rhat_val <- standard_diag_list[[diag_key]]$max_rhat
              min_bulk_ess_val <- standard_diag_list[[diag_key]]$min_bulk_ess
            }
            
            summary_from_fixef[[key]] <- data.frame(
              rt_def = rt_type_val,
              threshold = threshold_val,
              n_trials = n_trials_val,
              n_subjects = n_subjects_val,
              max_rhat = max_rhat_val,
              min_bulk_ess = min_bulk_ess_val,
              bias_intercept = intercept_est,
              bias_task_VDT_vs_ADT = task_est,
              bias_effort_high_vs_low = effort_est,
              drift_intercept = drift_est,
              stringsAsFactors = FALSE
            )
          }
          
          bind_rows(summary_from_fixef)
        }, error = function(e) {
          log_warn(paste("Failed to regenerate summary from fixef:", e$message))
          return(standard_only_df)  # Fallback to original
        })
        
        # Use regenerated summary if successful and has no NaN
        if (nrow(summary_regenerated) > 0) {
          na_count <- sum(is.na(summary_regenerated$bias_task_VDT_vs_ADT)) + 
                     sum(is.na(summary_regenerated$bias_effort_high_vs_low))
          if (na_count == 0) {
            standard_only_df <- summary_regenerated
            log_info("✓ Regenerated summary from fixef table (no NaN values)")
          } else {
            log_warn(paste("Regenerated summary still has", na_count, "NA values; using original"))
          }
        }
        
        summary_file <- file.path(SUMMARIES_DIR, "standard_only_bias_summary.csv")
        write_csv(standard_only_df, summary_file)
        log_info(paste("Saved:", summary_file))
        
        # Validation: check for NaN in task/effort columns
        na_task_effort <- sum(is.na(standard_only_df$bias_task_VDT_vs_ADT)) + 
                         sum(is.na(standard_only_df$bias_effort_high_vs_low))
        if (na_task_effort > 0) {
          log_error(paste("VALIDATION FAILED: standard_only_bias_summary.csv has", 
                         na_task_effort, "NA values in task/effort effect columns"))
          log_error("Available fixef terms for debugging:")
          for (key in names(standard_fixef_list)) {
            fx <- standard_fixef_list[[key]]
            # Use raw_term if available, otherwise term
            term_col <- if ("raw_term" %in% names(fx)) fx$raw_term else fx$term
            if ("dpar" %in% names(fx)) {
              bias_terms <- term_col[fx$dpar == "bias"]
            } else {
              bias_terms <- term_col[grepl("^bias_", term_col)]
            }
            log_error(paste("  ", key, ":", paste(bias_terms, collapse = ", ")))
          }
          stop("Standard-only summary export validation failed")
        } else {
          log_info("✓ Summary validation passed: no NaN in task/effort effects")
        }
        
        log_info("Summary:")
        print(standard_only_df)
        
        # Also save to legacy location
        write_csv(standard_only_df, file.path(OUTPUT_DIR, "standard_only_bias_summary.csv"))
      } else {
        log_warn("standard_only_df is empty after bind_rows; skipping CSV write")
      }
      
      # =========================================================================
      # EXPORT CONDITION-LEVEL BIAS PREDICTIONS (from stored list)
      # =========================================================================
      if (length(standard_bycond_list) > 0) {
        bias_by_condition_df <- tryCatch({
          bind_rows(standard_bycond_list)
        }, error = function(e) {
          log_error(paste("Failed to bind standard_bycond_list:", e$message))
          return(data.frame())
        })
        
        if (nrow(bias_by_condition_df) > 0) {
          # Remove any NaN values
          bias_by_condition_df <- bias_by_condition_df %>%
            mutate(across(where(is.numeric), ~ ifelse(is.nan(.x), NA_real_, .x)))
          
          # Validation: check expected row count
          n_rt_types <- length(unique(bias_by_condition_df$rt_def))
          n_thresholds <- length(unique(bias_by_condition_df$threshold))
          expected_rows <- n_rt_types * n_thresholds * 4  # 4 conditions per run
          if (nrow(bias_by_condition_df) != expected_rows) {
            log_warn(paste("WARNING: bias_by_condition_df has", nrow(bias_by_condition_df), 
                          "rows but expected", expected_rows))
            log_warn(paste("  RT types:", n_rt_types, "| Thresholds:", n_thresholds))
          }
          
          # Validation: check for NA quantiles
          na_quantiles <- sum(is.na(bias_by_condition_df$z_q2.5)) + sum(is.na(bias_by_condition_df$z_q97.5))
          if (na_quantiles > 0) {
            log_error(paste("VALIDATION FAILED: bias_by_condition_df has", 
                           na_quantiles, "NA quantile values"))
            stop("Standard-only condition-level bias export validation failed")
          }
          
          bias_condition_file <- file.path(TABLES_DIR, "standard_only_bias_by_condition.csv")
          write_csv(bias_by_condition_df, bias_condition_file)
          log_info(paste("Saved condition-level bias:", bias_condition_file))
          log_info(paste("  Rows:", nrow(bias_by_condition_df), "| Expected:", expected_rows))
          log_info("✓ Condition-level bias validation passed")
        } else {
          log_warn("bias_by_condition_df is empty after bind_rows")
        }
      } else {
        log_warn("standard_bycond_list is empty; no condition-level predictions to export")
      }
      
      # =========================================================================
      # EXPORT CONTRASTS (from stored list - computed from posterior draws)
      # =========================================================================
      if (length(standard_contrast_list) > 0) {
        contrasts_df <- tryCatch({
          bind_rows(standard_contrast_list)
        }, error = function(e) {
          log_error(paste("Failed to bind standard_contrast_list:", e$message))
          return(data.frame())
        })
        
        if (nrow(contrasts_df) > 0) {
          # Remove any NaN values
          contrasts_df <- contrasts_df %>%
            mutate(across(where(is.numeric), ~ ifelse(is.nan(.x), NA_real_, .x)))
          
          contrasts_file <- file.path(TABLES_DIR, "standard_only_bias_contrasts.csv")
          write_csv(contrasts_df, contrasts_file)
          log_info(paste("Saved bias contrasts:", contrasts_file))
          log_info(paste("  Rows:", nrow(contrasts_df), "| Expected:", 
                        length(standard_contrast_list) * 2, "contrasts (2 per model: Visual_Auditory, Low_High)"))
          
          # Validation: check for NA quantiles and ensure draws were used
          if (!"z_diff_q2.5" %in% names(contrasts_df) || !"z_diff_q97.5" %in% names(contrasts_df)) {
            log_error("VALIDATION FAILED: standard_only_bias_contrasts.csv missing required quantile columns")
            log_error(paste("Expected columns: z_diff_q2.5, z_diff_q97.5"))
            log_error(paste("Found columns:", paste(names(contrasts_df), collapse = ", ")))
            stop("Standard-only contrast export validation failed: missing columns")
          }
          
          na_quantiles <- sum(is.na(contrasts_df$z_diff_q2.5)) + sum(is.na(contrasts_df$z_diff_q97.5))
          if (na_quantiles > 0) {
            log_error(paste("VALIDATION FAILED: standard_only_bias_contrasts.csv has", 
                           na_quantiles, "NA quantile values"))
            log_error("This indicates contrasts were not computed from posterior draws correctly")
            log_error("Contrasts must be computed from posterior draws, not from condition-level means")
            # Show which rows have NA
            na_rows <- contrasts_df[is.na(contrasts_df$z_diff_q2.5) | is.na(contrasts_df$z_diff_q97.5), ]
            log_error(paste("Rows with NA quantiles:", nrow(na_rows)))
            for (i in 1:min(5, nrow(na_rows))) {
              log_error(paste("  Row", i, ":", paste(na_rows[i, c("rt_def", "threshold", "contrast")], collapse = ", ")))
            }
            stop("Standard-only contrast export validation failed")
          }
          
          # Additional validation: check that quantiles are reasonable
          invalid_quantiles <- sum(contrasts_df$z_diff_q2.5 > contrasts_df$z_diff_q97.5, na.rm = TRUE)
          if (invalid_quantiles > 0) {
            log_error(paste("VALIDATION FAILED: standard_only_bias_contrasts.csv has", 
                           invalid_quantiles, "rows where q2.5 > q97.5"))
            stop("Standard-only contrast export validation failed: invalid quantile order")
          }
          
          # Check for NaN values (should have been converted to NA, but double-check)
          nan_check <- sum(is.nan(contrasts_df$z_diff_q2.5)) + sum(is.nan(contrasts_df$z_diff_q97.5))
          if (nan_check > 0) {
            log_error(paste("VALIDATION FAILED: standard_only_bias_contrasts.csv has", 
                           nan_check, "NaN quantile values"))
            stop("Standard-only contrast export validation failed: NaN values present")
          }
          
          log_info("✓ Contrast validation passed: all quantiles computed from posterior draws")
        } else {
          log_warn("contrasts_df is empty after bind_rows")
        }
      } else {
        log_warn("standard_contrast_list is empty; no contrasts to export")
      }
      
      # =========================================================================
      # EXPORT FIXED EFFECTS ON LINK SCALE (from stored fixef_list)
      # =========================================================================
      # TIDY FIXEF FUNCTION FOR WIENER MODELS
      # =========================================================================
      tidy_fixef_wiener <- function(fit, meta) {
        # Extract fixef matrix
        fx <- brms::fixef(fit)
        
        # Convert to tibble with rownames
        df <- tibble::as_tibble(fx, rownames = "raw_term")
        
        # Create dpar and clean term columns
        df <- df %>%
          mutate(
            dpar = case_when(
              startsWith(raw_term, "bs_") ~ "bs",
              startsWith(raw_term, "ndt_") ~ "ndt",
              startsWith(raw_term, "bias_") ~ "bias",
              TRUE ~ "v"
            ),
            term = case_when(
              startsWith(raw_term, "bs_") ~ sub("^bs_", "", raw_term),
              startsWith(raw_term, "ndt_") ~ sub("^ndt_", "", raw_term),
              startsWith(raw_term, "bias_") ~ sub("^bias_", "", raw_term),
              TRUE ~ raw_term
            )
          )
        
        # Rename columns to EXACTLY: Estimate, Est.Error, Q2.5, Q97.5
        # brms uses these names already, but ensure they're correct
        col_names_map <- c(
          "Estimate" = "Estimate",
          "Est.Error" = "Est.Error",
          "Q2.5" = "Q2.5",
          "Q97.5" = "Q97.5"
        )
        
        # Verify required columns exist
        required_cols <- c("Estimate", "Est.Error", "Q2.5", "Q97.5")
        missing_cols <- setdiff(required_cols, names(df))
        if (length(missing_cols) > 0) {
          stop("Missing required columns in fixef: ", paste(missing_cols, collapse = ", "))
        }
        
        # Select and rename columns (keep raw_term for validation)
        df <- df %>%
          select(raw_term, dpar, term, Estimate, Est.Error, Q2.5, Q97.5)
        
        # Bind meta columns
        df$model <- meta$model
        df$rt_type <- meta$rt_type
        df$threshold <- meta$threshold
        df$n_trials <- meta$n_trials
        
        # Validate
        assert_no_na(df, c("Estimate", "Q2.5", "Q97.5"), "standard_only fixef tidy")
        
        # Stop if ANY raw_term contains "bias_" but dpar != "bias"
        bias_mismatch <- df %>%
          filter(grepl("^bias_", raw_term) & dpar != "bias")
        if (nrow(bias_mismatch) > 0) {
          stop("Found raw_term with 'bias_' prefix but dpar != 'bias': ", 
               paste(bias_mismatch$raw_term, collapse = ", "))
        }
        
        # Stop if ANY raw_term contains "bs_" but dpar != "bs"
        bs_mismatch <- df %>%
          filter(grepl("^bs_", raw_term) & dpar != "bs")
        if (nrow(bs_mismatch) > 0) {
          stop("Found raw_term with 'bs_' prefix but dpar != 'bs': ", 
               paste(bs_mismatch$raw_term, collapse = ", "))
        }
        
        # Stop if ANY dpar is NA
        if (any(is.na(df$dpar))) {
          na_dpar_terms <- df$raw_term[is.na(df$dpar)]
          stop("Found NA dpar values for terms: ", paste(na_dpar_terms, collapse = ", "))
        }
        
        # Keep raw_term column for backward compatibility with extraction code
        # Reorder columns: dpar, term, raw_term, Estimate, Est.Error, Q2.5, Q97.5, then meta
        df <- df %>%
          select(dpar, term, raw_term, Estimate, Est.Error, Q2.5, Q97.5, model, rt_type, threshold, n_trials)
        
        return(df)
      }
      
      # =========================================================================
      # ACCEPTANCE CRITERIA (verified in code):
      # 1. Running the script creates:
      #    - output/ddm_refits/runs/<run_id>/tables/standard_only_bias_fixef_link_scale.csv
      #    - output/ddm_refits/runs/<run_id>/tables/standard_only_bias_convergence.csv
      # 2. standard_only_bias_summary.csv has NO NA in Task/Effort bias effect columns
      #    (or script warns loudly with exact missing term names)
      # 3. Logs show bias term names for each standard-only run for immediate debugging
      # 4. fixef is stored per run/threshold/RT definition to avoid scope/lifetime issues
      # 5. Summary extraction uses safe name matching that cannot silently produce NA
      if (length(standard_fixef_list) > 0) {
        log_info("Exporting standard-only bias fixed effects on link scale...")
        
        # Combine all fixef from stored list
        standard_fixef_all <- tryCatch({
          bind_rows(standard_fixef_list)
        }, error = function(e) {
          log_error(paste("Failed to bind standard_fixef_list:", e$message))
          return(data.frame())
        })
        
        if (nrow(standard_fixef_all) > 0) {
          # Validation: check for NA estimates
          na_estimates <- sum(is.na(standard_fixef_all$Estimate))
          if (na_estimates > 0) {
            log_error(paste("VALIDATION FAILED: standard_fixef_all has", na_estimates, "NA Estimate values"))
            log_error("This indicates fixef extraction failed for some models")
            stop("Standard-only fixef export validation failed")
          }
          
          # Verify required columns exist
          required_cols <- c("Estimate", "Est.Error", "Q2.5", "Q97.5", "dpar", "term", "model", "rt_type", "threshold", "n_trials")
          missing_cols <- setdiff(required_cols, names(standard_fixef_all))
          if (length(missing_cols) > 0) {
            log_warn(paste("Missing columns in standard_fixef_all:", paste(missing_cols, collapse = ", ")))
            log_warn("Some columns may be missing due to fallback fixef extraction")
          }
          
          fixef_link_file <- file.path(TABLES_DIR, "standard_only_bias_fixef_link_scale.csv")
          write_csv_logged(standard_fixef_all, fixef_link_file)
        } else {
          log_warn("standard_fixef_all is empty; skipping fixef export")
        }
      } else {
        log_warn("standard_fixef_list is empty; no fixef to export")
      }
      
      # =========================================================================
      # EXPORT CONVERGENCE DIAGNOSTICS
      # =========================================================================
      if (length(standard_diag_list) > 0) {
        standard_diag_all <- tryCatch({
          bind_rows(standard_diag_list)
        }, error = function(e) {
          log_error(paste("Failed to bind diagnostics:", e$message))
          return(data.frame())
        })
        
        if (nrow(standard_diag_all) > 0) {
          diag_file <- file.path(TABLES_DIR, "standard_only_bias_convergence.csv")
          write_csv(standard_diag_all, diag_file)
          log_info(paste("Saved:", diag_file))
        }
      }
    } else {
      log_warn("No standard-only models were successfully fitted.")
    }
  }
} else {
  cat("\nSTEP 6: Standard-only bias calibration models (SKIPPED via DDM_SKIP_STANDARD_ONLY=1)\n\n")
}

# =========================================================================
# STEP 7: DECIDE ON PRIMARY MODEL
# =========================================================================

cat("\nSTEP 7: Deciding on primary model...\n\n")

# Default recommendation: probe_onset_locked (by design logic)
recommended_rt <- "probe_onset_locked"
recommendation_rationale <- "Default: probe_onset_locked aligns with task design (probe onset + grip relax + RT from window)"

if (!DRY_RUN && exists("summaries") && !is.null(summaries) && 
    "baseline_cue" %in% names(summaries) && "baseline_probe" %in% names(summaries) &&
    !is.null(summaries[["baseline_cue"]]) && !is.null(summaries[["baseline_probe"]])) {
  cue_summary <- summaries[["baseline_cue"]]$convergence
  probe_summary <- summaries[["baseline_probe"]]$convergence
  
  if (!is.null(cue_summary) && !is.null(probe_summary)) {
    cat("  Cue-locked RT model:\n")
    cat("    Max R-hat:", round(cue_summary$max_rhat, 4), "\n")
    cat("    Min ESS ratio:", round(cue_summary$min_neff_ratio, 3), "\n")
    
    cat("  Probe-onset-locked RT model:\n")
    cat("    Max R-hat:", round(probe_summary$max_rhat, 4), "\n")
    cat("    Min ESS ratio:", round(probe_summary$min_neff_ratio, 3), "\n")
    
    # Decision: prefer model with better convergence, but default to probe_onset_locked
    if (cue_summary$max_rhat < probe_summary$max_rhat && 
        cue_summary$min_neff_ratio > probe_summary$min_neff_ratio) {
      recommended_rt <- "cue_locked"
      recommendation_rationale <- "Cue-locked RT has better convergence metrics"
      cat("\n  RECOMMENDATION: Use cue-locked RT (better convergence)\n")
    } else {
      recommended_rt <- "probe_onset_locked"
      recommendation_rationale <- "Probe-onset-locked RT (default by design; convergence metrics acceptable)"
      cat("\n  RECOMMENDATION: Use probe-onset-locked RT (default by design)\n")
    }
  } else {
    cat("  RECOMMENDATION: Use probe-onset-locked RT (default by design; convergence summaries unavailable)\n")
  }
} else {
  cat("  RECOMMENDATION: Use probe-onset-locked RT (default by design)\n")
}

# Save recommendation with rationale (with defensive check)
if (exists("recommended_rt") && exists("recommendation_rationale")) {
  recommendation_text <- paste0(
    recommended_rt, "\n",
    "# Rationale: ", recommendation_rationale, "\n",
    "# RT constants: GripRelaxTime = ", GRIP_RELAX_SEC, "s, ProbeDuration = ", PROBE_DUR_SEC, "s\n",
    "# probe_onset_locked = cue_locked + ", PROBE_ONSET_TO_PROMPT_SEC, "s\n"
  )
  write_lines(
    recommendation_text,
    file.path(RESULTS_DIR, "recommended_rt_definition.txt")
  )
} else {
  log_warn("recommended_rt or recommendation_rationale not found; skipping recommendation file")
}

# =========================================================================
# FINAL SUMMARY
# =========================================================================

cat("\n================================================================================\n")
cat("DDM REFITTING COMPLETE\n")
cat("================================================================================\n")
cat("Chosen RT threshold:", CHOSEN_THRESHOLD, "seconds\n")
if (exists("recommended_rt")) {
  cat("Recommended RT definition:", recommended_rt, "\n")
  cat("Rationale:", recommendation_rationale, "\n")
} else {
  cat("Recommended RT definition: probe_onset_locked (default)\n")
  cat("Rationale: Default by design\n")
}
cat("\nOutput files:\n")
cat("  - Fixed effects comparison:", file.path(RESULTS_DIR, "ddm_fixef_comparison_rt_definitions.csv"), "\n")
cat("  - Convergence diagnostics:", file.path(RESULTS_DIR, "ddm_convergence_comparison.csv"), "\n")
cat("  - Sensitivity analysis:", file.path(RESULTS_DIR, "ddm_sensitivity_thresholds.csv"), "\n")
cat("  - Models saved in:", OUTPUT_DIR, "\n")
cat("  - Log file:", LOG_FILE, "\n")
cat("================================================================================\n")

# =========================================================================
# GENERATE RUN REPORT
# =========================================================================

set_step("GENERATE_REPORT")

generate_run_report <- function() {
  report_lines <- c(
    "# DDM Refitting Run Report",
    "",
    paste("**Generated:**", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    paste("**Git commit:**", git_commit),
    "",
    "## Configuration",
    "",
    paste("- **Input dataset:**", input_file, "(USING ddm_ready_data_unthresholded.csv)"),
    paste("- **R version:**", R.version.string),
    paste("- **brms version:**", as.character(packageVersion("brms"))),
    paste("- **cmdstanr version:**", tryCatch(as.character(packageVersion("cmdstanr")), error = function(e) "not installed")),
    paste("- **cmdstan path:**", cmdstan_path),
    "",
    "### Settings",
    "",
    paste("- **Chosen threshold:**", CHOSEN_THRESHOLD, "seconds"),
    paste("- **Sensitivity thresholds:**", paste(SENSITIVITY_THRESHOLDS, collapse=", ")),
    paste("- **MCMC chains:**", N_CHAINS),
    paste("- **MCMC iterations:**", N_ITER),
    paste("- **Warmup:**", N_WARMUP),
    paste("- **Dry run mode:**", DRY_RUN),
    paste("- **Continue on failures:**", CONTINUE_ON_FAIL),
    "",
    "## Data Summary",
    "",
    paste("- **Total trials loaded:**", nrow(df_raw)),
    paste("- **Trials after filtering:**", nrow(ddm_data)),
    paste("- **Unique subjects:**", length(unique(ddm_data$subject_id))),
    "",
    "### RT Quantiles: rt_cue_locked (pre-filter)",
    "",
    "| Quantile | Value (seconds) |",
    "|----------|------------------|"
  )
  
  # Add RT quantiles for rt_cue_locked (pre-filter) - ensure real numbers, not NA
  if (exists("ddm_data") && "rt_cue" %in% names(ddm_data)) {
    rt_quantiles_pre <- quantile(ddm_data$rt_cue, probs = c(0, 0.01, 0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99, 1), na.rm = TRUE)
    for (i in seq_along(rt_quantiles_pre)) {
      q_val <- ifelse(is.na(rt_quantiles_pre[i]) || is.nan(rt_quantiles_pre[i]), 
                      "N/A", round(rt_quantiles_pre[i], 4))
      report_lines <- c(report_lines, 
        paste("|", names(rt_quantiles_pre)[i], "|", q_val, "|"))
    }
  } else {
    report_lines <- c(report_lines, "| (data not available) | |")
  }
  
  # Add post-filter RT summaries per threshold
  report_lines <- c(report_lines,
    "",
    "### Post-Filter RT Summaries (per threshold)",
    "",
    "| Threshold | RT Type | Min | Median | Max |",
    "|-----------|---------|-----|--------|-----|"
  )
  
  for (thresh in SENSITIVITY_THRESHOLDS) {
    # Get post-filter data for this threshold
    data_thresh_temp <- tryCatch({
      apply_threshold_and_rt_def(ddm_data, thresh, "cue_locked")
    }, error = function(e) NULL)
    
    if (!is.null(data_thresh_temp) && nrow(data_thresh_temp) > 0) {
      # rt_cue (post-filter)
      min_cue <- round(min(data_thresh_temp$rt_cue, na.rm = TRUE), 4)
      med_cue <- round(median(data_thresh_temp$rt_cue, na.rm = TRUE), 4)
      max_cue <- round(max(data_thresh_temp$rt_cue, na.rm = TRUE), 4)
      report_lines <- c(report_lines,
        paste("|", thresh, "s | rt_cue_locked |", min_cue, "|", med_cue, "|", max_cue, "|"))
      
      # rt_probe_onset_locked (derived)
      if ("rt_model" %in% names(data_thresh_temp)) {
        min_probe <- round(min(data_thresh_temp$rt_model, na.rm = TRUE), 4)
        med_probe <- round(median(data_thresh_temp$rt_model, na.rm = TRUE), 4)
        max_probe <- round(max(data_thresh_temp$rt_model, na.rm = TRUE), 4)
        report_lines <- c(report_lines,
          paste("|", thresh, "s | rt_probe_onset_locked |", min_probe, "|", med_probe, "|", max_probe, "|"))
      }
    }
  }
  
  report_lines <- c(report_lines,
    "",
    "### Trial Counts by Threshold (applied to rt_cue_locked)",
    "",
    "| Threshold | Trials Remaining |",
    "|-----------|------------------|"
  )
  
  for (thresh in SENSITIVITY_THRESHOLDS) {
    # Count trials after applying filters and threshold
    data_thresh_temp <- tryCatch({
      apply_rt_filters(ddm_data, rt_floor = 0, rt_ceiling = 3.0)
      data_thresh_temp <- data_thresh_temp %>% filter(rt_cue >= thresh)
      nrow(data_thresh_temp)
    }, error = function(e) {
      return(0)
    })
    report_lines <- c(report_lines, paste("|", thresh, "s |", data_thresh_temp, "|"))
  }
  
  report_lines <- c(report_lines,
    "",
    "## Model Fit Status",
    "",
    "| Model | RT Definition | Status | Max R-hat | Min ESS Ratio | Error |",
    "|-------|---------------|--------|-----------|---------------|-------|"
  )
  
  # Add model statuses (if model_fit_status exists)
  if (exists("model_fit_status") && length(model_fit_status) > 0) {
    for (model_key in names(model_fit_status)) {
      status_info <- model_fit_status[[model_key]]
      max_rhat_str <- if (!is.null(status_info$max_rhat)) round(status_info$max_rhat, 4) else "N/A"
      min_neff_str <- if (!is.null(status_info$min_neff_ratio)) round(status_info$min_neff_ratio, 3) else "N/A"
      error_str <- if (!is.null(status_info$error) && !is.na(status_info$error)) status_info$error else "None"
      
      report_lines <- c(report_lines,
        paste("|", status_info$model_name, "|", status_info$rt_type, "|", 
              status_info$status, "|", max_rhat_str, "|", min_neff_str, "|", error_str, "|"))
    }
  } else {
    report_lines <- c(report_lines, "| (model status not available) | | | | | |")
  }
  
  report_lines <- c(report_lines,
    "",
    "## Output Files",
    "",
    paste("- **Log file:**", LOG_FILE),
    paste("- **Models directory:**", MODELS_DIR),
    paste("- **Tables directory (QMD-ready):**", TABLES_DIR),
    paste("- **Summaries directory:**", SUMMARIES_DIR),
    "",
    "### Key CSV Exports",
    "",
    paste("- **Convergence summary:**", file.path(TABLES_DIR, "convergence_summary.csv")),
    paste("- **LOO summary:**", file.path(TABLES_DIR, "loo_summary.csv")),
    paste("- **Fixed effects (link scale):**", file.path(TABLES_DIR, "fixef_link_scale.csv")),
    paste("- **Descriptive behavioral by condition:**", file.path(TABLES_DIR, "descriptive_behavioral_by_condition.csv")),
    paste("- **Predicted parameters by condition:**", file.path(TABLES_DIR, "predicted_parameters_by_condition.csv")),
    paste("- **Standard-only bias by condition:**", file.path(TABLES_DIR, "standard_only_bias_by_condition.csv")),
    paste("- **Standard-only bias contrasts:**", file.path(TABLES_DIR, "standard_only_bias_contrasts.csv")),
    paste("- **Standard-only bias fixef (link scale):**", file.path(TABLES_DIR, "standard_only_bias_fixef_link_scale.csv")),
    paste("- **Standard-only bias convergence:**", file.path(TABLES_DIR, "standard_only_bias_convergence.csv")),
    paste("- **Sensitivity thresholds data:**", file.path(TABLES_DIR, "ddm_sensitivity_thresholds.csv")),
    ""
  )
  
  writeLines(report_lines, REPORT_FILE)
  log_info(paste("Run report saved to:", REPORT_FILE))
}

generate_run_report()

# Close log file
set_step("FINALIZE")
log_info("==================================================================================")
log_info("DDM REFITTING COMPLETE")
log_info("==================================================================================")
log_info(paste("Analysis ID:", analysis_id))
log_info(paste("Chosen RT threshold:", CHOSEN_THRESHOLD, "seconds"))
log_info(paste("Run directory:", RUN_DIR))
log_info(paste("Log file:", LOG_FILE))
log_info(paste("Report file:", REPORT_FILE))
log_info(paste("Run index:", RUN_INDEX_FILE))
log_info("==================================================================================")

# Close logging (with defensive check)
tryCatch({
  sink(type = "output")
  if (exists("log_con") && !is.null(log_con)) {
    close(log_con)
  }
}, error = function(e) {
  # Ignore errors when closing sink/log_con
})

cat("\n✅ Script completed successfully!\n")
if (DRY_RUN) {
  cat("   [DRY RUN] No models were fitted.\n")
}
cat("   Log saved to:", LOG_FILE, "\n")
cat("   Report saved to:", REPORT_FILE, "\n")

# =========================================================================
# FINAL CHECKLIST: OUTPUT FILES
# =========================================================================

cat("\n")
cat("================================================================================\n")
cat("OUTPUT CHECKLIST\n")
cat("================================================================================\n")
cat("Run ID:", analysis_id, "\n")
cat("Output folder:", RUN_DIR, "\n")
cat("\n")

cat("Key output files:\n")
cat("  [LOGS]\n")
cat("    -", LOG_FILE, "\n")
cat("    -", REPORT_FILE, "\n")
cat("\n")

cat("  [MODELS] (saved as .rds files)\n")
if (dir.exists(MODELS_DIR)) {
  model_files <- list.files(MODELS_DIR, pattern = "\\.rds$", full.names = FALSE)
  if (length(model_files) > 0) {
    for (f in model_files) {
      cat("    -", f, "\n")
    }
  } else {
    cat("    - (no models saved - check if DRY_RUN was enabled)\n")
  }
} else {
  cat("    - (models directory not found)\n")
}
cat("\n")

cat("  [TABLES] (QMD-ready CSV exports)\n")
if (dir.exists(TABLES_DIR)) {
  table_files <- list.files(TABLES_DIR, pattern = "\\.csv$", full.names = FALSE)
  if (length(table_files) > 0) {
    for (f in table_files) {
      cat("    -", f, "\n")
    }
  } else {
    cat("    - (no table files found)\n")
  }
} else {
  cat("    - (tables directory not found)\n")
}
cat("\n")

cat("  [SUMMARIES]\n")
if (dir.exists(SUMMARIES_DIR)) {
  summary_files <- list.files(SUMMARIES_DIR, pattern = "\\.csv$", full.names = FALSE)
  if (length(summary_files) > 0) {
    for (f in summary_files) {
      cat("    -", f, "\n")
    }
  }
}
cat("\n")

cat("Expected QMD-ready exports:\n")
expected_tables <- c(
  "convergence_summary.csv",
  "loo_summary.csv", 
  "fixef_link_scale.csv",
  "descriptive_behavioral_by_condition.csv",
  "predicted_parameters_by_condition.csv",
  "standard_only_bias_by_condition.csv",
  "standard_only_bias_contrasts.csv",
  "standard_only_bias_fixef_link_scale.csv",
  "standard_only_bias_convergence.csv",
  "ddm_sensitivity_thresholds.csv"
)
for (tbl in expected_tables) {
  tbl_path <- file.path(TABLES_DIR, tbl)
  status <- if (file.exists(tbl_path)) "✓" else "✗"
  cat("  ", status, " ", tbl, "\n", sep = "")
}
cat("\n")

cat("================================================================================\n")
cat("Analysis complete. Check output folder:", RUN_DIR, "\n")
cat("================================================================================\n")
