# =========================================================================
# DDM POST-HOC EMPIRICAL CHECKS
# =========================================================================
# Reality checks: Do parameter estimates match observed behavior?
# Specifically: Negative drift on Hard - is this justified by accuracy?
# =========================================================================

library(dplyr)
library(readr)

cat("\n")
cat("================================================================================\n")
cat("DDM POST-HOC EMPIRICAL REALITY CHECKS\n")
cat("================================================================================\n")
cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Set working directory
if (!file.exists("output/models")) {
  if (file.exists("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")) {
    setwd("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")
  }
}

# Create output directory
dir.create("output/checks", recursive = TRUE, showWarnings = FALSE)

# =========================================================================
# LOAD DATA
# =========================================================================

cat("Loading data...\n")
data_file <- "data/analysis_ready/bap_ddm_ready.csv"

if (!file.exists(data_file)) {
  stop("Data file not found: ", data_file)
}

data <- read_csv(data_file, show_col_types = FALSE)

# Harmonize column names (as in analysis script)
if (!"rt" %in% names(data) && "resp1RT" %in% names(data)) {
  data$rt <- data$resp1RT
}
data$rt <- suppressWarnings(as.numeric(data$rt))

if (!"accuracy" %in% names(data) && "iscorr" %in% names(data)) {
  data$accuracy <- data$iscorr
}

if (!"subject_id" %in% names(data) && "sub" %in% names(data)) {
  data$subject_id <- as.character(data$sub)
}

if (!"task" %in% names(data) && "task_behav" %in% names(data)) {
  data$task <- data$task_behav
}

# Apply same filters as analysis
data_filtered <- data %>%
  filter(rt >= 0.25 & rt <= 3.0) %>%
  mutate(
    effort_condition = as.factor(effort_condition),
    difficulty_level = as.factor(difficulty_level),
    task = as.factor(task),
    subject_id = as.factor(subject_id)
  )

cat("✓ Data loaded:", nrow(data_filtered), "trials\n\n")

# =========================================================================
# 1. ACCURACY BY DIFFICULTY (OVERALL)
# =========================================================================

cat("================================================================================\n")
cat("1. ACCURACY BY DIFFICULTY LEVEL (OVERALL)\n")
cat("================================================================================\n\n")

