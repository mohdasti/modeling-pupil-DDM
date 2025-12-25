#!/usr/bin/env Rscript

# ============================================================================
# Rebuild MERGED and TRIALLEVEL from Behavioral Trial Data Ground Truth
# ============================================================================
# Uses bap_beh_trialdata_v2.csv as the authoritative source for which
# (subject, task, ses, run, trial) combinations are valid
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(stringr)
})

BASE_DIR <- "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM"
BEHAVIORAL_FILE <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"
ANALYSIS_READY_DIR <- file.path(BASE_DIR, "data/analysis_ready")
# Use backup if main file is empty/corrupted
MERGED_FILE <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_MERGED.csv")
MERGED_BACKUP <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_MERGED_scanner_ses23.parquet")

cat("=== REBUILDING FROM BEHAVIORAL TRIAL DATA ===\n\n")

# ============================================================================
# Step 1: Load and understand behavioral trial data
# ============================================================================

cat("Step 1: Loading behavioral trial data (ground truth)\n")
cat("----------------------------------------------------\n")

behavioral <- read_csv(BEHAVIORAL_FILE, show_col_types = FALSE, progress = FALSE)
cat("Loaded", nrow(behavioral), "behavioral trial rows\n")
cat("Columns:", paste(names(behavioral), collapse = ", "), "\n\n")

# Identify key columns
sub_col <- if("sub" %in% names(behavioral)) "sub" else if("subject_id" %in% names(behavioral)) "subject_id" else NULL
task_col <- if("task" %in% names(behavioral)) "task" else if("task_modality" %in% names(behavioral)) "task_modality" else NULL
ses_col <- if("ses" %in% names(behavioral)) "ses" else if("session_num" %in% names(behavioral)) "session_num" else if("session" %in% names(behavioral)) "session" else NULL
run_col <- if("run" %in% names(behavioral)) "run" else if("run_num" %in% names(behavioral)) "run_num" else NULL
trial_col <- if("trial" %in% names(behavioral)) "trial" else if("trial_index" %in% names(behavioral)) "trial_index" else if("trial_num" %in% names(behavioral)) "trial_num" else NULL

cat("Identified columns:\n")
cat("  - Subject:", sub_col, "\n")
cat("  - Task:", task_col, "\n")
cat("  - Session:", ses_col, "\n")
cat("  - Run:", run_col, "\n")
cat("  - Trial:", trial_col, "\n\n")

# Create ground truth lookup
ground_truth <- behavioral %>%
  mutate(
    subject_id = if(!is.null(sub_col)) {
      # Normalize subject IDs (ensure BAP format)
      subj_raw <- .data[[sub_col]]
      case_when(
        str_detect(subj_raw, "^BAP") ~ subj_raw,
        str_detect(subj_raw, "^\\d+$") ~ paste0("BAP", str_pad(subj_raw, 3, pad = "0")),
        TRUE ~ subj_raw
      )
    } else NA_character_,
    task = if(!is.null(task_col)) {
      # Normalize task names
      case_when(
        .data[[task_col]] == "aud" ~ "ADT",
        .data[[task_col]] == "vis" ~ "VDT",
        .data[[task_col]] == "ADT" ~ "ADT",
        .data[[task_col]] == "VDT" ~ "VDT",
        tolower(.data[[task_col]]) == "auditory" ~ "ADT",
        tolower(.data[[task_col]]) == "visual" ~ "VDT",
        TRUE ~ as.character(.data[[task_col]])
      )
    } else NA_character_,
    ses = if(!is.null(ses_col)) as.integer(.data[[ses_col]]) else NA_integer_,
    run = if(!is.null(run_col)) as.integer(.data[[run_col]]) else NA_integer_,
    trial_index = if(!is.null(trial_col)) as.integer(.data[[trial_col]]) else NA_integer_
  ) %>%
  filter(!is.na(subject_id), !is.na(task), !is.na(ses), !is.na(run), !is.na(trial_index)) %>%
  distinct(subject_id, task, ses, run, trial_index) %>%
  mutate(
    trial_uid = paste(subject_id, task, ses, run, trial_index, sep = ":")
  )

# Also create alternative matching keys (without ses, in case MERGED doesn't have ses)
ground_truth_no_ses <- ground_truth %>%
  select(subject_id, task, run, trial_index, ses, trial_uid) %>%
  distinct()

