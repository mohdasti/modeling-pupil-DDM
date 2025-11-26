#!/usr/bin/env Rscript
# =========================================================================
# MODULAR PIPELINE RUNNER - Run Steps Individually
# =========================================================================
# This allows you to run pipeline steps one at a time to avoid memory issues
# Each step can be run independently after prerequisites are complete
# =========================================================================

suppressPackageStartupMessages({
  library(here)
})

# =========================================================================
# HELPER FUNCTIONS
# =========================================================================

log_step <- function(step_name, message, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat(sprintf("[%s] [%s] [%s] %s\n", timestamp, level, step_name, message))
  flush.console()
}

check_prerequisite <- function(file_path, step_name) {
  if (!file.exists(file_path)) {
    log_step(step_name, sprintf("ERROR: Prerequisite file not found: %s", file_path), "ERROR")
    return(FALSE)
  }
  return(TRUE)
}

# =========================================================================
# STEP 1: DATA PREPARATION
# =========================================================================

run_step1a_ddm_only <- function() {
  log_step("STEP 1A", "Starting DDM-only data preparation...")
  start_time <- Sys.time()
  
  tryCatch({
    source("01_data_preprocessing/r/prepare_ddm_only_data.R")
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    log_step("STEP 1A", sprintf("✓ Complete (%.1f seconds)", elapsed))
    return(TRUE)
  }, error = function(e) {
    log_step("STEP 1A", sprintf("✗ FAILED: %s", e$message), "ERROR")
    return(FALSE)
  })
}

run_step1b_ddm_pupil <- function() {
  log_step("STEP 1B", "Starting DDM-pupil data preparation...")
  
  pupil_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
  if (!dir.exists(pupil_dir)) {
    log_step("STEP 1B", "⚠ Skipped (pupil data directory not found)", "WARN")
    return(FALSE)
  }
  
  start_time <- Sys.time()
  tryCatch({
    source("01_data_preprocessing/r/prepare_ddm_pupil_data.R")
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    log_step("STEP 1B", sprintf("✓ Complete (%.1f seconds)", elapsed))
    return(TRUE)
  }, error = function(e) {
    log_step("STEP 1B", sprintf("✗ FAILED: %s", e$message), "ERROR")
    return(FALSE)
  })
}

# =========================================================================
# STEP 2: PUPILLOMETRY ANALYSIS
# =========================================================================

run_step2a_features <- function() {
  log_step("STEP 2A", "Starting pupil feature extraction...")
  
  script <- "02_pupillometry_analysis/feature_extraction/run_feature_extraction.R"
  if (!file.exists(script)) {
    log_step("STEP 2A", "⚠ Skipped (script not found)", "WARN")
    return(FALSE)
  }
  
  start_time <- Sys.time()
  tryCatch({
    source(script)
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    log_step("STEP 2A", sprintf("✓ Complete (%.1f seconds)", elapsed))
    return(TRUE)
  }, error = function(e) {
    log_step("STEP 2A", sprintf("✗ FAILED: %s", e$message), "ERROR")
    return(FALSE)
  })
}

run_step2b_qc <- function() {
  log_step("STEP 2B", "Starting pupil quality control...")
  
  script <- "02_pupillometry_analysis/quality_control/run_pupil_qc.R"
  if (!file.exists(script)) {
    log_step("STEP 2B", "⚠ Skipped (script not found)", "WARN")
    return(FALSE)
  }
  
  start_time <- Sys.time()
  tryCatch({
    source(script)
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    log_step("STEP 2B", sprintf("✓ Complete (%.1f seconds)", elapsed))
    return(TRUE)
  }, error = function(e) {
    log_step("STEP 2B", sprintf("✗ FAILED: %s", e$message), "ERROR")
    return(FALSE)
  })
}

# =========================================================================
# STEP 3: BEHAVIORAL ANALYSIS
# =========================================================================

run_step3a_rt_analysis <- function() {
  log_step("STEP 3A", "Starting RT analysis...")
  
  script <- "03_behavioral_analysis/reaction_time/run_rt_analysis.R"
  if (!file.exists(script)) {
    log_step("STEP 3A", "⚠ Skipped (script not found)", "WARN")
    return(FALSE)
  }
  
  start_time <- Sys.time()
  tryCatch({
    source(script)
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    log_step("STEP 3A", sprintf("✓ Complete (%.1f seconds)", elapsed))
    return(TRUE)
  }, error = function(e) {
    log_step("STEP 3A", sprintf("✗ FAILED: %s", e$message), "ERROR")
    return(FALSE)
  })
}

# =========================================================================
# STEP 4: COMPUTATIONAL MODELING
# =========================================================================

run_step4a_standard_bias <- function() {
  log_step("STEP 4A", "Starting Standard-only bias model fitting...")
  log_step("STEP 4A", "Note: This may take 30-60 minutes")
  
  # Check prerequisite
  if (!check_prerequisite("data/analysis_ready/bap_ddm_only_ready.csv", "STEP 4A")) {
    return(FALSE)
  }
  
  start_time <- Sys.time()
  tryCatch({
    source("04_computational_modeling/drift_diffusion/fit_standard_bias_only.R")
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))
    log_step("STEP 4A", sprintf("✓ Complete (%.1f minutes)", elapsed))
    return(TRUE)
  }, error = function(e) {
    log_step("STEP 4A", sprintf("✗ FAILED: %s", e$message), "ERROR")
    return(FALSE)
  })
}

