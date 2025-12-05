#!/usr/bin/env Rscript

# ============================================================================
# Pupillometry Trial Flow Report
# ============================================================================
# Generates a detailed report showing trial counts at each preprocessing stage:
# 1. Raw flat files (from MATLAB pipeline)
# 2. Merged flat files (after behavioral data merge)
# 3. Analysis-ready files (after quality filtering)
# 
# Shows what gets added/dropped at each stage
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

cat("=================================================================\n")
cat("PUPILLOMETRY TRIAL FLOW REPORT\n")
cat("=================================================================\n")
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# ============================================================================
# CONFIGURATION
# ============================================================================

processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
analysis_ready_dir <- "data/analysis_ready"
output_dir <- "02_pupillometry_analysis/quality_control/output"
report_file <- file.path(output_dir, "trial_flow_report.txt")
csv_file <- file.path(output_dir, "trial_flow_summary.csv")
detailed_csv_file <- file.path(output_dir, "trial_flow_detailed.csv")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# STAGE 1: RAW FLAT FILES (from MATLAB pipeline)
# ============================================================================

cat("STAGE 1: Loading raw flat files...\n")

# Find all flat files (prefer merged, but also check regular)
flat_files_merged <- list.files(processed_dir, pattern = "_flat_merged\\.csv$", full.names = TRUE)
flat_files_reg <- list.files(processed_dir, pattern = "_flat\\.csv$", full.names = TRUE)

# Prefer merged files
if (length(flat_files_merged) > 0 && length(flat_files_reg) > 0) {
  merged_ids <- gsub("_flat_merged\\.csv$", "", basename(flat_files_merged))
  reg_ids <- gsub("_flat\\.csv$", "", basename(flat_files_reg))
  reg_to_keep <- !reg_ids %in% merged_ids
  flat_files <- c(flat_files_merged, flat_files_reg[reg_to_keep])
} else {
  flat_files <- c(flat_files_merged, flat_files_reg)
}

cat("  Found", length(flat_files), "flat files\n")

# Load raw flat files and count trials
raw_trials <- vector("list", length(flat_files))
for (i in seq_along(flat_files)) {
  tryCatch({
    # Load full data first
    full_data <- read_csv(flat_files[i], show_col_types = FALSE)
    
    # Get file info - try to extract from data first, then filename
    file_info <- strsplit(basename(flat_files[i]), "_")[[1]]
    sub <- file_info[1]
    
    # Try to get task from data first, then filename pattern
    task <- if("task" %in% names(full_data) && !all(is.na(full_data$task))) {
      unique(full_data$task[!is.na(full_data$task)])[1]
    } else if(grepl("_ADT_|_ADT\\.", basename(flat_files[i]))) {
      "ADT"
    } else if(grepl("_VDT_|_VDT\\.", basename(flat_files[i]))) {
      "VDT"
    } else if(grepl("Aoddball|Aodball", basename(flat_files[i]), ignore.case = TRUE)) {
      "ADT"
    } else if(grepl("Voddball", basename(flat_files[i]), ignore.case = TRUE)) {
      "VDT"
    } else {
      "Unknown"
    }
    
    # Count unique trials and runs in this file
    n_trials <- length(unique(full_data$trial_index))
    n_runs <- if("run" %in% names(full_data)) {
      length(unique(full_data$run[!is.na(full_data$run)]))
    } else NA_integer_
    
    raw_trials[[i]] <- data.frame(
      file = basename(flat_files[i]),
      sub = sub,
      task = task,
      stage = "Raw_Flat",
      n_trials = n_trials,
      n_samples = nrow(full_data),
      n_runs = n_runs,
      has_behavioral = "has_behavioral_data" %in% names(full_data),
      stringsAsFactors = FALSE
    )
  }, error = function(e) {
    cat("  Warning: Could not read", flat_files[i], ":", e$message, "\n")
    NULL
  })
}

raw_trials_df <- bind_rows(raw_trials[!sapply(raw_trials, is.null)])

cat("  Total raw trials:", sum(raw_trials_df$n_trials), "\n")
cat("  Unique subject-task combinations:", nrow(raw_trials_df), "\n\n")

# ============================================================================
# STAGE 2: MERGED FLAT FILES (after behavioral merge)
# ============================================================================

cat("STAGE 2: Analyzing merged flat files...\n")

