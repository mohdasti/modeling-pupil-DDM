#!/usr/bin/env Rscript

# ============================================================================
# Pupillometry Quality Control Script
# ============================================================================
# Comprehensive QC for pupillometry data
# Updated for post-audit pipeline (NaN handling, quality metrics, etc.)
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(tidyr)
  library(purrr)
})

cat("=== PUPILLOMETRY QUALITY CONTROL ===\n")
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# ============================================================================
# CONFIGURATION
# ============================================================================

processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
analysis_ready_dir <- "data/analysis_ready"
output_dir <- "output/qc/pupillometry"

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# 1. CHECK ANALYSIS-READY DATA
# ============================================================================

cat("1. Checking analysis-ready data...\n")

pupil_file <- file.path(analysis_ready_dir, "BAP_analysis_ready_PUPIL.csv")
behav_file <- file.path(analysis_ready_dir, "BAP_analysis_ready_BEHAVIORAL.csv")

if(!file.exists(pupil_file) || !file.exists(behav_file)) {
  cat("  ⚠ Analysis-ready files not found. Run feature extraction first.\n")
  cat("    Expected:", pupil_file, "\n")
  cat("    Expected:", behav_file, "\n")
  stop("Please run feature extraction first: source('02_pupillometry_analysis/feature_extraction/run_feature_extraction.R')")
}

pupil_data <- read_csv(pupil_file, show_col_types = FALSE)
behav_data <- read_csv(behav_file, show_col_types = FALSE)

cat("  ✓ Loaded pupil data:", nrow(pupil_data), "trials\n")
cat("  ✓ Loaded behavioral data:", nrow(behav_data), "trials\n\n")

# ============================================================================
# 2. DATA QUALITY CHECKS
# ============================================================================

cat("2. Data quality checks...\n")

qc_results <- list()

# Check 1: Subject counts
qc_results$subject_count <- length(unique(pupil_data$subject_id))
qc_results$subject_count_behav <- length(unique(behav_data$subject_id))

cat("  Subjects in pupil data:", qc_results$subject_count, "\n")
cat("  Subjects in behavioral data:", qc_results$subject_count_behav, "\n")

if(qc_results$subject_count != qc_results$subject_count_behav) {
  warning("WARNING: Subject count mismatch between pupil and behavioral data!")
}

# Check 2: Quality metrics
if("quality_iti" %in% names(pupil_data) && "quality_prestim" %in% names(pupil_data)) {
  qc_results$mean_quality_iti <- mean(pupil_data$quality_iti, na.rm = TRUE)
  qc_results$mean_quality_prestim <- mean(pupil_data$quality_prestim, na.rm = TRUE)
  qc_results$trials_below_80 <- sum(pupil_data$quality_iti < 0.80 | pupil_data$quality_prestim < 0.80, na.rm = TRUE)
  
  cat("  Mean ITI quality:", round(qc_results$mean_quality_iti, 3), "\n")
  cat("  Mean pre-stim quality:", round(qc_results$mean_quality_prestim, 3), "\n")
  cat("  Trials below 80% quality:", qc_results$trials_below_80, "\n")
} else {
  warning("WARNING: Quality metrics not found in pupil data")
}

# Check 3: Difficulty level distribution
if("difficulty_level" %in% names(pupil_data)) {
  diff_dist <- table(pupil_data$difficulty_level, useNA = "always")
  qc_results$difficulty_distribution <- diff_dist
  
  cat("  Difficulty level distribution:\n")
  for(i in 1:length(diff_dist)) {
    cat(sprintf("    %s: %d trials (%.1f%%)\n", 
                names(diff_dist)[i], 
                diff_dist[i],
                100 * diff_dist[i] / sum(diff_dist)))
  }
  
  # Check for all three levels
  expected_levels <- c("Standard", "Easy", "Hard")
  present_levels <- names(diff_dist)[names(diff_dist) != "NA"]
  missing_levels <- setdiff(expected_levels, present_levels)
  
  if(length(missing_levels) > 0) {
    warning("WARNING: Missing difficulty levels: ", paste(missing_levels, collapse = ", "))
    qc_results$missing_difficulty_levels <- missing_levels
  } else {
    cat("  ✓ All difficulty levels present (Standard, Easy, Hard)\n")
  }
} else {
  warning("WARNING: difficulty_level column not found")
}

