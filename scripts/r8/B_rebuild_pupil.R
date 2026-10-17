# Part B. Rebuild the pupil sample from the December 21 flat files only.
# Does not modify r5, r6, the stored trial table, or the flat files.

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(readr)
  library(tibble)
})

ROOT <- normalizePath(getwd(), mustWork = TRUE)
setwd(ROOT)
PARENT <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
OUT <- "data/analysis_ready/r8"
DIAG <- "output/diagnostics/pupil_rebuild"
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(DIAG, recursive = TRUE, showWarnings = FALSE)

BEH <- "data/analysis_ready/r5/ddm_behavioral_r5_full17857.csv"
# r5 QC file, used only to check the 3,925-trial match. Not a final output.
R5 <- file.path("data", "analysis_ready", "r5", paste0("ddm_pupil_", "r5_qc.csv"))
stopifnot(file.exists(BEH), file.exists(R5), dir.exists(PARENT))

# make_quick_share_v7.R lines 92-184. Gaps > 250 ms are not bridged. No interpolation.
compute_auc <- function(time, value, gap_max_ms = 250) {
  valid <- is.finite(time) & is.finite(value)
  if (sum(valid) < 2L) return(NA_real_)
  time <- time[valid]
  value <- value[valid]
  ord <- order(time)
  time <- time[ord]
  value <- value[ord]
  n <- length(time)
  dt <- diff(time)
  gap <- dt > gap_max_ms / 1000
  if (!any(gap)) {
    return(sum(dt * (value[-n] + value[-1]) / 2))
  }
  seg <- cumsum(c(0, gap)) + 1L
  auc <- 0
  for (s in unique(seg)) {
    m <- seg == s
    if (sum(m) < 2L) next
    ts <- time[m]
    ys <- value[m]
    d <- diff(ts)
    auc <- auc + sum(d * (ys[-length(ys)] + ys[-1]) / 2)
  }
  auc
}

# make_quick_share_v7.R lines 214-232. File-level median of unique positive diffs.
file_dt <- function(time_vec) {
  d <- diff(sort(unique(time_vec[is.finite(time_vec)])))
  d <- d[is.finite(d) & d > 0]
  if (!length(d)) return(0.004)
  dt <- median(d)
  if (dt >= 1 && dt <= 10) dt <- dt / 1000
  if (!is.finite(dt) || dt <= 0) 0.004 else dt
}

# lines 411-425, now guarded. Even spacing onto -3 to 10.7 is refused.
source("R/trial_time_axis.R")
trial_time <- function(n, dt, subject = NA, task = NA, session = NA, run = NA, trial = NA,
                       seg_start = NA_real_, seg_end = NA_real_) {
  build_trial_time(n, dt, seg_start, seg_end, subject, task, session, run, trial)
}

# build_pupil_trial_coverage_prefilter.R lines 67-78, on the builder axis.
prop_valid <- function(t, pupil, start, end) {
  in_win <- is.finite(t) & t >= start & t <= end
  if (!any(in_win)) return(NA_real_)
  mean(is.finite(pupil[in_win]))
}

window_mean <- function(t, pupil, b0, start, end) {
  in_win <- t >= start & t < end
  n_expected <- sum(in_win)
  if (!is.finite(b0)) {
    return(list(mean = NA_real_, prop = NA_real_, n_valid = 0L, n_expected = n_expected, status = "no_baseline"))
  }
  if (n_expected < 2L) {
    return(list(mean = NA_real_, prop = NA_real_, n_valid = 0L, n_expected = n_expected, status = "window_outside_timecourse"))
  }
  y <- pupil[in_win]
  n_valid <- sum(is.finite(y))
  prop <- n_valid / n_expected
  if (prop < 0.50) {
    return(list(mean = NA_real_, prop = prop, n_valid = as.integer(n_valid), n_expected = n_expected, status = "below_coverage"))
  }
  list(mean = mean(y[is.finite(y)]) - b0, prop = prop, n_valid = as.integer(n_valid),
       n_expected = n_expected, status = "ok")
}

