#!/usr/bin/env Rscript

# ============================================================================
# Pupil Trial Coverage (Pre-Filter) Builder
# ============================================================================
# Goal:
#   - Inspect sample-level merged flat files *before* any 0.80 validity filtering
#   - Quantify, per trial, how much of each analysis-relevant window is usable
#   - Provide a threshold sweep across multiple validity cutoffs for different
#     analysis "intents" (gates A/B/C)
# Outputs:
#   1) data/qc/pupil_trial_coverage_prefilter.csv
#   2) data/qc/pupil_threshold_sweep.csv
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(tidyr)
})

cat("=== BUILD PUPIL TRIAL COVERAGE (PREFILTER) ===\n")
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# ============================================================================
# CONFIGURATION
# ============================================================================

processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
behavioral_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"

qc_dir <- "data/qc"
dir.create(qc_dir, recursive = TRUE, showWarnings = FALSE)

coverage_file <- file.path(qc_dir, "pupil_trial_coverage_prefilter.csv")
threshold_sweep_file <- file.path(qc_dir, "pupil_threshold_sweep.csv")

# ============================================================================
# 1. DISCOVER MERGED FLAT FILES
# ============================================================================

cat("1. Discovering merged flat files...\n")

flat_files_merged <- list.files(processed_dir, pattern = "_flat_merged\\.csv$", full.names = TRUE)
flat_files_reg    <- list.files(processed_dir, pattern = "_flat\\.csv$",        full.names = TRUE)

if (length(flat_files_merged) == 0) {
  cat("  ⚠ No *_flat_merged.csv files found in:\n")
  cat("    ", processed_dir, "\n")
  cat("  Falling back to regular *_flat.csv files (no behavioral merge).\n")
  flat_files <- flat_files_reg
} else {
  flat_files <- flat_files_merged
}

if (length(flat_files) == 0) {
  stop("ERROR: No flat files found in ", processed_dir)
}

cat("  Using", length(flat_files), "file(s) for coverage analysis\n\n")

# ============================================================================
# 2. HELPER FUNCTIONS
# ============================================================================

prop_valid_window <- function(time, pupil, start, end) {
  idx <- !is.na(pupil) & !is.na(time) & time >= start & time <= end
  if (!any(time >= start & time <= end, na.rm = TRUE)) {
    return(NA_real_)
  }
  if (!any(idx, na.rm = TRUE)) {
    # There are samples in the window but all invalid
    return(0)
  }
  # Denominator = all samples in window (valid + invalid)
  denom_idx <- !is.na(time) & time >= start & time <= end
  mean(!is.na(pupil[denom_idx]))
}

safe_first <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) NA else x[1]
}

map_task <- function(task, task_modality = NULL) {
  if (!is.null(task) && "task" %in% names(task)) {
    return(task)
  }
  if (!is.null(task_modality)) {
    dplyr::case_when(
      task_modality == "aud" ~ "ADT",
      task_modality == "vis" ~ "VDT",
      TRUE ~ task_modality
    )
  } else {
    task
  }
}

# ============================================================================
# 3. LOAD BEHAVIORAL DATA (FOR EXPECTED TRIAL COUNTS)
# ============================================================================

cat("2. Loading behavioral data (for expected trial counts)...\n")

if (!file.exists(behavioral_file)) {
  cat("  ⚠ Behavioral file not found at:\n")
  cat("    ", behavioral_file, "\n")
  cat("  Continuing without behavioral expectations.\n\n")
  behavioral_data_per_trial <- NULL
} else {
  behavioral_data_raw <- read_csv(behavioral_file, show_col_types = FALSE)

  behavioral_data_per_trial <- behavioral_data_raw %>%
    mutate(
      sub = if ("sub" %in% names(.)) sub else if ("subject_id" %in% names(.)) as.character(subject_id) else NA_character_,
      task = if ("task" %in% names(.)) {
        dplyr::if_else(task == "aud", "ADT",
                       dplyr::if_else(task == "vis", "VDT", as.character(task)))
      } else if ("task_modality" %in% names(.)) {
        dplyr::case_when(
          task_modality == "aud" ~ "ADT",
          task_modality == "vis" ~ "VDT",
          TRUE ~ as.character(task_modality)
        )
      } else NA_character_,
      run = if ("run" %in% names(.)) run else if ("run_num" %in% names(.)) run_num else NA_integer_,
      trial_index = if ("trial_in_run" %in% names(.)) trial_in_run
      else if ("trial" %in% names(.)) trial
      else if ("trial_num" %in% names(.)) trial_num
      else NA_integer_,
      rt = if ("rt" %in% names(.)) rt else if ("resp1RT" %in% names(.)) resp1RT else if ("same_diff_resp_secs" %in% names(.)) same_diff_resp_secs else NA_real_,
      # Extract event timestamps from behavioral log (relative to TrialST = 0)
      fixST = if ("fixST" %in% names(.)) as.numeric(fixST) else NA_real_,
      fixOFSTP = if ("fixOFSTP" %in% names(.)) as.numeric(fixOFSTP) else NA_real_,
      A_V_ST = if ("A/V_ST" %in% names(.)) as.numeric(`A/V_ST`) else NA_real_
    ) %>%
    filter(!is.na(sub), !is.na(task), !is.na(run), !is.na(trial_index)) %>%
    transmute(
      subject_id = as.character(sub),
      task,
      run,
      trial_index,
      rt,
      fixST,
      fixOFSTP,
      A_V_ST
    )

  cat("  Behavioral trials loaded:", nrow(behavioral_data_per_trial), "\n\n")
}

