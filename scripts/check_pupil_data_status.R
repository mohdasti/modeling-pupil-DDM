#!/usr/bin/env Rscript
# ============================================================================
# Check Pupil Data Status
# ============================================================================
# Reports which participants, tasks, and runs are currently available
# in the cleaned pupil data flat files
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

cat("================================================================================\n")
cat("PUPIL DATA STATUS REPORT\n")
cat("================================================================================\n\n")

# Configuration
processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"

# Find all flat CSV files
flat_files_merged <- list.files(processed_dir, pattern = "_flat_merged\\.csv$", full.names = TRUE)
flat_files_reg <- list.files(processed_dir, pattern = "_flat\\.csv$", full.names = TRUE)

# Remove duplicates (if both regular and merged exist for same subject/task)
if (length(flat_files_merged) > 0 && length(flat_files_reg) > 0) {
  merged_ids <- gsub("_flat_merged\\.csv$", "", basename(flat_files_merged))
  reg_ids <- gsub("_flat\\.csv$", "", basename(flat_files_reg))
  reg_to_keep <- !reg_ids %in% merged_ids
  flat_files <- c(flat_files_merged, flat_files_reg[reg_to_keep])
} else {
  flat_files <- c(flat_files_merged, flat_files_reg)
}

cat(sprintf("Found %d flat CSV files\n\n", length(flat_files)))

if (length(flat_files) == 0) {
  stop("No flat files found in: ", processed_dir)
}

# Process each file to extract participant, task, and run information
file_info_list <- list()

for (i in seq_along(flat_files)) {
  file_path <- flat_files[i]
  filename <- basename(file_path)
  
  cat(sprintf("Processing: %s\n", filename))
  
  tryCatch({
    # Read just a sample to get structure (faster)
    df_sample <- read_csv(file_path, n_max = 1000, show_col_types = FALSE, progress = FALSE)
    
    # Check required columns
    required_cols <- c("sub", "task", "run")
    if (!all(required_cols %in% colnames(df_sample))) {
      cat(sprintf("  WARNING: Missing required columns in %s\n", filename))
      next
    }
    
    # Read full file to get unique combinations
    df <- read_csv(file_path, show_col_types = FALSE, progress = FALSE)
    
    # Extract unique combinations
    unique_combos <- df %>%
      distinct(sub, task, run) %>%
      arrange(sub, task, run) %>%
      mutate(
        filename = filename,
        n_rows = nrow(df),
        n_trials = if("trial_index" %in% colnames(df)) length(unique(df$trial_index[!is.na(df$trial_index)])) else NA_integer_
      )
    
    file_info_list[[i]] <- unique_combos
    
  }, error = function(e) {
    cat(sprintf("  ERROR reading %s: %s\n", filename, e$message))
  })
}

# Combine all file information
if (length(file_info_list) == 0) {
  stop("No files could be successfully read")
}

all_combos <- bind_rows(file_info_list)

cat("\n================================================================================\n")
cat("SUMMARY STATISTICS\n")
cat("================================================================================\n\n")

cat(sprintf("Total unique participants: %d\n", length(unique(all_combos$sub))))
cat(sprintf("Total unique tasks: %s\n", paste(unique(all_combos$task), collapse = ", ")))
cat(sprintf("Total participant-task-run combinations: %d\n", nrow(all_combos)))
cat(sprintf("Total rows across all files: %s\n", format(sum(all_combos$n_rows, na.rm = TRUE), big.mark = ",")))

# Create detailed summary by participant and task
cat("\n================================================================================\n")
cat("DETAILED STATUS BY PARTICIPANT AND TASK\n")
cat("================================================================================\n\n")

status_summary <- all_combos %>%
  group_by(sub, task) %>%
  summarise(
    n_runs = n(),
    runs = paste(sort(unique(run)), collapse = ", "),
    min_run = min(run, na.rm = TRUE),
    max_run = max(run, na.rm = TRUE),
    total_rows = sum(n_rows, na.rm = TRUE),
    total_trials = if(all(is.na(n_trials))) NA_integer_ else sum(n_trials, na.rm = TRUE),
    files = paste(unique(filename), collapse = "; "),
    .groups = "drop"
  ) %>%
  arrange(sub, task)

