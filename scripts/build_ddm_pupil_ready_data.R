#!/usr/bin/env Rscript
# ==============================================================================
# Build DDM-Pupil Ready Data
# ==============================================================================
# Purpose: Join pupil trial features to DDM-ready behavioral data and create
#          thresholded datasets for pupil-DDM modeling.
#
# Inputs:  - data/ddm_ready_data_unthresholded.csv (behavioral DDM data)
#          - output/pupil/pupil_trial_features.csv (pupil features)
#
# Outputs: - output/ddm_pupil/ddm_pupil_ready_thr0.15_probe_onset_locked.csv
#          - output/ddm_pupil/ddm_pupil_ready_thr0.20_probe_onset_locked.csv
#          - output/ddm_pupil/ddm_pupil_ready_thr0.25_probe_onset_locked.csv
#          - output/ddm_pupil/build_ddm_pupil_ready_data.log
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(here)
  library(stringr)
})

# ==============================================================================
# Setup logging
# ==============================================================================

SCRIPT_NAME <- "build_ddm_pupil_ready_data.R"
START_TIME <- Sys.time()

# Create output directory
OUTPUT_DIR <- here::here("output", "ddm_pupil")
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Open log file
LOG_FILE <- file.path(OUTPUT_DIR, "build_ddm_pupil_ready_data.log")
log_con <- file(LOG_FILE, open = "wt")

log_msg <- function(..., level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  msg <- paste(..., collapse = " ")
  log_line <- sprintf("[%s] [%s] %s", timestamp, level, msg)
  
  # Write to console
  cat(log_line, "\n")
  
  # Write to log file
  cat(log_line, "\n", file = log_con)
  flush(log_con)
}

log_msg(strrep("=", 80))
log_msg("BUILD DDM-PUPIL READY DATA")
log_msg(strrep("=", 80))
log_msg("Script:", SCRIPT_NAME)
log_msg("Start time:", format(START_TIME, "%Y-%m-%d %H:%M:%S"))
log_msg("Output directory:", OUTPUT_DIR)
log_msg("")

# ==============================================================================
# Step 1: Load input data
# ==============================================================================

log_msg("STEP 1: Loading input data...")

# Load DDM-ready data (unthresholded)
DDM_FILE_PATHS <- c(
  here::here("data", "ddm_ready_data_unthresholded.csv"),
  here::here("output", "rt_threshold_analysis", "ddm_ready_data_unthresholded.csv")
)

ddm_data <- NULL
ddm_file_used <- NULL

for (path in DDM_FILE_PATHS) {
  if (file.exists(path)) {
    log_msg("  Found DDM data:", path)
    ddm_data <- read_csv(path, show_col_types = FALSE)
    ddm_file_used <- path
    break
  }
}

if (is.null(ddm_data)) {
  log_msg("ERROR: DDM data file not found. Tried:", level = "ERROR")
  for (path in DDM_FILE_PATHS) {
    log_msg("  -", path, level = "ERROR")
  }
  close(log_con)
  stop("DDM data file not found")
}

log_msg("  ✓ Loaded DDM data:", nrow(ddm_data), "rows")
log_msg("  ✓ Columns:", ncol(ddm_data))

# Load pupil features
PUPIL_FILE <- here::here("output", "pupil", "pupil_trial_features.csv")

if (!file.exists(PUPIL_FILE)) {
  log_msg("ERROR: Pupil features file not found:", PUPIL_FILE, level = "ERROR")
  close(log_con)
  stop("Pupil features file not found: ", PUPIL_FILE)
}

pupil_data <- read_csv(PUPIL_FILE, show_col_types = FALSE)
log_msg("  ✓ Loaded pupil data:", nrow(pupil_data), "rows")
log_msg("  ✓ Columns:", ncol(pupil_data))
log_msg("")

# ==============================================================================
# Step 2: Prepare data for joining
# ==============================================================================

log_msg("STEP 2: Preparing data for joining...")

# Standardize task names in DDM data (aud -> ADT, vis -> VDT)
log_msg("  Standardizing task names...")
ddm_data <- ddm_data %>%
  mutate(
    task_std = case_when(
      tolower(task) == "aud" ~ "ADT",
      tolower(task) == "vis" ~ "VDT",
      TRUE ~ task
    )
  )