# ============================================================================
# 4. LOAD MERGED FLAT FILES AND BUILD TRIAL-LEVEL COVERAGE
# ============================================================================

cat("3. Loading merged flat files and computing coverage...\n")

trial_coverage_list <- map(flat_files, function(f) {
  cat("  Reading:", basename(f), "\n")
  df <- read_csv(f, show_col_types = FALSE, progress = FALSE)

  # Ensure mandatory columns exist
  required_cols <- c("time", "pupil")
  missing_req <- setdiff(required_cols, names(df))
  if (length(missing_req) > 0) {
    cat("    ⚠ Skipping file (missing columns):", paste(missing_req, collapse = ", "), "\n")
    return(NULL)
  }

  # Derive identifiers / behavioral mapping if necessary
  df <- df %>%
    mutate(
      sub = if ("sub" %in% names(.)) sub else if ("subject_id" %in% names(.)) as.character(subject_id) else NA_character_,
      task = if ("task" %in% names(.)) {
        dplyr::if_else(task == "aud", "ADT",
                       dplyr::if_else(task == "vis", "VDT", as.character(task)))
      } else if ("task_modality" %in% names(.)) {
        dplyr::case_when(
          task_modality == "aud" ~ "ADT",
          task_modality == "vis" ~ "VDT",
          TRUE ~ as.character(task_modality)
        )
      } else NA_character_,
      run = if ("run" %in% names(.)) run else if ("run_num" %in% names(.)) run_num else NA_integer_,
      trial_index = if ("trial_index" %in% names(.)) trial_index
      else if ("trial_in_run" %in% names(.)) trial_in_run
      else if ("trial" %in% names(.)) trial
      else if ("trial_num" %in% names(.)) trial_num
      else NA_integer_,
      gf_trPer = dplyr::coalesce(
        if ("gf_trPer" %in% names(.)) gf_trPer else NA_real_,
        if ("grip_targ_prop_mvc" %in% names(.)) grip_targ_prop_mvc else NA_real_
      ),
      stimLev = if ("stimLev" %in% names(.)) stimLev else if ("stim_level_index" %in% names(.)) stim_level_index else NA_real_,
      isOddball = if ("isOddball" %in% names(.)) isOddball else if ("stim_is_diff" %in% names(.)) as.integer(stim_is_diff) else NA_integer_,
      resp1RT = if ("resp1RT" %in% names(.)) resp1RT else NA_real_
    ) %>%
    filter(!is.na(sub), !is.na(task), !is.na(run), !is.na(trial_index))

  if (nrow(df) == 0) {
    cat("    ⚠ No valid rows after identifier mapping, skipping\n")
    return(NULL)
  }

  # Merge behavioral event timestamps (fixST, fixOFSTP, A/V_ST) with pupil data
  if (!is.null(behavioral_data_per_trial) && "fixST" %in% names(behavioral_data_per_trial)) {
    df <- df %>%
      left_join(
        behavioral_data_per_trial %>% 
          select(subject_id, task, run, trial_index, fixST, fixOFSTP, A_V_ST),
        by = c("sub" = "subject_id", "task", "run", "trial_index")
      )
  } else {
    # If behavioral data not available, add NA columns
    df$fixST <- NA_real_
    df$fixOFSTP <- NA_real_
    df$A_V_ST <- NA_real_
  }

  # PROMPT 3: Compute event-relative timestamps per trial
  # Time is already relative to TrialST (grip gauge onset = 0)
  # Use actual fixST and A/V_ST from behavioral log if available
  # Otherwise fall back to trial_label detection or canonical offsets
  df_with_events <- df %>%
    group_by(sub, task, run, trial_index) %>%
    mutate(
      # Use fixST from behavioral log if available, otherwise detect from trial_label
      fixation_onset = if (!is.na(safe_first(fixST))) {
        safe_first(fixST)
      } else if ("trial_label" %in% names(df)) {
        fix_times <- time[trial_label == "Pre_Stimulus_Fixation" | 
                         (is.na(trial_label) & time >= 3.20 & time <= 3.30)]
        if (length(fix_times) > 0) min(fix_times, na.rm = TRUE) else 3.25
      } else {
        # Fallback: use canonical offset
        3.25
      },
      # Use A/V_ST from behavioral log if available, otherwise detect from trial_label
      stimulus_onset = if (!is.na(safe_first(A_V_ST))) {
        safe_first(A_V_ST)
      } else if ("trial_label" %in% names(df)) {
        stim_times <- time[trial_label == "Stimulus" | 
                          (is.na(trial_label) & time >= 3.70 & time <= 3.80)]
        if (length(stim_times) > 0) min(stim_times, na.rm = TRUE) else 3.75
      } else {
        # Fallback: use canonical offset
        3.75
      }
    ) %>%
    ungroup()

  # Trial-level coverage
  df_with_events %>%
    group_by(sub, task, run, trial_index) %>%
    summarise(
      subject_id = safe_first(as.character(sub)),
      task = safe_first(as.character(task)),
      run = safe_first(run),
      trial_index = safe_first(trial_index),

      # ---- Basic flags ----
      has_any_pupil = any(!is.na(pupil)),

      # Response onset for QC purposes
      rt = safe_first(resp1RT),
      response_onset = {
        rt_val <- safe_first(resp1RT)
        if (!is.na(rt_val) && rt_val > 0 && rt_val < 5.0) {
          4.7 + rt_val
        } else {
          7.7
        }
      },
      
      # PROMPT 3: Event-relative timestamps (per trial)
      fixation_onset_trial = safe_first(fixation_onset),
      stimulus_onset_trial = safe_first(stimulus_onset),
      
      # PROMPT 3: Event-relative prestim window (fixation interior, avoiding boundaries)
      # prestim = [fixST + 0.10, fixOFSTP - 0.10] to avoid blink/flip hotspots at boundaries
      prestim_start = safe_first(fixation_onset) + 0.10,
      prestim_end = {
        # Use fixOFSTP from behavioral log if available, otherwise use stimulus_onset - 0.10
        fixOFSTP_val <- safe_first(fixOFSTP)
        if (!is.na(fixOFSTP_val)) {
          fixOFSTP_val - 0.10
        } else {
          safe_first(stimulus_onset) - 0.10
        }
      },

      # ---- Phase validity (fixed windows) ----
      valid_iti       = prop_valid_window(time, pupil, -3.0,  0.0),
      # OLD: valid_prestim = prop_valid_window(time, pupil, 3.25, 3.75),
      # NEW (PROMPT 3): Event-relative prestim window
      valid_prestim_old = prop_valid_window(time, pupil, 3.25, 3.75),
      valid_prestim = {
        # Use the computed prestim_start and prestim_end (fixation interior)
        prestim_start_val <- safe_first(prestim_start)
        prestim_end_val <- safe_first(prestim_end)
        if (!is.na(prestim_start_val) && !is.na(prestim_end_val) && prestim_end_val > prestim_start_val) {
          prop_valid_window(time, pupil, prestim_start_val, prestim_end_val)
        } else {
          # Fallback to canonical if events not detected
          prop_valid_window(time, pupil, 3.25, 3.75)
        }
      },
      valid_stim      = prop_valid_window(time, pupil,  3.75, 4.45),
      valid_poststim  = prop_valid_window(time, pupil,  4.45, 4.70),
      valid_response  = prop_valid_window(time, pupil,  4.70, 7.70),

      # ---- Analysis windows ----
      valid_baseline500        = prop_valid_window(time, pupil, -0.5, 0.0),
      valid_total_auc_window   = prop_valid_window(time, pupil,  0.0, response_onset),
      valid_cognitive_window   = prop_valid_window(time, pupil,  4.65, response_onset),

      # coverage to response
      last_valid_time = {
        tv <- time[!is.na(pupil)]
        if (length(tv) == 0) NA_real_ else max(tv, na.rm = TRUE)
      },
      covers_to_response = !is.na(last_valid_time) & !is.na(response_onset) &
        last_valid_time >= (response_onset - 0.05),

      # Effort condition
      effort_condition = factor(dplyr::case_when(
        gf_trPer == 0.05 ~ "Low_5_MVC",
        gf_trPer == 0.40 ~ "High_40_MVC",
        TRUE ~ NA_character_
      ), levels = c("Low_5_MVC", "High_40_MVC")),

      # Difficulty level (Standard, Easy, Hard)
      difficulty_level = factor(dplyr::case_when(
        isOddball == 0 ~ "Standard",
        isOddball == 1 & stimLev %in% c(8, 16, 0.06, 0.12) ~ "Hard",
        isOddball == 1 & stimLev %in% c(32, 64, 0.24, 0.48) ~ "Easy",
        stimLev %in% c(8, 16, 0.06, 0.12) ~ "Hard",
        stimLev %in% c(32, 64, 0.24, 0.48) ~ "Easy",
        TRUE ~ NA_character_
      ), levels = c("Standard", "Easy", "Hard")),

      .groups = "drop"
    ) %>%
    mutate(
      # Salvage flag at default 0.80 threshold:
      salvage_cognitive_ok_total_fail = ifelse(
        !is.na(valid_cognitive_window) & !is.na(valid_baseline500) & !is.na(valid_total_auc_window),
        valid_cognitive_window >= 0.80 & valid_baseline500 >= 0.80 & valid_total_auc_window < 0.80,
        FALSE
      )
    )
})