merged_trials <- vector("list", length(flat_files_merged))
for (i in seq_along(flat_files_merged)) {
  tryCatch({
    full_data <- read_csv(flat_files_merged[i], show_col_types = FALSE)
    
    file_info <- strsplit(basename(flat_files_merged[i]), "_")[[1]]
    sub <- file_info[1]
    
    # Try to get task from data first, then filename pattern
    task <- if("task" %in% names(full_data) && !all(is.na(full_data$task))) {
      unique(full_data$task[!is.na(full_data$task)])[1]
    } else if(grepl("_ADT_|_ADT\\.", basename(flat_files_merged[i]))) {
      "ADT"
    } else if(grepl("_VDT_|_VDT\\.", basename(flat_files_merged[i]))) {
      "VDT"
    } else if(grepl("Aoddball|Aodball", basename(flat_files_merged[i]), ignore.case = TRUE)) {
      "ADT"
    } else if(grepl("Voddball", basename(flat_files_merged[i]), ignore.case = TRUE)) {
      "VDT"
    } else {
      "Unknown"
    }
    
    # Count trials with and without behavioral data
    n_trials_total <- length(unique(full_data$trial_index))
    n_trials_with_behav <- if("has_behavioral_data" %in% names(full_data)) {
      sum(full_data %>% group_by(trial_index) %>% summarise(has_behav = any(has_behavioral_data == 1, na.rm = TRUE), .groups = "drop") %>% pull(has_behav))
    } else 0
    
    # Quality metrics
    has_quality <- "overall_quality" %in% names(full_data)
    mean_quality <- if(has_quality) mean(full_data$overall_quality, na.rm = TRUE) else NA_real_
    
    # Count runs
    n_runs <- if("run" %in% names(full_data)) {
      length(unique(full_data$run[!is.na(full_data$run)]))
    } else NA_integer_
    
    merged_trials[[i]] <- data.frame(
      file = basename(flat_files_merged[i]),
      sub = sub,
      task = task,
      stage = "Merged_Flat",
      n_trials = n_trials_total,
      n_trials_with_behav = n_trials_with_behav,
      n_samples = nrow(full_data),
      n_runs = n_runs,
      mean_quality = mean_quality,
      stringsAsFactors = FALSE
    )
  }, error = function(e) {
    cat("  Warning: Could not read", flat_files_merged[i], ":", e$message, "\n")
    NULL
  })
}

merged_trials_df <- bind_rows(merged_trials[!sapply(merged_trials, is.null)])

cat("  Total merged trials:", sum(merged_trials_df$n_trials), "\n")
cat("  Trials with behavioral data:", sum(merged_trials_df$n_trials_with_behav), "\n\n")

# ============================================================================
# STAGE 3: ANALYSIS-READY FILES (after quality filtering)
# ============================================================================

cat("STAGE 3: Loading analysis-ready files...\n")

pupil_file <- file.path(analysis_ready_dir, "BAP_analysis_ready_PUPIL.csv")
behav_file <- file.path(analysis_ready_dir, "BAP_analysis_ready_BEHAVIORAL.csv")

if (!file.exists(pupil_file) || !file.exists(behav_file)) {
  cat("  ⚠ Analysis-ready files not found. Run feature extraction first.\n")
  analysis_ready_df <- data.frame(
    sub = character(0),
    task = character(0),
    stage = character(0),
    n_trials = integer(0),
    stringsAsFactors = FALSE
  )
} else {
  pupil_data <- read_csv(pupil_file, show_col_types = FALSE)
  behav_data <- read_csv(behav_file, show_col_types = FALSE)
  
  # Count trials by subject and task
  # Check which columns exist - analysis-ready files may have different quality column names
  has_overall_quality <- "overall_quality" %in% names(pupil_data)
  has_quality_iti <- "quality_iti" %in% names(pupil_data)
  has_quality_prestim <- "quality_prestim" %in% names(pupil_data)
  has_total_auc <- "total_auc" %in% names(pupil_data)
  has_cognitive_auc <- "cognitive_auc" %in% names(pupil_data)
  
  # Calculate mean quality - try different column names
  if (has_overall_quality) {
    quality_expr <- quote(mean(overall_quality, na.rm = TRUE))
  } else if (has_quality_iti && has_quality_prestim) {
    # Use mean of ITI and prestim quality as proxy
    quality_expr <- quote(mean((quality_iti + quality_prestim) / 2, na.rm = TRUE))
  } else if (has_quality_iti) {
    quality_expr <- quote(mean(quality_iti, na.rm = TRUE))
  } else if (has_quality_prestim) {
    quality_expr <- quote(mean(quality_prestim, na.rm = TRUE))
  } else {
    quality_expr <- quote(NA_real_)
  }
  
  analysis_ready_summary <- pupil_data %>%
    group_by(subject_id, task) %>%
    summarise(
      n_trials = n(),
      n_runs = n_distinct(run, na.rm = TRUE),
      mean_quality = eval(quality_expr),
      has_total_auc = if(has_total_auc) sum(!is.na(total_auc)) else 0L,
      has_cognitive_auc = if(has_cognitive_auc) sum(!is.na(cognitive_auc)) else 0L,
      .groups = "drop"
    ) %>%
    rename(sub = subject_id)
  
  analysis_ready_df <- analysis_ready_summary %>%
    mutate(stage = "Analysis_Ready")
  
  cat("  Total analysis-ready trials:", nrow(pupil_data), "\n")
  cat("  Unique subject-task combinations:", nrow(analysis_ready_summary), "\n\n")
}