log_msg("    Task mapping:")
task_mapping <- ddm_data %>%
  distinct(task, task_std) %>%
  arrange(task)
for (i in 1:nrow(task_mapping)) {
  log_msg(sprintf("      %s -> %s", task_mapping$task[i], task_mapping$task_std[i]))
}

# Extract trial_index from pupil trial_id (format: sub:task:session:run:trial_index)
log_msg("  Extracting trial_index from pupil trial_id...")
pupil_data <- pupil_data %>%
  mutate(
    trial_index_from_uid = as.integer(str_split_fixed(trial_id, ":", 5)[, 5])
  )

log_msg("    ✓ Extracted trial_index from", nrow(pupil_data), "pupil trials")
log_msg("    Example trial_id:", pupil_data$trial_id[1])
log_msg("    Extracted trial_index:", pupil_data$trial_index_from_uid[1])

# Check for NA trial_index
n_na_trial_index <- sum(is.na(pupil_data$trial_index_from_uid))
if (n_na_trial_index > 0) {
  log_msg("    WARNING:", n_na_trial_index, "pupil trials have NA trial_index", level = "WARN")
}

log_msg("")

# ==============================================================================
# Step 3: Join pupil features to DDM data
# ==============================================================================

log_msg("STEP 3: Joining pupil features to DDM data...")

# Join strategy: subject_id + task + trial_num
# Note: Pupil data has session/run info that DDM data doesn't have, so trial_index
# repeats across sessions. We need to aggregate pupil data first or use first match.

log_msg("  Join keys: subject_id + task_std + trial_num")
log_msg("  Pupil side: subject_id + task + trial_index_from_uid")
log_msg("")

# Check for many-to-many matches
pupil_counts <- pupil_data %>%
  group_by(subject_id, task, trial_index_from_uid) %>%
  summarise(n_pupil = n(), .groups = "drop")

many_to_many <- pupil_counts %>%
  filter(n_pupil > 1)

if (nrow(many_to_many) > 0) {
  log_msg("  WARNING: Found", nrow(many_to_many), "subject+task+trial combinations with multiple pupil records", level = "WARN")
  log_msg("  This is expected due to session/run structure in pupil data", level = "WARN")
  log_msg("  Strategy: Aggregate pupil features by taking mean across sessions/runs", level = "WARN")
  log_msg("")
  
  # Aggregate pupil data: take mean of pupil metrics across sessions/runs
  pupil_agg <- pupil_data %>%
    group_by(subject_id, task, trial_index_from_uid) %>%
    summarise(
      # Take first non-NA value for categorical variables
      effort_condition_pupil = first(na.omit(effort_condition)),
      difficulty_pupil = first(na.omit(difficulty)),
      
      # Average pupil metrics across sessions/runs
      pupil_tonic = mean(pupil_tonic, na.rm = TRUE),
      pupil_phasic = mean(pupil_phasic, na.rm = TRUE),
      pupil_metric_primary = mean(pupil_metric_primary, na.rm = TRUE),
      pupil_metric_primary_z = mean(pupil_metric_primary_z, na.rm = TRUE),
      pupil_w1p3 = mean(pupil_w1p3, na.rm = TRUE),
      pupil_w1p3_z = mean(pupil_w1p3_z, na.rm = TRUE),
      
      # Logical: TRUE if ANY session/run is missing
      pupil_missing = any(pupil_missing, na.rm = TRUE),
      pupil_qc_exclude = any(pupil_qc_exclude, na.rm = TRUE),
      
      # Concatenate QC reasons
      pupil_qc_reason = paste(unique(pupil_qc_reason[pupil_qc_reason != ""]), collapse = "; "),
      
      # Keep track of how many sessions/runs contributed
      n_pupil_sessions = n(),
      
      .groups = "drop"
    )
  
  log_msg("  ✓ Aggregated pupil data:")
  log_msg("    Before:", nrow(pupil_data), "rows")
  log_msg("    After:", nrow(pupil_agg), "rows")
  log_msg("    Unique subject+task+trial combinations:", nrow(pupil_agg))
  
  pupil_for_join <- pupil_agg
} else {
  log_msg("  ✓ No many-to-many matches found")
  pupil_for_join <- pupil_data %>%
    mutate(n_pupil_sessions = 1)
}

log_msg("")

