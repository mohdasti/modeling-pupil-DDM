#!/usr/bin/env Rscript
# =========================================================================
# DIAGNOSE BIAS INCLUDING TASK/EFFORT EFFECTS
# =========================================================================
# The Standard-only model has bias ~ task + effort_condition
# So we need to check actual bias predictions, not just intercept
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(posterior)
  library(readr)
  library(dplyr)
})

cat(strrep("=", 80), "\n")
cat("BIAS DIAGNOSTIC - INCLUDING TASK/EFFORT EFFECTS\n")
cat(strrep("=", 80), "\n\n")

# Load model and data
fit <- readRDS("output/models/standard_bias_only.rds")
data <- read_csv("data/analysis_ready/bap_ddm_only_ready.csv", show_col_types = FALSE)
std <- data %>% filter(difficulty_level == "Standard")

cat("Standard trials:", nrow(std), "\n")
cat(sprintf("  'Different' (dec_upper=1): %.1f%%\n", 100 * mean(std$dec_upper, na.rm=TRUE)))
cat(sprintf("  'Same' (dec_upper=0): %.1f%%\n\n", 100 * (1 - mean(std$dec_upper, na.rm=TRUE))))

# Extract all bias-related parameters
cat("EXTRACTING BIAS PARAMETERS...\n")
draws <- as_draws_df(fit)

# Bias intercept (on logit scale)
bias_intercept_logit <- draws$b_bias_Intercept

# Task effects (if present)
bias_adt_logit <- if ("b_bias_taskADT" %in% names(draws)) draws$b_bias_taskADT else rep(0, nrow(draws))
bias_vdt_logit <- if ("b_bias_taskVDT" %in% names(draws)) draws$b_bias_taskVDT else rep(0, nrow(draws))

# Effort effects (if present)
bias_low_logit <- if ("b_bias_effort_conditionLow_5_MVC" %in% names(draws)) {
  draws$b_bias_effort_conditionLow_5_MVC
} else {
  rep(0, nrow(draws))
}
bias_high_logit <- if ("b_bias_effort_conditionHigh_40_MVC" %in% names(draws)) {
  draws$b_bias_effort_conditionHigh_40_MVC
} else {
  rep(0, nrow(draws))
}

cat("Bias intercept (logit):", round(mean(bias_intercept_logit), 3), "\n")
cat("Task effects present:", any(bias_adt_logit != 0) || any(bias_vdt_logit != 0), "\n")
cat("Effort effects present:", any(bias_low_logit != 0) || any(bias_high_logit != 0), "\n\n")

# Calculate actual bias for each condition
cat("CALCULATING ACTUAL BIAS BY CONDITION...\n\n")

conditions <- std %>%
  distinct(task, effort_condition) %>%
  arrange(task, effort_condition)

for (i in 1:nrow(conditions)) {
  task_val <- conditions$task[i]
  effort_val <- conditions$effort_condition[i]
  
  # Calculate bias for this condition (on logit scale)
  bias_logit <- bias_intercept_logit
  
  # Add task effect
  if (task_val == "ADT" && any(bias_adt_logit != 0)) {
    bias_logit <- bias_logit + bias_adt_logit
  } else if (task_val == "VDT" && any(bias_vdt_logit != 0)) {
    bias_logit <- bias_logit + bias_vdt_logit
  }
  
  # Add effort effect
  if (effort_val == "Low_5_MVC" && any(bias_low_logit != 0)) {
    bias_logit <- bias_logit + bias_low_logit
  } else if (effort_val == "High_40_MVC" && any(bias_high_logit != 0)) {
    bias_logit <- bias_logit + bias_high_logit
  }
  
  # Convert to probability scale
  bias_prob <- plogis(bias_logit)
  bias_mean <- mean(bias_prob)
  
  # Get actual data for this condition
  condition_data <- std %>% filter(task == task_val, effort_condition == effort_val)
  prop_diff <- mean(condition_data$dec_upper, na.rm=TRUE)
  
  cat(sprintf("%s - %s:\n", task_val, effort_val))
  cat(sprintf("  Model bias: %.3f\n", bias_mean))
  cat(sprintf("  Data 'Different': %.3f\n", prop_diff))
  cat(sprintf("  Difference: %.3f\n", abs(bias_mean - prop_diff)))
  
  if (abs(bias_mean - prop_diff) < 0.15) {
    cat("  ✓ Match\n")
  } else if (abs((1 - bias_mean) - prop_diff) < 0.15) {
    cat("  ⚠ Match if flipped\n")
  } else {
    cat("  ✗ No match\n")
  }
  cat("\n")
}

# Also check overall
bias_intercept_prob <- mean(plogis(bias_intercept_logit))
prop_diff_overall <- mean(std$dec_upper, na.rm=TRUE)

cat("OVERALL:\n")
cat(sprintf("  Bias intercept (probability): %.3f\n", bias_intercept_prob))
cat(sprintf("  Data 'Different': %.3f\n", prop_diff_overall))
cat(sprintf("  Direct difference: %.3f\n", abs(bias_intercept_prob - prop_diff_overall)))
cat(sprintf("  Flipped difference: %.3f\n", abs((1 - bias_intercept_prob) - prop_diff_overall)))
cat("\n")

# Check if boundaries might be reversed
cat(strrep("=", 80), "\n")
cat("POSSIBLE ISSUE: Boundary Interpretation\n")
cat(strrep("=", 80), "\n\n")

cat("In brms wiener model:\n")
cat("  - dec(dec_upper) where dec_upper is 0 or 1\n")
cat("  - Question: Does dec_upper=1 mean upper or lower boundary?\n\n")

cat("Check your manuscript/code:\n")
cat("  - Manuscript says: 'upper boundary = Different'\n")
cat("  - Your code: dec_upper=1 when resp_is_diff=TRUE\n")
cat("  - So: dec_upper=1 should mean 'Different' = upper boundary\n\n")

cat("But model results suggest:\n")
cat("  - If dec_upper=1 means upper, bias should be ~0.109 (10.9%% Different)\n")
cat("  - But model estimates z = 0.569\n")
cat("  - This is closer to (1 - 0.109) = 0.891, suggesting REVERSAL\n\n")

cat("RECOMMENDATION:\n")
cat("  Test by manually checking what happens if you flip dec_upper\n")
cat("  Compare model predictions with data distribution\n\n")

cat(strrep("=", 80), "\n")

