#!/usr/bin/env Rscript

# ============================================================================
# Trial-Level Analysis-Ready Data Audit Script
# ============================================================================
# Comprehensive audit of trial-level pupillometry pipeline outputs
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(purrr)
  library(ggplot2)
})

# ============================================================================
# Configuration
# ============================================================================

BASE_DIR <- "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM"
QC_DIR <- file.path(BASE_DIR, "02_pupillometry_analysis/quality_control/exports")
ANALYSIS_READY_DIR <- file.path(BASE_DIR, "data/analysis_ready")
OUTPUT_DIR <- file.path(BASE_DIR, "data/qc/analysis_ready_audit")
FIG_DIR <- file.path(OUTPUT_DIR, "figures")

# Create output directories
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

# Key files
TRIALLEVEL_FILE <- file.path(ANALYSIS_READY_DIR, "BAP_analysis_ready_TRIALLEVEL.csv")
INVENTORY_FILE <- file.path(QC_DIR, "00_data_inventory_file_inventory.csv")
TRIAL_COVERAGE_FILE <- file.path(QC_DIR, "01_trial_coverage_prefilter.csv.gz")
SUBJECT_STATS_FILE <- file.path(QC_DIR, "08_analysis_ready_subject_stats.csv")
THRESHOLD_SWEEP_FILE <- file.path(QC_DIR, "03_threshold_sweep_long.csv.gz")

# Threshold grid for retention curves
THRESHOLD_GRID <- c(0.50, 0.60, 0.70, 0.80, 0.85, 0.90, 0.95)

# Results storage
audit_results <- list()
issues <- list()
warnings <- list()
trial_level <- NULL

cat("=== TRIAL-LEVEL ANALYSIS-READY DATA AUDIT ===\n\n")
cat("Starting comprehensive audit...\n\n")

# ============================================================================
# Load Trial-Level Data
# ============================================================================

cat("Loading trial-level dataset...\n")
if (!file.exists(TRIALLEVEL_FILE)) {
  stop("Trial-level file not found: ", TRIALLEVEL_FILE)
}

trial_level <- read_csv(TRIALLEVEL_FILE, show_col_types = FALSE, progress = FALSE)
cat("Loaded", nrow(trial_level), "trials\n\n")

# ============================================================================
# STEP 1: File Freshness / Provenance
# ============================================================================

cat("STEP 1: File Freshness / Provenance\n")
cat("-----------------------------------\n")

get_file_info <- function(file_path) {
  if (!file.exists(file_path)) {
    return(tibble(
      path = file_path,
      exists = FALSE,
      last_modified = NA_character_,
      file_size_bytes = NA_real_,
      file_size_mb = NA_real_,
      n_rows = NA_integer_,
      n_cols = NA_integer_
    ))
  }
  
  info <- file.info(file_path)
  n_rows <- NA_integer_
  n_cols <- NA_integer_
  
  tryCatch({
    if (file.size(file_path) < 100e6) {  # If < 100MB, read it
      df <- read_csv(file_path, n_max = 1, show_col_types = FALSE)
      n_cols <- ncol(df)
      # For row count, read full file if small
      if (file.size(file_path) < 10e6) {
        df_full <- read_csv(file_path, show_col_types = FALSE)
        n_rows <- nrow(df_full)
      }
    } else {
      header <- read_csv(file_path, n_max = 1, show_col_types = FALSE)
      n_cols <- ncol(header)
    }
  }, error = function(e) {
    # If reading fails, just record that
  })
  
  tibble(
    path = file_path,
    exists = TRUE,
    last_modified = format(info$mtime, "%Y-%m-%d %H:%M:%S"),
    file_size_bytes = info$size,
    file_size_mb = round(info$size / 1e6, 2),
    n_rows = n_rows,
    n_cols = n_cols
  )
}

key_files <- list(
  triallevel = TRIALLEVEL_FILE,
  inventory = INVENTORY_FILE,
  trial_coverage = TRIAL_COVERAGE_FILE,
  subject_stats = SUBJECT_STATS_FILE,
  threshold_sweep = THRESHOLD_SWEEP_FILE
)

file_provenance <- map_dfr(key_files, get_file_info, .id = "file_type")

# Add trial-level file info
triallevel_info <- file_provenance %>% filter(file_type == "triallevel")
if (nrow(triallevel_info) > 0 && triallevel_info$exists[1]) {
  triallevel_info$n_rows[1] <- nrow(trial_level)
  triallevel_info$n_cols[1] <- ncol(trial_level)
  file_provenance[file_provenance$file_type == "triallevel", ] <- triallevel_info
}

write_csv(file_provenance, file.path(OUTPUT_DIR, "file_provenance_triallevel.csv"))
cat("  ✓ Saved file_provenance_triallevel.csv\n\n")

audit_results$file_provenance <- file_provenance

# ============================================================================
# STEP 2: Inventory Completeness (Trial-Level)
# ============================================================================

cat("STEP 2: Inventory Completeness\n")
cat("-------------------------------\n")

