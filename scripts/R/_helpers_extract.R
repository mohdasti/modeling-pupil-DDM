# R/_helpers_extract.R
# Common helpers (paths, safe readers, small utilities)
# Used by extraction and reporting scripts

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(purrr)
  library(broom)
  library(broom.mixed)
})

# Resolve project root whether sourced from repo root or scripts/
detect_project_root <- function() {
  candidates <- unique(c(
    getwd(),
    normalizePath(file.path(getwd(), ".."), mustWork = FALSE),
    normalizePath(file.path(getwd(), "../.."), mustWork = FALSE)
  ))
  for (root in candidates) {
    if (dir.exists(file.path(root, "output", "publish")) &&
        (file.exists(file.path(root, "data", "ddm_ready_data_unthresholded.csv")) ||
         dir.exists(file.path(root, "data")))) {
      return(normalizePath(root))
    }
  }
  normalizePath(getwd())
}

PROJECT_ROOT <- detect_project_root()
PUBLISH_DIR  <- file.path(PROJECT_ROOT, "output", "publish")
dir.create(PUBLISH_DIR, recursive = TRUE, showWarnings = FALSE)

# ---------- Paths ----------
# Prefer bap_ddm_only_ready (valid rt/accuracy); bap_ddm_ready has all-NA rt/iscorr
DATA_PATH <- file.path(PROJECT_ROOT, "data/analysis_ready/bap_ddm_only_ready.csv")
if (!file.exists(DATA_PATH)) {
  DATA_PATH <- file.path(PROJECT_ROOT, "data/ddm_ready_data_unthresholded.csv")
}
if (!file.exists(DATA_PATH)) {
  DATA_PATH <- file.path(PROJECT_ROOT, "data/analysis_ready/bap_ddm_ready.csv")
}
MODEL_PATH <- file.path(PUBLISH_DIR, "fit_primary_vza.rds")
LOO_PATH   <- file.path(PUBLISH_DIR, "loo_difficulty_all.csv")

PPC_MAIN   <- file.path(PUBLISH_DIR, "table3_ppc_primary_pooled.csv")
PPC_COND   <- file.path(PUBLISH_DIR, "table3_ppc_primary_conditional.csv")
PPC_UNCOND <- file.path(PUBLISH_DIR, "table3_ppc_primary_unconditional.csv")

# Map export_ppc_primary_diagnostic column names to legacy extract names
normalize_ppc_metric_cols <- function(ppc) {
  if ("difficulty_3" %in% names(ppc) && !"difficulty_level" %in% names(ppc)) {
    ppc$difficulty_level <- ppc$difficulty_3
  }
  qp_src <- intersect(
    c("qp_rmse_max", "qp_rmse", "qp_rmse_uncond", "qp_rmse_cond", "qp_rmse_subj"),
    names(ppc)
  )[1]
  ks_src <- intersect(
    c("ks_mean_max", "ks_mean", "ks_uncond", "ks_cond", "ks_subj"),
    names(ppc)
  )[1]
  if (!is.na(qp_src)) {
    if (!"qp_rmse_max" %in% names(ppc)) ppc$qp_rmse_max <- ppc[[qp_src]]
    if (!"qp_rmse" %in% names(ppc)) ppc$qp_rmse <- ppc[[qp_src]]
  }
  if (!is.na(ks_src)) {
    if (!"ks_mean_max" %in% names(ppc)) ppc$ks_mean_max <- ppc[[ks_src]]
    if (!"ks_mean" %in% names(ppc)) ppc$ks_mean <- ppc[[ks_src]]
  }
  ppc
}

# ---------- Safe readers ----------
safe_read_csv <- function(path) {
  if (!file.exists(path)) stop("Missing file: ", path)
  read_csv(path, show_col_types = FALSE)
}

write_clean <- function(df, path) {
  if (!grepl("^/", path) && !grepl("^[A-Za-z]:", path)) {
    path <- file.path(PROJECT_ROOT, path)
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  write_csv(df, path)
  message("✓ wrote: ", path)
}

# ---------- Data helpers ----------
# Small accuracy helper if not present
ensure_decision <- function(dd) {
  if (!"decision" %in% names(dd)) {
    cand <- c("correct", "iscorr", "is_correct", "accuracy", "acc")
    have <- cand[cand %in% names(dd)]
    if (length(have)) {
      dd$decision <- as.integer(dd[[have[1]]])
    } else {
      stop("No 'decision' or correctness field found.")
    }
  }
  dd$decision <- as.integer(dd$decision)
  dd
}


