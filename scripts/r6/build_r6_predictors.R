# R6 predictor build. Reads the r5 QC table and the cleaned flat timecourses.
# Does not modify r5 data, scripts, or fits.
#
#   Rscript scripts/r6/build_r6_predictors.R
#
# Flat files: R6_FLAT_DIR, otherwise processed_dir in config/data_paths.yaml.

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(readr)
  library(tibble)
})

ROOT <- normalizePath(Sys.getenv("PROJECT_ROOT", getwd()), mustWork = TRUE)
setwd(ROOT)
source(file.path(ROOT, "R", "trial_time_axis.R"))
QC_CSV <- "data/analysis_ready/r5/ddm_pupil_r5_qc.csv"
OUT <- "data/analysis_ready/r6"
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
stopifnot(file.exists(QC_CSV))

# Timing is the Chapter 3 clock: t = 0 at squeeze onset. Trial time is built
# the same way as the AUC script. The first sample is at -3.0 s. The flat-file
# timestamps are not a uniform 250 Hz series, so when that step does not end
# near 10.7 s the samples are placed evenly from -3.0 to 10.7 s (3,425 samples,
# the cleaned 250 Hz trial).
PROBE_ONSET <- 4.35
RESP_START <- 4.70
GRIP_START <- 1.0
GRIP_END <- PROBE_ONSET
PRECHOICE_SEC <- 0.5
COVERAGE_MIN <- 0.50
MIN_B0 <- 10L
B0_START <- -0.5
B0_END <- 0.0

flat_dir <- Sys.getenv("R6_FLAT_DIR", "")
if (!nzchar(flat_dir) && file.exists("config/data_paths.yaml")) {
  line <- grep("^processed_dir:", readLines("config/data_paths.yaml"), value = TRUE)
  if (length(line)) {
    flat_dir <- sub("^processed_dir:\\s*", "", line[[1]])
    flat_dir <- gsub("^['\"]|['\"]$", "", trimws(flat_dir))
  }
}
if (!nzchar(flat_dir) || !dir.exists(flat_dir)) {
  stop("Cleaned flat-file directory not found. Set R6_FLAT_DIR.")
}

scale_within <- function(df, raw_col, out_col) {
  df %>%
    group_by(subject_id, task, effort_condition) %>%
    mutate(.cell_mean = mean(.data[[raw_col]]), .n_cell = n()) %>%
    ungroup() %>%
    mutate(.resid = .data[[raw_col]] - .cell_mean) %>%
    group_by(subject_id) %>%
    mutate(
      .n = n(),
      .n_cells = n_distinct(paste(as.character(task), as.character(effort_condition))),
      .sd = sqrt(sum(.resid^2) / (.n - .n_cells)),
      "{out_col}" := .resid / .sd
    ) %>%
    ungroup() %>%
    select(-.cell_mean, -.n_cell, -.resid, -.n, -.n_cells, -.sd)
}

infer_dt <- function(time_vec) {
  time_vec <- time_vec[is.finite(time_vec)]
  diffs <- diff(sort(unique(time_vec)))
  diffs <- diffs[diffs > 0 & is.finite(diffs)]
  if (!length(diffs)) return(0.004)
  dt_median <- median(diffs)
  if (dt_median >= 1 && dt_median <= 10) dt_median <- dt_median / 1000
  if (!is.finite(dt_median) || dt_median <= 0 || dt_median > 0.05) 0.004 else dt_median
}

window_stats <- function(t_rel, pupil, b0, start, end) {
  in_win <- t_rel >= start & t_rel < end
  n_expected <- sum(in_win)
  empty <- list(mean = NA_real_, prop = NA_real_, n_valid = 0L, n_expected = as.integer(n_expected))
  if (!is.finite(b0)) return(c(empty, list(status = "no_baseline")))
  if (n_expected < 2L) return(c(empty, list(status = "window_outside_timecourse")))
  y <- pupil[in_win]
  n_valid <- sum(is.finite(y))
  prop <- n_valid / n_expected
  if (prop < COVERAGE_MIN) {
    return(list(mean = NA_real_, prop = prop, n_valid = as.integer(n_valid),
                n_expected = as.integer(n_expected), status = "below_coverage"))
  }
  list(
    mean = mean(y[is.finite(y)]) - b0, prop = prop, n_valid = as.integer(n_valid),
    n_expected = as.integer(n_expected), status = "ok"
  )
}

