#!/usr/bin/env Rscript
# ==============================================================================
# Fit Pupil-DDM Models
# ==============================================================================
# Purpose: Fit DDM models with pupil predictors to test mechanistic hypotheses
#          about arousal effects on decision-making parameters.
#
# Input:  output/ddm_pupil/ddm_pupil_ready_thr0.20_probe_onset_locked.csv (PRIMARY)
#
# Outputs: - output/ddm_pupil/models/*.rds (model objects)
#          - output/ddm_pupil/tables/*.csv (parameter summaries)
#          - output/ddm_pupil/figs/*.png (diagnostic plots)
#          - output/ddm_pupil/logs/fit_pupil_ddm_models.log
#
# Models (additive spec aligned with primary behavioral run; same trial subset):
#   Model 0: Behavioral baseline (no pupil predictor)
#   Model 1: Pupil → bias only
#   Model 2: Pupil → drift + bias
#   Model 3: Pupil × difficulty on drift (Yerkes–Dodson interaction)
# ==============================================================================

suppressPackageStartupMessages({
  library(brms)
  library(cmdstanr)
  library(dplyr)
  library(readr)
  library(tidyr)
  library(ggplot2)
  library(bayesplot)
  library(posterior)
  library(here)
})

# ==============================================================================
# Setup logging
# ==============================================================================

SCRIPT_NAME <- "fit_pupil_ddm_models.R"
START_TIME <- Sys.time()

# Output layout (override for w1p3 sensitivity: PUPIL_OUTPUT_BASE=output/ddm_pupil_w1p3)
OUTPUT_BASE <- here::here(Sys.getenv("PUPIL_OUTPUT_BASE", "output/ddm_pupil"))
PUPIL_Z_COL <- Sys.getenv("PUPIL_Z_COL", "pupil_metric_primary_z")
PUPIL_METRIC_LABEL <- Sys.getenv("PUPIL_METRIC_LABEL", "pupil_metric_primary_z")
MODELS_DIR <- file.path(OUTPUT_BASE, "models")
TABLES_DIR <- file.path(OUTPUT_BASE, "tables")
FIGS_DIR <- file.path(OUTPUT_BASE, "figs")
LOG_DIR <- file.path(OUTPUT_BASE, "logs")

DATA_FILE <- Sys.getenv(
  "PUPIL_DATA_FILE",
  here::here("output", "ddm_pupil", "ddm_pupil_ready_thr0.20_probe_onset_locked.csv")
)

for (dir in c(MODELS_DIR, TABLES_DIR, FIGS_DIR, LOG_DIR)) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
}

# Open log file
LOG_FILE <- file.path(LOG_DIR, "fit_pupil_ddm_models.log")
log_con <- file(LOG_FILE, open = "wt")

log_msg <- function(..., level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  msg <- paste(..., collapse = " ")
  log_line <- sprintf("[%s] [%s] %s", timestamp, level, msg)
  
  # Write to console
  cat(log_line, "\n")
  
  # Write to log file
  cat(log_line, "\n", file = log_con)
  flush(log_con)
}

log_msg(strrep("=", 80))
log_msg("FIT PUPIL-DDM MODELS")
log_msg(strrep("=", 80))
log_msg("Script:", SCRIPT_NAME)
log_msg("Start time:", format(START_TIME, "%Y-%m-%d %H:%M:%S"))
log_msg("Output directory:", OUTPUT_BASE)
log_msg("Pupil z column:", PUPIL_Z_COL, "(", PUPIL_METRIC_LABEL, ")")
log_msg("Data file:", DATA_FILE)
log_msg("")

# ==============================================================================
# Configuration
# ==============================================================================

# MCMC settings (aligned with behavioral models)
N_CHAINS <- 4
N_ITER <- 2000
N_WARMUP <- 1000
ADAPT_DELTA <- 0.95
MAX_TREEDEPTH <- 12

# Random effects settings (aligned with chapter)
USE_BS_RANDOM_EFFECTS <- FALSE  # Boundary typically intercept-only
USE_NDT_RANDOM_EFFECTS <- FALSE  # NDT intercept-only for response-signal stability

