#!/usr/bin/env Rscript
# ============================================================================
# CH3 Extension Pipeline Runner
# ============================================================================
# Run this script to:
# 1. Regenerate waveform summaries from extended flat files
# 2. Run window selection diagnostics
# 3. Run STOP/GO checks
# ============================================================================

suppressPackageStartupMessages({
  library(here)
})

cat("================================================================================\n")
cat("CH3 EXTENSION PIPELINE\n")
cat("================================================================================\n")
cat("This script will:\n")
cat("  1. Regenerate waveform summaries (using make_quick_share_v7.R)\n")
cat("  2. Run window selection diagnostics (ch3_window_selection_v2.R)\n")
cat("  3. Run STOP/GO checks (ch3_stopgo_checks.R)\n\n")

# Set paths
REPO_ROOT <- here::here()
SCRIPTS_DIR <- file.path(REPO_ROOT, "scripts")
LATEST_BUILD <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/build_20251225_154443"

cat("Configuration:\n")
cat("  Repo root:", REPO_ROOT, "\n")
cat("  Latest MATLAB build:", LATEST_BUILD, "\n\n")

# Check if build directory exists
if (!dir.exists(LATEST_BUILD)) {
  stop("ERROR: Build directory does not exist: ", LATEST_BUILD, "\n",
       "Please update LATEST_BUILD in this script to point to the correct build directory.")
}

cat("================================================================================\n")
cat("STEP 1: Regenerate Waveform Summaries\n")
cat("================================================================================\n")
cat("NOTE: This will run make_quick_share_v7.R which regenerates all outputs.\n")
cat("      Make sure config/data_paths.yaml points to the correct build directory.\n\n")

response <- readline(prompt = "Continue with waveform regeneration? (yes/no): ")
if (tolower(response) %in% c("yes", "y")) {
  cat("\nRunning make_quick_share_v7.R...\n")
  source(file.path(SCRIPTS_DIR, "make_quick_share_v7.R"))
  cat("\n✓ Waveform regeneration complete\n\n")
} else {
  cat("\n⏭ Skipping waveform regeneration (assumes already done)\n\n")
}

cat("================================================================================\n")
cat("STEP 2: Window Selection Diagnostics\n")
cat("================================================================================\n")

source(file.path(SCRIPTS_DIR, "ch3_window_selection_v2.R"))
cat("\n✓ Window selection complete\n\n")

cat("================================================================================\n")
cat("STEP 3: STOP/GO Checks\n")
cat("================================================================================\n")

source(file.path(SCRIPTS_DIR, "ch3_stopgo_checks.R"))
cat("\n✓ STOP/GO checks complete\n\n")

cat("================================================================================\n")
cat("PIPELINE COMPLETE\n")
cat("================================================================================\n")
cat("Check outputs in:\n")
cat("  - quick_share_v7/analysis/pupil_waveforms_condition_mean.csv\n")
cat("  - quick_share_v7/qc/ch3_time_to_peak_summary.csv\n")
cat("  - quick_share_v7/qc/ch3_window_coverage.csv\n")
cat("  - quick_share_v7/qc/STOP_GO_ch3_extension.csv\n")
cat("  - quick_share_v7/figs/ch3_waveform_*.png\n\n")

