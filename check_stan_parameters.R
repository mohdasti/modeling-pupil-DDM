#!/usr/bin/env Rscript
# Check actual Stan parameter names from brms

library(brms)
library(dplyr)
library(readr)

# Load minimal data
ddm_data <- read_csv("data/analysis_ready/bap_ddm_ready.csv", show_col_types = FALSE, n_max=100) %>%
    filter(!is.na(rt), !is.na(iscorr), rt >= 0.2, rt <= 3.0) %>%
    mutate(
        subject_id = as.factor(subject_id),
        decision = ifelse(iscorr == 1, 1, 0)
    )

# Simple formula
formula_test <- bf(
    rt | dec(decision) ~ 1 + (1|subject_id),
    bs ~ 1 + (1|subject_id),
    ndt ~ 1 + (1|subject_id),
    bias ~ 1 + (1|subject_id)
)

priors <- c(
    prior(normal(0, 1), class = "Intercept"),
    prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
    prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
    prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
    prior(student_t(3, 0, 0.5), class = "sd"),
    prior(student_t(3, 0, 0.2), class = "sd", dpar = "ndt")
)

cat("Compiling model to check parameter names...\n")
cat("(This will fail at init, but we'll get the parameter names)\n\n")

# Compile only (don't fit)
tryCatch({
    test_model <- brm(
        formula = formula_test,
        data = ddm_data,
        family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
        prior = priors,
        chains = 0,  # Compile only
        iter = 0,
        compile = TRUE,
        backend = "cmdstanr"
    )
}, error = function(e) {
    # Try to get parameter names from Stan code
    cat("Error (expected):", e$message, "\n\n")
})

# Alternative: Use parnames if model object exists
if (exists("test_model")) {
    cat("Parameter names from model:\n")
    params <- parnames(test_model)
    print(params)
    cat("\nNDT-related parameters:\n")
    print(grep("ndt", params, value=TRUE, ignore.case=TRUE))
}
















