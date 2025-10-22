# =========================================================================
# COMPREHENSIVE MODEL RESULTS EXTRACTION SCRIPT
# =========================================================================
# This script extracts all available information from the fitted DDM models
# and saves it in a comprehensive, self-explanatory format for detailed analysis

cat("=== COMPREHENSIVE MODEL RESULTS EXTRACTION ===\n")
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Load required libraries
suppressPackageStartupMessages({
    library(brms)
    library(dplyr)
    library(readr)
    library(purrr)
    library(tidyr)
    library(ggplot2)
    library(bayesplot)
    library(posterior)
})

# Load configuration
source(file.path(getwd(), "config", "paths_config.R"))

# Create output directory for results
results_dir <- file.path(OUTPUT_PATHS$results, "comprehensive_analysis")
if (!dir.exists(results_dir)) {
    dir.create(results_dir, recursive = TRUE)
}

# Initialize results collection
all_results <- list()
model_summaries <- list()
diagnostic_plots <- list()
convergence_info <- list()

# Function to extract comprehensive model information
extract_model_info <- function(model_path, model_name) {
    cat("Extracting information for:", model_name, "\n")
    
    # Load model
    model <- readRDS(model_path)
    
    # Basic model information
    model_info <- list(
        model_name = model_name,
        file_path = model_path,
        file_size_mb = round(file.size(model_path) / (1024^2), 2),
        extraction_timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    )
    
    # Model specification
    model_info$family <- as.character(family(model))
    model_info$formula <- as.character(formula(model))
    model_info$data_points <- nrow(model$data)
    model_info$n_subjects <- length(unique(model$data$subject_id))
    
    # Sampling information
    model_info$chains <- model$fit@sim$chains
    model_info$iterations <- model$fit@sim$iter
    model_info$warmup <- model$fit@sim$warmup
    model_info$thin <- model$fit@sim$thin
    model_info$total_draws <- model$fit@sim$chains * (model$fit@sim$iter - model$fit@sim$warmup)
    
    # Timing information
    model_info$total_time_seconds <- sum(model$fit@sim$elapsed_time)
    model_info$warmup_time_seconds <- sum(model$fit@sim$elapsed_time[1:model$fit@sim$chains])
    model_info$sampling_time_seconds <- sum(model$fit@sim$elapsed_time[(model$fit@sim$chains+1):length(model$fit@sim$elapsed_time)])
    
    # Convergence diagnostics
    summary_obj <- summary(model)
    model_info$convergence <- list(
        max_rhat = max(summary_obj$fixed$Rhat, na.rm = TRUE),
        min_bulk_ess = min(summary_obj$fixed$Bulk_ESS, na.rm = TRUE),
        min_tail_ess = min(summary_obj$fixed$Tail_ESS, na.rm = TRUE),
        divergent_transitions = sum(model$fit@sim$divergent__),
        max_treedepth = max(model$fit@sim$treedepth__),
        energy_bfmi = min(model$fit@sim$energy__)
    )
    
    # Parameter estimates - Fixed effects
    fixed_effects <- summary_obj$fixed
    model_info$fixed_effects <- fixed_effects
    
    # Parameter estimates - Random effects
    if (!is.null(summary_obj$random)) {
        model_info$random_effects <- summary_obj$random
    }
    
    # Distributional parameters (DDM specific)
    if (!is.null(summary_obj$spec_pars)) {
        model_info$distributional_parameters <- summary_obj$spec_pars
    }
    
    # Prior information
    model_info$priors <- model$prior
    
    # Data summary
    model_info$data_summary <- list(
        rt_mean = mean(model$data$rt, na.rm = TRUE),
        rt_sd = sd(model$data$rt, na.rm = TRUE),
        rt_min = min(model$data$rt, na.rm = TRUE),
        rt_max = max(model$data$rt, na.rm = TRUE),
        decision_mean = mean(model$data$decision, na.rm = TRUE),
        decision_sd = sd(model$data$decision, na.rm = TRUE),
        accuracy_rate = mean(model$data$decision, na.rm = TRUE)
    )
    
    # Model-specific variables
    if ("effort_condition" %in% names(model$data)) {
        model_info$effort_condition_summary <- table(model$data$effort_condition)
    }
    if ("difficulty_level" %in% names(model$data)) {
        model_info$difficulty_level_summary <- table(model$data$difficulty_level)
    }
    if ("effort_arousal_scaled" %in% names(model$data)) {
        model_info$effort_arousal_summary <- list(
            mean = mean(model$data$effort_arousal_scaled, na.rm = TRUE),
            sd = sd(model$data$effort_arousal_scaled, na.rm = TRUE),
            min = min(model$data$effort_arousal_scaled, na.rm = TRUE),
            max = max(model$data$effort_arousal_scaled, na.rm = TRUE)
        )
    }
    if ("tonic_arousal_scaled" %in% names(model$data)) {
        model_info$tonic_arousal_summary <- list(
            mean = mean(model$data$tonic_arousal_scaled, na.rm = TRUE),
            sd = sd(model$data$tonic_arousal_scaled, na.rm = TRUE),
            min = min(model$data$tonic_arousal_scaled, na.rm = TRUE),
            max = max(model$data$tonic_arousal_scaled, na.rm = TRUE)
        )
    }
    
    return(model_info)
}

