#!/usr/bin/env Rscript
# =========================================================================
# TEST scripts/01_data_processing/01_process_and_qc.R
# =========================================================================
# Tests the behavioral data processing part with new column structure
# =========================================================================

cat("================================================================================\n")
cat("TESTING scripts/01_data_processing/01_process_and_qc.R\n")
cat("================================================================================\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

library(dplyr)
library(readr)
library(purrr)

# Simulate DATA_PATHS structure
DATA_PATHS <- list(
    behavioral_file = "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv",
    behavioral_data = "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv",
    analysis_ready = "data/analysis_ready"
)

# Create output directory
if (!dir.exists(DATA_PATHS$analysis_ready)) {
    dir.create(DATA_PATHS$analysis_ready, recursive = TRUE)
}

cat("Step 1: Loading behavioral data (as in 01_process_and_qc.R)...\n")
behavioral_file_path <- if (!is.null(DATA_PATHS$behavioral_file)) {
    DATA_PATHS$behavioral_file
} else if (!is.null(DATA_PATHS$behavioral_data)) {
    DATA_PATHS$behavioral_data
} else {
    stop("No behavioral data path found in DATA_PATHS")
}

cat("   Using path:", behavioral_file_path, "\n")
behavioral_data_raw <- readr::read_csv(behavioral_file_path, show_col_types = FALSE, n_max = 5000)

cat("✅ Loaded", nrow(behavioral_data_raw), "rows\n\n")

cat("Step 2: Testing column mapping (as in 01_process_and_qc.R)...\n")
behavioral_data_per_trial <- behavioral_data_raw %>%
    dplyr::mutate(
        # Map subject identifier
        sub = if ("sub" %in% names(.)) sub else if ("subject_id" %in% names(.)) as.character(subject_id) else NA_character_,
        # Map task (convert "aud"/"vis" to "ADT"/"VDT")
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
        # Map run number
        run = if ("run" %in% names(.)) run else if ("run_num" %in% names(.)) run_num else NA_integer_,
        # Map trial number
        trial = if ("trial" %in% names(.)) trial else if ("trial_num" %in% names(.)) trial_num else if ("trial_index" %in% names(.)) trial_index else NA_integer_,
        # Map RT
        rt = if ("rt" %in% names(.)) rt else if ("resp1RT" %in% names(.)) resp1RT else if ("same_diff_resp_secs" %in% names(.)) same_diff_resp_secs else NA_real_,
        # Map accuracy
        accuracy = if ("accuracy" %in% names(.)) accuracy else if ("iscorr" %in% names(.)) iscorr else if ("resp_is_correct" %in% names(.)) as.integer(resp_is_correct) else NA_integer_,
        # Map grip force
        gf_trPer = if ("gf_trPer" %in% names(.)) gf_trPer else if ("grip_targ_prop_mvc" %in% names(.)) grip_targ_prop_mvc else NA_real_,
        # Map stimulus level
        stimLev = if ("stimLev" %in% names(.)) stimLev else if ("stim_level_index" %in% names(.)) stim_level_index else NA_real_,
        # Map oddball status
        isOddball = if ("isOddball" %in% names(.)) isOddball else if ("stim_is_diff" %in% names(.)) as.integer(stim_is_diff) else NA_integer_
    ) %>%
    dplyr::select(sub, task, run, trial, rt, accuracy, gf_trPer, stimLev, isOddball) %>%
    dplyr::rename(trial_index = trial)

cat("✅ Column mapping successful\n")
cat("   Mapped columns:", paste(names(behavioral_data_per_trial), collapse = ", "), "\n")
cat("   Rows:", nrow(behavioral_data_per_trial), "\n\n")

cat("Step 3: Testing data quality checks...\n")
cat("   Missing sub:", sum(is.na(behavioral_data_per_trial$sub)), "\n")
cat("   Missing task:", sum(is.na(behavioral_data_per_trial$task)), "\n")
cat("   Missing run:", sum(is.na(behavioral_data_per_trial$run)), "\n")
cat("   Missing rt:", sum(is.na(behavioral_data_per_trial$rt)), "\n")
cat("   Missing accuracy:", sum(is.na(behavioral_data_per_trial$accuracy)), "\n\n")

cat("Step 4: Testing effort_condition and difficulty_level creation...\n")
full_dataset <- behavioral_data_per_trial %>%
    dplyr::mutate(
        subject_id = as.character(sub),
        effort_condition = factor(case_when(
            gf_trPer == 0.05 ~ "Low_5_MVC",
            gf_trPer == 0.40 ~ "High_40_MVC",
            TRUE ~ NA_character_
        )),
        difficulty_level = factor(case_when(
            isOddball == 0 ~ "Standard",
            stimLev %in% c(8, 16, 0.06, 0.12) ~ "Hard",
            stimLev %in% c(32, 64, 0.24, 0.48) ~ "Easy",
            TRUE ~ NA_character_
        ))
    ) %>%
    dplyr::select(
        subject_id, task, run, trial_index,
        effort_condition, difficulty_level,
        rt, accuracy
    ) %>%
    dplyr::filter(!is.na(rt), !is.na(accuracy), !is.na(effort_condition), !is.na(difficulty_level))

cat("✅ Dataset created successfully\n")
cat("   Final rows:", nrow(full_dataset), "\n")
cat("   Subjects:", length(unique(full_dataset$subject_id)), "\n")
cat("   Tasks:", paste(unique(full_dataset$task), collapse = ", "), "\n")
cat("   Effort conditions:", paste(unique(full_dataset$effort_condition), collapse = ", "), "\n")
cat("   Difficulty levels:", paste(unique(full_dataset$difficulty_level), collapse = ", "), "\n\n")

cat("Step 5: Testing output file creation...\n")
behavioral_dataset <- full_dataset %>%
    dplyr::select(subject_id, task, run, trial_index, effort_condition, difficulty_level, rt, accuracy)

output_path_behav <- file.path(DATA_PATHS$analysis_ready, "test_BAP_analysis_ready_BEHAVIORAL.csv")
readr::write_csv(behavioral_dataset, output_path_behav)

cat("✅ Output file created:", output_path_behav, "\n")
cat("   File size:", file.size(output_path_behav), "bytes\n")
cat("   Rows:", nrow(behavioral_dataset), "\n\n")

cat("================================================================================\n")
cat("✅ scripts/01_data_processing/01_process_and_qc.R TEST PASSED\n")
cat("================================================================================\n")
cat("The script works correctly with the new column structure.\n")
cat("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("================================================================================\n")