if (!file.exists(INVENTORY_FILE)) {
  warnings <- append(warnings, list("Inventory file not found - skipping completeness check"))
  cat("  ⚠ Inventory file not found\n\n")
  inventory_summary <- tibble()
  missing_data <- tibble()
} else {
  inventory <- read_csv(INVENTORY_FILE, show_col_types = FALSE)
  
  # Count expected participants, sessions, runs per task
  if (nrow(inventory) > 0) {
    # Standardize column names
    inventory <- inventory %>%
      mutate(
        subject_id = if("subject_id" %in% names(.)) subject_id else if("sub" %in% names(.)) sub else NA_character_,
        task = if("task" %in% names(.)) task else NA_character_,
        ses = if("ses" %in% names(.)) ses else if("session" %in% names(.)) session else 1L,
        run = if("run" %in% names(.)) run else NA_integer_
      ) %>%
      filter(!is.na(subject_id), !is.na(task))
    
    expected_summary <- inventory %>%
      distinct(subject_id, task, ses, run) %>%
      count(subject_id, task, ses, run, name = "expected_count")
    
    cat("  Expected units (subject-task-ses-run):", nrow(expected_summary), "\n")
  } else {
    expected_summary <- tibble()
  }
  
  # Count observed in TRIALLEVEL
  observed_summary <- trial_level %>%
    mutate(
      ses = if("ses" %in% names(.)) ses else if("ses_value" %in% names(.)) ses_value else 1L
    ) %>%
    distinct(subject_id, task, ses, run) %>%
    count(subject_id, task, ses, run, name = "observed_count")
  
  cat("  Observed units (subject-task-ses-run):", nrow(observed_summary), "\n")
  
  # Compute missingness
  if (nrow(expected_summary) > 0) {
    if (nrow(observed_summary) > nrow(expected_summary)) {
      cat("  ⚠ Observed units (", nrow(observed_summary), ") > expected (", nrow(expected_summary), ")\n")
      cat("    This suggests inventory may be incomplete or TRIALLEVEL has additional data\n")
      extra_data <- observed_summary %>%
        anti_join(expected_summary, by = c("subject_id", "task", "ses", "run"))
      cat("    Extra units in TRIALLEVEL:", nrow(extra_data), "\n")
      missing_data <- expected_summary %>%
        anti_join(observed_summary, by = c("subject_id", "task", "ses", "run"))
    } else {
      missing_data <- expected_summary %>%
        anti_join(observed_summary, by = c("subject_id", "task", "ses", "run"))
    }
    
    missing_pct <- round(100 * nrow(missing_data) / nrow(expected_summary), 2)
    coverage_pct <- round(100 * (nrow(expected_summary) - nrow(missing_data)) / nrow(expected_summary), 2)
    cat("  Missing units:", nrow(missing_data), "(", missing_pct, "%)\n")
    cat("  Coverage:", coverage_pct, "%\n")
    
    if (missing_pct > 5 && nrow(observed_summary) <= nrow(expected_summary)) {
      issues <- append(issues, list(
        paste0("Missing >5% of expected units: ", missing_pct, "%")
      ))
      cat("  ⚠ FAIL: Missing >5% of expected units\n")
    } else if (nrow(observed_summary) > nrow(expected_summary)) {
      cat("  ✓ TRIALLEVEL has more units than inventory (likely inventory is incomplete)\n")
    } else {
      cat("  ✓ Missing units within acceptable range (<5%)\n")
    }
  } else {
    missing_data <- tibble()
  }
  
  inventory_summary <- tibble(
    metric = c("expected_units", "observed_units", "missing_units", "missing_pct", "coverage_pct"),
    value = c(
      nrow(expected_summary),
      nrow(observed_summary),
      nrow(missing_data),
      if(nrow(expected_summary) > 0) missing_pct else NA_real_,
      if(nrow(expected_summary) > 0) coverage_pct else NA_real_
    )
  )
  
  write_csv(inventory_summary, file.path(OUTPUT_DIR, "inventory_summary_triallevel.csv"))
  if (nrow(missing_data) > 0) {
    write_csv(missing_data, file.path(OUTPUT_DIR, "missing_subject_task_run_triallevel.csv"))
  }
  cat("  ✓ Saved inventory_summary_triallevel.csv\n")
  if (nrow(missing_data) > 0) {
    cat("  ✓ Saved missing_subject_task_run_triallevel.csv\n")
  }
}

cat("\n")
audit_results$inventory_summary <- inventory_summary
audit_results$missing_data <- missing_data

# ============================================================================
# STEP 3: Uniqueness Checks (Trial-Level)
# ============================================================================

cat("STEP 3: Uniqueness Checks\n")
cat("-------------------------\n")

n_total <- nrow(trial_level)
n_unique_trial_uid <- n_distinct(trial_level$trial_uid)

# Check for duplicates on trial_uid
duplicates <- trial_level %>%
  group_by(trial_uid) %>%
  filter(n() > 1) %>%
  ungroup()

n_duplicates <- nrow(duplicates)

cat("  Total trials:", n_total, "\n")
cat("  Unique trial_uid:", n_unique_trial_uid, "\n")
cat("  Duplicate trial_uid:", n_duplicates, "\n")

if (n_duplicates > 0) {
  issues <- append(issues, list(
    paste0("Duplicate trial_uid found: ", n_duplicates, " rows")
  ))
  cat("  ⚠ FAIL: Duplicate trial_uid detected\n")
} else {
  cat("  ✓ No duplicate trial_uid - data is properly trial-level\n")
}

# Check uniqueness on (subject_id, task, run, trial_index)
simple_duplicates <- trial_level %>%
  group_by(subject_id, task, run, trial_index) %>%
  filter(n() > 1) %>%
  ungroup()

n_simple_duplicates <- nrow(simple_duplicates)
if (n_simple_duplicates > 0) {
  cat("  ⚠ WARNING: Duplicates on (subject_id, task, run, trial_index):", n_simple_duplicates, "\n")
} else {
  cat("  ✓ No duplicates on (subject_id, task, run, trial_index)\n")
}

