#!/usr/bin/env Rscript
# =========================================================================
# STEP 1B: PREPARE DDM-PUPIL DATA (REQUIRES PUPIL DATA)
# =========================================================================
# Creates analysis-ready dataset for DDM modeling with pupillometry features
# This version REQUIRES pupil data to be merged, creating a combined dataset
# =========================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(here)
})

# Source validation functions
source("R/validate_experimental_design.R")

# =========================================================================
# CONFIGURATION & LOGGING SETUP
# =========================================================================

SCRIPT_NAME <- "prepare_ddm_pupil_data.R"
START_TIME <- Sys.time()
LOG_DIR <- "logs"
OUTPUT_DIR <- "data/analysis_ready"

# Create directories
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Log file with timestamp
LOG_FILE <- file.path(LOG_DIR, paste0("ddm_pupil_data_prep_", format(START_TIME, "%Y%m%d_%H%M%S"), ".log"))

# Logging function
log_msg <- function(..., level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  msg <- paste(..., collapse = " ")
  log_entry <- sprintf("[%s] [%s] %s\n", timestamp, level, msg)
  cat(log_entry)
  cat(log_entry, file = LOG_FILE, append = TRUE)
}

log_msg(strrep("=", 80))
log_msg("STARTING DDM-PUPIL DATA PREPARATION")
log_msg(strrep("=", 80))
log_msg("Script:", SCRIPT_NAME)
log_msg("Start time:", format(START_TIME, "%Y-%m-%d %H:%M:%S"))
log_msg("Working directory:", getwd())
log_msg("Log file:", LOG_FILE)
log_msg("")

# =========================================================================
# DATA PATHS
# =========================================================================

PUPIL_FLAT_DIR <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
BEHAVIORAL_FILE <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"
OUTPUT_FILE <- file.path(OUTPUT_DIR, "bap_ddm_pupil_ready.csv")

log_msg("Configuration:")
log_msg("  Pupil flat files directory:", PUPIL_FLAT_DIR)
log_msg("  Behavioral data:", BEHAVIORAL_FILE)
log_msg("  Output file:", OUTPUT_FILE)
log_msg("")

# =========================================================================
# STEP 1: LOAD PUPIL FLAT FILES
# =========================================================================

log_msg("STEP 1: Loading pupil flat files...")
tic_load <- Sys.time()

flat_files <- list.files(PUPIL_FLAT_DIR, pattern = "_flat\\.csv$", full.names = TRUE)

if (length(flat_files) == 0) {
  log_msg("ERROR: No flat CSV files found in", PUPIL_FLAT_DIR, level = "ERROR")
  stop("No pupil flat files found")
}

log_msg("  Found", length(flat_files), "flat files")
log_msg("  Loading and combining...")

pupil_flat <- map_dfr(flat_files, function(f) {
  tryCatch({
    read_csv(f, show_col_types = FALSE, progress = FALSE)
  }, error = function(e) {
    log_msg("  Warning: Error reading", basename(f), "-", e$message, level = "WARN")
    return(tibble())
  })
})

load_time <- as.numeric(difftime(Sys.time(), tic_load, units = "secs"))
log_msg("  Loaded", nrow(pupil_flat), "pupil samples")
log_msg("  Subjects:", length(unique(pupil_flat$sub)))
log_msg("  Tasks:", paste(unique(pupil_flat$task), collapse = ", "))
log_msg("  Load time:", round(load_time, 2), "seconds")
log_msg("")

# =========================================================================
# STEP 2: LOAD BEHAVIORAL DATA
# =========================================================================

log_msg("STEP 2: Loading behavioral data...")
tic_behav <- Sys.time()

if (!file.exists(BEHAVIORAL_FILE)) {
  log_msg("ERROR: Behavioral file not found:", BEHAVIORAL_FILE, level = "ERROR")
  stop("File not found: ", BEHAVIORAL_FILE)
}

behavioral_data <- read_csv(BEHAVIORAL_FILE, show_col_types = FALSE)

behav_time <- as.numeric(difftime(Sys.time(), tic_behav, units = "secs"))
log_msg("  Loaded", nrow(behavioral_data), "behavioral trials")
log_msg("  Load time:", round(behav_time, 2), "seconds")
log_msg("")

# =========================================================================
# STEP 3: MAP BEHAVIORAL COLUMNS
# =========================================================================

log_msg("STEP 3: Mapping behavioral columns...")