cat("Ground truth summary:\n")
cat("  - Unique (subject×task×ses×run×trial) combinations:", nrow(ground_truth), "\n")
cat("  - Unique subjects:", n_distinct(ground_truth$subject_id), "\n")
cat("  - Unique tasks:", paste(unique(ground_truth$task), collapse = ", "), "\n")
cat("  - Session distribution:\n")
print(table(ground_truth$ses, useNA = "ifany"))
cat("\n")

# ============================================================================
# Step 2: Load MERGED and filter to ground truth
# ============================================================================

cat("Step 2: Filtering MERGED to match behavioral ground truth\n")
cat("----------------------------------------------------------\n")

# Check if MERGED exists and has data, otherwise use backup
if (!file.exists(MERGED_FILE) || file.info(MERGED_FILE)$size < 1000) {
  if (file.exists(MERGED_BACKUP)) {
    cat("MERGED file is empty/corrupted, using backup...\n")
    if (requireNamespace("arrow", quietly = TRUE)) {
      library(arrow)
      merged <- read_parquet(MERGED_BACKUP)
      cat("Loaded", nrow(merged), "sample-level rows from backup\n")
    } else {
      stop("Backup is parquet but arrow package not available")
    }
  } else {
    stop("MERGED file not found and no backup available")
  }
} else {
  cat("Loading MERGED file (this may take a moment)...\n")
  merged <- read_csv(MERGED_FILE, show_col_types = FALSE, progress = FALSE)
  cat("Loaded", nrow(merged), "sample-level rows\n")
}

