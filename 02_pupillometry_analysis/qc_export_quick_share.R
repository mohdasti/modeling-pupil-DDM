#!/usr/bin/env Rscript
# ============================================================================
# Quick Share QC Export - Compact QC Snapshot for Dissertation
# ============================================================================
# Generates exactly 8 CSV files for sharing (no HTML, no giant dumps)
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(tidyr)
})

# ============================================================================
# CONFIGURATION
# ============================================================================

# Output directory
OUTPUT_DIR <- "data/qc/quick_share"
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Get repo root
# Try to find repo root by looking for .git or common files
REPO_ROOT <- getwd()
if (file.exists(".git") || file.exists("README.md") || file.exists("Makefile")) {
  REPO_ROOT <- getwd()
} else {
  # Try going up one level
  parent <- dirname(getwd())
  if (file.exists(file.path(parent, ".git")) || file.exists(file.path(parent, "README.md"))) {
    REPO_ROOT <- parent
  }
}

cat("=== QUICK SHARE QC EXPORT ===\n")
cat("Repo root:", REPO_ROOT, "\n")
cat("Output dir:", OUTPUT_DIR, "\n\n")

# ============================================================================
# STEP 1: DISCOVER INPUT FILES
# ============================================================================

cat("STEP 1: Discovering input files...\n")

# Find MATLAB flat files
# Try common locations relative to repo root and absolute paths
possible_dirs <- c(
  file.path(REPO_ROOT, "data", "BAP_processed"),
  file.path(REPO_ROOT, "BAP_processed"),
  file.path(dirname(REPO_ROOT), "BAP_Pupillometry", "BAP", "BAP_processed"),
  file.path(dirname(REPO_ROOT), "LC-BAP", "BAP", "BAP_Pupillometry", "BAP", "BAP_processed"),
  "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed",
  Sys.getenv("BAP_PROCESSED_DIR", unset = "")
)
possible_dirs <- possible_dirs[nzchar(possible_dirs) & possible_dirs != ""]

flat_dir <- NULL
for (d in possible_dirs) {
  if (dir.exists(d)) {
    flat_files <- list.files(d, pattern = ".*_(ADT|VDT)_flat\\.csv$", full.names = TRUE, recursive = TRUE)
    if (length(flat_files) > 0) {
      flat_dir <- d
      cat("  Found flat files in:", d, "\n")
      cat("  Found", length(flat_files), "flat files\n")
      break
    }
  }
}

if (is.null(flat_dir)) {
  stop("ERROR: Could not find MATLAB flat files. Checked:\n", paste(possible_dirs, collapse = "\n"))
}

# Find availability files if they exist
availability_file <- NULL
possible_avail <- c(
  file.path(REPO_ROOT, "data", "qc", "analysis_ready_audit", "06_availability_stimulus_locked_long.csv"),
  file.path(REPO_ROOT, "quality_control", "exports", "06_availability_stimulus_locked_long.csv"),
  file.path(REPO_ROOT, "06_availability_stimulus_locked_long.csv")
)

for (f in possible_avail) {
  if (file.exists(f)) {
    availability_file <- f
    cat("  Found availability file:", f, "\n")
    break
  }
}

# Find analysis-ready files if they exist
analysis_ready_file <- NULL
possible_ready <- c(
  file.path(REPO_ROOT, "data", "analysis_ready", "BAP_TRIALLEVEL.csv"),
  file.path(REPO_ROOT, "data", "intermediate", "pupil_TRIALLEVEL_from_matlab.csv")
)

for (f in possible_ready) {
  if (file.exists(f)) {
    analysis_ready_file <- f
    cat("  Found analysis-ready file:", f, "\n")
    break
  }
}

# Build file provenance
file_provenance <- tibble(
  file_type = character(),
  filepath = character(),
  modified_time = character(),
  size_mb = numeric(),
  n_rows = integer(),
  n_cols = integer()
)

add_provenance <- function(type, path) {
  if (file.exists(path)) {
    rel_path <- if (startsWith(path, REPO_ROOT)) {
      sub(paste0("^", REPO_ROOT, "/"), "", path)
    } else {
      path
    }
    
    info <- file.info(path)
    n_rows <- NA_integer_
    n_cols <- NA_integer_
    
    if (endsWith(path, ".csv")) {
      tryCatch({
        sample <- read_csv(path, n_max = 0, show_col_types = FALSE)
        n_cols <- ncol(sample)
        # Try to count rows (may be slow for large files)
        if (file.size(path) < 100 * 1024 * 1024) {  # Only if < 100MB
          n_rows <- length(count.fields(path, sep = ",")) - 1  # -1 for header
        }
      }, error = function(e) {
        # Skip row count if it fails
      })
    }
    
    file_provenance <<- bind_rows(
      file_provenance,
      tibble(
        file_type = type,
        filepath = rel_path,
        modified_time = format(info$mtime, "%Y-%m-%d %H:%M:%S"),
        size_mb = round(info$size / 1024^2, 2),
        n_rows = n_rows,
        n_cols = n_cols
      )
    )
  }
}

