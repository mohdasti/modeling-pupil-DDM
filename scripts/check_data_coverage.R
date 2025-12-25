#!/usr/bin/env Rscript

# ============================================================================
# Data Coverage Check Script
# ============================================================================
# Compares raw data files (logP.txt) with processed TRIALLEVEL data
# to identify missing sessions/runs
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(purrr)
})

# ============================================================================
# Configuration
# ============================================================================

BASE_DIR <- "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM"
OUTPUT_DIR <- file.path(BASE_DIR, "data/qc/coverage")
TRIALLEVEL_FILE <- file.path(BASE_DIR, "data/analysis_ready/BAP_analysis_ready_TRIALLEVEL.csv")

# Common locations to search for raw data
RAW_DATA_LOCATIONS <- c(
  "/Users/mohdasti/Documents/MATLAB/LCTaskCode_01102022",
  "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry",
  file.path(BASE_DIR, "data/raw"),
  file.path(BASE_DIR, "~/Desktop/BAP_DDM_run")
)

dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("=== DATA COVERAGE CHECK ===\n\n")

# ============================================================================
# TASK 1: Build Raw Data Manifest
# ============================================================================

cat("TASK 1: Building raw data manifest from logP.txt files\n")
cat("-------------------------------------------------------\n")

# Function to find all logP.txt files
# STRICT FILTER: Only InsideScanner ses-2/3 files for analysis-ready processing
find_logp_files <- function(search_paths) {
  all_files <- c()
  for (path in search_paths) {
    # Expand ~ if present
    path <- path.expand(path)
    if (dir.exists(path)) {
      files <- list.files(path, pattern = "logP\\.txt$", recursive = TRUE, full.names = TRUE)
      all_files <- c(all_files, files)
      if (length(files) > 0) {
        cat("  Found", length(files), "files in", path, "\n")
      }
    }
  }
  unique(all_files)
}

# Function to filter files to ONLY InsideScanner ses-2/3
filter_scanner_ses23 <- function(filepaths) {
  # STRICT REQUIREMENT: Must match pattern for InsideScanner ses-2 or ses-3
  # Pattern: .../BAP/data/sub-*/ses-[23]/InsideScanner/*_logP.txt
  filtered <- filepaths[
    grepl("InsideScanner", filepaths, ignore.case = TRUE) &
    (grepl("ses-2|ses_2|session2", filepaths, ignore.case = TRUE) |
     grepl("ses-3|ses_3|session3", filepaths, ignore.case = TRUE)) &
    !grepl("/Documents/MATLAB/|LCTaskCode", filepaths, ignore.case = TRUE)
  ]
  
  cat("Filtered to InsideScanner ses-2/3 only:\n")
  cat("  - Total files found:", length(filepaths), "\n")
  cat("  - After filtering:", length(filtered), "\n")
  cat("  - Excluded:", length(filepaths) - length(filtered), "\n\n")
  
  filtered
}

logp_files <- find_logp_files(RAW_DATA_LOCATIONS)
cat("Total logP.txt files found:", length(logp_files), "\n\n")

# STRICT FILTER: Only InsideScanner ses-2/3 for analysis-ready processing
cat("Applying strict filter: InsideScanner ses-2/3 only\n")
logp_files <- filter_scanner_ses23(logp_files)
cat("Files remaining after filter:", length(logp_files), "\n\n")

