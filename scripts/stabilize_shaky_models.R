# =========================================================================
# STABILIZE SHAKY MODELS
# =========================================================================
# Re-fit Model1_Baseline, Model2_Force, Model7_Task, Model8_Task_Additive
# with stricter convergence settings and explicit initialization
# =========================================================================

library(brms)
library(dplyr)
library(readr)
library(posterior)

cat("\n")
cat("================================================================================\n")
cat("STABILIZING SHAKY MODELS\n")
cat("================================================================================\n")
cat("Models: Model1_Baseline, Model2_Force, Model7_Task, Model8_Task_Additive\n")
cat("Settings: iter=3000 (warmup=1500), adapt_delta=0.95, max_treedepth=12\n")
cat("LIGHTWEIGHT MODE: Reduced iterations to prevent system crashes\n")
cat("Started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("================================================================================\n\n")

# Set working directory
if (!file.exists("output/models")) {
  if (file.exists("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")) {
    setwd("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")
  }
}

# Create output directories
dir.create("output/diagnostics", recursive = TRUE, showWarnings = FALSE)

# =========================================================================
# LOAD DATA
# =========================================================================

cat("Loading data...\n")

data_file <- "data/analysis_ready/bap_ddm_ready.csv"
if (!file.exists(data_file)) {
  stop("Data file not found: ", data_file)
}

data <- read_csv(data_file, show_col_types = FALSE)

# Harmonize columns
if (!"rt" %in% names(data) && "resp1RT" %in% names(data)) {
  data$rt <- data$resp1RT
}
data$rt <- suppressWarnings(as.numeric(data$rt))
if (!"accuracy" %in% names(data) && "iscorr" %in% names(data)) {
  data$accuracy <- data$iscorr
}
if (!"subject_id" %in% names(data) && "sub" %in% names(data)) {
  data$subject_id <- as.character(data$sub)
}
if (!"task" %in% names(data) && "task_behav" %in% names(data)) {
  data$task <- data$task_behav
}

ddm_data <- data %>%
  filter(rt >= 0.25 & rt <= 3.0) %>%
  mutate(
    response = as.integer(accuracy),
    effort_condition = as.factor(effort_condition),
    difficulty_level = as.factor(difficulty_level),
    subject_id = as.factor(subject_id),
    task = as.factor(task),
    decision = ifelse(accuracy == 1, 1, 0)
  )

cat("✓ Data loaded:", nrow(ddm_data), "trials\n\n")

# =========================================================================
# MODEL SPECIFICATIONS (from original script)
# =========================================================================

base_priors <- c(
  prior(normal(0, 1), class = "Intercept"),
  prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
  prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
  prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
  prior(student_t(3, 0, 0.5), class = "sd")
)

models_to_stabilize <- list(
  "Model1_Baseline" = list(
    formula = bf(
      rt | dec(decision) ~ 1 + (1|subject_id),
      bs ~ 1 + (1|subject_id),
      ndt ~ 1,
      bias ~ 1 + (1|subject_id)
    ),
    priors = base_priors
  ),
  "Model2_Force" = list(
    formula = bf(
      rt | dec(decision) ~ effort_condition + (1|subject_id),
      bs ~ 1 + (1|subject_id),
      ndt ~ 1,
      bias ~ 1 + (1|subject_id)
    ),
    priors = c(base_priors, prior(normal(0, 0.5), class = "b"))
  ),
  "Model7_Task" = list(
    formula = bf(
      rt | dec(decision) ~ task + (1|subject_id),
      bs ~ 1 + (1|subject_id),
      ndt ~ 1,
      bias ~ 1 + (1|subject_id)
    ),
    priors = c(base_priors, prior(normal(0, 0.5), class = "b"))
  ),
  "Model8_Task_Additive" = list(
    formula = bf(
      rt | dec(decision) ~ effort_condition + difficulty_level + task + (1|subject_id),
      bs ~ 1 + (1|subject_id),
      ndt ~ 1,
      bias ~ 1 + (1|subject_id)
    ),
    priors = c(base_priors, prior(normal(0, 0.5), class = "b"))
  )
)

# =========================================================================
# EXPLICIT INITIALIZATION FUNCTION
# =========================================================================

stabilized_init <- function() {
  # Explicit initialization matching Stan parameter names
  # For brms Wiener models with dpar, intercepts are: Intercept_bs, Intercept_ndt, Intercept_bias
  list(
    Intercept = rnorm(1, 0, 0.5),           # Drift intercept
    Intercept_bs = log(1.3),                # Boundary intercept (on log scale)
    Intercept_ndt = log(0.18),             # NDT intercept (on log scale) - CRITICAL: must be < min RT
    Intercept_bias = 0,                     # Bias intercept (on logit scale, 0 = 0.5)
    # Random effects SD (optional - brms will initialize if missing)
    sd_subject_id__Intercept = runif(1, 0.1, 0.3),
    sd_subject_id__bs_Intercept = runif(1, 0.05, 0.15),
    sd_subject_id__bias_Intercept = runif(1, 0.05, 0.15)
  )
}

# =========================================================================
# STABILIZATION FUNCTION
# =========================================================================

stabilize_model <- function(model_name, spec, data) {
  cat("\n")
  cat("================================================================================\n")
  cat("STABILIZING:", model_name, "\n")
  cat("================================================================================\n")
  cat("Started:", format(Sys.time(), "%H:%M:%S"), "\n\n")
  
  # Validate priors before sampling
  cat("Validating priors...\n")
  tryCatch({
    # validate_prior checks prior-formula consistency
    # Syntax varies by brms version, so wrap in tryCatch
    validation_result <- validate_prior(spec$formula, data = data, prior = spec$priors)
    if (is.null(validation_result) || length(validation_result) == 0) {
      cat("✓ Priors validated (no warnings)\n")
    } else {
      cat("⚠️  Prior validation warnings (may be benign):\n")
      print(validation_result)
    }
  }, error = function(e) {
    cat("⚠️  PRIOR VALIDATION ERROR (but continuing):", e$message, "\n")
    cat("  Note: validate_prior() sometimes fails due to brms version differences\n")
    cat("  Continuing with model fitting...\n")
  })
  
  cat("\nFitting model with stabilization settings (LIGHTWEIGHT MODE)...\n")
  cat("  Iterations: 3000 (warmup: 1500)\n")
  cat("  adapt_delta: 0.95\n")
  cat("  max_treedepth: 12\n")
  cat("  Chains: 2 (reduced from 4 to prevent crashes)\n")
  cat("  Cores: 1 (sequential to avoid memory overload)\n")
  cat("  Explicit initialization: bs=log(1.3), ndt=log(0.18), bias=0\n\n")
  
  # Clean up memory before fitting
  gc(verbose = FALSE)
  
  fit_start <- Sys.time()
  
  # Fit model with stabilization settings (reduced for system safety)
  fit <- brm(
    formula = spec$formula,
    data = data,
    family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
    prior = spec$priors,
    chains = 2,  # Reduced from 4
    iter = 3000,  # Reduced from 6000
    warmup = 1500,  # Reduced from 3000
    cores = 1,  # Sequential to avoid memory overload
    init = stabilized_init,
    control = list(adapt_delta = 0.95, max_treedepth = 12),  # Slightly reduced
    backend = "cmdstanr",
    file = file.path("output/models", model_name),
    file_refit = "always",  # Always refit with new settings
    refresh = 200,  # More frequent updates
    seed = 123
  )
  
  fit_elapsed <- difftime(Sys.time(), fit_start, units = "mins")
  cat("✓ Model fitted (took", round(as.numeric(fit_elapsed), 1), "minutes)\n\n")
  
  # Clean up memory after fitting
  gc(verbose = FALSE)
  
  # =====================================================================
  # CONVERGENCE CHECKS
  # =====================================================================
  
  cat("Checking convergence diagnostics...\n")
  
  # Get R-hat values
  rhat_values <- rhat(fit)
  max_rhat <- max(rhat_values, na.rm = TRUE)
  
  # Get ESS ratios
  ess_ratios <- neff_ratio(fit)
  min_ess_ratio <- min(ess_ratios, na.rm = TRUE)
  
  # Get ESS values (absolute)
  ess_bulk <- ess_bulk(fit)
  ess_tail <- ess_tail(fit)
  min_ess_bulk <- min(ess_bulk, na.rm = TRUE)
  min_ess_tail <- min(ess_tail, na.rm = TRUE)
  
  cat("  Max R-hat:", round(max_rhat, 4), "\n")
  cat("  Min ESS ratio:", round(min_ess_ratio, 4), "\n")
  cat("  Min ESS (bulk):", round(min_ess_bulk, 0), "\n")
  cat("  Min ESS (tail):", round(min_ess_tail, 0), "\n")
  
  # Check convergence criteria
  convergence_failed <- FALSE
  if (max_rhat > 1.05) {
    cat("  ❌ CONVERGENCE FAILED: Max R-hat > 1.05\n")
    convergence_failed <- TRUE
  }
  
  if (min_ess_ratio < 0.1) {
    cat("  ❌ CONVERGENCE FAILED: Min ESS ratio < 0.1\n")
    convergence_failed <- TRUE
  }
  
  if (convergence_failed) {
    cat("\n⚠️  WARNING: Model did not converge!\n")
    cat("  Max R-hat:", max_rhat, "(threshold: 1.05)\n")
    cat("  Min ESS ratio:", min_ess_ratio, "(threshold: 0.1)\n")
    cat("  Model saved but convergence is poor.\n")
  } else {
    cat("\n✓ CONVERGENCE: PASSED\n")
  }
  
  # Return diagnostics
  list(
    model_name = model_name,
    max_rhat = max_rhat,
    min_ess_ratio = min_ess_ratio,
    min_ess_bulk = min_ess_bulk,
    min_ess_tail = min_ess_tail,
    converged = !convergence_failed,
    fit_time_minutes = as.numeric(fit_elapsed),
    fit = fit
  )
}

# =========================================================================
# FIT ALL MODELS
# =========================================================================

diagnostics <- list()

cat("NOTE: Fitting models sequentially to prevent system overload.\n")
cat("      Cleanup between models will help prevent crashes.\n\n")

for (i in seq_along(models_to_stabilize)) {
  model_name <- names(models_to_stabilize)[i]
  spec <- models_to_stabilize[[model_name]]
  
  cat(sprintf("\n>>> Processing model %d of %d: %s\n\n", 
              i, length(models_to_stabilize), model_name))
  
  # Clean up memory before each model
  if (i > 1) {
    cat("Cleaning up memory before next model...\n")
    gc(verbose = FALSE)
    Sys.sleep(2)  # Brief pause to let system recover
  }
  
  tryCatch({
    diag <- stabilize_model(model_name, spec, ddm_data)
    diagnostics[[model_name]] <- diag
    
    # Clean up the fit object from memory (keep diagnostics)
    if ("fit" %in% names(diag)) {
      diag$fit <- NULL  # Remove large fit object
    }
    
    # Force garbage collection after each model
    gc(verbose = FALSE)
    
  }, error = function(e) {
    cat("❌ ERROR fitting", model_name, ":", e$message, "\n\n")
    diagnostics[[model_name]] <- list(
      model_name = model_name,
      error = e$message,
      converged = FALSE
    )
    # Clean up on error too
    gc(verbose = FALSE)
  })
}

# =========================================================================
# SAVE DIAGNOSTICS
# =========================================================================

cat("\n")
cat("================================================================================\n")
cat("CONVERGENCE DIAGNOSTICS SUMMARY\n")
cat("================================================================================\n\n")

# Create summary data frame
diagnostic_summary <- data.frame(
  model = character(),
  max_rhat = numeric(),
  min_ess_ratio = numeric(),
  min_ess_bulk = numeric(),
  min_ess_tail = numeric(),
  converged = logical(),
  fit_time_minutes = numeric(),
  stringsAsFactors = FALSE
)

for (model_name in names(diagnostics)) {
  diag <- diagnostics[[model_name]]
  
  if (!is.null(diag$error)) {
    diagnostic_summary <- rbind(diagnostic_summary, data.frame(
      model = model_name,
      max_rhat = NA,
      min_ess_ratio = NA,
      min_ess_bulk = NA,
      min_ess_tail = NA,
      converged = FALSE,
      fit_time_minutes = NA,
      stringsAsFactors = FALSE
    ))
    next
  }
  
  diagnostic_summary <- rbind(diagnostic_summary, data.frame(
    model = model_name,
    max_rhat = diag$max_rhat,
    min_ess_ratio = diag$min_ess_ratio,
    min_ess_bulk = diag$min_ess_bulk,
    min_ess_tail = diag$min_ess_tail,
    converged = diag$converged,
    fit_time_minutes = diag$fit_time_minutes,
    stringsAsFactors = FALSE
  ))
}

print(diagnostic_summary)

# Save to CSV
csv_file <- "output/diagnostics/convergence_report.csv"
write.csv(diagnostic_summary, file = csv_file, row.names = FALSE)

cat("\n✓ Diagnostics saved to:", csv_file, "\n\n")

# Summary
n_converged <- sum(diagnostic_summary$converged, na.rm = TRUE)
n_total <- nrow(diagnostic_summary)

cat("================================================================================\n")
cat("STABILIZATION COMPLETE\n")
cat("================================================================================\n")
cat("Converged:", n_converged, "of", n_total, "models\n")
cat("Completed:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

if (n_converged < n_total) {
  cat("⚠️  WARNING: Some models did not converge!\n")
  cat("Check convergence_report.csv for details.\n\n")
}

cat("Models saved to: output/models/\n")
cat("  (Old models overwritten with stabilized versions)\n\n")

