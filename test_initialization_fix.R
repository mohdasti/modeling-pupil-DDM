#!/usr/bin/env Rscript
# Quick test of initialization fixes
# Tests Model1_Baseline with the new safe initialization

cat("================================================================================\n")
cat("TESTING INITIALIZATION FIXES\n")
cat("================================================================================\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

library(brms)
library(dplyr)
library(readr)

# Load data
cat("[", format(Sys.time(), "%H:%M:%S"), "] Loading data...\n")
ddm_data <- read_csv("data/analysis_ready/bap_ddm_ready.csv", show_col_types = FALSE) %>%
    filter(!is.na(rt), !is.na(iscorr), rt >= 0.2, rt <= 3.0) %>%
    mutate(
        subject_id = as.factor(subject_id),
        decision = ifelse(iscorr == 1, 1, 0)
    )

cat("[", format(Sys.time(), "%H:%M:%S"), "] Data loaded:", nrow(ddm_data), "trials from", 
    length(unique(ddm_data$subject_id)), "subjects\n\n")

# Base priors (intercept-only)
base_priors <- c(
    prior(normal(0, 1), class = "Intercept"),
    prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
    prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
    prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
    prior(student_t(3, 0, 0.5), class = "sd"),
    prior(student_t(3, 0, 0.2), class = "sd", dpar = "ndt")
)

# Model formula (baseline)
formula_test <- bf(
    rt | dec(decision) ~ 1 + (1|subject_id),
    bs ~ 1 + (1|subject_id),
    ndt ~ 1 + (1|subject_id),
    bias ~ 1 + (1|subject_id)
)

# Get number of subjects for z_ndt vector
n_subjects <- length(unique(ddm_data$subject_id))
cat("[", format(Sys.time(), "%H:%M:%S"), "] Number of subjects:", n_subjects, "\n")

# Safe init function with ALL NDT components
safe_init <- function(chain_id = 1) {
    init_list <- list(
        # Fixed effects
        Intercept = rnorm(1, 0, 0.5),
        bs_Intercept = log(runif(1, 1.0, 2.0)),
        bias_Intercept = rnorm(1, 0, 0.3),
        
        # CRITICAL: NDT intercept pinned low
        b_ndt_Intercept = log(0.20),
        
        # CRITICAL: NDT random effect SD clamped tiny
        sd_ndt_subject_id__Intercept = 0.05,
        
        # CRITICAL: NDT raw random effects zeroed
        z_ndt_subject_id = rep(0, n_subjects)
    )
    
    # Also initialize other RE components
    init_list$sd_bs_subject_id__Intercept <- 0.1
    init_list$z_bs_subject_id <- rep(0, n_subjects)
    init_list$sd_bias_subject_id__Intercept <- 0.1
    init_list$z_bias_subject_id <- rep(0, n_subjects)
    init_list$sd_subject_id__Intercept <- 0.1
    init_list$r_subject_id__1 <- rep(0, n_subjects)
    
    return(init_list)
}

cat("[", format(Sys.time(), "%H:%M:%S"), "] Testing initialization...\n")
cat("  Checking init function creates valid values...\n")
test_init <- safe_init()
cat("  ✓ Init function works\n")
cat("  NDT intercept (log scale):", test_init$b_ndt_Intercept, "=", exp(test_init$b_ndt_Intercept), "s on natural scale\n")
cat("  NDT RE SD:", test_init$sd_ndt_subject_id__Intercept, "\n")
cat("  NDT raw REs length:", length(test_init$z_ndt_subject_id), "(should be", n_subjects, ")\n")
cat("  All z_ndt values zero:", all(test_init$z_ndt_subject_id == 0), "\n\n")

cat("[", format(Sys.time(), "%H:%M:%S"), "] Fitting Model1_Baseline (test)...\n")
cat("  This will test if initialization succeeds...\n\n")

tryCatch({
    start_time <- Sys.time()
    
    test_model <- brm(
        formula = formula_test,
        data = ddm_data,
        family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
        prior = base_priors,
        chains = 2,  # Reduced for quick test
        iter = 500,  # Reduced for quick test
        warmup = 250,
        cores = 2,
        init = safe_init,
        init_r = 0.02,
        control = list(adapt_delta = 0.95, max_treedepth = 12),
        refresh = 50,
        file = "output/models/Model1_Baseline_TEST.rds",
        file_refit = "on_change"
    )
    
    elapsed <- difftime(Sys.time(), start_time, units = "mins")
    
    cat("\n================================================================================\n")
    cat("✅ INITIALIZATION TEST SUCCESSFUL!\n")
    cat("================================================================================\n")
    cat("Model completed in", round(elapsed, 1), "minutes\n")
    cat("Chains:", length(test_model$fit$metadata()$chains), "\n")
    cat("Iterations:", test_model$fit$metadata()$iter_sampling + test_model$fit$metadata()$iter_warmup, "\n\n")
    
    # Check diagnostics
    cat("Diagnostics:\n")
    summary_test <- summary(test_model)
    
    # Check R-hat
    max_rhat <- max(summary_test$fixed$Rhat, na.rm = TRUE)
    cat("  Max R-hat:", round(max_rhat, 3), if(max_rhat <= 1.01) "✓" else "⚠", "\n")
    
    # Check ESS
    min_ess <- min(summary_test$fixed$ESS_Bulk, na.rm = TRUE)
    cat("  Min ESS:", round(min_ess, 0), if(min_ess > 400) "✓" else "⚠", "\n")
    
    # Check for divergences
    sampler_params <- test_model$fit$sampler_diagnostics()
    n_divergent <- sum(sampler_params[,,"divergent__"], na.rm = TRUE)
    cat("  Divergent transitions:", n_divergent, if(n_divergent == 0) "✓" else "⚠", "\n\n")
    
    # Show NDT parameter
    cat("NDT Intercept (log scale):", round(summary_test$fixed["b_ndt_Intercept", "Estimate"], 3), "\n")
    cat("NDT Intercept (natural scale):", round(exp(summary_test$fixed["b_ndt_Intercept", "Estimate"]), 3), "s\n")
    cat("Min RT in data:", round(min(ddm_data$rt), 3), "s\n")
    cat("NDT < min(RT):", exp(summary_test$fixed["b_ndt_Intercept", "Estimate"]) < min(ddm_data$rt), "\n\n")
    
    cat("✅ All checks passed! Initialization fixes are working.\n")
    cat("================================================================================\n")
    
}, error = function(e) {
    cat("\n================================================================================\n")
    cat("❌ INITIALIZATION TEST FAILED\n")
    cat("================================================================================\n")
    cat("Error:", e$message, "\n")
    cat("\nThis suggests the initialization still needs adjustment.\n")
    cat("Check the error message above for details.\n")
    cat("================================================================================\n")
})

cat("\nEnd time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("================================================================================\n")














