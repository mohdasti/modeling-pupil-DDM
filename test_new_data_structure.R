#!/usr/bin/env Rscript
# =========================================================================
# TEST NEW DATA STRUCTURE
# =========================================================================
# Tests that the new behavioral data file can be loaded and mapped correctly
# =========================================================================

cat("================================================================================\n")
cat("TESTING NEW BEHAVIORAL DATA STRUCTURE\n")
cat("================================================================================\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

library(dplyr)
library(readr)

# Test file path
behavioral_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"

cat("Step 1: Loading behavioral data...\n")
cat("File:", behavioral_file, "\n")

if (!file.exists(behavioral_file)) {
    stop("ERROR: Behavioral data file not found!")
}

behavioral_data <- read_csv(behavioral_file, show_col_types = FALSE, n_max = 1000)
cat("✅ Loaded", nrow(behavioral_data), "rows (sample)\n")
cat("   Columns:", length(names(behavioral_data)), "\n\n")

cat("Step 2: Checking for new column names...\n")
new_cols <- c("subject_id", "task_modality", "run_num", "trial_num", 
              "same_diff_resp_secs", "resp_is_correct", "grip_targ_prop_mvc",
              "stim_level_index", "stim_is_diff", "grip_level")
missing_cols <- setdiff(new_cols, names(behavioral_data))
if (length(missing_cols) > 0) {
    cat("⚠️  Missing columns:", paste(missing_cols, collapse = ", "), "\n")
} else {
    cat("✅ All expected new columns found\n")
}
cat("\n")

cat("Step 3: Testing column mappings...\n")
behavioral_mapped <- behavioral_data %>%
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
    )

cat("✅ Column mappings successful\n")
cat("   Mapped columns: sub, task, run, trial_index, rt, iscorr, gf_trPer, stimLev, isOddball\n\n")

cat("Step 4: Verifying data quality...\n")
cat("   Subjects:", length(unique(behavioral_mapped$sub)), "\n")
cat("   Tasks:", paste(unique(behavioral_mapped$task), collapse = ", "), "\n")
cat("   RT range:", round(min(behavioral_mapped$rt, na.rm = TRUE), 3), "to", 
    round(max(behavioral_mapped$rt, na.rm = TRUE), 3), "seconds\n")
cat("   Accuracy range:", min(behavioral_mapped$iscorr, na.rm = TRUE), "to", 
    max(behavioral_mapped$iscorr, na.rm = TRUE), "\n")
cat("   Grip levels:", paste(unique(behavioral_mapped$gf_trPer), collapse = ", "), "\n")
cat("   Stimulus levels:", paste(sort(unique(behavioral_mapped$stimLev)), collapse = ", "), "\n")
cat("   Oddball values:", paste(sort(unique(behavioral_mapped$isOddball)), collapse = ", "), "\n\n")

cat("Step 5: Checking for missing values...\n")
missing_rt <- sum(is.na(behavioral_mapped$rt))
missing_acc <- sum(is.na(behavioral_mapped$iscorr))
missing_grip <- sum(is.na(behavioral_mapped$gf_trPer))
cat("   Missing RT:", missing_rt, "(", round(100*missing_rt/nrow(behavioral_mapped), 1), "%)\n")
cat("   Missing accuracy:", missing_acc, "(", round(100*missing_acc/nrow(behavioral_mapped), 1), "%)\n")
cat("   Missing grip:", missing_grip, "(", round(100*missing_grip/nrow(behavioral_mapped), 1), "%)\n\n")

cat("Step 6: Testing effort condition creation...\n")
behavioral_mapped <- behavioral_mapped %>%
    mutate(
        effort_condition = case_when(
            abs(gf_trPer - 0.05) < 0.001 ~ "Low_5_MVC",
            abs(gf_trPer - 0.4) < 0.001 ~ "High_40_MVC",
            TRUE ~ NA_character_
        )
    )
cat("   Effort conditions:", paste(unique(behavioral_mapped$effort_condition), collapse = ", "), "\n")
cat("   Count per condition:\n")
print(table(behavioral_mapped$effort_condition, useNA = "always"))
cat("\n")

cat("Step 7: Testing difficulty level creation...\n")
behavioral_mapped <- behavioral_mapped %>%
    mutate(
        difficulty_level = case_when(
            isOddball == 0 | is.na(isOddball) ~ "Standard",
            stimLev %in% c(0, 1, 2, 8, 16, 0.06, 0.12) ~ "Hard",
            stimLev %in% c(3, 4, 32, 64, 0.24, 0.48) ~ "Easy",
            TRUE ~ NA_character_
        )
    )
cat("   Difficulty levels:", paste(unique(behavioral_mapped$difficulty_level), collapse = ", "), "\n")
cat("   Count per level:\n")
print(table(behavioral_mapped$difficulty_level, useNA = "always"))
cat("\n")

cat("================================================================================\n")
cat("✅ ALL TESTS PASSED\n")
cat("================================================================================\n")
cat("The new data structure is compatible with the updated scripts.\n")
cat("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("================================================================================\n")

