# run_resume_bias_models.R
# Simple wrapper to run the resume script from anywhere
# Usage: source("run_resume_bias_models.R") in RStudio, or Rscript run_resume_bias_models.R

# Find project root
find_project_root <- function() {
  current <- getwd()
  markers <- c("R/resume_bias_models.R", ".git", "data/analysis_ready")
  
  # Check current directory
  if (any(sapply(markers, function(m) file.exists(file.path(current, m))))) {
    return(normalizePath(current))
  }
  
  # Walk up directories
  max_depth <- 5
  path <- current
  for (i in 1:max_depth) {
    path <- dirname(path)
    if (path == dirname(path)) break  # Reached filesystem root
    if (any(sapply(markers, function(m) file.exists(file.path(path, m))))) {
      return(normalizePath(path))
    }
  }
  
  # Fallback: common project location
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
  cat("Working directory changed to:", getwd(), "\n")
} else {
  cat("Working directory:", getwd(), "\n")
  cat("Project root verified.\n")
}

# Now source the resume script
cat("\n")
cat("=", strrep("=", 70), "\n")
cat("Starting bias models resume script...\n")
cat("=", strrep("=", 70), "\n")
cat("\n")

source("R/resume_bias_models.R")