qc <- fread(QC_CSV)
qc[, `:=`(
  subject_id = as.character(subject_id),
  task = as.character(task),
  session = as.integer(session),
  run = as.integer(run),
  trial = as.integer(trial),
  rt = as.numeric(rt),
  rt_cue = as.numeric(rt_cue),
  tepr_raw = as.numeric(tepr_raw),
  tepr_c = as.numeric(tepr_c)
)]
stopifnot(nrow(qc) == 4569L, all(abs(qc$rt - qc$rt_cue - 0.35) < 1e-6))
qc[, row_id := .I]

rebuilt <- scale_within(as_tibble(qc), "tepr_raw", "tepr_c_check")
err <- max(abs(rebuilt$tepr_c_check - rebuilt$tepr_c))
if (!is.finite(err) || err > 1e-8) stop("scale_within does not reproduce r5 tepr_c (max abs diff ", err, ").")

# ---- D1. Within-subject correlation of tepr_c with probe-locked RT ----------
fisher_summary <- function(subject_rows, scope, difficulty) {
  z <- subject_rows$z
  k <- length(z)
  zbar <- mean(z)
  se <- if (k >= 2) sd(z) / sqrt(k) else NA_real_
  crit <- if (k >= 2) qt(0.975, k - 1) else NA_real_
  tibble(
    scope = scope, difficulty = difficulty, n_subjects = k,
    n_trials = sum(subject_rows$n),
    mean_r_fisher = tanh(zbar),
    ci_lo = if (is.finite(se)) tanh(zbar - crit * se) else NA_real_,
    ci_hi = if (is.finite(se)) tanh(zbar + crit * se) else NA_real_,
    mean_z = zbar, se_z = se, ci_on = "unweighted mean of Fisher z, t interval across subjects"
  )
}
subject_cor <- function(df) {
  rows <- lapply(split(df, df$subject_id), function(w) {
    n <- nrow(w)
    r <- if (n > 3 && sd(w$tepr_c) > 0 && sd(w$rt) > 0) cor(w$tepr_c, w$rt) else NA_real_
    tibble(subject_id = w$subject_id[1], n = n, r = r, z = if (is.finite(r)) atanh(pmin(pmax(r, -0.999999), 0.999999)) else NA_real_)
  })
  bind_rows(rows)
}
subj_all <- subject_cor(as_tibble(qc))
subj_all$scope <- "overall"
subj_all$difficulty <- "all"
subj_diff <- bind_rows(lapply(split(as_tibble(qc), qc$difficulty_3), function(w) {
  out <- subject_cor(w)
  out$scope <- "by_difficulty"
  out$difficulty <- w$difficulty_3[1]
  out
}))
subj_cor_tbl <- bind_rows(subj_all, subj_diff)
d1 <- bind_rows(
  fisher_summary(subj_all[is.finite(subj_all$z), ], "overall", "all"),
  bind_rows(lapply(split(subj_diff, subj_diff$difficulty), function(w) {
    fisher_summary(w[is.finite(w$z), ], "by_difficulty", w$difficulty[1])
  }))
)
write_csv(d1, file.path(OUT, "d1_tepr_rt_correlation.csv"))
write_csv(subj_cor_tbl, file.path(OUT, "d1_tepr_rt_by_subject.csv"))

# ---- D2. Lag is the previous trial's already-scaled tepr_c -------------------
# Previous means trial number - 1 in the same subject, task, session, and run.
# A missing QC trial stays missing; the lag does not skip over it.
prev <- qc[, .(subject_id, task, session, run, trial = trial + 1L, lag_tepr_c = tepr_c, lag_tepr_raw = tepr_raw)]
qc[prev, on = c("subject_id", "task", "session", "run", "trial"), `:=`(lag_tepr_c = i.lag_tepr_c, lag_tepr_raw = i.lag_tepr_raw)]
n_runs <- uniqueN(qc, by = c("subject_id", "task", "session", "run"))
n_lag <- sum(is.finite(qc$lag_tepr_c))
lag_none <- qc[, .(n_lag = sum(is.finite(lag_tepr_c))), by = subject_id][n_lag == 0, subject_id]
lag_tbl <- tibble(
  n_qc_trials = nrow(qc),
  n_runs = n_runs,
  n_with_previous_qc_trial = n_lag,
  n_missing_lag = nrow(qc) - n_lag,
  pct_retained = 100 * n_lag / nrow(qc),
  subjects_with_no_lag = paste(lag_none, collapse = ","),
  rule = "lag_tepr_c is tepr_c of trial-1 in the same subject x task x session x run; NA if that trial failed QC or does not exist. Not rescaled."
)
write_csv(lag_tbl, file.path(OUT, "lag_retention.csv"))

