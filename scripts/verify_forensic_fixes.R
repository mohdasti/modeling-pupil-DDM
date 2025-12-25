#!/usr/bin/env Rscript

# ============================================================================
# VERIFY FORENSIC FIXES: Check that ses/run are correct after fixes
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(arrow)
})

BASE_DIR <- "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM"
OUTPUT_DIR <- file.path(BASE_DIR, "data/qc/pipeline_forensics")
ANALYSIS_READY_DIR <- file.path(BASE_DIR, "data/analysis_ready")
BAP_PROCESSED <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"

cat("=== VERIFYING FORENSIC FIXES ===\n\n")

# Check flat files (after MATLAB fix)
cat("1. Checking MATLAB flat files (should have ses column)...\n")
cat("----------------------------------------------------------------\n")
flat_files <- list.files(BAP_PROCESSED, pattern = "_flat\\.csv$", full.names = TRUE)
if (length(flat_files) > 0) {
  sample_flat <- read_csv(flat_files[1], show_col_types = FALSE, n_max = 100)
  if ("ses" %in% names(sample_flat)) {
    cat("✓ ses column found in flat files\n")
    cat("  ses values:", paste(sort(unique(sample_flat$ses)), collapse = ", "), "\n")
    cat("  run values:", paste(sort(unique(sample_flat$run)), collapse = ", "), "\n")
    if (any(sample_flat$run != sample_flat$ses, na.rm = TRUE)) {
      cat("✓ run != ses (correct!)\n")
    } else {
      cat("⚠ run equals ses in flat files\n")
    }
  } else {
    cat("✗ ses column NOT found - MATLAB may not have been re-run\n")
  }
} else {
  cat("No flat files found\n")
}

# Check merged files (after R merger fix)
cat("\n2. Checking R merged files (should have ses from behavioral)...\n")
cat("----------------------------------------------------------------\n")
merged_files <- list.files(BAP_PROCESSED, pattern = "_flat_merged\\.csv$", full.names = TRUE)
if (length(merged_files) > 0) {
  sample_merged <- read_csv(merged_files[1], show_col_types = FALSE, n_max = 100)
  if ("ses" %in% names(sample_merged)) {
    cat("✓ ses column found in merged files\n")
    ses_vals <- unique(sample_merged$ses[!is.na(sample_merged$ses)])
    run_vals <- unique(sample_merged$run[!is.na(sample_merged$run)])
    cat("  ses values:", paste(sort(ses_vals), collapse = ", "), "\n")
    cat("  run values:", paste(sort(run_vals), collapse = ", "), "\n")
    if (all(ses_vals %in% c(2, 3))) {
      cat("✓ ses values are 2 or 3 (correct!)\n")
    } else {
      cat("✗ ses has invalid values:", paste(ses_vals, collapse = ", "), "\n")
    }
    if (all(run_vals %in% 1:5)) {
      cat("✓ run values are 1-5 (correct!)\n")
    } else {
      cat("✗ run has invalid values:", paste(run_vals, collapse = ", "), "\n")
    }
    if (any(sample_merged$run != sample_merged$ses, na.rm = TRUE)) {
      cat("✓ run != ses (correct!)\n")
    } else {
      cat("⚠ run equals ses in merged files\n")
    }
  } else {
    cat("✗ ses column NOT found - R merger may not have been re-run\n")
  }
} else {
  cat("No merged files found\n")
}

# Check QMD output
cat("\n3. Checking QMD output (MERGED and TRIALLEVEL)...\n")
cat("---------------------------------------------------\n")

