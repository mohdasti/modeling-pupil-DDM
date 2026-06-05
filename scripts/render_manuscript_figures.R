#!/usr/bin/env Rscript
# Regenerate ALL manuscript figures with colors_manuscript.R
# Outputs: output/figures/manuscript_palette/ (+ mirrors to output/figures/)

suppressPackageStartupMessages(library(here))
repo <- here::here()
setwd(repo)

source(here::here("R", "colors_manuscript.R"))
source(here::here("R", "fig_save_utils.R"))
stopifnot(length(cond_colors) == 6, length(param_colors) == 4, length(task_colors) == 2)
cat("Color system loaded OK\n")

out_palette <- file.path(repo, "output/figures/manuscript_palette")
dir.create(out_palette, recursive = TRUE, showWarnings = FALSE)

run_script <- function(path) {
  path <- file.path(repo, path)
  if (!file.exists(path)) {
    message("SKIP (missing): ", path)
    return(invisible(FALSE))
  }
  message("\n=== ", basename(path), " ===")
  tryCatch({
    source(path, local = new.env(parent = globalenv()))
    TRUE
  }, error = function(e) {
    message("ERROR in ", basename(path), ": ", conditionMessage(e))
    FALSE
  })
}

# ── R/figure scripts used by the manuscript ───────────────────────────────────
fig_scripts <- c(
  "scripts/R/fig_ddm_process.R",
  "scripts/R/fig_ndt_prior_posterior.R",
  "scripts/R/fig_caf.R",
  "scripts/R/fig_ppc_heatmaps.R",
  "scripts/R/fig_qp.R",
  "scripts/R/fig_ppc_rt_overlay.R",
  "scripts/R/fig_bias_forest.R",
  "scripts/R/fig_v_standard_posterior.R",
  "scripts/R/fig_ppc_small_multiples.R",
  "scripts/R/fig_pdiff_heatmap.R",
  "scripts/R/fig_fixed_effects.R",
  "scripts/plot_decision_landscape.R",
  "scripts/plot_pupil_waveforms_bap_reference_style.R"
)

invisible(lapply(fig_scripts, run_script))

# ── Inline-style figures (same logic as chap3_ddm_results.qmd chunks) ───────────
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(tibble)
  library(ggplot2)
  library(patchwork)
})

run_dir <- file.path(repo, "output/ddm_refits/runs/20260226_092110")
PRIMARY_MODEL <- "additive"
PRIMARY_RT    <- "probe_onset_locked"
PRIMARY_THR   <- 0.20

cond_colors_spaced <- stats::setNames(unname(cond_colors), gsub("/", " / ", names(cond_colors)))
contrast_colors <- c(
  "Easy vs. Standard" = diff_colors["Easy"],
  "Hard vs. Standard" = diff_colors["Hard"],
  "Easy vs. Hard"     = diff_colors["Standard"]
)
ch_model_colors <- c(M_hist = unname(model_colors["history"]), M_wsls = unname(model_colors["wsls"]))
fatigue_param_colors <- c("Drift (v)" = unname(param_colors["v"]), "Boundary (a)" = unname(param_colors["a"]))
fatigue_effort_colors <- c(
  "Low effort (5% MVC)"   = unname(effort_colors["Low"]),
  "High effort (40% MVC)" = unname(effort_colors["High"])
)
param_display_colors <- c(
  "Drift (v)" = unname(param_colors["v"]), "Boundary (a)" = unname(param_colors["a"]),
  "Bias (z)" = unname(param_colors["z"]), "Non-decision time (t0)" = unname(param_colors["t0"])
)

