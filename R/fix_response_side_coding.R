# R/fix_response_side_coding.R
# =========================================================================
# FIX RESPONSE-SIDE CODING IN EXISTING DATA FILES
# =========================================================================
# This script updates existing analysis-ready files to use direct resp_is_diff
# instead of inferred response-side coding

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

cat("================================================================================\n")
cat("FIXING RESPONSE-SIDE CODING\n")
cat("================================================================================\n\n")

# Load raw behavioral data to get resp_is_diff
raw_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"
cat("Loading raw behavioral data:", raw_file, "\n")
raw_behav <- read_csv(raw_file, show_col_types = FALSE)

# Load existing analysis-ready file
ddm_file <- "data/analysis_ready/bap_ddm_ready.csv"
cat("Loading existing DDM-ready file:", ddm_file, "\n")
ddm_data <- read_csv(ddm_file, show_col_types = FALSE)

# Merge resp_is_diff from raw data
# Match on: subject_id, task, run, trial_index
ddm_fixed <- ddm_data %>%
  mutate(
    # Ensure matching columns exist
    subject_id_char = as.character(subject_id),
    task_char = as.character(task)
  ) %>%
  left_join(
    raw_behav %>%
      mutate(
        subject_id_char = as.character(subject_id),
        task_char = case_when(
          task_modality == "aud" ~ "ADT",
          task_modality == "vis" ~ "VDT",
          TRUE ~ as.character(task_modality)
        ),
        run_num_match = run_num,
        trial_num_match = trial_num
      ) %>%
      select(subject_id_char, task_char, run_num_match, trial_num_match, resp_is_diff),
    by = c("subject_id_char" = "subject_id_char",
           "task_char" = "task_char",
           "run" = "run_num_match",
           "trial_index" = "trial_num_match")
  ) %>%
  # Filter out trials with missing resp_is_diff
  filter(!is.na(resp_is_diff)) %>%
  # Create explicit DDM boundary coding
  mutate(
    resp_is_diff = as.logical(resp_is_diff),
    dec_upper = case_when(
      resp_is_diff == TRUE  ~ 1L,  # Upper = Different
      resp_is_diff == FALSE ~ 0L,  # Lower = Same
      TRUE ~ NA_integer_
    ),
    response_label = ifelse(dec_upper == 1, "different", "same")
  ) %>%
  select(-subject_id_char, -task_char)

cat("\nOriginal trials:", nrow(ddm_data), "\n")
cat("Trials after adding resp_is_diff:", nrow(ddm_fixed), "\n")
cat("Trials excluded (missing resp_is_diff):", nrow(ddm_data) - nrow(ddm_fixed), "\n\n")

# Validation checks
cat("Validation checks:\n")
prop_std_diff <- mean(subset(ddm_fixed, difficulty_level=="Standard")$dec_upper, na.rm=TRUE)
cat("  Standard trials - Proportion 'Different':", round(prop_std_diff, 3), "\n")

validation_check <- ddm_fixed %>%
  mutate(
    inferred_diff = case_when(
      difficulty_level == "Standard" & iscorr == 0 ~ 1L,
      difficulty_level != "Standard" & iscorr == 1 ~ 1L,
      TRUE ~ 0L
    )
  ) %>%
  summarise(
    match_rate = mean(dec_upper == inferred_diff, na.rm=TRUE),
    n_total = n()
  )

cat("  Direct vs Inferred match rate:", round(validation_check$match_rate, 4), "\n")

if(validation_check$match_rate < 0.999) {
  warning("WARNING: Some mismatches between direct and inferred coding!")
}

# Save fixed file
output_file <- "data/analysis_ready/bap_ddm_ready_fixed.csv"
write_csv(ddm_fixed, output_file)
cat("\n✓ Saved fixed file:", output_file, "\n")

# Also update the _with_upper file
output_file2 <- "data/analysis_ready/bap_ddm_ready_with_upper_fixed.csv"
write_csv(ddm_fixed, output_file2)
cat("✓ Saved:", output_file2, "\n")

cat("\n================================================================================\n")
cat("COMPLETE\n")
cat("================================================================================\n")

