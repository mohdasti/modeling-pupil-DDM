#!/usr/bin/env Rscript
# =========================================================================
# STEP 4: FIT PRIMARY DDM MODEL (v + z + a)
# =========================================================================
# Fits the primary hierarchical Wiener DDM model where difficulty maps to
# drift rate (v), boundary separation (a), and starting-point bias (z)
# =========================================================================
# Model: rt | dec(dec_upper) ~ difficulty_level + task + effort_condition + (1|subject_id)
#        bs ~ difficulty_level + task + (1|subject_id)
#        ndt ~ task + effort_condition
#        bias ~ task + effort_condition + (1|subject_id)
#        NOTE: Bias does NOT vary by difficulty_level (expert guidance: randomized trials)
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

SCRIPT_NAME <- "fit_primary_vza.R"
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
LOG_FILE <- file.path(LOG_DIR, paste0("fit_primary_vza_", format(START_TIME, "%Y%m%d_%H%M%S"), ".log"))

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
log_msg("FITTING PRIMARY DDM MODEL (v + z + a)")
log_msg(strrep("=", 80))
log_msg("Script:", SCRIPT_NAME)
log_msg("Start time:", format(START_TIME, "%Y-%m-%d %H:%M:%S"))
log_msg("Working directory:", getwd())
log_msg("Log file:", LOG_FILE)
log_msg("Data file:", DATA_FILE)
log_msg("Using pupil data:", USE_PUPIL_DATA)
log_msg("")

# =========================================================================
# STEP 1: LOAD AND VALIDATE DATA
# =========================================================================

log_msg("STEP 1: Loading and validating data...")
tic_data <- Sys.time()

if (!file.exists(DATA_FILE)) {
  log_msg("ERROR: Data file not found:", DATA_FILE, level = "ERROR")
  stop("Data file not found: ", DATA_FILE)
}

dd <- read_csv(DATA_FILE, show_col_types = FALSE)

log_msg("  Loaded", nrow(dd), "trials from", length(unique(dd$subject_id)), "subjects")

# CRITICAL: Verify dec_upper column exists
if (!"dec_upper" %in% names(dd)) {
  log_msg("ERROR: dec_upper column not found in data file!", level = "ERROR")
  log_msg("  Available columns:", paste(names(dd), collapse = ", "))
  stop("dec_upper column required for response-side coding")
}

# Verify dec_upper coding
dec_values <- unique(dd$dec_upper[!is.na(dd$dec_upper)])
if (!all(dec_values %in% c(0L, 1L))) {
  log_msg("ERROR: dec_upper contains invalid values:", paste(dec_values, collapse = ", "), level = "ERROR")
  stop("dec_upper must contain only 0, 1, or NA")
}

log_msg("  ✓ dec_upper column validated (response-side coding)")

# Check Standard trials distribution
std_trials <- dd %>% filter(difficulty_level == "Standard")
prop_std_same <- 1 - mean(std_trials$dec_upper, na.rm = TRUE)
log_msg(sprintf("  Standard trials - Proportion 'Same': %.3f (expected: ~0.89)", prop_std_same))

data_time <- as.numeric(difftime(Sys.time(), tic_data, units = "secs"))
log_msg("  Data load time:", round(data_time, 2), "seconds")
log_msg("")

# =========================================================================
# STEP 2: PREPARE DATA FOR MODELING
# =========================================================================

log_msg("STEP 2: Preparing data for modeling...")

dd <- dd %>%
  mutate(
    subject_id = factor(subject_id),
    task = factor(task),
    effort_condition = factor(effort_condition, levels = c("Low_5_MVC", "High_40_MVC")),
    difficulty_level = factor(difficulty_level, levels = c("Standard", "Hard", "Easy")),
    # CRITICAL: Use dec_upper directly (response-side coding)
    # No need to derive decision from iscorr
    dec_upper = as.integer(dec_upper)  # Ensure integer type
  ) %>%
  filter(
    !is.na(rt),
    !is.na(dec_upper),  # Must have response choice
    rt >= 0.25,
    rt <= 3.0
  )