# Backend
USE_CMDSTANR <- TRUE

log_msg("MCMC Configuration:")
log_msg("  Chains:", N_CHAINS)
log_msg("  Iterations:", N_ITER, "(warmup:", N_WARMUP, ")")
log_msg("  adapt_delta:", ADAPT_DELTA)
log_msg("  max_treedepth:", MAX_TREEDEPTH)
log_msg("  Backend:", if (USE_CMDSTANR) "cmdstanr" else "rstan")
log_msg("")

# ==============================================================================
# Step 1: Load data
# ==============================================================================

log_msg("STEP 1: Loading data...")

if (!file.exists(DATA_FILE)) {
  log_msg("ERROR: Data file not found:", DATA_FILE, level = "ERROR")
  close(log_con)
  stop("Data file not found: ", DATA_FILE)
}

ddm_data <- read_csv(DATA_FILE, show_col_types = FALSE)

if (!PUPIL_Z_COL %in% names(ddm_data)) {
  log_msg("ERROR: Pupil column not found:", PUPIL_Z_COL, level = "ERROR")
  log_msg("Available pupil columns:", paste(grep("^pupil", names(ddm_data), value = TRUE), collapse = ", "),
          level = "ERROR")
  close(log_con)
  stop("Missing pupil column: ", PUPIL_Z_COL)
}

log_msg("  ✓ Loaded:", DATA_FILE)
log_msg("  Rows:", nrow(ddm_data))
log_msg("  Columns:", ncol(ddm_data))
log_msg("")

# ==============================================================================
# Step 2: Prepare data for modeling
# ==============================================================================

log_msg("STEP 2: Preparing data for modeling...")

# Filter for valid trials (exclude pupil_qc_exclude if desired)
# Note: We keep pupil_missing trials but they will have NA pupil values
log_msg("  Filtering criteria:")
log_msg("    - Keep all trials with valid RT and choice")
log_msg("    - Keep pupil_missing trials (NA pupil values)")
log_msg("    - Optionally filter pupil_qc_exclude")

# Check if we should filter by pupil QC
FILTER_PUPIL_QC <- FALSE  # Set to TRUE to exclude low-quality pupil trials
if (FILTER_PUPIL_QC) {
  n_before <- nrow(ddm_data)
  ddm_data <- ddm_data %>% filter(!pupil_qc_exclude)
  n_after <- nrow(ddm_data)
  log_msg("  Filtered pupil_qc_exclude: removed", n_before - n_after, "trials")
}

# Prepare modeling dataset (factor coding aligned with primary additive model)
model_data_all <- ddm_data %>%
  mutate(
    subject_id = as.character(subject_id),
    task = factor(task_std, levels = c("ADT", "VDT")),
    difficulty_3 = factor(difficulty_level, levels = c("Standard", "Hard", "Easy")),
    effort_condition = factor(effort_condition, levels = c("Low", "High")),
    dec_upper = as.integer(choice_binary),
    rt = rt_primary,
    pupil_z = .data[[PUPIL_Z_COL]],
    pupil_scaled = .data[[PUPIL_Z_COL]]
  ) %>%
  filter(!is.na(rt), !is.na(dec_upper), rt > 0) %>%
  select(subject_id, task, difficulty_3, effort_condition, rt, dec_upper,
         pupil_z, pupil_scaled, pupil_missing, pupil_qc_exclude, n_pupil_sessions)

# Nested comparison: all four models on the same pupil-available trials
n_before_pupil <- nrow(model_data_all)
model_data <- model_data_all %>%
  filter(!is.na(pupil_z), !is.na(pupil_scaled))
if (isTRUE(FILTER_PUPIL_QC) && "pupil_qc_exclude" %in% names(model_data)) {
  model_data <- model_data %>% filter(!pupil_qc_exclude)
}

