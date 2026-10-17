# Tests for the guarded trial time axis.
# Run from the repo root: Rscript tests/test_time_axis_guard.R

options(warn = 1)
suppressPackageStartupMessages(library(data.table))
source("R/trial_time_axis.R")

PARENT <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
BUILD <- file.path(PARENT, "build_20251225_154443")
fail <- function(msg) stop("TEST FAIL: ", msg, call. = FALSE)
pass <- function(msg) message("PASS: ", msg)

compute_auc <- function(time, value) {
  ok <- is.finite(time) & is.finite(value)
  if (sum(ok) < 2) return(NA_real_)
  time <- time[ok]
  value <- value[ok]
  ord <- order(time)
  time <- time[ord]
  value <- value[ord]
  gap <- diff(time)
  keep <- which(gap > 0 & gap <= 0.25)
  if (!length(keep)) return(NA_real_)
  sum(gap[keep] * (value[keep] + value[keep + 1]) / 2)
}

file_dt <- function(time_vec) {
  d <- diff(sort(unique(time_vec[is.finite(time_vec)])))
  d <- d[is.finite(d) & d > 0]
  if (!length(d)) return(0.004)
  dt <- median(d)
  if (dt >= 1 && dt <= 10) dt <- dt / 1000
  dt
}

one_trial <- function(path, with_seg) {
  cols <- c("session_used", "run_used", "trial_in_run_raw", "time", "pupil")
  if (with_seg) cols <- c(cols, "seg_start_rel_used", "seg_end_rel_used")
  dt <- fread(path, select = cols)
  setnames(dt, c("session_used", "run_used", "trial_in_run_raw"), c("session", "run", "trial"))
  dt <- dt[session %in% c(2L, 3L)]
  key <- dt[, .N, by = .(session, run, trial)][N > 100][1]
  tr <- dt[session == key$session & run == key$run & trial == key$trial]
  list(tr = tr, key = key, dt_file = file_dt(dt$time))
}

# 1. December 21 trial whose step end is the expected epoch: AUC unchanged to 1e-12.
candidates <- c("BAP125", "BAP118", "BAP202", "BAP003")
found <- NULL
for (sub in candidates) {
  path <- file.path(PARENT, paste0(sub, "_ADT_flat.csv"))
  if (!file.exists(path)) next
  dt <- fread(path, select = c("session_used", "run_used", "trial_in_run_raw", "time", "pupil"))
  setnames(dt, c("session_used", "run_used", "trial_in_run_raw"), c("session", "run", "trial"))
  dt <- dt[session %in% c(2L, 3L)]
  dt_file <- file_dt(dt$time)
  keys <- dt[, .N, by = .(session, run, trial)][N > 100]
  for (i in seq_len(nrow(keys))) {
    tr <- dt[session == keys$session[i] & run == keys$run[i] & trial == keys$trial[i]]
    n <- nrow(tr)
    old_t <- seq(from = -3.0, by = dt_file, length.out = n)
    if (!is.finite(old_t[n]) || old_t[n] < 8 || old_t[n] > 15) next
    b1_vals <- tr$pupil[old_t >= 3.85 & old_t < 4.35]
    if (sum(is.finite(b1_vals)) < 10) next
    b1 <- mean(b1_vals, na.rm = TRUE)
    w <- old_t >= 4.65 & old_t <= 7.65
    auc_old <- compute_auc(old_t[w], tr$pupil[w] - b1)
    if (!is.finite(auc_old)) next
    found <- list(sub = sub, tr = tr, old_t = old_t, n = n, dt_file = dt_file,
                  session = keys$session[i], run = keys$run[i], trial = keys$trial[i],
                  auc_old = auc_old, b1 = b1)
    break
  }
  if (!is.null(found)) break
}
if (is.null(found)) fail("No Dec 21 ADT trial had a step end in [8, 15] s and a finite AUC")
new <- build_trial_time(found$n, found$dt_file, subject = found$sub, task = "ADT",
                         session = found$session, run = found$run, trial = found$trial)
