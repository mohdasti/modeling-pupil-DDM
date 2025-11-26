#!/usr/bin/env Rscript
# =========================================================================
# QUICK BIAS CHECK - Simple Diagnostic
# =========================================================================
# Checks if bias interpretation matches data without full simulation
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(posterior)
  library(readr)
  library(dplyr)
})

cat("=" %+% strrep("=", 78), "\n")
cat("QUICK BIAS DIAGNOSTIC CHECK\n")
cat("=" %+% strrep("=", 78), "\n\n")

# Load fitted model
cat("Loading fitted Standard-only bias model...\n")
fit <- readRDS("output/models/standard_bias_only.rds")

# Load data
cat("Loading data...\n")
data <- read_csv("data/analysis_ready/bap_ddm_only_ready.csv", show_col_types = FALSE)

# Extract Standard trials
std <- data %>% filter(difficulty_level == "Standard")
cat(sprintf("Standard trials: %d\n\n", nrow(std)))

# Check actual data distribution
prop_diff_data <- mean(std$dec_upper, na.rm = TRUE)
prop_same_data <- 1 - prop_diff_data

cat("DATA DISTRIBUTION:\n")
cat(sprintf("  Proportion 'Different' (dec_upper=1): %.3f\n", prop_diff_data))
cat(sprintf("  Proportion 'Same' (dec_upper=0): %.3f\n\n", prop_same_data))

# Extract bias estimate
cat("EXTRACTING BIAS ESTIMATE...\n")
draws <- as_draws_df(fit)
bias_logit <- draws$b_bias_Intercept
bias_prob <- plogis(bias_logit)

bias_mean <- mean(bias_prob)
bias_q025 <- quantile(bias_prob, 0.025)
bias_q975 <- quantile(bias_prob, 0.975)

cat("MODEL BIAS ESTIMATE:\n")
cat(sprintf("  Bias (probability scale): %.3f [%.3f, %.3f]\n", 
            bias_mean, bias_q025, bias_q975))
cat("\n")

# INTERPRETATION
cat("=" %+% strrep("=", 78), "\n")
cat("INTERPRETATION CHECK\n")
cat("=" %+% strrep("=", 78), "\n\n")

cat("In DDM with drift ≈ 0:\n")
cat("  - Bias z represents starting point as proportion from lower to upper boundary\n")
cat("  - z = 0.0 means starting at lower boundary\n")
cat("  - z = 1.0 means starting at upper boundary\n")
cat("  - z = 0.5 means starting at center\n\n")

cat("If dec_upper = 1 means 'Different' (upper boundary):\n")
cat(sprintf("  - Model estimates z = %.3f (%.1f%% toward upper boundary)\n", 
            bias_mean, 100 * bias_mean))
cat(sprintf("  - This should predict ~%.1f%% 'Different' responses\n", 100 * bias_mean))
cat(sprintf("  - But data shows %.1f%% 'Different' responses\n", 100 * prop_diff_data))
cat("\n")

# DIAGNOSIS
cat("=" %+% strrep("=", 78), "\n")
cat("DIAGNOSIS\n")
cat("=" %+% strrep("=", 78), "\n\n")

diff_abs <- abs(bias_mean - prop_diff_data)
diff_flipped <- abs((1 - bias_mean) - prop_diff_data)

if (diff_abs < 0.15) {
  cat("✓ BIAS MATCHES DATA (within 15%%)\n")
  cat("  → Coding is CORRECT\n")
} else if (diff_flipped < 0.15) {
  cat("✗ BIAS DOES NOT MATCH DATA\n")
  cat("✓ BUT: (1 - bias) DOES match data\n")
  cat("  → CODING IS REVERSED!\n")
  cat("  → Need to flip dec_upper: dec_upper = 1 - dec_upper\n")
} else {
  cat("✗ BIAS DOES NOT MATCH DATA\n")
  cat("✗ (1 - bias) ALSO does not match\n")
  cat("  → This suggests a different problem\n")
  cat("  → May need deeper investigation\n")
}

cat("\n")

# Expected values
cat("EXPECTED VALUES:\n")
cat(sprintf("  If 'Different' = upper boundary:\n"))
cat(sprintf("    Bias should be ≈ %.3f (to match %.1f%% 'Different')\n", 
            prop_diff_data, 100 * prop_diff_data))
cat(sprintf("  If 'Same' = upper boundary:\n"))
cat(sprintf("    Bias should be ≈ %.3f (to match %.1f%% 'Same')\n", 
            prop_same_data, 100 * prop_same_data))
cat("\n")

cat("=" %+% strrep("=", 78), "\n")

# Helper function
`%+%` <- function(x, y) paste0(x, y)

