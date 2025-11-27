# =========================================================================
# COMPREHENSIVE DDM ANALYSIS AUDIT
# =========================================================================
# Systematic verification of data processing, filtering, and model specifications
# =========================================================================

library(dplyr)
library(readr)
library(brms)

cat("\n")
cat("================================================================================\n")
cat("COMPREHENSIVE DDM ANALYSIS AUDIT\n")
cat("================================================================================\n")
cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Set working directory
if (!file.exists("output/models")) {
  if (file.exists("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")) {
    setwd("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")
  }
}

audit_results <- list()

# =========================================================================
# 1. DATA FILE VERIFICATION
# =========================================================================

cat("SECTION 1: DATA FILE VERIFICATION\n")
cat("--------------------------------------------------------------------------------\n")

data_file <- "data/analysis_ready/bap_ddm_ready.csv"

if (!file.exists(data_file)) {
  stop("ERROR: Data file not found: ", data_file)
}

cat("✓ Data file exists:", data_file, "\n")
cat("  File size:", round(file.info(data_file)$size / 1024 / 1024, 2), "MB\n")

# Load raw data
raw_data <- read_csv(data_file, show_col_types = FALSE)
cat("  Raw data rows:", nrow(raw_data), "\n")
cat("  Raw data columns:", ncol(raw_data), "\n")

audit_results$raw_data <- list(
  n_rows = nrow(raw_data),
  n_cols = ncol(raw_data),
  file_size_mb = round(file.info(data_file)$size / 1024 / 1024, 2)
)

# =========================================================================
# 2. DATA PREPARATION VERIFICATION
# =========================================================================

cat("\nSECTION 2: DATA PREPARATION VERIFICATION\n")
cat("--------------------------------------------------------------------------------\n")

# Harmonize column names (as in script)
if (!"rt" %in% names(raw_data) && "resp1RT" %in% names(raw_data)) {
  raw_data$rt <- raw_data$resp1RT
  cat("✓ Mapped resp1RT -> rt\n")
}
raw_data$rt <- suppressWarnings(as.numeric(raw_data$rt))

if (!"accuracy" %in% names(raw_data) && "iscorr" %in% names(raw_data)) {
  raw_data$accuracy <- raw_data$iscorr
  cat("✓ Mapped iscorr -> accuracy\n")
}

if (!"subject_id" %in% names(raw_data) && "sub" %in% names(raw_data)) {
  raw_data$subject_id <- as.character(raw_data$sub)
  cat("✓ Mapped sub -> subject_id\n")
}

if (!"task" %in% names(raw_data) && "task_behav" %in% names(raw_data)) {
  raw_data$task <- raw_data$task_behav
  cat("✓ Mapped task_behav -> task\n")
}

# Check for missing values
missing_rt <- sum(is.na(raw_data$rt))
missing_acc <- sum(is.na(raw_data$accuracy))
missing_subj <- sum(is.na(raw_data$subject_id))

cat("\nMissing values:\n")
cat("  RT:", missing_rt, "(", round(100*missing_rt/nrow(raw_data), 2), "%)\n")
cat("  Accuracy:", missing_acc, "(", round(100*missing_acc/nrow(raw_data), 2), "%)\n")
cat("  Subject ID:", missing_subj, "(", round(100*missing_subj/nrow(raw_data), 2), "%)\n")

# RT range check (before filtering)
rt_range <- range(raw_data$rt, na.rm = TRUE)
cat("\nRT range (before filtering):\n")
cat("  Min:", rt_range[1], "s\n")
cat("  Max:", rt_range[2], "s\n")
cat("  Mean:", mean(raw_data$rt, na.rm = TRUE), "s\n")
cat("  Median:", median(raw_data$rt, na.rm = TRUE), "s\n")

audit_results$prep <- list(
  missing_rt = missing_rt,
  missing_acc = missing_acc,
  missing_subj = missing_subj,
  rt_range_before = rt_range
)

# =========================================================================
# 3. FILTERING VERIFICATION
# =========================================================================

cat("\nSECTION 3: FILTERING VERIFICATION\n")
cat("--------------------------------------------------------------------------------\n")

