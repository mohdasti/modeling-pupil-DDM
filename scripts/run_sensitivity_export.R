# =========================================================================
# QUICK SENSITIVITY EXPORT FIX
# =========================================================================
# Run this code directly in your R console after ddm_refit_with_new_threshold.R
# has completed the model fitting but before the export section failed.
# 
# This assumes you're still in the same R session where the script ran.
# =========================================================================

# Check if required objects exist
if (!exists("sensitivity_results")) {
  stop("sensitivity_results not found. Make sure you're in the same R session where the script ran.")
}

if (!exists("sensitivity_data_df")) {
  stop("sensitivity_data_df not found. Make sure you're in the same R session where the script ran.")
}

if (!exists("TABLES_DIR")) {
  # Try to infer from most recent run
  runs_base <- "output/ddm_refits/runs"
  if (dir.exists(runs_base)) {
    runs <- list.dirs(runs_base, full.names = FALSE, recursive = FALSE)
    if (length(runs) > 0) {
      run_dir <- file.path(runs_base, sort(runs, decreasing = TRUE)[1])
      TABLES_DIR <- file.path(run_dir, "tables")
      SUMMARIES_DIR <- file.path(run_dir, "summaries")
      RESULTS_DIR <- "output/results"
      cat("Using run directory:", run_dir, "\n")
    } else {
      stop("No runs found. Please set TABLES_DIR, SUMMARIES_DIR, and RESULTS_DIR manually.")
    }
  } else {
    stop("Runs directory not found. Please set TABLES_DIR, SUMMARIES_DIR, and RESULTS_DIR manually.")
  }
}

# Combine sensitivity results (with defensive check)
if (length(sensitivity_results) > 0) {
  sensitivity_df <- tryCatch({
    bind_rows(sensitivity_results)
  }, error = function(e) {
    cat("ERROR: Failed to bind sensitivity_results:", e$message, "\n")
    cat("sensitivity_results structure:\n")
    for (i in seq_along(sensitivity_results)) {
      cat("  Element", i, "columns:", paste(names(sensitivity_results[[i]]), collapse = ", "), "\n")
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
      
      cat("Available columns:", paste(available_cols, collapse = ", "), "\n")
      
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
      cat("WARNING: Using fallback - model results only (no data summary)\n")
      sensitivity_export <- sensitivity_df %>%
        select(all_of(c("threshold", "n_trials", "looic", "looic_se"))) %>%
        arrange(threshold)
    }
    
    # Update the TABLES_DIR file (used by QMD) with merged data + LOOIC values
    sensitivity_file_qmd <- file.path(TABLES_DIR, "ddm_sensitivity_thresholds.csv")
    write_csv(sensitivity_export, sensitivity_file_qmd)
    cat("✓ Saved QMD table (with LOOIC):", sensitivity_file_qmd, "\n")
    
    # Also save full results to SUMMARIES_DIR
    sensitivity_file <- file.path(SUMMARIES_DIR, "ddm_sensitivity_thresholds.csv")
    write_csv(sensitivity_df, sensitivity_file)
    cat("✓ Saved full results:", sensitivity_file, "\n")
    
    # Also save to legacy location
    if (!dir.exists(RESULTS_DIR)) dir.create(RESULTS_DIR, recursive = TRUE, showWarnings = FALSE)
    write_csv(sensitivity_df, file.path(RESULTS_DIR, "ddm_sensitivity_thresholds.csv"))
    cat("✓ Saved to legacy location\n")
    
    # Print summary
    cat("\n=== Sensitivity Export Summary ===\n")
    print(sensitivity_export)
    cat("\n✓ Export completed successfully!\n")
    
  } else {
    cat("WARNING: sensitivity_df is empty; skipping CSV write\n")
  }
} else {
  cat("WARNING: sensitivity_results is empty; skipping CSV write\n")
}
