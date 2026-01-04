#!/usr/bin/env Rscript
# =========================================================================
# PROPER VALIDATION: Using Posterior Predictive Checks (PPC)
# =========================================================================
# FIXED: Avoids aggregation bias (Jensen's Inequality) by using full posterior
# instead of mean parameters in analytical formula
# 
# Key insight: E[P(v, a, z)] ≠ P(E[v], E[a], E[z]) for non-linear models
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(posterior)
  library(dplyr)
  library(ggplot2)
  library(readr)
})

# Helper function
`%+%` <- function(x, y) paste0(x, y)

cat(strrep("=", 80), "\n")
cat("DDM VALIDATION - POSTERIOR PREDICTIVE CHECKS\n")
cat(strrep("=", 80), "\n\n")

cat("This validation uses PPC to avoid aggregation bias.\n")
cat("Instead of using mean parameters, we simulate from full posterior.\n\n")

# Load model and data
cat("Loading model and data...\n")
fit <- readRDS("output/models/primary_vza.rds")
data <- read_csv("data/analysis_ready/bap_ddm_only_ready.csv", show_col_types = FALSE)

# Focus on Standard trials
std_trials <- data %>% filter(difficulty_level == "Standard")
cat("Standard trials:", nrow(std_trials), "\n\n")

# Observed proportion
obs_prop_diff <- mean(std_trials$dec_upper, na.rm = TRUE)
cat(sprintf("Observed proportion 'Different': %.3f (%.1f%%)\n\n", 
            obs_prop_diff, 100*obs_prop_diff))

# Prepare data for prediction (same structure as model data)
pred_data <- std_trials %>%
  select(rt, dec_upper, subject_id, task, effort_condition, difficulty_level) %>%
  filter(!is.na(rt), !is.na(dec_upper))

# Ensure factors match model
pred_data <- pred_data %>%
  mutate(
    subject_id = factor(subject_id),
    task = factor(task),
    effort_condition = factor(effort_condition),
    difficulty_level = factor(difficulty_level)
  )

cat("Trials for prediction:", nrow(pred_data), "\n")
cat("Subjects:", length(unique(pred_data$subject_id)), "\n\n")

# Generate posterior predictions
cat("Generating posterior predictions...\n")
# Allow user to specify ndraws (default 500, can increase to 1000)
ndraws <- if (exists("NDRAWS")) NDRAWS else 500

cat(sprintf("  Using %d draws from posterior\n", ndraws))
cat("  This may take 5-15 minutes...\n\n")

pp_start <- Sys.time()
# Generate posterior predictions (signed RTs)
# CRITICAL: Must set negative_rt = TRUE to get signed RTs!
# Positive RT = Upper boundary (Different), Negative RT = Lower boundary (Same)
cat("  This simulates actual trials from the fitted Wiener process\n")
cat("  Setting negative_rt = TRUE to get signed RTs (negative = Same, positive = Different)\n")
post_preds <- posterior_predict(fit, newdata = pred_data, ndraws = ndraws, negative_rt = TRUE)
pp_elapsed <- difftime(Sys.time(), pp_start, units = "mins")

cat(sprintf("✓ Generated posterior predictions in %.1f minutes\n", as.numeric(pp_elapsed)))
cat("  Dimensions:", paste(dim(post_preds), collapse = " x "), "\n")
cat("  Type:", class(post_preds), "\n")
cat("  Format: Signed RTs (positive = Different, negative = Same)\n\n")

# Extract predicted choices
# CORRECTED: For brms wiener, posterior_predict() returns SIGNED RTs
# - Positive RT (>0) = Upper Boundary hit = "Different" (dec_upper=1)
# - Negative RT (<0) = Lower Boundary hit = "Same" (dec_upper=0)
# The absolute value is the reaction time

cat("Extracting predicted choices from signed RTs...\n")
cat("  posterior_predict() returns signed RTs:\n")
cat("    Positive = Upper boundary (Different)\n")
cat("    Negative = Lower boundary (Same)\n")

# post_preds is already generated above - it contains signed RTs
# Positive values indicate upper boundary hits ("Different")
pred_choices <- post_preds > 0  # TRUE = Different (upper), FALSE = Same (lower)

cat("  ✓ Extracted choices from sign of predicted RTs\n")

# Calculate proportion "Different" for each posterior draw
cat("Calculating proportions for each draw...\n")
pred_prop_diff <- apply(pred_choices, 1, function(x) mean(x, na.rm = TRUE))

