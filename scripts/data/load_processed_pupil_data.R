# ============================================================================
# Load Processed Pupil Data
# ============================================================================
# Reads flat CSV files from BAP_processed and prepares for DDM analysis
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(tidyr)
})

cat("Loading processed pupil data...\n")

# Configuration
processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
output_dir <- "data/analysis_ready"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Find all flat CSV files (both regular and merged)
flat_files_merged <- list.files(processed_dir, pattern = "_flat_merged\\.csv$", full.names = TRUE)
flat_files_reg <- list.files(processed_dir, pattern = "_flat\\.csv$", full.names = TRUE)

# Remove duplicates (if both regular and merged exist for same subject/task)
# Keep merged versions where they exist
if (length(flat_files_merged) > 0 && length(flat_files_reg) > 0) {
  # Extract subject-task identifiers from merged files
  merged_ids <- gsub("_flat_merged\\.csv$", "", basename(flat_files_merged))
  reg_ids <- gsub("_flat\\.csv$", "", basename(flat_files_reg))
  
  # Find which regular files to exclude (already have merged version)
  reg_to_keep <- !reg_ids %in% merged_ids
  
  # Combine: all merged files + regular files that don't have merged versions
  flat_files <- c(flat_files_merged, flat_files_reg[reg_to_keep])
  cat("Using", length(flat_files_merged), "merged files +", sum(reg_to_keep), "regular files\n")
} else {
  # Use whatever is available
  flat_files <- c(flat_files_merged, flat_files_reg)
}

cat("Found", length(flat_files), "flat files\n")

# Load and combine all flat files
all_data <- vector("list", length(flat_files))

for (i in seq_along(flat_files)) {
  cat("Loading:", basename(flat_files[i]), "\n")
  
  # Read the CSV
  df <- read_csv(flat_files[i], show_col_types = FALSE, progress = FALSE)
  
  # Store with filename for reference
  all_data[[i]] <- df
}

# Combine all data
combined_data <- bind_rows(all_data)

cat("Combined data:", nrow(combined_data), "rows from", length(flat_files), "files\n")

# Basic data structure summary
cat("\nColumns:\n")
print(colnames(combined_data))

cat("\nUnique subjects:", length(unique(combined_data$sub)), "\n")
cat("Tasks:", paste(unique(combined_data$task), collapse = ", "), "\n")
cat("Runs:", min(combined_data$run, na.rm = TRUE), "to", max(combined_data$run, na.rm = TRUE), "\n")

# Save combined data
output_file <- file.path(output_dir, "bap_processed_pupil_flat.csv")
write_csv(combined_data, output_file)
cat("\n✓ Saved combined data to:", output_file, "\n")

# Create summary
summary_data <- combined_data %>%
  group_by(sub, task, run) %>%
  summarise(
    n_samples = n(),
    n_trials = length(unique(trial_index)),
    has_data = any(has_behavioral_data == 1, na.rm = TRUE),
    mean_pupil = mean(pupil, na.rm = TRUE),
    sd_pupil = sd(pupil, na.rm = TRUE),
    .groups = "drop"
  )

summary_file <- file.path(output_dir, "bap_processed_summary.csv")
write_csv(summary_data, summary_file)
cat("✓ Saved summary to:", summary_file, "\n")

# Create trial-level data (for DDM analysis)
cat("\nCreating trial-level dataset...\n")

trial_level_data <- combined_data %>%
  filter(has_behavioral_data == 1, !is.na(trial_index)) %>%
  group_by(sub, task, run, trial_index) %>%
  summarise(
    trial_label = first(trial_label),
    n_samples = n(),
    mean_pupil = mean(pupil, na.rm = TRUE),
    sd_pupil = sd(pupil, na.rm = TRUE),
    baseline_quality = first(baseline_quality),
    trial_quality = first(trial_quality),
    overall_quality = first(overall_quality),
    .groups = "drop"
  )

trial_file <- file.path(output_dir, "bap_trial_level_pupil.csv")
write_csv(trial_level_data, trial_file)
cat("✓ Saved trial-level data to:", trial_file, "\n")

cat("\n✅ Pupil data loading complete!\n")
cat("Next steps:\n")
cat("  1. Link with behavioral data (RT, choice, conditions)\n")
cat("  2. Run: scripts/pupil/prepare_pupil_features.R\n")
cat("  3. Run: scripts/tonic_alpha_analysis.R\n")

