#!/usr/bin/env Rscript

# ============================================================================
# Rebuild MERGED and TRIALLEVEL with CORRECTED Matching Logic
# ============================================================================
# ISSUE FOUND: MERGED "run" column actually contains session number, not run number
# SOLUTION: Match on (subject, task, ses, trial) ignoring run, then recover run from behavioral
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(arrow)
  library(stringr)
})

BASE_DIR <- "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM"
BEHAVIORAL_FILE <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"
ANALYSIS_READY_DIR <- file.path(BASE_DIR, "data/analysis_ready")
MERGED_BACKUP <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_MERGED_scanner_ses23.parquet")

cat("=== REBUILDING WITH CORRECTED MATCHING ===\n\n")
cat("ISSUE IDENTIFIED: MERGED 'run' column contains session number, not run number\n")
cat("SOLUTION: Match on (subject, task, ses, trial) and recover run from behavioral\n\n")

# ============================================================================
# Step 1: Load and prepare behavioral ground truth
# ============================================================================

cat("Step 1: Loading behavioral ground truth\n")
cat("----------------------------------------\n")

behavioral <- read_csv(BEHAVIORAL_FILE, show_col_types = FALSE)

ground_truth <- behavioral %>%
  mutate(
    subject_id = subject_id,
    task = case_when(
      task_modality == "aud" ~ "ADT",
      task_modality == "vis" ~ "VDT",
      TRUE ~ task_modality
    ),
    ses = session_num,
    run = run_num,  # This is the REAL run number
    trial_index = trial_num,
    trial_uid = paste(subject_id, task, ses, run, trial_index, sep = ":")
  ) %>%
  distinct(subject_id, task, ses, run, trial_index, trial_uid)

cat("Ground truth:", nrow(ground_truth), "unique trials\n")
cat("Sessions:", paste(sort(unique(ground_truth$ses)), collapse = ", "), "\n")
cat("Runs:", paste(sort(unique(ground_truth$run)), collapse = ", "), "\n\n")

# ============================================================================
# Step 2: Load MERGED and fix the run issue
# ============================================================================

cat("Step 2: Loading MERGED and correcting run assignment\n")
cat("------------------------------------------------------\n")

merged <- read_parquet(MERGED_BACKUP)
cat("Loaded", nrow(merged), "sample-level rows\n")

# CRITICAL FIX: MERGED "run" is actually session
# We need to match on (subject, task, ses, trial_index) and recover run from behavioral
merged <- merged %>%
  mutate(
    # Normalize task
    task = case_when(
      task == "aud" ~ "ADT",
      task == "vis" ~ "VDT",
      task == "ADT" ~ "ADT",
      task == "VDT" ~ "VDT",
      tolower(task) == "auditory" ~ "ADT",
      tolower(task) == "visual" ~ "VDT",
      TRUE ~ task
    ),
    # Normalize subject_id
    subject_id = case_when(
      str_detect(subject_id, "^BAP") ~ subject_id,
      str_detect(subject_id, "^\\d+$") ~ paste0("BAP", str_pad(subject_id, 3, pad = "0")),
      TRUE ~ subject_id
    )
  )

# Match MERGED to behavioral to recover the REAL run number
# Match on (subject, task, ses, trial_index) since MERGED run is wrong
merged_with_run <- merged %>%
  left_join(
    ground_truth %>% select(subject_id, task, ses, trial_index, run, trial_uid),
    by = c("subject_id", "task", "ses", "trial_index"),
    suffix = c("_old", "")
  ) %>%
  mutate(
    # Use recovered run, fall back to old run if not found (shouldn't happen)
    run = ifelse(!is.na(run), run, run_old),
    # Create proper trial_uid
    trial_uid = ifelse(!is.na(trial_uid), trial_uid,
                      paste(subject_id, task, ses, run, trial_index, sep = ":"))
  ) %>%
  select(-run_old)

cat("Matched MERGED to behavioral ground truth\n")
cat("  - Rows with recovered run:", sum(!is.na(merged_with_run$run) & 
                                        merged_with_run$run != merged_with_run$ses), "\n")
cat("  - Rows still using old run (should be minimal):", 
    sum(merged_with_run$run == merged_with_run$ses & !is.na(merged_with_run$run)), "\n\n")

# Filter to only trials in ground truth
merged_filtered <- merged_with_run %>%
  filter(trial_uid %in% ground_truth$trial_uid)

cat("Filtered MERGED:\n")
cat("  - Original rows:", nrow(merged), "\n")
cat("  - After run recovery:", nrow(merged_with_run), "\n")
cat("  - After filtering to ground truth:", nrow(merged_filtered), "\n")
cat("  - Unique trials:", n_distinct(merged_filtered$trial_uid), "\n\n")

# Save corrected MERGED
output_merged_csv <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_MERGED.csv")
output_merged_parquet <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_MERGED.parquet")

write_csv(merged_filtered, output_merged_csv)
cat("✓ Saved:", output_merged_csv, "\n")

if (requireNamespace("arrow", quietly = TRUE)) {
  library(arrow)
  write_parquet(merged_filtered, output_merged_parquet)
  cat("✓ Saved:", output_merged_parquet, "\n")
}

# ============================================================================
# Step 3: Rebuild TRIALLEVEL
# ============================================================================

