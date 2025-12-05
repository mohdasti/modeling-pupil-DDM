# =========================================================================
# DATA INTEGRATION SCRIPT: MERGE SUBJECT-LEVEL DATA WITH TRIAL-LEVEL DDM DATA
# =========================================================================

cat("=== DATA INTEGRATION SCRIPT ===\n")
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Load required libraries
library(dplyr)
library(readr)

cat("Loading subject-level master spreadsheets...\n")

# Load the new subject-level master spreadsheets
demographics_df <- read_csv('/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_DDM/data/LC Aging Subject Data master spreadsheet - demographics.csv', skip = 1, show_col_types = FALSE)
lc_integrity_df <- read_csv('/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_DDM/data/LC Aging Subject Data master spreadsheet - LC integrity.csv', skip = 1, show_col_types = FALSE)
neuropsych_df <- read_csv('/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_DDM/data/LC Aging Subject Data master spreadsheet - neuropsych.csv', skip = 1, show_col_types = FALSE)

# Load the existing trial-level DDM data
pupil_ddm_df <- read_csv('data/analysis_ready/BAP_analysis_ready_PUPIL.csv')
behav_ddm_df <- read_csv('data/analysis_ready/BAP_analysis_ready_BEHAVIORAL.csv')

cat("SUCCESS: All datasets loaded\n")
cat("Demographics (raw):", nrow(demographics_df), "rows\n")
cat("LC Integrity (raw):", nrow(lc_integrity_df), "rows\n")
cat("Neuropsych (raw):", nrow(neuropsych_df), "rows\n")
cat("Pupil DDM:", nrow(pupil_ddm_df), "trials\n")
cat("Behavioral DDM:", nrow(behav_ddm_df), "trials\n\n")

# ============================================================================
# SANITY CHECK 1: Identify all subjects (NO RUN-BASED FILTERING)
# ============================================================================

cat("=== SANITY CHECK 1: Identifying all subjects (no run threshold) ===\n")

# NOTE: Subject filtering based on number of runs has been DISABLED
# All subjects with data are included, regardless of number of runs

valid_subjects <- unique(behav_ddm_df$subject_id)
cat("Total subjects with data:", length(valid_subjects), "\n")
cat("All subjects included (no run threshold applied)\n\n")

# No filtering - all subjects are kept
# pupil_ddm_df and behav_ddm_df remain unchanged

cat("Preparing and merging subject-level data...\n")

# Prepare demographics data
demographics_subset <- demographics_df %>%
  select(subject_id = `SUBJECT NUMBER_1`,
         age = `AGE AT BAP SESSION 1`) %>%
  mutate(
    subject_id = as.character(subject_id),
    age = as.numeric(age)
  ) %>%
  # Remove duplicates by keeping the first occurrence
  distinct(subject_id, .keep_all = TRUE) %>%
  # Keep all subjects (no filtering based on run count)
  # filter(subject_id %in% valid_subjects)  # DISABLED

cat("Demographics subset (filtered to valid subjects):", nrow(demographics_subset), "subjects\n")

# Prepare LC integrity data
lc_integrity_subset <- lc_integrity_df %>%
  select(subject_id = `SUBJECT NUMBER`,
         lc_cnr_max = `LC_CNR_max`) %>%
  mutate(subject_id = as.character(subject_id)) %>%
  # Remove duplicates by keeping the first occurrence
  distinct(subject_id, .keep_all = TRUE) %>%
  # Keep all subjects (no filtering based on run count)
  # filter(subject_id %in% valid_subjects)  # DISABLED

cat("LC integrity subset (filtered to valid subjects):", nrow(lc_integrity_subset), "subjects\n")

# Prepare neuropsychology data and calculate TMT score
neuropsych_subset <- neuropsych_df %>%
  select(subject_id = `SUBJECT NUMBER`,
         tmt_a = `Trail Making 1 (seconds)`,
         tmt_b = `Trail Making 2 (seconds)`) %>%
  mutate(
    subject_id = as.character(subject_id),
    # Convert character to numeric, handling NA values
    tmt_a = as.numeric(tmt_a),
    tmt_b = as.numeric(tmt_b),
    tmt_b_minus_a = tmt_b - tmt_a
  ) %>%
  # Remove duplicates by keeping the first occurrence
  distinct(subject_id, .keep_all = TRUE) %>%
  # Keep all subjects (no filtering based on run count)
  # filter(subject_id %in% valid_subjects)  # DISABLED

cat("Neuropsych subset (filtered to valid subjects):", nrow(neuropsych_subset), "subjects\n")

# Merge all subject-level data frames into one
subject_data <- demographics_subset %>%
  left_join(lc_integrity_subset, by = "subject_id") %>%
  left_join(neuropsych_subset, by = "subject_id") %>%
  # Create scaled versions of the variables for modeling
  mutate(
    age_scaled = scale(age)[,1],
    lc_cnr_max_scaled = scale(lc_cnr_max)[,1],
    tmt_scaled = scale(tmt_b_minus_a)[,1]
  )

cat("Merged subject data (filtered to valid subjects):", nrow(subject_data), "subjects\n")
cat("Subjects with age data:", sum(!is.na(subject_data$age)), "\n")
cat("Subjects with LC data:", sum(!is.na(subject_data$lc_cnr_max)), "\n")
cat("Subjects with TMT data:", sum(!is.na(subject_data$tmt_b_minus_a)), "\n\n")

# SANITY CHECK: Verify we're only working with valid subjects
if(nrow(subject_data) != length(valid_subjects)) {
  warning("WARNING: Subject data count (", nrow(subject_data), ") doesn't match valid subjects count (", length(valid_subjects), ")")
  cat("This may indicate missing subject-level data for some valid subjects.\n")
}

cat("Merging subject-level data into trial-level datasets...\n")

# Merge with the PUPIL dataset
pupil_ddm_full <- pupil_ddm_df %>%
  left_join(subject_data, by = "subject_id")

# Merge with the BEHAVIORAL dataset
behav_ddm_full <- behav_ddm_df %>%
  left_join(subject_data, by = "subject_id")

cat("Pupil DDM full:", nrow(pupil_ddm_full), "trials\n")
cat("Behavioral DDM full:", nrow(behav_ddm_full), "trials\n")

# Check data availability after merging
cat("\nData availability after merging:\n")
cat("Pupil trials with age data:", sum(!is.na(pupil_ddm_full$age)), "\n")
cat("Pupil trials with LC data:", sum(!is.na(pupil_ddm_full$lc_cnr_max)), "\n")
cat("Pupil trials with TMT data:", sum(!is.na(pupil_ddm_full$tmt_b_minus_a)), "\n")
cat("Behavioral trials with age data:", sum(!is.na(behav_ddm_full$age)), "\n")
cat("Behavioral trials with LC data:", sum(!is.na(behav_ddm_full$lc_cnr_max)), "\n")
cat("Behavioral trials with TMT data:", sum(!is.na(behav_ddm_full$tmt_b_minus_a)), "\n")

# Save the newly enriched, analysis-ready files
write_csv(pupil_ddm_full, 'data/analysis_ready/BAP_analysis_ready_PUPIL_full.csv')
write_csv(behav_ddm_full, 'data/analysis_ready/BAP_analysis_ready_BEHAVIORAL_full.csv')

cat("\n=== DATA INTEGRATION COMPLETE ===\n")
cat("SUCCESS: Data integration complete. Two new files were created:\n")
cat("data/analysis_ready/BAP_analysis_ready_PUPIL_full.csv\n")
cat("data/analysis_ready/BAP_analysis_ready_BEHAVIORAL_full.csv\n")
cat("Completed at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