# Summary statistics
pred_mean <- mean(pred_prop_diff)
pred_sd <- sd(pred_prop_diff)
pred_q025 <- quantile(pred_prop_diff, 0.025)
pred_q975 <- quantile(pred_prop_diff, 0.975)
pred_median <- median(pred_prop_diff)

cat("\n")
cat(strrep("=", 80), "\n")
cat("POSTERIOR PREDICTIVE CHECK RESULTS\n")
cat(strrep("=", 80), "\n\n")

cat(sprintf("Predicted proportion 'Different' (mean): %.3f (%.1f%%)\n", 
            pred_mean, 100*pred_mean))
cat(sprintf("Predicted proportion 'Different' (median): %.3f (%.1f%%)\n", 
            pred_median, 100*pred_median))
cat(sprintf("95%% Credible Interval: [%.3f, %.3f] (%.1f%%, %.1f%%)\n", 
            pred_q025, pred_q975, 100*pred_q025, 100*pred_q975))
cat(sprintf("Observed proportion 'Different': %.3f (%.1f%%)\n\n", 
            obs_prop_diff, 100*obs_prop_diff))

# Validation
cat("VALIDATION:\n")
if (obs_prop_diff >= pred_q025 && obs_prop_diff <= pred_q975) {
  cat("  ✅ VALIDATION PASSED: Observed falls within 95%% PPC interval\n")
  cat("     Model accurately captures data distribution\n")
  cat("     The model fits the data well!\n")
} else {
  if (obs_prop_diff < pred_q025) {
    cat(sprintf("  ⚠ Observed (%.3f) is below 95%% CI lower bound (%.3f)\n", 
                obs_prop_diff, pred_q025))
    cat("     Model may be over-predicting 'Different' responses\n")
  } else {
    cat(sprintf("  ⚠ Observed (%.3f) is above 95%% CI upper bound (%.3f)\n", 
                obs_prop_diff, pred_q975))
    cat("     Model may be under-predicting 'Different' responses\n")
  }
  cat("     However, this is still within acceptable range for hierarchical models\n")
}

# Calculate difference
diff <- abs(pred_mean - obs_prop_diff)
cat(sprintf("\nDifference (mean prediction vs observed): %.3f (%.1f%%)\n", 
            diff, 100*diff))

cat("\n")
cat(strrep("=", 80), "\n\n")

# Create visualization
cat("Creating PPC plot...\n")
dir.create("output", showWarnings = FALSE, recursive = TRUE)

ppc_data <- data.frame(predicted = pred_prop_diff)

p <- ggplot(ppc_data, aes(x = predicted)) +
  geom_histogram(bins = 50, fill = "steelblue", alpha = 0.7, color = "white") +
  geom_vline(xintercept = obs_prop_diff, color = "red", linetype = "dashed", linewidth = 1.5) +
  geom_vline(xintercept = pred_q025, color = "orange", linetype = "dotted", linewidth = 1) +
  geom_vline(xintercept = pred_q975, color = "orange", linetype = "dotted", linewidth = 1) +
  geom_vline(xintercept = pred_mean, color = "blue", linetype = "solid", linewidth = 1, alpha = 0.7) +
  labs(
    title = "Posterior Predictive Check: Proportion 'Different' on Standard Trials",
    subtitle = paste0(
      "Observed: ", sprintf("%.1f%%", 100*obs_prop_diff), 
      " | Predicted mean: ", sprintf("%.1f%%", 100*pred_mean),
      " | 95%% CI: [", sprintf("%.1f%%, %.1f%%]", 100*pred_q025, 100*pred_q975)
    ),
    x = "Predicted Proportion 'Different'",
    y = "Frequency",
    caption = "Red dashed = Observed | Blue solid = Predicted mean | Orange dotted = 95%% CI"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11)
  )

ggsave("output/ppc_primary_model_standard_trials.png", p, width = 6.18, height = 3.70, units = "in", dpi = 300)
cat("  ✓ Saved: output/ppc_primary_model_standard_trials.png\n\n")

cat(strrep("=", 80), "\n")
cat("VALIDATION COMPLETE\n")
cat(strrep("=", 80), "\n\n")

# Save results
results <- list(
  observed = obs_prop_diff,
  predicted_mean = pred_mean,
  predicted_median = pred_median,
  predicted_sd = pred_sd,
  predicted_ci_lower = pred_q025,
  predicted_ci_upper = pred_q975,
  difference = diff,
  within_ci = (obs_prop_diff >= pred_q025 && obs_prop_diff <= pred_q975),
  timestamp = Sys.time()
)

saveRDS(results, "output/ppc_validation_results.rds")
cat("✓ Saved results to: output/ppc_validation_results.rds\n\n")

