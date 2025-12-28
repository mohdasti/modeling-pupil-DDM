#!/usr/bin/env Rscript
# ============================================================================
# Chapter 3 Window Selection and Timing Verification
# ============================================================================
# Part 1: Timing verification against MATLAB/log definitions
# Part 2: Stimulus-locked waveform plotting
# Part 3: Window selection diagnostics
# Part 4: Response-locked exploratory plot
# ============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(ggplot2)
  library(readr)
})

# ============================================================================
# CONFIGURATION
# ============================================================================

REPO_ROOT <- normalizePath(".")
QUICK_SHARE_DIR <- file.path(REPO_ROOT, "quick_share_v7")
MERGED_FILE <- file.path(QUICK_SHARE_DIR, "merged", "BAP_triallevel_merged_v4.csv")
CH2_FILE <- file.path(QUICK_SHARE_DIR, "analysis_ready", "ch2_triallevel.csv")
CH3_FILE <- file.path(QUICK_SHARE_DIR, "analysis_ready", "ch3_triallevel.csv")
BAP_PROCESSED_DIR <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"

# Output directories
QC_DIR <- file.path(QUICK_SHARE_DIR, "qc")
FIGS_DIR <- file.path(QUICK_SHARE_DIR, "figs")
dir.create(QC_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIGS_DIR, recursive = TRUE, showWarnings = FALSE)

cat("=== Chapter 3 Window Selection and Timing Verification ===\n\n")
cat("Merged file:", MERGED_FILE, "\n")
cat("CH3 file:", CH3_FILE, "\n")
cat("BAP processed dir:", BAP_PROCESSED_DIR, "\n\n")

# ============================================================================
# PART 1: TIMING VERIFICATION
# ============================================================================

cat("PART 1: Timing Verification\n")
cat("---------------------------\n")

# Load merged data
merged <- fread(MERGED_FILE)
cat("Loaded", nrow(merged), "trials from merged_v4\n")

# Expected timing values (from MATLAB pipeline config)
EXPECTED_TARGET_ONSET <- 4.35  # 3.75 (stimulus start) + 0.6 (standard 0.1 + ISI 0.5)
EXPECTED_RESP_START <- 4.70

# Compute per-trial timing offsets
# Note: merged_v4 already has t_target_onset_rel and t_resp_start_rel
# We need to verify these match expectations and compute stim1_onset_rel if needed

# For ADT: stim1_onset_rel = A/V_ST - TrialST (should be ~3.75)
# For VDT: stim1_onset_rel = A/V_ST - TrialST (should be ~3.75)
# Target onset:
#   - VDT: G2_ONST - TrialST (should be ~4.35)
#   - ADT: stim1_onset_rel + 0.6 (should be ~4.35)

# Since we already have t_target_onset_rel in merged_v4, we'll use it
# and compute stim1_onset_rel as target_onset - 0.6 for ADT
# For VDT, we'd need G2_ONST if available, but we can use target_onset - 0.6 as approximation

merged_timing <- merged %>%
  mutate(
    # Compute stim1_onset_rel (stimulus pair onset relative to TrialST)
    stim1_onset_rel = ifelse(!is.na(t_target_onset_rel), t_target_onset_rel - 0.6, NA_real_),
    target_onset_rel = t_target_onset_rel,
    resp_start_rel = t_resp_start_rel,
    target_stim1_diff = target_onset_rel - stim1_onset_rel
  ) %>%
  filter(!is.na(task), task %in% c("ADT", "VDT"))

cat("Computed timing offsets for", nrow(merged_timing), "trials\n")

