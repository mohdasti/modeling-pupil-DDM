#!/usr/bin/env Rscript
# =========================================================================
# DDM PARAMETER VALIDATION
# =========================================================================
# Validates that DDM parameter estimates are realistic and consistent with data
# Ensures parameters match experimental design constraints
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(posterior)
  library(dplyr)
})

# =========================================================================
# EXPECTED PARAMETER RANGES (from literature and experimental design)
# =========================================================================

# Drift rate (v) - identity link
EXPECTED_V_MIN <- -3.0  # Strong bias toward lower boundary
EXPECTED_V_MAX <- 5.0   # Strong evidence toward upper boundary
EXPECTED_V_STD_MIN <- -3.0  # Standard trials: allow negative drift (evidence for "Same")
EXPECTED_V_STD_MAX <- 1.0   # Standard trials: positive drift also possible (but less expected)

# Boundary separation (a/bs) - log link, so values are on log scale
EXPECTED_BS_MIN <- log(0.5)   # Very narrow boundaries
EXPECTED_BS_MAX <- log(3.0)   # Very wide boundaries
EXPECTED_BS_TYPICAL <- log(1.7)  # Typical for older adults
EXPECTED_BS_TOLERANCE <- 0.5     # ±0.5 on log scale

# Non-decision time (t₀/ndt) - log link
EXPECTED_NDT_MIN <- log(0.10)  # 100ms minimum
EXPECTED_NDT_MAX <- log(0.50)  # 500ms maximum
EXPECTED_NDT_TYPICAL <- log(0.23)  # 230ms typical for response-signal design
EXPECTED_NDT_TOLERANCE <- 0.15     # ±0.15 on log scale

# Helper functions (define BEFORE using them)
logit <- function(p) log(p / (1 - p))

# Analytical solution for probability of hitting upper boundary in Wiener process
# Returns probability of hitting UPPER boundary (1/Different) given drift v, boundary a, and bias z
# Formula: P(upper) = (exp(-2*v*a*(1-z)) - 1) / (exp(-2*v*a) - 1)
# When v ≈ 0, use limit: P(upper) = z
prob_upper_analytical <- function(v, a, z) {
  # Handle edge case where v is exactly 0 (L'Hopital's rule)
  if (abs(v) < 1e-5) {
    return(z)
  }
  
  # Standard Wiener formula (brms/rtdists uses diffusion coefficient s=1 by default)
  # P(upper) = (exp(-2*v*a*(1-z)) - 1) / (exp(-2*v*a) - 1)
  
  # Calculate terms
  term_numerator <- exp(-2 * v * a * (1 - z)) - 1
  term_denominator <- exp(-2 * v * a) - 1
  
  # Avoid division by zero (shouldn't happen with v ≠ 0, but safety check)
  if (abs(term_denominator) < 1e-10) {
    return(z)  # Fallback to bias-only
  }
  
  prob <- term_numerator / term_denominator
  
  # Ensure probability is in valid range [0, 1]
  prob <- pmax(0, pmin(1, prob))
  
  return(prob)
}

# Starting point bias (z) - logit link
EXPECTED_BIAS_MIN <- -2.0  # Strong bias toward lower boundary (logit scale)
EXPECTED_BIAS_MAX <- 2.0   # Strong bias toward upper boundary (logit scale)
EXPECTED_BIAS_STD_MAX <- logit(0.3)  # Standard trials: z < 0.3 (probability scale)
EXPECTED_BIAS_STD_MIN <- logit(0.1)   # Standard trials: z > 0.1 (probability scale)

# =========================================================================
# VALIDATION FUNCTIONS
# =========================================================================