# ---- D2. Pre-choice and grip windows from the flat timecourses --------------
pairs <- unique(qc[, .(subject_id, task)])
pieces <- vector("list", nrow(pairs))
for (i in seq_len(nrow(pairs))) {
  subj <- pairs$subject_id[i]
  tsk <- pairs$task[i]
  path <- file.path(flat_dir, sprintf("%s_%s_flat.csv", subj, tsk))
  cat(sprintf("[%02d/%02d] %s\n", i, nrow(pairs), basename(path)))
  if (!file.exists(path)) stop("Missing flat file: ", path)
  dt <- fread(path, select = c("sub", "task", "session_used", "run_used", "trial_in_run_raw", "time", "pupil"), showProgress = FALSE)
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
  wanted <- qc[subject_id == subj & task == tsk, .(subject_id, task, session, run, trial, rt, rt_cue)]
  kept <- dt[wanted, on = c("subject_id", "task", "session", "run", "trial"), nomatch = 0]
  if (!nrow(kept)) {
    pieces[[i]] <- wanted[, .(subject_id, task, session, run, trial,
                              prechoice_raw = NA_real_, prechoice_prop = NA_real_, prechoice_n_valid = 0L,
                              prechoice_n_expected = 0L, prechoice_status = "no_timecourse",
                              grip_raw = NA_real_, grip_prop = NA_real_, grip_n_valid = 0L,
                              grip_n_expected = 0L, grip_status = "no_timecourse")]
    rm(dt, kept); next
  }
  pieces[[i]] <- kept[, {
    n <- .N
    t_rel <- build_trial_time(
      n, dt_used,
      subject = subject_id[1], task = task[1],
      session = session[1], run = run[1], trial = trial[1]
    )$t
    time_rule <- "step_from_m3"
    b0_vals <- pupil[t_rel >= B0_START & t_rel < B0_END]
    n_b0 <- sum(is.finite(b0_vals))
    b0 <- if (n_b0 >= MIN_B0) mean(b0_vals[is.finite(b0_vals)]) else NA_real_
    resp <- PROBE_ONSET + rt[1]
    if (abs(resp - (RESP_START + rt_cue[1])) > 1e-6) stop("Probe-locked and cue-locked response times disagree.")
    pre <- window_stats(t_rel, pupil, b0, resp - PRECHOICE_SEC, resp)
    grip <- window_stats(t_rel, pupil, b0, GRIP_START, GRIP_END)
    .(
      prechoice_raw = pre$mean, prechoice_prop = pre$prop, prechoice_n_valid = pre$n_valid,
      prechoice_n_expected = pre$n_expected, prechoice_status = pre$status,
      grip_raw = grip$mean, grip_prop = grip$prop, grip_n_valid = grip$n_valid,
      grip_n_expected = grip$n_expected, grip_status = grip$status,
      sampling_dt = dt_used, n_samples = n, n_b0 = as.integer(n_b0), time_rule = time_rule
    )
  }, by = .(subject_id, task, session, run, trial)]
  rm(dt, kept)
}
windows <- rbindlist(pieces, use.names = TRUE, fill = TRUE)
time_rules <- windows[!is.na(time_rule), .N, by = time_rule]
# Trials with no flat-file rows never entered `pieces` rows above only when the
# file had zero matches. Left join catches any QC key that produced no group.
if (anyDuplicated(windows, by = c("subject_id", "task", "session", "run", "trial"))) {
  stop("Window summary has duplicate trial keys.")
}
qc[windows, on = c("subject_id", "task", "session", "run", "trial"), `:=`(
  prechoice_raw = i.prechoice_raw, prechoice_prop = i.prechoice_prop,
  prechoice_n_valid = i.prechoice_n_valid, prechoice_n_expected = i.prechoice_n_expected,
  prechoice_status = i.prechoice_status,
  grip_raw = i.grip_raw, grip_prop = i.grip_prop, grip_n_valid = i.grip_n_valid,
  grip_n_expected = i.grip_n_expected, grip_status = i.grip_status,
  sampling_dt = i.sampling_dt, n_samples = i.n_samples, n_b0 = i.n_b0
)]
qc[is.na(prechoice_status), prechoice_status := "no_timecourse"]
qc[is.na(grip_status), grip_status := "no_timecourse"]

status_counts <- function(col, label) {
  tab <- qc[, .N, by = c(col)]
  setnames(tab, col, "status")
  tab[, window := label]
  tab
}
coverage <- rbind(status_counts("prechoice_status", "prechoice"), status_counts("grip_status", "grip"), fill = TRUE)
coverage[, gate := sprintf("finite B0 (>= %d samples in [-0.5, 0)) and >= %.0f%% finite pupil samples in the window", MIN_B0, 100 * COVERAGE_MIN)]
write_csv(as_tibble(coverage), file.path(OUT, "window_coverage.csv"))

