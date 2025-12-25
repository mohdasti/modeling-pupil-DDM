#!/usr/bin/env Rscript
# ============================================================================
# Export Quick-Share QC Tables
# ============================================================================
# - Recomputes window validity using an explicit time reference
# - Supports both ADT and VDT
# - Writes EXACTLY 8 small CSVs (+ README_quick_share.md) to
#     02_pupillometry_analysis/quick_share/
# - Makes denominators explicit (behavioral vs pupil-present)
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(tidyr)
})

cat("=== EXPORT QUICK-SHARE QC TABLES ===\n\n")

# ----------------------------------------------------------------------------
# Helper utilities
# ----------------------------------------------------------------------------

identify_column <- function(df, candidates) {
  for (cand in candidates) {
    if (cand %in% names(df)) return(cand)
  }
  return(NA_character_)
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x

safe_quantile <- function(x, prob) {
  if (all(is.na(x))) return(NA_real_)
  as.numeric(quantile(x, prob, na.rm = TRUE, names = FALSE))
}

window_validity <- function(time, pupil, start, end) {
  if (all(is.na(time)) || all(is.na(pupil))) return(NA_real_)
  in_window <- !is.na(time) & time >= start & time <= end
  if (!any(in_window)) return(NA_real_)
  mean(!is.na(pupil[in_window]), na.rm = TRUE)
}

get_git_hash <- function() {
  hash <- tryCatch(
    system("git rev-parse --short HEAD", intern = TRUE),
    error = function(e) NA_character_
  )
  if (length(hash) == 0) NA_character_ else hash[[1]]
}

# ----------------------------------------------------------------------------
# Paths and discovery
# ----------------------------------------------------------------------------

# Repo root: assume script is run from repo root OR from this directory
this_dir <- normalizePath(dirname(sys.frames()[[1]]$ofile %||% "."), mustWork = FALSE)
if (basename(this_dir) == "02_pupillometry_analysis") {
  REPO_ROOT <- normalizePath(file.path(this_dir, ".."))
} else {
  # Fallback: assume current working directory is repo root
  REPO_ROOT <- normalizePath(getwd())
}

OUTPUT_DIR <- file.path(REPO_ROOT, "02_pupillometry_analysis", "quick_share")
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("Repo root: ", REPO_ROOT, "\n", sep = "")
cat("Output dir: ", OUTPUT_DIR, "\n\n", sep = "")

cat("STEP 1: Discovering inputs...\n")

# BAP_processed discovery (prefer local, then env)
possible_bap_dirs <- c(
  file.path(REPO_ROOT, "BAP_processed"),
  file.path(REPO_ROOT, "data", "BAP_processed"),
  Sys.getenv("BAP_PROCESSED_DIR", unset = "")
)
possible_bap_dirs <- unique(possible_bap_dirs[nzchar(possible_bap_dirs)])

BAP_DIR <- NULL
for (d in possible_bap_dirs) {
  if (dir.exists(d)) {
    flat_files_tmp <- list.files(d, pattern = "_flat\\.csv$", full.names = TRUE, recursive = TRUE)
    if (length(flat_files_tmp) > 0) {
      BAP_DIR <- d
      cat("  Using BAP_processed dir: ", d, "\n", sep = "")
      break
    }
  }
}

if (is.null(BAP_DIR)) {
  stop("Could not locate BAP_processed directory. Tried:\n",
       paste(possible_bap_dirs, collapse = "\n"))
}

# Key files under BAP_processed
qc_run_counts_file   <- file.path(BAP_DIR, "qc_matlab", "qc_matlab_run_trial_counts.csv")
qc_trial_flags_file  <- file.path(BAP_DIR, "qc_matlab", "qc_matlab_trial_level_flags.csv")
flat_files           <- list.files(BAP_DIR, pattern = "_flat\\.csv$", full.names = TRUE, recursive = TRUE)
flat_merged_files    <- list.files(BAP_DIR, pattern = "_flat_merged\\.csv$", full.names = TRUE, recursive = TRUE)

cat("  Found ", length(flat_files), " flat files\n", sep = "")
if (length(flat_merged_files) > 0) {
  cat("  Found ", length(flat_merged_files), " flat_merged files (not required)\n", sep = "")
}
if (file.exists(qc_run_counts_file))  cat("  Found qc_matlab_run_trial_counts.csv\n")
if (file.exists(qc_trial_flags_file)) cat("  Found qc_matlab_trial_level_flags.csv\n")

# Analysis-ready / behavioral trial data
analysis_ready_dir <- file.path(REPO_ROOT, "data", "analysis_ready")
intermediate_dir   <- file.path(REPO_ROOT, "data", "intermediate")

behav_candidates <- c(
  file.path(intermediate_dir, "behavior_TRIALLEVEL_normalized.csv"),
  list.files(analysis_ready_dir, pattern = "\\.csv$", full.names = TRUE)
)
behav_candidates <- unique(behav_candidates[file.exists(behav_candidates)])

behavioral_file <- if (length(behav_candidates) > 0) behav_candidates[[1]] else NA_character_
if (!is.na(behavioral_file)) {
  cat("  Behavioral trial-level candidate: ", behavioral_file, "\n", sep = "")
} else {
  cat("  Behavioral trial-level file: NOT FOUND (behavioral denominators will be NA)\n")
}

git_hash <- get_git_hash()

# ----------------------------------------------------------------------------
# File provenance table (01)
# ----------------------------------------------------------------------------

file_provenance <- tibble(
  file_type = character(),
  filepath = character(),
  modified_time = character(),
  size_mb = numeric(),
  n_rows = numeric(),
  n_cols = numeric(),
  git_hash = character()
)

add_prov <- function(type, path) {
  if (!file.exists(path)) return(invisible(NULL))
  info <- file.info(path)
  n_rows <- NA_real_
  n_cols <- NA_real_
  if (grepl("\\.csv$", path, ignore.case = TRUE)) {
    # cheap header read
    hdr <- tryCatch(read_csv(path, n_max = 0, show_col_types = FALSE),
                    error = function(e) NULL)
    if (!is.null(hdr)) n_cols <- ncol(hdr)
  }
  rel <- sub(paste0("^", REPO_ROOT, "/"), "", normalizePath(path))
  file_provenance <<- bind_rows(
    file_provenance,
    tibble(
      file_type = type,
      filepath = rel,
      modified_time = format(info$mtime, "%Y-%m-%d %H:%M:%S"),
      size_mb = round(info$size / 1024^2, 3),
      n_rows = n_rows,
      n_cols = n_cols,
      git_hash = git_hash
    )
  )
}

add_prov("BAP_processed_dir", BAP_DIR)
if (file.exists(qc_run_counts_file))  add_prov("qc_matlab_run_trial_counts", qc_run_counts_file)
if (file.exists(qc_trial_flags_file)) add_prov("qc_matlab_trial_level_flags", qc_trial_flags_file)
if (!is.na(behavioral_file))          add_prov("behavior_triallevel", behavioral_file)

# ----------------------------------------------------------------------------
# Load qc_matlab run-level and trial-level (optional)
# ----------------------------------------------------------------------------

qc_run_counts <- if (file.exists(qc_run_counts_file)) {
  read_csv(qc_run_counts_file, show_col_types = FALSE)
} else tibble()

qc_trial_flags <- if (file.exists(qc_trial_flags_file)) {
  read_csv(qc_trial_flags_file, show_col_types = FALSE)
} else tibble()

# ----------------------------------------------------------------------------
# Load behavioral triallevel (optional)
# ----------------------------------------------------------------------------

behavioral_trials <- tibble()

if (!is.na(behavioral_file)) {
  beh_raw <- read_csv(behavioral_file, show_col_types = FALSE)

  if ("subject_id" %in% names(beh_raw)) {
    behavioral_trials <- beh_raw %>%
      mutate(
        subject_id = as.character(subject_id),
        task = case_when(
          task %in% c("ADT", "VDT") ~ task,
          task_modality == "aud" ~ "ADT",
          task_modality == "vis" ~ "VDT",
          TRUE ~ as.character(task %||% task_modality)
        ),
        session = as.integer(session %||% session_num),
        run     = as.integer(run %||% run_num),
        trial_in_run_raw = as.integer(trial_in_run %||% trial_num),
        rt = as.numeric(rt %||% same_diff_resp_secs %||% resp1RT),
        choice = as.numeric(choice %||% resp_is_diff),
        correct = as.numeric(correct %||% resp_is_correct),
        effort = case_when(
          "grip_targ_prop_mvc" %in% names(.) & grip_targ_prop_mvc == 0.05 ~ "Low",
          "grip_targ_prop_mvc" %in% names(.) & grip_targ_prop_mvc == 0.40 ~ "High",
          TRUE ~ NA_character_
        ),
        intensity = as.numeric(
          intensity %||% stim_level_index %||% stimLev
        ),
        session = if_else(is.na(session), NA_integer_, session)
      ) %>%
      filter(session %in% c(2L, 3L),
             task %in% c("ADT", "VDT")) %>%
      select(subject_id, task, session, run, trial_in_run_raw,
             rt, choice, correct, effort, intensity)
  }
}

# ----------------------------------------------------------------------------
# Sample-level flat → trial-level window validity
# ----------------------------------------------------------------------------

cat("\nSTEP 2: Building trial-level pupil summary (time-reference aware)...\n")

if (length(flat_files) == 0) {
  stop("No *_flat.csv files found under BAP_processed directory.")
}

process_flat_file <- function(path) {
  fn <- basename(path)
  cat("  Processing ", fn, "\n", sep = "")

  df <- read_csv(path, show_col_types = FALSE)

  # Canonical identifiers
  col_sub   <- identify_column(df, c("sub", "subject", "subject_id"))
  col_task  <- identify_column(df, c("task", "task_name", "task_modality"))
  col_ses   <- identify_column(df, c("ses", "session", "session_num"))
  col_run   <- identify_column(df, c("run", "run_num"))
  col_trial <- identify_column(df, c("trial_in_run_raw", "trial_in_run", "trial_index", "trial_num"))
  col_time  <- identify_column(df, c("time", "time_ptb", "trial_pupilTime"))
  col_tstart <- identify_column(df, c("trial_start_time_ptb", "trialStartTime_ptb"))

  col_pupil <- identify_column(df, c("pupil", "pupilSize", "pupil_diameter"))

  if (is.na(col_time) || is.na(col_tstart) || is.na(col_pupil)) {
    # Cannot compute time-relative windows without these
    return(tibble())
  }

  df <- df %>%
    mutate(
      subject_id = if (!is.na(col_sub)) as.character(.data[[col_sub]]) else str_extract(fn, "BAP\\d+"),
      task_raw   = if (!is.na(col_task)) as.character(.data[[col_task]]) else NA_character_,
      task = case_when(
        task_raw %in% c("ADT", "VDT") ~ task_raw,
        task_raw == "Aoddball" ~ "ADT",
        task_raw == "Voddball" ~ "VDT",
        str_detect(fn, "ADT") ~ "ADT",
        str_detect(fn, "VDT") ~ "VDT",
        TRUE ~ NA_character_
      ),
      session = if (!is.na(col_ses)) as.integer(.data[[col_ses]]) else NA_integer_,
      run     = if (!is.na(col_run)) as.integer(.data[[col_run]]) else NA_integer_,
      trial_in_run_raw = if (!is.na(col_trial)) as.integer(.data[[col_trial]]) else NA_integer_,
      time_ptb  = as.numeric(.data[[col_time]]),
      trial_start_time_ptb = as.numeric(.data[[col_tstart]]),
      pupil    = as.numeric(.data[[col_pupil]])
    ) %>%
    filter(
      !is.na(subject_id),
      !is.na(task),
      session %in% c(2L, 3L),
      run %in% 1:5,
      !is.na(trial_in_run_raw)
    )

  if (!nrow(df)) return(tibble())

  # Time relative to trial start
  df <- df %>%
    mutate(
      t_rel_trial = time_ptb - trial_start_time_ptb
    )

  # Per-trial aggregation with correct time reference
  trial <- df %>%
    group_by(subject_id, task, session, run, trial_in_run_raw) %>%
    summarise(
      n_samples_total = n(),
      n_samples_valid = sum(!is.na(pupil), na.rm = TRUE),
      pupil_present_trial = any(!is.na(pupil)),
      t_min = min(t_rel_trial, na.rm = TRUE),
      t_max = max(t_rel_trial, na.rm = TRUE),
      t_median = median(t_rel_trial, na.rm = TRUE),
      # Reference event: by default trial start => t_rel_trial already relative to start
      ref_event = "trial_start",
      # Baseline / prestim relative to reference (trial start)
      baseline_valid = window_validity(t_rel_trial, pupil, -0.5, 0.0),
      prestim_valid  = window_validity(t_rel_trial, pupil, -1.0, 0.0),
      # Cognitive window requires target onset. If we don't have it, leave NA.
      cognitive_valid = NA_real_,
      # Flags from sample-level if present
      segmentation_source = if ("segmentation_source" %in% names(df)) {
        as.character(first(segmentation_source[!is.na(segmentation_source)]))
      } else NA_character_,
      .groups = "drop"
    ) %>%
    mutate(
      trial_uid = paste(subject_id, task, session, run, trial_in_run_raw, sep = ":")
    )

  trial
}

trial_from_flat <- map_dfr(flat_files, process_flat_file)

if (!nrow(trial_from_flat)) {
  stop("No valid trials could be constructed from flat files (missing time / trial_start columns?)")
}

cat("  Built ", nrow(trial_from_flat), " trials with explicit time reference\n", sep = "")

# ----------------------------------------------------------------------------
# Timebase assertions (per run)
# ----------------------------------------------------------------------------

cat("\nSTEP 3: Timebase assertions...\n")

run_timebase <- trial_from_flat %>%
  group_by(subject_id, task, session, run) %>%
  summarise(
    min_t_rel_trial_median = median(t_min, na.rm = TRUE),
    max_t_rel_trial_median = median(t_max, na.rm = TRUE),
    missing_target_marker_count = sum(is.na(cognitive_valid)),
    .groups = "drop"
  ) %>%
  mutate(
    timebase_issue = !(
      min_t_rel_trial_median <= -2.5 & min_t_rel_trial_median >= -3.5 &
      max_t_rel_trial_median >= 10.2 & max_t_rel_trial_median <= 11.2
    )
  )

n_timebase_issues <- sum(run_timebase$timebase_issue, na.rm = TRUE)
cat("  Runs with timebase issues: ", n_timebase_issues, "\n", sep = "")

# ----------------------------------------------------------------------------
# Merge in qc_matlab run counts if present
# ----------------------------------------------------------------------------

if (nrow(qc_run_counts)) {
  # Try to normalise qc_run_counts key columns
  qc_run_counts <- qc_run_counts %>%
    rename_with(~"subject_id", .cols = any_of(c("sub", "subject_id", "subject"))) %>%
    rename_with(~"task_raw",   .cols = any_of(c("task", "task_name", "task_modality"))) %>%
    rename_with(~"session",    .cols = any_of(c("ses", "session", "session_num"))) %>%
    rename_with(~"run",        .cols = any_of(c("run", "run_num"))) %>%
    mutate(
      subject_id = as.character(subject_id),
      task = case_when(
        task_raw %in% c("ADT", "VDT") ~ task_raw,
        task_raw == "Aoddball" ~ "ADT",
        task_raw == "Voddball" ~ "VDT",
        TRUE ~ task_raw
      ),
      session = as.integer(session),
      run = as.integer(run)
    )
}

# ----------------------------------------------------------------------------
# Merge pupil trial-level with behavioral (if available)
# ----------------------------------------------------------------------------

trial <- trial_from_flat

if (nrow(behavioral_trials)) {
  trial <- trial %>%
    left_join(
      behavioral_trials,
      by = c("subject_id", "task", "session", "run", "trial_in_run_raw")
    )
}

# Canonical gates
trial <- trial %>%
  mutate(
    ch2_primary = !is.na(baseline_valid) & !is.na(cognitive_valid) &
      baseline_valid >= 0.60 & cognitive_valid >= 0.60,
    ch3_behavior_ready = !is.na(rt) & !is.na(choice) &
      rt >= 0.2 & rt <= 3.0,
    ch3_pupil_ready = ch3_behavior_ready & ch2_primary
  )

# ----------------------------------------------------------------------------
# 02_design_expected_vs_observed.csv
# ----------------------------------------------------------------------------

cat("\nSTEP 4: Building quick-share tables...\n")

design_table <- trial %>%
  group_by(subject_id, task, session) %>%
  summarise(
    expected_runs = 5L,
    expected_trials_per_run = 30L,
    expected_total_trials = expected_runs * expected_trials_per_run,
    runs_observed = sort(unique(run)),
    n_runs_observed = length(runs_observed),
    trials_pupil_present = sum(pupil_present_trial, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    runs_observed_str = paste(runs_observed, collapse = ","),
    missing_runs = setdiff(1:5, runs_observed),
    runs_missing_str = ifelse(lengths(list(missing_runs)) == 0L,
                              "",
                              vapply(missing_runs, function(x) paste(x, collapse = ","), character(1))),
    missing_runs_count = pmax(0L, expected_runs - n_runs_observed)
  ) %>%
  select(-runs_observed, -missing_runs)

if (nrow(behavioral_trials)) {
  beh_design <- behavioral_trials %>%
    group_by(subject_id, task, session) %>%
    summarise(
      behavioral_total_trials = n(),
      .groups = "drop"
    )
  design_table <- design_table %>%
    left_join(beh_design,
              by = c("subject_id", "task", "session"))
}

# CH2 window-pass counts at thresholds (among pupil-present trials)
thr_values <- c(0.5, 0.6, 0.7)

window_pass_counts <- map_dfr(thr_values, function(th) {
  trial %>%
    filter(pupil_present_trial) %>%
    group_by(subject_id, task, session) %>%
    summarise(
      threshold = th,
      pupil_window_pass_trials = sum(baseline_valid >= th & cognitive_valid >= th, na.rm = TRUE),
      .groups = "drop"
    )
})

window_pass_wide <- window_pass_counts %>%
  mutate(colname = paste0("pupil_window_pass_thr_", sprintf("%.2f", threshold))) %>%
  select(-threshold) %>%
  pivot_wider(
    names_from = colname,
    values_from = pupil_window_pass_trials,
    values_fill = 0L
  )

design_table <- design_table %>%
  left_join(window_pass_wide,
            by = c("subject_id", "task", "session"))

# ----------------------------------------------------------------------------
# 03_trials_per_subject_task_ses.csv
# ----------------------------------------------------------------------------

trials_per_subject <- trial %>%
  group_by(subject_id, task, session) %>%
  summarise(
    n_trials_pupil_present = sum(pupil_present_trial, na.rm = TRUE),
    n_trials_ch2_primary = sum(ch2_primary, na.rm = TRUE),
    n_trials_ch3_behavior_ready = sum(ch3_behavior_ready, na.rm = TRUE),
    n_trials_ch3_pupil_ready = sum(ch3_pupil_ready, na.rm = TRUE),
    .groups = "drop"
  )

if (nrow(behavioral_trials)) {
  beh_counts <- behavioral_trials %>%
    group_by(subject_id, task, session) %>%
    summarise(
      n_trials_behavioral = n(),
      .groups = "drop"
    )
  trials_per_subject <- trials_per_subject %>%
    left_join(beh_counts,
              by = c("subject_id", "task", "session"))
}

# ----------------------------------------------------------------------------
# 04_run_level_counts.csv
# ----------------------------------------------------------------------------

run_level_counts <- trial %>%
  group_by(subject_id, task, session, run) %>%
  summarise(
    n_trials_pupil_present = sum(pupil_present_trial, na.rm = TRUE),
    segmentation_source = first(segmentation_source[!is.na(segmentation_source)]),
    .groups = "drop"
  ) %>%
  left_join(run_timebase,
            by = c("subject_id", "task", "session", "run"))

if (nrow(qc_run_counts)) {
  # assume qc_run_counts has per-run extracted trial counts
  extracted_counts <- qc_run_counts %>%
    rename_with(~"subject_id", .cols = any_of(c("subject_id", "sub", "subject"))) %>%
    rename_with(~"task",       .cols = any_of(c("task", "task_modality", "task_name"))) %>%
    rename_with(~"session",    .cols = any_of(c("ses", "session", "session_num"))) %>%
    rename_with(~"run",        .cols = any_of(c("run", "run_num"))) %>%
    mutate(
      subject_id = as.character(subject_id),
      task = case_when(
        task %in% c("ADT", "VDT") ~ task,
        task == "Aoddball" ~ "ADT",
        task == "Voddball" ~ "VDT",
        TRUE ~ task
      ),
      session = as.integer(session),
      run = as.integer(run)
    ) %>%
    select(subject_id, task, session, run,
           n_trials_extracted = any_of(c("n_trials", "n_pupil_trials", "n_extracted_trials")))

  run_level_counts <- run_level_counts %>%
    left_join(extracted_counts,
              by = c("subject_id", "task", "session", "run"))
} else {
  run_level_counts$n_trials_extracted <- NA_integer_
}

run_level_counts <- run_level_counts %>%
  mutate(
    missing_target_marker_count = if_else(is.na(missing_target_marker_count),
                                          0L, as.integer(missing_target_marker_count))
  )

# ----------------------------------------------------------------------------
# 05_window_validity_summary.csv
# ----------------------------------------------------------------------------

window_summary <- trial %>%
  group_by(task) %>%
  summarise(
    baseline_mean  = mean(baseline_valid, na.rm = TRUE),
    baseline_median = median(baseline_valid, na.rm = TRUE),
    baseline_p10   = safe_quantile(baseline_valid, 0.10),
    baseline_p90   = safe_quantile(baseline_valid, 0.90),
    baseline_pct_na = mean(is.na(baseline_valid)),

    cognitive_mean  = mean(cognitive_valid, na.rm = TRUE),
    cognitive_median = median(cognitive_valid, na.rm = TRUE),
    cognitive_p10   = safe_quantile(cognitive_valid, 0.10),
    cognitive_p90   = safe_quantile(cognitive_valid, 0.90),
    cognitive_pct_na = mean(is.na(cognitive_valid)),

    prestim_mean  = mean(prestim_valid, na.rm = TRUE),
    prestim_median = median(prestim_valid, na.rm = TRUE),
    prestim_p10   = safe_quantile(prestim_valid, 0.10),
    prestim_p90   = safe_quantile(prestim_valid, 0.90),
    prestim_pct_na = mean(is.na(prestim_valid)),
    .groups = "drop"
  )

# ----------------------------------------------------------------------------
# 06_gate_pass_rates_by_threshold.csv
# ----------------------------------------------------------------------------

gate_rates <- map_dfr(thr_values, function(th) {
  df <- trial %>%
    mutate(
      ch2_window_pass = !is.na(baseline_valid) & !is.na(cognitive_valid) &
        baseline_valid >= th & cognitive_valid >= th
    )

  by_task <- df %>%
    group_by(task) %>%
    summarise(
      threshold = th,
      # denominators
      n_pupil_present = sum(pupil_present_trial, na.rm = TRUE),
      n_behavioral_total = if (nrow(behavioral_trials)) {
        behavioral_trials %>%
          filter(task == first(task)) %>%
          nrow()
      } else NA_integer_,
      # counts
      n_pass_pupil_present = sum(ch2_window_pass & pupil_present_trial, na.rm = TRUE),
      n_pass_behavior_total = if (!is.na(n_behavioral_total)) n_pass_pupil_present else NA_integer_,
      pass_rate_pupil_present = ifelse(n_pupil_present > 0,
                                       n_pass_pupil_present / n_pupil_present, NA_real_),
      pass_rate_behavior_total = ifelse(!is.na(n_behavioral_total) & n_behavioral_total > 0,
                                        n_pass_behavior_total / n_behavioral_total, NA_real_),
      .groups = "drop"
    )
  by_task
})

# ----------------------------------------------------------------------------
# 07_bias_checks_key_gates.csv
# ----------------------------------------------------------------------------

predictors_available <- c(
  effort = "effort" %in% names(trial),
  intensity = "intensity" %in% names(trial),
  session = TRUE
)

mk_bias <- function(var) {
  if (!predictors_available[[var]]) return(NULL)
  trial %>%
    filter(pupil_present_trial) %>%
    filter(!is.na(.data[[var]])) %>%
    group_by(task, !!sym(var)) %>%
    summarise(
      n = n(),
      ch2_primary_pass_rate = mean(ch2_primary, na.rm = TRUE),
      ch3_pupil_ready_pass_rate = mean(ch3_pupil_ready, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    group_by(task) %>%
    summarise(
      predictor = var,
      max_min_ch2_primary = max(ch2_primary_pass_rate, na.rm = TRUE) -
        min(ch2_primary_pass_rate, na.rm = TRUE),
      max_min_ch3_pupil = max(ch3_pupil_ready_pass_rate, na.rm = TRUE) -
        min(ch3_pupil_ready_pass_rate, na.rm = TRUE),
      flag_ch2_primary = max_min_ch2_primary > 0.10,
      flag_ch3_pupil   = max_min_ch3_pupil > 0.10,
      .groups = "drop"
    )
}

bias_list <- list(
  mk_bias("effort"),
  mk_bias("intensity"),
  mk_bias("session")
)

bias_checks <- bind_rows(bias_list[!vapply(bias_list, is.null, logical(1))])

if (!nrow(bias_checks)) {
  bias_checks <- tibble(
    task = character(),
    predictor = character(),
    max_min_ch2_primary = numeric(),
    max_min_ch3_pupil = numeric(),
    flag_ch2_primary = logical(),
    flag_ch3_pupil = logical()
  )
}

if (!predictors_available[["effort"]] &&
    !predictors_available[["intensity"]] &&
    !predictors_available[["session"]]) {
  bias_checks <- bias_checks %>%
    add_row(task = "ALL",
            predictor = "NONE",
            max_min_ch2_primary = NA_real_,
            max_min_ch3_pupil = NA_real_,
            flag_ch2_primary = NA,
            flag_ch3_pupil = NA)
}

# ----------------------------------------------------------------------------
# 08_prestim_dip_summary.csv
# ----------------------------------------------------------------------------

prestim_dip <- trial %>%
  group_by(task) %>%
  summarise(
    has_prestim = sum(!is.na(prestim_valid)) > 0,
    availability_min = ifelse(has_prestim, mean(prestim_valid, na.rm = TRUE), NA_real_),
    availability_reference = ifelse(has_prestim, mean(baseline_valid, na.rm = TRUE), NA_real_),
    dip_depth = ifelse(has_prestim, availability_min - availability_reference, NA_real_),
    dip_time = NA_real_,  # cannot reconstruct time-of-dip from trial-level only
    status = ifelse(has_prestim, "estimated_from_trial_windows", "insufficient_pretrial_data"),
    .groups = "drop"
  )

# ----------------------------------------------------------------------------
# Safeguard: ADT vs VDT cognitive-validity imbalance
# ----------------------------------------------------------------------------

adt_cog_all_na <- trial %>%
  filter(task == "ADT") %>%
  summarise(all_na = all(is.na(cognitive_valid))) %>%
  pull(all_na)
vdt_cog_all_na <- trial %>%
  filter(task == "VDT") %>%
  summarise(all_na = all(is.na(cognitive_valid))) %>%
  pull(all_na)

if (length(adt_cog_all_na) == 1 && length(vdt_cog_all_na) == 1 &&
    isTRUE(adt_cog_all_na) && !isTRUE(vdt_cog_all_na)) {
  cat("\n*** WARNING: ADT marker parsing / task mapping likely broken.\n")
  cat("    ADT has 0 non-NA cognitive_valid while VDT does not.\n\n")
}

# ----------------------------------------------------------------------------
# Write 8 CSVs
# ----------------------------------------------------------------------------

cat("\nSTEP 5: Writing CSVs...\n")

write_csv(file_provenance, file.path(OUTPUT_DIR, "01_file_provenance.csv"))
write_csv(design_table,    file.path(OUTPUT_DIR, "02_design_expected_vs_observed.csv"))
write_csv(trials_per_subject, file.path(OUTPUT_DIR, "03_trials_per_subject_task_ses.csv"))
write_csv(run_level_counts,   file.path(OUTPUT_DIR, "04_run_level_counts.csv"))
write_csv(window_summary,     file.path(OUTPUT_DIR, "05_window_validity_summary.csv"))
write_csv(gate_rates,         file.path(OUTPUT_DIR, "06_gate_pass_rates_by_threshold.csv"))
write_csv(bias_checks,        file.path(OUTPUT_DIR, "07_bias_checks_key_gates.csv"))
write_csv(prestim_dip,        file.path(OUTPUT_DIR, "08_prestim_dip_summary.csv"))

cat("  ✓ 8 CSVs written to ", OUTPUT_DIR, "\n", sep = "")

# ----------------------------------------------------------------------------
# README_quick_share.md
# ----------------------------------------------------------------------------

cat("\nSTEP 6: Writing README_quick_share.md...\n")

n_subjects <- n_distinct(trial$subject_id)
n_trials_total <- nrow(trial)
n_trials_ch2 <- sum(trial$ch2_primary, na.rm = TRUE)
n_trials_ch3_behav <- sum(trial$ch3_behavior_ready, na.rm = TRUE)
n_trials_ch3_pupil <- sum(trial$ch3_pupil_ready, na.rm = TRUE)

ref_event_statement <- "All windows are computed relative to TRIAL START (trial_start_time_ptb); per-trial TARGET onset markers were not available in flat files."

readme_path <- file.path(OUTPUT_DIR, "README_quick_share.md")

readme <- paste0(
  "# Quick-Share QC Snapshot\n\n",
  "Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n",
  "## Filters Applied\n\n",
  "- **Sessions**: 2–3 only (session 1 excluded)\n",
  "- **Runs**: 1–5 only\n",
  "- **Tasks**: ADT and VDT\n",
  "- **Location**: InsideScanner only (practice/outside-scanner excluded via session/run filters)\n\n",
  "## Top-Line Counts (Trial-Level)\n\n",
  "- **N subjects**: ", n_subjects, "\n",
  "- **N trials (total, pupil trials)**: ", n_trials_total, "\n",
  "- **N trials (CH2 primary usable)**: ", n_trials_ch2, "\n",
  "- **N trials (CH3 behavior-ready)**: ", n_trials_ch3_behav, "\n",
  "- **N trials (CH3 pupil+behavior-ready)**: ", n_trials_ch3_pupil, "\n\n",
  "## Time Reference\n\n",
  "- ", ref_event_statement, "\n\n",
  "## If You Only Read One Thing\n\n",
  "1. **CH2 (pupil) retention**: ", sprintf(\"%.1f%%\", 100 * n_trials_ch2 / max(1, n_trials_total)), 
  " of pupil-present trials pass the primary window gate.\n",
  "2. **CH3 (pupil+behavior) retention**: ", sprintf(\"%.1f%%\", 100 * n_trials_ch3_pupil / max(1, n_trials_total)),
  " of pupil-present trials are behavior-ready AND pass CH2.\n",
  "3. **Design compliance**: see `02_design_expected_vs_observed.csv` for missing runs/trials per subject×task×session.\n",
  "4. **Timebase sanity**: see `04_run_level_counts.csv` for `timebase_issue` and t_rel_trial medians.\n",
  "5. **Prestim diagnostics**: see `08_prestim_dip_summary.csv`; many ADT prestim values may be NA if events are missing.\n",
  "6. **Bias checks**: see `07_bias_checks_key_gates.csv` for gate bias by effort/intensity/session.\n",
  "7. **Window distributions**: see `05_window_validity_summary.csv` for baseline/cognitive/prestim validity summaries.\n",
  "8. **File inventory**: see `01_file_provenance.csv` (includes git hash).\n\n",
  "## Files Generated\n\n",
  "1. `01_file_provenance.csv` – Inputs used, timestamps, git hash\n",
  "2. `02_design_expected_vs_observed.csv` – Expected vs observed runs/trials and window-pass counts\n",
  "3. `03_trials_per_subject_task_ses.csv` – Trial counts and gate counts by subject×task×session\n",
  "4. `04_run_level_counts.csv` – Run-level n_trials, segmentation_source, timebase_issue, t_rel medians\n",
  "5. `05_window_validity_summary.csv` – Baseline/cognitive/prestim validity distributions by task\n",
  "6. `06_gate_pass_rates_by_threshold.csv` – CH2 gate pass rates with both denominators\n",
  "7. `07_bias_checks_key_gates.csv` – Gate bias by effort/intensity/session (if available)\n",
  "8. `08_prestim_dip_summary.csv` – Prestim window depth/status by task\n"
)

writeLines(readme, readme_path)

cat("  ✓ README_quick_share.md written\n\n")
cat("=== QUICK-SHARE QC EXPORT COMPLETE ===\n")


