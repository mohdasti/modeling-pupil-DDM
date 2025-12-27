#!/usr/bin/env Rscript

# ============================================================================
# Pupil Waveform Plots (ADT and VDT)
# ============================================================================
# Generates publication-quality pupil waveform plots showing baseline-corrected
# pupil traces across conditions, with event markers and AUC windows
# Updated to use quick_share_v6 waveform summaries or process from flat files
# Adapted from Zenon et al. (2014) method
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(purrr)
  library(ggplot2)
  library(patchwork)
  library(yaml)
  library(here)
})

cat("=== PUPIL WAVEFORM PLOTS ===\n")
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# ============================================================================
# CONFIGURATION
# ============================================================================

REPO_ROOT <- here::here()

# Load config
config_file <- file.path(REPO_ROOT, "config", "data_paths.yaml")
if (file.exists(config_file)) {
  config <- read_yaml(config_file)
  processed_dir <- config$processed_dir
} else {
  processed_dir <- Sys.getenv("PUPIL_PROCESSED_DIR")
  if (processed_dir == "") {
    processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
  }
}

# Check for quick_share_v7 waveform summaries
V7_ROOT <- file.path(REPO_ROOT, "quick_share_v7")
V7_WAVEFORM_FILE <- file.path(V7_ROOT, "analysis", "pupil_waveforms_condition_mean.csv")

output_dir <- file.path(REPO_ROOT, "06_visualization", "publication_figures")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Use waveform summaries if available
use_waveform_summaries <- file.exists(V7_WAVEFORM_FILE)

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

# Task configurations (ADT and VDT) - Updated timing
task_configs <- list(
  ADT = list(
    task_name = "ADT",
    stimulus_label = "Target",
    response_label = "Response",
    # Timing (relative to squeeze onset = 0) - Based on MATLAB task code
    squeeze_end = 3.0,  # Squeeze ends (blank screen starts)
    blank_end = 3.25,  # Blank screen ends (fixation starts)
    fixation_end = 3.75,  # Fixation ends (Standard stimulus starts)
    standard_onset = 3.75,  # Standard (1st stimulus) onset (A/V_ST) - 100ms duration
    standard_end = 3.85,  # Standard ends (ISI starts)
    isi_end = 4.35,  # ISI ends (Target stimulus starts)
    target_onset = 4.35,  # Target (2nd stimulus) onset - 100ms duration
    target_end = 4.45,  # Target ends (post-stimulus blank starts)
    post_stim_blank_end = 4.7,  # Post-stimulus blank ends (Response window starts)
    response_window_start = 4.7,  # Response window start (Resp1ST)
    response_window_end = 7.70,  # End of Response 1 window (Resp1ET) - 3000ms duration
    total_auc_start = 0,  # From squeeze onset
    baseline_window_start = -0.5,  # Baseline B0 window start
    baseline_window_end = 0,  # Baseline B0 window end
    cognitive_auc_latency = 0.3,  # 300ms after target onset (cognitive window starts at 4.65s)
    cognitive_auc_end = 6.65  # Cognitive AUC ends at target+2.3s (W2.0 window, extends into response period)
  ),
  VDT = list(
    task_name = "VDT",
    stimulus_label = "Target",
    response_label = "Response",
    # Timing (relative to squeeze onset = 0) - Based on MATLAB task code
    squeeze_end = 3.0,  # Squeeze ends (blank screen starts)
    blank_end = 3.25,  # Blank screen ends (fixation starts)
    fixation_end = 3.75,  # Fixation ends (Standard stimulus starts)
    standard_onset = 3.75,  # Standard (1st stimulus) onset (A/V_ST) - 100ms duration
    standard_end = 3.85,  # Standard ends (ISI starts)
    isi_end = 4.35,  # ISI ends (Target stimulus starts)
    target_onset = 4.35,  # Target (2nd stimulus) onset - 100ms duration
    target_end = 4.45,  # Target ends (post-stimulus blank starts)
    post_stim_blank_end = 4.7,  # Post-stimulus blank ends (Response window starts)
    response_window_start = 4.7,  # Response window start (Resp1ST)
    response_window_end = 7.70,  # End of Response 1 window (Resp1ET) - 3000ms duration
    total_auc_start = 0,  # From squeeze onset
    baseline_window_start = -0.5,  # Baseline B0 window start
    baseline_window_end = 0,  # Baseline B0 window end
    cognitive_auc_latency = 0.3,  # 300ms after target onset (cognitive window starts at 4.65s)
    cognitive_auc_end = 6.65  # Cognitive AUC ends at target+2.3s (W2.0 window, extends into response period)
  )
)