standardize_pred_params <- function(df) {
  if ("model_name" %in% names(df) && !"model" %in% names(df)) df <- df %>% rename(model = model_name)
  if ("rt_def" %in% names(df) && !"rt_type" %in% names(df)) df <- df %>% rename(rt_type = rt_def)
  if ("effort_condition" %in% names(df) && !"effort" %in% names(df)) {
    df <- df %>% mutate(effort = case_when(
      effort_condition %in% c("low", "Low", "Low_5_MVC") ~ "Low",
      effort_condition %in% c("high", "High", "High_40_MVC") ~ "High",
      TRUE ~ as.character(effort_condition)
    ))
  }
  if ("difficulty_3" %in% names(df) && !"difficulty" %in% names(df)) df <- df %>% rename(difficulty = difficulty_3)
  if ("v_median" %in% names(df) && !"drift_median" %in% names(df)) {
    df <- df %>% rename(drift_median = v_median, drift_q2.5 = v_q2.5, drift_q97.5 = v_q97.5,
                        a_median = a_median, a_q2.5 = a_q2.5, a_q97.5 = a_q97.5)
  }
  df
}

pred_params <- NULL
pred_path <- file.path(run_dir, "tables/predicted_parameters_by_condition.csv")
if (file.exists(pred_path)) {
  pred_params <- read_csv(pred_path, show_col_types = FALSE) %>% standardize_pred_params()
  drift_pooled <- pred_params %>%
    filter(model == PRIMARY_MODEL, rt_type == PRIMARY_RT, threshold == PRIMARY_THR) %>%
    group_by(difficulty, effort) %>% slice(1) %>% ungroup() %>%
    mutate(difficulty = factor(difficulty, levels = c("Standard", "Easy", "Hard")),
           effort = factor(effort, levels = c("Low", "High")))
  p_drift <- ggplot(drift_pooled, aes(x = difficulty, y = drift_median, color = effort, group = effort)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = unname(stat_colors["zero_line"]), alpha = 0.5) +
    geom_pointrange(aes(ymin = drift_q2.5, ymax = drift_q97.5), position = position_dodge(0.35)) +
    geom_line(position = position_dodge(0.35), alpha = 0.7) +
    scale_color_manual(values = effort_colors) + labs(x = "Difficulty", y = "Drift Rate (v)") +
    theme_bw(base_size = 14) + theme(legend.position = "none")
  boundary_pooled <- pred_params %>%
    filter(model == PRIMARY_MODEL, rt_type == PRIMARY_RT, threshold == PRIMARY_THR) %>%
    group_by(difficulty, effort) %>% slice(1) %>% ungroup() %>%
    mutate(difficulty = factor(difficulty, levels = c("Standard", "Easy", "Hard")),
           effort = factor(effort, levels = c("Low", "High")))
  p_boundary <- ggplot(boundary_pooled, aes(x = difficulty, y = a_median, color = effort, group = effort)) +
    geom_pointrange(aes(ymin = a_q2.5, ymax = a_q97.5), position = position_dodge(0.35)) +
    geom_line(position = position_dodge(0.35), alpha = 0.7) +
    scale_color_manual(values = effort_colors) + labs(x = "Difficulty", y = "Boundary Separation (a)") +
    theme_bw(base_size = 14) + theme(legend.position = "none")
  save_manuscript_fig(p_drift + p_boundary + plot_layout(guides = "collect"), "fig_ddm_parameters_combined", 12, 5)
}