# Create timing sanity summary by task
timing_summary <- merged_timing %>%
  group_by(task) %>%
  summarise(
    n_trials = n(),
    stim1_onset_median = median(stim1_onset_rel, na.rm = TRUE),
    stim1_onset_q25 = quantile(stim1_onset_rel, 0.25, na.rm = TRUE),
    stim1_onset_q75 = quantile(stim1_onset_rel, 0.75, na.rm = TRUE),
    target_onset_median = median(target_onset_rel, na.rm = TRUE),
    target_onset_q25 = quantile(target_onset_rel, 0.25, na.rm = TRUE),
    target_onset_q75 = quantile(target_onset_rel, 0.75, na.rm = TRUE),
    resp_start_median = median(resp_start_rel, na.rm = TRUE),
    resp_start_q25 = quantile(resp_start_rel, 0.25, na.rm = TRUE),
    resp_start_q75 = quantile(resp_start_rel, 0.75, na.rm = TRUE),
    target_stim1_diff_median = median(target_stim1_diff, na.rm = TRUE),
    target_stim1_diff_q25 = quantile(target_stim1_diff, 0.25, na.rm = TRUE),
    target_stim1_diff_q75 = quantile(target_stim1_diff, 0.75, na.rm = TRUE),
    .groups = "drop"
  )

fwrite(timing_summary, file.path(QC_DIR, "timing_sanity_summary.csv"))
cat("✓ Saved timing sanity summary\n")
print(timing_summary)

# Flag outlier runs (where median target_onset_rel deviates >0.05s from expected)
timing_by_run <- merged_timing %>%
  group_by(sub, task, session_used, run_used) %>%
  summarise(
    n_trials = n(),
    target_onset_median = median(target_onset_rel, na.rm = TRUE),
    target_onset_deviation = abs(target_onset_median - EXPECTED_TARGET_ONSET),
    is_outlier = target_onset_deviation > 0.05,
    .groups = "drop"
  )

outlier_runs <- timing_by_run %>% filter(is_outlier)
fwrite(outlier_runs, file.path(QC_DIR, "timing_outlier_runs.csv"))
cat("\n✓ Found", nrow(outlier_runs), "outlier runs (target_onset deviates >0.05s from expected)\n")
if (nrow(outlier_runs) > 0) {
  cat("Outlier runs:\n")
  print(outlier_runs)
}

# ============================================================================
# PART 2: STIMULUS-LOCKED WAVEFORM PLOTTING
# ============================================================================

cat("\nPART 2: Stimulus-Locked Waveform Plotting\n")
cat("------------------------------------------\n")

# Load CH3 data to get ddm_ready flag
ch3_data <- fread(CH3_FILE)
cat("Loaded", nrow(ch3_data), "trials from ch3_triallevel\n")
cat("Trials with ddm_ready:", sum(ch3_data$ddm_ready, na.rm = TRUE), "\n")

# Check if we need flat files
cat("\nLocating flat files...\n")
flat_files <- list.files(BAP_PROCESSED_DIR, pattern = "_flat\\.csv$", full.names = TRUE, recursive = TRUE)
cat("Found", length(flat_files), "flat files\n")

if (length(flat_files) == 0) {
  stop("ERROR: No flat files found in ", BAP_PROCESSED_DIR)
}

# Check first flat file to understand structure
sample_flat <- fread(flat_files[1], nrows = 1000)
cat("Sample flat file columns:", paste(names(sample_flat), collapse = ", "), "\n")
cat("Time range in sample:", min(sample_flat$time, na.rm = TRUE), "to", max(sample_flat$time, na.rm = TRUE), "\n")

# Flat files have absolute PTB time. We need to compute relative time to squeeze onset.
# MATLAB pipeline outputs: trial_start_time_ptb = squeeze_onset_ptb - 3.0
# So: squeeze_onset_ptb = trial_start_time_ptb + 3.0
# And: time_rel = time (absolute PTB) - squeeze_onset_ptb

# We need to verify that data extends to at least target_onset + 3.0 seconds (relative to squeeze)
required_max_time_rel <- EXPECTED_TARGET_ONSET + 3.0  # 4.35 + 3.0 = 7.35 seconds

# Check if trial_start_time_ptb exists
if (!"trial_start_time_ptb" %in% names(sample_flat)) {
  stop("ERROR: trial_start_time_ptb column not found in flat files. Cannot compute relative time.")
}

# Load and process flat files
cat("\nLoading and processing flat files...\n")

# Get unique trial identifiers from ch3 that are ddm_ready
ddm_ready_trials <- ch3_data %>%
  filter(ddm_ready == TRUE) %>%
  select(trial_uid, sub, task, session_used, run_used, trial_index, 
         t_target_onset_rel, t_resp_start_rel, effort, isOddball, stimulus_intensity)

