#!/usr/bin/env Rscript
# ============================================================================
# Master Script: Run Complete AUC Feature Extraction Pipeline
# ============================================================================
# Runs all scripts in order to compute AUC features and update analysis datasets
# ============================================================================

suppressPackageStartupMessages({
  library(here)
})

cat("=== RUNNING AUC FEATURE EXTRACTION PIPELINE ===\n\n")

REPO_ROOT <- here::here()

# Step 1: Compute AUC features from flat files
cat("STEP 1: Computing AUC features from flat files...\n")
cat("-----------------------------------------------\n")
system2("Rscript", 
        file.path(REPO_ROOT, "scripts", "compute_auc_features_from_flats.R"),
        stdout = "", stderr = "")

# Step 2: Update Ch2/Ch3 analysis-ready datasets
cat("\nSTEP 2: Updating Ch2/Ch3 analysis-ready datasets...\n")
cat("----------------------------------------------------\n")
system2("Rscript",
        file.path(REPO_ROOT, "scripts", "update_ch2_ch3_with_auc.R"),
        stdout = "", stderr = "")

# Step 3: Generate waveform summaries (optional - can be slow)
cat("\nSTEP 3: Generating waveform summaries...\n")
cat("-----------------------------------------\n")
cat("NOTE: This step processes all flat files and may take 10-30 minutes.\n")
cat("      To run it, uncomment the next line or run separately:\n")
cat("      Rscript scripts/generate_waveform_summaries.R\n\n")

# Uncomment to run waveform generation:
# system2("Rscript",
#         file.path(REPO_ROOT, "scripts", "generate_waveform_summaries.R"),
#         stdout = "", stderr = "")

cat("\n=== PIPELINE COMPLETE ===\n")
cat("\nOutputs are in: quick_share_v5/\n")
cat("  - merged/BAP_triallevel_merged_v3.csv\n")
cat("  - analysis/ch2_analysis_ready.csv\n")
cat("  - analysis/ch3_ddm_ready.csv\n")
cat("  - analysis/pupil_auc_trial_level.csv\n")
cat("  - qc/qc_event_time_ranges.csv\n")
cat("  - qc/qc_auc_missingness_by_condition.csv\n")
cat("  - figures/auc_distributions.png\n")
cat("  - figures/gate_pass_rates_overview.png\n")

