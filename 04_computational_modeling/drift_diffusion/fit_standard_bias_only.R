#!/usr/bin/env Rscript
# =========================================================================
# STEP 4A: FIT STANDARD-ONLY BIAS MODEL
# =========================================================================
# Fits a hierarchical Wiener DDM to Standard (Δ=0) trials only to estimate
# bias (z) with drift tightly constrained to zero
# =========================================================================
# Model: rt | dec(dec_upper) ~ 1 + (1|subject_id)  [drift ≈ 0 with tight prior]
#        bs ~ 1 + (1|subject_id)
#        ndt ~ 1
#        bias ~ task + effort_condition + (1|subject_id)
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(cmdstanr)
  library(dplyr)
  library(readr)
  library(posterior)
})

# Helper function for logit (needed for validation constants)
logit <- function(p) log(p / (1 - p))

# Source validation functions (after logit is defined)
source("R/validate_ddm_parameters.R")

# =========================================================================
# CONFIGURATION & LOGGING SETUP
# =========================================================================

SCRIPT_NAME <- "fit_standard_bias_only.R"
START_TIME <- Sys.time()

# Paths
DATA_DDM_ONLY <- "data/analysis_ready/bap_ddm_only_ready.csv"
DATA_DDM_PUPIL <- "data/analysis_ready/bap_ddm_pupil_ready.csv"
OUT_DIR <- "output/models"
PUBLISH_DIR <- "output/publish"
LOG_DIR <- "logs"

