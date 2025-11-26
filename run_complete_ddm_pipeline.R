#!/usr/bin/env Rscript
# =========================================================================
# COMPLETE DDM PIPELINE - ALL 7 STEPS
# =========================================================================
# Professional, reproducible pipeline following 7-step structure
# Runs all steps in order with proper dependencies and validation
# =========================================================================

suppressPackageStartupMessages({
  library(here)
})

# =========================================================================
# CONFIGURATION
# =========================================================================

PIPELINE_START <- Sys.time()
LOG_DIR <- "logs"
PIPELINE_LOG <- file.path(LOG_DIR, paste0("complete_pipeline_", format(PIPELINE_START, "%Y%m%d_%H%M%S"), ".log"))

# Create log directory
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)

# Helper function for string concatenation
`%+%` <- function(x, y) paste0(x, y)

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
log_pipeline("COMPLETE DDM ANALYSIS PIPELINE - ALL 7 STEPS")
log_pipeline(strrep("=", 80))
log_pipeline("Start time:", format(PIPELINE_START, "%Y-%m-%d %H:%M:%S"))
log_pipeline("Working directory:", getwd())
log_pipeline("Pipeline log:", PIPELINE_LOG)
log_pipeline("")
log_pipeline("This pipeline will run all 7 steps in order:")
log_pipeline("  Step 1: Data Preprocessing")
log_pipeline("  Step 2: Pupillometry Analysis")
log_pipeline("  Step 3: Behavioral Analysis")
log_pipeline("  Step 4: Computational Modeling (DDM)")
log_pipeline("  Step 5: Statistical Analysis")
log_pipeline("  Step 6: Visualization")
log_pipeline("  Step 7: Manuscript Generation")
log_pipeline("")

# =========================================================================
# STEP 1: DATA PREPARATION
# =========================================================================

log_pipeline(strrep("=", 80))
log_pipeline("STEP 1: DATA PREPARATION")
log_pipeline(strrep("=", 80))

# Option A: DDM-only data (REQUIRED)
log_pipeline("1A: Preparing DDM-only data (REQUIRED)...")
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

if (!result_step1a$success) {
  log_pipeline("  ✗ Step 1A FAILED - Pipeline cannot continue", level = "ERROR")
  quit(status = 1)
} else {
  log_pipeline("  ✓ Step 1A complete")
}

log_pipeline("")

# Option B: DDM-pupil data (OPTIONAL - only if pupil files available)
log_pipeline("1B: Preparing DDM-pupil data (OPTIONAL)...")
step1b_start <- Sys.time()

PUPIL_DIR <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
if (dir.exists(PUPIL_DIR)) {
  result_step1b <- tryCatch({
    source("01_data_preprocessing/r/prepare_ddm_pupil_data.R")
    list(success = TRUE, message = "DDM-pupil data prepared successfully")
  }, error = function(e) {
    log_pipeline("ERROR in Step 1B:", e$message, level = "ERROR")
    list(success = FALSE, message = e$message)
  })
} else {
  log_pipeline("  Skipping: Pupil data directory not found", level = "WARN")
  log_pipeline("  Location checked:", PUPIL_DIR)
  result_step1b <- list(success = FALSE, message = "Pupil data directory not available")
}

step1b_time <- as.numeric(difftime(Sys.time(), step1b_start, units = "secs"))
log_pipeline(sprintf("  Step 1B elapsed time: %.1f seconds", step1b_time))

if (result_step1b$success) {
  log_pipeline("  ✓ Step 1B complete")
} else {
  log_pipeline("  ⚠ Step 1B skipped (pupil data not available)")
}

log_pipeline("")

# =========================================================================
# STEP 2: PUPILLOMETRY ANALYSIS
# =========================================================================

log_pipeline(strrep("=", 80))
log_pipeline("STEP 2: PUPILLOMETRY ANALYSIS")
log_pipeline(strrep("=", 80))
log_pipeline("2A: Pupil feature extraction (OPTIONAL - requires pupil data)...")

