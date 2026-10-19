# Phase 1d local export. Does not fit a DDM.
# Rebuilds the pupil tables from the r10 extract and fits the reduced
# accuracy and median-RT models on the primary 17,857 trials.

options(warn = 1, scipen = 999)
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(tibble)
  library(data.table)
  library(lme4)
  library(lmerTest)
  library(emmeans)
  library(broom.mixed)
})

ROOT <- normalizePath(getwd(), mustWork = TRUE)
setwd(ROOT)
DIAG <- "output/diagnostics/qmd_phase1d"
dir.create(DIAG, recursive = TRUE, showWarnings = FALSE)
stop_at <- function(step, msg) {
  writeLines(c(paste("# Stopped at", step), "", msg), file.path(DIAG, "STOPPED.md"))
  stop(step, ": ", msg, call. = FALSE)
}

FINAL <- "output/ddm_refits/runs/final_20261016"
TAB <- file.path(FINAL, "tables", "final")
FIG <- file.path(FINAL, "figures", "final")
RUN <- "output/ddm_refits/runs/r10_20261017_081458"
num <- function(x) as.numeric(x)

# Tail ESS printed by scripts/r10/a3_tail_ess.R on the VM.
tail_ess <- c(
  P0 = 2609.826, P1 = 2404.898, P2 = 2264.492, P3 = 2475.774,
  P0_base = 2831.084, P4 = 2943.145, P5 = 3063.620,
  P0_rt = 3651.568, P3_rt = 3222.511, P0_lag = 2231.456, P6 = 2780.349,
  P0_pre = 3114.655, P7 = 2750.402, P0_grip = 3104.713, P8 = 3275.657
)
conv <- read_csv(file.path(RUN, "tables/convergence.csv"), show_col_types = FALSE)
if (nrow(conv) != 15L || !all(conv$pass)) stop_at("A1", "r10 convergence.csv is not 15 passing models")
full <- conv %>%
  transmute(
    model, n, adapt_delta,
    max_rhat = rhat, min_bulk_ess = ess_bulk,
    min_tail_ess = unname(tail_ess[model]),
    divergences,
    pass = rhat < 1.01 & ess_bulk >= 400 & unname(tail_ess[model]) >= 400 & divergences == 0
  )
if (!all(full$pass)) stop_at("A3", "A model fails the tail-ESS rule")
write_csv(full, file.path(RUN, "tables/convergence_full.csv"))

archive_file <- function(path) {
  if (!file.exists(path)) return(invisible(NULL))
  dest <- sub("(\\.[A-Za-z0-9]+)$", "_r8\\1", path)
  if (!file.exists(dest)) file.rename(path, dest)
  dest
}
pupil_tables <- c(
  "T7_pupil_models.csv", "T7_P0_effort_terms.csv",
  "T8_pupil_ordering.csv", "T9_pupil_descriptives.csv",
  "T10_convergence_all.csv", "T10b_convergence_display.csv",
  "T12b_participant_flow.csv"
)
for (nm in pupil_tables) archive_file(file.path(TAB, nm))
for (stem in c("F5_pupil_boundary", "S_tepr_timecourse", "S_participant_flow")) {
  for (ext in c("png", "pdf", "svg", "_source.txt")) archive_file(file.path(FIG, paste0(stem, ext)))
}