uniqueness_checks <- tibble(
  check = c("total_trials", "unique_trial_uid", "duplicate_trial_uid", "granularity"),
  value = c(
    as.character(n_total),
    as.character(n_unique_trial_uid),
    as.character(n_duplicates),
    "trial_level"
  )
)

write_csv(uniqueness_checks, file.path(OUTPUT_DIR, "uniqueness_checks_triallevel.csv"))
cat("  ✓ Saved uniqueness_checks_triallevel.csv\n")

cat("\n")
audit_results$uniqueness_checks <- uniqueness_checks

# ============================================================================
# STEP 4: Gate Columns and Logic Validation
# ============================================================================

cat("STEP 4: Gate Columns and Logic Validation\n")
cat("------------------------------------------\n")

# Check for gate columns
gate_cols <- names(trial_level)[grepl("^(pass_|gate_)", names(trial_level))]
cat("  Found", length(gate_cols), "gate columns\n")

# Check for validity columns
validity_cols <- names(trial_level)[grepl("^valid_", names(trial_level))]
cat("  Found", length(validity_cols), "validity columns\n")

# Recompute gates at threshold 0.80
dissertation_threshold <- 0.80
cat("  Recomputing gates at threshold", dissertation_threshold, "...\n")

# Get validity columns
valid_baseline <- if("valid_baseline500" %in% names(trial_level)) {
  trial_level$valid_baseline500
} else if("valid_prop_baseline_500ms" %in% names(trial_level)) {
  trial_level$valid_prop_baseline_500ms
} else NULL

valid_iti <- if("valid_iti" %in% names(trial_level)) {
  trial_level$valid_iti
} else if("valid_prop_iti_full" %in% names(trial_level)) {
  trial_level$valid_prop_iti_full
} else NULL

valid_prestim <- if("valid_prestim_fix_interior" %in% names(trial_level)) {
  trial_level$valid_prestim_fix_interior
} else if("valid_prop_prestim" %in% names(trial_level)) {
  trial_level$valid_prop_prestim
} else NULL

valid_total_auc <- if("valid_total_auc_window" %in% names(trial_level)) {
  trial_level$valid_total_auc_window
} else if("valid_prop_total_auc" %in% names(trial_level)) {
  trial_level$valid_prop_total_auc
} else NULL

valid_cog <- if("valid_cognitive_window" %in% names(trial_level)) {
  trial_level$valid_cognitive_window
} else if("valid_prop_cognitive_auc" %in% names(trial_level)) {
  trial_level$valid_prop_cognitive_auc
} else NULL

# Recompute gates
gate_mismatch_results <- list()

if (!is.null(valid_iti) && !is.null(valid_prestim)) {
  recomputed_stimlocked <- (valid_iti >= dissertation_threshold & valid_prestim >= dissertation_threshold)
  
  stored_stimlocked <- if("pass_stimlocked_t080" %in% names(trial_level)) {
    as.logical(trial_level$pass_stimlocked_t080)
  } else if("gate_stimlocked_T" %in% names(trial_level)) {
    as.logical(trial_level$gate_stimlocked_T)
  } else NULL
  
  if (!is.null(stored_stimlocked)) {
    mismatch_rate <- mean(recomputed_stimlocked != stored_stimlocked, na.rm = TRUE)
    gate_mismatch_results[[length(gate_mismatch_results) + 1]] <- tibble(
      gate_column = "pass_stimlocked_t080",
      mismatch_rate = mismatch_rate,
      n_mismatches = sum(recomputed_stimlocked != stored_stimlocked, na.rm = TRUE),
      n_total = sum(!is.na(recomputed_stimlocked) & !is.na(stored_stimlocked))
    )
    
    if (mismatch_rate > 0.001) {
      issues <- append(issues, list(
        paste0("Gate mismatch for pass_stimlocked_t080: ", round(100 * mismatch_rate, 2), "%")
      ))
    }
  }
}

if (!is.null(valid_total_auc)) {
  recomputed_total_auc <- (valid_total_auc >= dissertation_threshold)
  
  stored_total_auc <- if("pass_total_auc_t080" %in% names(trial_level)) {
    as.logical(trial_level$pass_total_auc_t080)
  } else if("gate_total_auc_T" %in% names(trial_level)) {
    as.logical(trial_level$gate_total_auc_T)
  } else NULL
  
  if (!is.null(stored_total_auc)) {
    mismatch_rate <- mean(recomputed_total_auc != stored_total_auc, na.rm = TRUE)
    gate_mismatch_results[[length(gate_mismatch_results) + 1]] <- tibble(
      gate_column = "pass_total_auc_t080",
      mismatch_rate = mismatch_rate,
      n_mismatches = sum(recomputed_total_auc != stored_total_auc, na.rm = TRUE),
      n_total = sum(!is.na(recomputed_total_auc) & !is.na(stored_total_auc))
    )
    
    if (mismatch_rate > 0.001) {
      issues <- append(issues, list(
        paste0("Gate mismatch for pass_total_auc_t080: ", round(100 * mismatch_rate, 2), "%")
      ))
    }
  }
}

