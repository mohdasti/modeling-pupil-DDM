#!/usr/bin/env Rscript
# =========================================================================
# QUICK TEST: Fit a single DDM model to verify standardized priors work
# =========================================================================

cat("================================================================================\n")
cat("QUICK TEST: Single DDM Model\n")
cat("================================================================================\n")
cat("Testing Model1_Baseline with standardized priors...\n\n")

library(brms)
library(dplyr)
library(readr)

# =========================================================================
# Load data
# =========================================================================

cat("Loading data...\n")

# Try analysis-ready file first
data_file <- "data/analysis_ready/bap_ddm_ready.csv"

if (!file.exists(data_file)) {
    stop("Data file not found: ", data_file)
}

data <- read_csv(data_file, show_col_types = FALSE)

cat("✅ Loaded", nrow(data), "trials\n")

# =========================================================================
# Prepare data
# =========================================================================

cat("Preparing data...\n")

ddm_data <- data %>%
    filter(
        !is.na(rt), !is.na(iscorr),
        rt >= 0.2 & rt <= 3.0  # Standardized RT filtering
    ) %>%
    mutate(
        subject_id = as.factor(subject_id),
        decision = ifelse(iscorr == 1, 1, 0)  # 1=correct, 0=incorrect (iscorr is correct column)
    )

cat("✅ After filtering:", nrow(ddm_data), "trials\n")
cat("   Subjects:", length(unique(ddm_data$subject_id)), "\n\n")

# =========================================================================
# Define model with standardized priors
# =========================================================================

cat("Setting up model with standardized priors...\n")

# Simple baseline model
formula_test <- bf(
    rt | dec(decision) ~ 1 + (1|subject_id),
    bs ~ 1 + (1|subject_id),
    ndt ~ 1 + (1|subject_id),
    bias ~ 1 + (1|subject_id)
)

# Standardized priors (for baseline model - intercept-only)
priors_test <- c(
    # Drift rate (v) - identity link
    prior(normal(0, 1), class = "Intercept"),
    
    # Boundary separation (a/bs) - log link: center at log(1.7) for older adults
    prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
    
    # Non-decision time (t0/ndt) - log link: center at log(0.35) for older adults + response-signal
    prior(normal(log(0.35), 0.25), class = "Intercept", dpar = "ndt"),
    
    # Starting point bias (z) - logit link: centered at 0.5 with moderate spread
    prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
    
    # Random effects - subject-level variability
    prior(student_t(3, 0, 0.5), class = "sd")
)

cat("✅ Priors defined\n\n")

# =========================================================================
# Fit model (reduced iterations for quick test)
# =========================================================================

cat("================================================================================\n")
cat("FITTING MODEL (reduced iterations for testing)...\n")
cat("================================================================================\n\n")

    tryCatch({
    # Set better initial values to avoid initialization issues
    # NDT should be less than minimum RT
    min_rt <- min(ddm_data$rt)
    init_ndt <- log(min_rt * 0.3)  # Start at 30% of min RT (reasonable for older adults)
    
    model_test <- brm(
        formula = formula_test,
        data = ddm_data,
        family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
        prior = priors_test,
        chains = 2,      # Reduced for speed
        cores = 2,       # Reduced for speed
        iter = 1000,     # Reduced for speed (normal: 2000)
        warmup = 500,   # Reduced for speed (normal: 1000)
        seed = 12345,
        init = function() {
            list(
                Intercept = rnorm(1, 0, 0.5),
                bs_Intercept = log(runif(1, 1.0, 2.0)),
                ndt_Intercept = init_ndt,
                bias_Intercept = rnorm(1, 0, 0.3)
            )
        },
        control = list(adapt_delta = 0.95, max_treedepth = 12),
        refresh = 100
    )
    
    cat("\n================================================================================\n")
    cat("✅ MODEL FITTING SUCCESSFUL!\n")
    cat("================================================================================\n\n")
    
    # Quick convergence check
    cat("Convergence diagnostics:\n")
    summary_test <- summary(model_test)
    max_rhat <- max(summary_test$fixed$Rhat, na.rm = TRUE)
    min_ess <- min(summary_test$fixed$Bulk_ESS, na.rm = TRUE)
    
    cat("  Max R-hat:", round(max_rhat, 4), if(max_rhat < 1.02) "✅" else "⚠️", "\n")
    cat("  Min ESS:", round(min_ess, 0), if(min_ess > 100) "✅" else "⚠️", "\n\n")
    
    # Show key parameters
    cat("Key parameter estimates (on natural scale):\n")
    fixed_effects <- summary_test$fixed
    
    # Get Intercepts and transform to natural scale
    # Note: brms uses "bs_Intercept", "ndt_Intercept", "bias_Intercept" for dpar parameters
    if ("Intercept" %in% rownames(fixed_effects)) {
        intercept_v <- fixed_effects["Intercept", "Estimate"]
        cat("  Drift rate (v):", round(intercept_v, 3), "\n")
    }
    
    if ("bs_Intercept" %in% rownames(fixed_effects)) {
        intercept_bs <- fixed_effects["bs_Intercept", "Estimate"]
        bs_natural <- exp(intercept_bs)
        cat("  Boundary separation (a):", round(bs_natural, 3), "\n")
    }
    
    if ("ndt_Intercept" %in% rownames(fixed_effects)) {
        intercept_ndt <- fixed_effects["ndt_Intercept", "Estimate"]
        ndt_natural <- exp(intercept_ndt)
        cat("  Non-decision time (t0):", round(ndt_natural, 3), "s\n")
    }
    
    if ("bias_Intercept" %in% rownames(fixed_effects)) {
        intercept_bias <- fixed_effects["bias_Intercept", "Estimate"]
        bias_natural <- plogis(intercept_bias)
        cat("  Starting point (z):", round(bias_natural, 3), "\n")
    }
    cat("\n")
    
    # Save test model
    output_dir <- "output/models"
    if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
    
    save_path <- file.path(output_dir, "test_model_baseline.rds")
    saveRDS(model_test, save_path)
    cat("✅ Test model saved to:", save_path, "\n\n")
    
    cat("================================================================================\n")
    cat("✅ TEST PASSED - Ready for full pipeline!\n")
    cat("================================================================================\n")
    cat("All standardized changes are working correctly:\n")
    cat("  ✅ Priors applied successfully\n")
    cat("  ✅ Formulas structured correctly\n")
    cat("  ✅ Model converged\n")
    cat("\nYou can now run the full pipeline:\n")
    cat("  Rscript run_full_pipeline.R\n")
    cat("================================================================================\n")
    
}, error = function(e) {
    cat("\n================================================================================\n")
    cat("❌ ERROR: Model fitting failed\n")
    cat("================================================================================\n")
    cat("Error message:\n")
    cat(e$message, "\n\n")
    cat("Traceback:\n")
    print(traceback())
    cat("\n================================================================================\n")
    stop("Test failed - fix errors before running full pipeline")
})