if (!identical(new$rule, "step_from_m3")) fail(paste("Dec 21 rule is", new$rule))
if (max(abs(new$t - found$old_t)) > 0) fail("Dec 21 axis differs from the step rule")
w <- new$t >= 4.65 & new$t <= 7.65
auc_new <- compute_auc(new$t[w], found$tr$pupil[w] - found$b1)
if (!is.finite(auc_new) || abs(auc_new - found$auc_old) > 1e-12) {
  fail(sprintf("AUC mismatch: new %.12g old %.12g", auc_new, found$auc_old))
}
pass(sprintf("Dec 21 %s ADT s%s r%s t%s end %.4f AUC %.6f matches the step rule",
             found$sub, found$session, found$run, found$trial, new$implied_end, auc_new))

# 2. December 25 trial with segment columns stripped: stop.
p25 <- file.path(BUILD, "BAP003_ADT_flat.csv")
if (!file.exists(p25)) fail(paste("Missing", p25))
b <- one_trial(p25, TRUE)
stopped <- tryCatch(
  build_trial_time(nrow(b$tr), b$dt_file, subject = "BAP003", task = "ADT",
                    session = b$key$session, run = b$key$run, trial = b$key$trial),
  error = function(e) e
)
if (!inherits(stopped, "error")) fail("Dec 25 without seg columns did not stop")
msg <- conditionMessage(stopped)
if (!grepl("BAP003", msg) || !grepl("samples", msg) || !grepl("span", msg)) {
  fail(paste("Stop message is not informative:", msg))
}
pass(paste("Dec 25 without seg columns stopped:", msg))

# 3. December 25 with seg columns: axis from -3 to the segment end; dip at 3.0-3.4 s.
subjects <- c("BAP003", "BAP125", "BAP172", "BAP118", "BAP202")
grid <- seq(2.5, 4.0, by = 0.02)
sums <- numeric(length(grid))
counts <- integer(length(grid))
n_trials <- 0L
for (sub in subjects) {
  path <- file.path(BUILD, paste0(sub, "_ADT_flat.csv"))
  if (!file.exists(path)) fail(paste("Missing", path))
  dt <- fread(path, select = c("session_used", "run_used", "trial_in_run_raw", "time", "pupil",
                                "seg_start_rel_used", "seg_end_rel_used"))
  setnames(dt, c("session_used", "run_used", "trial_in_run_raw"), c("session", "run", "trial"))
  dt <- dt[session %in% c(2L, 3L)]
  dt_used <- file_dt(dt$time)
  parts <- split(seq_len(nrow(dt)), paste(dt$session, dt$run, dt$trial))
  for (ix in parts) {
    if (length(ix) < 100) next
    ax <- build_trial_time(
      length(ix), dt_used,
      seg_start = dt$seg_start_rel_used[ix[1]],
      seg_end = dt$seg_end_rel_used[ix[1]],
      subject = sub, task = "ADT",
      session = dt$session[ix[1]], run = dt$run[ix[1]], trial = dt$trial[ix[1]]
    )
    if (!identical(ax$rule, "segment_window")) fail(paste(sub, "did not use the segment window"))
    if (abs(ax$t[1] - dt$seg_start_rel_used[ix[1]]) > 1e-8) fail("Axis does not start at seg_start")
    t <- ax$t
    pup <- dt$pupil[ix]
    in_b0 <- is.finite(t) & is.finite(pup) & t >= -0.5 & t < 0
    if (sum(in_b0) < 10) next
    y <- pup - mean(pup[in_b0])
    ok <- is.finite(t) & is.finite(y)
    yy <- stats::approx(t[ok], y[ok], xout = grid, rule = 1, ties = "ordered")$y
    finite <- is.finite(yy)
    sums[finite] <- sums[finite] + yy[finite]
    counts[finite] <- counts[finite] + 1L
    n_trials <- n_trials + 1L
  }
}
if (n_trials < 50) fail(paste("Too few Dec 25 trials in the average:", n_trials))
mean_y <- sums / pmax(counts, 1)
dip_at <- grid[which.min(mean_y)]
if (dip_at < 3.0 || dip_at > 3.4) fail(sprintf("Dip at %.2f s is outside 3.0-3.4 (n = %d)", dip_at, n_trials))
pass(sprintf("Dec 25 segment axis, 5-subject ADT dip at %.2f s (%d trials)", dip_at, n_trials))

message("All time-axis guard tests passed.")
