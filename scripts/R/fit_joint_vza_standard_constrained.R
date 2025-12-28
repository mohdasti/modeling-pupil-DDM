# R/fit_joint_vza_standard_constrained.R

# Joint fit: Standard informs z (and a), Easy/Hard drive v; v(Standard) ~ 0 with tight prior.
# This model uses all trials but constrains drift on Standard to be ≈ 0,
# while allowing task/effort effects on drift only for non-Standard trials.

suppressPackageStartupMessages({
  library(brms)
  library(cmdstanr)
  library(dplyr)
  library(readr)
  library(posterior)
})

# Ensure output directories exist
dir.create("output/models", recursive = TRUE, showWarnings = FALSE)
dir.create("output/publish", recursive = TRUE, showWarnings = FALSE)

# Load data with response-side decision boundary
dd <- read_csv("data/analysis_ready/bap_ddm_ready_with_upper.csv", show_col_types = FALSE) %>%
  mutate(
    subject_id = factor(subject_id),
    task = factor(task),
    effort_condition = factor(effort_condition, levels = c("Low_5_MVC", "High_MVC")),
    difficulty_level = factor(difficulty_level, levels = c("Standard", "Hard", "Easy")),
    decision = as.integer(dec_upper),
    is_nonstd = ifelse(difficulty_level == "Standard", 0L, 1L)  # 1 for Easy/Hard, 0 for Standard
  )

cat("Data summary:\n")
cat("  Total trials:", nrow(dd), "\n")
cat("  Subjects:", n_distinct(dd$subject_id), "\n")
cat("  Trials by difficulty:\n")
print(table(dd$difficulty_level))
cat("  Trials by task:\n")
print(table(dd$task))
cat("  Trials by effort:\n")
print(table(dd$effort_condition))
cat("  is_nonstd distribution:\n")
print(table(dd$is_nonstd))
cat("  Decision distribution (dec_upper):\n")
print(table(dd$decision))

# Wiener family with log link for boundary and NDT, logit for bias
fam <- wiener(
  link_bs = "log",
  link_ndt = "log",
  link_bias = "logit"
)

# Model specification:
# - drift (v): separate coefficients per difficulty (no intercept), 
#              and allow task/effort ONLY when non-Standard (via is_nonstd interaction)
# - bias (z): difficulty + task + subject RE (allows pooling across conditions)
# - boundary (a/bs): difficulty + task + subject RE
# - ndt: task + effort (no RE to avoid init explosions)

form <- bf(
  rt | dec(decision) ~ 0 + difficulty_level + task:is_nonstd + effort_condition:is_nonstd + (1 | subject_id),
  bs   ~ difficulty_level + task + (1 | subject_id),
  ndt  ~ task + effort_condition,             # small condition effects, no RE
  bias ~ difficulty_level + task + (1 | subject_id)
)

# Prior specifications:
# - v(Standard): tight around 0 (normal(0, 0.04)) - not a delta function but very tight
# - v(Hard/Easy): moderate priors (normal(0, 0.6))
# - v task/effort effects: only apply to non-Standard (via is_nonstd interaction)
# - bs intercept: log(1.7) with sd 0.30
# - ndt intercept: log(0.23) with sd 0.20
# - bias intercept: 0 with sd 0.5
# - bias/bs effects: 0 with sd 0.35
# - random effects: student_t(3,0,0.30)

# Note: With 0 + difficulty_level, brms creates coefficients like:
# - difficulty_levelStandard, difficulty_levelHard, difficulty_levelEasy
# Interaction terms depend on reference levels and will be created during fitting
pri <- c(
  # v coefficients explicitly named by difficulty:
  prior(normal(0, 0.04), class = "b", coef = "difficulty_levelStandard"),  # v(Standard) ≈ 0 (tight but not delta)
  prior(normal(0, 0.6), class = "b", coef = "difficulty_levelHard"),
  prior(normal(0, 0.6), class = "b", coef = "difficulty_levelEasy"),
  # Task/effort effects on drift only for non-Standard (via is_nonstd interaction)
  # Note: Exact coefficient names depend on reference levels; brms will handle this
  prior(normal(0, 0.3), class = "b"),  # General prior for interaction terms (will apply to task:is_nonstd and effort:is_nonstd)
  
  # Boundary (bs) priors
  prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
  prior(normal(0, 0.35), class = "b", dpar = "bs"),
  
  # NDT priors
  prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
  prior(normal(0, 0.15), class = "b", dpar = "ndt"),
  
  # Bias priors
  prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
  prior(normal(0, 0.35), class = "b", dpar = "bias"),
  
  # Random effects
  prior(student_t(3, 0, 0.30), class = "sd")
)

cat("\n=== Model Specification ===\n")
cat("Formula:\n")
print(form)
cat("\nPriors:\n")
print(pri)

