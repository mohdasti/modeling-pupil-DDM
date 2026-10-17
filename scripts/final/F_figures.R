# Part F. Figures from the Part T tables.
# Run from the repo root: Rscript scripts/final/F_figures.R

options(warn = 1)
suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(patchwork)
  library(tibble)
})

ROOT <- normalizePath(getwd(), mustWork = TRUE)
setwd(ROOT)
source(file.path(ROOT, "R", "colors_manuscript.R"))
source(file.path(ROOT, "R", "fig_save_utils.R"))

FINAL <- "output/ddm_refits/runs/final_20261016"
TAB <- file.path(FINAL, "tables", "final")
FIG <- file.path(FINAL, "figures", "final")
INV <- "output/diagnostics/final_exports"
dir.create(FIG, recursive = TRUE, showWarnings = FALSE)

REVISE_STEMS <- c(
  "F1_design_model", "F3_effort_forest", "F5_pupil_boundary",
  "S_participant_flow", "S_ppc_M4", "S_ndt_prior_posterior", "S_tepr_timecourse"
)
revise_only <- Sys.getenv("REVISE_ONLY", "") == "1"
save_final <- function(plot, stem, width, height, source_note) {
  if (revise_only && !stem %in% REVISE_STEMS) return(invisible(NULL))
  only <- Sys.getenv("FIG_ONLY", "")
  if (nzchar(only) && !stem %in% strsplit(only, ",", fixed = TRUE)[[1]]) {
    return(invisible(NULL))
  }
  png_path <- file.path(FIG, paste0(stem, ".png"))
  if (capabilities("cairo")) {
    ggsave(
      png_path, plot, width = width, height = height, dpi = 300,
      device = function(filename, width, height, ...) {
        grDevices::png(
          filename, width = width, height = height,
          units = "in", res = 300, type = "cairo"
        )
      }
    )
  } else {
    save_manuscript_fig(plot, stem, width, height, dpi = 300, out_dir = FIG, also_legacy = FALSE)
  }
  if (capabilities("cairo")) {
    ggsave(
      file.path(FIG, paste0(stem, ".pdf")), plot,
      width = width, height = height, device = grDevices::cairo_pdf
    )
  }
  writeLines(source_note, file.path(FIG, paste0(stem, "_source.txt")))
}

theme_ms <- function() {
  theme_classic(base_size = 11) +
    theme(
      panel.grid = element_blank(),
      strip.background = element_blank(),
      strip.text = element_text(face = "bold"),
      legend.position = "bottom"
    )
}

# ---------------------------------------------------------------------------
# F1. Keep panels A and B from the existing Fig 1 script. Redo panel C.
# ---------------------------------------------------------------------------
message("F1")
fig1_lines <- readLines("06_visualization/publication_figures/fig1_design_schematic.R")
# Panel B only: drop the numeric non-decision-time annotation. The schematic geometry stays.
# The source file stores the subscript as the characters \u2080; parse() would turn that into a glyph
# the PDF font cannot draw, so both labels become the ASCII name.
fig1_lines <- gsub('label = "t\\u2080"', 'label = "t0"', fig1_lines, fixed = TRUE)
fig1_lines <- sub(
  'label = sprintf\\(.*ndt\\)',
  'label = "t0"',
  fig1_lines
)
cut_at <- grep("Panel C: predictor map \\(matrix", fig1_lines)[1]
fig1_env <- new.env(parent = globalenv())
eval(parse(text = fig1_lines[seq_len(cut_at - 1)]), envir = fig1_env)

param_ids <- c("v", "a", "t0", "z")
param_cols <- unname(param_colors[param_ids])
names(param_cols) <- param_ids
predictors <- c("Difficulty", "Difficulty x task", "Task", "Effort", "Effort x stimulus")
cell_of <- function(predictor, param) {
  key <- paste(predictor, param)
  checked <- c(
    "Difficulty v", "Difficulty a",
    "Difficulty x task v",
    "Task v", "Task a", "Task z",
    "Effort v", "Effort a", "Effort z",
    "Effort x stimulus v"
  )
  if (key %in% checked) return("check")
  if (predictor == "Difficulty" && param == "z") return("exclude")
  "dash"
}
note_of <- function(predictor, param) {
  key <- paste(predictor, param)
  notes <- c(
    "Difficulty v" = "main effect",
    "Difficulty a" = "main effect",
    "Difficulty x task v" = "modality\nshift",
    "Task v" = "main effect",
    "Task a" = "main effect",
    "Task z" = "main effect",
    "Effort v" = "drift\ncriterion",
    "Effort a" = "main effect",
    "Effort z" = "main effect",
    "Effort x stimulus v" = "evidence\nquality"
  )
  if (key %in% names(notes)) unname(notes[[key]]) else ""
}
grid_df <- tidyr::crossing(predictor = predictors, param = param_ids) %>%
  mutate(
    param_idx = match(param, param_ids),
    pred_idx = match(predictor, predictors),
    cell_type = mapply(cell_of, predictor, param),
    note = mapply(note_of, predictor, param),
    tile_fill = if_else(cell_type == "exclude", "#FFF7ED", "white"),
    text_color = case_when(
      cell_type == "check" ~ param,
      cell_type == "exclude" ~ "exclude",
      TRUE ~ "dash"
    ),
    cell_text = case_when(
      cell_type == "check" ~ paste0("Yes\n", note),
      cell_type == "exclude" ~ "No\nnot in M4",
      TRUE ~ "-"
    )
  )
header_df <- tibble(param_idx = seq_along(param_ids), label = c("Drift (v)", "Boundary (a)", "NDT (t0)", "Bias (z)"))
panel_c <- ggplot(grid_df, aes(x = param_idx, y = pred_idx)) +
  geom_tile(aes(fill = tile_fill), color = "#D1D5DB", linewidth = 0.35) +
  scale_fill_identity() +
  geom_text(aes(label = cell_text, color = text_color), size = 2.6, lineheight = 0.85, fontface = "bold") +
  geom_text(
    data = header_df, aes(x = param_idx, y = 0.35, label = label), inherit.aes = FALSE,
    color = unname(param_cols[header_df$param_idx]), size = 2.8, fontface = "bold"
  ) +
  scale_color_manual(values = c(param_cols, dash = "#9CA3AF", exclude = "#B45309"), guide = "none") +
  scale_x_continuous(limits = c(0.45, 4.55), expand = c(0, 0)) +
  scale_y_reverse(breaks = seq_along(predictors), labels = predictors, limits = c(length(predictors) + 0.55, 0.15), expand = c(0, 0)) +
  labs(
    title = "C", x = NULL, y = NULL,
    caption = "N = 67 participants, 17,857 trials. Non-decision time is an intercept only."
  ) +
  fig1_env$theme_manuscript() +
  theme(
    axis.line = element_blank(), axis.ticks = element_blank(), axis.text.x = element_blank(),
    axis.text.y = element_text(size = 8, color = "black", face = "bold"),
    plot.caption = element_text(size = 7, color = "#6B7280", hjust = 0),
    plot.margin = margin(4, 6, 8, 4)
  )
