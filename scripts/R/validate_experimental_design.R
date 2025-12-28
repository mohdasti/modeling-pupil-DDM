#!/usr/bin/env Rscript
# =========================================================================
# EXPERIMENTAL DESIGN VALIDATION
# =========================================================================
# Comprehensive validation of experimental design constraints and data integrity
# Ensures data matches experimental design specifications
# =========================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

# =========================================================================
# EXPERIMENTAL DESIGN SPECIFICATIONS
# =========================================================================

EXPECTED_DIFFICULTY_LEVELS <- c("Standard", "Hard", "Easy")
EXPECTED_TASKS <- c("ADT", "VDT")
EXPECTED_EFFORT_CONDITIONS <- c("Low_5_MVC", "High_40_MVC")

# Stimulus level mappings (from experimental design)
STANDARD_STIM_LEVELS <- c(0, NA)  # No difference
HARD_STIM_LEVELS <- c(0, 1, 2, 8, 16, 0.06, 0.12)  # Small differences
EASY_STIM_LEVELS <- c(3, 4, 32, 64, 0.24, 0.48)  # Large differences

# Expected RT ranges (in seconds)
MIN_RT <- 0.25  # 250ms floor (response-signal design)
MAX_RT <- 3.0   # 3s ceiling

# Expected accuracy ranges (proportions)
MIN_ACCURACY <- 0.50  # At least chance level
MAX_ACCURACY <- 1.00

# Expected response distributions on Standard trials
EXPECTED_STD_PROP_SAME <- 0.85  # ~85-90% "same" responses
EXPECTED_STD_PROP_DIFF <- 0.15  # ~10-15% "different" responses
TOLERANCE_STD_PROP <- 0.10  # Allow ±10% deviation

# =========================================================================
# VALIDATION FUNCTIONS
# =========================================================================

validate_difficulty_levels <- function(data, log_fn = cat) {
  # Validate difficulty level assignments match stimulus properties
  log_fn("\n=== VALIDATION: Difficulty Level Assignments ===\n")
  
  issues <- list()
  
  # Check 1: All difficulty levels are valid
  invalid_levels <- setdiff(unique(data$difficulty_level), EXPECTED_DIFFICULTY_LEVELS)
  if (length(invalid_levels) > 0) {
    issues$invalid_levels <- invalid_levels
    log_fn("  ✗ Invalid difficulty levels found:", paste(invalid_levels, collapse=", "), "\n")
  } else {
    log_fn("  ✓ All difficulty levels are valid\n")
  }
  
  # Check 2: Standard trials have isOddball == 0
  std_trials <- data %>% filter(difficulty_level == "Standard")
  if (nrow(std_trials) > 0) {
    std_with_oddball <- sum(std_trials$isOddball == 1, na.rm = TRUE)
    if (std_with_oddball > 0) {
      issues$std_with_oddball <- std_with_oddball
      log_fn(sprintf("  ✗ %d Standard trials have isOddball=1 (should be 0)\n", std_with_oddball))
    } else {
      log_fn("  ✓ All Standard trials have isOddball=0\n")
    }
  }
  
  # Check 3: Hard/Easy trials have isOddball == 1
  diff_trials <- data %>% filter(difficulty_level %in% c("Hard", "Easy"))
  if (nrow(diff_trials) > 0) {
    diff_without_oddball <- sum(diff_trials$isOddball == 0, na.rm = TRUE)
    if (diff_without_oddball > 0) {
      issues$diff_without_oddball <- diff_without_oddball
      log_fn(sprintf("  ✗ %d Hard/Easy trials have isOddball=0 (should be 1)\n", diff_without_oddball))
    } else {
      log_fn("  ✓ All Hard/Easy trials have isOddball=1\n")
    }
  }
  
  # Check 4: Stimulus level consistency
  if ("stimLev" %in% names(data)) {
    # Standard should have stimLev == 0 or NA
    std_stim <- std_trials %>% filter(!is.na(stimLev), stimLev != 0)
    if (nrow(std_stim) > 0) {
      issues$std_wrong_stim <- nrow(std_stim)
      log_fn(sprintf("  ✗ %d Standard trials have non-zero stimLev\n", nrow(std_stim)))
    } else {
      log_fn("  ✓ Standard trials have stimLev=0 or NA\n")
    }
    
    # Hard should have stimLev in HARD_STIM_LEVELS
    hard_trials <- data %>% filter(difficulty_level == "Hard")
    if (nrow(hard_trials) > 0) {
      hard_stim <- hard_trials %>% 
        filter(!is.na(stimLev), !stimLev %in% HARD_STIM_LEVELS)
      if (nrow(hard_stim) > 0) {
        issues$hard_wrong_stim <- nrow(hard_stim)
        log_fn(sprintf("  ✗ %d Hard trials have unexpected stimLev values\n", nrow(hard_stim)))
        log_fn("    Unexpected values:", paste(unique(hard_stim$stimLev), collapse=", "), "\n")
      } else {
        log_fn("  ✓ Hard trials have expected stimLev values\n")
      }
    }
    
    # Easy should have stimLev in EASY_STIM_LEVELS
    easy_trials <- data %>% filter(difficulty_level == "Easy")
    if (nrow(easy_trials) > 0) {
      easy_stim <- easy_trials %>% 
        filter(!is.na(stimLev), !stimLev %in% EASY_STIM_LEVELS)
      if (nrow(easy_stim) > 0) {
        issues$easy_wrong_stim <- nrow(easy_stim)
        log_fn(sprintf("  ✗ %d Easy trials have unexpected stimLev values\n", nrow(easy_stim)))
        log_fn("    Unexpected values:", paste(unique(easy_stim$stimLev), collapse=", "), "\n")
      } else {
        log_fn("  ✓ Easy trials have expected stimLev values\n")
      }
    }
  }
  
  return(issues)
}

