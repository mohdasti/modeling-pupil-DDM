#!/usr/bin/env Rscript

# ============================================================================
# Create Trial-Level Dataset from Sample-Level MERGED Data
# ============================================================================
# Aggregates sample-level pupillometry data to one row per trial
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(purrr)
})

# ============================================================================
# Configuration
# ============================================================================

BASE_DIR <- "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM"
MERGED_FILE <- file.path(BASE_DIR, "data/analysis_ready/BAP_analysis_ready_MERGED.csv")
OUTPUT_DIR <- file.path(BASE_DIR, "data/analysis_ready")
OUTPUT_CSV <- file.path(OUTPUT_DIR, "BAP_analysis_ready_TRIALLEVEL.csv")
OUTPUT_PARQUET <- file.path(OUTPUT_DIR, "BAP_analysis_ready_TRIALLEVEL.parquet")

# Threshold for gate flags
DISSERTATION_THRESHOLD <- 0.80
THR_LABEL <- sprintf("t%03d", round(DISSERTATION_THRESHOLD * 100))

cat("=== CREATING TRIAL-LEVEL DATASET ===\n\n")

# ============================================================================
# TASK A: Load and Create trial_uid
# ============================================================================

cat("TASK A: Loading MERGED file and creating trial_uid\n")
cat("----------------------------------------------------\n")

cat("Loading MERGED file (this may take a moment)...\n")
merged <- read_csv(MERGED_FILE, show_col_types = FALSE, progress = TRUE)

cat("Loaded", nrow(merged), "rows\n")
cat("Columns:", paste(names(merged), collapse = ", "), "\n\n")

# Check for ses column
has_ses <- "ses" %in% names(merged) || "session" %in% names(merged)
ses_col <- if("ses" %in% names(merged)) "ses" else if("session" %in% names(merged)) "session" else NULL

cat("Trial identity columns:\n")
cat("  - subject_id:", "subject_id" %in% names(merged), "\n")
cat("  - task:", "task" %in% names(merged), "\n")
cat("  - run:", "run" %in% names(merged), "\n")
cat("  - trial_index:", "trial_index" %in% names(merged), "\n")
cat("  - ses/session:", !is.null(ses_col), "\n\n")

# Create trial_uid
# Strategy: subject_id + task + ses (if available) + run + trial_index
if (!is.null(ses_col)) {
  merged <- merged %>%
    mutate(
      ses_value = if(is.na(!!sym(ses_col))) 1L else as.integer(!!sym(ses_col)),
      trial_uid = paste(subject_id, task, ses_value, run, trial_index, sep = ":")
    )
  cat("Created trial_uid using: subject_id + task + ses + run + trial_index\n")
} else {
  # Try to extract ses from trial_id if it exists
  if ("trial_id" %in% names(merged)) {
    # Check if trial_id contains ses information
    merged <- merged %>%
      mutate(
        ses_value = 1L,  # Default to 1 if not available
        trial_uid = paste(subject_id, task, ses_value, run, trial_index, sep = ":")
      )
    cat("Created trial_uid using: subject_id + task + run + trial_index (ses defaulted to 1)\n")
  } else {
    merged <- merged %>%
      mutate(
        ses_value = 1L,
        trial_uid = paste(subject_id, task, ses_value, run, trial_index, sep = ":")
      )
    cat("Created trial_uid using: subject_id + task + run + trial_index (ses defaulted to 1)\n")
  }
}

# Verify uniqueness
n_total_rows <- nrow(merged)
n_unique_trial_uid <- n_distinct(merged$trial_uid)
n_unique_trials_simple <- merged %>%
  select(subject_id, task, trial_index) %>%
  distinct() %>%
  nrow()

cat("\nUniqueness check:\n")
cat("  - Total rows:", n_total_rows, "\n")
cat("  - Unique trial_uid:", n_unique_trial_uid, "\n")
cat("  - Unique (subject_id, task, trial_index):", n_unique_trials_simple, "\n")

# Check for collisions using only (subject_id, task, trial_index)
collisions <- merged %>%
  group_by(subject_id, task, trial_index) %>%
  summarise(
    n_runs = n_distinct(run),
    n_trial_uids = n_distinct(trial_uid),
    runs = paste(sort(unique(run)), collapse = ","),
    .groups = "drop"
  ) %>%
  filter(n_runs > 1 | n_trial_uids > 1)

n_collisions <- nrow(collisions)
cat("  - Collisions (same subject+task+trial_index across runs):", n_collisions, "\n\n")

if (n_collisions > 0) {
  cat("Top 20 collision examples:\n")
  print(head(collisions, 20))
  cat("\n")
} else {
  cat("✓ No collisions detected - trial_uid is unique\n\n")
}

