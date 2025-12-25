#!/usr/bin/env Rscript

# ============================================================================
# Pupillometry Feature Extraction
# ============================================================================
# Step 1: Prepare analysis-ready data from merged flat files
# Step 2: Integrate with subject-level data (demographics, LC integrity, etc.)
# ============================================================================

cat("=== PUPILLOMETRY FEATURE EXTRACTION ===\n\n")

# Step 1: Prepare analysis-ready data (if not already created)
if(!file.exists('data/analysis_ready/BAP_analysis_ready_PUPIL.csv') || 
   !file.exists('data/analysis_ready/BAP_analysis_ready_BEHAVIORAL.csv')) {
  cat("Step 1: Preparing analysis-ready data from merged flat files...\n")
  suppressWarnings(suppressMessages({
    source('02_pupillometry_analysis/feature_extraction/prepare_analysis_ready_data.R')
  }))
  cat("\n")
} else {
  cat("Step 1: Analysis-ready data already exists. Skipping.\n")
  cat("  Found: data/analysis_ready/BAP_analysis_ready_PUPIL.csv\n")
  cat("  Found: data/analysis_ready/BAP_analysis_ready_BEHAVIORAL.csv\n\n")
}

# Step 2: Integrate with subject-level data
cat("Step 2: Integrating with subject-level data...\n")
suppressWarnings(suppressMessages({
  source(file.path('scripts','utilities','data_integration.R'))
}))

cat("\n=== FEATURE EXTRACTION COMPLETE ===\n")