# TEPR timecourse
wf_path <- file.path(repo, "data/pupil_processed/analysis/pupil_waveforms_condition_mean.csv")
if (file.exists(wf_path)) {
  wf <- read_csv(wf_path, show_col_types = FALSE) %>%
    filter(chapter == "ch3") %>%
    mutate(
      difficulty_level = case_when(
        isOddball == 0 | (!is.na(stimulus_intensity) & stimulus_intensity == 0) ~ "Standard",
        stimulus_intensity %in% c(1, 2) ~ "Hard",
        stimulus_intensity %in% c(3, 4) ~ "Easy",
        TRUE ~ NA_character_
      ),
      effort_level = case_when(
        effort %in% c("Low", "Low_Force_5pct") ~ "Low",
        effort %in% c("High", "High_Force_40pct") ~ "High",
        TRUE ~ NA_character_
      ),
      condition = paste0(difficulty_level, " / ", effort_level)
    ) %>%
    filter(!is.na(condition), !grepl("Standard", condition)) %>%
    rename(mean_pupil_isolated = mean_pupil_full) %>%
    group_by(task, condition, t_rel) %>%
    summarise(mean_pupil_isolated = weighted.mean(mean_pupil_isolated, n_trials, na.rm = TRUE), .groups = "drop")
  cols <- cond_colors_spaced[names(cond_colors_spaced) %in% unique(wf$condition)]
  p_tepr <- ggplot(wf, aes(x = t_rel, y = mean_pupil_isolated, color = condition, fill = condition)) +
    geom_smooth(se = TRUE, method = "gam", formula = y ~ s(x, k = 20), linewidth = 1.2, alpha = 0.3) +
    facet_wrap(~task, ncol = 1) +
    scale_color_manual(values = cols) + scale_fill_manual(values = cols) +
    labs(x = "Time (s, relative to squeeze onset)", y = "Baseline-Corrected Pupil (AU)") +
    theme_minimal(base_size = 12) + theme(legend.position = "bottom")
  save_manuscript_fig(p_tepr, "fig_tepr_timecourse", 10, 8)
}

model_path <- file.path(run_dir, "models", "additive__probe_onset_locked__thr0.20.rds")
if (file.exists(model_path) && requireNamespace("brms", quietly = TRUE)) {
  suppressPackageStartupMessages(library(brms))
  fit <- readRDS(model_path)
  d <- as_draws_df(fit)
  eff_var <- intersect(c("b_effort_conditionhigh", "b_effort_conditionHigh"), names(d))[1]
  if (!is.na(eff_var)) {
    diff_draws <- as.numeric(d[[eff_var]])
    p_eff <- ggplot(tibble(diff = diff_draws), aes(x = diff)) +
      geom_density(fill = unname(effort_colors["High"]), alpha = 0.55, color = "black", linewidth = 0.4) +
      geom_vline(xintercept = 0, linetype = "dashed", color = unname(stat_colors["zero_line"])) +
      labs(x = "Drift rate contrast: High - Low Effort", y = "Posterior density") +
      theme_bw(base_size = 12)
    save_manuscript_fig(p_eff, "fig_effort_drift_posterior_h1", 6, 3)
  }
  v_easy <- intersect(c("b_difficulty_3Easy", "b_difficultylevelEasy"), names(d))[1]
  v_hard <- intersect(c("b_difficulty_3Hard", "b_difficultylevelHard"), names(d))[1]
  a_easy <- intersect(c("b_bs_difficulty_3Easy", "b_bs_difficultylevelEasy"), names(d))[1]
  a_hard <- intersect(c("b_bs_difficulty_3Hard", "b_bs_difficultylevelHard"), names(d))[1]
  if (!is.na(v_easy) && !is.na(v_hard) && !is.na(a_easy) && !is.na(a_hard)) {
    mk <- function(vals, labels) tibble(contrast = rep(labels, each = length(vals[[1]])), value = unlist(vals)) %>%
      mutate(contrast = factor(contrast, levels = labels))
    cv <- mk(list(d[[v_easy]], d[[v_hard]], d[[v_easy]] - d[[v_hard]]),
             c("Easy vs. Standard", "Hard vs. Standard", "Easy vs. Hard"))
    ca <- mk(list(d[[a_easy]], d[[a_hard]], d[[a_easy]] - d[[a_hard]]),
             c("Easy vs. Standard", "Hard vs. Standard", "Easy vs. Hard"))
    p_v <- ggplot(cv, aes(x = value, fill = contrast, color = contrast)) +
      geom_density(alpha = 0.45) + geom_vline(xintercept = 0, linetype = "dashed") +
      facet_wrap(~contrast, scales = "free", ncol = 1) +
      scale_fill_manual(values = contrast_colors, guide = "none") +
      scale_color_manual(values = contrast_colors, guide = "none") + theme_bw(base_size = 11)
    p_a <- ggplot(ca, aes(x = value, fill = contrast, color = contrast)) +
      geom_density(alpha = 0.45) + geom_vline(xintercept = 0, linetype = "dashed") +
      facet_wrap(~contrast, scales = "free", ncol = 1) +
      scale_fill_manual(values = contrast_colors, guide = "none") +
      scale_color_manual(values = contrast_colors, guide = "none") + theme_bw(base_size = 11)
    save_manuscript_fig(p_v + p_a + plot_layout(ncol = 2), "fig_difficulty_contrasts", 10, 4)
  }
}

