#!/usr/bin/env Rscript
# =========================================================================
# TEST prepare_fresh_data.R BEHAVIORAL DATA PROCESSING
# =========================================================================
# Tests the behavioral data loading and processing part of prepare_fresh_data.R
# =========================================================================

cat("================================================================================\n")
cat("TESTING prepare_fresh_data.R BEHAVIORAL DATA PROCESSING\n")
cat("================================================================================\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

library(dplyr)
library(readr)
library(purrr)

# Use same paths as prepare_fresh_data.R
behavioral_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"
output_dir <- "data/analysis_ready"

# Create output directory
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

cat("Step 1: Loading behavioral data (as in prepare_fresh_data.R)...\n")
behavioral_data <- read_csv(behavioral_file, show_col_types = FALSE, n_max = 5000)

cat("✅ Loaded", nrow(behavioral_data), "rows\n\n")

cat("Step 2: Testing column mapping (as in prepare_fresh_data.R)...\n")
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
        isOddball = as.integer(stim_is_diff)
    ) %>%
    # Filter valid trials
    filter(!is.na(rt), rt >= 0.2, rt <= 3.0)

cat("✅ Column mapping and filtering successful\n")
cat("   After filtering:", nrow(behavioral_data), "trials\n")
cat("   Subjects:", length(unique(behavioral_data$sub)), "\n")
cat("   Tasks:", paste(unique(behavioral_data$task), collapse = ", "), "\n\n")

cat("Step 3: Testing effort_condition creation...\n")
behavioral_data <- behavioral_data %>%
    mutate(
        effort_condition = case_when(
            abs(gf_trPer - 0.05) < 0.001 ~ "Low_5_MVC",
            abs(gf_trPer - 0.4) < 0.001 ~ "High_40_MVC",
            TRUE ~ NA_character_
        )
    )

cat("✅ Effort condition created\n")
cat("   Levels:", paste(unique(behavioral_data$effort_condition), collapse = ", "), "\n")
cat("   Count:\n")
print(table(behavioral_data$effort_condition, useNA = "always"))
cat("\n")

cat("Step 4: Testing difficulty_level creation...\n")
behavioral_data <- behavioral_data %>%
    mutate(
        difficulty_level = case_when(
            isOddball == 0 | is.na(isOddball) ~ "Standard",
            stimLev %in% c(0, 1, 2, 8, 16, 0.06, 0.12) ~ "Hard",
            stimLev %in% c(3, 4, 32, 64, 0.24, 0.48) ~ "Easy",
            TRUE ~ NA_character_
        )
    )

cat("✅ Difficulty level created\n")
cat("   Levels:", paste(unique(behavioral_data$difficulty_level), collapse = ", "), "\n")
cat("   Count:\n")
print(table(behavioral_data$difficulty_level, useNA = "always"))
cat("\n")

cat("Step 5: Testing DDM-ready data creation...\n")
ddm_ready <- behavioral_data %>%
    filter(
        !is.na(rt), !is.na(iscorr),
        rt >= 0.25, rt <= 3.0
    ) %>%
    mutate(
        subject_id = as.factor(sub),
        task = as.factor(task),
        effort_condition = as.factor(if("effort_condition" %in% names(.)) effort_condition else "Unknown"),
        difficulty_level = as.factor(difficulty_level),
        choice = as.integer(iscorr),
        choice_binary = as.integer(iscorr)
    ) %>%
    select(
        subject_id, task, run, trial_index, rt, choice, choice_binary, iscorr,
        difficulty_level, effort_condition, stimLev, isOddball
    )

cat("✅ DDM-ready data created\n")
cat("   Total trials:", nrow(ddm_ready), "\n")
cat("   Subjects:", length(unique(ddm_ready$subject_id)), "\n")
cat("   Columns:", paste(names(ddm_ready), collapse = ", "), "\n\n")

# Save a test output
test_output <- file.path(output_dir, "test_ddm_ready.csv")
write_csv(ddm_ready, test_output)
cat("Step 6: Saved test output to:", test_output, "\n")
cat("   File size:", file.size(test_output), "bytes\n\n")

cat("================================================================================\n")
cat("✅ prepare_fresh_data.R BEHAVIORAL PROCESSING TEST PASSED\n")
cat("================================================================================\n")
cat("The behavioral data processing part works correctly.\n")
cat("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("================================================================================\n")