run_step4b_primary_model <- function() {
  log_step("STEP 4B", "Starting Primary model (v+z+a) fitting...")
  log_step("STEP 4B", "Note: This may take 30-60 minutes")
  
  # Check prerequisite
  if (!check_prerequisite("data/analysis_ready/bap_ddm_only_ready.csv", "STEP 4B")) {
    return(FALSE)
  }
  
  start_time <- Sys.time()
  tryCatch({
    source("04_computational_modeling/drift_diffusion/fit_primary_vza.R")
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))
    log_step("STEP 4B", sprintf("✓ Complete (%.1f minutes)", elapsed))
    return(TRUE)
  }, error = function(e) {
    log_step("STEP 4B", sprintf("✗ FAILED: %s", e$message), "ERROR")
    return(FALSE)
  })
}

# =========================================================================
# STEP 5: STATISTICAL ANALYSIS
# =========================================================================

run_step5a_statistics <- function() {
  log_step("STEP 5A", "Starting statistical analysis...")
  
  # Check prerequisites
  if (!check_prerequisite("output/models/primary_vza.rds", "STEP 5A")) {
    return(FALSE)
  }
  
  script <- "scripts/02_statistical_analysis/02_ddm_analysis.R"
  if (!file.exists(script)) {
    log_step("STEP 5A", "⚠ Skipped (script not found)", "WARN")
    return(FALSE)
  }
  
  start_time <- Sys.time()
  tryCatch({
    source(script)
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))
    log_step("STEP 5A", sprintf("✓ Complete (%.1f minutes)", elapsed))
    return(TRUE)
  }, error = function(e) {
    log_step("STEP 5A", sprintf("✗ FAILED: %s", e$message), "ERROR")
    return(FALSE)
  })
}

# =========================================================================
# STEP 6: VISUALIZATION
# =========================================================================

run_step6a_visualization <- function() {
  log_step("STEP 6A", "Starting visualization...")
  
  script <- "scripts/02_statistical_analysis/create_results_visualizations.R"
  if (!file.exists(script)) {
    log_step("STEP 6A", "⚠ Skipped (script not found)", "WARN")
    return(FALSE)
  }
  
  start_time <- Sys.time()
  tryCatch({
    source(script)
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    log_step("STEP 6A", sprintf("✓ Complete (%.1f seconds)", elapsed))
    return(TRUE)
  }, error = function(e) {
    log_step("STEP 6A", sprintf("✗ FAILED: %s", e$message), "ERROR")
    return(FALSE)
  })
}

# =========================================================================
# MAIN EXECUTION - MODULAR
# =========================================================================

cat("\n")
cat("=" %+% strrep("=", 78), "\n")
cat("MODULAR DDM PIPELINE RUNNER\n")
cat("=" %+% strrep("=", 78), "\n")
cat("\n")
cat("Available functions:\n")
cat("  run_step1a_ddm_only()       - Prepare DDM-only data (REQUIRED FIRST)\n")
cat("  run_step1b_ddm_pupil()      - Prepare DDM-pupil data (OPTIONAL)\n")
cat("  run_step2a_features()       - Extract pupil features (OPTIONAL)\n")
cat("  run_step2b_qc()             - Pupil quality control (OPTIONAL)\n")
cat("  run_step3a_rt_analysis()    - RT analysis (RECOMMENDED)\n")
cat("  run_step4a_standard_bias()  - Fit Standard-only bias model (RECOMMENDED)\n")
cat("  run_step4b_primary_model()  - Fit Primary model (REQUIRED)\n")
cat("  run_step5a_statistics()     - Statistical analysis (OPTIONAL)\n")
cat("  run_step6a_visualization()  - Create visualizations (OPTIONAL)\n")
cat("\n")
cat("Example usage:\n")
cat("  # Step 1: Prepare data\n")
cat("  run_step1a_ddm_only()\n")
cat("\n")
cat("  # Step 4: Fit models (after Step 1)\n")
cat("  run_step4a_standard_bias()\n")
cat("  run_step4b_primary_model()\n")
cat("\n")
cat("=" %+% strrep("=", 78), "\n")
cat("\n")

# Helper function for string concatenation
`%+%` <- function(x, y) paste0(x, y)

# If running as script with arguments, execute specified step
if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) > 0) {
    step_name <- args[1]
    switch(step_name,
      "1a" = run_step1a_ddm_only(),
      "1b" = run_step1b_ddm_pupil(),
      "2a" = run_step2a_features(),
      "2b" = run_step2b_qc(),
      "3a" = run_step3a_rt_analysis(),
      "4a" = run_step4a_standard_bias(),
      "4b" = run_step4b_primary_model(),
      "5a" = run_step5a_statistics(),
      "6a" = run_step6a_visualization(),
      {
        cat("Unknown step:", step_name, "\n")
        cat("Available steps: 1a, 1b, 2a, 2b, 3a, 4a, 4b, 5a, 6a\n")
        quit(status = 1)
      }
    )
  }
}