beh <- fread(BEH)
beh[, `:=`(subject_id = as.character(subject_id), task = as.character(task),
           session = as.integer(session), run = as.integer(run), trial = as.integer(trial))]
stopifnot(nrow(beh) == 17857L, anyDuplicated(beh, by = c("subject_id", "task", "session", "run", "trial")) == 0L)

r5 <- fread(R5)
r5[, `:=`(subject_id = as.character(subject_id), task = as.character(task),
          session = as.integer(session), run = as.integer(run), trial = as.integer(trial))]

pairs <- unique(beh[, .(subject_id, task)])
cat("Behavioral subject x task pairs:", nrow(pairs), "\n")

pieces <- vector("list", nrow(pairs))
manifest <- vector("list", nrow(pairs))
for (i in seq_len(nrow(pairs))) {
  subj <- pairs$subject_id[i]
  tsk <- pairs$task[i]
  path <- file.path(PARENT, sprintf("%s_%s_flat.csv", subj, tsk))
  cat(sprintf("[%02d/%02d] %s\n", i, nrow(pairs), basename(path)))
  wanted <- beh[subject_id == subj & task == tsk]
  if (!file.exists(path)) {
    pieces[[i]] <- wanted[, .(subject_id, task, session, run, trial, matched = FALSE)]
    next
  }
  manifest[[i]] <- data.table(
    path = path, bytes = file.info(path)$size, md5 = unname(tools::md5sum(path))
  )
  dt <- fread(path, select = c("session_used", "run_used", "trial_in_run_raw", "time", "pupil"), showProgress = FALSE)
  setnames(dt, c("session_used", "run_used", "trial_in_run_raw"), c("session", "run", "trial"))
  dt[, `:=`(session = as.integer(session), run = as.integer(run), trial = as.integer(trial),
            time = as.numeric(time), pupil = as.numeric(pupil))]
  dt <- dt[session %in% c(2L, 3L)]
  dt[, `:=`(subject_id = subj, task = tsk)]
  dt_used <- file_dt(dt$time)
  kept <- dt[wanted, on = c("subject_id", "task", "session", "run", "trial"), nomatch = NULL]
  if (!nrow(kept)) {
    pieces[[i]] <- wanted[, .(subject_id, task, session, run, trial, matched = FALSE)]
    rm(dt); next
  }
  pieces[[i]] <- kept[, {
    n <- .N
    ax <- tryCatch(
      trial_time(n, dt_used, subject_id[1], task[1], session[1], run[1], trial[1]),
      error = function(e) NULL
    )
    if (is.null(ax)) {
      list(
        matched = TRUE, n_samples = n, time_rule = "refused", sampling_dt = dt_used,
        baseline_raw = NA_real_, n_b0 = 0L,
        b1_mean = NA_real_, n_b1 = 0L, B1_quality = NA_real_,
        tepr_raw = NA_real_, auc_b0 = NA_real_, cog_quality = NA_real_,
        prechoice_raw = NA_real_, prechoice_prop = NA_real_, prechoice_status = "refused_axis",
        grip_raw = NA_real_, grip_prop = NA_real_, grip_status = "refused_axis"
      )
    } else {
    t_rel <- ax$t
    b0_vals <- pupil[t_rel >= -0.5 & t_rel < 0]
    n_b0 <- sum(is.finite(b0_vals))
    b0 <- if (n_b0 >= 10L) mean(b0_vals[is.finite(b0_vals)]) else NA_real_
    # B1 quality and the cognitive-window quality are finite-sample proportions
    # on this same axis. B1 is [3.85, 4.35), the baseline used for tepr_raw.
    # The cognitive window is [4.05, 5.05]. Neither uses an even -3 to 10.7 grid.
    b1_in <- t_rel >= 3.85 & t_rel < 4.35
    n_b1 <- sum(is.finite(pupil[b1_in]))
    b1 <- if (n_b1 >= 10L) mean(pupil[b1_in][is.finite(pupil[b1_in])]) else NA_real_
    b1_quality <- if (any(b1_in)) mean(is.finite(pupil[b1_in])) else NA_real_
    w3 <- t_rel >= 4.65 & t_rel <= 7.65
    tepr <- if (is.finite(b1)) compute_auc(t_rel[w3], pupil[w3] - b1) else NA_real_
    auc_b0 <- if (is.finite(b0)) compute_auc(t_rel[w3], pupil[w3] - b0) else NA_real_
    cog_in <- t_rel >= 4.05 & t_rel <= 5.05
    cog_q <- if (any(cog_in)) mean(is.finite(pupil[cog_in])) else NA_real_
    pre <- window_mean(t_rel, pupil, b0, 4.35 + rt[1] - 0.5, 4.35 + rt[1])
    grip <- window_mean(t_rel, pupil, b0, 1.0, 4.35)
    list(
      matched = TRUE, n_samples = n, time_rule = ax$rule, sampling_dt = dt_used,
      baseline_raw = b0, n_b0 = as.integer(n_b0),
      b1_mean = b1, n_b1 = as.integer(n_b1), B1_quality = b1_quality,
      tepr_raw = tepr, auc_b0 = auc_b0, cog_quality = cog_q,
      prechoice_raw = pre$mean, prechoice_prop = pre$prop, prechoice_status = pre$status,
      grip_raw = grip$mean, grip_prop = grip$prop, grip_status = grip$status
    )
    }
  }, by = .(subject_id, task, session, run, trial)]
  missed <- wanted[!pieces[[i]], on = c("subject_id", "task", "session", "run", "trial")]
  if (nrow(missed)) {
    pieces[[i]] <- rbind(pieces[[i]], missed[, .(subject_id, task, session, run, trial, matched = FALSE)], fill = TRUE)
  }
  rm(dt, kept)
}
trials <- rbindlist(pieces, fill = TRUE)
man <- rbindlist(manifest)
fwrite(man, file.path(OUT, "flat_file_manifest.csv"))
fwrite(trials, file.path(OUT, "ddm_pupil_r8_matched_metrics.csv"))
cat("Rows", nrow(trials), "matched", sum(trials$matched, na.rm = TRUE), "files", nrow(man), "\n")

