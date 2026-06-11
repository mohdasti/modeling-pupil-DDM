#!/usr/bin/env Rscript
# ==============================================================================
# Project Inventory: List files under project root to see what exists
# and what may need to be uploaded (raw data, pupil, scripts).
# Usage: Rscript scripts/inventory_project.R
#        Or from R: source("scripts/inventory_project.R")
# ==============================================================================

root <- Sys.getenv("PROJECT_ROOT", unset = "~/Feb2026")
if (!dir.exists(path.expand(root))) {
  root <- getwd()
  message("Using getwd(): ", root)
} else {
  root <- normalizePath(path.expand(root))
}

cat("\n=== PROJECT INVENTORY:", root, "===\n\n")

# Helper: list files with size
list_dir <- function(path, pattern = NULL, recursive = FALSE, max_depth = Inf) {
  if (!dir.exists(path)) return(character(0))
  if (recursive) {
    f <- list.files(path, recursive = TRUE, full.names = TRUE, include.dirs = FALSE)
    if (!is.null(pattern)) f <- grep(pattern, f, value = TRUE)
    # Limit depth
    depth <- lengths(strsplit(sub(path, "", f, fixed = TRUE), .Platform$file.sep))
    f <- f[depth <= max_depth]
  } else {
    f <- list.files(path, full.names = TRUE, include.dirs = FALSE)
    if (!is.null(pattern)) f <- grep(pattern, f, value = TRUE)
  }
  f
}

# Directories of interest
dirs <- c(
  "data",
  "data/ddm_ready_data_unthresholded.csv",
  "data/pupil_processed",
  "data/pupil_processed/analysis_ready",
  "data/analysis_ready",
  "output",
  "output/pupil",
  "output/ddm_pupil",
  "output/ddm_refits",
  "scripts",
  "quick_share_v7"
)

cat("--- DIRECTORIES & KEY FILES ---\n")
for (d in dirs) {
  p <- file.path(root, d)
  if (file.exists(p)) {
    if (dir.exists(p)) {
      n <- length(list.files(p, recursive = TRUE))
      cat("  [DIR] ", d, " (", n, " items)\n", sep = "")
    } else {
      sz <- round(file.info(p)$size / 1024, 1)
      cat("  [FILE]", d, " (", sz, " KB)\n", sep = "")
    }
  } else {
    cat("  [MISSING]", d, "\n")
  }
}

cat("\n--- DATA FILES (csv, rds) ---\n")
data_files <- list.files(root, pattern = "\\.(csv|rds)$", recursive = TRUE, full.names = TRUE)
# Trim to project-relative paths
rel <- sub(paste0("^", gsub("([.*+?^${}()|[\\]\\\\])", "\\\\\\1", root), "/?"), "", data_files)
for (f in head(rel, 80)) {
  full <- file.path(root, f)
  sz <- round(file.info(full)$size / 1024 / 1024, 2)
  cat("  ", f, " (", sz, " MB)\n", sep = "")
}
if (length(rel) > 80) cat("  ... and", length(rel) - 80, "more\n")

cat("\n--- PUPIL-RELATED FILES ---\n")
pupil_files <- list.files(root, pattern = "pupil", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
rel_p <- sub(paste0("^", gsub("([.*+?^${}()|[\\]\\\\])", "\\\\\\1", root), "/?"), "", pupil_files)
for (f in head(rel_p, 50)) {
  full <- file.path(root, f)
  if (file.info(full)$isdir) next
  sz <- round(file.info(full)$size / 1024, 1)
  cat("  ", f, " (", sz, " KB)\n", sep = "")
}
if (length(rel_p) > 50) cat("  ... and", length(rel_p) - 50, "more\n")

cat("\n--- SCRIPTS (R, sh) ---\n")
script_files <- list.files(file.path(root, "scripts"), pattern = "\\.(R|r|sh)$", recursive = TRUE, full.names = FALSE)
for (f in head(script_files, 60)) cat("  scripts/", f, "\n", sep = "")
if (length(script_files) > 60) cat("  ... and", length(script_files) - 60, "more\n")

cat("\n--- PIPELINE INPUTS CHECK ---\n")
checks <- list(
  "DDM data (for ddm_refit_gcp)" = c("data/ddm_ready_data_unthresholded.csv"),
  "Pupil trial features (for build_ddm_pupil_ready)" = c("output/pupil/pupil_trial_features.csv"),
  "Pupil source (for build_pupil_trial_features)" = c(
    "data/pupil_processed/analysis_ready/ch3_triallevel.csv",
    "quick_share_v7/analysis_ready/ch3_triallevel.csv",
    "data/analysis_ready/ch3_triallevel.csv"
  )
)
for (name in names(checks)) {
  paths <- checks[[name]]
  found <- paths[file.exists(file.path(root, paths))]
  if (length(found) > 0) {
    cat("  OK ", name, ": ", paste(found, collapse = ", "), "\n", sep = "")
  } else {
    cat("  MISSING ", name, ": need one of ", paste(paths, collapse = ", "), "\n", sep = "")
  }
}

cat("\n")
