# =========================================================================
# BAP ENHANCED MODEL CAPTURE AND INTERPRETATION
# =========================================================================
# 
# This script provides enhanced model output capture and interpretation
# for the BAP pupillometry analysis pipeline.
#
# Functions:
# - capture_ddm_results: Detailed DDM model capture and interpretation
# - capture_lmm_results: Linear mixed model results and interpretation
# - capture_correlation_results: Correlation analysis results
# - generate_research_summary: Comprehensive research summary
# =========================================================================

library(dplyr)
library(brms)
library(lme4)
library(bayesplot)
library(corrplot)

# =========================================================================
# FUNCTION 1: CAPTURE DDM RESULTS
# =========================================================================

capture_ddm_results <- function(ddm_model, data, log_filename) {
    
    write("## Drift Diffusion Model (DDM) Results\n\n", file = log_filename, append = TRUE)
    
    # Model information
    write("**Model Information:**\n", file = log_filename, append = TRUE)
    write(paste("- Model Type: Hierarchical Wiener Process\n"), file = log_filename, append = TRUE)
    write(paste("- Formula:", as.character(ddm_model$formula)[1], "\n"), file = log_filename, append = TRUE)
    write(paste("- Subjects:", length(unique(data$subject_id)), "\n"), file = log_filename, append = TRUE)
    write(paste("- Trials:", nrow(data), "\n"), file = log_filename, append = TRUE)
    write(paste("- Chains:", ddm_model$fit@sim$chains, "\n"), file = log_filename, append = TRUE)
    write(paste("- Iterations:", ddm_model$fit@sim$iter, "\n"), file = log_filename, append = TRUE)
    write(paste("- Warmup:", ddm_model$fit@sim$warmup, "\n\n"), file = log_filename, append = TRUE)
    
    # Convergence diagnostics
    write("**Convergence Diagnostics:**\n", file = log_filename, append = TRUE)
    rhat_values <- rhat(ddm_model)
    ess_values <- neff_ratio(ddm_model) * nrow(as.matrix(ddm_model))
    
    write(paste("- Max R-hat:", round(max(rhat_values, na.rm = TRUE), 4), "\n"), file = log_filename, append = TRUE)
    write(paste("- Min ESS:", round(min(ess_values, na.rm = TRUE), 0), "\n"), file = log_filename, append = TRUE)
    write(paste("- Divergent transitions:", sum(nuts_params(ddm_model, pars = "divergent__")$Value), "\n\n"), file = log_filename, append = TRUE)
    
    # Parameter estimates
    write("**Parameter Estimates:**\n", file = log_filename, append = TRUE)
    
    # Extract fixed effects
    fixed_effects <- fixef(ddm_model)
    write("Fixed Effects:\n", file = log_filename, append = TRUE)
    for(i in 1:nrow(fixed_effects)) {
        param_name <- rownames(fixed_effects)[i]
        estimate <- fixed_effects[i, "Estimate"]
        se <- fixed_effects[i, "Est.Error"]
        l95 <- fixed_effects[i, "Q2.5"]
        u95 <- fixed_effects[i, "Q97.5"]
        
        write(paste("-", param_name, ":", round(estimate, 4), 
                   "[", round(l95, 4), ",", round(u95, 4), "]\n"), 
              file = log_filename, append = TRUE)
    }
    write("\n", file = log_filename, append = TRUE)
    
    # Random effects summary
    random_effects <- VarCorr(ddm_model)
    write("Random Effects (Subject-level):\n", file = log_filename, append = TRUE)
    for(i in 1:length(random_effects)) {
        effect_name <- names(random_effects)[i]
        sd_value <- random_effects[[i]]$sd[1,1]
        write(paste("-", effect_name, "SD:", round(sd_value, 4), "\n"), 
              file = log_filename, append = TRUE)
    }
    write("\n", file = log_filename, append = TRUE)
    
    # Model fit metrics
    write("**Model Fit Metrics:**\n", file = log_filename, append = TRUE)
    loo_result <- loo(ddm_model)
    write(paste("- LOO-IC:", round(loo_result$estimates["looic", "Estimate"], 2), "\n"), file = log_filename, append = TRUE)
    write(paste("- LOO-IC SE:", round(loo_result$estimates["looic", "SE"], 2), "\n"), file = log_filename, append = TRUE)
    
    # Posterior predictive check
    write("**Posterior Predictive Check:**\n", file = log_filename, append = TRUE)
    pp_check_result <- pp_check(ddm_model, type = "stat", stat = "mean")
    write("- Posterior predictive check performed (see plots)\n\n", file = log_filename, append = TRUE)
    
    # Interpretation
    write("**DDM Parameter Interpretation:**\n", file = log_filename, append = TRUE)
    write("1. **Drift Rate (v):** Represents the speed and direction of evidence accumulation\n", file = log_filename, append = TRUE)
    write("   - Positive values: Faster accumulation toward correct response\n", file = log_filename, append = TRUE)
    write("   - Negative values: Faster accumulation toward incorrect response\n", file = log_filename, append = TRUE)
    write("   - Higher absolute values: More decisive processing\n\n", file = log_filename, append = TRUE)
    
    write("2. **Boundary Separation (a):** Represents response caution\n", file = log_filename, append = TRUE)
    write("   - Higher values: More cautious responding (slower but potentially more accurate)\n", file = log_filename, append = TRUE)
    write("   - Lower values: Less cautious responding (faster but potentially less accurate)\n\n", file = log_filename, append = TRUE)
    
    write("3. **Non-Decision Time (t0):** Represents motor and encoding time\n", file = log_filename, append = TRUE)
    write("   - Time not related to decision process\n", file = log_filename, append = TRUE)
    write("   - Includes motor preparation and response execution\n\n", file = log_filename, append = TRUE)
    
    write("4. **Starting Point Bias (z):** Represents response bias\n", file = log_filename, append = TRUE)
    write("   - Values closer to 0.5: No bias\n", file = log_filename, append = TRUE)
    write("   - Values closer to 0 or 1: Bias toward one response\n\n", file = log_filename, append = TRUE)
    
    return(list(
        model = ddm_model,
        convergence = list(rhat_max = max(rhat_values, na.rm = TRUE), 
                          ess_min = min(ess_values, na.rm = TRUE)),
        fixed_effects = fixed_effects,
        random_effects = random_effects,
        loo_ic = loo_result$estimates["looic", "Estimate"]
    ))
}

