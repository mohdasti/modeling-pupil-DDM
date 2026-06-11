#!/usr/bin/env Rscript
# =========================================================================
# MANUAL SENSITIVITY EXPORT
# =========================================================================
# This script manually runs the sensitivity export section that failed
# due to a column name mismatch. Run this after ddm_refit_with_new_threshold.R
# has completed the model fitting but before the export section.
# =========================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

# Load logging functions if available
if (file.exists("R/utils/logging_validation.R")) {
  source("R/utils/logging_validation.R")
} else {
  # Fallback logging functions
  log_info <- function(msg) cat("[INFO]", msg, "\n")
  log_warn <- function(msg) cat("[WARN]", msg, "\n")
  log_error <- function(msg) cat("[ERROR]", msg, "\n")
}

# Get run directory from command line or use most recent
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 0) {
  run_dir <- args[1]
} else {
  # Use most recent run
  runs_base <- "output/ddm_refits/runs"
  if (dir.exists(runs_base)) {
    runs <- list.dirs(runs_base, full.names = FALSE, recursive = FALSE)
    if (length(runs) > 0) {
      run_dir <- file.path(runs_base, sort(runs, decreasing = TRUE)[1])
      log_info(paste("Using most recent run:", run_dir))
    } else {
      stop("No runs found in ", runs_base)
    }
  } else {
    stop("Runs directory not found: ", runs_base)
  }
}

# Set up directory paths
TABLES_DIR <- file.path(run_dir, "tables")
SUMMARIES_DIR <- file.path(run_dir, "summaries")
RESULTS_DIR <- "output/results"

# Check if sensitivity_results exists in the environment
# If not, try to load it from a saved RDS file
if (!exists("sensitivity_results") || length(sensitivity_results) == 0) {
  log_warn("sensitivity_results not found in environment. Checking for saved files...")
  
  # Try to find sensitivity results in summaries directory
  sensitivity_rds <- file.path(SUMMARIES_DIR, "sensitivity_results.rds")
  if (file.exists(sensitivity_rds)) {
    sensitivity_results <- readRDS(sensitivity_rds)
    log_info("Loaded sensitivity_results from RDS file")
  } else {
    stop("sensitivity_results not found. Please ensure models have been fitted.")
  }
}

# Check if sensitivity_data_df exists or needs to be loaded
if (!exists("sensitivity_data_df") || nrow(sensitivity_data_df) == 0) {
  log_warn("sensitivity_data_df not found. Loading from CSV...")
  sensitivity_data_file <- file.path(TABLES_DIR, "ddm_sensitivity_thresholds.csv")
  if (file.exists(sensitivity_data_file)) {
    sensitivity_data_df <- read_csv(sensitivity_data_file, show_col_types = FALSE)
    log_info("Loaded sensitivity_data_df from CSV")
  } else {
    log_warn("sensitivity_data_df CSV not found. Will use fallback.")
    sensitivity_data_df <- data.frame()
  }
}

# =========================================================================
# EXPORT SENSITIVITY RESULTS
# =========================================================================

log_info("Combining sensitivity results...")

# Combine sensitivity results (with defensive check)
if (length(sensitivity_results) > 0) {
  sensitivity_df <- tryCatch({
    bind_rows(sensitivity_results)
  }, error = function(e) {
    log_error(paste("Failed to bind sensitivity_results:", e$message))
    log_error("sensitivity_results structure:")
    for (i in seq_along(sensitivity_results)) {
      log_error(paste("  Element", i, "columns:", paste(names(sensitivity_results[[i]]), collapse = ", ")))
    }
    return(data.frame())  # Return empty data.frame
  })
  
  if (nrow(sensitivity_df) > 0) {
    # Merge data summary (n_trials, min/max RT) with model results (LOOIC, parameters)
    # Merge by threshold to combine pre-fit data summary with post-fit model results
    if (exists("sensitivity_data_df") && nrow(sensitivity_data_df) > 0) {
      # Filter for cue_locked RT type (sensitivity analysis uses cue_locked)
      # Use correct column names: min_rt (not min_rt_cue), and use all_of() to avoid tidyselect warnings
      cols_to_select <- c("threshold", "n_trials", "n_subjects", "min_rt", "median_rt")
      available_cols <- intersect(cols_to_select, names(sensitivity_data_df))
      
      log_info(paste("Available columns in sensitivity_data_df:", paste(available_cols, collapse = ", ")))
      
      sensitivity_export <- sensitivity_data_df %>%
        filter(rt_type == "cue_locked") %>%
        select(all_of(available_cols)) %>%
        left_join(
          sensitivity_df %>% select(all_of(c("threshold", "looic", "looic_se"))),
          by = "threshold"
        ) %>%
        arrange(threshold)
    } else {
      # Fallback: use model results only
      log_warn("Using fallback: model results only (no data summary)")
      sensitivity_export <- sensitivity_df %>%
        select(all_of(c("threshold", "n_trials", "looic", "looic_se"))) %>%
        arrange(threshold)
    }
    
    # Update the TABLES_DIR file (used by QMD) with merged data + LOOIC values
    sensitivity_file_qmd <- file.path(TABLES_DIR, "ddm_sensitivity_thresholds.csv")
    write_csv(sensitivity_export, sensitivity_file_qmd)
    log_info(paste("✓ Saved QMD table (with LOOIC):", sensitivity_file_qmd))
    
    # Also save full results to SUMMARIES_DIR
    sensitivity_file <- file.path(SUMMARIES_DIR, "ddm_sensitivity_thresholds.csv")
    write_csv(sensitivity_df, sensitivity_file)
    log_info(paste("✓ Saved full results:", sensitivity_file))
    
    # Also save to legacy location
    legacy_file <- file.path(RESULTS_DIR, "ddm_sensitivity_thresholds.csv")
    if (!dir.exists(RESULTS_DIR)) dir.create(RESULTS_DIR, recursive = TRUE, showWarnings = FALSE)
    write_csv(sensitivity_df, legacy_file)
    log_info(paste("✓ Saved to legacy location:", legacy_file))
    
    # Print summary
    cat("\n=== Sensitivity Export Summary ===\n")
    print(sensitivity_export)
    cat("\n✓ Export completed successfully!\n")
    
  } else {
    log_warn("sensitivity_df is empty; skipping CSV write")
  }
} else {
  log_warn("sensitivity_results is empty; skipping CSV write")
}
