#!/usr/bin/env Rscript
# ============================================================================
# Quick-Share: Build Trial-Level QC Dataset
# ============================================================================
# Reads qc_matlab_trial_level_flags.csv OR rebuilds from flat files
# Produces canonical trial-level dataset with correct window definitions
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(tidyr)
  library(data.table)
  library(here)
  library(yaml)
})

cat("=== BUILDING TRIAL-LEVEL QC DATASET ===\n\n")

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

REPO_ROOT <- here::here()

# Try to load config file first
config_file <- file.path(REPO_ROOT, "config", "data_paths.yaml")
if (file.exists(config_file)) {
  config <- read_yaml(config_file)
  PROCESSED_DIR <- config$processed_dir
  if (is.null(PROCESSED_DIR) || PROCESSED_DIR == "") {
    # Fall back to environment variable or default
    PROCESSED_DIR <- Sys.getenv("PUPIL_PROCESSED_DIR")
    if (PROCESSED_DIR == "") {
      PROCESSED_DIR <- file.path(REPO_ROOT, "data", "processed")
    }
  }
} else {
  # Fall back to environment variable or default
  PROCESSED_DIR <- Sys.getenv("PUPIL_PROCESSED_DIR")
  if (PROCESSED_DIR == "") {
    PROCESSED_DIR <- file.path(REPO_ROOT, "data", "processed")
  }
}

OUTPUT_DIR <- file.path(REPO_ROOT, "derived")
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

QC_FLAGS_FILE <- file.path(PROCESSED_DIR, "qc_matlab_trial_level_flags.csv")

cat("Repo root: ", REPO_ROOT, "\n", sep = "")
cat("Processed dir: ", PROCESSED_DIR, "\n", sep = "")
cat("Output dir: ", OUTPUT_DIR, "\n\n", sep = "")

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------

FS <- 250  # Hz
DT <- 1 / FS  # 0.004 s

# Window definitions (based on MATLAB pipeline phase structure)
# From BAP_Pupillometry_Pipeline.m:
# - ITI_Baseline: -3.0 to 0.0 (relative to squeeze onset)
# - Stimulus: 3.75 to 4.45 (target onset at 3.75s)
# - Response_Different: 4.7 to 7.7

BASELINE_WIN <- c(-3.0, 0.0)  # ITI_Baseline phase
TARGET_ONSET <- 3.75  # Start of Stimulus phase
COG_WIN <- c(TARGET_ONSET + 0.3, TARGET_ONSET + 1.3)  # [4.05, 5.05]
STIM_WIN <- c(3.75, 4.45)  # Stimulus phase
RESPONSE_WIN <- c(4.7, 7.7)  # Response_Different phase

# ----------------------------------------------------------------------------
# Helper Functions
# ----------------------------------------------------------------------------

window_validity_pct <- function(pupil_vec, t_rel_vec, t_start, t_end) {
  in_window <- !is.na(t_rel_vec) & t_rel_vec >= t_start & t_rel_vec <= t_end
  if (!any(in_window, na.rm = TRUE)) return(NA_real_)
  pupil_in_window <- pupil_vec[in_window]
  100 * mean(!is.na(pupil_in_window) & is.finite(pupil_in_window), na.rm = TRUE)
}

# ----------------------------------------------------------------------------
# STEP 1: Inspect trial_label values to understand phase structure
# ----------------------------------------------------------------------------

cat("STEP 1: Inspecting trial_label structure...\n")

# Search for flat files - try both exact pattern and broader pattern
flat_files <- list.files(PROCESSED_DIR, pattern = "_(ADT|VDT)_flat\\.csv$", 
                         full.names = TRUE, recursive = TRUE)

# If not found, try broader pattern
if (length(flat_files) == 0) {
  flat_files <- list.files(PROCESSED_DIR, pattern = ".*flat\\.csv$", 
                           full.names = TRUE, recursive = TRUE)
  # Filter to ADT/VDT
  flat_files <- flat_files[str_detect(basename(flat_files), "(ADT|VDT).*flat")]
}

