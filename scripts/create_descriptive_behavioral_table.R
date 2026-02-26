#!/usr/bin/env Rscript
# Create descriptive behavioral table from unthresholded data
# This replicates the logic from ddm_refit_with_new_threshold.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

# Load logging and validation utilities
source("R/utils/logging_validation.R")

# Configuration
PROBE_DUR_SEC <- 0.1
GRIP_RELAX_SEC <- 0.25
PROBE_ONSET_TO_PROMPT_SEC <- PROBE_DUR_SEC + GRIP_RELAX_SEC  # 0.35

# Get run directory from command line or use default
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 0) {
  run_dir <- args[1]
} else {
  runs_base <- "output/ddm_refits/runs"
  if (dir.exists(runs_base)) {
    runs <- list.dirs(runs_base, full.names = FALSE, recursive = FALSE)
    if (length(runs) > 0) {
      run_dir <- file.path(runs_base, sort(runs, decreasing = TRUE)[1])
    } else {
      run_dir <- "output/ddm_refits/runs/20260204_214842"
    }
  } else {
    stop("Runs directory not found")
  }
}

cat("Run directory:", run_dir, "\n")

# Find input file
input_candidates <- c(
  "output/rt_threshold_analysis/ddm_ready_data_unthresholded.csv",
  "data/ddm_ready_data_unthresholded.csv"
)
input_file <- NULL
for (candidate in input_candidates) {
  if (file.exists(candidate)) {
    input_file <- candidate
    break
  }
}

if (is.null(input_file)) {
  stop("Input file not found")
}

cat("Input file:", input_file, "\n")

# Load and standardize data
df_raw <- read_csv(input_file, show_col_types = FALSE)

# Standardize (simplified version of standardize_ddm_ready)
df <- df_raw

# RT columns
if ("rt_cue_locked" %in% names(df)) {
  df$rt_cue <- df$rt_cue_locked
} else if ("rt" %in% names(df)) {
  df$rt_cue <- df$rt
} else {
  stop("RT column not found")
}

if ("rt_probe_onset_locked" %in% names(df)) {
  df$rt_probe_onset <- df$rt_probe_onset_locked
} else {
  df$rt_probe_onset <- df$rt_cue + PROBE_ONSET_TO_PROMPT_SEC
}

# Factor standardization
df$subject_id <- as.character(df$subject_id)
df$task <- tolower(as.character(df$task))
if (any(grepl("^a", df$task, ignore.case = TRUE))) {
  df$task <- ifelse(grepl("^a", df$task, ignore.case = TRUE), "ADT", "VDT")
} else if (any(grepl("^v", df$task, ignore.case = TRUE))) {
  df$task <- ifelse(grepl("^v", df$task, ignore.case = TRUE), "VDT", "ADT")
}
df$task <- factor(df$task, levels = c("ADT", "VDT"))

df$effort_condition <- tolower(as.character(df$effort_condition))
df$effort_condition <- factor(df$effort_condition, levels = c("low", "high"))

# Difficulty standardization
if ("difficulty_level" %in% names(df)) {
  if (is.numeric(df$difficulty_level)) {
    df$difficulty_3 <- case_when(
      df$difficulty_level == 0 ~ "Standard",
      df$difficulty_level %in% c(1, 2) ~ "Hard",
      df$difficulty_level %in% c(3, 4) ~ "Easy",
      TRUE ~ "Standard"
    )
  } else {
    df$difficulty_3 <- as.character(df$difficulty_level)
    df$difficulty_3 <- case_when(
      grepl("standard|baseline|0", df$difficulty_3, ignore.case = TRUE) ~ "Standard",
      grepl("easy|3|4", df$difficulty_3, ignore.case = TRUE) ~ "Easy",
      grepl("hard|1|2", df$difficulty_3, ignore.case = TRUE) ~ "Hard",
      TRUE ~ "Standard"
    )
  }
} else {
  stop("difficulty_level column not found")
}
df$difficulty_3 <- factor(df$difficulty_3, levels = c("Standard", "Hard", "Easy"))

