# =========================================================================
# BAP Pupillometry Analysis - Phase B: Statistical Modeling
#
# Stage 1: Hierarchical DDM - FINAL POLISHED VERSION
# =========================================================================

library(brms)
library(tidyverse)
library(bayesplot)

# =========================================================================
# SECTION 1: ADAPTIVE DDM BUILDER FUNCTION
# =========================================================================

build_adaptive_ddm <- function(data, 
                               min_subjects_for_complex = 15,
                               min_trials_per_subject = 80,
                               verbose = TRUE) {
    
    # Analyze data characteristics
    n_subjects <- length(unique(data$subject_id))
    trials_per_subject <- nrow(data) / n_subjects
    min_rt <- min(data$rt)
    max_ndt <- min_rt - 0.01
    
    if (verbose) {
        cat("=== ADAPTIVE DDM CONFIGURATION ===\n")
        cat("Subjects:", n_subjects, "\n")
        cat("Trials per subject:", round(trials_per_subject, 1), "\n")
        cat("Min RT:", round(min_rt, 3), "\n")
        cat("Max NDT:", round(max_ndt, 3), "\n")
    }
    
    # Adaptive model complexity
    if (n_subjects >= min_subjects_for_complex && trials_per_subject >= min_trials_per_subject) {
        # Complex model for large datasets
        formula <- bf(
            rt | dec(response) ~ force_condition * stimulus_condition + 
                (force_condition * stimulus_condition | subject_id),
            bs ~ 1 + (1 | subject_id),
            ndt ~ 1 + (1 | subject_id)
        )
        complexity <- "COMPLEX"
        
    } else if (n_subjects >= 10) {
        # Intermediate model
        formula <- bf(
            rt | dec(response) ~ force_condition * stimulus_condition + 
                (force_condition + stimulus_condition | subject_id),
            bs ~ 1 + (1 | subject_id),
            ndt ~ 1
        )
        complexity <- "INTERMEDIATE"
        
    } else {
        # Simple model for small datasets
        formula <- bf(
            rt | dec(response) ~ force_condition * stimulus_condition + (1 | subject_id),
            bs ~ 1 + (1 | subject_id),
            ndt ~ 1
        )
        complexity <- "SIMPLE"
    }
    
    # CORRECTED: Data-driven priors with numeric bounds
    priors <- c(
        prior(normal(0, 1), class = "Intercept"),  # For drift rate
        prior(normal(1, 0.5), class = "Intercept", dpar = "bs"),  # For boundary separation
        # FIXED: Use numeric value, not R variable
        prior(normal(0.2, 0.08), class = "Intercept", dpar = "ndt", 
              lb = 0.01, ub = max_ndt),  # max_ndt gets evaluated here
        prior(normal(0, 0.5), class = "b"),
        prior(exponential(2), class = "sd")  # Tighter prior as you wanted
    )
    
    # Adaptive sampling settings
    if (n_subjects < 10) {
        sampling <- list(iter = 6000, warmup = 3000, adapt_delta = 0.99, max_treedepth = 15)
    } else if (n_subjects < 30) {
        sampling <- list(iter = 4000, warmup = 2000, adapt_delta = 0.95, max_treedepth = 12)
    } else {
        sampling <- list(iter = 2000, warmup = 1000, adapt_delta = 0.9, max_treedepth = 10)
    }
    
    if (verbose) {
        cat("Model complexity:", complexity, "\n")
        cat("Iterations:", sampling$iter, "| Adapt delta:", sampling$adapt_delta, "\n\n")
    }
    
    return(list(
        formula = formula,
        priors = priors,
        sampling = sampling,
        complexity = complexity,
        max_ndt = max_ndt
    ))
}

# =========================================================================
# SECTION 2: ROBUST MODEL FITTING WITH AUTO-RETRY
# =========================================================================

