#!/usr/bin/env Rscript
# ==============================================================================
# Build Pupil Trial Features
# ==============================================================================
# Purpose: Generate a single clean per-trial pupil feature table suitable for
#          joining to DDM-ready data.
#
# Input:  data/pupil_processed/analysis_ready/ch3_triallevel.csv
#         (Primary pupil feature file from make_quick_share_v7.R pipeline)
#
# Output: output/pupil/pupil_trial_features.csv
#         output/pupil/build_pupil_trial_features.log
#
# Primary metric: cog_auc_w3 (Cognitive AUC W3.0 window, TEPR)
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(here)
})

# ==============================================================================
# Setup logging
# ==============================================================================

SCRIPT_NAME <- "build_pupil_trial_features.R"
START_TIME <- Sys.time()

# Create output directory
OUTPUT_DIR <- here::here("output", "pupil")
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Open log file
LOG_FILE <- file.path(OUTPUT_DIR, "build_pupil_trial_features.log")
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
log_msg("BUILD PUPIL TRIAL FEATURES")
log_msg(strrep("=", 80))
log_msg("Script:", SCRIPT_NAME)
log_msg("Start time:", format(START_TIME, "%Y-%m-%d %H:%M:%S"))
log_msg("Output directory:", OUTPUT_DIR)
log_msg("")

# ==============================================================================
# Step 1: Load input data
# ==============================================================================

log_msg("STEP 1: Loading input data...")

# Primary pupil feature file (from make_quick_share_v7.R or equivalent)
# BAP_triallevel_merged_v4 has same structure as ch3_triallevel (trial_uid, sub, task, cog_auc_w3, etc.)
PUPIL_FILE_PATHS <- c(
  here::here("data", "pupil_processed", "analysis_ready", "ch3_triallevel.csv"),
  here::here("data", "pupil_processed", "analysis_ready", "BAP_triallevel_merged_v4.csv"),
  here::here("data", "pupil_processed", "merged", "BAP_triallevel_merged_v4.csv"),
  here::here("quick_share_v7", "analysis_ready", "ch3_triallevel.csv"),
  here::here("data", "analysis_ready", "ch3_triallevel.csv")
)

pupil_data <- NULL
pupil_file_used <- NULL

for (path in PUPIL_FILE_PATHS) {
  if (file.exists(path)) {
    log_msg("  Found pupil data:", path)
    pupil_data <- read_csv(path, show_col_types = FALSE)
    pupil_file_used <- path
    break
  }
}

if (is.null(pupil_data)) {
  log_msg("ERROR: Pupil data file not found. Tried:", level = "ERROR")
  for (path in PUPIL_FILE_PATHS) {
    log_msg("  -", path, level = "ERROR")
  }
  close(log_con)
  stop("Pupil data file not found")
}

log_msg("  ✓ Loaded:", nrow(pupil_data), "rows")
log_msg("  ✓ Columns:", ncol(pupil_data))
log_msg("")

# ==============================================================================
# Step 2: Identify and map columns
# ==============================================================================

log_msg("STEP 2: Identifying and mapping columns...")

# Check for required columns (subject: sub or subject_id)
required_cols <- c("trial_uid", "task")
has_subject <- "sub" %in% names(pupil_data) || "subject_id" %in% names(pupil_data)
missing_cols <- setdiff(required_cols, names(pupil_data))
if (!has_subject) missing_cols <- c(missing_cols, "sub/subject_id")

if (length(missing_cols) > 0) {
  log_msg("ERROR: Missing required columns:", paste(missing_cols, collapse = ", "), level = "ERROR")
  close(log_con)
  stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
}

# Map column names to standard names
log_msg("  Mapping column names...")

# Subject ID
if ("sub" %in% names(pupil_data)) {
  pupil_data <- pupil_data %>% mutate(subject_id = sub)
  log_msg("    subject_id <- sub")
} else if ("subject_id" %in% names(pupil_data)) {
  log_msg("    subject_id (already present)")
} else {
  log_msg("ERROR: No subject identifier found", level = "ERROR")
  close(log_con)
  stop("No subject identifier column found")
}