validate_drift_estimates <- function(fit, data, log_fn = cat) {
  # Validate drift rate estimates are realistic
  log_fn("\n=== VALIDATION: Drift Rate (v) Estimates ===\n")
  
  issues <- list()
  
  # Extract drift intercept
  v_samples <- posterior_samples(fit, pars = "^b_Intercept$")
  if (ncol(v_samples) == 0) {
    log_fn("  ⚠ Could not extract drift intercept\n")
    return(issues)
  }
  
  v_intercept <- v_samples[[1]]
  v_mean <- mean(v_intercept)
  v_q025 <- quantile(v_intercept, 0.025)
  v_q975 <- quantile(v_intercept, 0.975)
  
  log_fn(sprintf("  Drift intercept: mean=%.3f, 95%% CI=[%.3f, %.3f]\n", 
                 v_mean, v_q025, v_q975))
  
  # Check if within expected range
  if (v_mean < EXPECTED_V_MIN || v_mean > EXPECTED_V_MAX) {
    issues$v_out_of_range <- TRUE
    log_fn(sprintf("  ✗ Drift intercept (%.3f) outside expected range [%.1f, %.1f]\n", 
                   v_mean, EXPECTED_V_MIN, EXPECTED_V_MAX))
  } else {
    log_fn("  ✓ Drift intercept within expected range\n")
  }
  
  # Check Standard trial drift (if model includes difficulty)
  if ("difficulty_level" %in% names(data)) {
    std_trials <- data %>% filter(difficulty_level == "Standard")
    if (nrow(std_trials) > 0) {
      # Extract Standard drift (intercept + Standard effect if present)
      v_std_samples <- tryCatch({
        # Try to get Standard-specific drift
        std_pars <- posterior_samples(fit, pars = "^b_difficulty_levelStandard")
        if (ncol(std_pars) > 0) {
          v_intercept + std_pars[[1]]
        } else {
          v_intercept  # If no Standard effect, use intercept
        }
      }, error = function(e) v_intercept)
      
      v_std_mean <- mean(v_std_samples)
      
      log_fn(sprintf("  Standard trial drift: mean=%.3f\n", v_std_mean))
      
      # For Standard trials, negative drift is expected (evidence for "Same")
      # Allow negative values up to -3.0, positive up to 1.0
      if (v_std_mean < -3.0 || v_std_mean > 1.0) {
        issues$v_std_not_zero <- TRUE
        log_fn(sprintf("  ⚠ Standard trial drift (%.3f) outside expected range [-3.0, 1.0]\n", v_std_mean))
      } else if (v_std_mean < -0.5) {
        log_fn(sprintf("  ✓ Standard trial drift is negative (%.3f) - evidence for 'Same' responses\n", v_std_mean))
      } else if (abs(v_std_mean) < 0.5) {
        log_fn(sprintf("  ⚠ Standard trial drift (%.3f) is close to zero - may indicate misfit\n", v_std_mean))
        log_fn("    Expected: negative drift (evidence accumulation toward 'Same')\n")
      } else {
        log_fn(sprintf("  ⚠ Standard trial drift (%.3f) is positive - unexpected for Standard trials\n", v_std_mean))
      }
    }
  }
  
  return(issues)
}

validate_boundary_estimates <- function(fit, log_fn = cat) {
  # Validate boundary separation estimates are realistic
  log_fn("\n=== VALIDATION: Boundary Separation (a/bs) Estimates ===\n")
  
  issues <- list()
  
  # Extract boundary intercept (on log scale)
  bs_samples <- posterior_samples(fit, pars = "^b_bs_Intercept")
  if (ncol(bs_samples) == 0) {
    log_fn("  ⚠ Could not extract boundary intercept\n")
    return(issues)
  }
  
  bs_log <- bs_samples[[1]]
  bs_mean_log <- mean(bs_log)
  bs_mean_prob <- exp(bs_mean_log)  # Convert to probability scale
  
  bs_q025 <- quantile(bs_log, 0.025)
  bs_q975 <- quantile(bs_log, 0.975)
  
  log_fn(sprintf("  Boundary intercept (log scale): mean=%.3f, 95%% CI=[%.3f, %.3f]\n", 
                 bs_mean_log, bs_q025, bs_q975))
  log_fn(sprintf("  Boundary intercept (probability scale): mean=%.3f\n", bs_mean_prob))
  
  # Check if within expected range
  if (bs_mean_log < EXPECTED_BS_MIN || bs_mean_log > EXPECTED_BS_MAX) {
    issues$bs_out_of_range <- TRUE
    log_fn(sprintf("  ✗ Boundary intercept (%.3f) outside expected range [%.2f, %.2f]\n", 
                   bs_mean_log, EXPECTED_BS_MIN, EXPECTED_BS_MAX))
  } else {
    log_fn("  ✓ Boundary intercept within expected range\n")
  }
  
  # Check if close to typical value
  if (abs(bs_mean_log - EXPECTED_BS_TYPICAL) > EXPECTED_BS_TOLERANCE) {
    issues$bs_atypical <- TRUE
    log_fn(sprintf("  ⚠ Boundary intercept (%.3f) differs from typical (%.3f)\n", 
                   bs_mean_log, EXPECTED_BS_TYPICAL))
  } else {
    log_fn(sprintf("  ✓ Boundary intercept close to typical value (%.3f)\n", EXPECTED_BS_TYPICAL))
  }
  
  return(issues)
}

