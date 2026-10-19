# Part V. Inline values, copied from the Part T tables.
# Run from the repo root: Rscript scripts/final/V_inline_values.R

options(warn = 1)
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(jsonlite)
})

ROOT <- normalizePath(getwd(), mustWork = TRUE)
setwd(ROOT)
FINAL <- "output/ddm_refits/runs/final_20261016"
TAB <- file.path(FINAL, "tables", "final")

num <- function(x) as.numeric(x)
effect <- function(row) {
  list(
    median = num(row$median), lo = num(row$q2.5), hi = num(row$q97.5),
    p_lt0 = num(row$p_lt0), p_gt0 = num(row$p_gt0), pct_rope = num(row$pct_in_rope)
  )
}
pick <- function(df, term) {
  hit <- df[df$term == term, , drop = FALSE]
  if (nrow(hit) != 1) stop("Expected one row for ", term, ", found ", nrow(hit))
  hit
}

t2 <- read.csv(file.path(TAB, "T2_effort_effects_M4.csv"), stringsAsFactors = FALSE)
t4 <- read.csv(file.path(TAB, "T4_fixef_M4.csv"), stringsAsFactors = FALSE)
t4b <- read.csv(file.path(TAB, "T4b_M4b_task_effort.csv"), stringsAsFactors = FALSE)
t5 <- read.csv(file.path(TAB, "T5_model_comparison.csv"), stringsAsFactors = FALSE)
t5b <- read.csv(file.path(TAB, "T5_delta_M0_vs_M1.csv"), stringsAsFactors = FALSE)
t6 <- read.csv(file.path(TAB, "T6a_robustness_effort_terms.csv"), stringsAsFactors = FALSE)
t6b <- read.csv(file.path(TAB, "T6b_M4r_random_slopes.csv"), stringsAsFactors = FALSE)
t8 <- read.csv(file.path(TAB, "T8_pupil_ordering.csv"), stringsAsFactors = FALSE)
t9 <- read.csv(file.path(TAB, "T9_pupil_descriptives.csv"), stringsAsFactors = FALSE)
t10 <- read.csv(file.path(TAB, "T10_convergence_all.csv"), stringsAsFactors = FALSE)
t11 <- read.csv(file.path(TAB, "T11_ppc_summary.csv"), stringsAsFactors = FALSE)
t12 <- read.csv(file.path(TAB, "T12b_participant_flow.csv"), stringsAsFactors = FALSE)
t13 <- read.csv(file.path(TAB, "T13a_accuracy_rt_descriptives.csv"), stringsAsFactors = FALSE)
flow <- function(node) t12[t12$node == node, , drop = FALSE]

gate_list <- list()
qc <- t9[t9$block == "qc_gate" & !is.na(t9$gate), , drop = FALSE]
for (i in seq_len(nrow(qc))) {
  g <- qc$gate[i]
  gate_list[[paste0("n_pupil_", g, "_trials")]] <- num(qc$n_trials[i])
  gate_list[[paste0("n_pupil_", g, "_subjects")]] <- num(qc$n_subjects[i])
}

robust_term <- function(model, term) {
  hit <- t6[t6$model == model & t6$term == term, , drop = FALSE]
  effect(hit)
}
t0_of <- function(model) {
  hit <- t6[t6$model == model & t6$term == "b_effort_conditionhigh", , drop = FALSE]
  list(median = num(hit$t0_median), lo = num(hit$t0_q2.5), hi = num(hit$t0_q97.5))
}
pupil_of <- function(model) {
  hit <- t8[t8$model == model, , drop = FALSE]
  list(
    median = num(hit$median), lo = num(hit$q2.5), hi = num(hit$q97.5),
    p_lt0 = num(hit$p_lt0), p_gt0 = num(hit$p_gt0),
    pct_change = num(hit$pct_change_median),
    delta_elpd = num(hit$delta_elpd_vs_baseline),
    se_delta_elpd = num(hit$se_delta_elpd)
  )
}
beh_of <- function(diff) {
  hit <- t13[t13$record == "paired_accuracy" & t13$difficulty_3 == diff, , drop = FALSE]
  list(
    mean = num(hit$mean_high_minus_low), t = num(hit$t),
    df = num(hit$df), p = num(hit$p)
  )
}
m4conv <- t10[t10$model == "M4", , drop = FALSE]
t5row <- function(model) t5[t5$model == model, , drop = FALSE]
bs_row <- pick(t2, "b_bs_effort_conditionhigh")

