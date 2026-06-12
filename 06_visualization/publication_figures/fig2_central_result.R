# fig2_central_result.R
# Fig 2: Selective effort effect on drift rate — the central claim
# Panels A+B: drift (v) estimates + H1 posterior contrast
# Panels C+D: boundary (a) estimates + H2 posterior contrast

suppressPackageStartupMessages({
  library(brms)
  library(tidybayes)
  library(ggplot2)
  library(dplyr)
  library(patchwork)
  library(here)
})

source(here("R", "colors_manuscript.R"))
source(here("06_visualization", "publication_figures", "manuscript_paths.R"))

fmt_posterior_p_annot <- function(p, dir = c("lt", "gt")) {
  sym <- if (dir[1] == "lt") "<" else ">"
  if (is.na(p)) return("")
  if (p >= 0.999) return(sprintf("P(\u03b2%s0) > .999", sym))
  if (p <= 0.001) return(sprintf("P(\u03b2%s0) < .001", sym))
  sprintf("P(\u03b2%s0) = %.3f", sym, p)
}

fit_primary <- readRDS(PATH_PRIMARY_MODEL)

# ── Shared theme ──────────────────────────────────────────────────────────────
theme_manuscript <- function() {
  theme_classic(base_size = 8, base_family = "Helvetica") +
    theme(
      axis.line         = element_line(linewidth = 0.4),
      axis.ticks        = element_line(linewidth = 0.3),
      axis.ticks.length = unit(2, "pt"),
      axis.text         = element_text(size = 7, color = "black"),
      axis.title        = element_text(size = 8),
      plot.title        = element_text(size = 8, face = "bold"),
      legend.text       = element_text(size = 7),
      legend.key.size   = unit(8, "pt"),
      panel.grid        = element_blank(),
      plot.margin       = margin(4, 4, 4, 4, "pt")
    )
}

# ── Population-level condition estimates ──────────────────────────────────────
newdata_v <- expand.grid(
  difficulty_3     = levels(fit_primary$data$difficulty_3),
  effort_condition = levels(fit_primary$data$effort_condition),
  task             = "ADT",
  subject_id       = NA,
  stringsAsFactors = FALSE
)

draws_v <- newdata_v %>%
  add_epred_draws(fit_primary, dpar = "mu", re_formula = NA, ndraws = 2000) %>%
  group_by(difficulty_3, effort_condition) %>%
  summarise(
    median = median(.epred),
    lo95   = quantile(.epred, 0.025),
    hi95   = quantile(.epred, 0.975),
    .groups = "drop"
  ) %>%
  mutate(
    difficulty_3 = factor(difficulty_3, levels = c("Standard", "Hard", "Easy")),
    effort_label = if_else(effort_condition == "high", "High", "Low")
  )

draws_a <- newdata_v %>%
  add_epred_draws(fit_primary, dpar = "bs", re_formula = NA, ndraws = 2000) %>%
  mutate(.epred = exp(.epred)) %>%
  group_by(difficulty_3, effort_condition) %>%
  summarise(
    median = median(.epred),
    lo95   = quantile(.epred, 0.025),
    hi95   = quantile(.epred, 0.975),
    .groups = "drop"
  ) %>%
  mutate(
    difficulty_3 = factor(difficulty_3, levels = c("Standard", "Hard", "Easy")),
    effort_label = if_else(effort_condition == "high", "High", "Low")
  )

# ── H1 / H2 contrast posteriors (High − Low effort; low = reference) ─────────
draws_df <- as_draws_df(fit_primary)

contrast_v <- draws_df %>%
  transmute(delta = b_effort_conditionhigh)

contrast_a <- draws_df %>%
  transmute(delta = b_bs_effort_conditionhigh)

# ── Panel A: Drift rate by Difficulty × Effort ────────────────────────────────
panel_a <- ggplot(draws_v,
                  aes(x = difficulty_3, y = median,
                      color = effort_label, group = effort_label)) +
  geom_hline(yintercept = 0, color = stat_colors["zero_line"],
             linewidth = 0.4, linetype = "dashed") +
  geom_line(linewidth = 0.6, position = position_dodge(0.15)) +
  geom_pointrange(aes(ymin = lo95, ymax = hi95),
                  linewidth = 0.5, size = 0.6,
                  position = position_dodge(0.15)) +
  scale_color_manual(
    values = effort_colors,
    labels = c("High" = "High (40% MVC)", "Low" = "Low (5% MVC)")
  ) +
  labs(title = "A", x = "Difficulty", y = "Drift rate (v)", color = "Effort") +
  theme_manuscript() +
  theme(
    legend.position    = "top",
    legend.justification = "left",
    legend.direction   = "horizontal",
    legend.margin      = margin(b = 2, unit = "pt"),
    legend.background  = element_rect(fill = "white", color = NA),
    plot.margin        = margin(2, 4, 4, 4, "pt")
  )