accuracy_by_difficulty <- data_filtered %>%
  group_by(difficulty_level) %>%
  summarise(
    n_trials = n(),
    n_correct = sum(accuracy == 1, na.rm = TRUE),
    n_incorrect = sum(accuracy == 0, na.rm = TRUE),
    accuracy_rate = mean(accuracy, na.rm = TRUE),
    accuracy_se = sd(accuracy, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  ) %>%
  mutate(
    accuracy_95ci_lower = accuracy_rate - 1.96 * accuracy_se,
    accuracy_95ci_upper = accuracy_rate + 1.96 * accuracy_se
  )

print(accuracy_by_difficulty)

# =========================================================================
# 2. ACCURACY BY DIFFICULTY AND TASK
# =========================================================================

cat("\n================================================================================\n")
cat("2. ACCURACY BY DIFFICULTY LEVEL AND TASK\n")
cat("================================================================================\n\n")

accuracy_by_difficulty_task <- data_filtered %>%
  group_by(difficulty_level, task) %>%
  summarise(
    n_trials = n(),
    n_correct = sum(accuracy == 1, na.rm = TRUE),
    accuracy_rate = mean(accuracy, na.rm = TRUE),
    accuracy_se = sd(accuracy, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  ) %>%
  mutate(
    accuracy_95ci_lower = accuracy_rate - 1.96 * accuracy_se,
    accuracy_95ci_upper = accuracy_rate + 1.96 * accuracy_se
  ) %>%
  arrange(difficulty_level, task)

print(accuracy_by_difficulty_task)

# =========================================================================
# 3. RT DISTRIBUTIONS BY DIFFICULTY AND TASK
# =========================================================================

cat("\n================================================================================\n")
cat("3. RT DISTRIBUTIONS BY DIFFICULTY AND TASK\n")
cat("================================================================================\n\n")

rt_by_difficulty_task <- data_filtered %>%
  group_by(difficulty_level, task) %>%
  summarise(
    n_trials = n(),
    rt_mean = mean(rt, na.rm = TRUE),
    rt_median = median(rt, na.rm = TRUE),
    rt_p10 = quantile(rt, 0.10, na.rm = TRUE),
    rt_p50 = quantile(rt, 0.50, na.rm = TRUE),
    rt_p90 = quantile(rt, 0.90, na.rm = TRUE),
    rt_sd = sd(rt, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(difficulty_level, task)

print(rt_by_difficulty_task)

# =========================================================================
# 4. COMBINED SUMMARY TABLE
# =========================================================================

cat("\n================================================================================\n")
cat("4. COMBINED EMPIRICAL SUMMARY\n")
cat("================================================================================\n\n")

# Merge accuracy and RT data
empirical_summary <- accuracy_by_difficulty_task %>%
  left_join(rt_by_difficulty_task, by = c("difficulty_level", "task", "n_trials")) %>%
  select(difficulty_level, task, n_trials, 
         accuracy_rate, accuracy_95ci_lower, accuracy_95ci_upper,
         rt_median, rt_p10, rt_p50, rt_p90, rt_mean, rt_sd)

print(empirical_summary)

# =========================================================================
# 5. REALITY CHECK: DRIFT ESTIMATES vs BEHAVIOR
# =========================================================================

cat("\n================================================================================\n")
cat("5. REALITY CHECK: DRIFT ESTIMATES vs OBSERVED BEHAVIOR\n")
cat("================================================================================\n\n")

# Load parameter estimates
if (file.exists("model_parameter_estimates.csv")) {
  param_ests <- read_csv("model_parameter_estimates.csv", show_col_types = FALSE)
  
  # Get Hard difficulty drift estimates
  hard_drift <- param_ests %>%
    filter(grepl("difficulty_levelHard", parameter, fixed = TRUE) & 
           grepl("^Model[345]", model)) %>%
    select(model, parameter, estimate, ci_lower, ci_upper)
  
  if (nrow(hard_drift) > 0) {
    cat("Drift rate estimates for Hard difficulty:\n")
    print(hard_drift)
    cat("\n")
    
    # Check if any Hard drift estimates are negative
    negative_drift <- hard_drift %>% filter(estimate < 0)
    
    if (nrow(negative_drift) > 0) {
      cat("⚠️  WARNING: Negative drift estimates found for Hard difficulty!\n\n")
      
      # Check Hard accuracy
      hard_accuracy <- accuracy_by_difficulty %>%
        filter(difficulty_level == "Hard") %>%
        pull(accuracy_rate)
      
      if (hard_accuracy >= 0.5) {
        cat("❌ INCONSISTENCY DETECTED:\n")
        cat("   - Hard difficulty accuracy:", round(hard_accuracy, 3), "(", round(100*hard_accuracy, 1), "%)\n")
        cat("   - Negative drift estimate(s) found\n")
        cat("   - This is INCONSISTENT: Accuracy > 0.5 should correspond to positive drift\n\n")
        cat("   RECOMMENDATION: If Hard accuracy is > 0.5 but drift is negative,\n")
        cat("   the difficulty effect may be captured in boundary separation (a) or\n")
        cat("   starting point bias (z) rather than drift rate (v).\n")
        cat("   Consider:\n")
        cat("   1. Check if boundary separation differs by difficulty\n")
        cat("   2. Check if starting point bias differs by difficulty\n")
        cat("   3. Review model specification for Hard condition\n\n")
        
        # Add flag to summary
        empirical_summary <- empirical_summary %>%
          mutate(
            negative_drift_flag = ifelse(difficulty_level == "Hard", 
                                         "⚠️ Negative drift despite accuracy > 0.5", 
                                         NA_character_)
          )
      } else {
        cat("✓ CONSISTENT: Hard accuracy < 0.5 (", round(100*hard_accuracy, 1), "%)\n")
        cat("   Negative drift estimates are justified by below-chance accuracy.\n\n")
      }
    } else {
      cat("✓ All Hard difficulty drift estimates are positive or zero.\n\n")
    }
  }
}

# =========================================================================
# 6. DETAILED ACCURACY CHECK BY CONDITION
# =========================================================================

cat("\n================================================================================\n")
cat("6. DETAILED ACCURACY BY CONDITION\n")
cat("================================================================================\n\n")

# Accuracy by all condition combinations
accuracy_detailed <- data_filtered %>%
  group_by(difficulty_level, task, effort_condition) %>%
  summarise(
    n_trials = n(),
    n_correct = sum(accuracy == 1, na.rm = TRUE),
    accuracy_rate = mean(accuracy, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(difficulty_level, task, effort_condition)

print(accuracy_detailed)

# Flag any condition with accuracy < 0.5
low_accuracy_conditions <- accuracy_detailed %>%
  filter(accuracy_rate < 0.5)

if (nrow(low_accuracy_conditions) > 0) {
  cat("\n⚠️  CONDITIONS WITH ACCURACY < 0.5:\n")
  print(low_accuracy_conditions)
  cat("\nThese conditions may justify negative drift estimates.\n")
} else {
  cat("\n✓ All condition combinations have accuracy >= 0.5\n")
  cat("  Negative drift estimates would be inconsistent with behavior.\n")
}

# =========================================================================
# 7. SAVE RESULTS
# =========================================================================

cat("\n================================================================================\n")
cat("7. SAVING RESULTS\n")
cat("================================================================================\n\n")

# Save comprehensive summary
write.csv(empirical_summary, 
          file = "output/checks/empirical_by_condition.csv",
          row.names = FALSE)

# Save detailed accuracy breakdown
write.csv(accuracy_detailed, 
          file = "output/checks/accuracy_by_condition_detailed.csv",
          row.names = FALSE)

# Save accuracy by difficulty only
write.csv(accuracy_by_difficulty, 
          file = "output/checks/accuracy_by_difficulty.csv",
          row.names = FALSE)

# Save RT distributions
write.csv(rt_by_difficulty_task, 
          file = "output/checks/rt_by_difficulty_task.csv",
          row.names = FALSE)

cat("✓ Results saved to:\n")
cat("  - output/checks/empirical_by_condition.csv (main summary)\n")
cat("  - output/checks/accuracy_by_condition_detailed.csv (detailed accuracy)\n")
cat("  - output/checks/accuracy_by_difficulty.csv (accuracy by difficulty)\n")
cat("  - output/checks/rt_by_difficulty_task.csv (RT distributions)\n\n")

# =========================================================================
# 8. FINAL SUMMARY
# =========================================================================

cat("================================================================================\n")
cat("REALITY CHECK SUMMARY\n")
cat("================================================================================\n\n")

# Overall accuracy by difficulty
overall_acc <- accuracy_by_difficulty %>%
  select(difficulty_level, accuracy_rate) %>%
  rename(overall_accuracy = accuracy_rate)

cat("Overall accuracy by difficulty:\n")
print(overall_acc)
cat("\n")

# Check Hard specifically
hard_acc <- accuracy_by_difficulty %>%
  filter(difficulty_level == "Hard") %>%
  pull(accuracy_rate)

cat("Hard difficulty accuracy:", round(hard_acc, 3), "(", round(100*hard_acc, 1), "%)\n")

if (hard_acc < 0.5) {
  cat("✓ Negative drift on Hard is JUSTIFIED (accuracy < 0.5)\n")
} else {
  cat("❌ WARNING: Hard accuracy >= 0.5 but drift is negative\n")
  cat("   This suggests difficulty effects may be in boundary/bias, not drift\n")
}

cat("\n")
cat("================================================================================\n")
cat("EMPIRICAL CHECKS COMPLETE\n")
cat("================================================================================\n\n")