# ---- Verification against r5 before the gates are treated as final ----------
cmp <- merge(
  r5[, .(subject_id, task, session, run, trial, tepr_r5 = tepr_raw, tepr_c_r5 = tepr_c,
         B1_r5 = B1_quality, cog_r5 = cog_quality, base_r5 = baseline_raw)],
  trials[matched == TRUE, .(subject_id, task, session, run, trial, tepr_raw, B1_quality, cog_quality, baseline_raw)],
  by = c("subject_id", "task", "session", "run", "trial"),
  all.x = TRUE
)
cmp[, abs_tepr := abs(tepr_raw - tepr_r5)]
n_r5_in_r8 <- sum(is.finite(cmp$tepr_raw))
n_exact <- sum(cmp$abs_tepr < 1e-4, na.rm = TRUE)
n_far <- sum(cmp$abs_tepr >= 1e-4, na.rm = TRUE)
cat(sprintf("r5 QC trials with an r8 tepr: %d; within 1e-4: %d; at least 1e-4: %d; missing r8: %d\n",
            n_r5_in_r8, n_exact, n_far, sum(!is.finite(cmp$tepr_raw))))
cat(sprintf("r(tepr) all shared finite: %.4f\n", cor(cmp$tepr_raw, cmp$tepr_r5, use = "complete.obs")))
if (n_exact > 0) cat(sprintf("r on within-1e-4: %.6f; max abs %.3g\n",
                             cor(cmp$tepr_raw[cmp$abs_tepr < 1e-4], cmp$tepr_r5[cmp$abs_tepr < 1e-4]),
                             max(cmp$abs_tepr[cmp$abs_tepr < 1e-4])))
if (n_far > 0) cat(sprintf("r on >=1e-4: %.4f; n %d\n",
                           cor(cmp$tepr_raw[cmp$abs_tepr >= 1e-4], cmp$tepr_r5[cmp$abs_tepr >= 1e-4]), n_far))
