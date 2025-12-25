#!/usr/bin/env Rscript

# ============================================================================
# Pupillometry Visualization Script
# ============================================================================
# Creates comprehensive visualizations for pupillometry data
# Updated for post-audit pipeline (handles NaN values, uses quality metrics)
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(tidyr)
  library(readr)
  library(purrr)
  library(gridExtra)
  library(viridis)
})

cat("=== PUPILLOMETRY VISUALIZATION SCRIPT ===\n")
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# ============================================================================
# CONFIGURATION
# ============================================================================

# Paths (update these based on your setup)
flat_files_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
output_dir <- "06_visualization/pupillometry"
analysis_ready_dir <- "data/analysis_ready"

# Create output directory
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# 1. DATA QUALITY VISUALIZATIONS
# ============================================================================

cat("1. Creating data quality visualizations...\n")

# Load flat files for quality assessment
flat_files <- list.files(flat_files_dir, pattern = "_flat_merged\\.csv$", full.names = TRUE)

if(length(flat_files) > 0) {
  cat("  Loading", length(flat_files), "merged flat files...\n")
  
  # Load sample of data for quality assessment
  quality_data <- map_dfr(flat_files[1:min(10, length(flat_files))], function(f) {
    df <- read_csv(f, n_max = 10000, show_col_types = FALSE)
    df %>%
      summarise(
        file = basename(f),
        sub = first(sub),
        task = first(task),
        n_samples = n(),
        n_trials = length(unique(trial_index)),
        zero_values = sum(pupil == 0, na.rm = TRUE),
        nan_values = sum(is.na(pupil)),
        nan_pct = round(100 * sum(is.na(pupil)) / n(), 2),
        mean_baseline_quality = mean(baseline_quality, na.rm = TRUE),
        mean_overall_quality = mean(overall_quality, na.rm = TRUE),
        has_trial_in_run = "trial_in_run" %in% names(.),
        .groups = "drop"
      )
  })
  
  # Plot 1: Quality metrics across files
  p1 <- ggplot(quality_data, aes(x = reorder(file, mean_overall_quality), y = mean_overall_quality)) +
    geom_col(fill = "steelblue", alpha = 0.7) +
    geom_hline(yintercept = 0.80, linetype = "dashed", color = "red", linewidth = 1) +
    coord_flip() +
    labs(
      title = "Overall Quality by File (80% threshold shown)",
      x = "File",
      y = "Mean Overall Quality"
    ) +
    theme_minimal() +
    theme(axis.text.y = element_text(size = 6))
  
  ggsave(file.path(output_dir, "quality_by_file.png"), p1, width = 10, height = 8, dpi = 300)
  cat("  ✓ Saved: quality_by_file.png\n")
  
  # Plot 2: NaN percentage
  p2 <- ggplot(quality_data, aes(x = reorder(file, nan_pct), y = nan_pct)) +
    geom_col(fill = "coral", alpha = 0.7) +
    coord_flip() +
    labs(
      title = "Missing Data (NaN) Percentage by File",
      subtitle = "Zeros converted to NaN in MATLAB pipeline",
      x = "File",
      y = "NaN Percentage (%)"
    ) +
    theme_minimal() +
    theme(axis.text.y = element_text(size = 6))
  
  ggsave(file.path(output_dir, "nan_percentage_by_file.png"), p2, width = 10, height = 8, dpi = 300)
  cat("  ✓ Saved: nan_percentage_by_file.png\n")
  
} else {
  cat("  ⚠ No merged flat files found. Skipping quality visualizations.\n")
}

# ============================================================================
# 2. PUPIL TIMECOURSE VISUALIZATIONS
# ============================================================================

cat("\n2. Creating pupil timecourse visualizations...\n")

if(length(flat_files) > 0) {
  # Load one example file for timecourse
  example_file <- flat_files[1]
  cat("  Loading example file:", basename(example_file), "\n")
  
  timecourse_data <- read_csv(example_file, n_max = 50000, show_col_types = FALSE) %>%
    filter(
      !is.na(pupil),  # Only valid (non-NaN) data
      has_behavioral_data == 1
    ) %>%
    mutate(
      force_condition = factor(force_condition),
      stimulus_condition = factor(stimulus_condition)
    )
  
  if(nrow(timecourse_data) > 0) {
    # Aggregate by time bins
    timecourse_summary <- timecourse_data %>%
      mutate(
        time_bin = round(time, 1)  # 0.1s bins
      ) %>%
      group_by(time_bin, force_condition, stimulus_condition) %>%
      summarise(
        mean_pupil = mean(pupil, na.rm = TRUE),
        se_pupil = sd(pupil, na.rm = TRUE) / sqrt(n()),
        n_samples = n(),
        .groups = "drop"
      )
    
    # Plot 3: Timecourse by force condition
    p3 <- ggplot(timecourse_summary, 
                 aes(x = time_bin, y = mean_pupil, 
                     color = force_condition, fill = force_condition)) +
      geom_line(linewidth = 1.2, alpha = 0.8) +
      geom_ribbon(aes(ymin = mean_pupil - se_pupil, ymax = mean_pupil + se_pupil),
                  alpha = 0.2, color = NA) +
      facet_wrap(~ stimulus_condition, ncol = 2) +
      labs(
        title = "Pupil Timecourse by Force and Stimulus Condition",
        subtitle = paste("File:", basename(example_file)),
        x = "Time (seconds)",
        y = "Pupil Diameter (mm)",
        color = "Force Condition",
        fill = "Force Condition"
      ) +
      theme_minimal() +
      theme(legend.position = "bottom")
    
    ggsave(file.path(output_dir, "pupil_timecourse_example.png"), p3, 
           width = 12, height = 6, dpi = 300)
    cat("  ✓ Saved: pupil_timecourse_example.png\n")
    
  } else {
    cat("  ⚠ No valid data in example file. Skipping timecourse plot.\n")
  }
}