validate_ndt_estimates <- function(fit, data, log_fn = cat) {
  # Validate non-decision time estimates are realistic
  log_fn("\n=== VALIDATION: Non-Decision Time (t₀/ndt) Estimates ===\n")
  
  issues <- list()
  
  # Extract NDT intercept (on log scale)
  ndt_samples <- posterior_samples(fit, pars = "^b_ndt_Intercept")
  if (ncol(ndt_samples) == 0) {
    log_fn("  ⚠ Could not extract NDT intercept\n")
    return(issues)
  }
  
  ndt_log <- ndt_samples[[1]]
  ndt_mean_log <- mean(ndt_log)
  ndt_mean_prob <- exp(ndt_mean_log)  # Convert to seconds
  
  ndt_q025 <- quantile(ndt_log, 0.025)
  ndt_q975 <- quantile(ndt_log, 0.975)
  
  log_fn(sprintf("  NDT intercept (log scale): mean=%.3f, 95%% CI=[%.3f, %.3f]\n", 
                 ndt_mean_log, ndt_q025, ndt_q975))
  log_fn(sprintf("  NDT intercept (seconds): mean=%.3f\n", ndt_mean_prob))
  
  # Check if within expected range
  if (ndt_mean_log < EXPECTED_NDT_MIN || ndt_mean_log > EXPECTED_NDT_MAX) {
    issues$ndt_out_of_range <- TRUE
    log_fn(sprintf("  ✗ NDT intercept (%.3f) outside expected range [%.2f, %.2f]\n", 
                   ndt_mean_log, EXPECTED_NDT_MIN, EXPECTED_NDT_MAX))
  } else {
    log_fn("  ✓ NDT intercept within expected range\n")
  }
  
  # Check if NDT is less than minimum RT
  min_rt <- min(data$rt, na.rm = TRUE)
  if (ndt_mean_prob >= min_rt) {
    issues$ndt_exceeds_min_rt <- TRUE
    log_fn(sprintf("  ✗ NDT (%.3fs) exceeds minimum RT (%.3fs) - IMPOSSIBLE!\n", 
                   ndt_mean_prob, min_rt))
  } else {
    log_fn(sprintf("  ✓ NDT (%.3fs) is less than minimum RT (%.3fs)\n", 
                   ndt_mean_prob, min_rt))
  }
  
  # Check if close to typical value
  if (abs(ndt_mean_log - EXPECTED_NDT_TYPICAL) > EXPECTED_NDT_TOLERANCE) {
    issues$ndt_atypical <- TRUE
    log_fn(sprintf("  ⚠ NDT intercept (%.3f) differs from typical (%.3f)\n", 
                   ndt_mean_log, EXPECTED_NDT_TYPICAL))
  } else {
    log_fn(sprintf("  ✓ NDT intercept close to typical value (%.3f)\n", EXPECTED_NDT_TYPICAL))
  }
  
  return(issues)
}

