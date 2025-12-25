#!/usr/bin/env Rscript

# Diagnose the validate_event_timing.R script to understand the schema mismatch

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(tidyr)
})

cat("=== DIAGNOSE VALIDATE EVENT TIMING SCRIPT ===\n\n")

# The specific file we sanity-checked
test_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data/sub-BAP103/ses-3/InsideScanner/subjectBAP103_Aoddball_session3_run5_7_8_13_30_logP.txt"

# Use the same parsing function from validate_event_timing.R
parse_log_file <- function(file_path) {
  lines <- readLines(file_path, warn = FALSE)
  
  header_line <- NULL
  data_start <- NULL
  
  for (i in seq_along(lines)) {
    if (grepl("Trial#", lines[i]) || grepl("TrialST", lines[i])) {
      header_line <- i
      data_start <- i + 1
      break
    }
  }
  
  if (is.null(header_line)) {
    return(tibble())
  }
  
  header <- str_trim(lines[header_line])
  # FIX: Use TAB separator, not whitespace (to avoid splitting "Hi Grip?" into two columns)
  header_cols <- str_split(header, "\t")[[1]]
  header_cols <- trimws(header_cols)  # Remove any remaining whitespace
  
  filename <- basename(file_path)
  sub_match <- str_extract(filename, "subject(\\d+)")
  subject_id <- if (!is.na(sub_match)) str_extract(sub_match, "\\d+") else NA_character_
  
  task_match <- str_extract(filename, "_(A|V)oddball_")
  task <- if (!is.na(task_match)) {
    if (grepl("Aoddball", task_match)) "ADT" else "VDT"
  } else NA_character_
  
  ses_match <- str_extract(filename, "session(\\d+)")
  session <- if (!is.na(ses_match)) as.integer(str_extract(ses_match, "\\d+")) else NA_integer_
  
  run_match <- str_extract(filename, "_run(\\d+)_")
  run <- if (!is.na(run_match)) as.integer(str_extract(run_match, "\\d+")) else NA_integer_
  
  data_lines <- lines[data_start:length(lines)]
  data_lines <- data_lines[!grepl("^%", data_lines) & nchar(str_trim(data_lines)) > 0]
  
  if (length(data_lines) == 0) {
    return(tibble())
  }
  
  # Parse data - USE TAB SEPARATOR (not whitespace!)
  data_df <- map_dfr(data_lines, function(line) {
    values <- str_split(str_trim(line), "\t")[[1]]  # Split on TAB
    values <- trimws(values)  # Remove any remaining whitespace
    if (length(values) >= length(header_cols)) {
      values <- values[1:length(header_cols)]
      names(values) <- header_cols
      as_tibble(t(values))
    } else {
      tibble()
    }
  })
  
  # Convert numeric columns
  numeric_cols <- c("TrialST", "blankST", "fixST", "A/V_ST", "relaxST", "Resp1ST", "Trial#")
  for (col in numeric_cols) {
    if (col %in% names(data_df)) {
      data_df[[col]] <- as.numeric(data_df[[col]])
    }
  }
  
  data_df %>%
    mutate(
      subject_id = subject_id,
      task = task,
      session = session,
      run = run,
      log_file = basename(file_path)
    )
}

cat("1. PARSING TEST FILE:\n")
cat("   File:", test_file, "\n\n")

parsed_data <- parse_log_file(test_file)

cat("2. DATAFRAME INFO:\n")
cat("   Object name: parsed_data\n")
cat("   Rows:", nrow(parsed_data), "\n")
cat("   Columns:", ncol(parsed_data), "\n\n")

cat("3. COLUMN NAMES:\n")
cat("   ", paste(names(parsed_data), collapse = ", "), "\n\n")

# Check for the required columns
cat("4. REQUIRED COLUMNS CHECK:\n")
required <- c("TrialST", "blankST", "fixST", "A/V_ST")
for (col in required) {
  exists <- col %in% names(parsed_data)
  cat(sprintf("   %-15s: %s\n", col, if(exists) "✓ Found" else "✗ Missing"))
  if (exists) {
    cat(sprintf("      First 3 values: %s\n", 
      paste(head(parsed_data[[col]], 3), collapse = ", ")))
  }
}
cat("\n")