step2a_start <- Sys.time()

# Check if pupil feature extraction script exists
FEATURE_EXTRACTION_SCRIPT <- "02_pupillometry_analysis/feature_extraction/run_feature_extraction.R"
if (file.exists(FEATURE_EXTRACTION_SCRIPT)) {
  result_step2a <- tryCatch({
    source(FEATURE_EXTRACTION_SCRIPT)
    list(success = TRUE, message = "Pupil feature extraction completed")
  }, error = function(e) {
    log_pipeline("ERROR in Step 2A:", e$message, level = "ERROR")
    list(success = FALSE, message = e$message)
  })
} else {
  log_pipeline("  Skipping: Feature extraction script not found", level = "WARN")
  result_step2a <- list(success = FALSE, message = "Script not found")
}

step2a_time <- as.numeric(difftime(Sys.time(), step2a_start, units = "secs"))
log_pipeline(sprintf("  Step 2A elapsed time: %.1f seconds", step2a_time))

if (result_step2a$success) {
  log_pipeline("  ✓ Step 2A complete")
} else {
  log_pipeline("  ⚠ Step 2A skipped")
}

log_pipeline("")

log_pipeline("2B: Pupil quality control (OPTIONAL - requires pupil data)...")

step2b_start <- Sys.time()

QC_SCRIPT <- "02_pupillometry_analysis/quality_control/run_pupil_qc.R"
if (file.exists(QC_SCRIPT)) {
  result_step2b <- tryCatch({
    source(QC_SCRIPT)
    list(success = TRUE, message = "Pupil QC completed")
  }, error = function(e) {
    log_pipeline("ERROR in Step 2B:", e$message, level = "ERROR")
    list(success = FALSE, message = e$message)
  })
} else {
  log_pipeline("  Skipping: QC script not found", level = "WARN")
  result_step2b <- list(success = FALSE, message = "Script not found")
}

step2b_time <- as.numeric(difftime(Sys.time(), step2b_start, units = "secs"))
log_pipeline(sprintf("  Step 2B elapsed time: %.1f seconds", step2b_time))

if (result_step2b$success) {
  log_pipeline("  ✓ Step 2B complete")
} else {
  log_pipeline("  ⚠ Step 2B skipped")
}

log_pipeline("")

# =========================================================================
# STEP 3: BEHAVIORAL ANALYSIS
# =========================================================================

log_pipeline(strrep("=", 80))
log_pipeline("STEP 3: BEHAVIORAL ANALYSIS")
log_pipeline(strrep("=", 80))
log_pipeline("3A: RT analysis and sanity checks (RECOMMENDED)...")

step3a_start <- Sys.time()

RT_ANALYSIS_SCRIPT <- "03_behavioral_analysis/reaction_time/run_rt_analysis.R"
if (file.exists(RT_ANALYSIS_SCRIPT)) {
  result_step3a <- tryCatch({
    source(RT_ANALYSIS_SCRIPT)
    list(success = TRUE, message = "RT analysis completed")
  }, error = function(e) {
    log_pipeline("ERROR in Step 3A:", e$message, level = "ERROR")
    list(success = FALSE, message = e$message)
  })
} else {
  log_pipeline("  Skipping: RT analysis script not found", level = "WARN")
  result_step3a <- list(success = FALSE, message = "Script not found")
}

step3a_time <- as.numeric(difftime(Sys.time(), step3a_start, units = "secs"))
log_pipeline(sprintf("  Step 3A elapsed time: %.1f seconds", step3a_time))

if (result_step3a$success) {
  log_pipeline("  ✓ Step 3A complete")
} else {
  log_pipeline("  ⚠ Step 3A skipped")
}

log_pipeline("")

# =========================================================================
# STEP 4: COMPUTATIONAL MODELING (DDM)
# =========================================================================