# Trial ID (use trial_uid as the stable identifier)
if ("trial_uid" %in% names(pupil_data)) {
  pupil_data <- pupil_data %>% mutate(trial_id = trial_uid)
  log_msg("    trial_id <- trial_uid")
} else if ("trial_id" %in% names(pupil_data)) {
  log_msg("    trial_id (already present)")
} else {
  log_msg("ERROR: No trial identifier found", level = "ERROR")
  close(log_con)
  stop("No trial identifier column found")
}

# Task (should already be present)
log_msg("    task (present)")

# Effort condition
if ("effort_condition" %in% names(pupil_data)) {
  log_msg("    effort_condition (present)")
} else if ("effort" %in% names(pupil_data)) {
  pupil_data <- pupil_data %>% mutate(effort_condition = effort)
  log_msg("    effort_condition <- effort")
} else {
  log_msg("    WARNING: effort_condition not found, will be set to NA", level = "WARN")
  pupil_data <- pupil_data %>% mutate(effort_condition = NA_character_)
}

# Difficulty
if ("difficulty" %in% names(pupil_data)) {
  log_msg("    difficulty (present)")
} else if ("difficulty_level" %in% names(pupil_data)) {
  pupil_data <- pupil_data %>% mutate(difficulty = difficulty_level)
  log_msg("    difficulty <- difficulty_level")
} else if ("difficulty_3" %in% names(pupil_data)) {
  pupil_data <- pupil_data %>% mutate(difficulty = difficulty_3)
  log_msg("    difficulty <- difficulty_3")
} else {
  log_msg("    WARNING: difficulty not found, will be set to NA", level = "WARN")
  pupil_data <- pupil_data %>% mutate(difficulty = NA_character_)
}

# Tonic arousal (baseline pupil)
if ("baseline_B0_mean" %in% names(pupil_data)) {
  pupil_data <- pupil_data %>% mutate(pupil_tonic = baseline_B0_mean)
  log_msg("    pupil_tonic <- baseline_B0_mean")
} else if ("baseline_B0" %in% names(pupil_data)) {
  pupil_data <- pupil_data %>% mutate(pupil_tonic = baseline_B0)
  log_msg("    pupil_tonic <- baseline_B0")
} else {
  log_msg("    WARNING: baseline pupil not found, will be set to NA", level = "WARN")
  pupil_data <- pupil_data %>% mutate(pupil_tonic = NA_real_)
}

# Phasic arousal (PRIMARY: cog_auc_w3, per inventory report)
if ("cog_auc_w3" %in% names(pupil_data)) {
  pupil_data <- pupil_data %>% mutate(pupil_phasic = cog_auc_w3)
  log_msg("    pupil_phasic <- cog_auc_w3 (PRIMARY TEPR metric)")
} else if ("cognitive_auc" %in% names(pupil_data)) {
  pupil_data <- pupil_data %>% mutate(pupil_phasic = cognitive_auc)
  log_msg("    pupil_phasic <- cognitive_auc")
} else if ("cog_auc" %in% names(pupil_data)) {
  pupil_data <- pupil_data %>% mutate(pupil_phasic = cog_auc)
  log_msg("    pupil_phasic <- cog_auc")
} else {
  log_msg("    WARNING: phasic pupil not found, will be set to NA", level = "WARN")
  pupil_data <- pupil_data %>% mutate(pupil_phasic = NA_real_)
}

# Primary metric = phasic (per inventory report: cog_auc_w3 is PRIMARY)
pupil_data <- pupil_data %>% mutate(pupil_metric_primary = pupil_phasic)
log_msg("    pupil_metric_primary <- pupil_phasic (cog_auc_w3)")

# Truncated Decision-Response AUC (0.3–1.3 s post-probe); sensitivity metric
if ("cog_auc_w1p3" %in% names(pupil_data)) {
  pupil_data <- pupil_data %>% mutate(pupil_w1p3 = cog_auc_w1p3)
  log_msg("    pupil_w1p3 <- cog_auc_w1p3 (truncated TEPR window)")
} else {
  pupil_data <- pupil_data %>% mutate(pupil_w1p3 = NA_real_)
  log_msg("    WARNING: cog_auc_w1p3 not found; pupil_w1p3 set to NA", level = "WARN")
}

# Quality metrics
if ("B1_quality" %in% names(pupil_data) && "cog_quality" %in% names(pupil_data)) {
  log_msg("    Quality metrics: B1_quality, cog_quality (present)")
} else {
  log_msg("    WARNING: Quality metrics not found", level = "WARN")
}

