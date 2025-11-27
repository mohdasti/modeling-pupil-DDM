# =========================================================================
# EXTRACT COMPREHENSIVE MODEL STATISTICS
# =========================================================================
# Extracts detailed statistics from all DDM models for APA-formatted report
# =========================================================================

library(brms)
library(dplyr)
library(tidyr)

# Set working directory
if (!file.exists("output/models")) {
  if (file.exists("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")) {
    setwd("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")
  }
}

cat("Extracting comprehensive model statistics...\n\n")

# Model names
model_names <- c("Model1_Baseline", "Model2_Force", "Model3_Difficulty", 
                 "Model4_Additive", "Model5_Interaction", "Model7_Task",
                 "Model8_Task_Additive", "Model9_Task_Intx", "Model10_Param_v_bs")

# Storage for results
all_results <- list()
convergence_info <- list()
parameter_estimates <- list()

for (model_name in model_names) {
  cat("Processing", model_name, "...\n")
  
  model_file <- paste0("output/models/", model_name, ".rds")
  
  if (!file.exists(model_file)) {
    cat("  ⚠️  File not found\n")
    next
  }
  
  tryCatch({
    # Load model
    model <- readRDS(model_file)
    
    # Extract summary
    model_summary <- summary(model)
    
    # Convergence diagnostics
    rhat_vals <- brms::rhat(model)
    ess_vals <- brms::neff_ratio(model)
    
    convergence_info[[model_name]] <- data.frame(
      model = model_name,
      rhat_max = max(rhat_vals, na.rm = TRUE),
      rhat_mean = mean(rhat_vals, na.rm = TRUE),
      ess_min = min(ess_vals, na.rm = TRUE),
      ess_mean = mean(ess_vals, na.rm = TRUE),
      converged = max(rhat_vals, na.rm = TRUE) < 1.05 & min(ess_vals, na.rm = TRUE) > 0.05
    )
    
    # Extract posterior samples for key parameters
    posterior_samples <- as_draws_df(model)
    
    # Get parameter estimates (posterior means and credible intervals)
    fixed_effects <- model_summary$fixed
    
    # Create parameter summary
    param_summary <- data.frame(
      model = model_name,
      parameter = rownames(fixed_effects),
      estimate = fixed_effects[, "Estimate"],
      est_error = fixed_effects[, "Est.Error"],
      ci_lower = fixed_effects[, "l-95% CI"],
      ci_upper = fixed_effects[, "u-95% CI"]
    )
    
    parameter_estimates[[model_name]] <- param_summary
    
    # Extract key parameters for summary
    key_params <- list()
    
    # Drift rate (Intercept)
    if ("Intercept" %in% rownames(fixed_effects)) {
      key_params$drift_intercept <- list(
        mean = fixed_effects["Intercept", "Estimate"],
        ci_lower = fixed_effects["Intercept", "l-95% CI"],
        ci_upper = fixed_effects["Intercept", "u-95% CI"]
      )
    }
    
    # Boundary separation
    if ("Intercept" %in% rownames(fixed_effects[grepl("bs", rownames(fixed_effects)), ])) {
      bs_params <- fixed_effects[grepl("^bs_", rownames(fixed_effects)), , drop = FALSE]
      if (nrow(bs_params) > 0) {
        bs_intercept <- bs_params[grepl("Intercept", rownames(bs_params)), ]
        if (nrow(bs_intercept) > 0) {
          key_params$boundary_intercept <- list(
            mean = exp(bs_intercept[1, "Estimate"]),  # Back-transform from log
            ci_lower = exp(bs_intercept[1, "l-95% CI"]),
            ci_upper = exp(bs_intercept[1, "u-95% CI"])
          )
        }
      }
    }
    
    # Non-decision time
    ndt_params <- fixed_effects[grepl("^ndt_", rownames(fixed_effects)), , drop = FALSE]
    if (nrow(ndt_params) > 0) {
      ndt_intercept <- ndt_params[grepl("Intercept", rownames(ndt_params)), ]
      if (nrow(ndt_intercept) > 0) {
        key_params$ndt_intercept <- list(
          mean = exp(ndt_intercept[1, "Estimate"]),  # Back-transform from log
          ci_lower = exp(ndt_intercept[1, "l-95% CI"]),
          ci_upper = exp(ndt_intercept[1, "u-95% CI"])
        )
      }
    }
    
    # Effort effects (if present)
    effort_params <- fixed_effects[grepl("effort", rownames(fixed_effects), ignore.case = TRUE), , drop = FALSE]
    if (nrow(effort_params) > 0) {
      key_params$effort_effects <- effort_params
    }
    
    # Difficulty effects (if present)
    diff_params <- fixed_effects[grepl("difficulty", rownames(fixed_effects), ignore.case = TRUE), , drop = FALSE]
    if (nrow(diff_params) > 0) {
      key_params$difficulty_effects <- diff_params
    }
    
    # Task effects (if present)
    task_params <- fixed_effects[grepl("^task", rownames(fixed_effects), ignore.case = TRUE), , drop = FALSE]
    if (nrow(task_params) > 0) {
      key_params$task_effects <- task_params
    }
    
    all_results[[model_name]] <- list(
      model_name = model_name,
      convergence = convergence_info[[model_name]],
      key_parameters = key_params,
      all_parameters = param_summary,
      n_subjects = length(unique(posterior_samples$subject_id)),
      n_iterations = nrow(posterior_samples) / 4  # 4 chains
    )
    
    cat("  ✅ Extracted statistics\n")
    
  }, error = function(e) {
    cat("  ❌ Error:", e$message, "\n")
  })
}

# Save results
saveRDS(all_results, "model_statistics_detailed.rds")

# Create summary dataframes
convergence_df <- bind_rows(convergence_info)
write.csv(convergence_df, "model_convergence_summary.csv", row.names = FALSE)

param_df <- bind_rows(parameter_estimates)
write.csv(param_df, "model_parameter_estimates.csv", row.names = FALSE)

cat("\n✅ Statistics extraction complete!\n")
cat("  - Detailed results: model_statistics_detailed.rds\n")
cat("  - Convergence summary: model_convergence_summary.csv\n")
cat("  - Parameter estimates: model_parameter_estimates.csv\n\n")