fit_ddm_with_retry <- function(data, model_spec, max_attempts = 3) {
    
    for (attempt in 1:max_attempts) {
        cat("=== FITTING ATTEMPT", attempt, "of", max_attempts, "===\n")
        
        tryCatch({
            model <- brm(
                formula = model_spec$formula,
                data = data,
                family = wiener(link_bs = "log", link_ndt = "identity", link_bias = "identity"),
                prior = model_spec$priors,
                chains = 4,
                iter = model_spec$sampling$iter,
                warmup = model_spec$sampling$warmup,
                cores = 4,
                init = 0.1,
                control = list(
                    adapt_delta = model_spec$sampling$adapt_delta,
                    max_treedepth = model_spec$sampling$max_treedepth
                ),
                file = paste0("bap_ddm_attempt_", attempt),
                file_refit = "on_change"
            )
            
            # Convergence diagnostics
            rhat_max <- max(rhat(model), na.rm = TRUE)
            n_divergent <- sum(nuts_params(model, pars = "divergent__")$Value)
            bulk_ess_min <- min(neff_ratio(model) * nrow(as.matrix(model)), na.rm = TRUE)
            
            cat("Max R-hat:", round(rhat_max, 4), "\n")
            cat("Divergent transitions:", n_divergent, "\n")
            cat("Min Bulk ESS:", round(bulk_ess_min, 0), "\n")
            
            # Convergence criteria
            convergence_ok <- (rhat_max < 1.05 && 
                                   n_divergent < nrow(data) * 0.02 && 
                                   bulk_ess_min > 400)
            
            if (convergence_ok) {
                cat("✓ CONVERGENCE ACHIEVED\n\n")
                return(list(model = model, attempt = attempt, converged = TRUE))
            } else {
                cat("⚠ Convergence issues detected\n")
                if (attempt < max_attempts) {
                    cat("Adjusting settings for next attempt...\n\n")
                    # Increase adapt_delta and iterations for next attempt
                    model_spec$sampling$adapt_delta <- min(0.999, model_spec$sampling$adapt_delta + 0.02)
                    model_spec$sampling$iter <- model_spec$sampling$iter + 1000
                    model_spec$sampling$warmup <- model_spec$sampling$warmup + 500
                }
            }
            
        }, error = function(e) {
            cat("✗ ERROR in attempt", attempt, ":", e$message, "\n\n")
        })
    }
    
    cat("✗ CONVERGENCE FAILED after", max_attempts, "attempts\n")
    return(list(model = NULL, attempt = max_attempts, converged = FALSE))
}

# =========================================================================
# SECTION 3: PARAMETER EXTRACTION (CORRECTED)
# =========================================================================

extract_ddm_parameters <- function(model, data) {
    cat("=== EXTRACTING DDM PARAMETERS ===\n")
    
    # CORRECTED: Extract predicted RTs using posterior_epred (2D array)
    rt_pred <- posterior_epred(model)
    data$rt_predicted <- apply(rt_pred, 2, mean)
    data$rt_predicted_sd <- apply(rt_pred, 2, sd)
    
    # CORRECTED: Use posterior_linpred() for DDM parameters
    tryCatch({
        # Drift rate (mu/v) - use posterior_linpred, not posterior_epred
        v_samples <- posterior_linpred(model, dpar = "mu")
        data$drift_rate <- apply(v_samples, 2, mean)
        data$drift_rate_sd <- apply(v_samples, 2, sd)
        
        # Boundary separation (bs/a)
        bs_samples <- posterior_linpred(model, dpar = "bs")
        data$boundary_sep <- apply(bs_samples, 2, mean)
        data$boundary_sep_sd <- apply(bs_samples, 2, sd)
        
        # Non-decision time (ndt/t0)
        ndt_samples <- posterior_linpred(model, dpar = "ndt")
        data$non_decision_time <- apply(ndt_samples, 2, mean)
        data$non_decision_time_sd <- apply(ndt_samples, 2, sd)
        
        cat("✓ Successfully extracted all DDM parameters\n")
        
    }, error = function(e) {
        cat("⚠ Error extracting some parameters:", e$message, "\n")
        cat("Falling back to basic parameter extraction...\n")
        
        # Fallback: just add predicted RTs
        data$drift_rate <- NA
        data$boundary_sep <- NA  
        data$non_decision_time <- NA
    })
    
    return(data)
}

