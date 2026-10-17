# Model-free r8 exports. Does not read or write a fitted model.
# Writes tables/final_r8 and figures/final_r8 only.

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(readr)
  library(tibble)
  library(data.table)
})

ROOT <- normalizePath(getwd(), mustWork = TRUE)
setwd(ROOT)
source(file.path(ROOT, "R", "colors_manuscript.R"))
source(file.path(ROOT, "R", "fig_save_utils.R"))
source(file.path(ROOT, "R", "trial_time_axis.R"))

FINAL <- "output/ddm_refits/runs/final_20261016"
TAB <- file.path(FINAL, "tables", "final_r8")
FIG <- file.path(FINAL, "figures", "final_r8")
dir.create(TAB, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG, recursive = TRUE, showWarnings = FALSE)

save_r8 <- function(plot, stem, width, height, source_note) {
  save_manuscript_fig(plot, stem, width, height, dpi = 300, out_dir = FIG, also_legacy = FALSE)
  if (capabilities("cairo")) {
    ggsave(file.path(FIG, paste0(stem, ".pdf")), plot, width = width, height = height, device = grDevices::cairo_pdf)
  }
  writeLines(source_note, file.path(FIG, paste0(stem, "_source.txt")))
}
theme_ms <- function() {
  theme_classic(base_size = 11) +
    theme(panel.grid = element_blank(), strip.background = element_blank(),
          strip.text = element_text(face = "bold"), legend.position = "bottom")
}

gates <- read_csv("data/analysis_ready/r8/qc_gate_counts.csv", show_col_types = FALSE) %>%
  mutate(block = "qc_gate", source_model = "r8 December 21 rebuild", tier = "main")
cor_tepr <- read_csv("data/analysis_ready/r8/d1_tepr_rt_correlation.csv", show_col_types = FALSE) %>%
  mutate(block = "tepr_rt_correlation", source_model = "r8 QC", tier = "main")
raw_means <- read_csv("data/analysis_ready/r8/raw_means_by_task_effort.csv", show_col_types = FALSE) %>%
  mutate(block = "raw_means", source_model = "r8 QC", tier = "ms_supp")
paired <- read_csv("data/analysis_ready/r8/paired_high_minus_low.csv", show_col_types = FALSE) %>%
  mutate(block = "paired_high_minus_low", source_model = "r8 QC", tier = "main")
grip_means <- read_csv("data/analysis_ready/r8/grip_means_by_task_effort.csv", show_col_types = FALSE) %>%
  mutate(block = "grip_means", source_model = "r8 grip", tier = "ms_supp")
grip_paired <- read_csv("data/analysis_ready/r8/grip_paired_high_minus_low.csv", show_col_types = FALSE) %>%
  mutate(block = "grip_paired", source_model = "r8 grip", tier = "main")
t9 <- bind_rows(gates, cor_tepr, raw_means, paired, grip_means, grip_paired)
write_csv(t9, file.path(TAB, "T9_pupil_descriptives.csv"))
message("Wrote T9 (", nrow(t9), " rows)")

