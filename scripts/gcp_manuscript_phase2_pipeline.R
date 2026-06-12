#!/usr/bin/env Rscript
# Phase-2 manuscript analyses (GCP):
#   1. Extended convergence (tail ESS)
#   2. Additive sensitivity fits at RT cutoffs 0.15 / 0.25 (0.20 skipped if present)
#   3. H1/H2 contrast table by cutoff
#   4. PPC mid-body QP RMSE per cell
#   5. Refresh publish gate
#
# Usage:
#   DDM_RUN_ID=20260226_092110 Rscript scripts/gcp_manuscript_phase2_pipeline.R

suppressPackageStartupMessages(library(here))
ROOT <- here::here()
RUN_ID <- Sys.getenv("DDM_RUN_ID", "20260226_092110")
LOG_DIR <- file.path(ROOT, "output", "ddm_refits", "runs", RUN_ID, "logs")
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)
STATUS <- file.path(LOG_DIR, "gcp_phase2_status.txt")

write_status <- function(step, msg) {
  line <- sprintf("[%s] %s — %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), step, msg)
  cat(line, "\n")
  cat(line, "\n", file = STATUS, append = TRUE)
}

run_r <- function(step, script_rel) {
  write_status(step, "START")
  log_file <- file.path(LOG_DIR, paste0(step, ".log"))
  status <- system2("Rscript", file.path(ROOT, script_rel), stdout = log_file, stderr = log_file)
  if (!identical(status, 0L)) {
    tail_txt <- if (file.exists(log_file)) paste(tail(readLines(log_file, warn = FALSE), 25), collapse = "\n") else ""
    stop(step, " failed (status ", status, ")\n", tail_txt)
  }
  write_status(step, "OK")
}

if (!tolower(Sys.getenv("RESUME_PIPELINE", "false")) %in% c("1", "true", "yes")) {
  cat("", file = STATUS)
}
write_status("INIT", paste("RUN_ID =", RUN_ID))

Sys.setenv(DDM_RUN_ID = RUN_ID)

run_r("preflight_brms", "scripts/check_brms_preflight.R")

conv_ext_csv <- file.path(ROOT, "output", "ddm_refits", "runs", RUN_ID, "tables", "convergence_primary_extended.csv")
skip_conv <- tolower(Sys.getenv("SKIP_CONVERGENCE_EXTENDED", "false")) %in% c("1", "true", "yes")
if (skip_conv && file.exists(conv_ext_csv)) {
  write_status("convergence_extended", "SKIP (SKIP_CONVERGENCE_EXTENDED=true; CSV present)")
} else if (file.exists(conv_ext_csv) && Sys.getenv("PUPIL_REFIT", "on_change") != "always") {
  write_status("convergence_extended", "SKIP (convergence_primary_extended.csv already exists)")
} else {
  run_r("convergence_extended", "scripts/R/extract_convergence_extended.R")
}

if (!tolower(Sys.getenv("SKIP_SENSITIVITY_ADDITIVE", "false")) %in% c("1", "true", "yes")) {
  run_r("sensitivity_additive", "scripts/fit_sensitivity_additive_thresholds.R")
} else {
  write_status("sensitivity_additive", "SKIP")
  run_r("h1_h2_export", "scripts/export_h1_h2_by_rt_cutoff.R")
}

if (!tolower(Sys.getenv("SKIP_PPC_MIDBODY", "false")) %in% c("1", "true", "yes")) {
  run_r("ppc_midbody", "scripts/R/export_ppc_primary_diagnostic.R")
  Sys.setenv(DDM_RUN_ID = RUN_ID)
  run_r("publish_gate", "scripts/R/make_publish_gate.R")
} else {
  write_status("ppc_midbody", "SKIP")
}

write_status("COMPLETE", "Run: bash scripts/pack_gcp_phase2_results_for_download.sh")
