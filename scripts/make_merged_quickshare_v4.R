#!/usr/bin/env Rscript
# ============================================================================
# Make Merged Trial-Level Dataset + Quick-Share Bundle v4
# ============================================================================
# FIXES: Proper key standardization, merge validation, no double-counting
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(tidyr)
  library(yaml)
  library(here)
  library(broom)
})

cat("=== MAKING MERGED TRIAL-LEVEL + QUICK-SHARE v4 ===\n\n")

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

REPO_ROOT <- here::here()

# Load config
config_file <- file.path(REPO_ROOT, "config", "data_paths.yaml")
if (file.exists(config_file)) {
  config <- read_yaml(config_file)
  PROCESSED_DIR <- config$processed_dir
  BEHAVIORAL_FILE <- config$behavioral_csv
} else {
  PROCESSED_DIR <- Sys.getenv("PUPIL_PROCESSED_DIR")
  BEHAVIORAL_FILE <- Sys.getenv("BEHAVIORAL_CSV")
  if (PROCESSED_DIR == "" || BEHAVIORAL_FILE == "") {
    stop("Please set config/data_paths.yaml or environment variables")
  }
}

OUTPUT_DIR <- file.path(REPO_ROOT, "quick_share_v4")
QUICKSHARE_DIR <- file.path(OUTPUT_DIR, "quick_share")
MERGED_DIR <- file.path(OUTPUT_DIR, "merged")
dir.create(QUICKSHARE_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(MERGED_DIR, recursive = TRUE, showWarnings = FALSE)

cat("Repo root: ", REPO_ROOT, "\n", sep = "")
cat("Processed dir: ", PROCESSED_DIR, "\n", sep = "")
cat("Behavioral file: ", BEHAVIORAL_FILE, "\n", sep = "")
cat("Output dir: ", OUTPUT_DIR, "\n\n", sep = "")

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------

GATE_THRESHOLDS <- c(0.50, 0.60, 0.70)
EXPECTED_TRIALS_PER_RUN <- 30L
TR_SCANNER <- 1.75  # seconds

# ----------------------------------------------------------------------------
# Helper: Standardize subject ID (pad with zeros if needed)
# ----------------------------------------------------------------------------

standardize_sub <- function(x) {
  x <- as.character(x)
  # Extract BAP number
  num <- str_extract(x, "\\d+")
  # Pad to 3 digits (vectorized)
  num_padded <- if_else(is.na(num), NA_character_, 
                       str_pad(num, width = 3, side = "left", pad = "0"))
  if_else(is.na(num_padded), x, paste0("BAP", num_padded))
}

# ----------------------------------------------------------------------------
# STEP A: Load and standardize pupil trial-level data
# ----------------------------------------------------------------------------

cat("STEP A: Loading and standardizing pupil trial-level data...\n")

trial_level_file <- file.path(REPO_ROOT, "derived", "triallevel_qc.csv")
if (!file.exists(trial_level_file)) {
  stop("Trial-level QC file not found: ", trial_level_file, 
       "\nPlease run R/quickshare_build_triallevel.R first.")
}

pupil_raw <- read_csv(trial_level_file, show_col_types = FALSE)
cat("  ✓ Loaded ", nrow(pupil_raw), " pupil trials\n", sep = "")
cat("  Columns: ", paste(names(pupil_raw), collapse = ", "), "\n", sep = "")

# Standardize keys
pupil <- pupil_raw %>%
  mutate(
    # Subject: normalize to "sub" and standardize format
    sub = if ("subject" %in% names(.)) {
      standardize_sub(subject)
    } else if ("sub" %in% names(.)) {
      standardize_sub(sub)
    } else if ("subject_id" %in% names(.)) {
      standardize_sub(subject_id)
    } else {
      stop("Pupil file missing subject column")
    },
    
    # Task: ensure ADT/VDT
    task = as.character(if ("task" %in% names(.)) task else NA_character_),
    
    # Session: normalize to session_used
    session_used = as.integer(if ("session_used" %in% names(.)) session_used else
                             if ("session" %in% names(.)) session else
                             if ("ses" %in% names(.)) ses else NA_integer_),
    
    # Run: normalize to run_used
    run_used = as.integer(if ("run_used" %in% names(.)) run_used else
                         if ("run" %in% names(.)) run else NA_integer_),
    
    # Trial index: normalize to trial_index **within run (1-30)**.
    # IMPORTANT: Prefer trial_in_run_raw (per-run index) over global trial_index.
    trial_index = as.integer(
      if ("trial_in_run_raw" %in% names(.)) {
        trial_in_run_raw
      } else if ("trial_in_run" %in% names(.)) {
        trial_in_run
      } else if ("trial_index" %in% names(.)) {
        trial_index
      } else {
        NA_integer_
      }
    )
  ) %>%
  filter(
    !is.na(sub), !is.na(task), !is.na(session_used), !is.na(run_used), !is.na(trial_index),
    session_used %in% c(2L, 3L),
    task %in% c("ADT", "VDT")
  ) %>%
  # Create trial_uid
  mutate(
    trial_uid = paste(sub, task, session_used, run_used, trial_index, sep = ":")
  )

cat("  ✓ Standardized to ", nrow(pupil), " pupil trials\n", sep = "")

# Validate uniqueness
pupil_dups <- pupil %>%
  group_by(trial_uid) %>%
  summarise(n = n(), .groups = "drop") %>%
  filter(n > 1)

if (nrow(pupil_dups) > 0) {
  stop("CRITICAL: Duplicate trial_uid in pupil data: ", nrow(pupil_dups), " duplicates")
}
cat("  ✓ Pupil trial_uids are unique\n", sep = "")

# ----------------------------------------------------------------------------
# STEP B: Load and standardize behavioral data
# ----------------------------------------------------------------------------

cat("\nSTEP B: Loading and standardizing behavioral data...\n")

if (is.null(BEHAVIORAL_FILE) || BEHAVIORAL_FILE == "" || !file.exists(BEHAVIORAL_FILE)) {
  # Try alternative locations
  candidates <- c(
    file.path(REPO_ROOT, "data", "intermediate", "behavior_TRIALLEVEL_normalized.csv"),
    "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"
  )
  found <- candidates[file.exists(candidates)]
  if (length(found) > 0) {
    BEHAVIORAL_FILE <- found[1]
    cat("  Found behavioral file at: ", BEHAVIORAL_FILE, "\n", sep = "")
  } else {
    stop("Behavioral file not found. Checked:\n",
         paste("  -", c(BEHAVIORAL_FILE, candidates), collapse = "\n"),
         "\nPlease set behavioral_csv in config/data_paths.yaml")
  }
}

beh_raw <- read_csv(BEHAVIORAL_FILE, show_col_types = FALSE)
cat("  ✓ Loaded ", nrow(beh_raw), " behavioral trial rows\n", sep = "")
cat("  Columns: ", paste(names(beh_raw), collapse = ", "), "\n", sep = "")

# Standardize keys and extract behavioral variables
beh <- beh_raw %>%
  mutate(
    # Subject: standardize
    sub = if ("subject_id" %in% names(.)) {
      standardize_sub(subject_id)
    } else if ("sub" %in% names(.)) {
      standardize_sub(sub)
    } else if ("subject" %in% names(.)) {
      standardize_sub(subject)
    } else {
      stop("Behavioral file missing subject column")
    },
    
    # Task: normalize to ADT/VDT
    task = if ("task" %in% names(.)) {
      case_when(
        task == "ADT" ~ "ADT",
        task == "VDT" ~ "VDT",
        task == "aud" ~ "ADT",
        task == "vis" ~ "VDT",
        TRUE ~ as.character(task)
      )
    } else if ("task_modality" %in% names(.)) {
      case_when(
        task_modality == "aud" ~ "ADT",
        task_modality == "vis" ~ "VDT",
        TRUE ~ as.character(task_modality)
      )
    } else NA_character_,
    
    # Session: normalize to session_used
    session_used = as.integer(if ("session_used" %in% names(.)) session_used else
                             if ("session" %in% names(.)) session else
                             if ("session_num" %in% names(.)) session_num else
                             if ("ses" %in% names(.)) ses else NA_integer_),
    
    # Run: normalize to run_used
    run_used = as.integer(if ("run_used" %in% names(.)) run_used else
                         if ("run" %in% names(.)) run else
                         if ("run_num" %in% names(.)) run_num else NA_integer_),
    
    # Trial index: normalize to trial_index (within run)
    trial_index = as.integer(if ("trial_index" %in% names(.)) trial_index else
                           if ("trial_in_run" %in% names(.)) trial_in_run else
                           if ("trial_num" %in% names(.)) trial_num else
                           if ("trial" %in% names(.)) trial else NA_integer_),
    
    # Behavioral variables
    rt = if ("rt" %in% names(.)) rt else
         if ("same_diff_resp_secs" %in% names(.)) same_diff_resp_secs else
         if ("resp1RT" %in% names(.)) resp1RT else NA_real_,
    
    choice = if ("choice" %in% names(.)) choice else
             if ("resp_is_diff" %in% names(.)) resp_is_diff else
             if ("resp1" %in% names(.)) resp1 else NA_integer_,
    
    correct = if ("correct" %in% names(.)) correct else
              if ("resp_is_correct" %in% names(.)) as.integer(resp_is_correct) else
              if ("iscorr" %in% names(.)) iscorr else NA_integer_,
    
    stimulus_intensity = if ("stimulus_intensity" %in% names(.)) stimulus_intensity else
                        if ("intensity" %in% names(.)) intensity else
                        if ("stimLev" %in% names(.)) stimLev else
                        if ("stim_level_index" %in% names(.)) stim_level_index else NA_real_,
    
    effort = if ("effort" %in% names(.)) effort else
             if ("grip_targ_prop_mvc" %in% names(.)) {
               case_when(
                 grip_targ_prop_mvc == 0.05 ~ "Low",
                 grip_targ_prop_mvc == 0.40 ~ "High",
                 TRUE ~ NA_character_
               )
             } else if ("gf_trPer" %in% names(.)) {
               case_when(
                 gf_trPer == 0.05 ~ "Low",
                 gf_trPer == 0.40 ~ "High",
                 TRUE ~ NA_character_
               )
             } else NA_character_,
    
    isOddball = if ("isOddball" %in% names(.)) isOddball else
                if ("stim_is_diff" %in% names(.)) as.integer(stim_is_diff) else NA_integer_
  ) %>%
  filter(
    !is.na(sub), !is.na(task), !is.na(session_used), !is.na(run_used), !is.na(trial_index),
    session_used %in% c(2L, 3L),
    task %in% c("ADT", "VDT")
  ) %>%
  # Create trial_uid
  mutate(
    trial_uid = paste(sub, task, session_used, run_used, trial_index, sep = ":")
  )

# Check for duplicates
beh_dups <- beh %>%
  group_by(trial_uid) %>%
  summarise(n = n(), .groups = "drop") %>%
  filter(n > 1)

if (nrow(beh_dups) > 0) {
  cat("  ⚠ Warning: ", nrow(beh_dups), " duplicate trial_uids in behavioral data\n", sep = "")
  cat("    Taking first occurrence for each duplicate\n", sep = "")
  beh <- beh %>%
    group_by(trial_uid) %>%
    slice(1) %>%
    ungroup()
}

cat("  ✓ Standardized to ", nrow(beh), " behavioral trials\n", sep = "")
cat("  ✓ Behavioral trial_uids are unique\n", sep = "")

# ----------------------------------------------------------------------------
# STEP C: Merge pupil + behavioral
# ----------------------------------------------------------------------------

cat("\nSTEP C: Merging pupil + behavioral data...\n")

# Drop any placeholder behavioral columns from pupil data
pupil_clean <- pupil %>%
  select(-any_of(c("rt", "choice", "correct", "stimulus_intensity", "effort", 
                   "isOddball", "has_behavioral_data")))

# Merge
merged <- pupil_clean %>%
  left_join(
    beh %>% select(trial_uid, rt, choice, correct, stimulus_intensity, effort, isOddball),
    by = "trial_uid"
  ) %>%
  mutate(
    has_behavioral_data = !is.na(rt) & !is.na(choice)
  )

cat("  ✓ Merged ", nrow(merged), " trials\n", sep = "")

# ----------------------------------------------------------------------------
# STEP D: Validation checks
# ----------------------------------------------------------------------------

cat("\nSTEP D: Running validation checks...\n")

# 1) Coverage
coverage <- merged %>%
  summarise(
    n_total = n(),
    n_with_beh = sum(has_behavioral_data, na.rm = TRUE),
    pct_with_beh = 100 * n_with_beh / n_total
  )

cat("  1) Coverage:\n", sep = "")
cat("     Total trials: ", coverage$n_total, "\n", sep = "")
cat("     With behavioral: ", coverage$n_with_beh, " (", 
    sprintf("%.1f", coverage$pct_with_beh), "%)\n", sep = "")

coverage_by_task <- merged %>%
  group_by(task) %>%
  summarise(
    n_total = n(),
    n_with_beh = sum(has_behavioral_data, na.rm = TRUE),
    pct_with_beh = 100 * n_with_beh / n_total,
    .groups = "drop"
  )

cat("     By task:\n", sep = "")
for (i in 1:nrow(coverage_by_task)) {
  cat("       ", coverage_by_task$task[i], ": ", coverage_by_task$n_with_beh[i], 
      " / ", coverage_by_task$n_total[i], " (", 
      sprintf("%.1f", coverage_by_task$pct_with_beh[i]), "%)\n", sep = "")
}

# 2) Key uniqueness
pupil_uids <- n_distinct(pupil$trial_uid)
beh_uids <- n_distinct(beh$trial_uid)
merged_uids <- n_distinct(merged$trial_uid)

cat("  2) Key uniqueness:\n", sep = "")
cat("     Pupil unique trial_uids: ", pupil_uids, "\n", sep = "")
cat("     Behavioral unique trial_uids: ", beh_uids, "\n", sep = "")
cat("     Merged unique trial_uids: ", merged_uids, "\n", sep = "")

if (merged_uids != nrow(merged)) {
  stop("CRITICAL: Merged dataset has duplicate trial_uids!")
}

# 3) Run integrity
run_counts <- merged %>%
  group_by(sub, task, session_used, run_used) %>%
  summarise(n_trials = n_distinct(trial_uid), .groups = "drop")

run_summary <- run_counts %>%
  summarise(
    mean_trials = mean(n_trials, na.rm = TRUE),
    median_trials = median(n_trials, na.rm = TRUE),
    min_trials = min(n_trials, na.rm = TRUE),
    max_trials = max(n_trials, na.rm = TRUE),
    n_runs = n()
  )

cat("  3) Run integrity:\n", sep = "")
cat("     Mean trials per run: ", sprintf("%.1f", run_summary$mean_trials), "\n", sep = "")
cat("     Median trials per run: ", run_summary$median_trials, "\n", sep = "")
cat("     Range: [", run_summary$min_trials, ", ", run_summary$max_trials, "]\n", sep = "")
cat("     Total runs: ", run_summary$n_runs, "\n", sep = "")

if (run_summary$median_trials < 25 || run_summary$median_trials > 35) {
  cat("     ⚠ Warning: Median trials per run is unusual (expected ~30)\n", sep = "")
}

# 4) Spot-check unmatched
unmatched_sample <- merged %>%
  filter(!has_behavioral_data) %>%
  select(trial_uid, sub, task, session_used, run_used, trial_index) %>%
  head(20)

cat("  4) Spot-check unmatched trials (first 20):\n", sep = "")
if (nrow(unmatched_sample) > 0) {
  print(unmatched_sample)
} else {
  cat("     (All trials matched!)\n", sep = "")
}

# 5) Spot-check matched
matched_sample <- merged %>%
  filter(has_behavioral_data) %>%
  select(trial_uid, sub, task, session_used, run_used, trial_index, 
         rt, choice, correct, stimulus_intensity, effort) %>%
  head(20)

cat("  5) Spot-check matched trials (first 20):\n", sep = "")
if (nrow(matched_sample) > 0) {
  print(matched_sample)
} else {
  stop("CRITICAL: No trials matched! Merge failed completely.")
}

# Convert quality columns if needed
merged <- merged %>%
  mutate(
    baseline_quality = if ("pct_non_nan_baseline" %in% names(.)) pct_non_nan_baseline / 100 else NA_real_,
    cog_quality = if ("pct_non_nan_cogwin" %in% names(.)) pct_non_nan_cogwin / 100 else NA_real_,
    overall_quality = if ("pct_non_nan_overall" %in% names(.)) pct_non_nan_overall / 100 else NA_real_
  )

# ----------------------------------------------------------------------------
# STEP E: Generate quick-share CSVs
# ----------------------------------------------------------------------------

cat("\nSTEP E: Generating quick-share CSVs...\n")

# 01_merge_diagnostics.csv
merge_diagnostics <- merged %>%
  group_by(task) %>%
  summarise(
    n_pupil_trials = n_distinct(trial_uid),
    n_matched = sum(has_behavioral_data, na.rm = TRUE),
    match_rate_pct = 100 * n_matched / n_distinct(trial_uid),
    .groups = "drop"
  ) %>%
  bind_rows(
    merged %>%
      summarise(
        task = "ALL",
        n_pupil_trials = n_distinct(trial_uid),
        n_matched = sum(has_behavioral_data, na.rm = TRUE),
        match_rate_pct = 100 * n_matched / n_distinct(trial_uid)
      )
  )

# Unmatched samples
unmatched_pupil <- merged %>%
  filter(!has_behavioral_data) %>%
  select(trial_uid) %>%
  distinct() %>%
  head(20)

unmatched_beh <- beh %>%
  anti_join(merged %>% filter(has_behavioral_data), by = "trial_uid") %>%
  select(trial_uid) %>%
  distinct() %>%
  head(20)

unmatched_pupil_str <- if (nrow(unmatched_pupil) > 0) {
  paste(unmatched_pupil$trial_uid, collapse = "; ")
} else NA_character_

unmatched_beh_str <- if (nrow(unmatched_beh) > 0) {
  paste(unmatched_beh$trial_uid, collapse = "; ")
} else NA_character_

merge_diagnostics_full <- merge_diagnostics %>%
  mutate(
    n_unmatched_pupil = if_else(task == "ALL", as.integer(nrow(unmatched_pupil)), NA_integer_),
    n_unmatched_beh = if_else(task == "ALL", as.integer(nrow(unmatched_beh)), NA_integer_),
    unmatched_pupil_sample = if_else(task == "ALL", unmatched_pupil_str, NA_character_),
    unmatched_beh_sample = if_else(task == "ALL", unmatched_beh_str, NA_character_)
  )

write_csv(merge_diagnostics_full, file.path(QUICKSHARE_DIR, "01_merge_diagnostics.csv"))
cat("  ✓ 01_merge_diagnostics.csv\n")

# 02_trials_per_subject_task_ses.csv
trials_per_subject <- merged %>%
  group_by(sub, task, session_used) %>%
  summarise(
    n_runs = n_distinct(run_used),
    n_trials = n_distinct(trial_uid),
    n_trials_with_behavior = sum(has_behavioral_data, na.rm = TRUE),
    expected_runs = 5L,
    missing_runs = pmax(0L, expected_runs - n_runs),
    .groups = "drop"
  )

write_csv(trials_per_subject, file.path(QUICKSHARE_DIR, "02_trials_per_subject_task_ses.csv"))
cat("  ✓ 02_trials_per_subject_task_ses.csv\n")

# 03_condition_cell_counts.csv
condition_counts <- merged %>%
  filter(has_behavioral_data) %>%
  group_by(sub, task, effort, stimulus_intensity) %>%
  summarise(
    n_trials_total = n_distinct(trial_uid),
    n_trials_valid_primary = sum(
      !is.na(baseline_quality) & baseline_quality >= 0.60 &
      !is.na(cog_quality) & cog_quality >= 0.60,
      na.rm = TRUE
    ),
    n_trials_valid_lenient = sum(
      !is.na(baseline_quality) & baseline_quality >= 0.50 &
      !is.na(cog_quality) & cog_quality >= 0.50,
      na.rm = TRUE
    ),
    n_trials_valid_strict = sum(
      !is.na(baseline_quality) & baseline_quality >= 0.70 &
      !is.na(cog_quality) & cog_quality >= 0.70,
      na.rm = TRUE
    ),
    .groups = "drop"
  )

write_csv(condition_counts, file.path(QUICKSHARE_DIR, "03_condition_cell_counts.csv"))
cat("  ✓ 03_condition_cell_counts.csv\n")

# 04_run_level_counts.csv
run_level <- merged %>%
  group_by(sub, task, session_used, run_used) %>%
  summarise(
    n_trials = n_distinct(trial_uid),
    n_trials_with_behavior = sum(has_behavioral_data, na.rm = TRUE),
    mean_baseline_quality = mean(baseline_quality, na.rm = TRUE),
    mean_cog_quality = mean(cog_quality, na.rm = TRUE),
    mean_overall_quality = mean(overall_quality, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(run_level, file.path(QUICKSHARE_DIR, "04_run_level_counts.csv"))
cat("  ✓ 04_run_level_counts.csv\n")

# 05_window_validity_summary.csv
window_summary <- merged %>%
  filter(has_behavioral_data) %>%
  mutate(effort_group = if_else(is.na(effort), "Unknown", effort)) %>%
  group_by(task, effort_group) %>%
  summarise(
    n_trials = n_distinct(trial_uid),
    baseline_mean = mean(baseline_quality, na.rm = TRUE),
    baseline_median = median(baseline_quality, na.rm = TRUE),
    cog_mean = mean(cog_quality, na.rm = TRUE),
    cog_median = median(cog_quality, na.rm = TRUE),
    overall_mean = mean(overall_quality, na.rm = TRUE),
    overall_median = median(overall_quality, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  rename(effort = effort_group)

write_csv(window_summary, file.path(QUICKSHARE_DIR, "05_window_validity_summary.csv"))
cat("  ✓ 05_window_validity_summary.csv\n")

# 06_gate_pass_rates_by_threshold.csv
gate_rates <- map_dfr(GATE_THRESHOLDS, function(th) {
  merged %>%
    filter(has_behavioral_data) %>%
    mutate(
      baseline_ok = !is.na(baseline_quality) & baseline_quality >= th,
      cog_ok = !is.na(cog_quality) & cog_quality >= th
    ) %>%
    group_by(task) %>%
    summarise(
      threshold = th,
      n_trials_total = n_distinct(trial_uid),
      n_trials_pass = sum(baseline_ok & cog_ok, na.rm = TRUE),
      pass_rate = n_trials_pass / n_trials_total,
      pass_rate_pct = 100 * pass_rate,
      .groups = "drop"
    )
})

write_csv(gate_rates, file.path(QUICKSHARE_DIR, "06_gate_pass_rates_by_threshold.csv"))
cat("  ✓ 06_gate_pass_rates_by_threshold.csv\n")

# 07_bias_checks_key_gates.csv
bias_checks_list <- list()

for (th in GATE_THRESHOLDS) {
  pass_col <- paste0("pass_primary_", sprintf("%03d", as.integer(th * 100)))
  merged[[pass_col]] <- 
    !is.na(merged$baseline_quality) & merged$baseline_quality >= th &
    !is.na(merged$cog_quality) & merged$cog_quality >= th &
    merged$has_behavioral_data
  
  # Stratified by effort
  if (any(!is.na(merged$effort))) {
    effort_strat <- merged %>%
      filter(!is.na(effort), has_behavioral_data) %>%
      group_by(effort) %>%
      summarise(
        threshold = th,
        factor = "effort",
        level = first(effort),
        n_total = n_distinct(trial_uid),
        n_pass = sum(.data[[pass_col]], na.rm = TRUE),
        pass_rate = n_pass / n_total,
        .groups = "drop"
      )
    bias_checks_list[[length(bias_checks_list) + 1]] <- effort_strat
  }
  
  # Stratified by task
  task_strat <- merged %>%
    filter(has_behavioral_data) %>%
    group_by(task) %>%
    summarise(
      threshold = th,
      factor = "task",
      level = first(task),
      n_total = n_distinct(trial_uid),
      n_pass = sum(.data[[pass_col]], na.rm = TRUE),
      pass_rate = n_pass / n_total,
      .groups = "drop"
    )
  bias_checks_list[[length(bias_checks_list) + 1]] <- task_strat
}

if (length(bias_checks_list) > 0) {
  bias_checks <- bind_rows(bias_checks_list)
} else {
  bias_checks <- tibble(
    threshold = numeric(),
    factor = character(),
    level = character(),
    n_total = integer(),
    n_pass = integer(),
    pass_rate = numeric()
  )
}

write_csv(bias_checks, file.path(QUICKSHARE_DIR, "07_bias_checks_key_gates.csv"))
cat("  ✓ 07_bias_checks_key_gates.csv\n")

# 08_trial_level_for_jitter.csv (simplified - no time columns available)
jitter_data <- merged %>%
  select(trial_uid, sub, task, session_used, run_used, trial_index) %>%
  arrange(sub, task, session_used, run_used, trial_index) %>%
  group_by(sub, task, session_used, run_used) %>%
  mutate(
    trial_seq = row_number(),
    note = "Time columns not available in trial-level data"
  ) %>%
  ungroup()

write_csv(jitter_data, file.path(QUICKSHARE_DIR, "08_trial_level_for_jitter.csv"))
cat("  ✓ 08_trial_level_for_jitter.csv\n")

# ----------------------------------------------------------------------------
# STEP F: Save merged dataset
# ----------------------------------------------------------------------------

cat("\nSTEP F: Saving merged trial-level dataset...\n")

# Create gate pass flags
for (th in GATE_THRESHOLDS) {
  pass_col <- paste0("pass_primary_", sprintf("%03d", as.integer(th * 100)))
  merged[[pass_col]] <- 
    !is.na(merged$baseline_quality) & merged$baseline_quality >= th &
    !is.na(merged$cog_quality) & merged$cog_quality >= th &
    merged$has_behavioral_data
}

# ----------------------------------------------------------------------------
# STEP G: Derive behavioral columns and compute correctness
# ----------------------------------------------------------------------------

cat("\nSTEP G: Deriving behavioral columns and computing correctness...\n")

# Ensure stimulus_intensity is numeric
merged <- merged %>%
  mutate(
    stimulus_intensity = as.numeric(stimulus_intensity)
  )

# Derive isOddball from stimulus_intensity (intensity != 0 means oddball)
merged <- merged %>%
  mutate(
    isOddball = if_else(is.na(stimulus_intensity), NA_integer_, 
                       as.integer(stimulus_intensity != 0))
  )

# Standardize choice to numeric and label
merged <- merged %>%
  mutate(
    choice_num = case_when(
      is.na(choice) ~ NA_integer_,
      is.logical(choice) ~ as.integer(choice),
      is.numeric(choice) ~ as.integer(choice),
      TRUE ~ NA_integer_
    ),
    choice_label = case_when(
      is.na(choice_num) ~ NA_character_,
      choice_num == 0 ~ "SAME",
      choice_num == 1 ~ "DIFFERENT",
      TRUE ~ NA_character_
    )
  )

# Compute correct_calc from choice_num and isOddball
merged <- merged %>%
  mutate(
    correct_calc = case_when(
      is.na(choice_num) | is.na(isOddball) ~ NA_integer_,
      TRUE ~ as.integer(choice_num == isOddball)
    )
  )

# Preserve legacy correct column (don't overwrite)
# Create correct_final using correct_calc
merged <- merged %>%
  mutate(
    correct_final = correct_calc
  )

cat("  ✓ Derived isOddball from stimulus_intensity\n", sep = "")
cat("  ✓ Created choice_num and choice_label\n", sep = "")
cat("  ✓ Computed correct_calc and correct_final\n", sep = "")

# Unit check: isOddball NA rate should match stimulus_intensity NA rate
isOddball_na_rate <- mean(is.na(merged$isOddball), na.rm = TRUE)
intensity_na_rate <- mean(is.na(merged$stimulus_intensity), na.rm = TRUE)

cat("\n  Unit check - NA rates:\n", sep = "")
cat("    isOddball NA rate: ", sprintf("%.3f", isOddball_na_rate), "\n", sep = "")
cat("    stimulus_intensity NA rate: ", sprintf("%.3f", intensity_na_rate), "\n", sep = "")

if (abs(isOddball_na_rate - intensity_na_rate) > 0.001) {
  cat("    ⚠ Warning: NA rates don't match exactly\n", sep = "")
}

# ----------------------------------------------------------------------------
# STEP H: Run-level QC for correctness agreement
# ----------------------------------------------------------------------------

cat("\nSTEP H: Computing run-level correctness QC...\n")

QC_DIR <- file.path(OUTPUT_DIR, "qc")
dir.create(QC_DIR, recursive = TRUE, showWarnings = FALSE)

# Run-level correctness agreement
run_correctness <- merged %>%
  filter(has_behavioral_data) %>%
  group_by(sub, task, session_used, run_used) %>%
  summarise(
    n_trials = n_distinct(trial_uid),
    n_with_behavior = sum(!is.na(choice_num), na.rm = TRUE),
    agree_correct = mean(as.integer(correct) == correct_calc, na.rm = TRUE),
    acc_correct_calc = mean(correct_calc, na.rm = TRUE),
    acc_correct_legacy = mean(as.integer(correct), na.rm = TRUE),
    .groups = "drop"
  )

write_csv(run_correctness, file.path(QC_DIR, "qc_run_correctness_agreement.csv"))
cat("  ✓ Saved: qc/qc_run_correctness_agreement.csv\n", sep = "")

# Agreement distribution summary
agree_summary <- run_correctness %>%
  filter(!is.na(agree_correct)) %>%
  summarise(
    min_agree = min(agree_correct, na.rm = TRUE),
    median_agree = median(agree_correct, na.rm = TRUE),
    max_agree = max(agree_correct, na.rm = TRUE),
    mean_agree = mean(agree_correct, na.rm = TRUE),
    n_runs = n()
  )

cat("\n  Agreement distribution:\n", sep = "")
cat("    Min: ", sprintf("%.3f", agree_summary$min_agree), "\n", sep = "")
cat("    Median: ", sprintf("%.3f", agree_summary$median_agree), "\n", sep = "")
cat("    Max: ", sprintf("%.3f", agree_summary$max_agree), "\n", sep = "")
cat("    Mean: ", sprintf("%.3f", agree_summary$mean_agree), "\n", sep = "")
cat("    Runs with data: ", agree_summary$n_runs, "\n", sep = "")

# Flag bad runs (agree_correct < 0.90 or NA)
bad_runs <- run_correctness %>%
  filter(is.na(agree_correct) | agree_correct < 0.90) %>%
  arrange(sub, task, session_used, run_used)

write_csv(bad_runs, file.path(QC_DIR, "qc_runs_flagged_correctness.csv"))
cat("  ✓ Saved: qc/qc_runs_flagged_correctness.csv\n", sep = "")
cat("    Flagged runs: ", nrow(bad_runs), "\n", sep = "")

# Select final columns for merged dataset
merged_final <- merged %>%
  select(
    # Trial identity
    trial_uid, sub, task, session_used, run_used, trial_index,
    
    # Behavioral (original)
    rt, choice, correct, stimulus_intensity, effort,
    has_behavioral_data,
    
    # Behavioral (derived)
    isOddball, choice_num, choice_label, correct_calc, correct_final,
    
    # Pupil QC
    baseline_quality, cog_quality, overall_quality,
    any_of(c("pct_non_nan_baseline", "pct_non_nan_cogwin", "pct_non_nan_overall")),
    
    # Gate pass flags
    starts_with("pass_primary_"),
    
    # QC flags
    any_of(c("window_oob_any", "all_nan_any", "any_timebase_bug", "target_onset_found"))
  )

merged_output <- file.path(MERGED_DIR, "BAP_triallevel_merged_v2.csv")
write_csv(merged_final, merged_output)
cat("  ✓ Saved: ", merged_output, "\n", sep = "")

# Final validation
cat("\n=== FINAL VALIDATION ===\n")
cat("Total trials: ", nrow(merged_final), "\n", sep = "")
cat("Trials with behavioral: ", sum(merged_final$has_behavioral_data, na.rm = TRUE), "\n", sep = "")
cat("Trials with rt: ", sum(!is.na(merged_final$rt), na.rm = TRUE), "\n", sep = "")
cat("Trials with choice: ", sum(!is.na(merged_final$choice), na.rm = TRUE), "\n", sep = "")
cat("Trials with intensity: ", sum(!is.na(merged_final$stimulus_intensity), na.rm = TRUE), "\n", sep = "")
cat("Trials with effort: ", sum(!is.na(merged_final$effort), na.rm = TRUE), "\n", sep = "")
cat("Trials with isOddball: ", sum(!is.na(merged_final$isOddball), na.rm = TRUE), "\n", sep = "")
cat("Trials with correct_final: ", sum(!is.na(merged_final$correct_final), na.rm = TRUE), "\n", sep = "")

if (all(is.na(merged_final$rt)) && all(is.na(merged_final$choice))) {
  stop("CRITICAL ERROR: All behavioral columns are NA. Merge failed.")
}

cat("\n=== COMPLETE ===\n")
cat("Quick-share CSVs saved to: ", QUICKSHARE_DIR, "\n", sep = "")
cat("Merged dataset saved to: ", merged_output, "\n", sep = "")