# ---- Flow. Behavioral counts stay the checked r5 values. Pupil counts are r8.
flow_tbl <- read_csv(file.path(FINAL, "tables/final/T12b_participant_flow.csv"), show_col_types = FALSE)
flow_n <- function(node, col) {
  hit <- flow_tbl[flow_tbl$node == node, col, drop = TRUE]
  stopifnot(length(hit) == 1L)
  as.numeric(hit)
}
gate_n <- function(gate, col) {
  hit <- gates[gates$gate == gate, col, drop = TRUE]
  stopifnot(length(hit) == 1L)
  as.numeric(hit)
}
fmt_n <- function(x) format(x, big.mark = ",", scientific = FALSE)
box_df <- function(id, x, y, w, h, label, linetype = "solid", fill = "white") {
  tibble(id = id, x = x, y = y, xmin = x - w / 2, xmax = x + w / 2,
         ymin = y - h / 2, ymax = y + h / 2, label = label, linetype = linetype, fill = fill)
}
n_collected <- 18097
n_cue_excluded <- 240
n_cue_kept <- 17857
n_adt_subj <- flow_n("task_ADT", "n_subjects")
n_adt_tri <- flow_n("task_ADT", "n_trials")
n_vdt_subj <- flow_n("task_VDT", "n_subjects")
n_vdt_tri <- flow_n("task_VDT", "n_trials")
xc <- 5.35
xl <- 1.75
xr <- 9.95
boxes <- bind_rows(
  box_df("enrolled", xc, 19.2, 4.0, 1.15, "Enrolled\n69"),
  box_df("excl2", xl, 17.65, 3.0, 1.4, "Excluded: 2\nMCI, 1\nTremor, 1", fill = "#F3F4F6"),
  box_df("analyzed", xc, 16.05, 4.0, 1.15, "Analyzed\n67 participants"),
  box_df("collected", xc, 13.65, 4.0, 1.2, sprintf("Trials collected\n%s", fmt_n(n_collected))),
  box_df("excl240", xl, 12.1, 3.0, 1.3, sprintf("Excluded: %s\ncue-locked RT < 0.20 s", fmt_n(n_cue_excluded)), fill = "#F3F4F6"),
  box_df("primary", xc, 9.7, 4.2, 2.15, sprintf(
    "Primary analysis\n%s trials\nADT: %d participants, %s trials\nVDT: %d participants, %s trials",
    fmt_n(n_cue_kept), n_adt_subj, fmt_n(n_adt_tri), n_vdt_subj, fmt_n(n_vdt_tri)
  )),
  box_df("sensitivity", xc, 6.35, 4.2, 2.2, sprintf(
    "Sensitivity samples\nRT cutoff 0.15 s: %s trials\nRT cutoff 0.25 s: %s trials\nNear-chance excluded: %d participants, %s trials",
    fmt_n(flow_n("cutoff_0.15_trials", "n_trials")),
    fmt_n(flow_n("cutoff_0.25_trials", "n_trials")),
    54, fmt_n(14642)
  ), linetype = "dashed", fill = "#FAFAFA"),
  box_df("matched", xr, 9.7, 3.6, 1.3, sprintf("Matched to a pupil recording\n%s trials (%d)", fmt_n(gate_n("matched", "n_trials")), gate_n("matched", "n_subjects"))),
  box_df("tepr", xr, 7.95, 3.6, 1.2, sprintf("TEPR present\n%s trials (%d)", fmt_n(gate_n("tepr_nonmissing", "n_trials")), gate_n("tepr_nonmissing", "n_subjects"))),
  box_df("baseline", xr, 6.25, 3.6, 1.2, sprintf("Baseline quality\n%s trials (%d)", fmt_n(gate_n("B1_quality_ge_0.50", "n_trials")), gate_n("B1_quality_ge_0.50", "n_subjects"))),
  box_df("window", xr, 4.55, 3.6, 1.2, sprintf("Window quality\n%s trials (%d)", fmt_n(gate_n("cog_quality_ge_0.50", "n_trials")), gate_n("cog_quality_ge_0.50", "n_subjects"))),
  box_df("min20", xr, 2.7, 3.6, 1.5, sprintf("At least 20 trials\nper participant and task\n%s trials (%d)", fmt_n(gate_n("subject_task_ge_20", "n_trials")), gate_n("subject_task_ge_20", "n_subjects")))
)
edge <- function(id, side) {
  b <- boxes[boxes$id == id, ]
  switch(side, top = b$ymax, bottom = b$ymin, left = b$xmin, right = b$xmax, cx = b$x, cy = b$y)
}
arr <- function(x, y, xend, yend, linetype = "solid") tibble(x, y, xend, yend, linetype)
arrows <- bind_rows(
  arr(edge("enrolled", "cx"), edge("enrolled", "bottom"), edge("analyzed", "cx"), edge("analyzed", "top")),
  arr(edge("enrolled", "cx"), edge("excl2", "cy"), edge("excl2", "right"), edge("excl2", "cy")),
  arr(edge("analyzed", "cx"), edge("analyzed", "bottom"), edge("collected", "cx"), edge("collected", "top")),
  arr(edge("collected", "cx"), edge("collected", "bottom"), edge("primary", "cx"), edge("primary", "top")),
  arr(edge("collected", "cx"), edge("excl240", "cy"), edge("excl240", "right"), edge("excl240", "cy")),
  arr(edge("primary", "right"), edge("matched", "cy"), edge("matched", "left"), edge("matched", "cy")),
  arr(edge("matched", "cx"), edge("matched", "bottom"), edge("tepr", "cx"), edge("tepr", "top")),
  arr(edge("tepr", "cx"), edge("tepr", "bottom"), edge("baseline", "cx"), edge("baseline", "top")),
  arr(edge("baseline", "cx"), edge("baseline", "bottom"), edge("window", "cx"), edge("window", "top")),
  arr(edge("window", "cx"), edge("window", "bottom"), edge("min20", "cx"), edge("min20", "top")),
  arr(edge("primary", "cx"), edge("primary", "bottom"), edge("sensitivity", "cx"), edge("sensitivity", "top"), "dashed")
)
sf <- ggplot() +
  geom_segment(data = arrows %>% filter(linetype == "solid"),
               aes(x = x, y = y, xend = xend, yend = yend),
               arrow = arrow(length = unit(1.8, "mm"), type = "closed"), linewidth = 0.35) +
  geom_segment(data = arrows %>% filter(linetype != "solid"),
               aes(x = x, y = y, xend = xend, yend = yend),
               arrow = arrow(length = unit(1.8, "mm"), type = "closed"),
               linetype = "dashed", linewidth = 0.35, color = "#4B5563") +
  geom_rect(data = boxes, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, linetype = linetype, fill = fill),
            color = "#111827", linewidth = 0.35) +
  geom_text(data = boxes, aes(x = x, y = y, label = label), size = 2.45, lineheight = 0.92) +
  scale_linetype_identity() +
  scale_fill_identity() +
  coord_cartesian(xlim = c(0.05, 11.95), ylim = c(1.6, 20.05), clip = "off") +
  theme_void() +
  theme(plot.margin = margin(6, 8, 6, 6),
        plot.background = element_rect(fill = "white", colour = NA),
        panel.background = element_rect(fill = "white", colour = NA))
