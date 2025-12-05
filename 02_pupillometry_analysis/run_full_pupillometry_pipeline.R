#!/usr/bin/env Rscript

# ============================================================================
# Full Pupillometry Analysis Pipeline
# ============================================================================
# Master script that orchestrates the complete pupillometry analysis pipeline:
# 1. Data preparation (from merged flat files)
# 2. Feature extraction (Total AUC, Cognitive AUC)
# 3. Quality control checks
# 4. Visualizations
# 
# This script is designed to be run whenever new pupil data is added.
# It will automatically detect new files and process them.
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

cat("=================================================================\n")
cat("FULL PUPILLOMETRY ANALYSIS PIPELINE\n")
cat("=================================================================\n")
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# ============================================================================
# CONFIGURATION
# ============================================================================

# Paths
processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
behavioral_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"
output_dir <- "data/analysis_ready"
qc_output_dir <- "02_pupillometry_analysis/quality_control/output"
viz_output_dir <- "06_visualization/publication_figures"

# Create output directories
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(qc_output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(viz_output_dir, recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# STEP 1: CHECK FOR NEW DATA
# ============================================================================

cat("STEP 1: Checking for new data...\n")

# Find all flat files (merged and regular)
flat_files_merged <- list.files(processed_dir, pattern = "_flat_merged\\.csv$", full.names = TRUE)
flat_files_reg <- list.files(processed_dir, pattern = "_flat\\.csv$", full.names = TRUE)

# Prefer merged files
if (length(flat_files_merged) > 0 && length(flat_files_reg) > 0) {
  merged_ids <- gsub("_flat_merged\\.csv$", "", basename(flat_files_merged))
  reg_ids <- gsub("_flat\\.csv$", "", basename(flat_files_reg))
  reg_to_keep <- !reg_ids %in% merged_ids
  flat_files <- c(flat_files_merged, flat_files_reg[reg_to_keep])
} else {
  flat_files <- c(flat_files_merged, flat_files_reg)
}

cat("  Found", length(flat_files), "flat files\n")

# Check if analysis-ready files exist and are up-to-date
analysis_ready_pupil <- file.path(output_dir, "BAP_analysis_ready_PUPIL.csv")
analysis_ready_behav <- file.path(output_dir, "BAP_analysis_ready_BEHAVIORAL.csv")

needs_rerun <- FALSE
if (!file.exists(analysis_ready_pupil) || !file.exists(analysis_ready_behav)) {
  cat("  Analysis-ready files not found - will create them\n")
  needs_rerun <- TRUE
} else {
  # Check if any flat files are newer than analysis-ready files
  flat_file_mtimes <- file.mtime(flat_files)
  analysis_mtime <- file.mtime(analysis_ready_pupil)
  if(any(flat_file_mtimes > analysis_mtime, na.rm = TRUE)) {
    cat("  New or updated flat files detected - will regenerate analysis-ready data\n")
    needs_rerun <- TRUE
  } else {
    cat("  Analysis-ready files are up-to-date\n")
  }
}

# ============================================================================
# STEP 2: DATA PREPARATION (if needed)
# ============================================================================

if(needs_rerun) {
  cat("\nSTEP 2: Preparing analysis-ready data...\n")
  cat("  Sourcing: 02_pupillometry_analysis/feature_extraction/prepare_analysis_ready_data.R\n")
  cat("  This will create BAP_analysis_ready_PUPIL.csv and BAP_analysis_ready_BEHAVIORAL.csv\n")
  
  tryCatch({
    source("02_pupillometry_analysis/feature_extraction/prepare_analysis_ready_data.R")
    cat("  ✓ Data preparation complete\n")
  }, error = function(e) {
    cat("  ✗ ERROR in data preparation:", e$message, "\n")
    stop("Pipeline failed at data preparation step")
  })
} else {
  cat("\nSTEP 2: Skipping data preparation (files are up-to-date)\n")
  cat("  To force regeneration, delete:", analysis_ready_pupil, "\n")
}

# ============================================================================
# STEP 3: FEATURE EXTRACTION (if needed)
# ============================================================================

cat("\nSTEP 3: Running feature extraction...\n")
cat("  Sourcing: 02_pupillometry_analysis/feature_extraction/run_feature_extraction.R\n")

tryCatch({
  source("02_pupillometry_analysis/feature_extraction/run_feature_extraction.R")
  cat("  ✓ Feature extraction complete\n")
}, error = function(e) {
  cat("  ✗ ERROR in feature extraction:", e$message, "\n")
  warning("Feature extraction failed, but continuing with pipeline...")
})

# ============================================================================
# STEP 4: QUALITY CONTROL
# ============================================================================

cat("\nSTEP 4: Running quality control checks...\n")
cat("  Sourcing: 02_pupillometry_analysis/quality_control/run_pupil_qc.R\n")

tryCatch({
  source("02_pupillometry_analysis/quality_control/run_pupil_qc.R")
  cat("  ✓ Quality control complete\n")
}, error = function(e) {
  cat("  ✗ ERROR in quality control:", e$message, "\n")
  warning("Quality control failed, but continuing with pipeline...")
})

# ============================================================================
# STEP 5: VISUALIZATIONS
# ============================================================================

cat("\nSTEP 5: Generating visualizations...\n")

# 5a. QC visualizations
cat("  5a. QC visualizations...\n")
cat("    Sourcing: 02_pupillometry_analysis/visualization/run_pupil_visualizations.R\n")

tryCatch({
  source("02_pupillometry_analysis/visualization/run_pupil_visualizations.R")
  cat("    ✓ QC visualizations complete\n")
}, error = function(e) {
  cat("    ✗ ERROR in QC visualizations:", e$message, "\n")
  warning("QC visualizations failed, but continuing...")
})

# 5b. Waveform plots
cat("  5b. Waveform plots...\n")
cat("    Sourcing: 02_pupillometry_analysis/visualization/plot_pupil_waveforms.R\n")

tryCatch({
  source("02_pupillometry_analysis/visualization/plot_pupil_waveforms.R")
  cat("    ✓ Waveform plots complete\n")
}, error = function(e) {
  cat("    ✗ ERROR in waveform plots:", e$message, "\n")
  warning("Waveform plots failed, but continuing...")
})

# ============================================================================
# STEP 6: SUMMARY REPORT
# ============================================================================

cat("\nSTEP 6: Generating summary report...\n")

summary_file <- file.path("02_pupillometry_analysis", "pipeline_summary.txt")
sink(summary_file)

cat("=================================================================\n")
cat("PUPILLOMETRY PIPELINE SUMMARY\n")
cat("=================================================================\n\n")
cat("Generated at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Data summary
if(file.exists(analysis_ready_pupil)) {
  pupil_data <- read_csv(analysis_ready_pupil, show_col_types = FALSE, n_max = 1)
  cat("ANALYSIS-READY DATA:\n")
  cat("  Pupil data file:", analysis_ready_pupil, "\n")
  if(file.exists(analysis_ready_behav)) {
    behav_data <- read_csv(analysis_ready_behav, show_col_types = FALSE, n_max = 1)
    cat("  Behavioral data file:", analysis_ready_behav, "\n")
  }
  cat("\n")
}

# File counts
cat("DATA FILES:\n")
cat("  Total flat files:", length(flat_files), "\n")
cat("  Merged files:", length(flat_files_merged), "\n")
cat("  Regular files:", length(flat_files_reg), "\n")
cat("\n")

# Subject and trial counts
if(file.exists(analysis_ready_pupil)) {
  pupil_summary <- read_csv(analysis_ready_pupil, show_col_types = FALSE)
  cat("DATA SUMMARY:\n")
  cat("  Total trials:", nrow(pupil_summary), "\n")
  if("subject_id" %in% names(pupil_summary)) {
    cat("  Unique subjects:", length(unique(pupil_summary$subject_id)), "\n")
  }
  if("task" %in% names(pupil_summary)) {
    cat("  Tasks:", paste(unique(pupil_summary$task), collapse = ", "), "\n")
  }
  if("difficulty_level" %in% names(pupil_summary)) {
    cat("  Difficulty levels:", paste(unique(pupil_summary$difficulty_level[!is.na(pupil_summary$difficulty_level)]), collapse = ", "), "\n")
  }
  if("total_auc" %in% names(pupil_summary)) {
    cat("  Trials with Total AUC:", sum(!is.na(pupil_summary$total_auc)), "\n")
  }
  if("cognitive_auc" %in% names(pupil_summary)) {
    cat("  Trials with Cognitive AUC:", sum(!is.na(pupil_summary$cognitive_auc)), "\n")
  }
  cat("\n")
}

# Output files
cat("OUTPUT FILES:\n")
cat("  Analysis-ready data:", output_dir, "\n")
cat("  QC reports:", qc_output_dir, "\n")
cat("  Visualizations:", viz_output_dir, "\n")
cat("\n")

cat("=================================================================\n")
cat("PIPELINE COMPLETE\n")
cat("=================================================================\n")

sink()

cat("  ✓ Summary report saved:", summary_file, "\n")

# ============================================================================
# COMPLETION
# ============================================================================

cat("\n=================================================================\n")
cat("FULL PIPELINE COMPLETE\n")
cat("=================================================================\n")
cat("Completed at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("Next steps:\n")
cat("  1. Review QC reports in:", qc_output_dir, "\n")
cat("  2. Check visualizations in:", viz_output_dir, "\n")
cat("  3. Review summary report:", summary_file, "\n")
cat("\n")

cat("To re-run the pipeline after adding new data:\n")
cat("  source('02_pupillometry_analysis/run_full_pupillometry_pipeline.R')\n")
cat("\n")