if (length(flat_files) == 0) {
  stop("No *_ADT_flat.csv or *_VDT_flat.csv files found in ", PROCESSED_DIR, 
       "\nPlease check:\n",
       "  1. config/data_paths.yaml has correct processed_dir path\n",
       "  2. Or set PUPIL_PROCESSED_DIR environment variable\n",
       "  3. Or files are in data/processed/")
}

cat("  Found ", length(flat_files), " flat files\n", sep = "")

# Sample a few files to inspect trial_label values (read more rows to see all phases)
label_samples <- list()
n_sample_files <- min(10, length(flat_files))
cat("  Sampling ", n_sample_files, " files for label inspection...\n", sep = "")
for (i in 1:n_sample_files) {
  tryCatch({
    # Read more rows to capture all phases
    sample_df <- fread(flat_files[i], nrows = 50000, select = c("trial_label", "time", "trial_index"))
    if ("trial_label" %in% names(sample_df)) {
      unique_labels <- unique(sample_df$trial_label[!is.na(sample_df$trial_label)])
      label_samples[[i]] <- unique_labels
      if (i <= 5) {  # Only print first 5 to avoid clutter
        cat("  File ", i, ": found labels: ", paste(unique_labels, collapse = ", "), "\n", sep = "")
      }
    }
  }, error = function(e) {
    if (i <= 5) {
      cat("  Warning: Could not sample file ", i, "\n", sep = "")
    }
  })
}

# Build label map
all_labels <- unique(unlist(label_samples))
cat("  Unique labels found: ", paste(all_labels, collapse = ", "), "\n", sep = "")

# Identify target onset labels
target_labels <- all_labels[str_detect(all_labels, regex("target|stim|targ|gabor", ignore_case = TRUE))]
baseline_labels <- all_labels[str_detect(all_labels, regex("baseline|iti|pre", ignore_case = TRUE))]

cat("  Target-related labels: ", paste(target_labels, collapse = ", "), "\n", sep = "")
cat("  Baseline-related labels: ", paste(baseline_labels, collapse = ", "), "\n", sep = "")

# ----------------------------------------------------------------------------
# STEP 2: Check if qc_matlab_trial_level_flags.csv exists
# ----------------------------------------------------------------------------

cat("\nSTEP 2: Checking for existing QC flags file...\n")

if (file.exists(QC_FLAGS_FILE)) {
  cat("  Found: ", QC_FLAGS_FILE, "\n", sep = "")
  qc_flags <- read_csv(QC_FLAGS_FILE, show_col_types = FALSE)
  cat("  Loaded ", nrow(qc_flags), " rows\n", sep = "")
  
  # Check what columns exist
  has_window_cols <- any(str_detect(names(qc_flags), "baseline|stim|response|cog"))
  if (has_window_cols) {
    cat("  ✓ Window validity columns found in QC flags\n")
    use_existing_flags <- TRUE
  } else {
    cat("  ⚠ Window validity columns NOT found, will rebuild from flat files\n")
    use_existing_flags <- FALSE
  }
} else {
  cat("  Not found: ", QC_FLAGS_FILE, "\n", sep = "")
  cat("  Will rebuild from flat files\n")
  use_existing_flags <- FALSE
}

# ----------------------------------------------------------------------------
# STEP 3: Build trial-level dataset
# ----------------------------------------------------------------------------