fig_w_mm <- 230
panel_a_h_mm <- fig_w_mm / fig1_env$trial_asp
panel_bc_h_mm <- 78
fig1 <- fig1_env$panel_a + fig1_env$panel_b + panel_c +
  plot_layout(design = "AA\nBC", heights = c(panel_a_h_mm, panel_bc_h_mm), widths = c(1.15, 1.45))
ggsave(file.path(FIG, "F1_design_model.png"), fig1, width = fig_w_mm, height = panel_a_h_mm + panel_bc_h_mm, units = "mm", dpi = 300)
ggsave(file.path(FIG, "F1_design_model.pdf"), fig1, width = fig_w_mm, height = panel_a_h_mm + panel_bc_h_mm, units = "mm")
writeLines(
  "Panels A and B from 06_visualization/publication_figures/fig1_design_schematic.R. Panel C rebuilt for the M4 predictor map. Units mm.",
  file.path(FIG, "F1_design_model_source.txt")
)

# ---------------------------------------------------------------------------
# F2 condition parameters
# ---------------------------------------------------------------------------
message("F2")
t3 <- read_csv(file.path(TAB, "T3_condition_cells_M4.csv"), show_col_types = FALSE) %>%
  filter(quantity %in% c("v", "a")) %>%
  mutate(
    difficulty_3 = factor(difficulty_3, levels = c("Standard", "Hard", "Easy")),
    effort_label = ifelse(effort_condition == "high", "High", "Low"),
    quantity = factor(quantity, levels = c("v", "a"), labels = c("Drift rate (v)", "Boundary (a)"))
  )
v_panels <- t3 %>% filter(grepl("Drift", quantity))
f2 <- ggplot(t3, aes(x = difficulty_3, y = median, color = effort_label, group = effort_label)) +
  geom_hline(data = v_panels, aes(yintercept = 0), linetype = "dashed", color = stat_colors["zero_line"], linewidth = 0.3) +
  geom_pointrange(aes(ymin = q2.5, ymax = q97.5), position = position_dodge(width = 0.35), linewidth = 0.4, size = 0.35) +
  scale_color_manual(values = effort_colors, name = "Effort") +
  facet_grid(quantity ~ task, scales = "free_y") +
  labs(x = "Difficulty", y = "Posterior median and 95% CrI") +
  theme_ms()
save_final(f2, "F2_condition_parameters", 7.2, 6.2, "T3_condition_cells_M4.csv, quantities v and a.")

# ---------------------------------------------------------------------------
# F3 effort forest
# ---------------------------------------------------------------------------
message("F3")
term_levels <- c(
  "b_effort_conditionhigh", "b_effort_x_stim",
  "b_bs_effort_conditionhigh", "b_bias_effort_conditionhigh"
)
model_order <- c("M4", "M4r", "M4_thr0.15", "M4_thr0.25", "M4_subchance")
t6_raw <- read_csv(file.path(TAB, "T6a_robustness_effort_terms.csv"), show_col_types = FALSE)
fail_rhat <- function(model_id) {
  rows <- t6_raw[t6_raw$model == model_id, , drop = FALSE]
  nrow(rows) > 0 && any(rows$max_rhat >= 1.01)
}
# First factor level is drawn at the bottom, so reverse the requested top-to-bottom order.
model_lab_top <- c(
  "M4 (primary)",
  "Random effort slopes",
  if (fail_rhat("M4_thr0.15")) "RT cutoff 0.15 s\u2021" else "RT cutoff 0.15 s",
  "RT cutoff 0.25 s",
  "Near-chance excluded (N = 54)"
)
model_lab <- c(
  M4 = model_lab_top[1], M4r = model_lab_top[2], M4_thr0.15 = model_lab_top[3],
  M4_thr0.25 = model_lab_top[4], M4_subchance = model_lab_top[5]
)
t6 <- t6_raw %>%
  filter(term %in% term_levels, model %in% model_order) %>%
  mutate(
    term = factor(term, levels = term_levels),
    model = factor(model, levels = model_order),
    fail_rhat = max_rhat >= 1.01,
    model_lab = factor(unname(model_lab[as.character(model)]), levels = rev(model_lab_top))
  )
draw_forest <- function(term_id, title, axis_lab, show_y) {
  d <- t6 %>% filter(term == term_id)
  rope_hw <- unique(d$rope_halfwidth)
  stopifnot(length(rope_hw) == 1L)
  lo <- min(c(d$q2.5, -1.4 * rope_hw))
  hi <- max(c(d$q97.5, 1.4 * rope_hw))
  has_axis <- !is.null(axis_lab) && nzchar(axis_lab)
  ggplot(d, aes(x = median, y = model_lab)) +
    geom_rect(
      aes(xmin = -rope_hw, xmax = rope_hw, ymin = -Inf, ymax = Inf),
      inherit.aes = FALSE, fill = "#E5E7EB"
    ) +
    geom_vline(xintercept = 0, color = stat_colors["zero_line"], linewidth = 0.3) +
    geom_errorbar(
      aes(
        xmin = q2.5, xmax = q97.5,
        linewidth = model == "M4",
        linetype = fail_rhat
      ),
      orientation = "y", width = 0.18, color = "#374151"
    ) +
    geom_point(aes(shape = model == "M4", size = model == "M4"), fill = "white", color = "#111827") +
    scale_shape_manual(values = c(`TRUE` = 16, `FALSE` = 21), guide = "none") +
    scale_size_manual(values = c(`TRUE` = 2.4, `FALSE` = 1.6), guide = "none") +
    scale_linewidth_manual(values = c(`TRUE` = 0.7, `FALSE` = 0.3), guide = "none") +
    scale_linetype_manual(values = c(`TRUE` = "dashed", `FALSE` = "solid"), guide = "none") +
    scale_x_continuous(limits = c(lo, hi), expand = expansion(mult = 0.06)) +
    labs(
      title = title,
      x = if (has_axis) axis_lab else " ",
      y = NULL
    ) +
    theme_ms() +
    theme(
      legend.position = "none",
      plot.title = element_text(face = "bold", size = 11, hjust = 0.5),
      axis.title.x = element_text(size = 7.5, color = if (has_axis) "#374151" else "white"),
      axis.text.y = if (show_y) element_text(size = 8) else element_blank(),
      axis.ticks.y = if (show_y) element_line() else element_blank()
    )
}
axis_same <- "\u2190 toward 'same'          toward 'different' \u2192"
axis_quality <- "\u2190 lower evidence quality / higher evidence quality \u2192"
f3 <- draw_forest("b_effort_conditionhigh", "Drift criterion", axis_same, TRUE) +
  draw_forest("b_effort_x_stim", "Evidence quality", axis_quality, FALSE) +
  draw_forest("b_bs_effort_conditionhigh", "Boundary separation", "(log scale)", FALSE) +
  draw_forest("b_bias_effort_conditionhigh", "Starting point", "(logit scale)", FALSE) +
  plot_layout(nrow = 1)