# Check 4: Effort condition distribution
if("effort_condition" %in% names(pupil_data)) {
  effort_dist <- table(pupil_data$effort_condition, useNA = "always")
  qc_results$effort_distribution <- effort_dist
  
  cat("  Effort condition distribution:\n")
  for(i in 1:length(effort_dist)) {
    cat(sprintf("    %s: %d trials (%.1f%%)\n", 
                names(effort_dist)[i], 
                effort_dist[i],
                100 * effort_dist[i] / sum(effort_dist)))
  }
} else {
  warning("WARNING: effort_condition column not found")
}

# Check 5: Task distribution
task_dist <- table(pupil_data$task, useNA = "always")
qc_results$task_distribution <- task_dist

cat("  Task distribution:\n")
for(i in 1:length(task_dist)) {
  cat(sprintf("    %s: %d trials (%.1f%%)\n", 
              names(task_dist)[i], 
              task_dist[i],
              100 * task_dist[i] / sum(task_dist)))
}

# Check 6: Pupil feature availability
pupil_features <- c("tonic_arousal", "effort_arousal_change")
missing_features <- setdiff(pupil_features, names(pupil_data))
if(length(missing_features) > 0) {
  warning("WARNING: Missing pupil features: ", paste(missing_features, collapse = ", "))
  qc_results$missing_features <- missing_features
} else {
  cat("  ✓ All required pupil features present\n")
  
  # Check for valid values
  if("tonic_arousal" %in% names(pupil_data)) {
    qc_results$tonic_arousal_mean <- mean(pupil_data$tonic_arousal, na.rm = TRUE)
    qc_results$tonic_arousal_sd <- sd(pupil_data$tonic_arousal, na.rm = TRUE)
    qc_results$tonic_arousal_missing <- sum(is.na(pupil_data$tonic_arousal))
    
    cat("  Tonic arousal: M =", round(qc_results$tonic_arousal_mean, 3), 
        ", SD =", round(qc_results$tonic_arousal_sd, 3),
        ", Missing =", qc_results$tonic_arousal_missing, "\n")
  }
  
  if("effort_arousal_change" %in% names(pupil_data)) {
    qc_results$effort_change_mean <- mean(pupil_data$effort_arousal_change, na.rm = TRUE)
    qc_results$effort_change_sd <- sd(pupil_data$effort_arousal_change, na.rm = TRUE)
    qc_results$effort_change_missing <- sum(is.na(pupil_data$effort_arousal_change))
    
    cat("  Effort arousal change: M =", round(qc_results$effort_change_mean, 3), 
        ", SD =", round(qc_results$effort_change_sd, 3),
        ", Missing =", qc_results$effort_change_missing, "\n")
  }
}

cat("\n")

# ============================================================================
# 3. CREATE QC PLOTS
# ============================================================================

cat("3. Creating QC plots...\n")

# Plot 1: Quality metrics distribution
if("quality_iti" %in% names(pupil_data) && "quality_prestim" %in% names(pupil_data)) {
  quality_long <- pupil_data %>%
    select(quality_iti, quality_prestim) %>%
    pivot_longer(everything(), names_to = "metric", values_to = "quality")
  
  p1 <- ggplot(quality_long, aes(x = quality, fill = metric)) +
    geom_histogram(bins = 30, alpha = 0.7, position = "identity") +
    geom_vline(xintercept = 0.80, linetype = "dashed", color = "red", linewidth = 1) +
    labs(
      title = "Pupil Quality Metrics Distribution",
      subtitle = "80% threshold shown (all trials should be >= 0.80)",
      x = "Quality (proportion valid)",
      y = "Frequency",
      fill = "Metric"
    ) +
    scale_fill_manual(values = c("quality_iti" = "steelblue", "quality_prestim" = "coral"),
                      labels = c("quality_iti" = "ITI Baseline", "quality_prestim" = "Pre-Stimulus")) +
    theme_minimal() +
    theme(legend.position = "bottom")
  
  ggsave(file.path(output_dir, "quality_metrics_distribution.png"), p1, 
         width = 10, height = 6, dpi = 300)
  cat("  ✓ Saved: quality_metrics_distribution.png\n")
}