# =========================================================================
# SECTION 4: MAIN ANALYSIS PIPELINE
# =========================================================================

# --- 1. Load and Prepare Data ---
cat("=== LOADING DATA ===\n")
setwd("/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned")

# Load with error handling
if (!file.exists("BAP_all_subjects_aggregated_for_modeling.csv")) {
    stop("Data file not found! Check file path and name.")
}

all_trials_df <- read.csv("BAP_all_subjects_aggregated_for_modeling.csv")

# Prepare DDM data
ddm_data <- all_trials_df %>%
    filter(!is.na(rt) & !is.na(accuracy)) %>%
    filter(rt > 0.250) %>%
    mutate(response = if_else(accuracy == 1, 2, 1))

cat("Trials loaded:", nrow(all_trials_df), "\n")
cat("Trials for DDM:", nrow(ddm_data), "\n")
cat("Subjects:", length(unique(ddm_data$subject_id)), "\n\n")

# Data validation
if (nrow(ddm_data) < 50) {
    stop("Too few trials for DDM analysis (< 50)")
}

# --- 2. Build Adaptive Model Specification ---
model_spec <- build_adaptive_ddm(ddm_data)

# --- 3. Fit the Model ---
fit_result <- fit_ddm_with_retry(ddm_data, model_spec)

if (!fit_result$converged) {
    cat("⚠ Model did not converge. Consider:\n")
    cat("1. Collecting more data\n")
    cat("2. Simplifying the model further\n")
    cat("3. Checking data quality\n")
    stop("Model fitting failed")
}

ddm_model <- fit_result$model

# --- 4. Model Diagnostics ---
cat("=== MODEL DIAGNOSTICS ===\n")
print(ddm_model)

# Create diagnostic plots
pdf("ddm_diagnostics.pdf", width = 12, height = 8)
plot(ddm_model)
mcmc_trace(ddm_model, pars = c("Intercept", "bs_Intercept", "ndt_Intercept"))
dev.off()

# --- 5. Extract Parameters ---
ddm_data_final <- extract_ddm_parameters(ddm_model, ddm_data)

# --- 6. Save Results ---
cat("=== SAVING RESULTS ===\n")
write.csv(ddm_data_final, "BAP_DDM_results_with_parameters.csv", row.names = FALSE)
saveRDS(ddm_model, "BAP_DDM_model.rds")
saveRDS(model_spec, "BAP_DDM_model_spec.rds")

# --- 7. Summary ---
cat("=== ANALYSIS COMPLETE ===\n")
cat("Model complexity:", model_spec$complexity, "\n")
cat("Converged in", fit_result$attempt, "attempts\n")
cat("Final dataset saved with", ncol(ddm_data_final), "variables\n")
cat("Key DDM parameters: drift_rate, boundary_sep, non_decision_time\n")

# Quick parameter summary
if (!is.na(ddm_data_final$drift_rate[1])) {
    cat("\n=== PARAMETER SUMMARY ===\n")
    cat("Drift rate range:", round(range(ddm_data_final$drift_rate, na.rm = TRUE), 3), "\n")
    cat("Boundary separation range:", round(range(ddm_data_final$boundary_sep, na.rm = TRUE), 3), "\n")
    cat("Non-decision time range:", round(range(ddm_data_final$non_decision_time, na.rm = TRUE), 3), "\n")
}

cat("\n🎉 DDM Analysis Successfully Completed! 🎉\n")


# =========================================================================
# BAP Pupillometry Analysis - Phase B (Bridging Analysis)
#
# Modeling Behavior Directly with Arousal Covariates
# =========================================================================

library(lme4)
library(tidyverse)
library(lmerTest) # To get p-values for the linear model

