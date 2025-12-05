#!/usr/bin/env Rscript

# ============================================================================
# Pupil Waveform Plots (ADT and VDT)
# ============================================================================
# Generates publication-quality pupil waveform plots showing baseline-corrected
# pupil traces across conditions, with event markers and AUC windows
# Adapted from Zenon et al. (2014) method
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)  # Includes pipe operator %>%
  library(tidyr)
  library(readr)
  library(purrr)
  library(ggplot2)
  library(patchwork)
})

# Ensure pipe operator is available
if(!exists("%>%")) {
  library(magrittr)
}

cat("=== PUPIL WAVEFORM PLOTS ===\n")
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("NOTE: Using all available data (no run-based subject filtering)\n\n")

# ============================================================================
# CONFIGURATION
# ============================================================================

# Paths
processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
output_dir <- "06_visualization/publication_figures"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Define the common color scheme
condition_colors <- c(
  "Easy / Low" = "#5DADE2",    # Light blue
  "Easy / High" = "#2E86AB",   # Dark blue  
  "Hard / Low" = "#EC70AB",    # Light pink
  "Hard / High" = "#A23B72"    # Dark pink
)

# Timeline bar colors
timeline_bar_colors <- list(
  baseline = "#7F8C8D",
  total_auc = "#1F78B4",
  cognitive_auc = "#D95F02"
)

# Task configurations (ADT and VDT)
task_configs <- list(
  ADT = list(
    task_name = "ADT",
    stimulus_label = "Target onset",
    response_label = "Response",
    # Timing (relative to squeeze onset = 0)
    target_onset = 4.35,  # Target stimulus onset (after Standard 100ms + ISI 500ms)
    response_window_start = 4.7,  # Response window start
    total_auc_start = 0,  # From squeeze onset
    baseline_window_start = -0.5,  # Baseline window start
    baseline_window_end = 0,  # Baseline window end
    cognitive_auc_latency = 0.3  # 300ms after target onset
  ),
  VDT = list(
    task_name = "VDT",
    stimulus_label = "Target onset",
    response_label = "Response",
    # Timing (relative to squeeze onset = 0)
    target_onset = 4.35,  # Target stimulus onset (after Standard 100ms + ISI 500ms)
    response_window_start = 4.7,  # Response window start
    total_auc_start = 0,  # From squeeze onset
    baseline_window_start = -0.5,  # Baseline window start
    baseline_window_end = 0,  # Baseline window end
    cognitive_auc_latency = 0.3  # 300ms after target onset
  )
)

# ============================================================================
# 1. LOAD AND PREPARE DATA
# ============================================================================

cat("1. Loading merged flat files...\n")

# Find merged flat files
flat_files_merged <- list.files(processed_dir, pattern = "_flat_merged\\.csv$", full.names = TRUE)
flat_files_reg <- list.files(processed_dir, pattern = "_flat\\.csv$", full.names = TRUE)

# Prefer merged files
if (length(flat_files_merged) > 0 && length(flat_files_reg) > 0) {
  merged_ids <- gsub("_flat_merged\\.csv$", "", basename(flat_files_merged))
  reg_ids <- gsub("_flat\\.csv$", "", basename(flat_files_reg))
  reg_to_keep <- !reg_ids %in% merged_ids
  flat_files <- c(flat_files_merged, flat_files_reg[reg_to_keep])
  cat("  Using", length(flat_files_merged), "merged files +", sum(reg_to_keep), "regular files\n")
} else {
  flat_files <- c(flat_files_merged, flat_files_reg)
}

if(length(flat_files) == 0) {
  stop("ERROR: No flat files found in ", processed_dir)
}

cat("  Found", length(flat_files), "flat files\n")

# Load all flat files
cat("  Loading data...\n")
all_data <- purrr::map_dfr(flat_files, function(f) {
  cat("    Loading:", basename(f), "\n")
  readr::read_csv(f, show_col_types = FALSE, progress = FALSE)
})

cat("  Loaded", nrow(all_data), "total samples\n")

# Filter to ADT and VDT only
all_data <- dplyr::filter(all_data, task %in% c("ADT", "VDT"))

if(nrow(all_data) == 0) {
  stop("ERROR: No ADT or VDT data found")
}

cat("  Filtered to", nrow(all_data), "samples from ADT/VDT tasks\n")

# ============================================================================
# 2. CREATE BASELINE-CORRECTED PUPIL TRACE
# ============================================================================