# Plot 2: Difficulty level by task
if("difficulty_level" %in% names(pupil_data) && "task" %in% names(pupil_data)) {
  diff_task_summary <- pupil_data %>%
    group_by(task, difficulty_level) %>%
    summarise(n_trials = n(), .groups = "drop")
  
  p2 <- ggplot(diff_task_summary, aes(x = task, y = n_trials, fill = difficulty_level)) +
    geom_col(position = "dodge", alpha = 0.8) +
    scale_fill_manual(values = c("Standard" = "#90EE90", "Easy" = "#87CEEB", "Hard" = "#FFB6C1")) +
    labs(
      title = "Trial Count by Task and Difficulty Level",
      x = "Task",
      y = "Number of Trials",
      fill = "Difficulty"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")
  
  ggsave(file.path(output_dir, "difficulty_by_task.png"), p2, 
         width = 8, height = 6, dpi = 300)
  cat("  ✓ Saved: difficulty_by_task.png\n")
}

# Plot 3: Effort condition by difficulty
if("effort_condition" %in% names(pupil_data) && "difficulty_level" %in% names(pupil_data)) {
  effort_diff_summary <- pupil_data %>%
    group_by(effort_condition, difficulty_level) %>%
    summarise(n_trials = n(), .groups = "drop")
  
  p3 <- ggplot(effort_diff_summary, aes(x = effort_condition, y = n_trials, fill = difficulty_level)) +
    geom_col(position = "dodge", alpha = 0.8) +
    scale_fill_manual(values = c("Standard" = "#90EE90", "Easy" = "#87CEEB", "Hard" = "#FFB6C1")) +
    labs(
      title = "Trial Count by Effort and Difficulty",
      x = "Effort Condition",
      y = "Number of Trials",
      fill = "Difficulty"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")
  
  ggsave(file.path(output_dir, "effort_by_difficulty.png"), p3, 
         width = 10, height = 6, dpi = 300)
  cat("  ✓ Saved: effort_by_difficulty.png\n")
}

# Plot 4: Tonic arousal distribution by condition
if("tonic_arousal" %in% names(pupil_data) && "effort_condition" %in% names(pupil_data)) {
  p4 <- ggplot(pupil_data, aes(x = tonic_arousal, fill = effort_condition)) +
    geom_histogram(bins = 50, alpha = 0.7, position = "identity") +
    facet_wrap(~ task) +
    labs(
      title = "Tonic Arousal Distribution by Effort Condition and Task",
      x = "Tonic Arousal (mm)",
      y = "Frequency",
      fill = "Effort"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")
  
  ggsave(file.path(output_dir, "tonic_arousal_distribution.png"), p4, 
         width = 12, height = 6, dpi = 300)
  cat("  ✓ Saved: tonic_arousal_distribution.png\n")
}

cat("\n")

# ============================================================================
# 4. CHECK FLAT FILES (if available)
# ============================================================================

cat("4. Checking flat files (if available)...\n")

flat_files_merged <- list.files(processed_dir, pattern = "_flat_merged\\.csv$", full.names = TRUE)

if(length(flat_files_merged) > 0) {
  cat("  Found", length(flat_files_merged), "merged flat files\n")
  
  # Sample check on a few files
  sample_files <- flat_files_merged[1:min(5, length(flat_files_merged))]
  
  flat_qc <- map_dfr(sample_files, function(f) {
    df <- read_csv(f, n_max = 10000, show_col_types = FALSE)
    tibble(
      file = basename(f),
      n_samples = nrow(df),
      zero_values = sum(df$pupil == 0, na.rm = TRUE),
      nan_values = sum(is.na(df$pupil)),
      nan_pct = round(100 * sum(is.na(df$pupil)) / nrow(df), 2),
      has_trial_in_run = "trial_in_run" %in% names(df),
      has_baseline_quality = "baseline_quality" %in% names(df),
      has_overall_quality = "overall_quality" %in% names(df)
    )
  })
  
  cat("  Sample file QC:\n")
  print(flat_qc)
  
  # Check for zeros (should be 0 after MATLAB pipeline fix)
  if(any(flat_qc$zero_values > 0)) {
    warning("WARNING: Some flat files still contain zero values!")
    cat("  Files with zeros:", paste(flat_qc$file[flat_qc$zero_values > 0], collapse = ", "), "\n")
  } else {
    cat("  ✓ No zero values found (correctly converted to NaN)\n")
  }
  
  # Check for trial_in_run
  if(all(flat_qc$has_trial_in_run)) {
    cat("  ✓ All files have trial_in_run column\n")
  } else {
    warning("WARNING: Some files missing trial_in_run column")
  }
  
} else {
  cat("  ⚠ No merged flat files found\n")
}

cat("\n")

# ============================================================================
# 5. GENERATE QC REPORT
# ============================================================================

cat("5. Generating QC report...\n")

report_file <- file.path(output_dir, "pupil_qc_report.txt")
sink(report_file)

cat("=== PUPILLOMETRY QUALITY CONTROL REPORT ===\n\n")
cat("Generated at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("=== DATA SUMMARY ===\n")
cat("Pupil trials:", nrow(pupil_data), "\n")
cat("Behavioral trials:", nrow(behav_data), "\n")
cat("Subjects:", qc_results$subject_count, "\n\n")

cat("=== QUALITY METRICS ===\n")
if("quality_iti" %in% names(pupil_data)) {
  cat("Mean ITI quality:", round(qc_results$mean_quality_iti, 3), "\n")
  cat("Mean pre-stim quality:", round(qc_results$mean_quality_prestim, 3), "\n")
  cat("Trials below 80% quality:", qc_results$trials_below_80, "\n")
  cat("Expected: All trials should have quality >= 0.80\n\n")
}

cat("=== DIFFICULTY LEVEL DISTRIBUTION ===\n")
if("difficulty_level" %in% names(pupil_data)) {
  for(i in 1:length(qc_results$difficulty_distribution)) {
    cat(sprintf("%s: %d trials (%.1f%%)\n", 
                names(qc_results$difficulty_distribution)[i], 
                qc_results$difficulty_distribution[i],
                100 * qc_results$difficulty_distribution[i] / sum(qc_results$difficulty_distribution)))
  }
  if(!is.null(qc_results$missing_difficulty_levels)) {
    cat("\nWARNING: Missing difficulty levels:", paste(qc_results$missing_difficulty_levels, collapse = ", "), "\n")
  }
  cat("\n")
}

cat("=== EFFORT CONDITION DISTRIBUTION ===\n")
if("effort_condition" %in% names(pupil_data)) {
  for(i in 1:length(qc_results$effort_distribution)) {
    cat(sprintf("%s: %d trials (%.1f%%)\n", 
                names(qc_results$effort_distribution)[i], 
                qc_results$effort_distribution[i],
                100 * qc_results$effort_distribution[i] / sum(qc_results$effort_distribution)))
  }
  cat("\n")
}

cat("=== TASK DISTRIBUTION ===\n")
for(i in 1:length(qc_results$task_distribution)) {
  cat(sprintf("%s: %d trials (%.1f%%)\n", 
              names(qc_results$task_distribution)[i], 
              qc_results$task_distribution[i],
              100 * qc_results$task_distribution[i] / sum(qc_results$task_distribution)))
}
cat("\n")

cat("=== PUPIL FEATURES ===\n")
if("tonic_arousal" %in% names(pupil_data)) {
  cat("Tonic arousal: M =", round(qc_results$tonic_arousal_mean, 3), 
      ", SD =", round(qc_results$tonic_arousal_sd, 3), "\n")
}
if("effort_arousal_change" %in% names(pupil_data)) {
  cat("Effort arousal change: M =", round(qc_results$effort_change_mean, 3), 
      ", SD =", round(qc_results$effort_change_sd, 3), "\n")
}
cat("\n")

cat("=== VALIDATION CHECKS ===\n")
cat("✓ All quality checks completed\n")
cat("✓ Plots saved to:", output_dir, "\n")
cat("\n=== END REPORT ===\n")

sink()

cat("  ✓ Saved:", report_file, "\n")

# ============================================================================
# COMPLETION
# ============================================================================

cat("\n=== QC COMPLETE ===\n")
cat("All QC checks completed. Reports and plots saved to:", output_dir, "\n")
cat("Completed at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