# ── Panel B: H1 contrast posterior ───────────────────────────────────────────
dens_v <- density(contrast_v$delta)
cri_v  <- quantile(contrast_v$delta, c(0.025, 0.975))
p_neg_v <- mean(contrast_v$delta < 0)

panel_b <- ggplot(contrast_v, aes(x = delta)) +
  geom_vline(xintercept = 0, color = stat_colors["zero_line"],
             linewidth = 0.4, linetype = "dashed") +
  geom_ribbon(
    data = data.frame(x = dens_v$x, y = dens_v$y) %>%
      filter(x >= cri_v[1], x <= cri_v[2]),
    aes(x = x, ymin = 0, ymax = y),
    fill = effort_colors["High"], alpha = 0.35, inherit.aes = FALSE
  ) +
  geom_density(color = effort_colors["High"], linewidth = 0.7) +
  annotate(
    "text",
    x = min(contrast_v$delta) * 0.85,
    y = max(dens_v$y) * 0.9,
    label = sprintf(
      "\u03b2 = %.3f\n95%% CrI [%.3f, %.3f]\n%s",
      median(contrast_v$delta), cri_v[1], cri_v[2],
      fmt_posterior_p_annot(p_neg_v, "lt")
    ),
    size = 2.2, hjust = 0, color = stat_colors["empirical"]
  ) +
  labs(title = "B", x = "High \u2212 Low effort on v", y = "Posterior density") +
  theme_manuscript()

# ── Panel C: Boundary separation by Difficulty × Effort ──────────────────────
panel_c <- ggplot(draws_a,
                  aes(x = difficulty_3, y = median,
                      color = effort_label, group = effort_label)) +
  geom_line(linewidth = 0.6, position = position_dodge(0.15)) +
  geom_pointrange(aes(ymin = lo95, ymax = hi95),
                  linewidth = 0.5, size = 0.6,
                  position = position_dodge(0.15)) +
  scale_color_manual(values = effort_colors) +
  labs(title = "C", x = "Difficulty", y = "Boundary separation (a)") +
  theme_manuscript() +
  theme(legend.position = "none")

# ── Panel D: H2 contrast posterior ───────────────────────────────────────────
dens_a <- density(contrast_a$delta)
cri_a  <- quantile(contrast_a$delta, c(0.025, 0.975))
p_pos_a <- mean(contrast_a$delta > 0)
xr_a    <- range(contrast_a$delta)
x_pad_a <- max(0.35 * diff(xr_a), 0.003)
x_left_d <- xr_a[1] - x_pad_a
x_annot_d <- x_left_d + 0.08 * x_pad_a

panel_d <- ggplot(contrast_a, aes(x = delta)) +
  geom_vline(xintercept = 0, color = stat_colors["zero_line"],
             linewidth = 0.4, linetype = "dashed") +
  geom_ribbon(
    data = data.frame(x = dens_a$x, y = dens_a$y) %>%
      filter(x >= cri_a[1], x <= cri_a[2]),
    aes(x = x, ymin = 0, ymax = y),
    fill = effort_colors["High"], alpha = 0.20, inherit.aes = FALSE
  ) +
  geom_density(color = effort_colors["High"], linewidth = 0.7, linetype = "dashed") +
  annotate(
    "text",
    x = x_annot_d,
    y = max(dens_a$y) * 0.9,
    label = sprintf(
      "\u03b2 = %.3f\n95%% CrI [%.3f, %.3f]\n%s",
      median(contrast_a$delta), cri_a[1], cri_a[2],
      fmt_posterior_p_annot(p_pos_a, "gt")
    ),
    size = 2.2, hjust = 0, color = stat_colors["empirical"]
  ) +
  coord_cartesian(xlim = c(x_left_d, xr_a[2] + 0.05 * diff(xr_a))) +
  labs(title = "D", x = "High \u2212 Low effort on a (log scale)", y = "Posterior density") +
  theme_manuscript()

# ── Combine & save (2×2: A–B top, C–D bottom) ───────────────────────────────
fig2 <- (panel_a | panel_b) / (panel_c | panel_d) +
  plot_layout(widths = c(1.4, 1), heights = c(1, 1))

dir.create(PATH_FIG_OUT, recursive = TRUE, showWarnings = FALSE)

ggsave(
  file.path(PATH_FIG_OUT, "fig2_central_result.pdf"),
  fig2, width = 180, height = 100, units = "mm", device = cairo_pdf
)
ggsave(
  file.path(PATH_FIG_OUT, "fig2_central_result.png"),
  fig2, width = 180, height = 100, units = "mm", dpi = 300
)

message("Fig 2 saved.")
