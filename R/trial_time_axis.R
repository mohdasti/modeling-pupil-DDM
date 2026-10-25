# Trial-relative pupil time at the recorded 250 Hz rate.
# t_k = -3 + 0.004 * (k - 1). Samples are never spread evenly, and file
# timestamps are not a clock. A trial is accepted only when its sample count
# is a full epoch (3425 or 3426 samples; the 3425-sample epoch ends at 10.696 s)
# or a documented December 25 short epoch (about 2680 samples, 250 Hz end near
# 7.72 s; observed counts 2673-2730). Any other count stops, with the trial id.

build_trial_time <- function(n, dt = 0.004,
                              seg_start = NA_real_, seg_end = NA_real_,
                              subject = NA, task = NA, session = NA, run = NA, trial = NA,
                              expected_end = 10.7) {
  n <- suppressWarnings(as.integer(n)[1])
  if (!is.finite(n) || n < 2L) {
    stop("Time axis needs at least 2 samples.")
  }
  t <- -3 + 0.004 * (seq_len(n) - 1)
  implied_end <- t[n]
  if (n %in% c(3425L, 3426L)) {
    return(list(t = t, rule = "fixed_250hz", implied_end = implied_end))
  }
  # December 25 build, Resp1ET epochs. 2673 samples end at 7.688 s and
  # 2730 samples end at 7.916 s. Counts near 3080 are not this epoch.
  if (n >= 2673L && n <= 2730L) {
    return(list(t = t, rule = "short_epoch_250hz", implied_end = implied_end))
  }
  stop(sprintf(
    paste0(
      "Time axis refused for subject %s task %s session %s run %s trial %s: ",
      "%d samples, 250 Hz end %.4f s. Accepted counts are 3425 or 3426 ",
      "(full epoch, end 10.696 or 10.700 s) or 2673-2730 ",
      "(December 25 short epoch, end near 7.72 s)."
    ),
    subject, task, session, run, trial, n, implied_end
  ))
}