# Perform left join (keep all DDM trials, add pupil where available)
ddm_pupil <- ddm_data %>%
  left_join(
    pupil_for_join,
    by = c("subject_id" = "subject_id", 
           "task_std" = "task", 
           "trial_num" = "trial_index_from_uid"),
    suffix = c("_ddm", "_pupil")
  )

log_msg("  ✓ Join completed")
log_msg("  Rows after join:", nrow(ddm_pupil))

# Check for duplicates created by join
n_dups <- nrow(ddm_pupil) - nrow(ddm_data)
if (n_dups > 0) {
  log_msg("  ERROR: Join created", n_dups, "duplicate rows!", level = "ERROR")
  log_msg("  This suggests multiple pupil trials matched to the same DDM trial", level = "ERROR")
  
  # Identify duplicates
  dups <- ddm_pupil %>%
    group_by(subject_id, trial_num, task_std) %>%
    filter(n() > 1) %>%
    arrange(subject_id, trial_num)
  
  log_msg("  First 10 duplicate keys:", level = "ERROR")
  for (i in 1:min(10, nrow(dups))) {
    log_msg(sprintf("    %s, trial %d, task %s", 
                    dups$subject_id[i], dups$trial_num[i], dups$task_std[i]), 
            level = "ERROR")
  }
  
  close(log_con)
  stop("Join created duplicates - check join keys")
} else {
  log_msg("  ✓ No duplicates created by join")
}

log_msg("")

# ==============================================================================
# Step 4: Compute merge success metrics
# ==============================================================================

log_msg("STEP 4: Computing merge success metrics...")

# Overall match rate
n_total <- nrow(ddm_pupil)
n_matched <- sum(!is.na(ddm_pupil$pupil_metric_primary))
pct_matched <- 100 * n_matched / n_total

log_msg("  Overall merge success:")
log_msg(sprintf("    Total DDM trials: %d", n_total))
log_msg(sprintf("    Matched with pupil: %d (%.1f%%)", n_matched, pct_matched))
log_msg(sprintf("    Unmatched: %d (%.1f%%)", n_total - n_matched, 100 - pct_matched))
log_msg("")

# Match rate by subject
log_msg("  Match rate by subject:")
match_by_subj <- ddm_pupil %>%
  group_by(subject_id) %>%
  summarise(
    n_trials = n(),
    n_matched = sum(!is.na(pupil_metric_primary)),
    pct_matched = 100 * n_matched / n_trials,
    .groups = "drop"
  ) %>%
  arrange(pct_matched)

log_msg(sprintf("    Mean match rate: %.1f%%", mean(match_by_subj$pct_matched)))
log_msg(sprintf("    Median match rate: %.1f%%", median(match_by_subj$pct_matched)))
log_msg("")

# Subjects with <90% matched
low_match_subj <- match_by_subj %>%
  filter(pct_matched < 90)

if (nrow(low_match_subj) > 0) {
  log_msg("  Subjects with <90% match rate:")
  for (i in 1:nrow(low_match_subj)) {
    log_msg(sprintf("    %s: %d/%d matched (%.1f%%)", 
                    low_match_subj$subject_id[i], 
                    low_match_subj$n_matched[i], 
                    low_match_subj$n_trials[i], 
                    low_match_subj$pct_matched[i]))
  }
} else {
  log_msg("  ✓ All subjects have >=90% match rate")
}

log_msg("")

# ==============================================================================
# Step 5: Select RT definition (probe-onset-locked)
# ==============================================================================

log_msg("STEP 5: Selecting RT definition...")

# Check available RT columns
rt_cols <- grep("^rt", names(ddm_pupil), value = TRUE)
log_msg("  Available RT columns:")
for (col in rt_cols) {
  log_msg("    -", col)
}
log_msg("")

# Use probe-onset-locked RT as PRIMARY
# Cue-locked RT for exclusion (aligned with behavioral refit pipeline)
if ("rt_cue_locked" %in% names(ddm_pupil)) {
  ddm_pupil <- ddm_pupil %>% mutate(rt_cue = rt_cue_locked)
} else if ("rt_cue" %in% names(ddm_pupil)) {
  ddm_pupil <- ddm_pupil %>% mutate(rt_cue = rt_cue)
} else if ("rt" %in% names(ddm_pupil)) {
  ddm_pupil <- ddm_pupil %>% mutate(rt_cue = rt)
  log_msg("  Using rt as cue-locked RT for threshold exclusion")
} else {
  stop("No cue-locked RT column found (expected rt_cue_locked, rt_cue, or rt)")
}

