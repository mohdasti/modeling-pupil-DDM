#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(ggplot2)
  library(patchwork)
  library(readr)
  library(yaml)
})

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x

repo_root <- normalizePath(".", mustWork = TRUE)
source(file.path(repo_root, "R", "tepr_waveform_helpers.R"))

config <- yaml::read_yaml(file.path(repo_root, "config", "data_paths.yaml"))
processed_dir <- config$processed_dir

build_dirs <- list.dirs(processed_dir, recursive = FALSE, full.names = TRUE)
build_dirs <- build_dirs[grepl("build_[0-9]{8}_[0-9]{6}$", basename(build_dirs))]
flat_root <- if (length(build_dirs) > 0) {
  build_dirs[which.max(file.info(build_dirs)$mtime)]
} else {
  processed_dir
}

analysis_dir <- file.path(repo_root, "data", "pupil_processed", "analysis")
fig_dir <- file.path(repo_root, "output", "figures", "tepr_subject_waveforms")
dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

trial_path <- file.path(repo_root, "data", "pupil_processed", "analysis_ready", "ch3_triallevel.csv")
stopifnot(file.exists(trial_path), dir.exists(flat_root))

source(file.path(repo_root, "R", "colors_manuscript.R"))
condition_colors <- stats::setNames(unname(cond_colors), gsub("/", " / ", names(cond_colors)))

B0_WIN <- c(-0.5, 0.0)
TARGET_ONSET <- 4.35
RESP_START <- 4.70
RESP_END <- 7.70
COG_START <- 4.65
COG_END <- 7.65
FS_HZ <- 50
TIME_GRID <- seq(B0_WIN[1], RESP_END, by = 1 / FS_HZ)
GAM_K <- 10L
GAM_N_TIMEPOINTS <- 200L

find_squeeze_onset <- function(dt) {
  if ("trial_start_time_ptb" %in% names(dt) && any(is.finite(dt$trial_start_time_ptb))) {
    return(dt$trial_start_time_ptb[which(is.finite(dt$trial_start_time_ptb))[1]])
  }
  if ("trial_label" %in% names(dt)) {
    idx <- which(dt$trial_label %in% c("Squeeze", "Grip", "Squeeze_Start"))
    if (length(idx) > 0) return(dt$time[idx[1]])
  }
  NA_real_
}

classify_difficulty <- function(stimulus_intensity, isOddball) {
  dplyr::case_when(
    isOddball == 0 | (is.na(isOddball) & !is.na(stimulus_intensity) & stimulus_intensity == 0) ~ "Standard",
    !is.na(stimulus_intensity) & stimulus_intensity %in% c(1, 2) ~ "Hard",
    !is.na(stimulus_intensity) & stimulus_intensity %in% c(3, 4) ~ "Easy",
    isOddball == 1 & is.na(stimulus_intensity) ~ "Easy",
    TRUE ~ NA_character_
  )
}

trial_meta <- readr::read_csv(trial_path, show_col_types = FALSE) %>%
  filter(
    auc_available == TRUE,
    task %in% c("ADT", "VDT"),
    !is.na(effort),
    !is.na(stimulus_intensity),
    stimulus_intensity %in% 1:4
  ) %>%
  mutate(
    sub = as.character(sub),
    task = as.character(task),
    session_used = as.integer(session_used),
    run_used = as.integer(run_used),
    trial_index = as.integer(trial_index),
    effort = case_when(
      effort %in% c("Low", "Low_Force_5pct") ~ "Low",
      effort %in% c("High", "High_Force_40pct") ~ "High",
      TRUE ~ as.character(effort)
    ),
    difficulty = classify_difficulty(stimulus_intensity, isOddball),
    condition = paste(difficulty, effort, sep = " / ")
  ) %>%
  filter(difficulty %in% c("Easy", "Hard"), effort %in% c("Low", "High")) %>%
  select(trial_uid, sub, task, session_used, run_used, trial_index, effort,
         stimulus_intensity, isOddball, difficulty, condition)

flat_files <- list.files(flat_root, pattern = ".*_(ADT|VDT)_flat\\.csv$", full.names = TRUE)
if (length(flat_files) == 0) stop("No ADT/VDT flat files found in ", flat_root)

subject_out <- file.path(analysis_dir, "pupil_waveforms_subject_condition_mean.csv")
condition_out <- file.path(analysis_dir, "pupil_waveforms_condition_mean_subject_derived.csv")
reuse_waveforms <- identical(Sys.getenv("REUSE_TEPR_WAVEFORMS"), "1") && file.exists(subject_out)

cat("Flat root: ", flat_root, "\n", sep = "")
cat("Flat files: ", length(flat_files), "\n", sep = "")
cat("Eligible trials: ", nrow(trial_meta), "\n", sep = "")

