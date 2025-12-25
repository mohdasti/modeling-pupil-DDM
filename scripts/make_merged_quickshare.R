#!/usr/bin/env Rscript
# ============================================================================
# Make Merged Trial-Level Dataset + Quick-Share Bundle
# ============================================================================
# Fixes behavioral merge and generates <= 8 CSVs for sharing
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(tidyr)
  library(data.table)
  library(yaml)
  library(here)
  library(broom)
})

cat("=== MAKING MERGED TRIAL-LEVEL + QUICK-SHARE ===\n\n")

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

OUTPUT_DIR <- file.path(REPO_ROOT, "quick_share_v3")
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

# Window definitions
BASELINE_WIN <- c(-0.5, 0.0)
COG_WIN <- c(4.65, 5.65)  # target_onset (3.75) + [0.3, 1.3]
TOTAL_AUC_WIN <- c(0.0, 5.65)  # target_onset (3.75) + 1.3

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

trapezoidal_auc <- function(x, y) {
  if (length(x) < 2 || length(y) < 2) return(NA_real_)
  if (length(x) != length(y)) return(NA_real_)
  valid <- !is.na(x) & !is.na(y) & is.finite(x) & is.finite(y)
  if (sum(valid) < 2) return(NA_real_)
  x_valid <- x[valid]
  y_valid <- y[valid]
  ord <- order(x_valid)
  x_ord <- x_valid[ord]
  y_ord <- y_valid[ord]
  sum(diff(x_ord) * (y_ord[-length(y_ord)] + y_ord[-1]) / 2)
}

# ----------------------------------------------------------------------------
# STEP 1: Load trial-level pupil data (from previous script output)
# ----------------------------------------------------------------------------

cat("STEP 1: Loading trial-level pupil data...\n")

trial_level_file <- file.path(REPO_ROOT, "derived", "triallevel_qc.csv")
if (!file.exists(trial_level_file)) {
  stop("Trial-level QC file not found: ", trial_level_file, 
       "\nPlease run R/quickshare_build_triallevel.R first.")
}

trial_level <- read_csv(trial_level_file, show_col_types = FALSE)
cat("  ✓ Loaded ", nrow(trial_level), " pupil trials\n", sep = "")
cat("  Columns: ", paste(names(trial_level), collapse = ", "), "\n", sep = "")

# Normalize trial_level columns to match merge keys
# Check what subject column exists (triallevel_qc.csv uses "subject")
if ("subject" %in% names(trial_level)) {
  trial_level$sub <- as.character(trial_level$subject)
} else if ("sub" %in% names(trial_level)) {
  trial_level$sub <- as.character(trial_level$sub)
} else if ("subject_id" %in% names(trial_level)) {
  trial_level$sub <- as.character(trial_level$subject_id)
} else {
  stop("Trial-level file missing subject column (subject, sub, or subject_id). Found: ", 
       paste(names(trial_level)[1:min(15, length(names(trial_level)))], collapse = ", "))
}

# Ensure other key columns exist
if (!"task" %in% names(trial_level)) {
  stop("Trial-level file missing task column")
}

if (!"session_used" %in% names(trial_level)) {
  if ("session" %in% names(trial_level)) {
    trial_level$session_used <- as.integer(trial_level$session)
  } else if ("ses" %in% names(trial_level)) {
    trial_level$session_used <- as.integer(trial_level$ses)
  } else {
    stop("Trial-level file missing session column (session_used, session, or ses)")
  }
}

if (!"run_used" %in% names(trial_level)) {
  if ("run" %in% names(trial_level)) {
    trial_level$run_used <- as.integer(trial_level$run)
  } else {
    stop("Trial-level file missing run column (run_used or run)")
  }
}

if (!"trial_index" %in% names(trial_level)) {
  if ("trial_in_run_raw" %in% names(trial_level)) {
    trial_level$trial_index <- as.integer(trial_level$trial_in_run_raw)
  } else if ("trial_in_run" %in% names(trial_level)) {
    trial_level$trial_index <- as.integer(trial_level$trial_in_run)
  } else if ("trial" %in% names(trial_level)) {
    trial_level$trial_index <- as.integer(trial_level$trial)
  } else {
    stop("Trial-level file missing trial column (trial_index, trial_in_run_raw, trial_in_run, or trial)")
  }
}

