# fig5_individual_differences.R
# NHB Fig 5: Individual differences and robustness
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
source(here("06_visualization", "publication_figures", "nhb_paths.R"))

fit_primary <- readRDS(PATH_PRIMARY_MODEL)
beh_data    <- read_csv(PATH_BEHAVIORAL_DATA, show_col_types = FALSE)

label_color <- unname(stat_colors["empirical"])
age_lo      <- "#B8BCC4"
age_hi      <- "#2E86AB"

theme_nhb <- function() {
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
  theme_nhb()

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
  # Bracket arrow to the RIGHT of "High (40%)" column (x > 2)
  annotate(
    "segment",
    x = 2.18, xend = 2.18,
    y = v_lo_mean, yend = v_hi_mean,
    linewidth = 0.5, color = unname(effort_colors["High"]),
    arrow = arrow(length = unit(1.5, "pt"), ends = "both")
  ) +
  annotate(
    "text",
    x = 2.24, y = y_arrow,
    label = sprintf("\u0394v = %.2f", v_effort),
    size = 2.0, hjust = 0, color = unname(effort_colors["High"])
  ) +
  scale_color_manual(values = effort_colors) +
  scale_x_discrete(labels = c("Low" = "Low (5%)", "High" = "High (40%)")) +
  coord_cartesian(xlim = c(0.5, 2.7), clip = "off") +
  labs(
    title = "B",
    x = "Effort condition",
    y = "Subject-level drift rate (v)",
    caption = "v < 0: same-boundary (response-side coding)"
  ) +
  theme_nhb() +
  theme(legend.position = "none")

# ── Panel C: Caterpillar — subject-level drift estimates, sorted, age-colored ──
# Note: pct_reduction vs v_Low was a mathematical identity (same Δv for all);
# this caterpillar shows the actual heterogeneity in individual drift estimates.
cat_df <- tibble(
  subject_id = rownames(re_subj),
  v_est  = v_intercept + re_subj[, "Estimate", "Intercept"],
  v_lo95 = v_intercept + re_subj[, "Q2.5",     "Intercept"],
  v_hi95 = v_intercept + re_subj[, "Q97.5",    "Intercept"]
) %>%
  left_join(load_subject_age(.$subject_id), by = "subject_id") %>%
  arrange(v_est) %>%
  mutate(rank = row_number())

has_age <- sum(!is.na(cat_df$age)) >= 10

panel_c <- ggplot(cat_df, aes(x = v_est, y = rank)) +
  geom_vline(
    xintercept = v_intercept,
    color = stat_colors["zero_line"], linewidth = 0.35, linetype = "dotted"
  ) +
  geom_segment(
    aes(x = v_lo95, xend = v_hi95, yend = rank),
    color = "#C9CDD3", linewidth = 0.35
  ) +
  labs(
    title = "C",
    x = "Subject-level drift rate (v)",
    y = "Participant (sorted)",
    caption = "Sorted by baseline drift (Standard trials)"
  ) +
  theme_nhb() +
  theme(
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank()
  )

if (has_age) {
  panel_c <- panel_c +
    geom_point(aes(color = age), size = 1.3, alpha = 0.9) +
    scale_color_gradient(low = age_lo, high = age_hi, name = "Age (y)") +
    theme(legend.key.height = unit(0.35, "cm"),
          legend.key.width  = unit(0.25, "cm"),
          legend.title      = element_text(size = 6),
          legend.position   = "right")
} else {
  panel_c <- panel_c +
    geom_point(color = unname(effort_colors["High"]), size = 1.3, alpha = 0.9)
}

# ── Combine & save ────────────────────────────────────────────────────────────
fig5 <- panel_a | panel_b | panel_c

dir.create(PATH_FIG_OUT, recursive = TRUE, showWarnings = FALSE)

ggsave(
  file.path(PATH_FIG_OUT, "fig5_individual_differences.pdf"),
  fig5, width = 180, height = 80, units = "mm", device = cairo_pdf
)
ggsave(
  file.path(PATH_FIG_OUT, "fig5_individual_differences.png"),
  fig5, width = 180, height = 80, units = "mm", dpi = 300
)

message("Fig 5 saved.")
