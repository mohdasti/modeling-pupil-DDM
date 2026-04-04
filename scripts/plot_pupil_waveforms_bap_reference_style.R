#!/usr/bin/env Rscript
# BAP Pupil Waveform Plots – ADT + VDT, reference style (mirrors LCYA figure)
#
# Key BAP experiment timing (from make_quick_share_v7.R constants):
#   B0 window     : −0.5 to 0 s  (pre-trial baseline, before squeeze)
#   S1 onset      : 3.75 s        (standard / first stimulus)
#   B1 window     : 3.85 to 4.35 s (pre-target baseline, = target + B1_WIN)
#   S2/Target     : 4.35 s        (TARGET_ONSET_DEFAULT)
#   Resp signal   : 4.70 s        (RESP_START_DEFAULT — when participants CAN respond)
#   Total AUC     : 0 → 4.70 s   (squeeze onset to response signal)
#   Cognitive AUC : 4.85 → 6.05 s (target + 0.50 s to target + 1.70 s, fixed 1.20 s window)
#                                  COG_WIN_PRIMARY_START = 0.50, COG_WIN_PRIMARY_END = 1.70
#
# Convergence: a secondary aggregate-level B0 correction is applied so that all
# four condition traces converge to 0 at the squeeze onset.  The individual-trial
# B0 correction in make_quick_share_v7.R already does this per trial; the aggregate
# correction removes residual sampling variance so the convergence is visible in the plot.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(patchwork)
  library(here)
})

repo_root     <- here::here()
waveform_path <- file.path(repo_root, "data/pupil_processed/analysis/pupil_waveforms_condition_mean.csv")
trial_path    <- file.path(repo_root, "data/pupil_processed/analysis_ready/ch3_triallevel.csv")
output_dir    <- file.path(repo_root, "06_visualization", "publication_figures")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_file   <- file.path(output_dir, "Figure_Pupil_Waveforms_ADT_VDT_reference_style.png")

# ── BAP experiment constants (from make_quick_share_v7.R) ────────────────────
TARGET_ONSET      <- 4.35   # S2/Target/Probe onset
S1_ONSET          <- 3.75   # S1/Standard onset
RESP_START        <- 4.70   # Response signal onset (RESP_START_DEFAULT)
B0_WIN            <- c(-0.5, 0.0)   # Pre-trial baseline window
B1_WIN_START      <- TARGET_ONSET + (-0.5)   # = 3.85 s
B1_WIN_END        <- TARGET_ONSET + 0.0      # = 4.35 s
COG_START         <- TARGET_ONSET + 0.50     # = 4.85 s (COG_WIN_PRIMARY_START)
COG_END           <- TARGET_ONSET + 1.70     # = 6.05 s (COG_WIN_PRIMARY_END)

# ── Color scheme ─────────────────────────────────────────────────────────────
condition_colors <- c(
  "Easy / Low"  = "#5DADE2",
  "Easy / High" = "#2E86AB",
  "Hard / Low"  = "#EC70AB",
  "Hard / High" = "#A23B72"
)

timeline_bar_colors <- list(
  baseline      = "#7F8C8D",
  total_auc     = "#1F78B4",
  cognitive_auc = "#D95F02"
)

stopifnot(file.exists(waveform_path), file.exists(trial_path))

# ── Load data ─────────────────────────────────────────────────────────────────
waveform_data <- read_csv(waveform_path, show_col_types = FALSE)
trials        <- read_csv(trial_path,    show_col_types = FALSE)

# ── Empirical median response time per task (Easy / Hard trials only) ─────────
timing <- trials %>%
  filter(!(stimulus_intensity == 0 & isOddball == 0)) %>%
  filter(stimulus_intensity %in% 1:4 | (isOddball == 1L & !is.na(stimulus_intensity))) %>%
  group_by(task) %>%
  summarise(
    med_target = median(t_target_onset_rel, na.rm = TRUE),
    med_resp   = median(t_resp_actual,      na.rm = TRUE),
    .groups = "drop"
  )

