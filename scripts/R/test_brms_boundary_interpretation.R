#!/usr/bin/env Rscript
# =========================================================================
# TEST: BRMS BOUNDARY INTERPRETATION
# =========================================================================
# Quick test to verify how brms interprets dec() function and boundaries
# This will help diagnose the bias interpretation issue
# =========================================================================

suppressPackageStartupMessages({
  library(rtdists)
  library(brms)
  library(dplyr)
  library(tibble)
  library(posterior)
})

cat("=" %+% strrep("=", 78), "\n")
cat("TESTING BRMS BOUNDARY INTERPRETATION\n")
cat("=" %+% strrep("=", 78), "\n\n")

# =========================================================================
# SIMULATION SETUP
# =========================================================================

cat("Step 1: Simulating data with known bias (z = 0.1, expecting 10% upper hits)...\n")

set.seed(123)
n <- 1000

# Parameters
a <- 2.0      # boundary separation
z <- 0.1      # starting point (10% from lower = bias toward lower boundary)
v <- 0.0      # no drift (Standard trials)
ndt <- 0.2    # non-decision time

# Simulate Wiener process
sim_data <- rwiener(n, alpha = a, tau = ndt, beta = z, delta = v)

# Check actual proportion
prop_upper_sim <- mean(sim_data$resp == "upper")
prop_lower_sim <- mean(sim_data$resp == "lower")

cat(sprintf("  Simulated data:\n"))
cat(sprintf("    Proportion 'upper': %.3f (expected ~0.1)\n", prop_upper_sim))
cat(sprintf("    Proportion 'lower': %.3f (expected ~0.9)\n", prop_lower_sim))
cat("\n")

# =========================================================================
# CODE FOR BRMS
# =========================================================================

cat("Step 2: Coding data for brms...\n")

# Option A: Upper boundary = 1 (what we're currently using)
sim_df_A <- tibble(
  rt = sim_data$q,
  dec_upper = as.integer(sim_data$resp == "upper"),  # 1 = upper, 0 = lower
  subject_id = factor(rep(1, n))
) %>% filter(rt > 0, rt < 10)  # Filter valid RTs

cat("  Option A: dec_upper = 1 when resp == 'upper'\n")
cat(sprintf("    Trials: %d\n", nrow(sim_df_A)))
cat(sprintf("    Proportion dec_upper = 1: %.3f\n", mean(sim_df_A$dec_upper)))
cat("\n")

# Option B: Upper boundary = 0 (reversed)
sim_df_B <- tibble(
  rt = sim_data$q,
  dec_upper = as.integer(sim_data$resp == "lower"),  # REVERSED: 1 = lower, 0 = upper
  subject_id = factor(rep(1, n))
) %>% filter(rt > 0, rt < 10)  # Filter valid RTs

cat("  Option B: dec_upper = 1 when resp == 'lower' (REVERSED)\n")
cat(sprintf("    Trials: %d\n", nrow(sim_df_B)))
cat(sprintf("    Proportion dec_upper = 1: %.3f\n", mean(sim_df_B$dec_upper)))
cat("\n")

# =========================================================================
# FIT MODEL WITH OPTION A
# =========================================================================

cat("Step 3: Fitting model with Option A (current coding)...\n")
cat("  (This may take a few minutes)\n\n")

fit_A <- tryCatch({
  brm(
    bf(rt | dec(dec_upper) ~ 1,
       bs ~ 1,
       ndt ~ 1,
       bias ~ 1),
    data = sim_df_A,
    family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
    chains = 2,
    iter = 2000,
    warmup = 1000,
    cores = 2,
    refresh = 0,
    silent = 2,
    backend = "cmdstanr"
  )
}, error = function(e) {
  cat("  ERROR:", e$message, "\n")
  return(NULL)
})

if (!is.null(fit_A)) {
  draws_A <- as_draws_df(fit_A)
  bias_A <- mean(plogis(draws_A$b_bias_Intercept))
  
  cat("  Option A Results:\n")
  cat(sprintf("    Estimated bias (z): %.3f\n", bias_A))
  cat(sprintf("    True bias (z): %.3f\n", z))
  cat(sprintf("    Match: %s\n", ifelse(abs(bias_A - z) < 0.15, "YES ✓", "NO ✗")))
  cat("\n")
  
  if (abs(bias_A - z) < 0.15) {
    cat("  ✓ Option A coding is CORRECT\n")
  } else {
    cat("  ✗ Option A coding does NOT match (might need Option B)\n")
  }
}

# =========================================================================
# FIT MODEL WITH OPTION B (IF A FAILED)
# =========================================================================

if (is.null(fit_A) || (abs(bias_A - z) > 0.15)) {
  cat("\nStep 4: Fitting model with Option B (reversed coding)...\n")
  cat("  (This may take a few minutes)\n\n")
  
  fit_B <- tryCatch({
    brm(
      bf(rt | dec(dec_upper) ~ 1,
         bs ~ 1,
         ndt ~ 1,
         bias ~ 1),
      data = sim_df_B,
      family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
      chains = 2,
      iter = 2000,
      warmup = 1000,
      cores = 2,
      refresh = 0,
      silent = 2,
      backend = "cmdstanr"
    )
  }, error = function(e) {
    cat("  ERROR:", e$message, "\n")
    return(NULL)
  })
  
  if (!is.null(fit_B)) {
    draws_B <- as_draws_df(fit_B)
    bias_B <- mean(plogis(draws_B$b_bias_Intercept))
    
    cat("  Option B Results:\n")
    cat(sprintf("    Estimated bias (z): %.3f\n", bias_B))
    cat(sprintf("    True bias (z): %.3f\n", z))
    cat(sprintf("    Match: %s\n", ifelse(abs(bias_B - z) < 0.15, "YES ✓", "NO ✗")))
    cat("\n")
    
    if (abs(bias_B - z) < 0.15) {
      cat("  ✓ Option B coding is CORRECT (current coding needs to be flipped!)\n")
    }
  }
}

# =========================================================================
# DIAGNOSIS
# =========================================================================

cat("\n" %+% strrep("=", 78), "\n")
cat("DIAGNOSIS\n")
cat(strrep("=", 78), "\n\n")

cat("Based on your Standard-only model:\n")
cat("  - Data shows: 89.1% 'Same' (lower boundary)\n")
cat("  - Model estimates: z = 0.569 (> 0.5, toward upper boundary)\n")
cat("  - Expected: z ≈ 0.109 (< 0.5, toward lower boundary)\n\n")

cat("If Option A matches in simulation:\n")
cat("  → Current coding is correct, but model has different issue\n\n")

cat("If Option B matches in simulation:\n")
cat("  → Current coding is REVERSED, need to flip dec_upper\n\n")

cat(strrep("=", 78), "\n")

# Helper function
`%+%` <- function(x, y) paste0(x, y)

