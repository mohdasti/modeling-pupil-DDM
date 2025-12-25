#!/usr/bin/env Rscript
# ============================================================================
# Comprehensive Pupil Data Sanity Checks
# ============================================================================
# Runs checks and balances on existing pupil flat CSV files
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

cat("================================================================================\n")
cat("PUPIL DATA SANITY CHECKS AND BALANCES\n")
cat("================================================================================\n\n")

# Configuration
processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
behavioral_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"

# Find all flat CSV files
flat_files_merged <- list.files(processed_dir, pattern = "_flat_merged\\.csv$", full.names = TRUE)
flat_files_reg <- list.files(processed_dir, pattern = "_flat\\.csv$", full.names = TRUE)

# Remove duplicates (prefer merged versions)
if (length(flat_files_merged) > 0 && length(flat_files_reg) > 0) {
  merged_ids <- gsub("_flat_merged\\.csv$", "", basename(flat_files_merged))
  reg_ids <- gsub("_flat\\.csv$", "", basename(flat_files_reg))
  reg_to_keep <- !reg_ids %in% merged_ids
  flat_files <- c(flat_files_merged, flat_files_reg[reg_to_keep])
} else {
  flat_files <- c(flat_files_merged, flat_files_reg)
}

cat(sprintf("Found %d flat CSV files to check\n\n", length(flat_files)))

if (length(flat_files) == 0) {
  stop("No flat files found!")
}

# Load behavioral data for comparison
cat("Loading behavioral data for reference...\n")
behavioral_data <- read_csv(behavioral_file, show_col_types = FALSE) %>%
  mutate(
    sub = as.character(subject_id),
    task_pupil = case_when(
      task_modality == "aud" ~ "ADT",
      task_modality == "vis" ~ "VDT",
      TRUE ~ as.character(task_modality)
    ),
    run = run_num,
    trial = trial_num
  )

cat(sprintf("Loaded behavioral data: %d rows\n\n", nrow(behavioral_data)))

# Initialize results storage
all_checks <- list()

# ============================================================================
# CHECK 1: File Structure and Basic Integrity
# ============================================================================
cat("================================================================================\n")
cat("CHECK 1: FILE STRUCTURE AND BASIC INTEGRITY\n")
cat("================================================================================\n\n")

check1_results <- list()

for (file_path in flat_files) {
  filename <- basename(file_path)
  cat(sprintf("Checking: %s\n", filename))
  
  tryCatch({
    df <- read_csv(file_path, show_col_types = FALSE, progress = FALSE)
    
    # Extract subject and task from filename
    parts <- regmatches(filename, gregexpr("BAP\\d+|ADT|VDT", filename))[[1]]
    subject <- if(length(parts) > 0) parts[1] else NA
    task <- if(length(parts) > 1) parts[2] else NA
    
    # Required columns check
    required_cols <- c("sub", "task", "run", "trial_index", "pupil", "time")
    missing_cols <- setdiff(required_cols, colnames(df))
    
    # Basic statistics
    n_rows <- nrow(df)
    n_trials <- length(unique(df$trial_index[!is.na(df$trial_index)]))
    n_runs <- length(unique(df$run[!is.na(df$run)]))
    
    # Pupil data checks
    pupil_missing <- sum(is.na(df$pupil))
    pupil_zero <- sum(df$pupil == 0, na.rm = TRUE)
    pupil_negative <- sum(df$pupil < 0, na.rm = TRUE)
    pupil_unrealistic <- sum(df$pupil > 100 | df$pupil < 1, na.rm = TRUE)
    
    # Time checks
    time_negative <- sum(df$time < 0, na.rm = TRUE)
    time_na <- sum(is.na(df$time))
    
    # Trial index checks
    trial_index_na <- sum(is.na(df$trial_index))
    trial_index_negative <- sum(df$trial_index < 0, na.rm = TRUE)
    
    # Run checks
    run_na <- sum(is.na(df$run))
    run_negative <- sum(df$run < 0, na.rm = TRUE)
    
    check1_results[[filename]] <- list(
      filename = filename,
      subject = subject,
      task = task,
      status = if(length(missing_cols) == 0) "PASS" else "FAIL",
      missing_cols = paste(missing_cols, collapse = ", "),
      n_rows = n_rows,
      n_trials = n_trials,
      n_runs = n_runs,
      pupil_missing_pct = 100 * pupil_missing / n_rows,
      pupil_zero_pct = 100 * pupil_zero / n_rows,
      pupil_negative = pupil_negative,
      pupil_unrealistic = pupil_unrealistic,
      time_negative = time_negative,
      time_na = time_na,
      trial_index_na = trial_index_na,
      trial_index_negative = trial_index_negative,
      run_na = run_na,
      run_negative = run_negative
    )
    
    # Print summary
    if(length(missing_cols) > 0) {
      cat(sprintf("  ❌ FAIL: Missing columns: %s\n", paste(missing_cols, collapse = ", ")))
    } else {
      cat(sprintf("  ✓ PASS: Structure OK\n"))
    }
    cat(sprintf("    Rows: %s | Trials: %d | Runs: %d\n", 
                format(n_rows, big.mark = ","), n_trials, n_runs))
    cat(sprintf("    Pupil: %.1f%% missing, %d zeros, %d negative, %d unrealistic\n",
                check1_results[[filename]]$pupil_missing_pct, pupil_zero, 
                pupil_negative, pupil_unrealistic))
    
  }, error = function(e) {
    cat(sprintf("  ❌ ERROR reading file: %s\n", e$message))
    check1_results[[filename]] <- list(
      filename = filename,
      status = "ERROR",
      error = e$message
    )
  })
}