if (use_existing_flags && has_window_cols) {
  cat("\nSTEP 3: Using existing QC flags...\n")
  
  # Normalize column names
  trial_data <- qc_flags %>%
    mutate(
      subject = as.character(if ("sub" %in% names(.)) sub else subject),
      task = as.character(task),
      session_used = as.integer(if ("session_used" %in% names(.)) session_used else ses),
      run_used = as.integer(if ("run_used" %in% names(.)) run_used else run),
      trial_index = as.integer(trial_index),
      trial_in_run_raw = as.integer(if ("trial_in_run_raw" %in% names(.)) trial_in_run_raw else trial_index),
      has_behavioral_data = as.integer(if ("has_behavioral_data" %in% names(.)) has_behavioral_data else 0L)
    ) %>%
    filter(
      !is.na(subject), !is.na(task), !is.na(session_used), !is.na(run_used), !is.na(trial_index),
      session_used %in% c(2L, 3L),
      task %in% c("ADT", "VDT")
    )
  
  # Map existing columns to canonical names
  if ("pct_non_nan_baseline" %in% names(trial_data)) {
    # Already has baseline
  } else if ("baseline_quality" %in% names(trial_data)) {
    trial_data$pct_non_nan_baseline <- trial_data$baseline_quality * 100
  } else {
    trial_data$pct_non_nan_baseline <- NA_real_
  }
  
  if ("pct_non_nan_overall" %in% names(trial_data)) {
    # Already has overall
  } else if ("overall_quality" %in% names(trial_data)) {
    trial_data$pct_non_nan_overall <- trial_data$overall_quality * 100
  } else {
    trial_data$pct_non_nan_overall <- NA_real_
  }
  
  # Add missing columns with defaults
  trial_data <- trial_data %>%
    mutate(
      pct_non_nan_prestim = if ("pct_non_nan_prestim" %in% names(.)) pct_non_nan_prestim else NA_real_,
      pct_non_nan_stim = if ("pct_non_nan_stim" %in% names(.)) pct_non_nan_stim else NA_real_,
      pct_non_nan_response = if ("pct_non_nan_response" %in% names(.)) pct_non_nan_response else NA_real_,
      pct_non_nan_cogwin = NA_real_,  # Will compute below
      any_timebase_bug = if ("any_timebase_bug" %in% names(.)) any_timebase_bug else 0L,
      window_oob_any = if ("window_oob_any" %in% names(.)) window_oob_any else 
                       if ("window_oob" %in% names(.)) window_oob else 0L,
      all_nan_any = if ("all_nan_any" %in% names(.)) all_nan_any else
                    if ("all_nan" %in% names(.)) all_nan else 0L
    )
  
} else {
  cat("\nSTEP 3: Rebuilding from flat files...\n")
  
  # Process files to build trial-level dataset
  trial_data_list <- list()
  n_files <- length(flat_files)
  
  # Check for test mode (process only first 10 files)
  TEST_MODE <- Sys.getenv("QUICKSHARE_TEST_MODE", "false") == "true"
  if (TEST_MODE) {
    cat("  ⚠ TEST MODE: Processing only first 10 files\n", sep = "")
    flat_files <- flat_files[1:min(10, length(flat_files))]
    n_files <- length(flat_files)
  }
  
  cat("  Processing ", n_files, " files (this may take several minutes)...\n", sep = "")
  start_time <- Sys.time()
  
  for (i in seq_along(flat_files)) {
    if (i %% 10 == 0 || i == 1) {
      elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
      rate <- i / elapsed
      eta <- (n_files - i) / rate
      cat("    Progress: ", i, "/", n_files, " (", sprintf("%.1f", 100*i/n_files), 
          "%) | Elapsed: ", sprintf("%.1f", elapsed), "s | ETA: ", sprintf("%.1f", eta), "s\n", sep = "")
    }
    
    fn <- basename(flat_files[i])
    
    tryCatch({
      # First, peek at column names (fast)
      sample_df <- fread(flat_files[i], nrows = 100)
      available_cols <- names(sample_df)
      
      desired_cols <- c("sub", "task", "ses", "run", "session_used", "run_used",
                       "trial_index", "trial_in_run_raw", "pupil", "time", "trial_label",
                       "has_behavioral_data", "window_oob", "all_nan")
      
      cols_to_read <- intersect(desired_cols, available_cols)
      
      if (length(cols_to_read) < 8) {
        if (i <= 5) cat("    Warning: ", fn, " has too few columns, skipping\n", sep = "")
        next
      }
      
      # Read full file (fread is fast)
      df <- fread(flat_files[i], select = cols_to_read,
                  colClasses = list(character = c("sub", "task", "trial_label"),
                                   integer = c("ses", "run", "session_used", "run_used",
                                              "trial_index", "trial_in_run_raw",
                                              "has_behavioral_data", "window_oob", "all_nan"),
                                   numeric = c("pupil", "time")))
      
      # Normalize
      df <- df %>%
        mutate(
          subject = as.character(sub),
          task = as.character(task),
          session_used = as.integer(if ("session_used" %in% names(.)) session_used else ses),
          run_used = as.integer(if ("run_used" %in% names(.)) run_used else run),
          trial_index = as.integer(trial_index),
          trial_in_run_raw = as.integer(if ("trial_in_run_raw" %in% names(.)) trial_in_run_raw else trial_index),
          pupil = as.numeric(pupil),
          time = as.numeric(time),
          trial_label = as.character(trial_label),
          has_behavioral_data = as.integer(if ("has_behavioral_data" %in% names(.)) has_behavioral_data else 0L),
          window_oob = as.integer(if ("window_oob" %in% names(.)) window_oob else 0L),
          all_nan = as.integer(if ("all_nan" %in% names(.)) all_nan else 0L)
        ) %>%
        filter(
          !is.na(subject), !is.na(task), !is.na(session_used), !is.na(run_used), !is.na(trial_index),
          session_used %in% c(2L, 3L),
          task %in% c("ADT", "VDT"),
          !is.na(time)
        )
      
      if (nrow(df) == 0) next
      
      # Compute t_rel from sample index within each trial
      df <- df %>%
        group_by(subject, task, session_used, run_used, trial_index) %>%
        arrange(time) %>%
        mutate(
          sample_i = row_number(),
          n_samples = n(),
          # Window is [-3, +10.7] = 13.7s total
          dt = 13.7 / (n_samples - 1),
          t_rel = -3 + (sample_i - 1) * dt
        ) %>%
        ungroup()
      
      # Target onset is fixed at 3.75s (start of Stimulus phase)
      # No need to compute from labels - use fixed timing
      
      # Compute trial-level metrics
      trial_metrics <- df %>%
        group_by(subject, task, session_used, run_used, trial_index) %>%
        summarise(
          trial_in_run_raw = first(trial_in_run_raw[!is.na(trial_in_run_raw)]),
          has_behavioral_data = any(has_behavioral_data == 1L, na.rm = TRUE),
          window_oob_any = max(window_oob, na.rm = TRUE),
          all_nan_any = max(all_nan, na.rm = TRUE),
          any_timebase_bug = 0L,  # Placeholder
          
          # Overall validity
          pct_non_nan_overall = 100 * mean(!is.na(pupil) & is.finite(pupil), na.rm = TRUE),
          
          # Baseline window (use ITI_Baseline label or time-based)
          pct_non_nan_baseline = {
            if (any(str_detect(trial_label, regex("ITI_Baseline|baseline", ignore_case = TRUE)), na.rm = TRUE)) {
              # Label-based: ITI_Baseline phase
              in_baseline <- str_detect(trial_label, regex("ITI_Baseline|baseline", ignore_case = TRUE))
              pupil_baseline <- pupil[in_baseline]
              100 * mean(!is.na(pupil_baseline) & is.finite(pupil_baseline), na.rm = TRUE)
            } else {
              # Time-based: [-3.0, 0.0] relative to squeeze onset
              window_validity_pct(pupil, t_rel, BASELINE_WIN[1], BASELINE_WIN[2])
            }
          },
          
          # Prestim (Pre_Stimulus_Fixation phase: 3.25-3.75)
          pct_non_nan_prestim = {
            if (any(str_detect(trial_label, regex("Pre_Stimulus_Fixation|pre.*stim", ignore_case = TRUE)), na.rm = TRUE)) {
              in_prestim <- str_detect(trial_label, regex("Pre_Stimulus_Fixation|pre.*stim", ignore_case = TRUE))
              pupil_prestim <- pupil[in_prestim]
              100 * mean(!is.na(pupil_prestim) & is.finite(pupil_prestim), na.rm = TRUE)
            } else {
              # Time-based: [3.25, 3.75]
              window_validity_pct(pupil, t_rel, 3.25, 3.75)
            }
          },
          
          # Stim (Stimulus phase: 3.75-4.45)
          pct_non_nan_stim = {
            if (any(str_detect(trial_label, regex("Stimulus", ignore_case = TRUE)), na.rm = TRUE)) {
              in_stim <- str_detect(trial_label, regex("Stimulus", ignore_case = TRUE))
              pupil_stim <- pupil[in_stim]
              100 * mean(!is.na(pupil_stim) & is.finite(pupil_stim), na.rm = TRUE)
            } else {
              # Time-based: [3.75, 4.45]
              window_validity_pct(pupil, t_rel, STIM_WIN[1], STIM_WIN[2])
            }
          },
          
          # Response (Response_Different phase: 4.7-7.7)
          pct_non_nan_response = {
            if (any(str_detect(trial_label, regex("Response_Different|response", ignore_case = TRUE)), na.rm = TRUE)) {
              in_response <- str_detect(trial_label, regex("Response_Different|response", ignore_case = TRUE))
              pupil_response <- pupil[in_response]
              100 * mean(!is.na(pupil_response) & is.finite(pupil_response), na.rm = TRUE)
            } else {
              # Time-based: [4.7, 7.7]
              window_validity_pct(pupil, t_rel, RESPONSE_WIN[1], RESPONSE_WIN[2])
            }
          },
          
          # Cognitive window (post-target: [4.05, 5.05] = target_onset + [0.3, 1.3])
          pct_non_nan_cogwin = {
            # Use fixed timing: target onset is at 3.75s (start of Stimulus phase)
            window_validity_pct(pupil, t_rel, COG_WIN[1], COG_WIN[2])
          },
          
          target_onset_found = {
            # Check if Stimulus phase exists in labels
            any(str_detect(trial_label, regex("Stimulus", ignore_case = TRUE)), na.rm = TRUE) ||
            any(t_rel >= STIM_WIN[1] & t_rel <= STIM_WIN[2], na.rm = TRUE)
          },
          
          .groups = "drop"
        )
      
      trial_data_list[[i]] <- trial_metrics
      rm(df, trial_metrics)
      
      # Only GC every 10 files to save time
      if (i %% 10 == 0) {
        gc(verbose = FALSE)
      }
      
    }, error = function(e) {
      cat("    Error processing ", fn, ": ", e$message, "\n", sep = "")
    })
  }
  
  # Final GC
  gc(verbose = FALSE)
  
  trial_data <- bind_rows(trial_data_list)
  rm(trial_data_list)
  gc(verbose = FALSE)
  
  # Deduplicate
  trial_data <- trial_data %>%
    group_by(subject, task, session_used, run_used, trial_index) %>%
    slice(1) %>%
    ungroup()
}

