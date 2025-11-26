#!/usr/bin/env Rscript
# =========================================================================
# STEP 1A: PREPARE DDM-ONLY DATA (NO PUPIL REQUIREMENT)
# =========================================================================
# Creates analysis-ready dataset for DDM modeling from behavioral data only
# This version does NOT require pupil data, allowing DDM analyses to proceed
# independently of pupillometry processing
# =========================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(here)
})

# Source validation functions
source("R/validate_experimental_design.R")

# =========================================================================
# CONFIGURATION & LOGGING SETUP
# =========================================================================

SCRIPT_NAME <- "prepare_ddm_only_data.R"
START_TIME <- Sys.time()
LOG_DIR <- "logs"
OUTPUT_DIR <- "data/analysis_ready"

# Create directories
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Log file with timestamp
LOG_FILE <- file.path(LOG_DIR, paste0("ddm_only_data_prep_", format(START_TIME, "%Y%m%d_%H%M%S"), ".log"))

# Logging function
log_msg <- function(..., level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  msg <- paste(..., collapse = " ")
  log_entry <- sprintf("[%s] [%s] %s\n", timestamp, level, msg)
  cat(log_entry)
  cat(log_entry, file = LOG_FILE, append = TRUE)
}

log_msg(strrep("=", 80))
log_msg("STARTING DDM-ONLY DATA PREPARATION")
log_msg(strrep("=", 80))
log_msg("Script:", SCRIPT_NAME)
log_msg("Start time:", format(START_TIME, "%Y-%m-%d %H:%M:%S"))
log_msg("Working directory:", getwd())
log_msg("Log file:", LOG_FILE)
log_msg("")

# =========================================================================
# DATA PATHS
# =========================================================================

BEHAVIORAL_FILE <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"
OUTPUT_FILE <- file.path(OUTPUT_DIR, "bap_ddm_only_ready.csv")

log_msg("Configuration:")
log_msg("  Behavioral data:", BEHAVIORAL_FILE)
log_msg("  Output file:", OUTPUT_FILE)
log_msg("")

# =========================================================================
# STEP 1: LOAD RAW BEHAVIORAL DATA
# =========================================================================

log_msg("STEP 1: Loading raw behavioral data...")
tic_load <- Sys.time()

if (!file.exists(BEHAVIORAL_FILE)) {
  log_msg("ERROR: Behavioral file not found:", BEHAVIORAL_FILE, level = "ERROR")
  stop("File not found: ", BEHAVIORAL_FILE)
}

behavioral_data <- read_csv(BEHAVIORAL_FILE, show_col_types = FALSE)

load_time <- as.numeric(difftime(Sys.time(), tic_load, units = "secs"))
log_msg("  Loaded", nrow(behavioral_data), "trials from", length(unique(behavioral_data$subject_id)), "subjects")
log_msg("  Load time:", round(load_time, 2), "seconds")
log_msg("")

# =========================================================================
# STEP 2: MAP COLUMNS TO EXPECTED NAMES
# =========================================================================

log_msg("STEP 2: Mapping columns to expected names...")

behavioral_data <- behavioral_data %>%
  mutate(
    # Subject identifier
    subject_id = as.character(subject_id),
    
    # Task mapping (aud/vis -> ADT/VDT)
    task = case_when(
      task_modality == "aud" ~ "ADT",
      task_modality == "vis" ~ "VDT",
      TRUE ~ as.character(task_modality)
    ),
    
    # Run and trial numbers
    run = run_num,
    trial_index = trial_num,
    
    # RT (response time in seconds)
    rt = same_diff_resp_secs,
    
    # Accuracy (convert True/False to 1/0)
    iscorr = as.integer(resp_is_correct),
    
    # CRITICAL: Include direct response-side column
    resp_is_diff = resp_is_diff,  # TRUE = "different", FALSE = "same"
    
    # Grip force
    gf_trPer = grip_targ_prop_mvc,
    
    # Stimulus properties
    stimLev = stim_level_index,
    isOddball = as.integer(stim_is_diff)
  )

log_msg("  Column mapping complete")
log_msg("")

# =========================================================================
# STEP 3: CREATE DIFFICULTY LEVELS
# =========================================================================

log_msg("STEP 3: Creating difficulty levels...")

