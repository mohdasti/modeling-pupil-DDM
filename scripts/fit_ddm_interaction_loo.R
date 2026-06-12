#!/usr/bin/env Rscript
# Fit difficulty × effort interaction DDM and compare to additive via PSIS-LOO.
#
# Usage:
#   DDM_RUN_ID=20260226_092110 Rscript scripts/fit_ddm_interaction_loo.R
#
# Outputs:
#   output/ddm_refits/runs/<RUN_ID>/models/interaction__probe_onset_locked__thr0.20.rds
#   output/ddm_refits/runs/<RUN_ID>/loo/loo_interaction_primary_thr.rds
#   output/ddm_refits/runs/<RUN_ID>/loo/loo_interaction_compare.rds
#   output/ddm_refits/runs/<RUN_ID>/tables/interaction_loo_summary.csv
#   output/ddm_refits/runs/<RUN_ID>/tables/interaction_key_terms.csv

suppressPackageStartupMessages({
  library(brms)
  library(cmdstanr)
  library(dplyr)
  library(readr)
  library(here)
  library(tibble)
})

RUN_ID <- Sys.getenv("DDM_RUN_ID", "20260226_092110")
THRESHOLD <- as.numeric(Sys.getenv("DDM_THRESHOLD", "0.20"))
ROOT <- here::here()
RUN_DIR <- file.path(ROOT, "output", "ddm_refits", "runs", RUN_ID)
MODELS_DIR <- file.path(RUN_DIR, "models")
LOO_DIR <- file.path(RUN_DIR, "loo")
TABLES_DIR <- file.path(RUN_DIR, "tables")
LOG_DIR <- file.path(RUN_DIR, "logs")
dir.create(MODELS_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(LOO_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(TABLES_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)

LOG_FILE <- file.path(LOG_DIR, "fit_interaction.log")
log_msg <- function(...) {
  line <- paste0("[", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "] ", paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = LOG_FILE, append = TRUE)
}

thr_tag <- formatC(THRESHOLD, format = "f", digits = 2)
additive_path <- file.path(MODELS_DIR, paste0("additive__probe_onset_locked__thr", thr_tag, ".rds"))
out_path <- file.path(MODELS_DIR, paste0("interaction__probe_onset_locked__thr", thr_tag, ".rds"))
loo_int_path <- file.path(LOO_DIR, "loo_interaction_primary_thr.rds")
loo_cmp_path <- file.path(LOO_DIR, "loo_interaction_compare.rds")
loo_add_path <- file.path(LOO_DIR, "loo_additive_primary_thr.rds")
summary_path <- file.path(TABLES_DIR, "interaction_loo_summary.csv")
terms_path <- file.path(TABLES_DIR, "interaction_key_terms.csv")

if (!file.exists(additive_path)) {
  hits <- list.files(MODELS_DIR, pattern = "^additive__probe_onset_locked__thr.*\\.rds$", full.names = TRUE)
  if (length(hits) > 0) additive_path <- hits[1]
}

log_msg("RUN_ID=", RUN_ID, "| threshold=", THRESHOLD)

if (file.exists(summary_path) && file.exists(loo_cmp_path) &&
    Sys.getenv("PUPIL_REFIT", "on_change") != "always") {
  log_msg("Interaction LOO outputs exist; skipping.")
  quit(save = "no", status = 0)
}

if (!file.exists(additive_path)) stop("Additive model not found under ", MODELS_DIR)

additive_fit <- readRDS(additive_path)
model_data <- as.data.frame(additive_fit$data)
rt_vec <- if ("rt" %in% names(model_data)) model_data$rt else model_data$rt_model
model_data$rt <- rt_vec
model_data <- model_data %>%
  filter(!is.na(rt), !is.na(choice_binary), rt > 0) %>%
  mutate(
    subject_id = as.character(subject_id),
    choice_binary = as.integer(choice_binary),
    difficulty_3 = factor(difficulty_3, levels = c("Standard", "Hard", "Easy")),
    task = factor(task, levels = c("ADT", "VDT")),
    effort_condition = factor(tolower(as.character(effort_condition)), levels = c("low", "high"))
  )

min_rt <- min(model_data$rt, na.rm = TRUE)
ndt_ub_val <- as.numeric(min_rt - 0.01)
if (!is.finite(ndt_ub_val) || ndt_ub_val <= 0.05) {
  stop("Invalid ndt upper bound: ", ndt_ub_val)
}
ndt_ub <- as.numeric(log(ndt_ub_val))
log_msg("N=", nrow(model_data), " min_rt=", round(min_rt, 4))

formula_interaction <- bf(
  rt | dec(choice_binary) ~ 1 + effort_condition * difficulty_3 + (1 | subject_id),
  bs ~ 1 + effort_condition * difficulty_3 + (1 | subject_id),
  ndt ~ 1,
  bias ~ task + effort_condition + (1 | subject_id)
)

priors <- c(
  prior(normal(0, 1), class = "Intercept"),
  prior(normal(0, 0.5), class = "b"),
  prior(normal(log(1.3), 0.25), class = "Intercept", dpar = "bs", lb = log(0.3), ub = log(5)),
  prior(normal(0, 0.20), class = "b", dpar = "bs"),
  eval(substitute(
    prior(normal(log(0.35), 0.15), class = "Intercept", dpar = "ndt", lb = log(0.02), ub = UB_VAL),
    list(UB_VAL = ndt_ub)
  )),
  prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
  prior(normal(0, 0.5), class = "b", dpar = "bias"),
  prior(exponential(5), class = "sd"),
  prior(exponential(10), class = "sd", dpar = "bs"),
  prior(exponential(5), class = "sd", dpar = "bias")
)

safe_init <- function(chain_id = 1) {
  list(
    Intercept = 0,
    Intercept_bs = log(1.3),
    Intercept_ndt = log(0.30),
    Intercept_bias = 0,
    sd_subject_id__Intercept = 0.1,
    sd_subject_id__bs_Intercept = 0.1,
    sd_subject_id__bias_Intercept = 0.1
  )
}

log_msg("Starting brm() interaction model ...")
t0 <- Sys.time()
fit <- brm(
  formula = formula_interaction,
  data = model_data,
  family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
  prior = priors,
  chains = 4L,
  iter = 2000L,
  warmup = 1000L,
  cores = 4L,
  init = safe_init,
  control = list(adapt_delta = 0.95, max_treedepth = 12L),
  backend = "cmdstanr",
  file = out_path,
  file_refit = Sys.getenv("PUPIL_REFIT", "on_change"),
  refresh = 100,
  silent = 0
)
log_msg("Fit done in", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1),
        "min | max Rhat=", round(max(rhat(fit), na.rm = TRUE), 4))

fx <- fixef(fit)
int_terms <- fx[grepl("effort_conditionhigh:difficulty_3", rownames(fx)), , drop = FALSE]
if (nrow(int_terms) > 0) {
  int_tbl <- tibble::tibble(
    term = rownames(int_terms),
    dpar = ifelse(grepl("^bs_", rownames(int_terms)), "bs", "v"),
    Estimate = int_terms[, "Estimate"],
    Q2.5 = int_terms[, "Q2.5"],
    Q97.5 = int_terms[, "Q97.5"]
  )
  write_csv(int_tbl, terms_path)
  log_msg("Saved interaction terms:", terms_path)
}

log_msg("Computing LOO ...")
loo_int <- loo(fit)
saveRDS(loo_int, loo_int_path)

if (file.exists(loo_add_path)) {
  loo_add <- readRDS(loo_add_path)
} else {
  loo_add <- loo(additive_fit)
  saveRDS(loo_add, loo_add_path)
}

cmp <- loo_compare(loo_add, loo_int)
saveRDS(cmp, loo_cmp_path)
log_msg("Delta ELPD (interaction vs additive):", round(cmp[2, "elpd_diff"], 2),
        " SE:", round(cmp[2, "se_diff"], 2))

write_csv(
  tibble::tibble(
    comparison = "interaction_vs_additive",
    delta_elpd = cmp[2, "elpd_diff"],
    se_diff = cmp[2, "se_diff"],
    elpd_additive = loo_add$estimates["elpd_loo", "Estimate"],
    elpd_interaction = loo_int$estimates["elpd_loo", "Estimate"],
    pareto_k_additive = max(loo_add$diagnostics$pareto_k, na.rm = TRUE),
    pareto_k_interaction = max(loo_int$diagnostics$pareto_k, na.rm = TRUE),
    max_rhat_interaction = max(rhat(fit), na.rm = TRUE)
  ),
  summary_path
)
log_msg("Done.")