if (any(t6$fail_rhat)) {
  f3 <- f3 + plot_annotation(caption = "\u2021 did not meet the R-hat < 1.01 criterion")
}
save_final(
  f3, "F3_effort_forest", 12.2, 4.6,
  paste(
    "T6a_robustness_effort_terms.csv (the M4 rows are the same estimates as T2).",
    "Shaded band is the ROPE: drift \u00b10.02, log boundary and logit starting point \u00b10.05.",
    "Each x-axis includes at least 1.4 times the ROPE half-width on both sides, and is widened further when a credible interval extends past that.",
    "Rows from top to bottom: M4 (primary), random effort slopes, RT cutoff 0.15 s, RT cutoff 0.25 s, near-chance excluded (N = 54).",
    "The drift-criterion axis uses same/different. The evidence-quality axis uses lower/higher evidence quality, because that coefficient is the effort by stimulus interaction.",
    "Boundary and starting-point axes are labeled log scale and logit scale.",
    "A row is an open dashed interval, and carries a dagger, only when its max R-hat is at least 1.01.",
    sep = " "
  )
)

# ---------------------------------------------------------------------------
# F4 Brinley
# ---------------------------------------------------------------------------
message("F4")
beh <- read_csv(file.path(FINAL, "data/ddm_behavioral_r5_full17857.csv"), show_col_types = FALSE)
brinley <- beh %>%
  filter(difficulty_3 %in% c("Easy", "Hard"), is.finite(rt), rt > 0, rt < 10) %>%
  group_by(subject_id, difficulty_3) %>%
  summarise(mean_rt = mean(rt), .groups = "drop") %>%
  pivot_wider(names_from = difficulty_3, values_from = mean_rt) %>%
  filter(is.finite(Easy), is.finite(Hard)) %>%
  mutate(Easy = Easy * 1000, Hard = Hard * 1000)
slope <- coef(lm(Hard ~ Easy, data = brinley))[["Easy"]]
f4 <- ggplot(brinley, aes(x = Easy, y = Hard)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = stat_colors["zero_line"]) +
  geom_smooth(method = "lm", se = TRUE, color = stat_colors["empirical"], fill = "#E5E7EB", linewidth = 0.55) +
  geom_point(color = stat_colors["empirical"], size = 1.7, alpha = 0.7) +
  labs(
    x = "Mean RT: Easy trials (ms)", y = "Mean RT: Hard trials (ms)",
    caption = sprintf("slope = %.2f", slope)
  ) +
  theme_ms() + theme(legend.position = "none")
save_final(f4, "F4_brinley", 5.4, 5.2, "Primary 17,857-trial file. One point per participant, Hard vs Easy mean RT, pooled across task and effort.")

# ---------------------------------------------------------------------------
# F5 pupil boundary slopes
# ---------------------------------------------------------------------------
message("F5")
iv_fig <- readRDS(file.path(TAB, "inline_values.rds"))
tepr_post <- iv_fig$tepr_window_post_probe
if (is.null(tepr_post) || !nzchar(as.character(tepr_post))) {
  stop("tepr_window_post_probe is missing from inline values")
}
tepr_post <- as.character(tepr_post)
tepr_after <- sub(" s$", " s after probe", tepr_post)
fmt_elpd_lab <- function(delta, se) {
  one <- function(x) {
    s <- sprintf("%.1f", x)
    if (!is.na(suppressWarnings(as.numeric(s))) && as.numeric(s) == 0) {
      sub("^-", "", s)
    } else {
      sub("-", "\u2212", s)
    }
  }
  paste0(one(delta), " \u00b1 ", one(se))
}
# Top-to-bottom within each group. Factor levels are stored bottom-to-top.
f5_order <- c("P8", "P5", "P6", "P7", "P3_rt", "P3")
f5_labels <- c(
  P3 = paste0("Post-probe TEPR (", tepr_after, ")"),
  P3_rt = "Post-probe TEPR, slowest 20% removed",
  P7 = "Pre-response window (0.5 s)",
  P6 = "Previous-trial TEPR",
  P5 = "Pre-trial baseline pupil",
  P8 = "Grip-period pupil"
)
f5_groups <- c(
  P3 = "Within the current trial", P3_rt = "Within the current trial", P7 = "Within the current trial",
  P6 = "Precedes the current decision", P5 = "Precedes the current decision", P8 = "Precedes the current decision"
)
t8 <- read_csv(file.path(TAB, "T8_pupil_ordering.csv"), show_col_types = FALSE) %>%
  mutate(
    model = as.character(model),
    row_lab = factor(unname(f5_labels[model]), levels = unname(f5_labels[f5_order])),
    group = factor(unname(f5_groups[model]), levels = c("Within the current trial", "Precedes the current decision")),
    elpd_lab = mapply(fmt_elpd_lab, delta_elpd_vs_baseline, se_delta_elpd, USE.NAMES = FALSE)
  )
stopifnot(setequal(t8$model, names(f5_labels)))
f5_forest <- ggplot(t8, aes(x = pct_change_median, y = row_lab)) +
  geom_vline(xintercept = 0, color = stat_colors["zero_line"]) +
  geom_errorbar(
    aes(xmin = pct_change_q2.5, xmax = pct_change_q97.5),
    orientation = "y", width = 0.18, linewidth = 0.45, color = "#374151"
  ) +
  geom_point(size = 2.2, color = "#111827") +
  facet_grid(group ~ ., scales = "free_y", space = "free_y") +
  labs(title = " ", x = "Change in boundary per SD of the pupil predictor (%)", y = NULL) +
  theme_ms() +
  theme(
    legend.position = "none",
    plot.title = element_text(size = 11, face = "bold", color = "white"),
    strip.text.y = element_text(angle = 0, face = "bold", size = 9)
  )
f5_elpd <- ggplot(t8, aes(x = 1, y = row_lab, label = elpd_lab)) +
  geom_text(size = 3.1, hjust = 0.5) +
  facet_grid(group ~ ., scales = "free_y", space = "free_y") +
  scale_x_continuous(limits = c(0.7, 1.3), expand = c(0, 0)) +
  labs(title = "\u0394ELPD \u00b1 SE", x = " ", y = NULL) +
  theme_ms() +
  theme(
    legend.position = "none",
    axis.text = element_blank(),
    axis.ticks = element_blank(),
    axis.line = element_blank(),
    axis.title.x = element_text(color = "white", size = 11),
    strip.text = element_blank(),
    plot.title = element_text(size = 11, face = "bold", hjust = 0.5)
  )