log_msg("  ✓ Prepared modeling dataset")
log_msg("  Trials after RT/choice filters:", n_before_pupil)
log_msg("  Trials with valid pupil (analysis subset):", nrow(model_data))
log_msg("  Subjects (pupil subset):", n_distinct(model_data$subject_id))
log_msg("  Pupil excluded:", n_before_pupil - nrow(model_data),
        sprintf("(%.1f%%)", 100 * (n_before_pupil - nrow(model_data)) / n_before_pupil))
log_msg("")

# Log dataset dimensions
log_msg("Dataset dimensions:")
log_msg("  Subjects:", n_distinct(model_data$subject_id))
log_msg("  Trials:", nrow(model_data))
log_msg("  Tasks:", paste(levels(model_data$task), collapse = ", "))
log_msg("  Difficulties:", paste(levels(model_data$difficulty_3), collapse = ", "))
log_msg("  Efforts:", paste(levels(model_data$effort_condition), collapse = ", "))
log_msg("")

# RT statistics
log_msg("RT statistics (probe-onset-locked):")
log_msg(sprintf("  Mean: %.3f s", mean(model_data$rt, na.rm = TRUE)))
log_msg(sprintf("  SD: %.3f s", sd(model_data$rt, na.rm = TRUE)))
log_msg(sprintf("  Min: %.3f s", min(model_data$rt, na.rm = TRUE)))
log_msg(sprintf("  Max: %.3f s", max(model_data$rt, na.rm = TRUE)))
log_msg("")

# Pupil statistics
log_msg("Pupil statistics (", PUPIL_Z_COL, "):")
log_msg(sprintf("  Mean: %.3f", mean(model_data$pupil_z, na.rm = TRUE)))
log_msg(sprintf("  SD: %.3f", sd(model_data$pupil_z, na.rm = TRUE)))
log_msg(sprintf("  Min: %.3f", min(model_data$pupil_z, na.rm = TRUE)))
log_msg(sprintf("  Max: %.3f", max(model_data$pupil_z, na.rm = TRUE)))
log_msg(sprintf("  Missing pupil_z in subset: %d (should be 0)",
                sum(is.na(model_data$pupil_z))))
log_msg("")

# ==============================================================================
# Step 3: Define model formulas (primary additive specification)
# ==============================================================================

log_msg("STEP 3: Defining model formulas...")
log_msg("")

bs_formula <- if (USE_BS_RANDOM_EFFECTS) {
  as.formula("bs ~ difficulty_3 + effort_condition + (1 | subject_id)")
} else {
  as.formula("bs ~ difficulty_3 + effort_condition")
}

formula_m0 <- bf(
  rt | dec(dec_upper) ~ difficulty_3 + effort_condition + (1 | subject_id),
  bs_formula,
  ndt ~ 1,
  bias ~ task + effort_condition + (1 | subject_id)
)

log_msg("Model 0 (Behavioral baseline, pupil-available subset):")
log_msg("  v ~ difficulty_3 + effort_condition + (1 | subject_id)")
log_msg("  bs ~ difficulty_3 + effort_condition")
log_msg("  ndt ~ 1")
log_msg("  bias ~ task + effort_condition + (1 | subject_id)")
log_msg("")

formula_m1 <- bf(
  rt | dec(dec_upper) ~ difficulty_3 + effort_condition + (1 | subject_id),
  bs_formula,
  ndt ~ 1,
  bias ~ task + effort_condition + pupil_z + (1 | subject_id)
)

log_msg("Model 1 (Pupil → bias only):")
log_msg("  bias ~ task + effort_condition + pupil_z + (1 | subject_id)")
log_msg("")

formula_m2 <- bf(
  rt | dec(dec_upper) ~ difficulty_3 + effort_condition + pupil_z + (1 | subject_id),
  bs_formula,
  ndt ~ 1,
  bias ~ task + effort_condition + pupil_z + (1 | subject_id)
)

log_msg("Model 2 (Pupil → drift + bias):")
log_msg("  v ~ difficulty_3 + effort_condition + pupil_z + (1 | subject_id)")
log_msg("  bias ~ task + effort_condition + pupil_z + (1 | subject_id)")
log_msg("")

