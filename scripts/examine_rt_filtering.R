#!/usr/bin/env Rscript

# Examine RT filtering effects with new 0.2 sec threshold
# Answer Question 4 from systematic_analysis.md

library(dplyr)
library(readr)

cat("================================================================================\n")
cat("RT FILTERING ANALYSIS WITH 0.2 SEC THRESHOLD\n")
cat("================================================================================\n\n")

# Load the data - using latest master dataset
data_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"
if (!file.exists(data_file)) {
  # Fallback to analysis-ready if master not available
  data_file <- "data/analysis_ready/bap_ddm_ready.csv"
}
if (!file.exists(data_file)) {
  stop("Data file not found at either location")
}

cat("Loading data from:", data_file, "\n")
data_raw <- read_csv(data_file, show_col_types = FALSE)

# Map new column names to expected names
if ("subject_id" %in% names(data_raw)) {
  # New file format - map columns
  data <- data_raw %>%
    mutate(
      sub = as.character(subject_id),
      task = case_when(
        task_modality == "aud" ~ "aud",
        task_modality == "vis" ~ "vis",
        TRUE ~ as.character(task_modality)
      ),
      rt = same_diff_resp_secs,
      resp1RT = same_diff_resp_secs,
      iscorr = as.integer(resp_is_correct),
      stimLev = stim_level_index,
      isOddball = as.integer(stim_is_diff)
    )
} else {
  # Old file format - use as is
  data <- data_raw
  # Standardize RT column name if needed
  if (!"rt" %in% names(data) && "resp1RT" %in% names(data)) {
    data$rt <- data$resp1RT
  }
}

cat("1. RAW DATA SUMMARY\n")
cat("   Total trials loaded:", nrow(data), "\n")
# Handle different column names
sub_col <- if("subject_id" %in% names(data)) "subject_id" else "sub"
task_col <- if("task" %in% names(data)) "task" else NA
cat("   Subjects:", length(unique(data[[sub_col]])), "\n")
if(!is.na(task_col)) {
  cat("   Tasks:", paste(unique(data[[task_col]]), collapse = ", "), "\n")
}
cat("\n")

# Check for difficulty levels
cat("2. DIFFICULTY LEVEL DISTRIBUTION (BEFORE FILTERING)\n")
if ("difficulty_level" %in% names(data)) {
  diff_table <- table(data$difficulty_level, useNA = "always")
  cat("   ")
  for (i in 1:length(diff_table)) {
    cat(names(diff_table)[i], ":", diff_table[i], "trials | ")
  }
  cat("\n\n")
} else {
  cat("   Creating difficulty levels...\n")
  # Map difficulty from raw columns if needed
  if("isOddball" %in% names(data) && "stimLev" %in% names(data)) {
    data <- data %>% mutate(
      difficulty_level = case_when(
        isOddball == 0 ~ "Standard",
        stimLev %in% c(8, 16, 0.06, 0.12) ~ "Hard",
        stimLev %in% c(32, 64, 0.24, 0.48) ~ "Easy",
        TRUE ~ NA_character_
      )
    )
    diff_table <- table(data$difficulty_level, useNA = "always")
    cat("   ")
    for (i in 1:length(diff_table)) {
      cat(names(diff_table)[i], ":", diff_table[i], "trials | ")
    }
    cat("\n\n")
  } else {
    cat("   Warning: No difficulty information found\n\n")
  }
}

# Examine RT distribution
cat("3. RT DISTRIBUTION\n")
rt_stats <- data %>%
  filter(!is.na(rt)) %>%
  summarise(
    n_trials = n(),
    n_missing_rt = sum(is.na(rt)),
    mean_rt = mean(rt),
    sd_rt = sd(rt),
    min_rt = min(rt),
    p25_rt = quantile(rt, 0.25),
    median_rt = median(rt),
    p75_rt = quantile(rt, 0.75),
    max_rt = max(rt)
  )

cat("   Total trials with RT:", rt_stats$n_trials, "\n")
cat("   Missing RT:", rt_stats$n_missing_rt, "\n")
cat("   Mean RT:", round(rt_stats$mean_rt, 3), "sec\n")
cat("   Median RT:", round(rt_stats$median_rt, 3), "sec\n")
cat("   SD RT:", round(rt_stats$sd_rt, 3), "sec\n")
cat("   Min RT:", round(rt_stats$min_rt, 3), "sec\n")
cat("   Max RT:", round(rt_stats$max_rt, 3), "sec\n")
cat("   Q1:", round(rt_stats$p25_rt, 3), "sec | Q3:", round(rt_stats$p75_rt, 3), "sec\n\n")

# Count outliers with different thresholds
cat("4. RT OUTLIER COUNTS (DIFFERENT THRESHOLDS)\n")
outlier_counts <- data %>%
  filter(!is.na(rt)) %>%
  summarise(
    total = n(),
    below_200ms = sum(rt < 0.2),
    above_3000ms = sum(rt > 3.0),
    valid_200_3000 = sum(rt >= 0.2 & rt <= 3.0),
    below_150ms = sum(rt < 0.15),
    below_250ms = sum(rt < 0.25),
    above_4000ms = sum(rt > 4.0),
    above_5000ms = sum(rt > 5.0)
  )

cat("   Total trials:", outlier_counts$total, "\n")
cat("   RT < 150 ms:", outlier_counts$below_150ms, 
    sprintf("(%.1f%%)", 100 * outlier_counts$below_150ms / outlier_counts$total), "\n")
