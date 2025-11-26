#!/usr/bin/env Rscript
# =========================================================================
# MASTER DDM PIPELINE RUNNER
# =========================================================================
# Professional, reproducible pipeline following 7-step structure
# Supports both DDM-only and DDM-pupil analyses
# =========================================================================

suppressPackageStartupMessages({
  library(here)
})

# =========================================================================
# CONFIGURATION
# =========================================================================

PIPELINE_START <- Sys.time()
LOG_DIR <- "logs"
PIPELINE_LOG <- file.path(LOG_DIR, paste0("ddm_pipeline_", format(PIPELINE_START, "%Y%m%d_%H%M%S"), ".log"))

# Create log directory
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)

# Logging function
log_pipeline <- function(..., level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  msg <- paste(..., collapse = " ")
  log_entry <- sprintf("[%s] [%s] %s\n", timestamp, level, msg)
  cat(log_entry)
  cat(log_entry, file = PIPELINE_LOG, append = TRUE)
  flush.console()
}

# =========================================================================
# PIPELINE HEADER
# =========================================================================

log_pipeline(strrep("=", 80))
log_pipeline("DDM ANALYSIS PIPELINE")
log_pipeline(strrep("=", 80))
log_pipeline("Start time:", format(PIPELINE_START, "%Y-%m-%d %H:%M:%S"))
log_pipeline("Working directory:", getwd())
log_pipeline("Pipeline log:", PIPELINE_LOG)
log_pipeline("")

# =========================================================================
# STEP 1: DATA PREPARATION
# =========================================================================

log_pipeline("STEP 1: DATA PREPARATION")
log_pipeline(strrep("-", 80))

# Option A: DDM-only data (no pupil requirement)
log_pipeline("Option A: Preparing DDM-only data...")
step1a_start <- Sys.time()

result_step1a <- tryCatch({
  source("01_data_preprocessing/r/prepare_ddm_only_data.R")
  list(success = TRUE, message = "DDM-only data prepared successfully")
}, error = function(e) {
  log_pipeline("ERROR in Step 1A:", e$message, level = "ERROR")
  list(success = FALSE, message = e$message)
})

step1a_time <- as.numeric(difftime(Sys.time(), step1a_start, units = "secs"))
log_pipeline(sprintf("  Step 1A elapsed time: %.1f seconds", step1a_time))

if (result_step1a$success) {
  log_pipeline("  ✓ DDM-only data preparation complete")
} else {
  log_pipeline("  ✗ DDM-only data preparation failed", level = "ERROR")
}

log_pipeline("")

# Option B: DDM-pupil data (requires pupil files)
log_pipeline("Option B: Preparing DDM-pupil data...")
step1b_start <- Sys.time()

result_step1b <- tryCatch({
  if (dir.exists("/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed")) {
    source("01_data_preprocessing/r/prepare_ddm_pupil_data.R")
    list(success = TRUE, message = "DDM-pupil data prepared successfully")
  } else {
    log_pipeline("  Skipping: Pupil data directory not found", level = "WARN")
    list(success = FALSE, message = "Pupil data directory not available")
  }
}, error = function(e) {
  log_pipeline("ERROR in Step 1B:", e$message, level = "ERROR")
  list(success = FALSE, message = e$message)
})

step1b_time <- as.numeric(difftime(Sys.time(), step1b_start, units = "secs"))
log_pipeline(sprintf("  Step 1B elapsed time: %.1f seconds", step1b_time))

if (result_step1b$success) {
  log_pipeline("  ✓ DDM-pupil data preparation complete")
} else {
  log_pipeline("  ⚠ DDM-pupil data preparation skipped (pupil data not available)")
}

log_pipeline("")

# =========================================================================
# STEP 2-3: OPTIONAL (Pupillometry and Behavioral Analysis)
# =========================================================================

