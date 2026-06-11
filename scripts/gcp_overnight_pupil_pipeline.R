#!/usr/bin/env Rscript
# ==============================================================================
# GCP overnight pupil-DDM pipeline
# ==============================================================================
# Completes primary pupil models (m2–m3 if needed), postprocesses tables, then
# runs truncated-AUC (w1p3) sensitivity fits in output/ddm_pupil_w1p3/.
#
# Usage (on GCP VM, detached — see run_gcp_overnight_detached.sh):
#   DDM_RUN_ID=20260226_092110 PUPIL_REFIT=on_change \
#     Rscript scripts/gcp_overnight_pupil_pipeline.R
# ==============================================================================

suppressPackageStartupMessages({
  library(here)
})

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || is.na(x)) y else x

ROOT <- here::here()
RUN_ID <- Sys.getenv("DDM_RUN_ID", "20260226_092110")
PUPIL_REFIT <- Sys.getenv("PUPIL_REFIT", "on_change")
SKIP_W1P3 <- isTRUE(tolower(Sys.getenv("SKIP_W1P3", "false")) %in% c("1", "true", "yes"))

STATUS_DIR <- file.path(ROOT, "output", "ddm_pupil", "logs")
dir.create(STATUS_DIR, recursive = TRUE, showWarnings = FALSE)
STATUS_FILE <- file.path(STATUS_DIR, "gcp_overnight_status.txt")
MASTER_LOG <- file.path(STATUS_DIR, "gcp_overnight_master.log")

write_status <- function(step, msg) {
  line <- sprintf("[%s] %s — %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), step, msg)
  cat(line, "\n")
  cat(line, "\n", file = STATUS_FILE, append = TRUE)
  cat(line, "\n", file = MASTER_LOG, append = TRUE)
}

run_step <- function(step_name, expr) {
  write_status(step_name, "START")
  t0 <- Sys.time()
  ok <- tryCatch({
    force(expr)
    TRUE
  }, error = function(e) {
    write_status(step_name, paste("FAILED:", conditionMessage(e)))
    FALSE
  })
  mins <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)
  if (ok) write_status(step_name, paste("OK (", mins, " min)", sep = ""))
  if (!ok) stop("Pipeline halted at step: ", step_name)
  invisible(ok)
}

fit_and_post <- function(output_base, z_col, metric_label, data_file) {
  Sys.setenv(
    PUPIL_OUTPUT_BASE = output_base,
    PUPIL_Z_COL = z_col,
    PUPIL_METRIC_LABEL = metric_label,
    PUPIL_DATA_FILE = data_file,
    PUPIL_REFIT = PUPIL_REFIT,
    DDM_RUN_ID = RUN_ID
  )
  source(file.path(ROOT, "scripts", "fit_pupil_ddm_models.R"), local = new.env())
  source(file.path(ROOT, "scripts", "postprocess_pupil_ddm_models.R"), local = new.env())
}

cat("", file = STATUS_FILE)
write_status("INIT", paste("ROOT =", ROOT, "| RUN_ID =", RUN_ID, "| PUPIL_REFIT =", PUPIL_REFIT))

# ── 0. VM sanity ─────────────────────────────────────────────────────────────
run_step("vm_check", source(file.path(ROOT, "scripts", "check_vm_capabilities.R"), local = new.env()))

# ── 1. Rebuild pupil join (optional; skip if files fresh) ────────────────────
if (tolower(Sys.getenv("REBUILD_PUPIL_DATA", "auto")) %in% c("1", "true", "yes")) {
  run_step("build_pupil_features", source(file.path(ROOT, "scripts", "build_pupil_trial_features.R"), local = new.env()))
  run_step("build_ddm_pupil_ready", source(file.path(ROOT, "scripts", "build_ddm_pupil_ready_data.R"), local = new.env()))
} else {
  primary_csv <- file.path(ROOT, "output", "ddm_pupil", "ddm_pupil_ready_thr0.20_probe_onset_locked.csv")
  if (!file.exists(primary_csv)) {
    write_status("build_data", "primary CSV missing — rebuilding pupil features")
    run_step("build_pupil_features", source(file.path(ROOT, "scripts", "build_pupil_trial_features.R"), local = new.env()))
    run_step("build_ddm_pupil_ready", source(file.path(ROOT, "scripts", "build_ddm_pupil_ready_data.R"), local = new.env()))
  } else {
    d <- utils::read.csv(primary_csv, nrows = 5)
    if (!"pupil_w1p3_z" %in% names(d)) {
      write_status("build_data", "pupil_w1p3_z missing — rebuilding join")
      run_step("build_pupil_features", source(file.path(ROOT, "scripts", "build_pupil_trial_features.R"), local = new.env()))
      run_step("build_ddm_pupil_ready", source(file.path(ROOT, "scripts", "build_ddm_pupil_ready_data.R"), local = new.env()))
    } else {
      write_status("build_data", "SKIP (existing ddm_pupil ready CSV with w1p3 columns)")
    }
  }
}

PRIMARY_DATA <- file.path(ROOT, "output", "ddm_pupil", "ddm_pupil_ready_thr0.20_probe_onset_locked.csv")
if (!file.exists(PRIMARY_DATA)) {
  stop("Missing primary pupil-ready data: ", PRIMARY_DATA)
}

# ── 2. Primary metric (Decision-Response AUC w3) ───────────────────────────
run_step("primary_fit_post", fit_and_post(
  output_base = "output/ddm_pupil",
  z_col = "pupil_metric_primary_z",
  metric_label = "Decision-Response AUC (w3.0)",
  data_file = PRIMARY_DATA
))

# Mirror tables for QMD fallback path output/pupil_ddm/
run_step("sync_pupil_ddm", source(file.path(ROOT, "scripts", "sync_pupil_to_publish.R"), local = new.env()))

# ── 3. Truncated AUC sensitivity (w1p3) ────────────────────────────────────
if (!SKIP_W1P3) {
  d_check <- utils::read.csv(PRIMARY_DATA, nrows = 1000)
  n_w1p3 <- sum(!is.na(d_check$pupil_w1p3_z))
  if (n_w1p3 < 100) {
    write_status("w1p3_sensitivity", paste("SKIP — only", n_w1p3, "non-NA pupil_w1p3_z in sample"))
  } else {
    run_step("w1p3_fit_post", fit_and_post(
      output_base = "output/ddm_pupil_w1p3",
      z_col = "pupil_w1p3_z",
      metric_label = "Truncated AUC (w1p3, 0.3–1.3 s)",
      data_file = PRIMARY_DATA
    ))
    # Side-by-side LOO comparison
    loo_primary <- file.path(ROOT, "output", "ddm_pupil", "tables", "pupil_loo_summary.csv")
    loo_w1p3 <- file.path(ROOT, "output", "ddm_pupil_w1p3", "tables", "pupil_loo_summary.csv")
    if (file.exists(loo_primary) && file.exists(loo_w1p3)) {
      lp <- read.csv(loo_primary)
      lw <- read.csv(loo_w1p3)
      lp$tepr_window <- "w3_primary"
      lw$tepr_window <- "w1p3_truncated"
      cmp <- rbind(lp, lw)
      out_cmp <- file.path(ROOT, "output", "ddm_pupil", "tables", "pupil_loo_window_comparison.csv")
      write.csv(cmp, out_cmp, row.names = FALSE)
      write_status("w1p3_compare", paste("Wrote", out_cmp))
    }
  }
} else {
  write_status("w1p3_sensitivity", "SKIP (SKIP_W1P3=true)")
}

write_status("COMPLETE", "All steps finished. Run: bash scripts/pack_pupil_ddm_for_download.sh")
