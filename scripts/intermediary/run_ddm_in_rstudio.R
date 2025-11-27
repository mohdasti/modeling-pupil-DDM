# =========================================================================
# DDM ANALYSIS - RSTUDIO RUNNER WITH LIVE MONITORING
# =========================================================================
# This script runs the DDM analysis in RStudio with real-time logging
# Usage: Source this entire file in RStudio (Cmd+Shift+S or Source button)
# =========================================================================

# Record start time
analysis_start_time <- Sys.time()
cat("\n")
cat("================================================================================\n")
cat("DDM ANALYSIS - RSTUDIO EXECUTION\n")
cat("================================================================================\n")
cat("Started:", format(analysis_start_time, "%Y-%m-%d %H:%M:%S"), "\n")
cat("================================================================================\n\n")

# # Set working directory to project root
# cat("Current working directory:", getwd(), "\n")
# 
# # Look for the project root by searching for key files
# find_project_root <- function() {
#   # Common locations for the project
#   possible_roots <- c(
#     ".",  # Current directory
#     "..", "../..", "../../..",  # Parent directories
#     # Or search for specific project path
#     "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM"
#   )
#   
#   for (root in possible_roots) {
#     root_path <- normalizePath(root)
#     script_path <- file.path(root_path, "scripts/02_statistical_analysis/02_ddm_analysis.R")
#     if (file.exists(script_path)) {
#       return(root_path)
#     }
#   }
#   return(NULL)
# }

project_root <- find_project_root()

if (is.null(project_root)) {
  stop("ERROR: Cannot find project root.\n",
       "Current directory: ", getwd(), "\n",
       "Looking for: scripts/02_statistical_analysis/02_ddm_analysis.R\n",
       "Please either:\n",
       "  1. Open the project folder in RStudio (File > Open Project),\n",
       "  2. Or set working directory manually: setwd('/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM')")
}

cat("Found project root at:", project_root, "\n")
setwd(project_root)
cat("Working directory set to:", getwd(), "\n\n")

# Source the main DDM analysis script
# This script handles everything: data loading, model fitting, logging
cat("Sourcing main DDM analysis script...\n")
cat("This will fit all DDM models. Progress will be displayed below.\n")
cat("================================================================================\n\n")

source("scripts/02_statistical_analysis/02_ddm_analysis.R")

# Analysis complete!
analysis_end_time <- Sys.time()
total_duration <- difftime(analysis_end_time, analysis_start_time, units = "mins")

cat("\n")
cat("================================================================================\n")
cat("ANALYSIS COMPLETE!\n")
cat("================================================================================\n")
cat("Total duration:", sprintf("%.1f minutes (%.2f hours)", 
                                as.numeric(total_duration),
                                as.numeric(total_duration)/60), "\n")
cat("\n")
cat("Next steps:\n")
cat("  1. Check output/models/ for .rds files\n")
cat("  2. Load models: readRDS('output/models/ModelName.rds')\n")
cat("  3. Review console output above for any errors/warnings\n")
cat("================================================================================\n\n")

cat("✅ Script execution complete!\n\n")