# Validate priors before fitting
cat("\n=== Validating priors ===\n")
tryCatch({
  validate_prior(form, data = dd, prior = pri)
  cat("✓ Priors validated successfully\n")
}, error = function(e) {
  warning("Prior validation warning: ", e$message)
  cat("This may be due to interaction coefficient names.\n")
  cat("Proceeding with fit - brms will handle coefficient matching.\n")
})

cat("\n=== Fitting model ===\n")
cat("This may take a while (6000 iterations, 3 chains)...\n")

# Safe initialization: NDT must be < min(RT) for all subjects
min_rt_global <- min(dd$rt, na.rm = TRUE)
cat("Global minimum RT:", min_rt_global, "seconds\n")

# Use very conservative initialization: 60% of minimum RT (on log scale)
ndt_init <- log(min_rt_global * 0.6)
cat("Using NDT initialization:", ndt_init, "=", exp(ndt_init), "seconds (60% of min RT)\n")

# Safe initialization function
# Try multiple initialization strategies - brms will use the first that works
safe_init <- function(chain_id = 1) {
  # Strategy: Initialize NDT intercept very low, all other NDT coefs to 0
  # This ensures NDT = exp(low_value + 0 + 0) = low value for all conditions
  list(
    Intercept = 0,
    # Try both possible NDT parameter names
    Intercept_ndt = ndt_init,  # For models without fixed effects
    b_ndt_Intercept = ndt_init  # For models with fixed effects (will be ignored if doesn't exist)
  )
}

cat("Using custom initialization with NDT =", exp(ndt_init), "seconds\n")

fit <- brm(
  form,
  data = dd,
  family = fam,
  prior = pri,
  chains = 3,
  iter = 6000,
  warmup = 3000,
  cores = 3,
  threads = threading(2),
  init = safe_init,
  control = list(adapt_delta = 0.99, max_treedepth = 14),
  backend = "cmdstanr",
  file = "output/models/joint_vza_stdconstrained",
  file_refit = "on_change",
  seed = 20251119
)

cat("\n=== Model fit complete ===\n")
cat("Saving to output/publish/fit_joint_vza_stdconstrained.rds\n")

saveRDS(fit, "output/publish/fit_joint_vza_stdconstrained.rds")

cat("\n=== Model Summary ===\n")
print(summary(fit))

cat("\n=== Checking convergence ===\n")
rhat_max <- max(rhat(fit), na.rm = TRUE)
cat("Max R-hat:", rhat_max, "\n")
if (rhat_max > 1.01) {
  warning("Some parameters have R-hat > 1.01. Consider increasing iterations or checking model specification.")
} else {
  cat("✓ Convergence looks good (R-hat ≤ 1.01)\n")
}

cat("\n=== Checking drift (v) estimates ===\n")
# Extract drift coefficients
v_draws <- as_draws_df(fit, variable = "^b_difficulty_level", regex = TRUE)
if (ncol(v_draws) > 0) {
  v_summary <- summarise_draws(v_draws, mean, median, ~quantile(.x, probs = c(0.05, 0.95)))
  cat("Drift (v) by difficulty:\n")
  print(v_summary)
  cat("\nNote: v(Standard) should be close to 0 (tight prior)\n")
  cat("      v(Easy/Hard) should show difficulty effects\n")
} else {
  cat("Could not extract drift coefficients. Check model output.\n")
}

# Check task/effort effects on drift (non-Standard only)
v_interaction <- as_draws_df(fit, variable = "^b_.*:is_nonstd1", regex = TRUE)
if (ncol(v_interaction) > 0) {
  v_int_summary <- summarise_draws(v_interaction, mean, median, ~quantile(.x, probs = c(0.05, 0.95)))
  cat("\nTask/Effort effects on drift (non-Standard only):\n")
  print(v_int_summary)
}

cat("\n=== Checking bias (z) estimates ===\n")
# Extract bias intercept and effects
bias_draws <- as_draws_df(fit, variable = "^b_bias_", regex = TRUE)
if (ncol(bias_draws) > 0) {
  bias_summary <- summarise_draws(bias_draws, mean, median, ~quantile(.x, probs = c(0.05, 0.95)))
  cat("Bias (z) parameters summary:\n")
  print(bias_summary)
  cat("\nNote: Bias on logit scale. >0 = bias toward 'different', <0 = bias toward 'same'\n")
  cat("Natural scale: expit(intercept) gives the bias parameter z\n")
} else {
  cat("Could not extract bias parameters. Check model output.\n")
}

cat("\n=== Key Model Features ===\n")
cat("1. Uses all trials (Standard, Easy, Hard)\n")
cat("2. Drift on Standard tightly constrained to ≈ 0\n")
cat("3. Task/effort effects on drift only for non-Standard trials\n")
cat("4. Bias estimated with pooling across all conditions\n")
cat("5. Boundary and NDT allow condition effects\n")

cat("\n✓ Model saved successfully!\n")
cat("File: output/publish/fit_joint_vza_stdconstrained.rds\n")

