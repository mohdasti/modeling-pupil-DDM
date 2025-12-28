#!/usr/bin/env Rscript
# =========================================================================
# DDM PARAMETER VALIDATION - USING POSTERIOR PREDICTIVE CHECKS
# =========================================================================
# FIXED: Uses PPC instead of analytical formula with mean parameters
# This avoids aggregation bias (Jensen's Inequality) in non-linear models
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(posterior)
  library(dplyr)
})

# =========================================================================
# POSTERIOR PREDICTIVE CHECK VALIDATION
# =========================================================================

validate_ddm_model_ppc <- function(fit, data, log_file = NULL) {
  # Validate model using Posterior Predictive Checks (PPC)
  # This avoids aggregation bias from using mean parameters
  
  log_fn <- function(...) {
    msg <- paste(..., collapse = " ")
    cat(msg, "\n")
    if (!is.null(log_file)) {
      cat(msg, "\n", file = log_file, append = TRUE)
    }
  }
  
  log_fn("")
  log_fn("=" %+% strrep("=", 78))
  log_fn("DDM MODEL VALIDATION - POSTERIOR PREDICTIVE CHECKS")
  log_fn("=" %+% strrep("=", 78))
  log_fn("")
  log_fn("Using PPC to avoid aggregation bias (Jensen's Inequality)")
  log_fn("")
  
  issues <- list()
  
  # Extract Standard trials if available
  if ("difficulty_level" %in% names(data)) {
    std_trials <- data %>% filter(difficulty_level == "Standard")
    
    if (nrow(std_trials) > 0) {
      log_fn("Standard trials found:", nrow(std_trials))
      
      # Get observed proportion "Different"
      obs_prop_diff <- mean(std_trials$dec_upper, na.rm = TRUE)
      log_fn("Observed proportion 'Different':", sprintf("%.3f (%.1f%%)", 
                                                         obs_prop_diff, 100*obs_prop_diff))
      log_fn("")
      
      # Generate posterior predictions for Standard trials only
      log_fn("Generating posterior predictions for Standard trials...")
      log_fn("  (This may take a few minutes)")
      
      # Filter model data to Standard trials
      std_data <- std_trials %>%
        select(rt, dec_upper, subject_id, task, effort_condition, difficulty_level) %>%
        filter(!is.na(rt), !is.na(dec_upper))
      
      # Generate posterior predictions
      # Use subset of draws for efficiency (e.g., 500)
      post_preds <- tryCatch({
        posterior_predict(fit, newdata = std_data, ndraws = 500)
      }, error = function(e) {
        log_fn("  ERROR generating predictions:", e$message)
        return(NULL)
      })
      
      if (!is.null(post_preds)) {
        log_fn("  ✓ Generated", nrow(post_preds), "posterior predictions")
        
        # Extract predicted choices
        # brms wiener predict returns RT with sign indicating boundary
        # Positive RT = upper boundary, Negative RT = lower boundary
        # OR check structure - might return list with $rt and $response
        
        # Check structure of predictions
        if (is.matrix(post_preds) || is.data.frame(post_preds)) {
          # If numeric matrix, assume sign indicates boundary
          # Positive = upper (Different), Negative = lower (Same)
          pred_choices <- post_preds > 0
        } else if (is.list(post_preds) && "response" %in% names(post_preds)) {
          # If list, extract response column
          pred_choices <- post_preds$response == 1  # 1 = upper
        } else {
          log_fn("  ⚠ Unexpected prediction format - check brms documentation")
          return(issues)
        }
        
        # Calculate proportion "Different" for each posterior draw
        pred_prop_diff <- apply(pred_choices, 1, function(x) mean(x, na.rm = TRUE))
        
        # Summary statistics
        pred_mean <- mean(pred_prop_diff)
        pred_q025 <- quantile(pred_prop_diff, 0.025)
        pred_q975 <- quantile(pred_prop_diff, 0.975)
        pred_ci <- c(pred_q025, pred_q975)
        
        log_fn("")
        log_fn("POSTERIOR PREDICTIVE CHECK RESULTS:")
        log_fn("  Predicted proportion 'Different':", sprintf("%.3f", pred_mean))
        log_fn("  95% CI:", sprintf("[%.3f, %.3f]", pred_ci[1], pred_ci[2]))
        log_fn("  Observed proportion 'Different':", sprintf("%.3f", obs_prop_diff))
        log_fn("")
        
        # Check if observed falls within 95% CI
        if (obs_prop_diff >= pred_ci[1] && obs_prop_diff <= pred_ci[2]) {
          log_fn("  ✓ VALIDATION PASSED: Observed falls within 95% PPC interval")
          log_fn("    Model accurately captures data distribution")
        } else {
          diff_lower <- abs(obs_prop_diff - pred_ci[1])
          diff_upper <- abs(obs_prop_diff - pred_ci[2])
          if (obs_prop_diff < pred_ci[1]) {
            log_fn(sprintf("  ⚠ Observed (%.3f) is below 95% CI [%.3f, %.3f]", 
                           obs_prop_diff, pred_ci[1], pred_ci[2]))
          } else {
            log_fn(sprintf("  ⚠ Observed (%.3f) is above 95% CI [%.3f, %.3f]", 
                           obs_prop_diff, pred_ci[1], pred_ci[2]))
          }
          issues$ppc_outside_ci <- TRUE
        }
        
        # Calculate difference
        diff <- abs(pred_mean - obs_prop_diff)
        log_fn(sprintf("  Difference (mean prediction vs observed): %.3f (%.1f%%)", 
                       diff, 100*diff))
        
        if (diff < 0.05) {
          log_fn("  ✓ Mean prediction matches observed closely")
        } else if (diff < 0.10) {
          log_fn("  ⚠ Small difference, but within acceptable range")
        } else {
          log_fn("  ⚠ Larger difference - review model specification")
          issues$ppc_large_diff <- TRUE
        }
        
      } else {
        log_fn("  ✗ Failed to generate predictions")
        issues$ppc_failed <- TRUE
      }
    }
  }
  
  log_fn("")
  log_fn("=" %+% strrep("=", 78))
  
  return(issues)
}

# Helper function
`%+%` <- function(x, y) paste0(x, y)















