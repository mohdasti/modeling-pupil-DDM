# R/fit_standard_bias_only_sensitivity.R

# Sensitivity analysis: Tighten v(Standard) prior from normal(0, 0.03) to normal(0, 0.02)
# Goal: Confirm that bias (z) estimates are stable when drift prior is tightened

suppressPackageStartupMessages({
  library(brms); library(readr); library(dplyr); library(posterior)
})

dir.create("output/models", recursive = TRUE, showWarnings = FALSE)
dir.create("output/publish", recursive = TRUE, showWarnings = FALSE)

cat("=== Sensitivity Analysis: Tightened v(Standard) Prior ===\n")
cat("Original prior: normal(0, 0.03)\n")
cat("New prior: normal(0, 0.02) - tighter constraint\n\n")

dd <- read_csv("data/analysis_ready/bap_ddm_ready_with_upper.csv", show_col_types = FALSE) %>%
  filter(difficulty_level == "Standard") %>%
  mutate(
    subject_id = factor(subject_id),
    task = factor(task),
    effort_condition = factor(effort_condition, levels = c("Low_5_MVC", "High_MVC")),
    decision = as.integer(dec_upper)
  )

cat("Data summary:\n")
cat("  Trials:", nrow(dd), "\n")
cat("  Subjects:", n_distinct(dd$subject_id), "\n")

fam <- wiener(link_bs = "log", link_ndt = "log", link_bias = "logit")

form <- bf(
  rt | dec(decision) ~ 1 + (1 | subject_id),
  bs   ~ 1 + (1 | subject_id),
  ndt  ~ 1,
  bias ~ task + effort_condition + (1 | subject_id)
)

# Tighter prior on drift: normal(0, 0.02) instead of normal(0, 0.03)
pri <- c(
  prior(normal(0, 0.02), class = "Intercept"),  # Tighter: was 0.03
  prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
  prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
  prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
  prior(normal(0, 0.35), class = "b", dpar = "bias"),
  prior(student_t(3, 0, 0.30), class = "sd")
)

cat("\n=== Model Specification ===\n")
cat("Formula: Same as original Standard-only model\n")
cat("Priors: Drift prior tightened from normal(0, 0.03) to normal(0, 0.02)\n")
cat("All other priors unchanged\n")

# Safe initialization
min_rt_global <- min(dd$rt, na.rm = TRUE)
safe_init <- function(chain_id = 1) {
  ndt_init_val <- log(min_rt_global * 0.6)
  list(
    b_Intercept = 0,
    b_bs_Intercept = log(1.3),
    b_ndt_Intercept = ndt_init_val,
    b_bias_Intercept = 0
  )
}

cat("\n=== Fitting Model ===\n")
cat("This may take 20-40 minutes...\n")
cat("Chains: 3, Iterations: 4,000 (warmup: 2,000)\n\n")

fit <- brm(
  form,
  data = dd,
  family = fam,
  prior = pri,
  chains = 3,
  iter = 4000,
  warmup = 2000,
  cores = 3,
  threads = threading(2),
  control = list(adapt_delta = 0.99, max_treedepth = 14),
  backend = "cmdstanr",
  file = "output/models/standard_bias_only_sens",
  file_refit = "on_change",
  seed = 20251120,  # Different seed from original
  init = safe_init
)

cat("\n=== Model Fit Complete ===\n")
saveRDS(fit, "output/publish/fit_standard_bias_only_sens.rds")
cat("✓ Saved: output/publish/fit_standard_bias_only_sens.rds\n")

# Check convergence
cat("\n=== Convergence Diagnostics ===\n")
rhat_max <- max(rhat(fit), na.rm = TRUE)
cat("Max R-hat:", round(rhat_max, 4), "\n")
if (rhat_max > 1.01) {
  warning("Some parameters have R-hat > 1.01")
} else {
  cat("✓ Convergence looks good\n")
}

# Extract key parameters for comparison
cat("\n=== Key Parameter Estimates ===\n")
fx <- fixef(fit)

# Drift (v)
v_est <- fx["Intercept", ]
cat("Drift (v):\n")
cat("  Estimate:", round(v_est["Estimate"], 4), "\n")
cat("  95% CrI: [", round(v_est["Q2.5"], 4), ", ", round(v_est["Q97.5"], 4), "]\n", sep = "")

# Bias intercept
bias_int <- fx["bias_Intercept", ]
cat("\nBias Intercept (z, logit scale):\n")
cat("  Estimate:", round(bias_int["Estimate"], 4), "\n")
cat("  95% CrI: [", round(bias_int["Q2.5"], 4), ", ", round(bias_int["Q97.5"], 4), "]\n", sep = "")
cat("  Natural scale: z =", round(plogis(bias_int["Estimate"]), 3), "\n")

# Task effect
bias_task <- fx["bias_taskVDT", ]
cat("\nTask Effect (VDT - ADT, logit scale):\n")
cat("  Estimate:", round(bias_task["Estimate"], 4), "\n")
cat("  95% CrI: [", round(bias_task["Q2.5"], 4), ", ", round(bias_task["Q97.5"], 4), "]\n", sep = "")

cat("\n=== Comparison with Original Model ===\n")
cat("(Run comparison script after this completes)\n")
cat("Expected: Bias estimates should be very similar despite tighter drift prior\n")

cat("\n✓ Sensitivity analysis complete!\n")

