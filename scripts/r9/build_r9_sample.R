# Build the r9 pupil sample from the step-rule QC keys.
# Does not fit a model and does not overwrite data/analysis_ready/r8.

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(tibble)
})

ROOT <- normalizePath(getwd(), mustWork = TRUE)
setwd(ROOT)
KEYS <- "output/diagnostics/r8_gatefix/qc_new_keys.csv"
BEH <- "data/analysis_ready/r5/ddm_behavioral_r5_full17857.csv"
MET <- "data/analysis_ready/r8/ddm_pupil_r8_matched_metrics.csv"
OUT <- "data/analysis_ready/r9"
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
stopifnot(file.exists(KEYS), file.exists(BEH), file.exists(MET))

keys <- fread(KEYS)
beh <- fread(BEH)
met <- fread(MET)
id <- c("subject_id", "task", "session", "run", "trial")
for (dt in list(keys, beh, met)) {
  dt[, `:=`(subject_id = as.character(subject_id), task = as.character(task),
            session = as.integer(session), run = as.integer(run), trial = as.integer(trial))]
}
met <- met[matched == TRUE]
raw_cols <- c(id, "baseline_raw", "b1_mean", "B1_quality", "tepr_raw", "auc_b0", "cog_quality",
              "prechoice_raw", "prechoice_prop", "prechoice_status", "grip_raw", "grip_prop", "grip_status")
g4 <- merge(beh, met[, ..raw_cols], by = id)
g4 <- merge(g4, keys[, .(subject_id, task, session, run, trial, B1_new, cog_new)], by = id)
stopifnot(nrow(g4) == nrow(keys))
g4[, `:=`(B1_quality = B1_new, cog_quality = cog_new)]
g4[, c("B1_new", "cog_new") := NULL]

scale_within <- function(df, raw_col, out_col) {
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
if (any(!is.finite(qc$tepr_c))) stop("Pooled within-cell SD was undefined for tepr_c.")
qc[, row_id := .I]
base_scaled <- as.data.table(scale_within(qc, "baseline_raw", "base_c"))
qc[, base_c := NA_real_]
qc[match(base_scaled$row_id, row_id), base_c := base_scaled$base_c]

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
full_cols <- c(qc_cols, "lag_tepr_raw", "lag_tepr_c",
               "prechoice_raw", "prechoice_c", "prechoice_prop", "prechoice_status",
               "grip_raw", "grip_c", "grip_prop", "grip_status", "keep_p3_rt")
fwrite(qc[, ..qc_cols], file.path(OUT, "ddm_pupil_r9_qc.csv"))
fwrite(qc[, ..full_cols], file.path(OUT, "ddm_pupil_r9.csv"))
fwrite(qc[is.finite(lag_tepr_c)], file.path(OUT, "ddm_pupil_r9_lag.csv"))
fwrite(qc[is.finite(prechoice_c)], file.path(OUT, "ddm_pupil_r9_prechoice.csv"))
fwrite(qc[is.finite(grip_c)], file.path(OUT, "ddm_pupil_r9_grip.csv"))
fwrite(qc[keep_p3_rt == TRUE], file.path(OUT, "ddm_pupil_r9_rt.csv"))
cat("QC", nrow(qc), "subjects", uniqueN(qc$subject_id),
    "base", sum(is.finite(qc$base_c)), "lag", sum(is.finite(qc$lag_tepr_c)),
    "pre", sum(is.finite(qc$prechoice_c)), "grip", sum(is.finite(qc$grip_c)),
    "rt", sum(qc$keep_p3_rt), "\n")
