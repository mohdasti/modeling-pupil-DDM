#!/usr/bin/env Rscript
# ============================================================================
# Chapter 3 Window Selection and Timing Verification (v3)
# ============================================================================
# Updated to include W1.3, W2.0, W2.5, W3.0, and RespWin windows
# Outputs to versioned QC directory: qc/ch3_extension_v3/
# ============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(ggplot2)
  library(readr)
})

REPO_ROOT <- normalizePath(".")
QUICK_SHARE_DIR <- file.path(REPO_ROOT, "quick_share_v7")
MERGED_FILE <- file.path(QUICK_SHARE_DIR, "merged", "BAP_triallevel_merged_v4.csv")
CH3_FILE <- file.path(QUICK_SHARE_DIR, "analysis_ready", "ch3_triallevel.csv")
WAVEFORM_FILE <- file.path(QUICK_SHARE_DIR, "analysis", "pupil_waveforms_condition_mean.csv")

QC_DIR <- file.path(QUICK_SHARE_DIR, "qc", "ch3_extension_v3")
FIGS_DIR <- file.path(QUICK_SHARE_DIR, "figs")
dir.create(QC_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIGS_DIR, recursive = TRUE, showWarnings = FALSE)

cat("=== Chapter 3 Window Selection (v3) ===\n\n")

EXPECTED_TARGET_ONSET <- 4.35
EXPECTED_RESP_START <- 4.70
EXPECTED_RESP_END <- 7.70

# PART 1: Timing verification
cat("PART 1: Timing Verification\n")
cat("---------------------------\n")
merged <- fread(MERGED_FILE)
merged_timing <- merged %>%
  mutate(
    stim1_onset_rel = ifelse(!is.na(t_target_onset_rel), t_target_onset_rel - 0.6, NA_real_),
    target_onset_rel = t_target_onset_rel,
    resp_start_rel = t_resp_start_rel,
    target_stim1_diff = target_onset_rel - stim1_onset_rel
  ) %>%
  filter(!is.na(task), task %in% c("ADT", "VDT"))

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
cat("✓ Found", nrow(outlier_runs), "outlier runs\n\n")

# PART 2: Waveform plotting using existing summaries
cat("PART 2: Stimulus-Locked Waveform Plotting\n")
cat("------------------------------------------\n")

if (!file.exists(WAVEFORM_FILE)) {
  stop("ERROR: Waveform file not found: ", WAVEFORM_FILE)
}

waveform_data <- fread(WAVEFORM_FILE) %>%
  filter(chapter == "ch3") %>%
  mutate(
    t_from_target = t_rel - EXPECTED_TARGET_ONSET,
    effort_label = ifelse(effort == "High", "High Effort", "Low Effort"),
    oddball_label = ifelse(isOddball == 1, "Oddball", "Standard")
  )

max_time_rel <- max(waveform_data$t_rel, na.rm = TRUE)
max_t_from_target <- max(waveform_data$t_from_target, na.rm = TRUE)
cat("Waveform data extends to:", max_time_rel, "s from squeeze onset\n")
cat("Waveform data extends to:", round(max_t_from_target, 2), "s from target onset\n")

# Plot window: -0.5 to +3.5s from target (sufficient for TEPR analysis)
plot_window_end <- min(3.5, max_t_from_target - 0.1)  # Leave small margin
cat("Plotting window: -0.5 to", round(plot_window_end, 2), "s from target\n")

# Filter for plotting
waveform_data_plot <- waveform_data %>%
  filter(t_from_target >= -0.5 & t_from_target <= plot_window_end)

# Verify data extends to at least 7.65s from squeeze (target + 3.3s minimum)
required_min_for_windows <- EXPECTED_TARGET_ONSET + 3.3  # Need target + 3.3s for W3.0 window
if (max_time_rel < required_min_for_windows) {
  extension_needed <- required_min_for_windows - max_time_rel
  warning("WARNING: Waveform data may not extend far enough for full window selection analysis.\n",
          "Available: ", max_time_rel, "s. Recommended: ", required_min_for_windows, "s.\n",
          "Need extension of: ", round(extension_needed, 2), "s.\n",
          "Proceeding with available data, but W3.0 window selection may be limited.\n")
} else {
  cat("✓ Data extension sufficient for full window selection analysis\n")
}

