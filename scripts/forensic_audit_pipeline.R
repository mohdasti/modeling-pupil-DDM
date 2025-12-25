#!/usr/bin/env Rscript

# ============================================================================
# FORENSIC AUDIT: Prove/Disprove ses==1 Contamination
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(tidyr)
  library(purrr)
})

BASE_DIR <- "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM"
OUTPUT_DIR <- file.path(BASE_DIR, "data/qc/pipeline_forensics")
BAP_CLEANED <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned"
BAP_PROCESSED <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"

cat("=== FORENSIC AUDIT: TASK 0 - PROVE/DISPROVE ses==1 CONTAMINATION ===\n\n")

# ============================================================================
# TASK 0A: List filenames in BAP_cleaned
# ============================================================================

cat("TASK 0A: Scanning BAP_cleaned directory...\n")
cat("----------------------------------------------------------------------\n")

if (dir.exists(BAP_CLEANED)) {
  cleaned_files <- list.files(BAP_CLEANED, pattern = ".*_cleaned\\.mat$", full.names = FALSE, recursive = FALSE)
  cat("Found", length(cleaned_files), "cleaned .mat files\n\n")
  
  # Parse session and run from filenames
  filename_scan <- tibble(
    filename = cleaned_files,
    ses_from_filename = str_extract(filename, "(?i)session(\\d+)") %>% str_extract("\\d+") %>% as.integer(),
    ses_from_filename_alt = str_extract(filename, "(?i)ses-?(\\d+)") %>% str_extract("\\d+") %>% as.integer(),
    run_from_filename = str_extract(filename, "(?i)run(\\d+)") %>% str_extract("\\d+") %>% as.integer(),
    has_session1 = str_detect(filename, "(?i)(session1|ses-?1)"),
    has_outsidescanner = str_detect(filename, "(?i)outsidescanner"),
    has_practice = str_detect(filename, "(?i)(practice|matlab)"),
    subject = str_extract(filename, "(?i)subject([A-Z0-9]+)") %>% str_extract("[A-Z0-9]+"),
    task = if_else(str_detect(filename, "(?i)Aoddball"), "ADT",
                   if_else(str_detect(filename, "(?i)Voddball"), "VDT", "Unknown"))
  ) %>%
    mutate(
      ses_parsed = coalesce(ses_from_filename, ses_from_filename_alt)
    )
  
  cat("Session distribution in BAP_cleaned filenames:\n")
  print(table(filename_scan$ses_parsed, useNA = "ifany"))
  
  cat("\nFiles with session1 pattern:\n")
  session1_files <- filename_scan %>% filter(has_session1 | ses_parsed == 1)
  if (nrow(session1_files) > 0) {
    print(session1_files)
  } else {
    cat("✓ NO session1 files found in BAP_cleaned\n")
  }
  
  cat("\nFiles with OutsideScanner pattern:\n")
  outside_files <- filename_scan %>% filter(has_outsidescanner)
  if (nrow(outside_files) > 0) {
    print(outside_files)
  } else {
    cat("✓ NO OutsideScanner files found\n")
  }
  
  cat("\nFiles with practice/MATLAB pattern:\n")
  practice_files <- filename_scan %>% filter(has_practice)
  if (nrow(practice_files) > 0) {
    print(practice_files)
  } else {
    cat("✓ NO practice/MATLAB files found\n")
  }
  
  write_csv(filename_scan, file.path(OUTPUT_DIR, "bap_cleaned_filename_scan.csv"))
  cat("\n✓ Saved: bap_cleaned_filename_scan.csv\n\n")
  
} else {
  cat("ERROR: BAP_cleaned directory not found:", BAP_CLEANED, "\n")
  filename_scan <- tibble()
}

# ============================================================================
# TASK 0B: Extract source paths from processed files
# ============================================================================

cat("TASK 0B: Extracting source paths from processed files...\n")
cat("--------------------------------------------------------\n")

# Check flat files
flat_files <- list.files(BAP_PROCESSED, pattern = "_flat\\.csv$", full.names = TRUE)
cat("Found", length(flat_files), "flat CSV files\n")

