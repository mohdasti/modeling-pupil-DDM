#!/usr/bin/env Rscript
# LC integrity exploratory analyses for Chapter 3 supplement (Appendix A8).
# Merges LC MRI metrics (Bennett et al. pipeline) with behavioral summaries and
# subject-level DDM random effects from the primary model.

suppressPackageStartupMessages({
  library(tidyverse)
  library(broom)
  library(brms)
  library(ggplot2)
  library(here)
})

source(here("R", "colors_manuscript.R"))
source(here("R", "fig_save_utils.R"))

LC_FILE <- "data/raw/bap_beh_subjxtaskdata_v2.csv"
DDM_FIT <- "output/models/primary_vza.rds"
OUT_DIR <- "output/lc_integrity"
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Individual-differences scatter styling (matches fig5 / Brinley convention)
scatter_point_col <- unname(stat_colors["empirical"])
scatter_line_col <- unname(stat_colors["empirical"])
scatter_annot_col <- unname(stat_colors["empirical"])

normalize_subject_id <- function(id) {
  id <- as.character(id)
  id_clean <- str_replace(id, "^BAP", "")
  num_match <- str_extract(id_clean, "\\d+")
  ifelse(!is.na(num_match), sprintf("BAP%03d", as.integer(num_match)), id)
}

partial_cor <- function(df, x, y) {
  sub <- df %>%
    filter(!is.na(.data[[x]]), !is.na(.data[[y]]), !is.na(age), !is.na(sex))
  if (nrow(sub) < 12) {
    return(tibble(r = NA_real_, p = NA_real_, n = nrow(sub)))
  }
  m_x <- lm(reformulate(c("age", "sex"), x), data = sub)
  m_y <- lm(reformulate(c("age", "sex"), y), data = sub)
  ct <- cor.test(resid(m_x), resid(m_y))
  tibble(r = unname(ct$estimate), p = ct$p.value, n = nrow(sub))
}

raw <- read_csv(LC_FILE, show_col_types = FALSE)

lc <- raw %>%
  distinct(subject_id, .keep_all = TRUE) %>%
  transmute(
    subject_id = normalize_subject_id(subject_id),
    age,
    sex = factor(sex),
    LC_CNR_max,
    LC_CNR_mean,
    LC_fICVF,
    LC_fISO,
    LC_fICVF_caudal,
    LC_fICVF_rostral,
    LC_fISO_caudal,
    LC_fISO_rostral,
    LC_MD_500,
    LC_AD_500,
    LC_Composite_v2,
    PC1_v2
  )