f5 <- f5_forest + f5_elpd + plot_layout(widths = c(4.6, 1.15))
save_final(
  f5, "F5_pupil_boundary", 10.4, 5.4,
  paste(
    "T8_pupil_ordering.csv.",
    "P3 is compared with P0. P5 is compared with P0_base.",
    "P3_rt, P6, P7, and P8 use the matched baselines stored in T8 (P0_rt, P0_lag, P0_pre, P0_grip).",
    "The post-probe window text is tepr_window_post_probe from inline_values.rds.",
    "The right-hand column is delta ELPD at one decimal, with a Unicode minus. A negative zero is printed as 0.0.",
    "Labels replace the model codes. Within each group the order is the order in the figure request.",
    sep = " "
  )
)

# ---------------------------------------------------------------------------
# S-flow
# ---------------------------------------------------------------------------
message("S-flow")
flow_tbl <- read_csv(file.path(TAB, "T12b_participant_flow.csv"), show_col_types = FALSE)
flow_n <- function(node, col) {
  hit <- flow_tbl[flow_tbl$node == node, col, drop = TRUE]
  stopifnot(length(hit) == 1L, is.finite(hit))
  as.numeric(hit)
}
# Cue-locked RT is the `rt` column of the unthresholded file (probe-onset RT is a different column and is never below 0.20 s).
unthr <- read_csv("data/ddm_ready_data_unthresholded.csv", col_select = "rt", show_col_types = FALSE)
n_collected <- nrow(unthr)
n_cue_excluded <- sum(unthr$rt < 0.20)
n_cue_kept <- sum(unthr$rt >= 0.20)
stopifnot(n_collected == flow_n("behavioral_trials_collected", "n_trials"))
stopifnot(n_cue_kept == flow_n("primary_analysis_trials", "n_trials"))
raw_beh <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v3.csv"
raw_note <- "The Nov2025 raw trial file was not on disk, so the cue-locked count was not repeated there."
if (file.exists(raw_beh)) {
  raw_dt <- read_csv(
    raw_beh,
    col_select = c("same_diff_resp_secs", "resp_is_diff", "resp_is_correct"),
    show_col_types = FALSE
  )
  responded <- raw_dt %>%
    filter(is.finite(same_diff_resp_secs), same_diff_resp_secs > 0, is.finite(resp_is_diff), is.finite(resp_is_correct))
  raw_note <- sprintf(
    "Raw file bap_beh_trialdata_v3.csv: %d rows, %d with a positive cue-locked response, %d of those below 0.20 s, %d at or above 0.20 s.",
    nrow(raw_dt), nrow(responded), sum(responded$same_diff_resp_secs < 0.20), sum(responded$same_diff_resp_secs >= 0.20)
  )
  stopifnot(sum(responded$same_diff_resp_secs < 0.20) == n_cue_excluded)
  stopifnot(sum(responded$same_diff_resp_secs >= 0.20) == n_cue_kept)
}
message(sprintf("Cue-locked RT < 0.20 s: %d of %d collected trials.", n_cue_excluded, n_collected))
message(raw_note)
acc_subj <- beh %>%
  mutate(correct = as.integer(
    (difficulty_3 == "Standard" & choice_binary == 0) |
      (difficulty_3 != "Standard" & choice_binary == 1)
  )) %>%
  group_by(subject_id) %>%
  summarise(accuracy = mean(correct), n = n(), .groups = "drop")