cat("   RT < 200 ms:", outlier_counts$below_200ms, 
    sprintf("(%.1f%%)", 100 * outlier_counts$below_200ms / outlier_counts$total), "\n")
cat("   RT < 250 ms:", outlier_counts$below_250ms, 
    sprintf("(%.1f%%)", 100 * outlier_counts$below_250ms / outlier_counts$total), "\n")
cat("   RT > 3000 ms:", outlier_counts$above_3000ms, 
    sprintf("(%.1f%%)", 100 * outlier_counts$above_3000ms / outlier_counts$total), "\n")
cat("   RT > 4000 ms:", outlier_counts$above_4000ms, 
    sprintf("(%.1f%%)", 100 * outlier_counts$above_4000ms / outlier_counts$total), "\n")
cat("   RT > 5000 ms:", outlier_counts$above_5000ms, 
    sprintf("(%.1f%%)", 100 * outlier_counts$above_5000ms / outlier_counts$total), "\n\n")

cat("5. VALID TRIALS (0.2 sec ≤ RT ≤ 3.0 sec)\n")
cat("   Valid trials:", outlier_counts$valid_200_3000, 
    sprintf("(%.1f%% retention)\n", 100 * outlier_counts$valid_200_3000 / outlier_counts$total))
cat("   Removed:", outlier_counts$total - outlier_counts$valid_200_3000,
    sprintf("(%.1f%% removed)\n\n", 100 * (1 - outlier_counts$valid_200_3000 / outlier_counts$total)))

# Examine outliers by difficulty level
cat("6. OUTLIERS BY DIFFICULTY LEVEL\n")
if ("difficulty_level" %in% names(data)) {
  outliers_by_diff <- data %>%
    filter(!is.na(rt)) %>%
    mutate(
      is_outlier = rt < 0.2 | rt > 3.0
    ) %>%
    group_by(difficulty_level) %>%
    summarise(
      total = n(),
      outliers = sum(is_outlier),
      pct_outlier = 100 * outliers / total,
      .groups = "drop"
    )
  
  print(outliers_by_diff)
  cat("\n")
}

# Examine outliers by subject
cat("7. OUTLIER RATE BY SUBJECT\n")
outliers_by_subject <- data %>%
  filter(!is.na(rt)) %>%
  mutate(
    is_outlier = rt < 0.2 | rt > 3.0
  ) %>%
  group_by(across(any_of(c("subject_id", "sub")))) %>%
  summarise(
    total_trials = n(),
    n_outliers = sum(is_outlier),
    pct_outlier = 100 * n_outliers / total_trials,
    .groups = "drop"
  ) %>%
  arrange(desc(pct_outlier))

cat("   Subjects with >50% outliers:\n")
high_outlier_subs <- outliers_by_subject %>% filter(pct_outlier > 50)
if (nrow(high_outlier_subs) > 0) {
  print(high_outlier_subs)
} else {
  cat("   None\n")
}

cat("\n   Top 5 worst subjects:\n")
print(head(outliers_by_subject, 5))
cat("\n   Overall outlier rate:\n")
cat(sprintf("   Mean: %.1f%% | Median: %.1f%% | SD: %.1f%%\n\n", 
            mean(outliers_by_subject$pct_outlier),
            median(outliers_by_subject$pct_outlier),
            sd(outliers_by_subject$pct_outlier)))

# Distribution of RT values
cat("8. RT DISTRIBUTION DETAILS (0-500ms range)\n")
rt_details <- data %>%
  filter(!is.na(rt)) %>%
  mutate(
    rt_range = case_when(
      rt < 0.1 ~ "< 100ms",
      rt >= 0.1 & rt < 0.15 ~ "100-150ms",
      rt >= 0.15 & rt < 0.2 ~ "150-200ms",
      rt >= 0.2 & rt < 0.25 ~ "200-250ms",
      rt >= 0.25 & rt < 0.3 ~ "250-300ms",
      rt >= 0.3 & rt < 0.5 ~ "300-500ms",
      TRUE ~ "> 500ms"
    )
  ) %>%
  count(rt_range) %>%
  arrange(match(rt_range, c("< 100ms", "100-150ms", "150-200ms", "200-250ms", 
                            "250-300ms", "300-500ms", "> 500ms"))) %>%
  mutate(pct = 100 * n / sum(n))

print(rt_details)
cat("\n")

cat("================================================================================\n")
cat("SUMMARY AND RECOMMENDATIONS\n")
cat("================================================================================\n")
cat(sprintf("Total trials: %d\n", outlier_counts$total))
cat(sprintf("Valid trials (≥200ms, ≤3000ms): %d (%.1f%%)\n", 
            outlier_counts$valid_200_3000,
            100 * outlier_counts$valid_200_3000 / outlier_counts$total))
cat(sprintf("Removed: %d (%.1f%%)\n", 
            outlier_counts$total - outlier_counts$valid_200_3000,
            100 * (1 - outlier_counts$valid_200_3000 / outlier_counts$total)))

if (outlier_counts$below_200ms > outlier_counts$total * 0.05) {
  cat("\n⚠️  WARNING: >5% of trials have RT < 200ms\n")
  cat("   This suggests possible anticipatory responses or timing issues\n")
  cat("   Consider investigating:\n")
  cat("   - Hardware timing accuracy\n")
  cat("   - Participant instructions\n")
  cat("   - Data collection procedures\n")
}

cat("\n✅ Analysis complete!\n")