# ============================================================================
# 3. FEATURE DISTRIBUTIONS
# ============================================================================

cat("\n3. Creating feature distribution visualizations...\n")

# Check if analysis-ready data exists
pupil_analysis_file <- file.path(analysis_ready_dir, "BAP_analysis_ready_PUPIL.csv")

if(file.exists(pupil_analysis_file)) {
  cat("  Loading analysis-ready pupil data...\n")
  
  pupil_features <- read_csv(pupil_analysis_file, show_col_types = FALSE)
  
  # Plot 4: Tonic arousal distribution
  if("tonic_arousal" %in% names(pupil_features)) {
    p4 <- ggplot(pupil_features, aes(x = tonic_arousal)) +
      geom_histogram(bins = 50, fill = "steelblue", alpha = 0.7, color = "white") +
      labs(
        title = "Distribution of Tonic Arousal (Baseline Pupil)",
        x = "Tonic Arousal (mm)",
        y = "Frequency"
      ) +
      theme_minimal()
    
    ggsave(file.path(output_dir, "tonic_arousal_distribution.png"), p4, 
           width = 8, height = 6, dpi = 300)
    cat("  ✓ Saved: tonic_arousal_distribution.png\n")
  }
  
  # Plot 5: Effort arousal change
  if("effort_arousal_change" %in% names(pupil_features)) {
    p5 <- ggplot(pupil_features, aes(x = effort_arousal_change)) +
      geom_histogram(bins = 50, fill = "coral", alpha = 0.7, color = "white") +
      geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
      labs(
        title = "Distribution of Effort Arousal Change",
        subtitle = "Pre-stimulus - Baseline",
        x = "Effort Arousal Change (mm)",
        y = "Frequency"
      ) +
      theme_minimal()
    
    ggsave(file.path(output_dir, "effort_arousal_change_distribution.png"), p5, 
           width = 8, height = 6, dpi = 300)
    cat("  ✓ Saved: effort_arousal_change_distribution.png\n")
  }
  
  # Plot 6: Quality metrics
  if("quality_iti" %in% names(pupil_features) && "quality_prestim" %in% names(pupil_features)) {
    quality_long <- pupil_features %>%
      select(quality_iti, quality_prestim) %>%
      pivot_longer(everything(), names_to = "metric", values_to = "quality")
    
    p6 <- ggplot(quality_long, aes(x = quality, fill = metric)) +
      geom_histogram(bins = 30, alpha = 0.7, position = "identity") +
      geom_vline(xintercept = 0.80, linetype = "dashed", color = "red") +
      labs(
        title = "Quality Metrics Distribution",
        subtitle = "80% threshold shown",
        x = "Quality (proportion valid)",
        y = "Frequency",
        fill = "Metric"
      ) +
      theme_minimal() +
      theme(legend.position = "bottom")
    
    ggsave(file.path(output_dir, "quality_metrics_distribution.png"), p6, 
           width = 10, height = 6, dpi = 300)
    cat("  ✓ Saved: quality_metrics_distribution.png\n")
  }
  
} else {
  cat("  ⚠ Analysis-ready pupil data not found. Run feature extraction first.\n")
  cat("    Expected file:", pupil_analysis_file, "\n")
}

# ============================================================================
# 4. SUMMARY STATISTICS
# ============================================================================

cat("\n4. Creating summary report...\n")

summary_file <- file.path(output_dir, "visualization_summary.txt")
sink(summary_file)

cat("=== PUPILLOMETRY VISUALIZATION SUMMARY ===\n\n")
cat("Generated at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

if(length(flat_files) > 0) {
  cat("Files processed:", length(flat_files), "\n")
  if(exists("quality_data")) {
    cat("\nQuality Statistics:\n")
    cat("  Mean overall quality:", round(mean(quality_data$mean_overall_quality, na.rm = TRUE), 3), "\n")
    cat("  Mean baseline quality:", round(mean(quality_data$mean_baseline_quality, na.rm = TRUE), 3), "\n")
    cat("  Mean NaN percentage:", round(mean(quality_data$nan_pct, na.rm = TRUE), 2), "%\n")
    cat("  Files with trial_in_run:", sum(quality_data$has_trial_in_run), "/", nrow(quality_data), "\n")
  }
}

if(file.exists(pupil_analysis_file)) {
  if(exists("pupil_features")) {
    cat("\nFeature Statistics:\n")
    cat("  Total trials:", nrow(pupil_features), "\n")
    if("tonic_arousal" %in% names(pupil_features)) {
      cat("  Mean tonic arousal:", round(mean(pupil_features$tonic_arousal, na.rm = TRUE), 3), "mm\n")
    }
    if("effort_arousal_change" %in% names(pupil_features)) {
      cat("  Mean effort arousal change:", round(mean(pupil_features$effort_arousal_change, na.rm = TRUE), 3), "mm\n")
    }
  }
}

cat("\nPlots saved to:", output_dir, "\n")
cat("\n=== END SUMMARY ===\n")

sink()

cat("  ✓ Saved: visualization_summary.txt\n")

# ============================================================================
# COMPLETION
# ============================================================================

cat("\n=== VISUALIZATION COMPLETE ===\n")
cat("All plots saved to:", output_dir, "\n")
cat("Completed at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")