# Function to create diagnostic plots
create_diagnostic_plots <- function(model_path, model_name) {
    cat("Creating diagnostic plots for:", model_name, "\n")
    
    model <- readRDS(model_path)
    
    # Create plots directory
    plots_dir <- file.path(results_dir, "diagnostic_plots")
    if (!dir.exists(plots_dir)) {
        dir.create(plots_dir, recursive = TRUE)
    }
    
    plots <- list()
    
    # Trace plots
    tryCatch({
        trace_plot <- mcmc_trace(model$fit, pars = c("b_Intercept", "bs_Intercept", "ndt_Intercept", "bias_Intercept"))
        ggsave(file.path(plots_dir, paste0(model_name, "_trace_plot.png")), 
               trace_plot, width = 12, height = 8, dpi = 300)
        plots$trace_plot <- "Created"
    }, error = function(e) {
        plots$trace_plot <- paste("Error:", e$message)
    })
    
    # Density plots
    tryCatch({
        density_plot <- mcmc_dens_overlay(model$fit, pars = c("b_Intercept", "bs_Intercept", "ndt_Intercept", "bias_Intercept"))
        ggsave(file.path(plots_dir, paste0(model_name, "_density_plot.png")), 
               density_plot, width = 12, height = 8, dpi = 300)
        plots$density_plot <- "Created"
    }, error = function(e) {
        plots$density_plot <- paste("Error:", e$message)
    })
    
    # Rhat plot
    tryCatch({
        rhat_plot <- mcmc_rhat(rhat(model$fit))
        ggsave(file.path(plots_dir, paste0(model_name, "_rhat_plot.png")), 
               rhat_plot, width = 10, height = 6, dpi = 300)
        plots$rhat_plot <- "Created"
    }, error = function(e) {
        plots$rhat_plot <- paste("Error:", e$message)
    })
    
    # Effective sample size plot
    tryCatch({
        ess_plot <- mcmc_neff(neff_ratio(model$fit))
        ggsave(file.path(plots_dir, paste0(model_name, "_ess_plot.png")), 
               ess_plot, width = 10, height = 6, dpi = 300)
        plots$ess_plot <- "Created"
    }, error = function(e) {
        plots$ess_plot <- paste("Error:", e$message)
    })
    
    return(plots)
}

# Get list of model files
model_files <- list.files(OUTPUT_PATHS$models, pattern = "\\.rds$", full.names = TRUE)
model_names <- gsub("\\.rds$", "", basename(model_files))

cat("Found", length(model_files), "model files:\n")
for (i in seq_along(model_files)) {
    cat("  ", i, ":", model_names[i], "\n")
}

# Extract information from each model
for (i in seq_along(model_files)) {
    model_name <- model_names[i]
    model_path <- model_files[i]
    
    cat("\n--- Processing", model_name, "---\n")
    
    # Extract model information
    model_info <- extract_model_info(model_path, model_name)
    all_results[[model_name]] <- model_info
    
    # Create diagnostic plots
    diagnostic_plots[[model_name]] <- create_diagnostic_plots(model_path, model_name)
}

# Create comprehensive summary
cat("\n=== CREATING COMPREHENSIVE SUMMARY ===\n")

# Overall analysis summary
analysis_summary <- list(
    analysis_timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    total_models_analyzed = length(all_results),
    successful_models = length(all_results),
    failed_models = 0,
    total_data_points = sum(sapply(all_results, function(x) x$data_points)),
    total_subjects = length(unique(unlist(sapply(all_results, function(x) unique(x$data$subject_id))))),
    total_computation_time_minutes = sum(sapply(all_results, function(x) x$total_time_seconds)) / 60
)