# ── Prepare condition-level waveform data ─────────────────────────────────────
wf <- waveform_data %>%
  filter(chapter == "ch3") %>%
  mutate(
    difficulty_level = case_when(
      isOddball == 0 | (is.na(isOddball) & !is.na(stimulus_intensity) & stimulus_intensity == 0) ~ "Standard",
      !is.na(stimulus_intensity) & stimulus_intensity %in% c(1, 2) ~ "Hard",
      !is.na(stimulus_intensity) & stimulus_intensity %in% c(3, 4) ~ "Easy",
      isOddball == 1 & is.na(stimulus_intensity)                    ~ "Easy",
      TRUE ~ NA_character_
    ),
    effort_level = case_when(
      effort %in% c("Low",  "Low_Force_5pct")  ~ "Low",
      effort %in% c("High", "High_Force_40pct") ~ "High",
      TRUE ~ NA_character_
    ),
    condition = case_when(
      !is.na(difficulty_level) & !is.na(effort_level) ~
        paste0(difficulty_level, " / ", effort_level),
      TRUE ~ "Unknown"
    )
  ) %>%
  filter(condition != "Unknown", !grepl("Standard", condition)) %>%
  group_by(task, condition, t_rel) %>%
  summarise(
    total_trials        = sum(n_trials, na.rm = TRUE),
    mean_pupil_isolated = sum(mean_pupil_full * n_trials, na.rm = TRUE) / total_trials,
    .groups = "drop"
  ) %>%
  filter(task %in% c("ADT", "VDT"))

if (nrow(wf) == 0) stop("No waveform rows after filtering.")

# ── Downsample to 50 Hz (every 0.02 s grid) for smooth visualisation ─────────
wf <- wf %>%
  mutate(t_rel_50 = round(t_rel * 50) / 50) %>%
  group_by(task, condition, t_rel_50) %>%
  summarise(mean_pupil_isolated = mean(mean_pupil_isolated, na.rm = TRUE), .groups = "drop") %>%
  rename(t_rel = t_rel_50)

# ── Secondary aggregate-level B0 correction for perfect convergence at t = 0 ─
# Each condition's baseline window is subtracted so all four traces start at 0.
# This removes residual sampling variance left after the per-trial correction.
wf <- wf %>%
  group_by(task, condition) %>%
  mutate(
    cond_b0 = mean(mean_pupil_isolated[t_rel >= B0_WIN[1] & t_rel < B0_WIN[2]], na.rm = TRUE),
    mean_pupil_isolated = mean_pupil_isolated - cond_b0
  ) %>%
  ungroup() %>%
  select(-cond_b0)