# Ensure MERGED has the necessary columns and create trial_uid
# First check if ses column exists (it should be in the backup)
# If not, we'll extract from trial_id or match with ground truth
if (!"ses" %in% names(merged) || all(is.na(merged$ses))) {
  # Try to extract from trial_id or match with ground truth
  if ("trial_id" %in% names(merged)) {
    # Parse trial_id format
    sample_trial_id <- merged$trial_id[1]
    trial_id_parts <- str_split(sample_trial_id, ":", simplify = TRUE)
    n_parts <- ncol(trial_id_parts)
    
    if (n_parts >= 5) {
      # Format: subject:task:ses:run:trial_index
      merged <- merged %>%
        mutate(
          subject_id = str_split(trial_id, ":", simplify = TRUE)[, 1],
          task = str_split(trial_id, ":", simplify = TRUE)[, 2],
          ses = as.integer(str_split(trial_id, ":", simplify = TRUE)[, 3]),
          run = as.integer(str_split(trial_id, ":", simplify = TRUE)[, 4]),
          trial_index = as.integer(str_split(trial_id, ":", simplify = TRUE)[, 5]),
          trial_uid = trial_id
        )
    } else if (n_parts == 4) {
      # Format: subject:task:run:trial_index (no ses)
      # Need to match with ground truth to get ses
      merged <- merged %>%
        mutate(
          subject_id_raw = str_split(trial_id, ":", simplify = TRUE)[, 1],
          task_raw = str_split(trial_id, ":", simplify = TRUE)[, 2],
          run = as.integer(str_split(trial_id, ":", simplify = TRUE)[, 3]),
          trial_index = as.integer(str_split(trial_id, ":", simplify = TRUE)[, 4]),
          # Normalize subject_id and task
          subject_id = case_when(
            str_detect(subject_id_raw, "^BAP") ~ subject_id_raw,
            str_detect(subject_id_raw, "^\\d+$") ~ paste0("BAP", str_pad(subject_id_raw, 3, pad = "0")),
            TRUE ~ subject_id_raw
          ),
          task = case_when(
            task_raw == "aud" ~ "ADT",
            task_raw == "vis" ~ "VDT",
            task_raw == "ADT" ~ "ADT",
            task_raw == "VDT" ~ "VDT",
            tolower(task_raw) == "auditory" ~ "ADT",
            tolower(task_raw) == "visual" ~ "VDT",
            TRUE ~ task_raw
          )
        ) %>%
        left_join(
          ground_truth_no_ses,
          by = c("subject_id", "task", "run", "trial_index")
        ) %>%
        mutate(
          trial_uid = ifelse(is.na(trial_uid), 
                            paste(subject_id, task, ses, run, trial_index, sep = ":"),
                            trial_uid)
        )
    } else {
      stop("Cannot parse trial_id format - unexpected number of parts: ", n_parts)
    }
  } else if (all(c("subject_id", "task", "run", "trial_index") %in% names(merged))) {
    # No trial_id - match with ground truth to get ses
    merged <- merged %>%
      left_join(
        ground_truth %>% select(subject_id, task, run, trial_index, ses),
        by = c("subject_id", "task", "run", "trial_index")
      ) %>%
      mutate(
        trial_uid = paste(subject_id, task, ses, run, trial_index, sep = ":")
      )
  } else {
    stop("Cannot create trial_uid from MERGED - missing required columns")
  }
} else {
  # ses column exists - ensure it's properly set and create trial_uid
  if (!"trial_uid" %in% names(merged)) {
    if (all(c("subject_id", "task", "ses", "run", "trial_index") %in% names(merged))) {
      # Normalize subject_id and task to match ground truth format
      merged <- merged %>%
        mutate(
          subject_id = case_when(
            str_detect(subject_id, "^BAP") ~ subject_id,
            str_detect(subject_id, "^\\d+$") ~ paste0("BAP", str_pad(subject_id, 3, pad = "0")),
            TRUE ~ subject_id
          ),
          task = case_when(
            task == "aud" ~ "ADT",
            task == "vis" ~ "VDT",
            task == "ADT" ~ "ADT",
            task == "VDT" ~ "VDT",
            tolower(task) == "auditory" ~ "ADT",
            tolower(task) == "visual" ~ "VDT",
            TRUE ~ task
          ),
          trial_uid = paste(subject_id, task, ses, run, trial_index, sep = ":")
        )
    } else if ("trial_id" %in% names(merged)) {
      # If trial_id exists but we have ses column, create proper trial_uid
      if ("ses" %in% names(merged) && all(c("subject_id", "task", "run", "trial_index") %in% names(merged))) {
        merged <- merged %>%
          mutate(
            subject_id = case_when(
              str_detect(subject_id, "^BAP") ~ subject_id,
              str_detect(subject_id, "^\\d+$") ~ paste0("BAP", str_pad(subject_id, 3, pad = "0")),
              TRUE ~ subject_id
            ),
            task = case_when(
              task == "aud" ~ "ADT",
              task == "vis" ~ "VDT",
              task == "ADT" ~ "ADT",
              task == "VDT" ~ "VDT",
              tolower(task) == "auditory" ~ "ADT",
              tolower(task) == "visual" ~ "VDT",
              TRUE ~ task
            ),
            trial_uid = paste(subject_id, task, ses, run, trial_index, sep = ":")
          )
      } else {
        merged <- merged %>%
          mutate(trial_uid = trial_id)
      }
    } else {
      stop("Cannot create trial_uid - missing required columns")
    }
  } else {
    # trial_uid exists but may need normalization - ensure subject_id and task match ground truth
    merged <- merged %>%
      mutate(
        subject_id = case_when(
          str_detect(subject_id, "^BAP") ~ subject_id,
          str_detect(subject_id, "^\\d+$") ~ paste0("BAP", str_pad(subject_id, 3, pad = "0")),
          TRUE ~ subject_id
        ),
        task = case_when(
          task == "aud" ~ "ADT",
          task == "vis" ~ "VDT",
          task == "ADT" ~ "ADT",
          task == "VDT" ~ "VDT",
          tolower(task) == "auditory" ~ "ADT",
          tolower(task) == "visual" ~ "VDT",
          TRUE ~ task
        )
      ) %>%
      # Recreate trial_uid with normalized values
      mutate(
        trial_uid = paste(subject_id, task, ses, run, trial_index, sep = ":")
      )
  }
}

# Filter MERGED to only include trials in ground truth
merged_filtered <- merged %>%
  filter(trial_uid %in% ground_truth$trial_uid)

cat("Filtered MERGED:\n")
cat("  - Original rows:", nrow(merged), "\n")
cat("  - Filtered rows:", nrow(merged_filtered), "\n")
cat("  - Removed:", nrow(merged) - nrow(merged_filtered), "rows\n")
cat("  - Unique trials in filtered:", n_distinct(merged_filtered$trial_uid), "\n\n")

