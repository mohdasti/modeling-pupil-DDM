#!/usr/bin/env Rscript
# ============================================================================
# Quick QC Export - Compact Pupillometry QC Snapshot
# ============================================================================
# Generates <= 8 CSV files + 1 README.md for data readiness assessment
# - Computes from latest MATLAB flat files (BAP_processed/*_flat.csv)
# - Merges with behavioral trialdata if available
# - Hard contamination guardrails: session_used in {2,3} only
# - Never loses run_used or session_used identity
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(tidyr)
})

cat("=== QUICK QC EXPORT ===\n\n")

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

# ----------------------------------------------------------------------------
# STEP 0: Discover files & decide canonical keys
# ----------------------------------------------------------------------------

cat("STEP 0: Discovering files and canonical keys...\n")

# Determine repo root
REPO_ROOT <- if (file.exists("02_pupillometry_analysis")) {
  normalizePath(getwd())
} else if (file.exists("../02_pupillometry_analysis")) {
  normalizePath("..")
} else {
  normalizePath(getwd())
}

OUTPUT_DIR <- file.path(REPO_ROOT, "02_pupillometry_analysis", "quick_share")
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("  Repo root: ", REPO_ROOT, "\n", sep = "")
cat("  Output dir: ", OUTPUT_DIR, "\n\n", sep = "")

# Find BAP_processed directory
possible_bap_dirs <- c(
  file.path(REPO_ROOT, "BAP_processed"),
  file.path(REPO_ROOT, "data", "BAP_processed"),
  "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed",
  Sys.getenv("BAP_PROCESSED_DIR", unset = "")
)
possible_bap_dirs <- unique(possible_bap_dirs[nzchar(possible_bap_dirs)])

BAP_DIR <- NULL
for (d in possible_bap_dirs) {
  if (dir.exists(d)) {
    flat_files_tmp <- list.files(d, pattern = "_flat\\.csv$", full.names = TRUE, recursive = TRUE)
    if (length(flat_files_tmp) > 0) {
      BAP_DIR <- d
      cat("  Found BAP_processed: ", d, "\n", sep = "")
      break
    }
  }
}

if (is.null(BAP_DIR)) {
  stop("ERROR: Could not locate BAP_processed directory with *_flat.csv files.\n",
       "Tried:\n", paste("  -", possible_bap_dirs, collapse = "\n"),
       "\n\nPlease set BAP_PROCESSED_DIR environment variable or place files in:\n",
       "  - ", file.path(REPO_ROOT, "BAP_processed"), "\n",
       "  - ", file.path(REPO_ROOT, "data", "BAP_processed"), "\n")
}

# Find flat files
flat_files <- list.files(BAP_DIR, pattern = "_flat\\.csv$", full.names = TRUE, recursive = TRUE)
cat("  Found ", length(flat_files), " flat files\n", sep = "")

if (length(flat_files) == 0) {
  stop("ERROR: No *_flat.csv files found in ", BAP_DIR)
}

# Check required columns in first file
sample_file <- read_csv(flat_files[1], n_max = 1, show_col_types = FALSE)
required_cols <- c("sub", "task", "session_used", "run_used", "trial_index", 
                   "trial_in_run_raw", "time", "pupil", "segmentation_source", 
                   "window_oob", "all_nan")
missing_cols <- setdiff(required_cols, names(sample_file))
if (length(missing_cols) > 0) {
  stop("ERROR: Required columns missing from flat files:\n",
       paste("  -", missing_cols, collapse = "\n"),
       "\n\nFound columns:\n",
       paste("  -", names(sample_file), collapse = "\n"))
}

cat("  ✓ Required columns present\n")

# Find behavioral trialdata
behav_candidates <- c(
  file.path(REPO_ROOT, "data", "analysis_ready", "bap_beh_trialdata*.csv"),
  file.path(REPO_ROOT, "data", "intermediate", "behavior_TRIALLEVEL_normalized.csv"),
  file.path(REPO_ROOT, "data", "bap_beh_trialdata*.csv"),
  "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv",
  Sys.getenv("BEHAVIORAL_DATA_FILE", unset = "")
)
behav_candidates <- unique(behav_candidates[nzchar(behav_candidates)])

behavioral_file <- NULL
for (pattern in behav_candidates) {
  if (str_detect(pattern, "\\*")) {
    matches <- Sys.glob(pattern)
    if (length(matches) > 0) {
      behavioral_file <- matches[1]
      break
    }
  } else if (file.exists(pattern)) {
    behavioral_file <- pattern
    break
  }
}

if (!is.null(behavioral_file)) {
  cat("  Found behavioral file: ", behavioral_file, "\n", sep = "")
} else {
  cat("  WARNING: Behavioral trialdata not found. Behavioral denominators will be NA.\n")
  cat("  Looked in:\n")
  for (p in behav_candidates) cat("    - ", p, "\n", sep = "")
}

# Find qc_matlab_trial_level_flags
qc_flags_file <- file.path(BAP_DIR, "qc_matlab", "qc_matlab_trial_level_flags.csv")
if (!file.exists(qc_flags_file)) {
  qc_flags_file <- file.path(REPO_ROOT, "data", "qc", "qc_matlab_trial_level_flags.csv")
}
has_qc_flags <- file.exists(qc_flags_file)
if (has_qc_flags) {
  cat("  Found qc_matlab_trial_level_flags.csv\n")
} else {
  cat("  WARNING: qc_matlab_trial_level_flags.csv not found. Will compute R proxies.\n")
}

git_hash <- get_git_hash()

# ----------------------------------------------------------------------------
# STEP 1: Build trial-level table from sample-level flat files
# ----------------------------------------------------------------------------

cat("\nSTEP 1: Building trial-level table from flat files...\n")

