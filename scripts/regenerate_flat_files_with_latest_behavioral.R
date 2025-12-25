#!/usr/bin/env Rscript
# ============================================================================
# Regenerate Flat Files with Latest Behavioral Data
# ============================================================================
# This script re-runs the merger to update all flat files with the latest
# behavioral data from /Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/
# ============================================================================

cat("================================================================================\n")
cat("REGENERATING FLAT FILES WITH LATEST BEHAVIORAL DATA\n")
cat("================================================================================\n\n")

cat("This script will:\n")
cat("  1. Load all existing flat CSV files\n")
cat("  2. Re-merge them with the latest behavioral data\n")
cat("  3. Overwrite existing _flat_merged.csv files\n\n")

cat("Behavioral data source:\n")
behavioral_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"
cat(sprintf("  %s\n\n", behavioral_file))

if(!file.exists(behavioral_file)) {
  stop("ERROR: Behavioral file not found at: ", behavioral_file)
}

cat("Proceeding with merge...\n\n")

# Source the merger script
source("01_data_preprocessing/r/Create merged flat file.R")

cat("\n================================================================================\n")
cat("REGENERATION COMPLETE\n")
cat("================================================================================\n\n")









