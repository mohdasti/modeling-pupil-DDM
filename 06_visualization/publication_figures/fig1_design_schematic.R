# fig1_design_schematic.R
# Fig 1: Study design and DDM architecture
# Panel A: existing Trial_Structure.png | Panel B: fig_ddm_process logic | Panel C: predictor map

suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
  library(here)
  library(tibble)
  library(dplyr)
  library(grid)
  library(png)
})

source(here("R", "colors_manuscript.R"))

repo <- here::here()

# ── Shared theme ──────────────────────────────────────────────────────────────
theme_manuscript <- function() {
  theme_classic(base_size = 8, base_family = "Helvetica") +
    theme(
      axis.line         = element_line(linewidth = 0.35, color = "black"),
      axis.ticks        = element_line(linewidth = 0.3, color = "black"),
      axis.ticks.length = unit(2, "pt"),
      axis.text         = element_text(size = 6.5, color = "black"),
      axis.title        = element_text(size = 7.5, color = "black"),
      plot.title        = element_text(size = 9, face = "bold", color = "black",
                                       hjust = 0, margin = margin(b = 2)),
      panel.grid        = element_blank(),
      legend.position   = "none",
      plot.margin       = margin(3, 5, 3, 3, "pt"),
      plot.background   = element_rect(fill = "white", color = NA)
    )
}

theme_panel_tag <- function(tag) {
  theme(plot.title = element_text(size = 9, face = "bold", hjust = 0,
                                  margin = margin(l = 0, b = 1)))
}

# ── Helper: embed PNG preserving native aspect ratio (letterboxed, not stretched) ─
image_panel <- function(img_path, tag, bg = "white") {
  if (!file.exists(img_path)) {
    stop("Image not found: ", img_path)
  }
  img <- readPNG(img_path)
  img_w <- ncol(img)
  img_h <- nrow(img)
  asp   <- img_w / img_h

  ggplot() +
    annotate("rect", xmin = 0, xmax = asp, ymin = 0, ymax = 1, fill = bg, color = NA) +
    annotation_custom(
      rasterGrob(img, interpolate = TRUE),
      xmin = 0, xmax = asp, ymin = 0, ymax = 1
    ) +
    coord_fixed(ratio = asp, xlim = c(0, asp), ylim = c(0, 1), clip = "off", expand = FALSE) +
    labs(title = tag) +
    theme_void() +
    theme_panel_tag(tag) +
    theme(plot.margin = margin(2, 3, 2, 3, "pt"))
}

# ── Panel A: reuse published trial-structure schematic ────────────────────────
trial_img <- file.path(repo, "output", "figures", "Trial_Structure.png")
if (!file.exists(trial_img)) {
  trial_img <- file.path(repo, "output", "figures", "manuscript_palette", "Trial_Structure.png")
}
panel_a <- image_panel(trial_img, "A")


