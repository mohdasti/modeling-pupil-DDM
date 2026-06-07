# fig5_individual_differences.R
# Fig 5: Individual differences and robustness
# Panel A: Brinley (pooled) | Panel B: paired drift by effort | Panel C: % reduction vs baseline

suppressPackageStartupMessages({
  library(brms)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(patchwork)
  library(here)
  library(readr)
})

source(here("R", "colors_manuscript.R"))
source(here("06_visualization", "publication_figures", "manuscript_paths.R"))

fit_primary <- readRDS(PATH_PRIMARY_MODEL)
beh_data    <- read_csv(PATH_BEHAVIORAL_DATA, show_col_types = FALSE)

label_color <- unname(stat_colors["empirical"])
age_lo      <- "#B8BCC4"
age_hi      <- "#2E86AB"

theme_manuscript <- function() {
  theme_classic(base_size = 8, base_family = "Helvetica") +
    theme(
      axis.line         = element_line(linewidth = 0.4),
      axis.ticks        = element_line(linewidth = 0.3),
      axis.ticks.length = unit(2, "pt"),
      axis.text         = element_text(size = 7, color = "black"),
      axis.title        = element_text(size = 8),
      plot.title        = element_text(size = 8, face = "bold"),
      plot.caption      = element_text(
        size = 6, color = label_color, hjust = 0,
        margin = margin(t = 3, unit = "pt")
      ),
      legend.text       = element_text(size = 7),
      panel.grid        = element_blank(),
      plot.margin       = margin(4, 4, 4, 4, "pt")
    )
}

load_subject_age <- function(subject_ids) {
  if ("age" %in% names(beh_data)) {
    return(
      beh_data %>%
        distinct(subject_id, age) %>%
        filter(subject_id %in% subject_ids)
    )
  }

  demo_path <- Sys.getenv(
    "BAP_DEMOGRAPHICS_CSV",
    unset = "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/LC Aging Subject Data master spreadsheet - demographics.csv"
  )
  if (!file.exists(demo_path)) {
    return(tibble(subject_id = subject_ids, age = NA_real_))
  }

  read_csv(demo_path, skip = 1, show_col_types = FALSE,
           col_names = c(
             "study", "subject_id", "subject_id2", "demo_comments", "completion",
             "bap_ses1_date", "bap_ses2_date", "bap_ses3_date", "bap_ses_order",
             "bap_tablet_date", "blank1", "bam_ses1", "bam_ses2", "bam_ses3", "bam_order",
             "bam_tablet", "blank2", "dob", "age", "sex", "edu", "hand", "race",
             "ethnicity", "first_lang", "blank3", "vision", "prescription", "blank4",
             "neuropsych_comments", "adt_comments", "vdt_comments", "stx_comments",
             "future_contact", "blank5", "days_ses1_2", "days_ses2_3"
           )) %>%
    mutate(
      subject_id = trimws(subject_id),
      age = as.numeric(age)
    ) %>%
    filter(subject_id %in% subject_ids, !is.na(age)) %>%
    distinct(subject_id, .keep_all = TRUE) %>%
    select(subject_id, age)
}