cat("  ✓ Loaded ", nrow(trial_data), " trials\n", sep = "")

# ----------------------------------------------------------------------------
# STEP 4: Assertions
# ----------------------------------------------------------------------------

cat("\nSTEP 4: Running assertions...\n")

# Check session_used
session_1_count <- sum(trial_data$session_used == 1L, na.rm = TRUE)
if (session_1_count > 0) {
  stop("CRITICAL ERROR: Found ", session_1_count, " trials with session_used == 1. Contamination detected!")
}
cat("  ✓ No session 1 contamination\n")

# Check trials per run
run_counts <- trial_data %>%
  group_by(subject, task, session_used, run_used) %>%
  summarise(n_trials = n_distinct(trial_index), .groups = "drop")

median_trials <- median(run_counts$n_trials, na.rm = TRUE)
outlier_runs <- run_counts %>% filter(n_trials < 25 | n_trials > 35)

if (median_trials < 25 || median_trials > 35) {
  stop("CRITICAL ERROR: Median trials per run is ", median_trials, 
       " (expected ~30). Check trial counting.")
}
cat("  ✓ Median trials per run: ", median_trials, "\n", sep = "")

if (nrow(outlier_runs) > 0) {
  cat("  ⚠ Found ", nrow(outlier_runs), " runs with unusual trial counts:\n", sep = "")
  print(head(outlier_runs, 10))
}