# ============================================================================
# CHECK 2: Data Completeness and Coverage
# ============================================================================
cat("\n================================================================================\n")
cat("CHECK 2: DATA COMPLETENESS AND COVERAGE\n")
cat("================================================================================\n\n")

check2_results <- list()

for (file_path in flat_files) {
  filename <- basename(file_path)
  
  tryCatch({
    df <- read_csv(file_path, show_col_types = FALSE, progress = FALSE)
    
    parts <- regmatches(filename, gregexpr("BAP\\d+|ADT|VDT", filename))[[1]]
    subject <- if(length(parts) > 0) parts[1] else NA
    task <- if(length(parts) > 1) parts[2] else NA
    
    # Trial coverage per run
    trial_coverage <- df %>%
      filter(!is.na(run), !is.na(trial_index)) %>%
      group_by(run) %>%
      summarise(
        n_trials = length(unique(trial_index)),
        n_samples = n(),
        samples_per_trial = n() / length(unique(trial_index)),
        .groups = "drop"
      )
    
    # Behavioral data matching
    has_behavioral <- if("has_behavioral_data" %in% colnames(df)) {
      sum(df$has_behavioral_data == 1, na.rm = TRUE)
    } else {
      NA
    }
    
    # Expected vs actual trials
    behavioral_subset <- behavioral_data %>%
      filter(sub == subject, task_pupil == task)
    
    expected_trials <- if(nrow(behavioral_subset) > 0) {
      behavioral_subset %>%
        group_by(run) %>%
        summarise(expected = n(), .groups = "drop")
    } else {
      tibble(run = numeric(), expected = numeric())
    }
    
    # Compare expected vs actual
    if(nrow(expected_trials) > 0 && nrow(trial_coverage) > 0) {
      comparison <- trial_coverage %>%
        left_join(expected_trials, by = "run") %>%
        mutate(
          trial_diff = n_trials - expected,
          coverage_pct = ifelse(expected > 0, 100 * n_trials / expected, NA)
        )
    } else {
      comparison <- trial_coverage %>%
        mutate(expected = NA, trial_diff = NA, coverage_pct = NA)
    }
    
    check2_results[[filename]] <- list(
      filename = filename,
      subject = subject,
      task = task,
      trial_coverage = trial_coverage,
      comparison = comparison,
      has_behavioral_samples = has_behavioral,
      behavioral_pct = if(!is.na(has_behavioral)) 100 * has_behavioral / nrow(df) else NA
    )
    
    cat(sprintf("%s - %s\n", subject, task))
    cat(sprintf("  Runs: %d | Trials per run: %s\n", 
                nrow(trial_coverage),
                paste(sprintf("%.0f", trial_coverage$n_trials), collapse = ", ")))
    if(nrow(comparison) > 0 && !all(is.na(comparison$coverage_pct))) {
      cat(sprintf("  Coverage vs behavioral: %s\n",
                  paste(sprintf("%.0f%%", comparison$coverage_pct), collapse = ", ")))
    }
    if(!is.na(has_behavioral)) {
      cat(sprintf("  Behavioral data: %d samples (%.1f%%)\n", 
                  has_behavioral, check2_results[[filename]]$behavioral_pct))
    }
    
  }, error = function(e) {
    cat(sprintf("  ❌ ERROR: %s\n", e$message))
  })
}

# ============================================================================
# CHECK 3: Data Quality and Outliers
# ============================================================================
cat("\n================================================================================\n")
cat("CHECK 3: DATA QUALITY AND OUTLIERS\n")
cat("================================================================================\n\n")

check3_results <- list()