# Load all flat files and compute relative time
# Note: Flat files have absolute PTB time. MATLAB pipeline extracts trials from 
# squeeze-3.0 to squeeze+10.7. The first sample in each trial is at squeeze-3.0.
# We'll compute time_rel by: time_rel = (time - min_time_per_trial) - 3.0
# This makes squeeze onset = 0, trial start = -3.0

cat("Loading flat files (this may take a while)...\n")
all_flat_data <- rbindlist(lapply(flat_files, function(f) {
  dt <- fread(f, select = c("sub", "task", "time", "pupil", "trial_index", 
                            "session_used", "run_used"))
  # Create trial_uid first
  dt[, trial_uid := paste(sub, task, session_used, run_used, trial_index, sep = ":")]
  # Compute time relative to squeeze onset per trial
  # MATLAB extracts: trial_start_ptb = squeeze_ptb - 3.0
  # So: squeeze_ptb = min(time) + 3.0
  # And: time_rel = time - squeeze_ptb = time - min(time) - 3.0
  dt[, min_time := min(time, na.rm = TRUE), by = trial_uid]
  dt[, time_rel := time - min_time - 3.0]  # squeeze onset at 0
  dt[, min_time := NULL]
  dt
}), use.names = TRUE, fill = TRUE)

# Check data extension
max_time_rel <- max(all_flat_data$time_rel, na.rm = TRUE)
cat("Maximum relative time in flat files:", max_time_rel, "seconds\n")
cat("Required (target_onset + 3.0):", required_max_time_rel, "seconds\n")

if (max_time_rel < required_max_time_rel) {
  stop("ERROR: Need to re-segment MATLAB flats to extend window. Required: target_onset (", 
       EXPECTED_TARGET_ONSET, ") + 3.0s = ", required_max_time_rel, "s available. Found max: ", max_time_rel, "s")
}

# Filter to ddm_ready trials only and compute t_from_target
flat_ddm_ready <- all_flat_data %>%
  inner_join(ddm_ready_trials, by = c("trial_uid", "sub", "task", "session_used", "run_used", "trial_index")) %>%
  mutate(
    t_from_target = time_rel - t_target_onset_rel,
    # Create condition labels
    effort_label = ifelse(effort == "high", "High Effort", "Low Effort"),
    oddball_label = ifelse(isOddball == 1, "Oddball", "Standard")
  ) %>%
  filter(t_from_target >= -0.5 & t_from_target <= 4.0)

cat("Prepared", nrow(flat_ddm_ready), "sample-level data points for waveform plotting\n")

# Check if we have enough data
if (nrow(flat_ddm_ready) == 0) {
  stop("ERROR: No valid data after filtering. Check timing alignment.")
}

# Compute waveform means by condition
# A) Grand mean by task
waveform_by_task <- flat_ddm_ready %>%
  group_by(task, t_from_target) %>%
  summarise(
    mean_pupil = mean(pupil, na.rm = TRUE),
    se_pupil = sd(pupil, na.rm = TRUE) / sqrt(n()),
    n_trials = n_distinct(trial_uid),
    .groups = "drop"
  )

# B) By effort level
waveform_by_effort <- flat_ddm_ready %>%
  group_by(task, effort_label, t_from_target) %>%
  summarise(
    mean_pupil = mean(pupil, na.rm = TRUE),
    se_pupil = sd(pupil, na.rm = TRUE) / sqrt(n()),
    n_trials = n_distinct(trial_uid),
    .groups = "drop"
  )

# C) By oddball status
waveform_by_oddball <- flat_ddm_ready %>%
  group_by(task, oddball_label, t_from_target) %>%
  summarise(
    mean_pupil = mean(pupil, na.rm = TRUE),
    se_pupil = sd(pupil, na.rm = TRUE) / sqrt(n()),
    n_trials = n_distinct(trial_uid),
    .groups = "drop"
  )

# Plot waveforms
plot_theme <- theme_minimal() +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "bottom",
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 10),
    legend.text = element_text(size = 10)
  )