behavioral_data <- behavioral_data %>%
  mutate(
    difficulty_level = case_when(
      isOddball == 0 | is.na(isOddball) ~ "Standard",
      stimLev %in% c(0, 1, 2, 8, 16, 0.06, 0.12) ~ "Hard",
      stimLev %in% c(3, 4, 32, 64, 0.24, 0.48) ~ "Easy",
      TRUE ~ NA_character_
    ),
    difficulty_level = as.factor(difficulty_level)
  )

difficulty_counts <- behavioral_data %>%
  filter(!is.na(difficulty_level)) %>%
  count(difficulty_level, name = "n_trials")

log_msg("  Difficulty level distribution:")
for (i in 1:nrow(difficulty_counts)) {
  log_msg(sprintf("    %s: %d trials", difficulty_counts$difficulty_level[i], difficulty_counts$n_trials[i]))
}
log_msg("")

# =========================================================================
# STEP 4: CREATE EFFORT CONDITIONS
# =========================================================================

log_msg("STEP 4: Creating effort conditions...")

behavioral_data <- behavioral_data %>%
  mutate(
    effort_condition = case_when(
      abs(gf_trPer - 0.05) < 0.001 ~ "Low_5_MVC",
      abs(gf_trPer - 0.4) < 0.001 ~ "High_40_MVC",
      TRUE ~ NA_character_
    ),
    effort_condition = as.factor(effort_condition)
  )

effort_counts <- behavioral_data %>%
  filter(!is.na(effort_condition)) %>%
  count(effort_condition, name = "n_trials")

log_msg("  Effort condition distribution:")
for (i in 1:nrow(effort_counts)) {
  log_msg(sprintf("    %s: %d trials", effort_counts$effort_condition[i], effort_counts$n_trials[i]))
}
log_msg("")

# =========================================================================
# STEP 5: FILTER VALID TRIALS
# =========================================================================

log_msg("STEP 5: Filtering valid trials...")
log_msg("  RT filter: [0.25, 3.0] seconds")
log_msg("  Excluding trials with missing resp_is_diff")

trials_before_filter <- nrow(behavioral_data)

ddm_ready <- behavioral_data %>%
  filter(
    !is.na(rt),
    !is.na(iscorr),
    !is.na(resp_is_diff),  # CRITICAL: Must have response choice
    rt >= 0.25,
    rt <= 3.0
  )

trials_after_filter <- nrow(ddm_ready)
trials_excluded <- trials_before_filter - trials_after_filter

log_msg("  Trials before filtering:", trials_before_filter)
log_msg("  Trials after filtering:", trials_after_filter)
log_msg("  Trials excluded:", trials_excluded, sprintf("(%.1f%%)", 100 * trials_excluded / trials_before_filter))
log_msg("")

# =========================================================================
# STEP 6: CREATE DDM BOUNDARY CODING
# =========================================================================

log_msg("STEP 6: Creating DDM boundary coding (response-side)...")

ddm_ready <- ddm_ready %>%
  mutate(
    # Ensure boolean
    resp_is_diff = as.logical(resp_is_diff),
    
    # CRITICAL: Explicit integer DDM boundary coding
    # Upper boundary (1) = "different", Lower boundary (0) = "same"
    dec_upper = case_when(
      resp_is_diff == TRUE  ~ 1L,  # Upper = Different
      resp_is_diff == FALSE ~ 0L,  # Lower = Same
      TRUE ~ NA_integer_
    ),
    
    # For readability/plotting
    response_label = ifelse(dec_upper == 1, "different", "same"),
    
    # Legacy columns (for compatibility)
    choice = as.integer(iscorr),
    choice_binary = as.integer(iscorr)
  )

# Verify coding
dec_dist <- table(ddm_ready$dec_upper, useNA = "always")
log_msg("  dec_upper distribution:")
log_msg(sprintf("    0 (Same): %d", dec_dist["0"] %||% 0))
log_msg(sprintf("    1 (Different): %d", dec_dist["1"] %||% 0))
log_msg(sprintf("    NA: %d", dec_dist["<NA>"] %||% 0))
log_msg("")

# =========================================================================
# STEP 7: COMPREHENSIVE VALIDATION CHECKS
# =========================================================================

log_msg("STEP 7: Running comprehensive validation checks...")
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

# Check 1: Verify dec_upper is only 0, 1, or NA
invalid_dec <- sum(!ddm_ready$dec_upper %in% c(0L, 1L, NA_integer_), na.rm = TRUE)
if (invalid_dec > 0) {
  log_msg("  ERROR: dec_upper contains invalid values!", level = "ERROR")
  stop("Invalid dec_upper values found")
} else {
  log_msg("  ✓ dec_upper coding: Valid (only 0, 1, or NA)")
}

