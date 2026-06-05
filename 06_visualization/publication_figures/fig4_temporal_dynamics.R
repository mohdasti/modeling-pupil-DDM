# fig4_temporal_dynamics.R
# NHB Fig 4: Temporal dynamics (fatigue + choice history)
# Panel A: boundary trajectories | Panel B: focal fatigue forest | Panel C: choice history

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

fit_fatigue <- readRDS(PATH_FATIGUE_MODEL)
fit_history <- readRDS(PATH_HISTORY_MODEL)
fit_wsls    <- readRDS(PATH_WSLS_MODEL)

draws_fat  <- as_draws_df(fit_fatigue)
draws_hist <- as_draws_df(fit_history)
draws_wsls <- as_draws_df(fit_wsls)

label_color <- unname(stat_colors["empirical"])
pt_size     <- 1.35
pt_stroke   <- 0.45
cri_linewidth <- 0.65

fatigue_effort_colors <- c(
  "Low effort (5% MVC)"  = unname(effort_colors["Low"]),
  "High effort (40% MVC)" = unname(effort_colors["High"])
)

theme_nhb <- function() {
  theme_classic(base_size = 8, base_family = "Helvetica") +
    theme(
      axis.line          = element_line(linewidth = 0.4),
      axis.ticks         = element_line(linewidth = 0.3),
      axis.ticks.length  = unit(2, "pt"),
      axis.text          = element_text(size = 7, color = "black"),
      axis.title         = element_text(size = 8),
      plot.title         = element_text(size = 8, face = "bold"),
      legend.text        = element_text(size = 7),
      panel.grid         = element_blank(),
      plot.margin        = margin(4, 4, 4, 4, "pt"),
      strip.text         = element_text(size = 7, color = "black"),
      strip.background   = element_blank()
    )
}

# ── Panel A: Boundary trajectories (population-level) ───────────────────────
bs_int  <- draws_fat[["Intercept_bs"]]
bs_bh   <- draws_fat[["b_bs_block_halfSecond_Half"]]
bs_eff  <- draws_fat[["b_bs_effort_conditionHigh_40_MVC"]]
bs_intx <- draws_fat[["b_bs_effort_conditionHigh_40_MVC:block_halfSecond_Half"]]

traj_df <- tibble(
  cell = c(
    "Low effort 1st half", "Low effort 2nd half",
    "High effort 1st half", "High effort 2nd half"
  ),
  boundary = list(
    exp(bs_int),
    exp(bs_int + bs_bh),
    exp(bs_int + bs_eff),
    exp(bs_int + bs_eff + bs_bh + bs_intx)
  )
) %>%
  mutate(
    effort = if_else(grepl("High", cell), "High effort (40% MVC)", "Low effort (5% MVC)"),
    half   = factor(
      if_else(grepl("1st", cell), "1st half", "2nd half"),
      levels = c("1st half", "2nd half")
    )
  ) %>%
  rowwise() %>%
  mutate(
    a_median = median(unlist(boundary)),
    a_lo95   = quantile(unlist(boundary), 0.025),
    a_hi95   = quantile(unlist(boundary), 0.975)
  ) %>%
  ungroup() %>%
  select(-boundary, -cell)

panel_a <- ggplot(traj_df, aes(x = half, y = a_median, color = effort, group = effort)) +
  geom_ribbon(aes(ymin = a_lo95, ymax = a_hi95, fill = effort),
              alpha = 0.15, color = NA) +
  geom_line(linewidth = 0.7) +
  geom_errorbar(aes(ymin = a_lo95, ymax = a_hi95), width = 0.08, linewidth = cri_linewidth) +
  geom_point(size = pt_size + 0.3) +
  scale_color_manual(values = fatigue_effort_colors, name = NULL) +
  scale_fill_manual(values = fatigue_effort_colors, guide = "none") +
  coord_cartesian(ylim = c(1.88, 2.20)) +
  labs(
    title = "A",
    x = "Session half",
    y = "Boundary separation\n(exp scale)"
  ) +
  theme_nhb() +
  theme(
    legend.position = "bottom",
    legend.margin = margin(t = 2, b = 0, unit = "pt"),
    legend.key.width = unit(0.4, "cm")
  )