# ============================================================================
# 1. LOAD AND PREPARE DATA
# ============================================================================

if (use_waveform_summaries) {
  cat("1. Loading waveform summaries from quick_share_v7...\n")
  
  waveform_data <- read_csv(V7_WAVEFORM_FILE, show_col_types = FALSE)
  
  cat("  ✓ Loaded waveform summaries\n")
  cat("    Total rows: ", nrow(waveform_data), "\n", sep = "")
  cat("    Chapters: ", paste(unique(waveform_data$chapter), collapse = ", "), "\n", sep = "")
  
  # Standardize column names and create condition labels
  all_data <- waveform_data %>%
    rename(
      time_from_squeeze = t_rel,
      mean_pupil_isolated = mean_pupil_full  # Use B0-corrected (full baseline correction)
    ) %>%
    mutate(
      # Map stimulus_intensity to difficulty: Easy vs Hard
      # Standard mapping: stim_intensity 1-2 = Hard, 3-4 = Easy, 0 = Standard
      # Note: stimulus_intensity may be NA for some trials
      difficulty_level = case_when(
        isOddball == 0 | (is.na(isOddball) & (!is.na(stimulus_intensity) & stimulus_intensity == 0)) ~ "Standard",
        !is.na(stimulus_intensity) & stimulus_intensity %in% c(1, 2) ~ "Hard",
        !is.na(stimulus_intensity) & stimulus_intensity %in% c(3, 4) ~ "Easy",
        isOddball == 1 & is.na(stimulus_intensity) ~ "Easy",  # Fallback: if isOddball=1 but no stimulus_intensity, assume Easy
        TRUE ~ NA_character_
      ),
      # Map effort to Low/High
      effort_level = case_when(
        effort == "Low" | effort == "Low_Force_5pct" ~ "Low",
        effort == "High" | effort == "High_Force_40pct" ~ "High",
        TRUE ~ NA_character_
      ),
      # Create condition label (Difficulty / Effort) matching color scheme
      condition = case_when(
        !is.na(difficulty_level) & !is.na(effort_level) ~ 
          paste0(difficulty_level, " / ", effort_level),
        TRUE ~ "Unknown"
      )
    ) %>%
    filter(condition != "Unknown", !grepl("Standard", condition))  # Only Easy/Hard
  
  # For plotting, use Ch2 (50Hz) waveforms
  all_data <- all_data %>%
    filter(chapter == "ch2", sample_rate_hz == 50) %>%
    select(-chapter, -sample_rate_hz, -difficulty_level, -effort_level, -mean_pupil_partial, -n_trials)
  
  cat("  Using Ch2 waveforms (50Hz) for plotting\n")
  cat("    Filtered to ", nrow(all_data), " rows\n", sep = "")
  
  # Calculate SE from n_trials if needed (for now, we'll use smoothed CI from geom_smooth)
  # Note: quick_share_v7 doesn't include SE, so we'll rely on geom_smooth confidence intervals
  
  # Ensure condition matches color scheme
  all_data$condition <- as.character(all_data$condition)
  
} else {
  cat("1. Loading merged flat files...\n")
  cat("  (Waveform summaries not found; processing from flat files)\n")
  
  # Find flat files
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
}