std_bias <- file.path(run_dir, "tables/standard_only_bias_by_condition.csv")
if (file.exists(std_bias)) {
  bias_by_task <- read_csv(std_bias, show_col_types = FALSE) %>%
    {if ("rt_def" %in% names(.)) rename(., rt_type = rt_def) else .} %>%
    filter(threshold == PRIMARY_THR, rt_type == PRIMARY_RT) %>%
    group_by(task) %>% summarise(z_mean = mean(z_mean), z_q2.5 = min(z_q2.5), z_q97.5 = max(z_q97.5), .groups = "drop") %>%
    mutate(task = factor(task, levels = c("ADT", "VDT")))
  save_manuscript_fig(
    ggplot(bias_by_task, aes(x = task, y = z_mean, fill = task)) +
      geom_hline(yintercept = 0.5, linetype = "dashed", color = unname(stat_colors["zero_line"])) +
      geom_col(width = 0.6, alpha = 0.8) +
      geom_errorbar(aes(ymin = z_q2.5, ymax = z_q97.5), width = 0.25, color = "black") +
      scale_fill_manual(values = task_colors, guide = "none") +
      labs(x = "Task Modality", y = "Bias (z)") + theme_minimal(base_size = 12),
    "fig_bias_by_task", 5, 3.5)
}

ch_hist <- file.path(repo, "output/publish/fit_exploratory_choice_history_hist.rds")
ch_wsls <- file.path(repo, "output/publish/fit_exploratory_choice_history_wsls.rds")
if (file.exists(ch_hist) && file.exists(ch_wsls) && requireNamespace("purrr", quietly = TRUE)) {
  library(purrr)
  extract_focal <- function(fit, model_label) {
    draws <- as_draws_df(fit)
    focal_map <- c("Perseveration (bias)" = "b_bias_prev_choice",
                   "Effort × History (bias)" = "b_bias_prev_choice:effort_conditionLow_5_MVC",
                   "WSLS: Correct × History (bias)" = "b_bias_prev_choice:prev_correct",
                   "Perseveration (drift)" = "b_prev_choice")
    map_dfr(names(focal_map), function(label) {
      col <- focal_map[[label]]
      if (col %in% names(draws)) tibble(parameter = label, model = model_label, draw = draws[[col]]) else NULL
    })
  }
  draws_all <- bind_rows(extract_focal(readRDS(ch_hist), "M_hist"), extract_focal(readRDS(ch_wsls), "M_wsls"))
  save_manuscript_fig(
    ggplot(draws_all, aes(x = draw, fill = model, colour = model)) +
      geom_density(alpha = 0.5) + geom_vline(xintercept = 0, linetype = "dashed", colour = unname(stat_colors["zero_line"])) +
      facet_wrap(~ parameter, scales = "free", ncol = 2) +
      scale_fill_manual(values = ch_model_colors) + scale_colour_manual(values = ch_model_colors) +
      labs(x = "Posterior draw", y = "Density") + theme_minimal(base_size = 11) + theme(legend.position = "bottom"),
    "fig_choice_history_posteriors", 10, 8)
}