# DDM-ready gate (from inventory: B1_quality >= 0.50 AND cog_quality >= 0.50 AND RT 0.2-3.0s)
if ("ddm_ready" %in% names(pupil_data)) {
  log_msg("    ddm_ready gate (present)")
} else {
  log_msg("    WARNING: ddm_ready gate not found", level = "WARN")
}

log_msg("")

# ==============================================================================
# Step 3: Compute QC flags and missingness
# ==============================================================================

log_msg("STEP 3: Computing QC flags and missingness...")

# Check which columns exist for QC logic
has_ddm_ready <- "ddm_ready" %in% names(pupil_data)
has_B1_quality <- "B1_quality" %in% names(pupil_data)
has_cog_quality <- "cog_quality" %in% names(pupil_data)

pupil_features <- pupil_data %>%
  mutate(
    # Missingness flag
    pupil_missing = is.na(pupil_metric_primary),
    
    # QC exclusion flag (based on ddm_ready gate if available)
    pupil_qc_exclude = if (has_ddm_ready) {
      !ddm_ready | is.na(ddm_ready)
    } else if (has_B1_quality && has_cog_quality) {
      # Fallback: apply DDM-ready criteria manually
      (is.na(B1_quality) | B1_quality < 0.50 | 
       is.na(cog_quality) | cog_quality < 0.50 |
       is.na(pupil_metric_primary))
    } else {
      # Fallback: just check for missing primary metric
      is.na(pupil_metric_primary)
    }
  )

# Compute QC reason based on available columns
if (has_B1_quality && has_cog_quality) {
  pupil_features <- pupil_features %>%
    mutate(
      pupil_qc_reason = case_when(
        is.na(pupil_metric_primary) ~ "missing_primary_metric",
        is.na(B1_quality) | B1_quality < 0.50 ~ "low_baseline_quality",
        is.na(cog_quality) | cog_quality < 0.50 ~ "low_cognitive_quality",
        pupil_qc_exclude ~ "qc_gate_failed",
        TRUE ~ ""
      )
    )
} else {
  pupil_features <- pupil_features %>%
    mutate(
      pupil_qc_reason = case_when(
        is.na(pupil_metric_primary) ~ "missing_primary_metric",
        pupil_qc_exclude ~ "qc_gate_failed",
        TRUE ~ ""
      )
    )
}

log_msg("  ✓ Computed pupil_missing flag")
log_msg("  ✓ Computed pupil_qc_exclude flag")
log_msg("  ✓ Computed pupil_qc_reason")
log_msg("")

# ==============================================================================
# Step 4: Compute within-subject z-scores
# ==============================================================================

log_msg("STEP 4: Computing within-subject z-scores...")

pupil_features <- pupil_features %>%
  group_by(subject_id) %>%
  mutate(
    pupil_metric_primary_z = if (all(is.na(pupil_metric_primary))) {
      NA_real_
    } else {
      as.numeric(scale(pupil_metric_primary))
    },
    pupil_w1p3_z = if (all(is.na(pupil_w1p3))) {
      NA_real_
    } else {
      as.numeric(scale(pupil_w1p3))
    }
  ) %>%
  ungroup()

log_msg("  ✓ Computed pupil_metric_primary_z (within-subject z-score)")
log_msg("  ✓ Computed pupil_w1p3_z (truncated window, within-subject z-score)")
log_msg("")

# ==============================================================================
# Step 5: Select and order output columns
# ==============================================================================

log_msg("STEP 5: Selecting output columns...")

output_cols <- c(
  "subject_id",
  "trial_id",
  "task",
  "effort_condition",
  "difficulty",
  "pupil_tonic",
  "pupil_phasic",
  "pupil_metric_primary",
  "pupil_metric_primary_z",
  "pupil_w1p3",
  "pupil_w1p3_z",
  "pupil_missing",
  "pupil_qc_exclude",
  "pupil_qc_reason"
)

pupil_features_out <- pupil_features %>%
  select(all_of(output_cols))

log_msg("  ✓ Selected", length(output_cols), "output columns")
log_msg("")

# ==============================================================================
# Step 6: Check for duplicates
# ==============================================================================

log_msg("STEP 6: Checking for duplicates...")

n_rows <- nrow(pupil_features_out)
n_unique_trials <- n_distinct(pupil_features_out$trial_id)

log_msg("  Total rows:", n_rows)
log_msg("  Unique trial_id:", n_unique_trials)