log_pipeline("STEP 2-3: OPTIONAL ANALYSES")
log_pipeline("  Note: These steps are optional and can be run separately")
log_pipeline("  Use run_complete_ddm_pipeline.R for full 7-step pipeline")
log_pipeline("")

# =========================================================================
# STEP 4: COMPUTATIONAL MODELING
# =========================================================================

log_pipeline("STEP 4: COMPUTATIONAL MODELING")
log_pipeline(strrep("-", 80))

# 4A: Standard-only bias model
log_pipeline("4A: Fitting Standard-only bias model...")
step4a_start <- Sys.time()

result_step4a <- tryCatch({
  source("04_computational_modeling/drift_diffusion/fit_standard_bias_only.R")
  list(success = TRUE, message = "Standard-only bias model fitted successfully")
}, error = function(e) {
  log_pipeline("ERROR in Step 4A:", e$message, level = "ERROR")
  list(success = FALSE, message = e$message)
})

step4a_time <- as.numeric(difftime(Sys.time(), step4a_start, units = "mins"))
log_pipeline(sprintf("  Step 4A elapsed time: %.1f minutes", step4a_time))

if (result_step4a$success) {
  log_pipeline("  ✓ Standard-only bias model complete")
} else {
  log_pipeline("  ✗ Standard-only bias model failed", level = "ERROR")
}

log_pipeline("")

# 4B: Primary model (v + z + a)
log_pipeline("4B: Fitting Primary model (v + z + a)...")
step4b_start <- Sys.time()

result_step4b <- tryCatch({
  source("04_computational_modeling/drift_diffusion/fit_primary_vza.R")
  list(success = TRUE, message = "Primary model fitted successfully")
}, error = function(e) {
  log_pipeline("ERROR in Step 4B:", e$message, level = "ERROR")
  list(success = FALSE, message = e$message)
})

step4b_time <- as.numeric(difftime(Sys.time(), step4b_start, units = "mins"))
log_pipeline(sprintf("  Step 4B elapsed time: %.1f minutes", step4b_time))

if (result_step4b$success) {
  log_pipeline("  ✓ Primary model complete")
} else {
  log_pipeline("  ✗ Primary model failed", level = "ERROR")
}

log_pipeline("")

# =========================================================================
# STEP 5-7: PLACEHOLDER (Statistical Analysis, Visualization, Manuscript)
# =========================================================================

log_pipeline("STEP 5-7: PLACEHOLDER")
log_pipeline("  (Statistical analysis, visualization, and manuscript generation")
log_pipeline("   run separately via dedicated scripts)")
log_pipeline("")

# =========================================================================
# PIPELINE SUMMARY
# =========================================================================

PIPELINE_END <- Sys.time()
TOTAL_TIME <- as.numeric(difftime(PIPELINE_END, PIPELINE_START, units = "mins"))

log_pipeline(strrep("=", 80))
log_pipeline("PIPELINE SUMMARY")
log_pipeline(strrep("=", 80))
log_pipeline("Step 1A (DDM-only data):", ifelse(result_step1a$success, "✓ SUCCESS", "✗ FAILED"))
log_pipeline("Step 1B (DDM-pupil data):", ifelse(result_step1b$success, "✓ SUCCESS", "⚠ SKIPPED"))
log_pipeline("Step 4A (Standard bias):", ifelse(result_step4a$success, "✓ SUCCESS", "✗ FAILED"))
log_pipeline("Step 4B (Primary model):", ifelse(result_step4b$success, "✓ SUCCESS", "✗ FAILED"))
log_pipeline("")
log_pipeline("Total pipeline time:", round(TOTAL_TIME, 1), "minutes")
log_pipeline("End time:", format(PIPELINE_END, "%Y-%m-%d %H:%M:%S"))
log_pipeline(strrep("=", 80))

# Exit with appropriate code
if (!result_step1a$success || !result_step4a$success || !result_step4b$success) {
  quit(status = 1)
}