process_flat_file <- function(path) {
  fn <- basename(path)
  cat("  Processing: ", fn, "\n", sep = "")
  
  df <- read_csv(path, show_col_types = FALSE, progress = FALSE)
  
  # Canonical identifiers (as specified)
  df <- df %>%
    mutate(
      subject_id = as.character(sub),
      task = as.character(task),
      session = as.integer(session_used),  # NOT ses, NOT session_from_filename
      run = as.integer(run_used),           # NOT run, NOT run_from_filename
      trial_in_run = as.integer(trial_index),  # primary
      trial_in_run_raw = as.integer(trial_in_run_raw),  # diagnostic
      time = as.numeric(time),
      pupil = as.numeric(pupil),
      segmentation_source = as.character(segmentation_source),
      window_oob = as.integer(window_oob %||% 0L),
      all_nan = as.integer(all_nan %||% 0L)
    ) %>%
    filter(
      !is.na(subject_id),
      !is.na(task),
      task %in% c("ADT", "VDT"),
      !is.na(session),
      !is.na(run),
      !is.na(trial_in_run),
      !is.na(time),
      !is.na(pupil) | !is.na(window_oob) | !is.na(all_nan)  # keep rows even if pupil is NA
    )
  
  # HARD CONTAMINATION GUARDRAIL: Check for session_used==1
  if (any(df$session == 1L, na.rm = TRUE)) {
    stop("ERROR: session_used==1 detected in ", fn, 
         "\nThis indicates practice/outside-scanner contamination.\n",
         "Filtering must enforce session_used in {2,3} only.\n",
         "Found sessions: ", paste(sort(unique(df$session)), collapse = ", "))
  }
  
  # Filter to sessions 2,3 only
  df <- df %>% filter(session %in% c(2L, 3L))
  
  if (nrow(df) == 0) return(tibble())
  
  # Per-trial aggregation (CRITICAL: group by trial, not sample)
  # First compute t_rel for window validity
  df <- df %>%
    group_by(subject_id, task, session, run, trial_in_run) %>%
    mutate(
      t_rel = time - min(time, na.rm = TRUE)  # relative time within trial
    ) %>%
    ungroup()
  
  # Now aggregate to trial level
  trial <- df %>%
    group_by(subject_id, task, session, run, trial_in_run) %>%
    summarise(
      # Sample counts
      n_samples = n(),
      n_samples_valid = sum(!is.na(pupil), na.rm = TRUE),
      
      # Time statistics (using time as seconds, median dt ~ 0.004 for 250 Hz)
      dt_median = {
        tv <- sort(unique(time[!is.na(time)]))
        if (length(tv) > 1) median(diff(tv), na.rm = TRUE) else NA_real_
      },
      max_gap = {
        tv <- sort(unique(time[!is.na(time)]))
        if (length(tv) > 1) max(diff(tv), na.rm = TRUE) else NA_real_
      },
      t_min = min(time, na.rm = TRUE),
      t_max = max(time, na.rm = TRUE),
      time_range = t_max - t_min,
      
      # Pupil quality
      pupil_non_nan_rate = mean(is.finite(pupil), na.rm = TRUE),
      
      # Window validity proxies (computed from t_rel)
      # Helper function to compute window validity safely
      window_validity_safe <- function(t_rel_vec, pupil_vec, t_start, t_end) {
        in_window <- !is.na(t_rel_vec) & t_rel_vec >= t_start & t_rel_vec <= t_end
        if (!any(in_window, na.rm = TRUE)) return(NA_real_)
        pupil_in_window <- pupil_vec[in_window]
        if (all(is.na(pupil_in_window))) return(NA_real_)
        mean(is.finite(pupil_in_window), na.rm = TRUE)
      },
      
      baseline_valid_proxy = window_validity_safe(t_rel, pupil, 0, 0.5),
      cog_valid_proxy = window_validity_safe(t_rel, pupil, 0.3, 1.3),
      prestim_valid_proxy = if (any(t_rel < 0, na.rm = TRUE)) {
        window_validity_safe(t_rel, pupil, -1.0, 0)
      } else NA_real_,
      
      # Flags
      segmentation_source = first(segmentation_source[!is.na(segmentation_source)]),
      window_oob = max(window_oob, na.rm = TRUE),
      all_nan = max(all_nan, na.rm = TRUE),
      
      # Diagnostic
      trial_in_run_raw = first(trial_in_run_raw[!is.na(trial_in_run_raw)]),
      
      .groups = "drop"
    ) %>%
    mutate(
      trial_key = paste(subject_id, task, session, run, trial_in_run, sep = ":")
    )
  
  # Window validity proxies are now computed in the trial aggregation above
  # Clean up to free memory
  rm(df)
  gc(verbose = FALSE)
  
  trial
}

# Process all flat files (streaming-friendly: process one at a time, don't accumulate large objects)
cat("  Processing ", length(flat_files), " files (streaming mode)...\n", sep = "")
trial_from_flat <- tibble()

for (i in seq_along(flat_files)) {
  if (i %% 50 == 0) cat("    Progress: ", i, "/", length(flat_files), "\n", sep = "")
  trial_batch <- process_flat_file(flat_files[i])
  if (nrow(trial_batch) > 0) {
    trial_from_flat <- bind_rows(trial_from_flat, trial_batch)
  }
  # Clear intermediate objects
  rm(trial_batch)
  gc(verbose = FALSE)
}

if (nrow(trial_from_flat) == 0) {
  stop("ERROR: No valid trials constructed from flat files.")
}

cat("  ✓ Built ", nrow(trial_from_flat), " trials\n", sep = "")

# Final contamination check
if (any(trial_from_flat$session == 1L, na.rm = TRUE)) {
  stop("ERROR: session==1 detected after processing. Contamination guardrail failed!")
}