validate_response_side_coding <- function(data, log_fn = cat) {
  # Validate response-side coding (dec_upper) matches data reality
  log_fn("\n=== VALIDATION: Response-Side Coding ===\n")
  
  issues <- list()
  
  # Check 1: dec_upper column exists
  if (!"dec_upper" %in% names(data)) {
    issues$missing_dec_upper <- TRUE
    log_fn("  ✗ dec_upper column missing!\n")
    return(issues)
  } else {
    log_fn("  ✓ dec_upper column present\n")
  }
  
  # Check 2: dec_upper contains only 0, 1, or NA
  invalid_dec <- setdiff(unique(data$dec_upper[!is.na(data$dec_upper)]), c(0L, 1L))
  if (length(invalid_dec) > 0) {
    issues$invalid_dec_values <- invalid_dec
    log_fn("  ✗ dec_upper contains invalid values:", paste(invalid_dec, collapse=", "), "\n")
  } else {
    log_fn("  ✓ dec_upper contains only 0, 1, or NA\n")
  }
  
  # Check 3: Response labels match dec_upper
  if ("response_label" %in% names(data)) {
    mismatches <- data %>%
      filter(!is.na(dec_upper) & !is.na(response_label)) %>%
      filter(
        (dec_upper == 1 & response_label != "different") |
        (dec_upper == 0 & response_label != "same")
      )
    
    if (nrow(mismatches) > 0) {
      issues$label_mismatches <- nrow(mismatches)
      log_fn(sprintf("  ✗ %d trials have mismatched response_label and dec_upper\n", nrow(mismatches)))
    } else {
      log_fn("  ✓ response_label matches dec_upper\n")
    }
  }
  
  # Check 4: Standard trials show expected "same" bias
  std_trials <- data %>% filter(difficulty_level == "Standard")
  if (nrow(std_trials) > 0) {
    prop_same <- 1 - mean(std_trials$dec_upper, na.rm = TRUE)
    prop_diff <- mean(std_trials$dec_upper, na.rm = TRUE)
    
    log_fn(sprintf("  Standard trials - Proportion 'Same': %.3f\n", prop_same))
    log_fn(sprintf("  Standard trials - Proportion 'Different': %.3f\n", prop_diff))
    
    if (prop_same < (EXPECTED_STD_PROP_SAME - TOLERANCE_STD_PROP)) {
      issues$std_too_few_same <- prop_same
      log_fn(sprintf("  ✗ Standard trials show too few 'Same' responses (expected: ≥%.2f)\n", 
                     EXPECTED_STD_PROP_SAME - TOLERANCE_STD_PROP))
    } else if (prop_same > (EXPECTED_STD_PROP_SAME + TOLERANCE_STD_PROP)) {
      issues$std_too_many_same <- prop_same
      log_fn(sprintf("  ⚠ Standard trials show unusually many 'Same' responses (expected: ~%.2f)\n", 
                     EXPECTED_STD_PROP_SAME))
    } else {
      log_fn("  ✓ Standard trials show expected 'Same' bias\n")
    }
  }
  
  # Check 5: Hard/Easy trials show expected accuracy patterns
  diff_trials <- data %>% filter(difficulty_level %in% c("Hard", "Easy"))
  if (nrow(diff_trials) > 0 && "iscorr" %in% names(data)) {
    # Easy should have higher accuracy than Hard
    easy_acc <- mean(diff_trials$iscorr[diff_trials$difficulty_level == "Easy"], na.rm = TRUE)
    hard_acc <- mean(diff_trials$iscorr[diff_trials$difficulty_level == "Hard"], na.rm = TRUE)
    
    log_fn(sprintf("  Easy trials accuracy: %.3f\n", easy_acc))
    log_fn(sprintf("  Hard trials accuracy: %.3f\n", hard_acc))
    
    if (easy_acc < hard_acc) {
      issues$easy_harder_than_hard <- TRUE
      log_fn("  ✗ Easy trials have LOWER accuracy than Hard (impossible!)\n")
    } else {
      log_fn("  ✓ Easy trials have higher accuracy than Hard\n")
    }
    
    # Both should be above chance
    if (easy_acc < MIN_ACCURACY || hard_acc < MIN_ACCURACY) {
      issues$below_chance <- TRUE
      log_fn("  ✗ Some difficulty levels show below-chance accuracy\n")
    }
  }
  
  return(issues)
}