process_flat <- function(flat_path) {
  dt <- data.table::fread(flat_path, showProgress = FALSE)
  needed <- c("sub", "task", "session_used", "run_used", "trial_index", "trial_in_run_raw",
              "trial_in_run", "time", "pupil", "trial_label", "trial_start_time_ptb",
              "seg_start_rel_used", "seg_end_rel_used")
  missing <- setdiff(needed, names(dt))
  for (nm in missing) dt[, (nm) := NA]

  dt[, `:=`(
    sub = as.character(sub),
    task = as.character(task),
    session_used = as.integer(session_used),
    run_used = as.integer(run_used),
    trial_index = as.integer(trial_index),
    trial_in_run_raw = as.integer(trial_in_run_raw),
    trial_in_run = as.integer(trial_in_run),
    time = as.numeric(time),
    pupil = as.numeric(pupil)
  )]
  dt[is.nan(pupil), pupil := NA_real_]
  dt <- dt[session_used %in% c(2L, 3L)]
  if (nrow(dt) == 0) return(tibble())

  dt[, trial_index_per_run := fifelse(!is.na(trial_in_run_raw), trial_in_run_raw,
                                      fifelse(!is.na(trial_in_run), trial_in_run,
                                              ((trial_index - 1L) %% 30L) + 1L))]

  keys <- unique(dt[, .(sub, task, session_used, run_used)])
  matches <- trial_meta %>%
    inner_join(as_tibble(keys), by = c("sub", "task", "session_used", "run_used"))
  if (nrow(matches) == 0) return(tibble())

  setDT(matches)
  joined <- merge(
    dt,
    matches,
    by.x = c("sub", "task", "session_used", "run_used", "trial_index_per_run"),
    by.y = c("sub", "task", "session_used", "run_used", "trial_index"),
    allow.cartesian = TRUE
  )
  if (nrow(joined) == 0) return(tibble())

  trial_rows <- joined[, {
    if (any(is.finite(seg_start_rel_used)) && any(is.finite(seg_end_rel_used))) {
      seg_start <- seg_start_rel_used[which(is.finite(seg_start_rel_used))[1]]
      seg_end <- seg_end_rel_used[which(is.finite(seg_end_rel_used))[1]]
      t_rel <- if (is.finite(seg_start) && is.finite(seg_end) && seg_end > seg_start) {
        seq(seg_start, seg_end, length.out = .N)
      } else {
        squeeze_onset <- find_squeeze_onset(.SD)
        time - squeeze_onset
      }
    } else {
      squeeze_onset <- find_squeeze_onset(.SD)
      t_rel <- time - squeeze_onset
    }

    b0_mask <- t_rel >= B0_WIN[1] & t_rel < B0_WIN[2]
    b0_mean <- mean(pupil[b0_mask], na.rm = TRUE)
    if (!is.finite(b0_mean)) {
      NULL
    } else {
      y <- pupil - b0_mean
      valid <- is.finite(t_rel) & is.finite(y) & t_rel >= B0_WIN[1] & t_rel <= RESP_END
      if (sum(valid) < 2) {
        NULL
      } else {
        interp <- interpolate_trial_to_grid(t_rel[valid], y[valid], TIME_GRID)
        if (nrow(interp) == 0) NULL else interp
      }
    }
  }, by = .(trial_uid, subject_id = sub, task, effort, difficulty, condition)]

  if (nrow(trial_rows) == 0) return(tibble())

  trial_rows[, `:=`(chapter = "ch3", sample_rate_hz = FS_HZ)]
  trial_rows[, .(
    mean_pupil_full = mean(mean_pupil_full, na.rm = TRUE),
    n_trials = uniqueN(trial_uid)
  ), by = .(chapter, sample_rate_hz, subject_id, task, effort, difficulty, condition, t_rel)] %>%
    as_tibble()
}