# Drop trials with window_oob==1 or all_nan==1 (keep counts for reporting)
n_dropped_oob <- sum(trial_from_flat$window_oob == 1L, na.rm = TRUE)
n_dropped_nan <- sum(trial_from_flat$all_nan == 1L, na.rm = TRUE)
n_dropped_both <- sum(trial_from_flat$window_oob == 1L | trial_from_flat$all_nan == 1L, na.rm = TRUE)

cat("  Dropped ", n_dropped_both, " trials (window_oob: ", n_dropped_oob, 
    ", all_nan: ", n_dropped_nan, ")\n", sep = "")

trial <- trial_from_flat %>%
  filter(window_oob != 1L, all_nan != 1L)

# ----------------------------------------------------------------------------
# Load and merge qc_matlab_trial_level_flags (if available)
# ----------------------------------------------------------------------------

if (has_qc_flags) {
  cat("\n  Loading qc_matlab_trial_level_flags...\n")
  qc_flags <- read_csv(qc_flags_file, show_col_types = FALSE)
  
  # Normalize column names for join (check existence first to avoid function name conflicts)
  if ("sub" %in% names(qc_flags)) {
    qc_flags$subject_id <- as.character(qc_flags$sub)
  } else if ("subject_id" %in% names(qc_flags)) {
    qc_flags$subject_id <- as.character(qc_flags$subject_id)
  } else if ("subject" %in% names(qc_flags)) {
    qc_flags$subject_id <- as.character(qc_flags$subject)
  } else {
    stop("qc_flags file missing subject identifier column (sub, subject_id, or subject)")
  }
  
  if (!"task" %in% names(qc_flags)) {
    stop("qc_flags file missing task column")
  }
  qc_flags$task <- as.character(qc_flags$task)
  
  if ("session_used" %in% names(qc_flags)) {
    qc_flags$session <- as.integer(qc_flags$session_used)
  } else if ("session" %in% names(qc_flags)) {
    qc_flags$session <- as.integer(qc_flags$session)
  } else if ("ses" %in% names(qc_flags)) {
    qc_flags$session <- as.integer(qc_flags$ses)
  } else {
    stop("qc_flags file missing session column (session_used, session, or ses)")
  }
  
  if ("run_used" %in% names(qc_flags)) {
    qc_flags$run <- as.integer(qc_flags$run_used)
  } else if ("run" %in% names(qc_flags)) {
    qc_flags$run <- as.integer(qc_flags$run)
  } else {
    stop("qc_flags file missing run column (run_used or run)")
  }
  
  if ("trial_index" %in% names(qc_flags)) {
    qc_flags$trial_in_run <- as.integer(qc_flags$trial_index)
  } else if ("trial_in_run" %in% names(qc_flags)) {
    qc_flags$trial_in_run <- as.integer(qc_flags$trial_in_run)
  } else if ("trial_in_run_raw" %in% names(qc_flags)) {
    qc_flags$trial_in_run <- as.integer(qc_flags$trial_in_run_raw)
  } else {
    stop("qc_flags file missing trial column (trial_index, trial_in_run, or trial_in_run_raw)")
  }
  
  qc_flags <- qc_flags %>%
    mutate(
      trial_key = paste(subject_id, task, session, run, trial_in_run, sep = ":")
    )
  
  # Join window validity flags
  window_cols <- c("baseline_valid", "cognitive_valid", "prestim_valid", 
                   "baseline_quality", "cognitive_quality", "overall_quality")
  available_window_cols <- intersect(window_cols, names(qc_flags))
  
  if (length(available_window_cols) > 0) {
    trial <- trial %>%
      left_join(
        qc_flags %>% select(trial_key, all_of(available_window_cols)),
        by = "trial_key"
      )
    cat("  ✓ Merged ", length(available_window_cols), " window validity columns from MATLAB\n", sep = "")
  } else {
    cat("  WARNING: qc_flags file exists but no window validity columns found\n")
    has_qc_flags <- FALSE
  }
} else {
  # Use proxies - ensure columns exist
  if (!"baseline_valid" %in% names(trial)) {
    trial$baseline_valid <- trial$baseline_valid_proxy
  }
  if (!"cognitive_valid" %in% names(trial)) {
    trial$cognitive_valid <- trial$cog_valid_proxy
  }
  if (!"prestim_valid" %in% names(trial)) {
    trial$prestim_valid <- trial$prestim_valid_proxy
  }
  trial$window_validity_source <- "R_proxy"
}

# Mark source of window validity if not already set
if (!"window_validity_source" %in% names(trial)) {
  trial$window_validity_source <- if (has_qc_flags) "MATLAB_flags" else "R_proxy"
}

# Ensure all window validity columns exist (fill with NA if missing)
if (!"baseline_valid" %in% names(trial)) {
  trial$baseline_valid <- NA_real_
}
if (!"cognitive_valid" %in% names(trial)) {
  trial$cognitive_valid <- NA_real_
}
if (!"prestim_valid" %in% names(trial)) {
  trial$prestim_valid <- NA_real_
}

# ----------------------------------------------------------------------------
# Load and merge behavioral trialdata (if available)
# ----------------------------------------------------------------------------

