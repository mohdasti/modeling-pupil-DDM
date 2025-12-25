#!/usr/bin/env Rscript

# Analyze a single task log file to compute event intervals

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

# File to analyze
log_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data/sub-BAP103/ses-3/InsideScanner/subjectBAP103_Aoddball_session3_run5_7_8_13_30_logP.txt"

cat("=== TASK LOG FILE ANALYSIS ===\n\n")

# 1. File info
cat("1. FILE INFO:\n")
cat("   Path:", log_file, "\n")

# Read file to get dimensions
lines <- readLines(log_file, warn = FALSE)
cat("   Total lines:", length(lines), "\n")

# Find header line (first line with "Trial#" or "TrialST")
header_line_idx <- NULL
for (i in seq_along(lines)) {
  if (grepl("Trial#|TrialST", lines[i])) {
    header_line_idx <- i
    break
  }
}

if (is.null(header_line_idx)) {
  stop("Cannot find header line")
}

cat("   Header line:", header_line_idx, "\n")
cat("   Data rows:", length(lines) - header_line_idx, "\n\n")

# 2. Print header and first 3 data lines
cat("2. HEADER LINE:\n")
cat(lines[header_line_idx], "\n\n")

cat("3. FIRST 3 DATA LINES:\n")
data_start <- header_line_idx + 1
for (i in data_start:min(data_start + 2, length(lines))) {
  cat(lines[i], "\n")
}
cat("\n")

# 3. Read into dataframe
cat("4. READING DATA...\n")
log_data <- read_delim(
  log_file,
  delim = "\t",
  skip = header_line_idx - 1,
  col_names = TRUE,
  show_col_types = FALSE,
  comment = "%"
)

# Trim whitespace from column names
names(log_data) <- trimws(names(log_data))

cat("   Columns:", ncol(log_data), "\n")
cat("   Rows:", nrow(log_data), "\n\n")

# Check required columns
required_cols <- c("TrialST", "blankST", "fixST", "fixOFSTP", "A/V_ST", "A/V_CT")
missing_cols <- setdiff(required_cols, names(log_data))
if (length(missing_cols) > 0) {
  cat("   ⚠ Missing columns:", paste(missing_cols, collapse = ", "), "\n")
  cat("   Available columns:", paste(names(log_data), collapse = ", "), "\n\n")
}

# 4. Compute intervals
cat("5. COMPUTING INTERVALS:\n\n")

# Convert to numeric (handle column name with forward slash)
log_data <- log_data %>%
  mutate(
    TrialST = as.numeric(.data[["TrialST"]]),
    blankST = as.numeric(.data[["blankST"]]),
    fixST = as.numeric(.data[["fixST"]]),
    fixOFSTP = as.numeric(.data[["fixOFSTP"]]),
    A_V_ST = as.numeric(.data[["A/V_ST"]]),
    A_V_CT = as.numeric(.data[["A/V_CT"]])
  )

# Compute intervals
intervals <- log_data %>%
  filter(
    !is.na(TrialST),
    !is.na(blankST),
    !is.na(fixST),
    !is.na(fixOFSTP),
    !is.na(A_V_ST),
    !is.na(A_V_CT)
  ) %>%
  mutate(
    blankST_minus_TrialST = blankST - TrialST,
    fixST_minus_blankST = fixST - blankST,
    fixOFSTP_minus_fixST = fixOFSTP - fixST,
    A_V_ST_minus_fixOFSTP = A_V_ST - fixOFSTP,
    A_V_CT_minus_A_V_ST = A_V_CT - A_V_ST
  )

cat("   Valid trials:", nrow(intervals), "\n\n")

# 5. Print mean/median
cat("6. INTERVAL STATISTICS:\n\n")

interval_stats <- intervals %>%
  summarise(
    blankST_minus_TrialST_mean = mean(blankST_minus_TrialST, na.rm = TRUE),
    blankST_minus_TrialST_median = median(blankST_minus_TrialST, na.rm = TRUE),
    fixST_minus_blankST_mean = mean(fixST_minus_blankST, na.rm = TRUE),
    fixST_minus_blankST_median = median(fixST_minus_blankST, na.rm = TRUE),
    fixOFSTP_minus_fixST_mean = mean(fixOFSTP_minus_fixST, na.rm = TRUE),
    fixOFSTP_minus_fixST_median = median(fixOFSTP_minus_fixST, na.rm = TRUE),
    A_V_ST_minus_fixOFSTP_mean = mean(A_V_ST_minus_fixOFSTP, na.rm = TRUE),
    A_V_ST_minus_fixOFSTP_median = median(A_V_ST_minus_fixOFSTP, na.rm = TRUE),
    A_V_CT_minus_A_V_ST_mean = mean(A_V_CT_minus_A_V_ST, na.rm = TRUE),
    A_V_CT_minus_A_V_ST_median = median(A_V_CT_minus_A_V_ST, na.rm = TRUE)
  )

cat("Interval                    | Mean (s)  | Median (s) | Expected (s)\n")
cat("----------------------------|-----------|------------|-------------\n")
cat(sprintf("blankST - TrialST         | %8.3f  | %8.3f   | %8.3f\n",
  interval_stats$blankST_minus_TrialST_mean,
  interval_stats$blankST_minus_TrialST_median,
  3.00))
cat(sprintf("fixST - blankST           | %8.3f  | %8.3f   | %8.3f\n",
  interval_stats$fixST_minus_blankST_mean,
  interval_stats$fixST_minus_blankST_median,
  0.25))
cat(sprintf("fixOFSTP - fixST          | %8.3f  | %8.3f   | %8.3f\n",
  interval_stats$fixOFSTP_minus_fixST_mean,
  interval_stats$fixOFSTP_minus_fixST_median,
  0.50))
cat(sprintf("A/V_ST - fixOFSTP         | %8.3f  | %8.3f   | %8.3f\n",
  interval_stats$A_V_ST_minus_fixOFSTP_mean,
  interval_stats$A_V_ST_minus_fixOFSTP_median,
  0.00))
cat(sprintf("A/V_CT - A/V_ST           | %8.3f  | %8.3f   | %8.3f\n",
  interval_stats$A_V_CT_minus_A_V_ST_mean,
  interval_stats$A_V_CT_minus_A_V_ST_median,
  0.70))
cat("\n")

# Print per-trial intervals for first few trials
cat("7. PER-TRIAL INTERVALS (first 5 trials):\n\n")
intervals %>%
  select(`Trial#`, blankST_minus_TrialST, fixST_minus_blankST, fixOFSTP_minus_fixST,
         A_V_ST_minus_fixOFSTP, A_V_CT_minus_A_V_ST) %>%
  head(5) %>%
  print()

cat("\n=== ANALYSIS COMPLETE ===\n")