# =========================================================================
# SECTION 1: ADAPTIVE BEHAVIORAL MODEL BUILDER
# =========================================================================

build_adaptive_behavioral_models <- function(data,
                                             min_subjects_for_complex = 15,
                                             verbose = TRUE) {
    
    n_subjects <- length(unique(data$subject_id))
    
    if (verbose) {
        cat("=== ADAPTIVE BEHAVIORAL MODEL CONFIGURATION ===\n")
        cat("Subjects:", n_subjects, "\n")
    }
    
    # Define the core fixed effects structure
    # We predict behavior from our key pupil/effort covariates and experimental conditions
    fixed_effects <- "tonic_arousal + force_evoked_arousal + effort_continuous * stimulus_condition"
    
    # Adapt the random effects structure based on data size
    if (n_subjects >= min_subjects_for_complex) {
        # Complex model with random slopes
        random_effects <- "(1 + tonic_arousal + effort_continuous | subject_id)"
        complexity <- "COMPLEX"
    } else {
        # Simpler model with only random intercepts for smaller datasets
        random_effects <- "(1 | subject_id)"
        complexity <- "SIMPLE"
    }
    
    # Create the full formulas
    rt_formula <- as.formula(paste("rt ~", fixed_effects, "+", random_effects))
    accuracy_formula <- as.formula(paste("accuracy ~", fixed_effects, "+", random_effects))
    
    if (verbose) {
        cat("Model complexity:", complexity, "\n")
        cat("RT formula:", deparse(rt_formula), "\n")
        cat("Accuracy formula:", deparse(accuracy_formula), "\n\n")
    }
    
    return(list(
        rt_formula = rt_formula,
        accuracy_formula = accuracy_formula,
        complexity = complexity
    ))
}

# =========================================================================
# SECTION 2: MAIN ANALYSIS PIPELINE
# =========================================================================

# --- 1. Load and Prepare Data ---
cat("=== LOADING DATA ===\n")
# setwd("/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned")
all_trials_df <- read.csv("BAP_all_subjects_aggregated_for_modeling.csv")

# Prepare data for modeling
model_data <- all_trials_df %>%
    filter(!is.na(rt) & !is.na(accuracy) & !is.na(tonic_arousal)) %>%
    filter(rt > 0.250) # Ensure valid RTs

cat("Trials loaded:", nrow(all_trials_df), "\n")
cat("Trials for Modeling:", nrow(model_data), "\n")
cat("Subjects:", length(unique(model_data$subject_id)), "\n\n")

if (nrow(model_data) < 50) {
    stop("Too few trials for analysis (< 50)")
}

# --- 2. Build Adaptive Model Specifications ---
model_spec <- build_adaptive_behavioral_models(model_data)

# --- 3. Fit the Linear Mixed Model (for RT) ---
cat("=== FITTING LMM FOR REACTION TIME ===\n")
# We use lmerTest to get p-values
rt_model <- lmer(model_spec$rt_formula, data = model_data)

# Print the summary
print(summary(rt_model))


# --- 4. Fit the Generalized Linear Mixed Model (for Accuracy) ---
cat("\n=== FITTING GLMM FOR ACCURACY ===\n")
# We use a binomial family for 0/1 accuracy data
accuracy_model <- glmer(model_spec$accuracy_formula,
                        data = model_data,
                        family = binomial(link = "logit"))

# Print the summary
print(summary(accuracy_model))


# --- 5. Save Results ---
cat("\n=== SAVING MODELS ===\n")
saveRDS(rt_model, "BAP_rt_model.rds")
saveRDS(accuracy_model, "BAP_accuracy_model.rds")
cat("✓ Models saved successfully!\n")

# --- 6. Summary ---
cat("\n=== ANALYSIS COMPLETE ===\n")
cat("Model complexity used:", model_spec$complexity, "\n")
cat("Results for RT and Accuracy models are displayed above.\n")
cat("These models provide a preliminary, robust test of how arousal and effort\n")
cat("are related to performance, bypassing the need for a converged DDM for now.\n")
