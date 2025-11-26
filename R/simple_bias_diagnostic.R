#!/usr/bin/env Rscript
# =========================================================================
# SIMPLE BIAS DIAGNOSTIC - Direct Check from Model Output
# =========================================================================
# Checks if bias interpretation matches data - no simulation needed
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(posterior)
  library(readr)
  library(dplyr)
})

cat(strrep("=", 80), "\n")
cat("SIMPLE BIAS DIAGNOSTIC CHECK\n")
cat(strrep("=", 80), "\n\n")

# Load model
cat("Loading Standard-only bias model...\n")
fit <- readRDS("output/models/standard_bias_only.rds")

# Load data
cat("Loading data...\n")
data <- read_csv("data/analysis_ready/bap_ddm_only_ready.csv", show_col_types = FALSE)
std <- data %>% filter(difficulty_level == "Standard")

cat(sprintf("Standard trials: %d\n\n", nrow(std)))

# Check data distribution
prop_diff_data <- mean(std$dec_upper, na.rm = TRUE)
prop_same_data <- 1 - prop_diff_data

cat("DATA DISTRIBUTION:\n")
cat(sprintf("  'Different' (dec_upper=1): %.1f%%\n", 100 * prop_diff_data))
cat(sprintf("  'Same' (dec_upper=0): %.1f%%\n\n", 100 * prop_same_data))

# Extract bias estimate
cat("EXTRACTING BIAS FROM MODEL...\n")
draws <- as_draws_df(fit)
bias_logit <- draws$b_bias_Intercept
bias_prob <- plogis(bias_logit)

bias_mean <- mean(bias_prob)
bias_q025 <- quantile(bias_prob, 0.025)
bias_q975 <- quantile(bias_prob, 0.975)

cat("MODEL BIAS ESTIMATE:\n")
cat(sprintf("  z (probability scale): %.3f [%.3f, %.3f]\n\n", 
            bias_mean, bias_q025, bias_q975))

# INTERPRETATION
cat(strrep("=", 80), "\n")
cat("INTERPRETATION\n")
cat(strrep("=", 80), "\n\n")

cat("KEY QUESTION: What does z =", bias_mean, "mean?\n\n")

cat("In DDM with drift ≈ 0:\n")
cat("  - z is starting point as proportion from lower to upper boundary\n")
cat("  - z = 0.0 → starting at lower boundary\n")
cat("  - z = 1.0 → starting at upper boundary\n")
cat("  - z = 0.5 → starting at center\n\n")

cat("IF 'Different' = Upper boundary (dec_upper=1 means upper):\n")
cat(sprintf("  - z = %.3f means %.1f%% toward upper boundary\n", 
            bias_mean, 100 * bias_mean))
cat(sprintf("  - Should predict ~%.1f%% 'Different' responses\n", 100 * bias_mean))
cat(sprintf("  - But data shows %.1f%% 'Different' responses\n\n", 100 * prop_diff_data))

match_normal <- abs(bias_mean - prop_diff_data) < 0.15
match_flipped <- abs((1 - bias_mean) - prop_diff_data) < 0.15

cat("CHECKING MATCHES:\n")
cat(sprintf("  Direct match (bias vs prop_diff): %.3f difference %s\n", 
            abs(bias_mean - prop_diff_data),
            ifelse(match_normal, "✓ MATCH", "✗ NO MATCH")))
cat(sprintf("  Flipped match (1-bias vs prop_diff): %.3f difference %s\n\n", 
            abs((1 - bias_mean) - prop_diff_data),
            ifelse(match_flipped, "✓ MATCH", "✗ NO MATCH")))

# DIAGNOSIS
cat(strrep("=", 80), "\n")
cat("DIAGNOSIS\n")
cat(strrep("=", 80), "\n\n")

if (match_normal) {
  cat("✓ BIAS MATCHES DATA DIRECTLY\n")
  cat("  → Coding is CORRECT\n")
  cat("  → Model is working as expected\n")
} else if (match_flipped) {
  cat("✗ BIAS DOES NOT MATCH DATA DIRECTLY\n")
  cat("✓ BUT: (1 - bias) DOES match data\n\n")
  cat("  → CODING IS REVERSED!\n")
  cat("  → In brms, dec_upper=1 means LOWER boundary, not upper!\n")
  cat("  → OR: Boundaries are interpreted differently than expected\n\n")
  cat("SOLUTION:\n")
  cat("  Flip dec_upper coding:\n")
  cat("    dec_upper = 1 - dec_upper\n")
  cat("  OR\n")
  cat("    dec_upper = ifelse(dec_upper == 1, 0, 1)\n")
} else {
  cat("✗ BIAS DOES NOT MATCH DATA IN EITHER DIRECTION\n")
  cat("  → This suggests a different problem\n")
  cat("  → May need deeper investigation\n")
}

cat("\n")

# RECOMMENDATION
cat(strrep("=", 80), "\n")
cat("RECOMMENDATION\n")
cat(strrep("=", 80), "\n\n")

if (match_flipped) {
  cat("ACTION REQUIRED:\n")
  cat("  1. Flip dec_upper coding in data preparation scripts\n")
  cat("  2. Re-run data preparation\n")
  cat("  3. Re-fit Standard-only model\n")
  cat("  4. Verify bias now matches data\n")
} else if (match_normal) {
  cat("NO ACTION NEEDED:\n")
  cat("  Model is working correctly!\n")
  cat("  The bias estimate may be affected by:\n")
  cat("  - Task/effort effects in the model\n")
  cat("  - Subject-level random effects\n")
  cat("  - Drift effects (even if small)\n")
} else {
  cat("FURTHER INVESTIGATION NEEDED:\n")
  cat("  - Check model specification\n")
  cat("  - Check for interactions\n")
  cat("  - Review brms documentation\n")
}

cat("\n")
cat(strrep("=", 80), "\n")

