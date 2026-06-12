#!/usr/bin/env Rscript
# Export H1 (effort on drift) and H2 (effort on boundary) contrasts by RT cutoff.
#
# Reads additive probe-onset-locked models when present:
#   additive__probe_onset_locked__thr0.15.rds
#   additive__probe_onset_locked__thr0.20.rds
#   additive__probe_onset_locked__thr0.25.rds
#
# Uses posterior draws stored in the brmsfit object (no brms/rstan reload).
#
# Usage:
#   DDM_RUN_ID=20260226_092110 Rscript scripts/export_h1_h2_by_rt_cutoff.R
#
# Output:
#   output/ddm_refits/runs/<RUN_ID>/tables/h1_h2_contrasts_by_cutoff.csv

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(here)
  library(tibble)
})

RUN_ID <- Sys.getenv("DDM_RUN_ID", "20260226_092110")
THRESHOLDS <- as.numeric(strsplit(Sys.getenv("DDM_THRESHOLDS", "0.15,0.20,0.25"), ",")[[1]])
ROOT <- here::here()
MODELS_DIR <- file.path(ROOT, "output", "ddm_refits", "runs", RUN_ID, "models")
TABLES_DIR <- file.path(ROOT, "output", "ddm_refits", "runs", RUN_ID, "tables")
dir.create(TABLES_DIR, recursive = TRUE, showWarnings = FALSE)

H1_VAR <- "b_effort_conditionhigh"
H2_VAR <- "b_bs_effort_conditionhigh"

draws_matrix <- function(fit) {
  samples <- fit$fit@sim$samples
  if (is.null(samples) || !length(samples)) {
    stop("No posterior samples found in fit object.")
  }
  do.call(rbind, lapply(samples, as.matrix))
}

max_rhat_from_samples <- function(samples) {
  if (!requireNamespace("posterior", quietly = TRUE)) {
    return(NA_real_)
  }
  n_chains <- length(samples)
  n_iter <- nrow(samples[[1L]])
  n_params <- ncol(samples[[1L]])
  arr <- array(
    NA_real_,
    dim = c(n_iter, n_chains, n_params),
    dimnames = list(NULL, NULL, colnames(samples[[1L]]))
  )
  for (i in seq_len(n_chains)) {
    arr[, i, ] <- as.matrix(samples[[i]])
  }
  rh <- posterior::rhat(arr)
  max(as.numeric(rh), na.rm = TRUE)
}

summarize_draw <- function(x) {
  c(
    Estimate = mean(x),
    Q2.5 = unname(quantile(x, 0.025)),
    Q97.5 = unname(quantile(x, 0.975))
  )
}

extract_contrast <- function(fit, threshold) {
  mat <- draws_matrix(fit)
  if (!H1_VAR %in% colnames(mat) || !H2_VAR %in% colnames(mat)) {
    stop(
      "Expected effort terms not found for threshold ", threshold,
      ". Available: ", paste(grep("effort", colnames(mat), value = TRUE), collapse = ", ")
    )
  }
  h1 <- summarize_draw(mat[, H1_VAR])
  h2 <- summarize_draw(mat[, H2_VAR])
  dat <- fit$data
  tibble(
    threshold = threshold,
    n_trials = nrow(dat),
    n_subjects = n_distinct(dat$subject_id),
    h1_beta = h1["Estimate"],
    h1_q2.5 = h1["Q2.5"],
    h1_q97.5 = h1["Q97.5"],
    h2_beta = h2["Estimate"],
    h2_q2.5 = h2["Q2.5"],
    h2_q97.5 = h2["Q97.5"],
    max_rhat = max_rhat_from_samples(fit$fit@sim$samples)
  )
}

rows <- list()
for (thr in THRESHOLDS) {
  thr_tag <- formatC(thr, format = "f", digits = 2)
  path <- file.path(MODELS_DIR, paste0("additive__probe_onset_locked__thr", thr_tag, ".rds"))
  if (!file.exists(path)) {
    message("Missing model for threshold ", thr, ": ", path)
    next
  }
  message("Extracting contrasts from ", basename(path))
  rows[[length(rows) + 1L]] <- extract_contrast(readRDS(path), thr)
}

if (length(rows) == 0) {
  stop("No additive models found. Run scripts/fit_sensitivity_additive_thresholds.R first.")
}

out <- bind_rows(rows) %>% arrange(threshold)
out_path <- file.path(TABLES_DIR, "h1_h2_contrasts_by_cutoff.csv")
write_csv(out, out_path)
cat("Wrote:", out_path, "\n")
print(out)
