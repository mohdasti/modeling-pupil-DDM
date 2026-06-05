# fig3_parameter_forest.R
# NHB Fig 3: Integrated parameter forest
# Panel A: effort contrasts H1–H4
# Panel B: difficulty contrasts on v and a

suppressPackageStartupMessages({
  library(brms)
  library(tidybayes)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(patchwork)
  library(purrr)
  library(here)
})

source(here("R", "colors_manuscript.R"))
source(here("06_visualization", "publication_figures", "nhb_paths.R"))

fit_primary <- readRDS(PATH_PRIMARY_MODEL)
draws_raw  <- as_draws_df(fit_primary)

theme_nhb <- function() {
  theme_classic(base_size = 8, base_family = "Helvetica") +
    theme(
      axis.line          = element_line(linewidth = 0.4),
      axis.ticks         = element_line(linewidth = 0.3),
      axis.ticks.length  = unit(2, "pt"),
      axis.text          = element_text(size = 7, color = "black"),
      axis.title         = element_text(size = 8),
      plot.title         = element_text(size = 8, face = "bold"),
      panel.grid.major.x = element_line(color = "#F3F4F6", linewidth = 0.3),
      panel.grid.major.y = element_blank(),
      plot.margin        = margin(4, 4, 4, 4, "pt"),
      strip.text         = element_text(size = 7, color = "black"),
      strip.background   = element_blank()
    )
}

label_color <- unname(stat_colors["empirical"])
# Filled = 95% CrI excludes 0; open = CrI spans 0 (see legend in Panel A)
pt_size    <- 1.35
pt_stroke  <- 0.45
cri_linewidth <- 0.65

# ── Panel A: Effort contrasts (H1, H2, H4) ─────────────────────────────────
effort_contrasts <- tibble(
  hypothesis = c("H1: drift (v)", "H2: boundary (a)", "H4: bias (z)"),
  param      = c("v", "a", "z"),
  coef_col   = c(
    "b_effort_conditionhigh",
    "b_bs_effort_conditionhigh",
    "b_bias_effort_conditionhigh"
  ),
  link_label = c("identity scale", "log scale", "logit scale")
)

contrast_df <- pmap_dfr(effort_contrasts, function(hypothesis, param, coef_col, link_label) {
  draws <- draws_raw[[coef_col]]
  tibble(
    hypothesis = hypothesis,
    param      = param,
    link_label = link_label,
    median     = median(draws),
    lo95       = quantile(draws, 0.025),
    hi95       = quantile(draws, 0.975),
    excludes0  = sign(lo95) == sign(hi95)
  )
})

contrast_df <- contrast_df %>%
  mutate(
    param_color = unname(param_colors[param]),
    y_pos       = 3:1
  )

panel_a <- ggplot(contrast_df) +
  geom_vline(xintercept = 0, color = stat_colors["zero_line"],
             linewidth = 0.5, linetype = "dashed") +
  geom_segment(aes(x = lo95, xend = hi95, y = y_pos, yend = y_pos, color = param_color),
               linewidth = cri_linewidth, lineend = "round") +
  scale_color_identity() +
  geom_point(
    aes(x = median, y = y_pos,
        fill  = if_else(excludes0, param_color, "white"),
        color = param_color),
    shape = 21, size = pt_size, stroke = pt_stroke
  ) +
  scale_fill_identity() +
  geom_text(
    aes(x = lo95, y = y_pos, label = hypothesis),
    size = 2.2, hjust = 1.1, color = label_color,
    nudge_x = -0.008
  ) +
  geom_text(
    aes(x = hi95, y = y_pos,
        label = sprintf("%.3f [%.3f, %.3f]", median, lo95, hi95)),
    size = 2.0, hjust = -0.05, color = label_color
  ) +
  annotate(
    "text",
    x = min(contrast_df$lo95) - 0.02, y = 0.25,
    label = "\u25cf CrI excludes 0    \u25cb CrI spans 0",
    size = 1.8, hjust = 0, color = label_color
  ) +
  scale_y_continuous(breaks = NULL, limits = c(0, 3.6)) +
  labs(
    title = "A \u2014 Effort contrasts (High \u2212 Low)",
    x = "Posterior estimate",
    y = NULL
  ) +
  coord_cartesian(
    xlim = c(min(contrast_df$lo95) - 0.12, max(contrast_df$hi95) + 0.08),
    clip = "off"
  ) +
  theme_nhb() +
  theme(axis.line.y = element_blank())

# ── Panel B: Difficulty contrasts on v and a ─────────────────────────────────
diff_contrasts <- bind_rows(
  tibble(
    contrast = c("Easy vs Standard", "Hard vs Standard", "Easy vs Hard"),
    param    = "v",
    draws    = list(
      draws_raw$b_difficulty_3Easy,
      draws_raw$b_difficulty_3Hard,
      draws_raw$b_difficulty_3Easy - draws_raw$b_difficulty_3Hard
    )
  ),
  tibble(
    contrast = c("Easy vs Standard", "Hard vs Standard", "Easy vs Hard"),
    param    = "a",
    draws    = list(
      draws_raw$b_bs_difficulty_3Easy,
      draws_raw$b_bs_difficulty_3Hard,
      draws_raw$b_bs_difficulty_3Easy - draws_raw$b_bs_difficulty_3Hard
    )
  )
) %>%
  mutate(
    median    = map_dbl(draws, median),
    lo95      = map_dbl(draws, ~ quantile(.x, 0.025)),
    hi95      = map_dbl(draws, ~ quantile(.x, 0.975)),
    excludes0 = sign(lo95) == sign(hi95),
    param_color = unname(param_colors[param]),
    param_label = recode(param, v = "Drift rate (v)", a = "Boundary (a)"),
    contrast    = factor(contrast, levels = c("Easy vs Standard", "Hard vs Standard", "Easy vs Hard")),
    y_pos       = as.numeric(contrast)
  )

panel_b <- ggplot(diff_contrasts) +
  geom_vline(xintercept = 0, color = stat_colors["zero_line"],
             linewidth = 0.5, linetype = "dashed") +
  geom_segment(aes(x = lo95, xend = hi95, y = y_pos, yend = y_pos, color = param_color),
               linewidth = cri_linewidth, lineend = "round") +
  scale_color_identity() +
  geom_point(
    aes(x = median, y = y_pos,
        fill  = if_else(excludes0, param_color, "white"),
        color = param_color),
    shape = 21, size = pt_size, stroke = pt_stroke
  ) +
  scale_fill_identity() +
  scale_y_continuous(breaks = 1:3, labels = levels(diff_contrasts$contrast)) +
  facet_wrap(~ param_label, scales = "free_x", nrow = 1) +
  labs(
    title = "B \u2014 Difficulty contrasts",
    x = "Posterior estimate",
    y = NULL
  ) +
  theme_nhb()

# ── Combine & save ───────────────────────────────────────────────────────────
fig3 <- panel_a / panel_b + plot_layout(heights = c(1, 1.2))

dir.create(PATH_FIG_OUT, recursive = TRUE, showWarnings = FALSE)

ggsave(
  file.path(PATH_FIG_OUT, "fig3_parameter_forest.pdf"),
  fig3, width = 180, height = 90, units = "mm", device = cairo_pdf
)
ggsave(
  file.path(PATH_FIG_OUT, "fig3_parameter_forest.png"),
  fig3, width = 180, height = 90, units = "mm", dpi = 300
)

message("Fig 3 saved.")