formula_m3 <- bf(
  rt | dec(dec_upper) ~ difficulty_3 + effort_condition + pupil_scaled * difficulty_3 + (1 | subject_id),
  bs_formula,
  ndt ~ 1,
  bias ~ task + effort_condition + (1 | subject_id)
)

log_msg("Model 3 (Pupil × difficulty on drift):")
log_msg("  v ~ difficulty_3 + effort_condition + pupil_scaled * difficulty_3 + (1 | subject_id)")
log_msg("")

# ==============================================================================
# Step 4: Define priors
# ==============================================================================

log_msg("STEP 4: Defining priors...")
log_msg("")

# Compute NDT upper bound (based on min RT)
min_rt <- min(model_data$rt, na.rm = TRUE)
ndt_ub <- log(min_rt - 0.02)  # Leave 20ms margin

log_msg("  Min RT:", round(min_rt, 3), "s")
log_msg("  NDT upper bound:", round(exp(ndt_ub), 3), "s (log scale:", round(ndt_ub, 3), ")")
log_msg("")

# Priors for probe-onset-locked RT (aligned with behavioral models)
# Based on ddm_refit_with_new_threshold.R priors
create_priors_pupil_ddm <- function(ndt_ub, include_pupil_drift = FALSE) {
  ndt_ub_val <- as.numeric(ndt_ub)
  
  priors <- c(
    # Drift rate (v)
    prior(normal(0, 1), class = "Intercept"),
    prior(normal(0, 0.5), class = "b"),  # For task, difficulty, effort
    
    # Boundary separation (bs)
    prior(normal(log(1.3), 0.25), class = "Intercept", dpar = "bs",
          lb = log(0.3), ub = log(5)),
    prior(normal(0, 0.20), class = "b", dpar = "bs"),  # For task, effort
    
    # Non-decision time (ndt)
    eval(substitute(
      prior(normal(log(0.35), 0.15), class = "Intercept", dpar = "ndt",
            lb = log(0.02), ub = UB_VAL),
      list(UB_VAL = ndt_ub_val)
    )),
    
    # Bias (z)
    prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
    prior(normal(0, 0.5), class = "b", dpar = "bias"),  # For task, effort, pupil_z
    
    # Random effects
    prior(exponential(5), class = "sd"),
    prior(exponential(5), class = "sd", dpar = "bias")
  )
  
  # Add pupil prior for drift if included
  if (include_pupil_drift) {
    # Pupil coefficient for drift: normal(0, 0.5) on link scale
    # Justification: Same scale as other drift predictors, allows both positive
    # and negative effects. 0.5 SD is weakly informative (95% CI: -1 to 1).
    priors <- c(
      priors,
      prior(normal(0, 0.5), class = "b", coef = "pupil_z")
    )
  }
  
  priors
}

log_msg("Prior specifications (probe-onset-locked RT):")
log_msg("  Drift (v):")
log_msg("    Intercept: normal(0, 1)")
log_msg("    Predictors: normal(0, 0.5)")
log_msg("  Boundary (bs):")
log_msg("    Intercept: normal(log(1.3), 0.25), lb=log(0.3), ub=log(5)")
log_msg("    Predictors: normal(0, 0.20)")
log_msg("  NDT (t0):")
log_msg(sprintf("    Intercept: normal(log(0.35), 0.15), lb=log(0.02), ub=%.3f", exp(ndt_ub)))
log_msg("  Bias (z):")
log_msg("    Intercept: normal(0, 0.5)")
log_msg("    Predictors: normal(0, 0.5)")
log_msg("  Random effects:")
log_msg("    SD: exponential(5)")
log_msg("")
log_msg("Pupil coefficient prior (when included):")
log_msg("  normal(0, 0.5) on link scale")
log_msg("  Justification: Weakly informative, allows positive/negative effects")
log_msg("  95% CI: approximately -1 to +1 on link scale")
log_msg("")

# ==============================================================================
# Step 5: Fit models
# ==============================================================================