log_pipeline(strrep("=", 80))
log_pipeline("STEP 4: COMPUTATIONAL MODELING (DDM)")
log_pipeline(strrep("=", 80))
log_pipeline("Note: This step may take 30-60 minutes per model")
log_pipeline("")

# 4A: Standard-only bias model (RECOMMENDED FIRST)
log_pipeline("4A: Fitting Standard-only bias model (RECOMMENDED FIRST)...")
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
  log_pipeline("  ✓ Step 4A complete")
} else {
  log_pipeline("  ✗ Step 4A FAILED", level = "ERROR")
}

log_pipeline("")

# 4B: Primary model (v + z + a) (REQUIRED)
log_pipeline("4B: Fitting Primary model (v + z + a) (REQUIRED)...")
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

if (!result_step4b$success) {
  log_pipeline("  ✗ Step 4B FAILED - Pipeline cannot continue", level = "ERROR")
  quit(status = 1)
} else {
  log_pipeline("  ✓ Step 4B complete")
}

log_pipeline("")

# =========================================================================
# STEP 5: STATISTICAL ANALYSIS
# =========================================================================

log_pipeline(strrep("=", 80))
log_pipeline("STEP 5: STATISTICAL ANALYSIS")
log_pipeline(strrep("=", 80))
log_pipeline("5A: DDM statistical analysis (contrasts, comparisons)...")

step5a_start <- Sys.time()

STAT_ANALYSIS_SCRIPT <- "scripts/02_statistical_analysis/02_ddm_analysis.R"
if (file.exists(STAT_ANALYSIS_SCRIPT)) {
  result_step5a <- tryCatch({
    source(STAT_ANALYSIS_SCRIPT)
    list(success = TRUE, message = "Statistical analysis completed")
  }, error = function(e) {
    log_pipeline("ERROR in Step 5A:", e$message, level = "ERROR")
    list(success = FALSE, message = e$message)
  })
} else {
  log_pipeline("  Skipping: Statistical analysis script not found", level = "WARN")
  result_step5a <- list(success = FALSE, message = "Script not found")
}

step5a_time <- as.numeric(difftime(Sys.time(), step5a_start, units = "mins"))
log_pipeline(sprintf("  Step 5A elapsed time: %.1f minutes", step5a_time))

if (result_step5a$success) {
  log_pipeline("  ✓ Step 5A complete")
} else {
  log_pipeline("  ⚠ Step 5A skipped")
}

log_pipeline("")

# =========================================================================
# STEP 6: VISUALIZATION
# =========================================================================

log_pipeline(strrep("=", 80))
log_pipeline("STEP 6: VISUALIZATION")
log_pipeline(strrep("=", 80))
log_pipeline("6A: Creating condition effects visualizations...")

step6a_start <- Sys.time()

VIZ_SCRIPT <- "scripts/02_statistical_analysis/create_results_visualizations.R"
if (file.exists(VIZ_SCRIPT)) {
  result_step6a <- tryCatch({
    source(VIZ_SCRIPT)
    list(success = TRUE, message = "Visualizations created")
  }, error = function(e) {
    log_pipeline("ERROR in Step 6A:", e$message, level = "ERROR")
    list(success = FALSE, message = e$message)
  })
} else {
  log_pipeline("  Skipping: Visualization script not found", level = "WARN")
  result_step6a <- list(success = FALSE, message = "Script not found")
}

step6a_time <- as.numeric(difftime(Sys.time(), step6a_start, units = "secs"))
log_pipeline(sprintf("  Step 6A elapsed time: %.1f seconds", step6a_time))

if (result_step6a$success) {
  log_pipeline("  ✓ Step 6A complete")
} else {
  log_pipeline("  ⚠ Step 6A skipped")
}

log_pipeline("")

# =========================================================================
# STEP 7: MANUSCRIPT GENERATION
# =========================================================================