validate_bias_estimates <- function(fit, data, log_fn = cat) {
  # Validate bias estimates are realistic and match data
  log_fn("\n=== VALIDATION: Starting-Point Bias (z) Estimates ===\n")
  
  issues <- list()
  
  # Extract bias intercept (on logit scale)
  bias_samples <- posterior_samples(fit, pars = "^b_bias_Intercept")
  if (ncol(bias_samples) == 0) {
    log_fn("  ⚠ Could not extract bias intercept\n")
    return(issues)
  }
  
  bias_logit <- bias_samples[[1]]
  bias_mean_logit <- mean(bias_logit)
  bias_mean_prob <- plogis(bias_mean_logit)  # Convert to probability scale
  
  bias_q025 <- quantile(bias_logit, 0.025)
  bias_q975 <- quantile(bias_logit, 0.975)
  
  log_fn(sprintf("  Bias intercept (logit scale): mean=%.3f, 95%% CI=[%.3f, %.3f]\n", 
                 bias_mean_logit, bias_q025, bias_q975))
  log_fn(sprintf("  Bias intercept (probability scale): mean=%.3f\n", bias_mean_prob))
  
  # Check if within expected range
  if (bias_mean_logit < EXPECTED_BIAS_MIN || bias_mean_logit > EXPECTED_BIAS_MAX) {
    issues$bias_out_of_range <- TRUE
    log_fn(sprintf("  ✗ Bias intercept (%.3f) outside expected range [%.1f, %.1f]\n", 
                   bias_mean_logit, EXPECTED_BIAS_MIN, EXPECTED_BIAS_MAX))
  } else {
    log_fn("  ✓ Bias intercept within expected range\n")
  }
  
  # Check Standard trial bias (CRITICAL VALIDATION)
  # FIXED: Now uses analytical solution when drift is non-zero
  if ("difficulty_level" %in% names(data)) {
    std_trials <- data %>% filter(difficulty_level == "Standard")
    if (nrow(std_trials) > 0) {
      prop_same_data <- 1 - mean(std_trials$dec_upper, na.rm = TRUE)
      prop_upper_data <- mean(std_trials$dec_upper, na.rm = TRUE)  # "Different" proportion
      
      # Extract Standard-specific bias if present
      std_bias_samples <- tryCatch({
        std_pars <- posterior_samples(fit, pars = "^b_bias_difficulty_levelStandard")
        if (ncol(std_pars) > 0) {
          bias_logit + std_pars[[1]]
        } else {
          bias_logit  # If no Standard effect, use intercept
        }
      }, error = function(e) bias_logit)
      
      std_bias_mean_logit <- mean(std_bias_samples)
      std_bias_mean_prob <- plogis(std_bias_mean_logit)
      
      # Extract drift for Standard trials
      v_samples <- posterior_samples(fit, pars = "^b_Intercept")
      if (ncol(v_samples) == 0) {
        log_fn("  ⚠ Could not extract drift intercept for validation\n")
      } else {
        v_intercept <- v_samples[[1]]
        v_std_mean <- mean(v_intercept)  # Standard trials use intercept
        
        # Extract boundary
        bs_samples <- posterior_samples(fit, pars = "^b_bs_Intercept")
        if (ncol(bs_samples) > 0) {
          a_std_mean <- exp(mean(bs_samples[[1]]))  # Convert from log scale
          
          log_fn(sprintf("  Standard trial parameters: v=%.3f, a=%.3f, z=%.3f\n", 
                         v_std_mean, a_std_mean, std_bias_mean_prob))
          log_fn(sprintf("  Standard trial data - Proportion 'Different': %.3f (%.1f%%)\n", 
                         prop_upper_data, 100 * prop_upper_data))
          log_fn(sprintf("  Standard trial data - Proportion 'Same': %.3f (%.1f%%)\n", 
                         prop_same_data, 100 * prop_same_data))
          
          # Compute predicted proportion using analytical solution
          # P(upper) = (exp(-2*v*a*(1-z)) - 1) / (exp(-2*v*a) - 1)
          pred_prop_upper <- prob_upper_analytical(v_std_mean, a_std_mean, std_bias_mean_prob)
          
          log_fn(sprintf("  Predicted proportion 'Different' (from v+a+z): %.3f (%.1f%%)\n", 
                         pred_prop_upper, 100 * pred_prop_upper))
          
          # Compare predicted vs observed
          diff <- abs(pred_prop_upper - prop_upper_data)
          
          if (diff < 0.05) {
            log_fn(sprintf("  ✓ VALIDATION PASSED: Model parameters accurately predict choice proportions (diff=%.3f)\n", diff))
            if (v_std_mean < -0.5 && std_bias_mean_prob > 0.5) {
              log_fn("    Note: Negative drift overrides bias to produce 'Same' responses\n")
            }
          } else if (diff < 0.10) {
            issues$bias_mismatch_data <- TRUE
            log_fn(sprintf("  ⚠ VALIDATION WARNING: Small mismatch between predicted and observed (diff=%.3f)\n", diff))
            log_fn("    Model may need refinement, but parameters are reasonable\n")
          } else {
            issues$bias_mismatch_data <- TRUE
            log_fn(sprintf("  ✗ VALIDATION FAILED: Large mismatch between predicted and observed (diff=%.3f)\n", diff))
            log_fn("    Review model specification or data coding\n")
          }
        } else {
          log_fn("  ⚠ Could not extract boundary intercept for validation\n")
        }
      }
      
      log_fn(sprintf("  Standard trial bias (probability scale): mean=%.3f\n", std_bias_mean_prob))
    }
  }
  
  return(issues)
}