cat("\n2. Creating baseline-corrected pupil traces...\n")

# Calculate global baseline (B0) per trial: 500ms window before squeeze onset
# Check if difficulty_level already exists
has_difficulty_level <- "difficulty_level" %in% names(all_data)

all_data <- dplyr::group_by(all_data, sub, task, run, trial_index)
all_data <- dplyr::mutate(all_data,
    # Calculate baseline B0 from -0.5s to 0s
    baseline_B0 = mean(pupil[time >= -0.5 & time < 0 & !is.na(pupil)], na.rm = TRUE),
    # Create isolated pupil trace (baseline-corrected)
    pupil_isolated = pupil - baseline_B0,
    # Create difficulty_level from isOddball and stimLev (if not already present)
    difficulty_level = if(has_difficulty_level) {
      difficulty_level
    } else {
      factor(case_when(
        isOddball == 0 ~ "Standard",
        # Map based on actual stimLev values in data (1-4 for Oddball trials)
        # Lower values = Hard (harder to detect), Higher values = Easy (easier to detect)
        isOddball == 1 & stimLev %in% c(1, 2, 8, 16, 0.06, 0.12) ~ "Hard",
        isOddball == 1 & stimLev %in% c(3, 4, 32, 64, 0.24, 0.48) ~ "Easy",
        TRUE ~ NA_character_
      ), levels = c("Standard", "Easy", "Hard"))
    },
    # Map force_condition to Low/High
    effort_level = case_when(
      force_condition == "Low_Force_5pct" ~ "Low",
      force_condition == "High_Force_40pct" ~ "High",
      TRUE ~ NA_character_
    ),
    # Create condition label (Difficulty / Effort)
    condition = case_when(
      !is.na(difficulty_level) & !is.na(effort_level) ~ 
        paste0(as.character(difficulty_level), " / ", effort_level),
      TRUE ~ "Unknown"
    ),
    # Use time as time_from_squeeze (time is already relative to squeeze onset)
    time_from_squeeze = time
  )
all_data <- dplyr::ungroup(all_data)

# Filter to valid conditions only
# Filter out Standard trials to only show Easy/Hard (matching the color scheme)
all_data <- dplyr::filter(all_data,
                          condition != "Unknown",
                          !is.na(pupil_isolated),
                          !is.na(time_from_squeeze),
                          !grepl("Standard", condition))  # Only Easy/Hard trials

# Count unique conditions (ensure condition is a character vector)
all_data$condition <- as.character(all_data$condition)
unique_conditions <- unique(all_data$condition[!is.na(all_data$condition) & all_data$condition != "Unknown"])
n_conditions <- length(unique_conditions)
cat("  Created baseline-corrected traces for", n_conditions, "conditions\n")
if(n_conditions > 0) {
  cat("    Conditions:", paste(unique_conditions, collapse = ", "), "\n")
}

# Calculate median response onset times per task (from actual RT data)
cat("\n3. Calculating median response onset times...\n")
response_onsets <- all_data %>%
  filter(!is.na(resp1RT), resp1RT > 0, resp1RT < 5.0) %>%
  group_by(task) %>%
  summarise(
    median_rt = median(resp1RT, na.rm = TRUE),
    median_response_onset = 4.7 + median_rt,  # Response window start + RT
    .groups = "drop"
  )

cat("  ADT median response onset:", round(response_onsets$median_response_onset[response_onsets$task == "ADT"], 2), "s\n")
cat("  VDT median response onset:", round(response_onsets$median_response_onset[response_onsets$task == "VDT"], 2), "s\n")

# ============================================================================
# 4. GENERATE WAVEFORM PLOTS
# ============================================================================

cat("\n4. Generating waveform plots...\n")

all_waveform_plots <- list()