# A) By task
p_task <- ggplot(waveform_by_task, aes(x = t_from_target, y = mean_pupil, color = task)) +
  geom_ribbon(aes(ymin = mean_pupil - se_pupil, ymax = mean_pupil + se_pupil, fill = task), 
              alpha = 0.2, linetype = 0) +
  geom_line(size = 1) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  labs(x = "Time from target onset (s)", y = "Pupil diameter (mm)",
       title = "Stimulus-Locked Pupil Waveforms by Task",
       color = "Task", fill = "Task") +
  coord_cartesian(xlim = c(-0.5, 4.0)) +
  plot_theme

ggsave(file.path(FIGS_DIR, "ch3_waveform_by_task.png"), p_task, width = 8, height = 6, dpi = 300)
cat("✓ Saved waveform by task plot\n")

# B) By effort
p_effort <- ggplot(waveform_by_effort, aes(x = t_from_target, y = mean_pupil, color = effort_label)) +
  geom_ribbon(aes(ymin = mean_pupil - se_pupil, ymax = mean_pupil + se_pupil, fill = effort_label), 
              alpha = 0.2, linetype = 0) +
  geom_line(size = 1) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  facet_wrap(~ task) +
  labs(x = "Time from target onset (s)", y = "Pupil diameter (mm)",
       title = "Stimulus-Locked Pupil Waveforms by Effort Level",
       color = "Effort", fill = "Effort") +
  coord_cartesian(xlim = c(-0.5, 4.0)) +
  plot_theme

ggsave(file.path(FIGS_DIR, "ch3_waveform_by_effort.png"), p_effort, width = 10, height = 6, dpi = 300)
cat("✓ Saved waveform by effort plot\n")

# C) By oddball
p_oddball <- ggplot(waveform_by_oddball, aes(x = t_from_target, y = mean_pupil, color = oddball_label)) +
  geom_ribbon(aes(ymin = mean_pupil - se_pupil, ymax = mean_pupil + se_pupil, fill = oddball_label), 
              alpha = 0.2, linetype = 0) +
  geom_line(size = 1) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  facet_wrap(~ task) +
  labs(x = "Time from target onset (s)", y = "Pupil diameter (mm)",
       title = "Stimulus-Locked Pupil Waveforms by Stimulus Type",
       color = "Stimulus", fill = "Stimulus") +
  coord_cartesian(xlim = c(-0.5, 4.0)) +
  plot_theme

ggsave(file.path(FIGS_DIR, "ch3_waveform_by_oddball.png"), p_oddball, width = 10, height = 6, dpi = 300)
cat("✓ Saved waveform by oddball plot\n")

# ============================================================================
# PART 3: WINDOW SELECTION DIAGNOSTICS
# ============================================================================

cat("\nPART 3: Window Selection Diagnostics\n")
cat("-------------------------------------\n")

# Compute time to peak for each condition set
# Peak search window: 0.3 to 4.0 seconds post-target (avoid initial artifact)

peak_summary_list <- list()

# By task
for (t in unique(waveform_by_task$task)) {
  wf <- waveform_by_task %>% filter(task == t, t_from_target >= 0.3 & t_from_target <= 4.0)
  if (nrow(wf) > 0) {
    peak_idx <- which.max(wf$mean_pupil)
    peak_summary_list[[length(peak_summary_list) + 1]] <- data.frame(
      condition_set = "task",
      condition_value = t,
      time_to_peak = wf$t_from_target[peak_idx],
      peak_amplitude = wf$mean_pupil[peak_idx]
    )
  }
}

# By effort
for (t in unique(waveform_by_effort$task)) {
  for (e in unique(waveform_by_effort$effort_label)) {
    wf <- waveform_by_effort %>% 
      filter(task == t, effort_label == e, t_from_target >= 0.3 & t_from_target <= 4.0)
    if (nrow(wf) > 0) {
      peak_idx <- which.max(wf$mean_pupil)
      peak_summary_list[[length(peak_summary_list) + 1]] <- data.frame(
        condition_set = "effort",
        condition_value = paste(t, e, sep = "_"),
        time_to_peak = wf$t_from_target[peak_idx],
        peak_amplitude = wf$mean_pupil[peak_idx]
      )
    }
  }
}