waveform_by_task <- waveform_data_plot %>%
  group_by(task, t_from_target) %>%
  summarise(
    mean_pupil = mean(mean_pupil_full, na.rm = TRUE),
    se_pupil = sd(mean_pupil_full, na.rm = TRUE) / sqrt(n()),
    n_trials = sum(n_trials, na.rm = TRUE),
    .groups = "drop"
  )

waveform_by_effort <- waveform_data_plot %>%
  group_by(task, effort_label, t_from_target) %>%
  summarise(
    mean_pupil = mean(mean_pupil_full, na.rm = TRUE),
    se_pupil = sd(mean_pupil_full, na.rm = TRUE) / sqrt(n()),
    n_trials = sum(n_trials, na.rm = TRUE),
    .groups = "drop"
  )

waveform_by_oddball <- waveform_data_plot %>%
  group_by(task, oddball_label, t_from_target) %>%
  summarise(
    mean_pupil = mean(mean_pupil_full, na.rm = TRUE),
    se_pupil = sd(mean_pupil_full, na.rm = TRUE) / sqrt(n()),
    n_trials = sum(n_trials, na.rm = TRUE),
    .groups = "drop"
  )

plot_theme <- theme_minimal() +
  theme(panel.grid.minor = element_blank(), legend.position = "bottom",
        axis.title = element_text(size = 12), axis.text = element_text(size = 10))

p_task <- ggplot(waveform_by_task, aes(x = t_from_target, y = mean_pupil, color = task)) +
  geom_ribbon(aes(ymin = mean_pupil - se_pupil, ymax = mean_pupil + se_pupil, fill = task), alpha = 0.2, linetype = 0) +
  geom_line(linewidth = 1) + geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  labs(x = "Time from target onset (s)", y = "Pupil diameter (mm)", title = "Stimulus-Locked Pupil Waveforms by Task") +
  coord_cartesian(xlim = c(-0.5, plot_window_end)) + plot_theme
ggsave(file.path(FIGS_DIR, "ch3_waveform_by_task.png"), p_task, width = 8, height = 6, dpi = 300)

p_effort <- ggplot(waveform_by_effort, aes(x = t_from_target, y = mean_pupil, color = effort_label)) +
  geom_ribbon(aes(ymin = mean_pupil - se_pupil, ymax = mean_pupil + se_pupil, fill = effort_label), alpha = 0.2, linetype = 0) +
  geom_line(linewidth = 1) + geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  facet_wrap(~ task) + labs(x = "Time from target onset (s)", y = "Pupil diameter (mm)", title = "Stimulus-Locked Pupil Waveforms by Effort Level") +
  coord_cartesian(xlim = c(-0.5, plot_window_end)) + plot_theme
ggsave(file.path(FIGS_DIR, "ch3_waveform_by_effort.png"), p_effort, width = 10, height = 6, dpi = 300)

p_oddball <- ggplot(waveform_by_oddball, aes(x = t_from_target, y = mean_pupil, color = oddball_label)) +
  geom_ribbon(aes(ymin = mean_pupil - se_pupil, ymax = mean_pupil + se_pupil, fill = oddball_label), alpha = 0.2, linetype = 0) +
  geom_line(linewidth = 1) + geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  facet_wrap(~ task) + labs(x = "Time from target onset (s)", y = "Pupil diameter (mm)", title = "Stimulus-Locked Pupil Waveforms by Stimulus Type") +
  coord_cartesian(xlim = c(-0.5, plot_window_end)) + plot_theme
ggsave(file.path(FIGS_DIR, "ch3_waveform_by_oddball.png"), p_oddball, width = 10, height = 6, dpi = 300)