log_msg("  Final dataset:", nrow(dd), "trials")
log_msg("  Subjects:", length(unique(dd$subject_id)))
log_msg("  Tasks:", paste(levels(dd$task), collapse = ", "))
log_msg("  Difficulty levels:", paste(levels(dd$difficulty_level), collapse = ", "))
log_msg("  Effort conditions:", paste(levels(dd$effort_condition), collapse = ", "))
log_msg("")

# =========================================================================
# STEP 3: DEFINE MODEL FORMULA
# =========================================================================

log_msg("STEP 3: Defining model formula...")

form <- bf(
  # CRITICAL: Use dec_upper for response-side coding
  # Upper boundary (1) = "different", Lower boundary (0) = "same"
  rt | dec(dec_upper) ~ difficulty_level + task + effort_condition + (1|subject_id),
  bs   ~ difficulty_level + task + (1|subject_id),
  ndt  ~ task + effort_condition,  # No random effects for stability
  # EXPERT GUIDANCE: Bias should NOT vary by difficulty_level because trials are randomized
  # Participants cannot adjust starting point based on difficulty they don't know about yet
  # Bias can vary by task (if blocked) and effort (if cued pre-trial)
  bias ~ task + effort_condition + (1|subject_id)
)

log_msg("  Model formula:")
log_msg("    Drift (v): rt | dec(dec_upper) ~ difficulty_level + task + effort_condition + (1|subject_id)")
log_msg("    Boundary (a): bs ~ difficulty_level + task + (1|subject_id)")
log_msg("    Non-decision time (t₀): ndt ~ task + effort_condition")
log_msg("    Bias (z): bias ~ task + effort_condition + (1|subject_id)")
log_msg("    NOTE: Bias does NOT vary by difficulty_level (expert guidance: randomized trials)")
log_msg("")

# =========================================================================
# STEP 4: DEFINE PRIORS
# =========================================================================

log_msg("STEP 4: Defining priors...")

fam <- wiener(link_bs = "log", link_ndt = "log", link_bias = "logit")

pri <- c(
  # Drift rate (v) - identity link
  prior(normal(0, 1), class = "Intercept"),
  prior(normal(0, 0.5), class = "b"),
  
  # Boundary separation (a/bs) - log link
  prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
  prior(normal(0, 0.35), class = "b", dpar = "bs"),
  
  # Non-decision time (t₀/ndt) - log link
  prior(normal(log(0.23), 0.12), class = "Intercept", dpar = "ndt"),
  prior(normal(0, 0.08), class = "b", dpar = "ndt"),
  
  # Starting point bias (z) - logit link
  prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
  prior(normal(0, 0.35), class = "b", dpar = "bias"),
  
  # Random effects
  prior(student_t(3, 0, 0.30), class = "sd")
)

log_msg("  Priors defined (weakly informative, literature-justified)")
log_msg("")

# =========================================================================
# STEP 5: SAFE INITIALIZATION
# =========================================================================

log_msg("STEP 5: Setting up safe initialization...")

min_rt <- min(dd$rt, na.rm = TRUE)
safe_ndt <- min_rt * 0.3  # 30% of min RT as safe NDT
log_msg(sprintf("  Min RT: %.3fs, Safe NDT: %.3fs (log = %.3f)", min_rt, safe_ndt, log(safe_ndt)))

safe_init <- function(chain_id = 1) {
  list(
    Intercept_ndt = log(safe_ndt),
    Intercept_bs  = log(1.5),
    Intercept_bias = 0,  # 0 on logit = 0.5 bias (no bias)
    Intercept     = 0
  )
}

log_msg("  Initialization function created")
log_msg("")

# =========================================================================
# STEP 6: FIT MODEL
# =========================================================================

log_msg("STEP 6: Fitting model...")
log_msg("  Algorithm: NUTS")
log_msg("  Chains: 4")
log_msg("  Iterations: 8,000 per chain (4,000 warmup, 4,000 sampling)")
log_msg("  Cores: 4")
log_msg("  Threads: 2 per chain")
log_msg("  Control: adapt_delta=0.995, max_treedepth=15")
log_msg("")

fit_file <- file.path(OUT_DIR, "primary_vza")
tic_fit <- Sys.time()