behavioral_trials <- tibble()
if (!is.null(behavioral_file)) {
  cat("\n  Loading behavioral trialdata...\n")
  beh_raw <- read_csv(behavioral_file, show_col_types = FALSE)
  
  # Normalize to canonical keys (check existence first)
  if ("sub" %in% names(beh_raw)) {
    beh_raw$subject_id <- as.character(beh_raw$sub)
  } else if ("subject_id" %in% names(beh_raw)) {
    beh_raw$subject_id <- as.character(beh_raw$subject_id)
  } else if ("subject" %in% names(beh_raw)) {
    beh_raw$subject_id <- as.character(beh_raw$subject)
  } else {
    stop("Behavioral file missing subject identifier column (sub, subject_id, or subject)")
  }
  
  # Task normalization
  if ("task" %in% names(beh_raw)) {
    # If task column exists, normalize it
    task_vec <- as.character(beh_raw$task)
    # Replace non-ADT/VDT values if task_modality exists
    if ("task_modality" %in% names(beh_raw)) {
      needs_replacement <- !task_vec %in% c("ADT", "VDT")
      if (any(needs_replacement)) {
        task_modality_vec <- as.character(beh_raw$task_modality[needs_replacement])
        task_vec[needs_replacement] <- ifelse(
          task_modality_vec == "aud", "ADT",
          ifelse(task_modality_vec == "vis", "VDT", task_vec[needs_replacement])
        )
      }
    }
    beh_raw$task <- task_vec
  } else if ("task_modality" %in% names(beh_raw)) {
    # Use task_modality to create task
    task_modality_vec <- as.character(beh_raw$task_modality)
    beh_raw$task <- ifelse(
      task_modality_vec == "aud", "ADT",
      ifelse(task_modality_vec == "vis", "VDT", NA_character_)
    )
  } else {
    stop("Behavioral file missing task column (task or task_modality)")
  }
  
  # Session normalization
  if ("session_used" %in% names(beh_raw)) {
    beh_raw$session <- as.integer(beh_raw$session_used)
  } else if ("session" %in% names(beh_raw)) {
    beh_raw$session <- as.integer(beh_raw$session)
  } else if ("ses" %in% names(beh_raw)) {
    beh_raw$session <- as.integer(beh_raw$ses)
  } else if ("session_num" %in% names(beh_raw)) {
    beh_raw$session <- as.integer(beh_raw$session_num)
  } else {
    stop("Behavioral file missing session column")
  }
  
  # Run normalization
  if ("run_used" %in% names(beh_raw)) {
    beh_raw$run <- as.integer(beh_raw$run_used)
  } else if ("run" %in% names(beh_raw)) {
    beh_raw$run <- as.integer(beh_raw$run)
  } else if ("run_num" %in% names(beh_raw)) {
    beh_raw$run <- as.integer(beh_raw$run_num)
  } else {
    stop("Behavioral file missing run column")
  }
  
  # Trial normalization
  if ("trial_index" %in% names(beh_raw)) {
    beh_raw$trial_in_run <- as.integer(beh_raw$trial_index)
  } else if ("trial_in_run" %in% names(beh_raw)) {
    beh_raw$trial_in_run <- as.integer(beh_raw$trial_in_run)
  } else if ("trial_num" %in% names(beh_raw)) {
    beh_raw$trial_in_run <- as.integer(beh_raw$trial_num)
  } else {
    stop("Behavioral file missing trial column")
  }
  
  # RT, choice, correct
  if ("rt" %in% names(beh_raw)) {
    beh_raw$rt <- as.numeric(beh_raw$rt)
  } else if ("same_diff_resp_secs" %in% names(beh_raw)) {
    beh_raw$rt <- as.numeric(beh_raw$same_diff_resp_secs)
  } else if ("resp1RT" %in% names(beh_raw)) {
    beh_raw$rt <- as.numeric(beh_raw$resp1RT)
  } else {
    beh_raw$rt <- NA_real_
  }
  
  if ("choice" %in% names(beh_raw)) {
    beh_raw$choice <- as.numeric(beh_raw$choice)
  } else if ("resp_is_diff" %in% names(beh_raw)) {
    beh_raw$choice <- as.numeric(beh_raw$resp_is_diff)
  } else if ("resp1" %in% names(beh_raw)) {
    beh_raw$choice <- as.numeric(beh_raw$resp1)
  } else {
    beh_raw$choice <- NA_real_
  }
  
  if ("correct" %in% names(beh_raw)) {
    beh_raw$correct <- as.numeric(beh_raw$correct)
  } else if ("resp_is_correct" %in% names(beh_raw)) {
    beh_raw$correct <- as.numeric(beh_raw$resp_is_correct)
  } else if ("iscorr" %in% names(beh_raw)) {
    beh_raw$correct <- as.numeric(beh_raw$iscorr)
  } else {
    beh_raw$correct <- NA_real_
  }
  
  # Effort
  if ("grip_targ_prop_mvc" %in% names(beh_raw)) {
    beh_raw$effort <- case_when(
      beh_raw$grip_targ_prop_mvc == 0.05 ~ "Low",
      beh_raw$grip_targ_prop_mvc == 0.40 ~ "High",
      TRUE ~ NA_character_
    )
  } else {
    beh_raw$effort <- NA_character_
  }
  
  # Intensity
  if ("intensity" %in% names(beh_raw)) {
    beh_raw$intensity <- as.numeric(beh_raw$intensity)
  } else if ("stim_level_index" %in% names(beh_raw)) {
    beh_raw$intensity <- as.numeric(beh_raw$stim_level_index)
  } else if ("stimLev" %in% names(beh_raw)) {
    beh_raw$intensity <- as.numeric(beh_raw$stimLev)
  } else {
    beh_raw$intensity <- NA_real_
  }
  
  # Filter and create trial_key
  beh_normalized <- beh_raw %>%
    filter(
      session %in% c(2L, 3L),
      task %in% c("ADT", "VDT"),
      !is.na(subject_id), !is.na(task), !is.na(session), !is.na(run), !is.na(trial_in_run)
    ) %>%
    select(subject_id, task, session, run, trial_in_run,
           rt, choice, correct, effort, intensity) %>%
    mutate(
      trial_key = paste(subject_id, task, session, run, trial_in_run, sep = ":")
    )
  
  behavioral_trials <- beh_normalized
  cat("  ✓ Loaded ", nrow(behavioral_trials), " behavioral trials\n", sep = "")
  
  # Merge with trial
  trial <- trial %>%
    left_join(behavioral_trials %>% select(-subject_id, -task, -session, -run, -trial_in_run),
              by = "trial_key")
}