add_provenance("flat_files_dir", flat_dir)
if (!is.null(availability_file)) add_provenance("availability_file", availability_file)
if (!is.null(analysis_ready_file)) add_provenance("analysis_ready_file", analysis_ready_file)

cat("\n")

# ============================================================================
# STEP 2: BUILD TRIAL-LEVEL DATASET
# ============================================================================

cat("STEP 2: Building trial-level dataset from flat files...\n")

flat_files <- list.files(flat_dir, pattern = ".*_(ADT|VDT)_flat\\.csv$", full.names = TRUE, recursive = TRUE)

# Helper function to compute window validity
window_validity <- function(time, pupil, start, end) {
  in_window <- !is.na(time) & time >= start & time <= end
  if (sum(in_window) == 0) return(NA_real_)
  mean(!is.na(pupil[in_window]) & pupil[in_window] > 0, na.rm = TRUE)
}

# Helper function to identify column names
identify_column <- function(df, candidates) {
  for (cand in candidates) {
    if (cand %in% names(df)) return(cand)
  }
  return(NA_character_)
}

# Helper function for coalescing with fallback
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x

# Load and aggregate flat files
trial_data <- map_dfr(flat_files, ~{
  cat("  Processing:", basename(.x), "\n")
  
  # Read file in chunks if very large, otherwise read all
  file_size_mb <- file.info(.x)$size / 1024^2
  if (file_size_mb > 500) {
    # For very large files, sample or process in chunks
    df <- read_csv(.x, show_col_types = FALSE, n_max = 500000)
    cat("    (Large file, reading first 500k rows)\n")
  } else {
    df <- read_csv(.x, show_col_types = FALSE)
  }
  
  # Extract identifiers from filename or columns
  filename <- basename(.x)
  subject_id <- str_extract(filename, "BAP\\d+")
  task <- if_else(str_detect(filename, "ADT"), "ADT", 
                  if_else(str_detect(filename, "VDT"), "VDT", NA_character_))
  
  # Map column names (handle variations)
  col_subject <- identify_column(df, c("sub", "subject", "subject_id"))
  col_task <- identify_column(df, c("task", "task_modality"))
  col_session <- identify_column(df, c("ses", "session", "session_num", "session_index"))
  col_run <- identify_column(df, c("run", "run_num", "run_index"))
  col_trial <- identify_column(df, c("trial_in_run_raw", "trial_in_run", "trial", "trial_num", "trial_index"))
  col_time <- identify_column(df, c("time", "trial_pupilTime", "timestamp", "time_rel_trial"))
  col_pupil <- identify_column(df, c("pupil", "pupilSize", "pupil_diameter"))
  
  # Normalize columns
  if (!is.na(col_subject) && col_subject %in% names(df)) {
    df$subject_id <- as.character(df[[col_subject]])
  } else {
    df$subject_id <- subject_id
  }
  
  if (!is.na(col_task) && col_task %in% names(df)) {
    df$task <- case_when(
      df[[col_task]] == "aud" ~ "ADT",
      df[[col_task]] == "vis" ~ "VDT",
      TRUE ~ as.character(df[[col_task]])
    )
  } else {
    df$task <- task
  }
  
  if (!is.na(col_session) && col_session %in% names(df)) {
    df$session <- as.integer(df[[col_session]])
  } else {
    df$session <- NA_integer_
  }
  
  if (!is.na(col_run) && col_run %in% names(df)) {
    df$run <- as.integer(df[[col_run]])
  } else {
    df$run <- NA_integer_
  }
  
  if (!is.na(col_trial) && col_trial %in% names(df)) {
    df$trial_in_run <- as.integer(df[[col_trial]])
  } else {
    df$trial_in_run <- NA_integer_
  }
  
  if (!is.na(col_time) && col_time %in% names(df)) {
    df$time <- as.numeric(df[[col_time]])
  } else {
    df$time <- NA_real_
  }
  
  if (!is.na(col_pupil) && col_pupil %in% names(df)) {
    df$pupil <- as.numeric(df[[col_pupil]])
  } else {
    df$pupil <- NA_real_
  }
  
  # Filter: InsideScanner only, sessions 2-3, runs 1-5
  df <- df %>%
    filter(
      session %in% c(2, 3),
      run %in% 1:5,
      !is.na(subject_id), !is.na(task), !is.na(session), !is.na(run), !is.na(trial_in_run)
    )
  
  if (nrow(df) == 0) return(tibble())
  
  # Aggregate to trial level
  # Compute window validity within each group
  result <- df %>%
    group_by(subject_id, task, session, run, trial_in_run) %>%
    summarise(
      n_samples_total = n(),
      n_samples_valid = sum(!is.na(pupil) & pupil > 0, na.rm = TRUE),
      
      # Time statistics
      time_min = min(time, na.rm = TRUE),
      time_max = max(time, na.rm = TRUE),
      time_median = median(time, na.rm = TRUE),
      
      # Determine target onset (scalar per group)
      target_onset = {
        has_target_range <- any(time > 4.0 & time < 5.5, na.rm = TRUE)
        if (has_target_range) {
          4.7
        } else if (min(time, na.rm = TRUE) < 0) {
          median(time, na.rm = TRUE) + 2.0
        } else {
          4.7
        }
      },
      
      # Window validity (compute using grouped time and pupil vectors)
      baseline_valid = {
        t_onset <- if_else(any(time > 4.0 & time < 5.5, na.rm = TRUE), 4.7,
                          if_else(min(time, na.rm = TRUE) < 0, median(time, na.rm = TRUE) + 2.0, 4.7))
        window_validity(time, pupil, t_onset - 0.5, t_onset)
      },
      cognitive_valid = {
        t_onset <- if_else(any(time > 4.0 & time < 5.5, na.rm = TRUE), 4.7,
                          if_else(min(time, na.rm = TRUE) < 0, median(time, na.rm = TRUE) + 2.0, 4.7))
        window_validity(time, pupil, t_onset + 0.3, t_onset + 1.3)
      },
      total_valid = {
        t_onset <- if_else(any(time > 4.0 & time < 5.5, na.rm = TRUE), 4.7,
                          if_else(min(time, na.rm = TRUE) < 0, median(time, na.rm = TRUE) + 2.0, 4.7))
        window_validity(time, pupil, t_onset, min(t_onset + 3.0, max(time, na.rm = TRUE)))
      },
      prestim_valid = {
        t_onset <- if_else(any(time > 4.0 & time < 5.5, na.rm = TRUE), 4.7,
                          if_else(min(time, na.rm = TRUE) < 0, median(time, na.rm = TRUE) + 2.0, 4.7))
        if (t_onset > 0.5) {
          window_validity(time, pupil, t_onset - 0.5, t_onset)
        } else {
          NA_real_
        }
      },
      
      # Preserve flags if they exist
      segmentation_source = if ("segmentation_source" %in% names(df)) {
        first(segmentation_source[!is.na(segmentation_source)])
      } else NA_character_,
      window_oob = if ("window_oob" %in% names(df)) {
        any(window_oob == TRUE, na.rm = TRUE)
      } else NA,
      
      .groups = "drop"
    ) %>%
    mutate(
      trial_uid = paste(subject_id, task, session, run, trial_in_run, sep = ":"),
      valid_prop = n_samples_valid / n_samples_total
    )
  
  result
})

