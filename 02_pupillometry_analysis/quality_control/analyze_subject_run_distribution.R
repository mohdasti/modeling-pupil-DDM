#!/usr/bin/env Rscript

# ============================================================================
# Subject Run Distribution Analysis
# ============================================================================
# Analyzes the distribution of subjects by number of runs per task
# Helps determine if the ≥5 runs filtering threshold is appropriate
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(tidyr)
})

cat("=================================================================\n")
cat("SUBJECT RUN DISTRIBUTION ANALYSIS\n")
cat("=================================================================\n")
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# ============================================================================
# CONFIGURATION
# ============================================================================

processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
analysis_ready_dir <- "data/analysis_ready"
output_dir <- "02_pupillometry_analysis/quality_control/output"

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# LOAD DATA
# ============================================================================

cat("Loading data...\n")

# Option 1: Use merged flat files (most complete data)
flat_files_merged <- list.files(processed_dir, pattern = "_flat_merged\\.csv$", full.names = TRUE)

if(length(flat_files_merged) == 0) {
  cat("  No merged files found, trying regular flat files...\n")
  flat_files_merged <- list.files(processed_dir, pattern = "_flat\\.csv$", full.names = TRUE)
}

cat("  Found", length(flat_files_merged), "flat files\n")

# Load and count runs per subject-task
run_counts_list <- vector("list", length(flat_files_merged))

for (i in seq_along(flat_files_merged)) {
  tryCatch({
    data <- read_csv(flat_files_merged[i], show_col_types = FALSE)
    
    # Get subject and task
    if("sub" %in% names(data)) {
      sub <- unique(data$sub[!is.na(data$sub)])[1]
    } else {
      file_info <- strsplit(basename(flat_files_merged[i]), "_")[[1]]
      sub <- file_info[1]
    }
    
    if("task" %in% names(data) && !all(is.na(data$task))) {
      task <- unique(data$task[!is.na(data$task)])[1]
    } else if(grepl("_ADT_|_ADT\\.", basename(flat_files_merged[i]))) {
      task <- "ADT"
    } else if(grepl("_VDT_|_VDT\\.", basename(flat_files_merged[i]))) {
      task <- "VDT"
    } else {
      task <- "Unknown"
    }
    
    # Count unique runs
    n_runs <- if("run" %in% names(data)) {
      length(unique(data$run[!is.na(data$run)]))
    } else {
      NA_integer_
    }
    
    # Count trials
    n_trials <- if("trial_index" %in% names(data)) {
      length(unique(data$trial_index[!is.na(data$trial_index)]))
    } else {
      NA_integer_
    }
    
    if(!is.na(n_runs) && !is.na(sub) && task != "Unknown") {
      run_counts_list[[i]] <- data.frame(
        sub = sub,
        task = task,
        n_runs = n_runs,
        n_trials = n_trials,
        stringsAsFactors = FALSE
      )
    }
  }, error = function(e) {
    cat("  Warning: Could not read", flat_files_merged[i], ":", e$message, "\n")
    NULL
  })
}

run_counts_df <- bind_rows(run_counts_list[!sapply(run_counts_list, is.null)])

cat("  Loaded data for", nrow(run_counts_df), "subject-task combinations\n\n")

# ============================================================================
# CREATE SUMMARY STATISTICS
# ============================================================================

cat("Creating summary statistics...\n")

# Summary by task
summary_by_task <- run_counts_df %>%
  group_by(task) %>%
  summarise(
    n_subjects = n(),
    mean_runs = mean(n_runs, na.rm = TRUE),
    median_runs = median(n_runs, na.rm = TRUE),
    min_runs = min(n_runs, na.rm = TRUE),
    max_runs = max(n_runs, na.rm = TRUE),
    .groups = "drop"
  )

cat("\nSummary by Task:\n")
print(summary_by_task)

# Distribution of runs
run_distribution <- run_counts_df %>%
  group_by(task, n_runs) %>%
  summarise(n_subjects = n(), .groups = "drop") %>%
  arrange(task, n_runs)

cat("\nRun Distribution:\n")
print(run_distribution)

# Calculate how many subjects would be excluded with different thresholds
threshold_analysis <- expand_grid(
  task = unique(run_counts_df$task),
  threshold = 1:10
) %>%
  left_join(
    run_counts_df %>%
      group_by(task, threshold = n_runs) %>%
      summarise(n_subjects = n(), .groups = "drop") %>%
      complete(task, threshold = 1:10, fill = list(n_subjects = 0)),
    by = c("task", "threshold")
  ) %>%
  group_by(task, threshold) %>%
  summarise(
    n_subjects_with_runs = sum(n_subjects[threshold <= n_runs], na.rm = TRUE),
    n_subjects_excluded = sum(n_subjects[threshold > n_runs], na.rm = TRUE),
    pct_excluded = round(100 * n_subjects_excluded / sum(n_subjects), 1),
    .groups = "drop"
  )