validate_convergence <- function(fit, log_fn = cat) {
  # Validate model convergence diagnostics
  log_fn("\n=== VALIDATION: Model Convergence ===\n")
  
  issues <- list()
  
  tryCatch({
    fit_summary <- summary(fit)
    
    # Extract diagnostics
    max_rhat <- max(fit_summary$fixed$Rhat, na.rm = TRUE)
    min_ess_bulk <- min(fit_summary$fixed$Bulk_ESS, na.rm = TRUE)
    min_ess_tail <- min(fit_summary$fixed$Tail_ESS, na.rm = TRUE)
    
    log_fn(sprintf("  Max Rhat: %.4f (target: ≤ 1.01)\n", max_rhat))
    log_fn(sprintf("  Min Bulk ESS: %.0f (target: ≥ 400)\n", min_ess_bulk))
    log_fn(sprintf("  Min Tail ESS: %.0f (target: ≥ 400)\n", min_ess_tail))
    
    # Check convergence
    if (max_rhat > 1.01) {
      issues$high_rhat <- max_rhat
      log_fn("  ✗ Model may not have converged (Rhat > 1.01)\n")
    } else {
      log_fn("  ✓ Rhat indicates convergence\n")
    }
    
    if (min_ess_bulk < 400) {
      issues$low_ess_bulk <- min_ess_bulk
      log_fn("  ✗ Low effective sample size (Bulk ESS < 400)\n")
    } else {
      log_fn("  ✓ Bulk ESS sufficient\n")
    }
    
    if (min_ess_tail < 400) {
      issues$low_ess_tail <- min_ess_tail
      log_fn("  ✗ Low effective sample size (Tail ESS < 400)\n")
    } else {
      log_fn("  ✓ Tail ESS sufficient\n")
    }
    
    # Check for divergent transitions
    sampler_params <- rstan::get_sampler_params(fit$fit, inc_warmup = FALSE)
    n_divergent <- sum(sapply(sampler_params, function(x) sum(x[, "divergent__"])))
    
    log_fn(sprintf("  Divergent transitions: %d (target: 0)\n", n_divergent))
    
    if (n_divergent > 0) {
      issues$divergent_transitions <- n_divergent
      log_fn("  ✗ Model has divergent transitions - may need tighter priors or higher adapt_delta\n")
    } else {
      log_fn("  ✓ No divergent transitions\n")
    }
    
  }, error = function(e) {
    log_fn("  ⚠ Could not extract convergence diagnostics:", e$message, "\n")
    issues$diagnostics_error <- TRUE
  })
  
  return(issues)
}

# =========================================================================
# MAIN VALIDATION FUNCTION
# =========================================================================

validate_ddm_model <- function(fit, data, log_file = NULL) {
  # Run all DDM parameter validations
  
  # Setup logging
  if (!is.null(log_file)) {
    log_con <- file(log_file, "w")
    log_fn <- function(...) {
      msg <- paste(..., collapse = "")
      cat(msg)
      cat(msg, file = log_con)
    }
  } else {
    log_fn <- cat
  }
  
  on.exit(if (!is.null(log_file)) close(log_con))
  
  log_fn("=" %+% strrep("=", 78), "\n")
  log_fn("DDM MODEL PARAMETER VALIDATION REPORT\n")
  log_fn("=" %+% strrep("=", 78), "\n")
  log_fn("Timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
  
  all_issues <- list()
  
  all_issues$convergence <- validate_convergence(fit, log_fn)
  all_issues$drift <- validate_drift_estimates(fit, data, log_fn)
  all_issues$boundary <- validate_boundary_estimates(fit, log_fn)
  all_issues$ndt <- validate_ndt_estimates(fit, data, log_fn)
  all_issues$bias <- validate_bias_estimates(fit, data, log_fn)
  
  # Summary
  log_fn("\n" %+% strrep("=", 78), "\n")
  log_fn("VALIDATION SUMMARY\n")
  log_fn(strrep("=", 78), "\n")
  
  total_issues <- sum(sapply(all_issues, function(x) length(x)))
  
  if (total_issues == 0) {
    log_fn("✓ ALL VALIDATIONS PASSED\n")
    log_fn("Model parameters are realistic and consistent with data.\n")
    return(list(success = TRUE, issues = all_issues))
  } else {
    log_fn(sprintf("⚠ %d validation issues found\n", total_issues))
    log_fn("Review the detailed report above.\n")
    return(list(success = FALSE, issues = all_issues))
  }
}

# Helper function
`%+%` <- function(x, y) paste0(x, y)

# If run as script
if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 2) {
    cat("Usage: Rscript validate_ddm_parameters.R <model_file.rds> <data_file.csv> [log_file]\n")
    quit(status = 1)
  }
  
  model_file <- args[1]
  data_file <- args[2]
  log_file <- if (length(args) >= 3) args[3] else NULL
  
  fit <- readRDS(model_file)
  data <- read_csv(data_file, show_col_types = FALSE)
  
  result <- validate_ddm_model(fit, data, log_file)
  quit(status = ifelse(result$success, 0, 1))
}