# Convergence summary across all models
convergence_summary <- data.frame(
    model_name = names(all_results),
    max_rhat = sapply(all_results, function(x) x$convergence$max_rhat),
    min_bulk_ess = sapply(all_results, function(x) x$convergence$min_bulk_ess),
    min_tail_ess = sapply(all_results, function(x) x$convergence$min_tail_ess),
    divergent_transitions = sapply(all_results, function(x) x$convergence$divergent_transitions),
    max_treedepth = sapply(all_results, function(x) x$convergence$max_treedepth),
    stringsAsFactors = FALSE
)

# DDM parameters summary
ddm_parameters_summary <- list()
for (model_name in names(all_results)) {
    model_info <- all_results[[model_name]]
    
    # Extract DDM parameters if available
    if (!is.null(model_info$distributional_parameters)) {
        ddm_params <- model_info$distributional_parameters
        ddm_parameters_summary[[model_name]] <- list(
            bs_intercept = ddm_params[ddm_params$Parameter == "bs_Intercept", ],
            ndt_intercept = ddm_params[ddm_params$Parameter == "ndt_Intercept", ],
            bias_intercept = ddm_params[ddm_params$Parameter == "bias_Intercept", ]
        )
    }
}

# Save comprehensive results to multiple formats

# 1. Detailed text report
cat("Saving detailed text report...\n")
text_report_file <- file.path(results_dir, "comprehensive_model_analysis_report.txt")
sink(text_report_file)

cat("================================================================================\n")
cat("COMPREHENSIVE BAP DDM MODEL ANALYSIS REPORT\n")
cat("================================================================================\n")
cat("Analysis Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Total Models Analyzed:", length(all_results), "\n")
cat("Total Data Points:", sum(sapply(all_results, function(x) x$data_points)), "\n")
cat("Total Computation Time:", round(sum(sapply(all_results, function(x) x$total_time_seconds)) / 60, 2), "minutes\n\n")

cat("================================================================================\n")
cat("ANALYSIS SUMMARY\n")
cat("================================================================================\n")
print(analysis_summary)

cat("\n================================================================================\n")
cat("CONVERGENCE DIAGNOSTICS SUMMARY\n")
cat("================================================================================\n")
print(convergence_summary)

cat("\n================================================================================\n")
cat("DETAILED MODEL INFORMATION\n")
cat("================================================================================\n")

for (model_name in names(all_results)) {
    model_info <- all_results[[model_name]]
    
    cat("\n---", model_name, "---\n")
    cat("File Size:", model_info$file_size_mb, "MB\n")
    cat("Family:", model_info$family, "\n")
    cat("Formula:", model_info$formula, "\n")
    cat("Data Points:", model_info$data_points, "\n")
    cat("Subjects:", model_info$n_subjects, "\n")
    cat("Chains:", model_info$chains, "\n")
    cat("Iterations:", model_info$iterations, "\n")
    cat("Warmup:", model_info$warmup, "\n")
    cat("Total Draws:", model_info$total_draws, "\n")
    cat("Total Time:", round(model_info$total_time_seconds, 2), "seconds\n")
    cat("Warmup Time:", round(model_info$warmup_time_seconds, 2), "seconds\n")
    cat("Sampling Time:", round(model_info$sampling_time_seconds, 2), "seconds\n")
    
    cat("\nConvergence Diagnostics:\n")
    cat("  Max Rhat:", round(model_info$convergence$max_rhat, 4), "\n")
    cat("  Min Bulk ESS:", model_info$convergence$min_bulk_ess, "\n")
    cat("  Min Tail ESS:", model_info$convergence$min_tail_ess, "\n")
    cat("  Divergent Transitions:", model_info$convergence$divergent_transitions, "\n")
    cat("  Max Treedepth:", model_info$convergence$max_treedepth, "\n")
    
    cat("\nData Summary:\n")
    cat("  RT Mean:", round(model_info$data_summary$rt_mean, 4), "\n")
    cat("  RT SD:", round(model_info$data_summary$rt_sd, 4), "\n")
    cat("  RT Range:", round(model_info$data_summary$rt_min, 4), "-", round(model_info$data_summary$rt_max, 4), "\n")
    cat("  Accuracy Rate:", round(model_info$data_summary$accuracy_rate, 4), "\n")
    
    if (!is.null(model_info$effort_condition_summary)) {
        cat("\nEffort Condition Distribution:\n")
        print(model_info$effort_condition_summary)
    }
    
    if (!is.null(model_info$difficulty_level_summary)) {
        cat("\nDifficulty Level Distribution:\n")
        print(model_info$difficulty_level_summary)
    }
    
    cat("\nFixed Effects:\n")
    print(model_info$fixed_effects)
    
    if (!is.null(model_info$random_effects)) {
        cat("\nRandom Effects:\n")
        print(model_info$random_effects)
    }
    
    if (!is.null(model_info$distributional_parameters)) {
        cat("\nDistributional Parameters (DDM):\n")
        print(model_info$distributional_parameters)
    }
    
    cat("\n", rep("=", 80), "\n")
}