# Function to parse subject_id, task, ses, run from filename/path
parse_file_info <- function(filepath) {
  filename <- basename(filepath)
  dirname <- dirname(filepath)
  
  # Initialize
  subject_id <- NA_character_
  task <- NA_character_
  ses <- NA_integer_
  run <- NA_integer_
  
  # Pattern 1: subject2_Aoddball_session1_run2_1_18_13_30_logP.txt
  # Extract subject
  subject_match <- str_extract(filename, "subject(\\d+|[A-Z]+\\d+)")
  if (!is.na(subject_match)) {
    subject_id <- str_replace(subject_match, "subject", "")
    # Convert to BAP format if needed
    if (str_detect(subject_id, "^\\d+$")) {
      subject_id <- paste0("BAP", str_pad(subject_id, 3, pad = "0"))
    }
  }
  
  # Extract task (Aoddball = ADT, Voddball = VDT)
  if (str_detect(filename, "Aoddball|A_oddball|ADT")) {
    task <- "ADT"
  } else if (str_detect(filename, "Voddball|V_oddball|VDT")) {
    task <- "VDT"
  }
  
  # Extract session
  ses_match <- str_extract(filename, "session(\\d+)|ses[_-]?(\\d+)")
  if (!is.na(ses_match)) {
    ses_num <- str_extract(ses_match, "\\d+")
    ses <- as.integer(ses_num)
  } else {
    # Try to extract from path
    ses_path_match <- str_extract(dirname, "ses[_-]?(\\d+)|session(\\d+)")
    if (!is.na(ses_path_match)) {
      ses_num <- str_extract(ses_path_match, "\\d+")
      ses <- as.integer(ses_num)
    } else {
      ses <- 1L  # Default
    }
  }
  
  # Extract run
  run_match <- str_extract(filename, "run(\\d+)")
  if (!is.na(run_match)) {
    run_num <- str_extract(run_match, "\\d+")
    run <- as.integer(run_num)
  } else {
    # Try alternative patterns
    run_match2 <- str_extract(filename, "_r(\\d+)_|_r(\\d+)\\.|_r(\\d+)$")
    if (!is.na(run_match2)) {
      run_num <- str_extract(run_match2, "\\d+")
      run <- as.integer(run_num)
    } else {
      run <- NA_integer_
    }
  }
  
  # If still missing, try to extract from path
  if (is.na(run)) {
    run_path_match <- str_extract(dirname, "run[_-]?(\\d+)")
    if (!is.na(run_path_match)) {
      run_num <- str_extract(run_path_match, "\\d+")
      run <- as.integer(run_num)
    }
  }
  
  tibble(
    subject_id = subject_id,
    task = task,
    ses = ses,
    run = run,
    filepath = filepath,
    filename = filename
  )
}

cat("Parsing file information...\n")
raw_manifest <- map_dfr(logp_files, parse_file_info)

# Clean up: remove rows with missing critical info
raw_manifest <- raw_manifest %>%
  filter(!is.na(subject_id), !is.na(task), !is.na(run))

cat("Parsed", nrow(raw_manifest), "files with complete information\n")
cat("Removed", length(logp_files) - nrow(raw_manifest), "files with missing info\n\n")

# Show sample
cat("Sample of parsed files:\n")
print(head(raw_manifest, 10))
cat("\n")

# Save raw manifest
write_csv(raw_manifest, file.path(OUTPUT_DIR, "raw_manifest.csv"))
cat("✓ Saved raw_manifest.csv\n\n")

# ============================================================================
# TASK 2: Build Processed Data Manifest
# ============================================================================

cat("TASK 2: Building processed data manifest from TRIALLEVEL\n")
cat("--------------------------------------------------------\n")

if (!file.exists(TRIALLEVEL_FILE)) {
  stop("TRIALLEVEL file not found: ", TRIALLEVEL_FILE)
}

trial_level <- read_csv(TRIALLEVEL_FILE, show_col_types = FALSE, progress = FALSE)
cat("Loaded", nrow(trial_level), "trials from TRIALLEVEL\n")

# Create manifest
processed_manifest <- trial_level %>%
  mutate(
    ses = if("ses" %in% names(.)) {
      ses
    } else if("ses_value" %in% names(.)) {
      ses_value
    } else {
      1L
    }
  ) %>%
  group_by(subject_id, task, ses, run) %>%
  summarise(
    n_trials = n(),
    .groups = "drop"
  )

cat("Found", nrow(processed_manifest), "unique (subject×task×ses×run) units\n\n")

# Show sample
cat("Sample of processed units:\n")
print(head(processed_manifest, 10))
cat("\n")

# Save processed manifest
write_csv(processed_manifest, file.path(OUTPUT_DIR, "processed_manifest.csv"))
cat("✓ Saved processed_manifest.csv\n\n")

# ============================================================================
# TASK 3: Compare and Compute Coverage
# ============================================================================

cat("TASK 3: Comparing manifests and computing coverage\n")
cat("---------------------------------------------------\n")

# Standardize ses (ensure both are integers)
raw_manifest <- raw_manifest %>%
  mutate(ses = as.integer(ses))

processed_manifest <- processed_manifest %>%
  mutate(ses = as.integer(ses))

# Find missing units with filepaths (for reporting)
missing_units_with_files <- raw_manifest %>%
  filter(
    !paste(subject_id, task, ses, run, sep = ":") %in%
    paste(processed_manifest$subject_id, processed_manifest$task, 
          processed_manifest$ses, processed_manifest$run, sep = ":")
  )