trial_coverage <- bind_rows(trial_coverage_list)

if (nrow(trial_coverage) == 0) {
  stop("ERROR: No trial-level coverage rows produced. Check input files.")
}

cat("\n  Trial-level rows:", nrow(trial_coverage), "\n")
cat("  Unique subjects:", length(unique(trial_coverage$subject_id)), "\n\n")

# ============================================================================
# 5. MERGE EXPECTED BEHAVIORAL COUNTS (IF AVAILABLE)
# ============================================================================

if (!is.null(behavioral_data_per_trial)) {
  expected_trials <- behavioral_data_per_trial %>%
    group_by(subject_id, task) %>%
    summarise(expected_trials = n(), .groups = "drop")

  trial_coverage <- trial_coverage %>%
    left_join(expected_trials, by = c("subject_id", "task"))
} else {
  trial_coverage$expected_trials <- NA_integer_
}

# ============================================================================
# 6. ADD TRIAL UID AND ANALYSIS GATES
# ============================================================================

cat("4. Adding trial UID and analysis gates...\n")

# Function to add trial UID and analysis-specific gates (independent, not nested)
add_analysis_gates <- function(df, threshold, config = NULL) {
  # Ensure trial_uid exists (create if missing)
  if (!"trial_uid" %in% names(df)) {
    df <- df %>%
      mutate(
        trial_uid = paste(
          subject_id,
          task,
          if ("session" %in% names(.)) coalesce(as.character(session), "NA") else "NA",
          run,
          trial_index,
          sep = "_"
        )
      )
  }
  
  # Ensure valid_prestim_fix_interior exists (use valid_prestim as alias if needed)
  if (!"valid_prestim_fix_interior" %in% names(df) && "valid_prestim" %in% names(df)) {
    df$valid_prestim_fix_interior <- df$valid_prestim
  }
  
  df <- df %>%
    mutate(
      # Independent analysis gates (NOT nested)
      # Gate for stimulus-locked analyses (baseline + prestim fixation interior)
      # valid_prestim_fix_interior is event-relative: [fixST+0.10, fixOFSTP-0.10]
      gate_stimlocked = !is.na(valid_baseline500) & !is.na(valid_prestim_fix_interior) &
        valid_baseline500 >= threshold & valid_prestim_fix_interior >= threshold,
      # Gate for total AUC analyses (includes baseline for correction)
      gate_total_auc = !is.na(valid_baseline500) & !is.na(valid_total_auc_window) &
        valid_baseline500 >= threshold & valid_total_auc_window >= threshold,
      # Gate for cognitive AUC analyses (includes baseline for correction)
      gate_cog_auc = !is.na(valid_cognitive_window) & !is.na(valid_baseline500) &
        valid_cognitive_window >= threshold & valid_baseline500 >= threshold,
      # Threshold used
      gate_threshold = threshold
    )
  return(df)
}