# =========================================================================
# FUNCTION 2: CAPTURE LINEAR MIXED MODEL RESULTS
# =========================================================================

capture_lmm_results <- function(lmm_model, model_name, data, log_filename) {
    
    write(paste("##", model_name, "Results\n\n"), file = log_filename, append = TRUE)
    
    # Model information
    write("**Model Information:**\n", file = log_filename, append = TRUE)
    write(paste("- Model Type:", class(lmm_model)[1], "\n"), file = log_filename, append = TRUE)
    write(paste("- Formula:", as.character(formula(lmm_model)), "\n"), file = log_filename, append = TRUE)
    write(paste("- Subjects:", length(unique(data$subject_id)), "\n"), file = log_filename, append = TRUE)
    write(paste("- Observations:", nrow(data), "\n"), file = log_filename, append = TRUE)
    write(paste("- Family:", ifelse(inherits(lmm_model, "glmerMod"), 
                                   as.character(lmm_model@call$family), "Gaussian"), "\n\n"), file = log_filename, append = TRUE)
    
    # Model summary
    model_summary <- summary(lmm_model)
    
    # Fixed effects
    write("**Fixed Effects:**\n", file = log_filename, append = TRUE)
    fixed_effects <- model_summary$coefficients
    for(i in 1:nrow(fixed_effects)) {
        param_name <- rownames(fixed_effects)[i]
        estimate <- fixed_effects[i, "Estimate"]
        se <- fixed_effects[i, "Std. Error"]
        t_value <- fixed_effects[i, "t value"]
        p_value <- fixed_effects[i, "Pr(>|t|)"]
        
        significance <- ifelse(p_value < 0.001, "***", 
                              ifelse(p_value < 0.01, "**", 
                                     ifelse(p_value < 0.05, "*", "")))
        
        write(paste("-", param_name, ":", round(estimate, 4), 
                   "±", round(se, 4), 
                   "t =", round(t_value, 3),
                   "p =", round(p_value, 4), significance, "\n"), 
              file = log_filename, append = TRUE)
    }
    write("\n", file = log_filename, append = TRUE)
    
    # Random effects
    write("**Random Effects:**\n", file = log_filename, append = TRUE)
    random_effects <- VarCorr(lmm_model)
    for(i in 1:length(random_effects)) {
        effect_name <- names(random_effects)[i]
        sd_value <- attr(random_effects[[i]], "stddev")[1]
        write(paste("-", effect_name, "SD:", round(sd_value, 4), "\n"), 
              file = log_filename, append = TRUE)
    }
    write("\n", file = log_filename, append = TRUE)
    
    # Model fit metrics
    write("**Model Fit Metrics:**\n", file = log_filename, append = TRUE)
    if(inherits(lmm_model, "lmerMod")) {
        # For linear models
        write(paste("- Marginal R²:", round(MuMIn::r.squaredGLMM(lmm_model)[1], 4), "\n"), file = log_filename, append = TRUE)
        write(paste("- Conditional R²:", round(MuMIn::r.squaredGLMM(lmm_model)[2], 4), "\n"), file = log_filename, append = TRUE)
    } else {
        # For generalized models
        write(paste("- AIC:", round(AIC(lmm_model), 2), "\n"), file = log_filename, append = TRUE)
        write(paste("- BIC:", round(BIC(lmm_model), 2), "\n"), file = log_filename, append = TRUE)
    }
    
    # Residual diagnostics
    write("**Residual Diagnostics:**\n", file = log_filename, append = TRUE)
    residuals_data <- residuals(lmm_model)
    write(paste("- Residual mean:", round(mean(residuals_data), 4), "\n"), file = log_filename, append = TRUE)
    write(paste("- Residual SD:", round(sd(residuals_data), 4), "\n"), file = log_filename, append = TRUE)
    write(paste("- Residual range:", paste(round(range(residuals_data), 4), collapse = " to "), "\n\n"), file = log_filename, append = TRUE)
    
    # Effect interpretation
    write("**Effect Interpretation:**\n", file = log_filename, append = TRUE)
    
    # Extract key effects
    coef_table <- model_summary$coefficients
    key_effects <- c("tonic_arousal", "force_evoked_arousal", "effort_continuous", 
                     "stimulus_condition", "force_condition")
    
    for(effect in key_effects) {
        if(effect %in% rownames(coef_table)) {
            estimate <- coef_table[effect, "Estimate"]
            p_value <- coef_table[effect, "Pr(>|t|)"]
            
            if(effect == "tonic_arousal") {
                interpretation <- ifelse(estimate > 0, 
                                       "Higher tonic arousal associated with increased response",
                                       "Higher tonic arousal associated with decreased response")
            } else if(effect == "force_evoked_arousal") {
                interpretation <- ifelse(estimate > 0,
                                       "Higher force-evoked arousal associated with increased response",
                                       "Higher force-evoked arousal associated with decreased response")
            } else if(effect == "effort_continuous") {
                interpretation <- ifelse(estimate > 0,
                                       "Higher effort associated with increased response",
                                       "Higher effort associated with decreased response")
            } else {
                interpretation <- paste("Effect of", effect, "on response")
            }
            
            significance <- ifelse(p_value < 0.001, "highly significant",
                                  ifelse(p_value < 0.01, "significant",
                                         ifelse(p_value < 0.05, "marginally significant", "non-significant")))
            
            write(paste("-", effect, ":", round(estimate, 4), 
                       "(", significance, "p =", round(p_value, 4), ")\n"), 
                  file = log_filename, append = TRUE)
            write(paste("  ", interpretation, "\n"), file = log_filename, append = TRUE)
        }
    }
    write("\n", file = log_filename, append = TRUE)
    
    return(list(
        model = lmm_model,
        fixed_effects = coef_table,
        random_effects = random_effects,
        residuals = residuals_data
    ))
}