fat_rds <- file.path(repo, "output/publish/fit_exploratory_fatigue_trajectory.rds")
fat_csv <- file.path(repo, "output/publish/exploratory_fatigue_trajectory_posterior_summary.csv")
if (file.exists(fat_rds) && file.exists(fat_csv)) {
  fat_fit <- readRDS(fat_rds); fat_draws <- as_draws_df(fat_fit)
  fat_tbl <- read_csv(fat_csv, show_col_types = FALSE) %>%
    mutate(q2.5 = as.numeric(sub("\\[(-?[0-9.]+),.*", "\\1", CrI_95)),
           q97.5 = as.numeric(sub(".*,\\s*(-?[0-9.]+)\\]", "\\1", CrI_95)))
  label_map <- c("b_age_z" = "Age", "b_block_halfSecond_Half" = "Block half: 2nd vs 1st",
                 "b_effort_conditionHigh_40_MVC" = "Effort: High vs Low",
                 "b_bs_block_halfSecond_Half" = "Block half: 2nd vs 1st [*]",
                 "b_bs_effort_conditionHigh_40_MVC" = "Effort: High vs Low",
                 "b_bs_effort_conditionHigh_40_MVC:block_halfSecond_Half" = "Effort x Block half")
  fat_forest <- fat_tbl %>% mutate(label = label_map[parameter], credible = as.logical(excludes0)) %>%
    filter(!is.na(label)) %>% group_by(parameter_type) %>% arrange(median) %>% ungroup() %>%
    mutate(label = factor(label, levels = unique(label)))
  p_forest <- ggplot(fat_forest, aes(x = median, y = label, color = parameter_type)) +
    geom_vline(xintercept = 0, linetype = "dashed", colour = unname(stat_colors["zero_line"])) +
    geom_errorbarh(aes(xmin = q2.5, xmax = q97.5), height = 0.3, alpha = 0.7) +
    geom_point(aes(shape = credible, size = credible)) +
    scale_color_manual(values = fatigue_param_colors, guide = "none") +
    scale_shape_manual(values = c("TRUE" = 16, "FALSE" = 21), guide = "none") +
    scale_size_manual(values = c("TRUE" = 3.2, "FALSE" = 2.2), guide = "none") +
    facet_grid(parameter_type ~ ., scales = "free_y", space = "free_y") +
    labs(x = "Posterior estimate", y = NULL) + theme_minimal(base_size = 10)
  bs_int <- fat_draws[["Intercept_bs"]]; bs_bh <- fat_draws[["b_bs_block_halfSecond_Half"]]
  bs_eff <- fat_draws[["b_bs_effort_conditionHigh_40_MVC"]]
  bs_intx <- fat_draws[["b_bs_effort_conditionHigh_40_MVC:block_halfSecond_Half"]]
  cell_summary <- tibble(`Low effort 1st half` = exp(bs_int), `Low effort 2nd half` = exp(bs_int + bs_bh),
                         `High effort 1st half` = exp(bs_int + bs_eff),
                         `High effort 2nd half` = exp(bs_int + bs_eff + bs_bh + bs_intx)) %>%
    pivot_longer(everything(), names_to = "cell", values_to = "boundary") %>%
    group_by(cell) %>% summarise(med = median(boundary), lo = quantile(boundary, .025),
                                 hi = quantile(boundary, .975), .groups = "drop") %>%
    mutate(effort = if_else(grepl("High", cell), "High effort (40% MVC)", "Low effort (5% MVC)"),
           half = factor(if_else(grepl("1st", cell), "1st Half", "2nd Half"), levels = c("1st Half", "2nd Half")))
  p_bound_traj <- ggplot(cell_summary, aes(x = half, y = med, colour = effort, group = effort)) +
    geom_ribbon(aes(ymin = lo, ymax = hi, fill = effort), alpha = 0.15, colour = NA) +
    geom_line(linewidth = 0.9) + geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.08) + geom_point(size = 3.5) +
    scale_color_manual(values = fatigue_effort_colors, name = NULL) +
    scale_fill_manual(values = fatigue_effort_colors, guide = "none") +
    coord_cartesian(ylim = c(1.88, 2.20)) +
    labs(x = "Session half", y = "Boundary separation (exp scale)") + theme_minimal(base_size = 10)
  save_manuscript_fig(p_forest + p_bound_traj + plot_layout(widths = c(1.55, 1), guides = "collect") &
                        theme(legend.position = "bottom"), "fig_fatigue_posteriors", 11, 7.5)
}

