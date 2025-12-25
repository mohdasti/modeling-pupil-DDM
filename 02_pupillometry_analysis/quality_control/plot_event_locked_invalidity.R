#!/usr/bin/env Rscript

# ============================================================================
# Plot Event-Locked Invalidity (Prompt 4)
# ============================================================================
# Creates overlay plots of P(invalid pupil) time-locked to events
# to check if prestim dip is a boundary artifact (blinks/transitions)
# vs true dropout
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(patchwork)
})

cat("=== PLOT EVENT-LOCKED INVALIDITY ===\n")
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Configuration
qc_dir <- "data/qc"
invalidity_file <- file.path(qc_dir, "event_locked_invalidity.csv")
output_dir <- "02_pupillometry_analysis/quality_control/figures"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(invalidity_file)) {
  stop("ERROR: Event-locked invalidity file not found. Run build_pupil_trial_coverage_prefilter.R first.")
}

# Load data
cat("Loading event-locked invalidity data...\n")
invalidity_data <- read_csv(invalidity_file, show_col_types = FALSE)

if (nrow(invalidity_data) == 0) {
  stop("ERROR: No data in event-locked invalidity file.")
}

cat("  Loaded", nrow(invalidity_data), "rows\n")
cat("  Tasks:", paste(unique(invalidity_data$task), collapse = ", "), "\n")
cat("  Events:", paste(unique(invalidity_data$event), collapse = ", "), "\n\n")

# Event labels for plots
event_labels <- c(
  "grip_onset" = "Grip Gauge Onset (TrialST)",
  "blank_onset" = "Blank Onset (blankST)",
  "fixation_onset" = "Fixation Onset (fixST)",
  "stimulus_onset" = "Stimulus Pair Onset (A/V_ST)"
)

# Plot 1: Overlay ADT vs VDT for each event
cat("Creating overlay plots (ADT vs VDT)...\n")

plots_list <- map(unique(invalidity_data$event), function(event_name) {
  event_data <- invalidity_data %>%
    filter(event == event_name) %>%
    mutate(
      task_label = ifelse(task == "ADT", "Auditory (ADT)", "Visual (VDT)")
    )
  
  if (nrow(event_data) == 0) {
    return(NULL)
  }
  
  p <- ggplot(event_data, aes(x = t_bin, y = p_invalid_mean, color = task_label)) +
    geom_line(size = 1, alpha = 0.8) +
    geom_ribbon(
      aes(ymin = p_invalid_mean - p_invalid_se, 
          ymax = p_invalid_mean + p_invalid_se,
          fill = task_label),
      alpha = 0.2,
      linetype = 0
    ) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", alpha = 0.7) +
    scale_color_manual(
      name = "Task",
      values = c("Auditory (ADT)" = "#E31A1C", "Visual (VDT)" = "#1F78B4")
    ) +
    scale_fill_manual(
      name = "Task",
      values = c("Auditory (ADT)" = "#E31A1C", "Visual (VDT)" = "#1F78B4")
    ) +
    labs(
      title = event_labels[event_name],
      subtitle = "P(invalid pupil) time-locked to event (±500ms, 20ms bins)",
      x = "Time Relative to Event (s)",
      y = "P(Invalid Pupil)",
      caption = "Vertical line marks event onset (t=0)"
    ) +
    theme_minimal() +
    theme(
      legend.position = "bottom",
      plot.title = element_text(face = "bold"),
      panel.grid.minor = element_blank()
    ) +
    coord_cartesian(xlim = c(-0.5, 0.5))
  
  return(p)
})

# Remove NULL plots
plots_list <- plots_list[!sapply(plots_list, is.null)]