# ---- gates -----------------------------------------------------------------
qual <- fread("output/diagnostics/r9_precheck/trial_window_quality.csv")
qual[, `:=`(subject_id = as.character(subject_id), task = as.character(task))]
g1 <- qual[tepr_ok == TRUE & rule == "step_from_m3"]
g2 <- g1[is.finite(q_b1) & q_b1 >= 0.50]
g3 <- g2[is.finite(q_auc) & q_auc >= 0.50]
cell_n <- g3[, .N, by = .(subject_id, task)]
keep <- cell_n[N >= 20, .(subject_id, task)]
g4 <- g3[keep, on = c("subject_id", "task"), nomatch = NULL]
gate_row <- function(gate, dt) {
  data.frame(
    gate = gate, n_trials = nrow(dt), n_subjects = uniqueN(dt$subject_id),
    n_subject_task = uniqueN(paste(dt$subject_id, dt$task)),
    stringsAsFactors = FALSE
  )
}
gates <- bind_rows(
  gate_row("matched", qual),
  gate_row("tepr_present", g1),
  gate_row("B1_quality_ge_0.50", g2),
  gate_row("auc_window_ge_0.50", g3),
  gate_row("subject_task_ge_20", g4)
)
if (gates$n_trials[gates$gate == "subject_task_ge_20"] != 4935L ||
    gates$n_subjects[gates$gate == "subject_task_ge_20"] != 43L) {
  stop_at("B3", "r10 gates do not end at 4,935 trials and 43 subjects")
}
gates$block <- "qc_gate"
gates$source_model <- "r10_20261017_081458"
gates$tier <- "main"
write_csv(gates, file.path(DIAG, "gate_counts_r10.csv"))

# ---- descriptives on the 4,935-trial file ----------------------------------
qc <- fread("data/analysis_ready/r10/ddm_pupil_r10.csv")
if (nrow(qc) != 4935L || uniqueN(qc$subject_id) != 43L) {
  stop_at("B2", paste("r10 QC file has", nrow(qc), "trials"))
}
paired_one <- function(df, value) {
  wide <- df %>%
    select(subject_id, task, effort_condition, all_of(value)) %>%
    pivot_wider(names_from = effort_condition, values_from = all_of(value)) %>%
    filter(!is.na(high), !is.na(low))
  bind_rows(lapply(split(wide, wide$task), function(w) {
    diff <- w$high - w$low
    tt <- t.test(w$high, w$low, paired = TRUE)
    tibble(
      task = w$task[1], outcome = value, n_subjects = nrow(w),
      mean_high_minus_low = mean(diff), t = unname(tt$statistic),
      df = unname(tt$parameter), p = tt$p.value
    )
  }))
}
cell_means <- function(df, value_col) {
  df %>%
    group_by(subject_id, task, effort_condition) %>%
    summarise(cell = mean(.data[[value_col]], na.rm = TRUE), .groups = "drop") %>%
    group_by(task, effort_condition) %>%
    summarise(n_subjects = n(), mean = mean(cell), sd = sd(cell), .groups = "drop") %>%
    mutate(outcome = value_col)
}
b1 <- as_tibble(qc[is.finite(tepr_raw)])
b0 <- as_tibble(qc[is.finite(auc_b0)])
subj_b1 <- b1 %>% group_by(subject_id, task, effort_condition) %>%
  summarise(tepr_raw = mean(tepr_raw), .groups = "drop")
subj_b0 <- b0 %>% group_by(subject_id, task, effort_condition) %>%
  summarise(auc_b0 = mean(auc_b0), .groups = "drop")
raw_means <- bind_rows(cell_means(b1, "tepr_raw"), cell_means(b0, "auc_b0")) %>%
  mutate(block = "raw_means", source_model = "r10 QC", tier = "ms_supp")
paired <- bind_rows(paired_one(subj_b1, "tepr_raw"), paired_one(subj_b0, "auc_b0")) %>%
  mutate(block = "paired_high_minus_low", source_model = "r10 QC", tier = "main")