# Check RT filtering (should be 0.25-3.0s as per script)
rt_filter_lower <- 0.25
rt_filter_upper <- 3.0

cat("RT filter: [", rt_filter_lower, ",", rt_filter_upper, "] seconds\n")

# Count trials at each filtering stage
trials_before_rt_filter <- nrow(raw_data[!is.na(raw_data$rt), ])
trials_after_rt_filter <- sum(!is.na(raw_data$rt) & raw_data$rt >= rt_filter_lower & raw_data$rt <= rt_filter_upper)
trials_excluded_rt_low <- sum(!is.na(raw_data$rt) & raw_data$rt < rt_filter_lower)
trials_excluded_rt_high <- sum(!is.na(raw_data$rt) & raw_data$rt > rt_filter_upper)

cat("\nFiltering statistics:\n")
cat("  Trials with valid RT:", trials_before_rt_filter, "\n")
cat("  Trials after RT filter:", trials_after_rt_filter, "\n")
cat("  Trials excluded (RT <", rt_filter_lower, "s):", trials_excluded_rt_low, "\n")
cat("  Trials excluded (RT >", rt_filter_upper, "s):", trials_excluded_rt_high, "\n")
cat("  Exclusion rate:", round(100*(1 - trials_after_rt_filter/trials_before_rt_filter), 2), "%\n")

# Apply filters as in script
ddm_data <- raw_data %>%
  dplyr::filter(rt >= rt_filter_lower & rt <= rt_filter_upper) %>%
  dplyr::mutate(
    response = as.integer(accuracy),
    effort_condition = as.factor(effort_condition),
    difficulty_level = as.factor(difficulty_level),
    subject_id = as.factor(subject_id),
    task = as.factor(task),
    decision = ifelse(accuracy == 1, 1, 0)
  )

cat("\nFinal dataset after filtering:\n")
cat("  Total trials:", nrow(ddm_data), "\n")
cat("  Unique subjects:", length(unique(ddm_data$subject_id)), "\n")

audit_results$filtering <- list(
  trials_before_rt = trials_before_rt_filter,
  trials_after_rt = trials_after_rt_filter,
  trials_excluded_low = trials_excluded_rt_low,
  trials_excluded_high = trials_excluded_rt_high,
  exclusion_rate = round(100*(1 - trials_after_rt_filter/trials_before_rt_filter), 2),
  final_trials = nrow(ddm_data),
  n_subjects = length(unique(ddm_data$subject_id))
)

# =========================================================================
# 4. FACTOR LEVEL VERIFICATION
# =========================================================================

cat("\nSECTION 4: FACTOR LEVEL VERIFICATION\n")
cat("--------------------------------------------------------------------------------\n")

effort_levels <- levels(ddm_data$effort_condition)
difficulty_levels <- levels(ddm_data$difficulty_level)
task_levels <- levels(ddm_data$task)

cat("Effort condition levels:\n")
for (lev in effort_levels) {
  n <- sum(ddm_data$effort_condition == lev, na.rm = TRUE)
  cat("  ", lev, ":", n, "trials (", round(100*n/nrow(ddm_data), 2), "%)\n")
}

cat("\nDifficulty level levels:\n")
for (lev in difficulty_levels) {
  n <- sum(ddm_data$difficulty_level == lev, na.rm = TRUE)
  cat("  ", lev, ":", n, "trials (", round(100*n/nrow(ddm_data), 2), "%)\n")
}

cat("\nTask levels:\n")
for (lev in task_levels) {
  n <- sum(ddm_data$task == lev, na.rm = TRUE)
  cat("  ", lev, ":", n, "trials (", round(100*n/nrow(ddm_data), 2), "%)\n")
}

# Check for imbalances
effort_counts <- table(ddm_data$effort_condition)
diff_counts <- table(ddm_data$difficulty_level)
task_counts <- table(ddm_data$task)

cat("\nBalance checks:\n")
cat("  Effort condition balance ratio:", round(min(effort_counts)/max(effort_counts), 3), "\n")
cat("  Difficulty level balance ratio:", round(min(diff_counts)/max(diff_counts), 3), "\n")
cat("  Task balance ratio:", round(min(task_counts)/max(task_counts), 3), "\n")