# ── Plotting function ─────────────────────────────────────────────────────────
plot_task <- function(task_name) {
  w <- filter(wf, task == task_name)

  tg <- timing$med_target[timing$task == task_name]
  tr <- timing$med_resp[timing$task == task_name]
  if (length(tg) != 1L || !is.finite(tg)) tg <- TARGET_ONSET
  if (length(tr) != 1L || !is.finite(tr)) tr <- RESP_START + 0.8

  conds      <- sort(unique(w$condition))
  w$condition <- factor(w$condition, levels = conds)
  colors_use  <- condition_colors[names(condition_colors) %in% conds]
  if (length(colors_use) == 0) colors_use <- setNames(scales::hue_pal()(length(conds)), conds)

  # x-axis extends to show full Cognitive AUC window (6.05 s) + small buffer
  x_end <- max(COG_END + 0.15, tr + 0.15)

  # ── Dynamic y-limits from GAM smooths ──────────────────────────────────────
  x_range     <- c(B0_WIN[1], x_end)
  smoothed_df <- suppressWarnings(tryCatch({
    ggplot_build(
      ggplot(w, aes(x = t_rel, y = mean_pupil_isolated, color = condition)) +
        geom_smooth(se = TRUE, method = "gam", formula = y ~ s(x, k = 12))
    )$data[[1]] %>% tibble::as_tibble()
  }, error = function(e) NULL))

  in_range <- if (!is.null(smoothed_df) && nrow(smoothed_df) > 0)
    smoothed_df$x >= x_range[1] & smoothed_df$x <= x_range[2] else logical(0)

  y_limits <- if (length(in_range) > 0 && any(in_range)) {
    c(quantile(smoothed_df$ymin[in_range], 0.01, na.rm = TRUE),
      quantile(smoothed_df$ymax[in_range], 0.99, na.rm = TRUE))
  } else {
    range(w$mean_pupil_isolated, na.rm = TRUE)
  }
  if (any(!is.finite(y_limits))) y_limits <- range(w$mean_pupil_isolated, na.rm = TRUE)
  if (any(!is.finite(y_limits)) || diff(y_limits) == 0) y_limits <- c(-1, 1)

  y_range_span  <- diff(y_limits)
  extra_margin  <- y_range_span * 0.30
  # Extra room below so the bottom (B0) bar can sit a little lower without clipping
  b0_vertical_drop <- y_range_span * 0.045
  y_lower_limit <- y_limits[1] - extra_margin * 2.0 - b0_vertical_drop
  y_upper_limit <- y_limits[2]

  # ── Event markers (dashed vertical lines + labels inside plot) ────────────
  # BAP trial structure: Squeeze → S1 (3.75) → S2/Target (4.35) → Resp signal (4.70) → Response
  event_label_y <- y_upper_limit - y_range_span * 0.005

  primary_events <- tibble::tibble(
    event    = c("Squeeze", "S2/Target onset", paste0("Response\n(median = ", round(tr, 2), "s)")),
    time     = c(0, tg, tr),
    label_x  = c(0, tg, tr - 0.12),
    hjust_val = c(0.5, 0.5, 1.0),
    lw       = c(0.6, 0.6, 0.6)
  )

  # S1 shown as a lighter secondary marker
  s1_event <- tibble::tibble(
    event = "S1 onset\n(3.75s)",
    time  = S1_ONSET,
    label_x  = S1_ONSET,
    hjust_val = 0.5,
    lw   = 0.4
  )

  # ── Timeline bars (BAP actual analysis windows) ───────────────────────────
  # Pre-trial Baseline B0: -0.5 to 0
  # Total AUC: 0 to 4.70 (RESP_START_DEFAULT — fixed window, not actual RT)
  # Pre-stimulus Baseline B1: 3.85 to 4.35 (B1_WIN relative to target)
  # Cognitive AUC (primary): 4.85 to 6.05 (COG_WIN_PRIMARY)
  bar_positions <- tibble::tibble(
    label  = c("Pre-trial Baseline (B0)", "Total AUC (0 → 4.70s)", "Pre-stim Baseline (B1)", "Cognitive AUC (4.85 → 6.05s)"),
    xstart = c(B0_WIN[1],  0,        B1_WIN_START, COG_START),
    xend   = c(B0_WIN[2],  RESP_START, B1_WIN_END,  COG_END),
    color  = c(
      timeline_bar_colors$baseline,
      timeline_bar_colors$total_auc,
      timeline_bar_colors$baseline,
      timeline_bar_colors$cognitive_auc
    )
  )
  bar_spacing <- extra_margin / (nrow(bar_positions) + 1)
  bar_positions <- bar_positions %>%
    mutate(
      row_idx = seq_len(n()),
      y       = y_lower_limit + bar_spacing * row_idx,
      text_y  = y + bar_spacing * 1.2,
      x_label = (xstart + xend) / 2
    ) %>%
    # Nudge only Pre-trial Baseline (B0) + its label slightly lower (toward panel bottom)
    mutate(
      y      = if_else(row_idx == 1L, y - b0_vertical_drop, y),
      text_y = if_else(row_idx == 1L, text_y - b0_vertical_drop, text_y)
    ) %>%
    select(-row_idx)

  # ── Build plot ─────────────────────────────────────────────────────────────
  ggplot(w, aes(x = t_rel, y = mean_pupil_isolated, color = condition, fill = condition)) +

    # S1 secondary marker (lighter, behind primary markers)
    geom_vline(
      data = s1_event, aes(xintercept = time),
      inherit.aes = FALSE, linetype = "dashed", color = "grey65", linewidth = 0.4
    ) +
    geom_text(
      data = s1_event,
      aes(x = label_x, y = event_label_y - y_range_span * 0.08, label = event, hjust = hjust_val),
      inherit.aes = FALSE, size = 3.2, color = "grey55", vjust = 1.1, fontface = "italic"
    ) +

    # Primary event lines
    geom_vline(
      data = primary_events, aes(xintercept = time),
      inherit.aes = FALSE, linetype = "dashed", color = "grey40", linewidth = 0.6
    ) +
    geom_text(
      data = primary_events,
      aes(x = label_x, y = event_label_y, label = event, hjust = hjust_val),
      inherit.aes = FALSE, size = 4.0, color = "grey20", vjust = 1.1, fontface = "bold"
    ) +

    # Smoothed waveforms with ribbons
    geom_smooth(method = "gam", formula = y ~ s(x, k = 12),
                linewidth = 1.2, se = TRUE, alpha = 0.25) +

    # Reference line at 0 (baseline level)
    geom_hline(yintercept = 0, linetype = "solid", color = "grey70", linewidth = 0.35) +

    # Timeline bars
    geom_segment(
      data = bar_positions,
      aes(x = xstart, xend = xend, y = y, yend = y, color = I(color)),
      inherit.aes = FALSE, linewidth = 2.2, lineend = "round"
    ) +
    geom_text(
      data = bar_positions,
      aes(x = x_label, y = text_y, label = label, color = I(color)),
      inherit.aes = FALSE, size = 3.3, fontface = "bold"
    ) +

    scale_color_manual(values = colors_use, name = "Condition") +
    scale_fill_manual( values = colors_use, name = "Condition") +
    scale_x_continuous(breaks = seq(0, ceiling(x_end), by = 1)) +
    coord_cartesian(
      xlim = c(B0_WIN[1], x_end),
      ylim = c(y_lower_limit, y_upper_limit)
    ) +
    labs(
      title    = paste0(task_name, ": Full Trial Pupil Waveform Time-Locked to Squeeze Onset"),
      subtitle = sprintf(
        "Baseline (B0): %.1fs to %.1fs, S2/Probe Onset (Median): %.2fs, Response Onset (Median): %.2fs",
        B0_WIN[1], B0_WIN[2], tg, tr
      ),
      x     = if (task_name == "VDT") "Time Relative to Squeeze Onset (seconds)" else NULL,
      y     = "Isolated Pupil (arbitrary units)",
      color = "Condition",
      fill  = "Condition"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      text             = element_text(size = 12),
      plot.title       = element_text(size = 13, face = "bold"),
      plot.subtitle    = element_text(size = 10, color = "grey30"),
      axis.title       = element_text(size = 14, face = "bold"),
      axis.text        = element_text(size = 12),
      legend.position  = "bottom",
      legend.box       = "horizontal",
      legend.title     = element_text(size = 14, face = "bold"),
      legend.text      = element_text(size = 12),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "grey90", linewidth = 0.3),
      plot.margin      = margin(12, 20, 32, 16)
    )
}

# ── Combine and save ──────────────────────────────────────────────────────────
p_adt <- plot_task("ADT")
p_vdt <- plot_task("VDT")

combined <- (p_adt / p_vdt) +
  plot_layout(guides = "collect") &
  theme(
    legend.position  = "bottom",
    legend.direction = "horizontal",
    panel.spacing    = grid::unit(2.4, "lines")
  )

ggsave(output_file, combined, width = 12, height = 15, dpi = 300)
message("Saved: ", output_file)