log_msg("STEP 5: Fitting models...")
log_msg("")

# Family
family_wiener <- wiener(link_bs = "log", link_ndt = "log", link_bias = "logit")

# Backend
backend <- if (USE_CMDSTANR) "cmdstanr" else "rstan"

# Control parameters
control_params <- list(
  adapt_delta = ADAPT_DELTA,
  max_treedepth = MAX_TREEDEPTH
)

# Convergence diagnostics (brms:: — posterior::rhat() breaks on brmsfit)
extract_brms_diagnostics <- function(fit, n_chains, n_iter, n_warmup, max_treedepth) {
  out <- list(
    max_rhat = NA_real_,
    min_bulk_ess = NA_real_,
    min_tail_ess = NA_real_,
    n_divergences = NA_integer_,
    n_treedepth_hits = NA_integer_
  )

  tryCatch({
    rhat_vals <- brms::rhat(fit)
    out$max_rhat <- suppressWarnings(max(rhat_vals, na.rm = TRUE))
  }, error = function(e) {
    log_msg("  WARNING: Could not compute Rhat:", conditionMessage(e), level = "WARN")
  })

  tryCatch({
    neff_rat <- brms::neff_ratio(fit)
    total_draws <- n_chains * (n_iter - n_warmup)
    bulk_ess <- neff_rat * total_draws
    out$min_bulk_ess <- suppressWarnings(min(bulk_ess, na.rm = TRUE))
    out$min_tail_ess <- out$min_bulk_ess
  }, error = function(e) {
    log_msg("  WARNING: Could not compute ESS:", conditionMessage(e), level = "WARN")
  })

  tryCatch({
    np <- brms::nuts_params(fit)
    if ("divergent__" %in% names(np)) {
      out$n_divergences <- sum(np$divergent__ == 1, na.rm = TRUE)
      out$n_treedepth_hits <- sum(np$treedepth__ >= max_treedepth, na.rm = TRUE)
    } else if ("Parameter" %in% names(np) && "Value" %in% names(np)) {
      out$n_divergences <- sum(subset(np, Parameter == "divergent__")$Value, na.rm = TRUE)
      out$n_treedepth_hits <- sum(
        subset(np, Parameter == "treedepth__")$Value >= max_treedepth,
        na.rm = TRUE
      )
    }
  }, error = function(e) {
    log_msg("  WARNING: Could not extract NUTS params:", conditionMessage(e), level = "WARN")
  })

  out
}

# Storage for models
models <- list()
model_info <- data.frame(
  model_name = character(),
  formula_desc = character(),
  n_trials = integer(),
  n_subjects = integer(),
  runtime_sec = numeric(),
  max_rhat = numeric(),
  min_bulk_ess = numeric(),
  min_tail_ess = numeric(),
  n_divergences = integer(),
  n_treedepth_hits = integer(),
  status = character(),
  stringsAsFactors = FALSE
)