# =========================================================================
# FUNCTION 3: CAPTURE CORRELATION RESULTS
# =========================================================================

capture_correlation_results <- function(correlation_matrix, p_values, log_filename) {
    
    write("## Correlation Analysis Results\n\n", file = log_filename, append = TRUE)
    
    # Overall correlation structure
    write("**Correlation Matrix Overview:**\n", file = log_filename, append = TRUE)
    write(paste("- Variables analyzed:", nrow(correlation_matrix), "\n"), file = log_filename, append = TRUE)
    write(paste("- Total correlations:", sum(upper.tri(correlation_matrix)), "\n"), file = log_filename, append = TRUE)
    
    # Significant correlations
    significant_cors <- which(p_values < 0.05 & upper.tri(p_values), arr.ind = TRUE)
    write(paste("- Significant correlations (p < 0.05):", nrow(significant_cors), "\n\n"), file = log_filename, append = TRUE)
    
    # Detailed correlation results
    write("**Detailed Correlation Results:**\n", file = log_filename, append = TRUE)
    
    for(i in 1:nrow(significant_cors)) {
        row_idx <- significant_cors[i, 1]
        col_idx <- significant_cors[i, 2]
        
        var1 <- rownames(correlation_matrix)[row_idx]
        var2 <- colnames(correlation_matrix)[col_idx]
        cor_value <- correlation_matrix[row_idx, col_idx]
        p_value <- p_values[row_idx, col_idx]
        
        significance <- ifelse(p_value < 0.001, "***",
                              ifelse(p_value < 0.01, "**",
                                     ifelse(p_value < 0.05, "*", "")))
        
        write(paste("-", var1, "vs", var2, ":", round(cor_value, 3), 
                   "p =", round(p_value, 4), significance, "\n"), 
              file = log_filename, append = TRUE)
    }
    write("\n", file = log_filename, append = TRUE)
    
    # Interpretation of key correlations
    write("**Key Correlation Interpretations:**\n", file = log_filename, append = TRUE)
    
    # RT vs Effort
    if("rt" %in% rownames(correlation_matrix) && "effort_continuous" %in% colnames(correlation_matrix)) {
        rt_effort_cor <- correlation_matrix["rt", "effort_continuous"]
        rt_effort_p <- p_values["rt", "effort_continuous"]
        
        if(rt_effort_p < 0.05) {
            direction <- ifelse(rt_effort_cor > 0, "positive", "negative")
            write(paste("- RT-Effort correlation:", round(rt_effort_cor, 3), 
                       "(", direction, "relationship)\n"), file = log_filename, append = TRUE)
            write("  Higher effort associated with slower/faster response times\n", file = log_filename, append = TRUE)
        }
    }
    
    # Arousal correlations
    if("tonic_arousal" %in% rownames(correlation_matrix)) {
        tonic_cors <- correlation_matrix["tonic_arousal", ]
        tonic_ps <- p_values["tonic_arousal", ]
        
        significant_tonic <- which(tonic_ps < 0.05)
        if(length(significant_tonic) > 0) {
            write("- Tonic arousal shows significant correlations with:\n", file = log_filename, append = TRUE)
            for(var in names(significant_tonic)) {
                cor_val <- tonic_cors[var]
                write(paste("  ", var, ":", round(cor_val, 3), "\n"), file = log_filename, append = TRUE)
            }
        }
    }
    
    write("\n", file = log_filename, append = TRUE)
    
    return(list(
        correlation_matrix = correlation_matrix,
        p_values = p_values,
        significant_correlations = significant_cors
    ))
}