audit_results$factors <- list(
  effort_levels = effort_levels,
  difficulty_levels = difficulty_levels,
  task_levels = task_levels,
  effort_counts = as.list(effort_counts),
  difficulty_counts = as.list(diff_counts),
  task_counts = as.list(task_counts)
)

# =========================================================================
# 5. PER-MODEL DATA COUNTS
# =========================================================================

cat("\nSECTION 5: PER-MODEL DATA COUNTS\n")
cat("--------------------------------------------------------------------------------\n")

model_names <- c("Model1_Baseline", "Model2_Force", "Model3_Difficulty", 
                 "Model4_Additive", "Model5_Interaction", "Model7_Task",
                 "Model8_Task_Additive", "Model9_Task_Intx", "Model10_Param_v_bs")

model_data_counts <- list()

for (model_name in model_names) {
  # Determine which filters apply to this model
  model_spec <- list(
    Model1_Baseline = list(filters = "none"),
    Model2_Force = list(filters = "effort_available"),
    Model3_Difficulty = list(filters = "difficulty_available"),
    Model4_Additive = list(filters = c("effort_available", "difficulty_available")),
    Model5_Interaction = list(filters = c("effort_available", "difficulty_available")),
    Model7_Task = list(filters = "task_available"),
    Model8_Task_Additive = list(filters = c("effort_available", "difficulty_available", "task_available")),
    Model9_Task_Intx = list(filters = c("effort_available", "difficulty_available", "task_available")),
    Model10_Param_v_bs = list(filters = c("effort_available", "difficulty_available"))
  )
  
  filters <- model_spec[[model_name]]$filters
  
  # Apply filters
  model_data <- ddm_data
  
  if ("effort_available" %in% filters) {
    model_data <- model_data %>% filter(!is.na(effort_condition))
  }
  if ("difficulty_available" %in% filters) {
    model_data <- model_data %>% filter(!is.na(difficulty_level))
  }
  if ("task_available" %in% filters) {
    model_data <- model_data %>% filter(!is.na(task))
  }
  
  # Remove rows with missing decision
  model_data <- model_data %>% filter(!is.na(decision))
  
  n_trials <- nrow(model_data)
  n_subjects <- length(unique(model_data$subject_id))
  
  cat(sprintf("%-25s: %6d trials, %3d subjects\n", model_name, n_trials, n_subjects))
  
  model_data_counts[[model_name]] <- list(
    n_trials = n_trials,
    n_subjects = n_subjects
  )
}

audit_results$per_model_counts <- model_data_counts

# =========================================================================
# 6. RT DISTRIBUTION CHECK
# =========================================================================

cat("\nSECTION 6: RT DISTRIBUTION CHECK\n")
cat("--------------------------------------------------------------------------------\n")

cat("RT distribution after filtering:\n")
cat("  Mean:", round(mean(ddm_data$rt, na.rm = TRUE), 3), "s\n")
cat("  Median:", round(median(ddm_data$rt, na.rm = TRUE), 3), "s\n")
cat("  SD:", round(sd(ddm_data$rt, na.rm = TRUE), 3), "s\n")
cat("  Min:", round(min(ddm_data$rt, na.rm = TRUE), 3), "s\n")
cat("  Max:", round(max(ddm_data$rt, na.rm = TRUE), 3), "s\n")
cat("  Q1:", round(quantile(ddm_data$rt, 0.25, na.rm = TRUE), 3), "s\n")
cat("  Q3:", round(quantile(ddm_data$rt, 0.75, na.rm = TRUE), 3), "s\n")

# Check for extreme outliers (beyond 3 SD)
rt_mean <- mean(ddm_data$rt, na.rm = TRUE)
rt_sd <- sd(ddm_data$rt, na.rm = TRUE)
extreme_outliers <- sum(ddm_data$rt > rt_mean + 3*rt_sd | ddm_data$rt < rt_mean - 3*rt_sd, na.rm = TRUE)

cat("\nExtreme outliers (>3 SD from mean):", extreme_outliers, "\n")