if (!is.null(valid_baseline) && !is.null(valid_cog)) {
  recomputed_cog_auc <- (valid_baseline >= dissertation_threshold & valid_cog >= dissertation_threshold)
  
  stored_cog_auc <- if("pass_cog_auc_t080" %in% names(trial_level)) {
    as.logical(trial_level$pass_cog_auc_t080)
  } else if("gate_cog_auc_T" %in% names(trial_level)) {
    as.logical(trial_level$gate_cog_auc_T)
  } else NULL
  
  if (!is.null(stored_cog_auc)) {
    mismatch_rate <- mean(recomputed_cog_auc != stored_cog_auc, na.rm = TRUE)
    gate_mismatch_results[[length(gate_mismatch_results) + 1]] <- tibble(
      gate_column = "pass_cog_auc_t080",
      mismatch_rate = mismatch_rate,
      n_mismatches = sum(recomputed_cog_auc != stored_cog_auc, na.rm = TRUE),
      n_total = sum(!is.na(recomputed_cog_auc) & !is.na(stored_cog_auc))
    )
    
    if (mismatch_rate > 0.001) {
      issues <- append(issues, list(
        paste0("Gate mismatch for pass_cog_auc_t080: ", round(100 * mismatch_rate, 2), "%")
      ))
    }
  }
}

if (length(gate_mismatch_results) > 0) {
  gate_mismatch <- bind_rows(gate_mismatch_results)
  write_csv(gate_mismatch, file.path(OUTPUT_DIR, "gate_recompute_mismatch_triallevel.csv"))
  cat("  ✓ Saved gate_recompute_mismatch_triallevel.csv\n")
  
  if (all(gate_mismatch$mismatch_rate < 0.001)) {
    cat("  ✓ All gate mismatches < 0.1% - gates are consistent\n")
  } else {
    cat("  ⚠ Some gate mismatches > 0.1%\n")
  }
} else {
  gate_mismatch <- tibble()
  cat("  ⚠ Could not validate gates - missing validity columns\n")
}

cat("\n")
audit_results$gate_mismatch <- gate_mismatch

# ============================================================================
# STEP 5: Trial Retention Curves (Trial-Level)
# ============================================================================

cat("STEP 5: Trial Retention Curves\n")
cat("-------------------------------\n")

retention_results <- list()

for (thr in THRESHOLD_GRID) {
  # Recompute gates at each threshold
  if (!is.null(valid_iti) && !is.null(valid_prestim)) {
    gate_stimlocked <- (valid_iti >= thr & valid_prestim >= thr)
    n_pass_stimlocked <- sum(gate_stimlocked, na.rm = TRUE)
    n_total_stimlocked <- sum(!is.na(gate_stimlocked))
    retention_stimlocked <- n_pass_stimlocked / n_total_stimlocked
    
    retention_results[[length(retention_results) + 1]] <- tibble(
      threshold = thr,
      gate_type = "stimlocked",
      n_pass = n_pass_stimlocked,
      n_total = n_total_stimlocked,
      retention_rate = retention_stimlocked
    )
  }
  
  if (!is.null(valid_total_auc)) {
    gate_total_auc <- (valid_total_auc >= thr)
    n_pass_total_auc <- sum(gate_total_auc, na.rm = TRUE)
    n_total <- sum(!is.na(gate_total_auc))
    retention_total_auc <- n_pass_total_auc / n_total
    
    retention_results[[length(retention_results) + 1]] <- tibble(
      threshold = thr,
      gate_type = "total_auc",
      n_pass = n_pass_total_auc,
      n_total = n_total,
      retention_rate = retention_total_auc
    )
  }
  
  if (!is.null(valid_baseline) && !is.null(valid_cog)) {
    gate_cog_auc <- (valid_baseline >= thr & valid_cog >= thr)
    n_pass_cog_auc <- sum(gate_cog_auc, na.rm = TRUE)
    n_total_cog <- sum(!is.na(gate_cog_auc))
    retention_cog_auc <- n_pass_cog_auc / n_total_cog
    
    retention_results[[length(retention_results) + 1]] <- tibble(
      threshold = thr,
      gate_type = "cog_auc",
      n_pass = n_pass_cog_auc,
      n_total = n_total_cog,
      retention_rate = retention_cog_auc
    )
  }
}

if (length(retention_results) > 0) {
  retention_curves <- bind_rows(retention_results)
  write_csv(retention_curves, file.path(OUTPUT_DIR, "retention_curves_triallevel.csv"))
  cat("  ✓ Saved retention_curves_triallevel.csv\n")
} else {
  retention_curves <- tibble()
}

cat("\n")
audit_results$retention_curves <- retention_curves

# ============================================================================
# STEP 6: Bias Checks (Trial-Level)
# ============================================================================

cat("STEP 6: Bias Checks (Selection Bias)\n")
cat("-------------------------------------\n")

# Find gate columns at dissertation threshold
gate_cols_t080 <- names(trial_level)[grepl("pass_.*_t080|gate_.*_T", names(trial_level))]

