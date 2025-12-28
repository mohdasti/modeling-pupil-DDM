# ============================================================================
# QUICK FIX: Regenerate Waveforms from Extended Flat Files
# ============================================================================
# Run this script to regenerate waveforms using ONLY the latest build directory
# ============================================================================

cat("================================================================================\n")
cat("QUICK FIX: Regenerate Waveforms from Extended Flat Files\n")
cat("================================================================================\n\n")

LATEST_BUILD <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/build_20251225_154443"
CONFIG_FILE <- "config/data_paths.yaml"
WAVEFORM_FILE <- "quick_share_v7/analysis/pupil_waveforms_condition_mean.csv"

# Step 1: Backup original config
cat("Step 1: Backing up original config...\n")
config_backup <- paste0(CONFIG_FILE, ".backup_", format(Sys.time(), "%Y%m%d_%H%M%S"))
if (file.exists(CONFIG_FILE)) {
  file.copy(CONFIG_FILE, config_backup)
  cat("  ✓ Backed up to:", config_backup, "\n")
}

# Step 2: Read and modify config
cat("\nStep 2: Updating config to point to latest build...\n")
if (file.exists(CONFIG_FILE)) {
  config_content <- readLines(CONFIG_FILE)
  
  # Find and replace processed_dir line
  processed_dir_line <- grep("^processed_dir:", config_content)
  if (length(processed_dir_line) > 0) {
    original_line <- config_content[processed_dir_line]
    config_content[processed_dir_line] <- paste0('processed_dir: "', LATEST_BUILD, '"')
    cat("  Changed:", original_line, "\n")
    cat("  To:     ", config_content[processed_dir_line], "\n")
  }
  
  # Write modified config
  writeLines(config_content, CONFIG_FILE)
  cat("  ✓ Config updated\n")
} else {
  stop("Config file not found: ", CONFIG_FILE)
}

# Step 3: Delete old waveform file
cat("\nStep 3: Deleting old waveform file...\n")
if (file.exists(WAVEFORM_FILE)) {
  file.remove(WAVEFORM_FILE)
  cat("  ✓ Deleted:", WAVEFORM_FILE, "\n")
} else {
  cat("  (File doesn't exist, skipping)\n")
}

# Step 4: Instructions
cat("\n================================================================================\n")
cat("NEXT STEPS:\n")
cat("================================================================================\n")
cat("1. Run make_quick_share_v7.R to regenerate waveforms:\n")
cat("   source('scripts/make_quick_share_v7.R')\n\n")
cat("2. After it completes, restore the original config:\n")
cat("   file.copy('", config_backup, "', '", CONFIG_FILE, "', overwrite = TRUE)\n", sep = "")
cat("   file.remove('", config_backup, "')\n\n", sep = "")
cat("3. Verify waveforms are extended (max t_rel should be >= 7.65s):\n")
cat("   waveform <- readr::read_csv('quick_share_v7/analysis/pupil_waveforms_condition_mean.csv')\n")
cat("   max(waveform$t_rel[waveform$chapter == 'ch3'], na.rm = TRUE)\n\n")
cat("================================================================================\n")