# Check baseline validity
baseline_zero_pct <- 100 * mean(trial_data$pct_non_nan_baseline == 0 | is.na(trial_data$pct_non_nan_baseline), na.rm = TRUE)
if (baseline_zero_pct > 80) {
  stop("CRITICAL ERROR: ", sprintf("%.1f", baseline_zero_pct), 
       "% of trials have pct_non_nan_baseline == 0. Window definition is broken!")
}
cat("  ✓ Baseline validity > 0 for ", sprintf("%.1f", 100 - baseline_zero_pct), "% of trials\n", sep = "")

# Check cognitive window
cogwin_na_pct <- 100 * mean(is.na(trial_data$pct_non_nan_cogwin), na.rm = TRUE)
target_onset_found_pct <- 100 * mean(trial_data$target_onset_found, na.rm = TRUE)

if (cogwin_na_pct > 10) {
  if (target_onset_found_pct < 50) {
    stop("CRITICAL ERROR: Only ", sprintf("%.1f", target_onset_found_pct), 
         "% of trials have target_onset_found=TRUE. Cannot define cognitive window reliably. ",
         "Check trial_label values for target/stim/gabor markers.")
  } else {
    cat("  ⚠ ", sprintf("%.1f", cogwin_na_pct), 
        "% of trials have NA for pct_non_nan_cogwin (but target_onset found for ",
        sprintf("%.1f", target_onset_found_pct), "%)\n", sep = "")
  }
} else {
  cat("  ✓ Cognitive window defined for ", sprintf("%.1f", 100 - cogwin_na_pct), "% of trials\n", sep = "")
}