fisher_summary <- function(subject_rows) {
  z <- subject_rows$z
  k <- length(z)
  zbar <- mean(z)
  se <- if (k >= 2) stats::sd(z) / sqrt(k) else NA_real_
  crit <- if (k >= 2) stats::qt(0.975, k - 1) else NA_real_
  tibble(
    scope = "overall", difficulty = "all", n_subjects = k, n_trials = sum(subject_rows$n),
    mean_r_fisher = tanh(zbar),
    ci_lo = if (is.finite(se)) tanh(zbar - crit * se) else NA_real_,
    ci_hi = if (is.finite(se)) tanh(zbar + crit * se) else NA_real_,
    mean_z = zbar, se_z = se
  )
}
subject_cor <- bind_rows(lapply(split(as_tibble(qc), as_tibble(qc)$subject_id), function(w) {
  n <- nrow(w)
  r <- if (n > 3 && stats::sd(w$tepr_c) > 0 && stats::sd(w$rt) > 0) stats::cor(w$tepr_c, w$rt) else NA_real_
  tibble(n = n, r = r, z = if (is.finite(r)) atanh(pmin(pmax(r, -0.999999), 0.999999)) else NA_real_)
}))
cor_tepr <- fisher_summary(subject_cor[is.finite(subject_cor$z), ]) %>%
  mutate(block = "tepr_rt_correlation", source_model = "r10 QC", tier = "main")

grip_ok <- as_tibble(qc[is.finite(grip_raw)])
grip_subj <- grip_ok %>%
  group_by(subject_id, task, effort_condition) %>%
  summarise(grip_raw = mean(grip_raw), .groups = "drop")
grip_means <- grip_subj %>%
  group_by(task, effort_condition) %>%
  summarise(n_subjects = n(), mean_grip = mean(grip_raw), sd_grip = sd(grip_raw), .groups = "drop") %>%
  mutate(block = "grip_means", source_model = "r10 grip", tier = "ms_supp")
grip_paired <- bind_rows(lapply(split(grip_subj, grip_subj$task), function(w) {
  wide <- pivot_wider(w, id_cols = subject_id, names_from = effort_condition, values_from = grip_raw)
  wide <- wide[is.finite(wide$high) & is.finite(wide$low), ]
  tt <- t.test(wide$high, wide$low, paired = TRUE)
  tibble(
    task = w$task[1], n_subjects = nrow(wide),
    mean_high_minus_low = mean(wide$high - wide$low),
    t = unname(tt$statistic), df = unname(tt$parameter), p = tt$p.value,
    block = "grip_paired", source_model = "r10 grip", tier = "main"
  )
}))
t9 <- bind_rows(gates, cor_tepr, raw_means, paired, grip_means, grip_paired)
write_csv(t9, file.path(TAB, "T9_pupil_descriptives.csv"))
write_csv(t9, file.path(DIAG, "T9_pupil_descriptives.csv"))

# ---- T7 T8 from the r10 extract --------------------------------------------
slopes <- read_csv(file.path(RUN, "tables/r8_slopes.csv"), show_col_types = FALSE)
effort <- read_csv(file.path(RUN, "tables/r8_effort_terms.csv"), show_col_types = FALSE)
if (nrow(slopes) != 10L) stop_at("B2", "r10 slope table does not have 10 rows")
if (!all(slopes$n_trials[slopes$model == "P3"] == 4935L)) stop_at("B2", "P3 is not on 4,935 trials")
slopes <- slopes %>%
  left_join(full %>% select(model, rhat = max_rhat, ess_bulk = min_bulk_ess, divergences, pass), by = "model") %>%
  mutate(
    pct_change_median = pct_change_a_median,
    pct_change_q2.5 = pct_change_a_q2.5,
    pct_change_q97.5 = pct_change_a_q97.5,
    delta_elpd_vs_baseline = delta_elpd,
    source_run = "r10_20261017_081458",
    tier = "ms_supp"
  )
baseline_elpd <- slopes %>%
  distinct(model, baseline, elpd_loo, delta_elpd) %>%
  group_by(baseline) %>%
  summarise(elpd_loo = elpd_loo[1] - delta_elpd[1], .groups = "drop")
