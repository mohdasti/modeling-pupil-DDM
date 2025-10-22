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
pupil_summary_per_trial <- pupil_data_raw %>%
    dplyr::group_by(sub, task, run, trial_index) %>%
    dplyr::summarise(
        tonic_arousal = mean(pupil[trial_label == "ITI_Baseline"], na.rm = TRUE),
        effort_arousal_pupil = mean(pupil[trial_label == "Pre_Stimulus_Fixation"], na.rm = TRUE),
        quality_iti = mean(pupil[trial_label == "ITI_Baseline"] > 0, na.rm = TRUE),
        quality_prestim = mean(pupil[trial_label == "Pre_Stimulus_Fixation"] > 0, na.rm = TRUE),
        .groups = "drop"
    ) %>%
    dplyr::mutate(effort_arousal_change = effort_arousal_pupil - tonic_arousal)
log_message("Loading and cleaning behavioral data...")
behavioral_data_per_trial <- readr::read_csv(DATA_PATHS$behavioral_file, show_col_types = FALSE) %>%
    dplyr::select(sub, task, run, trial, rt = resp1RT, accuracy = iscorr, gf_trPer, stimLev, isOddball) %>%
    dplyr::mutate(task = dplyr::if_else(task == "aud", "ADT", "VDT")) %>%
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
pupil_dataset <- full_dataset %>%
    dplyr::filter(quality_iti > 0.6 & quality_prestim > 0.6)
output_path_pupil <- file.path(DATA_PATHS$analysis_ready, "BAP_analysis_ready_PUPIL.csv")
readr::write_csv(pupil_dataset, output_path_pupil)
log_message(sprintf("SUCCESS: PUPIL dataset saved with %d high-quality trials.", nrow(pupil_dataset)))
log_message("Data processing (Step 1) complete.", "SUCCESS")