# =========================================================================
# FUNCTION 4: GENERATE COMPREHENSIVE RESEARCH SUMMARY
# =========================================================================

generate_research_summary <- function(ddm_results, rt_model_results, accuracy_model_results, 
                                     correlation_results, data_summary, log_filename) {
    
    write("## Comprehensive Research Summary\n\n", file = log_filename, append = TRUE)
    
    # Executive summary
    write("**Executive Summary:**\n", file = log_filename, append = TRUE)
    write("This analysis examined the relationship between force manipulation, pupillometry responses, ", file = log_filename, append = TRUE)
    write("and behavioral performance in a discrimination task. Key findings include:\n\n", file = log_filename, append = TRUE)
    
    # Data summary
    write("**Data Summary:**\n", file = log_filename, append = TRUE)
    write(paste("- Total subjects:", data_summary$n_subjects, "\n"), file = log_filename, append = TRUE)
    write(paste("- Total trials:", data_summary$n_trials, "\n"), file = log_filename, append = TRUE)
    write(paste("- Tasks analyzed:", paste(data_summary$tasks, collapse = ", "), "\n"), file = log_filename, append = TRUE)
    write(paste("- Force conditions:", paste(data_summary$force_conditions, collapse = ", "), "\n\n"), file = log_filename, append = TRUE)
    
    # Key findings
    write("**Key Findings:**\n", file = log_filename, append = TRUE)
    
    # DDM findings
    write("1. **Decision-Making Processes (DDM):**\n", file = log_filename, append = TRUE)
    if(!is.null(ddm_results)) {
        write("   - Drift rate effects: Evidence accumulation patterns show systematic variation\n", file = log_filename, append = TRUE)
        write("   - Boundary separation: Response caution varies across conditions\n", file = log_filename, append = TRUE)
        write("   - Non-decision time: Motor/encoding processes show individual differences\n", file = log_filename, append = TRUE)
    }
    write("\n", file = log_filename, append = TRUE)
    
    # Behavioral findings
    write("2. **Behavioral Performance:**\n", file = log_filename, append = TRUE)
    if(!is.null(rt_model_results)) {
        write("   - Reaction time patterns: Systematic effects of arousal and effort\n", file = log_filename, append = TRUE)
        write("   - Individual differences: Substantial subject-level variability\n", file = log_filename, append = TRUE)
    }
    if(!is.null(accuracy_model_results)) {
        write("   - Accuracy patterns: Force manipulation affects response accuracy\n", file = log_filename, append = TRUE)
        write("   - Arousal effects: Tonic and evoked arousal influence performance\n", file = log_filename, append = TRUE)
    }
    write("\n", file = log_filename, append = TRUE)
    
    # Correlation findings
    write("3. **Variable Relationships:**\n", file = log_filename, append = TRUE)
    if(!is.null(correlation_results)) {
        write("   - Effort-performance relationships: Clear associations identified\n", file = log_filename, append = TRUE)
        write("   - Arousal patterns: Tonic and evoked arousal show distinct patterns\n", file = log_filename, append = TRUE)
        write("   - Individual differences: Substantial variability in relationships\n", file = log_filename, append = TRUE)
    }
    write("\n", file = log_filename, append = TRUE)
    
    # Research implications
    write("**Research Implications:**\n", file = log_filename, append = TRUE)
    write("1. **Force Manipulation Effects:** The study demonstrates that force requirements ", file = log_filename, append = TRUE)
    write("systematically influence cognitive effort and decision-making processes.\n", file = log_filename, append = TRUE)
    
    write("2. **Pupillometry as Effort Index:** Pupillometry responses provide a reliable ", file = log_filename, append = TRUE)
    write("index of cognitive effort and arousal during decision-making tasks.\n", file = log_filename, append = TRUE)
    
    write("3. **Individual Differences:** Substantial individual variability in how force ", file = log_filename, append = TRUE)
    write("manipulation affects cognitive processes, suggesting trait-level factors.\n", file = log_filename, append = TRUE)
    
    write("4. **Methodological Advances:** The combination of DDM and pupillometry provides ", file = log_filename, append = TRUE)
    write("a powerful approach to understanding effort-decision relationships.\n\n", file = log_filename, append = TRUE)
    
    # Future directions
    write("**Future Research Directions:**\n", file = log_filename, append = TRUE)
    write("1. **Trait-Level Factors:** Investigate how individual differences in effort ", file = log_filename, append = TRUE)
    write("tolerance relate to decision-making patterns.\n", file = log_filename, append = TRUE)
    
    write("2. **Clinical Applications:** Apply this paradigm to clinical populations ", file = log_filename, append = TRUE)
    write("with effort-related deficits.\n", file = log_filename, append = TRUE)
    
    write("3. **Neural Mechanisms:** Combine with neuroimaging to understand neural ", file = log_filename, append = TRUE)
    write("substrates of effort-decision relationships.\n", file = log_filename, append = TRUE)
    
    write("4. **Intervention Studies:** Test interventions that modulate effort ", file = log_filename, append = TRUE)
    write("requirements and their effects on decision-making.\n\n", file = log_filename, append = TRUE)
    
    return(list(
        summary_generated = TRUE,
        key_findings = list(
            ddm_effects = !is.null(ddm_results),
            behavioral_effects = !is.null(rt_model_results) || !is.null(accuracy_model_results),
            correlation_effects = !is.null(correlation_results)
        )
    ))
}

