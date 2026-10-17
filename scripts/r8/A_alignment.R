# historical; not used for final outputs
# Part A: which flat-file generation is on the trial clock?
# Reads flat files only. Writes only under output/diagnostics/pupil_rebuild/.

suppressPackageStartupMessages(library(data.table))

PARENT <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
BUILD <- file.path(PARENT, "build_20251225_154443")
OUT <- "output/diagnostics/pupil_rebuild"
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

SUBJECTS <- c("BAP003", "BAP125", "BAP172", "BAP118", "BAP202")
TASKS <- c("ADT", "VDT")
GRID <- seq(-1, 8, by = 0.02)

file_dt <- function(time_vec) {
  d <- diff(sort(unique(time_vec)))
  d <- d[is.finite(d) & d > 0]
  dt <- if (length(d) == 0) 0.004 else median(d)
  unit <- if (dt < 0.05) "sec" else if (dt >= 1 && dt <= 10) "ms" else "sec"
  if (unit == "ms") dt <- dt / 1000
  list(dt = dt, unit = unit)
}

source("R/trial_time_axis.R")
builder_times <- function(n, dt, seg_start = NA_real_, seg_end = NA_real_,
                          subject = NA, task = NA, session = NA, run = NA, trial = NA) {
  build_trial_time(n, dt, seg_start, seg_end, subject, task, session, run, trial)
}

new_wave <- function() list(sums = numeric(length(GRID)), counts = integer(length(GRID)), n_trials = 0L)

add_trial <- function(t, pupil, wave) {
  ok <- is.finite(t) & is.finite(pupil)
  in_b0 <- ok & t >= -0.5 & t < 0
  if (sum(in_b0) < 10L) return(wave)
  y <- pupil[ok] - mean(pupil[in_b0])
  tt <- t[ok]
  idx <- findInterval(tt, GRID - 0.01)
  keep <- idx >= 1L & idx <= length(GRID)
  if (!any(keep)) return(wave)
  add <- rowsum(y[keep], idx[keep], reorder = FALSE)
  pos <- as.integer(rownames(add))
  wave$sums[pos] <- wave$sums[pos] + add[, 1]
  wave$counts[pos] <- wave$counts[pos] + tabulate(idx[keep], nbins = length(GRID))[pos]
  wave$n_trials <- wave$n_trials + 1L
  wave
}

latency <- function(mean_y, lo, hi, pick = which.min) {
  m <- GRID >= lo & GRID <= hi & is.finite(mean_y)
  if (!any(m)) return(NA_real_)
  GRID[m][pick(mean_y[m])]
}

pairs <- rbindlist(lapply(SUBJECTS, function(sub) {
  rbindlist(lapply(TASKS, function(task) {
    p21 <- file.path(PARENT, sprintf("%s_%s_flat.csv", sub, task))
    p25 <- file.path(BUILD, sprintf("%s_%s_flat.csv", sub, task))
    if (file.exists(p21) && file.exists(p25)) {
      data.table(sub = sub, task = task, p21 = p21, p25 = p25)
    }
  }))
}))
cat("File pairs:", nrow(pairs), "\n")

clock_rows <- list()
label_rows <- list()
seg_rows <- list()
waves <- list(
  dec21 = list(native = new_wave(), builder = new_wave(), fixed004 = new_wave()),
  dec25 = list(native = new_wave(), builder = new_wave(), fixed004 = new_wave())
)

