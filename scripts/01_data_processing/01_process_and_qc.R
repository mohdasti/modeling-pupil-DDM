# =========================================================================
# SCRIPT 1: PROCESS, QC, AND VISUALIZE DATA
# =========================================================================
log_message("Data processing (Step 1) initiated.", "INIT")
log_message("Loading and summarizing Matlab-generated flat files...")
csv_files <- list.files(path = DATA_PATHS$raw_flat_files, pattern = "_flat\\.csv$", full.names = TRUE)
if (length(csv_files) == 0) {
    stop("FATAL: No '*_flat.csv' files found in '", DATA_PATHS$raw_flat_files, "'. Please check the path.")
}
pupil_data_raw <- purrr::map_dfr(csv_files, readr::read_csv, show_col_types = FALSE)
log_message(sprintf("Loaded %d rows from %d flat files.", nrow(pupil_data_raw), length(csv_files)))
# UPDATED: Handle NaN values (zeros converted to NaN in MATLAB pipeline)
# UPDATED: Use baseline_quality and overall_quality from MATLAB pipeline if available
pupil_summary_per_trial <- pupil_data_raw %>%
    dplyr::group_by(sub, task, run, trial_index) %>%
    dplyr::summarise(
        tonic_arousal = mean(pupil[trial_label == "ITI_Baseline"], na.rm = TRUE),
        effort_arousal_pupil = mean(pupil[trial_label == "Pre_Stimulus_Fixation"], na.rm = TRUE),
        # UPDATED: Check for valid (non-NaN) data instead of > 0 (zeros are now NaN)
        quality_iti = mean(!is.na(pupil[trial_label == "ITI_Baseline"]), na.rm = TRUE),
        quality_prestim = mean(!is.na(pupil[trial_label == "Pre_Stimulus_Fixation"]), na.rm = TRUE),
        # Use MATLAB pipeline quality metrics if available (more accurate)
        baseline_quality = if("baseline_quality" %in% names(pupil_data_raw)) dplyr::first(na.omit(baseline_quality)) else NA_real_,
        overall_quality = if("overall_quality" %in% names(pupil_data_raw)) dplyr::first(na.omit(overall_quality)) else NA_real_,
        .groups = "drop"
    ) %>%
    dplyr::mutate(
        effort_arousal_change = effort_arousal_pupil - tonic_arousal,
        # Prefer MATLAB pipeline quality metrics if available
        quality_iti = ifelse(!is.na(baseline_quality), baseline_quality, quality_iti),
        quality_prestim = ifelse(!is.na(overall_quality), overall_quality, quality_prestim)
    )
log_message("Loading and cleaning behavioral data...")
# Check if behavioral_file exists in DATA_PATHS, otherwise use behavioral_data
behavioral_file_path <- if (!is.null(DATA_PATHS$behavioral_file)) {
    DATA_PATHS$behavioral_file
} else if (!is.null(DATA_PATHS$behavioral_data)) {
    DATA_PATHS$behavioral_data
} else {
    stop("No behavioral data path found in DATA_PATHS")
}

behavioral_data_raw <- readr::read_csv(behavioral_file_path, show_col_types = FALSE)

# Map new column names to expected names if needed
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
log_message("Merging pupil summaries and behavioral data...")
full_dataset <- dplyr::left_join(
    behavioral_data_per_trial,
    pupil_summary_per_trial,
    by = c("sub", "task", "run", "trial_index")
) %>%
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
        rt, accuracy,
        tonic_arousal, effort_arousal_change,
        quality_iti, quality_prestim
    ) %>%
    dplyr::filter(!is.na(rt), !is.na(accuracy), !is.na(effort_condition), !is.na(difficulty_level))
log_message("Performing QC and creating tiered datasets...")
behavioral_dataset <- full_dataset %>%
    dplyr::select(subject_id, task, run, trial_index, effort_condition, difficulty_level, rt, accuracy)
output_path_behav <- file.path(DATA_PATHS$analysis_ready, "BAP_analysis_ready_BEHAVIORAL.csv")
readr::write_csv(behavioral_dataset, output_path_behav)
log_message(sprintf("SUCCESS: BEHAVIORAL dataset saved with %d trials.", nrow(behavioral_dataset)))
# UPDATED: Use 80% quality threshold (matching MATLAB pipeline standard)
pupil_dataset <- full_dataset %>%
    dplyr::filter(quality_iti >= 0.80 & quality_prestim >= 0.80)
output_path_pupil <- file.path(DATA_PATHS$analysis_ready, "BAP_analysis_ready_PUPIL.csv")
readr::write_csv(pupil_dataset, output_path_pupil)
log_message(sprintf("SUCCESS: PUPIL dataset saved with %d high-quality trials.", nrow(pupil_dataset)))
log_message("Data processing (Step 1) complete.", "SUCCESS")