# =========================================================================
# RT THRESHOLD EVALUATION FOR RESPONSE-GATED SAME/DIFFERENT TASK
# =========================================================================
# This script evaluates candidate RT lower-bound thresholds for a 
# response-gated design where RT is measured from response prompt onset.
#
# Based on lab precedent: 200ms post-prompt was used in prior manuscript
# (described as 450ms post-probe-offset, implying ~250ms delay between
# probe offset and response prompt).
# =========================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(ggplot2)
  library(gt)
  library(stringr)
})

# =========================================================================
# CONFIGURATION
# =========================================================================

DATA_FILE <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v3.csv"
OUTPUT_DIR <- "output/rt_threshold_analysis"
RESULTS_DIR <- "output/results"
FIGURES_DIR <- "output/figures"

# Create output directories
dirs_to_create <- c(OUTPUT_DIR, RESULTS_DIR, FIGURES_DIR)
for (dir in dirs_to_create) {
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
}

# Candidate thresholds (seconds, post-prompt)
CANDIDATE_THRESHOLDS <- c(0.150, 0.175, 0.200, 0.225, 0.250)
DEFAULT_THRESHOLD <- 0.200  # Lab precedent

# Response prompt delay (estimated from manuscript: 200ms post-prompt = 450ms post-probe-offset)
# This implies ~250ms delay between probe offset and response prompt
PROMPT_DELAY_ESTIMATE <- 0.250  # seconds

cat("================================================================================\n")
cat("RT THRESHOLD EVALUATION FOR RESPONSE-GATED TASK\n")
cat("================================================================================\n")
cat("Data file:", DATA_FILE, "\n")
cat("Candidate thresholds:", paste(CANDIDATE_THRESHOLDS, collapse=", "), "seconds\n")
cat("Default threshold:", DEFAULT_THRESHOLD, "seconds (lab precedent)\n")
cat("Estimated prompt delay:", PROMPT_DELAY_ESTIMATE, "seconds\n")
cat("================================================================================\n\n")

# =========================================================================
# STEP 1: LOAD AND PREPARE DATA
# =========================================================================

cat("STEP 1: Loading and preparing data...\n")

raw_data <- read_csv(DATA_FILE, show_col_types = FALSE)

cat("  Total trials:", nrow(raw_data), "\n")
cat("  Unique subjects:", length(unique(raw_data$subject_id)), "\n")
cat("  Modalities:", paste(unique(raw_data$task_modality), collapse=", "), "\n")
cat("  Unique stim_offset values:", paste(sort(unique(raw_data$stim_offset)), collapse=", "), "\n\n")

# Prepare data with RT variables
data_prep <- raw_data %>%
  mutate(
    # Map task modality
    task = case_when(
      task_modality == "aud" ~ "ADT",
      task_modality == "vis" ~ "VDT",
      TRUE ~ as.character(task_modality)
    ),
    # RT_POSTPROMPT: measured from response prompt onset (primary measure)
    rt_postprompt = same_diff_resp_secs,
    # RT_PROBE_OFFSET_LOCKED: approximate probe-offset-locked RT
    # Add estimated delay between probe offset and response prompt
    rt_probe_offset_locked = rt_postprompt + PROMPT_DELAY_ESTIMATE,
    # RT_PROBE_ONSET_LOCKED: probe-onset-locked (probe is 0.1s duration)
    rt_probe_onset_locked = rt_probe_offset_locked + 0.100,
    # Map grip condition
    effort_condition = case_when(
      abs(grip_targ_prop_mvc - 0.05) < 0.001 ~ "Low_5_MVC",
      abs(grip_targ_prop_mvc - 0.4) < 0.001 ~ "High_40_MVC",
      TRUE ~ NA_character_
    ),
    # Map difficulty (stim_offset is the difficulty variable)
    stim_offset = stim_offset,
    # Response choice: resp_is_diff TRUE = "different", FALSE = "same"
    resp_is_diff = resp_is_diff,
    # Accuracy
    iscorr = as.integer(resp_is_correct),
    # Subject ID
    sub = as.character(subject_id)
  ) %>%
  filter(
    !is.na(rt_postprompt),
    !is.na(resp_is_diff),
    !is.na(iscorr)
  )

