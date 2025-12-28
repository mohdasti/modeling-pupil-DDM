#!/usr/bin/env Rscript
# ============================================================================
# Regenerate Waveforms from Latest Extended Flat Files
# ============================================================================
# This script regenerates waveform summaries using ONLY the latest build
# directory with extended segmentation (Resp1ET ending at ~7.7s)
# ============================================================================

suppressPackageStartupMessages({
  library(here)
  library(yaml)
})

cat("================================================================================\n")
cat("REGENERATE WAVEFORMS FROM LATEST BUILD (EXTENDED SEGMENTATION)\n")
cat("================================================================================\n\n")

# Set paths
REPO_ROOT <- here::here()
LATEST_BUILD <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/build_20251225_154443"
WAVEFORM_FILE <- file.path(REPO_ROOT, "quick_share_v7", "analysis", "pupil_waveforms_condition_mean.csv")

cat("Latest build directory: ", LATEST_BUILD, "\n", sep = "")
cat("Output waveform file: ", WAVEFORM_FILE, "\n\n", sep = "")

# Check build directory exists
if (!dir.exists(LATEST_BUILD)) {
  stop("ERROR: Build directory does not exist: ", LATEST_BUILD)
}

# Find flat files in latest build only
flat_files <- list.files(
  LATEST_BUILD,
  pattern = ".*_(ADT|VDT)_flat\\.csv$",
  full.names = TRUE
)

if (length(flat_files) == 0) {
  stop("ERROR: No flat CSV files found in ", LATEST_BUILD)
}

cat("Found ", length(flat_files), " flat files in latest build\n\n", sep = "")

# Verify these are extended files
cat("Verifying files are extended (checking first file)...\n")
first_file_sample <- read.csv(flat_files[1], nrows = 100)
if ("seg_end_rel_used" %in% names(first_file_sample)) {
  seg_end <- first_file_sample$seg_end_rel_used[1]
  cat("  seg_end_rel_used = ", round(seg_end, 2), "s (expected ~7.70s)\n", sep = "")
  if (seg_end < 7.0) {
    warning("WARNING: File does not appear to be extended! seg_end_rel_used = ", seg_end, "s")
  }
} else {
  warning("WARNING: seg_end_rel_used column not found - file may be old format")
}

cat("\n================================================================================\n")
cat("IMPORTANT: You need to run make_quick_share_v7.R with these files\n")
cat("================================================================================\n\n")
cat("Option 1: Temporarily point to latest build\n")
cat("  Edit config/data_paths.yaml and set:\n")
cat("    processed_dir: \"", LATEST_BUILD, "\"\n\n", sep = "")
cat("  Then run: source('scripts/make_quick_share_v7.R')\n\n")
cat("Option 2: Run make_quick_share_v7.R which should find these files\n")
cat("  (it searches recursively, so should find build directories)\n")
cat("  But make sure to delete the old waveform file first:\n\n")
cat("  file.remove('quick_share_v7/analysis/pupil_waveforms_condition_mean.csv')\n")
cat("  source('scripts/make_quick_share_v7.R')\n\n")

# Check if waveform file exists and show its max time
if (file.exists(WAVEFORM_FILE)) {
  cat("Current waveform file exists:\n")
  waveform_data <- read.csv(WAVEFORM_FILE)
  if ("t_rel" %in% names(waveform_data) && "chapter" %in% names(waveform_data)) {
    ch3_data <- waveform_data[waveform_data$chapter == "ch3", ]
    if (nrow(ch3_data) > 0) {
      max_t_rel <- max(ch3_data$t_rel, na.rm = TRUE)
      cat("  Current max t_rel (ch3): ", round(max_t_rel, 2), "s\n", sep = "")
      if (max_t_rel < 7.0) {
        cat("  ⚠ This appears to be from OLD flat files (not extended)\n")
        cat("  You should delete it and regenerate:\n")
        cat("    file.remove('quick_share_v7/analysis/pupil_waveforms_condition_mean.csv')\n")
      }
    }
  }
}

cat("\n================================================================================\n")

