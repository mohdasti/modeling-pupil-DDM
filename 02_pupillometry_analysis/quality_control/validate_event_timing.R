#!/usr/bin/env Rscript

# ============================================================================
# Prompt 6: Validate Event Timing from Task Log
# ============================================================================
# Loads behavioral log files (with TrialST, blankST, fixST, A/V_ST, Resp1ST)
# Computes distributions of inter-event intervals
# Validates against expected values from task code
# Flags systematic offsets that would imply misalignment
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(tidyr)
})

cat("=== VALIDATE EVENT TIMING FROM TASK LOG ===\n")
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Configuration
# Task log files are typically named: subject*_Aoddball_session*_run*_*_*_*_*_logP.txt
# or: subject*_Voddball_session*_run*_*_*_*_*_logP.txt
# They should be in the same directory as the behavioral data or in a logs directory

# Try to find log files in common locations
log_dirs <- c(
  "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025",
  "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data",
  "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed",
  "data/raw",
  "data/logs"
)

log_files <- NULL
for (dir in log_dirs) {
  if (dir.exists(dir)) {
    files <- list.files(dir, pattern = "_logP\\.txt$", full.names = TRUE, recursive = TRUE)
    if (length(files) > 0) {
      log_files <- files
      cat("Found log files in:", dir, "\n")
      break
    }
  }
}

if (is.null(log_files) || length(log_files) == 0) {
  cat("WARNING: No _logP.txt files found in standard locations.\n")
  cat("Please specify log file directory manually.\n")
  cat("Looking for files matching pattern: *_logP.txt\n\n")
  
  # Try one more time with a broader search
  log_files <- list.files(
    "/Users/mohdasti/Documents/LC-BAP",
    pattern = "_logP\\.txt$",
    full.names = TRUE,
    recursive = TRUE
  )
  
  if (length(log_files) == 0) {
    stop("ERROR: No task log files found. Cannot validate event timing.")
  }
}

cat("Found", length(log_files), "log file(s)\n\n")

# Expected intervals from task code (in seconds)
# Based on actual task code timing:
# - TrialST = grip gauge onset (t=0)
# - blankST = blank screen onset (after 3s grip duration)
# - fixST = fixation onset (after 0.25s blank duration)
# - fixOFSTP = fixation offset (after 0.50s fixation duration)
# - A/V_ST = stimulus pair onset (very close to fixOFSTP, within a frame ~0.01s)
# - A/V_CT = stimulus pair completion (after 0.70s stimulus duration)
# - relaxST = relax screen onset (after stimulus ends)
# - Resp1ST = response screen onset (variable, no fixed expected interval)
expected_intervals <- list(
  blankST_minus_TrialST = 3.00,      # Grip duration = 3.00s
  fixST_minus_blankST = 0.25,        # Blank duration = 0.25s
  A_V_ST_minus_fixST = 0.50,         # Fixation duration (fixST to fixOFSTP) + small gap to A/V_ST ≈ 0.50s
  relaxST_minus_A_V_ST = 0.70        # Stimulus duration (A/V_ST to A/V_CT) + small gap to relaxST ≈ 0.70s
  # Resp1ST_minus_relaxST: No fixed expected (Resp1ST is response screen onset, variable timing)
)

# Tolerance for validation (seconds)
tolerance <- 0.05  # 50ms tolerance

# Function to parse log file
parse_log_file <- function(file_path) {
  # Read file, skipping header lines (lines starting with %)
  lines <- readLines(file_path, warn = FALSE)
  
  # Find header line (contains column names)
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
    cat("  ⚠ Cannot find header in:", basename(file_path), "\n")
    return(tibble())
  }
  
  # Parse header - FIX: Use TAB separator (not whitespace!)
  # This prevents "Hi Grip?" from being split into two columns
  header <- str_trim(lines[header_line])
  header_cols <- str_split(header, "\t")[[1]]
  header_cols <- trimws(header_cols)  # Remove any remaining whitespace
  
  # Extract subject, task, session, run from filename
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
  
  # Read data (skip header and any remaining comment lines)
  data_lines <- lines[data_start:length(lines)]
  data_lines <- data_lines[!grepl("^%", data_lines) & nchar(str_trim(data_lines)) > 0]
  
  if (length(data_lines) == 0) {
    cat("  ⚠ No data lines in:", basename(file_path), "\n")
    return(tibble())
  }
  
  # Parse data - FIX: Use TAB separator (not whitespace!)
  data_df <- map_dfr(data_lines, function(line) {
    values <- str_split(str_trim(line), "\t")[[1]]
    values <- trimws(values)  # Remove any remaining whitespace
    if (length(values) >= length(header_cols)) {
      values <- values[1:length(header_cols)]
      names(values) <- header_cols
      as_tibble(t(values))
    } else {
      tibble()
    }
  })
  
  # Guardrail: Check column count mismatch
  if (ncol(data_df) != length(header_cols)) {
    warning("Column mismatch in ", basename(file_path), 
            ": header=", length(header_cols), " columns, data=", ncol(data_df), " columns")
  }
  
  # Convert numeric columns (using original column names with special characters)
  numeric_cols <- c("TrialST", "blankST", "fixST", "A/V_ST", "relaxST", "Resp1ST", "Trial#")
  for (col in numeric_cols) {
    if (col %in% names(data_df)) {
      data_df[[col]] <- as.numeric(data_df[[col]])
    }
  }
  
  # Add metadata
  data_df %>%
    mutate(
      subject_id = subject_id,
      task = task,
      session = session,
      run = run,
      log_file = basename(file_path)
    )
}

