#!/usr/bin/env Rscript
# Generate Updated Data Quality Report
# Combines sanity check results with status information

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(knitr)
})

cat("================================================================================\n")
cat("GENERATING UPDATED DATA QUALITY REPORT\n")
cat("================================================================================\n\n")

# Load sanity check results
sanity_summary <- read_csv("pupil_data_sanity_check_summary.csv", show_col_types = FALSE)

# Load status report
status_report <- read_csv("pupil_data_status_report.csv", show_col_types = FALSE)

# Load run detail
run_detail <- read_csv("pupil_data_run_detail.csv", show_col_types = FALSE)

# Check for new files
cleaned_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned"
processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"

cleaned_files <- list.files(cleaned_dir, pattern = "_eyetrack_cleaned\\.mat$", full.names = FALSE)
flat_files <- list.files(processed_dir, pattern = "_flat\\.csv$", full.names = FALSE)
merged_files <- list.files(processed_dir, pattern = "_flat_merged\\.csv$", full.names = FALSE)

cat("File Counts:\n")
cat(sprintf("  Cleaned .mat files: %d\n", length(cleaned_files)))
cat(sprintf("  Flat CSV files: %d\n", length(flat_files)))
cat(sprintf("  Merged CSV files: %d\n", length(merged_files)))
cat("\n")

# Extract subject-task from cleaned files
cleaned_info <- tibble(filename = cleaned_files) %>%
  mutate(
    subject = gsub(".*subject(BAP\\d+).*", "\\1", filename),
    task = case_when(
      grepl("Aoddball|Aodball", filename, ignore.case = TRUE) ~ "ADT",
      grepl("Voddball", filename, ignore.case = TRUE) ~ "VDT",
      TRUE ~ "Unknown"
    )
  ) %>%
  filter(subject != filename) %>%
  distinct(subject, task) %>%
  arrange(subject, task)

# Extract from processed files
processed_info <- tibble(filename = c(flat_files, merged_files)) %>%
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

# New files
new_files <- cleaned_info %>%
  anti_join(processed_info, by = c("subject", "task"))

# Generate comprehensive report
report <- list()

report$summary <- list(
  timestamp = Sys.time(),
  cleaned_files = length(cleaned_files),
  flat_files = length(flat_files),
  merged_files = length(merged_files),
  total_subjects_cleaned = length(unique(cleaned_info$subject)),
  total_subjects_processed = length(unique(processed_info$subject)),
  new_subject_task_combos = nrow(new_files),
  mean_merge_rate = mean(sanity_summary$merge_rate, na.rm = TRUE),
  mean_missing_data = mean(sanity_summary$pupil_missing_pct, na.rm = TRUE),
  files_with_issues = sum(sanity_summary$status == "ISSUES")
)

# Quality metrics
report$quality_metrics <- sanity_summary %>%
  summarise(
    total_files = n(),
    files_ok = sum(status == "OK"),
    files_with_issues = sum(status == "ISSUES"),
    mean_missing_pct = mean(pupil_missing_pct, na.rm = TRUE),
    mean_merge_rate = mean(merge_rate, na.rm = TRUE),
    median_merge_rate = median(merge_rate, na.rm = TRUE),
    min_merge_rate = min(merge_rate, na.rm = TRUE),
    max_merge_rate = max(merge_rate, na.rm = TRUE)
  )

# Files needing attention
report$files_needing_attention <- sanity_summary %>%
  filter(status == "ISSUES") %>%
  arrange(desc(pupil_missing_pct), merge_rate) %>%
  select(filename, subject, task, pupil_missing_pct, merge_rate, issues)

# New files summary
report$new_files <- new_files

# Write comprehensive report
cat("================================================================================\n")
cat("UPDATED DATA QUALITY REPORT\n")
cat("================================================================================\n\n")

cat("SUMMARY STATISTICS\n")
cat("------------------\n")
cat(sprintf("Report Generated: %s\n", format(report$summary$timestamp, "%Y-%m-%d %H:%M:%S")))
cat(sprintf("Cleaned .mat files: %d\n", report$summary$cleaned_files))
cat(sprintf("Flat CSV files: %d\n", report$summary$flat_files))
cat(sprintf("Merged CSV files: %d\n", report$summary$merged_files))
cat(sprintf("Total subjects (cleaned): %d\n", report$summary$total_subjects_cleaned))
cat(sprintf("Total subjects (processed): %d\n", report$summary$total_subjects_processed))
cat(sprintf("New subject-task combinations: %d\n", report$summary$new_subject_task_combos))
cat("\n")

cat("QUALITY METRICS\n")
cat("---------------\n")
cat(sprintf("Mean merge rate: %.1f%%\n", report$quality_metrics$mean_merge_rate * 100))
cat(sprintf("Median merge rate: %.1f%%\n", report$quality_metrics$median_merge_rate * 100))
cat(sprintf("Merge rate range: %.1f%% - %.1f%%\n", 
            report$quality_metrics$min_merge_rate * 100,
            report$quality_metrics$max_merge_rate * 100))
cat(sprintf("Mean missing data: %.2f%%\n", report$quality_metrics$mean_missing_pct))
cat(sprintf("Files with issues: %d / %d\n", 
            report$quality_metrics$files_with_issues,
            report$quality_metrics$total_files))
cat("\n")

if(nrow(report$new_files) > 0) {
  cat("NEW FILES REQUIRING PROCESSING\n")
  cat("-------------------------------\n")
  print(report$new_files)
  cat("\n")
}

if(nrow(report$files_needing_attention) > 0) {
  cat("FILES NEEDING ATTENTION\n")
  cat("------------------------\n")
  print(head(report$files_needing_attention, 10))
  if(nrow(report$files_needing_attention) > 10) {
    cat(sprintf("... and %d more files\n", nrow(report$files_needing_attention) - 10))
  }
  cat("\n")
}

# Save detailed report
write_csv(
  bind_rows(
    tibble(metric = "cleaned_files", value = as.character(report$summary$cleaned_files)),
    tibble(metric = "flat_files", value = as.character(report$summary$flat_files)),
    tibble(metric = "merged_files", value = as.character(report$summary$merged_files)),
    tibble(metric = "new_combinations", value = as.character(report$summary$new_subject_task_combos)),
    tibble(metric = "mean_merge_rate", value = sprintf("%.2f", report$summary$mean_merge_rate)),
    tibble(metric = "mean_missing_data", value = sprintf("%.2f", report$summary$mean_missing_data))
  ),
  "pupil_data_quality_report_updated.csv"
)

# Save new files list
if(nrow(report$new_files) > 0) {
  write_csv(report$new_files, "new_files_requiring_processing.csv")
  cat("✓ Saved new files list to: new_files_requiring_processing.csv\n")
}

cat("✓ Saved quality report to: pupil_data_quality_report_updated.csv\n")
cat("\n")
cat("================================================================================\n")
cat("REPORT GENERATION COMPLETE\n")
cat("================================================================================\n\n")