# ── Panel B: DDM schematic (adapted from scripts/R/fig_ddm_process.R) ─────────
build_ddm_panel <- function() {
  a   <- 1.5
  z   <- 0.6
  v   <- 0.8
  ndt <- 0.25

  set.seed(123)
  dt <- 0.005
  max_time <- 2
  time_points <- seq(0, max_time, by = dt)
  evidence <- numeric(length(time_points))
  evidence[1] <- z * a

  hit_index <- NA
  hit_boundary <- NA

  for (i in 2:length(time_points)) {
    new_evidence <- evidence[i - 1] + v * dt + rnorm(1, 0, sqrt(dt))
    if (new_evidence >= a && evidence[i - 1] < a) {
      fraction <- (a - evidence[i - 1]) / (new_evidence - evidence[i - 1])
      hit_index <- i - 1 + fraction
      hit_boundary <- a
      break
    }
    if (new_evidence <= 0 && evidence[i - 1] > 0) {
      fraction <- (0 - evidence[i - 1]) / (new_evidence - evidence[i - 1])
      hit_index <- i - 1 + fraction
      hit_boundary <- 0
      break
    }
    evidence[i] <- new_evidence
  }

  if (!is.na(hit_index)) {
    last_safe_index <- floor(hit_index)
    if (last_safe_index > 0) {
      evidence <- evidence[seq_len(last_safe_index)]
      time_points <- time_points[seq_len(last_safe_index)]
      exact_time <- time_points[length(time_points)] + (hit_index - last_safe_index) * dt
      time_points <- c(time_points, exact_time)
      evidence <- c(evidence, hit_boundary)
    }
    decision_time <- exact_time
  } else {
    decision_time <- time_points[length(time_points)]
  }

  total_rt <- ndt + decision_time
  plot_time <- time_points + ndt
  plot_evidence <- evidence

  arrow_start_x <- ndt + 0.18
  arrow_end_x   <- ndt + 0.32
  arrow_mid_x   <- (arrow_start_x + arrow_end_x) / 2
  arrow_start_y <- z * a + 0.04
  arrow_end_y   <- z * a + 0.18
  arrow_mid_y   <- (arrow_start_y + arrow_end_y) / 2

  label_x <- max(total_rt + 0.04, 0.68)

  ggplot() +
    annotate("rect", xmin = 0, xmax = ndt, ymin = -0.08, ymax = a + 0.12,
             fill = unname(param_colors["t0"]), alpha = 0.10, color = NA) +
    annotate("text", x = ndt / 2, y = 0.35,
             label = "t\u2080", size = 2.4,
             color = unname(param_colors["t0"]), fontface = "italic") +
    geom_hline(yintercept = a, linewidth = 0.7, color = unname(param_colors["a"])) +
    annotate("text", x = label_x, y = a + 0.02, label = '"Different"',
             size = 2.2, color = unname(param_colors["a"]), fontface = "bold", hjust = 0, vjust = 0) +
    geom_hline(yintercept = 0, linewidth = 0.7, color = "#4A5568") +
    annotate("text", x = label_x, y = -0.03, label = '"Same"',
             size = 2.4, color = "#4A5568", fontface = "bold", hjust = 0, vjust = 1) +
    geom_line(
      data = data.frame(time = plot_time, evidence = plot_evidence),
      aes(x = time, y = evidence),
      linewidth = 0.6, color = unname(stat_colors["empirical"])
    ) +
    geom_point(aes(x = ndt, y = z * a), size = 2.2,
               color = unname(param_colors["z"]), fill = "white", stroke = 1.2, shape = 21) +
    annotate("segment", x = ndt, xend = ndt, y = 0, yend = z * a,
             linetype = "dashed", linewidth = 0.4, color = unname(param_colors["z"]), alpha = 0.7) +
    annotate("text", x = ndt - 0.04, y = z * a,
             label = "z", size = 2.4, color = unname(param_colors["z"]),
             fontface = "bold", hjust = 1, vjust = 0.5) +
    annotate("segment",
             x = arrow_start_x, xend = arrow_end_x,
             y = arrow_start_y, yend = arrow_end_y,
             arrow = arrow(length = unit(2.5, "pt"), type = "closed"),
             linewidth = 0.5, color = unname(param_colors["v"])) +
    annotate("text", x = arrow_end_x + 0.06, y = arrow_end_y + 0.02,
             label = "v", size = 2.6, color = unname(param_colors["v"]),
             fontface = "italic", hjust = 0, vjust = 0) +
    geom_vline(xintercept = total_rt, linetype = "dashed", linewidth = 0.4,
               color = unname(param_colors["t0"]), alpha = 0.6) +
    annotate("segment", x = 0, xend = 0, y = -0.08, yend = -0.12, linewidth = 0.35) +
    annotate("text", x = 0, y = -0.16, label = "0", size = 2.1, hjust = 0.5, vjust = 0) +
    annotate("segment", x = ndt, xend = ndt, y = -0.08, yend = -0.12, linewidth = 0.35) +
    annotate("text", x = ndt, y = -0.16,
             label = sprintf("t\u2080\n(%.2fs)", ndt), size = 2.0, hjust = 0.5, vjust = 0) +
    labs(title = "B", x = "Time (s)", y = "Evidence") +
    scale_x_continuous(limits = c(-0.02, 1.15), expand = c(0, 0),
                       breaks = seq(0, 1, by = 0.5)) +
    scale_y_continuous(limits = c(-0.20, a + 0.12), expand = c(0, 0),
                       breaks = seq(0, 1.5, by = 0.5)) +
    theme_manuscript() +
    theme(
      axis.title.x = element_text(margin = margin(t = 3)),
      axis.title.y = element_text(margin = margin(r = 3)),
      plot.margin = margin(3, 4, 3, 3, "pt")
    )
}

panel_b <- build_ddm_panel()


# ── Panel C: predictor map (matrix.png content, compact manuscript styling) ───
param_ids <- c("v", "a", "t0", "z")
param_cols <- unname(param_colors[param_ids])
names(param_cols) <- param_ids

predictors_short <- c("Difficulty", "Task", "Effort")