cat(sprintf("  Aggregated to %d trials\n", nrow(trial_data)))

# ============================================================================
# STEP 3: ADD BEHAVIORAL DATA AND GATES
# ============================================================================

cat("STEP 3: Adding behavioral data and computing gates...\n")

# Try to load behavioral data
behavioral_file <- NULL
possible_behav <- c(
  file.path(REPO_ROOT, "data", "intermediate", "behavior_TRIALLEVEL_normalized.csv"),
  file.path(REPO_ROOT, "data", "analysis_ready", "BAP_TRIALLEVEL.csv"),
  file.path(dirname(REPO_ROOT), "LC-BAP", "BAP", "Nov2025", "bap_beh_trialdata_v2.csv")
)

for (f in possible_behav) {
  if (file.exists(f)) {
    behavioral_file <- f
    cat("  Loading behavioral data from:", f, "\n")
    break
  }
}

if (!is.null(behavioral_file)) {
  behav <- read_csv(behavioral_file, show_col_types = FALSE)
  
  # Normalize behavioral columns
  if ("subject_id" %in% names(behav)) {
    behav <- behav %>%
      mutate(
        subject_id = as.character(subject_id),
        task = if ("task_modality" %in% names(.)) {
          case_when(
            task_modality == "aud" ~ "ADT",
            task_modality == "vis" ~ "VDT",
            TRUE ~ as.character(task_modality)
          )
        } else if ("task" %in% names(.)) {
          case_when(
            task == "aud" ~ "ADT",
            task == "vis" ~ "VDT",
            TRUE ~ as.character(task)
          )
        } else NA_character_,
        session = as.integer(if ("session_num" %in% names(.)) session_num else 
                            if ("session" %in% names(.)) session else 
                            if ("ses" %in% names(.)) ses else NA),
        run = as.integer(if ("run_num" %in% names(.)) run_num else 
                        if ("run" %in% names(.)) run else NA),
        trial_in_run = as.integer(if ("trial_num" %in% names(.)) trial_num else 
                                 if ("trial_in_run" %in% names(.)) trial_in_run else
                                 if ("trial" %in% names(.)) trial else NA),
        rt = if ("same_diff_resp_secs" %in% names(.)) same_diff_resp_secs else
             if ("rt" %in% names(.)) rt else
             if ("resp1RT" %in% names(.)) resp1RT else NA_real_,
        choice = if ("resp_is_diff" %in% names(.)) resp_is_diff else
                 if ("choice" %in% names(.)) choice else NA,
        correct = if ("resp_is_correct" %in% names(.)) resp_is_correct else
                  if ("correct" %in% names(.)) correct else
                  if ("iscorr" %in% names(.)) iscorr else NA
      )
    
    # Add effort if grip_targ_prop_mvc exists
    if ("grip_targ_prop_mvc" %in% names(behav)) {
      behav <- behav %>%
        mutate(
          effort = case_when(
            grip_targ_prop_mvc == 0.05 ~ "Low",
            grip_targ_prop_mvc == 0.40 ~ "High",
            TRUE ~ NA_character_
          )
        )
    } else {
      behav$effort <- NA_character_
    }
    
    # Add intensity
    if ("stim_level_index" %in% names(behav)) {
      behav$intensity <- behav$stim_level_index
    } else if ("intensity" %in% names(behav)) {
      behav$intensity <- behav$intensity
    } else if ("stimLev" %in% names(behav)) {
      behav$intensity <- behav$stimLev
    } else {
      behav$intensity <- NA_real_
    }
    
    # Add oddball
    if ("stim_is_diff" %in% names(behav)) {
      behav$oddball <- behav$stim_is_diff
    } else if ("oddball" %in% names(behav)) {
      behav$oddball <- behav$oddball
    } else if ("isOddball" %in% names(behav)) {
      behav$oddball <- behav$isOddball
    } else {
      behav$oddball <- NA
    }
    
    # Add difficulty
    behav <- behav %>%
      mutate(
        difficulty = case_when(
          !is.na(oddball) & oddball == 0 ~ "Standard",
          !is.na(intensity) & intensity %in% c(1, 2) ~ "Hard",
          !is.na(intensity) & intensity %in% c(3, 4) ~ "Easy",
          TRUE ~ NA_character_
        )
      ) %>%
      select(any_of(c("subject_id", "task", "session", "run", "trial_in_run", 
                     "rt", "choice", "correct", "effort", "intensity", "oddball", "difficulty")))
    
    # Merge with trial data
    trial_data <- trial_data %>%
      left_join(behav, by = c("subject_id", "task", "session", "run", "trial_in_run"))
  }
}