merged_file <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_MERGED.csv")
if (file.exists(merged_file)) {
  cat("Loading MERGED (sample)...\n")
  merged_qmd <- read_csv(merged_file, show_col_types = FALSE, n_max = 10000)
  
  if ("ses" %in% names(merged_qmd) && "run" %in% names(merged_qmd)) {
    cat("✓ ses and run columns found\n")
    cat("  ses distribution:\n")
    print(table(merged_qmd$ses, useNA = "ifany"))
    cat("  run distribution:\n")
    print(table(merged_qmd$run, useNA = "ifany"))
    
    # Check assertions
    ses_valid <- all(merged_qmd$ses %in% c(2, 3), na.rm = TRUE)
    run_valid <- all(merged_qmd$run %in% 1:5, na.rm = TRUE)
    run_ne_ses <- any(merged_qmd$run != merged_qmd$ses, na.rm = TRUE)
    
    if (ses_valid) {
      cat("✓ ses values are 2 or 3\n")
    } else {
      cat("✗ ses has invalid values\n")
    }
    
    if (run_valid) {
      cat("✓ run values are 1-5\n")
    } else {
      cat("✗ run has invalid values\n")
    }
    
    if (run_ne_ses) {
      cat("✓ run != ses (fix working!)\n")
    } else {
      cat("✗ run still equals ses\n")
    }
    
    # Check for NA ses
    na_ses_count <- sum(is.na(merged_qmd$ses))
    if (na_ses_count == 0) {
      cat("✓ No NA ses values\n")
    } else {
      cat("⚠", na_ses_count, "rows have NA ses\n")
    }
  } else {
    cat("✗ ses or run columns missing\n")
  }
} else {
  cat("MERGED file not found\n")
}

triallevel_file <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_TRIALLEVEL.csv")
if (file.exists(triallevel_file)) {
  cat("\nLoading TRIALLEVEL...\n")
  triallevel <- read_csv(triallevel_file, show_col_types = FALSE)
  
  if ("ses" %in% names(triallevel) && "run" %in% names(triallevel)) {
    cat("✓ ses and run columns found\n")
    cat("  Total trials:", nrow(triallevel), "\n")
    cat("  ses distribution:\n")
    print(table(triallevel$ses, useNA = "ifany"))
    cat("  run distribution:\n")
    print(table(triallevel$run, useNA = "ifany"))
    
    # Check assertions
    ses_valid <- all(triallevel$ses %in% c(2, 3), na.rm = TRUE)
    run_valid <- all(triallevel$run %in% 1:5, na.rm = TRUE)
    run_ne_ses <- any(triallevel$run != triallevel$ses, na.rm = TRUE)
    
    if (ses_valid && run_valid && run_ne_ses) {
      cat("\n✓✓✓ ALL CHECKS PASSED ✓✓✓\n")
      cat("  - ses in {2,3}:", ses_valid, "\n")
      cat("  - run in {1,2,3,4,5}:", run_valid, "\n")
      cat("  - run != ses:", run_ne_ses, "\n")
    } else {
      cat("\n✗ SOME CHECKS FAILED\n")
      cat("  - ses in {2,3}:", ses_valid, "\n")
      cat("  - run in {1-5}:", run_valid, "\n")
      cat("  - run != ses:", run_ne_ses, "\n")
    }
    
    # Check trial_id format
    if ("trial_uid" %in% names(triallevel)) {
      sample_uid <- head(triallevel$trial_uid, 5)
      cat("\nSample trial_uid:\n")
      print(sample_uid)
      
      # Check if trial_uid includes ses
      uid_parts <- str_split(sample_uid[1], ":", simplify = TRUE)
      if (length(uid_parts) >= 5) {
        cat("✓ trial_uid includes ses (5 parts: sub:task:ses:run:trial)\n")
      } else if (length(uid_parts) == 4) {
        cat("⚠ trial_uid missing ses (4 parts: sub:task:run:trial)\n")
      }
    }
  } else {
    cat("✗ ses or run columns missing\n")
  }
} else {
  cat("TRIALLEVEL file not found\n")
}

# Generate verification numbers
cat("\n4. Generating verification numbers...\n")
cat("----------------------------------------\n")