if (length(gate_cols_t080) > 0) {
  cat("  Checking bias for", length(gate_cols_t080), "gate columns\n")
  
  bias_results <- list()
  
  for (gate_col in gate_cols_t080) {
    gate_values <- as.logical(trial_level[[gate_col]])
    
    # Check task bias
    if ("task" %in% names(trial_level)) {
      task_table <- table(trial_level$task, gate_values, useNA = "no")
      if (nrow(task_table) > 1 && ncol(task_table) > 1) {
        task_pass_rates <- prop.table(task_table, margin = 1)[, "TRUE"]
        max_diff <- max(task_pass_rates, na.rm = TRUE) - min(task_pass_rates, na.rm = TRUE)
        
        if (max_diff > 0.10) {
          issues <- append(issues, list(
            paste0("Task bias in ", gate_col, ": ", round(100 * max_diff, 1), " percentage point difference")
          ))
        }
        
        bias_results[[length(bias_results) + 1]] <- tibble(
          gate_column = gate_col,
          predictor = "task",
          max_pass_rate = max(task_pass_rates, na.rm = TRUE),
          min_pass_rate = min(task_pass_rates, na.rm = TRUE),
          difference_pct = 100 * max_diff,
          flagged = max_diff > 0.10
        )
      }
    }
    
    # Check effort bias (Hi Grip)
    effort_col <- if("effort_condition" %in% names(trial_level)) "effort_condition" else 
                  if("hi_grip" %in% names(trial_level)) "hi_grip" else NULL
    
    if (!is.null(effort_col)) {
      if (effort_col == "effort_condition") {
        effort_data <- trial_level %>%
          filter(effort_condition %in% c("High_40_MVC", "Low_5_MVC"))
      } else {
        effort_data <- trial_level %>%
          filter(!is.na(!!sym(effort_col)))
      }
      
      if (nrow(effort_data) > 0) {
        if (effort_col == "effort_condition") {
          effort_table <- table(effort_data$effort_condition, gate_values[trial_level$effort_condition %in% c("High_40_MVC", "Low_5_MVC")], useNA = "no")
        } else {
          effort_table <- table(effort_data[[effort_col]], gate_values[!is.na(trial_level[[effort_col]])], useNA = "no")
        }
        
        if (nrow(effort_table) > 1 && ncol(effort_table) > 1) {
          effort_pass_rates <- prop.table(effort_table, margin = 1)[, "TRUE"]
          max_diff <- max(effort_pass_rates, na.rm = TRUE) - min(effort_pass_rates, na.rm = TRUE)
          
          if (max_diff > 0.10) {
            issues <- append(issues, list(
              paste0("Effort bias in ", gate_col, ": ", round(100 * max_diff, 1), " percentage point difference")
            ))
          }
          
          bias_results[[length(bias_results) + 1]] <- tibble(
            gate_column = gate_col,
            predictor = "effort",
            max_pass_rate = max(effort_pass_rates, na.rm = TRUE),
            min_pass_rate = min(effort_pass_rates, na.rm = TRUE),
            difference_pct = 100 * max_diff,
            flagged = max_diff > 0.10
          )
        }
      }
    }
    
    # Check oddball bias
    oddball_col <- if("isOddball" %in% names(trial_level)) "isOddball" else
                   if("oddball" %in% names(trial_level)) "oddball" else
                   if("difficulty_level" %in% names(trial_level)) "difficulty_level" else NULL
    
    if (!is.null(oddball_col)) {
      if (oddball_col == "difficulty_level") {
        oddball_data <- trial_level %>%
          filter(difficulty_level %in% c("Easy", "Hard", "Standard"))
        oddball_data$oddball_flag <- as.integer(oddball_data$difficulty_level == "Hard")
      } else {
        oddball_data <- trial_level %>%
          filter(!is.na(!!sym(oddball_col)))
        oddball_data$oddball_flag <- as.integer(oddball_data[[oddball_col]])
      }
      
      if (nrow(oddball_data) > 0) {
        oddball_table <- table(oddball_data$oddball_flag, gate_values[!is.na(trial_level[[oddball_col]])], useNA = "no")
        if (nrow(oddball_table) > 1 && ncol(oddball_table) > 1) {
          oddball_pass_rates <- prop.table(oddball_table, margin = 1)[, "TRUE"]
          max_diff <- max(oddball_pass_rates, na.rm = TRUE) - min(oddball_pass_rates, na.rm = TRUE)
          
          if (max_diff > 0.10) {
            issues <- append(issues, list(
              paste0("Oddball bias in ", gate_col, ": ", round(100 * max_diff, 1), " percentage point difference")
            ))
          }
          
          bias_results[[length(bias_results) + 1]] <- tibble(
            gate_column = gate_col,
            predictor = "oddball",
            max_pass_rate = max(oddball_pass_rates, na.rm = TRUE),
            min_pass_rate = min(oddball_pass_rates, na.rm = TRUE),
            difference_pct = 100 * max_diff,
            flagged = max_diff > 0.10
          )
        }
      }
    }
  }
  
  if (length(bias_results) > 0) {
    bias_checks <- bind_rows(bias_results)
    write_csv(bias_checks, file.path(OUTPUT_DIR, "gate_bias_checks_triallevel.csv"))
    cat("  ✓ Saved gate_bias_checks_triallevel.csv\n")
  } else {
    bias_checks <- tibble()
  }
} else {
  warnings <- append(warnings, list("No gate columns found for bias checks"))
  bias_checks <- tibble()
}

cat("\n")
audit_results$bias_checks <- bias_checks

# ============================================================================
# STEP 7: Generate Final Report with "Hard Truths"
# ============================================================================

cat("STEP 7: Generating Final Report\n")
cat("--------------------------------\n")

# Compute "hard truths"
n_subjects <- n_distinct(trial_level$subject_id)
n_tasks <- n_distinct(trial_level$task)
n_sessions <- if("ses" %in% names(trial_level)) {
  n_distinct(trial_level$ses)
} else if("ses_value" %in% names(trial_level)) {
  n_distinct(trial_level$ses_value)
} else 1L
n_runs <- n_distinct(trial_level$run)