beh_file <- file.path(repo, "data/ddm_ready_data_unthresholded.csv")
if (file.exists(beh_file)) {
  beh <- read_csv(beh_file, show_col_types = FALSE)
  brinley_data <- beh %>%
    filter(!is.na(rt), rt > 0, rt < 10, !is.na(difficulty_level), !is.na(effort_condition)) %>%
    group_by(subject_id, difficulty_level, effort_condition) %>%
    summarise(mean_rt = mean(rt, na.rm = TRUE), .groups = "drop") %>%
    pivot_wider(names_from = difficulty_level, values_from = mean_rt, names_prefix = "mean_rt_") %>%
    filter(!is.na(mean_rt_Easy), !is.na(mean_rt_Hard)) %>%
    mutate(mean_rt_Easy_ms = mean_rt_Easy * 1000, mean_rt_Hard_ms = mean_rt_Hard * 1000)
  effort_levs <- unique(brinley_data$effort_condition)
  high_eff <- effort_levs[grepl("High|40", effort_levs, ignore.case = TRUE)][1]
  low_eff  <- effort_levs[grepl("Low|5", effort_levs, ignore.case = TRUE)][1]
  color_map <- setNames(c(unname(effort_colors["High"]), unname(effort_colors["Low"])),
                        c(as.character(high_eff), as.character(low_eff)))
  save_manuscript_fig(
    ggplot(brinley_data, aes(x = mean_rt_Easy_ms, y = mean_rt_Hard_ms)) +
      geom_point(aes(color = effort_condition), size = 1.5, alpha = 0.7) +
      geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = unname(stat_colors["zero_line"])) +
      geom_smooth(method = "lm", se = TRUE, color = unname(stat_colors["empirical"]), linewidth = 0.7, alpha = 0.2) +
      scale_color_manual(values = color_map, labels = c("High Effort", "Low Effort")) +
      labs(x = "Mean RT: Easy Trials (ms)", y = "Mean RT: Hard Trials (ms)") +
      theme_minimal(base_size = 12) + theme(legend.position = "bottom"),
    "fig_brinley_plot", 7, 6)
  rt_plot_data <- beh %>% filter(!is.na(rt), rt > 0, rt <= 3) %>%
    mutate(Task = case_when(task == "aud" ~ "ADT", task == "vis" ~ "VDT", TRUE ~ as.character(task)),
           Difficulty = factor(difficulty_level, levels = c("Standard", "Easy", "Hard")),
           Effort = factor(case_when(effort_condition %in% c("Low", "Low_5_MVC") ~ "Low",
                                     effort_condition %in% c("High", "High_40_MVC") ~ "High",
                                     TRUE ~ as.character(effort_condition)), levels = c("Low", "High")),
           Condition = factor(paste(Difficulty, Effort, sep = " - "),
                              levels = c("Standard - Low", "Standard - High", "Easy - Low",
                                         "Easy - High", "Hard - Low", "Hard - High")))
  save_manuscript_fig(
    ggplot(rt_plot_data, aes(x = rt, fill = Effort, color = Effort)) +
      geom_density(linewidth = 0.9, alpha = 0.5) + facet_grid(Condition ~ Task) +
      scale_fill_manual(values = effort_colors) + scale_color_manual(values = effort_colors) +
      labs(x = "Reaction Time (s)", y = "Density") + theme_minimal(base_size = 12),
    "fig_rt_distribution", 8, 8)
}

loo_path <- file.path(run_dir, "tables/loo_summary.csv")
if (file.exists(loo_path)) {
  loo_summary <- read_csv(loo_path, show_col_types = FALSE) %>%
    {if ("model_name" %in% names(.)) rename(., model = model_name) else .} %>%
    {if ("rt_def" %in% names(.)) rename(., rt_type = rt_def) else .} %>%
    {if ("loo_ic" %in% names(.)) rename(., looic = loo_ic) else .} %>%
    {if ("loo_se" %in% names(.)) rename(., looic_se = loo_se) else .} %>%
    filter(threshold == PRIMARY_THR) %>%
    mutate(model_label = if_else(model == "baseline", "Baseline", "Additive"),
           rt_label = if_else(rt_type == "cue_locked", "Cue-locked", "Probe-onset-locked"))
  save_manuscript_fig(
    ggplot(loo_summary, aes(x = model_label, y = looic, color = rt_label)) +
      geom_pointrange(aes(ymin = looic - looic_se, ymax = looic + looic_se), position = position_dodge(0.3)) +
      scale_color_manual(values = c("Cue-locked" = unname(effort_colors["Low"]),
                                  "Probe-onset-locked" = unname(effort_colors["High"]))) +
      labs(x = "Model", y = "LOOIC") + theme_minimal(base_size = 12) + theme(legend.position = "bottom"),
    "fig_loo_comparison", 7, 4.5)
}