save_r8(
  sf, "S_participant_flow", 8.6, 10.6,
  paste(
    "Behavioral counts are the checked r5 values: 69 enrolled, 2 excluded, 18,097 collected, 240 cue-locked RT < 0.20 s, 17,857 primary (ADT 64/8,774, VDT 65/9,083), cutoffs 17,981 and 17,720, near-chance 54 participants and 14,642 trials.",
    "Pupil counts are the December 21 r8 gates in data/analysis_ready/r8/qc_gate_counts.csv: 12,630, 9,405, 5,888, 5,107, 4,952 (42 participants).",
    "The dashed box is not a further exclusion from the primary analysis.",
    sep = " "
  )
)
message("Wrote S_participant_flow")

# ---- Timecourse on the r8 QC trials, December 21 flats.
flat_line <- grep("^processed_dir:", readLines("config/data_paths.yaml"), value = TRUE)
flat_dir <- gsub("^processed_dir:\\s*|\"", "", flat_line[[1]])
flat_dir <- sub("\\s+$", "", flat_dir)
if (!dir.exists(flat_dir)) stop("Flat-file directory not found: ", flat_dir)
infer_dt <- function(time_vec) {
  time_vec <- time_vec[is.finite(time_vec)]
  diffs <- diff(sort(unique(time_vec)))
  diffs <- diffs[diffs > 0 & is.finite(diffs)]
  if (!length(diffs)) return(0.004)
  dt_median <- median(diffs)
  if (dt_median >= 1 && dt_median <= 10) dt_median <- dt_median / 1000
  if (!is.finite(dt_median) || dt_median <= 0 || dt_median > 0.05) 0.004 else dt_median
}
qc_tepr <- fread("data/analysis_ready/r8/ddm_pupil_r8_qc.csv")
qc_tepr[, `:=`(subject_id = as.character(subject_id), task = as.character(task),
               session = as.integer(session), run = as.integer(run), trial = as.integer(trial),
               effort_condition = as.character(effort_condition))]