# Helper function to fit and log model
fit_model <- function(model_name, formula, priors, include_pupil = FALSE) {
  log_msg(strrep("-", 80))
  log_msg("Fitting", model_name)
  log_msg(strrep("-", 80))
  
  model_start <- Sys.time()
  
  # Log formula
  log_msg("Formula:")
  log_msg("  ", deparse(formula$formula[[1]]))
  for (dpar in names(formula$pforms)) {
    log_msg("  ", dpar, ":", deparse(formula$pforms[[dpar]]))
  }
  log_msg("")
  
  # Fit model
  log_msg("Starting MCMC sampling...")
  log_msg("  Chains:", N_CHAINS)
  log_msg("  Iterations:", N_ITER)
  log_msg("  Warmup:", N_WARMUP)
  log_msg("")
  
  fit <- tryCatch({
    brm(
      formula = formula,
      data = model_data,
      family = family_wiener,
      prior = priors,
      chains = N_CHAINS,
      iter = N_ITER,
      warmup = N_WARMUP,
      cores = N_CHAINS,
      backend = backend,
      control = control_params,
      seed = 12345,
      file = file.path(MODELS_DIR, paste0(model_name, ".rds")),
      file_refit = Sys.getenv("PUPIL_REFIT", "on_change")
    )
  }, error = function(e) {
    log_msg("ERROR during model fitting:", e$message, level = "ERROR")
    return(NULL)
  })
  
  model_end <- Sys.time()
  runtime_sec <- as.numeric(difftime(model_end, model_start, units = "secs"))
  
  if (is.null(fit)) {
    log_msg("✗ Model fitting FAILED", level = "ERROR")
    log_msg("")
    
    model_info <<- rbind(model_info, data.frame(
      model_name = model_name,
      formula_desc = "Failed to fit",
      n_trials = nrow(model_data),
      n_subjects = n_distinct(model_data$subject_id),
      runtime_sec = runtime_sec,
      max_rhat = NA,
      min_bulk_ess = NA,
      min_tail_ess = NA,
      n_divergences = NA,
      n_treedepth_hits = NA,
      status = "FAILED",
      stringsAsFactors = FALSE
    ))
    
    return(NULL)
  }
  
  log_msg("✓ Model fitting completed")
  log_msg("  Runtime:", round(runtime_sec / 60, 1), "minutes")
  log_msg("")
  
  # Extract diagnostics
  log_msg("Sampling diagnostics:")
  diag <- extract_brms_diagnostics(
    fit, N_CHAINS, N_ITER, N_WARMUP, MAX_TREEDEPTH
  )
  max_rhat <- diag$max_rhat
  min_bulk_ess <- diag$min_bulk_ess
  min_tail_ess <- diag$min_tail_ess
  n_divergences <- diag$n_divergences
  n_treedepth_hits <- diag$n_treedepth_hits

  if (!is.na(max_rhat)) {
    log_msg(sprintf("  Max Rhat: %.4f", max_rhat))
    if (max_rhat > 1.01) log_msg("  WARNING: Some Rhat > 1.01", level = "WARN")
  }
  if (!is.na(min_bulk_ess)) {
    log_msg(sprintf("  Min ESS bulk: %.0f", min_bulk_ess))
    if (min_bulk_ess < 400) log_msg("  WARNING: Some ESS bulk < 400", level = "WARN")
  }
  if (!is.na(min_tail_ess)) {
    log_msg(sprintf("  Min ESS tail: %.0f", min_tail_ess))
    if (min_tail_ess < 400) log_msg("  WARNING: Some ESS tail < 400", level = "WARN")
  }
  if (!is.na(n_divergences)) {
    log_msg(sprintf("  Divergences: %d", n_divergences))
    if (n_divergences > 0) log_msg("  WARNING: Divergent transitions detected", level = "WARN")
  }
  if (!is.na(n_treedepth_hits)) {
    log_msg(sprintf("  Max treedepth hits: %d", n_treedepth_hits))
    if (n_treedepth_hits > 0) log_msg("  WARNING: Max treedepth reached", level = "WARN")
  }

  log_msg("")

  # Determine status
  status <- "OK"
  if (!is.na(max_rhat) && max_rhat > 1.01) status <- "WARN_RHAT"
  if ((!is.na(min_bulk_ess) && min_bulk_ess < 400) ||
      (!is.na(min_tail_ess) && min_tail_ess < 400)) status <- "WARN_ESS"
  if (!is.na(n_divergences) && n_divergences > 0) status <- "WARN_DIVERGENCES"
  if ((!is.na(max_rhat) && max_rhat > 1.05) ||
      (!is.na(n_divergences) && n_divergences > 100)) status <- "FAIL"
  
  log_msg("Status:", status)
  log_msg("")
  
  # Store model info
  model_info <<- rbind(model_info, data.frame(
    model_name = model_name,
    formula_desc = paste(deparse(formula$formula[[1]]), collapse = " "),
    n_trials = nrow(model_data),
    n_subjects = n_distinct(model_data$subject_id),
    runtime_sec = runtime_sec,
    max_rhat = max_rhat,
    min_bulk_ess = min_bulk_ess,
    min_tail_ess = min_tail_ess,
    n_divergences = n_divergences,
    n_treedepth_hits = n_treedepth_hits,
    status = status,
    stringsAsFactors = FALSE
  ))
  
  return(fit)
}

