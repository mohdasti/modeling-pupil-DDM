#!/usr/bin/env Rscript
# Sync selected artifacts from the canonical DDM refit run into output/publish
# for legacy scripts and PPC gate tables. Safe to re-run after every refit.
#
# Usage:
#   DDM_RUN_ID=20260226_092110 Rscript scripts/sync_publish_from_run.R
# Then (PPC gate CSVs):
#   DDM_RUN_ID=20260226_092110 Rscript scripts/R/make_publish_gate.R

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

detect_root <- function() {
  candidates <- c(getwd(), normalizePath(file.path(getwd(), ".."), mustWork = FALSE))
  for (root in candidates) {
    if (dir.exists(file.path(root, "output", "publish"))) return(normalizePath(root))
  }
  normalizePath(getwd())
}

ROOT <- detect_root()
RUN_ID <- Sys.getenv("DDM_RUN_ID", "20260226_092110")
RUN_DIR <- file.path(ROOT, "output", "ddm_refits", "runs", RUN_ID)
TABLES <- file.path(RUN_DIR, "tables")
MODELS <- file.path(RUN_DIR, "models")
PUBLISH <- file.path(ROOT, "output", "publish")
dir.create(PUBLISH, recursive = TRUE, showWarnings = FALSE)

if (!dir.exists(TABLES)) {
  stop("Run tables not found: ", TABLES, "\nSet DDM_RUN_ID to a valid refit run.")
}

copy_if_newer <- function(src, dst) {
  if (!file.exists(src)) {
    message("  skip (missing): ", basename(src))
    return(invisible(FALSE))
  }
  if (file.exists(dst) && file.info(dst)$mtime >= file.info(src)$mtime) {
    message("  up-to-date: ", basename(dst))
    return(invisible(TRUE))
  }
  file.copy(src, dst, overwrite = TRUE)
  message("  synced: ", basename(src), " -> ", basename(dst))
  invisible(TRUE)
}

message("Syncing publish artifacts from run ", RUN_ID)

# Direct copies (same schema; used by legacy readers)
pairs <- c(
  "table_effect_contrasts.csv" = "table_effect_contrasts.csv",
  "fixef_link_scale.csv" = "fixef_link_scale.csv",
  "predicted_parameters_by_condition.csv" = "predicted_parameters_by_condition.csv",
  "convergence_summary.csv" = "convergence_summary.csv",
  "loo_summary.csv" = "loo_summary.csv"
)
for (src_name in names(pairs)) {
  copy_if_newer(
    file.path(TABLES, src_name),
    file.path(PUBLISH, pairs[[src_name]])
  )
}

# Standard-only bias (run schema differs from legacy publish names)
copy_if_newer(
  file.path(TABLES, "standard_only_bias_by_condition.csv"),
  file.path(PUBLISH, "standard_only_bias_by_condition.csv")
)
copy_if_newer(
  file.path(TABLES, "standard_only_bias_contrasts.csv"),
  file.path(PUBLISH, "standard_only_bias_contrasts.csv")
)
copy_if_newer(
  file.path(TABLES, "task_sensitivity_comparison.csv"),
  file.path(PUBLISH, "task_sensitivity_comparison.csv")
)

# Primary model symlink/copy for legacy scripts (primary_vza.rds)
primary_model <- file.path(MODELS, "additive__probe_onset_locked__thr0.20.rds")
legacy_rds <- file.path(PUBLISH, "fit_primary_vza.rds")
if (file.exists(primary_model)) {
  if (!file.exists(legacy_rds) || file.info(legacy_rds)$mtime < file.info(primary_model)$mtime) {
    file.copy(primary_model, legacy_rds, overwrite = TRUE)
    message("  synced: primary additive model -> fit_primary_vza.rds")
  } else {
    message("  up-to-date: fit_primary_vza.rds")
  }
}

manifest <- tibble(
  run_id = RUN_ID,
  synced_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  run_tables_dir = TABLES,
  primary_model = primary_model
)
write_csv(manifest, file.path(PUBLISH, "ddm_run_manifest.csv"))

message("\nNext: regenerate PPC gate CSVs from this run:")
message("  DDM_RUN_ID=", RUN_ID, " Rscript scripts/R/make_publish_gate.R")
message("Manifest written: output/publish/ddm_run_manifest.csv")
