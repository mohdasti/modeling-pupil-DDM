#!/usr/bin/env Rscript
# ==============================================================================
# Fit Cavanagh-style pupil → boundary separation (bs) model
# ==============================================================================
# One trial-wise pupil predictor on log boundary (bs); drift and bias match m0.
# Same pupil-available trial subset as the nested pupil-DDM sequence.
#
# Usage (primary Decision-Response AUC):
#   PUPIL_OUTPUT_BASE=output/ddm_pupil_boundary \
#   PUPIL_Z_COL=pupil_metric_primary_z \
#   Rscript scripts/fit_pupil_boundary_model.R
#
# Truncated window:
#   PUPIL_OUTPUT_BASE=output/ddm_pupil_boundary_w1p3 \
#   PUPIL_Z_COL=pupil_w1p3_z \
#   Rscript scripts/fit_pupil_boundary_model.R
# ==============================================================================

suppressPackageStartupMessages({
  library(brms)
  library(cmdstanr)
  library(dplyr)
  library(readr)
  library(here)
})

OUTPUT_BASE <- here::here(Sys.getenv("PUPIL_OUTPUT_BASE", "output/ddm_pupil_boundary"))
PUPIL_Z_COL <- Sys.getenv("PUPIL_Z_COL", "pupil_metric_primary_z")
PUPIL_METRIC_LABEL <- Sys.getenv("PUPIL_METRIC_LABEL", PUPIL_Z_COL)
DATA_FILE <- Sys.getenv(
  "PUPIL_DATA_FILE",
  here::here("output", "ddm_pupil", "ddm_pupil_ready_thr0.20_probe_onset_locked.csv")
)
MODELS_DIR <- file.path(OUTPUT_BASE, "models")
TABLES_DIR <- file.path(OUTPUT_BASE, "tables")
LOG_DIR <- file.path(OUTPUT_BASE, "logs")
for (d in c(MODELS_DIR, TABLES_DIR, LOG_DIR)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

LOG_FILE <- file.path(LOG_DIR, "fit_pupil_boundary_model.log")
log_con <- file(LOG_FILE, open = "wt")
on.exit(close(log_con), add = TRUE)

log_msg <- function(..., level = "INFO") {
  line <- sprintf("[%s] [%s] %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), level, paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = log_con)
  flush(log_con)
}

N_CHAINS <- 4L
N_ITER <- 2000L
N_WARMUP <- 1000L
ADAPT_DELTA <- 0.95
MAX_TREEDEPTH <- 12L

log_msg(strrep("=", 80))
log_msg("FIT PUPIL → BOUNDARY (Cavanagh-style)")
log_msg("OUTPUT:", OUTPUT_BASE, "| z_col:", PUPIL_Z_COL, "| data:", DATA_FILE)

if (!file.exists(DATA_FILE)) stop("Missing data: ", DATA_FILE)
if (!PUPIL_Z_COL %in% names(read_csv(DATA_FILE, n_max = 1, show_col_types = FALSE))) {
  stop("Missing pupil column: ", PUPIL_Z_COL)
}

ddm_data <- read_csv(DATA_FILE, show_col_types = FALSE)
model_data <- ddm_data %>%
  mutate(
    subject_id = as.character(subject_id),
    task = factor(task_std, levels = c("ADT", "VDT")),
    difficulty_3 = factor(difficulty_level, levels = c("Standard", "Hard", "Easy")),
    effort_condition = factor(effort_condition, levels = c("Low", "High")),
    dec_upper = as.integer(choice_binary),
    rt = rt_primary,
    pupil_z = .data[[PUPIL_Z_COL]]
  ) %>%
  filter(!is.na(rt), !is.na(dec_upper), rt > 0, !is.na(pupil_z))

log_msg("Trials with valid pupil:", nrow(model_data), "| Subjects:", n_distinct(model_data$subject_id))

min_rt <- min(model_data$rt, na.rm = TRUE)
ndt_ub <- log(min_rt - 0.02)

formula_m1p <- bf(
  rt | dec(dec_upper) ~ difficulty_3 + effort_condition + (1 | subject_id),
  bs ~ difficulty_3 + effort_condition + pupil_z,
  ndt ~ 1,
  bias ~ task + effort_condition + (1 | subject_id)
)

priors <- c(
  prior(normal(0, 1), class = "Intercept"),
  prior(normal(0, 0.5), class = "b"),
  prior(normal(log(1.3), 0.25), class = "Intercept", dpar = "bs", lb = log(0.3), ub = log(5)),
  prior(normal(0, 0.20), class = "b", dpar = "bs"),
  prior(normal(0, 0.20), class = "b", dpar = "bs", coef = "pupil_z"),
  prior(normal(log(0.35), 0.15), class = "Intercept", dpar = "ndt", lb = log(0.02), ub = ndt_ub),
  prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
  prior(normal(0, 0.5), class = "b", dpar = "bias"),
  prior(exponential(5), class = "sd"),
  prior(exponential(5), class = "sd", dpar = "bias")
)

log_msg("Fitting model_1p_pupil_boundary ...")
t0 <- Sys.time()
fit <- brm(
  formula = formula_m1p,
  data = model_data,
  family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
  prior = priors,
  chains = N_CHAINS,
  iter = N_ITER,
  warmup = N_WARMUP,
  cores = N_CHAINS,
  backend = "cmdstanr",
  control = list(adapt_delta = ADAPT_DELTA, max_treedepth = MAX_TREEDEPTH),
  seed = 12345,
  file = file.path(MODELS_DIR, "model_1p_pupil_boundary"),
  file_refit = Sys.getenv("PUPIL_REFIT", "on_change")
)
mins <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)
log_msg("Done in", mins, "min | max Rhat:", sprintf("%.4f", max(brms::rhat(fit), na.rm = TRUE)))

write_csv(
  tibble(
    model_name = "model_1p_pupil_boundary",
    n_trials = nrow(model_data),
    n_subjects = n_distinct(model_data$subject_id),
    runtime_min = mins,
    pupil_z_col = PUPIL_Z_COL,
    metric_label = PUPIL_METRIC_LABEL
  ),
  file.path(TABLES_DIR, "model_info.csv")
)
log_msg("Saved:", file.path(MODELS_DIR, "model_1p_pupil_boundary.rds"))
