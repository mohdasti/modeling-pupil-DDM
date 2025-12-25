#!/usr/bin/env Rscript
# Check for new cleaned files and compare with existing processed files

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

cat("================================================================================\n")
cat("CHECKING FOR NEW CLEANED FILES\n")
cat("================================================================================\n\n")

cleaned_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned"
processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"

# Get all cleaned .mat files
cleaned_files <- list.files(cleaned_dir, pattern = "_eyetrack_cleaned\\.mat$", full.names = FALSE)

# Get all processed flat files
flat_files <- list.files(processed_dir, pattern = "_flat\\.csv$", full.names = FALSE)
merged_files <- list.files(processed_dir, pattern = "_flat_merged\\.csv$", full.names = FALSE)

cat(sprintf("Cleaned files (.mat): %d\n", length(cleaned_files)))
cat(sprintf("Flat files (.csv): %d\n", length(flat_files)))
cat(sprintf("Merged files: %d\n", length(merged_files)))
cat("\n")

# Extract subject-task info from cleaned files
cleaned_info <- tibble(
  filename = cleaned_files
) %>%
  mutate(
    # Extract subject ID
    subject = gsub(".*subject(BAP\\d+).*", "\\1", filename),
    # Extract task
    task = case_when(
      grepl("Aoddball|Aodball", filename, ignore.case = TRUE) ~ "ADT",
      grepl("Voddball", filename, ignore.case = TRUE) ~ "VDT",
      TRUE ~ "Unknown"
    ),
    # Extract session and run
    session = gsub(".*session(\\d+).*", "\\1", filename),
    run = gsub(".*run(\\d+).*", "\\1", filename)
  ) %>%
  filter(subject != filename) %>%  # Remove files that didn't match pattern
  distinct(subject, task) %>%
  arrange(subject, task)

# Extract subject-task info from processed files
processed_info <- tibble(
  filename = c(flat_files, merged_files)
) %>%
  mutate(
    subject = gsub("(BAP\\d+).*", "\\1", filename),
    task = case_when(
      grepl("_ADT_", filename) ~ "ADT",
      grepl("_VDT_", filename) ~ "VDT",
      TRUE ~ "Unknown"
    )
  ) %>%
  filter(subject != filename) %>%
  distinct(subject, task) %>%
  arrange(subject, task)

# Find new combinations
new_combos <- cleaned_info %>%
  anti_join(processed_info, by = c("subject", "task"))

cat("================================================================================\n")
cat("NEW FILES NEEDING PROCESSING\n")
cat("================================================================================\n\n")

if(nrow(new_combos) > 0) {
  cat(sprintf("Found %d new subject-task combinations:\n\n", nrow(new_combos)))
  print(new_combos)
  cat("\n")
  cat("These need to be processed:\n")
  cat("1. Run MATLAB pipeline to create flat CSV files\n")
  cat("2. Run merger script to merge with behavioral data\n")
} else {
  cat("✓ No new files detected - all cleaned files have been processed\n")
}

cat("\n================================================================================\n")
cat("FILE STATUS SUMMARY\n")
cat("================================================================================\n\n")

cat("Subject-task combinations in cleaned files:\n")
print(cleaned_info)

cat("\nSubject-task combinations in processed files:\n")
print(processed_info)

cat("\n")









