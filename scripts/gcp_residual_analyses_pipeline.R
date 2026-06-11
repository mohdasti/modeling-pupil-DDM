#!/usr/bin/env Rscript
# ==============================================================================
# GCP residual manuscript analyses
# ==============================================================================
# Resolves remaining ambiguities:
#   1. PPC appendix tables (canonical run 20260226_092110)
#   2. Cavanagh-style pupil → boundary (bs) — primary + truncated TEPR windows
#   3. Combined pupil LOO comparison tables
#
# Usage (on VM, detached — see run_gcp_residual_detached.sh):
#   DDM_RUN_ID=20260226_092110 Rscript scripts/gcp_residual_analyses_pipeline.R
#
# Skip steps:
#   SKIP_PPC=true SKIP_BOUNDARY=true bash scripts/run_gcp_residual_detached.sh
# ==============================================================================

suppressPackageStartupMessages(library(here))

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || is.na(x)) y else x

ROOT <- here::here()
RUN_ID <- Sys.getenv("DDM_RUN_ID", "20260226_092110")
SKIP_PPC <- tolower(Sys.getenv("SKIP_PPC", "false")) %in% c("1", "true", "yes")
SKIP_BOUNDARY <- tolower(Sys.getenv("SKIP_BOUNDARY", "false")) %in% c("1", "true", "yes")
SKIP_BOUNDARY_W1P3 <- tolower(Sys.getenv("SKIP_BOUNDARY_W1P3", "false")) %in% c("1", "true", "yes")
SKIP_DIFFICULTY_ONLY <- tolower(Sys.getenv("SKIP_DIFFICULTY_ONLY", "false")) %in% c("1", "true", "yes")

STATUS_DIR <- file.path(ROOT, "output", "ddm_pupil", "logs")
dir.create(STATUS_DIR, recursive = TRUE, showWarnings = FALSE)
STATUS_FILE <- file.path(STATUS_DIR, "gcp_residual_status.txt")
MASTER_LOG <- file.path(STATUS_DIR, "gcp_residual_master.log")

write_status <- function(step, msg) {
  line <- sprintf("[%s] %s — %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), step, msg)
  cat(line, "\n")
  cat(line, "\n", file = STATUS_FILE, append = TRUE)
  cat(line, "\n", file = MASTER_LOG, append = TRUE)
}

run_step <- function(step_name, expr) {
  write_status(step_name, "START")
  t0 <- Sys.time()
  ok <- tryCatch({ force(expr); TRUE }, error = function(e) {
    write_status(step_name, paste("FAILED:", conditionMessage(e)))
    FALSE
  })
  mins <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)
  if (ok) write_status(step_name, paste("OK (", mins, " min)", sep = ""))
  if (!ok) stop("Pipeline halted at: ", step_name)
  invisible(ok)
}

fit_boundary <- function(step_name, output_base, z_col, baseline_loo_dir) {
  step_log <- file.path(STATUS_DIR, paste0(step_name, ".log"))
  runner <- file.path(ROOT, "scripts", "run_pupil_boundary_env.sh")
  if (!file.exists(runner)) {
    stop("Missing helper script: ", runner)
  }
  cmd <- sprintf(
    "bash %s %s %s %s %s %s",
    shQuote(runner),
    shQuote(step_name),
    shQuote(output_base),
    shQuote(z_col),
    shQuote(baseline_loo_dir),
    shQuote(step_log)
  )
  status <- system(cmd)
  if (!identical(status, 0L)) {
    tail_lines <- if (file.exists(step_log)) {
      paste(tail(readLines(step_log, warn = FALSE), 40), collapse = "\n")
    } else {
      "(no log captured)"
    }
    stop("run_pupil_boundary_env.sh failed (", step_name, ")\n", tail_lines)
  }
}

if (!tolower(Sys.getenv("RESUME_PIPELINE", "false")) %in% c("1", "true", "yes")) {
  cat("", file = STATUS_FILE)
}
write_status("INIT", paste("ROOT =", ROOT, "| RUN_ID =", RUN_ID))