# The previous diagnosis's 3,925 are the r5 trials whose stored tepr already
# matched a December 21 rebuild. Require that set to match again.
if (n_exact < 3925L) {
  msg <- sprintf(paste(
    "STOP. December 21 was selected, but only %d of the r5 QC trials match",
    "stored tepr_raw within 1e-4 (required: the 3,925). Shared finite %d, farther than 1e-4: %d."
  ), n_exact, n_r5_in_r8, n_far)
  writeLines(msg, file.path(DIAG, "STOPPED.md"))
  cat(msg, "\n")
  quit(status = 2)
}

# ---- Gates, in the r5 order --------------------------------------------------
matched <- merge(beh, trials[matched == TRUE], by = c("subject_id", "task", "session", "run", "trial"), all.x = FALSE)
stopifnot(nrow(matched) == sum(trials$matched, na.rm = TRUE))
g0 <- matched
g1 <- g0[is.finite(tepr_raw)]
g2 <- g1[is.finite(B1_quality) & B1_quality >= 0.50]
g3 <- g2[is.finite(cog_quality) & cog_quality >= 0.50]
cell_n <- g3[, .N, by = .(subject_id, task)]
keep <- cell_n[N >= 20, .(subject_id, task)]
drop <- cell_n[N < 20]
g4 <- g3[keep, on = c("subject_id", "task"), nomatch = NULL]
gate <- rbindlist(list(
  g0[, .(gate = "matched", n_trials = .N, n_subjects = uniqueN(subject_id), n_subject_task = uniqueN(paste(subject_id, task)))],
  g1[, .(gate = "tepr_nonmissing", n_trials = .N, n_subjects = uniqueN(subject_id), n_subject_task = uniqueN(paste(subject_id, task)))],
  g2[, .(gate = "B1_quality_ge_0.50", n_trials = .N, n_subjects = uniqueN(subject_id), n_subject_task = uniqueN(paste(subject_id, task)))],
  g3[, .(gate = "cog_quality_ge_0.50", n_trials = .N, n_subjects = uniqueN(subject_id), n_subject_task = uniqueN(paste(subject_id, task)))],
  g4[, .(gate = "subject_task_ge_20", n_trials = .N, n_subjects = uniqueN(subject_id), n_subject_task = uniqueN(paste(subject_id, task)))]
))
print(gate)
fwrite(gate, file.path(OUT, "qc_gate_counts.csv"))
fwrite(drop, file.path(OUT, "dropped_subject_task_cells.csv"))

