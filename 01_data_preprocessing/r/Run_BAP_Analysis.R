# =========================================================================
# BAP PUPILLOMETRY ANALYSIS - SINGLE EXECUTION SCRIPT
# =========================================================================
# 
# This script runs the complete BAP pupillometry analysis pipeline
# with comprehensive logging and reporting.
#
# Usage: Simply run this script and it will execute all steps automatically
# Output: Detailed research log with all results and interpretations
# =========================================================================

# Clear workspace and set up
rm(list = ls())
gc()

# Load the main pipeline
cat("=== BAP PUPILLOMETRY ANALYSIS PIPELINE ===\n")
cat("Starting automated analysis...\n\n")

# Source the main pipeline script
source("BAP_Complete_Pipeline_Automated.R")

cat("\n=== ANALYSIS COMPLETE ===\n")
cat("Check the generated log file for comprehensive results.\n")
cat("The log contains all statistical models, interpretations, and research implications.\n")
