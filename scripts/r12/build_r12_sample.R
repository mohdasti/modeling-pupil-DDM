# Build the r12 pupil sample from the Chapter 2 250 Hz export.
# Computes the 0.5 s pre-response window from the December 21 flat files.
# Does not fit a model.

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(tibble)
})

ROOT <- normalizePath(getwd(), mustWork = TRUE)
setwd(ROOT)
source("R/trial_time_axis.R")

SRC_CH3 <- "/Users/mohdasti/Documents/GitHub/Psychometrics_Pupillometry/data/analysis_ready/ch2_r2/ch2r2_20261024_140108/ch3_compatible_pupil_r2.csv"
SRC_CH2 <- "/Users/mohdasti/Documents/GitHub/Psychometrics_Pupillometry/data/analysis_ready/ch2_r2/ch2r2_20261024_140108/ch2_pupil_trials_r2.csv"
EXPECT_CH3 <- "b51234f74d7bea76d41a851b863aec59"
EXPECT_CH2 <- "7d3f64607eb5ac947155d5cffc4e8cff"
BEH <- "data/analysis_ready/r5/ddm_behavioral_r5_full17857.csv"
PARENT <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
OUT <- "data/analysis_ready/r12"
DIAG <- "output/diagnostics/ch3_d017"
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(DIAG, recursive = TRUE, showWarnings = FALSE)

stop_part <- function(step, msg) {
  writeLines(c(
    "Part: B",
    paste("Step:", step),
    "Error:",
    msg
  ), file.path(DIAG, "STOPPED.md"))
  stop(msg, call. = FALSE)
}

md5_file <- function(path) unname(tools::md5sum(path))
if (!file.exists(SRC_CH3)) stop_part("B1.1", paste("Missing", SRC_CH3))
got <- md5_file(SRC_CH3)
if (!identical(got, EXPECT_CH3)) {
  stop_part("B1.1", paste("ch3_compatible_pupil_r2.csv md5", got, "expected", EXPECT_CH3))
}
if (!file.exists(SRC_CH2)) stop_part("B1.1", paste("Missing", SRC_CH2))
got2 <- md5_file(SRC_CH2)
if (!identical(got2, EXPECT_CH2)) {
  stop_part("B1.1", paste("ch2_pupil_trials_r2.csv md5", got2, "expected", EXPECT_CH2))
}
file.copy(SRC_CH3, file.path(OUT, "ch3_compatible_pupil_r2.csv"), overwrite = TRUE)
if (!identical(md5_file(file.path(OUT, "ch3_compatible_pupil_r2.csv")), EXPECT_CH3)) {
  stop_part("B1.1", "Copy of ch3_compatible_pupil_r2.csv did not keep the source md5.")
}

id <- c("subject_id", "task", "session", "run", "trial")
beh <- fread(BEH)
ch3 <- fread(SRC_CH3)
ch2 <- fread(SRC_CH2, select = c(id, "effort", "stim_level_index", "is_high_grip", "n", "b0_quality", "time_rule"))
for (dt in list(beh, ch3, ch2)) {
  dt[, `:=`(subject_id = as.character(subject_id), task = as.character(task),
            session = as.integer(session), run = as.integer(run), trial = as.integer(trial))]
}
if (nrow(beh) != 17857L || anyDuplicated(beh, by = id) > 0L) {
  stop_part("B2.1", paste("Behavioral file has", nrow(beh), "rows."))
}
if (nrow(ch3) != 17857L) stop_part("B1.2", paste("Chapter 3 pupil file has", nrow(ch3), "rows, expected 17857."))

map_diff <- function(level) {
  fifelse(level == 0, "Standard",
          fifelse(level %in% c(1, 2), "Hard",
                  fifelse(level %in% c(3, 4), "Easy", NA_character_)))
}

lab <- merge(beh, ch2, by = id, all.x = TRUE)
matched_lab <- lab[time_rule == "fixed_250hz_from_m3"]
matched_lab[, effort_ok := tolower(effort) == tolower(effort_condition)]
matched_lab[, diff_from_ch2 := map_diff(stim_level_index)]
matched_lab[, diff_ok := diff_from_ch2 == difficulty_3]
n_bad_effort <- matched_lab[!(effort_ok %in% TRUE), .N]
n_bad_diff <- matched_lab[!(diff_ok %in% TRUE), .N]
if (n_bad_effort > 0L || n_bad_diff > 0L) {
  stop_part("B2.1", sprintf(
    "Labels disagree on matched trials: effort %d / %d, difficulty %d / %d.",
    n_bad_effort, nrow(matched_lab), n_bad_diff, nrow(matched_lab)
  ))
}