if (!is.null(pred_params)) {
  drift_suppl <- pred_params %>% filter(model == PRIMARY_MODEL, rt_type == PRIMARY_RT, threshold == PRIMARY_THR) %>%
    mutate(difficulty = factor(difficulty, levels = c("Standard", "Easy", "Hard")),
           effort = factor(effort, levels = c("Low", "High")), task = factor(task, levels = c("ADT", "VDT")))
  save_manuscript_fig(
    ggplot(drift_suppl, aes(x = difficulty, y = drift_median, color = effort, group = effort)) +
      geom_hline(yintercept = 0, linetype = "dashed", color = unname(stat_colors["zero_line"]), alpha = 0.5) +
      geom_pointrange(aes(ymin = drift_q2.5, ymax = drift_q97.5), position = position_dodge(0.3)) +
      geom_line(position = position_dodge(0.3), alpha = 0.5) +
      facet_wrap(~task) + scale_color_manual(values = effort_colors) +
      labs(x = "Difficulty", y = "Drift Rate (v)") + theme_minimal(base_size = 12) + theme(legend.position = "bottom"),
    "fig_suppl_drift_by_task", 8, 4)
  save_manuscript_fig(
    ggplot(drift_suppl, aes(x = difficulty, y = a_median, color = effort, group = effort)) +
      geom_pointrange(aes(ymin = a_q2.5, ymax = a_q97.5), position = position_dodge(0.3)) +
      geom_line(position = position_dodge(0.3), alpha = 0.5) +
      facet_wrap(~task) + scale_color_manual(values = effort_colors) +
      labs(x = "Difficulty", y = "Boundary Separation (a)") + theme_minimal(base_size = 12) + theme(legend.position = "bottom"),
    "fig_suppl_boundary_by_task", 8, 4)
  drift_forest <- drift_suppl %>% group_by(difficulty) %>%
    summarise(drift_median = mean(drift_median), drift_q2.5 = mean(drift_q2.5), drift_q97.5 = mean(drift_q97.5), .groups = "drop") %>%
    mutate(difficulty = factor(difficulty, levels = c("Standard", "Easy", "Hard")))
  save_manuscript_fig(
    ggplot(drift_forest, aes(x = reorder(difficulty, drift_median), y = drift_median, color = difficulty)) +
      geom_hline(yintercept = 0, linetype = "dashed", color = unname(stat_colors["zero_line"])) +
      geom_pointrange(aes(ymin = drift_q2.5, ymax = drift_q97.5)) +
      scale_color_manual(values = diff_colors, guide = "none") + coord_flip() +
      labs(x = NULL, y = "Drift Rate (v)") + theme_bw(base_size = 12),
    "fig_a4_2a_drift_by_difficulty", 7, 4)
}

# Copy static schematic figures into palette folder (design assets; not ggplot)
static_figs <- c(
  "Trial_Structure.png", "AUC_timeline_v2.png", "matrix.png",
  "fig-ddm-dag-plate-2.png", "plot4_parameter_correlation.png"
)
for (f in static_figs) {
  src <- file.path(repo, "output/figures", f)
  if (file.exists(src)) {
    file.copy(src, file.path(out_palette, f), overwrite = TRUE)
    message("Copied static: ", f)
  }
}

cat("\nDone. Figures in: ", out_palette, "\n", sep = "")