for (file_path in flat_files) {
  filename <- basename(file_path)
  
  tryCatch({
    df <- read_csv(file_path, show_col_types = FALSE, progress = FALSE)
    
    parts <- regmatches(filename, gregexpr("BAP\\d+|ADT|VDT", filename))[[1]]
    subject <- if(length(parts) > 0) parts[1] else NA
    task <- if(length(parts) > 1) parts[2] else NA
    
    # Pupil value statistics
    valid_pupil <- df$pupil[!is.na(df$pupil) & df$pupil > 0]
    
    if(length(valid_pupil) > 0) {
      pupil_mean <- mean(valid_pupil)
      pupil_sd <- sd(valid_pupil)
      pupil_median <- median(valid_pupil)
      pupil_q1 <- quantile(valid_pupil, 0.25)
      pupil_q3 <- quantile(valid_pupil, 0.75)
      pupil_iqr <- pupil_q3 - pupil_q1
      
      # Outlier detection (using IQR method)
      outliers_low <- sum(valid_pupil < (pupil_q1 - 3 * pupil_iqr))
      outliers_high <- sum(valid_pupil > (pupil_q3 + 3 * pupil_iqr))
      
      # Z-score outliers
      z_scores <- abs((valid_pupil - pupil_mean) / pupil_sd)
      z_outliers <- sum(z_scores > 4)  # 4 SD threshold
      
    } else {
      pupil_mean <- NA
      pupil_sd <- NA
      pupil_median <- NA
      outliers_low <- NA
      outliers_high <- NA
      z_outliers <- NA
    }
    
    # Time consistency
    if("time" %in% colnames(df) && sum(!is.na(df$time)) > 1) {
      time_sorted <- sort(df$time[!is.na(df$time)])
      time_diffs <- diff(time_sorted)
      time_gaps <- sum(time_diffs > 0.1)  # >100ms gaps
      time_mean_diff <- mean(time_diffs, na.rm = TRUE)
    } else {
      time_gaps <- NA
      time_mean_diff <- NA
    }
    
    # Trial label coverage (if available)
    if("trial_label" %in% colnames(df)) {
      unique_labels <- length(unique(df$trial_label[!is.na(df$trial_label)]))
      label_counts <- table(df$trial_label[!is.na(df$trial_label)])
    } else {
      unique_labels <- NA
      label_counts <- NA
    }
    
    check3_results[[filename]] <- list(
      filename = filename,
      subject = subject,
      task = task,
      pupil_mean = pupil_mean,
      pupil_sd = pupil_sd,
      pupil_median = pupil_median,
      outliers_iqr_low = outliers_low,
      outliers_iqr_high = outliers_high,
      outliers_z = z_outliers,
      time_gaps = time_gaps,
      time_mean_diff = time_mean_diff,
      unique_labels = unique_labels
    )
    
    cat(sprintf("%s - %s\n", subject, task))
    if(!is.na(pupil_mean)) {
      cat(sprintf("  Pupil: Mean=%.2f, SD=%.2f, Median=%.2f\n", 
                  pupil_mean, pupil_sd, pupil_median))
      cat(sprintf("  Outliers: %d low, %d high (IQR), %d (Z-score)\n",
                  ifelse(is.na(outliers_low), 0, outliers_low),
                  ifelse(is.na(outliers_high), 0, outliers_high),
                  ifelse(is.na(z_outliers), 0, z_outliers)))
    }
    if(!is.na(time_gaps)) {
      cat(sprintf("  Time gaps: %d (>100ms), mean diff=%.3fs\n", 
                  time_gaps, time_mean_diff))
    }
    if(!is.na(unique_labels)) {
      cat(sprintf("  Trial labels: %d unique\n", unique_labels))
    }
    
  }, error = function(e) {
    cat(sprintf("  ❌ ERROR: %s\n", e$message))
  })
}

# ============================================================================
# CHECK 4: Behavioral Data Integration
# ============================================================================
cat("\n================================================================================\n")
cat("CHECK 4: BEHAVIORAL DATA INTEGRATION\n")
cat("================================================================================\n\n")

check4_results <- list()