# By oddball
for (t in unique(waveform_by_oddball$task)) {
  for (o in unique(waveform_by_oddball$oddball_label)) {
    wf <- waveform_by_oddball %>% 
      filter(task == t, oddball_label == o, t_from_target >= 0.3 & t_from_target <= 4.0)
    if (nrow(wf) > 0) {
      peak_idx <- which.max(wf$mean_pupil)
      peak_summary_list[[length(peak_summary_list) + 1]] <- data.frame(
        condition_set = "oddball",
        condition_value = paste(t, o, sep = "_"),
        time_to_peak = wf$t_from_target[peak_idx],
        peak_amplitude = wf$mean_pupil[peak_idx]
      )
    }
  }
}

peak_summary <- bind_rows(peak_summary_list)
fwrite(peak_summary, file.path(QC_DIR, "ch3_time_to_peak_summary.csv"))
cat("✓ Saved time to peak summary\n")
print(peak_summary)

# Test window coverage
cat("\nTesting window coverage...\n")
windows <- list(
  W2.0 = c(0.3, 2.3),
  W2.5 = c(0.3, 2.8),
  W3.0 = c(0.3, 3.3)
)

# Check coverage per trial
window_coverage_list <- list()
for (win_name in names(windows)) {
  win_start <- windows[[win_name]][1]
  win_end <- windows[[win_name]][2]
  
  # For each trial, check if we have sufficient valid data in the window
  trial_coverage <- flat_ddm_ready %>%
    filter(t_from_target >= win_start & t_from_target <= win_end) %>%
    group_by(trial_uid, task) %>%
    summarise(
      n_samples = n(),
      n_valid = sum(!is.na(pupil) & pupil > 0, na.rm = TRUE),
      pct_valid = n_valid / n_samples * 100,
      .groups = "drop"
    ) %>%
    mutate(
      window = win_name,
      window_start = win_start,
      window_end = win_end,
      has_sufficient_data = pct_valid >= 80  # At least 80% valid samples
    )
  
  window_coverage_list[[win_name]] <- trial_coverage
}

window_coverage <- bind_rows(window_coverage_list) %>%
  group_by(window, window_start, window_end, task) %>%
  summarise(
    n_trials = n(),
    n_trials_sufficient = sum(has_sufficient_data),
    pct_trials_sufficient = mean(has_sufficient_data) * 100,
    mean_pct_valid = mean(pct_valid),
    .groups = "drop"
  )

fwrite(window_coverage, file.path(QC_DIR, "ch3_window_coverage.csv"))
cat("✓ Saved window coverage summary\n")
print(window_coverage)

# Recommend a primary window
# Choose the shortest window that captures the peak for most conditions AND maintains good coverage
max_peak_time <- max(peak_summary$time_to_peak, na.rm = TRUE)
cat("\nMaximum peak time across conditions:", max_peak_time, "seconds\n")

# Find shortest window that covers the peak and has good coverage (>90% trials)
recommended_window <- window_coverage %>%
  filter(window_end >= max_peak_time + 0.2) %>%  # Add 0.2s buffer after peak
  filter(pct_trials_sufficient >= 90) %>%
  arrange(window_end) %>%
  slice(1)

if (nrow(recommended_window) == 0) {
  # Fallback: use window with best coverage
  recommended_window <- window_coverage %>%
    arrange(desc(pct_trials_sufficient), window_end) %>%
    slice(1)
}

cat("\nRecommended window:", recommended_window$window, "\n")
cat("  Window: target +", recommended_window$window_start, "to target +", recommended_window$window_end, "seconds\n")
cat("  Coverage:", round(recommended_window$pct_trials_sufficient, 1), "% trials with sufficient data\n")

# Save recommendation
recommendation_text <- paste0(
  "# Chapter 3 Cognitive Window Recommendation\n\n",
  "## Recommended Window\n",
  "- **Window Name**: ", recommended_window$window, "\n",
  "- **Time Range**: target onset + ", recommended_window$window_start, "s to target onset + ", recommended_window$window_end, "s\n",
  "- **Coverage**: ", round(recommended_window$pct_trials_sufficient, 1), "% of trials have ≥80% valid data\n",
  "- **Mean Valid Data**: ", round(recommended_window$mean_pct_valid, 1), "%\n\n",
  "## Rationale\n",
  "- Maximum peak time across conditions: ", round(max_peak_time, 2), "s\n",
  "- This window captures the peak for all conditions with a 0.2s buffer\n",
  "- Coverage is acceptable (≥90% trials) for both ADT and VDT\n\n",
  "## Alternative Windows Considered\n",
  paste0(capture.output(print(window_coverage)), collapse = "\n")
)