n_qc <- nrow(qc_tepr)
grid <- seq(-0.5, 8, by = 0.02)
pairs <- unique(qc_tepr[, .(subject_id, task)])
subj_pieces <- vector("list", nrow(pairs))
n_joined <- 0L
n_b0 <- 0L
for (i in seq_len(nrow(pairs))) {
  subj <- pairs$subject_id[i]
  tsk <- pairs$task[i]
  path <- file.path(flat_dir, sprintf("%s_%s_flat.csv", subj, tsk))
  message(sprintf("  [%02d/%02d] %s", i, nrow(pairs), basename(path)))
  if (!file.exists(path)) stop("Missing flat file: ", path)
  dt <- fread(path, select = c("sub", "task", "session_used", "run_used", "trial_in_run_raw", "time", "pupil"), showProgress = FALSE)
  setnames(dt, c("sub", "session_used", "run_used", "trial_in_run_raw"), c("subject_id", "session", "run", "trial"))
  dt[, `:=`(subject_id = as.character(subject_id), task = as.character(task),
            session = as.integer(session), run = as.integer(run), trial = as.integer(trial),
            time = as.numeric(time), pupil = as.numeric(pupil))]
  dt <- dt[session %in% c(2L, 3L)]
  dt_used <- infer_dt(dt$time)
  wanted <- qc_tepr[subject_id == subj & task == tsk, .(subject_id, task, session, run, trial, effort_condition)]
  kept <- dt[wanted, on = c("subject_id", "task", "session", "run", "trial"), nomatch = 0]
  n_joined <- n_joined + uniqueN(kept, by = c("subject_id", "task", "session", "run", "trial"))
  if (!nrow(kept)) { rm(dt, kept); next }
  series <- kept[, {
    n <- .N
    t_rel <- build_trial_time(
      n, dt_used,
      subject = subject_id[1], task = task[1],
      session = session[1], run = run[1], trial = trial[1]
    )$t
    b0_vals <- pupil[t_rel >= -0.5 & t_rel < 0]
    b0 <- if (sum(is.finite(b0_vals)) >= 10L) mean(b0_vals[is.finite(b0_vals)]) else NA_real_
    if (!is.finite(b0)) .(time = grid, pupil_bc = NA_real_) else
      .(time = grid, pupil_bc = stats::approx(t_rel, pupil - b0, xout = grid, rule = 1, ties = "ordered")$y)
  }, by = .(subject_id, task, session, run, trial)]
  n_b0 <- n_b0 + uniqueN(series[is.finite(pupil_bc)], by = c("subject_id", "task", "session", "run", "trial"))
  series[wanted, on = c("subject_id", "task", "session", "run", "trial"), effort_condition := i.effort_condition]
  subj_pieces[[i]] <- series[, .(
    pupil = if (any(is.finite(pupil_bc))) mean(pupil_bc, na.rm = TRUE) else NA_real_
  ), by = .(subject_id, task, effort_condition, time)]
  rm(dt, kept, series)
}
subj_means <- rbindlist(subj_pieces)
subj_means <- subj_means[is.finite(pupil)]
subj_means[, effort_label := ifelse(effort_condition == "high", "High", "Low")]
means <- subj_means[, .(mean_pupil = mean(pupil), n_subjects = uniqueN(subject_id)), by = .(task, effort_label, time)]
wide <- dcast(subj_means, subject_id + task + time ~ effort_label, value.var = "pupil")
se_tbl <- wide[is.finite(Low) & is.finite(High), {
  subj_m <- (Low + High) / 2
  grand <- mean(subj_m)
  low_c <- Low - subj_m + grand
  high_c <- High - subj_m + grand
  n <- .N
  morey <- sqrt(2)
  .(se_Low = stats::sd(low_c) / sqrt(n) * morey, se_High = stats::sd(high_c) / sqrt(n) * morey, n_both = n)
}, by = .(task, time)]
se_long <- melt(se_tbl, id.vars = c("task", "time", "n_both"), measure.vars = c("se_Low", "se_High"),
                variable.name = "effort_label", value.name = "se")