# Gates. Coverage columns are the 250 Hz export: B1_quality is [3.85, 4.35),
# cog_quality is the TEPR window [4.65, 7.65].
pupil <- merge(beh, ch3, by = id, all.x = TRUE)
pupil[ch2, on = id, `:=`(n_samples = i.n, b0_quality = i.b0_quality, ch2_effort = i.effort)]
present <- pupil[time_rule == "fixed_250hz_from_m3" & is.finite(tepr_mean_465_765)]
g_b1 <- present[is.finite(B1_quality) & B1_quality >= 0.50]
g_win <- g_b1[is.finite(cog_quality) & cog_quality >= 0.50]
cell_n <- g_win[, .N, by = .(subject_id, task)]
keep_cells <- cell_n[N >= 20, .(subject_id, task)]
qc <- g_win[keep_cells, on = c("subject_id", "task"), nomatch = NULL]
if (nrow(qc) < 100L) stop_part("B2.2", paste("QC sample has only", nrow(qc), "trials."))

gates <- data.table(
  gate = c("behavioral", "250hz_tepr_present", "preprobe_coverage_ge_0.50",
           "tepr_window_coverage_ge_0.50", "ge_20_per_subject_task"),
  trials = c(nrow(beh), nrow(present), nrow(g_b1), nrow(g_win), nrow(qc)),
  subjects = c(uniqueN(beh$subject_id), uniqueN(present$subject_id), uniqueN(g_b1$subject_id),
               uniqueN(g_win$subject_id), uniqueN(qc$subject_id)),
  cells = c(uniqueN(paste(beh$subject_id, beh$task)), uniqueN(paste(present$subject_id, present$task)),
            uniqueN(paste(g_b1$subject_id, g_b1$task)), uniqueN(paste(g_win$subject_id, g_win$task)),
            uniqueN(paste(qc$subject_id, qc$task))),
  r10_trials = c(17857L, 7806L, 5895L, 5077L, 4935L),
  r10_subjects = c(67L, 54L, 52L, 49L, 43L)
)
fwrite(gates, file.path(DIAG, "r12_gates.csv"))

epoch <- qc[, .N, by = .(n_samples)]
epoch[, epoch_type := fifelse(n_samples %in% c(3425L, 3426L), "full_250hz",
                               fifelse(n_samples >= 2673L & n_samples <= 2730L, "short_250hz", "other"))]
if (any(epoch$epoch_type == "other")) {
  stop_part("B1.3", paste("QC trials with an unaccepted sample count:", paste(epoch[epoch_type == "other"]$n_samples, collapse = ", ")))
}
fwrite(epoch, file.path(DIAG, "r12_epoch_counts.csv"))