# Also find extra units (in processed but not in raw)
extra_units <- processed_manifest %>%
  select(subject_id, task, ses, run) %>%
  anti_join(
    raw_manifest %>% distinct(subject_id, task, ses, run),
    by = c("subject_id", "task", "ses", "run")
  )

# Compute coverage
# Get unique raw units
raw_units_unique <- raw_manifest %>%
  distinct(subject_id, task, ses, run)

n_raw_units <- nrow(raw_units_unique)
n_processed_units <- nrow(processed_manifest)

# Find missing units (in raw but not in processed)
missing_units_unique <- raw_units_unique %>%
  anti_join(
    processed_manifest %>% select(subject_id, task, ses, run),
    by = c("subject_id", "task", "ses", "run")
  )

n_missing_units <- nrow(missing_units_unique)

# Find extra units (in processed but not in raw)
extra_units <- processed_manifest %>%
  select(subject_id, task, ses, run) %>%
  anti_join(
    raw_units_unique,
    by = c("subject_id", "task", "ses", "run")
  )

n_extra_units <- nrow(extra_units)

# Coverage = (raw - missing) / raw
coverage_pct <- round(100 * (n_raw_units - n_missing_units) / n_raw_units, 2)

cat("Coverage Summary:\n")
cat("  - Total raw units (subject×task×ses×run):", n_raw_units, "\n")
cat("  - Total processed units:", n_processed_units, "\n")
cat("  - Missing units:", n_missing_units, "\n")
cat("  - Extra units (in processed but not in raw):", n_extra_units, "\n")
cat("  - Coverage:", coverage_pct, "%\n\n")

# Save missing units with filepaths
if (nrow(missing_units_with_files) > 0) {
  missing_units_summary <- missing_units_with_files %>%
    group_by(subject_id, task, ses, run) %>%
    summarise(
      n_files = n(),
      filepaths = paste(filepath, collapse = "; "),
      .groups = "drop"
    ) %>%
    arrange(subject_id, task, ses, run)
  
  write_csv(missing_units_summary, file.path(OUTPUT_DIR, "missing_units.csv"))
  cat("✓ Saved missing_units.csv\n\n")
  
  cat("Top 20 missing units:\n")
  print(head(missing_units_summary, 20))
  cat("\n")
} else {
  cat("✓ No missing units found!\n\n")
  # Create empty file
  write_csv(tibble(subject_id = character(), task = character(), ses = integer(), 
                   run = integer(), n_files = integer(), filepaths = character()),
            file.path(OUTPUT_DIR, "missing_units.csv"))
}

# ============================================================================
# TASK 4: Print Summary
# ============================================================================

cat("TASK 4: Final Summary\n")
cat("---------------------\n\n")

cat("=== COVERAGE SUMMARY ===\n\n")
cat("Total raw units (subject×task×ses×run):", n_raw_units, "\n")
cat("Total processed units:", n_processed_units, "\n")
cat("Missing units:", n_missing_units, "\n")
cat("Coverage:", coverage_pct, "%\n\n")

if (n_missing_units > 0) {
  cat("Top 20 Missing Units:\n")
  print(head(missing_units_summary %>% select(subject_id, task, ses, run, n_files), 20))
  cat("\n")
  
  # Breakdown by subject
  missing_by_subject <- missing_units_summary %>%
    group_by(subject_id) %>%
    summarise(n_missing = n(), .groups = "drop") %>%
    arrange(desc(n_missing))
  
  cat("Missing units by subject:\n")
  print(head(missing_by_subject, 10))
  cat("\n")
  
  # Breakdown by task
  missing_by_task <- missing_units_summary %>%
    group_by(task) %>%
    summarise(n_missing = n(), .groups = "drop")
  
  cat("Missing units by task:\n")
  print(missing_by_task)
  cat("\n")
}

if (n_extra_units > 0) {
  cat("Extra units (in processed but not in raw):", n_extra_units, "\n")
  cat("These may be from a different data source or renamed files.\n\n")
  print(head(extra_units, 10))
  cat("\n")
}

cat("=== OUTPUT FILES ===\n")
cat("  - data/qc/coverage/raw_manifest.csv\n")
cat("  - data/qc/coverage/processed_manifest.csv\n")
cat("  - data/qc/coverage/missing_units.csv\n\n")

cat("✓ Coverage check complete!\n")