validate_rt_ranges <- function(data, log_fn = cat) {
  # Validate RT ranges are realistic and within experimental constraints
  log_fn("\n=== VALIDATION: RT Ranges ===\n")
  
  issues <- list()
  
  if (!"rt" %in% names(data)) {
    issues$missing_rt <- TRUE
    log_fn("  ✗ rt column missing!\n")
    return(issues)
  }
  
  # Check 1: RTs within expected range
  rt_too_low <- sum(data$rt < MIN_RT, na.rm = TRUE)
  rt_too_high <- sum(data$rt > MAX_RT, na.rm = TRUE)
  
  if (rt_too_low > 0) {
    issues$rt_too_low <- rt_too_low
    log_fn(sprintf("  ✗ %d trials have RT < %.2fs (excluded)\n", rt_too_low, MIN_RT))
  } else {
    log_fn(sprintf("  ✓ All RTs ≥ %.2fs\n", MIN_RT))
  }
  
  if (rt_too_high > 0) {
    issues$rt_too_high <- rt_too_high
    log_fn(sprintf("  ✗ %d trials have RT > %.2fs (excluded)\n", rt_too_high, MAX_RT))
  } else {
    log_fn(sprintf("  ✓ All RTs ≤ %.2fs\n", MAX_RT))
  }
  
  # Check 2: RT distributions by difficulty
  if ("difficulty_level" %in% names(data)) {
    rt_by_diff <- data %>%
      filter(!is.na(rt) & !is.na(difficulty_level)) %>%
      group_by(difficulty_level) %>%
      summarise(
        mean_rt = mean(rt, na.rm = TRUE),
        median_rt = median(rt, na.rm = TRUE),
        .groups = "drop"
      )
    
    log_fn("  RT by difficulty level:\n")
    for (i in 1:nrow(rt_by_diff)) {
      log_fn(sprintf("    %s: mean=%.3fs, median=%.3fs\n", 
                     rt_by_diff$difficulty_level[i],
                     rt_by_diff$mean_rt[i],
                     rt_by_diff$median_rt[i]))
    }
    
    # Easy should be faster than Hard (easier = faster)
    if ("Easy" %in% rt_by_diff$difficulty_level && "Hard" %in% rt_by_diff$difficulty_level) {
      easy_mean <- rt_by_diff$mean_rt[rt_by_diff$difficulty_level == "Easy"]
      hard_mean <- rt_by_diff$mean_rt[rt_by_diff$difficulty_level == "Hard"]
      
      if (easy_mean > hard_mean) {
        issues$easy_slower_than_hard <- TRUE
        log_fn("  ✗ Easy trials are SLOWER than Hard (impossible!)\n")
      } else {
        log_fn("  ✓ Easy trials are faster than Hard\n")
      }
    }
  }
  
  return(issues)
}