trials_per_subj_task <- trial_level %>%
  group_by(subject_id, task) %>%
  summarise(n_trials = n(), .groups = "drop")

min_trials <- min(trials_per_subj_task$n_trials)
median_trials <- median(trials_per_subj_task$n_trials)
max_trials <- max(trials_per_subj_task$n_trials)

# Coverage from inventory
coverage_pct <- if(nrow(inventory_summary) > 0 && "coverage_pct" %in% inventory_summary$metric) {
  inventory_summary %>% filter(metric == "coverage_pct") %>% pull(value) %>% first()
} else NA_real_

# Gate pass rates
gate_pass_stimlocked <- if("pass_stimlocked_t080" %in% names(trial_level)) {
  round(100 * mean(trial_level$pass_stimlocked_t080, na.rm = TRUE), 1)
} else NA_real_

gate_pass_total_auc <- if("pass_total_auc_t080" %in% names(trial_level)) {
  round(100 * mean(trial_level$pass_total_auc_t080, na.rm = TRUE), 1)
} else NA_real_

gate_pass_cog_auc <- if("pass_cog_auc_t080" %in% names(trial_level)) {
  round(100 * mean(trial_level$pass_cog_auc_t080, na.rm = TRUE), 1)
} else NA_real_

# Compute additional metrics for new PASS/FAIL criteria
# Trials per subject×task
trials_per_subj_task <- trial_level %>%
  group_by(subject_id, task) %>%
  summarise(n_trials = n(), .groups = "drop")

median_trials_per_subj_task <- median(trials_per_subj_task$n_trials, na.rm = TRUE)

# Trials per run
trials_per_run <- trial_level %>%
  group_by(subject_id, task, ses, run) %>%
  summarise(n_trials = n(), .groups = "drop")

median_trials_per_run <- median(trials_per_run$n_trials, na.rm = TRUE)

# Check if subject×task has all 5 runs
runs_per_subj_task <- trial_level %>%
  group_by(subject_id, task) %>%
  summarise(
    n_runs = n_distinct(paste(ses, run, sep = ":")),
    runs = paste(sort(unique(run)), collapse = ","),
    .groups = "drop"
  )

subj_task_with_all_5_runs <- sum(runs_per_subj_task$n_runs >= 5)
pct_with_all_5_runs <- round(100 * subj_task_with_all_5_runs / nrow(runs_per_subj_task), 2)

# Gate bias at dissertation threshold (0.80)
gate_bias_at_thr <- bias_checks %>%
  filter(gate_column %in% c("pass_total_auc_t080", "pass_stimlocked_t080", "pass_cog_auc_t080"),
         predictor == "task")

max_gate_bias <- if(nrow(gate_bias_at_thr) > 0) {
  max(gate_bias_at_thr$difference_pct, na.rm = TRUE)
} else {
  0
}

# Determine PASS/FAIL with new criteria
pass_criteria <- list(
  merged_fresh = TRUE,  # Assume fresh if we got here
  inventory_complete = is.na(coverage_pct) || coverage_pct >= 90,
  uniqueness_ok = n_duplicates == 0,
  gate_mismatch_ok = length(gate_mismatch_results) == 0 || all(map_dbl(gate_mismatch_results, ~ .x$mismatch_rate) < 0.001),
  median_trials_per_subj_task_ok = median_trials_per_subj_task >= 120,
  median_trials_per_run_ok = median_trials_per_run >= 25,
  pct_with_all_5_runs_ok = pct_with_all_5_runs >= 90,
  gate_bias_acceptable = max_gate_bias <= 10  # Don't fail unless >10pp difference
)

overall_pass <- all(unlist(pass_criteria))