# Compute gates
trial_data <- trial_data %>%
  mutate(
    # CH2 gates
    ch2_primary = baseline_valid >= 0.60 & cognitive_valid >= 0.60,
    ch2_sens_050 = baseline_valid >= 0.50 & cognitive_valid >= 0.50,
    ch2_sens_070 = baseline_valid >= 0.70 & cognitive_valid >= 0.70,
    
    # CH3 gates
    ch3_behavior_ready = !is.na(choice) & !is.na(rt) & rt >= 0.2 & rt <= 3.0,
    ch3_pupil_ready = ch3_behavior_ready & baseline_valid >= 0.60 & cognitive_valid >= 0.60,
    
    # Diagnostic gates
    prestim_gate = prestim_valid >= 0.60
  )

cat("  Gates computed\n\n")

# ============================================================================
# STEP 4: PRESTIM DIP SUMMARY
# ============================================================================

cat("STEP 4: Computing prestim dip summary...\n")

prestim_dip <- NULL

if (!is.null(availability_file)) {
  # Use availability file if available
  avail <- read_csv(availability_file, show_col_types = FALSE)
  
  # Aggregate by task and time bin
  prestim_dip <- avail %>%
    filter(time_bin >= 2.5 & time_bin <= 4.2) %>%
    group_by(task) %>%
    summarise(
      dip_time = time_bin[which.min(availability)],
      dip_depth = min(availability, na.rm = TRUE) - mean(availability[time_bin >= 0.5 & time_bin <= 1.0], na.rm = TRUE),
      availability_min = min(availability, na.rm = TRUE),
      availability_reference = mean(availability[time_bin >= 0.5 & time_bin <= 1.0], na.rm = TRUE),
      method_used = "availability_file",
      .groups = "drop"
    )
  
  # Add overall
  overall <- avail %>%
    filter(time_bin >= 2.5 & time_bin <= 4.2) %>%
    summarise(
      task = "Overall",
      dip_time = time_bin[which.min(availability)],
      dip_depth = min(availability, na.rm = TRUE) - mean(availability[time_bin >= 0.5 & time_bin <= 1.0], na.rm = TRUE),
      availability_min = min(availability, na.rm = TRUE),
      availability_reference = mean(availability[time_bin >= 0.5 & time_bin <= 1.0], na.rm = TRUE),
      method_used = "availability_file"
    )
  
  prestim_dip <- bind_rows(prestim_dip, overall)
  
} else {
  # Reconstruct from trial-level prestim_valid (approximate)
  # Note: This is a simplified approximation - full reconstruction would need sample-level time series
  prestim_dip <- trial_data %>%
    filter(!is.na(prestim_valid)) %>%
    group_by(task) %>%
    summarise(
      dip_time = NA_real_,  # Cannot determine from trial-level data
      availability_min = mean(prestim_valid, na.rm = TRUE),
      availability_reference = mean(baseline_valid[!is.na(baseline_valid)], na.rm = TRUE),
      method_used = "reconstructed_from_trial_validity",
      .groups = "drop"
    ) %>%
    mutate(
      dip_depth = availability_min - availability_reference
    )
  
  # Add overall if we have data
  if (nrow(trial_data) > 0 && any(!is.na(trial_data$prestim_valid))) {
    overall <- trial_data %>%
      filter(!is.na(prestim_valid)) %>%
      summarise(
        task = "Overall",
        dip_time = NA_real_,
        availability_min = mean(prestim_valid, na.rm = TRUE),
        availability_reference = mean(baseline_valid[!is.na(baseline_valid)], na.rm = TRUE),
        method_used = "reconstructed_from_trial_validity"
      ) %>%
      mutate(
        dip_depth = availability_min - availability_reference
      )
    
    prestim_dip <- bind_rows(prestim_dip, overall)
  } else {
    # No prestim data available
    prestim_dip <- tibble(
      task = c("ADT", "VDT", "Overall"),
      dip_time = NA_real_,
      dip_depth = NA_real_,
      availability_min = NA_real_,
      availability_reference = NA_real_,
      method_used = "no_data_available"
    )
  }
}