# ============================================================================
# TASK B: Aggregate to Trial Level
# ============================================================================

cat("TASK B: Aggregating to trial level\n")
cat("-----------------------------------\n")

# Identify columns to aggregate
# Validity columns (take first value - should be constant per trial)
validity_cols <- c(
  "valid_prop_baseline_500ms",
  "valid_prop_iti_full", 
  "valid_prop_prestim",
  "valid_prop_total_auc",
  "valid_prop_cognitive_auc"
)

# Gate columns (take first value - should be constant per trial)
gate_cols <- c(
  "gate_stimlocked_T",
  "gate_total_auc_T",
  "gate_cog_auc_T"
)

# Behavioral columns (take first value - should be constant per trial)
behavioral_cols <- c(
  "effort_condition",
  "difficulty_level",
  "rt",
  "response_onset",
  "has_response_window"
)

# Check which columns actually exist
validity_cols <- intersect(validity_cols, names(merged))
gate_cols <- intersect(gate_cols, names(merged))
behavioral_cols <- intersect(behavioral_cols, names(merged))

cat("Aggregating columns:\n")
cat("  - Validity:", length(validity_cols), "columns\n")
cat("  - Gates:", length(gate_cols), "columns\n")
cat("  - Behavioral:", length(behavioral_cols), "columns\n")

# Check for pupil metric columns (baseline, AUC, etc.)
pupil_metric_cols <- names(merged)[grepl("baseline|auc|pupil|diameter", names(merged), ignore.case = TRUE)]
pupil_metric_cols <- setdiff(pupil_metric_cols, c(validity_cols, gate_cols))
cat("  - Pupil metrics found:", length(pupil_metric_cols), "columns\n")
if (length(pupil_metric_cols) > 0) {
  cat("    ", paste(head(pupil_metric_cols, 5), collapse = ", "), if(length(pupil_metric_cols) > 5) "..." else "", "\n")
}

# Aggregate to trial level
cat("\nAggregating data...\n")

trial_level <- merged %>%
  group_by(trial_uid, subject_id, task, run, trial_index) %>%
  summarise(
    # Add ses if available
    across(any_of(c("ses", "session")), first, .names = "{.col}"),
    ses_value = first(ses_value),
    
    # Validity proportions (take first - should be constant)
    across(any_of(validity_cols), first, .names = "{.col}"),
    
    # Gate flags (take first - should be constant)
    across(any_of(gate_cols), first, .names = "{.col}"),
    
    # Behavioral data (take first - should be constant)
    across(any_of(behavioral_cols), first, .names = "{.col}"),
    
    # Sample count per trial
    n_samples = n(),
    
    # Pupil metrics (if available, compute mean/sd)
    across(any_of(pupil_metric_cols), 
           list(mean = ~ mean(.x, na.rm = TRUE), 
                sd = ~ sd(.x, na.rm = TRUE),
                min = ~ min(.x, na.rm = TRUE),
                max = ~ max(.x, na.rm = TRUE)),
           .names = "{.col}_{.fn}"),
    
    .groups = "drop"
  )

cat("Aggregated to", nrow(trial_level), "trials\n\n")

# Recompute gate flags at dissertation threshold
cat("Computing gate flags at threshold", DISSERTATION_THRESHOLD, "...\n")

# Rename validity columns to match expected names
trial_level <- trial_level %>%
  mutate(
    # Standardize validity column names
    valid_baseline500 = if("valid_prop_baseline_500ms" %in% names(.)) {
      valid_prop_baseline_500ms
    } else NA_real_,
    valid_iti = if("valid_prop_iti_full" %in% names(.)) {
      valid_prop_iti_full
    } else NA_real_,
    valid_prestim_fix_interior = if("valid_prop_prestim" %in% names(.)) {
      valid_prop_prestim
    } else NA_real_,
    valid_total_auc_window = if("valid_prop_total_auc" %in% names(.)) {
      valid_prop_total_auc
    } else NA_real_,
    valid_cognitive_window = if("valid_prop_cognitive_auc" %in% names(.)) {
      valid_prop_cognitive_auc
    } else NA_real_,
    
    # Recompute gates at dissertation threshold
    pass_stimlocked_t080 = (valid_iti >= DISSERTATION_THRESHOLD & 
                            valid_prestim_fix_interior >= DISSERTATION_THRESHOLD),
    pass_total_auc_t080 = (valid_total_auc_window >= DISSERTATION_THRESHOLD),
    pass_cog_auc_t080 = (valid_baseline500 >= DISSERTATION_THRESHOLD & 
                         valid_cognitive_window >= DISSERTATION_THRESHOLD)
  )