# Add trial_uid and alias for prestim window to trial_coverage
trial_coverage <- trial_coverage %>%
  mutate(
    trial_uid = paste(
      subject_id,
      task,
      if ("session" %in% names(.)) coalesce(as.character(session), "NA") else "NA",
      run,
      trial_index,
      sep = "_"
    ),
    # Alias for clarity: valid_prestim is already event-relative (fixST+0.10 to fixOFSTP-0.10)
    valid_prestim_fix_interior = valid_prestim
  )

cat("  ✓ Added trial_uid to trial coverage\n")
cat("  Unique trial UIDs:", n_distinct(trial_coverage$trial_uid), "\n\n")

# ============================================================================
# 7. SAVE TRIAL-LEVEL COVERAGE
# ============================================================================

write_csv(trial_coverage, coverage_file)
cat("  ✓ Saved trial coverage to:", coverage_file, "\n\n")

# ============================================================================
# 8. THRESHOLD SWEEP (ANALYSIS-SPECIFIC GATES)
# ============================================================================

cat("5. Computing threshold sweep with analysis-specific gates...\n")

thresholds <- c(0.60, 0.70, 0.80, 0.85, 0.90, 0.95)

# Compute gates for each threshold
gate_sweep_list <- map(thresholds, function(thresh) {
  add_analysis_gates(trial_coverage, thresh) %>%
    select(trial_uid, subject_id, task, effort_condition, difficulty_level,
           gate_stimlocked, gate_total_auc, gate_cog_auc, gate_threshold)
})