baseline_n <- slopes %>% distinct(baseline, n_trials, n_subjects)
p0_n <- baseline_n[baseline_n$baseline == "P0", ]
t7_terms <- slopes %>%
  filter(model %in% c("P1", "P2", "P3", "P4")) %>%
  transmute(
    model, baseline, term, median, q2.5, q97.5, p_lt0, p_gt0,
    pct_change_median, pct_change_q2.5, pct_change_q97.5,
    delta_elpd_vs_baseline, se_delta_elpd,
    n_trials, n_subjects, max_rhat = rhat, passes_convergence_rule = pass,
    elpd_loo, source_run, tier, record = "pupil_model"
  )
p0_row <- tibble(
  model = "P0", baseline = "P0", term = "none (baseline)",
  median = NA_real_, q2.5 = NA_real_, q97.5 = NA_real_, p_lt0 = NA_real_, p_gt0 = NA_real_,
  pct_change_median = NA_real_, pct_change_q2.5 = NA_real_, pct_change_q97.5 = NA_real_,
  delta_elpd_vs_baseline = 0, se_delta_elpd = 0,
  n_trials = p0_n$n_trials, n_subjects = p0_n$n_subjects,
  max_rhat = full$max_rhat[full$model == "P0"],
  passes_convergence_rule = TRUE,
  elpd_loo = baseline_elpd$elpd_loo[baseline_elpd$baseline == "P0"],
  source_run = "r10_20261017_081458", tier = "ms_supp", record = "pupil_model"
)
t7 <- bind_rows(p0_row, t7_terms)
write_csv(t7, file.path(TAB, "T7_pupil_models.csv"))
p0_eff <- effort %>%
  filter(model == "P0") %>%
  mutate(record = "P0_effort_term", source_run = "r10_20261017_081458", tier = "ms_supp")
write_csv(p0_eff, file.path(TAB, "T7_P0_effort_terms.csv"))

order_models <- c("P3", "P3_rt", "P5", "P6", "P7", "P8")
labels <- c(
  P3 = "current-trial TEPR",
  P3_rt = "current-trial TEPR, fastest 80% of RTs",
  P5 = "pre-squeeze baseline",
  P6 = "previous-trial TEPR",
  P7 = "0.5 s before the response",
  P8 = "grip period before the probe"
)
precedes <- c(P3 = FALSE, P3_rt = FALSE, P5 = TRUE, P6 = TRUE, P7 = FALSE, P8 = TRUE)
group <- c(
  P3 = "within current trial", P3_rt = "within current trial", P7 = "within current trial",
  P6 = "precedes current decision", P5 = "precedes current decision", P8 = "precedes current decision"
)
t8 <- slopes %>%
  filter(model %in% order_models) %>%
  mutate(
    predictor = unname(labels[model]),
    precedes_current_decision = unname(precedes[model]),
    group = unname(group[model]),
    source_model = model
  ) %>%
  select(
    model, baseline, term, predictor, precedes_current_decision, group,
    median, q2.5, q97.5, p_lt0, p_gt0,
    pct_change_median, pct_change_q2.5, pct_change_q97.5,
    delta_elpd_vs_baseline, se_delta_elpd,
    n_trials, n_subjects, max_rhat = rhat, passes_convergence_rule = pass,
    elpd_loo, source_model, tier
  )
if (nrow(t8) != 6L || t8$baseline[t8$model == "P5"] != "P0_base" || t8$baseline[t8$model == "P3"] != "P0") {
  stop_at("B2", "T8 baselines are not the matched comparisons")
}
write_csv(t8, file.path(TAB, "T8_pupil_ordering.csv"))