cat("\nThreshold Analysis (how many subjects excluded at each threshold):\n")
print(threshold_analysis %>% filter(threshold <= 6))

# ============================================================================
# CREATE PLOTS
# ============================================================================

cat("\nCreating plots...\n")

# Plot 1: Distribution of subjects by number of runs (bar plot)
plot1 <- run_counts_df %>%
  mutate(n_runs_cat = factor(ifelse(n_runs >= 5, "5+", as.character(n_runs)),
                             levels = c("1", "2", "3", "4", "5+"))) %>%
  group_by(task, n_runs_cat) %>%
  summarise(n_subjects = n(), .groups = "drop") %>%
  ggplot(aes(x = n_runs_cat, y = n_subjects, fill = task)) +
  geom_bar(stat = "identity", position = "dodge", alpha = 0.8) +
  geom_text(aes(label = n_subjects), position = position_dodge(width = 0.9), 
            vjust = -0.5, size = 4, fontface = "bold") +
  facet_wrap(~ task, ncol = 2) +
  labs(
    title = "Distribution of Subjects by Number of Runs",
    subtitle = "Separate panels for ADT and VDT tasks",
    x = "Number of Runs",
    y = "Number of Subjects",
    fill = "Task"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 16, face = "bold"),
    plot.subtitle = element_text(size = 12),
    axis.title = element_text(size = 12, face = "bold"),
    axis.text = element_text(size = 11),
    strip.text = element_text(size = 12, face = "bold"),
    legend.position = "none"
  ) +
  scale_fill_manual(values = c("ADT" = "#4472C4", "VDT" = "#ED7D31"))

ggsave(file.path(output_dir, "subject_run_distribution_barplot.png"), 
       plot1, width = 10, height = 6, dpi = 300)
cat("  Saved: subject_run_distribution_barplot.png\n")

# Plot 2: Histogram showing exact run counts
plot2 <- run_counts_df %>%
  ggplot(aes(x = n_runs, fill = task)) +
  geom_histogram(binwidth = 1, alpha = 0.7, position = "identity") +
  geom_vline(xintercept = 5, linetype = "dashed", color = "red", linewidth = 1.2) +
  annotate("text", x = 5.3, y = Inf, label = "Current\nthreshold (≥5)", 
           hjust = 0, vjust = 1.5, color = "red", fontface = "bold", size = 4) +
  facet_wrap(~ task, ncol = 2, scales = "free_y") +
  labs(
    title = "Histogram of Run Counts per Subject-Task",
    subtitle = "Red dashed line shows current filtering threshold (≥5 runs)",
    x = "Number of Runs",
    y = "Number of Subject-Task Combinations",
    fill = "Task"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 16, face = "bold"),
    plot.subtitle = element_text(size = 12),
    axis.title = element_text(size = 12, face = "bold"),
    axis.text = element_text(size = 11),
    strip.text = element_text(size = 12, face = "bold"),
    legend.position = "bottom"
  ) +
  scale_fill_manual(values = c("ADT" = "#4472C4", "VDT" = "#ED7D31")) +
  scale_x_continuous(breaks = 1:10)

ggsave(file.path(output_dir, "subject_run_distribution_histogram.png"), 
       plot2, width = 10, height = 6, dpi = 300)
cat("  Saved: subject_run_distribution_histogram.png\n")

# Plot 3: Threshold analysis - how many subjects excluded at each threshold
plot3 <- threshold_analysis %>%
  filter(threshold <= 6) %>%
  ggplot(aes(x = threshold, y = pct_excluded, color = task)) +
  geom_line(linewidth = 1.2, alpha = 0.8) +
  geom_point(size = 3, alpha = 0.8) +
  geom_vline(xintercept = 5, linetype = "dashed", color = "red", linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "solid", color = "grey50") +
  labs(
    title = "Percentage of Subjects Excluded at Different Run Thresholds",
    subtitle = "Red dashed line shows current threshold (≥5 runs)",
    x = "Minimum Number of Runs Required",
    y = "Percentage of Subjects Excluded",
    color = "Task"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 16, face = "bold"),
    plot.subtitle = element_text(size = 12),
    axis.title = element_text(size = 12, face = "bold"),
    axis.text = element_text(size = 11),
    legend.position = "bottom"
  ) +
  scale_color_manual(values = c("ADT" = "#4472C4", "VDT" = "#ED7D31")) +
  scale_x_continuous(breaks = 1:6) +
  scale_y_continuous(breaks = seq(0, 100, by = 10))

