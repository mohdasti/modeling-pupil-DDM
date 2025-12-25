# ============================================================================
# Prepare Analysis-Ready Data
# ============================================================================
# Creates trial-level dataset with behavioral and pupil data
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(tidyr)
})

cat("Preparing analysis-ready data...\n")

# Load the flat pupil data
flat_data <- read_csv("data/analysis_ready/bap_processed_pupil_flat.csv", 
                      show_col_types = FALSE)

cat("Loaded", nrow(flat_data), "samples\n")

# Extract behavioral columns for those that have them
has_behav <- flat_data %>% filter(has_behavioral_data == 1)

cat("Samples with behavioral data:", nrow(has_behav), "\n")

# Create trial-level dataset with behavioral data
# First, ensure all expected columns exist (add as NA if missing)
has_behav <- has_behav %>%
  mutate(
    mvc = if ("mvc" %in% names(.)) mvc else NA_real_,
    ses = if ("ses" %in% names(.)) ses else NA_real_,
    stimLev = if ("stimLev" %in% names(.)) stimLev else NA_real_,
    isOddball = if ("isOddball" %in% names(.)) isOddball else NA_integer_,
    isStrength = if ("isStrength" %in% names(.)) isStrength else NA_integer_,
    iscorr = if ("iscorr" %in% names(.)) iscorr else NA_integer_,
    resp1 = if ("resp1" %in% names(.)) resp1 else NA_real_,
    resp1RT = if ("resp1RT" %in% names(.)) resp1RT else NA_real_,
    resp2 = if ("resp2" %in% names(.)) resp2 else NA_real_,
    resp2RT = if ("resp2RT" %in% names(.)) resp2RT else NA_real_,
    auc_rel_mvc = if ("auc_rel_mvc" %in% names(.)) auc_rel_mvc else NA_real_,
    resp1_isdiff = if ("resp1_isdiff" %in% names(.)) resp1_isdiff else NA_integer_,
    gf_trPer = if ("gf_trPer" %in% names(.)) gf_trPer else NA_real_,
    hit = if ("hit" %in% names(.)) hit else NA_integer_,
    miss = if ("miss" %in% names(.)) miss else NA_integer_,
    fa = if ("fa" %in% names(.)) fa else NA_integer_,
    cr = if ("cr" %in% names(.)) cr else NA_integer_,
    auc = if ("auc" %in% names(.)) auc else NA_real_,
    auc_prop_targ = if ("auc_prop_targ" %in% names(.)) auc_prop_targ else NA_real_,
    run_index = if ("run_index" %in% names(.)) run_index else NA_integer_,
    duration_index = if ("duration_index" %in% names(.)) duration_index else NA_integer_,
    trial = if ("trial" %in% names(.)) trial else NA_integer_,
    force_condition = if ("force_condition" %in% names(.)) force_condition else NA_character_,
    stimulus_condition = if ("stimulus_condition" %in% names(.)) stimulus_condition else NA_character_
  )

trial_data <- has_behav %>%
  group_by(sub, task, run, trial_index) %>%
  summarise(
    # Pupil metrics
    pupil_baseline = mean(pupil[time < -0.5], na.rm = TRUE),
    pupil_evoked = mean(pupil[time > 0.3 & time < 1.2], na.rm = TRUE),
    pupil_mean = mean(pupil, na.rm = TRUE),
    
    # Behavioral data (take first non-NA value)
    mvc = first(na.omit(mvc)),
    ses = first(na.omit(ses)),
    stimLev = first(na.omit(stimLev)),
    isOddball = first(na.omit(isOddball)),
    isStrength = first(na.omit(isStrength)),
    iscorr = first(na.omit(iscorr)),
    resp1 = first(na.omit(resp1)),
    resp1RT = first(na.omit(resp1RT)),
    resp2 = first(na.omit(resp2)),
    resp2RT = first(na.omit(resp2RT)),
    auc_rel_mvc = first(na.omit(auc_rel_mvc)),
    resp1_isdiff = first(na.omit(resp1_isdiff)),
    gf_trPer = first(na.omit(gf_trPer)),
    hit = first(na.omit(hit)),
    miss = first(na.omit(miss)),
    fa = first(na.omit(fa)),
    cr = first(na.omit(cr)),
    auc = first(na.omit(auc)),
    auc_prop_targ = first(na.omit(auc_prop_targ)),
    run_index = first(na.omit(run_index)),
    duration_index = first(na.omit(duration_index)),
    trial = first(na.omit(trial)),
    force_condition = first(na.omit(force_condition)),
    stimulus_condition = first(na.omit(stimulus_condition)),
    .groups = "drop"
  )

cat("Created", nrow(trial_data), "trial-level observations\n")

# Clean and prepare for DDM analysis
ddm_data <- trial_data %>%
  # Rename columns to match DDM analysis scripts
  rename(
    subject_id = sub,
    rt = resp1RT,
    choice_binary = resp1
  ) %>%
  # Create binary choice variable (1 = correct, 0 = incorrect, maybe diff = 2?)
  mutate(
    choice = case_when(
      iscorr == 1 ~ 1,
      TRUE ~ 0
    )
  ) %>%
  # Create difficulty level
  mutate(
    difficulty_level = case_when(
      stimulus_condition == "Standard" ~ "Easy",
      stimulus_condition == "Oddball" ~ "Hard",
      TRUE ~ "Standard"
    )
  ) %>%
  # Create effort condition  
  mutate(
    effort_condition = case_when(
      force_condition == "Low_Force_20pct" ~ "Low_20_MVC",
      force_condition == "High_Force_40pct" ~ "High_40_MVC",
      TRUE ~ force_condition
    )
  ) %>%
  # Standardize pupil measures within subject
  group_by(subject_id) %>%
  mutate(
    pupil_baseline_z = as.numeric(scale(pupil_baseline)[,1]),
    pupil_evoked_z = as.numeric(scale(pupil_evoked)[,1]),
    pupil_mean_z = as.numeric(scale(pupil_mean)[,1])
  ) %>%
  ungroup()

# Save the DDM-ready data
dir.create("data/analysis_ready", recursive = TRUE, showWarnings = FALSE)
write_csv(ddm_data, "data/analysis_ready/bap_ddm_ready.csv")

cat("\n✅ Analysis-ready data created!\n")
cat("  Saved to: data/analysis_ready/bap_ddm_ready.csv\n")
cat("\n  Columns:", ncol(ddm_data), "\n")
cat("  Trials:", nrow(ddm_data), "\n")
cat("  Subjects:", length(unique(ddm_data$subject_id)), "\n")
cat("  Tasks:", paste(unique(ddm_data$task), collapse = ", "), "\n")

# Summary
cat("\nData Summary:\n")
summary_stats <- ddm_data %>%
  group_by(subject_id, task, difficulty_level, effort_condition) %>%
  summarise(
    n_trials = n(),
    mean_rt = mean(rt, na.rm = TRUE),
    pct_correct = mean(choice, na.rm = TRUE) * 100,
    .groups = "drop"
  ) %>%
  group_by(task, difficulty_level, effort_condition) %>%
  summarise(
    n_subjects = length(unique(subject_id)),
    mean_trials = mean(n_trials),
    mean_rt = mean(mean_rt, na.rm = TRUE),
    mean_accuracy = mean(pct_correct, na.rm = TRUE),
    .groups = "drop"
  )

print(summary_stats)