if (n_rows != n_unique_trials) {
  log_msg("  WARNING: Found", n_rows - n_unique_trials, "duplicate trial_id values", level = "WARN")
  
  # Identify duplicates
  dups <- pupil_features_out %>%
    group_by(trial_id) %>%
    filter(n() > 1) %>%
    arrange(trial_id)
  
  log_msg("  First 10 duplicate trial_id values:", level = "WARN")
  for (tid in head(unique(dups$trial_id), 10)) {
    log_msg("    -", tid, level = "WARN")
  }
  
  # Keep first occurrence only
  log_msg("  Removing duplicates (keeping first occurrence)...")
  pupil_features_out <- pupil_features_out %>%
    distinct(trial_id, .keep_all = TRUE)
  
  log_msg("  ✓ After deduplication:", nrow(pupil_features_out), "rows")
} else {
  log_msg("  ✓ No duplicates found")
}

log_msg("")

# ==============================================================================
# Step 7: Compute and log diagnostics
# ==============================================================================

log_msg("STEP 7: Computing diagnostics...")
log_msg("")

# Number of subjects
n_subjects <- n_distinct(pupil_features_out$subject_id)
log_msg("Number of subjects:", n_subjects)

# Number of trials
n_trials <- nrow(pupil_features_out)
log_msg("Number of trials:", n_trials)
log_msg("")

# Missingness rate overall
n_missing <- sum(pupil_features_out$pupil_missing, na.rm = TRUE)
pct_missing <- 100 * n_missing / n_trials
log_msg("Missingness rate (overall):")
log_msg("  Missing trials:", n_missing, sprintf("(%.1f%%)", pct_missing))
log_msg("")

# Missingness rate by subject
log_msg("Missingness rate by subject (top 10 worst):")
missing_by_subj <- pupil_features_out %>%
  group_by(subject_id) %>%
  summarise(
    n_trials = n(),
    n_missing = sum(pupil_missing, na.rm = TRUE),
    pct_missing = 100 * n_missing / n_trials,
    .groups = "drop"
  ) %>%
  arrange(desc(pct_missing))

for (i in 1:min(10, nrow(missing_by_subj))) {
  row <- missing_by_subj[i, ]
  log_msg(sprintf("  %s: %d/%d missing (%.1f%%)", 
                  row$subject_id, row$n_missing, row$n_trials, row$pct_missing))
}
log_msg("")

# QC exclusion rate overall
n_excluded <- sum(pupil_features_out$pupil_qc_exclude, na.rm = TRUE)
pct_excluded <- 100 * n_excluded / n_trials
log_msg("QC exclusion rate (overall):")
log_msg("  Excluded trials:", n_excluded, sprintf("(%.1f%%)", pct_excluded))
log_msg("")

# QC exclusion rate by subject (top 10 worst)
log_msg("QC exclusion rate by subject (top 10 worst):")
excluded_by_subj <- pupil_features_out %>%
  group_by(subject_id) %>%
  summarise(
    n_trials = n(),
    n_excluded = sum(pupil_qc_exclude, na.rm = TRUE),
    pct_excluded = 100 * n_excluded / n_trials,
    .groups = "drop"
  ) %>%
  arrange(desc(pct_excluded))

for (i in 1:min(10, nrow(excluded_by_subj))) {
  row <- excluded_by_subj[i, ]
  log_msg(sprintf("  %s: %d/%d excluded (%.1f%%)", 
                  row$subject_id, row$n_excluded, row$n_trials, row$pct_excluded))
}
log_msg("")

# QC exclusion reasons
log_msg("QC exclusion reasons:")
qc_reasons <- pupil_features_out %>%
  filter(pupil_qc_exclude) %>%
  count(pupil_qc_reason, sort = TRUE)

if (nrow(qc_reasons) > 0) {
  for (i in 1:nrow(qc_reasons)) {
    reason <- qc_reasons$pupil_qc_reason[i]
    count <- qc_reasons$n[i]
    pct <- 100 * count / n_excluded
    log_msg(sprintf("  %s: %d (%.1f%%)", reason, count, pct))
  }
} else {
  log_msg("  (No exclusions)")
}
log_msg("")

# Summary statistics for pupil_metric_primary
log_msg("Summary statistics for pupil_metric_primary:")
valid_primary <- pupil_features_out %>%
  filter(!is.na(pupil_metric_primary)) %>%
  pull(pupil_metric_primary)