# Save filtered MERGED
output_merged_csv <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_MERGED.csv")
output_merged_parquet <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_MERGED.parquet")

write_csv(merged_filtered, output_merged_csv)
cat("✓ Saved:", output_merged_csv, "\n")

if (requireNamespace("arrow", quietly = TRUE)) {
  library(arrow)
  write_parquet(merged_filtered, output_merged_parquet)
  cat("✓ Saved:", output_merged_parquet, "\n")
}

cat("\n")

# ============================================================================
# Step 3: Rebuild TRIALLEVEL from filtered MERGED
# ============================================================================

cat("Step 3: Rebuilding TRIALLEVEL from filtered MERGED\n")
cat("---------------------------------------------------\n")

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

cat("Aggregating to trial level...\n")
cat("  - Validity columns:", length(validity_cols), "\n")
cat("  - Gate columns:", length(gate_cols), "\n")
cat("  - Behavioral columns:", length(behavioral_cols), "\n")

trial_level <- merged_filtered %>%
  group_by(trial_uid, subject_id, task, ses, run, trial_index) %>%
  summarise(
    ses = first(ses),
    across(any_of(validity_cols), first, .names = "{.col}"),
    across(any_of(gate_cols), first, .names = "{.col}"),
    across(any_of(behavioral_cols), first, .names = "{.col}"),
    n_samples = n(),
    .groups = "drop"
  )

cat("Aggregated to", nrow(trial_level), "trials\n")

# Verify we have all ground truth trials
trials_in_triallevel <- unique(trial_level$trial_uid)
trials_in_ground_truth <- unique(ground_truth$trial_uid)

missing_trials <- setdiff(trials_in_ground_truth, trials_in_triallevel)
cat("\nTrial coverage:\n")
cat("  - Ground truth trials:", length(trials_in_ground_truth), "\n")
cat("  - Trials with pupil data:", length(trials_in_triallevel), "\n")
cat("  - Missing trials (no pupil data):", length(missing_trials), "\n")
cat("  - Coverage:", round(100 * length(trials_in_triallevel) / length(trials_in_ground_truth), 1), "%\n\n")

# Recompute gates at threshold 0.80
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
    
    # Recompute gates
    pass_stimlocked_t080 = (valid_iti >= DISSERTATION_THRESHOLD & 
                             valid_prestim_fix_interior >= DISSERTATION_THRESHOLD),
    pass_total_auc_t080 = (valid_total_auc_window >= DISSERTATION_THRESHOLD),
    pass_cog_auc_t080 = (valid_baseline500 >= DISSERTATION_THRESHOLD & 
                         valid_cognitive_window >= DISSERTATION_THRESHOLD)
  )

# Add oddball and hi_grip flags
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
cat("  Rows:", nrow(trial_level), "\n")
cat("  Columns:", ncol(trial_level), "\n\n")

if (requireNamespace("arrow", quietly = TRUE)) {
  library(arrow)
  write_parquet(trial_level, output_triallevel_parquet)
  cat("✓ Saved:", output_triallevel_parquet, "\n\n")
}

# ============================================================================
# Step 4: Validation Summary
# ============================================================================

cat("Step 4: Validation Summary\n")
cat("---------------------------\n")

cat("Session distribution in TRIALLEVEL:\n")
print(table(trial_level$ses, useNA = "ifany"))

cat("\nTrials per subject×task:\n")
trials_per_subj_task <- trial_level %>%
  group_by(subject_id, task) %>%
  summarise(n_trials = n(), .groups = "drop")

cat("  - Min:", min(trials_per_subj_task$n_trials), "\n")
cat("  - Median:", median(trials_per_subj_task$n_trials), "\n")
cat("  - Max:", max(trials_per_subj_task$n_trials), "\n")

cat("\nUnique subjects:", n_distinct(trial_level$subject_id), "\n")
cat("Total trials:", nrow(trial_level), "\n")

cat("\n✓ Dataset rebuild complete!\n")
cat("\nOutput files:\n")
cat("  -", output_merged_csv, "\n")
if (file.exists(output_merged_parquet)) {
  cat("  -", output_merged_parquet, "\n")
}
cat("  -", output_triallevel_csv, "\n")
if (file.exists(output_triallevel_parquet)) {
  cat("  -", output_triallevel_parquet, "\n")
}