beh <- raw %>%
  filter(!is.na(task_modality)) %>%
  group_by(subject_id) %>%
  summarise(
    accuracy = mean(accuracy, na.rm = TRUE),
    accuracy_diff = mean(accuracy_diff, na.rm = TRUE),
    accuracy_diff_abs = mean(accuracy_diff_abs, na.rm = TRUE),
    rt_mean = mean(same_diff_resp_secs, na.rm = TRUE),
    rt_diff = mean(same_diff_resp_secs_diff, na.rm = TRUE),
    rt_diff_abs = mean(same_diff_resp_secs_diff_abs, na.rm = TRUE),
    dprime_mean = mean(sdt_dprime_i1_across_grip, na.rm = TRUE),
    dprime_variability = sd(
      c(
        sdt_dprime_i1_across_grip, sdt_dprime_i2_across_grip,
        sdt_dprime_i3_across_grip, sdt_dprime_i4_across_grip
      ),
      na.rm = TRUE
    ),
    pf_slope = mean(pf_slope_scaled_linear_across_grip, na.rm = TRUE),
    pf_threshold_diff = mean(pf_threshold_scaled_linear_diff, na.rm = TRUE),
    grip_sd = mean(grip_force_sd_runmean, na.rm = TRUE),
    tepr_mean = mean(rpf_auc_t2AUC_mean, na.rm = TRUE),
    tepr_diff = mean(rpf_auc_t2AUC_diff, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(subject_id = normalize_subject_id(subject_id))

fit <- readRDS(DDM_FIT)
re <- ranef(fit)$subject_id
ddm <- tibble(
  subject_id = normalize_subject_id(rownames(re)),
  v_mean = re[, "Estimate", "Intercept"],
  bs_log_mean = re[, "Estimate", "bs_Intercept"],
  a_mean = exp(fixef(fit)["bs_Intercept", "Estimate"] + re[, "Estimate", "bs_Intercept"]),
  z_logit_mean = re[, "Estimate", "bias_Intercept"],
  z_mean = plogis(fixef(fit)["bias_Intercept", "Estimate"] + re[, "Estimate", "bias_Intercept"])
)

dat <- lc %>%
  inner_join(beh, by = "subject_id") %>%
  inner_join(ddm, by = "subject_id")

lc_preds <- c("LC_fISO", "LC_fICVF", "LC_CNR_max", "LC_Composite_v2", "PC1_v2")
outcomes <- c(
  "dprime_variability", "dprime_mean", "grip_sd", "rt_diff_abs",
  "v_mean", "a_mean", "z_mean", "tepr_mean", "rt_mean", "pf_slope"
)

cor_tab <- crossing(predictor = lc_preds, outcome = outcomes) %>%
  rowwise() %>%
  mutate(data = list(partial_cor(dat, predictor, outcome))) %>%
  unnest(data) %>%
  ungroup() %>%
  mutate(
    fdr = p.adjust(p, "fdr"),
    outcome_type = case_when(
      outcome %in% c("dprime_variability", "grip_sd", "rt_diff_abs") ~ "variability_or_cost",
      outcome %in% c("v_mean", "a_mean", "z_mean") ~ "ddm_baseline",
      TRUE ~ "mean_performance"
    )
  )

summary_tbl <- cor_tab %>%
  filter(
    (predictor == "LC_fISO" & outcome %in% c(
      "dprime_variability", "dprime_mean", "v_mean", "a_mean", "z_mean",
      "tepr_mean", "rt_diff_abs"
    )) |
      (predictor == "LC_CNR_max" & outcome %in% c("dprime_variability", "v_mean", "tepr_mean"))
  ) %>%
  mutate(r = round(r, 3), p = signif(p, 3), fdr = signif(fdr, 3))

write_csv(dat, file.path(OUT_DIR, "lc_ddm_behavior_merged.csv"))
write_csv(cor_tab, file.path(OUT_DIR, "lc_partial_correlations.csv"))
write_csv(summary_tbl, file.path(OUT_DIR, "lc_supplement_summary_table.csv"))

inline_stats <- list(
  n_merged = nrow(dat),
  n_lc = sum(!is.na(dat$LC_fISO)),
  fiso_dprimevar_r = summary_tbl$r[summary_tbl$predictor == "LC_fISO" & summary_tbl$outcome == "dprime_variability"],
  fiso_dprimevar_p = summary_tbl$p[summary_tbl$predictor == "LC_fISO" & summary_tbl$outcome == "dprime_variability"],
  fiso_dprimevar_n = summary_tbl$n[summary_tbl$predictor == "LC_fISO" & summary_tbl$outcome == "dprime_variability"],
  fiso_dprime_mean_p = summary_tbl$p[summary_tbl$predictor == "LC_fISO" & summary_tbl$outcome == "dprime_mean"],
  fiso_a_r = summary_tbl$r[summary_tbl$predictor == "LC_fISO" & summary_tbl$outcome == "a_mean"],
  fiso_a_p = summary_tbl$p[summary_tbl$predictor == "LC_fISO" & summary_tbl$outcome == "a_mean"],
  fiso_v_p = summary_tbl$p[summary_tbl$predictor == "LC_fISO" & summary_tbl$outcome == "v_mean"],
  fiso_tepr_p = summary_tbl$p[summary_tbl$predictor == "LC_fISO" & summary_tbl$outcome == "tepr_mean"],
  cnr_tepr_p = summary_tbl$p[summary_tbl$predictor == "LC_CNR_max" & summary_tbl$outcome == "tepr_mean"]
)
saveRDS(inline_stats, file.path(OUT_DIR, "lc_supplement_inline_stats.rds"))

plot_dat <- dat %>% filter(!is.na(LC_fISO), !is.na(dprime_variability))
r_part <- partial_cor(dat, "LC_fISO", "dprime_variability")

p1 <- ggplot(plot_dat, aes(x = LC_fISO, y = dprime_variability)) +
  geom_point(size = 2.2, alpha = 0.75, color = scatter_point_col) +
  geom_smooth(
    method = "lm", se = TRUE,
    color = scatter_line_col, fill = scatter_line_col,
    linewidth = 0.7, alpha = 0.2
  ) +
  labs(
    x = "LC free-water fraction (fISO)",
    y = expression("Cross-intensity d' variability (SD)"),
    title = NULL
  ) +
  annotate(
    "text", x = Inf, y = Inf, hjust = 1.05, vjust = 1.3,
    label = sprintf("partial r = %.2f, p = %.3f\nn = %d", r_part$r, r_part$p, r_part$n),
    size = 3.5, color = scatter_annot_col
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())

save_manuscript_fig(p1, "fig_lc_fiso_dprime_variability", 5.5, 4.5)

make_panel_scatter <- function(xvar, yvar, ylab, label) {
  sub <- dat %>% filter(!is.na(.data[[xvar]]), !is.na(.data[[yvar]]))
  pc <- partial_cor(dat, xvar, yvar)
  ggplot(sub, aes(x = .data[[xvar]], y = .data[[yvar]])) +
    geom_point(size = 1.8, alpha = 0.75, color = scatter_point_col) +
    geom_smooth(
      method = "lm", se = TRUE,
      color = scatter_line_col, fill = scatter_line_col,
      linewidth = 0.7, alpha = 0.2
    ) +
    labs(x = NULL, y = ylab, title = label) +
    annotate(
      "text", x = Inf, y = Inf, hjust = 1.05, vjust = 1.3,
      label = sprintf("partial r = %.2f\np = %.3f", pc$r, pc$p),
      size = 3.2, color = scatter_annot_col
    ) +
    theme_minimal(base_size = 11) +
    theme(panel.grid.minor = element_blank(), plot.title = element_text(size = 11, face = "bold"))
}

if (requireNamespace("patchwork", quietly = TRUE)) {
  p2 <- patchwork::wrap_plots(
    make_panel_scatter("LC_fISO", "dprime_variability", "d' variability", "Variability"),
    make_panel_scatter("LC_fISO", "dprime_mean", "Mean d'", "Mean performance"),
    make_panel_scatter("LC_fISO", "a_mean", "Baseline boundary (a)", "DDM baseline"),
    make_panel_scatter("LC_fISO", "tepr_mean", "Mean TEPR (AUC)", "Phasic pupil"),
    ncol = 2
  ) +
    patchwork::plot_annotation(
      title = "LC fISO: variability, mean performance, DDM, and pupil",
      theme = theme(plot.title = element_text(size = 12, face = "bold"))
    )
  save_manuscript_fig(p2, "fig_lc_fiso_four_panel", 9, 7)
}

cat("LC supplement analysis complete.\n")
cat("  Subjects merged:", nrow(dat), "\n")
cat("  LC complete:", sum(!is.na(dat$LC_fISO)), "\n")
cat("  Outputs:", OUT_DIR, "\n")
