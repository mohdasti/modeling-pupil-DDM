#!/usr/bin/env Rscript
# Quick pre-flight check before running ddm_refit_with_new_threshold.R

cat("================================================================================\n")
cat("PRE-FLIGHT CHECK FOR DDM REFITTING SCRIPT\n")
cat("================================================================================\n\n")

# 1. Check working directory
cat("1. Working directory:\n")
cat("   ", getwd(), "\n")
if (!file.exists("scripts/ddm_refit_with_new_threshold.R")) {
  cat("   ✗ ERROR: scripts/ddm_refit_with_new_threshold.R not found!\n")
  cat("   → Make sure you're in the project root directory\n")
  stop("Wrong working directory")
} else {
  cat("   ✓ Script found\n")
}

# 2. Check required packages
cat("\n2. Required R packages:\n")
required_packages <- c("brms", "dplyr", "readr", "tidyr", "ggplot2", "bayesplot", "cmdstanr")
missing <- c()
for (pkg in required_packages) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    version <- tryCatch(as.character(packageVersion(pkg)), error = function(e) "unknown")
    cat("   ✓", pkg, "(", version, ")\n")
  } else {
    cat("   ✗", pkg, "(NOT INSTALLED)\n")
    missing <- c(missing, pkg)
  }
}

if (length(missing) > 0) {
  cat("\n   ERROR: Missing packages:", paste(missing, collapse = ", "), "\n")
  cat("   Install with:\n")
  cat("   install.packages(c(", paste0('"', missing, '"', collapse = ", "), "))\n")
  if ("cmdstanr" %in% missing) {
    cat("   For cmdstanr, also run: cmdstanr::install_cmdstan()\n")
  }
  stop("Missing required packages")
}

# 3. Check input data file
cat("\n3. Input data file:\n")
input_file <- "output/rt_threshold_analysis/ddm_ready_data_unthresholded.csv"
if (file.exists(input_file)) {
  file_info <- file.info(input_file)
  cat("   ✓ Found:", input_file, "\n")
  cat("   Size:", round(file_info$size / 1024 / 1024, 2), "MB\n")
  cat("   Modified:", format(file_info$mtime, "%Y-%m-%d %H:%M:%S"), "\n")
  
  # Check required columns
  cat("\n   Checking required columns...\n")
  df_sample <- readr::read_csv(input_file, n_max = 10, show_col_types = FALSE)
  required_cols <- c("subject_id", "task", "effort_condition", "difficulty_level", 
                     "is_standard", "choice_binary", "rt_cue_locked", "rt_probe_onset_locked")
  missing_cols <- setdiff(required_cols, names(df_sample))
  if (length(missing_cols) > 0) {
    cat("   ✗ Missing columns:", paste(missing_cols, collapse = ", "), "\n")
    stop("Missing required columns")
  } else {
    cat("   ✓ All required columns present\n")
  }
  
  # Check data size
  n_lines <- system(paste("wc -l", input_file), intern = TRUE)
  n_rows <- as.integer(strsplit(n_lines, "\\s+")[[1]][1]) - 1  # Subtract header
  cat("   Rows:", n_rows, "\n")
  
} else {
  cat("   ✗ NOT FOUND:", input_file, "\n")
  cat("   → Check if file exists or set DDM_INPUT_FILE environment variable\n")
  stop("Input file not found")
}

# 4. Check cmdstan installation
cat("\n4. Stan backend (cmdstanr):\n")
if (requireNamespace("cmdstanr", quietly = TRUE)) {
  cmdstan_path <- tryCatch(cmdstanr::cmdstan_path(), error = function(e) NULL)
  if (!is.null(cmdstan_path) && cmdstan_path != "") {
    cat("   ✓ cmdstan path:", cmdstan_path, "\n")
  } else {
    cat("   ✗ cmdstan not installed\n")
    cat("   → Run: cmdstanr::install_cmdstan()\n")
    warning("cmdstan not installed - models will fail to fit")
  }
} else {
  cat("   ✗ cmdstanr package not available\n")
}

# 5. Check output directories
cat("\n5. Output directories:\n")
output_dirs <- c("output/ddm_refits", "output/results", "output/figures")
for (dir in output_dirs) {
  if (dir.exists(dir)) {
    cat("   ✓", dir, "\n")
  } else {
    cat("   → Will be created:", dir, "\n")
  }
}

cat("\n================================================================================\n")
cat("PRE-FLIGHT CHECK COMPLETE\n")
cat("================================================================================\n")
cat("\nIf all checks passed, you can run:\n")
cat("  Rscript scripts/ddm_refit_with_new_threshold.R\n")
cat("\nFor a dry run (no model fitting):\n")
cat("  DDM_DRY_RUN=1 Rscript scripts/ddm_refit_with_new_threshold.R\n")
cat("\n")
