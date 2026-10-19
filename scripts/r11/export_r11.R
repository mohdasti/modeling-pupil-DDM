# Apply a finished r11 run to the local Phase 1d tables.
# Does not fit a model. Reads the r11 run directory and tables/final.
# Pupil keys are rebuilt by the Phase 1d V_inline_values.R, from T7/T8/T9.
#
#   R11_RUN_ID=r11_<timestamp> Rscript scripts/r11/export_r11.R

options(warn = 1, scipen = 999)
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
})

ROOT <- normalizePath(getwd(), mustWork = TRUE)
setwd(ROOT)
FINAL <- "output/ddm_refits/runs/final_20261016"
TAB <- file.path(FINAL, "tables", "final")
OUT_ROOT <- "output/ddm_refits/runs"

run_id <- Sys.getenv("R11_RUN_ID", "")
if (!nzchar(run_id)) {
  id_file <- file.path(OUT_ROOT, "r11_latest_run_id.txt")
  if (!file.exists(id_file)) stop("Set R11_RUN_ID. No r11_latest_run_id.txt.", call. = FALSE)
  run_id <- trimws(readLines(id_file, n = 1L, warn = FALSE))
}
if (!grepl("^r11_", run_id)) stop("R11_RUN_ID must start with r11_: ", run_id, call. = FALSE)
run_dir <- file.path(OUT_ROOT, run_id)
if (!dir.exists(run_dir)) stop("r11 run directory not found: ", run_dir, call. = FALSE)

need <- c(
  file.path(run_dir, "tables", "convergence.csv"),
  file.path(run_dir, "tables", "model_comparison_M0_M4b.csv"),
  file.path(run_dir, "tables", "M4_thr0.15_effort_terms.csv"),
  file.path(run_dir, "loo", "loo_M1.rds"),
  file.path(run_dir, "loo", "loo_M2.rds"),
  file.path(FINAL, "loo", "loo_M0.rds")
)
missing <- need[!file.exists(need)]
if (length(missing)) stop("r11 export is missing: ", paste(missing, collapse = ", "), call. = FALSE)

conv <- read_csv(file.path(run_dir, "tables", "convergence.csv"), show_col_types = FALSE)
cmp <- read_csv(file.path(run_dir, "tables", "model_comparison_M0_M4b.csv"), show_col_types = FALSE)
new_eff <- read_csv(file.path(run_dir, "tables", "M4_thr0.15_effort_terms.csv"), show_col_types = FALSE)
expected <- c("M1", "M2", "M4_thr0.15")
if (!setequal(conv$model, expected)) {
  stop("convergence.csv models are ", paste(conv$model, collapse = ", "), call. = FALSE)
}
pass <- with(conv, max_rhat < 1.01 & min_bulk_ess >= 400 & min_tail_ess >= 400 & divergences == 0)
if (!all(pass)) {
  stop(
    "Not exporting. These models fail the convergence rule: ",
    paste(conv$model[!pass], collapse = ", "),
    call. = FALSE
  )
}

backup <- function(path) {
  if (!file.exists(path)) return(invisible(NULL))
  dest <- sub("(\\.[A-Za-z0-9]+)$", "_pre_r11\\1", path)
  if (!file.exists(dest)) file.copy(path, dest, overwrite = FALSE)
  dest
}
for (nm in c(
  "T5_model_comparison.csv", "T5_delta_M0_vs_M1.csv", "T6a_robustness_effort_terms.csv",
  "T10_convergence_all.csv", "T10b_convergence_display.csv", "inline_values.json", "inline_values.rds"
)) backup(file.path(TAB, nm))
backup(file.path(FINAL, "figures", "final", "F3_effort_forest.png"))
backup(file.path(FINAL, "figures", "final", "F3_effort_forest.pdf"))

t5 <- read_csv(file.path(TAB, "T5_model_comparison.csv"), show_col_types = FALSE)
for (id in c("M1", "M2")) {
  hit <- cmp$model == id
  row <- t5$model == id
  if (sum(hit) != 1L || sum(row) != 1L) stop("T5 or comparison row for ", id, " is not unique.", call. = FALSE)
  t5$elpd_loo[row] <- cmp$elpd_loo[hit]
  t5$se_elpd_loo[row] <- cmp$se_elpd_loo[hit]
  t5$p_loo[row] <- cmp$p_loo[hit]
  t5$delta_elpd_vs_M4[row] <- cmp$delta_elpd_vs_M4[hit]
  t5$se_delta_elpd_vs_M4[row] <- cmp$se_delta_elpd_vs_M4[hit]
  t5$n_k_gt_0.7[row] <- cmp$n_k_gt_0.7[hit]
  t5$max_rhat[row] <- conv$max_rhat[conv$model == id]
  t5$min_bulk_ess[row] <- conv$min_bulk_ess[conv$model == id]
  t5$passes_convergence_rule[row] <- TRUE
  t5$rhat_footnote[row] <- ""
}
loo_m0 <- readRDS(file.path(FINAL, "loo", "loo_M0.rds"))
loo_m1 <- readRDS(file.path(run_dir, "loo", "loo_M1.rds"))
pw0 <- loo_m0$pointwise[, "elpd_loo"]
pw1 <- loo_m1$pointwise[, "elpd_loo"]
if (length(pw0) != length(pw1)) {
  stop("M0 LOO has ", length(pw0), " points and M1 has ", length(pw1), ".", call. = FALSE)
}
d01 <- pw0 - pw1
t5_delta <- tibble(
  contrast = "M0_vs_M1", delta_elpd = sum(d01), se = stats::sd(d01) * sqrt(length(d01)),
  source_model = "M0,M1", tier = "ms_supp"
)
write_csv(t5, file.path(TAB, "T5_model_comparison.csv"))
write_csv(t5_delta, file.path(TAB, "T5_delta_M0_vs_M1.csv"))