# ---- convergence rows -------------------------------------------------------
update_conv <- function(path, required) {
  x <- read_csv(sub("\\.csv$", "_r8.csv", path), show_col_types = FALSE)
  for (id in full$model) {
    row <- x$model == id
    if (!any(row)) {
      if (required) stop_at("B2", paste(id, "missing from", path))
      next
    }
    src <- full[full$model == id, ]
    x$max_rhat[row] <- src$max_rhat
    x$min_bulk_ess[row] <- src$min_bulk_ess
    x$min_tail_ess[row] <- src$min_tail_ess
    x$divergences[row] <- src$divergences
    x$passes_convergence_rule[row] <- TRUE
    x$chains[row] <- 8
    x$iter[row] <- 3000
    x$warmup[row] <- 1500
    if ("n_k_gt_0.7" %in% names(x)) x$n_k_gt_0.7[row] <- 0
    if ("note" %in% names(x)) x$note[row] <- "r10_20261017_081458"
  }
  write_csv(x, path)
}
update_conv(file.path(TAB, "T10_convergence_all.csv"), FALSE)
update_conv(file.path(TAB, "T10b_convergence_display.csv"), TRUE)

flow <- read_csv(file.path(TAB, "T12b_participant_flow_r8.csv"), show_col_types = FALSE)
flow_map <- c(
  pupil_matched = "matched",
  pupil_tepr_nonmissing = "tepr_present",
  pupil_B1_quality_ge_0.50 = "B1_quality_ge_0.50",
  pupil_cog_quality_ge_0.50 = "auc_window_ge_0.50",
  pupil_subject_task_ge_20 = "subject_task_ge_20"
)
for (node in names(flow_map)) {
  src <- gates[gates$gate == flow_map[[node]], ]
  hit <- flow$node == node
  flow$n_trials[hit] <- src$n_trials
  flow$n_subjects[hit] <- src$n_subjects
  flow$detail[hit] <- "r10 pupil gate"
  flow$source_model[hit] <- "r10_20261017_081458"
}
write_csv(flow, file.path(TAB, "T12b_participant_flow.csv"))

# ---- Part C ------------------------------------------------------------------
beh <- read_csv("output/ddm_refits/runs/final_20261016/data/ddm_behavioral_r5_full17857.csv", show_col_types = FALSE)
if (nrow(beh) != 17857L) stop_at("C1", paste("primary file has", nrow(beh), "rows"))
beh <- beh %>% mutate(
  correct = as.integer((difficulty_3 == "Standard" & choice_binary == 0) |
                          (difficulty_3 != "Standard" & choice_binary == 1)),
  difficulty_3 = factor(difficulty_3, levels = c("Standard", "Hard", "Easy")),
  effort_condition = factor(effort_condition, levels = c("low", "high")),
  task = factor(task, levels = c("ADT", "VDT"))
)
m_acc <- glmer(
  correct ~ difficulty_3 * effort_condition + task + (1 | subject_id),
  family = binomial, data = beh,
  control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
)
acc_fix <- tidy(m_acc, effects = "fixed", conf.int = TRUE)
hit <- acc_fix[acc_fix$term == "effort_conditionhigh", ]
if (abs(hit$estimate - 0.2039297469824211) > 1e-6 || abs(hit$p.value - 0.06796581183118545) > 1e-8) {
  stop_at("C1", sprintf("accuracy intercept model is %.6f, p %.6g", hit$estimate, hit$p.value))
}
acc_sd <- as.numeric(attr(VarCorr(m_acc)$subject_id, "stddev")["(Intercept)"])
write_csv(
  acc_fix %>% mutate(effect = "fixed", source_model = "lme4 binomial GLMM", tier = "diss_supp") %>%
    select(effect, term, estimate, std.error, statistic, p.value, conf.low, conf.high, source_model, tier),
  file.path(TAB, "T13b_accuracy_glmm.csv")
)

