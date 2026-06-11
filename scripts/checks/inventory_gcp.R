#!/usr/bin/env Rscript
# Inventory: what files exist for sensitivity analysis (and DDM pipeline)?
# Run on GCP VM to see what you have vs what you need to upload.

cat("\n=== GCP VM File Inventory ===\n\n")

# Find project root: try cwd, parent, common GCP paths
root <- "."
for (d in c(".", "..", "/home/rstudio/modeling-pupil-DDM", "/home/rstudio")) {
  if (file.exists(file.path(d, "scripts/checks/sensitivity.R"))) {
    root <- d
    break
  }
}

cat("Project root:", normalizePath(root, mustWork = FALSE), "\n\n")

check <- function(path, desc = NULL) {
  p <- file.path(root, path)
  exists <- file.exists(p)
  size <- if (exists) format(file.info(p)$size, big.mark = ",") else "-"
  status <- if (exists) "OK" else "MISSING"
  cat(sprintf("  %-50s %s  %s\n", path, status, if (exists) paste0("(", size, " bytes)") else ""))
  invisible(exists)
}

# --- Sensitivity analysis ---
cat("SENSITIVITY ANALYSIS (scripts/checks/sensitivity.R)\n")
cat(paste(rep("-", 60), collapse = ""), "\n")
check("scripts/checks/sensitivity.R")
check("data/analysis_ready/bap_ddm_only_ready.csv")
check("data/ddm_ready_data_unthresholded.csv")
check("output/models/Model3_Difficulty.rds")
check("output/models/Model4_Additive.rds")
cat("\n")

# --- DDM refit pipeline ---
cat("DDM REFIT PIPELINE\n")
cat(paste(rep("-", 60), collapse = ""), "\n")
check("scripts/ddm_refit_with_new_threshold.R")
check("scripts/ddm_refit_gcp.R")
check("R/utils/logging_validation.R")
check("data/ddm_ready_data_unthresholded.csv")
check("output/rt_threshold_analysis/ddm_ready_data_unthresholded.csv")
cat("\n")

# --- Outputs (if any) ---
cat("OUTPUTS\n")
cat(paste(rep("-", 60), collapse = ""), "\n")
check("output/checks/sensitivity_summary.csv")
check("output/sensitivity/sensitivity_summary.csv")
run_dirs <- list.dirs(file.path(root, "output/ddm_refits/runs"), full.names = FALSE, recursive = FALSE)
if (length(run_dirs) > 0) {
  cat("  output/ddm_refits/runs/:", length(run_dirs), "run(s)\n")
  for (r in head(run_dirs, 5)) cat("    -", r, "\n")
  if (length(run_dirs) > 5) cat("    ... and", length(run_dirs) - 5, "more\n")
} else {
  cat("  output/ddm_refits/runs/: (empty or missing)\n")
}
cat("\n")

# --- Summary ---
cat("SUMMARY\n")
cat(paste(rep("-", 60), collapse = ""), "\n")
sens_script <- file.exists(file.path(root, "scripts/checks/sensitivity.R"))
sens_data <- file.exists(file.path(root, "data/analysis_ready/bap_ddm_only_ready.csv")) ||
  file.exists(file.path(root, "data/ddm_ready_data_unthresholded.csv"))
sens_models <- file.exists(file.path(root, "output/models/Model3_Difficulty.rds")) &&
  file.exists(file.path(root, "output/models/Model4_Additive.rds"))

if (sens_script && sens_data && sens_models) {
  cat("  Sensitivity: READY (script + data + baseline models)\n")
} else {
  cat("  Sensitivity: NEED\n")
  if (!sens_script) cat("    - scripts/checks/sensitivity.R\n")
  if (!sens_data) cat("    - data (bap_ddm_only_ready.csv or ddm_ready_data_unthresholded.csv)\n")
  if (!sens_models) cat("    - output/models/Model3_Difficulty.rds, Model4_Additive.rds\n")
}
cat("\n=== Done ===\n")