validate_effort_conditions <- function(data, log_fn = cat) {
  # Validate effort condition assignments
  log_fn("\n=== VALIDATION: Effort Conditions ===\n")
  
  issues <- list()
  
  if (!"effort_condition" %in% names(data)) {
    issues$missing_effort <- TRUE
    log_fn("  ✗ effort_condition column missing!\n")
    return(issues)
  }
  
  # Check 1: All effort conditions are valid
  invalid_effort <- setdiff(unique(data$effort_condition), EXPECTED_EFFORT_CONDITIONS)
  if (length(invalid_effort) > 0) {
    issues$invalid_effort <- invalid_effort
    log_fn("  ✗ Invalid effort conditions:", paste(invalid_effort, collapse=", "), "\n")
  } else {
    log_fn("  ✓ All effort conditions are valid\n")
  }
  
  # Check 2: Grip force matches effort condition
  if ("gf_trPer" %in% names(data)) {
    low_effort <- data %>% filter(effort_condition == "Low_5_MVC")
    high_effort <- data %>% filter(effort_condition == "High_40_MVC")
    
    if (nrow(low_effort) > 0) {
      low_gf_mean <- mean(low_effort$gf_trPer, na.rm = TRUE)
      low_gf_expected <- 0.05
      if (abs(low_gf_mean - low_gf_expected) > 0.01) {
        issues$low_effort_gf_mismatch <- low_gf_mean
        log_fn(sprintf("  ✗ Low effort trials have unexpected gf_trPer: %.3f (expected: %.3f)\n", 
                       low_gf_mean, low_gf_expected))
      } else {
        log_fn(sprintf("  ✓ Low effort trials have correct gf_trPer: %.3f\n", low_gf_mean))
      }
    }
    
    if (nrow(high_effort) > 0) {
      high_gf_mean <- mean(high_effort$gf_trPer, na.rm = TRUE)
      high_gf_expected <- 0.40
      if (abs(high_gf_mean - high_gf_expected) > 0.01) {
        issues$high_effort_gf_mismatch <- high_gf_mean
        log_fn(sprintf("  ✗ High effort trials have unexpected gf_trPer: %.3f (expected: %.3f)\n", 
                       high_gf_mean, high_gf_expected))
      } else {
        log_fn(sprintf("  ✓ High effort trials have correct gf_trPer: %.3f\n", high_gf_mean))
      }
    }
  }
  
  return(issues)
}

validate_task_consistency <- function(data, log_fn = cat) {
  # Validate task assignments and consistency
  log_fn("\n=== VALIDATION: Task Consistency ===\n")
  
  issues <- list()
  
  if (!"task" %in% names(data)) {
    issues$missing_task <- TRUE
    log_fn("  ✗ task column missing!\n")
    return(issues)
  }
  
  # Check 1: All tasks are valid
  invalid_tasks <- setdiff(unique(data$task), EXPECTED_TASKS)
  if (length(invalid_tasks) > 0) {
    issues$invalid_tasks <- invalid_tasks
    log_fn("  ✗ Invalid tasks:", paste(invalid_tasks, collapse=", "), "\n")
  } else {
    log_fn("  ✓ All tasks are valid\n")
  }
  
  # Check 2: Task distribution
  task_counts <- table(data$task, useNA = "always")
  log_fn("  Task distribution:\n")
  for (task_name in names(task_counts)) {
    log_fn(sprintf("    %s: %d trials\n", task_name, task_counts[task_name]))
  }
  
  return(issues)
}

