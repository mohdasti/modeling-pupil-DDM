#!/usr/bin/env Rscript
# =========================================================================
# MASTER PIPELINE EXECUTION SCRIPT
# =========================================================================
# Runs the complete analysis pipeline from scratch with:
# - Latest data file (bap_trial_data_grip.csv)
# - Standardized priors
# - Standardized RT filtering (0.2-3.0s)
# - All improvements from audit
# =========================================================================

cat("================================================================================\n")
cat("BAP DDM ANALYSIS - FULL PIPELINE EXECUTION\n")
cat("================================================================================\n")
cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Running with:\n")
cat("  - Latest data: bap_trial_data_grip.csv\n")
cat("  - Standardized priors (literature-justified)\n")
cat("  - RT filtering: 0.2-3.0s\n")
cat("  - Standard trials included\n")
cat("================================================================================\n\n")

# Record pipeline start time for duration tracking
pipeline_start_time <- Sys.time()

# Set options
options(warn = 1)  # Show warnings
set.seed(12345)    # For reproducibility

# =========================================================================
# STEP 0: VERIFY DATA FILE
# =========================================================================

cat("\n[STEP 0] Verifying data file...\n")

latest_data_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/bap_trial_data_grip.csv"

if (!file.exists(latest_data_file)) {
    stop("ERROR: Latest data file not found at: ", latest_data_file, "\n",
         "Please verify the file path.")
}

cat("✅ Found latest data file:", latest_data_file, "\n")
cat("   File size:", file.size(latest_data_file) / 1024 / 1024, "MB\n")

# Load and verify
library(readr)
library(dplyr)

data_check <- read_csv(latest_data_file, show_col_types = FALSE, n_max = 10)
cat("✅ Data file readable\n")
cat("   Columns:", length(names(data_check)), "\n")
cat("   Sample columns:", paste(head(names(data_check), 5), collapse = ", "), "\n\n")

# =========================================================================
# STEP 1: DATA PREPROCESSING
# =========================================================================

cat("\n[STEP 1] DATA PREPROCESSING\n")
cat("----------------------------------------------------------------------\n")

# Note: Data preprocessing might already be done
# If analysis-ready files exist, we can skip this step
analysis_ready_dir <- "data/analysis_ready"
if (!dir.exists(analysis_ready_dir)) {
    dir.create(analysis_ready_dir, recursive = TRUE)
}

# Check if preprocessing is needed
needs_preprocessing <- !file.exists(file.path(analysis_ready_dir, "bap_ddm_ready.csv"))

if (needs_preprocessing) {
    cat("Running data preprocessing...\n")
    cat("NOTE: If preprocessing scripts need the data file copied to a different location,\n")
    cat("      you may need to update paths in preprocessing scripts.\n\n")
    
    # Option 1: Run the merger script (if pupillometry data is available)
    if (file.exists("01_data_preprocessing/r/Create merged flat file.R")) {
        cat("Running: Create merged flat file.R\n")
        tryCatch({
            source("01_data_preprocessing/r/Create merged flat file.R")
            cat("✅ Data preprocessing complete\n\n")
        }, error = function(e) {
            cat("⚠️  Preprocessing encountered issues (may be expected if pupillometry not ready):\n")
            cat("   ", e$message, "\n\n")
        })
    }
} else {
    cat("✅ Preprocessing outputs already exist, skipping...\n\n")
}

# =========================================================================
# STEP 2: PUPILLOMETRY FEATURE EXTRACTION
# =========================================================================

cat("\n[STEP 2] PUPILLOMETRY FEATURE EXTRACTION\n")
cat("----------------------------------------------------------------------\n")

# Check if pupil features already exist
pupil_features_file <- file.path(analysis_ready_dir, "bap_clean_pupil.csv")

if (!file.exists(pupil_features_file)) {
    cat("Running pupillometry feature extraction...\n")
    
    # Option 1: State/trait decomposition
    if (file.exists("scripts/utilities/state_trait_decomposition.R")) {
        tryCatch({
            source("scripts/utilities/state_trait_decomposition.R")
            cat("✅ Pupillometry features extracted\n\n")
        }, error = function(e) {
            cat("⚠️  Pupil feature extraction encountered issues:\n")
            cat("   ", e$message, "\n\n")
        })
    }
} else {
    cat("✅ Pupillometry features already exist, skipping...\n\n")
}

# =========================================================================
# STEP 3: DDM MODEL FITTING (MAIN ANALYSIS)
# =========================================================================

cat("\n[STEP 3] DDM MODEL FITTING\n")
cat("----------------------------------------------------------------------\n")
cat("Fitting DDM models with standardized priors...\n\n")

# Main DDM analysis
if (file.exists("scripts/02_statistical_analysis/02_ddm_analysis.R")) {
    cat("Running: 02_ddm_analysis.R\n")
    cat("[", format(Sys.time(), "%H:%M:%S"), "] Starting main DDM analysis...\n")
    start_time_ddm <- Sys.time()
    tryCatch({
        source("scripts/02_statistical_analysis/02_ddm_analysis.R")
        elapsed_ddm <- difftime(Sys.time(), start_time_ddm, units = "mins")
        cat("[", format(Sys.time(), "%H:%M:%S"), "] ✅ Main DDM analysis complete (took", round(elapsed_ddm, 1), "minutes)\n\n")
    }, error = function(e) {
        elapsed_ddm <- difftime(Sys.time(), start_time_ddm, units = "mins")
        cat("[", format(Sys.time(), "%H:%M:%S"), "] ❌ ERROR in main DDM analysis (after", round(elapsed_ddm, 1), "minutes):\n")
        cat("   ", e$message, "\n")
        stop("Pipeline stopped due to error in DDM analysis")
    })
} else {
    stop("ERROR: Main DDM analysis script not found!")
}

