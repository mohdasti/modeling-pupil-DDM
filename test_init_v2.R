#!/usr/bin/env Rscript
# Test initialization v2: Try init=0 and raise RT floor to 250ms

library(brms)
library(dplyr)
library(readr)

cat("================================================================================\n")
cat("TESTING INITIALIZATION v2: RT FLOOR = 250ms + init=0\n")
cat("================================================================================\n")

# Load data with HIGHER RT floor (250ms as research suggested)
ddm_data <- read_csv("data/analysis_ready/bap_ddm_ready.csv", show_col_types = FALSE) %>%
    filter(!is.na(rt), !is.na(iscorr), rt >= 0.25, rt <= 3.0) %>%  # RAISED FLOOR
    mutate(
        subject_id = as.factor(subject_id),
        decision = ifelse(iscorr == 1, 1, 0)
    )

cat("Data: ", nrow(ddm_data), "trials (RT >= 0.25s)\n")
cat("Min RT:", min(ddm_data$rt), "s\n")
cat("Max RT:", max(ddm_data$rt), "s\n\n")

# Priors
base_priors <- c(
    prior(normal(0, 1), class = "Intercept"),
    prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
    prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
    prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
    prior(student_t(3, 0, 0.5), class = "sd"),
    prior(student_t(3, 0, 0.2), class = "sd", dpar = "ndt")
)

# Formula
formula_test <- bf(
    rt | dec(decision) ~ 1 + (1|subject_id),
    bs ~ 1 + (1|subject_id),
    ndt ~ 1 + (1|subject_id),
    bias ~ 1 + (1|subject_id)
)

n_subjects <- length(unique(ddm_data$subject_id))

# Try init = 0 (all zeros) - let Stan transform from there
# This is often safer than custom inits
cat("Trying init = 0 (all parameters start at 0 on unconstrained scale)...\n\n")

tryCatch({
    test_model <- brm(
        formula = formula_test,
        data = ddm_data,
        family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
        prior = base_priors,
        chains = 2,
        iter = 500,
        warmup = 250,
        cores = 2,
        init = 0,  # All zeros - simpler approach
        control = list(adapt_delta = 0.95, max_treedepth = 12),
        refresh = 50,
        file = "output/models/Model1_Baseline_TEST_v2.rds"
    )
    
    cat("\n✅ SUCCESS with init = 0!\n")
    summary(test_model)
    
}, error = function(e) {
    cat("\n❌ Failed with init = 0:\n")
    cat("Error:", e$message, "\n")
    cat("\nTrying custom init with exact parameter matching...\n")
    
    # If init=0 fails, try the custom approach but with RT floor raised
})