n_near <- sum(acc_subj$accuracy <= 0.55)
n_near_trials <- sum(acc_subj$n[acc_subj$accuracy > 0.55])
n_near_subj <- sum(acc_subj$accuracy > 0.55)
stopifnot(n_near == 13L, n_near_subj == 54L, n_near_trials == 14642L)
fmt_n <- function(x) format(x, big.mark = ",", scientific = FALSE)
box_df <- function(id, x, y, w, h, label, linetype = "solid", fill = "white") {
  tibble(
    id = id, x = x, y = y,
    xmin = x - w / 2, xmax = x + w / 2, ymin = y - h / 2, ymax = y + h / 2,
    label = label, linetype = linetype, fill = fill
  )
}
n_adt_subj <- flow_n("task_ADT", "n_subjects")
n_adt_tri <- flow_n("task_ADT", "n_trials")
n_vdt_subj <- flow_n("task_VDT", "n_subjects")
n_vdt_tri <- flow_n("task_VDT", "n_trials")
xc <- 5.35
xl <- 1.75
xr <- 9.95
boxes <- bind_rows(
  box_df("enrolled", xc, 19.2, 4.0, 1.15, "Enrolled\n69"),
  box_df("excl2", xl, 17.65, 3.0, 1.4, "Excluded: 2\nMCI, 1\nTremor, 1", fill = "#F3F4F6"),
  box_df("analyzed", xc, 16.05, 4.0, 1.15, "Analyzed\n67 participants"),
  box_df("collected", xc, 13.65, 4.0, 1.2, sprintf("Trials collected\n%s", fmt_n(n_collected))),
  box_df("excl240", xl, 12.1, 3.0, 1.3, sprintf("Excluded: %s\ncue-locked RT < 0.20 s", fmt_n(n_cue_excluded)), fill = "#F3F4F6"),
  box_df("primary", xc, 9.7, 4.2, 2.15, sprintf(
    "Primary analysis\n%s trials\nADT: %d participants, %s trials\nVDT: %d participants, %s trials",
    fmt_n(n_cue_kept), n_adt_subj, fmt_n(n_adt_tri), n_vdt_subj, fmt_n(n_vdt_tri)
  )),
  box_df("sensitivity", xc, 6.35, 4.2, 2.2, sprintf(
    "Sensitivity samples\nRT cutoff 0.15 s: %s trials\nRT cutoff 0.25 s: %s trials\nNear-chance excluded: %d participants, %s trials",
    fmt_n(flow_n("cutoff_0.15_trials", "n_trials")),
    fmt_n(flow_n("cutoff_0.25_trials", "n_trials")),
    n_near_subj, fmt_n(n_near_trials)
  ), linetype = "dashed", fill = "#FAFAFA"),
  box_df("matched", xr, 9.7, 3.6, 1.3, sprintf("Matched to a pupil recording\n%s trials (%d)", fmt_n(flow_n("pupil_matched", "n_trials")), flow_n("pupil_matched", "n_subjects"))),
  box_df("tepr", xr, 7.95, 3.6, 1.2, sprintf("TEPR present\n%s trials (%d)", fmt_n(flow_n("pupil_tepr_nonmissing", "n_trials")), flow_n("pupil_tepr_nonmissing", "n_subjects"))),
  box_df("baseline", xr, 6.25, 3.6, 1.2, sprintf("Baseline quality\n%s trials (%d)", fmt_n(flow_n("pupil_B1_quality_ge_0.50", "n_trials")), flow_n("pupil_B1_quality_ge_0.50", "n_subjects"))),
  box_df("window", xr, 4.55, 3.6, 1.2, sprintf("Window quality\n%s trials (%d)", fmt_n(flow_n("pupil_cog_quality_ge_0.50", "n_trials")), flow_n("pupil_cog_quality_ge_0.50", "n_subjects"))),
  box_df("min20", xr, 2.7, 3.6, 1.5, sprintf("At least 20 trials\nper participant and task\n%s trials (%d)", fmt_n(flow_n("pupil_subject_task_ge_20", "n_trials")), flow_n("pupil_subject_task_ge_20", "n_subjects")))
)
edge <- function(id, side) {
  b <- boxes[boxes$id == id, ]
  switch(side, top = b$ymax, bottom = b$ymin, left = b$xmin, right = b$xmax, cx = b$x, cy = b$y)
}
arr <- function(x, y, xend, yend, linetype = "solid") tibble(x, y, xend, yend, linetype)
arrows <- bind_rows(
  arr(edge("enrolled", "cx"), edge("enrolled", "bottom"), edge("analyzed", "cx"), edge("analyzed", "top")),
  arr(edge("enrolled", "cx"), edge("excl2", "cy"), edge("excl2", "right"), edge("excl2", "cy")),
  arr(edge("analyzed", "cx"), edge("analyzed", "bottom"), edge("collected", "cx"), edge("collected", "top")),
  arr(edge("collected", "cx"), edge("collected", "bottom"), edge("primary", "cx"), edge("primary", "top")),
  arr(edge("collected", "cx"), edge("excl240", "cy"), edge("excl240", "right"), edge("excl240", "cy")),
  arr(edge("primary", "right"), edge("matched", "cy"), edge("matched", "left"), edge("matched", "cy")),
  arr(edge("matched", "cx"), edge("matched", "bottom"), edge("tepr", "cx"), edge("tepr", "top")),
  arr(edge("tepr", "cx"), edge("tepr", "bottom"), edge("baseline", "cx"), edge("baseline", "top")),
  arr(edge("baseline", "cx"), edge("baseline", "bottom"), edge("window", "cx"), edge("window", "top")),
  arr(edge("window", "cx"), edge("window", "bottom"), edge("min20", "cx"), edge("min20", "top")),
  arr(edge("primary", "cx"), edge("primary", "bottom"), edge("sensitivity", "cx"), edge("sensitivity", "top"), "dashed")
)
sf <- ggplot() +
  geom_segment(
    data = arrows %>% filter(linetype == "solid"),
    aes(x = x, y = y, xend = xend, yend = yend),
    arrow = arrow(length = unit(1.8, "mm"), type = "closed"),
    linewidth = 0.35
  ) +
  geom_segment(
    data = arrows %>% filter(linetype != "solid"),
    aes(x = x, y = y, xend = xend, yend = yend),
    arrow = arrow(length = unit(1.8, "mm"), type = "closed"),
    linetype = "dashed", linewidth = 0.35, color = "#4B5563"
  ) +
  geom_rect(
    data = boxes,
    aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, linetype = linetype, fill = fill),
    color = "#111827", linewidth = 0.35
  ) +
  geom_text(data = boxes, aes(x = x, y = y, label = label), size = 2.45, lineheight = 0.92) +
  scale_linetype_identity() +
  scale_fill_identity() +
  coord_cartesian(xlim = c(0.05, 11.95), ylim = c(1.6, 20.05), clip = "off") +
  theme_void() +
  theme(
    plot.margin = margin(6, 8, 6, 6),
    plot.background = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "white", colour = NA)
  )
save_final(
  sf, "S_participant_flow", 8.6, 10.6,
  paste(
    "Counts other than the cue-locked exclusion come from T12b_participant_flow.csv.",
    sprintf("Cue-locked exclusion: %d of %d trials in data/ddm_ready_data_unthresholded.csv have rt < 0.20. That column is cue-locked RT; the probe-onset column in the same file is never below 0.20 s. The %d remaining trials match the primary file.", n_cue_excluded, n_collected, n_cue_kept),
    raw_note,
    sprintf("Near-chance sample recomputed from the primary file: overall accuracy <= 0.55 excludes %d participants and leaves %d participants and %s trials.", n_near, n_near_subj, fmt_n(n_near_trials)),
    "Pupil counts are the r5 QC gates in T12b. The dashed box is not a further exclusion from the primary analysis.",
    sep = " "
  )
)

# ---------------------------------------------------------------------------
# S-ppc
# ---------------------------------------------------------------------------
message("S-ppc")
t11a <- read_csv(file.path(TAB, "T11a_ppc_choice.csv"), show_col_types = FALSE) %>%
  filter(source_model == "M4") %>%
  mutate(cell = paste(task, difficulty_3, effort_condition))
pa <- ggplot(t11a, aes(x = pred_median, y = observed, color = task)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = stat_colors["zero_line"]) +
  geom_errorbarh(aes(xmin = pred_q2.5, xmax = pred_q97.5), height = 0, linewidth = 0.3) +
  geom_point(size = 2) +
  scale_color_manual(values = task_colors, name = "Task") +
  labs(title = "A", x = "Predicted P(different)", y = "Observed P(different)") +
  theme_ms()
t11b <- read_csv(file.path(TAB, "T11b_ppc_rt_quantiles.csv"), show_col_types = FALSE) %>%
  mutate(
    q = as.numeric(sub("rt_q", "", quantity)),
    effort_label = ifelse(effort_condition == "high", "High", "Low"),
    difficulty_3 = factor(difficulty_3, levels = c("Standard", "Easy", "Hard")),
    response = factor(ifelse(response == "same", "Same", "Different"), levels = c("Same", "Different"))
  ) %>%
  pivot_longer(c(observed, pred_median), names_to = "series_raw", values_to = "rt") %>%
  mutate(series = ifelse(series_raw == "observed", "Observed", "Predicted"))
pb <- ggplot(t11b, aes(x = q, y = rt, color = effort_label, linetype = series, group = interaction(effort_label, series))) +
  geom_line(linewidth = 0.45) +
  geom_point(size = 1.1) +
  facet_grid(task ~ response + difficulty_3) +
  scale_color_manual(
    values = c(Low = unname(effort_colors["Low"]), High = unname(effort_colors["High"])),
    name = "Effort"
  ) +
  scale_linetype_manual(values = c(Observed = "solid", Predicted = "dashed"), name = "Series") +
  labs(title = "B", x = "RT quantile", y = "RT (s)") +
  theme_ms() +
  theme(legend.position = "bottom")
