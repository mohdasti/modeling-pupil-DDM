#!/usr/bin/env Rscript
# Postprocess Cavanagh-style pupil → boundary model: LOO + key coefficient on bs.

suppressPackageStartupMessages({
  library(brms)
  library(dplyr)
  library(readr)
  library(here)
  library(posterior)
})

OUTPUT_BASE <- here::here(Sys.getenv("PUPIL_OUTPUT_BASE", "output/ddm_pupil_boundary"))
MODELS_DIR <- file.path(OUTPUT_BASE, "models")
TABLES_DIR <- file.path(OUTPUT_BASE, "tables")
dir.create(TABLES_DIR, recursive = TRUE, showWarnings = FALSE)

model_path <- file.path(MODELS_DIR, "model_1p_pupil_boundary.rds")
if (!file.exists(model_path)) stop("Missing model: ", model_path)

fit <- readRDS(model_path)
n_trials <- nrow(fit$data)

loo_obj <- loo(fit)
n_high_k <- sum(loo_obj$diagnostics$pareto_k > 0.7, na.rm = TRUE)

# Baseline ELPD from sibling pupil run (same metric / window)
baseline_base <- Sys.getenv("PUPIL_BASELINE_LOO_DIR", "output/ddm_pupil")
if (!grepl("^/", baseline_base)) baseline_base <- here::here(baseline_base)
baseline_loo_path <- file.path(baseline_base, "tables", "pupil_loo_summary.csv")
baseline_elpd <- NA_real_
if (file.exists(baseline_loo_path)) {
  bl <- read_csv(baseline_loo_path, show_col_types = FALSE)
  baseline_elpd <- bl$elpd_loo[bl$model_name == "model_0_behavioral"][1]
}

loo_row <- tibble(
  model_name = "model_1p_pupil_boundary",
  n_trials = n_trials,
  elpd_loo = loo_obj$estimates["elpd_loo", "Estimate"],
  se_elpd_loo = loo_obj$estimates["elpd_loo", "SE"],
  looic = -2 * loo_obj$estimates["elpd_loo", "Estimate"],
  looic_se = 2 * loo_obj$estimates["elpd_loo", "SE"],
  pareto_k_max = max(loo_obj$diagnostics$pareto_k, na.rm = TRUE),
  n_pareto_k_gt_0.7 = n_high_k,
  loo_reliable = n_high_k == 0,
  delta_elpd_vs_m0 = if (is.finite(baseline_elpd)) elpd_loo - baseline_elpd else NA_real_,
  loo_note = "Cavanagh-style pupil on bs; compare delta to model_0 in matching pupil_loo_summary."
)

write_csv(loo_row, file.path(TABLES_DIR, "pupil_boundary_loo_summary.csv"))

fx <- fixef(fit, dpar = "bs")
term <- grep("pupil", rownames(fx), value = TRUE)[1]
if (is.na(term)) stop("No pupil term on bs in fixef")
key <- tibble(
  model = "model_1p_pupil_boundary",
  dpar = "bs",
  term = term,
  Estimate = fx[term, "Estimate"],
  Q2.5 = fx[term, "Q2.5"],
  Q97.5 = fx[term, "Q97.5"]
)
write_csv(key, file.path(TABLES_DIR, "pupil_boundary_key_terms.csv"))

message("Wrote ", file.path(TABLES_DIR, "pupil_boundary_loo_summary.csv"))
message("Pupil→bs: ", sprintf("beta=%.3f [%.3f, %.3f]", key$Estimate, key$Q2.5, key$Q97.5))
message("Delta ELPD vs m0: ", round(loo_row$delta_elpd_vs_m0, 2))