scale_within <- function(df, raw_col, out_col) {
  df <- as.data.table(df)
  use <- df[is.finite(df[[raw_col]])]
  if (nrow(use) < 2L) stop_part("B2.3", paste("No finite rows to scale for", raw_col))
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

qc <- as.data.table(scale_within(qc, "tepr_mean_465_765", "tepr_c"))
if (any(!is.finite(qc$tepr_c))) stop_part("B2.3", "Pooled within-cell SD was undefined for tepr_c.")
qc[, row_id := .I]
base_scaled <- as.data.table(scale_within(qc, "baseline_raw", "base_c"))
qc[, base_c := NA_real_]
qc[match(base_scaled$row_id, row_id), base_c := base_scaled$base_c]

qc <- qc[order(subject_id, task, session, run, trial)]
qc[, `:=`(lag_tepr_c = shift(tepr_c), lag_tepr_raw = shift(tepr_mean_465_765)),
   by = .(subject_id, task, session, run)]

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

window_mean <- function(t, pupil, b0, start, end) {
  in_win <- t >= start & t < end
  n_expected <- sum(in_win)
  if (!is.finite(b0) || n_expected < 2L) {
    return(list(mean = NA_real_, prop = if (n_expected > 0L) mean(is.finite(pupil[in_win])) else NA_real_))
  }
  y <- pupil[in_win]
  prop <- mean(is.finite(y))
  if (prop < 0.50) return(list(mean = NA_real_, prop = prop))
  list(mean = mean(y[is.finite(y)]) - b0, prop = prop)
}

pairs <- unique(qc[, .(subject_id, task)])
pieces <- vector("list", nrow(pairs))
dip_pieces <- vector("list", nrow(pairs))
grid <- seq(2.5, 4.5, by = 0.02)
max_abs <- 0
n_checked <- 0L
for (i in seq_len(nrow(pairs))) {
  subj <- pairs$subject_id[i]
  tsk <- pairs$task[i]
  path <- file.path(PARENT, sprintf("%s_%s_flat.csv", subj, tsk))
  wanted <- qc[subject_id == subj & task == tsk, .(subject_id, task, session, run, trial, rt, row_id)]
  if (!file.exists(path)) stop_part("B1.2", paste("Flat file missing for a QC cell:", path))
  dt <- fread(path, select = c("session_used", "run_used", "trial_in_run_raw", "pupil"), showProgress = FALSE)
  setnames(dt, c("session_used", "run_used", "trial_in_run_raw"), c("session", "run", "trial"))
  dt <- dt[session %in% c(2L, 3L)]
  dt[, `:=`(session = as.integer(session), run = as.integer(run), trial = as.integer(trial))]
  kept <- dt[wanted, on = c("session", "run", "trial"), nomatch = NULL]
  if (uniqueN(kept, by = c("session", "run", "trial")) != nrow(wanted)) {
    stop_part("B1.2", sprintf("Flat file %s is missing %d QC trials.", basename(path),
                              nrow(wanted) - uniqueN(kept, by = c("session", "run", "trial"))))
  }
  one <- kept[, {
    n <- .N
    ax <- tryCatch(
      build_trial_time(n, subject = subject_id[1], task = task[1], session = session[1], run = run[1], trial = trial[1]),
      error = function(e) e
    )
    if (inherits(ax, "error")) stop_part("B1.3", conditionMessage(ax))
    t_rel <- ax$t
    b0_vals <- pupil[t_rel >= -0.5 & t_rel < 0]
    b0 <- if (sum(is.finite(b0_vals)) >= 10L) mean(b0_vals[is.finite(b0_vals)]) else NA_real_
    b1_in <- t_rel >= 3.85 & t_rel < 4.35
    b1 <- if (sum(is.finite(pupil[b1_in])) >= 10L) mean(pupil[b1_in][is.finite(pupil[b1_in])]) else NA_real_
    w <- t_rel >= 4.65 & t_rel <= 7.65
    te_mean <- if (is.finite(b1) && any(is.finite(pupil[w]))) mean((pupil[w] - b1)[is.finite(pupil[w])]) else NA_real_
    pre <- window_mean(t_rel, pupil, b0, 4.35 + rt[1] - 0.5, 4.35 + rt[1])
    y <- if (is.finite(b0)) pupil - b0 else rep(NA_real_, n)
    ok <- is.finite(t_rel) & is.finite(y)
    yy <- if (sum(ok) >= 10L) stats::approx(t_rel[ok], y[ok], xout = grid, rule = 1, ties = "ordered")$y else rep(NA_real_, length(grid))
    list(prechoice_raw = pre$mean, prechoice_prop = pre$prop, te_recompute = te_mean,
         dip_y = list(yy), time_rule_axis = ax$rule, n_axis = n)
  }, by = .(subject_id, task, session, run, trial, row_id)]
  stored <- qc[subject_id == subj & task == tsk, .(row_id, tepr_mean_465_765)]
  cmp <- merge(one, stored, by = "row_id")
  abs_d <- abs(cmp$te_recompute - cmp$tepr_mean_465_765)
  max_abs <- max(max_abs, max(abs_d, na.rm = TRUE))
  n_checked <- n_checked + nrow(cmp)
  if (median(abs_d, na.rm = TRUE) > 1e-4) {
    stop_part("B1.2", sprintf(
      "Recomputed TEPR mean does not match the 250 Hz export for %s %s (median abs %.4g).",
      subj, tsk, median(abs_d, na.rm = TRUE)
    ))
  }
  pieces[[i]] <- one[, .(row_id, prechoice_raw, prechoice_prop, time_rule_axis, n_axis)]
  ys <- one$dip_y
  if (is.matrix(ys)) {
    mat <- ys
  } else {
    mat <- do.call(rbind, lapply(ys, function(v) if (is.null(v)) rep(NA_real_, length(grid)) else as.numeric(v)))
  }
  wave <- colMeans(mat, na.rm = TRUE)
  dip_at <- if (all(!is.finite(wave))) NA_real_ else grid[which.min(wave)]
  dip_pieces[[i]] <- data.table(
    subject_id = subj, task = tsk,
    dip_latency = dip_at,
    n_trials = nrow(one)
  )
  rm(dt, kept)
  if (i %% 10L == 0L) cat("flat files", i, "/", nrow(pairs), "\n")
}
pre <- rbindlist(pieces)
qc[pre, on = "row_id", `:=`(prechoice_raw = i.prechoice_raw, prechoice_prop = i.prechoice_prop,
                            time_rule_axis = i.time_rule_axis, n_axis = i.n_axis)]
if (any(!qc$time_rule_axis %in% c("fixed_250hz", "short_epoch_250hz"))) {
  stop_part("B1.3", "A QC trial was not accepted by the 250 Hz guard.")
}
qc[, prechoice_c := NA_real_]
pre_scaled <- as.data.table(scale_within(qc, "prechoice_raw", "prechoice_c"))
qc[match(pre_scaled$row_id, row_id), prechoice_c := pre_scaled$prechoice_c]
grip_scaled <- as.data.table(scale_within(qc, "grip_raw", "grip_c"))
qc[, grip_c := NA_real_]
qc[match(grip_scaled$row_id, row_id), grip_c := grip_scaled$grip_c]

dips <- rbindlist(dip_pieces)
fwrite(dips, file.path(DIAG, "r12_dip_by_cell.csv"))
dips_ok <- dips[is.finite(dip_latency)]
dip_sum <- data.table(
  n_cells = nrow(dips_ok),
  median = median(dips_ok$dip_latency),
  iqr = IQR(dips_ok$dip_latency),
  q25 = as.numeric(quantile(dips_ok$dip_latency, 0.25)),
  q75 = as.numeric(quantile(dips_ok$dip_latency, 0.75)),
  r10_median = 3.12,
  r10_n_cells = 61L,
  tepr_recompute_max_abs = max_abs,
  tepr_recompute_n = n_checked
)
fwrite(dip_sum, file.path(DIAG, "r12_dip.csv"))

# The within-participant x task (no effort) P3 slope is a model fit.
# Fifteen pupil models are already the VM job, and one extra brms fit
# will not finish in 10 minutes. It is not run.
qc[, centering_note := "within participant x task x effort; pooled within-cell SD"]

qc_cols <- c(
  "subject_id", "task", "session", "run", "trial", "effort_condition", "difficulty_3",
  "stim_sign", "effort_x_stim", "choice_binary", "rt", "rt_cue",
  "tepr_mean_465_765", "tepr_raw", "baseline_raw", "tepr_c", "base_c",
  "B1_quality", "cog_quality", "b0_quality", "grip_prop", "auc_b0", "n_samples", "time_rule"
)
full_cols <- c(qc_cols, "lag_tepr_raw", "lag_tepr_c",
               "prechoice_raw", "prechoice_c", "prechoice_prop",
               "grip_raw", "grip_c", "keep_p3_rt", "time_rule_axis")
fwrite(qc[, ..qc_cols], file.path(OUT, "ddm_pupil_r12_qc.csv"))
fwrite(qc[, ..full_cols], file.path(OUT, "ddm_pupil_r12.csv"))
fwrite(qc[is.finite(base_c)], file.path(OUT, "ddm_pupil_r12_base.csv"))
fwrite(qc[is.finite(lag_tepr_c)], file.path(OUT, "ddm_pupil_r12_lag.csv"))
fwrite(qc[is.finite(prechoice_c)], file.path(OUT, "ddm_pupil_r12_prechoice.csv"))
fwrite(qc[is.finite(grip_c)], file.path(OUT, "ddm_pupil_r12_grip.csv"))
fwrite(qc[keep_p3_rt == TRUE], file.path(OUT, "ddm_pupil_r12_rt.csv"))

cat("QC", nrow(qc), "subjects", uniqueN(qc$subject_id),
    "base", sum(is.finite(qc$base_c)), "lag", sum(is.finite(qc$lag_tepr_c)),
    "pre", sum(is.finite(qc$prechoice_c)), "grip", sum(is.finite(qc$grip_c)),
    "rt", sum(qc$keep_p3_rt), "\n")
cat("Dip median", dip_sum$median, "IQR", dip_sum$iqr, "r10", dip_sum$r10_median, "\n")
cat("TEPR recompute max abs", max_abs, "n", n_checked, "\n")
print(gates)
print(epoch)