cat("  Trials with valid RT and responses:", nrow(data_prep), "\n")
cat("  RT_POSTPROMPT range: [", round(min(data_prep$rt_postprompt, na.rm=TRUE), 3), 
    ", ", round(max(data_prep$rt_postprompt, na.rm=TRUE), 3), "] seconds\n")
cat("  RT_POSTPROMPT < 0:", sum(data_prep$rt_postprompt < 0, na.rm=TRUE), "trials\n\n")

# =========================================================================
# STEP 2: EVALUATE EACH CANDIDATE THRESHOLD
# =========================================================================

cat("STEP 2: Evaluating candidate thresholds...\n\n")

threshold_results <- list()

for (threshold in CANDIDATE_THRESHOLDS) {
  cat("  Evaluating threshold:", threshold, "seconds...\n")
  
  # Mark anticipatory trials
  data_thresh <- data_prep %>%
    mutate(
      is_anticipatory = rt_postprompt < threshold,
      threshold = threshold
    )
  
  # Overall statistics
  n_total <- nrow(data_thresh)
  n_removed <- sum(data_thresh$is_anticipatory, na.rm=TRUE)
  n_retained <- n_total - n_removed
  pct_retained <- (n_retained / n_total) * 100
  
  # Removed trial characteristics
  removed_trials <- data_thresh %>% filter(is_anticipatory)
  retained_trials <- data_thresh %>% filter(!is_anticipatory)
  
  removed_acc <- if(nrow(removed_trials) > 0) {
    mean(removed_trials$iscorr, na.rm=TRUE)
  } else NA_real_
  
  removed_bias <- if(nrow(removed_trials) > 0) {
    mean(removed_trials$resp_is_diff, na.rm=TRUE)  # Prop "different" responses
  } else NA_real_
  
  # Breakdown by modality
  by_modality <- data_thresh %>%
    group_by(task) %>%
    summarise(
      n_total = n(),
      n_removed = sum(is_anticipatory, na.rm=TRUE),
      n_retained = n_total - n_removed,
      pct_retained = (n_retained / n_total) * 100,
      .groups = "drop"
    )
  
  # Breakdown by difficulty (stim_offset)
  by_difficulty <- data_thresh %>%
    group_by(task, stim_offset) %>%
    summarise(
      n_total = n(),
      n_removed = sum(is_anticipatory, na.rm=TRUE),
      pct_removed = (n_removed / n_total) * 100,
      removed_acc = if(sum(is_anticipatory) > 0) {
        mean(iscorr[is_anticipatory], na.rm=TRUE)
      } else NA_real_,
      .groups = "drop"
    )
  
  # Breakdown by effort condition
  by_effort <- data_thresh %>%
    filter(!is.na(effort_condition)) %>%
    group_by(effort_condition) %>%
    summarise(
      n_total = n(),
      n_removed = sum(is_anticipatory, na.rm=TRUE),
      pct_retained = ((n_total - n_removed) / n_total) * 100,
      .groups = "drop"
    )
  
  # Subject-level summary
  by_subject <- data_thresh %>%
    group_by(sub) %>%
    summarise(
      n_total = n(),
      n_removed = sum(is_anticipatory, na.rm=TRUE),
      pct_removed = (n_removed / n_total) * 100,
      .groups = "drop"
    )
  
  threshold_results[[as.character(threshold)]] <- list(
    threshold = threshold,
    n_total = n_total,
    n_removed = n_removed,
    n_retained = n_retained,
    pct_retained = pct_retained,
    removed_acc = removed_acc,
    removed_bias = removed_bias,
    by_modality = by_modality,
    by_difficulty = by_difficulty,
    by_effort = by_effort,
    by_subject = by_subject,
    retained_data = retained_trials
  )
  
  cat("    Retained:", n_retained, "(", round(pct_retained, 1), "%)\n")
  cat("    Removed accuracy:", if(!is.na(removed_acc)) round(removed_acc, 3) else "N/A", "\n")
  cat("    Removed bias (prop 'different'):", if(!is.na(removed_bias)) round(removed_bias, 3) else "N/A", "\n\n")
}