se_long[, effort_label := ifelse(effort_label == "se_Low", "Low", "High")]
plot_tepr <- merge(means, se_long, by = c("task", "effort_label", "time"), all.x = TRUE)
setorder(plot_tepr, task, effort_label, time)
plot_tepr <- as_tibble(plot_tepr) %>%
  mutate(effort_label = factor(effort_label, levels = c("Low", "High")),
         task = factor(task, levels = c("ADT", "VDT")))
p_tepr <- ggplot(plot_tepr, aes(x = time, y = mean_pupil, color = effort_label, fill = effort_label)) +
  annotate("rect", xmin = 1.0, xmax = 4.35, ymin = -Inf, ymax = Inf, fill = "#E5E7EB", alpha = 0.85) +
  annotate("rect", xmin = 4.65, xmax = 7.65, ymin = -Inf, ymax = Inf, fill = "#DBEAFE", alpha = 0.55) +
  geom_vline(xintercept = 4.35, linewidth = 0.35, color = "#111827") +
  geom_vline(xintercept = 4.70, linewidth = 0.35, linetype = "dashed", color = "#111827") +
  geom_ribbon(aes(ymin = mean_pupil - se, ymax = mean_pupil + se), alpha = 0.22, color = NA) +
  geom_line(linewidth = 0.6) +
  facet_wrap(~ task, ncol = 1) +
  scale_color_manual(values = c(Low = unname(effort_colors["Low"]), High = unname(effort_colors["High"])), name = "Effort") +
  scale_fill_manual(values = c(Low = unname(effort_colors["Low"]), High = unname(effort_colors["High"])), name = "Effort") +
  scale_x_continuous(breaks = seq(0, 8, by = 1), limits = c(-0.5, 8)) +
  labs(x = "Time from squeeze onset (s)", y = "Baseline-corrected pupil (a.u.)",
       caption = "Grey band: grip period (1.0-4.35 s). Blue band: decision-window AUC (4.65-7.65 s). Solid line: probe (4.35 s). Dashed line: response cue (4.70 s).") +
  theme_ms()
n_cells <- uniqueN(subj_means, by = c("subject_id", "task", "effort_label"))
save_r8(
  p_tepr, "S_tepr_timecourse", 8.2, 7.2,
  sprintf(paste(
    "December 21 flat files in %s, restricted to the %d r8 QC trials.",
    "Same clock as the r8 AUC: first sample at -3.0 s, even spacing from -3.0 to 10.7 s when the step does not end between 8 and 15 s.",
    "B0 baseline [-0.5, 0) with at least 10 finite samples. Display grid is 50 Hz from -0.5 to 8 s.",
    "Line is the unweighted mean of within-participant means. Band is the Morey within-participant SE, effort repeated inside each task.",
    "Joined %d of %d QC trials; %d had a usable baseline. The average uses %d subject-by-task-by-effort cells.",
    sep = " "
  ), flat_dir, n_qc, n_joined, n_qc, n_b0, n_cells)
)
message(sprintf("S_tepr joined %d / %d, baseline %d, cells %d", n_joined, n_qc, n_b0, n_cells))