cat("✓ Saved waveform plots\n\n")

# PART 3: Window selection diagnostics
cat("PART 3: Window Selection Diagnostics\n")
cat("------------------------------------\n")

# Peak search window: 0.3 to 3.3 seconds post-target
peak_search_end <- min(3.3, plot_window_end)  # Search up to 3.3s post-target
peak_summary_list <- list()

for (t in unique(waveform_by_task$task)) {
  wf <- waveform_by_task %>% filter(task == t, t_from_target >= 0.3 & t_from_target <= peak_search_end)
  if (nrow(wf) > 0 && any(!is.na(wf$mean_pupil))) {
    peak_idx <- which.max(wf$mean_pupil)
    if (length(peak_idx) > 0 && is.finite(peak_idx)) {
      peak_summary_list[[length(peak_summary_list) + 1]] <- data.frame(
        condition_set = "task", condition_value = t,
        time_to_peak = wf$t_from_target[peak_idx], peak_amplitude = wf$mean_pupil[peak_idx]
      )
    }
  }
}

for (t in unique(waveform_by_effort$task)) {
  for (e in unique(waveform_by_effort$effort_label)) {
    wf <- waveform_by_effort %>% filter(task == t, effort_label == e, t_from_target >= 0.3 & t_from_target <= peak_search_end)
    if (nrow(wf) > 0 && any(!is.na(wf$mean_pupil))) {
      peak_idx <- which.max(wf$mean_pupil)
      if (length(peak_idx) > 0 && is.finite(peak_idx)) {
        peak_summary_list[[length(peak_summary_list) + 1]] <- data.frame(
          condition_set = "effort", condition_value = paste(t, e, sep = "_"),
          time_to_peak = wf$t_from_target[peak_idx], peak_amplitude = wf$mean_pupil[peak_idx]
        )
      }
    }
  }
}

for (t in unique(waveform_by_oddball$task)) {
  for (o in unique(waveform_by_oddball$oddball_label)) {
    wf <- waveform_by_oddball %>% filter(task == t, oddball_label == o, t_from_target >= 0.3 & t_from_target <= peak_search_end)
    if (nrow(wf) > 0 && any(!is.na(wf$mean_pupil))) {
      peak_idx <- which.max(wf$mean_pupil)
      if (length(peak_idx) > 0 && is.finite(peak_idx)) {
        peak_summary_list[[length(peak_summary_list) + 1]] <- data.frame(
          condition_set = "oddball", condition_value = paste(t, o, sep = "_"),
          time_to_peak = wf$t_from_target[peak_idx], peak_amplitude = wf$mean_pupil[peak_idx]
        )
      }
    }
  }
}

peak_summary <- bind_rows(peak_summary_list)
if (nrow(peak_summary) > 0) {
  fwrite(peak_summary, file.path(QC_DIR, "ch3_time_to_peak_summary.csv"))
  cat("✓ Saved time to peak summary\n")
} else {
  cat("⚠ WARNING: No peak data found - time_to_peak_summary.csv will be empty\n")
}

# Window coverage - includes W1.3, W2.0, W2.5, W3.0, and RespWin
windows <- list(
  W1.3 = c(0.3, 1.3),      # target+0.3 to target+1.3 (early cognitive, minimal post-response)
  W2.0 = c(0.3, 2.3),      # target+0.3 to target+2.3
  W2.5 = c(0.3, 2.8),      # target+0.3 to target+2.8
  W3.0 = c(0.3, 3.3),      # target+0.3 to target+3.3 (captures full TEPR peak)
  RespWin = c(0.3, EXPECTED_RESP_END - EXPECTED_TARGET_ONSET)  # target+0.3 to Resp1ET (7.70)
)

window_coverage_list <- list()

