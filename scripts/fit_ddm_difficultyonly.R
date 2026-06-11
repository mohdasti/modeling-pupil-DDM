#!/usr/bin/env Rscript
# Fit difficulty-only DDM (no effort on v or bs) for Appendix A1 LOO table row.
#
# Usage:
#   DDM_RUN_ID=20260226_092110 Rscript scripts/fit_ddm_difficultyonly.R
#
# Output:
#   output/ddm_refits/runs/<RUN_ID>/loo/loo_difficultyonly_primary_thr.rds
#   output/ddm_refits/runs/<RUN_ID>/models/difficultyonly__probe_onset_locked__thr0.20.rds

suppressPackageStartupMessages({
  library(brms)
  library(cmdstanr)
  library(dplyr)
  library(readr)
  library(here)
})

RUN_ID <- Sys.getenv("DDM_RUN_ID", "20260226_092110")
THRESHOLD <- as.numeric(Sys.getenv("DDM_THRESHOLD", "0.20"))
ROOT <- here::here()
RUN_DIR <- file.path(ROOT, "output", "ddm_refits", "runs", RUN_ID)
MODELS_DIR <- file.path(RUN_DIR, "models")
LOO_DIR <- file.path(RUN_DIR, "loo")
LOG_DIR <- file.path(RUN_DIR, "logs")
dir.create(MODELS_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(LOO_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)

LOG_FILE <- file.path(LOG_DIR, "fit_difficultyonly.log")
log_msg <- function(...) {
  line <- paste0("[", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "] ", paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = LOG_FILE, append = TRUE)
}

thr_tag <- formatC(THRESHOLD, format = "f", digits = 2)
additive_path <- file.path(MODELS_DIR, paste0("additive__probe_onset_locked__thr", thr_tag, ".rds"))
out_path <- file.path(MODELS_DIR, paste0("difficultyonly__probe_onset_locked__thr", thr_tag, ".rds"))
loo_path <- file.path(LOO_DIR, "loo_difficultyonly_primary_thr.rds")

if (!file.exists(additive_path)) {
  hits <- list.files(MODELS_DIR, pattern = "^additive__probe_onset_locked__thr.*\\.rds$", full.names = TRUE)
  if (length(hits) > 0) additive_path <- hits[1]
}

log_msg("RUN_ID=", RUN_ID, "| threshold=", THRESHOLD)
log_msg("cmdstan path:", tryCatch(cmdstanr::cmdstan_path(), error = function(e) paste("ERROR:", e$message)))

if (file.exists(out_path) && file.exists(loo_path) && Sys.getenv("PUPIL_REFIT", "on_change") != "always") {
  log_msg("Model and LOO exist; skipping fit.")
  quit(save = "no", status = 0)
}

if (!file.exists(additive_path)) {
  stop("Additive model not found under ", MODELS_DIR)
}

log_msg("Loading trial data from:", additive_path)
additive_fit <- readRDS(additive_path)
model_data <- as.data.frame(additive_fit$data)

required <- c("choice_binary", "difficulty_3", "task", "effort_condition", "subject_id")
missing <- setdiff(required, names(model_data))
if (length(missing) > 0) {
  stop("Additive fit$data missing columns: ", paste(missing, collapse = ", "))
}

if ("rt" %in% names(model_data)) {
  rt_vec <- model_data$rt
} else if ("rt_model" %in% names(model_data)) {
  rt_vec <- model_data$rt_model
} else {
  stop("No rt or rt_model column in additive fit$data")
}

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
  stop("Invalid ndt upper bound: ", ndt_ub_val, " (min_rt=", min_rt, ")")
}
ndt_ub <- as.numeric(log(ndt_ub_val))
log_msg("N=", nrow(model_data), " subjects=", n_distinct(model_data$subject_id),
        " min_rt=", round(min_rt, 4), " ndt_ub=", round(ndt_ub_val, 4))

formula_diffonly <- bf(
  rt | dec(choice_binary) ~ 1 + difficulty_3 + (1 | subject_id),
  bs ~ 1 + difficulty_3 + (1 | subject_id),
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

if (tolower(Sys.getenv("CLEAN_STAN_CACHE", "false")) %in% c("1", "true", "yes")) {
  stale <- list.files(MODELS_DIR, pattern = "^difficultyonly__probe_onset_locked", full.names = TRUE)
  if (length(stale) > 0) {
    log_msg("Removing stale difficultyonly cache files:", length(stale))
    unlink(stale)
  }
}

log_msg("Starting brm() ...")
t0 <- Sys.time()
fit <- tryCatch(
  brm(
    formula = formula_diffonly,
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
  ),
  error = function(e) {
    log_msg("brm() FAILED:", conditionMessage(e))
    stop(conditionMessage(e))
  }
)
mins <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)
log_msg("Fit done in", mins, "min | max Rhat=", round(max(rhat(fit), na.rm = TRUE), 4))

log_msg("Computing LOO ...")
loo_obj <- loo(fit)
saveRDS(loo_obj, loo_path)
log_msg("Saved LOO:", loo_path)

loo_add <- loo(additive_fit)
cmp <- loo_compare(loo_add, loo_obj)
log_msg("Delta ELPD (additive vs difficulty-only):", round(cmp[2, "elpd_diff"], 2))