# ============================================================================
# CREATE COMPARISON TABLES
# ============================================================================

cat("Creating comparison tables...\n")

# Combine all stages
all_stages <- bind_rows(
  raw_trials_df %>% select(sub, task, stage, n_trials),
  merged_trials_df %>% select(sub, task, stage, n_trials),
  analysis_ready_df %>% select(sub, task, stage, n_trials)
)

# Create summary by subject-task
summary_by_sub_task <- all_stages %>%
  group_by(sub, task) %>%
  summarise(
    raw_trials = sum(n_trials[stage == "Raw_Flat"], na.rm = TRUE),
    merged_trials = sum(n_trials[stage == "Merged_Flat"], na.rm = TRUE),
    analysis_ready_trials = sum(n_trials[stage == "Analysis_Ready"], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    dropped_at_merge = raw_trials - merged_trials,
    dropped_at_qc = merged_trials - analysis_ready_trials,
    total_dropped = raw_trials - analysis_ready_trials,
    pct_retained = round(100 * analysis_ready_trials / raw_trials, 1)
  ) %>%
  arrange(sub, task)

# Add run counts from merged files
run_counts <- merged_trials_df %>%
  group_by(sub, task) %>%
  summarise(n_runs = n(), .groups = "drop")

summary_by_sub_task <- summary_by_sub_task %>%
  left_join(run_counts, by = c("sub", "task"))

# Summary by task
summary_by_task <- summary_by_sub_task %>%
  group_by(task) %>%
  summarise(
    n_subjects = n(),
    total_raw_trials = sum(raw_trials, na.rm = TRUE),
    total_merged_trials = sum(merged_trials, na.rm = TRUE),
    total_analysis_ready_trials = sum(analysis_ready_trials, na.rm = TRUE),
    total_dropped_at_merge = sum(dropped_at_merge, na.rm = TRUE),
    total_dropped_at_qc = sum(dropped_at_qc, na.rm = TRUE),
    total_dropped = sum(total_dropped, na.rm = TRUE),
    overall_pct_retained = round(100 * sum(analysis_ready_trials, na.rm = TRUE) / sum(raw_trials, na.rm = TRUE), 1),
    .groups = "drop"
  )

# Overall summary
overall_summary <- summary_by_task %>%
  summarise(
    total_subjects = sum(n_subjects),
    total_raw_trials = sum(total_raw_trials),
    total_merged_trials = sum(total_merged_trials),
    total_analysis_ready_trials = sum(total_analysis_ready_trials),
    total_dropped_at_merge = sum(total_dropped_at_merge),
    total_dropped_at_qc = sum(total_dropped_at_qc),
    total_dropped = sum(total_dropped),
    overall_pct_retained = round(100 * total_analysis_ready_trials / total_raw_trials, 1)
  )

# ============================================================================
# GENERATE REPORT
# ============================================================================

cat("Generating detailed report...\n")

sink(report_file)

cat("=================================================================\n")
cat("PUPILLOMETRY TRIAL FLOW REPORT\n")
cat("=================================================================\n\n")
cat("Generated at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("This report shows trial counts at each preprocessing stage:\n")
cat("  1. Raw Flat Files: Trials from MATLAB pipeline (before behavioral merge)\n")
cat("  2. Merged Flat Files: Trials after merging with behavioral data\n")
cat("  3. Analysis-Ready Files: Trials after quality filtering (80% threshold)\n\n")

cat("=================================================================\n")
cat("OVERALL SUMMARY\n")
cat("=================================================================\n\n")

cat("Total Subjects:", overall_summary$total_subjects, "\n")
cat("Total Raw Trials:", overall_summary$total_raw_trials, "\n")
cat("Total Merged Trials:", overall_summary$total_merged_trials, "\n")
cat("Total Analysis-Ready Trials:", overall_summary$total_analysis_ready_trials, "\n")
cat("Trials Dropped at Merge Stage:", overall_summary$total_dropped_at_merge, "\n")
cat("Trials Dropped at QC Stage:", overall_summary$total_dropped_at_qc, "\n")
cat("Total Trials Dropped:", overall_summary$total_dropped, "\n")
cat("Overall Retention Rate:", overall_summary$overall_pct_retained, "%\n\n")

cat("=================================================================\n")
cat("SUMMARY BY TASK\n")
cat("=================================================================\n\n")

for (i in 1:nrow(summary_by_task)) {
  row <- summary_by_task[i, ]
  cat("Task:", row$task, "\n")
  cat("  Subjects:", row$n_subjects, "\n")
  cat("  Raw Trials:", row$total_raw_trials, "\n")
  cat("  Merged Trials:", row$total_merged_trials, "\n")
  cat("  Analysis-Ready Trials:", row$total_analysis_ready_trials, "\n")
  cat("  Dropped at Merge:", row$total_dropped_at_merge, "\n")
  cat("  Dropped at QC:", row$total_dropped_at_qc, "\n")
  cat("  Total Dropped:", row$total_dropped, "\n")
  cat("  Retention Rate:", row$overall_pct_retained, "%\n\n")
}

cat("=================================================================\n")
cat("DETAILED BREAKDOWN BY SUBJECT AND TASK\n")
cat("=================================================================\n\n")

cat("Columns:\n")
cat("  - sub: Subject ID\n")
cat("  - task: Task (ADT or VDT)\n")
cat("  - n_runs: Number of runs for this subject-task\n")
cat("  - raw_trials: Trials in raw flat files\n")
cat("  - merged_trials: Trials after behavioral merge\n")
cat("  - analysis_ready_trials: Trials after quality filtering\n")
cat("  - dropped_at_merge: Trials lost during merge\n")
cat("  - dropped_at_qc: Trials lost during QC filtering\n")
cat("  - total_dropped: Total trials dropped\n")
cat("  - pct_retained: Percentage of raw trials retained\n\n")

# Print detailed table
for (i in 1:nrow(summary_by_sub_task)) {
  row <- summary_by_sub_task[i, ]
  cat(sprintf("%-8s %-4s %3d runs: %4d raw → %4d merged → %4d ready | Dropped: %3d (merge) + %3d (QC) = %3d total | Retained: %5.1f%%\n",
              row$sub, row$task, 
              ifelse(is.na(row$n_runs), 0, row$n_runs),
              row$raw_trials, row$merged_trials, row$analysis_ready_trials,
              row$dropped_at_merge, row$dropped_at_qc, row$total_dropped,
              row$pct_retained))
}

cat("\n=================================================================\n")
cat("STAGE-BY-STAGE BREAKDOWN\n")
cat("=================================================================\n\n")

cat("STAGE 1: RAW FLAT FILES\n")
cat("  Source: MATLAB pipeline output\n")
cat("  Total Files:", length(flat_files), "\n")
cat("  Total Trials:", sum(raw_trials_df$n_trials), "\n")
cat("  Total Samples:", sum(raw_trials_df$n_samples), "\n\n")

cat("STAGE 2: MERGED FLAT FILES\n")
cat("  Source: Raw flat files + behavioral data merge\n")
cat("  Total Files:", length(flat_files_merged), "\n")
cat("  Total Trials:", sum(merged_trials_df$n_trials), "\n")
cat("  Trials with Behavioral Data:", sum(merged_trials_df$n_trials_with_behav), "\n")
cat("  Total Samples:", sum(merged_trials_df$n_samples), "\n")
if (nrow(merged_trials_df) > 0 && !all(is.na(merged_trials_df$mean_quality))) {
  cat("  Mean Quality Score:", round(mean(merged_trials_df$mean_quality, na.rm = TRUE), 3), "\n")
}
cat("  Trials Dropped:", sum(raw_trials_df$n_trials) - sum(merged_trials_df$n_trials), "\n\n")

cat("STAGE 3: ANALYSIS-READY FILES\n")
cat("  Source: Merged flat files after quality filtering (80% threshold)\n")
if (nrow(analysis_ready_df) > 0) {
  cat("  Total Trials:", sum(analysis_ready_df$n_trials), "\n")
  cat("  Unique Subject-Task Combinations:", nrow(analysis_ready_df), "\n")
  cat("  Mean Quality Score:", round(mean(analysis_ready_df$mean_quality, na.rm = TRUE), 3), "\n")
  cat("  Trials with Total AUC:", sum(analysis_ready_df$has_total_auc), "\n")
  cat("  Trials with Cognitive AUC:", sum(analysis_ready_df$has_cognitive_auc), "\n")
  cat("  Trials Dropped:", sum(merged_trials_df$n_trials) - sum(analysis_ready_df$n_trials), "\n")
} else {
  cat("  No analysis-ready files found. Run feature extraction first.\n")
}
cat("\n")

cat("=================================================================\n")
cat("QUALITY FILTERING DETAILS\n")
cat("=================================================================\n\n")

cat("Quality Threshold: 80% valid data per trial\n")
cat("This means trials with < 80% valid pupil samples are excluded.\n\n")

if (nrow(analysis_ready_df) > 0) {
  cat("Quality Distribution in Analysis-Ready Data:\n")
  quality_dist <- analysis_ready_df %>%
    summarise(
      min_quality = min(mean_quality, na.rm = TRUE),
      q25_quality = quantile(mean_quality, 0.25, na.rm = TRUE),
      median_quality = median(mean_quality, na.rm = TRUE),
      mean_quality = mean(mean_quality, na.rm = TRUE),
      q75_quality = quantile(mean_quality, 0.75, na.rm = TRUE),
      max_quality = max(mean_quality, na.rm = TRUE)
    )
  
  cat("  Min:", round(quality_dist$min_quality, 3), "\n")
  cat("  25th percentile:", round(quality_dist$q25_quality, 3), "\n")
  cat("  Median:", round(quality_dist$median_quality, 3), "\n")
  cat("  Mean:", round(quality_dist$mean_quality, 3), "\n")
  cat("  75th percentile:", round(quality_dist$q75_quality, 3), "\n")
  cat("  Max:", round(quality_dist$max_quality, 3), "\n\n")
}

cat("=================================================================\n")
cat("END OF REPORT\n")
cat("=================================================================\n")

sink()

# ============================================================================
# SAVE CSV FILES
# ============================================================================

cat("Saving CSV files...\n")

# Summary CSV
write_csv(summary_by_sub_task, csv_file)
cat("  Saved summary to:", csv_file, "\n")

# Detailed CSV with all stages
# Note: n_samples is NA for Analysis_Ready (trial-level data, not sample-level)
# Note: mean_quality is NA for Raw_Flat (quality metrics not yet calculated)
detailed_df <- bind_rows(
  raw_trials_df %>% select(sub, task, stage, n_trials, n_samples, n_runs) %>% 
    mutate(mean_quality = NA_real_),
  merged_trials_df %>% select(sub, task, stage, n_trials, n_samples, n_runs, mean_quality),
  analysis_ready_df %>% select(sub, task, stage, n_trials, n_runs, mean_quality) %>%
    mutate(n_samples = NA_integer_)  # Trial-level data, no sample count
) %>%
  arrange(sub, task, stage)

write_csv(detailed_df, detailed_csv_file)
cat("  Saved detailed data to:", detailed_csv_file, "\n")

# ============================================================================
# COMPLETION
# ============================================================================

cat("\n=================================================================\n")
cat("REPORT GENERATION COMPLETE\n")
cat("=================================================================\n")
cat("Report saved to:", report_file, "\n")
cat("Summary CSV saved to:", csv_file, "\n")
cat("Detailed CSV saved to:", detailed_csv_file, "\n\n")

cat("To view the report:\n")
cat("  cat", report_file, "\n")
cat("  or open in a text editor\n\n")

