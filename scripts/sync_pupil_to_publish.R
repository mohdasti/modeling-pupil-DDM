#!/usr/bin/env Rscript
# Copy primary pupil-DDM tables to output/pupil_ddm/ (QMD fallback path).
#
# Usage:
#   PUPIL_OUTPUT_BASE=output/ddm_pupil Rscript scripts/sync_pupil_to_publish.R

suppressPackageStartupMessages(library(readr))

ROOT <- normalizePath(getwd())
SRC_BASE <- file.path(ROOT, Sys.getenv("PUPIL_OUTPUT_BASE", "output/ddm_pupil"))
DST_BASE <- file.path(ROOT, "output", "pupil_ddm")

if (!dir.exists(file.path(SRC_BASE, "tables"))) {
  stop("No pupil tables at: ", file.path(SRC_BASE, "tables"))
}

dir.create(file.path(DST_BASE, "tables"), recursive = TRUE, showWarnings = TRUE)
dir.create(file.path(DST_BASE, "models"), recursive = TRUE, showWarnings = TRUE)

copy_tree <- function(src_sub, dst_sub) {
  src <- file.path(SRC_BASE, src_sub)
  dst <- file.path(DST_BASE, dst_sub)
  if (!dir.exists(src)) return(invisible(NULL))
  dir.create(dst, recursive = TRUE, showWarnings = FALSE)
  files <- list.files(src, full.names = TRUE)
  for (f in files) {
    if (!file.copy(f, file.path(dst, basename(f)), overwrite = TRUE)) {
      warning("copy failed: ", f)
    }
  }
}

copy_tree("tables", "tables")
copy_tree("models", "models")

message("Synced ", SRC_BASE, " -> ", DST_BASE)
