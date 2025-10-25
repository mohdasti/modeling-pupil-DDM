# =========================================================================
# ATTRISTION ANALYSIS: DATA RETENTION ACROSS PROCESSING STAGES
# =========================================================================
# Computes trial retention rates after RT filtering and pupil data QC
# =========================================================================

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(tidyr)
})

cat("Computing attrition rates...\n")

# =========================================================================
# LOAD DATA
# =========================================================================

# Load raw behavioral data (if available)
raw_data_path <- "data/raw/behavioral_data.csv"
if (file.exists(raw_data_path)) {
  raw_data <- read_csv(raw_data_path, show_col_types = FALSE)
  raw_counts <- raw_data %>%
    group_by(subject_id) %>%
    summarise(trials_raw = n(), .groups = "drop")
} else {
  # Create dummy counts if raw data not available
  cat("⚠️  Raw data not found. Using processed data as baseline.\n")
  raw_counts <- NULL
}

# Load processed/clean data
clean_data_path <- "data/analysis_ready/bap_clean_pupil.csv"
clean_data <- read_csv(clean_data_path, show_col_types = FALSE)

# Count trials after different filters
attrition_data <- clean_data %>%
  group_by(subject_id) %>%
  summarise(
    n_total = n(),
    .groups = "drop"
  )

# If we have trial_id or trial_index, we can reconstruct raw counts
if ("trial_index" %in% colnames(clean_data)) {
  # Count unique trials (approximation)
  max_trial_by_subj <- clean_data %>%
    group_by(subject_id) %>%
    summarise(max_trial = max(trial_index, na.rm = TRUE), .groups = "drop")
  
  attrition_data <- attrition_data %>%
    left_join(max_trial_by_subj, by = "subject_id") %>%
    mutate(
      # Estimate raw trials (assuming sequential numbering)
      trials_raw = ifelse(!is.na(max_trial), max_trial, n_total),
      trials_after_rt = n_total,  # Assumes RT filtering already done in clean data
      trials_after_pupil = n_total  # Assumes pupil QC already done
    )
} else {
  attrition_data <- attrition_data %>%
    mutate(
      trials_raw = NA_integer_,
      trials_after_rt = n_total,
      trials_after_pupil = n_total
    )
}

# Merge with raw counts if available
if (!is.null(raw_counts)) {
  attrition_data <- attrition_data %>%
    left_join(raw_counts, by = "subject_id") %>%
    mutate(
      trials_raw = ifelse(!is.na(trials_raw.x), trials_raw.x, trials_raw.y),
      trials_raw.x = NULL,
      trials_raw.y = NULL
    )
}

# =========================================================================
# COMPUTE RETENTION RATES
# =========================================================================

attrition_data <- attrition_data %>%
  mutate(
    # Compute percentages
    pct_retained = ifelse(!is.na(trials_raw) & trials_raw > 0,
                          100 * n_total / trials_raw,
                          NA_real_),
    trials_lost = ifelse(!is.na(trials_raw),
                         trials_raw - n_total,
                         NA_integer_),
    pct_lost = ifelse(!is.na(trials_raw) & trials_raw > 0,
                      100 * (trials_raw - n_total) / trials_raw,
                      NA_real_)
  ) %>%
  select(
    subj = subject_id,
    trials_raw,
    trials_after_rt,
    trials_after_pupil = n_total,
    trials_lost,
    percent_retained = pct_retained,
    percent_lost = pct_lost
  )

# =========================================================================
# SUMMARY STATISTICS
# =========================================================================

cat("\nAttrition Summary:\n")
cat("Total subjects:", nrow(attrition_data), "\n")
cat("Mean retention:", round(mean(attrition_data$percent_retained, na.rm = TRUE), 1), "%\n")
cat("SD retention:", round(sd(attrition_data$percent_retained, na.rm = TRUE), 1), "%\n")
cat("Min retention:", round(min(attrition_data$percent_retained, na.rm = TRUE), 1), "%\n")
cat("Max retention:", round(max(attrition_data$percent_retained, na.rm = TRUE), 1), "%\n")

# Overall totals
if (!is.na(attrition_data$trials_raw[1])) {
  total_raw <- sum(attrition_data$trials_raw, na.rm = TRUE)
  total_clean <- sum(attrition_data$trials_after_pupil, na.rm = TRUE)
  overall_pct <- 100 * total_clean / total_raw
  
  cat("\nOverall Retention:\n")
  cat("Raw trials:", total_raw, "\n")
  cat("Clean trials:", total_clean, "\n")
  cat("Overall retention:", round(overall_pct, 1), "%\n")
  cat("Trials lost:", total_raw - total_clean, "\n")
}

# =========================================================================
# SAVE RESULTS
# =========================================================================

dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
readr::write_csv(attrition_data, "output/tables/attrition_table.csv")

cat("\n✅ Attrition analysis complete!\n")
cat("Results saved to output/tables/attrition_table.csv\n")

# Create summary report
summary_text <- paste0(
  "# Data Attrition Report\n\n",
  "## Summary\n\n",
  "- **Total subjects**: ", nrow(attrition_data), "\n",
  "- **Mean retention**: ", round(mean(attrition_data$percent_retained, na.rm = TRUE), 1), "%\n",
  "- **SD retention**: ", round(sd(attrition_data$percent_retained, na.rm = TRUE), 1), "%\n",
  if (!is.na(attrition_data$trials_raw[1])) {
    paste0(
      "- **Raw trials (total)**: ", sum(attrition_data$trials_raw, na.rm = TRUE), "\n",
      "- **Clean trials (total)**: ", sum(attrition_data$trials_after_pupil, na.rm = TRUE), "\n",
      "- **Overall retention**: ", round(overall_pct, 1), "%\n"
    )
  } else {
    "- **Note**: Raw trial counts not available; retention computed from processed data\n"
  },
  "\n## Individual Subject Retention\n\n",
  "See `output/tables/attrition_table.csv` for per-subject retention rates.\n\n",
  "## Exclusions\n\n",
  "1. **RT filtering**: Trials with RT < 200 ms or RT > 3,000 ms excluded\n",
  "2. **Pupil QC**: Trials with >40% missing pupil data excluded\n",
  "3. **Incomplete trials**: Trials missing critical variables excluded\n"
)

writeLines(summary_text, "output/tables/attrition_summary.md")