# ----------------------------------------------------------------------------
# Expected design checks
# ----------------------------------------------------------------------------

cat("\nSTEP 2: Expected design checks...\n")

# Expected: <= 5 runs per subject-task-session, ~30 trials per run
# This will be computed in the design_table output
cat("  Expected runs: 1-5, expected trials per run: ~30\n")

# ----------------------------------------------------------------------------
# Window validity summary
# ----------------------------------------------------------------------------

cat("\nSTEP 3: Window validity summary...\n")

window_summary <- trial %>%
  filter(pupil_non_nan_rate > 0) %>%  # Only trials with some pupil data
  group_by(task, window_validity_source) %>%
  summarise(
    baseline_valid_mean = mean(baseline_valid, na.rm = TRUE),
    baseline_valid_median = median(baseline_valid, na.rm = TRUE),
    baseline_valid_p10 = safe_quantile(baseline_valid, 0.10),
    baseline_valid_p90 = safe_quantile(baseline_valid, 0.90),
    cognitive_valid_mean = mean(cognitive_valid, na.rm = TRUE),
    cognitive_valid_median = median(cognitive_valid, na.rm = TRUE),
    cognitive_valid_p10 = safe_quantile(cognitive_valid, 0.10),
    cognitive_valid_p90 = safe_quantile(cognitive_valid, 0.90),
    prestim_valid_mean = mean(prestim_valid, na.rm = TRUE),
    prestim_valid_median = median(prestim_valid, na.rm = TRUE),
    prestim_valid_p10 = safe_quantile(prestim_valid, 0.10),
    prestim_valid_p90 = safe_quantile(prestim_valid, 0.90),
    .groups = "drop"
  )

# ----------------------------------------------------------------------------
# Gate pass rates by threshold
# ----------------------------------------------------------------------------

cat("\nSTEP 4: Gate pass rates...\n")

thr_values <- c(0.50, 0.60, 0.70)

# Primary gate for Ch2: baseline>=thr AND cognitive>=thr
# Ch3 DDM pupil-ready: baseline>=0.50 AND cognitive>=0.50
trial <- trial %>%
  mutate(
    pupil_present = pupil_non_nan_rate > 0
  )

gate_rates <- map_dfr(thr_values, function(th) {
  trial %>%
    filter(pupil_present) %>%
    mutate(
      ch2_primary_pass = !is.na(baseline_valid) & !is.na(cognitive_valid) &
        baseline_valid >= th & cognitive_valid >= th,
      ch3_pupil_ready = !is.na(baseline_valid) & !is.na(cognitive_valid) &
        baseline_valid >= 0.50 & cognitive_valid >= 0.50
    ) %>%
    group_by(task) %>%
    summarise(
      threshold = th,
      n_pupil_present = n(),
      n_ch2_primary_pass = sum(ch2_primary_pass, na.rm = TRUE),
      n_ch3_pupil_ready = sum(ch3_pupil_ready, na.rm = TRUE),
      pass_rate_ch2_primary = mean(ch2_primary_pass, na.rm = TRUE),
      pass_rate_ch3_pupil = mean(ch3_pupil_ready, na.rm = TRUE),
      .groups = "drop"
    )
})

# Leniency check: overall_quality vs windowed (if available)
if ("overall_quality" %in% names(trial)) {
  leniency_check <- map_dfr(thr_values, function(th) {
    trial %>%
      filter(pupil_present) %>%
      mutate(
        overall_pass = overall_quality >= th,
        windowed_pass = !is.na(baseline_valid) & !is.na(cognitive_valid) &
          baseline_valid >= th & cognitive_valid >= th
      ) %>%
      group_by(task) %>%
      summarise(
        threshold = th,
        pass_rate_overall_only = mean(overall_pass, na.rm = TRUE),
        pass_rate_windowed = mean(windowed_pass, na.rm = TRUE),
        leniency_diff = pass_rate_overall_only - pass_rate_windowed,
        .groups = "drop"
      )
  })
  gate_rates <- gate_rates %>%
    left_join(leniency_check, by = c("task", "threshold"))
}

# ----------------------------------------------------------------------------
# Bias checks
# ----------------------------------------------------------------------------

cat("\nSTEP 5: Bias checks...\n")

# Usable flag for cognitive window (pass/fail at thr=0.60)
trial <- trial %>%
  mutate(
    usable_cognitive = !is.na(cognitive_valid) & cognitive_valid >= 0.60
  )

bias_checks <- tibble()