gate_sweep <- bind_rows(gate_sweep_list)

# Trial-level summary by threshold (using n_distinct on trial_uid)
trial_summary <- gate_sweep %>%
  group_by(gate_threshold) %>%
  summarise(
    n_trials_stimlocked = n_distinct(trial_uid[gate_stimlocked]),
    n_trials_total_auc = n_distinct(trial_uid[gate_total_auc]),
    n_trials_cog_auc = n_distinct(trial_uid[gate_cog_auc]),
    .groups = "drop"
  ) %>%
  rename(threshold = gate_threshold)

# Subject-level pass rates per gate
subject_summary <- gate_sweep %>%
  group_by(subject_id, task, gate_threshold) %>%
  summarise(
    n_trials_total = n_distinct(trial_uid),
    n_trials_stimlocked = n_distinct(trial_uid[gate_stimlocked]),
    n_trials_total_auc = n_distinct(trial_uid[gate_total_auc]),
    n_trials_cog_auc = n_distinct(trial_uid[gate_cog_auc]),
    pct_stimlocked = n_trials_stimlocked / n_trials_total * 100,
    pct_total_auc = n_trials_total_auc / n_trials_total * 100,
    pct_cog_auc = n_trials_cog_auc / n_trials_total * 100,
    .groups = "drop"
  ) %>%
  rename(threshold = gate_threshold)

# Legacy format (deprecated) for backwards compatibility
threshold_sweep_legacy <- gate_sweep %>%
  mutate(
    # DEPRECATED: Old nested gate system (kept for backwards compatibility)
    gate_A = gate_stimlocked,  # Approximate mapping
    gate_B = gate_total_auc,
    gate_C = gate_cog_auc,
    threshold = gate_threshold  # Rename for legacy format
  ) %>%
  pivot_longer(
    cols = c(gate_A, gate_B, gate_C),
    names_to = "gate",
    values_to = "retain"
  ) %>%
  group_by(subject_id, task, effort_condition, difficulty_level, threshold, gate) %>%
  summarise(
    n_trials_retained = sum(retain, na.rm = TRUE),
    .groups = "drop"
  )

# Save new format
write_csv(trial_summary, file.path(qc_dir, "gate_trial_summary.csv"))
cat("  ✓ Saved trial-level gate summary to: data/qc/gate_trial_summary.csv\n")

write_csv(subject_summary, file.path(qc_dir, "gate_subject_summary.csv"))
cat("  ✓ Saved subject-level gate summary to: data/qc/gate_subject_summary.csv\n")

# Save legacy format (deprecated)
write_csv(threshold_sweep_legacy, threshold_sweep_file)
cat("  ✓ Saved legacy threshold sweep (DEPRECATED) to:", threshold_sweep_file, "\n\n")

# ============================================================================
# GATE SUBSET VALIDATION (DEPRECATED - gates are now independent)
# ============================================================================

