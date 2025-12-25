#!/usr/bin/env Rscript

# ============================================================================
# REBUILD DATASETS WITH FORENSIC FIXES APPLIED
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(arrow)
})

BASE_DIR <- "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM"
OUTPUT_DIR <- file.path(BASE_DIR, "data/qc/pipeline_forensics")
ANALYSIS_READY_DIR <- file.path(BASE_DIR, "data/analysis_ready")
BAP_PROCESSED <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"

cat("=== REBUILDING WITH FORENSIC FIXES ===\n\n")
cat("NOTE: This script assumes MATLAB and R merger have been re-run with fixes.\n")
cat("If not, you need to:\n")
cat("1. Re-run MATLAB pipeline (adds ses column to flat files)\n")
cat("2. Re-run R merger (maps session_num->ses, includes ses in merge keys)\n")
cat("3. Then re-run QMD (this script will check QMD output)\n\n")

# Check if new merged files exist
merged_files <- list.files(BAP_PROCESSED, pattern = "_flat_merged\\.csv$", full.names = TRUE)
cat("Found", length(merged_files), "merged files\n")

if (length(merged_files) > 0) {
  # Sample a file to check if fixes are applied
  sample_file <- merged_files[1]
  sample_data <- read_csv(sample_file, show_col_types = FALSE, n_max = 10)
  
  cat("Sample merged file columns:", paste(names(sample_data), collapse = ", "), "\n")
  
  if ("ses" %in% names(sample_data)) {
    cat("✓ ses column found in merged files\n")
    cat("  ses values:", paste(unique(sample_data$ses), collapse = ", "), "\n")
    cat("  run values:", paste(unique(sample_data$run), collapse = ", "), "\n")
    
    # Check if run != ses
    if (any(sample_data$run != sample_data$ses, na.rm = TRUE)) {
      cat("✓ run != ses (fix working!)\n")
    } else {
      cat("⚠ run still equals ses - may need to check QMD\n")
    }
  } else {
    cat("✗ ses column NOT found - R merger may not have been re-run\n")
  }
}

# Check QMD output
merged_file <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_MERGED.csv")
if (file.exists(merged_file)) {
  cat("\nChecking QMD output...\n")
  merged_qmd <- read_csv(merged_file, show_col_types = FALSE, n_max = 1000)
  
  if ("ses" %in% names(merged_qmd)) {
    cat("✓ ses column in MERGED\n")
    cat("  ses distribution:\n")
    print(table(merged_qmd$ses, useNA = "ifany"))
    
    if ("run" %in% names(merged_qmd)) {
      cat("  run distribution:\n")
      print(table(merged_qmd$run, useNA = "ifany"))
      
      # Check run != ses
      if (any(merged_qmd$run != merged_qmd$ses, na.rm = TRUE)) {
        cat("✓ run != ses in MERGED (fix working!)\n")
      } else {
        cat("⚠ run still equals ses in MERGED\n")
      }
    }
  } else {
    cat("✗ ses column NOT in MERGED - QMD may not have been re-run\n")
  }
}

cat("\n=== NEXT STEPS ===\n")
cat("1. Re-run MATLAB pipeline to add ses to flat files\n")
cat("2. Re-run R merger to map session_num->ses\n")
cat("3. Re-run QMD to create new MERGED and TRIALLEVEL\n")
cat("4. Verify with this script\n")