cat("Parsing log files...\n")
log_data_list <- map(log_files, function(f) {
  cat("  Parsing:", basename(f), "\n")
  tryCatch({
    parse_log_file(f)
  }, error = function(e) {
    cat("    ⚠ Error parsing:", e$message, "\n")
    tibble()
  })
})

log_data <- bind_rows(log_data_list)

if (nrow(log_data) == 0) {
  stop("ERROR: No data parsed from log files.")
}

cat("\nParsed", nrow(log_data), "trial rows from", length(log_files), "log file(s)\n")
cat("Subjects:", length(unique(log_data$subject_id)), "\n")
cat("Tasks:", paste(unique(log_data$task), collapse = ", "), "\n\n")

# Ensure all timestamp columns are numeric (in case they weren't converted during parsing)
timestamp_cols <- c("TrialST", "blankST", "fixST", "A/V_ST", "relaxST", "Resp1ST", "Resp1ET", "Resp2ST", "Resp2ET")
for (col in timestamp_cols) {
  if (col %in% names(log_data)) {
    log_data[[col]] <- as.numeric(log_data[[col]])
  }
}

# Compute inter-event intervals
intervals <- log_data %>%
  filter(
    !is.na(`TrialST`),
    !is.na(`blankST`),
    !is.na(`fixST`),
    !is.na(`A/V_ST`),
    !is.na(`relaxST`)
  ) %>%
  mutate(
    blankST_minus_TrialST = as.numeric(blankST) - as.numeric(TrialST),
    fixST_minus_blankST = as.numeric(fixST) - as.numeric(blankST),
    A_V_ST_minus_fixST = as.numeric(.data[["A/V_ST"]]) - as.numeric(fixST),
    relaxST_minus_A_V_ST = as.numeric(relaxST) - as.numeric(.data[["A/V_ST"]]),
    Resp1ST_minus_relaxST = as.numeric(Resp1ST) - as.numeric(relaxST)  # For reference, but no expected value
  ) %>%
  select(subject_id, task, session, run, `Trial#`,
         blankST_minus_TrialST, fixST_minus_blankST,
         A_V_ST_minus_fixST, relaxST_minus_A_V_ST, Resp1ST_minus_relaxST)

# Summary statistics
interval_summary <- intervals %>%
  summarise(
    blankST_minus_TrialST_mean = mean(blankST_minus_TrialST, na.rm = TRUE),
    blankST_minus_TrialST_sd = sd(blankST_minus_TrialST, na.rm = TRUE),
    blankST_minus_TrialST_min = min(blankST_minus_TrialST, na.rm = TRUE),
    blankST_minus_TrialST_max = max(blankST_minus_TrialST, na.rm = TRUE),
    blankST_minus_TrialST_median = median(blankST_minus_TrialST, na.rm = TRUE),
    
    fixST_minus_blankST_mean = mean(fixST_minus_blankST, na.rm = TRUE),
    fixST_minus_blankST_sd = sd(fixST_minus_blankST, na.rm = TRUE),
    fixST_minus_blankST_min = min(fixST_minus_blankST, na.rm = TRUE),
    fixST_minus_blankST_max = max(fixST_minus_blankST, na.rm = TRUE),
    fixST_minus_blankST_median = median(fixST_minus_blankST, na.rm = TRUE),
    
    A_V_ST_minus_fixST_mean = mean(A_V_ST_minus_fixST, na.rm = TRUE),
    A_V_ST_minus_fixST_sd = sd(A_V_ST_minus_fixST, na.rm = TRUE),
    A_V_ST_minus_fixST_min = min(A_V_ST_minus_fixST, na.rm = TRUE),
    A_V_ST_minus_fixST_max = max(A_V_ST_minus_fixST, na.rm = TRUE),
    A_V_ST_minus_fixST_median = median(A_V_ST_minus_fixST, na.rm = TRUE),
    
    relaxST_minus_A_V_ST_mean = mean(relaxST_minus_A_V_ST, na.rm = TRUE),
    relaxST_minus_A_V_ST_sd = sd(relaxST_minus_A_V_ST, na.rm = TRUE),
    relaxST_minus_A_V_ST_min = min(relaxST_minus_A_V_ST, na.rm = TRUE),
    relaxST_minus_A_V_ST_max = max(relaxST_minus_A_V_ST, na.rm = TRUE),
    relaxST_minus_A_V_ST_median = median(relaxST_minus_A_V_ST, na.rm = TRUE),
    
    Resp1ST_minus_relaxST_mean = mean(Resp1ST_minus_relaxST, na.rm = TRUE),
    Resp1ST_minus_relaxST_sd = sd(Resp1ST_minus_relaxST, na.rm = TRUE),
    Resp1ST_minus_relaxST_min = min(Resp1ST_minus_relaxST, na.rm = TRUE),
    Resp1ST_minus_relaxST_max = max(Resp1ST_minus_relaxST, na.rm = TRUE),
    Resp1ST_minus_relaxST_median = median(Resp1ST_minus_relaxST, na.rm = TRUE)
  ) %>%
  pivot_longer(everything(), names_to = "metric", values_to = "value") %>%
  mutate(
    # Extract stat from the end (last part after final underscore)
    stat = str_extract(metric, "_(mean|sd|min|max|median)$"),
    stat = str_remove(stat, "^_"),
    # Extract interval (everything before the last underscore)
    interval = str_remove(metric, "_(mean|sd|min|max|median)$")
  ) %>%
  select(-metric) %>%
  pivot_wider(names_from = stat, values_from = value)