if (reuse_waveforms) {
  cat("Reusing cached subject-level waveform file: ", subject_out, "\n", sep = "")
  subject_waveforms <- readr::read_csv(subject_out, show_col_types = FALSE)
} else {
  subject_chunks <- vector("list", length(flat_files))
  for (i in seq_along(flat_files)) {
    cat(sprintf("[%03d/%03d] %s\n", i, length(flat_files), basename(flat_files[i])))
    subject_chunks[[i]] <- process_flat(flat_files[i])
  }

  subject_waveforms <- bind_rows(subject_chunks) %>%
    group_by(chapter, sample_rate_hz, subject_id, task, effort, difficulty, condition, t_rel) %>%
    summarise(
      mean_pupil_full = weighted.mean(mean_pupil_full, w = pmax(n_trials, 1), na.rm = TRUE),
      n_trials = sum(n_trials, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(task, condition, subject_id, t_rel)

  subject_waveforms <- winsorize_subject_waveforms(subject_waveforms)
}

plot_prep <- prepare_tepr_plot_data(subject_waveforms, winsorize = reuse_waveforms)
plot_data_full <- plot_prep$condition %>%
  filter(
    task %in% c("ADT", "VDT"),
    condition %in% c("Easy / Low", "Easy / High", "Hard / Low", "Hard / High")
  ) %>%
  mutate(condition = factor(condition, levels = c("Easy / Low", "Easy / High", "Hard / Low", "Hard / High")))

plot_data <- prepare_tepr_gam_plot_data(
  plot_prep,
  x_range = c(B0_WIN[1], RESP_END),
  n_timepoints = GAM_N_TIMEPOINTS
) %>%
  filter(
    task %in% c("ADT", "VDT"),
    condition %in% c("Easy / Low", "Easy / High", "Hard / Low", "Hard / High")
  ) %>%
  mutate(condition = factor(condition, levels = c("Easy / Low", "Easy / High", "Hard / Low", "Hard / High")))

condition_waveforms <- plot_data_full %>%
  transmute(
    chapter = "ch3",
    sample_rate_hz = FS_HZ,
    task, effort = sub(".* / ", "", condition),
    difficulty = sub(" / .*", "", condition),
    condition, t_rel,
    mean_pupil_full = mean_pupil_isolated,
    se_pupil_isolated,
    n_subjects
  )

if (!reuse_waveforms) readr::write_csv(subject_waveforms, subject_out)
readr::write_csv(condition_waveforms, condition_out)

cat("Wrote: ", subject_out, "\n", sep = "")
cat("Wrote: ", condition_out, "\n", sep = "")

event_markers <- tibble::tibble(
  event = c("Squeeze", "Probe", "Response cue"),
  time = c(0, TARGET_ONSET, RESP_START)
)

x_display <- c(-0.5, RESP_END)
gam_curves <- fit_tepr_gam_curves(
  plot_data,
  gam_k = GAM_K,
  x_range = x_display
)
y_limits <- tepr_gam_curves_ylimits(gam_curves, x_range = x_display)
y_lower_limit <- y_limits[1]
y_upper_limit <- y_limits[2]

p <- ggplot(gam_curves, aes(x = t_rel, y = fit, color = condition, fill = condition)) +
  annotate("rect", xmin = COG_START, xmax = COG_END, ymin = -Inf, ymax = Inf,
           fill = "grey90", alpha = 0.35) +
  geom_ribbon(aes(ymin = fit_lo, ymax = fit_hi), alpha = 0.22, color = NA) +
  geom_line(linewidth = 1.1, alpha = 0.95) +
  geom_vline(data = event_markers, aes(xintercept = time), inherit.aes = FALSE,
             linetype = "dashed", color = "grey40", linewidth = 0.5) +
  geom_text(data = event_markers, aes(x = time, y = y_upper_limit, label = event),
            inherit.aes = FALSE, angle = 90, hjust = 1.08, vjust = -0.25,
            size = 3.2, color = "grey25") +
  facet_wrap(~task, ncol = 1) +
  scale_color_manual(values = condition_colors, drop = FALSE) +
  scale_fill_manual(values = condition_colors, drop = FALSE) +
  scale_x_continuous(breaks = seq(-0.5, RESP_END, by = 1), expand = expansion(mult = c(0.01, 0.02))) +
  coord_cartesian(xlim = c(-0.5, RESP_END), ylim = c(y_lower_limit, y_upper_limit)) +
  labs(
    x = "Time relative to squeeze onset (s)",
    y = "Baseline-corrected pupil diameter (AU)",
    color = "Condition",
    fill = "Condition",
    title = "TEPR Time Course from Subject-Level Means",
    subtitle = sprintf(
      "Subject means winsorized; GAM on %d time samples, anchored at squeeze onset (t = 0; 95%% CI)",
      GAM_N_TIMEPOINTS
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "grey90", linewidth = 0.4),
    strip.text = element_text(face = "bold", size = 12),
    legend.position = "bottom",
    legend.title = element_text(face = "bold"),
    axis.title = element_text(face = "bold"),
    plot.title = element_text(face = "bold"),
    plot.margin = margin(10, 16, 10, 10)
  )

png_out <- file.path(fig_dir, "fig_tepr_timecourse_subject_means.png")
pdf_out <- file.path(fig_dir, "fig_tepr_timecourse_subject_means.pdf")
ggsave(png_out, p, width = 10, height = 8, dpi = 300)
ggsave(pdf_out, p, width = 10, height = 8, device = cairo_pdf)

qc <- subject_waveforms %>%
  group_by(task, condition) %>%
  summarise(
    n_subjects = n_distinct(subject_id),
    n_trials = sum(tapply(n_trials, subject_id, function(x) max(x, na.rm = TRUE)), na.rm = TRUE),
    min_time = min(t_rel, na.rm = TRUE),
    max_time = max(t_rel, na.rm = TRUE),
    pct_extreme_preprobe = mean(abs(mean_pupil_full[t_rel <= 4.2]) > 2, na.rm = TRUE),
    .groups = "drop"
  )
readr::write_csv(qc, file.path(analysis_dir, "pupil_waveforms_subject_condition_qc.csv"))
print(qc)
cat("Wrote: ", png_out, "\n", sep = "")
cat("Wrote: ", pdf_out, "\n", sep = "")