# Scale the new raw windows on the trials that passed the gate. Lag is already tepr_c.
scale_back <- function(raw_col, out_col) {
  sub <- as_tibble(qc[is.finite(qc[[raw_col]])])
  if (nrow(sub) < 2L) stop("No trials to scale for ", raw_col)
  scaled <- as.data.table(scale_within(sub, raw_col, out_col))
  if (any(!is.finite(scaled[[out_col]]))) {
    bad <- scaled[!is.finite(get(out_col)), unique(subject_id)]
    stop("Pooled SD undefined for ", raw_col, ": ", paste(bad, collapse = ", "))
  }
  if (!out_col %in% names(qc)) qc[, (out_col) := NA_real_]
  idx <- match(scaled$row_id, qc$row_id)
  if (anyNA(idx)) stop("Scaled rows did not match the QC table for ", raw_col)
  set(qc, i = idx, j = out_col, value = scaled[[out_col]])
}
scale_back("prechoice_raw", "prechoice_c")
scale_back("grip_raw", "grip_c")

# Slowest 20% within subject x task, by probe-locked RT. Ties break toward the later trial number.
qc[, drop_p3_rt := {
  n_drop <- floor(0.20 * .N)
  dropped <- rep(FALSE, .N)
  if (n_drop >= 1L) {
    ord <- order(-rt, -trial)
    dropped[ord[seq_len(n_drop)]] <- TRUE
  }
  dropped
}, by = .(subject_id, task)]
qc[, keep_p3_rt := !drop_p3_rt]
p3_tbl <- qc[, .(
  n_trials = .N,
  n_dropped = sum(drop_p3_rt),
  n_kept = sum(keep_p3_rt),
  rt_slowest_kept = max(rt[!drop_p3_rt]),
  rt_fastest_dropped = if (any(drop_p3_rt)) min(rt[drop_p3_rt]) else NA_real_
), by = .(subject_id, task)]
write_csv(as_tibble(p3_tbl), file.path(OUT, "p3_rt_exclusion_by_subject_task.csv"))
p3_sum <- tibble(
  n_trials = nrow(qc), n_dropped = sum(qc$drop_p3_rt), n_kept = sum(qc$keep_p3_rt),
  rule = "Within subject x task, drop floor(0.20 * n) trials with the largest probe-locked RT. Tie break: higher trial number dropped first. tepr_c is not rescaled."
)
write_csv(p3_sum, file.path(OUT, "p3_rt_exclusion.csv"))

# Grip manipulation check: subject means of the raw grip-period dilation.
grip_ok <- as_tibble(qc[is.finite(grip_raw)])
grip_subj <- grip_ok %>%
  group_by(subject_id, task, effort_condition) %>%
  summarise(grip_raw = mean(grip_raw), n_trials = n(), .groups = "drop")
grip_cells <- grip_subj %>%
  group_by(task, effort_condition) %>%
  summarise(n_subjects = n(), mean_grip = mean(grip_raw), sd_grip = sd(grip_raw), .groups = "drop")
paired_grip <- bind_rows(lapply(split(grip_subj, grip_subj$task), function(w) {
  wide <- tidyr::pivot_wider(w, id_cols = subject_id, names_from = effort_condition, values_from = grip_raw)
  wide <- wide[is.finite(wide$high) & is.finite(wide$low), ]
  tt <- t.test(wide$high, wide$low, paired = TRUE)
  tibble(task = w$task[1], n_subjects = nrow(wide), mean_high_minus_low = mean(wide$high - wide$low),
         t = unname(tt$statistic), df = unname(tt$parameter), p = tt$p.value)
}))
write_csv(grip_cells, file.path(OUT, "grip_means_by_task_effort.csv"))
write_csv(paired_grip, file.path(OUT, "grip_paired_high_minus_low.csv"))
write_csv(grip_subj, file.path(OUT, "grip_subject_means_by_task_effort.csv"))

retention <- rbindlist(list(
  data.table(set = "P0_P5_full", n_trials = nrow(qc), n_subjects = uniqueN(qc$subject_id)),
  data.table(set = "P6_lag", n_trials = sum(is.finite(qc$lag_tepr_c)), n_subjects = uniqueN(qc[is.finite(lag_tepr_c)]$subject_id)),
  data.table(set = "P7_prechoice", n_trials = sum(is.finite(qc$prechoice_c)), n_subjects = uniqueN(qc[is.finite(prechoice_c)]$subject_id)),
  data.table(set = "P8_grip", n_trials = sum(is.finite(qc$grip_c)), n_subjects = uniqueN(qc[is.finite(grip_c)]$subject_id)),
  data.table(set = "P3_rt", n_trials = sum(qc$keep_p3_rt), n_subjects = uniqueN(qc[keep_p3_rt == TRUE]$subject_id))
))
write_csv(as_tibble(retention), file.path(OUT, "model_set_counts.csv"))