cat("6. Validating gate relationships (NOTE: New gates are independent, not nested)...\n")

thresholds <- c(0.60, 0.70, 0.80, 0.85, 0.90, 0.95)

# Since gates are now independent, we validate that they don't have unexpected relationships
gate_subset_validation <- map_dfr(thresholds, function(thresh) {
  # Compute gates using the new function
  gate_trials <- add_analysis_gates(trial_coverage, thresh) %>%
    select(trial_uid, gate_stimlocked, gate_total_auc, gate_cog_auc)
  
  # Get trial UID sets
  trials_stimlocked <- gate_trials %>% filter(gate_stimlocked) %>% pull(trial_uid)
  trials_total_auc <- gate_trials %>% filter(gate_total_auc) %>% pull(trial_uid)
  trials_cog_auc <- gate_trials %>% filter(gate_cog_auc) %>% pull(trial_uid)
  
  # Compute set sizes (using n_distinct for trial_uid)
  size_stimlocked <- length(unique(trials_stimlocked))
  size_total_auc <- length(unique(trials_total_auc))
  size_cog_auc <- length(unique(trials_cog_auc))
  
  # Compute overlaps (for information, not violations since gates are independent)
  total_auc_minus_stimlocked <- setdiff(trials_total_auc, trials_stimlocked)
  cog_auc_minus_total_auc <- setdiff(trials_cog_auc, trials_total_auc)
  cog_auc_minus_stimlocked <- setdiff(trials_cog_auc, trials_stimlocked)
  
  size_total_auc_minus_stimlocked <- length(unique(total_auc_minus_stimlocked))
  size_cog_auc_minus_total_auc <- length(unique(cog_auc_minus_total_auc))
  size_cog_auc_minus_stimlocked <- length(unique(cog_auc_minus_stimlocked))
  
  tibble(
    threshold = thresh,
    size_stimlocked = size_stimlocked,
    size_total_auc = size_total_auc,
    size_cog_auc = size_cog_auc,
    size_total_auc_minus_stimlocked = size_total_auc_minus_stimlocked,
    size_cog_auc_minus_total_auc = size_cog_auc_minus_total_auc,
    size_cog_auc_minus_stimlocked = size_cog_auc_minus_stimlocked,
    note = "Gates are independent (not nested) - overlaps are informational only"
  )
})

# Print validation table
cat("\n  Gate Relationship Summary (Independent Gates):\n")
print(gate_subset_validation)

cat("\n  Note: Analysis gates are independent (not nested).\n")
cat("  Overlaps shown are informational only.\n")

# Save validation results
gate_subset_file <- file.path(qc_dir, "gate_relationship_summary.csv")
write_csv(gate_subset_validation, gate_subset_file)
cat("\n  ✓ Saved gate relationship summary to:", gate_subset_file, "\n\n")

# ============================================================================
# PROMPT 3: COMPARE OLD vs NEW PRESTIM WINDOW (GATE A RETENTION)
# ============================================================================

cat("6. Comparing old vs new prestim window definition (Gate A retention)...\n")