if (nrow(behavioral_trials) > 0 && "effort" %in% names(trial)) {
  # By effort, modality, intensity, RT quartile
  trial_with_rt_quartile <- trial %>%
    filter(pupil_present, !is.na(rt)) %>%
    mutate(
      rt_quartile = ntile(rt, 4)
    )
  
  bias_checks <- bind_rows(
    # By effort
    trial_with_rt_quartile %>%
      filter(!is.na(effort)) %>%
      group_by(task, effort) %>%
      summarise(
        predictor = "effort",
        predictor_value = first(effort),
        n = n(),
        usable_rate = mean(usable_cognitive, na.rm = TRUE),
        ch2_primary_rate = mean(!is.na(baseline_valid) & !is.na(cognitive_valid) &
                                baseline_valid >= 0.60 & cognitive_valid >= 0.60, na.rm = TRUE),
        .groups = "drop"
      ),
    # By intensity
    trial_with_rt_quartile %>%
      filter(!is.na(intensity)) %>%
      group_by(task, intensity) %>%
      summarise(
        predictor = "intensity",
        predictor_value = as.character(first(intensity)),
        n = n(),
        usable_rate = mean(usable_cognitive, na.rm = TRUE),
        ch2_primary_rate = mean(!is.na(baseline_valid) & !is.na(cognitive_valid) &
                                baseline_valid >= 0.60 & cognitive_valid >= 0.60, na.rm = TRUE),
        .groups = "drop"
      ),
    # By RT quartile
    trial_with_rt_quartile %>%
      filter(!is.na(rt_quartile)) %>%
      group_by(task, rt_quartile) %>%
      summarise(
        predictor = "rt_quartile",
        predictor_value = as.character(first(rt_quartile)),
        n = n(),
        usable_rate = mean(usable_cognitive, na.rm = TRUE),
        ch2_primary_rate = mean(!is.na(baseline_valid) & !is.na(cognitive_valid) &
                                baseline_valid >= 0.60 & cognitive_valid >= 0.60, na.rm = TRUE),
        .groups = "drop"
      )
  )
} else {
  # By task/session/run only
  bias_checks <- trial %>%
    filter(pupil_present) %>%
    group_by(task, session, run) %>%
    summarise(
      predictor = "session_run",
      predictor_value = paste("s", session, "r", run, sep = ""),
      n = n(),
      usable_rate = mean(usable_cognitive, na.rm = TRUE),
      ch2_primary_rate = mean(!is.na(baseline_valid) & !is.na(cognitive_valid) &
                              baseline_valid >= 0.60 & cognitive_valid >= 0.60, na.rm = TRUE),
      .groups = "drop"
    )
}

# ----------------------------------------------------------------------------
# Prestim dip summary
# ----------------------------------------------------------------------------

cat("\nSTEP 6: Prestim dip summary...\n")

prestim_dip <- trial %>%
  filter(pupil_present) %>%
  group_by(subject_id, task, session) %>%
  summarise(
    has_prestim = sum(!is.na(prestim_valid)) > 0,
    prestim_valid_mean = mean(prestim_valid, na.rm = TRUE),
    baseline_valid_mean = mean(baseline_valid, na.rm = TRUE),
    dip_depth = if (has_prestim) prestim_valid_mean - baseline_valid_mean else NA_real_,
    .groups = "drop"
  ) %>%
  group_by(task) %>%
  summarise(
    n_subjects = n_distinct(subject_id),
    n_with_prestim = sum(has_prestim, na.rm = TRUE),
    prestim_valid_mean_overall = mean(prestim_valid_mean, na.rm = TRUE),
    baseline_valid_mean_overall = mean(baseline_valid_mean, na.rm = TRUE),
    dip_depth_overall = mean(dip_depth, na.rm = TRUE),
    dip_depth_p10 = safe_quantile(dip_depth, 0.10),
    dip_depth_p90 = safe_quantile(dip_depth, 0.90),
    .groups = "drop"
  )

# ----------------------------------------------------------------------------
# STEP 2: Output exactly 8 CSVs + README
# ----------------------------------------------------------------------------

cat("\nSTEP 7: Writing outputs...\n")

# 01_file_provenance.csv
file_provenance <- tibble(
  item = c("BAP_processed_dir", "n_flat_files", "behavioral_file_found", 
           "qc_matlab_trial_level_flags_found", "git_hash", "timestamp"),
  value = c(
    BAP_DIR,
    as.character(length(flat_files)),
    if (!is.null(behavioral_file)) "yes" else "no",
    if (has_qc_flags) "yes" else "no",
    git_hash,
    format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  )
)

# Count total rows scanned
total_rows <- sum(map_int(flat_files, ~ {
  tryCatch({
    nrow(read_csv(.x, n_max = Inf, show_col_types = FALSE, progress = FALSE))
  }, error = function(e) 0L)
}))
file_provenance <- file_provenance %>%
  add_row(item = "total_rows_scanned", value = as.character(total_rows))

write_csv(file_provenance, file.path(OUTPUT_DIR, "01_file_provenance.csv"))
cat("  ✓ 01_file_provenance.csv\n")

# 02_design_expected_vs_observed.csv
design_table <- trial %>%
  group_by(subject_id, task, session) %>%
  summarise(
    expected_runs = 5L,
    expected_trials_per_run = 30L,
    expected_total_trials = expected_runs * expected_trials_per_run,
    runs_observed = paste(sort(unique(run)), collapse = ","),
    n_runs_observed = length(unique(run)),
    n_trials_observed = n_distinct(trial_in_run),  # DISTINCT, not sample rows
    .groups = "drop"
  ) %>%
  mutate(
    missing_runs_count = pmax(0L, expected_runs - n_runs_observed)
  )

if (nrow(behavioral_trials) > 0) {
  beh_design <- behavioral_trials %>%
    group_by(subject_id, task, session) %>%
    summarise(
      behavioral_total_trials = n(),
      .groups = "drop"
    )
  design_table <- design_table %>%
    left_join(beh_design, by = c("subject_id", "task", "session"))
}

write_csv(design_table, file.path(OUTPUT_DIR, "02_design_expected_vs_observed.csv"))
cat("  ✓ 02_design_expected_vs_observed.csv\n")

# 03_trials_per_subject_task_ses.csv
trials_per_subject <- trial %>%
  group_by(subject_id, task, session) %>%
  summarise(
    n_runs = length(unique(run)),
    n_trials_observed = n_distinct(trial_in_run),
    n_trials_pupil_present = sum(pupil_present, na.rm = TRUE),
    n_trials_ch2_primary_ready_0.60 = sum(
      !is.na(baseline_valid) & !is.na(cognitive_valid) &
      baseline_valid >= 0.60 & cognitive_valid >= 0.60 &
      pupil_present, na.rm = TRUE
    ),
    n_trials_ch3_pupil_ready_0.50 = sum(
      !is.na(baseline_valid) & !is.na(cognitive_valid) &
      baseline_valid >= 0.50 & cognitive_valid >= 0.50 &
      pupil_present, na.rm = TRUE
    ),
    .groups = "drop"
  )

