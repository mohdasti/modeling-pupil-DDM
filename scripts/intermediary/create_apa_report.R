# =========================================================================
# CREATE APA-FORMATTED COMPREHENSIVE REPORT
# =========================================================================

library(dplyr)
library(readr)

# Load data
convergence <- read.csv("model_convergence_summary.csv")
parameters <- read.csv("model_parameter_estimates.csv")
detailed <- readRDS("model_statistics_detailed.rds")

# Start report
report <- c()

# Title
report <- c(report, "# Bayesian Drift Diffusion Model Analysis Results")
report <- c(report, "")
report <- c(report, "**Analysis Date:** November 2, 2024")
report <- c(report, "**Data:** 17,243 trials from response-signal detection task")
report <- c(report, "**Participants:** Older adults")
report <- c(report, "")
report <- c(report, "---")
report <- c(report, "")

# Executive Summary
report <- c(report, "## Executive Summary")
report <- c(report, "")
report <- c(report, "Nine Bayesian drift diffusion models (DDM) were fitted to investigate the effects of effort condition, difficulty level, and task type on decision-making parameters. All models were fitted using `brms` (Bürkner, 2017) with the Wiener likelihood function. Models included subject-level random effects on drift rate, boundary separation, and starting point bias. Non-decision time was modeled as a population-level parameter without random effects.")
report <- c(report, "")
report <- c(report, sprintf("- **Total models fitted:** %d (9 main models + per-task variants)", length(list.files("output/models", pattern = "\\.rds$"))))
report <- c(report, sprintf("- **Models with acceptable convergence:** %d of 9", sum(convergence$converged)))
report <- c(report, sprintf("- **Mean R-hat:** %.3f (range: %.3f - %.3f)", 
                            mean(convergence$rhat_max), min(convergence$rhat_max), max(convergence$rhat_max)))
report <- c(report, sprintf("- **Mean ESS ratio:** %.3f (range: %.3f - %.3f)", 
                            mean(convergence$ess_mean), min(convergence$ess_min), max(convergence$ess_mean)))
report <- c(report, "")
report <- c(report, "---")
report <- c(report, "")

# Model Convergence
report <- c(report, "## Model Convergence Diagnostics")
report <- c(report, "")
report <- c(report, "Convergence was assessed using the potential scale reduction factor (R-hat; Gelman & Rubin, 1992) and effective sample size (ESS; Vehtari et al., 2021). R-hat values < 1.05 indicate acceptable convergence, with < 1.01 indicating excellent convergence. ESS ratios > 0.1 indicate sufficient effective samples.")
report <- c(report, "")

# Create convergence table
conv_table <- convergence %>%
  mutate(
    rhat_status = case_when(
      rhat_max < 1.01 ~ "Excellent",
      rhat_max < 1.05 ~ "Acceptable",
      TRUE ~ "Concerning"
    ),
    ess_status = case_when(
      ess_min > 0.1 ~ "Good",
      ess_min > 0.05 ~ "Acceptable",
      TRUE ~ "Low"
    ),
    overall_status = case_when(
      converged ~ "✓ Converged",
      TRUE ~ "⚠ Needs attention"
    )
  ) %>%
  select(Model = model, `Max R-hat` = rhat_max, `Mean R-hat` = rhat_mean,
         `Min ESS Ratio` = ess_min, `Mean ESS Ratio` = ess_mean, Status = overall_status)

report <- c(report, "### Table 1. Convergence Diagnostics by Model")
report <- c(report, "")
report <- c(report, "| Model | Max R-hat | Mean R-hat | Min ESS Ratio | Mean ESS Ratio | Status |")
report <- c(report, "|-------|-----------|------------|---------------|----------------|--------|")
for (i in 1:nrow(conv_table)) {
  report <- c(report, sprintf("| %s | %.3f | %.3f | %.3f | %.3f | %s |",
                              conv_table$Model[i],
                              conv_table$`Max R-hat`[i],
                              conv_table$`Mean R-hat`[i],
                              conv_table$`Min ESS Ratio`[i],
                              conv_table$`Mean ESS Ratio`[i],
                              conv_table$Status[i]))
}
report <- c(report, "")

# Convergence assessment
report <- c(report, sprintf("**Convergence Summary:** %d models (%.0f%%) showed acceptable convergence (R-hat < 1.05 and ESS ratio > 0.05).", 
                            sum(convergence$converged), 
                            100 * sum(convergence$converged) / nrow(convergence)))
