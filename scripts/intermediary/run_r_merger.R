#!/usr/bin/env Rscript

# ============================================================================
# Run R Merger
# ============================================================================
# This script runs the R merger to create merged flat files
# ============================================================================

# Get the project root directory
project_root <- "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM"

# Set working directory
setwd(project_root)

cat("============================================================================\n")
cat("RUNNING R MERGER\n")
cat("============================================================================\n")
cat("Working directory:", getwd(), "\n")
cat("Script: 01_data_preprocessing/r/Create merged flat file.R\n")
cat("\n")

# Source the merger script
merger_script <- file.path(project_root, "01_data_preprocessing", "r", "Create merged flat file.R")

if (!file.exists(merger_script)) {
  stop("ERROR: R merger script not found: ", merger_script)
}

# Run the merger
tryCatch({
  source(merger_script)
  cat("\n============================================================================\n")
  cat("R MERGER COMPLETE\n")
  cat("============================================================================\n")
}, error = function(e) {
  cat("\n============================================================================\n")
  cat("ERROR: R MERGER FAILED\n")
  cat("============================================================================\n")
  cat("Error message:", e$message, "\n")
  stop(e)
})