if (nrow(behavioral_trials) > 0) {
  beh_counts <- behavioral_trials %>%
    group_by(subject_id, task, session) %>%
    summarise(
      n_trials_behavioral = n(),
      n_trials_ch3_behavior_ready = sum(
        !is.na(rt) & !is.na(choice) & rt >= 0.2 & rt <= 3.0,
        na.rm = TRUE
      ),
      .groups = "drop"
    )
  trials_per_subject <- trials_per_subject %>%
    left_join(beh_counts, by = c("subject_id", "task", "session"))
  
  # Add CH3 pupil+behavior ready
  trial_ch3 <- trial %>%
    filter(pupil_present) %>%
    mutate(
      ch3_behavior_ready = !is.na(rt) & !is.na(choice) & rt >= 0.2 & rt <= 3.0,
      ch3_pupil_ready = ch3_behavior_ready & 
        !is.na(baseline_valid) & !is.na(cognitive_valid) &
        baseline_valid >= 0.50 & cognitive_valid >= 0.50
    ) %>%
    group_by(subject_id, task, session) %>%
    summarise(
      n_trials_ch3_pupil_ready = sum(ch3_pupil_ready, na.rm = TRUE),
      .groups = "drop"
    )
  trials_per_subject <- trials_per_subject %>%
    left_join(trial_ch3, by = c("subject_id", "task", "session"))
}

write_csv(trials_per_subject, file.path(OUTPUT_DIR, "03_trials_per_subject_task_ses.csv"))
cat("  ✓ 03_trials_per_subject_task_ses.csv\n")

# 04_run_level_counts.csv
run_level_counts <- trial %>%
  group_by(subject_id, task, session, run) %>%
  summarise(
    n_trials = n_distinct(trial_in_run),
    dt_median_median = median(dt_median, na.rm = TRUE),
    max_gap_median = median(max_gap, na.rm = TRUE),
    time_range_median = median(time_range, na.rm = TRUE),
    fraction_window_oob = mean(window_oob == 1L, na.rm = TRUE),
    fraction_all_nan = mean(all_nan == 1L, na.rm = TRUE),
    segmentation_source = first(segmentation_source[!is.na(segmentation_source)]),
    .groups = "drop"
  )

write_csv(run_level_counts, file.path(OUTPUT_DIR, "04_run_level_counts.csv"))
cat("  ✓ 04_run_level_counts.csv\n")

# 05_window_validity_summary.csv
write_csv(window_summary, file.path(OUTPUT_DIR, "05_window_validity_summary.csv"))
cat("  ✓ 05_window_validity_summary.csv\n")

# 06_gate_pass_rates_by_threshold.csv
write_csv(gate_rates, file.path(OUTPUT_DIR, "06_gate_pass_rates_by_threshold.csv"))
cat("  ✓ 06_gate_pass_rates_by_threshold.csv\n")

# 07_bias_checks_key_gates.csv
write_csv(bias_checks, file.path(OUTPUT_DIR, "07_bias_checks_key_gates.csv"))
cat("  ✓ 07_bias_checks_key_gates.csv\n")

# 08_prestim_dip_summary.csv
write_csv(prestim_dip, file.path(OUTPUT_DIR, "08_prestim_dip_summary.csv"))
cat("  ✓ 08_prestim_dip_summary.csv\n")

# README_quick_share.md
n_subjects <- n_distinct(trial$subject_id)
n_trials_total <- nrow(trial)
n_trials_pupil_present <- sum(trial$pupil_present, na.rm = TRUE)
n_trials_ch2 <- sum(
  trial$pupil_present & 
  !is.na(trial$baseline_valid) & !is.na(trial$cognitive_valid) &
  trial$baseline_valid >= 0.60 & trial$cognitive_valid >= 0.60,
  na.rm = TRUE
)
n_trials_ch2_primary <- n_trials_ch2  # alias for consistency
n_trials_ch3_pupil <- if (nrow(behavioral_trials) > 0) {
  sum(
    trial$pupil_present &
    !is.na(trial$rt) & !is.na(trial$choice) & trial$rt >= 0.2 & trial$rt <= 3.0 &
    !is.na(trial$baseline_valid) & !is.na(trial$cognitive_valid) &
    trial$baseline_valid >= 0.50 & trial$cognitive_valid >= 0.50,
    na.rm = TRUE
  )
} else NA_integer_