log_msg("  Starting MCMC sampling...")
log_msg("  (This may take 30-60 minutes depending on system)")

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
    threads = threading(2),
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
  log_msg("  Check Stan output above for details", level = "ERROR")
  stop("Model fitting failed: ", e$message)
})

fit_time <- as.numeric(difftime(Sys.time(), tic_fit, units = "mins"))
log_msg("")
log_msg("  ✓ Model fitting complete")
log_msg("  Wall time:", round(fit_time, 1), "minutes")
log_msg("")

# =========================================================================
# STEP 7: MODEL DIAGNOSTICS & PARAMETER VALIDATION
# =========================================================================

log_msg("STEP 7: Checking model diagnostics and validating parameters...")

# Get diagnostics
diag <- tryCatch({
  fit_summary <- summary(fit)
  
  # Extract key diagnostics
  max_rhat <- max(fit_summary$fixed$Rhat, na.rm = TRUE)
  min_ess_bulk <- min(fit_summary$fixed$Bulk_ESS, na.rm = TRUE)
  min_ess_tail <- min(fit_summary$fixed$Tail_ESS, na.rm = TRUE)
  
  # Check for divergent transitions
  sampler_params <- rstan::get_sampler_params(fit$fit, inc_warmup = FALSE)
  n_divergent <- sum(sapply(sampler_params, function(x) sum(x[, "divergent__"])))
  
  list(
    max_rhat = max_rhat,
    min_ess_bulk = min_ess_bulk,
    min_ess_tail = min_ess_tail,
    n_divergent = n_divergent
  )
}, error = function(e) {
  log_msg("  Warning: Could not extract diagnostics:", e$message, level = "WARN")
  return(NULL)
})

if (!is.null(diag)) {
  log_msg("  Convergence diagnostics:")
  log_msg(sprintf("    Max Rhat: %.4f (target: ≤ 1.01)", diag$max_rhat))
  log_msg(sprintf("    Min Bulk ESS: %.0f (target: ≥ 400)", diag$min_ess_bulk))
  log_msg(sprintf("    Min Tail ESS: %.0f (target: ≥ 400)", diag$min_ess_tail))
  log_msg(sprintf("    Divergent transitions: %d (target: 0)", diag$n_divergent))
  
  # Check convergence
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

# Run comprehensive parameter validation
log_msg("STEP 7B: Running comprehensive parameter validation...")
validation_log <- file.path(LOG_DIR, paste0("param_validation_primary_vza_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))
param_validation <- validate_ddm_model(fit, dd, validation_log)

if (!param_validation$success) {
  log_msg("  ⚠ Parameter validation found issues - review validation log:", validation_log, level = "WARN")
} else {
  log_msg("  ✓ All parameter validations passed")
}

log_msg("")

# =========================================================================
# STEP 8: SAVE RESULTS
# =========================================================================

log_msg("STEP 8: Saving results...")

# Model is already saved via file= argument
log_msg("  ✓ Model saved:", fit_file)

# Save summary to publish directory
if (!is.null(diag)) {
  summary_file <- file.path(PUBLISH_DIR, "primary_vza_diagnostics.csv")
  write_csv(
    tibble(
      metric = c("max_rhat", "min_ess_bulk", "min_ess_tail", "n_divergent"),
      value = c(diag$max_rhat, diag$min_ess_bulk, diag$min_ess_tail, diag$n_divergent)
    ),
    summary_file
  )
  log_msg("  ✓ Diagnostics saved:", summary_file)
}

log_msg("")

# =========================================================================
# FINAL SUMMARY
# =========================================================================

END_TIME <- Sys.time()
TOTAL_TIME <- as.numeric(difftime(END_TIME, START_TIME, units = "mins"))

log_msg(strrep("=", 80))
log_msg("PRIMARY MODEL FITTING COMPLETE")
log_msg(strrep("=", 80))
log_msg("Model file:", fit_file)
log_msg("Total elapsed time:", round(TOTAL_TIME, 1), "minutes")
log_msg("End time:", format(END_TIME, "%Y-%m-%d %H:%M:%S"))
log_msg("=" %+% strrep("=", 78))