if (nrow(trial_coverage) > 0 && "valid_prestim_old" %in% names(trial_coverage)) {
  # Compute Gate A retention with both definitions
  gate_a_comparison <- tidyr::crossing(
    trial_coverage %>%
      select(subject_id, task, effort_condition, difficulty_level,
             valid_iti, valid_prestim, valid_prestim_old, valid_baseline500),
    threshold = c(0.60, 0.70, 0.80, 0.85, 0.90)
  ) %>%
    mutate(
      gate_A_old = !is.na(valid_iti) & !is.na(valid_prestim_old) &
        valid_iti >= threshold & valid_prestim_old >= threshold,
      gate_A_new = !is.na(valid_iti) & !is.na(valid_prestim) &
        valid_iti >= threshold & valid_prestim >= threshold
    ) %>%
    group_by(threshold) %>%
    summarise(
      n_trials_old = sum(gate_A_old, na.rm = TRUE),
      n_trials_new = sum(gate_A_new, na.rm = TRUE),
      n_trials_recovered = sum(gate_A_new & !gate_A_old, na.rm = TRUE),
      n_trials_lost = sum(gate_A_old & !gate_A_new, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      pct_recovered = round(100 * n_trials_recovered / pmax(n_trials_old, 1), 1),
      pct_lost = round(100 * n_trials_lost / pmax(n_trials_old, 1), 1)
    )
  
  cat("\n  Gate A Retention Comparison (Old vs Event-Relative Prestim):\n")
  print(gate_a_comparison)
  
  # Subject-level recovery
  subject_recovery <- tidyr::crossing(
    trial_coverage %>%
      select(subject_id, task, valid_iti, valid_prestim, valid_prestim_old, valid_baseline500),
    threshold = 0.80
  ) %>%
    mutate(
      gate_A_old = !is.na(valid_iti) & !is.na(valid_prestim_old) &
        valid_iti >= threshold & valid_prestim_old >= threshold,
      gate_A_new = !is.na(valid_iti) & !is.na(valid_prestim) &
        valid_iti >= threshold & valid_prestim >= threshold
    ) %>%
    group_by(subject_id, task) %>%
    summarise(
      n_trials_old = sum(gate_A_old, na.rm = TRUE),
      n_trials_new = sum(gate_A_new, na.rm = TRUE),
      n_recovered = sum(gate_A_new & !gate_A_old, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    filter(n_recovered > 0) %>%
    arrange(desc(n_recovered))
  
  if (nrow(subject_recovery) > 0) {
    cat("\n  Subjects with recovered trials (threshold = 0.80):\n")
    print(subject_recovery)
    cat("\n  Total subjects with recovery:", nrow(subject_recovery), "\n")
    cat("  Total trials recovered:", sum(subject_recovery$n_recovered), "\n")
  } else {
    cat("\n  No trials recovered with event-relative definition.\n")
  }
  
  # Save comparison
  comparison_file <- file.path(qc_dir, "prestim_window_comparison.csv")
  write_csv(gate_a_comparison, comparison_file)
  cat("\n  ✓ Saved comparison to:", comparison_file, "\n")
} else {
  cat("  ⚠ Cannot compare: valid_prestim_old column not found\n")
}

# ============================================================================
# PROMPT 4: EVENT-LOCKED INVALIDITY ANALYSIS
# ============================================================================

cat("\n7. Computing event-locked invalidity (P(invalid pupil) time-locked to events)...\n")

# Load raw data again for event-locked analysis
event_locked_invalidity_list <- map(flat_files, function(f) {
  cat("  Processing:", basename(f), "\n")
  df <- read_csv(f, show_col_types = FALSE, progress = FALSE)
  
  if (!all(c("time", "pupil") %in% names(df))) {
    return(tibble())
  }
  
  # Derive identifiers
  df <- df %>%
    mutate(
      sub = if ("sub" %in% names(.)) sub else if ("subject_id" %in% names(.)) as.character(subject_id) else NA_character_,
      task = if ("task" %in% names(.)) {
        dplyr::if_else(task == "aud", "ADT",
                       dplyr::if_else(task == "vis", "VDT", as.character(task)))
      } else if ("task_modality" %in% names(.)) {
        dplyr::case_when(
          task_modality == "aud" ~ "ADT",
          task_modality == "vis" ~ "VDT",
          TRUE ~ as.character(task_modality)
        )
      } else NA_character_,
      run = if ("run" %in% names(.)) run else if ("run_num" %in% names(.)) run_num else NA_integer_,
      trial_index = if ("trial_index" %in% names(.)) trial_index
      else if ("trial_in_run" %in% names(.)) trial_in_run
      else if ("trial" %in% names(.)) trial
      else if ("trial_num" %in% names(.)) trial_num
      else NA_integer_
    ) %>%
    filter(!is.na(sub), !is.na(task), !is.na(run), !is.na(trial_index))
  
  if (nrow(df) == 0) {
    return(tibble())
  }
  
  # Mark invalid pupil (NA or 0)
  df$pupil[df$pupil == 0] <- NA_real_
  df$is_invalid <- is.na(df$pupil)
  
  # Create event-locked time windows (±500ms, 20ms bins)
  bin_width <- 0.02  # 20ms
  time_window <- 0.5  # ±500ms
  
  # For each event, compute t_rel and bin
  # Create separate data frames for each event
  bind_rows(
    # Grip onset (TrialST = 0.0)
    df %>%
      mutate(
        event = "grip_onset",
        event_time = 0.0,
        t_rel = time - event_time,
        t_bin = round(t_rel / bin_width) * bin_width
      ) %>%
      filter(t_rel >= -time_window & t_rel <= time_window, !is.na(t_bin)) %>%
      group_by(sub, task, run, trial_index, t_bin) %>%
      summarise(
        event = first(event),
        n_samples = n(),
        n_invalid = sum(is_invalid, na.rm = TRUE),
        p_invalid = mean(is_invalid, na.rm = TRUE),
        .groups = "drop"
      ),
    # Blank onset (blankST = 3.0)
    df %>%
      mutate(
        event = "blank_onset",
        event_time = 3.0,
        t_rel = time - event_time,
        t_bin = round(t_rel / bin_width) * bin_width
      ) %>%
      filter(t_rel >= -time_window & t_rel <= time_window, !is.na(t_bin)) %>%
      group_by(sub, task, run, trial_index, t_bin) %>%
      summarise(
        event = first(event),
        n_samples = n(),
        n_invalid = sum(is_invalid, na.rm = TRUE),
        p_invalid = mean(is_invalid, na.rm = TRUE),
        .groups = "drop"
      ),
    # Fixation onset (fixST = 3.25)
    df %>%
      mutate(
        event = "fixation_onset",
        event_time = 3.25,
        t_rel = time - event_time,
        t_bin = round(t_rel / bin_width) * bin_width
      ) %>%
      filter(t_rel >= -time_window & t_rel <= time_window, !is.na(t_bin)) %>%
      group_by(sub, task, run, trial_index, t_bin) %>%
      summarise(
        event = first(event),
        n_samples = n(),
        n_invalid = sum(is_invalid, na.rm = TRUE),
        p_invalid = mean(is_invalid, na.rm = TRUE),
        .groups = "drop"
      ),
    # Stimulus onset (A/V_ST = 3.75)
    df %>%
      mutate(
        event = "stimulus_onset",
        event_time = 3.75,
        t_rel = time - event_time,
        t_bin = round(t_rel / bin_width) * bin_width
      ) %>%
      filter(t_rel >= -time_window & t_rel <= time_window, !is.na(t_bin)) %>%
      group_by(sub, task, run, trial_index, t_bin) %>%
      summarise(
        event = first(event),
        n_samples = n(),
        n_invalid = sum(is_invalid, na.rm = TRUE),
        p_invalid = mean(is_invalid, na.rm = TRUE),
        .groups = "drop"
      )
  )
})

event_locked_invalidity <- bind_rows(event_locked_invalidity_list)

if (nrow(event_locked_invalidity) > 0) {
  # Aggregate across trials
  invalidity_summary <- event_locked_invalidity %>%
    mutate(
      subject_id = as.character(sub),
      task = as.character(task)
    ) %>%
    group_by(task, event, t_bin) %>%
    summarise(
      n_trials = n_distinct(paste(subject_id, run, trial_index)),
      n_samples_total = sum(n_samples, na.rm = TRUE),
      n_invalid_total = sum(n_invalid, na.rm = TRUE),
      p_invalid_mean = mean(p_invalid, na.rm = TRUE),
      p_invalid_se = sd(p_invalid, na.rm = TRUE) / sqrt(n()),
      .groups = "drop"
    )
  
  # Save event-locked invalidity
  invalidity_file <- file.path(qc_dir, "event_locked_invalidity.csv")
  write_csv(invalidity_summary, invalidity_file)
  cat("  ✓ Saved event-locked invalidity to:", invalidity_file, "\n")
  
  # Summary stats
  cat("\n  Event-locked invalidity summary:\n")
  invalidity_summary %>%
    group_by(task, event) %>%
    summarise(
      max_p_invalid = max(p_invalid_mean, na.rm = TRUE),
      mean_p_invalid = mean(p_invalid_mean, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    print()
} else {
  cat("  ⚠ No event-locked invalidity data computed\n")
}

# ============================================================================
# 8. CONSOLE SUMMARY (HIGH-LEVEL)
# ============================================================================

cat("5. Summary:\n")

subject_summary <- trial_coverage %>%
  group_by(subject_id) %>%
  summarise(
    n_trials = n(),
    any_pupil_trials = sum(has_any_pupil, na.rm = TRUE),
    salvage_trials = sum(salvage_cognitive_ok_total_fail, na.rm = TRUE),
    .groups = "drop"
  )

worst_subject <- subject_summary %>%
  mutate(pct_any_pupil = any_pupil_trials / n_trials) %>%
  arrange(pct_any_pupil) %>%
  slice_head(n = 3)

cat("  Subjects:", nrow(subject_summary), "\n")
cat("  Median trials per subject:", stats::median(subject_summary$n_trials), "\n")
cat("  Worst subjects by any-pupil coverage:\n")
print(worst_subject)

cat("\n=== BUILD COMPLETE ===\n")
cat("Completed at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")