# ── Panel B: Focal fatigue coefficients ─────────────────────────────────────
fat_coefs <- tibble(
  hypothesis = c(
    "2nd vs 1st half (a)*",
    "Effort \u00d7 half (a)",
    "Effort \u00d7 half (v)"
  ),
  param = c("a", "a", "v"),
  coef_col = c(
    "b_bs_block_halfSecond_Half",
    "b_bs_effort_conditionHigh_40_MVC:block_halfSecond_Half",
    "b_effort_conditionHigh_40_MVC:block_halfSecond_Half"
  ),
  y_pos = 3:1
) %>%
  rowwise() %>%
  mutate(
    draws_vec   = list(draws_fat[[coef_col]]),
    median      = median(unlist(draws_vec)),
    lo95        = quantile(unlist(draws_vec), 0.025),
    hi95        = quantile(unlist(draws_vec), 0.975),
    excludes0   = sign(lo95) == sign(hi95),
    param_color = unname(param_colors[param])
  ) %>%
  ungroup() %>%
  select(-draws_vec)

panel_b <- ggplot(fat_coefs) +
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
    size = 2.2, hjust = 1.1, color = label_color, nudge_x = -0.008
  ) +
  annotate(
    "text", x = min(fat_coefs$lo95) - 0.02, y = 0.25,
    label = "\u25cf CrI excludes 0    \u25cb CrI spans 0",
    size = 1.8, hjust = 0, color = label_color
  ) +
  scale_y_continuous(breaks = NULL, limits = c(0, 3.4)) +
  coord_cartesian(
    xlim = c(min(fat_coefs$lo95) - 0.14, max(fat_coefs$hi95) + 0.02),
    clip = "off"
  ) +
  labs(title = "B \u2014 Fatigue", x = "Posterior estimate", y = NULL) +
  theme_nhb() +
  theme(axis.line.y = element_blank(), axis.ticks.y = element_blank())

# ── Panel C: Choice history (perseveration + effort × history on bias) ────────
hist_density_df <- bind_rows(
  tibble(
    delta = draws_hist$b_bias_prev_choice,
    model = "History model",
    panel = "Perseveration (bias)"
  ),
  tibble(
    delta = draws_wsls$b_bias_prev_choice,
    model = "WSLS model",
    panel = "Perseveration (bias)"
  ),
  tibble(
    delta = draws_hist$`b_bias_prev_choice:effort_conditionLow_5_MVC`,
    model = "History model",
    panel = "Effort \u00d7 history (bias)"
  ),
  tibble(
    delta = draws_wsls$`b_bias_prev_choice:effort_conditionLow_5_MVC`,
    model = "WSLS model",
    panel = "Effort \u00d7 history (bias)"
  )
) %>%
  mutate(panel = factor(panel, levels = c("Perseveration (bias)", "Effort \u00d7 history (bias)")))

panel_c <- ggplot(hist_density_df, aes(x = delta, fill = model, color = model)) +
  geom_vline(xintercept = 0, color = stat_colors["zero_line"],
             linewidth = 0.5, linetype = "dashed") +
  geom_density(alpha = 0.35, linewidth = 0.6) +
  scale_fill_manual(
    values = c(
      "History model" = unname(model_colors["history"]),
      "WSLS model"    = unname(model_colors["wsls"])
    )
  ) +
  scale_color_manual(
    values = c(
      "History model" = unname(model_colors["history"]),
      "WSLS model"    = unname(model_colors["wsls"])
    )
  ) +
  facet_wrap(~ panel, scales = "free", ncol = 2) +
  labs(
    title = "C",
    x = "Posterior draw (logit scale)",
    y = "Density",
    fill = NULL,
    color = NULL
  ) +
  theme_nhb() +
  theme(legend.position = "bottom")

# ── Combine & save ───────────────────────────────────────────────────────────
fig4 <- (panel_a | panel_b) / panel_c +
  plot_layout(heights = c(1.2, 1))

dir.create(PATH_FIG_OUT, recursive = TRUE, showWarnings = FALSE)

ggsave(
  file.path(PATH_FIG_OUT, "fig4_temporal_dynamics.pdf"),
  fig4, width = 180, height = 100, units = "mm", device = cairo_pdf
)
ggsave(
  file.path(PATH_FIG_OUT, "fig4_temporal_dynamics.png"),
  fig4, width = 180, height = 100, units = "mm", dpi = 300
)

message("Fig 4 saved.")