if (length(valid_primary) > 0) {
  log_msg(sprintf("  Mean:   %.4f", mean(valid_primary, na.rm = TRUE)))
  log_msg(sprintf("  SD:     %.4f", sd(valid_primary, na.rm = TRUE)))
  log_msg(sprintf("  Min:    %.4f", min(valid_primary, na.rm = TRUE)))
  log_msg(sprintf("  Max:    %.4f", max(valid_primary, na.rm = TRUE)))
  log_msg(sprintf("  Median: %.4f", median(valid_primary, na.rm = TRUE)))
} else {
  log_msg("  (No valid values)")
}
log_msg("")

# Summary statistics for pupil_metric_primary_z
log_msg("Summary statistics for pupil_metric_primary_z (within-subject z-score):")
valid_z <- pupil_features_out %>%
  filter(!is.na(pupil_metric_primary_z)) %>%
  pull(pupil_metric_primary_z)

if (length(valid_z) > 0) {
  log_msg(sprintf("  Mean:   %.4f", mean(valid_z, na.rm = TRUE)))
  log_msg(sprintf("  SD:     %.4f", sd(valid_z, na.rm = TRUE)))
  log_msg(sprintf("  Min:    %.4f", min(valid_z, na.rm = TRUE)))
  log_msg(sprintf("  Max:    %.4f", max(valid_z, na.rm = TRUE)))
  log_msg(sprintf("  Median: %.4f", median(valid_z, na.rm = TRUE)))
} else {
  log_msg("  (No valid values)")
}
log_msg("")

# Distribution by task
log_msg("Distribution by task:")
task_dist <- pupil_features_out %>%
  count(task, sort = TRUE)

for (i in 1:nrow(task_dist)) {
  log_msg(sprintf("  %s: %d trials (%.1f%%)", 
                  task_dist$task[i], task_dist$n[i], 
                  100 * task_dist$n[i] / n_trials))
}
log_msg("")

# Distribution by effort_condition
log_msg("Distribution by effort_condition:")
effort_dist <- pupil_features_out %>%
  count(effort_condition, sort = TRUE)

for (i in 1:nrow(effort_dist)) {
  effort_val <- if (is.na(effort_dist$effort_condition[i])) "NA" else effort_dist$effort_condition[i]
  log_msg(sprintf("  %s: %d trials (%.1f%%)", 
                  effort_val, effort_dist$n[i], 
                  100 * effort_dist$n[i] / n_trials))
}
log_msg("")

# Distribution by difficulty
log_msg("Distribution by difficulty:")
diff_dist <- pupil_features_out %>%
  count(difficulty, sort = TRUE)

for (i in 1:nrow(diff_dist)) {
  diff_val <- if (is.na(diff_dist$difficulty[i])) "NA" else diff_dist$difficulty[i]
  log_msg(sprintf("  %s: %d trials (%.1f%%)", 
                  diff_val, diff_dist$n[i], 
                  100 * diff_dist$n[i] / n_trials))
}
log_msg("")

# ==============================================================================
# Step 8: Save output
# ==============================================================================

log_msg("STEP 8: Saving output...")

OUTPUT_FILE <- file.path(OUTPUT_DIR, "pupil_trial_features.csv")

write_csv(pupil_features_out, OUTPUT_FILE)

log_msg("  ✓ Saved:", OUTPUT_FILE)
log_msg("  ✓ Rows:", nrow(pupil_features_out))
log_msg("  ✓ Columns:", ncol(pupil_features_out))
log_msg("")

# Verify file exists
if (file.exists(OUTPUT_FILE)) {
  file_size <- file.info(OUTPUT_FILE)$size
  file_size_mb <- round(file_size / 1024 / 1024, 2)
  log_msg("  ✓ File verified:", OUTPUT_FILE)
  log_msg("  ✓ File size:", file_size_mb, "MB")
} else {
  log_msg("  ERROR: Output file not created!", level = "ERROR")
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
log_msg("  -", OUTPUT_FILE)
log_msg("  -", LOG_FILE)
log_msg("")

# Close log file
close(log_con)

cat("\n✓ Build completed successfully!\n")
cat("  Output:", OUTPUT_FILE, "\n")
cat("  Log:   ", LOG_FILE, "\n\n")