if (length(plots_list) > 0) {
  # Combine plots
  combined_plot <- wrap_plots(plots_list, ncol = 2) +
    plot_annotation(
      title = "Event-Locked Pupil Invalidity: ADT vs VDT",
      subtitle = "If invalidity peaks sharply at event boundaries, prestim dip is a boundary artifact (blinks/transitions), not random missingness",
      theme = theme(plot.title = element_text(size = 14, face = "bold"))
    )
  
  # Save
  output_file <- file.path(output_dir, "event_locked_invalidity_overlay.png")
  ggsave(
    output_file,
    combined_plot,
    width = 14,
    height = 10,
    dpi = 300
  )
  cat("  ✓ Saved overlay plot to:", output_file, "\n")
}

# Plot 2: Focus on fixation and stimulus onsets (most relevant for prestim dip)
cat("\nCreating focused plot (fixation & stimulus onsets)...\n")

focused_events <- invalidity_data %>%
  filter(event %in% c("fixation_onset", "stimulus_onset")) %>%
  mutate(
    task_label = ifelse(task == "ADT", "Auditory (ADT)", "Visual (VDT)"),
    event_label = ifelse(
      event == "fixation_onset",
      "Fixation Onset (fixST)",
      "Stimulus Pair Onset (A/V_ST)"
    )
  )

if (nrow(focused_events) > 0) {
  p_focused <- ggplot(focused_events, aes(x = t_bin, y = p_invalid_mean, color = task_label)) +
    geom_line(size = 1.2, alpha = 0.9) +
    geom_ribbon(
      aes(ymin = p_invalid_mean - p_invalid_se,
          ymax = p_invalid_mean + p_invalid_se,
          fill = task_label),
      alpha = 0.25,
      linetype = 0
    ) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", alpha = 0.7) +
    facet_wrap(~ event_label, ncol = 2, scales = "free_y") +
    scale_color_manual(
      name = "Task",
      values = c("Auditory (ADT)" = "#E31A1C", "Visual (VDT)" = "#1F78B4")
    ) +
    scale_fill_manual(
      name = "Task",
      values = c("Auditory (ADT)" = "#E31A1C", "Visual (VDT)" = "#1F78B4")
    ) +
    labs(
      title = "Event-Locked Invalidity: Fixation & Stimulus Onsets",
      subtitle = "P(invalid pupil) time-locked to key events (±500ms, 20ms bins)",
      x = "Time Relative to Event (s)",
      y = "P(Invalid Pupil)",
      caption = "Sharp peaks at t=0 indicate boundary artifacts (blinks/transitions)"
    ) +
    theme_minimal() +
    theme(
      legend.position = "bottom",
      plot.title = element_text(face = "bold", size = 12),
      strip.text = element_text(face = "bold"),
      panel.grid.minor = element_blank()
    ) +
    coord_cartesian(xlim = c(-0.5, 0.5))
  
  output_file_focused <- file.path(output_dir, "event_locked_invalidity_focused.png")
  ggsave(
    output_file_focused,
    p_focused,
    width = 12,
    height = 6,
    dpi = 300
  )
  cat("  ✓ Saved focused plot to:", output_file_focused, "\n")
}

# Summary statistics
cat("\n=== SUMMARY STATISTICS ===\n")
summary_stats <- invalidity_data %>%
  group_by(task, event) %>%
  summarise(
    max_p_invalid = max(p_invalid_mean, na.rm = TRUE),
    mean_p_invalid = mean(p_invalid_mean, na.rm = TRUE),
    p_invalid_at_t0 = {
      t0_data <- filter(., abs(t_bin) < 0.01)
      if (nrow(t0_data) > 0) mean(t0_data$p_invalid_mean, na.rm = TRUE) else NA_real_
    },
    .groups = "drop"
  ) %>%
  arrange(task, event)

print(summary_stats)

# Interpretation
cat("\n=== INTERPRETATION ===\n")
cat("If P(invalid) peaks sharply at t=0 (event onset), this suggests:\n")
cat("  - Boundary artifacts (blinks/eye movements during transitions)\n")
cat("  - NOT random missingness\n")
cat("  - Prestim dip may be due to fixation onset transition, not true dropout\n\n")

cat("=== PLOT COMPLETE ===\n")
cat("Completed at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")