# ── 0. Sanity ────────────────────────────────────────────────────────────────
run_dir <- file.path(ROOT, "output", "ddm_refits", "runs", RUN_ID)
if (!dir.exists(file.path(run_dir, "models"))) {
  stop("Canonical run not on VM: ", run_dir)
}
ready_csv <- file.path(ROOT, "output", "ddm_pupil", "ddm_pupil_ready_thr0.20_probe_onset_locked.csv")
if (!file.exists(ready_csv)) {
  stop("Missing pupil-ready CSV: ", ready_csv)
}
write_status("preflight", "OK")

# ── 1. Difficulty-only LOO (Appendix A1 row) ─────────────────────────────────
if (!SKIP_DIFFICULTY_ONLY) {
  Sys.setenv(DDM_RUN_ID = RUN_ID)
  run_step("difficulty_only_loo", {
    script <- file.path(ROOT, "scripts", "fit_ddm_difficultyonly.R")
    step_log <- file.path(STATUS_DIR, "difficulty_only_loo.log")
    status <- system2("Rscript", script, stdout = step_log, stderr = step_log)
    if (!identical(status, 0L)) {
      tail_lines <- if (file.exists(step_log)) {
        x <- readLines(step_log, warn = FALSE)
        paste(tail(x, 20), collapse = "\n")
      } else {
        "(no log captured)"
      }
      stop("fit_ddm_difficultyonly.R exited with status ", status, "\n", tail_lines)
    }
  })
} else {
  write_status("difficulty_only_loo", "SKIP (SKIP_DIFFICULTY_ONLY=true)")
}

# ── 2. PPC regeneration ──────────────────────────────────────────────────────
if (!SKIP_PPC) {
  Sys.setenv(DDM_RUN_ID = RUN_ID)
  run_step("ppc_sync_publish", source(file.path(ROOT, "scripts", "sync_publish_from_run.R"), local = new.env()))
  run_step("ppc_export_diagnostic", source(file.path(ROOT, "scripts", "R", "export_ppc_primary_diagnostic.R"), local = new.env()))
  run_step("ppc_publish_gate", source(file.path(ROOT, "scripts", "R", "make_publish_gate.R"), local = new.env()))
} else {
  write_status("ppc", "SKIP (SKIP_PPC=true)")
}

# ── 3. Cavanagh pupil → boundary (primary TEPR window) ───────────────────────
if (!SKIP_BOUNDARY) {
  run_step("boundary_primary", fit_boundary(
    step_name = "boundary_primary",
    output_base = "output/ddm_pupil_boundary",
    z_col = "pupil_metric_primary_z",
    baseline_loo_dir = "output/ddm_pupil"
  ))
} else {
  write_status("boundary_primary", "SKIP (SKIP_BOUNDARY=true)")
}

# ── 4. Cavanagh pupil → boundary (truncated TEPR window) ─────────────────────
if (!SKIP_BOUNDARY_W1P3) {
  d <- utils::read.csv(ready_csv, nrows = 500)
  n_w1 <- sum(!is.na(d$pupil_w1p3_z))
  if (n_w1 < 1000) {
    write_status("boundary_w1p3", paste("SKIP — only", n_w1, "non-NA pupil_w1p3_z in sample head"))
  } else {
    run_step("boundary_w1p3", fit_boundary(
      step_name = "boundary_w1p3",
      output_base = "output/ddm_pupil_boundary_w1p3",
      z_col = "pupil_w1p3_z",
      baseline_loo_dir = "output/ddm_pupil_w1p3"
    ))
  }
} else {
  write_status("boundary_w1p3", "SKIP (SKIP_BOUNDARY_W1P3=true)")
}

# ── 5. Merge LOO tables ──────────────────────────────────────────────────────
run_step("build_extended_loo", source(file.path(ROOT, "scripts", "build_pupil_extended_loo_table.R"), local = new.env()))

write_status("COMPLETE", "Run: bash scripts/pack_gcp_residual_results_for_download.sh")
