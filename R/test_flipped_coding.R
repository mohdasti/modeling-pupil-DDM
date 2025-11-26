#!/usr/bin/env Rscript
# =========================================================================
# TEST FLIPPED CODING - Quick Test
# =========================================================================
# Tests if flipping dec_upper makes bias match data
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(posterior)
  library(readr)
  library(dplyr)
})

cat(strrep("=", 80), "\n")
cat("TESTING FLIPPED CODING\n")
cat(strrep("=", 80), "\n\n")

# Load data
cat("Loading data...\n")
data <- read_csv("data/analysis_ready/bap_ddm_only_ready.csv", show_col_types = FALSE)
std <- data %>% filter(difficulty_level == "Standard")

cat(sprintf("Standard trials: %d\n", nrow(std)))
cat(sprintf("Original coding - 'Different' (dec_upper=1): %.1f%%\n", 
            100 * mean(std$dec_upper, na.rm=TRUE)))

# Test: Flip the coding
std_test <- std %>%
  mutate(
    dec_upper_flipped = 1L - dec_upper  # Flip: 1->0, 0->1
  )

cat(sprintf("Flipped coding - 'Different' (dec_upper_flipped=1): %.1f%%\n\n", 
            100 * mean(std_test$dec_upper_flipped, na.rm=TRUE)))

# Load existing model to check what it actually predicts
cat("Loading existing model...\n")
fit_original <- readRDS("output/models/standard_bias_only.rds")

draws <- as_draws_df(fit_original)
bias_original <- mean(plogis(draws$b_bias_Intercept))

cat(sprintf("Original model bias: %.3f\n\n", bias_original))

# Analysis
cat(strrep("=", 80), "\n")
cat("ANALYSIS\n")
cat(strrep("=", 80), "\n\n")

prop_diff_original <- mean(std$dec_upper)
prop_diff_flipped <- mean(std_test$dec_upper_flipped)

cat("ORIGINAL CODING (dec_upper=1 means 'Different'):\n")
cat(sprintf("  Data: %.1f%% 'Different'\n", 100 * prop_diff_original))
cat(sprintf("  Model bias: %.3f\n", bias_original))
cat(sprintf("  Difference: %.3f\n\n", abs(bias_original - prop_diff_original)))

cat("FLIPPED CODING (dec_upper_flipped=1 means 'Same'):\n")
cat(sprintf("  Data: %.1f%% 'Different' (now coded as 0)\n", 100 * prop_diff_original))
cat(sprintf("  Data: %.1f%% 'Same' (now coded as 1)\n", 100 * prop_diff_flipped))
cat(sprintf("  Model bias: %.3f (if we flipped, would need 1 - bias)\n", bias_original))
cat(sprintf("  Flipped bias: %.3f\n", 1 - bias_original))
cat(sprintf("  Difference from 'Same' proportion: %.3f\n\n", 
            abs((1 - bias_original) - prop_diff_flipped)))

# Check which matches better
match_original <- abs(bias_original - prop_diff_original)
match_flipped_same <- abs((1 - bias_original) - prop_diff_flipped)
match_flipped_diff <- abs(bias_original - prop_diff_flipped)

cat("MATCH COMPARISON:\n")
cat(sprintf("  Original coding vs 'Different': %.3f\n", match_original))
cat(sprintf("  Flipped coding vs 'Same': %.3f\n", match_flipped_same))
cat(sprintf("  Flipped coding vs 'Different': %.3f\n", match_flipped_diff))

best_match <- min(match_original, match_flipped_same, match_flipped_diff)

if (match_original == best_match) {
  cat("\n✓ Best match: Original coding (but still large difference!)\n")
} else if (match_flipped_same == best_match) {
  cat("\n✓ Best match: Flipped coding matches 'Same' proportion\n")
  cat("  → This suggests boundaries are REVERSED in brms!\n")
} else {
  cat("\n✓ Best match: Flipped coding matches 'Different' (unlikely)\n")
}

cat("\n")

# Recommendation
cat(strrep("=", 80), "\n")
cat("RECOMMENDATION\n")
cat(strrep("=", 80), "\n\n")

if (match_flipped_same < 0.2 && match_flipped_same < match_original) {
  cat("✓ STRONG EVIDENCE: Boundaries are REVERSED\n")
  cat("\nSOLUTION:\n")
  cat("  1. Update data preparation scripts:\n")
  cat("     dec_upper = ifelse(resp_is_diff == TRUE, 0L, 1L)  # FLIP!\n")
  cat("  2. Re-run data preparation\n")
  cat("  3. Re-fit Standard-only model\n")
  cat("  4. Verify bias now matches data\n")
} else {
  cat("⚠ UNSURE: Need to investigate further\n")
  cat("\nPOSSIBLE ISSUES:\n")
  cat("  - Task/effort effects are large\n")
  cat("  - Random effects are shifting estimates\n")
  cat("  - Model specification issue\n")
  cat("\nNEXT STEPS:\n")
  cat("  - Check brms documentation on dec() function\n")
  cat("  - Review existing parameter recovery scripts\n")
  cat("  - Consider simpler model without task/effort effects\n")
}

cat("\n")
cat(strrep("=", 80), "\n")