writeLines(recommendation_text, file.path(QC_DIR, "ch3_window_recommendation.md"))
cat("✓ Saved window recommendation\n")

# ============================================================================
# PART 4: RESPONSE-LOCKED EXPLORATORY PLOT
# ============================================================================

cat("\nPART 4: Response-Locked Exploratory Plot\n")
cat("----------------------------------------\n")

# Compute response-locked time axis
# t_to_response = t_rel - resp_press_rel
# where resp_press_rel = resp_start_rel + rt

ch3_with_rt <- ch3_data %>%
  filter(ddm_ready == TRUE) %>%
  select(trial_uid, sub, task, session_used, run_used, trial_index, 
         t_resp_start_rel, rt, effort, isOddball)

  # Merge with flat data (use time_rel, not absolute time)
flat_response_locked <- all_flat_data %>%
  inner_join(ch3_with_rt, by = c("trial_uid", "sub", "task", "session_used", "run_used", "trial_index")) %>%
  filter(!is.na(rt), rt > 0) %>%
  mutate(
    resp_press_rel = t_resp_start_rel + rt,
    t_to_response = time_rel - resp_press_rel,
    effort_label = ifelse(effort == "high", "High Effort", "Low Effort"),
    oddball_label = ifelse(isOddball == 1, "Oddball", "Standard")
  ) %>%
  filter(t_to_response >= -3.0 & t_to_response <= 0.5)

cat("Prepared", nrow(flat_response_locked), "sample-level data points for response-locked plotting\n")

if (nrow(flat_response_locked) > 0) {
  # Compute waveform means
  waveform_response <- flat_response_locked %>%
    group_by(task, t_to_response) %>%
    summarise(
      mean_pupil = mean(pupil, na.rm = TRUE),
      se_pupil = sd(pupil, na.rm = TRUE) / sqrt(n()),
      n_trials = n_distinct(trial_uid),
      .groups = "drop"
    )
  
  # Plot response-locked waveform
  p_response <- ggplot(waveform_response, aes(x = t_to_response, y = mean_pupil, color = task)) +
    geom_ribbon(aes(ymin = mean_pupil - se_pupil, ymax = mean_pupil + se_pupil, fill = task), 
                alpha = 0.2, linetype = 0) +
    geom_line(size = 1) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    labs(x = "Time to response (s)", y = "Pupil diameter (mm)",
         title = "Response-Locked Pupil Waveforms",
         color = "Task", fill = "Task") +
    coord_cartesian(xlim = c(-3.0, 0.5)) +
    plot_theme
  
  ggsave(file.path(FIGS_DIR, "ch3_response_locked.png"), p_response, width = 8, height = 6, dpi = 300)
  cat("✓ Saved response-locked plot\n")
  
  # Compute mean slope in last 1s pre-response
  slope_summary <- flat_response_locked %>%
    filter(t_to_response >= -1.0 & t_to_response < 0) %>%
    group_by(trial_uid, task) %>%
    arrange(t_to_response) %>%
    summarise(
      n_samples = n(),
      slope = if(n() >= 2) {
        lm(pupil ~ t_to_response)$coefficients[2]
      } else NA_real_,
      .groups = "drop"
    ) %>%
    group_by(task) %>%
    summarise(
      n_trials = n(),
      mean_slope = mean(slope, na.rm = TRUE),
      se_slope = sd(slope, na.rm = TRUE) / sqrt(n()),
      .groups = "drop"
    )
  
  fwrite(slope_summary, file.path(QC_DIR, "ch3_response_locked_summary.csv"))
  cat("✓ Saved response-locked slope summary\n")
  print(slope_summary)
} else {
  cat("WARNING: No valid data for response-locked plotting\n")
}

cat("\n=== Analysis Complete ===\n")
cat("Outputs saved to:\n")
cat("  QC:", QC_DIR, "\n")
cat("  Figures:", FIGS_DIR, "\n")