save_final(
  pa / pb + plot_layout(heights = c(1, 1.6)),
  "S_ppc_M4", 11, 9.2,
  "Panel A: T11a_ppc_choice.csv, M4 rows, observed versus predicted P(different). Panel B: T11b_ppc_rt_quantiles.csv. One panel per task, response, and difficulty. Colour is effort. Solid lines are observed quantiles and dashed lines are predicted medians."
)

# ---------------------------------------------------------------------------
# S-ndt
# ---------------------------------------------------------------------------
message("S-ndt")
draws <- read_csv(file.path(FINAL, "draws/draws_M4.csv"), show_col_types = FALSE)
post <- exp(draws$b_ndt_Intercept)
min_rt <- min(beh$rt, na.rm = TRUE)
ub_sec <- min_rt - 0.01
ub <- log(ub_sec)
set.seed(2026)
cand <- rnorm(400000, log(0.35), 0.15)
prior <- exp(cand[cand > log(0.02) & cand < ub])
bound_lab <- "Upper bound"
p_post <- ggplot(tibble(t0 = post), aes(x = t0)) +
  geom_density(fill = unname(stat_colors["posterior"]), color = NA, adjust = 1.2) +
  geom_vline(xintercept = ub_sec, linetype = "dashed", linewidth = 0.4, color = "#111827") +
  annotate("text", x = ub_sec, y = Inf, label = bound_lab, hjust = 1.08, vjust = 1.4, size = 3) +
  scale_x_continuous(limits = c(min(post) - 0.004, ub_sec + 0.012)) +
  labs(title = "Posterior", x = "Non-decision time (s)", y = "Density") +
  theme_ms() + theme(legend.position = "none")
p_prior <- ggplot(tibble(t0 = prior), aes(x = t0)) +
  geom_density(fill = unname(stat_colors["prior"]), color = NA, adjust = 1.2) +
  geom_vline(xintercept = ub_sec, linetype = "dashed", linewidth = 0.4, color = "#111827") +
  annotate("text", x = ub_sec, y = Inf, label = bound_lab, hjust = 1.08, vjust = 1.4, size = 3) +
  labs(title = "Prior", x = "Non-decision time (s)", y = "Density") +
  theme_ms() + theme(legend.position = "none")
sn <- p_post / p_prior
save_final(
  sn, "S_ndt_prior_posterior", 6.2, 6.4,
  sprintf(
    "Posterior: M4 draws file draws_M4.csv, exp(b_ndt_Intercept). Prior: normal(log(0.35), 0.15) on the log scale, truncated to log(0.02) and log(min probe-locked RT - 0.01), then exponentiated. The prior is the r4 specification. The dashed line is the upper bound, min probe-locked RT in the primary file (%.4f s) minus 0.01 s = %.4f s. The prior is on its own panel because it is much wider than the posterior.",
    min_rt, ub_sec
  )
)

# ---------------------------------------------------------------------------
# S-caf and S-rtdist and S-acc
# ---------------------------------------------------------------------------
message("S-caf S-rtdist S-acc")
beh <- beh %>% mutate(correct = as.integer(
  (difficulty_3 == "Standard" & choice_binary == 0) |
    (difficulty_3 != "Standard" & choice_binary == 1)
))
caf <- beh %>%
  filter(is.finite(rt), rt > 0, rt < 10) %>%
  mutate(
    effort_label = ifelse(effort_condition == "high", "High", "Low"),
    difficulty_3 = factor(difficulty_3, levels = c("Standard", "Easy", "Hard"))
  ) %>%
  group_by(task, effort_label, difficulty_3) %>%
  mutate(bin = cut(rt, breaks = 5, labels = FALSE)) %>%
  filter(!is.na(bin)) %>%
  group_by(task, effort_label, difficulty_3, bin) %>%
  summarise(acc_emp = mean(correct), bin_rt_mid = mean(rt), .groups = "drop")
sc <- ggplot(caf, aes(x = bin_rt_mid, y = acc_emp, color = effort_label, group = effort_label)) +
  geom_point(size = 1.2) + geom_line(linewidth = 0.45) +
  scale_color_manual(values = effort_colors, name = "Effort") +
  facet_grid(task ~ difficulty_3) +
  scale_y_continuous(limits = c(0, 1)) +
  labs(x = "RT bin midpoint (s)", y = "Accuracy") +
  theme_ms()
save_final(sc, "S_caf", 9, 6.2, "Primary 17,857-trial file. Five RT bins within task x difficulty x effort. Standard trials included.")

rt_long <- beh %>%
  select(rt, rt_cue) %>%
  pivot_longer(everything(), names_to = "rt_type", values_to = "rt") %>%
  filter(is.finite(rt), rt > 0, rt < 5) %>%
  mutate(rt_type = ifelse(rt_type == "rt", "Probe-onset-locked RT", "Cue-locked RT"))
sr <- ggplot(rt_long, aes(x = rt, fill = rt_type)) +
  geom_histogram(bins = 50, alpha = 0.65, position = "identity") +
  scale_fill_manual(values = c("Cue-locked RT" = unname(effort_colors["Low"]), "Probe-onset-locked RT" = unname(effort_colors["High"]))) +
  facet_wrap(~ rt_type, ncol = 1) +
  labs(x = "Response time (s)", y = "Frequency") +
  theme_ms() + theme(legend.position = "none")
save_final(sr, "S_rt_distributions", 7, 5.2, "Primary 17,857-trial file, columns rt and rt_cue.")

acc <- read_csv(file.path(TAB, "T13a_accuracy_rt_descriptives.csv"), show_col_types = FALSE) %>%
  filter(record == "subject") %>%
  mutate(
    effort_label = ifelse(effort_condition == "high", "High", "Low"),
    difficulty_3 = factor(difficulty_3, levels = c("Standard", "Hard", "Easy"))
  )
means <- acc %>%
  group_by(task, difficulty_3, effort_label) %>%
  summarise(accuracy = mean(accuracy), .groups = "drop")
sa <- ggplot(acc, aes(x = difficulty_3, y = accuracy, group = interaction(subject_id, effort_label), color = effort_label)) +
  geom_line(alpha = 0.15, linewidth = 0.25) +
  geom_line(data = means, aes(group = effort_label), linewidth = 0.9) +
  geom_point(data = means, aes(group = effort_label), size = 2) +
  scale_color_manual(values = effort_colors, name = "Effort") +
  facet_wrap(~ task) +
  labs(x = "Difficulty", y = "Accuracy") +
  theme_ms()
