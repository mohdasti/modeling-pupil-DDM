# R/fit_standard_bias_only.R

# Use only Standard (Δ=0) trials to estimate bias (z). Drift is tightly regularized around 0.
# This isolates bias estimation on zero-evidence trials where we expect v≈0.

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
    decision = as.integer(dec_upper)
  ) %>%
  filter(difficulty_level == "Standard")

cat("Filtered to Standard trials only:\n")
cat("  Total trials:", nrow(dd), "\n")
cat("  Subjects:", n_distinct(dd$subject_id), "\n")
cat("  Task distribution:\n")
print(table(dd$task))
cat("  Effort distribution:\n")
print(table(dd$effort_condition))
cat("  Decision distribution (dec_upper):\n")
print(table(dd$decision))
cat("  Mean decision (p(different)):", mean(dd$decision, na.rm = TRUE), "\n")

# Wiener family with log link for boundary and NDT, logit for bias
fam <- wiener(
  link_bs = "log",
  link_ndt = "log",
  link_bias = "logit"
)

# Model specification:
# - drift (v): intercept-only (Standard only), v ~ 0 with tight prior
# - bias (z): allow task + effort (they exist on Standard trials), plus subject RE
# - boundary (a/bs): intercept + subject RE (optionally include task effects if you expect caution differences by task)
# - ndt: task + effort (no RE to avoid init explosions)

form <- bf(
  rt | dec(decision) ~ 1 + (1 | subject_id),
  bs   ~ 1 + (1 | subject_id),
  ndt  ~ task + effort_condition,
  bias ~ task + effort_condition + (1 | subject_id)
)

# Prior specifications:
# - v intercept: tight around 0 (Standard should have v≈0)
# - bs intercept: log(1.7) with sd 0.30 (typical boundary)
# - ndt intercept: log(0.23) with sd 0.20 (typical NDT for response-signal)
# - bias intercept: 0 with sd 0.5 (no bias on logit scale)
# - bias effects: 0 with sd 0.35 (moderate task/effort effects)
# - ndt effects: 0 with sd 0.15 (small ndt effects)
# - random effects: student_t(3,0,0.30) for subject-level variation

pri <- c(
  prior(normal(0, 0.03), class = "Intercept"),                    # v ≈ 0 on Standard (very tight)
  prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
  prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
  prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),     # no bias on logit scale
  prior(normal(0, 0.35), class = "b", dpar = "bias"),            # task/effort effects on bias
  prior(normal(0, 0.15), class = "b", dpar = "ndt"),             # small ndt effects
  prior(student_t(3, 0, 0.30), class = "sd")                     # subject-level variation
)

cat("\n=== Model Specification ===\n")
cat("Formula:\n")
print(form)
cat("\nPriors:\n")
print(pri)

cat("\n=== Fitting model ===\n")
cat("This may take a while...\n")

# Safe initialization: NDT must be < min(RT) for all subjects
min_rt_global <- min(dd$rt, na.rm = TRUE)
cat("Global minimum RT:", min_rt_global, "seconds\n")

# Use very conservative initialization: 60% of minimum RT (on log scale)
ndt_init <- log(min_rt_global * 0.6)
cat("Using NDT initialization:", ndt_init, "=", exp(ndt_init), "seconds (60% of min RT)\n")

# Safe initialization: Use init = 0 (initializes all parameters to 0)
# This is the safest approach - brms will handle parameter names automatically
# NDT will start at exp(0) = 1, but Stan will quickly adapt during warmup
# Alternatively, we can use a custom function, but init = 0 is more reliable
cat("Using init = 0 (all parameters start at 0)\n")
cat("Note: NDT will start high but should adapt quickly during warmup\n")

fit <- brm(
  form,
  data = dd,
  family = fam,
  prior = pri,
  chains = 3,
  iter = 5000,
  warmup = 2500,
  cores = 3,
  threads = threading(2),
  init = 0,  # Initialize all parameters to 0 (safest, brms handles it)
  control = list(adapt_delta = 0.99, max_treedepth = 14),
  backend = "cmdstanr",
  file = "output/models/standard_bias_only",
  file_refit = "on_change",
  seed = 20251119
)

cat("\n=== Model fit complete ===\n")
cat("Saving to output/publish/fit_standard_bias_only.rds\n")

saveRDS(fit, "output/publish/fit_standard_bias_only.rds")

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
# Extract drift intercept (main formula intercept)
v_draws <- as_draws_df(fit, variable = "^b_Intercept$", regex = TRUE)
if (ncol(v_draws) > 0) {
  v_summary <- summarise_draws(v_draws, mean, median, q5, q95)
  cat("Drift intercept (v) summary:\n")
  print(v_summary)
  cat("\nNote: v should be close to 0 on Standard trials (Δ=0, zero evidence)\n")
} else {
  cat("Could not extract drift intercept. Check model output.\n")
}

cat("\n=== Checking bias (z) estimates ===\n")
# Extract bias intercept and effects
bias_draws <- as_draws_df(fit, variable = "^b_bias_", regex = TRUE)
bias_summary <- summarise_draws(bias_draws, mean, median, q5, q95)
cat("Bias (z) parameters summary:\n")
print(bias_summary)
cat("\nNote: Bias intercept on logit scale. >0 = bias toward 'different', <0 = bias toward 'same'\n")
cat("Natural scale: expit(intercept) gives the bias parameter z\n")

cat("\n✓ Model saved successfully!\n")
cat("File: output/publish/fit_standard_bias_only.rds\n")