if (exists("triallevel") && nrow(triallevel) > 0 && "ses" %in% names(triallevel) && "run" %in% names(triallevel)) {
  verification_numbers <- tibble(
    metric = c(
      "total_trials",
      "unique_subjects",
      "ses_2_count",
      "ses_3_count",
      "run_1_count",
      "run_2_count",
      "run_3_count",
      "run_4_count",
      "run_5_count",
      "ses_valid",
      "run_valid",
      "run_ne_ses",
      "na_ses_count"
    ),
    value = c(
      nrow(triallevel),
      n_distinct(triallevel$subject_id),
      sum(triallevel$ses == 2, na.rm = TRUE),
      sum(triallevel$ses == 3, na.rm = TRUE),
      sum(triallevel$run == 1, na.rm = TRUE),
      sum(triallevel$run == 2, na.rm = TRUE),
      sum(triallevel$run == 3, na.rm = TRUE),
      sum(triallevel$run == 4, na.rm = TRUE),
      sum(triallevel$run == 5, na.rm = TRUE),
      as.integer(all(triallevel$ses %in% c(2, 3), na.rm = TRUE)),
      as.integer(all(triallevel$run %in% 1:5, na.rm = TRUE)),
      as.integer(any(triallevel$run != triallevel$ses, na.rm = TRUE)),
      sum(is.na(triallevel$ses))
    )
  )
  
  write_csv(verification_numbers, file.path(OUTPUT_DIR, "final_verification_numbers.csv"))
  cat("✓ Saved: final_verification_numbers.csv\n")
  
  # Create markdown report
  report_lines <- c(
    "# Final Verification Report",
    "",
    "**Date:**", format(Sys.time(), '%Y-%m-%d %H:%M:%S'),
    "",
    "## Summary",
    "",
    paste("- Total trials:", nrow(triallevel)),
    paste("- Unique subjects:", n_distinct(triallevel$subject_id)),
    "",
    "## Session Distribution",
    "",
    "| ses | Count |",
    "|-----|-------|",
    paste("| 2 |", sum(triallevel$ses == 2, na.rm = TRUE), "|"),
    paste("| 3 |", sum(triallevel$ses == 3, na.rm = TRUE), "|"),
    "",
    "## Run Distribution",
    "",
    "| run | Count |",
    "|-----|-------|",
    paste("| 1 |", sum(triallevel$run == 1, na.rm = TRUE), "|"),
    paste("| 2 |", sum(triallevel$run == 2, na.rm = TRUE), "|"),
    paste("| 3 |", sum(triallevel$run == 3, na.rm = TRUE), "|"),
    paste("| 4 |", sum(triallevel$run == 4, na.rm = TRUE), "|"),
    paste("| 5 |", sum(triallevel$run == 5, na.rm = TRUE), "|"),
    "",
    "## Validation Checks",
    "",
    paste("- ✓ ses in {2,3}:", all(triallevel$ses %in% c(2, 3), na.rm = TRUE)),
    paste("- ✓ run in {1,2,3,4,5}:", all(triallevel$run %in% 1:5, na.rm = TRUE)),
    paste("- ✓ run != ses:", any(triallevel$run != triallevel$ses, na.rm = TRUE)),
    paste("- ✓ No NA ses:", sum(is.na(triallevel$ses)) == 0),
    "",
    "## Conclusion",
    "",
    if (all(triallevel$ses %in% c(2, 3), na.rm = TRUE) && 
        all(triallevel$run %in% 1:5, na.rm = TRUE) && 
        any(triallevel$run != triallevel$ses, na.rm = TRUE) &&
        sum(is.na(triallevel$ses)) == 0) {
      "**✓✓✓ ALL CHECKS PASSED - Pipeline fixes are working correctly ✓✓✓**"
    } else {
      "**✗ SOME CHECKS FAILED - Review fixes**"
    }
  )
  
  write_lines(report_lines, file.path(OUTPUT_DIR, "final_verification.md"))
  cat("✓ Saved: final_verification.md\n")
}

cat("\n=== VERIFICATION COMPLETE ===\n")