for (win_name in names(windows)) {
  win_start_rel <- windows[[win_name]][1] + EXPECTED_TARGET_ONSET
  win_end_rel <- windows[[win_name]][2] + EXPECTED_TARGET_ONSET
  
  # Check coverage using waveform data (which extends to 7.70s)
  coverage_by_task <- waveform_data %>%
    group_by(task) %>%
    summarise(
      has_data_in_window = any(t_rel >= win_start_rel & t_rel <= win_end_rel, na.rm = TRUE),
      max_t_rel = max(t_rel, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      window = win_name, 
      window_start_rel = win_start_rel, 
      window_end_rel = win_end_rel,
      coverage = ifelse(max_t_rel >= win_end_rel, TRUE, FALSE)
    )
  
  window_coverage_list[[win_name]] <- coverage_by_task
}

window_coverage <- bind_rows(window_coverage_list) %>%
  mutate(
    window_start_post_target = window_start_rel - EXPECTED_TARGET_ONSET,
    window_end_post_target = window_end_rel - EXPECTED_TARGET_ONSET
  ) %>%
  select(window, window_start_rel, window_end_rel, window_start_post_target, window_end_post_target, 
         task, coverage, has_data_in_window, max_t_rel)

fwrite(window_coverage, file.path(QC_DIR, "ch3_window_coverage.csv"))
cat("✓ Saved window coverage summary\n")

# Window recommendation logic
max_peak_time <- if (nrow(peak_summary) > 0 && any(is.finite(peak_summary$time_to_peak))) {
  max(peak_summary$time_to_peak, na.rm = TRUE)
} else {
  NA_real_
}

# Recommend smallest window whose end >= max_peak + 0.2s AND has coverage for BOTH tasks
# If no peak data, default to W3.0
if (!is.na(max_peak_time) && is.finite(max_peak_time)) {
  recommended_window <- window_coverage %>%
    filter(coverage == TRUE, window_end_post_target >= max_peak_time + 0.2) %>%
    group_by(window) %>%
    filter(n_distinct(task) == 2) %>%  # Coverage for both tasks
    ungroup() %>%
    arrange(window_end_post_target) %>%
    slice(1)
  
  if (nrow(recommended_window) == 0) {
    # Fallback: any window with coverage
    recommended_window <- window_coverage %>%
      filter(coverage == TRUE) %>%
      group_by(window) %>%
      filter(n_distinct(task) == 2) %>%
      ungroup() %>%
      arrange(desc(window_end_post_target)) %>%
      slice(1)
  }
} else {
  # Default to W3.0 if no peak data
  recommended_window <- window_coverage %>%
    filter(window == "W3.0") %>%
    slice(1)
  cat("⚠ No peak data available - defaulting to W3.0 window\n")
}

if (nrow(recommended_window) == 0) {
  recommended_window <- window_coverage %>% 
    arrange(desc(window_end_post_target)) %>% 
    slice(1)
}

cat("\nRecommended window:", recommended_window$window[1], "\n")
cat("  Window: target +", recommended_window$window_start_post_target[1], "to target +", recommended_window$window_end_post_target[1], "seconds\n")
if (!is.na(max_peak_time) && is.finite(max_peak_time)) {
  cat("  Maximum peak time:", round(max_peak_time, 2), "s post-target\n")
}

recommendation_text <- paste0(
  "# Chapter 3 Cognitive Window Recommendation\n\n",
  "## Recommended Window\n",
  "- **Window Name**: ", recommended_window$window[1], "\n",
  "- **Time Range**: target onset + ", recommended_window$window_start_post_target[1], "s to target onset + ", recommended_window$window_end_post_target[1], "s\n"
)

if (!is.na(max_peak_time) && is.finite(max_peak_time)) {
  recommendation_text <- paste0(
    recommendation_text,
    "- **Maximum peak time**: ", round(max_peak_time, 2), "s post-target\n\n"
  )
}

writeLines(recommendation_text, file.path(QC_DIR, "ch3_window_recommendation.md"))
cat("✓ Saved window recommendation\n\n")

cat("=== Analysis Complete ===\n")