log_pipeline(strrep("=", 80))
log_pipeline("STEP 7: MANUSCRIPT GENERATION")
log_pipeline(strrep("=", 80))
log_pipeline("7A: Generating manuscript report...")

step7a_start <- Sys.time()

MANUSCRIPT_SCRIPT <- "reports/chap3_ddm_results.qmd"
if (file.exists(MANUSCRIPT_SCRIPT)) {
  log_pipeline("  Manuscript source file found:", MANUSCRIPT_SCRIPT)
  log_pipeline("  To render, run: quarto render", MANUSCRIPT_SCRIPT)
  log_pipeline("  (Skipping automatic rendering in pipeline)")
  result_step7a <- list(success = TRUE, message = "Manuscript source ready")
} else {
  log_pipeline("  Skipping: Manuscript source not found", level = "WARN")
  result_step7a <- list(success = FALSE, message = "File not found")
}

step7a_time <- as.numeric(difftime(Sys.time(), step7a_start, units = "secs"))
log_pipeline(sprintf("  Step 7A elapsed time: %.1f seconds", step7a_time))

log_pipeline("")

# =========================================================================
# PIPELINE SUMMARY
# =========================================================================

PIPELINE_END <- Sys.time()
TOTAL_TIME <- as.numeric(difftime(PIPELINE_END, PIPELINE_START, units = "mins"))

log_pipeline(strrep("=", 80))
log_pipeline("COMPLETE PIPELINE SUMMARY")
log_pipeline(strrep("=", 80))
log_pipeline("Step 1A (DDM-only data):", ifelse(result_step1a$success, "✓ SUCCESS", "✗ FAILED"))
log_pipeline("Step 1B (DDM-pupil data):", ifelse(result_step1b$success, "✓ SUCCESS", "⚠ SKIPPED"))
log_pipeline("Step 2A (Pupil features):", ifelse(result_step2a$success, "✓ SUCCESS", "⚠ SKIPPED"))
log_pipeline("Step 2B (Pupil QC):", ifelse(result_step2b$success, "✓ SUCCESS", "⚠ SKIPPED"))
log_pipeline("Step 3A (RT analysis):", ifelse(result_step3a$success, "✓ SUCCESS", "⚠ SKIPPED"))
log_pipeline("Step 4A (Standard bias):", ifelse(result_step4a$success, "✓ SUCCESS", "✗ FAILED"))
log_pipeline("Step 4B (Primary model):", ifelse(result_step4b$success, "✓ SUCCESS", "✗ FAILED"))
log_pipeline("Step 5A (Statistical analysis):", ifelse(result_step5a$success, "✓ SUCCESS", "⚠ SKIPPED"))
log_pipeline("Step 6A (Visualization):", ifelse(result_step6a$success, "✓ SUCCESS", "⚠ SKIPPED"))
log_pipeline("Step 7A (Manuscript):", ifelse(result_step7a$success, "✓ SUCCESS", "⚠ SKIPPED"))
log_pipeline("")
log_pipeline("Total pipeline time:", round(TOTAL_TIME, 1), "minutes")
log_pipeline("End time:", format(PIPELINE_END, "%Y-%m-%d %H:%M:%S"))
log_pipeline(strrep("=", 80))
log_pipeline("")
log_pipeline("NEXT STEPS:")
log_pipeline("  1. Review log files in", LOG_DIR)
log_pipeline("  2. Check validation reports in", LOG_DIR)
log_pipeline("  3. Review model outputs in output/models/")
log_pipeline("  4. Review figures in output/figures/")
log_pipeline("  5. Render manuscript: quarto render reports/chap3_ddm_results.qmd")
log_pipeline("")

# Exit with appropriate code
critical_failures <- !result_step1a$success || !result_step4b$success
if (critical_failures) {
  log_pipeline("⚠ Pipeline completed with CRITICAL FAILURES", level = "ERROR")
  quit(status = 1)
} else {
  log_pipeline("✓ Pipeline completed successfully!")
}

