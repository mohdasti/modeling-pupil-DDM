#!/usr/bin/env Rscript
# Quick fix script to generate convergence_summary.csv from existing run data
# Usage: Rscript scripts/fix_convergence_summary.R [run_id]
# If run_id not provided, uses the most recent run

library(readr)
library(dplyr)

# Get run_id from command line or use most recent
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 0) {
  run_id <- args[1]
} else {
  # Find most recent run
  runs_dir <- "output/ddm_refits/runs"
  if (!dir.exists(runs_dir)) {
    stop("Runs directory not found: ", runs_dir)
  }
  runs <- list.dirs(runs_dir, full.names = FALSE, recursive = FALSE)
  if (length(runs) == 0) {
    stop("No runs found in ", runs_dir)
  }
  run_id <- sort(runs, decreasing = TRUE)[1]
  cat("Using most recent run:", run_id, "\n")
}

# Set up paths
RUN_INDEX_FILE <- file.path(runs_dir, run_id, "run_index.csv")
CONVERGENCE_FILE <- file.path(runs_dir, run_id, "summaries", "ddm_convergence_comparison.csv")
TABLES_DIR <- file.path(runs_dir, run_id, "tables")
OUTPUT_FILE <- file.path(TABLES_DIR, "convergence_summary.csv")

# Check files exist
if (!file.exists(RUN_INDEX_FILE)) {
  stop("run_index.csv not found: ", RUN_INDEX_FILE)
}
if (!file.exists(CONVERGENCE_FILE)) {
  stop("convergence comparison file not found: ", CONVERGENCE_FILE)
}

# Read data
cat("Reading run_index.csv...\n")
run_index_df <- read_csv(RUN_INDEX_FILE, show_col_types = FALSE)

cat("Reading convergence comparison...\n")
convergence_all <- read_csv(CONVERGENCE_FILE, show_col_types = FALSE)

# Get CHOSEN_THRESHOLD from run_index (most common threshold)
chosen_threshold <- run_index_df %>%
  filter(model_name %in% c("baseline", "additive")) %>%
  pull(threshold) %>%
  as.numeric() %>%
  median(na.rm = TRUE)

cat("Chosen threshold:", chosen_threshold, "\n")

# Merge convergence data with run_index
cat("Merging data...\n")
# Use run_index_df directly since it already has all the needed columns
convergence_summary_qmd <- run_index_df %>%
  filter(model_name %in% c("baseline", "additive")) %>%
  select(model_name, rt_def = rt_def, threshold, N_trials, N_subjects,
         max_rhat, min_bulk_ess, divergences, output_rds_path) %>%
  # Ensure threshold is numeric
  mutate(threshold = as.numeric(threshold))

# Ensure tables directory exists
if (!dir.exists(TABLES_DIR)) {
  dir.create(TABLES_DIR, recursive = TRUE)
  cat("Created tables directory:", TABLES_DIR, "\n")
}

# Write output
cat("Writing convergence_summary.csv...\n")
write_csv(convergence_summary_qmd, OUTPUT_FILE)
cat("Success! Saved to:", OUTPUT_FILE, "\n")
cat("\nPreview:\n")
print(convergence_summary_qmd)
