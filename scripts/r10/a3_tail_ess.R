# Read-only check of the r10 fits, plus the r8 pointer restore.
# Does not refit. Writes convergence_full.csv and, if needed, restores
# r8_latest_run_id.txt from the misrouted r9 job.
#
#   cd ~/Feb2026
#   Rscript scripts/r10/a3_tail_ess.R

suppressPackageStartupMessages({
  library(brms)
  library(posterior)
  library(readr)
})

options(warn = 1)
setwd(normalizePath(getwd(), mustWork = TRUE))

id_file <- "output/ddm_refits/runs/r10_latest_run_id.txt"
id <- trimws(readLines(id_file, n = 1L, warn = FALSE))
if (!identical(id, "r10_20261017_081458")) {
  stop("r10 id is ", id, ", expected r10_20261017_081458")
}
qc <- grep("Full QC", readLines("output/diagnostics/pupil_rebuild/r10_console.log", warn = FALSE), value = TRUE)[1]
if (!grepl("Full QC 4935", qc) || !grepl("base_c 4488", qc) || !grepl("missing base_c 447", qc)) {
  stop("Unexpected QC line: ", qc)
}

conv <- read_csv(file.path("output/ddm_refits/runs", id, "tables/convergence.csv"), show_col_types = FALSE)
if (nrow(conv) != 15L || !all(conv$pass)) {
  stop("convergence.csv does not have 15 passing models")
}

pointer <- "output/ddm_refits/runs/r8_latest_run_id.txt"
log_dir <- "output/diagnostics/qmd_phase1d"
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
log_path <- file.path(log_dir, "pointer_restore.log")
current <- if (file.exists(pointer)) trimws(readLines(pointer, n = 1L, warn = FALSE)) else "(missing)"
if (identical(current, "r8_20261017_060429")) {
  writeLines("r8_20261017_015218", pointer)
  msg <- sprintf("%s restored r8_latest_run_id.txt from r8_20261017_060429 to r8_20261017_015218",
                 format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
} else {
  msg <- sprintf("%s r8_latest_run_id.txt was %s; left unchanged",
                 format(Sys.time(), "%Y-%m-%d %H:%M:%S"), current)
}
cat(msg, "\n", file = log_path, append = TRUE)
message(msg)

manifest_path <- "output/ddm_refits/runs/MANIFEST.csv"
rows_m <- data.frame(
  run_id = c("r8_20261017_015218", "r8_20261017_060429", "r10_20261017_081458"),
  status = c("superseded_gate_clock", "abandoned_r9_misrouted", "final_pupil"),
  note = c(
    "Original r8 pupil run.",
    "r9 runner fell back to the r8 input; duplicate of r8; do not use",
    "4935-trial pupil sample."
  ),
  stringsAsFactors = FALSE
)
if (!file.exists(manifest_path)) {
  write_csv(rows_m, manifest_path)
  message("Wrote ", manifest_path)
} else {
  header <- names(read_csv(manifest_path, n_max = 0, show_col_types = FALSE))
  if (!identical(header, c("run_id", "status", "note"))) {
    message("Left ", manifest_path, " unchanged; its columns are ", paste(header, collapse = ", "))
  } else {
    old <- read_csv(manifest_path, show_col_types = FALSE)
    old <- old[!old$run_id %in% rows_m$run_id, , drop = FALSE]
    write_csv(rbind(old, rows_m), manifest_path)
    message("Updated ", manifest_path)
  }
}

keys <- c("P0", "P1", "P2", "P3", "P0_base", "P4", "P5",
          "P0_rt", "P3_rt", "P0_lag", "P6", "P0_pre", "P7", "P0_grip", "P8")
run <- file.path("output/ddm_refits/runs", id)
rows <- vector("list", length(keys))
for (i in seq_along(keys)) {
  key <- keys[i]
  path <- file.path(run, "models", sprintf("%s__probe_onset_locked__thr0.20.rds", key))
  message("ESS ", key)
  fit <- readRDS(path)
  draws <- posterior::as_draws_array(fit)
  s <- posterior::summarise_draws(draws, rhat = posterior::rhat, ess_bulk = posterior::ess_bulk, ess_tail = posterior::ess_tail)
  np <- brms::nuts_params(fit)
  div <- sum(np$Parameter == "divergent__" & np$Value > 0)
  rows[[i]] <- data.frame(
    model = key,
    n = conv$n[conv$model == key],
    adapt_delta = conv$adapt_delta[conv$model == key],
    max_rhat = max(s$rhat, na.rm = TRUE),
    min_bulk_ess = min(s$ess_bulk, na.rm = TRUE),
    min_tail_ess = min(s$ess_tail, na.rm = TRUE),
    divergences = div,
    stringsAsFactors = FALSE
  )
  rm(fit, draws, s, np)
  gc(verbose = FALSE)
}
out <- do.call(rbind, rows)
out$pass <- with(out, max_rhat < 1.01 & min_bulk_ess >= 400 & min_tail_ess >= 400 & divergences == 0)
dest <- file.path(run, "tables", "convergence_full.csv")
write_csv(out, dest)
message("Wrote ", dest)
print(out, row.names = FALSE)
if (!all(out$pass)) {
  failed <- paste(out$model[!out$pass], collapse = ", ")
  stop("Tail-ESS rule failed: ", failed, call. = FALSE)
}
message("All 15 models pass max R-hat < 1.01, bulk and tail ESS >= 400, 0 divergences.")