for (i in seq_len(nrow(pairs))) {
  sub <- pairs$sub[i]
  task <- pairs$task[i]
  cat("Reading", sub, task, "\n")
  d21 <- fread(pairs$p21[i], select = c(
    "session_used", "run_used", "trial_in_run_raw", "time", "pupil", "trial_label"
  ))
  d25 <- fread(pairs$p25[i], select = c(
    "session_used", "run_used", "trial_in_run_raw", "time", "pupil", "trial_label",
    "seg_start_rel_used", "seg_end_rel_used", "seg_end_source"
  ))
  d21 <- d21[session_used %in% c(2L, 3L)]
  d25 <- d25[session_used %in% c(2L, 3L)]
  setnames(d21, c("session_used", "run_used", "trial_in_run_raw"), c("session", "run", "trial"))
  setnames(d25, c("session_used", "run_used", "trial_in_run_raw"), c("session", "run", "trial"))

  label_rows[[length(label_rows) + 1L]] <- data.table(
    subject = sub, task = task, generation = "dec21",
    labels = paste(sort(unique(d21$trial_label)), collapse = "|")
  )
  label_rows[[length(label_rows) + 1L]] <- data.table(
    subject = sub, task = task, generation = "dec25",
    labels = paste(sort(unique(d25$trial_label)), collapse = "|")
  )

  seg_rows[[length(seg_rows) + 1L]] <- unique(d25[, .(
    subject = sub, task = task, session, run, trial,
    seg_start = seg_start_rel_used, seg_end = seg_end_rel_used,
    seg_end_source
  )])

  keys <- merge(
    unique(d21[, .(session, run, trial)]),
    unique(d25[, .(session, run, trial)]),
    by = c("session", "run", "trial")
  )
  d21 <- d21[keys, on = c("session", "run", "trial")]
  d25 <- d25[keys, on = c("session", "run", "trial")]
  info21 <- file_dt(d21$time)
  info25 <- file_dt(d25$time)

  run_gen <- function(dt, generation, info) {
    dt[, key := paste(session, run, trial, sep = ":")]
    # Preserve within-trial file order. split() keeps order inside each group.
    idx <- split(seq_len(nrow(dt)), dt$key)
    for (ix in idx) {
      pup <- dt$pupil[ix]
      native <- dt$time[ix]
      n <- length(ix)
      built <- builder_times(
        n, info$dt,
        seg_start = if ("seg_start_rel_used" %in% names(dt)) dt$seg_start_rel_used[ix[1]] else NA_real_,
        seg_end = if ("seg_end_rel_used" %in% names(dt)) dt$seg_end_rel_used[ix[1]] else NA_real_,
        subject = sub, task = task,
        session = dt$session[ix[1]], run = dt$run[ix[1]], trial = dt$trial[ix[1]]
      )
      fixed <- seq(from = -3.0, by = 0.004, length.out = n)
      dtime <- diff(native)
      dpos <- dtime[is.finite(dtime) & dtime > 0]
      clock_rows[[length(clock_rows) + 1L]] <<- data.table(
        subject = sub, task = task, generation = generation,
        session = dt$session[ix[1]], run = dt$run[ix[1]], trial = dt$trial[ix[1]],
        n = n,
        t_first = native[1], t_last = native[n],
        dt_median = if (length(dpos)) median(dpos) else NA_real_,
        n_jump_gt_50ms = sum(dtime > 0.05, na.rm = TRUE),
        n_in_m3_to_11 = sum(native >= -3 & native <= 11, na.rm = TRUE),
        n_in_dip_window = sum(native >= 2.5 & native <= 3.8, na.rm = TRUE),
        builder_rule = built$rule,
        builder_dt = info$dt,
        builder_end = built$t[n],
        fixed_end = fixed[n],
        seg_end = if ("seg_end_rel_used" %in% names(dt)) dt$seg_end_rel_used[ix[1]] else NA_real_
      )
      waves[[generation]]$native <<- add_trial(native, pup, waves[[generation]]$native)
      waves[[generation]]$builder <<- add_trial(built$t, pup, waves[[generation]]$builder)
      waves[[generation]]$fixed004 <<- add_trial(fixed, pup, waves[[generation]]$fixed004)
    }
    cat(" ", generation, "shared trials", length(idx),
        "file dt", signif(info$dt, 4), info$unit, "\n")
  }
  run_gen(d21, "dec21", info21)
  run_gen(d25, "dec25", info25)
  rm(d21, d25)
  gc(verbose = FALSE)
}

clock <- rbindlist(clock_rows)
labels <- rbindlist(label_rows)
seg <- rbindlist(seg_rows)
fwrite(clock, file.path(OUT, "partA_trial_clock.csv"))
fwrite(labels, file.path(OUT, "partA_labels.csv"))
fwrite(seg[, .(
  n_trials = .N,
  seg_start = unique(seg_start)[1],
  seg_end_min = min(seg_end),
  seg_end_med = median(seg_end),
  seg_end_max = max(seg_end)
), by = .(subject, task, seg_end_source)], file.path(OUT, "partA_seg_end.csv"))

wave_out <- list()
cat("\n===== LATENCIES (seconds) =====\n")
for (gen in names(waves)) {
  for (ax in names(waves[[gen]])) {
    w <- waves[[gen]][[ax]]
    mean_y <- ifelse(w$counts > 0, w$sums / w$counts, NA_real_)
    dip <- latency(mean_y, 2.5, 3.8, which.min)
    dip_wide <- latency(mean_y, 1.5, 5.5, which.min)
    peak <- latency(mean_y, 4.35, 7.65, which.max)
    cat(sprintf("%s %-9s trials=%d dip[2.5,3.8]=%s dip[1.5,5.5]=%s peak(4.35,7.65]=%s\n",
                gen, ax, w$n_trials,
                ifelse(is.na(dip), "NA", sprintf("%.2f", dip)),
                ifelse(is.na(dip_wide), "NA", sprintf("%.2f", dip_wide)),
                ifelse(is.na(peak), "NA", sprintf("%.2f", peak))))
    wave_out[[length(wave_out) + 1L]] <- data.table(
      generation = gen, axis = ax, t = GRID, mean_b0 = mean_y, n = w$counts, n_trials = w$n_trials
    )
  }
}
fwrite(rbindlist(wave_out), file.path(OUT, "partA_waveforms.csv"))

cat("\n===== CLOCK SUMMARY =====\n")
print(clock[, .(
  n_trials = .N,
  n_med = median(n),
  t_first_med = median(t_first),
  t_last_med = median(t_last),
  dt_med = median(dt_median),
  jumps_med = median(n_jump_gt_50ms),
  trials_with_dip_window_sample = sum(n_in_dip_window > 0),
  trials_with_any_in_m3_11 = sum(n_in_m3_to_11 > 0)
), by = .(generation, builder_rule)])
cat("labels:\n")
print(labels)
cat("seg end sources:\n")
print(seg[, .N, by = seg_end_source])
cat("seg end range", range(seg$seg_end), "\n")