# Create directories
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(PUBLISH_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(LOG_DIR, showWarnings = FALSE, recursive = TRUE)

# Log file with timestamp
LOG_FILE <- file.path(LOG_DIR, paste0("fit_standard_bias_", format(START_TIME, "%Y%m%d_%H%M%S"), ".log"))

# Determine which data file to use
USE_PUPIL_DATA <- FALSE  # Set to TRUE if you want to use pupil data
DATA_FILE <- if (USE_PUPIL_DATA && file.exists(DATA_DDM_PUPIL)) {
  DATA_DDM_PUPIL
} else if (file.exists(DATA_DDM_ONLY)) {
  DATA_DDM_ONLY
} else {
  stop("No DDM-ready data file found. Run data preparation scripts first.")
}

# Logging function
log_msg <- function(..., level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  msg <- paste(..., collapse = " ")
  log_entry <- sprintf("[%s] [%s] %s\n", timestamp, level, msg)
  cat(log_entry)
  cat(log_entry, file = LOG_FILE, append = TRUE)
  flush.console()
}

# Start logging
log_msg(strrep("=", 80))
log_msg("FITTING STANDARD-ONLY BIAS MODEL")
log_msg(strrep("=", 80))
log_msg("Script:", SCRIPT_NAME)
log_msg("Start time:", format(START_TIME, "%Y-%m-%d %H:%M:%S"))
log_msg("Working directory:", getwd())
log_msg("Log file:", LOG_FILE)
log_msg("Data file:", DATA_FILE)
log_msg("")

# =========================================================================
# STEP 1: LOAD AND FILTER DATA
# =========================================================================

log_msg("STEP 1: Loading and filtering Standard trials only...")
tic_data <- Sys.time()

if (!file.exists(DATA_FILE)) {
  log_msg("ERROR: Data file not found:", DATA_FILE, level = "ERROR")
  stop("Data file not found: ", DATA_FILE)
}

dd <- read_csv(DATA_FILE, show_col_types = FALSE)

log_msg("  Loaded", nrow(dd), "total trials")

# CRITICAL: Verify dec_upper column exists
if (!"dec_upper" %in% names(dd)) {
  log_msg("ERROR: dec_upper column not found!", level = "ERROR")
  stop("dec_upper column required for response-side coding")
}

# Filter to Standard trials only
dd <- dd %>%
  mutate(
    subject_id = factor(subject_id),
    task = factor(task),
    effort_condition = factor(effort_condition, levels = c("Low_5_MVC", "High_40_MVC")),
    difficulty_level = factor(difficulty_level, levels = c("Standard", "Hard", "Easy")),
    dec_upper = as.integer(dec_upper)
  ) %>%
  filter(
    difficulty_level == "Standard",
    !is.na(rt),
    !is.na(dec_upper),
    rt >= 0.25,
    rt <= 3.0
  )

log_msg("  Filtered to", nrow(dd), "Standard trials")
log_msg("  Subjects:", length(unique(dd$subject_id)))
log_msg("  Tasks:", paste(levels(dd$task), collapse = ", "))
log_msg("  Effort conditions:", paste(levels(dd$effort_condition), collapse = ", "))

# Check response distribution
prop_diff <- mean(dd$dec_upper, na.rm = TRUE)
prop_same <- 1 - prop_diff
log_msg(sprintf("  Response distribution: %.1f%% 'Different', %.1f%% 'Same'", 
                100 * prop_diff, 100 * prop_same))
log_msg(sprintf("  Expected bias z should be approximately %.3f (close to lower boundary)", prop_same))

data_time <- as.numeric(difftime(Sys.time(), tic_data, units = "secs"))
log_msg("  Data load time:", round(data_time, 2), "seconds")
log_msg("")

# =========================================================================
# STEP 2: DEFINE MODEL FORMULA
# =========================================================================

log_msg("STEP 2: Defining model formula...")

fam <- wiener(link_bs = "log", link_ndt = "log", link_bias = "logit")

form <- bf(
  # Drift rate: Allow negative values (evidence for "Same" on Standard trials)
  # FIXED: Removed tight constraint - negative drift drives "Same" responses
  rt | dec(dec_upper) ~ 1 + (1 | subject_id),
  bs   ~ 1 + (1 | subject_id),
  ndt  ~ 1,  # No fixed effects to avoid initialization issues
  bias ~ task + effort_condition + (1 | subject_id)
)

log_msg("  Model formula:")
log_msg("    Drift (v): rt | dec(dec_upper) ~ 1 + (1|subject_id) [relaxed prior: allows negative drift]")
log_msg("    Boundary (a): bs ~ 1 + (1|subject_id)")
log_msg("    Non-decision time (t₀): ndt ~ 1")
log_msg("    Bias (z): bias ~ task + effort_condition + (1|subject_id)")
log_msg("")

# =========================================================================
# STEP 3: DEFINE PRIORS
# =========================================================================

log_msg("STEP 3: Defining priors...")

pri <- c(
  # Drift rate (v) - Allow negative drift (evidence for "Same" on Standard trials)
  # FIXED: Changed from normal(0, 0.03) to normal(0, 2) to allow model to fit
  # Negative drift drives accumulation toward "Same" (lower boundary)
  prior(normal(0, 2), class = "Intercept"),  # Weakly informative, allows negative values
  
  # Boundary separation (a/bs) - log link
  prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
  
  # Non-decision time (t₀/ndt) - log link
  prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
  
  # Starting point bias (z) - logit link
  prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
  prior(normal(0, 0.35), class = "b", dpar = "bias"),  # task/effort effects
  
  # Random effects
  prior(student_t(3, 0, 0.30), class = "sd")
)

log_msg("  Priors defined (drift prior relaxed to allow negative drift)")
log_msg("  NOTE: Negative drift = evidence for 'Same' (lower boundary)")
log_msg("")

# =========================================================================
# STEP 4: SAFE INITIALIZATION
# =========================================================================

log_msg("STEP 4: Setting up safe initialization...")

min_rt <- min(dd$rt, na.rm = TRUE)
safe_ndt <- min_rt * 0.6  # 60% of min RT as safe NDT
log_msg(sprintf("  Min RT: %.3fs, Safe NDT: %.3fs (log = %.3f)", min_rt, safe_ndt, log(safe_ndt)))

safe_init <- function(chain_id = 1) {
  list(
    Intercept_ndt = log(safe_ndt),
    Intercept_bs  = log(1.5),
    Intercept_bias = 0,  # 0 on logit = 0.5 bias
    # Allow drift to start negative (evidence for "Same")
    # Will be sampled from prior normal(0, 2)
    Intercept     = rnorm(1, -1, 1)  # Negative drift more likely for Standard trials
  )
}

log_msg("  Initialization function created")
log_msg("")

# =========================================================================
# STEP 5: FIT MODEL
# =========================================================================

log_msg("STEP 5: Fitting model...")
log_msg("  Algorithm: NUTS")
log_msg("  Chains: 4")
log_msg("  Iterations: 8,000 per chain (4,000 warmup, 4,000 sampling)")
log_msg("  Cores: 4")
log_msg("  Control: adapt_delta=0.995, max_treedepth=15")
log_msg("")

fit_file <- file.path(OUT_DIR, "standard_bias_only")
tic_fit <- Sys.time()

log_msg("  Starting MCMC sampling...")

fit <- tryCatch({
  brm(
    form,
    data = dd,
    family = fam,
    prior = pri,
    chains = 4,
    iter = 8000,
    warmup = 4000,
    cores = 4,
    control = list(adapt_delta = 0.995, max_treedepth = 15),
    backend = "cmdstanr",
    file = fit_file,
    file_refit = "always",
    refresh = 200,
    init = safe_init,
    seed = 20251116,
    save_pars = save_pars(all = TRUE)
  )
}, error = function(e) {
  log_msg("ERROR during model fitting:", e$message, level = "ERROR")
  stop("Model fitting failed: ", e$message)
})

fit_time <- as.numeric(difftime(Sys.time(), tic_fit, units = "mins"))
log_msg("")
log_msg("  ✓ Model fitting complete")
log_msg("  Wall time:", round(fit_time, 1), "minutes")
log_msg("")

# =========================================================================
# STEP 6: CHECK CONVERGENCE
# =========================================================================

log_msg("STEP 6: Checking convergence...")

diag <- tryCatch({
  fit_summary <- summary(fit)
  max_rhat <- max(fit_summary$fixed$Rhat, na.rm = TRUE)
  min_ess_bulk <- min(fit_summary$fixed$Bulk_ESS, na.rm = TRUE)
  min_ess_tail <- min(fit_summary$fixed$Tail_ESS, na.rm = TRUE)
  
  sampler_params <- rstan::get_sampler_params(fit$fit, inc_warmup = FALSE)
  n_divergent <- sum(sapply(sampler_params, function(x) sum(x[, "divergent__"])))
  
  list(max_rhat = max_rhat, min_ess_bulk = min_ess_bulk, 
       min_ess_tail = min_ess_tail, n_divergent = n_divergent)
}, error = function(e) {
  log_msg("  Warning: Could not extract diagnostics", level = "WARN")
  return(NULL)
})

if (!is.null(diag)) {
  log_msg("  Convergence diagnostics:")
  log_msg(sprintf("    Max Rhat: %.4f (target: ≤ 1.01)", diag$max_rhat))
  log_msg(sprintf("    Min Bulk ESS: %.0f (target: ≥ 400)", diag$min_ess_bulk))
  log_msg(sprintf("    Min Tail ESS: %.0f (target: ≥ 400)", diag$min_ess_tail))
  log_msg(sprintf("    Divergent transitions: %d (target: 0)", diag$n_divergent))
  
  converged <- (diag$max_rhat <= 1.01) && 
               (diag$min_ess_bulk >= 400) && 
               (diag$min_ess_tail >= 400) && 
               (diag$n_divergent == 0)
  
  if (converged) {
    log_msg("  ✓ Model converged successfully")
  } else {
    log_msg("  WARNING: Model may not have converged", level = "WARN")
  }
}

log_msg("")

# =========================================================================
# STEP 7: EXTRACT BIAS ESTIMATES
# =========================================================================

log_msg("STEP 7: Extracting bias estimates...")

# Extract bias intercept (on logit scale)
bias_samples <- posterior_samples(fit, pars = "^b_bias_Intercept")
if (ncol(bias_samples) > 0) {
  bias_logit <- mean(bias_samples[[1]])
  bias_prob <- plogis(bias_logit)
  
  log_msg(sprintf("  Bias intercept (logit scale): %.3f", bias_logit))
  log_msg(sprintf("  Bias intercept (probability scale): %.3f", bias_prob))
  log_msg(sprintf("  Expected (from data): %.3f", prop_same))
  
  if (abs(bias_prob - prop_same) < 0.1) {
    log_msg("  ✓ Bias estimate matches data distribution")
  } else {
    log_msg("  WARNING: Bias estimate differs from data", level = "WARN")
  }
}

log_msg("")

# =========================================================================
# STEP 7B: PARAMETER VALIDATION
# =========================================================================

log_msg("STEP 7B: Running comprehensive parameter validation...")
validation_log <- file.path(LOG_DIR, paste0("param_validation_standard_bias_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))
param_validation <- validate_ddm_model(fit, dd, validation_log)

if (!param_validation$success) {
  log_msg("  ⚠ Parameter validation found issues - review validation log:", validation_log, level = "WARN")
} else {
  log_msg("  ✓ All parameter validations passed")
}

log_msg("")

# =========================================================================
# FINAL SUMMARY
# =========================================================================

END_TIME <- Sys.time()
TOTAL_TIME <- as.numeric(difftime(END_TIME, START_TIME, units = "mins"))

log_msg(strrep("=", 80))
log_msg("STANDARD-ONLY BIAS MODEL FITTING COMPLETE")
log_msg(strrep("=", 80))
log_msg("Model file:", fit_file)
log_msg("Total elapsed time:", round(TOTAL_TIME, 1), "minutes")
log_msg("End time:", format(END_TIME, "%Y-%m-%d %H:%M:%S"))
log_msg(strrep("=", 80))