behavioral_data <- behavioral_data %>%
  mutate(
    sub = as.character(subject_id),
    task = case_when(
      task_modality == "aud" ~ "ADT",
      task_modality == "vis" ~ "VDT",
      TRUE ~ as.character(task_modality)
    ),
    run = run_num,
    trial_index = trial_num,
    rt = same_diff_resp_secs,
    iscorr = as.integer(resp_is_correct),
    resp_is_diff = resp_is_diff,  # CRITICAL: Direct response choice
    gf_trPer = grip_targ_prop_mvc,
    stimLev = stim_level_index,
    isOddball = as.integer(stim_is_diff)
  ) %>%
  filter(!is.na(rt), rt >= 0.2, rt <= 3.0)

log_msg("  Mapped", nrow(behavioral_data), "valid behavioral trials")
log_msg("")

# =========================================================================
# STEP 4: COMPUTE PUPIL FEATURES
# =========================================================================

log_msg("STEP 4: Computing pupil features...")
tic_pupil <- Sys.time()

# Tonic baseline (ITI period)
log_msg("  Computing tonic baseline (ITI)...")
tonic_baseline <- pupil_flat %>%
  filter(trial_label == "ITI_Baseline" | grepl("ITI", trial_label)) %>%
  group_by(sub, task, run, trial_index) %>%
  summarise(
    tonic_baseline = mean(pupil, na.rm = TRUE),
    tonic_samples = n(),
    .groups = "drop"
  )

log_msg("    Tonic baseline computed for", nrow(tonic_baseline), "trials")

# Phasic features (200-900ms after stimulus)
log_msg("  Computing phasic features (200-900ms)...")
phasic_features <- pupil_flat %>%
  filter(
    has_behavioral_data == 1,
    !is.na(time),
    time >= 0.2,
    time <= 0.9
  ) %>%
  group_by(sub, task, run, trial_index) %>%
  summarise(
    phasic_slope = {
      if (n() < 5 || all(is.na(pupil))) NA_real_
      else {
        model <- lm(pupil ~ time, data = data.frame(pupil = pupil, time = time))
        coef(model)[2]
      }
    },
    phasic_mean = mean(pupil, na.rm = TRUE),
    phasic_peak = max(pupil, na.rm = TRUE),
    phasic_samples = n(),
    .groups = "drop"
  )

log_msg("    Phasic features computed for", nrow(phasic_features), "trials")

pupil_time <- as.numeric(difftime(Sys.time(), tic_pupil, units = "secs"))
log_msg("  Pupil feature computation time:", round(pupil_time, 2), "seconds")
log_msg("")

# =========================================================================
# STEP 5: MERGE BEHAVIORAL AND PUPIL DATA
# =========================================================================

log_msg("STEP 5: Merging behavioral and pupil data...")
tic_merge <- Sys.time()

trialwise_pupil <- behavioral_data %>%
  left_join(tonic_baseline, by = c("sub", "task", "run", "trial_index")) %>%
  left_join(phasic_features, by = c("sub", "task", "run", "trial_index")) %>%
  mutate(
    subject_id = sub,
    # Create scaled features
    tonic_baseline_z = scale(tonic_baseline)[,1],
    phasic_slope_z = scale(phasic_slope)[,1],
    phasic_mean_z = scale(phasic_mean)[,1],
    # Effort arousal change
    effort_arousal_change = phasic_mean - tonic_baseline,
    effort_arousal_change_z = scale(effort_arousal_change)[,1]
  )

merge_time <- as.numeric(difftime(Sys.time(), tic_merge, units = "secs"))
log_msg("  Merged", nrow(trialwise_pupil), "trials")
log_msg("  Trials with pupil data:", sum(!is.na(trialwise_pupil$tonic_baseline)))
log_msg("  Merge time:", round(merge_time, 2), "seconds")
log_msg("")

# =========================================================================
# STEP 6: CREATE DIFFICULTY AND EFFORT CONDITIONS
# =========================================================================

log_msg("STEP 6: Creating difficulty and effort conditions...")

trialwise_pupil <- trialwise_pupil %>%
  mutate(
    difficulty_level = case_when(
      isOddball == 0 | is.na(isOddball) ~ "Standard",
      stimLev %in% c(0, 1, 2, 8, 16, 0.06, 0.12) ~ "Hard",
      stimLev %in% c(3, 4, 32, 64, 0.24, 0.48) ~ "Easy",
      TRUE ~ NA_character_
    ),
    difficulty_level = as.factor(difficulty_level),
    effort_condition = case_when(
      abs(gf_trPer - 0.05) < 0.001 ~ "Low_5_MVC",
      abs(gf_trPer - 0.4) < 0.001 ~ "High_40_MVC",
      TRUE ~ NA_character_
    ),
    effort_condition = as.factor(effort_condition)
  )