readme_content <- paste0(
  "# Quick-Share QC Snapshot\n\n",
  "Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n",
  "## Purpose\n\n",
  "This export provides a compact QC snapshot to assess data readiness for:\n",
  "- **Chapter 2**: Psychometric + pupil coupling analyses\n",
  "- **Chapter 3**: DDM (Drift Diffusion Model) analyses\n\n",
  "## Filters Applied\n\n",
  "- **Sessions**: 2-3 only (session 1 / practice / OutsideScanner excluded)\n",
  "- **Runs**: 1-5 only\n",
  "- **Tasks**: ADT and VDT\n",
  "- **Trial exclusions**: window_oob==1 or all_nan==1\n\n",
  "## Top-Line Counts\n\n",
  "- **N subjects**: ", n_subjects, "\n",
  "- **N trials (total)**: ", n_trials_total, "\n",
  "- **N trials (pupil-present)**: ", n_trials_pupil_present, "\n",
  "- **N trials (CH2 primary ready @ 0.60)**: ", n_trials_ch2, "\n",
  if (!is.na(n_trials_ch3_pupil)) {
    paste0("- **N trials (CH3 pupil+behavior ready @ 0.50)**: ", n_trials_ch3_pupil, "\n")
  } else "",
  "\n## Window Validity Source\n\n",
  "- **Source**: ", if (has_qc_flags) "MATLAB flags (qc_matlab_trial_level_flags.csv)" else "R proxies (computed from t_rel windows)", "\n",
  "- **Baseline window**: first 0.5s of t_rel (relative time within trial)\n",
  "- **Cognitive window**: t_rel [0.3, 1.3] seconds\n",
  "- **Prestim window**: t_rel [-1.0, 0] seconds (if available)\n\n",
  "## Files Generated\n\n",
  "1. **01_file_provenance.csv** - Input paths, git hash, timestamps, file counts\n",
  "2. **02_design_expected_vs_observed.csv** - Expected vs observed runs/trials per subject×task×session\n",
  "3. **03_trials_per_subject_task_ses.csv** - Trial counts and gate counts by subject×task×session\n",
  "4. **04_run_level_counts.csv** - Run-level statistics (n_trials, dt_median, max_gap, time_range, window_oob/all_nan fractions)\n",
  "5. **05_window_validity_summary.csv** - Window validity distributions by task\n",
  "6. **06_gate_pass_rates_by_threshold.csv** - CH2/CH3 gate pass rates at thresholds {0.50, 0.60, 0.70}\n",
  "7. **07_bias_checks_key_gates.csv** - Gate bias by effort/intensity/RT quartile (if behavioral data available) or by task/session/run\n",
  "8. **08_prestim_dip_summary.csv** - Prestim window depth/status by task\n\n",
  "## Data Readiness Verdict\n\n",
  "### Chapter 2 (Pupil Coupling)\n",
  "- **Primary gate**: baseline_valid >= 0.60 AND cognitive_valid >= 0.60\n",
  "- **Retention rate**: ", sprintf("%.1f%%", 100 * n_trials_ch2 / max(1, n_trials_pupil_present)), 
  " of pupil-present trials pass\n",
  "- **Decision**: See `03_trials_per_subject_task_ses.csv` for per-subject counts\n\n",
  "### Chapter 3 (DDM)\n",
  if (!is.na(n_trials_ch3_pupil)) {
    paste0(
      "- **Gate**: behavior-ready (RT 0.2-3.0s) AND baseline_valid >= 0.50 AND cognitive_valid >= 0.50\n",
      "- **Retention rate**: ", sprintf("%.1f%%", 100 * n_trials_ch3_pupil / max(1, n_trials_pupil_present)),
      " of pupil-present trials pass\n",
      "- **Decision**: See `03_trials_per_subject_task_ses.csv` for per-subject counts\n"
    )
  } else {
    paste0(
      "- **Gate**: baseline_valid >= 0.50 AND cognitive_valid >= 0.50 (behavioral data not available)\n",
      "- **Retention rate**: See `06_gate_pass_rates_by_threshold.csv`\n",
      "- **Decision**: Behavioral data required for full CH3 assessment\n"
    )
  },
  "\n## Key Identifiers\n\n",
  "- **subject_id**: from `sub` column\n",
  "- **session**: from `session_used` (NOT `ses`, NOT `session_from_filename`)\n",
  "- **run**: from `run_used` (NOT `run`, NOT `run_from_filename`)\n",
  "- **trial_in_run**: from `trial_index` (primary), `trial_in_run_raw` (diagnostic)\n",
  "- **trial_key**: paste(subject_id, task, session, run, trial_in_run, sep=\":\")\n\n",
  "## Notes\n\n",
  "- Per-trial relative time (`t_rel`) computed as `time - min(time)` within each trial\n",
  "- Median time step expected ~0.004 seconds (250 Hz)\n",
  "- All window validity computed from `t_rel`, not from `trial_start_time_ptb` (treated as metadata)\n"
)

writeLines(readme_content, file.path(OUTPUT_DIR, "README_quick_share.md"))
cat("  ✓ README_quick_share.md\n")

# ----------------------------------------------------------------------------
# STEP 4: Validation with known case (BAP170 ADT)
# ----------------------------------------------------------------------------

cat("\nSTEP 8: Validation (BAP170 ADT)...\n")

bap170_adt <- trial %>%
  filter(subject_id == "BAP170", task == "ADT")

if (nrow(bap170_adt) > 0) {
  bap170_runs <- bap170_adt %>%
    group_by(session, run) %>%
    summarise(
      n_trials = n_distinct(trial_in_run),
      dt_median_check = median(dt_median, na.rm = TRUE),
      .groups = "drop"
    )
  
  cat("  BAP170 ADT:\n")
  for (i in 1:nrow(bap170_runs)) {
    cat("    Session ", bap170_runs$session[i], ", Run ", bap170_runs$run[i], 
        ": ", bap170_runs$n_trials[i], " trials, dt_median=", 
        sprintf("%.4f", bap170_runs$dt_median_check[i]), "\n", sep = "")
  }
  
  # Assertions
  runs_1_5 <- bap170_adt %>% filter(run %in% 1:5) %>% pull(run) %>% unique() %>% sort()
  if (length(runs_1_5) > 0) {
    for (r in runs_1_5) {
      n_trials_r <- bap170_adt %>% filter(run == r) %>% n_distinct(.$trial_in_run)
      if (n_trials_r != 30) {
        warning("BAP170 ADT run ", r, " has ", n_trials_r, " trials (expected 30)")
      }
    }
  }
  
  dt_median_overall <- median(bap170_adt$dt_median, na.rm = TRUE)
  if (!is.na(dt_median_overall) && abs(dt_median_overall - 0.004) > 0.002) {
    warning("BAP170 ADT dt_median = ", sprintf("%.4f", dt_median_overall), 
            " (expected ~0.004)")
  } else {
    cat("  ✓ dt_median check passed\n")
  }
} else {
  cat("  BAP170 ADT not found in data (validation skipped)\n")
}

cat("\n=== QUICK QC EXPORT COMPLETE ===\n")
cat("Outputs saved to: ", OUTPUT_DIR, "\n", sep = "")