scale_within <- function(df, raw_col, out_col) {
  # Rows with a missing raw value are removed before the mean. That is the
  # na.rm = TRUE mean, and one missing trial cannot turn a cell mean into NA.
  # tepr_raw has no missing values after the gates. baseline, pre-choice, and
  # grip are scaled on the finite subset only; the other trials stay NA.
  df <- as.data.table(df)
  use <- df[is.finite(df[[raw_col]])]
  if (nrow(use) < 2L) stop("No finite rows to scale for ", raw_col)
  use %>%
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

qc <- as.data.table(scale_within(g4, "tepr_raw", "tepr_c"))
if (any(!is.finite(qc$tepr_c))) {
  writeLines("STOP. Pooled within-cell SD was undefined for tepr_c.", file.path(DIAG, "STOPPED.md"))
  quit(status = 2)
}
qc[, row_id := .I]
base_scaled <- as.data.table(scale_within(qc, "baseline_raw", "base_c"))
qc[, base_c := NA_real_]
qc[match(base_scaled$row_id, row_id), base_c := base_scaled$base_c]

# Lag is the previous QC trial's tepr_c. It is not scaled again (r6).
qc[, row_id := .I]
prev <- qc[, .(subject_id, task, session, run, trial = trial + 1L, lag_tepr_c = tepr_c, lag_tepr_raw = tepr_raw)]
qc[prev, on = c("subject_id", "task", "session", "run", "trial"),
   `:=`(lag_tepr_c = i.lag_tepr_c, lag_tepr_raw = i.lag_tepr_raw)]

attach_scaled <- function(raw_col, out_col) {
  scaled <- as.data.table(scale_within(as_tibble(qc), raw_col, out_col))
  if (!out_col %in% names(qc)) qc[, (out_col) := NA_real_]
  idx <- match(scaled$row_id, qc$row_id)
  set(qc, i = idx, j = out_col, value = scaled[[out_col]])
}
attach_scaled("prechoice_raw", "prechoice_c")
attach_scaled("grip_raw", "grip_c")

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

qc_cols <- c(
  "subject_id", "task", "session", "run", "trial", "effort_condition", "difficulty_3",
  "stim_sign", "effort_x_stim", "choice_binary", "rt", "rt_cue",
  "tepr_raw", "baseline_raw", "tepr_c", "base_c", "B1_quality", "cog_quality", "auc_b0"
)
fwrite(qc[, ..qc_cols], file.path(OUT, "ddm_pupil_r8_qc.csv"))
full_cols <- c(qc_cols, "lag_tepr_raw", "lag_tepr_c",
               "prechoice_raw", "prechoice_c", "prechoice_prop", "prechoice_status",
               "grip_raw", "grip_c", "grip_prop", "grip_status", "keep_p3_rt")
fwrite(qc[, ..full_cols], file.path(OUT, "ddm_pupil_r8.csv"))
fwrite(qc[is.finite(lag_tepr_c)], file.path(OUT, "ddm_pupil_r8_lag.csv"))
fwrite(qc[is.finite(prechoice_c)], file.path(OUT, "ddm_pupil_r8_prechoice.csv"))
fwrite(qc[is.finite(grip_c)], file.path(OUT, "ddm_pupil_r8_grip.csv"))
fwrite(qc[keep_p3_rt == TRUE], file.path(OUT, "ddm_pupil_r8_rt.csv"))

# Enter / leave relative to r5
keys_r5 <- r5[, .(subject_id, task, session, run, trial)]
keys_r8 <- qc[, .(subject_id, task, session, run, trial)]
entered <- keys_r8[!keys_r5, on = c("subject_id", "task", "session", "run", "trial")]
left <- keys_r5[!keys_r8, on = c("subject_id", "task", "session", "run", "trial")]
cat("Entered QC vs r5:", nrow(entered), " Left:", nrow(left), "\n")
fwrite(entered, file.path(OUT, "qc_entered_vs_r5.csv"))
fwrite(left, file.path(OUT, "qc_left_vs_r5.csv"))

# Why the r5 trials left: last gate they fail in r8
left_why <- merge(left, trials, by = c("subject_id", "task", "session", "run", "trial"), all.x = TRUE)
left_why[, reason := fcase(
  !matched %in% TRUE, "no December 21 flat trial",
  !is.finite(tepr_raw), "tepr missing (B1 < 10 finite samples or < 2 window samples)",
  !is.finite(B1_quality) | B1_quality < 0.50, "B1_quality < 0.50",
  !is.finite(cog_quality) | cog_quality < 0.50, "cog_quality < 0.50",
  !paste(subject_id, task) %in% paste(keep$subject_id, keep$task), "subject x task under 20 trials",
  !is.finite(baseline_raw), "B0 mean missing",
  default = "other"
)]
why <- left_why[, .N, by = reason]
print(why)
fwrite(why, file.path(OUT, "qc_left_reasons.csv"))
fwrite(cmp, file.path(DIAG, "partB_tepr_comparison.csv"))

both <- merge(cmp[is.finite(tepr_raw)], qc[, .(subject_id, task, session, run, trial, tepr_c)],
              by = c("subject_id", "task", "session", "run", "trial"), all.x = TRUE)
cat(sprintf("FINAL within 1e-4 %d of %d r5 QC; r all finite %.4f; r far %.4f\n",
            n_exact, nrow(r5),
            cor(cmp$tepr_raw, cmp$tepr_r5, use = "complete.obs"),
            if (n_far) cor(cmp$tepr_raw[cmp$abs_tepr >= 1e-4], cmp$tepr_r5[cmp$abs_tepr >= 1e-4]) else NA_real_))
cat("QC N", nrow(qc), "subjects", uniqueN(qc$subject_id), "\n")
cat("lag", sum(is.finite(qc$lag_tepr_c)), "pre", sum(is.finite(qc$prechoice_c)),
    "grip", sum(is.finite(qc$grip_c)), "rt", sum(qc$keep_p3_rt), "\n")