save_final(sa, "S_accuracy_by_condition", 8, 4.6, "T13a_accuracy_rt_descriptives.csv, record = subject. Lines are participants. Points are the mean across participants.")

# ---------------------------------------------------------------------------
# S-dag copy. S-lc: copy the non-DDM figure; redraw the panel whose y is boundary.
# S-tepr is not drawn: the cached waveforms are not the 4,569-trial QC set.
# ---------------------------------------------------------------------------
message("S-dag S-lc")
dag_from <- "output/figures/manuscript_palette/fig-ddm-dag-plate-2.png"
file.copy(dag_from, file.path(FIG, "S_dag_plate.png"), overwrite = TRUE)
if (file.exists("output/figures/manuscript_palette/fig-ddm-dag-plate-2.pdf")) {
  file.copy("output/figures/manuscript_palette/fig-ddm-dag-plate-2.pdf", file.path(FIG, "S_dag_plate.pdf"), overwrite = TRUE)
}
writeLines("Copied unchanged from output/figures/manuscript_palette/fig-ddm-dag-plate-2.png.", file.path(FIG, "S_dag_plate_source.txt"))

dprime_png <- "output/figures/manuscript_palette/fig_lc_fiso_dprime_variability.png"
file.copy(dprime_png, file.path(FIG, "S_lc_fiso_dprime_variability.png"), overwrite = TRUE)
dprime_pdf <- "output/figures/manuscript_palette/fig_lc_fiso_dprime_variability.pdf"
if (file.exists(dprime_pdf)) file.copy(dprime_pdf, file.path(FIG, "S_lc_fiso_dprime_variability.pdf"), overwrite = TRUE)
writeLines("Copied unchanged. The y-axis is d-prime variability, not a DDM parameter.", file.path(FIG, "S_lc_fiso_dprime_variability_source.txt"))

pts <- read_csv(file.path(TAB, "T14_subject_points.csv"), show_col_types = FALSE)
t14 <- read_csv(file.path(TAB, "T14_lc_neuropsych_ddm.csv"), show_col_types = FALSE)
ann <- function(outcome) {
  hit <- t14[t14$analysis == "lc" & t14$predictor == "LC_fISO" & t14$outcome == outcome, , drop = FALSE]
  if (!nrow(hit)) return("")
  sprintf("partial r = %.2f\np = %.3f", hit$r[1], hit$p[1])
}
one_sc <- function(yvar, ylab, title) {
  sub <- pts %>% filter(is.finite(LC_fISO), is.finite(.data[[yvar]]))
  ggplot(sub, aes(x = LC_fISO, y = .data[[yvar]])) +
    geom_point(size = 1.6, alpha = 0.75, color = stat_colors["empirical"]) +
    geom_smooth(method = "lm", se = TRUE, color = stat_colors["empirical"], fill = stat_colors["empirical"], linewidth = 0.6, alpha = 0.15) +
    annotate("text", x = Inf, y = Inf, hjust = 1.05, vjust = 1.3, label = ann(yvar), size = 3) +
    labs(x = NULL, y = ylab, title = title) +
    theme_ms() + theme(legend.position = "none", plot.title = element_text(face = "bold", size = 11))
}
lc4 <- one_sc("dprime_variability", "d' variability", "Variability") +
  one_sc("dprime_mean", "Mean d'", "Mean performance") +
  one_sc("a_mean", "Baseline boundary (a)", "DDM baseline") +
  one_sc("tepr_mean", "Mean TEPR (AUC)", "Phasic pupil") +
  plot_layout(ncol = 2) +
  plot_annotation(title = "LC fISO")
save_final(lc4, "S_lc_fiso_four_panel", 9, 7, "T14_subject_points.csv for the points. Partial-correlation annotation from T14_lc_neuropsych_ddm.csv. The boundary panel uses the M4 subject intercept.")

# ---------------------------------------------------------------------------
# S-tepr. Cleaned flat files, restricted to the 4,952-trial r8 QC set.
# ---------------------------------------------------------------------------
message("S-tepr")
suppressPackageStartupMessages(library(data.table))
source("R/trial_time_axis.R")
flat_line <- grep("^processed_dir:", readLines("config/data_paths.yaml"), value = TRUE)
flat_dir <- gsub("^processed_dir:\\s*|\"", "", flat_line[[1]])
flat_dir <- sub("\\s+$", "", flat_dir)
if (!dir.exists(flat_dir)) stop("Flat-file directory not found: ", flat_dir)

infer_dt <- function(time_vec) {
  time_vec <- time_vec[is.finite(time_vec)]
  diffs <- diff(sort(unique(time_vec)))
  diffs <- diffs[diffs > 0 & is.finite(diffs)]
  if (!length(diffs)) return(0.004)
  dt_median <- median(diffs)
  if (dt_median >= 1 && dt_median <= 10) dt_median <- dt_median / 1000
  if (!is.finite(dt_median) || dt_median <= 0 || dt_median > 0.05) 0.004 else dt_median
}