cor_row <- t9[t9$block == "tepr_rt_correlation" & t9$scope == "overall", , drop = FALSE]
grip <- t9[t9$block == "grip_paired", , drop = FALSE]
tepr_p <- t9[t9$block == "paired_high_minus_low" & t9$outcome == "tepr_raw", , drop = FALSE]
pair_task <- function(df, task) {
  hit <- df[df$task == task, , drop = FALSE]
  list(diff = num(hit$mean_high_minus_low), t = num(hit$t), df = num(hit$df), p = num(hit$p))
}

vals <- c(gate_list, list(
  n_enrolled = num(flow("enrolled")$n_subjects),
  n_excluded = num(flow("excluded_after_enrollment")$n_subjects),
  n_final = num(flow("analytic_sample")$n_subjects),
  n_adt = num(flow("task_ADT")$n_subjects),
  n_vdt = num(flow("task_VDT")$n_subjects),
  n_trials_primary = num(flow("primary_analysis_trials")$n_trials),
  n_trials_cutoff_excluded = num(flow("probe_rt_below_0.20_or_missing")$n_trials),
  n_trials_thr015 = num(flow("cutoff_0.15_trials")$n_trials),
  n_trials_thr025 = num(flow("cutoff_0.25_trials")$n_trials),
  n_subchance_excluded = 13,
  n_subchance_remaining = 54,
  n_pupil_matched_trials = num(flow("pupil_matched")$n_trials),
  n_pupil_final_trials = num(flow("pupil_subject_task_ge_20")$n_trials),
  n_pupil_final_subjects = num(flow("pupil_subject_task_ge_20")$n_subjects),
  n_chains = 8, n_iter = 3000, n_warmup = 1500,
  adapt_delta = 0.95, max_treedepth = 12, seed = 2026,
  max_rhat_M4 = num(m4conv$max_rhat),
  min_bulk_ess_M4 = num(m4conv$min_bulk_ess),
  min_tail_ess_M4 = num(m4conv$min_tail_ess),
  crit = effect(pick(t2, "b_effort_conditionhigh")),
  qual = effect(pick(t2, "b_effort_x_stim")),
  bs = effect(bs_row),
  bias = effect(pick(t2, "b_bias_effort_conditionhigh")),
  drift_diff_trials = effect(pick(t2, "drift_different")),
  drift_same_trials = effect(pick(t2, "drift_same")),
  bs_pct_change = list(
    median = num(bs_row$natural_scale_median),
    lo = num(bs_row$natural_scale_q2.5),
    hi = num(bs_row$natural_scale_q97.5)
  ),
  task_v = effect(pick(t4, "b_taskVDT")),
  task_hard_x_vdt = effect(pick(t4, "b_difficulty_3Hard:taskVDT")),
  task_easy_x_vdt = effect(pick(t4, "b_difficulty_3Easy:taskVDT")),
  task_bs = effect(pick(t4, "b_bs_taskVDT")),
  task_bias = effect(pick(t4, "b_bias_taskVDT")),
  t0_M4 = t0_of("M4"),
  t0_thr015 = t0_of("M4_thr0.15"),
  t0_thr025 = t0_of("M4_thr0.25"),
  delta_elpd_M3_vs_M4 = num(t5row("M3")$delta_elpd_vs_M4),
  se_delta_elpd_M3_vs_M4 = num(t5row("M3")$se_delta_elpd_vs_M4),
  delta_elpd_M4b_vs_M4 = num(t5row("M4b")$delta_elpd_vs_M4),
  se_delta_elpd_M4b_vs_M4 = num(t5row("M4b")$se_delta_elpd_vs_M4),
  delta_elpd_M0_vs_M1 = num(t5b$delta_elpd),
  se_delta_elpd_M0_vs_M1 = num(t5b$se),
  crit_M4r = robust_term("M4r", "b_effort_conditionhigh"),
  qual_M4r = robust_term("M4r", "b_effort_x_stim"),
  crit_thr015 = robust_term("M4_thr0.15", "b_effort_conditionhigh"),
  qual_thr015 = robust_term("M4_thr0.15", "b_effort_x_stim"),
  crit_thr025 = robust_term("M4_thr0.25", "b_effort_conditionhigh"),
  qual_thr025 = robust_term("M4_thr0.25", "b_effort_x_stim"),
  crit_subchance = robust_term("M4_subchance", "b_effort_conditionhigh"),
  qual_subchance = robust_term("M4_subchance", "b_effort_x_stim"),
  sd_effort_M4r = effect(pick(t6b, "sd_subject_id__effort_conditionhigh")),
  sd_bs_effort_M4r = effect(pick(t6b, "sd_subject_id__bs_effort_conditionhigh")),
  m4b_effort_x_task = effect(pick(t4b, "b_taskVDT:effort_conditionhigh")),
  m4b_quality_x_task = effect(pick(t4b, "b_taskVDT:effort_x_stim")),
  crit_ADT_M4b = effect(pick(t4b, "criterion_ADT")),
  crit_VDT_M4b = effect(pick(t4b, "criterion_VDT")),
  P3 = pupil_of("P3"),
  P3_rt = pupil_of("P3_rt"),
  P5 = pupil_of("P5"),
  P6 = pupil_of("P6"),
  P7 = pupil_of("P7"),
  P8 = pupil_of("P8"),
  delta_elpd_P3_vs_P0 = pupil_of("P3")$delta_elpd,
  se_delta_elpd_P3_vs_P0 = pupil_of("P3")$se_delta_elpd,
  tepr_rt_r = num(cor_row$mean_r_fisher),
  tepr_rt_ci_lo = num(cor_row$ci_lo),
  tepr_rt_ci_hi = num(cor_row$ci_hi),
  grip_ADT = pair_task(grip, "ADT"),
  grip_VDT = pair_task(grip, "VDT"),
  tepr_high_low_ADT = pair_task(tepr_p, "ADT"),
  tepr_high_low_VDT = pair_task(tepr_p, "VDT"),
  ppc_choice_inside_M4 = num(t11$ppc_choice_inside_M4),
  ppc_rt_inside_pct_M4 = num(t11$ppc_rt_inside_pct_M4),
  ppc_rt_median_bias_ms_M4 = num(t11$ppc_rt_median_bias_ms_M4),
  acc_high_low_Standard = beh_of("Standard"),
  acc_high_low_Hard = beh_of("Hard"),
  acc_high_low_Easy = beh_of("Easy"),
  rope_v = 0.02, rope_a = 0.05, rope_z = 0.05
))