# Check 2: Standard trials should be mostly "same"
std_trials <- ddm_ready %>% filter(difficulty_level == "Standard")
prop_std_diff <- mean(std_trials$dec_upper, na.rm = TRUE)
prop_std_same <- 1 - prop_std_diff

log_msg(sprintf("  Standard trials - Proportion 'Different': %.3f", prop_std_diff))
log_msg(sprintf("  Standard trials - Proportion 'Same': %.3f", prop_std_same))
if (prop_std_same > 0.80) {
  log_msg("  ✓ Standard trials show expected 'Same' bias (>80%)")
} else {
  log_msg("  WARNING: Standard trials show unexpected distribution", level = "WARN")
}

# Check 3: Response label consistency
label_check <- ddm_ready %>%
  filter(!is.na(dec_upper) & !is.na(response_label)) %>%
  summarise(
    all_diff_are_1 = all(dec_upper[response_label == "different"] == 1),
    all_same_are_0 = all(dec_upper[response_label == "same"] == 0)
  )

if (label_check$all_diff_are_1 && label_check$all_same_are_0) {
  log_msg("  ✓ Response labels match dec_upper coding")
} else {
  log_msg("  ERROR: Response label mismatch!", level = "ERROR")
  stop("Response label validation failed")
}

# Check 4: Direct vs inferred coding validation
validation_check <- ddm_ready %>%
  mutate(
    inferred_diff = case_when(
      difficulty_level == "Standard" & iscorr == 0 ~ 1L,
      difficulty_level != "Standard" & iscorr == 1 ~ 1L,
      TRUE ~ 0L
    )
  ) %>%
  summarise(
    match_rate = mean(dec_upper == inferred_diff, na.rm = TRUE),
    n_total = n(),
    n_matched = sum(dec_upper == inferred_diff, na.rm = TRUE),
    n_mismatched = sum(dec_upper != inferred_diff, na.rm = TRUE)
  )

log_msg(sprintf("  Direct vs Inferred match rate: %.4f", validation_check$match_rate))
log_msg(sprintf("    Matched: %d / %d", validation_check$n_matched, validation_check$n_total))
log_msg(sprintf("    Mismatched: %d", validation_check$n_mismatched))

if (validation_check$match_rate < 0.99) {
  log_msg("  WARNING: Some mismatches between direct and inferred coding", level = "WARN")
  log_msg("    (Using direct resp_is_diff as ground truth)")
}

log_msg("")

# =========================================================================
# STEP 8: SELECT FINAL COLUMNS
# =========================================================================

log_msg("STEP 8: Selecting final columns...")

ddm_ready <- ddm_ready %>%
  select(
    # Identifiers
    subject_id, task, run, trial_index,
    
    # Response variables
    rt, iscorr, choice, choice_binary,
    
    # CRITICAL: Response-side coding columns
    resp_is_diff, dec_upper, response_label,
    
    # Experimental conditions
    difficulty_level, effort_condition,
    
    # Stimulus properties
    stimLev, isOddball,
    
    # Grip force
    gf_trPer
  )

log_msg("  Selected", ncol(ddm_ready), "columns")
log_msg("")

# =========================================================================
# STEP 9: SAVE OUTPUT
# =========================================================================

log_msg("STEP 9: Saving output file...")

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
log_msg("DDM-ONLY DATA PREPARATION COMPLETE")
log_msg(strrep("=", 80))
log_msg("Final dataset:")
log_msg("  Total trials:", nrow(ddm_ready))
log_msg("  Subjects:", length(unique(ddm_ready$subject_id)))
log_msg("  Tasks:", paste(unique(ddm_ready$task), collapse = ", "))
log_msg("  Difficulty levels:", paste(levels(ddm_ready$difficulty_level), collapse = ", "))
log_msg("  Effort conditions:", paste(levels(ddm_ready$effort_condition), collapse = ", "))
log_msg("")
log_msg("Response-side coding:")
log_msg("  Upper boundary (1) = 'Different' responses")
log_msg("  Lower boundary (0) = 'Same' responses")
log_msg("  Standard trials - Proportion 'Same':", round(prop_std_same, 3))
log_msg("")
log_msg("Total elapsed time:", round(ELAPSED_TIME, 2), "seconds")
log_msg("End time:", format(END_TIME, "%Y-%m-%d %H:%M:%S"))
log_msg("=" %+% strrep("=", 78))