cat("5. FIRST 3 ROWS OF TIMESTAMP COLUMNS:\n")
if (all(required %in% names(parsed_data))) {
  parsed_data %>%
    select(`Trial#`, TrialST, blankST, fixST, `A/V_ST`) %>%
    head(3) %>%
    print()
} else {
  cat("   ⚠ Cannot display - missing columns\n")
  cat("   Available columns:", paste(names(parsed_data), collapse = ", "), "\n")
}
cat("\n")

cat("6. COMPUTING INTERVALS (same as validate_event_timing.R):\n")
if (all(required %in% names(parsed_data))) {
  # Trim whitespace from column names (in case that's the issue)
  names(parsed_data) <- trimws(names(parsed_data))
  
  intervals <- parsed_data %>%
    filter(
      !is.na(TrialST),
      !is.na(blankST),
      !is.na(fixST),
      !is.na(`A/V_ST`)
    ) %>%
    mutate(
      blankST_minus_TrialST = as.numeric(blankST) - as.numeric(TrialST),
      fixST_minus_blankST = as.numeric(fixST) - as.numeric(blankST),
      A_V_ST_minus_fixST = as.numeric(.data[["A/V_ST"]]) - as.numeric(fixST)
    ) %>%
    select(`Trial#`, blankST_minus_TrialST, fixST_minus_blankST, A_V_ST_minus_fixST)
  
  cat("\n   Per-trial intervals:\n")
  print(intervals)
  
  cat("\n   Summary statistics:\n")
  intervals %>%
    summarise(
      blankST_minus_TrialST_mean = mean(blankST_minus_TrialST, na.rm = TRUE),
      blankST_minus_TrialST_median = median(blankST_minus_TrialST, na.rm = TRUE),
      fixST_minus_blankST_mean = mean(fixST_minus_blankST, na.rm = TRUE),
      fixST_minus_blankST_median = median(fixST_minus_blankST, na.rm = TRUE),
      A_V_ST_minus_fixST_mean = mean(A_V_ST_minus_fixST, na.rm = TRUE),
      A_V_ST_minus_fixST_median = median(A_V_ST_minus_fixST, na.rm = TRUE)
    ) %>%
    print()
} else {
  cat("   ⚠ Cannot compute - missing columns\n")
}

cat("\n7. RAW HEADER AND FIRST DATA LINE (for comparison):\n")
lines <- readLines(test_file, warn = FALSE)
header_idx <- which(grepl("Trial#", lines))[1]
if (!is.na(header_idx)) {
  cat("   Header line:", lines[header_idx], "\n")
  cat("   First data line:", lines[header_idx + 1], "\n")
  
  cat("\n   PROBLEM: Header split by WHITESPACE (current method):\n")
  header_cols_ws <- str_split(str_trim(lines[header_idx]), "\\s+")[[1]]
  cat("   ", paste(header_cols_ws, collapse = " | "), "\n")
  cat("   Count:", length(header_cols_ws), "\n")
  cat("   ⚠ 'Hi Grip?' becomes TWO columns: 'Hi' and 'Grip?'\n")
  
  cat("\n   SOLUTION: Header split by TAB:\n")
  header_cols_tab <- str_split(str_trim(lines[header_idx]), "\t")[[1]]
  header_cols_tab <- trimws(header_cols_tab)
  cat("   ", paste(header_cols_tab, collapse = " | "), "\n")
  cat("   Count:", length(header_cols_tab), "\n")
  
  cat("\n   First data line split by TAB:\n")
  data_cols_tab <- str_split(str_trim(lines[header_idx + 1]), "\t")[[1]]
  data_cols_tab <- trimws(data_cols_tab)
  cat("   ", paste(data_cols_tab, collapse = " | "), "\n")
  cat("   Count:", length(data_cols_tab), "\n")
  
  cat("\n   Column alignment:\n")
  cat("   Header (TAB):", length(header_cols_tab), "columns\n")
  cat("   Data (TAB):", length(data_cols_tab), "columns\n")
  if (length(header_cols_tab) == length(data_cols_tab)) {
    cat("   ✓ Perfect match!\n")
  } else {
    cat("   ⚠ Mismatch\n")
  }
}

cat("\n=== DIAGNOSIS COMPLETE ===\n")