# Cell notes transcribed from matrix.png (not embedded as image)
grid_df <- tidyr::crossing(
  predictor = predictors_short,
  param = param_ids
) %>%
  mutate(
    param_idx = match(param, param_ids),
    pred_idx  = match(predictor, predictors_short),
    cell_type = case_when(
      predictor == "Difficulty" & param %in% c("v", "a")              ~ "check",
      predictor == "Difficulty" & param == "z"                        ~ "exclude",
      predictor == "Task"       & param %in% c("v", "a", "z")         ~ "check",
      predictor == "Effort"     & param %in% c("v", "z")              ~ "check",
      TRUE                                                            ~ "dash"
    ),
    note = case_when(
      predictor == "Difficulty" & param == "v"  ~ "evidence\nstrength",
      predictor == "Difficulty" & param == "a"  ~ "caution /\nthreshold",
      predictor == "Task"       & param == "v"  ~ "modality\nshift",
      predictor == "Task"       & param == "a"  ~ "modality\nshift",
      predictor == "Task"       & param == "z"  ~ "pre-\nstimulus",
      predictor == "Effort"     & param == "v"  ~ "dual-task\ndemand",
      predictor == "Effort"     & param == "z"  ~ "pre-\nstimulus",
      TRUE ~ ""
    ),
    tile_fill = if_else(cell_type == "exclude", "#FFF7ED", "white"),
    text_color = case_when(
      cell_type == "check"   ~ param,
      cell_type == "exclude" ~ "exclude",
      TRUE                   ~ "dash"
    ),
    cell_text = case_when(
      cell_type == "check"   ~ paste0("\u2713\n", note),
      cell_type == "exclude" ~ "\u2717\nExcluded*",
      TRUE                   ~ "\u2014"
    )
  )

header_df <- tibble(
  param_idx = seq_along(param_ids),
  label = c("Drift (v)", "Boundary (a)", "NDT (t\u2080)", "Bias (z)")
)

panel_c <- ggplot(grid_df, aes(x = param_idx, y = pred_idx)) +
  geom_tile(aes(fill = tile_fill), color = "#D1D5DB", linewidth = 0.35) +
  scale_fill_identity() +
  geom_text(
    aes(label = cell_text, color = text_color),
    size = 2.05, lineheight = 0.78, fontface = "bold"
  ) +
  geom_text(
    data = header_df,
    aes(x = param_idx, y = 0.44, label = label),
    inherit.aes = FALSE,
    color = unname(param_cols[header_df$param_idx]),
    size = 2.1, fontface = "bold", vjust = 0
  ) +
  scale_color_manual(
    values = c(param_cols, dash = "#9CA3AF", exclude = "#B45309"),
    guide = "none"
  ) +
  scale_x_continuous(limits = c(0.5, 4.5), expand = c(0, 0)) +
  scale_y_reverse(
    breaks = seq_along(predictors_short),
    labels = predictors_short,
    # Tiles at y = 1:3 span ±0.5 → Effort row needs ylim ≥ 3.5
    limits = c(3.52, 0.22),
    expand = c(0, 0)
  ) +
  labs(
    title = "C", x = NULL, y = NULL,
    caption = "*z excludes difficulty (pre-trial randomization). t\u2080 intercept-only."
  ) +
  theme_manuscript() +
  theme(
    axis.line   = element_blank(),
    axis.ticks  = element_blank(),
    axis.text.x = element_blank(),
    axis.text.y = element_text(size = 6.5, color = "black", face = "bold"),
    plot.caption = element_text(
      size = 4.8, color = "#6B7280", hjust = 0, lineheight = 0.95,
      margin = margin(t = 3)
    ),
    plot.margin = margin(2, 3, 6, 3, "pt")
  )


# ── Combine ───────────────────────────────────────────────────────────────────
# Panel A image is ~0.92 w/h; match composite aspect so it is not squeezed
fig1 <- panel_a + panel_b + panel_c +
  plot_layout(widths = c(2.55, 1.2, 1.55)) +
  plot_annotation(theme = theme(plot.margin = margin(2, 2, 2, 2, "pt")))

out_dir <- here("output", "figures", "manuscript")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

fig_w_mm <- 180
fig_h_mm <- 86

ggsave(
  filename = file.path(out_dir, "fig1_design_schematic.pdf"),
  plot = fig1, width = fig_w_mm, height = fig_h_mm, units = "mm", device = cairo_pdf
)
ggsave(
  filename = file.path(out_dir, "fig1_design_schematic.png"),
  plot = fig1, width = fig_w_mm, height = fig_h_mm, units = "mm", dpi = 300
)

message("Fig 1 saved (Panel A: Trial_Structure.png; B: DDM schematic; C: predictor map).")