# =========================================================================
# STEP 3: CREATE THRESHOLD DECISION TABLE
# =========================================================================

cat("STEP 3: Creating threshold decision table...\n")

decision_table <- bind_rows(lapply(threshold_results, function(x) {
  data.frame(
    threshold_sec = x$threshold,
    threshold_ms = x$threshold * 1000,
    n_total = x$n_total,
    n_removed = x$n_removed,
    n_retained = x$n_retained,
    pct_retained = round(x$pct_retained, 2),
    removed_acc = round(x$removed_acc, 3),
    removed_bias = round(x$removed_bias, 3),
    stringsAsFactors = FALSE
  )
}))

# Add summary statistics for retained trials
for (i in 1:nrow(decision_table)) {
  thresh <- decision_table$threshold_sec[i]
  retained <- threshold_results[[as.character(thresh)]]$retained_data
  
  decision_table$mean_rt[i] <- round(mean(retained$rt_postprompt, na.rm=TRUE), 3)
  decision_table$median_rt[i] <- round(median(retained$rt_postprompt, na.rm=TRUE), 3)
  decision_table$retained_acc[i] <- round(mean(retained$iscorr, na.rm=TRUE), 3)
}

# Save decision table
write_csv(decision_table, file.path(OUTPUT_DIR, "threshold_decision_table.csv"))
cat("  Saved:", file.path(OUTPUT_DIR, "threshold_decision_table.csv"), "\n\n")

# Print table
print(decision_table)

# =========================================================================
# STEP 4: CREATE VISUALIZATIONS
# =========================================================================

cat("\nSTEP 4: Creating visualizations...\n")

