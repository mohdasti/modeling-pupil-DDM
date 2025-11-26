#!/usr/bin/env Rscript
# =========================================================================
# PREPARE FRESH DATA FOR ANALYSIS
# =========================================================================
# Processes pupil flat files and behavioral data to create analysis-ready datasets
# =========================================================================

cat("================================================================================\n")
cat("PREPARING FRESH DATA FOR ANALYSIS\n")
cat("================================================================================\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

library(dplyr)
library(readr)
library(purrr)

# =========================================================================
# CONFIGURATION
# =========================================================================

# Data paths
pupil_flat_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
behavioral_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"
output_dir <- "data/analysis_ready"

# Create output directory
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

cat("[", format(Sys.time(), "%H:%M:%S"), "] Step 1: Loading pupil flat files...\n")

# =========================================================================
# STEP 1: LOAD AND COMBINE PUPIL FLAT FILES
# =========================================================================

flat_files <- list.files(pupil_flat_dir, pattern = "_flat\\.csv$", full.names = TRUE)

if (length(flat_files) == 0) {
    stop("ERROR: No flat CSV files found in ", pupil_flat_dir)
}

cat("Found", length(flat_files), "flat files\n")
cat("Loading and combining...\n")

pupil_flat <- map_dfr(flat_files, function(f) {
    tryCatch({
        read_csv(f, show_col_types = FALSE, progress = FALSE)
    }, error = function(e) {
        cat("  Warning: Error reading", basename(f), "-", e$message, "\n")
        return(tibble())
    })
})

cat("[", format(Sys.time(), "%H:%M:%S"), "] Loaded", nrow(pupil_flat), "pupil samples\n")
cat("  Subjects:", length(unique(pupil_flat$sub)), "\n")
cat("  Tasks:", paste(unique(pupil_flat$task), collapse = ", "), "\n\n")

# Save combined flat file
flat_output <- file.path(output_dir, "bap_processed_pupil_flat.csv")
write_csv(pupil_flat, flat_output)
cat("[", format(Sys.time(), "%H:%M:%S"), "] Saved combined flat file:", flat_output, "\n\n")

# =========================================================================
# STEP 2: CREATE TRIAL-LEVEL PUPIL FEATURES
# =========================================================================

cat("[", format(Sys.time(), "%H:%M:%S"), "] Step 2: Computing trial-level pupil features...\n")

# Load behavioral data to get trial identifiers
cat("Loading behavioral data...\n")
behavioral_data <- read_csv(behavioral_file, show_col_types = FALSE)

# Map new column names to expected names
# New file has: subject_id, task_modality, run_num, trial_num, same_diff_resp_secs, resp_is_correct, etc.
behavioral_data <- behavioral_data %>%
    mutate(
        # Map subject identifier
        sub = as.character(subject_id),
        # Map task (convert "aud"/"vis" to "ADT"/"VDT")
        task = case_when(
            task_modality == "aud" ~ "ADT",
            task_modality == "vis" ~ "VDT",
            TRUE ~ as.character(task_modality)
        ),
        # Map run number
        run = run_num,
        # Map trial number
        trial_index = trial_num,
        # Map RT (response time in seconds)
        rt = same_diff_resp_secs,
        # Map accuracy (convert True/False to 1/0)
        iscorr = as.integer(resp_is_correct),
        # Map grip force (use grip_targ_prop_mvc which has numeric values 0.05/0.4)
        gf_trPer = grip_targ_prop_mvc,
        # Map stimulus level
        stimLev = stim_level_index,
        # Map oddball status (convert True/False to 1/0)
        isOddball = as.integer(stim_is_diff),
        # CRITICAL: Include direct response-side column for DDM
        # resp_is_diff: TRUE = "different", FALSE = "same"
        resp_is_diff = resp_is_diff
    ) %>%
    # Filter valid trials
    filter(!is.na(rt), rt >= 0.2, rt <= 3.0)

cat("Behavioral data: ", nrow(behavioral_data), "trials from", length(unique(behavioral_data$sub)), "subjects\n")

# Compute tonic baseline (ITI period)
cat("Computing tonic baseline (ITI)...\n")
tonic_baseline <- pupil_flat %>%
    filter(trial_label == "ITI_Baseline" | grepl("ITI", trial_label)) %>%
    group_by(sub, task, run, trial_index) %>%
    summarise(
        tonic_baseline = mean(pupil, na.rm = TRUE),
        tonic_samples = n(),
        .groups = "drop"
    )

# Compute phasic features (200-900ms after stimulus)
cat("Computing phasic features (200-900ms)...\n")
phasic_features <- pupil_flat %>%
    filter(
        has_behavioral_data == 1,
        !is.na(time),
        time >= 0.2,  # 200ms after stimulus
        time <= 0.9   # 900ms after stimulus
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

# Merge features
trialwise_pupil <- behavioral_data %>%
    left_join(tonic_baseline, by = c("sub", "task", "run", "trial_index" = "trial_index")) %>%
    left_join(phasic_features, by = c("sub", "task", "run", "trial_index" = "trial_index")) %>%
    mutate(
        subject_id = sub,
        # CRITICAL: resp_is_diff is already in behavioral_data from the mutate() above
        # Create scaled features
        tonic_baseline_z = scale(tonic_baseline)[,1],
        phasic_slope_z = scale(phasic_slope)[,1],
        phasic_mean_z = scale(phasic_mean)[,1],
        # Effort arousal change (pre-stimulus - baseline)
        effort_arousal_change = phasic_mean - tonic_baseline,
        effort_arousal_change_z = scale(effort_arousal_change)[,1]
    )

# Save trialwise features
trialwise_output <- file.path(output_dir, "BAP_trialwise_pupil_features.csv")
write_csv(trialwise_pupil, trialwise_output)
cat("[", format(Sys.time(), "%H:%M:%S"), "] Saved trialwise pupil features:", trialwise_output, "\n")
cat("  Trials with pupil data:", sum(!is.na(trialwise_pupil$tonic_baseline)), "\n\n")

# =========================================================================
# STEP 3: CREATE DDM-READY DATA
# =========================================================================

cat("[", format(Sys.time(), "%H:%M:%S"), "] Step 3: Creating DDM-ready data...\n")

# Create effort_condition from gf_trPer (Grip Force Trial Percent)
# Values: 0.05 = Low (5% MVC), 0.4 = High (40% MVC)
# Note: New file has grip_targ_prop_mvc with values 0.05 and 0.4
if (!"effort_condition" %in% names(trialwise_pupil)) {
    if ("gf_trPer" %in% names(trialwise_pupil)) {
        cat("Creating effort_condition from gf_trPer (0.05 = Low, 0.4 = High)...\n")
        trialwise_pupil$effort_condition <- case_when(
            abs(trialwise_pupil$gf_trPer - 0.05) < 0.001 ~ "Low_5_MVC",
            abs(trialwise_pupil$gf_trPer - 0.4) < 0.001 ~ "High_40_MVC",
            TRUE ~ NA_character_
        )
        cat("Effort levels:", paste(unique(trialwise_pupil$effort_condition), collapse = ", "), "\n")
        cat("Count per level:\n")
        print(table(trialwise_pupil$effort_condition, useNA = "always"))
    } else if ("grip_level" %in% names(trialwise_pupil)) {
        # Fallback: use grip_level if gf_trPer not available
        cat("Creating effort_condition from grip_level (low/high)...\n")
        trialwise_pupil$effort_condition <- case_when(
            tolower(trialwise_pupil$grip_level) == "low" ~ "Low_5_MVC",
            tolower(trialwise_pupil$grip_level) == "high" ~ "High_40_MVC",
            TRUE ~ NA_character_
        )
    } else if ("mvc" %in% names(trialwise_pupil)) {
        # Fallback: use mvc median split if gf_trPer not available
        mvc_median <- median(trialwise_pupil$mvc, na.rm = TRUE)
        trialwise_pupil$effort_condition <- case_when(
            is.na(trialwise_pupil$mvc) ~ NA_character_,
            trialwise_pupil$mvc <= mvc_median ~ "Low_MVC",
            trialwise_pupil$mvc > mvc_median ~ "High_MVC",
            TRUE ~ NA_character_
        )
    } else if ("force_condition" %in% names(trialwise_pupil)) {
        trialwise_pupil$effort_condition <- trialwise_pupil$force_condition
    }
}

ddm_ready <- trialwise_pupil %>%
    filter(
        !is.na(rt), !is.na(iscorr),
        rt >= 0.25, rt <= 3.0,  # Raised floor to 250ms (research recommendation)
        !is.na(resp_is_diff)  # CRITICAL: Exclude trials with missing response choice
    ) %>%
    mutate(
        subject_id = as.factor(subject_id),
        task = as.factor(task),
        effort_condition = as.factor(if("effort_condition" %in% names(.)) effort_condition else "Unknown"),
        difficulty_level = case_when(
            isOddball == 0 | is.na(isOddball) ~ "Standard",
            stimLev %in% c(0, 1, 2, 8, 16, 0.06, 0.12) ~ "Hard",
            stimLev %in% c(3, 4, 32, 64, 0.24, 0.48) ~ "Easy",
            TRUE ~ NA_character_
        ),
        difficulty_level = as.factor(difficulty_level),
        choice = as.integer(iscorr),
        choice_binary = as.integer(iscorr),
        # CRITICAL: Create explicit integer DDM boundary coding
        # Upper boundary (1) = "different", Lower boundary (0) = "same"
        resp_is_diff = as.logical(resp_is_diff),  # Ensure boolean
        dec_upper = case_when(
            resp_is_diff == TRUE  ~ 1L,  # Upper = Different
            resp_is_diff == FALSE ~ 0L,  # Lower = Same
            TRUE ~ NA_integer_
        ),
        # For readability/plotting only
        response_label = ifelse(dec_upper == 1, "different", "same")
    ) %>%
    select(
        subject_id, task, run, trial_index, rt, choice, choice_binary, iscorr,
        difficulty_level, effort_condition, stimLev, isOddball,
        resp_is_diff, dec_upper, response_label,  # CRITICAL: Include response-side columns
        tonic_baseline, tonic_baseline_z,
        phasic_slope, phasic_slope_z,
        phasic_mean, phasic_mean_z,
        effort_arousal_change, effort_arousal_change_z
    )

# =========================================================================
# VALIDATION CHECKS
# =========================================================================

cat("\n[", format(Sys.time(), "%H:%M:%S"), "] Running validation checks...\n")

# Check 1: Verify boundary proportions match expectations
prop_std_diff <- mean(subset(ddm_ready, difficulty_level=="Standard")$dec_upper, na.rm=TRUE)
cat("  Standard trials - Proportion 'Different':", round(prop_std_diff, 3), 
    "(Expected: ~0.12 for 87.8% 'Same')\n")

# Check 2: Validate direct vs inferred coding match
validation_check <- ddm_ready %>%
    mutate(
        inferred_diff = case_when(
            difficulty_level == "Standard" & iscorr == 0 ~ 1L,  # Error on Standard = Different
            difficulty_level != "Standard" & iscorr == 1 ~ 1L,  # Correct on Easy/Hard = Different
            TRUE ~ 0L
        )
    ) %>%
    summarise(
        match_rate = mean(dec_upper == inferred_diff, na.rm=TRUE),
        n_total = n(),
        n_matched = sum(dec_upper == inferred_diff, na.rm=TRUE)
    )

cat("  Direct vs Inferred coding match rate:", round(validation_check$match_rate, 4), 
    "(", validation_check$n_matched, "/", validation_check$n_total, ")\n")

if(validation_check$match_rate < 0.999) {
    warning("CRITICAL: Raw response data does not match inferred accuracy logic!")
    warning("Match rate:", validation_check$match_rate, "- Investigate data quality issues")
}

# Check 3: Verify dec_upper is properly coded (should be only 0 or 1)
invalid_dec <- sum(!ddm_ready$dec_upper %in% c(0L, 1L, NA_integer_), na.rm=TRUE)
if(invalid_dec > 0) {
    stop("ERROR: dec_upper contains invalid values (not 0, 1, or NA)")
} else {
    cat("  dec_upper coding: Valid (only 0, 1, or NA)\n")
}

cat("  Validation complete.\n\n")

ddm_output <- file.path(output_dir, "bap_ddm_ready.csv")
write_csv(ddm_ready, ddm_output)
cat("[", format(Sys.time(), "%H:%M:%S"), "] Saved DDM-ready data:", ddm_output, "\n")
cat("  Total trials:", nrow(ddm_ready), "\n")
cat("  Subjects:", length(unique(ddm_ready$subject_id)), "\n\n")

cat("================================================================================\n")
cat("✅ DATA PREPARATION COMPLETE\n")
cat("================================================================================\n")
cat("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Files created:\n")
cat("  -", flat_output, "\n")
cat("  -", trialwise_output, "\n")
cat("  -", ddm_output, "\n")
cat("================================================================================\n")