for (file_path in flat_files) {
  filename <- basename(file_path)
  
  tryCatch({
    df <- read_csv(file_path, show_col_types = FALSE, progress = FALSE)
    
    parts <- regmatches(filename, gregexpr("BAP\\d+|ADT|VDT", filename))[[1]]
    subject <- if(length(parts) > 0) parts[1] else NA
    task <- if(length(parts) > 1) parts[2] else NA
    
    # Check if behavioral columns exist
    behavioral_cols <- c("iscorr", "resp1RT", "stimLev", "isOddball", "gf_trPer")
    has_behavioral_cols <- behavioral_cols %in% colnames(df)
    
    # Get behavioral data for this subject-task
    behavioral_subset <- behavioral_data %>%
      filter(sub == subject, task_pupil == task)
    
    # Check merge status
    if("has_behavioral_data" %in% colnames(df)) {
      trials_with_behav <- df %>%
        filter(has_behavioral_data == 1) %>%
        distinct(run, trial_index) %>%
        nrow()
      
      total_trials <- df %>%
        distinct(run, trial_index) %>%
        nrow()
      
      merge_rate <- if(total_trials > 0) 100 * trials_with_behav / total_trials else 0
    } else {
      trials_with_behav <- NA
      total_trials <- NA
      merge_rate <- NA
    }
    
    # Check for expected behavioral trials
    expected_behavioral_trials <- if(nrow(behavioral_subset) > 0) {
      behavioral_subset %>%
        distinct(run, trial) %>%
        nrow()
    } else {
      0
    }
    
    check4_results[[filename]] <- list(
      filename = filename,
      subject = subject,
      task = task,
      has_behavioral_cols = sum(has_behavioral_cols),
      behavioral_cols_present = paste(behavioral_cols[has_behavioral_cols], collapse = ", "),
      trials_with_behav = trials_with_behav,
      total_trials = total_trials,
      merge_rate = merge_rate,
      expected_behavioral_trials = expected_behavioral_trials
    )
    
    cat(sprintf("%s - %s\n", subject, task))
    cat(sprintf("  Behavioral columns: %d/%d present (%s)\n",
                sum(has_behavioral_cols), length(behavioral_cols),
                if(sum(has_behavioral_cols) == length(behavioral_cols)) "✓" else "⚠"))
    if(!is.na(merge_rate)) {
      cat(sprintf("  Merge rate: %.1f%% (%d/%d trials)\n", 
                  merge_rate, trials_with_behav, total_trials))
    }
    cat(sprintf("  Expected behavioral trials: %d\n", expected_behavioral_trials))
    
  }, error = function(e) {
    cat(sprintf("  ❌ ERROR: %s\n", e$message))
  })
}

# ============================================================================
# SUMMARY REPORT
# ============================================================================
cat("\n================================================================================\n")
cat("SUMMARY REPORT\n")
cat("================================================================================\n\n")

# Compile summary
summary_df <- tibble(
  filename = character(),
  subject = character(),
  task = character(),
  status = character(),
  n_rows = numeric(),
  n_trials = numeric(),
  n_runs = numeric(),
  pupil_missing_pct = numeric(),
  merge_rate = numeric(),
  issues = character()
)

for (filename in names(check1_results)) {
  c1 <- check1_results[[filename]]
  c2 <- check2_results[[filename]]
  c4 <- check4_results[[filename]]
  
  issues <- c()
  if(c1$status != "PASS") issues <- c(issues, "Structure issues")
  if(c1$pupil_missing_pct > 50) issues <- c(issues, "High missing data")
  if(c1$pupil_unrealistic > 0) issues <- c(issues, "Unrealistic values")
  if(!is.null(c4) && !is.na(c4$merge_rate) && c4$merge_rate < 50) {
    issues <- c(issues, "Low merge rate")
  }
  
  summary_df <- summary_df %>%
    add_row(
      filename = filename,
      subject = c1$subject,
      task = c1$task,
      status = if(length(issues) == 0) "OK" else "ISSUES",
      n_rows = c1$n_rows,
      n_trials = c1$n_trials,
      n_runs = c1$n_runs,
      pupil_missing_pct = c1$pupil_missing_pct,
      merge_rate = if(!is.null(c4) && !is.na(c4$merge_rate)) c4$merge_rate else NA,
      issues = paste(issues, collapse = "; ")
    )
}

# Print summary
cat("Files with issues:\n")
issues_df <- summary_df %>% filter(status == "ISSUES")
if(nrow(issues_df) > 0) {
  print(issues_df %>% select(filename, subject, task, issues))
} else {
  cat("  ✓ No files with major issues detected\n")
}

cat("\nOverall statistics:\n")
cat(sprintf("  Total files: %d\n", nrow(summary_df)))
cat(sprintf("  Files with issues: %d\n", sum(summary_df$status == "ISSUES")))
cat(sprintf("  Mean missing data: %.1f%%\n", mean(summary_df$pupil_missing_pct, na.rm = TRUE)))
cat(sprintf("  Mean merge rate: %.1f%%\n", mean(summary_df$merge_rate, na.rm = TRUE)))

# Save summary
write_csv(summary_df, "pupil_data_sanity_check_summary.csv")
cat("\n✓ Summary saved to: pupil_data_sanity_check_summary.csv\n")

cat("\n================================================================================\n")
cat("SANITY CHECKS COMPLETE\n")
cat("================================================================================\n\n")