audit_results$rt_distribution <- list(
  mean = mean(ddm_data$rt, na.rm = TRUE),
  median = median(ddm_data$rt, na.rm = TRUE),
  sd = sd(ddm_data$rt, na.rm = TRUE),
  min = min(ddm_data$rt, na.rm = TRUE),
  max = max(ddm_data$rt, na.rm = TRUE),
  q1 = quantile(ddm_data$rt, 0.25, na.rm = TRUE),
  q3 = quantile(ddm_data$rt, 0.75, na.rm = TRUE),
  extreme_outliers = extreme_outliers
)

# =========================================================================
# 7. ACCURACY/DECISION CHECK
# =========================================================================

cat("\nSECTION 7: ACCURACY/DECISION CHECK\n")
cat("--------------------------------------------------------------------------------\n")

accuracy_rate <- mean(ddm_data$accuracy, na.rm = TRUE)
decision_dist <- table(ddm_data$decision, useNA = "ifany")

cat("Accuracy statistics:\n")
cat("  Overall accuracy:", round(accuracy_rate, 3), "\n")
cat("  Decision=1 (correct):", sum(ddm_data$decision == 1, na.rm = TRUE), "\n")
cat("  Decision=0 (incorrect):", sum(ddm_data$decision == 0, na.rm = TRUE), "\n")
cat("  Missing decision:", sum(is.na(ddm_data$decision)), "\n")

# Check for any inconsistencies between accuracy and decision
if ("accuracy" %in% names(ddm_data) && "decision" %in% names(ddm_data)) {
  inconsistency <- sum((ddm_data$accuracy == 1 & ddm_data$decision != 1) | 
                       (ddm_data$accuracy == 0 & ddm_data$decision != 0), na.rm = TRUE)
  cat("  Inconsistencies (accuracy vs decision):", inconsistency, "\n")
}

audit_results$accuracy <- list(
  overall_rate = accuracy_rate,
  n_correct = sum(ddm_data$decision == 1, na.rm = TRUE),
  n_incorrect = sum(ddm_data$decision == 0, na.rm = TRUE),
  missing = sum(is.na(ddm_data$decision))
)

# =========================================================================
# 8. SUBJECT-LEVEL CHECKS
# =========================================================================

cat("\nSECTION 8: SUBJECT-LEVEL CHECKS\n")
cat("--------------------------------------------------------------------------------\n")

subject_trials <- ddm_data %>%
  group_by(subject_id) %>%
  summarise(
    n_trials = n(),
    mean_rt = mean(rt, na.rm = TRUE),
    mean_acc = mean(accuracy, na.rm = TRUE),
    .groups = "drop"
  )

cat("Subject-level statistics:\n")
cat("  Trials per subject:\n")
cat("    Min:", min(subject_trials$n_trials), "\n")
cat("    Max:", max(subject_trials$n_trials), "\n")
cat("    Mean:", round(mean(subject_trials$n_trials), 1), "\n")
cat("    Median:", median(subject_trials$n_trials), "\n")

# Check for subjects with very few trials
low_trial_subjects <- sum(subject_trials$n_trials < 20)
cat("\n  Subjects with < 20 trials:", low_trial_subjects, "\n")

# Check for subjects with very low accuracy
low_acc_subjects <- sum(subject_trials$mean_acc < 0.5, na.rm = TRUE)
cat("  Subjects with accuracy < 0.5:", low_acc_subjects, "\n")

audit_results$subjects <- list(
  n_subjects = nrow(subject_trials),
  min_trials = min(subject_trials$n_trials),
  max_trials = max(subject_trials$n_trials),
  mean_trials = mean(subject_trials$n_trials),
  median_trials = median(subject_trials$n_trials),
  low_trial_subjects = low_trial_subjects,
  low_acc_subjects = low_acc_subjects
)

# =========================================================================
# 9. VERIFY ACTUAL MODEL DATA COUNTS
# =========================================================================

cat("\nSECTION 9: VERIFY ACTUAL MODEL DATA COUNTS\n")
cat("--------------------------------------------------------------------------------\n")
cat("Loading fitted models to verify actual data used...\n\n")