# Add oddball flag if difficulty_level indicates it
if ("difficulty_level" %in% names(trial_level)) {
  trial_level <- trial_level %>%
    mutate(
      isOddball = case_when(
        difficulty_level == "Hard" ~ TRUE,
        difficulty_level == "Standard" ~ FALSE,
        difficulty_level == "Easy" ~ FALSE,
        TRUE ~ NA
      ),
      oddball = as.integer(isOddball)
    )
} else {
  trial_level <- trial_level %>%
    mutate(
      isOddball = NA,
      oddball = NA_integer_
    )
}

# Add Hi Grip flag
if ("effort_condition" %in% names(trial_level)) {
  trial_level <- trial_level %>%
    mutate(
      hi_grip = case_when(
        effort_condition == "High_40_MVC" ~ TRUE,
        effort_condition == "Low_5_MVC" ~ FALSE,
        TRUE ~ NA
      )
    )
} else {
  trial_level <- trial_level %>%
    mutate(hi_grip = NA)
}

# Add accuracy if available (check for iscorr, accuracy, etc.)
accuracy_cols <- c("iscorr", "accuracy", "correct", "hit")
accuracy_col <- intersect(accuracy_cols, names(trial_level))[1]
if (!is.na(accuracy_col)) {
  trial_level <- trial_level %>%
    mutate(accuracy = !!sym(accuracy_col))
} else {
  trial_level <- trial_level %>%
    mutate(accuracy = NA_real_)
}

cat("✓ Gate flags computed\n\n")

# ============================================================================
# Export
# ============================================================================

cat("Exporting trial-level dataset...\n")

# Export CSV
write_csv(trial_level, OUTPUT_CSV)
cat("✓ Saved:", OUTPUT_CSV, "\n")
cat("  Rows:", nrow(trial_level), "\n")
cat("  Columns:", ncol(trial_level), "\n\n")

# Export Parquet if arrow is available
if (requireNamespace("arrow", quietly = TRUE)) {
  library(arrow)
  write_parquet(trial_level, OUTPUT_PARQUET)
  cat("✓ Saved:", OUTPUT_PARQUET, "\n\n")
} else {
  cat("⚠ arrow package not available - skipping parquet export\n")
  cat("  Install with: install.packages('arrow')\n\n")
}

# ============================================================================
# Summary Statistics
# ============================================================================

cat("=== TRIAL-LEVEL DATASET SUMMARY ===\n\n")

cat("Total trials:", nrow(trial_level), "\n")
cat("Unique subjects:", n_distinct(trial_level$subject_id), "\n")
cat("Tasks:", paste(unique(trial_level$task), collapse = ", "), "\n")
cat("Unique runs:", n_distinct(trial_level$run), "\n")

if (!is.null(ses_col) || "ses_value" %in% names(trial_level)) {
  cat("Unique sessions:", n_distinct(trial_level$ses_value), "\n")
}

# Trials per subject×task
trials_per_subj_task <- trial_level %>%
  group_by(subject_id, task) %>%
  summarise(n_trials = n(), .groups = "drop")

cat("\nTrials per subject×task:\n")
cat("  - Min:", min(trials_per_subj_task$n_trials), "\n")
cat("  - Median:", median(trials_per_subj_task$n_trials), "\n")
cat("  - Max:", max(trials_per_subj_task$n_trials), "\n")

# Gate pass rates
cat("\nGate pass rates (trial-level) at threshold", DISSERTATION_THRESHOLD, ":\n")
cat("  - pass_stimlocked_t080:", sum(trial_level$pass_stimlocked_t080, na.rm = TRUE), "/", 
    sum(!is.na(trial_level$pass_stimlocked_t080)), 
    "(", round(100 * mean(trial_level$pass_stimlocked_t080, na.rm = TRUE), 1), "%)\n")
cat("  - pass_total_auc_t080:", sum(trial_level$pass_total_auc_t080, na.rm = TRUE), "/",
    sum(!is.na(trial_level$pass_total_auc_t080)),
    "(", round(100 * mean(trial_level$pass_total_auc_t080, na.rm = TRUE), 1), "%)\n")
cat("  - pass_cog_auc_t080:", sum(trial_level$pass_cog_auc_t080, na.rm = TRUE), "/",
    sum(!is.na(trial_level$pass_cog_auc_t080)),
    "(", round(100 * mean(trial_level$pass_cog_auc_t080, na.rm = TRUE), 1), "%)\n")

cat("\n✓ Trial-level dataset creation complete!\n")