# Ensure sub is character
trial_level$sub <- as.character(trial_level$sub)
trial_level$task <- as.character(trial_level$task)
trial_level$session_used <- as.integer(trial_level$session_used)
trial_level$run_used <- as.integer(trial_level$run_used)
trial_level$trial_index <- as.integer(trial_level$trial_index)

# ----------------------------------------------------------------------------
# STEP 2: Load and merge behavioral data
# ----------------------------------------------------------------------------

cat("\nSTEP 2: Loading behavioral data...\n")

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
         paste("  -", c(BEHAVIORAL_FILE, candidates), collapse = "\n"))
  }
}

behavioral_raw <- read_csv(BEHAVIORAL_FILE, show_col_types = FALSE)
cat("  ✓ Loaded ", nrow(behavioral_raw), " behavioral trial rows\n", sep = "")
cat("  Columns: ", paste(names(behavioral_raw), collapse = ", "), "\n", sep = "")

# Normalize behavioral columns with robust mapping
behavioral <- behavioral_raw %>%
  mutate(
    # Subject ID
    sub = as.character(if ("sub" %in% names(.)) sub else 
                      if ("subject_id" %in% names(.)) subject_id else NA_character_),
    
    # Task
    task = if ("task" %in% names(.)) {
      as.character(task)
    } else if ("task_modality" %in% names(.)) {
      case_when(
        task_modality == "aud" ~ "ADT",
        task_modality == "vis" ~ "VDT",
        TRUE ~ as.character(task_modality)
      )
    } else NA_character_,
    
    # Session (behavioral file uses "session")
    session_used = as.integer(if ("session_used" %in% names(.)) session_used else
                             if ("session" %in% names(.)) session else
                             if ("ses" %in% names(.)) ses else
                             if ("session_num" %in% names(.)) session_num else NA_integer_),
    
    # Run (behavioral file uses "run")
    run_used = as.integer(if ("run_used" %in% names(.)) run_used else
                         if ("run" %in% names(.)) run else
                         if ("run_num" %in% names(.)) run_num else NA_integer_),
    
      # Trial index (behavioral file uses trial_in_run)
      trial_index = as.integer(if ("trial_index" %in% names(.)) trial_index else
                           if ("trial_in_run" %in% names(.)) trial_in_run else
                           if ("trial" %in% names(.)) trial else
                           if ("trial_num" %in% names(.)) trial_num else NA_integer_),
    
    # Behavioral variables
    rt = if ("rt" %in% names(.)) rt else
         if ("resp1RT" %in% names(.)) resp1RT else
         if ("same_diff_resp_secs" %in% names(.)) same_diff_resp_secs else NA_real_,
    
    choice = if ("choice" %in% names(.)) choice else
             if ("resp_is_diff" %in% names(.)) resp_is_diff else
             if ("resp1" %in% names(.)) resp1 else NA_integer_,
    
    correct = if ("correct" %in% names(.)) correct else
              if ("iscorr" %in% names(.)) iscorr else
              if ("resp_is_correct" %in% names(.)) as.integer(resp_is_correct) else NA_integer_,
    
    stimulus_intensity = if ("stimulus_intensity" %in% names(.)) stimulus_intensity else
                        if ("stimLev" %in% names(.)) stimLev else
                        if ("stim_level_index" %in% names(.)) stim_level_index else NA_real_,
    
    effort = if ("effort" %in% names(.)) effort else
             if ("gf_trPer" %in% names(.)) {
               case_when(
                 gf_trPer == 0.05 ~ "Low",
                 gf_trPer == 0.40 ~ "High",
                 TRUE ~ NA_character_
               )
             } else if ("grip_targ_prop_mvc" %in% names(.)) {
               case_when(
                 grip_targ_prop_mvc == 0.05 ~ "Low",
                 grip_targ_prop_mvc == 0.40 ~ "High",
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
  )

cat("  ✓ Normalized to ", nrow(behavioral), " behavioral trials\n", sep = "")

# Check for duplicates
beh_dups <- behavioral %>%
  group_by(sub, task, session_used, run_used, trial_index) %>%
  summarise(n = n(), .groups = "drop") %>%
  filter(n > 1)

if (nrow(beh_dups) > 0) {
  cat("  ⚠ Warning: ", nrow(beh_dups), " duplicate trial keys in behavioral data\n", sep = "")
  behavioral <- behavioral %>%
    group_by(sub, task, session_used, run_used, trial_index) %>%
    slice(1) %>%
    ungroup()
}

# Merge with trial_level
cat("\nSTEP 3: Merging pupil + behavioral data...\n")

trial_level_merged <- trial_level %>%
  left_join(behavioral, by = c("sub" = "sub", "task" = "task", 
                               "session_used" = "session_used", 
                               "run_used" = "run_used", 
                               "trial_index" = "trial_index"),
            suffix = c("", "_beh"))

# Update has_behavioral_data based on actual merge success
# Also convert pct_non_nan columns to quality (0-1 scale) for consistency
trial_level_merged <- trial_level_merged %>%
  mutate(
    has_behavioral_data = !is.na(rt) | !is.na(choice) | !is.na(correct),
    # Convert percentage (0-100) to quality (0-1) scale
    baseline_quality = pct_non_nan_baseline / 100,
    cog_quality = pct_non_nan_cogwin / 100,
    trial_quality = pct_non_nan_overall / 100,
    overall_quality = pct_non_nan_overall / 100
  )

# Merge diagnostics
n_pupil <- nrow(trial_level)
n_beh <- nrow(behavioral)
n_matched <- sum(trial_level_merged$has_behavioral_data, na.rm = TRUE)

cat("  ✓ Merge complete\n", sep = "")
cat("    - Pupil trials: ", n_pupil, "\n", sep = "")
cat("    - Behavioral trials: ", n_beh, "\n", sep = "")
cat("    - Matched trials: ", n_matched, "\n", sep = "")

# Assertion: Must have some matches
if (n_matched == 0) {
  stop("CRITICAL ERROR: Zero trials matched. Check merge keys:\n",
       "Pupil keys: ", paste(unique(paste(trial_level$sub[1:5], trial_level$task[1:5], 
                                          trial_level$session_used[1:5], trial_level$run_used[1:5],
                                          trial_level$trial_index[1:5], sep=":")), collapse=", "), "\n",
       "Behavioral keys: ", paste(unique(paste(behavioral$sub[1:5], behavioral$task[1:5],
                                               behavioral$session_used[1:5], behavioral$run_used[1:5],
                                               behavioral$trial_index[1:5], sep=":")), collapse=", "))
}

# ----------------------------------------------------------------------------
# STEP 4: Compute pupil features (AUCs) from sample-level data
# ----------------------------------------------------------------------------

cat("\nSTEP 4: Computing pupil features (AUCs)...\n")

# We need to read sample-level data to compute AUCs
# For efficiency, process in batches
flat_files <- list.files(PROCESSED_DIR, pattern = "_(ADT|VDT)_flat\\.csv$", 
                         full.names = TRUE, recursive = TRUE)

if (length(flat_files) == 0) {
  cat("  ⚠ No flat files found, skipping AUC computation\n", sep = "")
  trial_level_merged <- trial_level_merged %>%
    mutate(
      total_auc = NA_real_,
      cog_auc_fixed = NA_real_,
      cog_mean_fixed = NA_real_
    )
} else {
  cat("  Processing ", length(flat_files), " files for AUC computation...\n", sep = "")
  
  # Process a sample to compute AUCs (can be optimized later)
  # For now, compute from trial_level if we have time_rel data
  # Otherwise, mark as NA
  trial_level_merged <- trial_level_merged %>%
    mutate(
      total_auc = NA_real_,  # Placeholder - would need sample-level data
      cog_auc_fixed = NA_real_,
      cog_mean_fixed = NA_real_
    )
  
  cat("  ⚠ AUC computation requires sample-level data access (placeholder for now)\n", sep = "")
}

# ----------------------------------------------------------------------------
# STEP 5: Generate quick-share CSVs
# ----------------------------------------------------------------------------

cat("\nSTEP 5: Generating quick-share CSVs...\n")

# 01_merge_diagnostics.csv
merge_diagnostics <- trial_level_merged %>%
  group_by(task) %>%
  summarise(
    n_pupil_trials = n(),
    n_beh_trials = sum(!is.na(rt) | !is.na(choice), na.rm = TRUE),
    n_matched = sum(has_behavioral_data, na.rm = TRUE),
    match_rate_pupil_pct = 100 * n_matched / n_pupil_trials,
    .groups = "drop"
  ) %>%
  bind_rows(
    trial_level_merged %>%
      summarise(
        task = "ALL",
        n_pupil_trials = n(),
        n_beh_trials = sum(!is.na(rt) | !is.na(choice), na.rm = TRUE),
        n_matched = sum(has_behavioral_data, na.rm = TRUE),
        match_rate_pupil_pct = 100 * n_matched / n_pupil_trials
      )
  )

# Unmatched keys
unmatched_pupil <- trial_level_merged %>%
  filter(!has_behavioral_data) %>%
  select(sub, task, session_used, run_used, trial_index) %>%
  distinct() %>%
  head(20)

unmatched_beh <- behavioral %>%
  anti_join(trial_level, by = c("sub", "task", "session_used", "run_used", "trial_index")) %>%
  select(sub, task, session_used, run_used, trial_index) %>%
  distinct() %>%
  head(20)

# Add unmatched counts and samples (only for "ALL" row)
# Create sample strings outside mutate
unmatched_pupil_str <- if (nrow(unmatched_pupil) > 0) {
  paste(paste(unmatched_pupil$sub, unmatched_pupil$task, 
              unmatched_pupil$session_used, unmatched_pupil$run_used,
              unmatched_pupil$trial_index, sep=":"), collapse="; ")
} else {
  NA_character_
}

unmatched_beh_str <- if (nrow(unmatched_beh) > 0) {
  paste(paste(unmatched_beh$sub, unmatched_beh$task,
              unmatched_beh$session_used, unmatched_beh$run_used,
              unmatched_beh$trial_index, sep=":"), collapse="; ")
} else {
  NA_character_
}

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
trials_per_subject <- trial_level_merged %>%
  group_by(sub, task, session_used) %>%
  summarise(
    n_runs = n_distinct(run_used),
    n_trials = n(),
    n_trials_with_behavior = sum(has_behavioral_data, na.rm = TRUE),
    expected_runs = 5L,
    missing_runs = pmax(0L, expected_runs - n_runs),
    .groups = "drop"
  )

write_csv(trials_per_subject, file.path(QUICKSHARE_DIR, "02_trials_per_subject_task_ses.csv"))
cat("  ✓ 02_trials_per_subject_task_ses.csv\n")

# 03_condition_cell_counts.csv
# Convert quality (0-1) to percentage for thresholds
condition_counts <- trial_level_merged %>%
  filter(has_behavioral_data) %>%
  mutate(
    baseline_ok_60 = !is.na(baseline_quality) & baseline_quality >= 0.60,
    baseline_ok_50 = !is.na(baseline_quality) & baseline_quality >= 0.50,
    baseline_ok_70 = !is.na(baseline_quality) & baseline_quality >= 0.70,
    cog_ok_60 = !is.na(cog_quality) & cog_quality >= 0.60,
    cog_ok_50 = !is.na(cog_quality) & cog_quality >= 0.50,
    cog_ok_70 = !is.na(cog_quality) & cog_quality >= 0.70
  ) %>%
  group_by(sub, task, effort, stimulus_intensity) %>%
  summarise(
    n_trials_total = n(),
    n_trials_valid_primary = sum(baseline_ok_60 & cog_ok_60, na.rm = TRUE),
    n_trials_valid_lenient = sum(baseline_ok_50 & cog_ok_50, na.rm = TRUE),
    n_trials_valid_strict = sum(baseline_ok_70 & cog_ok_70, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(condition_counts, file.path(QUICKSHARE_DIR, "03_condition_cell_counts.csv"))
cat("  ✓ 03_condition_cell_counts.csv\n")

# 04_run_level_counts.csv
run_level <- trial_level_merged %>%
  group_by(sub, task, session_used, run_used) %>%
  summarise(
    n_trials = n(),
    n_trials_with_behavior = sum(has_behavioral_data, na.rm = TRUE),
    mean_baseline_quality = mean(baseline_quality, na.rm = TRUE),
    mean_cog_quality = mean(cog_quality, na.rm = TRUE),
    mean_trial_quality = mean(trial_quality, na.rm = TRUE),
    mean_overall_quality = mean(overall_quality, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(run_level, file.path(QUICKSHARE_DIR, "04_run_level_counts.csv"))
cat("  ✓ 04_run_level_counts.csv\n")

# 05_window_validity_summary.csv
window_summary <- trial_level_merged %>%
  filter(has_behavioral_data) %>%
  mutate(effort_group = if_else(is.na(effort), "Unknown", effort)) %>%
  group_by(task, effort_group) %>%
  summarise(
    n_trials = n(),
    baseline_mean = mean(baseline_quality, na.rm = TRUE),
    baseline_median = median(baseline_quality, na.rm = TRUE),
    baseline_p10 = quantile(baseline_quality, 0.10, na.rm = TRUE, names = FALSE),
    baseline_p90 = quantile(baseline_quality, 0.90, na.rm = TRUE, names = FALSE),
    cog_mean = mean(cog_quality, na.rm = TRUE),
    cog_median = median(cog_quality, na.rm = TRUE),
    cog_p10 = quantile(cog_quality, 0.10, na.rm = TRUE, names = FALSE),
    cog_p90 = quantile(cog_quality, 0.90, na.rm = TRUE, names = FALSE),
    total_mean = mean(overall_quality, na.rm = TRUE),
    total_median = median(overall_quality, na.rm = TRUE),
    total_p10 = quantile(overall_quality, 0.10, na.rm = TRUE, names = FALSE),
    total_p90 = quantile(overall_quality, 0.90, na.rm = TRUE, names = FALSE),
    .groups = "drop"
  ) %>%
  rename(effort = effort_group)

write_csv(window_summary, file.path(QUICKSHARE_DIR, "05_window_validity_summary.csv"))
cat("  ✓ 05_window_validity_summary.csv\n")

# 06_gate_pass_rates_by_threshold.csv
gate_rates <- map_dfr(GATE_THRESHOLDS, function(th) {
  trial_level_merged %>%
    filter(has_behavioral_data) %>%
    mutate(
      baseline_ok = if ("baseline_quality" %in% names(.)) 
        !is.na(baseline_quality) & baseline_quality >= th else FALSE,
      cog_ok = if ("cog_quality" %in% names(.)) 
        !is.na(cog_quality) & cog_quality >= th else FALSE
    ) %>%
    group_by(task) %>%
    summarise(
      threshold = th,
      n_trials_total = n(),
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
  # Create pass flag (quality is 0-1 scale, so use th directly)
  pass_col <- paste0("pass_primary_", sprintf("%03d", as.integer(th * 100)))
  trial_level_merged[[pass_col]] <- 
    !is.na(trial_level_merged$baseline_quality) & 
    trial_level_merged$baseline_quality >= th &
    !is.na(trial_level_merged$cog_quality) & 
    trial_level_merged$cog_quality >= th &
    trial_level_merged$has_behavioral_data
  
  # Stratified by effort
  if (any(!is.na(trial_level_merged$effort))) {
    effort_strat <- trial_level_merged %>%
      filter(!is.na(effort), has_behavioral_data) %>%
      group_by(effort) %>%
      summarise(
        threshold = th,
        factor = "effort",
        level = first(effort),
        n_total = n(),
        n_pass = sum(.data[[pass_col]], na.rm = TRUE),
        pass_rate = n_pass / n_total,
        .groups = "drop"
      )
    bias_checks_list[[length(bias_checks_list) + 1]] <- effort_strat
  }
  
  # Stratified by task
  task_strat <- trial_level_merged %>%
    filter(has_behavioral_data) %>%
    group_by(task) %>%
    summarise(
      threshold = th,
      factor = "task",
      level = first(task),
      n_total = n(),
      n_pass = sum(.data[[pass_col]], na.rm = TRUE),
      pass_rate = n_pass / n_total,
      .groups = "drop"
    )
  bias_checks_list[[length(bias_checks_list) + 1]] <- task_strat
  
  # Logistic regression if effort available
  if (any(!is.na(trial_level_merged$effort))) {
    # Filter first, then extract outcome
    model_data <- trial_level_merged %>%
      filter(!is.na(effort), has_behavioral_data) %>%
      mutate(
        effort_f = factor(effort),
        task_f = factor(task)
      )
    
    # Extract outcome after filtering
    outcome_var <- model_data[[pass_col]]
    model_data$pass_outcome <- as.integer(outcome_var)
    
    # Remove rows with NA outcome
    model_data <- model_data %>%
      filter(!is.na(pass_outcome))
    
    if (nrow(model_data) > 0) {
      tryCatch({
        # Use the extracted outcome column directly
        model <- glm(pass_outcome ~ effort_f + task_f,
                     data = model_data, family = binomial())
        
        coef_summary <- broom::tidy(model) %>%
          mutate(
            threshold = th,
            factor = "model",
            level = term,
            n_total = nrow(model_data),
            n_pass = sum(model_data$pass_outcome, na.rm = TRUE),
            pass_rate = n_pass / n_total,
            estimate = estimate,
            p_value = p.value
          ) %>%
          select(threshold, factor, level, n_total, n_pass, pass_rate, estimate, p_value)
        
        bias_checks_list[[length(bias_checks_list) + 1]] <- coef_summary
      }, error = function(e) {
        cat("  Warning: Could not fit model for threshold ", th, ": ", e$message, "\n", sep = "")
      })
    }
  }
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

# 08_trial_level_for_jitter.csv
# Check if time columns exist, otherwise create placeholder
jitter_data <- trial_level_merged %>%
  select(sub, task, session_used, run_used, trial_index) %>%
  arrange(sub, task, session_used, run_used, trial_index) %>%
  group_by(sub, task, session_used, run_used) %>%
  mutate(
    # Create trial sequence number for jitter analysis
    trial_seq = row_number(),
    prev_trial_seq = lag(trial_seq),
    tr_interval = if_else(!is.na(prev_trial_seq), 1.75, NA_real_),  # Assume TR spacing
    tr_interval_mod = if_else(!is.na(tr_interval), tr_interval %% TR_SCANNER, NA_real_),
    note = "Time columns not available in trial-level data; using trial sequence for jitter analysis"
  ) %>%
  ungroup()

write_csv(jitter_data, file.path(QUICKSHARE_DIR, "08_trial_level_for_jitter.csv"))
cat("  ✓ 08_trial_level_for_jitter.csv\n")

# ----------------------------------------------------------------------------
# STEP 6: Save merged trial-level dataset
# ----------------------------------------------------------------------------

cat("\nSTEP 6: Saving merged trial-level dataset...\n")

# Select and order columns for merged output
trial_level_final <- trial_level_merged %>%
  mutate(
    pct_non_nan_total = if ("pct_non_nan_total" %in% names(trial_level_merged)) 
      pct_non_nan_total else overall_quality * 100
  ) %>%
  select(
    # Trial identity
    sub, task, session_used, run_used, trial_index,
    
    # Behavioral
    rt, choice, correct, stimulus_intensity, effort, isOddball,
    has_behavioral_data,
    
    # Pupil QC
    baseline_quality, trial_quality, cog_quality, overall_quality,
    pct_non_nan_total,
    
    # Gate pass flags
    starts_with("pass_primary_"),
    
    # Pupil features (placeholders for now)
    any_of(c("total_auc", "cog_auc_fixed", "cog_mean_fixed")),
    
    # QC flags
    any_of(c("window_oob", "all_nan", "window_oob_any", "all_nan_any", "any_timebase_bug"))
  )

merged_output <- file.path(MERGED_DIR, "BAP_triallevel_merged.csv")
write_csv(trial_level_final, merged_output)
cat("  ✓ Saved: ", merged_output, "\n", sep = "")

# Assertions
cat("\n=== VALIDATION ===\n")
cat("Total trials: ", nrow(trial_level_final), "\n", sep = "")
cat("Trials with behavioral: ", sum(trial_level_final$has_behavioral_data, na.rm = TRUE), "\n", sep = "")
cat("Trials with rt: ", sum(!is.na(trial_level_final$rt), na.rm = TRUE), "\n", sep = "")
cat("Trials with choice: ", sum(!is.na(trial_level_final$choice), na.rm = TRUE), "\n", sep = "")

if (all(is.na(trial_level_final$rt)) && all(is.na(trial_level_final$choice))) {
  stop("CRITICAL ERROR: All behavioral columns are NA. Merge failed.")
}

cat("\n=== COMPLETE ===\n")
cat("Quick-share CSVs saved to: ", QUICKSHARE_DIR, "\n", sep = "")
cat("Merged dataset saved to: ", merged_output, "\n", sep = "")