qc_tepr <- fread("data/analysis_ready/r8/ddm_pupil_r8_qc.csv")
qc_tepr[, `:=`(
  subject_id = as.character(subject_id),
  task = as.character(task),
  session = as.integer(session),
  run = as.integer(run),
  trial = as.integer(trial),
  effort_condition = as.character(effort_condition)
)]
stopifnot(nrow(qc_tepr) == 4952L)
grid <- seq(-0.5, 8, by = 0.02)
pairs <- unique(qc_tepr[, .(subject_id, task)])
subj_pieces <- vector("list", nrow(pairs))
n_joined <- 0L
n_b0 <- 0L
for (i in seq_len(nrow(pairs))) {
  subj <- pairs$subject_id[i]
  tsk <- pairs$task[i]
  path <- file.path(flat_dir, sprintf("%s_%s_flat.csv", subj, tsk))
  message(sprintf("  [%02d/%02d] %s", i, nrow(pairs), basename(path)))
  if (!file.exists(path)) stop("Missing flat file: ", path)
  dt <- fread(
    path,
    select = c("sub", "task", "session_used", "run_used", "trial_in_run_raw", "time", "pupil"),
    showProgress = FALSE
  )
  setnames(dt, c("sub", "session_used", "run_used", "trial_in_run_raw"), c("subject_id", "session", "run", "trial"))
  dt[, `:=`(
    subject_id = as.character(subject_id),
    task = as.character(task),
    session = as.integer(session),
    run = as.integer(run),
    trial = as.integer(trial),
    time = as.numeric(time),
    pupil = as.numeric(pupil)
  )]
  dt <- dt[session %in% c(2L, 3L)]
  if (anyNA(dt$trial) || anyNA(dt$session) || anyNA(dt$run)) stop("Missing trial keys in ", path)
  blk <- dt[, .(subject_id, task, session, run, trial, blk = rleid(subject_id, task, session, run, trial))]
  if (anyDuplicated(unique(blk), by = c("subject_id", "task", "session", "run", "trial"))) {
    stop("Trial key is not one contiguous block in ", path)
  }
  dt_used <- infer_dt(dt$time)
  wanted <- qc_tepr[subject_id == subj & task == tsk, .(subject_id, task, session, run, trial, effort_condition)]
  kept <- dt[wanted, on = c("subject_id", "task", "session", "run", "trial"), nomatch = 0]
  n_joined <- n_joined + uniqueN(kept, by = c("subject_id", "task", "session", "run", "trial"))
  if (!nrow(kept)) {
    rm(dt, kept)
    next
  }
  series <- kept[, {
    n <- .N
    t_rel <- build_trial_time(
      n, dt_used,
      subject = subject_id[1], task = task[1],
      session = session[1], run = run[1], trial = trial[1]
    )$t
    b0_vals <- pupil[t_rel >= -0.5 & t_rel < 0]
    b0_ok <- sum(is.finite(b0_vals)) >= 10L
    b0 <- if (b0_ok) mean(b0_vals[is.finite(b0_vals)]) else NA_real_
    if (!is.finite(b0)) {
      .(time = grid, pupil_bc = NA_real_)
    } else {
      .(time = grid, pupil_bc = stats::approx(t_rel, pupil - b0, xout = grid, rule = 1, ties = "ordered")$y)
    }
  }, by = .(subject_id, task, session, run, trial)]
  n_b0 <- n_b0 + uniqueN(series[is.finite(pupil_bc)], by = c("subject_id", "task", "session", "run", "trial"))
  series[wanted, on = c("subject_id", "task", "session", "run", "trial"), effort_condition := i.effort_condition]
  subj_pieces[[i]] <- series[, .(
    pupil = if (any(is.finite(pupil_bc))) mean(pupil_bc, na.rm = TRUE) else NA_real_
  ), by = .(subject_id, task, effort_condition, time)]
  rm(dt, kept, series)
}
stopifnot(n_joined == 4952L)
subj_means <- rbindlist(subj_pieces)
subj_means <- subj_means[is.finite(pupil)]
subj_means[, effort_label := ifelse(effort_condition == "high", "High", "Low")]

means <- subj_means[, .(
  mean_pupil = mean(pupil),
  n_subjects = uniqueN(subject_id)
), by = .(task, effort_label, time)]
wide <- dcast(subj_means, subject_id + task + time ~ effort_label, value.var = "pupil")
se_tbl <- wide[is.finite(Low) & is.finite(High), {
  subj_m <- (Low + High) / 2
  grand <- mean(subj_m)
  low_c <- Low - subj_m + grand
  high_c <- High - subj_m + grand
  n <- .N
  morey <- sqrt(2)
  .(
    se_Low = stats::sd(low_c) / sqrt(n) * morey,
    se_High = stats::sd(high_c) / sqrt(n) * morey,
    n_both = n
  )
}, by = .(task, time)]
se_long <- melt(
  se_tbl, id.vars = c("task", "time", "n_both"),
  measure.vars = c("se_Low", "se_High"),
  variable.name = "effort_label", value.name = "se"
)
se_long[, effort_label := ifelse(effort_label == "se_Low", "Low", "High")]
plot_tepr <- merge(means, se_long, by = c("task", "effort_label", "time"), all.x = TRUE)
setorder(plot_tepr, task, effort_label, time)
plot_tepr <- as_tibble(plot_tepr) %>%
  mutate(
    effort_label = factor(effort_label, levels = c("Low", "High")),
    task = factor(task, levels = c("ADT", "VDT"))
  )

p_tepr <- ggplot(plot_tepr, aes(x = time, y = mean_pupil, color = effort_label, fill = effort_label)) +
  annotate("rect", xmin = 1.0, xmax = 4.35, ymin = -Inf, ymax = Inf, fill = "#E5E7EB", alpha = 0.85) +
  annotate("rect", xmin = 4.65, xmax = 7.65, ymin = -Inf, ymax = Inf, fill = "#DBEAFE", alpha = 0.55) +
  geom_vline(xintercept = 4.35, linewidth = 0.35, color = "#111827") +
  geom_vline(xintercept = 4.70, linewidth = 0.35, linetype = "dashed", color = "#111827") +
  geom_ribbon(aes(ymin = mean_pupil - se, ymax = mean_pupil + se), alpha = 0.22, color = NA) +
  geom_line(linewidth = 0.6) +
  facet_wrap(~ task, ncol = 1) +
  scale_color_manual(
    values = c(Low = unname(effort_colors["Low"]), High = unname(effort_colors["High"])),
    name = "Effort"
  ) +
  scale_fill_manual(
    values = c(Low = unname(effort_colors["Low"]), High = unname(effort_colors["High"])),
    name = "Effort"
  ) +
  scale_x_continuous(breaks = seq(0, 8, by = 1), limits = c(-0.5, 8)) +
  labs(
    x = "Time from squeeze onset (s)",
    y = "Baseline-corrected pupil (a.u.)",
    caption = "Grey band: grip period (1.0\u20134.35 s). Blue band: decision-window AUC (4.65\u20137.65 s). Solid line: probe (4.35 s). Dashed line: response cue (4.70 s)."
  ) +
  theme_ms()
save_final(
  p_tepr, "S_tepr_timecourse", 8.2, 7.2,
  sprintf(
    paste(
      "Cleaned flat timecourses in %s, the same files and the same clock as the r6 prechoice and grip predictors.",
      "Restricted to the 4,952 trials in data/analysis_ready/r8/ddm_pupil_r8_qc.csv.",
      "Join keys: subject, task, session, run, trial, with flat-file columns session_used, run_used, and trial_in_run_raw, sessions 2 and 3 only.",
      "Time zero is squeeze onset. The first sample is placed at -3.0 s; if stepping by the file's median interval does not end between 8 and 15 s, samples are placed evenly from -3.0 to 10.7 s.",
      "Each trial is baseline-corrected by its mean pupil on [-0.5, 0), requiring at least 10 finite samples, then interpolated onto a 50 Hz grid from -0.5 to 8 s.",
      "The line is the unweighted mean of the within-participant means. The band is the Morey within-participant standard error, with effort as the repeated factor inside each task.",
      "Joined %d of 4,952 trials to a timecourse; %d of those had a usable baseline and enter the average. The rest are omitted.",
      "The average uses %d subject-by-task-by-effort cells.",
      sep = " "
    ),
    flat_dir, n_joined, n_b0, uniqueN(subj_means, by = c("subject_id", "task", "effort_label"))
  )
)
message("Part F finished: ", FIG)