# Choice binary
if ("choice_binary" %in% names(df)) {
  df$choice_binary <- as.integer(df$choice_binary)
}

# Create base clean dataset (same as main script)
ddm_base <- df %>%
  filter(
    rt_cue > 0,
    choice_binary %in% c(0L, 1L),
    !is.na(subject_id),
    !is.na(task),
    !is.na(effort_condition),
    !is.na(difficulty_3)
  )

cat("Base clean dataset:", nrow(ddm_base), "trials\n")

# Compute descriptive statistics
counts_by_condition <- ddm_base %>%
  group_by(task, effort_condition, difficulty_3) %>%
  summarise(
    n_trials = n(),
    n_subjects = n_distinct(subject_id),
    .groups = "drop"
  )

choice_props <- ddm_base %>%
  group_by(task, effort_condition, difficulty_3) %>%
  summarise(
    prop_different = mean(choice_binary == 1L, na.rm = TRUE),  # choice_binary == 1 means resp_is_diff == 1 (different)
    prop_same = mean(choice_binary == 0L, na.rm = TRUE),      # choice_binary == 0 means resp_is_diff == 0 (same)
    n_different = sum(choice_binary == 1L, na.rm = TRUE),
    n_same = sum(choice_binary == 0L, na.rm = TRUE),
    .groups = "drop"
  )

# Validation: prop_same + prop_different should equal 1
stopifnot(all(abs(choice_props$prop_same + choice_props$prop_different - 1) < 1e-8))

rt_cue_quantiles <- ddm_base %>%
  group_by(task, effort_condition, difficulty_3) %>%
  summarise(
    rt_cue_min = min(rt_cue, na.rm = TRUE),
    rt_cue_q25 = quantile(rt_cue, 0.25, na.rm = TRUE),
    rt_cue_median = median(rt_cue, na.rm = TRUE),
    rt_cue_q75 = quantile(rt_cue, 0.75, na.rm = TRUE),
    rt_cue_max = max(rt_cue, na.rm = TRUE),
    .groups = "drop"
  )

rt_probe_quantiles <- ddm_base %>%
  group_by(task, effort_condition, difficulty_3) %>%
  summarise(
    rt_probe_onset_min = min(rt_probe_onset, na.rm = TRUE),
    rt_probe_onset_q25 = quantile(rt_probe_onset, 0.25, na.rm = TRUE),
    rt_probe_onset_median = median(rt_probe_onset, na.rm = TRUE),
    rt_probe_onset_q75 = quantile(rt_probe_onset, 0.75, na.rm = TRUE),
    rt_probe_onset_max = max(rt_probe_onset, na.rm = TRUE),
    .groups = "drop"
  )

# Combine all tables
descriptive_df <- counts_by_condition %>%
  left_join(choice_props, by = c("task", "effort_condition", "difficulty_3")) %>%
  left_join(rt_cue_quantiles, by = c("task", "effort_condition", "difficulty_3")) %>%
  left_join(rt_probe_quantiles, by = c("task", "effort_condition", "difficulty_3")) %>%
  arrange(task, effort_condition, difficulty_3) %>%
  mutate(
    data_source = "ddm_ready_data_unthresholded.csv",
    run_id = basename(run_dir)
  )

# Write output
tables_dir <- file.path(run_dir, "tables")
if (!dir.exists(tables_dir)) dir.create(tables_dir, recursive = TRUE)

output_file <- file.path(tables_dir, "descriptive_behavioral_by_condition.csv")
write_csv(descriptive_df, output_file)

cat("\n✓ Created:", output_file, "\n")
cat("  Rows:", nrow(descriptive_df), "\n")
cat("  Columns:", ncol(descriptive_df), "\n")
cat("\nPreview:\n")
print(head(descriptive_df, 3))