validate_subject_consistency <- function(data, log_fn = cat) {
  # Validate subject IDs and trial counts
  log_fn("\n=== VALIDATION: Subject Consistency ===\n")
  
  issues <- list()
  
  if (!"subject_id" %in% names(data)) {
    issues$missing_subject_id <- TRUE
    log_fn("  ✗ subject_id column missing!\n")
    return(issues)
  }
  
  n_subjects <- length(unique(data$subject_id))
  log_fn(sprintf("  Total subjects: %d\n", n_subjects))
  
  # Check for subjects with very few trials
  trials_per_subject <- data %>%
    group_by(subject_id) %>%
    summarise(n_trials = n(), .groups = "drop")
  
  min_trials <- min(trials_per_subject$n_trials)
  max_trials <- max(trials_per_subject$n_trials)
  mean_trials <- mean(trials_per_subject$n_trials)
  
  log_fn(sprintf("  Trials per subject: min=%d, max=%d, mean=%.1f\n", 
                 min_trials, max_trials, mean_trials))
  
  # Flag subjects with suspiciously few trials
  low_trial_subjects <- trials_per_subject %>% filter(n_trials < 50)
  if (nrow(low_trial_subjects) > 0) {
    issues$low_trial_subjects <- nrow(low_trial_subjects)
    log_fn(sprintf("  ⚠ %d subjects have < 50 trials\n", nrow(low_trial_subjects)))
  }
  
  return(issues)
}

# =========================================================================
# MAIN VALIDATION FUNCTION
# =========================================================================

validate_ddm_data <- function(data_file, log_file = NULL) {
  # Run all validation checks on a DDM-ready data file
  
  # Setup logging
  if (!is.null(log_file)) {
    log_con <- file(log_file, "w")
    log_fn <- function(...) {
      msg <- paste(..., collapse = "")
      cat(msg)
      cat(msg, file = log_con)
    }
  } else {
    log_fn <- cat
  }
  
  on.exit(if (!is.null(log_file)) close(log_con))
  
  log_fn(strrep("=", 80), "\n")
  log_fn("DDM DATA VALIDATION REPORT\n")
  log_fn(strrep("=", 80), "\n")
  log_fn("Data file:", data_file, "\n")
  log_fn("Timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
  
  # Load data
  if (!file.exists(data_file)) {
    log_fn("ERROR: Data file not found!\n")
    return(list(success = FALSE, issues = list(file_not_found = TRUE)))
  }
  
  data <- read_csv(data_file, show_col_types = FALSE)
  log_fn(sprintf("Loaded %d trials from %d subjects\n\n", 
                 nrow(data), length(unique(data$subject_id))))
  
  # Run all validations
  all_issues <- list()
  
  all_issues$difficulty <- validate_difficulty_levels(data, log_fn)
  all_issues$response_coding <- validate_response_side_coding(data, log_fn)
  all_issues$rt_ranges <- validate_rt_ranges(data, log_fn)
  all_issues$effort <- validate_effort_conditions(data, log_fn)
  all_issues$task <- validate_task_consistency(data, log_fn)
  all_issues$subject <- validate_subject_consistency(data, log_fn)
  
  # Summary
  log_fn("\n", strrep("=", 80), "\n")
  log_fn("VALIDATION SUMMARY\n")
  log_fn(strrep("=", 78), "\n")
  
  total_issues <- sum(sapply(all_issues, function(x) length(x)))
  
  if (total_issues == 0) {
    log_fn("✓ ALL VALIDATIONS PASSED\n")
    log_fn("Data file is ready for DDM modeling.\n")
    return(list(success = TRUE, issues = all_issues))
  } else {
    log_fn(sprintf("⚠ %d validation issues found\n", total_issues))
    log_fn("Review the detailed report above.\n")
    log_fn("Data file may need corrections before modeling.\n")
    return(list(success = FALSE, issues = all_issues))
  }
}

# Helper function
`%+%` <- function(x, y) paste0(x, y)

# If run as script
if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 1) {
    cat("Usage: Rscript validate_experimental_design.R <data_file> [log_file]\n")
    quit(status = 1)
  }
  
  data_file <- args[1]
  log_file <- if (length(args) >= 2) args[2] else NULL
  
  result <- validate_ddm_data(data_file, log_file)
  quit(status = ifelse(result$success, 0, 1))
}

