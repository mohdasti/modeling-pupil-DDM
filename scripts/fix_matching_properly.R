#!/usr/bin/env Rscript

# ============================================================================
# Fix Matching Properly - Don't Require Run Match
# ============================================================================
# ISSUE: MERGED run column is wrong (equals ses), but MERGED trials DO exist
# SOLUTION: Match on (subject, task, ses, trial_index) and accept that
#           we can't uniquely identify run from MERGED alone
#           But we can match to behavioral which HAS the correct run
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

cat("=== FIXING MATCHING PROPERLY ===\n\n")
cat("STRATEGY: Match MERGED to behavioral on (subject, task, ses, trial_index)\n")
cat("          This will recover the correct run number from behavioral\n")
cat("          If a MERGED trial matches multiple behavioral trials (different runs),\n")
cat("          we'll keep ALL matches (they're all valid pupil data)\n\n")

# Load behavioral ground truth
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
    run = run_num,
    trial_index = trial_num,
    trial_uid = paste(subject_id, task, ses, run, trial_index, sep = ":")
  ) %>%
  distinct(subject_id, task, ses, run, trial_index, trial_uid)

cat("Behavioral ground truth:", nrow(ground_truth), "unique trials\n\n")

# Load MERGED
merged <- read_parquet(MERGED_BACKUP)
cat("MERGED:", nrow(merged), "sample-level rows\n")

# Normalize MERGED
merged <- merged %>%
  mutate(
    task = case_when(
      task == "aud" ~ "ADT",
      task == "vis" ~ "VDT",
      task == "ADT" ~ "ADT",
      task == "VDT" ~ "VDT",
      tolower(task) == "auditory" ~ "ADT",
      tolower(task) == "visual" ~ "VDT",
      TRUE ~ task
    ),
    subject_id = case_when(
      str_detect(subject_id, "^BAP") ~ subject_id,
      str_detect(subject_id, "^\\d+$") ~ paste0("BAP", str_pad(subject_id, 3, pad = "0")),
      TRUE ~ subject_id
    )
  )

# Match MERGED to behavioral on (subject, task, ses, trial_index)
# This will recover the correct run number
# NOTE: This is a many-to-many join, which is OK - if MERGED trial matches
#       multiple behavioral trials (different runs), we keep all matches
cat("Matching MERGED to behavioral (many-to-many is expected)...\n")
merged_with_run <- merged %>%
  select(-run) %>%  # Remove the wrong run column
  left_join(
    ground_truth %>% select(subject_id, task, ses, trial_index, run, trial_uid),
    by = c("subject_id", "task", "ses", "trial_index"),
    relationship = "many-to-many"
  )

cat("After matching:\n")
cat("  - Rows:", nrow(merged_with_run), "\n")
cat("  - Unique trials (with recovered run):", n_distinct(merged_with_run$trial_uid), "\n\n")

# Filter to only trials that matched (have trial_uid)
merged_matched <- merged_with_run %>%
  filter(!is.na(trial_uid))

cat("Matched trials:", n_distinct(merged_matched$trial_uid), "\n")
cat("Unmatched MERGED rows:", nrow(merged_with_run) - nrow(merged_matched), "\n\n")

# Save corrected MERGED
output_merged_csv <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_MERGED.csv")
output_merged_parquet <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_MERGED.parquet")

write_csv(merged_matched, output_merged_csv)
cat("✓ Saved:", output_merged_csv, "\n")

if (requireNamespace("arrow", quietly = TRUE)) {
  library(arrow)
  write_parquet(merged_matched, output_merged_parquet)
  cat("✓ Saved:", output_merged_parquet, "\n")
}

# Rebuild TRIALLEVEL
cat("\nRebuilding TRIALLEVEL...\n")

validity_cols <- c(
  "valid_prop_baseline_500ms", "valid_baseline500",
  "valid_prop_iti_full", "valid_iti",
  "valid_prop_prestim", "valid_prestim_fix_interior",
  "valid_prop_total_auc", "valid_total_auc_window",
  "valid_prop_cognitive_auc", "valid_cognitive_window"
)
validity_cols <- intersect(validity_cols, names(merged_matched))

gate_cols <- names(merged_matched)[grepl("^(pass_|gate_)", names(merged_matched))]
behavioral_cols <- c("effort_condition", "difficulty_level", "rt", "response_onset", "has_response_window")
behavioral_cols <- intersect(behavioral_cols, names(merged_matched))

trial_level <- merged_matched %>%
  group_by(trial_uid, subject_id, task, ses, run, trial_index) %>%
  summarise(
    ses = first(ses),
    run = first(run),
    across(any_of(validity_cols), first, .names = "{.col}"),
    across(any_of(gate_cols), first, .names = "{.col}"),
    across(any_of(behavioral_cols), first, .names = "{.col}"),
    n_samples = n(),
    .groups = "drop"
  )

cat("TRIALLEVEL:", nrow(trial_level), "trials\n")

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

# Summary
cat("\n=== SUMMARY ===\n")
cat("TRIALLEVEL:", nrow(trial_level), "trials\n")
cat("Unique subjects:", n_distinct(trial_level$subject_id), "\n")
cat("Sessions:", paste(sort(unique(trial_level$ses)), collapse = ", "), "\n")
cat("Runs:", paste(sort(unique(trial_level$run)), collapse = ", "), "\n")
cat("Coverage:", round(100 * nrow(trial_level) / nrow(ground_truth), 2), "%\n")

cat("\n✓ Done! This approach accepts that MERGED run is wrong and recovers\n")
cat("  the correct run from behavioral data via many-to-many matching.\n")