# =========================================================================
# STEP 4: ADDITIONAL DDM ANALYSES
# =========================================================================

cat("\n[STEP 4] ADDITIONAL DDM ANALYSES\n")
cat("----------------------------------------------------------------------\n")

# Tonic alpha analysis
if (file.exists("scripts/tonic_alpha_analysis.R")) {
    cat("[", format(Sys.time(), "%H:%M:%S"), "] Running: tonic_alpha_analysis.R\n")
    start_time <- Sys.time()
    tryCatch({
        source("scripts/tonic_alpha_analysis.R")
        elapsed <- difftime(Sys.time(), start_time, units = "mins")
        cat("[", format(Sys.time(), "%H:%M:%S"), "] ✅ Tonic alpha analysis complete (took", round(elapsed, 1), "minutes)\n\n")
    }, error = function(e) {
        elapsed <- difftime(Sys.time(), start_time, units = "mins")
        cat("[", format(Sys.time(), "%H:%M:%S"), "] ⚠️  Tonic alpha analysis encountered issues (after", round(elapsed, 1), "minutes):\n")
        cat("   ", e$message, "\n\n")
    })
}

# History modeling
if (file.exists("scripts/history_modeling.R")) {
    cat("[", format(Sys.time(), "%H:%M:%S"), "] Running: history_modeling.R\n")
    start_time <- Sys.time()
    tryCatch({
        source("scripts/history_modeling.R")
        elapsed <- difftime(Sys.time(), start_time, units = "mins")
        cat("[", format(Sys.time(), "%H:%M:%S"), "] ✅ History modeling complete (took", round(elapsed, 1), "minutes)\n\n")
    }, error = function(e) {
        elapsed <- difftime(Sys.time(), start_time, units = "mins")
        cat("[", format(Sys.time(), "%H:%M:%S"), "] ⚠️  History modeling encountered issues (after", round(elapsed, 1), "minutes):\n")
        cat("   ", e$message, "\n\n")
    })
}

# State/trait models (if data available)
if (file.exists("scripts/advanced/fit_state_trait_ddm_models.R")) {
    cat("[", format(Sys.time(), "%H:%M:%S"), "] Running: fit_state_trait_ddm_models.R\n")
    start_time <- Sys.time()
    tryCatch({
        source("scripts/advanced/fit_state_trait_ddm_models.R")
        elapsed <- difftime(Sys.time(), start_time, units = "mins")
        cat("[", format(Sys.time(), "%H:%M:%S"), "] ✅ State/trait models complete (took", round(elapsed, 1), "minutes)\n\n")
    }, error = function(e) {
        elapsed <- difftime(Sys.time(), start_time, units = "mins")
        cat("[", format(Sys.time(), "%H:%M:%S"), "] ⚠️  State/trait models encountered issues (after", round(elapsed, 1), "minutes):\n")
        cat("   ", e$message, "\n\n")
    })
}

# =========================================================================
# STEP 5: QUALITY CONTROL AND SENSITIVITY CHECKS
# =========================================================================

cat("\n[STEP 5] QUALITY CONTROL\n")
cat("----------------------------------------------------------------------\n")

# Lapse sensitivity check
if (file.exists("scripts/qc/lapse_sensitivity_check.R")) {
    cat("[", format(Sys.time(), "%H:%M:%S"), "] Running: lapse_sensitivity_check.R\n")
    start_time <- Sys.time()
    tryCatch({
        source("scripts/qc/lapse_sensitivity_check.R")
        elapsed <- difftime(Sys.time(), start_time, units = "mins")
        cat("[", format(Sys.time(), "%H:%M:%S"), "] ✅ Lapse sensitivity check complete (took", round(elapsed, 1), "minutes)\n\n")
    }, error = function(e) {
        elapsed <- difftime(Sys.time(), start_time, units = "mins")
        cat("[", format(Sys.time(), "%H:%M:%S"), "] ⚠️  Lapse sensitivity check encountered issues (after", round(elapsed, 1), "minutes):\n")
        cat("   ", e$message, "\n\n")
    })
}

# =========================================================================
# STEP 6: SUMMARY AND VERIFICATION
# =========================================================================

cat("\n[STEP 6] VERIFICATION AND SUMMARY\n")
cat("----------------------------------------------------------------------\n")

# Check outputs
output_dir <- "output/models"
if (dir.exists(output_dir)) {
    model_files <- list.files(output_dir, pattern = "\\.rds$", full.names = TRUE)
    cat("Generated model files:", length(model_files), "\n")
    if (length(model_files) > 0) {
        cat("Sample files:\n")
        for (f in head(model_files, 5)) {
            cat("  -", basename(f), "\n")
        }
    }
}

pipeline_end_time <- Sys.time()
pipeline_duration <- difftime(pipeline_end_time, pipeline_start_time, units = "mins")

cat("\n================================================================================\n")
cat("✅ PIPELINE EXECUTION COMPLETE\n")
cat("================================================================================\n")
cat("Start time:", format(pipeline_start_time, "%Y-%m-%d %H:%M:%S"), "\n")
cat("End time:  ", format(pipeline_end_time, "%Y-%m-%d %H:%M:%S"), "\n")
cat("Duration:  ", round(pipeline_duration, 1), "minutes\n")
cat("\nCheck output/ directory for results\n")
cat("Check output/models/ for fitted models\n")
cat("Check output/figures/ for visualizations\n")
cat("================================================================================\n")