ggsave(file.path(output_dir, "subject_exclusion_by_threshold.png"), 
       plot3, width = 10, height = 6, dpi = 300)
cat("  Saved: subject_exclusion_by_threshold.png\n")

# Plot 4: Combined view - subjects by run count with current threshold highlighted
plot4 <- run_counts_df %>%
  mutate(n_runs_cat = factor(ifelse(n_runs >= 5, "5+", as.character(n_runs)),
                             levels = c("1", "2", "3", "4", "5+"))) %>%
  group_by(task, n_runs_cat) %>%
  summarise(n_subjects = n(), .groups = "drop") %>%
  ggplot(aes(x = n_runs_cat, y = n_subjects, fill = n_runs_cat)) +
  geom_bar(stat = "identity", alpha = 0.8) +
  geom_text(aes(label = n_subjects), vjust = -0.5, size = 4.5, fontface = "bold") +
  facet_wrap(~ task, ncol = 2) +
  labs(
    title = "Subject Count by Number of Runs (Current Threshold: ≥5)",
    subtitle = "Subjects with 5+ runs are included in analysis-ready data",
    x = "Number of Runs",
    y = "Number of Subjects",
    fill = "Runs"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 16, face = "bold"),
    plot.subtitle = element_text(size = 12),
    axis.title = element_text(size = 12, face = "bold"),
    axis.text = element_text(size = 11),
    strip.text = element_text(size = 12, face = "bold"),
    legend.position = "bottom"
  ) +
  scale_fill_manual(
    values = c("1" = "#E74C3C", "2" = "#F39C12", "3" = "#F1C40F", 
               "4" = "#3498DB", "5+" = "#27AE60"),
    labels = c("1" = "1 run", "2" = "2 runs", "3" = "3 runs", 
               "4" = "4 runs", "5+" = "5+ runs (included)")
  )

ggsave(file.path(output_dir, "subject_run_distribution_combined.png"), 
       plot4, width = 10, height = 6, dpi = 300)
cat("  Saved: subject_run_distribution_combined.png\n")

# ============================================================================
# SAVE SUMMARY TABLES
# ============================================================================

cat("\nSaving summary tables...\n")

write_csv(run_distribution, file.path(output_dir, "run_distribution_by_task.csv"))
cat("  Saved: run_distribution_by_task.csv\n")

write_csv(threshold_analysis, file.path(output_dir, "threshold_analysis.csv"))
cat("  Saved: threshold_analysis.csv\n")

# Create detailed summary
detailed_summary <- run_counts_df %>%
  group_by(task, n_runs) %>%
  summarise(
    n_subjects = n(),
    total_trials = sum(n_trials, na.rm = TRUE),
    mean_trials_per_subject = mean(n_trials, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(task, n_runs)

write_csv(detailed_summary, file.path(output_dir, "detailed_run_summary.csv"))
cat("  Saved: detailed_run_summary.csv\n")

# ============================================================================
# PRINT RECOMMENDATIONS
# ============================================================================

cat("\n=================================================================\n")
cat("RECOMMENDATIONS\n")
cat("=================================================================\n\n")

current_threshold <- 5
for(task_name in unique(run_counts_df$task)) {
  task_data <- run_counts_df %>% filter(task == task_name)
  total_subjects <- nrow(task_data)
  subjects_meeting_threshold <- sum(task_data$n_runs >= current_threshold)
  subjects_excluded <- total_subjects - subjects_meeting_threshold
  pct_excluded <- round(100 * subjects_excluded / total_subjects, 1)
  
  cat("Task:", task_name, "\n")
  cat("  Total subjects:", total_subjects, "\n")
  cat("  Subjects with ≥", current_threshold, " runs:", subjects_meeting_threshold, "\n")
  cat("  Subjects excluded:", subjects_excluded, "(", pct_excluded, "%)\n")
  
  # Show distribution
  dist <- table(task_data$n_runs)
  cat("  Distribution:\n")
  for(runs in sort(as.numeric(names(dist)))) {
    cat("    ", runs, " run(s):", dist[as.character(runs)], "subjects\n")
  }
  cat("\n")
}

cat("Considerations:\n")
cat("  - Lower threshold (e.g., ≥3 runs) would include more subjects\n")
cat("  - Higher threshold (e.g., ≥5 runs) ensures more data per subject\n")
cat("  - Consider task-specific thresholds if distributions differ\n")
cat("  - Consider whether subjects with fewer runs have sufficient data for analysis\n\n")

cat("=================================================================\n")
cat("ANALYSIS COMPLETE\n")
cat("=================================================================\n")
cat("Output files saved to:", output_dir, "\n\n")