report <- c(report, "")
report <- c(report, "Models with convergence concerns (Model1_Baseline, Model2_Force, Model7_Task, Model8_Task_Additive) had R-hat values slightly above 1.05 or ESS ratios below 0.05, which may indicate that additional iterations or stronger priors are needed. However, R-hat values remain below 1.1, suggesting chains are mixing adequately for most practical purposes.")
report <- c(report, "")
report <- c(report, "---")
report <- c(report, "")

# Parameter Estimates
report <- c(report, "## Parameter Estimates")
report <- c(report, "")
report <- c(report, "Posterior parameter estimates are reported as means with 95% credible intervals (CI). For parameters on transformed scales (boundary separation and non-decision time on log scale, bias on logit scale), values are reported on the natural scale.")

# Extract key parameter estimates for each model
report <- c(report, "")

for (i in 1:length(detailed)) {
  model <- detailed[[i]]
  model_name <- model$model_name
  
  report <- c(report, paste0("### ", model_name))
  report <- c(report, "")
  
  # Key parameters
  if (length(model$key_parameters) > 0) {
    kp <- model$key_parameters
    
    # Drift intercept
    if ("drift_intercept" %in% names(kp)) {
      di <- kp$drift_intercept
      report <- c(report, sprintf("- **Drift rate (intercept):** *M* = %.3f, 95%% CI [%.3f, %.3f]", 
                                  di$mean, di$ci_lower, di$ci_upper))
    }
    
    # Boundary intercept
    if ("boundary_intercept" %in% names(kp)) {
      bi <- kp$boundary_intercept
      report <- c(report, sprintf("- **Boundary separation (intercept):** *M* = %.3f, 95%% CI [%.3f, %.3f]", 
                                  bi$mean, bi$ci_lower, bi$ci_upper))
    }
    
    # NDT intercept
    if ("ndt_intercept" %in% names(kp)) {
      ni <- kp$ndt_intercept
      report <- c(report, sprintf("- **Non-decision time (intercept):** *M* = %.3fs, 95%% CI [%.3fs, %.3fs]", 
                                  ni$mean, ni$ci_lower, ni$ci_upper))
    }
    
    # Effort effects
    if ("effort_effects" %in% names(kp)) {
      report <- c(report, "- **Effort condition effects:**")
      ee <- kp$effort_effects
      for (j in 1:nrow(ee)) {
        param_name <- rownames(ee)[j]
        clean_name <- gsub("effort_condition|b_|_", " ", param_name, ignore.case = TRUE)
        report <- c(report, sprintf("  - %s: *M* = %.3f, 95%% CI [%.3f, %.3f]", 
                                    clean_name, ee$Estimate[j], ee$`l-95% CI`[j], ee$`u-95% CI`[j]))
      }
    }
    
    # Difficulty effects
    if ("difficulty_effects" %in% names(kp)) {
      report <- c(report, "- **Difficulty level effects:**")
      de <- kp$difficulty_effects
      for (j in 1:nrow(de)) {
        param_name <- rownames(de)[j]
        clean_name <- gsub("difficulty_level|b_|_", " ", param_name, ignore.case = TRUE)
        report <- c(report, sprintf("  - %s: *M* = %.3f, 95%% CI [%.3f, %.3f]", 
                                    clean_name, de$Estimate[j], de$`l-95% CI`[j], de$`u-95% CI`[j]))
      }
    }
    
    # Task effects
    if ("task_effects" %in% names(kp)) {
      report <- c(report, "- **Task type effects:**")
      te <- kp$task_effects
      for (j in 1:nrow(te)) {
        param_name <- rownames(te)[j]
        clean_name <- gsub("task|b_|_", " ", param_name, ignore.case = TRUE)
        report <- c(report, sprintf("  - %s: *M* = %.3f, 95%% CI [%.3f, %.3f]", 
                                    clean_name, te$Estimate[j], te$`l-95% CI`[j], te$`u-95% CI`[j]))
      }
    }
  }
  
  report <- c(report, "")
}

report <- c(report, "---")
report <- c(report, "")

