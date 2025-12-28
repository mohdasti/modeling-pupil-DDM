#!/usr/bin/env Rscript
# ============================================================================
# Regenerate CH3 Features with W1.3 Window
# ============================================================================
# This script regenerates the quick_share_v7 dataset with the new 
# cog_auc_w1p3 and cog_mean_w1p3 features for Chapter 3 DDM analysis.
#
# Run this in RStudio:
#   source("scripts/REGENERATE_CH3_FEATURES.R")
# ============================================================================

cat("============================================================================\n")
cat("Regenerating CH3 Features with Early Window (W1.3)\n")
cat("============================================================================\n")
cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Check if we're in the repo root
if (!file.exists("scripts/make_quick_share_v7.R")) {
  stop("ERROR: Please run this script from the repository root directory.\n",
       "Current working directory: ", getwd(), "\n",
       "Expected to find: scripts/make_quick_share_v7.R")
}

cat("Current working directory:", getwd(), "\n")
cat("✓ Repository root detected\n\n")

# Check if config file exists
config_file <- "config/data_paths.yaml"
if (!file.exists(config_file)) {
  warning("WARNING: config/data_paths.yaml not found.\n",
          "The pipeline may fail if paths are not configured correctly.\n")
} else {
  cat("✓ Config file found: ", config_file, "\n")
}

cat("\n")
cat("STEP 1: Running make_quick_share_v7.R\n")
cat("-------------------------------------\n")
cat("This will:\n")
cat("  1. Process flat pupil files from MATLAB output\n")
cat("  2. Compute AUC features including:\n")
cat("     - total_auc (legacy)\n")
cat("     - cog_auc (legacy)\n")
cat("     - cog_auc_w3 (target+0.3 to target+3.3)\n")
cat("     - cog_auc_respwin (target+0.3 to Resp1ET)\n")
cat("     - cog_auc_w1p3 (target+0.3 to target+1.3) [NEW]\n")
cat("     - cog_mean_w1p3 (mean pupil in W1.3 window) [NEW]\n")
cat("  3. Merge with behavioral data\n")
cat("  4. Generate analysis-ready datasets (ch2_triallevel.csv, ch3_triallevel.csv)\n")
cat("\n")
cat("This may take several minutes depending on dataset size...\n")
cat("\n")

# Source the main pipeline script
cat("Running make_quick_share_v7.R...\n")
cat("----------------------------------------------------------------------------\n")

source("scripts/make_quick_share_v7.R", local = TRUE)

cat("\n")
cat("----------------------------------------------------------------------------\n")
cat("Pipeline completed!\n\n")

# Verify the new columns exist
cat("STEP 2: Verifying new features\n")
cat("-------------------------------------\n")

ch3_file <- "quick_share_v7/analysis_ready/ch3_triallevel.csv"
if (file.exists(ch3_file)) {
  cat("Checking ch3_triallevel.csv for new features...\n")
  ch3_data <- readr::read_csv(ch3_file, n_max = 100, show_col_types = FALSE)
  
  required_cols <- c("cog_auc_w1p3", "cog_mean_w1p3")
  missing_cols <- setdiff(required_cols, names(ch3_data))
  
  if (length(missing_cols) == 0) {
    cat("✓ All new features found:\n")
    for (col in required_cols) {
      n_non_na <- sum(!is.na(ch3_data[[col]]))
      n_total <- nrow(ch3_data)
      pct <- 100 * n_non_na / n_total
      cat("  - ", col, ": ", n_non_na, "/", n_total, " non-NA (", 
          sprintf("%.1f", pct), "%)\n", sep = "")
    }
  } else {
    warning("WARNING: Missing columns: ", paste(missing_cols, collapse = ", "), "\n",
            "The pipeline may not have run successfully.\n")
  }
} else {
  warning("WARNING: ch3_triallevel.csv not found at: ", ch3_file, "\n")
}

merged_file <- "quick_share_v7/merged/BAP_triallevel_merged_v4.csv"
if (file.exists(merged_file)) {
  cat("\nChecking merged_v4.csv for new features...\n")
  merged_data <- readr::read_csv(merged_file, n_max = 100, show_col_types = FALSE)
  
  required_cols <- c("cog_auc_w1p3", "cog_mean_w1p3")
  missing_cols <- setdiff(required_cols, names(merged_data))
  
  if (length(missing_cols) == 0) {
    cat("✓ All new features found in merged_v4.csv\n")
  } else {
    warning("WARNING: Missing columns in merged_v4.csv: ", 
            paste(missing_cols, collapse = ", "), "\n")
  }
}

cat("\n")
cat("============================================================================\n")
cat("Next Steps:\n")
cat("============================================================================\n")
cat("1. Run window selection diagnostics:\n")
cat("   source(\"scripts/ch3_window_selection_v3.R\")\n\n")
cat("2. After reviewing QC outputs, create STOP/GO checks and decision memo\n")
cat("3. Update your Methods section using the decision memo\n")
cat("\n")
cat("New QC outputs will be in: quick_share_v7/qc/ch3_extension_v3/\n")
cat("============================================================================\n")