# Phase 1d. Rebuild the pupil keys in the contract shape, and the accuracy
# and RT keys from the reduced models. A later r11 run of this script must
# not put the paired-t keys or the r8 pupil keys back.
num <- function(x) as.numeric(x)
slope_of <- function(model) {
  hit <- t8[t8$model == model, , drop = FALSE]
  if (nrow(hit) != 1) stop("T8 rows for ", model, " = ", nrow(hit))
  list(
    median = num(hit$median), lo = num(hit$q2.5), hi = num(hit$q97.5),
    pct = num(hit$pct_change_median), p_gt0 = num(hit$p_gt0), p_lt0 = num(hit$p_lt0)
  )
}
delta_of <- function(model) {
  hit <- t8[t8$model == model, , drop = FALSE]
  list(delta = num(hit$delta_elpd_vs_baseline), se = num(hit$se_delta_elpd))
}
t7 <- read.csv(file.path(TAB, "T7_pupil_models.csv"), stringsAsFactors = FALSE)
t7e <- read.csv(file.path(TAB, "T7_P0_effort_terms.csv"), stringsAsFactors = FALSE)
t7_slope <- function(model, term) {
  hit <- t7[t7$model == model & t7$term == term, , drop = FALSE]
  if (nrow(hit) != 1) stop("T7 rows for ", model, " ", term, " = ", nrow(hit))
  pct <- num(hit$pct_change_median)
  list(
    median = num(hit$median), lo = num(hit$q2.5), hi = num(hit$q97.5),
    pct = if (is.finite(pct)) pct else NA_real_,
    p_gt0 = num(hit$p_gt0), p_lt0 = num(hit$p_lt0)
  )
}
effort_of <- function(term, with_pct) {
  hit <- t7e[t7e$model == "P0" & t7e$term == term, , drop = FALSE]
  if (nrow(hit) != 1) stop("P0 effort rows for ", term, " = ", nrow(hit))
  pct <- if (with_pct) num(hit$pct_change_a_median) else NA_real_
  list(
    median = num(hit$median), lo = num(hit$q2.5), hi = num(hit$q97.5),
    pct = pct, p_gt0 = num(hit$p_gt0), p_lt0 = num(hit$p_lt0)
  )
}
pair_of <- function(block, task, outcome = NULL) {
  hit <- t9[t9$block == block & t9$task == task, , drop = FALSE]
  if (!is.null(outcome)) hit <- hit[hit$outcome == outcome, , drop = FALSE]
  if (nrow(hit) != 1) stop("T9 rows ", block, " ", task, " ", outcome, " = ", nrow(hit))
  list(diff = num(hit$mean_high_minus_low), t = num(hit$t), df = num(hit$df), p = num(hit$p))
}
gate_n <- function(gate, col) {
  hit <- t9[t9$block == "qc_gate" & t9$gate == gate, , drop = FALSE]
  if (nrow(hit) != 1) stop("Gate row ", gate, " = ", nrow(hit))
  num(hit[[col]])
}
trial_key <- function(path) {
  x <- read.csv(path, stringsAsFactors = FALSE)
  paste(x$subject_id, x$task, x$session, x$run, x$trial, sep = "|")
}
r10_keys <- trial_key("data/analysis_ready/r10/ddm_pupil_r10.csv")
r8_keys <- trial_key("data/analysis_ready/r8/ddm_pupil_r8.csv")
d3 <- delta_of("P3")
d3rt <- delta_of("P3_rt")
loo_dir <- "output/ddm_refits/runs/r10_20261017_081458/loo"
loo_models <- c(
  "P0", "P1", "P2", "P3", "P0_base", "P4", "P5", "P0_rt", "P3_rt",
  "P0_lag", "P6", "P0_pre", "P7", "P0_grip", "P8"
)
k_gt <- 0L
max_k <- NA_real_
found_loo <- 0L
maxes <- numeric(0)
for (key in loo_models) {
  status <- read.csv(file.path(loo_dir, paste0("loo_", key, "_status.csv")), stringsAsFactors = FALSE)
  if (num(status$k_0.7_1) + num(status$k_gt_1) > 0) k_gt <- k_gt + 1L
  rds <- file.path(loo_dir, paste0("loo_", key, ".rds"))
  if (file.exists(rds)) {
    obj <- readRDS(rds)
    maxes <- c(maxes, max(obj$diagnostics$pareto_k, na.rm = TRUE))
    found_loo <- found_loo + 1L
  }
}
if (found_loo == length(loo_models)) max_k <- max(maxes)
subset_n <- c(P0_base = "n_pupil_base_trials", P0_rt = "n_pupil_rt80_trials",
              P0_lag = "n_pupil_lag_trials", P0_pre = "n_pupil_pre_trials",
              P0_grip = "n_pupil_grip_trials")