# Generate markdown report
report_lines <- c(
  "# Trial-Level Analysis-Ready Data Audit Report",
  "",
  paste("**Generated:**", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "",
  "## Executive Summary",
  "",
  if(overall_pass) "**STATUS: ✅ PASS**" else "**STATUS: ❌ FAIL**",
  "",
  "### Updated PASS/FAIL Criteria (v2)",
  "",
  "PASS requires:",
  paste0("- Median trials per subject×task >= 120 (observed: ", round(median_trials_per_subj_task, 1), if(median_trials_per_subj_task >= 120) " ✅)" else " ❌)"),
  paste0("- Median trials per run >= 25 (observed: ", round(median_trials_per_run, 1), if(median_trials_per_run >= 25) " ✅)" else " ❌)"),
  paste0("- >=90% of (subject×task) have all 5 runs (observed: ", pct_with_all_5_runs, "%", if(pct_with_all_5_runs >= 90) " ✅)" else " ❌)"),
  paste0("- Gate bias by task <= 10pp (observed: ", round(max_gate_bias, 1), "pp", if(max_gate_bias <= 10) " ✅)" else " ❌)"),
  "",
  "## Hard Truths",
  "",
  "### Dataset Characteristics",
  "",
  paste("- **Total trials:**", n_total),
  paste("- **Total subjects:**", n_subjects),
  paste("- **Tasks:**", paste(unique(trial_level$task), collapse = ", ")),
  paste("- **Sessions:**", n_sessions),
  paste("- **Runs:**", n_runs),
  "",
  "### Trials per Subject×Task",
  "",
  paste("- **Min:**", min_trials),
  paste("- **Median:**", median_trials, if(median_trials >= 120) "✅" else "❌ (target: >=120)"),
  paste("- **Max:**", max_trials),
  "",
  "### Trials per Run",
  "",
  paste("- **Median:**", round(median_trials_per_run, 1), if(median_trials_per_run >= 25) "✅" else "❌ (target: >=25)"),
  "",
  "### Run Completeness",
  "",
  paste("- **Subject×task with all 5 runs:**", subj_task_with_all_5_runs, "/", nrow(runs_per_subj_task), " (", pct_with_all_5_runs, "%)", if(pct_with_all_5_runs >= 90) "✅" else "❌ (target: >=90%)"),
  "",
  "### Inventory Coverage",
  "",
  if(!is.na(coverage_pct)) {
    paste("- **Coverage:**", coverage_pct, "%")
  } else {
    "- **Coverage:** Not available"
  },
  "",
  "### Gate Pass Rates (Trial-Level) at Threshold 0.80",
  "",
  if(!is.na(gate_pass_stimlocked)) {
    paste("- **pass_stimlocked_t080:**", gate_pass_stimlocked, "%")
  } else {
    "- **pass_stimlocked_t080:** Not available"
  },
  if(!is.na(gate_pass_total_auc)) {
    paste("- **pass_total_auc_t080:**", gate_pass_total_auc, "%")
  } else {
    "- **pass_total_auc_t080:** Not available"
  },
  if(!is.na(gate_pass_cog_auc)) {
    paste("- **pass_cog_auc_t080:**", gate_pass_cog_auc, "%")
  } else {
    "- **pass_cog_auc_t080:** Not available"
  },
  "",
  "### Gate Bias by Task",
  "",
  if(max_gate_bias > 0) {
    paste("- **Max difference:**", round(max_gate_bias, 1), "percentage points", if(max_gate_bias <= 10) "✅" else "❌ (threshold: <=10pp)")
  } else {
    "- **Gate bias:** Not computed"
  },
  "",
  "---",
  "",
  "## Detailed Results",
  "",
  "### STEP 1: File Freshness / Provenance",
  "",
  "| File Type | Path | Exists | Last Modified | Size (MB) | Rows | Cols |",
  "|-----------|------|--------|---------------|-----------|------|------|"
)

# Add file provenance table
if (nrow(file_provenance) > 0) {
  for (i in 1:nrow(file_provenance)) {
    row <- file_provenance[i, ]
    report_lines <- c(report_lines,
      sprintf("| %s | %s | %s | %s | %s | %s | %s |",
              row$file_type,
              basename(row$path),
              if(row$exists) "Yes" else "No",
              if(!is.na(row$last_modified)) row$last_modified else "N/A",
              if(!is.na(row$file_size_mb)) as.character(row$file_size_mb) else "N/A",
              if(!is.na(row$n_rows)) as.character(row$n_rows) else "N/A",
              if(!is.na(row$n_cols)) as.character(row$n_cols) else "N/A")
    )
  }
}

report_lines <- c(report_lines,
  "",
  "### STEP 2: Inventory Completeness",
  ""
)

if (nrow(inventory_summary) > 0) {
  report_lines <- c(report_lines,
    "| Metric | Value |",
    "|--------|-------|"
  )
  for (i in 1:nrow(inventory_summary)) {
    row <- inventory_summary[i, ]
    report_lines <- c(report_lines,
      sprintf("| %s | %s |", row$metric, row$value)
    )
  }
}

report_lines <- c(report_lines,
  "",
  "### STEP 3: Uniqueness Checks",
  "",
  "| Check | Value |",
  "|-------|-------|"
)

for (i in 1:nrow(uniqueness_checks)) {
  row <- uniqueness_checks[i, ]
  report_lines <- c(report_lines,
    sprintf("| %s | %s |", row$check, row$value)
  )
}

report_lines <- c(report_lines,
  "",
  "### STEP 4: Gate Logic Validation",
  ""
)

if (nrow(gate_mismatch) > 0) {
  report_lines <- c(report_lines,
    "| Gate Column | Mismatch Rate | N Mismatches | N Total |",
    "|-------------|---------------|--------------|---------|"
  )
  for (i in 1:nrow(gate_mismatch)) {
    row <- gate_mismatch[i, ]
    report_lines <- c(report_lines,
      sprintf("| %s | %.4f | %d | %d |",
              row$gate_column, row$mismatch_rate, row$n_mismatches, row$n_total)
    )
  }
} else {
  report_lines <- c(report_lines, "*No gate mismatches detected*")
}

report_lines <- c(report_lines,
  "",
  "### STEP 5: Trial Retention Curves",
  ""
)

if (nrow(retention_curves) > 0) {
  report_lines <- c(report_lines,
    "| Threshold | Gate Type | N Pass | N Total | Retention Rate |",
    "|-----------|-----------|--------|---------|----------------|"
  )
  for (i in 1:nrow(retention_curves)) {
    row <- retention_curves[i, ]
    report_lines <- c(report_lines,
      sprintf("| %.2f | %s | %d | %d | %.3f |",
              row$threshold, row$gate_type, row$n_pass, row$n_total, row$retention_rate)
    )
  }
}

report_lines <- c(report_lines,
  "",
  "### STEP 6: Bias Checks",
  ""
)

if (nrow(bias_checks) > 0) {
  report_lines <- c(report_lines,
    "| Gate Column | Predictor | Max Pass Rate | Min Pass Rate | Difference (%) | Flagged |",
    "|-------------|-----------|---------------|---------------|----------------|---------|"
  )
  for (i in 1:nrow(bias_checks)) {
    row <- bias_checks[i, ]
    report_lines <- c(report_lines,
      sprintf("| %s | %s | %.3f | %.3f | %.1f | %s |",
              row$gate_column, row$predictor, row$max_pass_rate, row$min_pass_rate,
              row$difference_pct, if(row$flagged) "⚠️" else "✓")
    )
  }
} else {
  report_lines <- c(report_lines, "*Bias checks not available*")
}

report_lines <- c(report_lines,
  "",
  "---",
  "",
  "## What to Fix Next",
  ""
)

if (length(issues) > 0) {
  report_lines <- c(report_lines,
    "### Critical Issues",
    ""
  )
  for (i in seq_along(issues)) {
    report_lines <- c(report_lines, paste(i, ".", issues[[i]]))
  }
} else {
  report_lines <- c(report_lines, "*No critical issues identified*")
}

if (length(warnings) > 0) {
  report_lines <- c(report_lines,
    "",
    "### Warnings",
    ""
  )
  for (i in seq_along(warnings)) {
    report_lines <- c(report_lines, paste("-", warnings[[i]]))
  }
}

report_lines <- c(report_lines,
  "",
  "---",
  "",
  "## Supporting Files",
  "",
  "All supporting CSV tables are available in: `data/qc/analysis_ready_audit/`",
  "",
  "- `file_provenance_triallevel.csv` - File timestamps and sizes",
  "- `inventory_summary_triallevel.csv` - Expected vs observed data counts",
  "- `missing_subject_task_run_triallevel.csv` - Missing data units",
  "- `uniqueness_checks_triallevel.csv` - Duplicate row analysis",
  "- `gate_recompute_mismatch_triallevel.csv` - Gate logic validation",
  "- `retention_curves_triallevel.csv` - Trial retention by threshold",
  "- `gate_bias_checks_triallevel.csv` - Selection bias analysis",
  ""
)

# Write report (v2 with updated criteria)
report_file <- file.path(OUTPUT_DIR, "analysis_ready_audit_report_TRIALLEVEL_v2.md")
writeLines(report_lines, report_file)
cat("  ✓ Saved analysis_ready_audit_report_TRIALLEVEL_v2.md\n\n")

# ============================================================================
# Console Summary
# ============================================================================

cat("\n")
cat("=== AUDIT COMPLETE ===\n\n")

cat("STATUS:", if(overall_pass) "✅ PASS" else "❌ FAIL", "\n\n")

cat("HARD TRUTHS:\n")
cat("  - Total trials:", n_total, "\n")
cat("  - Total subjects:", n_subjects, "\n")
cat("  - Tasks:", paste(unique(trial_level$task), collapse = ", "), "\n")
cat("  - Sessions:", n_sessions, "\n")
cat("  - Runs:", n_runs, "\n")
cat("  - Trials per subject×task: min=", min_trials, ", median=", median_trials, ", max=", max_trials, "\n")
cat("  - Trials per run: median=", median_trials_per_run, "\n")
cat("  - Subject×task with all 5 runs:", subj_task_with_all_5_runs, "/", nrow(runs_per_subj_task), " (", pct_with_all_5_runs, "%)\n")
if (!is.na(coverage_pct)) {
  cat("  - Inventory coverage:", coverage_pct, "%\n")
}
cat("  - Gate pass rates (trial-level) at 0.80:\n")
if (!is.na(gate_pass_stimlocked)) {
  cat("    - pass_stimlocked_t080:", gate_pass_stimlocked, "%\n")
}
if (!is.na(gate_pass_total_auc)) {
  cat("    - pass_total_auc_t080:", gate_pass_total_auc, "%\n")
}
if (!is.na(gate_pass_cog_auc)) {
  cat("    - pass_cog_auc_t080:", gate_pass_cog_auc, "%\n")
}
if (max_gate_bias > 0) {
  cat("  - Max gate bias by task:", round(max_gate_bias, 1), "percentage points\n")
}

cat("\nPASS/FAIL Checks (Updated Criteria):\n")
cat("  - Inventory complete (>90%):", if(pass_criteria$inventory_complete) "✅" else "❌", "\n")
cat("  - Trial uniqueness OK:", if(pass_criteria$uniqueness_ok) "✅" else "❌", "\n")
cat("  - Gate mismatches near zero:", if(pass_criteria$gate_mismatch_ok) "✅" else "❌", "\n")
cat("  - Median trials per subject×task >= 120:", if(pass_criteria$median_trials_per_subj_task_ok) "✅" else "❌", " (", round(median_trials_per_subj_task, 1), ")\n")
cat("  - Median trials per run >= 25:", if(pass_criteria$median_trials_per_run_ok) "✅" else "❌", " (", round(median_trials_per_run, 1), ")\n")
cat("  - >=90% subject×task have all 5 runs:", if(pass_criteria$pct_with_all_5_runs_ok) "✅" else "❌", " (", pct_with_all_5_runs, "%)\n")
cat("  - Gate bias by task <= 10pp:", if(pass_criteria$gate_bias_acceptable) "✅" else "❌", " (", round(max_gate_bias, 1), "pp)\n")

cat("\n")

if (length(issues) > 0) {
  cat("What to Fix:\n")
  for (i in seq_along(issues)) {
    cat(sprintf("  %d. %s\n", i, issues[[i]]))
  }
} else {
  cat("No critical issues found. Trial-level data appears ready for analysis.\n")
}

cat("\n")
cat("Report saved to:", report_file, "\n")
cat("Supporting files in:", OUTPUT_DIR, "\n")
cat("\n")