for (task_name in c("ADT", "VDT")) {
  cat("  Processing", task_name, "...\n")
  
  task_data <- all_data %>%
    filter(task == task_name)
  
  if(nrow(task_data) == 0) {
    cat("    ⚠ No data for", task_name, "- skipping\n")
    next
  }
  
  config <- task_configs[[task_name]]
  response_onset_median <- response_onsets$median_response_onset[response_onsets$task == task_name]
  
  # If no RT data, use fixed response window start
  if(is.na(response_onset_median) || !is.finite(response_onset_median)) {
    response_onset_median <- config$response_window_start
    cat("    Using fixed response onset:", response_onset_median, "s\n")
  }
  
  # Create condition-specific averages for pupil_isolated
  waveform_summary <- task_data %>%
    dplyr::group_by(condition, time_from_squeeze) %>%
    dplyr::summarise(
      mean_pupil_isolated = mean(pupil_isolated, na.rm = TRUE),
      se_pupil_isolated = sd(pupil_isolated, na.rm = TRUE) / sqrt(n()),
      n_samples = n(),
      .groups = "drop"
    ) %>%
    dplyr::filter(!is.na(mean_pupil_isolated),
                  !is.na(time_from_squeeze))
  
  if(nrow(waveform_summary) == 0) {
    cat("    ⚠ No valid data for", task_name, "- skipping\n")
    next
  }
  
  # Determine dynamic y-limits from smoothed means
  x_range <- c(config$baseline_window_start, response_onset_median)
  smoothed_df <- suppressWarnings({
    tryCatch({
      ggplot_build(
        ggplot(waveform_summary, aes(x = time_from_squeeze, y = mean_pupil_isolated, color = condition)) +
          geom_smooth(se = TRUE, method = "gam", formula = y ~ s(x, k = 30))
      )$data[[1]] %>% as_tibble()
    }, error = function(e) {
      NULL
    })
  })
  
  y_limits <- if (!is.null(smoothed_df) && nrow(smoothed_df) > 0) {
    # Use wider range (0.01 to 0.99) to ensure confidence ribbons are fully visible
    y_min <- quantile(smoothed_df$y[smoothed_df$x >= x_range[1] & smoothed_df$x <= x_range[2]], 0.01, na.rm = TRUE)
    y_max <- quantile(smoothed_df$y[smoothed_df$x >= x_range[1] & smoothed_df$x <= x_range[2]], 0.99, na.rm = TRUE)
    c(y_min, y_max)
  } else {
    c(NA_real_, NA_real_)
  }
  
  if (any(!is.finite(y_limits))) {
    y_limits <- range(waveform_summary$mean_pupil_isolated, na.rm = TRUE)
  }
  
  if (any(!is.finite(y_limits)) || diff(y_limits) == 0) {
    fallback_span <- max(abs(y_limits), na.rm = TRUE)
    if (!is.finite(fallback_span) || fallback_span == 0) {
      fallback_span <- 1
    }
    y_limits <- c(-fallback_span, fallback_span)
  }
  
  # Calculate cognitive AUC start time
  cognitive_start_plot <- config$target_onset + config$cognitive_auc_latency
  if (cognitive_start_plot > response_onset_median) {
    cognitive_start_plot <- response_onset_median
  }
  
  y_range_span <- diff(y_limits)
  if (!is.finite(y_range_span) || y_range_span <= 0) {
    y_range_span <- max(abs(y_limits), na.rm = TRUE)
    if (!is.finite(y_range_span) || y_range_span == 0) {
      y_range_span <- 1
    }
  }
  
  extra_margin <- y_range_span * 0.3
  y_lower_limit <- y_limits[1] - extra_margin * 1.4
  y_upper_limit <- y_limits[2]
  
  # Timeline bars
  bar_positions <- tibble(
    label = c("Baseline", "Total AUC", "Cognitive AUC"),
    xstart = c(config$baseline_window_start, config$total_auc_start, cognitive_start_plot),
    xend = c(config$baseline_window_end, response_onset_median, response_onset_median),
    color = c(
      timeline_bar_colors$baseline,
      timeline_bar_colors$total_auc,
      timeline_bar_colors$cognitive_auc
    )
  )
  
  bar_spacing <- extra_margin / (nrow(bar_positions) + 1)
  bar_positions <- bar_positions %>%
    mutate(
      y = y_lower_limit + bar_spacing * seq_len(n()),
      text_y = y + bar_spacing * 0.65,
      x_label = (xstart + xend) / 2
    )
  
  # Event markers
  event_markers_plot <- tibble(
    event = c("Trial onset", config$stimulus_label, config$response_label),
    time = c(0, config$target_onset, response_onset_median)
  ) %>%
    filter(!is.na(time))
  
  event_label_y <- y_upper_limit - y_range_span * 0.005
  
  # Plotting range
  plot_start_time <- config$baseline_window_start
  plot_end_time <- response_onset_median
  
  # Ensure condition is a factor with proper levels
  waveform_summary$condition <- factor(waveform_summary$condition, 
                                       levels = names(condition_colors))
  
  # Create plot
  plot_waveform <- ggplot(waveform_summary, 
                          aes(x = time_from_squeeze, y = mean_pupil_isolated, 
                              color = condition, fill = condition)) +
    # Smoothed lines with confidence intervals
    geom_smooth(method = "gam", formula = y ~ s(x, k = 30), 
                linewidth = 1.2, span = 0.2, se = TRUE, alpha = 0.3) +
    
    # Vertical markers for events
    {if (nrow(event_markers_plot) > 0) 
      geom_vline(data = event_markers_plot, aes(xintercept = time), 
                 linetype = "dashed", color = "grey40", linewidth = 0.6)
    } +
    {if (nrow(event_markers_plot) > 0) 
      geom_text(data = event_markers_plot, aes(x = time, y = event_label_y, label = event), 
                inherit.aes = FALSE, size = 4.5, color = "grey20", hjust = 0.5, vjust = 1.1, fontface = "bold")
    } +
    
    # Timeline bars
    geom_segment(
      data = bar_positions,
      aes(x = xstart, xend = xend, y = y, yend = y, color = I(color)),
      inherit.aes = FALSE,
      linewidth = 2.2,
      lineend = "round"
    ) +
    geom_text(
      data = bar_positions,
      aes(x = x_label, y = text_y, label = label, color = I(color)),
      inherit.aes = FALSE,
      size = 3.5,
      fontface = "bold"
    ) +
    
    labs(
      title = task_name,
      x = if (task_name == "VDT") "Time Relative to Squeeze Onset (seconds)" else NULL,
      y = "Isolated Pupil (arbitrary units)",
      color = "Condition",
      fill = "Condition"
    ) +
    
    scale_color_manual(values = condition_colors, name = "Condition", 
                       breaks = names(condition_colors),
                       guide = guide_legend(override.aes = list(fill = condition_colors))) +
    scale_fill_manual(values = condition_colors, name = "Condition",
                      breaks = names(condition_colors)) +
    scale_x_continuous(breaks = seq(0, ceiling(plot_end_time), by = 1)) +
    coord_cartesian(xlim = c(plot_start_time, plot_end_time), 
                    ylim = c(y_lower_limit, y_upper_limit)) +
    theme_minimal() +
    theme(
      text = element_text(size = 12),
      plot.title = element_text(size = 18, face = "bold"),
      axis.title = element_text(size = 14, face = "bold"),
      axis.text = element_text(size = 12),
      legend.position = "bottom",
      legend.box = "horizontal",
      legend.title = element_text(size = 14, face = "bold"),
      legend.text = element_text(size = 12),
      legend.key.size = unit(1.2, "cm"),
      legend.margin = margin(t = 10),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "grey90", linewidth = 0.3),
      plot.margin = margin(12, 20, 32, 16)
    )
  
  all_waveform_plots[[task_name]] <- plot_waveform
  cat("    ✓ Created waveform plot for", task_name, "\n")
}