if ("rt_probe_onset_locked" %in% names(ddm_pupil)) {
  log_msg("  ✓ Using rt_probe_onset_locked as PRIMARY RT definition")
  ddm_pupil <- ddm_pupil %>%
    mutate(rt_primary = rt_probe_onset_locked)
} else if ("rt" %in% names(ddm_pupil)) {
  log_msg("  WARNING: rt_probe_onset_locked not found, using 'rt' column", level = "WARN")
  ddm_pupil <- ddm_pupil %>%
    mutate(rt_primary = rt)
} else {
  log_msg("  ERROR: No RT column found!", level = "ERROR")
  close(log_con)
  stop("No RT column found in data")
}

# Log RT statistics
log_msg("  RT statistics (rt_primary):")
log_msg(sprintf("    Mean: %.4f s", mean(ddm_pupil$rt_primary, na.rm = TRUE)))
log_msg(sprintf("    SD: %.4f s", sd(ddm_pupil$rt_primary, na.rm = TRUE)))
log_msg(sprintf("    Min: %.4f s", min(ddm_pupil$rt_primary, na.rm = TRUE)))
log_msg(sprintf("    Max: %.4f s", max(ddm_pupil$rt_primary, na.rm = TRUE)))
log_msg(sprintf("    Missing: %d (%.1f%%)", 
                sum(is.na(ddm_pupil$rt_primary)), 
                100 * sum(is.na(ddm_pupil$rt_primary)) / nrow(ddm_pupil)))
log_msg("")

# ==============================================================================
# Step 6: Apply RT validity filtering (before thresholding)
# ==============================================================================

log_msg("STEP 6: Applying RT validity filtering...")

n_start <- nrow(ddm_pupil)
log_msg("  Starting rows:", n_start)

# Filter: remove missing RT
ddm_pupil_valid <- ddm_pupil %>%
  filter(!is.na(rt_primary))

n_after_rt_filter <- nrow(ddm_pupil_valid)
n_removed_rt <- n_start - n_after_rt_filter
log_msg(sprintf("  After removing missing RT: %d rows (removed %d, %.1f%%)", 
                n_after_rt_filter, n_removed_rt, 100 * n_removed_rt / n_start))

# Filter: remove invalid choices (if choice_binary is present)
if ("choice_binary" %in% names(ddm_pupil_valid)) {
  ddm_pupil_valid <- ddm_pupil_valid %>%
    filter(!is.na(choice_binary))
  
  n_after_choice_filter <- nrow(ddm_pupil_valid)
  n_removed_choice <- n_after_rt_filter - n_after_choice_filter
  log_msg(sprintf("  After removing invalid choices: %d rows (removed %d, %.1f%%)", 
                  n_after_choice_filter, n_removed_choice, 
                  100 * n_removed_choice / n_after_rt_filter))
}

log_msg("")

# ==============================================================================
# Step 7: Pupil missingness after merge
# ==============================================================================

log_msg("STEP 7: Pupil missingness after merge...")

n_valid_trials <- nrow(ddm_pupil_valid)
n_pupil_missing <- sum(ddm_pupil_valid$pupil_missing, na.rm = TRUE)
pct_pupil_missing <- 100 * n_pupil_missing / n_valid_trials

log_msg("  Overall pupil missingness:")
log_msg(sprintf("    Total valid trials: %d", n_valid_trials))
log_msg(sprintf("    Pupil missing: %d (%.1f%%)", n_pupil_missing, pct_pupil_missing))
log_msg("")

# Pupil missingness by condition
if ("task_std" %in% names(ddm_pupil_valid) && 
    "effort_condition" %in% names(ddm_pupil_valid) &&
    "difficulty_level" %in% names(ddm_pupil_valid)) {
  
  log_msg("  Pupil missingness by condition:")
  
  pupil_miss_by_cond <- ddm_pupil_valid %>%
    group_by(task_std, difficulty_level, effort_condition) %>%
    summarise(
      n_trials = n(),
      n_missing = sum(pupil_missing, na.rm = TRUE),
      pct_missing = 100 * n_missing / n_trials,
      .groups = "drop"
    ) %>%
    arrange(task_std, difficulty_level, effort_condition)
  
  for (i in 1:nrow(pupil_miss_by_cond)) {
    log_msg(sprintf("    %s / %s / %s: %d/%d missing (%.1f%%)",
                    pupil_miss_by_cond$task_std[i],
                    pupil_miss_by_cond$difficulty_level[i],
                    pupil_miss_by_cond$effort_condition[i],
                    pupil_miss_by_cond$n_missing[i],
                    pupil_miss_by_cond$n_trials[i],
                    pupil_miss_by_cond$pct_missing[i]))
  }
}

