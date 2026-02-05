#!/usr/bin/env Rscript
# Post-process predicted_parameters_by_condition.csv to add metadata columns
# This adds model_name, rt_def, threshold, run_id to existing file
#
# Usage: Rscript scripts/postprocess_predicted_parameters_metadata.R [run_dir]
# Default: output/ddm_refits/runs/20260204_214842

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

# Get run directory from command line or use default
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 0) {
  run_dir <- args[1]
} else {
  # Use most recent run or default
  runs_base <- "output/ddm_refits/runs"
  if (dir.exists(runs_base)) {
    runs <- list.dirs(runs_base, full.names = FALSE, recursive = FALSE)
    if (length(runs) > 0) {
      run_dir <- file.path(runs_base, sort(runs, decreasing = TRUE)[1])
      cat("Using most recent run:", run_dir, "\n")
    } else {
      run_dir <- "output/ddm_refits/runs/20260204_214842"
      cat("Using default run:", run_dir, "\n")
    }
  } else {
    stop("Runs directory not found: ", runs_base)
  }
}

if (!dir.exists(run_dir)) {
  stop("Run directory not found: ", run_dir)
}

# Set up paths
tables_dir <- file.path(run_dir, "tables")
input_file <- file.path(tables_dir, "predicted_parameters_by_condition.csv")
output_file <- file.path(tables_dir, "predicted_parameters_by_condition.csv")

cat("================================================================================\n")
cat("POST-PROCESSING PREDICTED PARAMETERS METADATA\n")
cat("================================================================================\n")
cat("Timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Run directory:", run_dir, "\n")
cat("Input file:", input_file, "\n")
cat("================================================================================\n\n")

# Check if file exists
if (!file.exists(input_file)) {
  stop("Input file not found: ", input_file)
}

# Read existing file
df <- read_csv(input_file, show_col_types = FALSE)
cat("Loaded", nrow(df), "rows from", input_file, "\n")

# Check if metadata columns already exist and are complete
has_metadata <- "model_name" %in% names(df) && "rt_def" %in% names(df) && 
                "threshold" %in% names(df) && "run_id" %in% names(df)
has_na_threshold <- has_metadata && any(is.na(df$threshold))

if (has_metadata && !has_na_threshold) {
  cat("✓ Metadata columns already present and complete. No changes needed.\n")
  cat("  model_name:", unique(df$model_name), "\n")
  cat("  rt_def:", unique(df$rt_def), "\n")
  cat("  threshold:", unique(df$threshold), "\n")
  cat("  run_id:", unique(df$run_id), "\n")
} else {
  if (has_na_threshold) {
    cat("Metadata columns exist but threshold is NA. Updating...\n")
  } else {
    cat("Adding metadata columns...\n")
  }
  cat("Adding metadata columns...\n")
  
  # Extract run_id from directory name
  run_id_val <- basename(run_dir)
  
  # Determine metadata from run context
  # Check if we can infer from model files or use defaults
  models_dir <- file.path(run_dir, "models")
  model_files <- list.files(models_dir, pattern = "^additive__.*\\.rds$", full.names = FALSE)
  
  # Default values (based on typical primary model)
  model_name_val <- "additive"
  rt_def_val <- "probe_onset_locked"  # Primary model uses probe_onset_locked
  threshold_val <- 0.20  # CHOSEN_THRESHOLD default
  
  # Try to infer from model files
  if (length(model_files) > 0) {
    # Look for additive_probe model
    probe_models <- grep("probe_onset_locked", model_files, value = TRUE)
    if (length(probe_models) > 0) {
      # Extract threshold from filename (e.g., "additive__probe_onset_locked__thr0.20.rds" -> 0.20)
      filename <- probe_models[1]
      # Simple approach: extract everything after "thr" and before ".rds"
      if (grepl("thr", filename)) {
        # Extract part after "thr"
        after_thr <- sub(".*thr", "", filename)
        # Remove .rds extension
        thr_str <- sub("\\.rds$", "", after_thr)
        threshold_val <- as.numeric(thr_str)
        if (!is.na(threshold_val)) {
          cat("  Inferred threshold:", threshold_val, "from model file:", filename, "\n")
        } else {
          cat("  Could not parse threshold, using default 0.20\n")
        }
      } else {
        cat("  No 'thr' pattern found, using default 0.20\n")
      }
    }
  }
  
  # Add/update metadata columns
  if (has_metadata) {
    # Update existing columns
    df$model_name <- model_name_val
    df$rt_def <- rt_def_val
    df$threshold <- threshold_val
    df$run_id <- run_id_val
    # Reorder to put metadata first
    df <- df %>% select(model_name, rt_def, threshold, run_id, everything())
  } else {
    # Add new columns at the beginning
    df <- df %>%
      mutate(
        model_name = model_name_val,
        rt_def = rt_def_val,
        threshold = threshold_val,
        run_id = run_id_val,
        .before = 1  # Add at the beginning
      )
  }
  
  cat("  Added metadata:\n")
  cat("    model_name:", model_name_val, "\n")
  cat("    rt_def:", rt_def_val, "\n")
  cat("    threshold:", threshold_val, "\n")
  cat("    run_id:", run_id_val, "\n")
  
  # Write updated file
  write_csv(df, output_file)
  cat("\n✓ Saved updated file:", output_file, "\n")
  cat("  Rows:", nrow(df), "\n")
  cat("  Columns:", ncol(df), "\n")
}

# Print preview
cat("\nPreview (first 3 rows):\n")
print(head(df, 3))

cat("\n================================================================================\n")
cat("Post-processing complete.\n")
cat("================================================================================\n")