# ============================================================================
# 5. COMBINE AND SAVE PLOTS
# ============================================================================

if(length(all_waveform_plots) > 0) {
  cat("\n5. Combining plots...\n")
  
  # Combine ADT and VDT plots
  if("ADT" %in% names(all_waveform_plots) && "VDT" %in% names(all_waveform_plots)) {
    combined_waveform_plot <- (all_waveform_plots[["ADT"]] / all_waveform_plots[["VDT"]]) +
      plot_layout(guides = "collect") &
      theme(
        legend.position = "bottom",
        legend.direction = "horizontal",
        panel.spacing = grid::unit(2.4, "lines")
      )
    
    output_file <- file.path(output_dir, "Figure3_Pupil_Waveforms_ADT_VDT.png")
    ggsave(output_file, combined_waveform_plot, width = 12, height = 10, dpi = 300)
    cat("  ✓ Saved:", output_file, "\n")
  }
  
  # Save individual plots
  for(task_name in names(all_waveform_plots)) {
    output_file <- file.path(output_dir, paste0("Pupil_Waveform_", task_name, ".png"))
    ggsave(output_file, all_waveform_plots[[task_name]], width = 10, height = 6, dpi = 300)
    cat("  ✓ Saved:", output_file, "\n")
  }
} else {
  cat("\n⚠ No plots generated - check data availability\n")
}

# ============================================================================
# COMPLETION
# ============================================================================

cat("\n=== WAVEFORM PLOTS COMPLETE ===\n")
cat("Completed at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Output directory:", output_dir, "\n")