# ============================================================================
# 2. CREATE BASELINE-CORRECTED PUPIL TRACE (if not using summaries)
# ============================================================================

if (!use_waveform_summaries) {
  cat("\n2. Creating baseline-corrected pupil traces...\n")
  
  # Calculate global baseline (B0) per trial: 500ms window before squeeze onset
  # Check if difficulty_level already exists
  has_difficulty_level <- "difficulty_level" %in% names(all_data)
  
  all_data <- dplyr::group_by(all_data, sub, task, run, trial_index)
  all_data <- dplyr::mutate(all_data,
      # Calculate baseline B0 from -0.5s to 0s (updated to match quick_share_v6)
      baseline_B0 = mean(pupil[time >= -0.5 & time < 0 & !is.na(pupil)], na.rm = TRUE),
      # Create isolated pupil trace (baseline-corrected using B0)
      pupil_isolated = pupil - baseline_B0,
      # Create difficulty_level from isOddball and stimLev (if not already present)
      difficulty_level = if(has_difficulty_level) {
        difficulty_level
      } else {
        factor(case_when(
          isOddball == 0 ~ "Standard",
          # Map based on actual stimLev values in data
          # Lower values = Hard (harder to detect), Higher values = Easy (easier to detect)
          isOddball == 1 & stimLev %in% c(1, 2, 8, 16, 0.06, 0.12) ~ "Hard",
          isOddball == 1 & stimLev %in% c(3, 4, 32, 64, 0.24, 0.48) ~ "Easy",
          TRUE ~ NA_character_
        ), levels = c("Standard", "Easy", "Hard"))
      },
      # Map force_condition or effort to Low/High
      effort_level = case_when(
        force_condition == "Low_Force_5pct" | effort == "Low" ~ "Low",
        force_condition == "High_Force_40pct" | effort == "High" ~ "High",
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
  
  # Count unique conditions
  all_data$condition <- as.character(all_data$condition)
  unique_conditions <- unique(all_data$condition[!is.na(all_data$condition) & all_data$condition != "Unknown"])
  n_conditions <- length(unique_conditions)
  cat("  Created baseline-corrected traces for", n_conditions, "conditions\n")
  if(n_conditions > 0) {
    cat("    Conditions:", paste(unique_conditions, collapse = ", "), "\n")
  }
} else {
  cat("\n2. Using pre-computed waveform summaries (baseline B0 already applied)\n")
}

# Calculate median response onset times per task
cat("\n3. Calculating median response onset times...\n")
if (!use_waveform_summaries && "resp1RT" %in% names(all_data)) {
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
} else {
  # Use fixed response window start (4.7s) if no RT data or using summaries
  response_onsets <- tibble(
    task = c("ADT", "VDT"),
    median_response_onset = c(4.7, 4.7)
  )
  cat("  Using fixed response onset: 4.7s (response window start)\n")
}

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
  if (use_waveform_summaries) {
    # Use pre-aggregated waveform data (mean_pupil_isolated already computed)
    # Note: quick_share_v7 doesn't include SE, so we'll use geom_smooth for confidence intervals
    waveform_summary <- task_data %>%
      select(condition, time_from_squeeze, mean_pupil_isolated) %>%
      distinct() %>%
      filter(!is.na(mean_pupil_isolated), !is.na(time_from_squeeze))
  } else {
    # Aggregate from sample-level data
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
  }
  
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
    # For ADT, use full range (min/max of confidence ribbons) to capture all fluctuations
    # For VDT, use quantile-based range (0.01 to 0.99) for cleaner visualization
    x_mask <- smoothed_df$x >= x_range[1] & smoothed_df$x <= x_range[2]
    if (task_name == "ADT") {
      y_min <- min(smoothed_df$ymin[x_mask], na.rm = TRUE)
      y_max <- max(smoothed_df$ymax[x_mask], na.rm = TRUE)
    } else {
      # VDT: use quantile-based range
      y_min <- quantile(smoothed_df$y[x_mask], 0.01, na.rm = TRUE)
      y_max <- quantile(smoothed_df$y[x_mask], 0.99, na.rm = TRUE)
    }
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
  
  # Calculate cognitive AUC window (extends into response window)
  # Based on MATLAB task code: Cognitive processing continues during response period
  # W2.0 window: target+0.3 to target+2.3 (4.65s to 6.65s) - commonly used
  # For visualization, use W2.0 as a reasonable cognitive window
  cognitive_start_plot <- config$target_onset + config$cognitive_auc_latency  # target+0.3s = 4.65s
  cognitive_end_plot <- config$target_onset + 2.3  # target+2.3s = 6.65s (W2.0 window)
  
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
  
  # Timeline bars (single Cognitive AUC ending at Response start)
  bar_positions <- tibble(
    label = c("Baseline", "Total AUC", "Cognitive AUC"),
    xstart = c(config$baseline_window_start, config$total_auc_start, 
               cognitive_start_plot),
    xend = c(config$baseline_window_end, response_onset_median, 
             cognitive_end_plot),
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
  
  # Event markers: Standard (1st stimulus), Target (2nd stimulus), Response
  event_markers_plot <- tibble(
    event = c("Standard", config$stimulus_label, config$response_label),
    time = c(config$standard_onset, config$target_onset, config$response_window_start)
  ) %>%
    filter(!is.na(time))
  
  # Stagger event labels vertically to avoid overlap
  n_events <- nrow(event_markers_plot)
  event_label_ys <- y_upper_limit - y_range_span * seq(0.005, 0.005 + (n_events - 1) * 0.025, length.out = n_events)
  event_markers_plot$label_y <- event_label_ys
  
  # Plotting range (extend into response window to show cognitive AUC)
  plot_start_time <- config$baseline_window_start
  plot_end_time <- min(cognitive_end_plot + 0.5, max(waveform_summary$time_from_squeeze, na.rm = TRUE))
  
  # Get conditions actually present in data
  conditions_present <- unique(waveform_summary$condition)
  conditions_present <- conditions_present[!is.na(conditions_present)]
  
  # Ensure condition is a factor with levels matching present conditions
  waveform_summary$condition <- factor(waveform_summary$condition, 
                                       levels = sort(conditions_present))
  
  # Create color mapping for present conditions only
  colors_for_plot <- condition_colors[names(condition_colors) %in% conditions_present]
  if (length(colors_for_plot) == 0) {
    # Fallback: use default colors if no matches
    colors_for_plot <- scales::hue_pal()(length(conditions_present))
    names(colors_for_plot) <- conditions_present
  }
  
  # Create plot
  plot_waveform <- ggplot(waveform_summary, 
                          aes(x = time_from_squeeze, y = mean_pupil_isolated, 
                              color = condition, fill = condition)) +
    # Smoothed lines with confidence intervals
    geom_smooth(method = "gam", formula = y ~ s(x, k = 30), 
                linewidth = 1.2, span = 0.2, se = TRUE, alpha = 0.3) +
    
    # Vertical markers for events (Standard, Target, Response)
    {if (nrow(event_markers_plot) > 0) 
      geom_vline(data = event_markers_plot, aes(xintercept = time), 
                 linetype = "dashed", color = "grey40", linewidth = 0.6)
    } +
    {if (nrow(event_markers_plot) > 0) 
      geom_text(data = event_markers_plot, aes(x = time, y = label_y, label = event), 
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
    
    scale_color_manual(values = colors_for_plot, name = "Condition", 
                       breaks = names(colors_for_plot),
                       guide = guide_legend(override.aes = list(fill = colors_for_plot))) +
    scale_fill_manual(values = colors_for_plot, name = "Condition",
                      breaks = names(colors_for_plot)) +
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