# Add expected values and compute deviations
interval_summary <- interval_summary %>%
  mutate(
    expected = case_when(
      interval == "blankST_minus_TrialST" ~ expected_intervals$blankST_minus_TrialST,
      interval == "fixST_minus_blankST" ~ expected_intervals$fixST_minus_blankST,
      interval == "A_V_ST_minus_fixST" ~ expected_intervals$A_V_ST_minus_fixST,
      interval == "relaxST_minus_A_V_ST" ~ expected_intervals$relaxST_minus_A_V_ST,
      interval == "Resp1ST_minus_relaxST" ~ NA_real_,  # No fixed expected (variable timing)
      TRUE ~ NA_real_
    ),
    mean = as.numeric(mean),
    expected = as.numeric(expected),
    deviation = mean - expected,
    deviation_pct = ifelse(!is.na(expected), round(100 * deviation / expected, 2), NA_real_),
    within_tolerance = ifelse(!is.na(expected), abs(deviation) <= tolerance, NA),
    flag = case_when(
      is.na(expected) ~ "N/A (no expected)",
      !within_tolerance ~ "⚠ MISALIGNED",
      TRUE ~ "✓ OK"
    )
  )

# Save results
qc_dir <- "data/qc"
dir.create(qc_dir, recursive = TRUE, showWarnings = FALSE)

output_file <- file.path(qc_dir, "event_timing_validation.csv")
summary_file <- file.path(qc_dir, "event_timing_summary.csv")

write_csv(intervals, output_file)
write_csv(interval_summary, summary_file)

cat("=== EVENT TIMING VALIDATION ===\n\n")
print(interval_summary)

cat("\n  ✓ Saved interval data to:", output_file, "\n")
cat("  ✓ Saved summary to:", summary_file, "\n\n")

# Check for systematic offsets
cat("=== VALIDATION RESULTS ===\n\n")
misaligned <- interval_summary %>% filter(!within_tolerance)
if (nrow(misaligned) > 0) {
  cat("⚠ WARNING: Systematic offsets detected:\n")
  print(misaligned)
  cat("\nThese intervals deviate from expected values by more than", tolerance, "s.\n")
  cat("This may indicate misalignment in the analysis pipeline.\n\n")
} else {
  cat("✓ All intervals match expected values within tolerance (", tolerance, "s).\n\n")
}

# Task-specific summaries
if ("task" %in% names(intervals)) {
  cat("By task:\n")
  interval_summary_by_task <- intervals %>%
    group_by(task) %>%
    summarise(
      blankST_minus_TrialST_mean = mean(blankST_minus_TrialST, na.rm = TRUE),
      blankST_minus_TrialST_sd = sd(blankST_minus_TrialST, na.rm = TRUE),
      fixST_minus_blankST_mean = mean(fixST_minus_blankST, na.rm = TRUE),
      fixST_minus_blankST_sd = sd(fixST_minus_blankST, na.rm = TRUE),
      A_V_ST_minus_fixST_mean = mean(A_V_ST_minus_fixST, na.rm = TRUE),
      A_V_ST_minus_fixST_sd = sd(A_V_ST_minus_fixST, na.rm = TRUE),
      relaxST_minus_A_V_ST_mean = mean(relaxST_minus_A_V_ST, na.rm = TRUE),
      relaxST_minus_A_V_ST_sd = sd(relaxST_minus_A_V_ST, na.rm = TRUE),
      Resp1ST_minus_relaxST_mean = mean(Resp1ST_minus_relaxST, na.rm = TRUE),
      Resp1ST_minus_relaxST_sd = sd(Resp1ST_minus_relaxST, na.rm = TRUE)
    )
  print(interval_summary_by_task)
}

cat("\n=== VALIDATION COMPLETE ===\n")
cat("Completed at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")

