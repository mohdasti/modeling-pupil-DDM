#!/usr/bin/env Rscript
# Test Script: Compare Before/After Fixes
# This script tests the fixes by comparing old vs new pipeline outputs

library(readr)
library(dplyr)

cat("=== TESTING AUDIT FIXES ===\n\n")

# Check if old file exists
old_file <- '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/BAP003_ADT_flat_merged.csv'

if(file.exists(old_file)) {
  cat("BEFORE FIXES (Old Pipeline):\n")
  cat("============================\n")
  
  old_data <- read_csv(old_file, n_max=50000, show_col_types=FALSE)
  
  cat(sprintf("Total samples: %d\n", nrow(old_data)))
  cat(sprintf("Zero values: %d (%.2f%%)\n", 
              sum(old_data$pupil == 0, na.rm=TRUE),
              100*sum(old_data$pupil == 0, na.rm=TRUE)/nrow(old_data)))
  cat(sprintf("NaN values: %d (%.2f%%)\n", 
              sum(is.na(old_data$pupil)),
              100*sum(is.na(old_data$pupil))/nrow(old_data)))
  cat(sprintf("Unique trials: %d\n", length(unique(old_data$trial_index))))
  cat(sprintf("Has trial_in_run: %s\n", ifelse('trial_in_run' %in% names(old_data), 'YES', 'NO')))
  
  if('baseline_quality' %in% names(old_data)) {
    cat(sprintf("Mean baseline quality: %.3f\n", mean(old_data$baseline_quality, na.rm=TRUE)))
    cat(sprintf("Trials with baseline < 0.80: %d\n", 
                sum(old_data %>% group_by(trial_index) %>% 
                    summarise(bq = first(baseline_quality)) %>% 
                    pull(bq) < 0.80, na.rm=TRUE)))
  }
  
  if('overall_quality' %in% names(old_data)) {
    cat(sprintf("Mean overall quality: %.3f\n", mean(old_data$overall_quality, na.rm=TRUE)))
    
    # Calculate valid trial rate
    trial_summary <- old_data %>%
      group_by(trial_index) %>%
      summarise(
        overall_qual = first(overall_quality),
        baseline_qual = first(baseline_quality),
        .groups='drop'
      )
    
    valid_trials_old <- sum(trial_summary$overall_qual >= 0.80, na.rm=TRUE)
    cat(sprintf("Trials with overall_quality >= 0.80: %d / %d (%.1f%%)\n",
                valid_trials_old, nrow(trial_summary),
                100*valid_trials_old/nrow(trial_summary)))
    
    # With baseline check
    valid_trials_with_baseline <- sum(
      trial_summary$overall_qual >= 0.80 & 
      trial_summary$baseline_qual >= 0.80, 
      na.rm=TRUE
    )
    cat(sprintf("Trials with both >= 0.80: %d / %d (%.1f%%)\n",
                valid_trials_with_baseline, nrow(trial_summary),
                100*valid_trials_with_baseline/nrow(trial_summary)))
  }
  
  cat("\n")
} else {
  cat("Old file not found - will test new pipeline only\n\n")
}

# Expected results after fixes
cat("EXPECTED AFTER FIXES (New Pipeline):\n")
cat("====================================\n")
cat("1. Zero values should be converted to NaN\n")
cat("2. trial_in_run column should be present\n")
cat("3. Baseline quality check should exclude trials with baseline < 0.80\n")
cat("4. Overall quality threshold should be 0.80 (already applied)\n")
cat("5. R merger should use trial_in_run instead of position\n\n")

cat("KEY METRICS TO CHECK:\n")
cat("- Zero percentage should be 0% (all converted to NaN)\n")
cat("- NaN percentage should increase (zeros converted)\n")
cat("- Valid trial rate may decrease slightly (baseline check + zero handling)\n")
cat("- trial_in_run should be present and sequential (1, 2, 3...)\n")
cat("- Merge rate should be accurate (no misaligned trials)\n\n")

cat("=== TEST COMPLETE ===\n")
cat("To test the full pipeline:\n")
cat("1. Run MATLAB pipeline on BAP003 (with fixes)\n")
cat("2. Run R merger (with trial_in_run matching)\n")
cat("3. Compare results with this script\n")