if (length(flat_files) > 0) {
  # Sample a few files to check structure
  sample_flat <- read_csv(flat_files[1], show_col_types = FALSE, n_max = 5)
  cat("Sample flat file columns:", paste(names(sample_flat), collapse = ", "), "\n")
  
  # Check if there's a source column
  has_source <- any(grepl("source|file|path|filename", names(sample_flat), ignore.case = TRUE))
  cat("Has source column:", has_source, "\n\n")
}

# Check merged files
merged_files <- list.files(BAP_PROCESSED, pattern = "_flat_merged\\.csv$", full.names = TRUE)
cat("Found", length(merged_files), "merged CSV files\n")

if (length(merged_files) > 0) {
  sample_merged <- read_csv(merged_files[1], show_col_types = FALSE, n_max = 5)
  cat("Sample merged file columns:", paste(names(sample_merged), collapse = ", "), "\n\n")
}

# Load TRIALLEVEL
triallevel_file <- file.path(BASE_DIR, "data/analysis_ready/BAP_analysis_ready_TRIALLEVEL.csv")
if (file.exists(triallevel_file)) {
  cat("Loading TRIALLEVEL...\n")
  triallevel <- read_csv(triallevel_file, show_col_types = FALSE)
  cat("TRIALLEVEL rows:", nrow(triallevel), "\n")
  cat("TRIALLEVEL columns:", paste(names(triallevel), collapse = ", "), "\n")
  cat("Session distribution in TRIALLEVEL:\n")
  if ("ses" %in% names(triallevel)) {
    print(table(triallevel$ses, useNA = "ifany"))
  }
  cat("\n")
} else {
  cat("TRIALLEVEL file not found\n\n")
}

# ============================================================================
# TASK 0C: Re-parse session and run from source paths
# ============================================================================

cat("TASK 0C: Re-parsing session and run from source paths...\n")
cat("--------------------------------------------------------\n")

# For flat files, we need to infer source from filename
# The filename pattern is: {subject}_{task}_flat.csv
# We need to match this back to BAP_cleaned files

if (length(flat_files) > 0 && nrow(filename_scan) > 0) {
  # Extract subject and task from flat file names
  flat_metadata <- tibble(
    filepath = flat_files,
    filename = basename(flat_files),
    subject_from_file = str_extract(filename, "^([A-Z0-9]+)_") %>% str_remove("_"),
    task_from_file = str_extract(filename, "_(ADT|VDT)_") %>% str_remove_all("_")
  )
  
  # Try to match to cleaned files
  flat_with_source <- flat_metadata %>%
    left_join(
      filename_scan %>% select(filename, ses_parsed, run_from_filename, subject, task),
      by = c("subject_from_file" = "subject", "task_from_file" = "task")
    )
  
  cat("Matched", sum(!is.na(flat_with_source$ses_parsed)), "flat files to cleaned sources\n\n")
}

# For TRIALLEVEL, we need to reconstruct source path from stored columns
if (exists("triallevel") && nrow(triallevel) > 0) {
  triallevel_parsed <- triallevel %>%
    mutate(
      # Try to reconstruct source filename pattern
      inferred_source_pattern = paste0("subject", subject_id, ".*", task, ".*"),
      # Parse ses from stored value
      ses_stored = if("ses" %in% names(.)) ses else NA_integer_,
      # Parse run from stored value  
      run_stored = if("run" %in% names(.)) run else NA_integer_,
      # For now, we'll need to match back to flat files to get actual source paths
      source_file = NA_character_
    )
  
  cat("TRIALLEVEL parsed - stored ses distribution:\n")
  print(table(triallevel_parsed$ses_stored, useNA = "ifany"))
  cat("\nTRIALLEVEL parsed - stored run distribution:\n")
  print(table(triallevel_parsed$run_stored, useNA = "ifany"))
  cat("\n")
}

cat("✓ Task 0C complete (partial - need to trace through pipeline for full source paths)\n\n")

# ============================================================================
# TASK 0D: Compare stored vs parsed ses/run
# ============================================================================

cat("TASK 0D: Comparing stored vs parsed ses/run...\n")
cat("------------------------------------------------\n")

# This will be completed after we trace through the full pipeline
# For now, create placeholder structure

cat("(Will be completed after full pipeline trace)\n\n")

cat("=== TASK 0 COMPLETE (partial) ===\n")
cat("Next: Trace through MATLAB, R, and QMD to find exact source paths\n")