for (model_name in model_names) {
  model_file <- paste0("output/models/", model_name, ".rds")
  
  if (file.exists(model_file)) {
    tryCatch({
      model <- readRDS(model_file)
      
      # Extract data from model
      model_data <- model$data
      actual_trials <- nrow(model_data)
      actual_subjects <- length(unique(model_data$subject_id))
      
      expected <- model_data_counts[[model_name]]
      
      cat(sprintf("%-25s: %6d trials (expected: %6d), %3d subjects (expected: %3d)",
                  model_name, actual_trials, expected$n_trials, 
                  actual_subjects, expected$n_subjects))
      
      if (actual_trials != expected$n_trials) {
        cat(" ⚠️ MISMATCH!")
      } else {
        cat(" ✓")
      }
      cat("\n")
      
      audit_results$per_model_counts[[model_name]]$actual_trials <- actual_trials
      audit_results$per_model_counts[[model_name]]$actual_subjects <- actual_subjects
      audit_results$per_model_counts[[model_name]]$match <- (actual_trials == expected$n_trials)
      
    }, error = function(e) {
      cat(sprintf("%-25s: ERROR loading model\n", model_name))
    })
  } else {
    cat(sprintf("%-25s: File not found\n", model_name))
  }
}

# =========================================================================
# 10. SUMMARY AND FLAGS
# =========================================================================

cat("\n")
cat("================================================================================\n")
cat("AUDIT SUMMARY AND FLAGS\n")
cat("================================================================================\n\n")

flags <- list()

# Check for issues
if (missing_rt > 0) flags$missing_rt <- paste0("Missing RT in ", missing_rt, " trials")
if (trials_excluded_rt_low + trials_excluded_rt_high > 0.1 * nrow(raw_data)) {
  flags$high_exclusion <- paste0("High RT exclusion rate: ", 
                                  round(100*(trials_excluded_rt_low + trials_excluded_rt_high)/nrow(raw_data), 2), "%")
}
if (low_trial_subjects > 0) {
  flags$low_trial_subjects <- paste0(low_trial_subjects, " subjects have < 20 trials")
}
if (extreme_outliers > 100) {
  flags$extreme_outliers <- paste0("Many extreme RT outliers: ", extreme_outliers)
}

# Check for mismatches
mismatches <- sapply(audit_results$per_model_counts, function(x) {
  if (!is.null(x$match)) return(!x$match)
  return(FALSE)
})

if (any(mismatches, na.rm = TRUE)) {
  flags$data_mismatch <- "Some models have different trial counts than expected"
}

if (length(flags) == 0) {
  cat("✓ No major issues detected\n\n")
} else {
  cat("⚠️  ISSUES FLAGGED:\n")
  for (flag in flags) {
    cat("  -", flag, "\n")
  }
  cat("\n")
}

# Save audit results
saveRDS(audit_results, "audit_results.rds")

# Create summary CSV
summary_data <- data.frame(
  metric = c("Raw trials", "After RT filter", "Final trials", "Unique subjects",
             "Excluded RT low", "Excluded RT high", "Missing RT", "Missing accuracy"),
  value = c(nrow(raw_data), trials_after_rt_filter, nrow(ddm_data), 
            length(unique(ddm_data$subject_id)),
            trials_excluded_rt_low, trials_excluded_rt_high, missing_rt, missing_acc)
)

write.csv(summary_data, "audit_summary.csv", row.names = FALSE)

# Per-model summary
model_summary <- do.call(rbind, lapply(names(model_data_counts), function(m) {
  data.frame(
    model = m,
    expected_trials = model_data_counts[[m]]$n_trials,
    actual_trials = ifelse(is.null(model_data_counts[[m]]$actual_trials), 
                          NA, model_data_counts[[m]]$actual_trials),
    match = ifelse(is.null(model_data_counts[[m]]$match), NA, 
                  model_data_counts[[m]]$match)
  )
}))

write.csv(model_summary, "audit_per_model_counts.csv", row.names = FALSE)

cat("✓ Audit results saved:\n")
cat("  - audit_results.rds (detailed)\n")
cat("  - audit_summary.csv (summary)\n")
cat("  - audit_per_model_counts.csv (per-model counts)\n")

cat("\n")
cat("================================================================================\n")
cat("AUDIT COMPLETE\n")
cat("================================================================================\n\n")