out_cols <- c(
  "subject_id", "task", "session", "run", "trial", "effort_condition", "difficulty_3",
  "stim_sign", "effort_x_stim", "choice_binary", "rt", "rt_cue",
  "tepr_raw", "baseline_raw", "tepr_c", "base_c", "B1_quality", "cog_quality",
  "lag_tepr_raw", "lag_tepr_c",
  "prechoice_raw", "prechoice_c", "prechoice_prop", "prechoice_status",
  "grip_raw", "grip_c", "grip_prop", "grip_status",
  "keep_p3_rt"
)
fwrite(qc[, ..out_cols], file.path(OUT, "ddm_pupil_r6.csv"))

report <- c(
  "# R6 predictor build",
  "",
  sprintf("Source QC table: `%s` (N = %d). Flat files: `%s`.", QC_CSV, nrow(qc), flat_dir),
  "The r5 table was not modified. scale_within reproduced stored tepr_c.",
  "",
  "## D1. tepr_c with probe-locked RT",
  "",
  "Each correlation is within subject. The reported r is tanh of the unweighted mean Fisher z. The 95% interval uses a t critical value on the across-subject SD of z. Subjects with fewer than 4 trials, or with zero variance, are left out of that average.",
  "",
  capture.output(print(as.data.frame(d1), row.names = FALSE)),
  "",
  "## D2. Predictors",
  "",
  sprintf("lag_tepr_c is the previous trial's tepr_c (already centered within subject x task x effort and divided by the subject pooled SD). It is not scaled a second time. Retained %d of %d trials (%.1f%%). There are %d subject x task x session x run blocks; the first trial of each block has no lag, and so does any trial whose predecessor failed QC. Subjects with no lag trial: %s.",
          n_lag, nrow(qc), 100 * n_lag / nrow(qc), n_runs, if (length(lag_none)) paste(lag_none, collapse = ", ") else "none"),
  "",
  "Trial time uses the AUC builder's clock. The first sample is at -3.0 s. If stepping by the file's median timestamp interval does not end near 10.7 s, samples are placed evenly from -3.0 to 10.7 s.",
  "",
  capture.output(print(as.data.frame(time_rules), row.names = FALSE)),
  "",
  sprintf("prechoice_c is the mean B0-baseline-corrected pupil on [response - 0.5 s, response). Response time on the squeeze clock is probe onset (%.2f s) + probe-locked RT, which equals response-window onset (%.2f s) + cue-locked RT. grip_c is the mean on [squeeze + %.1f s, probe onset %.2f s). B0 is the mean pupil on [%.1f, 0) and requires at least %d finite samples, the same rule as the AUC builder. A trial is kept when at least %.0f%% of samples inside the window are finite. Both kept series are then centered and scaled with the r5 scale_within function on the trials that passed.",
          PROBE_ONSET, RESP_START, GRIP_START, GRIP_END, B0_START, MIN_B0, 100 * COVERAGE_MIN),
  "",
  "### Window status",
  "",
  capture.output(print(as.data.frame(coverage), row.names = FALSE)),
  "",
  "### Trials available for each model set",
  "",
  capture.output(print(as.data.frame(retention), row.names = FALSE)),
  "",
  "### Raw grip-period dilation by task x effort",
  "",
  "Means are means of subject-level means, on trials that passed the grip gate. High is 40% MVC and low is 5% MVC. The test is a subject-level paired High - Low t-test.",
  "",
  capture.output(print(as.data.frame(grip_cells), row.names = FALSE)),
  "",
  capture.output(print(as.data.frame(paired_grip), row.names = FALSE)),
  "",
  sprintf("P3_rt keeps %d of %d trials after dropping the slowest 20%% within each subject x task. tepr_c is the r5 value, not recomputed on the reduced set.",
          sum(qc$keep_p3_rt), nrow(qc)),
  "",
  "Modeling file: ddm_pupil_r6.csv."
)
writeLines(report, file.path(OUT, "r6_build_report.md"))
cat("Wrote ", OUT, "\n", sep = "")
print(as.data.frame(retention))
print(as.data.frame(d1))
print(as.data.frame(paired_grip))