# ----------------------------------------------------------------------------
# STEP 5: Save trial-level dataset
# ----------------------------------------------------------------------------

cat("\nSTEP 5: Saving trial-level dataset...\n")

# Select and order columns
trial_data_final <- trial_data %>%
  select(
    subject, task, session_used, run_used, trial_in_run_raw, trial_index,
    has_behavioral_data,
    pct_non_nan_overall,
    pct_non_nan_baseline,
    pct_non_nan_prestim,
    pct_non_nan_stim,
    pct_non_nan_response,
    pct_non_nan_cogwin,
    any_timebase_bug,
    window_oob_any,
    all_nan_any,
    target_onset_found
  )

output_file <- file.path(OUTPUT_DIR, "triallevel_qc.csv")
write_csv(trial_data_final, output_file)
cat("  ✓ Saved to: ", output_file, "\n", sep = "")

# Summary statistics
cat("\n=== SUMMARY ===\n")
cat("Total trials: ", nrow(trial_data_final), "\n", sep = "")
cat("Trials with baseline > 0: ", sum(trial_data_final$pct_non_nan_baseline > 0, na.rm = TRUE), 
    " (", sprintf("%.1f", 100 * mean(trial_data_final$pct_non_nan_baseline > 0, na.rm = TRUE)), "%)\n", sep = "")
cat("Trials with cogwin defined: ", sum(!is.na(trial_data_final$pct_non_nan_cogwin)), 
    " (", sprintf("%.1f", 100 * mean(!is.na(trial_data_final$pct_non_nan_cogwin))), "%)\n", sep = "")
cat("Trials with target_onset_found: ", sum(trial_data_final$target_onset_found), 
    " (", sprintf("%.1f", 100 * mean(trial_data_final$target_onset_found)), "%)\n", sep = "")

cat("\n=== BUILD COMPLETE ===\n")