log_msg("  Conditions created")
log_msg("")

# =========================================================================
# STEP 7: FILTER AND CREATE DDM CODING
# =========================================================================

log_msg("STEP 7: Filtering valid trials and creating DDM coding...")

ddm_ready <- trialwise_pupil %>%
  filter(
    !is.na(rt),
    !is.na(iscorr),
    !is.na(resp_is_diff),  # CRITICAL: Must have response choice
    rt >= 0.25,
    rt <= 3.0
  ) %>%
  mutate(
    subject_id = as.factor(subject_id),
    task = as.factor(task),
    resp_is_diff = as.logical(resp_is_diff),
    
    # CRITICAL: Explicit integer DDM boundary coding
    dec_upper = case_when(
      resp_is_diff == TRUE  ~ 1L,  # Upper = Different
      resp_is_diff == FALSE ~ 0L,  # Lower = Same
      TRUE ~ NA_integer_
    ),
    response_label = ifelse(dec_upper == 1, "different", "same"),
    choice = as.integer(iscorr),
    choice_binary = as.integer(iscorr)
  )

log_msg("  Filtered to", nrow(ddm_ready), "valid trials")
log_msg("")

# =========================================================================
# STEP 8: COMPREHENSIVE VALIDATION CHECKS
# =========================================================================

log_msg("STEP 8: Running comprehensive validation checks...")
log_msg("")

# Save temporary file for validation
temp_validation_file <- file.path(OUTPUT_DIR, paste0("temp_validation_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"))
write_csv(ddm_ready, temp_validation_file)

# Run comprehensive validation
validation_log <- file.path(LOG_DIR, paste0("validation_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))
validation_result <- validate_ddm_data(temp_validation_file, validation_log)

# Clean up temp file
unlink(temp_validation_file)

# Check validation results
if (!validation_result$success) {
  log_msg("  ⚠ Validation found issues - review validation log:", validation_log, level = "WARN")
  log_msg("    Data file will still be saved, but review issues before modeling")
  log_msg("")
} else {
  log_msg("  ✓ All validation checks passed")
  log_msg("")
}

# Same validation as DDM-only script
invalid_dec <- sum(!ddm_ready$dec_upper %in% c(0L, 1L, NA_integer_), na.rm = TRUE)
if (invalid_dec > 0) {
  log_msg("  ERROR: Invalid dec_upper values!", level = "ERROR")
  stop("Validation failed")
} else {
  log_msg("  ✓ dec_upper coding: Valid")
}

std_trials <- ddm_ready %>% filter(difficulty_level == "Standard")
prop_std_same <- 1 - mean(std_trials$dec_upper, na.rm = TRUE)
log_msg(sprintf("  Standard trials - Proportion 'Same': %.3f", prop_std_same))

log_msg("")

# =========================================================================
# STEP 9: SELECT FINAL COLUMNS AND SAVE
# =========================================================================

log_msg("STEP 9: Selecting final columns and saving...")

ddm_ready <- ddm_ready %>%
  select(
    subject_id, task, run, trial_index,
    rt, iscorr, choice, choice_binary,
    resp_is_diff, dec_upper, response_label,
    difficulty_level, effort_condition, stimLev, isOddball, gf_trPer,
    tonic_baseline, tonic_baseline_z,
    phasic_slope, phasic_slope_z,
    phasic_mean, phasic_mean_z,
    effort_arousal_change, effort_arousal_change_z
  )

write_csv(ddm_ready, OUTPUT_FILE)

log_msg("  ✓ Saved:", OUTPUT_FILE)
log_msg("  File size:", round(file.info(OUTPUT_FILE)$size / 1024, 2), "KB")
log_msg("")

# =========================================================================
# FINAL SUMMARY
# =========================================================================

END_TIME <- Sys.time()
ELAPSED_TIME <- as.numeric(difftime(END_TIME, START_TIME, units = "secs"))

log_msg(strrep("=", 80))
log_msg("DDM-PUPIL DATA PREPARATION COMPLETE")
log_msg(strrep("=", 80))
log_msg("Final dataset:")
log_msg("  Total trials:", nrow(ddm_ready))
log_msg("  Subjects:", length(unique(ddm_ready$subject_id)))
log_msg("  Trials with pupil data:", sum(!is.na(ddm_ready$tonic_baseline)))
log_msg("")
log_msg("Total elapsed time:", round(ELAPSED_TIME, 2), "seconds")
log_msg("End time:", format(END_TIME, "%Y-%m-%d %H:%M:%S"))
log_msg("=" %+% strrep("=", 78))


