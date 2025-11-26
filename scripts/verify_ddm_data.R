#!/usr/bin/env Rscript
# =========================================================================
# VERIFY DDM DATA FILES
# =========================================================================
# Quick validation script to check DDM-ready data files before model fitting
# =========================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

# Helper function
`%+%` <- function(x, y) paste0(x, y)

cat(strrep("=", 80), "\n")
cat("DDM DATA VERIFICATION\n")
cat(strrep("=", 80), "\n\n")

# Check DDM-only file
ddm_only_file <- "data/analysis_ready/bap_ddm_only_ready.csv"
if (file.exists(ddm_only_file)) {
  cat("Checking DDM-only file:", ddm_only_file, "\n")
  ddm_only <- read_csv(ddm_only_file, show_col_types = FALSE)
  
  cat("  ✓ File exists\n")
  cat("  Trials:", nrow(ddm_only), "\n")
  cat("  Subjects:", length(unique(ddm_only$subject_id)), "\n")
  
  # Check dec_upper
  if ("dec_upper" %in% names(ddm_only)) {
    dec_vals <- unique(ddm_only$dec_upper[!is.na(ddm_only$dec_upper)])
    if (all(dec_vals %in% c(0L, 1L))) {
      cat("  ✓ dec_upper coding: Valid (only 0 or 1)\n")
    } else {
      cat("  ✗ dec_upper contains invalid values:", paste(dec_vals, collapse=", "), "\n")
    }
    
    # Check Standard trials
    std <- ddm_only %>% filter(difficulty_level == "Standard")
    prop_same <- 1 - mean(std$dec_upper, na.rm=TRUE)
    cat(sprintf("  Standard trials - Proportion 'Same': %.3f (expected: ~0.89)\n", prop_same))
  } else {
    cat("  ✗ dec_upper column missing!\n")
  }
  
  cat("\n")
} else {
  cat("  ⚠ DDM-only file not found:", ddm_only_file, "\n")
  cat("    Run: Rscript 01_data_preprocessing/r/prepare_ddm_only_data.R\n\n")
}

# Check DDM-pupil file
ddm_pupil_file <- "data/analysis_ready/bap_ddm_pupil_ready.csv"
if (file.exists(ddm_pupil_file)) {
  cat("Checking DDM-pupil file:", ddm_pupil_file, "\n")
  ddm_pupil <- read_csv(ddm_pupil_file, show_col_types = FALSE)
  
  cat("  ✓ File exists\n")
  cat("  Trials:", nrow(ddm_pupil), "\n")
  cat("  Subjects:", length(unique(ddm_pupil$subject_id)), "\n")
  
  # Check pupil columns
  pupil_cols <- c("tonic_baseline", "phasic_slope", "phasic_mean")
  has_pupil <- sum(pupil_cols %in% names(ddm_pupil))
  cat("  Pupil feature columns:", has_pupil, "/", length(pupil_cols), "\n")
  
  if ("dec_upper" %in% names(ddm_pupil)) {
    cat("  ✓ dec_upper column present\n")
  } else {
    cat("  ✗ dec_upper column missing!\n")
  }
  
  cat("\n")
} else {
  cat("  ⚠ DDM-pupil file not found:", ddm_pupil_file, "\n")
  cat("    Run: Rscript 01_data_preprocessing/r/prepare_ddm_pupil_data.R\n\n")
}

cat(strrep("=", 80), "\n")
cat("VERIFICATION COMPLETE\n")
cat(strrep("=", 80), "\n")