t6 <- read_csv(file.path(TAB, "T6a_robustness_effort_terms.csv"), show_col_types = FALSE)
info15 <- conv[conv$model == "M4_thr0.15", ]
for (i in seq_len(nrow(new_eff))) {
  hit <- which(t6$model == "M4_thr0.15" & t6$term == new_eff$term[i])
  if (length(hit) != 1L) stop("T6a row for M4_thr0.15 / ", new_eff$term[i], " is not unique.", call. = FALSE)
  for (col in intersect(names(new_eff), names(t6))) t6[[col]][hit] <- new_eff[[col]][i]
  t6$max_rhat[hit] <- info15$max_rhat
  t6$passes_convergence_rule[hit] <- TRUE
}
write_csv(t6, file.path(TAB, "T6a_robustness_effort_terms.csv"))

update_conv <- function(path) {
  x <- read_csv(path, show_col_types = FALSE)
  for (id in conv$model) {
    row <- x$model == id
    if (!any(row)) stop(id, " is missing from ", path, call. = FALSE)
    src <- conv[conv$model == id, ]
    x$chains[row] <- src$chains
    x$iter[row] <- src$iter
    x$warmup[row] <- src$warmup
    x$max_rhat[row] <- src$max_rhat
    x$max_rhat_b[row] <- src$max_rhat_b
    x$min_bulk_ess[row] <- src$min_bulk_ess
    x$min_bulk_ess_b[row] <- src$min_bulk_ess_b
    x$min_tail_ess[row] <- src$min_tail_ess
    x$min_tail_ess_b[row] <- src$min_tail_ess_b
    x$divergences[row] <- src$divergences
    x$treedepth_hits[row] <- src$treedepth_hits
    x$passes_convergence_rule[row] <- TRUE
    if ("note" %in% names(x)) x$note[row] <- paste("max R-hat parameter", src$worst_param)
    if (id %in% c("M1", "M2")) x$n_k_gt_0.7[row] <- cmp$n_k_gt_0.7[cmp$model == id]
  }
  write_csv(x, path)
}
update_conv(file.path(TAB, "T10_convergence_all.csv"))
update_conv(file.path(TAB, "T10b_convergence_display.csv"))

for (id in c("M1", "M2")) {
  dest <- file.path(FINAL, "loo", paste0("loo_", id, ".rds"))
  backup(dest)
  file.copy(file.path(run_dir, "loo", paste0("loo_", id, ".rds")), dest, overwrite = TRUE)
}

st <- system2("Rscript", "scripts/final/V_inline_values.R")
if (!is.null(st) && st != 0) stop("V_inline_values.R exited with status ", st, call. = FALSE)
Sys.setenv(FIG_ONLY = "F3_effort_forest", REVISE_ONLY = "1")
st <- system2("Rscript", "scripts/final/F_figures.R")
if (!is.null(st) && st != 0) stop("F_figures.R exited with status ", st, call. = FALSE)

iv <- readRDS(file.path(TAB, "inline_values.rds"))
if (!identical(iv$n_pupil_final_trials, 4935) || !identical(as.character(iv$acc_model_re), "(1 | subject_id)")) {
  stop("Export changed the Phase 1d pupil sample or the accuracy random effect.", call. = FALSE)
}
if (abs(iv$delta_elpd_P3_vs_P0$delta - 67.94683210390326) > 1e-6) {
  stop("P3 delta ELPD is no longer the r10 value.", call. = FALSE)
}
acc <- iv$acc_high_low_Standard
if (is.null(acc$pp) || is.null(acc$or) || !is.null(acc$mean)) {
  stop("Accuracy keys are no longer the emmeans contrasts.", call. = FALSE)
}
message("r11 export applied from ", run_id, ". Pupil keys and accuracy contrasts are unchanged.")
