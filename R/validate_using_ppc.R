#!/usr/bin/env Rscript
# =========================================================================
# PROPER VALIDATION: Using Posterior Predictive Checks (PPC)
# =========================================================================
# FIXED: Avoids aggregation bias (Jensen's Inequality) by using full posterior
# instead of mean parameters in analytical formula
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(posterior)
  library(dplyr)
  library(ggplot2)
})

cat(strrep("=", 80), "\n")
cat("DDM VALIDATION - POSTERIOR PREDICTIVE CHECKS\n")
cat(strrep("=", 80), "\n\n")

# Load model and data
cat("Loading model and data...\n")
fit <- readRDS("output/models/primary_vza.rds")
data <- read_csv("data/analysis_ready/bap_ddm_only_ready.csv", show_col_types = FALSE)

std_trials <- data %>% filter(difficulty_level == "Standard")
cat("Standard trials:", nrow(std_trials), "\n\n")

# Observed proportion
obs_prop_diff <- mean(std_trials$dec_upper, na.rm = TRUE)
cat(sprintf("Observed proportion 'Different': %.3f (%.1f%%)\n\n", 
            obs_prop_diff, 100*obs_prop_diff))

# Generate posterior predictions
cat("Generating posterior predictions (this may take a few minutes)...\n")
cat("Using 500 draws from posterior...\n\n")

# Prepare data for prediction
pred_data <- std_trials %>%
  select(rt, dec_upper, subject_id, task, effort_condition, difficulty_level) %>%
  filter(!is.na(rt), !is.na(dec_upper))

cat("Trials for prediction:", nrow(pred_data), "\n\n")

# Generate predictions
post_preds <- posterior_predict(fit, newdata = pred_data, ndraws = 500)

cat("Generated predictions. Structure:\n")
cat("  Dimensions:", paste(dim(post_preds), collapse = " x "), "\n")
cat("  Type:", class(post_preds), "\n\n")

# Extract predicted choices
# brms wiener: posterior_predict returns RT with sign indicating boundary
# Positive RT = upper boundary (Different), Negative RT = lower boundary (Same)
pred_choices <- post_preds > 0  # Positive = Different (upper)

# Calculate proportion "Different" for each posterior draw
pred_prop_diff <- apply(pred_choices, 1, function(x) mean(x, na.rm = TRUE))

# Summary
pred_mean <- mean(pred_prop_diff)
pred_q025 <- quantile(pred_prop_diff, 0.025)
pred_q975 <- quantile(pred_prop_diff, 0.975)

cat(strrep("=", 80), "\n")
cat("POSTERIOR PREDICTIVE CHECK RESULTS\n")
cat(strrep("=", 80), "\n\n")

cat(sprintf("Predicted proportion 'Different' (mean): %.3f (%.1f%%)\n", 
            pred_mean, 100*pred_mean))
cat(sprintf("95% Credible Interval: [%.3f, %.3f] (%.1f%%, %.1f%%)\n", 
            pred_q025, pred_q975, 100*pred_q025, 100*pred_q975))
cat(sprintf("Observed proportion 'Different': %.3f (%.1f%%)\n\n", 
            obs_prop_diff, 100*obs_prop_diff))

# Validation
if (obs_prop_diff >= pred_q025 && obs_prop_diff <= pred_q975) {
  cat("✅ VALIDATION PASSED: Observed falls within 95% PPC interval\n")
  cat("   Model accurately captures data distribution\n")
} else {
  if (obs_prop_diff < pred_q025) {
    cat(sprintf("⚠ Observed (%.3f) is below 95% CI lower bound (%.3f)\n", 
                obs_prop_diff, pred_q025))
  } else {
    cat(sprintf("⚠ Observed (%.3f) is above 95% CI upper bound (%.3f)\n", 
                obs_prop_diff, pred_q975))
  }
}

cat("\n")

# Visualize
cat("Creating PPC plot...\n")
ppc_data <- data.frame(
  predicted = pred_prop_diff,
  observed = obs_prop_diff
)

p <- ggplot(ppc_data, aes(x = predicted)) +
  geom_histogram(bins = 50, fill = "steelblue", alpha = 0.7) +
  geom_vline(xintercept = obs_prop_diff, color = "red", linetype = "dashed", linewidth = 1.5) +
  geom_vline(xintercept = pred_q025, color = "orange", linetype = "dotted") +
  geom_vline(xintercept = pred_q975, color = "orange", linetype = "dotted") +
  labs(
    title = "Posterior Predictive Check: Proportion 'Different' on Standard Trials",
    x = "Predicted Proportion 'Different'",
    y = "Frequency",
    subtitle = paste0("Observed: ", sprintf("%.1f%%", 100*obs_prop_diff),
                     " | Predicted mean: ", sprintf("%.1f%%", 100*pred_mean),
                     " | 95% CI: [", sprintf("%.1f%%, %.1f%%]", 
                                            100*pred_q025, 100*pred_q975))
  ) +
  theme_minimal()

ggsave("output/ppc_primary_model_standard_trials.png", p, width = 10, height = 6)
cat("  ✓ Saved: output/ppc_primary_model_standard_trials.png\n\n")

cat(strrep("=", 80), "\n")