emm <- emmeans(m_acc, ~ effort_condition | difficulty_3, weights = "equal")
pp_df <- as.data.frame(summary(contrast(regrid(emm), method = "revpairwise"), infer = c(TRUE, TRUE)))
od_df <- as.data.frame(summary(contrast(emm, method = "revpairwise"), infer = c(TRUE, TRUE), type = "response"))
if (!all(grepl("^high", pp_df$contrast)) || !all(grepl("^high", od_df$contrast))) {
  stop_at("C3", paste("contrast labels are", paste(unique(pp_df$contrast), collapse = "; ")))
}
t13d <- tibble(
  difficulty = pp_df$difficulty_3,
  pp = 100 * pp_df$estimate, pp_lo = 100 * pp_df$asymp.LCL, pp_hi = 100 * pp_df$asymp.UCL,
  or = od_df$odds.ratio, or_lo = od_df$asymp.LCL, or_hi = od_df$asymp.UCL,
  z = od_df$z.ratio, p = od_df$p.value
)
write_csv(t13d, file.path(TAB, "T13d_accuracy_effort_contrasts.csv"))

cells <- beh %>%
  group_by(subject_id, task, difficulty_3, effort_condition) %>%
  summarise(rt_median = stats::median(rt), .groups = "drop")
if (nrow(cells) != 774L) stop_at("C4", paste("RT cells =", nrow(cells)))
m_rt <- lmer(
  rt_median ~ difficulty_3 * effort_condition + task + (1 | subject_id),
  data = cells
)
rt_fix <- tidy(m_rt, effects = "fixed", conf.int = TRUE, ddf = "Satterthwaite")
rt_sd <- as.numeric(attr(VarCorr(m_rt)$subject_id, "stddev")["(Intercept)"])
write_csv(
  rt_fix %>% mutate(effect = "fixed", source_model = "lmerTest median RT", tier = "diss_supp") %>%
    select(effect, term, estimate, std.error, df, statistic, p.value, conf.low, conf.high, source_model, tier),
  file.path(TAB, "T13c_rt_lmm.csv")
)
emm_rt <- emmeans(m_rt, ~ effort_condition | difficulty_3, weights = "equal")
rt_con <- as.data.frame(summary(contrast(emm_rt, method = "revpairwise"), infer = c(TRUE, TRUE)))
if (!all(grepl("^high", rt_con$contrast))) stop_at("C4", "RT contrast is not High - Low")
lo_col <- if ("lower.CL" %in% names(rt_con)) "lower.CL" else "asymp.LCL"
hi_col <- if ("upper.CL" %in% names(rt_con)) "upper.CL" else "asymp.UCL"
t13e <- tibble(
  difficulty = rt_con$difficulty_3,
  ms = 1000 * rt_con$estimate, ms_lo = 1000 * rt_con[[lo_col]], ms_hi = 1000 * rt_con[[hi_col]],
  t = rt_con$t.ratio, df = rt_con$df, p = rt_con$p.value
)
write_csv(t13e, file.path(TAB, "T13e_rt_effort_contrasts.csv"))

reduction <- tibble(
  outcome = c(rep("accuracy", 3), rep("rt", 3)),
  step = rep(c("maximal", "no correlation", "intercepts"), 2),
  formula_re = c(
    "(1 + effort_condition | subject_id)",
    "(1 | subject_id) + (0 + effort_c | subject_id)",
    "(1 | subject_id)",
    "(1 + effort_condition | subject_id)",
    "(1 | subject_id) + (0 + effort_c | subject_id)",
    "(1 | subject_id)"
  ),
  singular = c(TRUE, TRUE, isSingular(m_acc, tol = 1e-4), TRUE, TRUE, isSingular(m_rt, tol = 1e-4)),
  slope_sd = c(0, 0, NA, 0.011183, 0, NA),
  intercept_sd = c(0.71700968, 0.701312, acc_sd, 0.250617, 0.25614, rt_sd),
  correlation = c(-0.03126575, NA, NA, 1, NA, NA),
  optimizer = "bobyqa",
  used = c(FALSE, FALSE, TRUE, FALSE, FALSE, TRUE)
)
if (any(reduction$singular & reduction$used)) stop_at("C2", "The model in use is singular")
write_csv(reduction, file.path(TAB, "T13a_reduction_log.csv"))
message("Phase 1d tables written")
