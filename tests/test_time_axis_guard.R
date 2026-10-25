# Tests for the 250 Hz trial time axis.
# Run from the repo root: Rscript tests/test_time_axis_guard.R

options(warn = 1)
suppressPackageStartupMessages(library(data.table))
source("R/trial_time_axis.R")

PARENT <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
BUILD <- file.path(PARENT, "build_20251225_154443")
fail <- function(msg) stop("TEST FAIL: ", msg, call. = FALSE)
pass <- function(msg) message("PASS: ", msg)

file_dt <- function(time_vec) {
  d <- diff(sort(unique(time_vec[is.finite(time_vec)])))
  d <- d[is.finite(d) & d > 0]
  if (!length(d)) return(0.004)
  dt <- median(d)
  if (dt >= 1 && dt <= 10) dt <- dt / 1000
  dt
}

# 1. December 21 full epoch is the 250 Hz grid, not the timestamp step.
candidates <- c("BAP125", "BAP118", "BAP202", "BAP003")
found <- NULL
for (sub in candidates) {
  path <- file.path(PARENT, paste0(sub, "_ADT_flat.csv"))
  if (!file.exists(path)) next
  dt <- fread(path, select = c("session_used", "run_used", "trial_in_run_raw", "time", "pupil"))
  setnames(dt, c("session_used", "run_used", "trial_in_run_raw"), c("session", "run", "trial"))
  dt <- dt[session %in% c(2L, 3L)]
  keys <- dt[, .N, by = .(session, run, trial)][N %in% c(3425L, 3426L)]
  if (!nrow(keys)) next
  tr <- dt[session == keys$session[1] & run == keys$run[1] & trial == keys$trial[1]]
  found <- list(sub = sub, n = nrow(tr), session = keys$session[1], run = keys$run[1],
                trial = keys$trial[1], dt_file = file_dt(dt$time))
  break
}
if (is.null(found)) fail("No December 21 ADT trial had 3425 or 3426 samples")
new <- build_trial_time(found$n, found$dt_file, subject = found$sub, task = "ADT",
                         session = found$session, run = found$run, trial = found$trial)
if (!identical(new$rule, "fixed_250hz")) fail(paste("December 21 rule is", new$rule))
expected <- -3 + 0.004 * (seq_len(found$n) - 1)
if (max(abs(new$t - expected)) > 1e-12) fail("December 21 axis is not t_k = -3 + 0.004(k-1)")
if (found$n == 3425L && abs(new$implied_end - 10.696) > 1e-9) fail("3425-sample epoch does not end at 10.696 s")
if (found$n == 3426L && abs(new$implied_end - 10.700) > 1e-9) fail("3426-sample epoch does not end at 10.700 s")
old_step <- seq(from = -3.0, by = found$dt_file, length.out = found$n)
if (max(abs(new$t - old_step)) < 1e-6) fail("250 Hz axis matches the timestamp step; the compression was not removed")
pass(sprintf("December 21 %s ADT s%s r%s t%s n=%d end %.3f s is the 250 Hz grid",
             found$sub, found$session, found$run, found$trial, found$n, new$implied_end))

# 2. A count that is neither the full epoch nor the short epoch stops, and names the trial.
stopped <- tryCatch(
  build_trial_time(3091L, 0.004, subject = "BAP003", task = "ADT",
                    session = 2L, run = 1L, trial = 9L),
  error = function(e) e
)
if (!inherits(stopped, "error")) fail("Count 3091 did not stop")
msg <- conditionMessage(stopped)
if (!grepl("BAP003", msg) || !grepl("3091", msg) || !grepl("trial 9", msg)) {
  fail(paste("Stop message does not name the trial:", msg))
}
pass(paste("Unexpected count stopped:", msg))

# 3. December 25 short epochs are accepted on the 250 Hz axis with no segment window.
#    The gauge-offset light reflex on that axis falls in 3.0-3.6 s.
p25 <- file.path(BUILD, "BAP003_ADT_flat.csv")
if (!file.exists(p25)) fail(paste("Missing", p25))
one <- fread(p25, select = c("session_used", "run_used", "trial_in_run_raw"))
setnames(one, c("session", "run", "trial"))
one <- one[session %in% c(2L, 3L), .N, by = .(session, run, trial)][1]
short <- build_trial_time(one$N, subject = "BAP003", task = "ADT",
                           session = one$session, run = one$run, trial = one$trial)
if (!identical(short$rule, "short_epoch_250hz")) fail(paste("December 25 rule is", short$rule))
if (short$implied_end < 7.65 || short$implied_end > 7.95) {
  fail(sprintf("Short-epoch end %.3f s is not near 7.72 s", short$implied_end))
}
pass(sprintf("December 25 short epoch n=%d end %.3f s accepted without segment columns",
             one$N, short$implied_end))

subjects <- c("BAP003", "BAP125", "BAP172", "BAP118", "BAP202")
grid <- seq(2.5, 4.5, by = 0.02)
sums <- numeric(length(grid))
counts <- integer(length(grid))
n_trials <- 0L
for (sub in subjects) {
  path <- file.path(BUILD, paste0(sub, "_ADT_flat.csv"))
  if (!file.exists(path)) fail(paste("Missing", path))
  dt <- fread(path, select = c("session_used", "run_used", "trial_in_run_raw", "pupil"))
  setnames(dt, c("session_used", "run_used", "trial_in_run_raw"), c("session", "run", "trial"))
  dt <- dt[session %in% c(2L, 3L)]
  parts <- split(seq_len(nrow(dt)), paste(dt$session, dt$run, dt$trial))
  for (ix in parts) {
    n <- length(ix)
    if (n < 2673L || n > 2730L) next
    ax <- build_trial_time(n, subject = sub, task = "ADT",
                            session = dt$session[ix[1]], run = dt$run[ix[1]], trial = dt$trial[ix[1]])
    if (!identical(ax$rule, "short_epoch_250hz")) fail(paste(sub, "did not use the short-epoch rule"))
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
if (n_trials < 50) fail(paste("Too few December 25 trials in the average:", n_trials))
mean_y <- sums / pmax(counts, 1)
dip_at <- grid[which.min(mean_y)]
if (dip_at < 3.0 || dip_at > 3.6) fail(sprintf("Dip at %.2f s is outside 3.0-3.6 (n = %d)", dip_at, n_trials))
pass(sprintf("December 25 250 Hz axis, 5-subject ADT dip at %.2f s (%d trials)", dip_at, n_trials))

message("All time-axis guard tests passed.")