# ── Panel A: Brinley plot (one point per participant, pooled across effort) ───
brinley_df <- beh_data %>%
  filter(
    difficulty_level %in% c("Easy", "Hard"),
    !is.na(rt), rt > 0, rt < 10
  ) %>%
  group_by(subject_id, difficulty_level) %>%
  summarise(mean_rt = mean(rt, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = difficulty_level, values_from = mean_rt, names_prefix = "mean_rt_") %>%
  filter(!is.na(mean_rt_Easy), !is.na(mean_rt_Hard)) %>%
  mutate(
    Easy = mean_rt_Easy * 1000,
    Hard = mean_rt_Hard * 1000
  )

lm_fit   <- lm(Hard ~ Easy, data = brinley_df)
lm_slope <- coef(lm_fit)[["Easy"]]

panel_a <- ggplot(brinley_df, aes(x = Easy, y = Hard)) +
  geom_abline(
    slope = 1, intercept = 0,
    color = stat_colors["zero_line"], linewidth = 0.4, linetype = "dashed"
  ) +
  geom_smooth(
    method = "lm", se = TRUE, color = label_color,
    fill = "#E5E7EB", linewidth = 0.55, alpha = 0.45
  ) +
  geom_point(color = label_color, size = 1.6, alpha = 0.65) +
  labs(
    title = "A",
    x = "Mean RT: Easy trials (ms)",
    y = "Mean RT: Hard trials (ms)",
    caption = sprintf("slope = %.2f (< 1: disproportionate slowing)", lm_slope)
  ) +
  theme_manuscript()

# ── Subject-level drift (Low vs High effort) ───────────────────────────────────
re_subj <- ranef(fit_primary)$subject_id
pop_fixed <- fixef(fit_primary)

v_intercept <- pop_fixed["Intercept", "Estimate"]
v_effort    <- pop_fixed["effort_conditionhigh", "Estimate"]

subj_ranef <- tibble(
  subject_id = rownames(re_subj),
  ranef_v    = re_subj[, "Estimate", "Intercept"]
)

subj_violin_df <- subj_ranef %>%
  crossing(effort_label = factor(c("Low", "High"), levels = c("Low", "High"))) %>%
  mutate(
    v_subj = v_intercept + ranef_v +
      if_else(effort_label == "High", v_effort, 0)
  )

effort_means <- subj_violin_df %>%
  group_by(effort_label) %>%
  summarise(v_mean = mean(v_subj), .groups = "drop")

# ── Panel B: Paired within-person drift (makes H1 shift visible) ──────────────
v_lo_mean <- effort_means$v_mean[effort_means$effort_label == "Low"]
v_hi_mean <- effort_means$v_mean[effort_means$effort_label == "High"]
y_arrow   <- mean(c(v_lo_mean, v_hi_mean))

v_rng  <- range(subj_violin_df$v_subj, na.rm = TRUE)
v_span <- diff(v_rng)
ylim_b <- c(v_rng[1] - 0.06 * v_span, v_rng[2] + 0.10 * v_span)

panel_b <- ggplot(subj_violin_df, aes(x = effort_label, y = v_subj, group = subject_id)) +
  geom_line(color = "#C9CDD3", linewidth = 0.28, alpha = 0.75) +
  geom_point(aes(color = effort_label), size = 1.15, alpha = 0.75) +
  geom_line(
    data = effort_means,
    aes(x = effort_label, y = v_mean, group = 1),
    inherit.aes = FALSE,
    color = label_color, linewidth = 0.9
  ) +
  geom_point(
    data = effort_means,
    aes(x = effort_label, y = v_mean),
    inherit.aes = FALSE,
    shape = 18, size = 2.2, color = label_color
  ) +
  annotate(
    "segment",
    x = 2.12, xend = 2.12,
    y = v_lo_mean, yend = v_hi_mean,
    linewidth = 0.5, color = unname(effort_colors["High"]),
    arrow = arrow(length = unit(1.5, "pt"), ends = "both")
  ) +
  annotate(
    "text",
    x = 2.17, y = y_arrow,
    label = sprintf("\u0394v = %.2f", v_effort),
    size = 2.0, hjust = 0, color = unname(effort_colors["High"])
  ) +
  scale_color_manual(values = effort_colors) +
  scale_x_discrete(
    labels = c("Low" = "Low (5%)", "High" = "High (40%)"),
    expand = expansion(mult = c(0.12, 0.22))
  ) +
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.02))) +
  coord_cartesian(xlim = c(0.75, 2.35), ylim = ylim_b, clip = "on") +
  labs(
    title = "B",
    x = "Effort condition",
    y = "Subject-level drift rate (v)",
    caption = "v < 0: same-boundary (response-side coding)"
  ) +
  theme_manuscript() +
  theme(
    legend.position = "none",
    plot.margin = margin(4, 10, 10, 4, "pt"),
    axis.text.x = element_text(margin = margin(t = 4, unit = "pt"))
  )

# ── Panel C: Per-person Low vs High effort drift scatter ─────────────────────
scatter_df <- subj_violin_df %>%
  select(subject_id, effort_label, v_subj) %>%
  pivot_wider(names_from = effort_label, values_from = v_subj)

panel_c <- ggplot(scatter_df, aes(x = Low, y = High)) +
  geom_abline(
    slope = 1, intercept = 0,
    color = stat_colors["zero_line"], linewidth = 0.4, linetype = "dashed"
  ) +
  geom_point(color = label_color, size = 1.4, alpha = 0.7) +
  coord_cartesian(xlim = c(-1.5, 0.5), ylim = c(-1.5, 0.5)) +
  labs(
    title = "C",
    x = "Drift rate: Low effort (v)",
    y = "Drift rate: High effort (v)",
    caption = "Points below diagonal: lower drift under High effort"
  ) +
  theme_manuscript()

# ── Combine & save ────────────────────────────────────────────────────────────
fig5 <- panel_a | panel_b | panel_c

dir.create(PATH_FIG_OUT, recursive = TRUE, showWarnings = FALSE)

ggsave(
  file.path(PATH_FIG_OUT, "fig5_individual_differences.pdf"),
  fig5, width = 180, height = 85, units = "mm", device = cairo_pdf
)
ggsave(
  file.path(PATH_FIG_OUT, "fig5_individual_differences.png"),
  fig5, width = 180, height = 85, units = "mm", dpi = 300
)

message("Fig 5 saved.")
