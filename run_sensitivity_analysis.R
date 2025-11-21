# run_sensitivity_analysis.R
# Simple wrapper to run sensitivity analysis in RStudio
# Usage: source("run_sensitivity_analysis.R") in RStudio

# Find project root
find_project_root <- function() {
  current <- getwd()
  markers <- c("R/fit_standard_bias_only_sensitivity.R", ".git", "data/analysis_ready")
  
  # Check current directory
  if (any(sapply(markers, function(m) file.exists(file.path(current, m))))) {
    return(normalizePath(current))
  }
  
  # Walk up directories
  max_depth <- 5
  path <- current
  for (i in 1:max_depth) {
    path <- dirname(path)
    if (path == dirname(path)) break
    if (any(sapply(markers, function(m) file.exists(file.path(path, m))))) {
      return(normalizePath(path))
    }
  }
  
  # Fallback
  project_path <- file.path(Sys.getenv("HOME"), "Documents", "GitHub", "modeling-pupil-DDM", "modeling-pupil-DDM")
  if (dir.exists(project_path)) {
    return(normalizePath(project_path))
  }
  
  stop("Could not find project root. Please run this script from within the project directory.")
}

project_root <- find_project_root()

if (getwd() != project_root) {
  cat("Changing working directory to project root:\n")
  cat("  From:", getwd(), "\n")
  cat("  To:  ", project_root, "\n")
  setwd(project_root)
}

cat("\n")
cat("=", strrep("=", 70), "\n")
cat("SENSITIVITY ANALYSIS: Tightened v(Standard) Prior\n")
cat("=", strrep("=", 70), "\n")
cat("\n")
cat("This will:\n")
cat("  1. Fit Standard-only model with tighter drift prior (normal(0, 0.02))\n")
cat("  2. Compare bias estimates with original model (normal(0, 0.03))\n")
cat("  3. Confirm bias stability\n")
cat("\n")
cat("Estimated time: 20-40 minutes\n")
cat("\n")
cat("Starting...\n")
cat("\n")

# Run sensitivity analysis
source("R/fit_standard_bias_only_sensitivity.R")

# If sensitivity model completed, run comparison
if (file.exists("output/publish/fit_standard_bias_only_sens.rds")) {
  cat("\n")
  cat("=", strrep("=", 70), "\n")
  cat("Running comparison...\n")
  cat("=", strrep("=", 70), "\n")
  source("R/compare_sensitivity_bias.R")
} else {
  cat("\n⚠️  Sensitivity model not found. Comparison skipped.\n")
}

cat("\n")
cat("=", strrep("=", 70), "\n")
cat("SENSITIVITY ANALYSIS COMPLETE\n")
cat("=", strrep("=", 70), "\n")