# Print detailed table
cat("Participant | Task | Runs | Run Range | Total Rows | Total Trials\n")
cat("------------|------|------|-----------|------------|-------------\n")
for (i in 1:nrow(status_summary)) {
  row <- status_summary[i, ]
  cat(sprintf("%-11s | %-4s | %4d | %3d-%3d   | %10s | %12s\n",
              row$sub, row$task, row$n_runs, row$min_run, row$max_run,
              format(row$total_rows, big.mark = ","),
              if(is.na(row$total_trials)) "N/A" else format(row$total_trials, big.mark = ",")))
}

# Create run-level detail
cat("\n================================================================================\n")
cat("RUN-LEVEL DETAIL\n")
cat("================================================================================\n\n")

run_detail <- all_combos %>%
  arrange(sub, task, run) %>%
  select(sub, task, run, filename, n_rows, n_trials)

cat("Participant | Task | Run | Filename | Rows | Trials\n")
cat("------------|------|-----|----------|------|-------\n")
for (i in 1:nrow(run_detail)) {
  row <- run_detail[i, ]
  cat(sprintf("%-11s | %-4s | %3d | %-30s | %5s | %6s\n",
              row$sub, row$task, row$run, 
              substr(row$filename, 1, 30),
              format(row$n_rows, big.mark = ","),
              if(is.na(row$n_trials)) "N/A" else format(row$n_trials, big.mark = ",")))
}

# Participant-level summary
cat("\n================================================================================\n")
cat("PARTICIPANT-LEVEL SUMMARY\n")
cat("================================================================================\n\n")

participant_summary <- all_combos %>%
  group_by(sub) %>%
  summarise(
    tasks = paste(sort(unique(task)), collapse = ", "),
    n_tasks = length(unique(task)),
    total_runs = n(),
    total_rows = sum(n_rows, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(sub)

cat("Participant | Tasks | # Tasks | Total Runs | Total Rows\n")
cat("------------|-------|---------|------------|------------\n")
for (i in 1:nrow(participant_summary)) {
  row <- participant_summary[i, ]
  cat(sprintf("%-11s | %-5s | %7d | %10d | %10s\n",
              row$sub, row$tasks, row$n_tasks, row$total_runs,
              format(row$total_rows, big.mark = ",")))
}

# Task-level summary
cat("\n================================================================================\n")
cat("TASK-LEVEL SUMMARY\n")
cat("================================================================================\n\n")

task_summary <- all_combos %>%
  group_by(task) %>%
  summarise(
    n_participants = length(unique(sub)),
    participants = paste(sort(unique(sub)), collapse = ", "),
    total_runs = n(),
    total_rows = sum(n_rows, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(task)

cat("Task | # Participants | Total Runs | Total Rows | Participants\n")
cat("-----|----------------|------------|------------|-------------\n")
for (i in 1:nrow(task_summary)) {
  row <- task_summary[i, ]
  cat(sprintf("%-4s | %14d | %10d | %10s | %s\n",
              row$task, row$n_participants, row$total_runs,
              format(row$total_rows, big.mark = ","),
              substr(row$participants, 1, 60)))
}

# Save detailed report to CSV
output_file <- "pupil_data_status_report.csv"
write_csv(status_summary, output_file)
cat(sprintf("\n✓ Detailed summary saved to: %s\n", output_file))

# Save run-level detail
run_detail_file <- "pupil_data_run_detail.csv"
write_csv(run_detail, run_detail_file)
cat(sprintf("✓ Run-level detail saved to: %s\n", run_detail_file))

cat("\n================================================================================\n")
cat("REPORT COMPLETE\n")
cat("================================================================================\n\n")