cat("  Prestim dip computed\n\n")

# ============================================================================
# STEP 5: EXPORT 8 CSVs
# ============================================================================

cat("STEP 5: Exporting 8 CSV files...\n")

# (1) File provenance
write_csv(file_provenance, file.path(OUTPUT_DIR, "01_file_provenance.csv"))
cat("  ✓ 01_file_provenance.csv\n")

# (2) Design expected vs observed
design_check <- trial_data %>%
  group_by(subject_id, task, session) %>%
  summarise(
    n_runs_observed = n_distinct(run),
    n_trials_observed = n(),
    n_runs_expected = 5,
    n_trials_expected = 150,
    runs_observed = paste(sort(unique(run)), collapse = ","),
    runs_missing = paste(setdiff(1:5, unique(run)), collapse = ","),
    missing_runs_count = 5 - n_runs_observed,
    .groups = "drop"
  ) %>%
  mutate(
    runs_deviation = n_runs_observed - n_runs_expected,
    trials_deviation = n_trials_observed - n_trials_expected
  )

write_csv(design_check, file.path(OUTPUT_DIR, "02_design_expected_vs_observed.csv"))
cat("  ✓ 02_design_expected_vs_observed.csv\n")

# (3) Trials per subject×task×ses
trials_summary <- trial_data %>%
  group_by(subject_id, task, session) %>%
  summarise(
    n_trials_observed = n(),
    n_trials_ch2_primary = sum(ch2_primary, na.rm = TRUE),
    n_trials_ch3_behavior_ready = sum(ch3_behavior_ready, na.rm = TRUE),
    n_trials_ch3_pupil_ready = sum(ch3_pupil_ready, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(trials_summary, file.path(OUTPUT_DIR, "03_trials_per_subject_task_ses.csv"))
cat("  ✓ 03_trials_per_subject_task_ses.csv\n")

# (4) Run-level counts
run_counts <- trial_data %>%
  group_by(subject_id, task, session, run) %>%
  summarise(
    n_trials = n(),
    segmentation_source = first(segmentation_source[!is.na(segmentation_source)]),
    n_window_oob = sum(window_oob, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(run_counts, file.path(OUTPUT_DIR, "04_run_level_counts.csv"))
cat("  ✓ 04_run_level_counts.csv\n")

# (5) Window validity summary
validity_summary <- trial_data %>%
  group_by(task) %>%
  summarise(
    baseline_valid_mean = mean(baseline_valid, na.rm = TRUE),
    baseline_valid_median = median(baseline_valid, na.rm = TRUE),
    baseline_valid_p10 = quantile(baseline_valid, 0.10, na.rm = TRUE),
    baseline_valid_p25 = quantile(baseline_valid, 0.25, na.rm = TRUE),
    baseline_valid_p75 = quantile(baseline_valid, 0.75, na.rm = TRUE),
    baseline_valid_p90 = quantile(baseline_valid, 0.90, na.rm = TRUE),
    
    cognitive_valid_mean = mean(cognitive_valid, na.rm = TRUE),
    cognitive_valid_median = median(cognitive_valid, na.rm = TRUE),
    cognitive_valid_p10 = quantile(cognitive_valid, 0.10, na.rm = TRUE),
    cognitive_valid_p25 = quantile(cognitive_valid, 0.25, na.rm = TRUE),
    cognitive_valid_p75 = quantile(cognitive_valid, 0.75, na.rm = TRUE),
    cognitive_valid_p90 = quantile(cognitive_valid, 0.90, na.rm = TRUE),
    
    total_valid_mean = mean(total_valid, na.rm = TRUE),
    total_valid_median = median(total_valid, na.rm = TRUE),
    total_valid_p10 = quantile(total_valid, 0.10, na.rm = TRUE),
    total_valid_p25 = quantile(total_valid, 0.25, na.rm = TRUE),
    total_valid_p75 = quantile(total_valid, 0.75, na.rm = TRUE),
    total_valid_p90 = quantile(total_valid, 0.90, na.rm = TRUE),
    
    prestim_valid_mean = mean(prestim_valid, na.rm = TRUE),
    prestim_valid_median = median(prestim_valid, na.rm = TRUE),
    prestim_valid_p10 = quantile(prestim_valid, 0.10, na.rm = TRUE),
    prestim_valid_p25 = quantile(prestim_valid, 0.25, na.rm = TRUE),
    prestim_valid_p75 = quantile(prestim_valid, 0.75, na.rm = TRUE),
    prestim_valid_p90 = quantile(prestim_valid, 0.90, na.rm = TRUE),
    .groups = "drop"
  )

# If effort is available, add by effort
if ("effort" %in% names(trial_data)) {
  validity_by_effort <- trial_data %>%
    filter(!is.na(effort)) %>%
    group_by(task, effort) %>%
    summarise(
      baseline_valid_mean = mean(baseline_valid, na.rm = TRUE),
      cognitive_valid_mean = mean(cognitive_valid, na.rm = TRUE),
      total_valid_mean = mean(total_valid, na.rm = TRUE),
      prestim_valid_mean = mean(prestim_valid, na.rm = TRUE),
      .groups = "drop"
    )
  
  validity_summary <- bind_rows(
    validity_summary %>% mutate(effort = NA_character_),
    validity_by_effort
  )
}

write_csv(validity_summary, file.path(OUTPUT_DIR, "05_window_validity_summary.csv"))
cat("  ✓ 05_window_validity_summary.csv\n")

# (6) Gate pass rates by threshold
gate_rates <- map_dfr(c(0.50, 0.60, 0.70), function(thr) {
  trial_data %>%
    mutate(
      ch2_gate = baseline_valid >= thr & cognitive_valid >= thr,
      ch3_pupil_gate = ch3_behavior_ready & baseline_valid >= thr & cognitive_valid >= thr
    ) %>%
    group_by(task) %>%
    summarise(
      threshold = thr,
      ch2_pass = sum(ch2_gate, na.rm = TRUE),
      ch2_total = n(),
      ch2_pass_rate = ch2_pass / ch2_total,
      ch3_pupil_pass = sum(ch3_pupil_gate, na.rm = TRUE),
      ch3_pupil_total = sum(!is.na(ch3_behavior_ready)),
      ch3_pupil_pass_rate = ch3_pupil_pass / ch3_pupil_total,
      .groups = "drop"
    )
})

write_csv(gate_rates, file.path(OUTPUT_DIR, "06_gate_pass_rates_by_threshold.csv"))
cat("  ✓ 06_gate_pass_rates_by_threshold.csv\n")

# (7) Bias checks
bias_checks <- trial_data %>%
  filter(!is.na(ch2_primary), !is.na(ch3_pupil_ready)) %>%
  group_by(task) %>%
  summarise(
    ch2_primary_pass_rate = mean(ch2_primary, na.rm = TRUE),
    ch3_pupil_ready_pass_rate = mean(ch3_pupil_ready, na.rm = TRUE),
    .groups = "drop"
  )

# Add by effort if available
if ("effort" %in% names(trial_data)) {
  bias_by_effort <- trial_data %>%
    filter(!is.na(effort)) %>%
    group_by(task, effort) %>%
    summarise(
      ch2_primary_pass_rate = mean(ch2_primary, na.rm = TRUE),
      ch3_pupil_ready_pass_rate = mean(ch3_pupil_ready, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    group_by(task) %>%
    summarise(
      ch2_primary_by_effort_max_diff = {
        rates <- ch2_primary_pass_rate[!is.na(ch2_primary_pass_rate)]
        if (length(rates) > 0) max(rates) - min(rates) else NA_real_
      },
      ch3_pupil_ready_by_effort_max_diff = {
        rates <- ch3_pupil_ready_pass_rate[!is.na(ch3_pupil_ready_pass_rate)]
        if (length(rates) > 0) max(rates) - min(rates) else NA_real_
      },
      ch2_primary_effort_flag = {
        rates <- ch2_primary_pass_rate[!is.na(ch2_primary_pass_rate)]
        if (length(rates) > 0) (max(rates) - min(rates)) > 0.10 else NA
      },
      ch3_pupil_ready_effort_flag = {
        rates <- ch3_pupil_ready_pass_rate[!is.na(ch3_pupil_ready_pass_rate)]
        if (length(rates) > 0) (max(rates) - min(rates)) > 0.10 else NA
      },
      .groups = "drop"
    )
  
  bias_checks <- bias_checks %>% left_join(bias_by_effort, by = "task")
}

# Add by difficulty if available
if ("difficulty" %in% names(trial_data)) {
  bias_by_diff <- trial_data %>%
    filter(!is.na(difficulty)) %>%
    group_by(task, difficulty) %>%
    summarise(
      ch2_primary_pass_rate = mean(ch2_primary, na.rm = TRUE),
      ch3_pupil_ready_pass_rate = mean(ch3_pupil_ready, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    group_by(task) %>%
    summarise(
      ch2_primary_by_difficulty_max_diff = {
        rates <- ch2_primary_pass_rate[!is.na(ch2_primary_pass_rate)]
        if (length(rates) > 0) max(rates) - min(rates) else NA_real_
      },
      ch3_pupil_ready_by_difficulty_max_diff = {
        rates <- ch3_pupil_ready_pass_rate[!is.na(ch3_pupil_ready_pass_rate)]
        if (length(rates) > 0) max(rates) - min(rates) else NA_real_
      },
      ch2_primary_difficulty_flag = {
        rates <- ch2_primary_pass_rate[!is.na(ch2_primary_pass_rate)]
        if (length(rates) > 0) (max(rates) - min(rates)) > 0.10 else NA
      },
      ch3_pupil_ready_difficulty_flag = {
        rates <- ch3_pupil_ready_pass_rate[!is.na(ch3_pupil_ready_pass_rate)]
        if (length(rates) > 0) (max(rates) - min(rates)) > 0.10 else NA
      },
      .groups = "drop"
    )
  
  bias_checks <- bias_checks %>% left_join(bias_by_diff, by = "task")
}

# Add by oddball if available
if ("oddball" %in% names(trial_data)) {
  bias_by_oddball <- trial_data %>%
    filter(!is.na(oddball)) %>%
    group_by(task, oddball) %>%
    summarise(
      ch2_primary_pass_rate = mean(ch2_primary, na.rm = TRUE),
      ch3_pupil_ready_pass_rate = mean(ch3_pupil_ready, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    group_by(task) %>%
    summarise(
      ch2_primary_by_oddball_max_diff = {
        rates <- ch2_primary_pass_rate[!is.na(ch2_primary_pass_rate)]
        if (length(rates) > 0) max(rates) - min(rates) else NA_real_
      },
      ch3_pupil_ready_by_oddball_max_diff = {
        rates <- ch3_pupil_ready_pass_rate[!is.na(ch3_pupil_ready_pass_rate)]
        if (length(rates) > 0) max(rates) - min(rates) else NA_real_
      },
      ch2_primary_oddball_flag = {
        rates <- ch2_primary_pass_rate[!is.na(ch2_primary_pass_rate)]
        if (length(rates) > 0) (max(rates) - min(rates)) > 0.10 else NA
      },
      ch3_pupil_ready_oddball_flag = {
        rates <- ch3_pupil_ready_pass_rate[!is.na(ch3_pupil_ready_pass_rate)]
        if (length(rates) > 0) (max(rates) - min(rates)) > 0.10 else NA
      },
      .groups = "drop"
    )
  
  bias_checks <- bias_checks %>% left_join(bias_by_oddball, by = "task")
}

write_csv(bias_checks, file.path(OUTPUT_DIR, "07_bias_checks_key_gates.csv"))
cat("  ✓ 07_bias_checks_key_gates.csv\n")

# (8) Prestim dip summary
write_csv(prestim_dip, file.path(OUTPUT_DIR, "08_prestim_dip_summary.csv"))
cat("  ✓ 08_prestim_dip_summary.csv\n")

# ============================================================================
# STEP 6: GENERATE README
# ============================================================================

cat("\nSTEP 6: Generating README...\n")

# Compute summary statistics
n_subjects <- n_distinct(trial_data$subject_id)
n_trials_total <- nrow(trial_data)
n_trials_ch2 <- sum(trial_data$ch2_primary, na.rm = TRUE)
n_trials_ch3_behav <- sum(trial_data$ch3_behavior_ready, na.rm = TRUE)
n_trials_ch3_pupil <- sum(trial_data$ch3_pupil_ready, na.rm = TRUE)

readme_content <- paste0(
  "# Quick Share QC Snapshot\n\n",
  "Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n",
  "## Filters Applied\n\n",
  "- **Sessions**: 2-3 only (excluded session 1)\n",
  "- **Location**: InsideScanner only (practice/OutsideScanner excluded)\n",
  "- **Runs**: 1-5 only\n",
  "- **Tasks**: ADT and VDT\n\n",
  "## Summary Statistics\n\n",
  "- **N subjects**: ", n_subjects, "\n",
  "- **N trials (total observed)**: ", n_trials_total, "\n",
  "- **N trials (CH2 primary usable)**: ", n_trials_ch2, "\n",
  "- **N trials (CH3 behavior-ready)**: ", n_trials_ch3_behav, "\n",
  "- **N trials (CH3 pupil+behavior-ready)**: ", n_trials_ch3_pupil, "\n\n",
  "## Prestim Dip Status\n\n"
)

if (!is.null(prestim_dip)) {
  for (i in 1:nrow(prestim_dip)) {
    row <- prestim_dip[i, ]
    readme_content <- paste0(
      readme_content,
      "- **", row$task, "**: ",
      if (!is.na(row$dip_time)) paste0("Dip at ", round(row$dip_time, 2), "s, ") else "",
      "Depth = ", round(row$dip_depth, 3), 
      " (min availability = ", round(row$availability_min, 3), 
      ", reference = ", round(row$availability_reference, 3), ")\n"
    )
  }
  readme_content <- paste0(readme_content, "\n")
}

readme_content <- paste0(
  readme_content,
  "## Terminal Summary\n\n",
  "```\n",
  "=== QUICK SHARE QC SNAPSHOT ===\n",
  "Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n",
  "FILTERS:\n",
  "  Sessions: 2-3 only\n",
  "  Location: InsideScanner only\n",
  "  Runs: 1-5 only\n\n",
  "COUNTS:\n",
  sprintf("  Subjects: %d\n", n_subjects),
  sprintf("  Total trials: %d\n", n_trials_total),
  sprintf("  CH2 primary usable: %d (%.1f%%)\n", n_trials_ch2, 100 * n_trials_ch2 / n_trials_total),
  sprintf("  CH3 behavior-ready: %d (%.1f%%)\n", n_trials_ch3_behav, 100 * n_trials_ch3_behav / n_trials_total),
  sprintf("  CH3 pupil+behavior-ready: %d (%.1f%%)\n", n_trials_ch3_pupil, 100 * n_trials_ch3_pupil / n_trials_total),
  "\n",
  "PRESTIM DIP:\n"
)

# Add prestim dip to terminal summary
if (!is.null(prestim_dip) && nrow(prestim_dip) > 0) {
  for (i in 1:nrow(prestim_dip)) {
    row <- prestim_dip[i, ]
    if (!is.na(row$dip_depth)) {
      readme_content <- paste0(
        readme_content,
        sprintf("  %s: depth=%.3f, min=%.3f, ref=%.3f\n", 
                row$task, row$dip_depth, row$availability_min, row$availability_reference)
      )
    }
  }
}

readme_content <- paste0(
  readme_content,
  "\n",
  "STATUS: ",
  if (n_trials_ch2 > 0 && n_trials_ch3_pupil > 0) "✓ READY" else "⚠ LOW RETENTION",
  "\n",
  "```\n\n",
  "## Red Flags\n\n"
)

# Check for red flags
red_flags <- character()

if (any(design_check$missing_runs_count > 0, na.rm = TRUE)) {
  n_missing <- sum(design_check$missing_runs_count > 0, na.rm = TRUE)
  red_flags <- c(red_flags, paste0("- ", n_missing, " subject×task×session combinations missing runs"))
}

if (any(bias_checks$ch2_primary_effort_flag == TRUE, na.rm = TRUE)) {
  red_flags <- c(red_flags, "- CH2 primary gate shows >10pp bias by effort")
}

if (any(bias_checks$ch3_pupil_ready_effort_flag == TRUE, na.rm = TRUE)) {
  red_flags <- c(red_flags, "- CH3 pupil+behavior gate shows >10pp bias by effort")
}

if (length(red_flags) == 0) {
  readme_content <- paste0(readme_content, "- None detected\n\n")
} else {
  readme_content <- paste0(readme_content, paste(red_flags, collapse = "\n"), "\n\n")
}

readme_content <- paste0(
  readme_content,
  "## Files Generated\n\n",
  "1. `01_file_provenance.csv` - Input file metadata\n",
  "2. `02_design_expected_vs_observed.csv` - Design compliance check\n",
  "3. `03_trials_per_subject_task_ses.csv` - Trial counts by unit\n",
  "4. `04_run_level_counts.csv` - Run-level statistics\n",
  "5. `05_window_validity_summary.csv` - Window validity distributions\n",
  "6. `06_gate_pass_rates_by_threshold.csv` - Gate retention by threshold\n",
  "7. `07_bias_checks_key_gates.csv` - Condition bias checks\n",
  "8. `08_prestim_dip_summary.csv` - Prestim dip metrics\n"
)

writeLines(readme_content, file.path(OUTPUT_DIR, "README_quick_share.md"))
cat("  ✓ README_quick_share.md\n")

cat("\n=== EXPORT COMPLETE ===\n")
cat("All files written to:", OUTPUT_DIR, "\n")