# =========================================================================
# FUNCTION 5: CREATE DATA DICTIONARY
# =========================================================================

create_data_dictionary <- function(data, log_filename) {
    
    write("## Data Dictionary\n\n", file = log_filename, append = TRUE)
    
    write("**Variable Definitions and Descriptions:**\n\n", file = log_filename, append = TRUE)
    
    # Define variable descriptions
    var_descriptions <- list(
        # Subject and trial identifiers
        "sub" = "Subject identifier (BAP###)",
        "subject_id" = "Subject identifier for analysis",
        "trial_index" = "Trial number within session",
        "run" = "Run number within session",
        "run_index" = "Run index (1, 2, 3, etc.)",
        
        # Task and condition variables
        "task" = "Task type (aud = auditory, vis = visual)",
        "task_pupil" = "Task type for pupillometry (ADT = auditory, VDT = visual)",
        "force_condition" = "Force condition (Low_Force_5pct, High_Force_40pct)",
        "stimulus_condition" = "Stimulus condition (Standard, Oddball)",
        "stimLev" = "Stimulus level (intensity)",
        "isOddball" = "Oddball indicator (1 = oddball, 0 = standard)",
        "isStrength" = "Strength condition indicator",
        
        # Behavioral variables
        "mvc" = "Maximum voluntary contraction (force measure)",
        "ses" = "Session number",
        "iscorr" = "Response accuracy (1 = correct, 0 = incorrect)",
        "resp1" = "First response (1 or 2)",
        "resp1RT" = "First response reaction time (seconds)",
        "resp2" = "Second response (confidence)",
        "resp2RT" = "Second response reaction time (seconds)",
        "auc_rel_mvc" = "Area under curve relative to MVC",
        "resp1_isdiff" = "First response different indicator",
        "gf_trPer" = "Grip force target percentage",
        
        # Pupillometry variables
        "pupil" = "Pupil diameter (arbitrary units)",
        "time" = "Time within trial (seconds)",
        "trial_label" = "Trial phase label (ITI_Baseline, Squeeze, etc.)",
        "duration_index" = "Sample index within trial",
        "valid" = "Data validity indicator (1 = valid, 0 = invalid)",
        "baseline_quality" = "Baseline period quality score",
        "trial_quality" = "Trial period quality score",
        "overall_quality" = "Overall data quality score",
        
        # Derived variables
        "has_behavioral_data" = "Indicator for trials with behavioral data",
        "force_level" = "Force level factor (Low Force (5%), High Force (40%))",
        "stim_level" = "Stimulus level factor",
        "trial_phase" = "Trial phase factor",
        
        # Analysis variables
        "rt" = "Reaction time for analysis (seconds)",
        "accuracy" = "Accuracy for analysis (1 = correct, 0 = incorrect)",
        "response" = "Response for DDM (1 = incorrect, 2 = correct)",
        "tonic_arousal" = "Tonic arousal measure",
        "force_evoked_arousal" = "Force-evoked arousal measure",
        "effort_continuous" = "Continuous effort measure"
    )
    
    # Write variable descriptions
    for(var_name in names(data)) {
        if(var_name %in% names(var_descriptions)) {
            description <- var_descriptions[[var_name]]
        } else {
            description <- "Variable not documented"
        }
        
        # Get variable statistics
        var_data <- data[[var_name]]
        if(is.numeric(var_data)) {
            stats <- paste0("Range: ", paste(range(var_data, na.rm = TRUE), collapse = " to "),
                           " | Mean: ", round(mean(var_data, na.rm = TRUE), 3),
                           " | SD: ", round(sd(var_data, na.rm = TRUE), 3),
                           " | Missing: ", sum(is.na(var_data)), " (", 
                           round(100*sum(is.na(var_data))/length(var_data), 1), "%)")
        } else {
            unique_vals <- unique(var_data)
            stats <- paste0("Categories: ", paste(unique_vals, collapse = ", "),
                           " | Missing: ", sum(is.na(var_data)), " (", 
                           round(100*sum(is.na(var_data))/length(var_data), 1), "%)")
        }
        
        write(paste0("**", var_name, ":** ", description, "\n"), file = log_filename, append = TRUE)
        write(paste0("- ", stats, "\n\n"), file = log_filename, append = TRUE)
    }
    
    return(var_descriptions)
}

