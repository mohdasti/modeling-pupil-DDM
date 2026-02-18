#!/usr/bin/env Rscript
# =========================================================================
# EXTRACT standard_only_bias_fixef_link_scale.csv FROM RUN_DIR
# =========================================================================
# The main DDM refit pipeline writes this file when it runs standard-only
# models. If run_dir was created by an older pipeline or the export was
# skipped, this script regenerates it from the standard_only model RDS.
#
# Usage: Rscript scripts/extract_standard_only_fixef_from_run.R [run_dir]
# Default run_dir: output/ddm_refits/runs/20260214_045745
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(dplyr)
  library(readr)
})

args <- commandArgs(trailingOnly = TRUE)
run_dir <- if (length(args) > 0) args[1] else "output/ddm_refits/runs/20260214_045745"
models_dir <- file.path(run_dir, "models")
tables_dir <- file.path(run_dir, "tables")

if (!dir.exists(models_dir)) {
  stop("Models directory not found: ", models_dir)
}
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

# Find standard_only probe_onset_locked thr0.20 model (primary)
pattern <- "standard_only__probe_onset_locked__thr0\\.20\\.rds"
candidates <- list.files(models_dir, pattern = pattern, full.names = TRUE)
if (length(candidates) == 0) {
  pattern2 <- "standard_only.*probe_onset.*0\\.20"
  candidates <- list.files(models_dir, pattern = pattern2, full.names = TRUE)
}
if (length(candidates) == 0) {
  stop("No standard_only probe_onset_locked thr0.20 model found in ", models_dir)
}
model_path <- candidates[1]
cat("Loading:", model_path, "\n")

fit <- readRDS(model_path)
fx <- brms::fixef(fit)
df <- as_tibble(fx, rownames = "raw_term")

# Map to dpar and term (same logic as ddm_refit pipeline)
df <- df %>%
  mutate(
    dpar = case_when(
      startsWith(raw_term, "bs_") ~ "bs",
      startsWith(raw_term, "ndt_") ~ "ndt",
      startsWith(raw_term, "bias_") ~ "bias",
      TRUE ~ "v"
    ),
    term = case_when(
      startsWith(raw_term, "bs_") ~ sub("^bs_", "", raw_term),
      startsWith(raw_term, "ndt_") ~ sub("^ndt_", "", raw_term),
      startsWith(raw_term, "bias_") ~ sub("^bias_", "", raw_term),
      TRUE ~ raw_term
    )
  ) %>%
  select(dpar, term, raw_term, Estimate, Est.Error, Q2.5, Q97.5) %>%
  mutate(
    model = "standard_only",
    rt_type = "probe_onset_locked",
    threshold = 0.20,
    n_trials = NA_integer_
  )

out_path <- file.path(tables_dir, "standard_only_bias_fixef_link_scale.csv")
write_csv(df, out_path)
cat("✓ Wrote:", out_path, "\n")
cat("  Rows:", nrow(df), "| Drift Intercept (dpar=v, term=Intercept):",
    nrow(df %>% filter(dpar == "v", term == "Intercept")), "\n")