# Plot 1: RT distributions by modality and difficulty
p1 <- data_prep %>%
  filter(!is.na(task), !is.na(stim_offset)) %>%
  ggplot(aes(x = rt_postprompt, fill = task)) +
  geom_histogram(bins = 50, alpha = 0.7, position = "identity") +
  geom_vline(xintercept = CANDIDATE_THRESHOLDS, linetype = "dashed", 
             color = "red", alpha = 0.5) +
  facet_wrap(~ task, scales = "free_y") +
  labs(
    title = "RT Distribution by Modality",
    subtitle = paste("Red dashed lines show candidate thresholds:", 
                     paste(CANDIDATE_THRESHOLDS, collapse=", "), "s"),
    x = "RT (seconds, post-prompt)",
    y = "Frequency",
    fill = "Task"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")

ggsave(file.path(FIGURES_DIR, "rt_distribution_by_modality.png"), 
       p1, width = 10, height = 6, dpi = 300)
cat("  Saved:", file.path(FIGURES_DIR, "rt_distribution_by_modality.png"), "\n")

# Plot 2: RT by difficulty level
p2 <- data_prep %>%
  filter(!is.na(task), !is.na(stim_offset)) %>%
  ggplot(aes(x = factor(stim_offset), y = rt_postprompt, fill = task)) +
  geom_violin(alpha = 0.6) +
  geom_boxplot(width = 0.2, alpha = 0.8, outlier.size = 0.5) +
  geom_hline(yintercept = CANDIDATE_THRESHOLDS, linetype = "dashed", 
             color = "red", alpha = 0.5) +
  facet_wrap(~ task, scales = "free_x") +
  labs(
    title = "RT Distribution by Difficulty (stim_offset)",
    subtitle = "Red dashed lines show candidate thresholds",
    x = "Stimulus Offset (difficulty)",
    y = "RT (seconds, post-prompt)",
    fill = "Task"
  ) +
  theme_minimal(base_size = 12)

ggsave(file.path(FIGURES_DIR, "rt_by_difficulty.png"), 
       p2, width = 12, height = 6, dpi = 300)
cat("  Saved:", file.path(FIGURES_DIR, "rt_by_difficulty.png"), "\n")

# Plot 3: Conditional Accuracy Function (CAF)
# Create RT quantiles for retained trials (using default threshold)
default_retained <- threshold_results[[as.character(DEFAULT_THRESHOLD)]]$retained_data

if (nrow(default_retained) > 0) {
  default_retained <- default_retained %>%
    mutate(
      rt_quantile = ntile(rt_postprompt, 5),
      rt_quantile_label = paste0("Q", rt_quantile)
    )
  
  caf_data <- default_retained %>%
    group_by(task, rt_quantile_label) %>%
    summarise(
      accuracy = mean(iscorr, na.rm=TRUE),
      mean_rt = mean(rt_postprompt, na.rm=TRUE),
      n = n(),
      se = sqrt(accuracy * (1 - accuracy) / n),
      .groups = "drop"
    )
  
  p3 <- caf_data %>%
    ggplot(aes(x = mean_rt, y = accuracy, color = task)) +
    geom_point(size = 3) +
    geom_errorbar(aes(ymin = accuracy - 1.96*se, ymax = accuracy + 1.96*se), 
                  width = 0.05) +
    geom_line(alpha = 0.7) +
    geom_vline(xintercept = DEFAULT_THRESHOLD, linetype = "dashed", 
               color = "red", alpha = 0.7) +
    annotate("text", x = DEFAULT_THRESHOLD, y = 0.5, 
             label = paste("Threshold:", DEFAULT_THRESHOLD, "s"), 
             hjust = -0.1, color = "red", size = 3) +
    labs(
      title = "Conditional Accuracy Function (CAF)",
      subtitle = paste("RT quantiles for retained trials (threshold =", DEFAULT_THRESHOLD, "s)"),
      x = "Mean RT (seconds, post-prompt)",
      y = "Accuracy",
      color = "Task"
    ) +
    theme_minimal(base_size = 12)
  
  ggsave(file.path(FIGURES_DIR, "caf_plot.png"), 
         p3, width = 10, height = 6, dpi = 300)
  cat("  Saved:", file.path(FIGURES_DIR, "caf_plot.png"), "\n")
}

# Plot 4: Threshold comparison - retention rate
p4 <- decision_table %>%
  ggplot(aes(x = threshold_ms, y = pct_retained)) +
  geom_point(size = 3, color = "#2E86AB") +
  geom_line(color = "#2E86AB", alpha = 0.7) +
  geom_vline(xintercept = DEFAULT_THRESHOLD * 1000, linetype = "dashed", 
             color = "red", alpha = 0.7) +
  annotate("text", x = DEFAULT_THRESHOLD * 1000, y = max(decision_table$pct_retained) - 1,
           label = "Default (lab precedent)", hjust = -0.1, color = "red", size = 3) +
  labs(
    title = "Trial Retention Rate by Threshold",
    x = "Threshold (ms, post-prompt)",
    y = "Retention Rate (%)"
  ) +
  theme_minimal(base_size = 12)

ggsave(file.path(FIGURES_DIR, "threshold_retention_comparison.png"), 
       p4, width = 8, height = 6, dpi = 300)
cat("  Saved:", file.path(FIGURES_DIR, "threshold_retention_comparison.png"), "\n")

# =========================================================================
# STEP 5: DECISION RULE APPLICATION
# =========================================================================

cat("\nSTEP 5: Applying decision rule...\n")
cat("  Decision rule:\n")
cat("  - Start at T = 0.200 (default, matches lab precedent)\n")
cat("  - Consider lowering ONLY if:\n")
cat("    (a) RTs 0.150-0.200 show no anticipation signature\n")
cat("    (b) Including them improves DDM fit\n")
cat("    (c) Parameter estimates are stable\n")
cat("  - If any fail, keep T = 0.200\n\n")

# Check condition (a): Anticipation signature in 0.150-0.200 range
trials_150_200 <- data_prep %>%
  filter(rt_postprompt >= 0.150 & rt_postprompt < 0.200)

if (nrow(trials_150_200) > 0) {
  acc_150_200 <- mean(trials_150_200$iscorr, na.rm=TRUE)
  bias_150_200 <- mean(trials_150_200$resp_is_diff, na.rm=TRUE)
  
  cat("  Condition (a) check - RTs in [0.150, 0.200):\n")
  cat("    N trials:", nrow(trials_150_200), "\n")
  cat("    Accuracy:", round(acc_150_200, 3), "\n")
  cat("    Bias (prop 'different'):", round(bias_150_200, 3), "\n")
  
  # Check for subject-specific spikes
  subj_spikes <- trials_150_200 %>%
    group_by(sub) %>%
    summarise(n = n(), .groups = "drop") %>%
    arrange(desc(n))
  
  cat("    Top subjects with RTs in this range:\n")
  print(head(subj_spikes, 5))
  
  # Decision: if accuracy is very low or bias is extreme, these may be anticipatory
  condition_a_pass <- acc_150_200 > 0.4 & abs(bias_150_200 - 0.5) < 0.3
  
  cat("    Condition (a) PASS:", condition_a_pass, "\n\n")
} else {
  condition_a_pass <- TRUE  # No trials in this range, so no issue
  cat("  No trials in [0.150, 0.200) range\n\n")
}

# Conditions (b) and (c) will be evaluated after DDM fitting
cat("  Conditions (b) and (c) will be evaluated after DDM fitting.\n")
cat("  For now, RECOMMENDED THRESHOLD:", DEFAULT_THRESHOLD, "seconds\n\n")

# =========================================================================
# STEP 6: SAVE PREPARED DATA FOR DDM FITTING
# =========================================================================

cat("STEP 6: Saving prepared data for DDM fitting...\n")

# Save data with default threshold applied
default_retained <- threshold_results[[as.character(DEFAULT_THRESHOLD)]]$retained_data

ddm_ready <- default_retained %>%
  select(
    sub, task, run_num, trial_num, 
    rt_postprompt, rt_probe_offset_locked, rt_probe_onset_locked,
    resp_is_diff, iscorr, effort_condition, stim_offset, stim_level_index
  ) %>%
  rename(
    subject_id = sub,
    run = run_num,
    trial_index = trial_num,
    rt = rt_postprompt,
    choice = resp_is_diff,  # TRUE = "different" = upper boundary
    accuracy = iscorr
  ) %>%
  mutate(
    # Convert choice to binary: 1 = "different" (upper), 0 = "same" (lower)
    choice_binary = as.integer(choice),
    # Create difficulty factor
    difficulty_level = case_when(
      stim_offset == 0 ~ "Standard",
      (task == "ADT" & stim_offset %in% c(8, 16)) | 
      (task == "VDT" & stim_offset %in% c(0.06, 0.12)) ~ "Hard",
      (task == "ADT" & stim_offset %in% c(32, 64)) | 
      (task == "VDT" & stim_offset %in% c(0.24, 0.48)) ~ "Easy",
      TRUE ~ "Unknown"
    )
  )

write_csv(ddm_ready, file.path(OUTPUT_DIR, "ddm_ready_data.csv"))
cat("  Saved:", file.path(OUTPUT_DIR, "ddm_ready_data.csv"), "\n")
cat("  Trials ready for DDM:", nrow(ddm_ready), "\n\n")

# =========================================================================
# FINAL SUMMARY
# =========================================================================

cat("================================================================================\n")
cat("RT THRESHOLD EVALUATION COMPLETE\n")
cat("================================================================================\n")
cat("Recommended threshold:", DEFAULT_THRESHOLD, "seconds (", DEFAULT_THRESHOLD * 1000, "ms)\n")
cat("Trials retained:", threshold_results[[as.character(DEFAULT_THRESHOLD)]]$n_retained, 
    "(", round(threshold_results[[as.character(DEFAULT_THRESHOLD)]]$pct_retained, 1), "%)\n")
cat("Trials removed:", threshold_results[[as.character(DEFAULT_THRESHOLD)]]$n_removed, "\n")
cat("\nOutput files:\n")
cat("  - Decision table:", file.path(OUTPUT_DIR, "threshold_decision_table.csv"), "\n")
cat("  - DDM-ready data:", file.path(OUTPUT_DIR, "ddm_ready_data.csv"), "\n")
cat("  - Figures:", file.path(FIGURES_DIR, "*.png"), "\n")
cat("================================================================================\n")