log_msg("")

# ==============================================================================
# Step 8: Create thresholded datasets
# ==============================================================================

log_msg("STEP 8: Creating thresholded datasets...")

THRESHOLDS <- c(0.15, 0.20, 0.25)

for (thr in THRESHOLDS) {
  log_msg("")
  log_msg(sprintf("  === Threshold: %.2f s ===", thr))
  
  # Apply threshold on cue-locked RT (same rule as behavioral refit); model RT stays probe-onset
  ddm_pupil_thr <- ddm_pupil_valid %>%
    filter(!is.na(rt_cue), rt_cue >= thr)
  
  n_after_thr <- nrow(ddm_pupil_thr)
  n_removed_thr <- n_valid_trials - n_after_thr
  pct_removed_thr <- 100 * n_removed_thr / n_valid_trials
  
  log_msg(sprintf("    Rows after cue-locked RT >= %.2f: %d (removed %d, %.1f%%)",
                  thr, n_after_thr, n_removed_thr, pct_removed_thr))
  
  # Subjects retained
  n_subjects <- n_distinct(ddm_pupil_thr$subject_id)
  log_msg(sprintf("    Subjects retained: %d", n_subjects))
  
  # Condition coverage (for primary threshold only)
  if (thr == 0.20) {
    log_msg("")
    log_msg("    Condition coverage (Task × Difficulty × Effort):")
    
    cond_coverage <- ddm_pupil_thr %>%
      group_by(task_std, difficulty_level, effort_condition) %>%
      summarise(
        n_trials = n(),
        n_subjects = n_distinct(subject_id),
        n_pupil_missing = sum(pupil_missing, na.rm = TRUE),
        pct_pupil_missing = 100 * n_pupil_missing / n_trials,
        .groups = "drop"
      ) %>%
      arrange(task_std, difficulty_level, effort_condition)
    
    for (i in 1:nrow(cond_coverage)) {
      log_msg(sprintf("      %s / %s / %s: %d trials, %d subjects, %.1f%% pupil missing",
                      cond_coverage$task_std[i],
                      cond_coverage$difficulty_level[i],
                      cond_coverage$effort_condition[i],
                      cond_coverage$n_trials[i],
                      cond_coverage$n_subjects[i],
                      cond_coverage$pct_pupil_missing[i]))
    }
  }
  
  # Save dataset
  output_file <- file.path(OUTPUT_DIR, 
                           sprintf("ddm_pupil_ready_thr%.2f_probe_onset_locked.csv", thr))
  
  write_csv(ddm_pupil_thr, output_file)
  
  file_size_mb <- round(file.info(output_file)$size / 1024 / 1024, 2)
  log_msg(sprintf("    ✓ Saved: %s (%.2f MB)", basename(output_file), file_size_mb))
}

log_msg("")

# ==============================================================================
# Finish
# ==============================================================================

END_TIME <- Sys.time()
ELAPSED <- as.numeric(difftime(END_TIME, START_TIME, units = "secs"))

log_msg(strrep("=", 80))
log_msg("COMPLETED SUCCESSFULLY")
log_msg(strrep("=", 80))
log_msg("End time:", format(END_TIME, "%Y-%m-%d %H:%M:%S"))
log_msg("Elapsed time:", sprintf("%.1f seconds", ELAPSED))
log_msg("")
log_msg("Output files:")
for (thr in THRESHOLDS) {
  output_file <- file.path(OUTPUT_DIR, 
                           sprintf("ddm_pupil_ready_thr%.2f_probe_onset_locked.csv", thr))
  log_msg("  -", output_file)
}
log_msg("  -", LOG_FILE)
log_msg("")

# Close log file
close(log_con)

cat("\n✓ Build completed successfully!\n")
cat("  Output directory:", OUTPUT_DIR, "\n")
cat("  Log file:        ", LOG_FILE, "\n\n")
