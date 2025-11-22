#!/usr/bin/env Rscript
# Step 7: Manuscript Generation - DDM Chapter Report
# This script generates the final comprehensive DDM chapter report
# It integrates all analysis outputs (QA, manipulation checks, LOO, PPC, etc.)

# Set working directory to project root
if (basename(getwd()) == "07_manuscript") {
  setwd("..")
}

# First, ensure all extraction scripts have been run
cat("========================================\n")
cat("Step 7: Generating DDM Chapter Report\n")
cat("========================================\n\n")

cat("Step 1: Running all extraction scripts...\n")
source("R/run_extract_all.R")

cat("\nStep 2: Rendering Quarto report...\n")
suppressPackageStartupMessages({
  library(quarto)
})

# Render the comprehensive report
quarto::quarto_render(
  "reports/chap3_ddm_results.qmd", 
  output_format = c("html", "docx")
)

cat("\n✓ DDM Chapter report generated:\n")
cat("  - reports/chap3_ddm_results.html\n")
cat("  - reports/chap3_ddm_results.docx\n")
cat("\n========================================\n")
cat("Step 7 complete!\n")
cat("========================================\n")