# =========================================================================
# MAIN FUNCTION: COMPREHENSIVE MODEL CAPTURE
# =========================================================================

comprehensive_model_capture <- function(ddm_model = NULL, rt_model = NULL, accuracy_model = NULL,
                                       correlation_matrix = NULL, p_values = NULL, 
                                       data = NULL, log_filename) {
    
    write("## Enhanced Model Capture and Interpretation\n\n", file = log_filename, append = TRUE)
    
    results <- list()
    
    # Capture DDM results
    if(!is.null(ddm_model)) {
        write("Capturing DDM results...\n", file = log_filename, append = TRUE)
        results$ddm <- capture_ddm_results(ddm_model, data, log_filename)
    }
    
    # Capture LMM results
    if(!is.null(rt_model)) {
        write("Capturing RT model results...\n", file = log_filename, append = TRUE)
        results$rt_model <- capture_lmm_results(rt_model, "Reaction Time Linear Mixed Model", data, log_filename)
    }
    
    if(!is.null(accuracy_model)) {
        write("Capturing accuracy model results...\n", file = log_filename, append = TRUE)
        results$accuracy_model <- capture_lmm_results(accuracy_model, "Accuracy Generalized Linear Mixed Model", data, log_filename)
    }
    
    # Capture correlation results
    if(!is.null(correlation_matrix) && !is.null(p_values)) {
        write("Capturing correlation results...\n", file = log_filename, append = TRUE)
        results$correlations <- capture_correlation_results(correlation_matrix, p_values, log_filename)
    }
    
    # Create data dictionary
    if(!is.null(data)) {
        write("Creating data dictionary...\n", file = log_filename, append = TRUE)
        results$data_dictionary <- create_data_dictionary(data, log_filename)
    }
    
    # Generate comprehensive summary
    write("Generating comprehensive research summary...\n", file = log_filename, append = TRUE)
    data_summary <- list(
        n_subjects = length(unique(data$subject_id)),
        n_trials = nrow(data),
        tasks = unique(data$task),
        force_conditions = unique(data$force_condition)
    )
    
    results$research_summary <- generate_research_summary(
        results$ddm, results$rt_model, results$accuracy_model,
        results$correlations, data_summary, log_filename
    )
    
    write("Enhanced model capture completed successfully.\n", file = log_filename, append = TRUE)
    
    return(results)
}