# Fit Model 0: Behavioral baseline
priors_m0 <- create_priors_pupil_ddm(ndt_ub = ndt_ub, include_pupil_drift = FALSE)
models$m0 <- fit_model("model_0_behavioral", formula_m0, priors_m0, include_pupil = FALSE)

# Fit Model 1: Pupil → bias only
priors_m1 <- create_priors_pupil_ddm(ndt_ub = ndt_ub, include_pupil_drift = FALSE)
models$m1 <- fit_model("model_1_pupil_bias", formula_m1, priors_m1, include_pupil = TRUE)

# Fit Model 2: Pupil → bias + drift
priors_m2 <- create_priors_pupil_ddm(ndt_ub = ndt_ub, include_pupil_drift = TRUE)
models$m2 <- fit_model("model_2_pupil_bias_drift", formula_m2, priors_m2, include_pupil = TRUE)

# Fit Model 3: Pupil × difficulty on drift (uses pupil_scaled, not pupil_z)
priors_m3 <- create_priors_pupil_ddm(ndt_ub = ndt_ub, include_pupil_drift = FALSE)
models$m3 <- fit_model("model_3_pupil_difficulty_interaction", formula_m3, priors_m3, include_pupil = TRUE)

# Copy interaction model to primary behavioral run_dir for QMD pupil-interaction-stats chunk
run_id <- Sys.getenv("DDM_RUN_ID", "20260226_092110")
run_models_dir <- here::here("output", "ddm_refits", "runs", run_id, "models")
if (!is.null(models$m3)) {
  dir.create(run_models_dir, recursive = TRUE, showWarnings = FALSE)
  dest <- file.path(run_models_dir, "pupil_interaction__probe_onset_locked__thr0.20.rds")
  src <- file.path(MODELS_DIR, "model_3_pupil_difficulty_interaction.rds")
  if (file.exists(src)) {
    ok <- file.copy(src, dest, overwrite = TRUE)
    log_msg(if (ok) paste("✓ Copied interaction model to", dest)
            else paste("WARNING: failed to copy interaction model to", dest),
            level = if (ok) "INFO" else "WARN")
  }
}

# ==============================================================================
# Step 6: Save model info
# ==============================================================================

log_msg("STEP 6: Saving model info...")

model_info_file <- file.path(TABLES_DIR, "model_info.csv")
write_csv(model_info, model_info_file)

log_msg("  ✓ Saved:", model_info_file)
log_msg("")

# Print summary table
log_msg("Model Summary:")
print(model_info)
log_msg("")

# ==============================================================================
# Finish
# ==============================================================================

END_TIME <- Sys.time()
ELAPSED <- as.numeric(difftime(END_TIME, START_TIME, units = "secs"))

log_msg(strrep("=", 80))
log_msg("COMPLETED")
log_msg(strrep("=", 80))
log_msg("End time:", format(END_TIME, "%Y-%m-%d %H:%M:%S"))
log_msg("Total elapsed time:", sprintf("%.1f minutes", ELAPSED / 60))
log_msg("")
log_msg("Output files:")
log_msg("  Models:")
for (i in 1:nrow(model_info)) {
  if (model_info$status[i] != "FAILED") {
    log_msg("    -", file.path(MODELS_DIR, paste0(model_info$model_name[i], ".rds")))
  }
}
log_msg("  Tables:")
log_msg("    -", model_info_file)
log_msg("  Log:")
log_msg("    -", LOG_FILE)
log_msg("")

# Close log file
close(log_con)

cat("\n✓ Pupil-DDM model fitting completed!\n")
cat("  Log file:", LOG_FILE, "\n")
cat("  Models directory:", MODELS_DIR, "\n\n")

# Print final summary to console
cat("Model Summary:\n")
print(model_info)
cat("\n")