sink()

# 2. CSV files for structured data
cat("Saving CSV files...\n")

# Convergence summary CSV
write_csv(convergence_summary, file.path(results_dir, "convergence_summary.csv"))

# Fixed effects summary
fixed_effects_all <- list()
for (model_name in names(all_results)) {
    fe <- all_results[[model_name]]$fixed_effects
    fe$model_name <- model_name
    fixed_effects_all[[model_name]] <- fe
}
fixed_effects_df <- bind_rows(fixed_effects_all)
write_csv(fixed_effects_df, file.path(results_dir, "fixed_effects_summary.csv"))

# Random effects summary
random_effects_all <- list()
for (model_name in names(all_results)) {
    if (!is.null(all_results[[model_name]]$random_effects)) {
        re <- all_results[[model_name]]$random_effects
        if (is.data.frame(re)) {
            re$model_name <- model_name
            random_effects_all[[model_name]] <- re
        }
    }
}
if (length(random_effects_all) > 0) {
    random_effects_df <- bind_rows(random_effects_all)
    # Convert any remaining list columns to character
    random_effects_df <- random_effects_df %>%
        mutate(across(where(is.list), ~ sapply(., function(x) if(is.null(x)) NA else paste(x, collapse = ", "))))
    write_csv(random_effects_df, file.path(results_dir, "random_effects_summary.csv"))
}

# Distributional parameters summary
dist_params_all <- list()
for (model_name in names(all_results)) {
    if (!is.null(all_results[[model_name]]$distributional_parameters)) {
        dp <- all_results[[model_name]]$distributional_parameters
        if (is.data.frame(dp)) {
            dp$model_name <- model_name
            dist_params_all[[model_name]] <- dp
        }
    }
}
if (length(dist_params_all) > 0) {
    dist_params_df <- bind_rows(dist_params_all)
    # Convert any remaining list columns to character
    dist_params_df <- dist_params_df %>%
        mutate(across(where(is.list), ~ sapply(., function(x) if(is.null(x)) NA else paste(x, collapse = ", "))))
    write_csv(dist_params_df, file.path(results_dir, "distributional_parameters_summary.csv"))
}

# 3. RDS file with complete results
cat("Saving complete results as RDS...\n")
saveRDS(list(
    analysis_summary = analysis_summary,
    all_results = all_results,
    convergence_summary = convergence_summary,
    diagnostic_plots = diagnostic_plots,
    extraction_timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
), file.path(results_dir, "complete_analysis_results.rds"))

# 4. JSON file for easy parsing
cat("Saving JSON summary...\n")
library(jsonlite)
json_summary <- list(
    analysis_summary = analysis_summary,
    convergence_summary = convergence_summary,
    model_summaries = lapply(all_results, function(x) {
        list(
            model_name = x$model_name,
            family = x$family,
            formula = x$formula,
            data_points = x$data_points,
            n_subjects = x$n_subjects,
            convergence = x$convergence,
            data_summary = x$data_summary
        )
    })
)
write_json(json_summary, file.path(results_dir, "analysis_summary.json"), pretty = TRUE)

# Final summary
cat("\n=== EXTRACTION COMPLETE ===\n")
cat("Results saved to:", results_dir, "\n")
cat("Files created:\n")
cat("  - comprehensive_model_analysis_report.txt (detailed text report)\n")
cat("  - convergence_summary.csv (convergence diagnostics)\n")
cat("  - fixed_effects_summary.csv (fixed effects estimates)\n")
cat("  - random_effects_summary.csv (random effects estimates)\n")
cat("  - distributional_parameters_summary.csv (DDM parameters)\n")
cat("  - complete_analysis_results.rds (complete R object)\n")
cat("  - analysis_summary.json (JSON summary)\n")
cat("  - diagnostic_plots/ (diagnostic plots directory)\n")

cat("\nAnalysis completed at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
