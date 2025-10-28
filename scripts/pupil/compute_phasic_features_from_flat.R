# ============================================================================
# Compute Phasic Pupil Features from Flat Data
# ============================================================================
# Computes phasic slope (200-900ms) from already-flattened pupil data
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(readr)
})

cat("Computing phasic pupil features...\n")

# Load the flat pupil data
flat_data <- read_csv("data/analysis_ready/bap_processed_pupil_flat.csv",
                     show_col_types = FALSE, progress = FALSE)

cat("Loaded", nrow(flat_data), "samples\n")

# Load the DDM-ready data to get trial identifiers
ddm_data <- read_csv("data/analysis_ready/bap_ddm_ready.csv",
                     show_col_types = FALSE, progress = FALSE)

# Create trial identifiers to match
flat_data <- flat_data %>%
  mutate(
    trial_id = paste(sub, task, run, trial_index, sep = "_"),
    time_ms = time * 1000  # Convert seconds to milliseconds
  )

# Compute phasic features for each trial
phasic_features <- flat_data %>%
  filter(
    has_behavioral_data == 1,  # Only trials with behavioral data
    time_ms >= 200 & time_ms <= 900  # Phasic window
  ) %>%
  group_by(trial_id, sub, task, run, trial_index) %>%
  summarise(
    n_samples = n(),
    phasic_slope = {
      # OLS slope within 200-900ms
      if (n() < 5 || all(is.na(pupil))) NA_real_
      else {
        model <- lm(pupil ~ time_ms, data = data.frame(pupil = pupil, time_ms = time_ms))
        coef(model)[2]
      }
    },
    phasic_mean = mean(pupil, na.rm = TRUE),
    .groups = "drop"
  )

cat("Computed phasic features for", nrow(phasic_features), "trials\n")

# Merge with DDM data
ddm_data <- ddm_data %>%
  mutate(
    trial_id = paste(subject_id, task, run, trial_index, sep = "_")
  ) %>%
  left_join(phasic_features %>%
              select(trial_id, phasic_slope, phasic_mean),
            by = "trial_id")

# Standardize phasic slope within subject
ddm_data <- ddm_data %>%
  group_by(subject_id) %>%
  mutate(
    phasic_slope_z = as.numeric(scale(phasic_slope)[,1])
  ) %>%
  ungroup()

# Save updated data
write_csv(ddm_data, "data/analysis_ready/bap_ddm_ready.csv")

cat("✅ Phasic features computed and added to DDM data\n")
cat("  Phasic slope (200-900ms) computed for", sum(!is.na(ddm_data$phasic_slope)), "trials\n")
cat("  Data saved to: data/analysis_ready/bap_ddm_ready.csv\n")
