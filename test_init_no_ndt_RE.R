#!/usr/bin/env Rscript
# Test: Remove NDT random effects first (simplify, then grow approach)

library(brms)
library(dplyr)
library(readr)

cat("================================================================================\n")
cat("TESTING: No NDT Random Effects (simplify first approach)\n")
cat("================================================================================\n")

# Load data with RT floor = 250ms
ddm_data <- read_csv("data/analysis_ready/bap_ddm_ready.csv", show_col_types = FALSE) %>%
    filter(!is.na(rt), !is.na(iscorr), rt >= 0.25, rt <= 3.0) %>%
    mutate(
        subject_id = as.factor(subject_id),
        decision = ifelse(iscorr == 1, 1, 0)
    )

cat("Data: ", nrow(ddm_data), "trials (RT >= 0.25s)\n")
cat("Min RT:", min(ddm_data$rt), "s\n\n")

# Priors (same)
base_priors <- c(
    prior(normal(0, 1), class = "Intercept"),
    prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
    prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),  # No RE SD prior needed
    prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
    prior(student_t(3, 0, 0.5), class = "sd")
    # NOTE: No sd for ndt since no RE on ndt
)

# Formula WITHOUT NDT random effects
formula_test <- bf(
    rt | dec(decision) ~ 1 + (1|subject_id),
    bs ~ 1 + (1|subject_id),
    ndt ~ 1,  # NO RANDOM EFFECTS - simplifies initialization
    bias ~ 1 + (1|subject_id)
)

cat("Formula: ndt has NO random effects (simplified)\n\n")

# Simple init - just set ndt intercept
safe_init <- function(chain_id = 1) {
    list(
        Intercept = rnorm(1, 0, 0.5),
        bs_Intercept = log(runif(1, 1.0, 2.0)),
        b_ndt_Intercept = log(0.18),  # Even lower: 180ms to be safe
        bias_Intercept = rnorm(1, 0, 0.3),
        sd_bs_subject_id__Intercept = 0.1,
        z_bs_subject_id = rep(0, length(unique(ddm_data$subject_id))),
        sd_bias_subject_id__Intercept = 0.1,
        z_bias_subject_id = rep(0, length(unique(ddm_data$subject_id))),
        sd_subject_id__Intercept = 0.1,
        r_subject_id__1 = rep(0, length(unique(ddm_data$subject_id)))
    )
}

cat("Trying simplified model (no NDT RE)...\n\n")

tryCatch({
    start_time <- Sys.time()
    
    test_model <- brm(
        formula = formula_test,
        data = ddm_data,
        family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
        prior = base_priors,
        chains = 2,
        iter = 500,
        warmup = 250,
        cores = 2,
        init = safe_init,
        control = list(adapt_delta = 0.95, max_treedepth = 12),
        refresh = 50,
        file = "output/models/Model1_Baseline_NO_NDT_RE.rds"
    )
    
    elapsed <- difftime(Sys.time(), start_time, units = "mins")
    
    cat("\n✅ SUCCESS! Model completed in", round(elapsed, 1), "minutes\n")
    cat("This confirms the issue is with NDT random effects initialization\n")
    
    # Show summary
    cat("\nModel summary:\n")
    print(summary(test_model)$fixed[, c("Estimate", "l-95% CI", "u-95% CI", "Rhat")])
    
}, error = function(e) {
    cat("\n❌ Still failed:\n")
    cat("Error:", e$message, "\n")
})

cat("\n================================================================================\n")
