cat("\nStep 3: Rebuilding TRIALLEVEL\n")
cat("------------------------------\n")

# Aggregate to trial level
validity_cols <- c(
  "valid_prop_baseline_500ms", "valid_baseline500",
  "valid_prop_iti_full", "valid_iti",
  "valid_prop_prestim", "valid_prestim_fix_interior",
  "valid_prop_total_auc", "valid_total_auc_window",
  "valid_prop_cognitive_auc", "valid_cognitive_window"
)
validity_cols <- intersect(validity_cols, names(merged_filtered))

gate_cols <- names(merged_filtered)[grepl("^(pass_|gate_)", names(merged_filtered))]
behavioral_cols <- c("effort_condition", "difficulty_level", "rt", "response_onset", "has_response_window")
behavioral_cols <- intersect(behavioral_cols, names(merged_filtered))

trial_level <- merged_filtered %>%
  group_by(trial_uid, subject_id, task, ses, run, trial_index) %>%
  summarise(
    ses = first(ses),
    run = first(run),  # Use recovered run
    across(any_of(validity_cols), first, .names = "{.col}"),
    across(any_of(gate_cols), first, .names = "{.col}"),
    across(any_of(behavioral_cols), first, .names = "{.col}"),
    n_samples = n(),
    .groups = "drop"
  )

cat("Aggregated to", nrow(trial_level), "trials\n")

# Recompute gates
DISSERTATION_THRESHOLD <- 0.80

trial_level <- trial_level %>%
  mutate(
    valid_baseline500 = if("valid_prop_baseline_500ms" %in% names(.)) {
      valid_prop_baseline_500ms
    } else if("valid_baseline500" %in% names(.)) {
      valid_baseline500
    } else NA_real_,
    
    valid_iti = if("valid_prop_iti_full" %in% names(.)) {
      valid_prop_iti_full
    } else if("valid_iti" %in% names(.)) {
      valid_iti
    } else NA_real_,
    
    valid_prestim_fix_interior = if("valid_prop_prestim" %in% names(.)) {
      valid_prop_prestim
    } else if("valid_prestim_fix_interior" %in% names(.)) {
      valid_prestim_fix_interior
    } else NA_real_,
    
    valid_total_auc_window = if("valid_prop_total_auc" %in% names(.)) {
      valid_prop_total_auc
    } else if("valid_total_auc_window" %in% names(.)) {
      valid_total_auc_window
    } else NA_real_,
    
    valid_cognitive_window = if("valid_prop_cognitive_auc" %in% names(.)) {
      valid_prop_cognitive_auc
    } else if("valid_cognitive_window" %in% names(.)) {
      valid_cognitive_window
    } else NA_real_,
    
    pass_stimlocked_t080 = (valid_iti >= DISSERTATION_THRESHOLD & 
                             valid_prestim_fix_interior >= DISSERTATION_THRESHOLD),
    pass_total_auc_t080 = (valid_total_auc_window >= DISSERTATION_THRESHOLD),
    pass_cog_auc_t080 = (valid_baseline500 >= DISSERTATION_THRESHOLD & 
                         valid_cognitive_window >= DISSERTATION_THRESHOLD)
  )

# Add flags
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
}

if ("effort_condition" %in% names(trial_level)) {
  trial_level <- trial_level %>%
    mutate(
      hi_grip = case_when(
        effort_condition == "High_40_MVC" ~ TRUE,
        effort_condition == "Low_5_MVC" ~ FALSE,
        TRUE ~ NA
      )
    )
}

# Save TRIALLEVEL
output_triallevel_csv <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_TRIALLEVEL.csv")
output_triallevel_parquet <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_TRIALLEVEL.parquet")

write_csv(trial_level, output_triallevel_csv)
cat("✓ Saved:", output_triallevel_csv, "\n")

if (requireNamespace("arrow", quietly = TRUE)) {
  library(arrow)
  write_parquet(trial_level, output_triallevel_parquet)
  cat("✓ Saved:", output_triallevel_parquet, "\n")
}

# ============================================================================
# Step 4: Validation
# ============================================================================

cat("\nStep 4: Validation Summary\n")
cat("---------------------------\n")

cat("TRIALLEVEL summary:\n")
cat("  - Total trials:", nrow(trial_level), "\n")
cat("  - Unique subjects:", n_distinct(trial_level$subject_id), "\n")
cat("  - Session distribution:\n")
print(table(trial_level$ses, useNA = "ifany"))
cat("  - Run distribution:\n")
print(table(trial_level$run, useNA = "ifany"))
cat("\n  - Trials per subject×task:\n")
trials_per_subj_task <- trial_level %>%
  group_by(subject_id, task) %>%
  summarise(n_trials = n(), .groups = "drop")
cat("    Min:", min(trials_per_subj_task$n_trials), "\n")
cat("    Median:", median(trials_per_subj_task$n_trials), "\n")
cat("    Max:", max(trials_per_subj_task$n_trials), "\n")

# Coverage
coverage_pct <- round(100 * nrow(trial_level) / nrow(ground_truth), 2)
cat("\nCoverage:", coverage_pct, "% (", nrow(trial_level), "/", nrow(ground_truth), ")\n")

cat("\n✓ Rebuild complete with corrected run assignment!\n")

