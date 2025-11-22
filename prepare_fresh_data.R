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
behavioral_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/bap_trial_data_grip.csv"
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

# Standardize column names
if (!"rt" %in% names(behavioral_data) && "resp1RT" %in% names(behavioral_data)) {
    behavioral_data$rt <- behavioral_data$resp1RT
}
if (!"iscorr" %in% names(behavioral_data) && "accuracy" %in% names(behavioral_data)) {
    behavioral_data$iscorr <- behavioral_data$accuracy
}

# Filter behavioral data and standardize column names
behavioral_data <- behavioral_data %>%
    filter(!is.na(rt), rt >= 0.2, rt <= 3.0) %>%
    mutate(
        sub = as.character(sub),
        task = case_when(
            task == "aud" ~ "ADT",
            task == "vis" ~ "VDT",
            TRUE ~ as.character(task)
        ),
        # Ensure trial_index exists (may be called "trial")
        trial_index = if("trial_index" %in% names(.)) trial_index else if("trial" %in% names(.)) trial else NA_integer_
    )

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
if (!"effort_condition" %in% names(trialwise_pupil)) {
    if ("gf_trPer" %in% names(trialwise_pupil)) {
        cat("Creating effort_condition from gf_trPer (0.05 = Low, 0.4 = High)...\n")
        trialwise_pupil$effort_condition <- case_when(
            trialwise_pupil$gf_trPer == 0.05 ~ "Low_5_MVC",
            trialwise_pupil$gf_trPer == 0.4 ~ "High_MVC",
            TRUE ~ NA_character_
        )
        cat("Effort levels:", paste(unique(trialwise_pupil$effort_condition), collapse = ", "), "\n")
        cat("Count per level:\n")
        print(table(trialwise_pupil$effort_condition, useNA = "always"))
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
        rt >= 0.25, rt <= 3.0  # Raised floor to 250ms (research recommendation)
    ) %>%
    mutate(
        subject_id = as.factor(subject_id),
        task = as.factor(task),
        effort_condition = as.factor(if("effort_condition" %in% names(.)) effort_condition else "Unknown"),
        difficulty_level = case_when(
            isOddball == 0 ~ "Standard",
            stimLev %in% c(8, 16, 0.06, 0.12) ~ "Hard",
            stimLev %in% c(32, 64, 0.24, 0.48) ~ "Easy",
            TRUE ~ NA_character_
        ),
        difficulty_level = as.factor(difficulty_level),
        choice = as.integer(iscorr),
        choice_binary = as.integer(iscorr)
    ) %>%
    select(
        subject_id, task, run, trial_index, rt, choice, choice_binary, iscorr,
        difficulty_level, effort_condition, stimLev, isOddball,
        tonic_baseline, tonic_baseline_z,
        phasic_slope, phasic_slope_z,
        phasic_mean, phasic_mean_z,
        effort_arousal_change, effort_arousal_change_z
    )

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