# Model Specifications
report <- c(report, "## Model Specifications")
report <- c(report, "")
report <- c(report, "All models were fitted using:")
report <- c(report, "- **Family:** Wiener diffusion model (`brms::wiener()`)")
report <- c(report, "- **Link functions:** Identity for drift rate, log for boundary separation and non-decision time, logit for starting point bias")
report <- c(report, "- **Prior specifications:** Literature-informed priors for older adults (Ratcliff & Tuerlinckx, 2002; Theisen et al., 2020)")
report <- c(report, "  - Drift rate: Normal(0, 1)")
report <- c(report, "  - Boundary separation: Normal(log(1.7), 0.30) on log scale")
report <- c(report, "  - Non-decision time: Normal(log(0.23), 0.20) on log scale (response-signal design)")
report <- c(report, "  - Starting point bias: Normal(0, 0.5) on logit scale")
report <- c(report, "- **MCMC specifications:** 4 chains, 2000 iterations (1000 warmup)")
report <- c(report, "- **Random effects:** Subject-level random intercepts on drift, boundary, and bias")
report <- c(report, "- **RT filtering:** 0.25-3.0 seconds")
report <- c(report, "")
report <- c(report, "### Model Descriptions")
report <- c(report, "")
report <- c(report, "1. **Model1_Baseline:** Intercept-only model with random subject effects")
report <- c(report, "2. **Model2_Force:** Effort condition effect on drift rate")
report <- c(report, "3. **Model3_Difficulty:** Difficulty level effect on drift rate")
report <- c(report, "4. **Model4_Additive:** Additive effects of effort condition and difficulty level")
report <- c(report, "5. **Model5_Interaction:** Effort condition × Difficulty level interaction")
report <- c(report, "6. **Model7_Task:** Task type (ADT/VDT) main effect")
report <- c(report, "7. **Model8_Task_Additive:** Additive effects of task, effort, and difficulty")
report <- c(report, "8. **Model9_Task_Intx:** Task × Effort and Task × Difficulty interactions")
report <- c(report, "9. **Model10_Param_v_bs:** Both drift rate and boundary separation estimated as functions of effort and difficulty")
report <- c(report, "")
report <- c(report, "---")
report <- c(report, "")

# Methodological Notes
report <- c(report, "## Methodological Notes")
report <- c(report, "")
report <- c(report, "### Response-Signal Design")
report <- c(report, "")
report <- c(report, "This analysis used a response-signal design, where reaction times are measured from the response signal rather than stimulus onset. This affects the interpretation of non-decision time, which reflects primarily motor execution and post-signal encoding rather than stimulus processing (Ratcliff, 2006). The non-decision time prior was therefore centered at 0.23s (230ms), lower than typical stimulus-onset designs (~350ms).")
report <- c(report, "")
report <- c(report, "### Prior Standardization")
report <- c(report, "")
report <- c(report, "All models used standardized, literature-justified priors based on meta-analytic estimates for older adults (Theisen et al., 2020) and DDM estimation best practices (Ratcliff & Tuerlinckx, 2002; Wabersich & Vandekerckhove, 2014).")
report <- c(report, "")
report <- c(report, "---")
report <- c(report, "")

# References
report <- c(report, "## References")
report <- c(report, "")
report <- c(report, "Bürkner, P.-C. (2017). brms: An R package for Bayesian multilevel models using Stan. *Journal of Statistical Software*, *80*(1), 1-28. https://doi.org/10.18637/jss.v080.i01")
report <- c(report, "")
report <- c(report, "Gelman, A., & Rubin, D. B. (1992). Inference from iterative simulation using multiple sequences. *Statistical Science*, *7*(4), 457-472. https://doi.org/10.1214/ss/1177011136")
report <- c(report, "")
report <- c(report, "Ratcliff, R. (2006). Modeling response signal and response time data. *Cognitive Psychology*, *53*(3), 195-237. https://doi.org/10.1016/j.cogpsych.2005.10.002")
report <- c(report, "")
report <- c(report, "Ratcliff, R., & Tuerlinckx, F. (2002). Estimating parameters of the diffusion model: Approaches to dealing with contaminant reaction times and parameter variability. *Psychonomic Bulletin & Review*, *9*(3), 438-481. https://doi.org/10.3758/BF03196302")
report <- c(report, "")
report <- c(report, "Theisen, M., Lerche, V., von Krause, M., & Voss, A. (2020). Age differences in diffusion model parameters: A meta-analysis. *Psychological Research*, *84*(7), 1854-1876. https://doi.org/10.1007/s00426-019-01164-5")
report <- c(report, "")
report <- c(report, "Vehtari, A., Gelman, A., Simpson, D., Carpenter, B., & Bürkner, P.-C. (2021). Rank-normalization, folding, and localization: An improved R̂ for assessing convergence of MCMC (with discussion). *Bayesian Analysis*, *16*(2), 667-718. https://doi.org/10.1214/20-BA1221")
report <- c(report, "")
report <- c(report, "Wabersich, D., & Vandekerckhove, J. (2014). The RWiener package: An R package providing distribution functions for the Wiener diffusion model. *The R Journal*, *6*(1), 49-56. https://doi.org/10.32614/RJ-2014-005")

# Write report
writeLines(report, "DDM_ANALYSIS_APA_REPORT.md")

cat("\n✅ APA-formatted report created: DDM_ANALYSIS_APA_REPORT.md\n\n")