full_conv <- read.csv(file.path("output/ddm_refits/runs/r10_20261017_081458/tables/convergence_full.csv"),
                      stringsAsFactors = FALSE)
drop_names <- c(
  "P3", "P3_rt", "P5", "P6", "P7", "P8",
  "delta_elpd_P3_vs_P0", "se_delta_elpd_P3_vs_P0",
  "tepr_rt_r", "tepr_rt_ci_lo", "tepr_rt_ci_hi",
  "grip_ADT", "grip_VDT", "tepr_high_low_ADT", "tepr_high_low_VDT",
  "n_pupil_entered_vs_r5", "n_pupil_left_vs_r5",
  grep("^n_pupil_", names(vals), value = TRUE)
)
vals[intersect(drop_names, names(vals))] <- NULL
t13d <- read.csv(file.path(TAB, "T13d_accuracy_effort_contrasts.csv"), stringsAsFactors = FALSE)
t13e <- read.csv(file.path(TAB, "T13e_rt_effort_contrasts.csv"), stringsAsFactors = FALSE)
acc_of <- function(diff) {
  hit <- t13d[t13d$difficulty == diff, , drop = FALSE]
  if (nrow(hit) != 1) stop("T13d rows for ", diff, " = ", nrow(hit))
  list(
    pp = num(hit$pp), pp_lo = num(hit$pp_lo), pp_hi = num(hit$pp_hi),
    or = num(hit$or), or_lo = num(hit$or_lo), or_hi = num(hit$or_hi),
    z = num(hit$z), p = num(hit$p)
  )
}
rt_of <- function(diff) {
  hit <- t13e[t13e$difficulty == diff, , drop = FALSE]
  if (nrow(hit) != 1) stop("T13e rows for ", diff, " = ", nrow(hit))
  list(
    ms = num(hit$ms), ms_lo = num(hit$ms_lo), ms_hi = num(hit$ms_hi),
    t = num(hit$t), df = num(hit$df), p = num(hit$p)
  )
}
pupil_added <- list(
  n_pupil_matched_trials = gate_n("matched", "n_trials"),
  n_pupil_matched_subjects = gate_n("matched", "n_subjects"),
  n_pupil_tepr_present_trials = gate_n("tepr_present", "n_trials"),
  n_pupil_tepr_present_subjects = gate_n("tepr_present", "n_subjects"),
  n_pupil_b1_quality_trials = gate_n("B1_quality_ge_0.50", "n_trials"),
  n_pupil_b1_quality_subjects = gate_n("B1_quality_ge_0.50", "n_subjects"),
  n_pupil_window_quality_trials = gate_n("auc_window_ge_0.50", "n_trials"),
  n_pupil_window_quality_subjects = gate_n("auc_window_ge_0.50", "n_subjects"),
  n_pupil_final_trials = gate_n("subject_task_ge_20", "n_trials"),
  n_pupil_final_subjects = gate_n("subject_task_ge_20", "n_subjects"),
  n_pupil_entered_vs_r8 = length(setdiff(r10_keys, r8_keys)),
  n_pupil_left_vs_r8 = length(setdiff(r8_keys, r10_keys)),
  P3_bs = slope_of("P3"),
  P3_rt_bs = slope_of("P3_rt"),
  P5_bs = slope_of("P5"),
  P6_bs = slope_of("P6"),
  P7_bs = slope_of("P7"),
  P8_bs = slope_of("P8"),
  P1_bias = t7_slope("P1", "b_bias_tepr_c"),
  P2_drift_tepr = t7_slope("P2", "b_tepr_c"),
  P2_drift_tepr_x_stim = t7_slope("P2", "b_tepr_c:stim_sign"),
  P4_bias_base = t7_slope("P4", "b_bias_base_c"),
  P0_crit = effort_of("b_effort_conditionhigh", FALSE),
  P0_qual = effort_of("b_effort_x_stim", FALSE),
  P0_bs = effort_of("b_bs_effort_conditionhigh", TRUE),
  P0_bias = effort_of("b_bias_effort_conditionhigh", FALSE),
  delta_elpd_P3_vs_P0 = d3,
  delta_elpd_P3rt_vs_P0rt = d3rt,
  delta_elpd_P5_vs_P0base = delta_of("P5"),
  delta_elpd_P6_vs_P0lag = delta_of("P6"),
  delta_elpd_P7_vs_P0pre = delta_of("P7"),
  delta_elpd_P8_vs_P0grip = delta_of("P8"),
  delta_elpd_P1_vs_P0 = {
    hit <- t7[t7$model == "P1", , drop = FALSE]
    list(delta = num(hit$delta_elpd_vs_baseline[1]), se = num(hit$se_delta_elpd[1]))
  },
  delta_elpd_P2_vs_P0 = {
    hit <- t7[t7$model == "P2", , drop = FALSE]
    list(delta = num(hit$delta_elpd_vs_baseline[1]), se = num(hit$se_delta_elpd[1]))
  },
  delta_elpd_P4_vs_P0base = {
    hit <- t7[t7$model == "P4", , drop = FALSE]
    list(delta = num(hit$delta_elpd_vs_baseline[1]), se = num(hit$se_delta_elpd[1]))
  },
  tepr_rt_r = list(
    r = num(cor_row$mean_r_fisher), lo = num(cor_row$ci_lo), hi = num(cor_row$ci_hi),
    n_subjects = num(cor_row$n_subjects)
  ),
  grip_high_low_ADT = pair_of("grip_paired", "ADT"),
  grip_high_low_VDT = pair_of("grip_paired", "VDT"),
  tepr_high_low_ADT_B1 = pair_of("paired_high_minus_low", "ADT", "tepr_raw"),
  tepr_high_low_VDT_B1 = pair_of("paired_high_minus_low", "VDT", "tepr_raw"),
  tepr_high_low_ADT_B0 = pair_of("paired_high_minus_low", "ADT", "auc_b0"),
  tepr_high_low_VDT_B0 = pair_of("paired_high_minus_low", "VDT", "auc_b0"),
  tepr_window_start = 4.65,
  tepr_window_end = 7.65,
  tepr_baseline_start = 3.85,
  tepr_baseline_end = 4.35,
  tepr_window_post_probe = "0.3\u20133.3 s",
  tepr_baseline_pre_probe = "0.5 s",
  max_k_pupil_models = max_k,
  n_pupil_models_k_gt_0.7 = k_gt,
  pct_gain_lost_rt_trim = 100 * (1 - d3rt$delta / d3$delta),
  acc_high_low_Standard = acc_of("Standard"),
  acc_high_low_Hard = acc_of("Hard"),
  acc_high_low_Easy = acc_of("Easy"),
  rt_high_low_Standard = rt_of("Standard"),
  rt_high_low_Hard = rt_of("Hard"),
  rt_high_low_Easy = rt_of("Easy"),
  acc_model_re = "(1 | subject_id)"
)
for (model in names(subset_n)) {
  pupil_added[[subset_n[[model]]]] <- num(full_conv$n[full_conv$model == model])
}
if (pupil_added$n_pupil_final_trials != 4935 || pupil_added$n_pupil_final_subjects != 43) {
  stop("Pupil gate does not end at 4,935 trials and 43 subjects")
}
vals[intersect(names(pupil_added), names(vals))] <- NULL
vals <- c(vals, pupil_added)

saveRDS(vals, file.path(TAB, "inline_values.rds"))
writeLines(
  jsonlite::toJSON(vals, auto_unbox = TRUE, digits = NA, pretty = TRUE, na = "null"),
  file.path(TAB, "inline_values.json")
)
message("Wrote inline values (", length(vals), " top-level keys); LOO objects found: ", found_loo)
