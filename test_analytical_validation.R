#!/usr/bin/env Rscript
# =========================================================================
# TEST: Analytical Validation Function
# =========================================================================
# Quick test to verify the analytical validation works correctly
# =========================================================================

# Define the analytical function directly (same as in validate_ddm_parameters.R)
prob_upper_analytical <- function(v, a, z) {
  # Handle edge case where v is exactly 0 (L'Hopital's rule)
  if (abs(v) < 1e-5) {
    return(z)
  }
  
  # Standard Wiener formula (brms/rtdists uses diffusion coefficient s=1 by default)
  # P(upper) = (exp(-2*v*a*(1-z)) - 1) / (exp(-2*v*a) - 1)
  
  # Calculate terms
  term_numerator <- exp(-2 * v * a * (1 - z)) - 1
  term_denominator <- exp(-2 * v * a) - 1
  
  # Avoid division by zero (shouldn't happen with v ≠ 0, but safety check)
  if (abs(term_denominator) < 1e-10) {
    return(z)  # Fallback to bias-only
  }
  
  prob <- term_numerator / term_denominator
  
  # Ensure probability is in valid range [0, 1]
  prob <- pmax(0, pmin(1, prob))
  
  return(prob)
}

cat(strrep("=", 80), "\n")
cat("TESTING ANALYTICAL VALIDATION FUNCTION\n")
cat(strrep("=", 80), "\n\n")

# Test case: Your actual model results
v_est <- -1.404  # Drift
a_est <- 2.374   # Boundary
z_est <- 0.573   # Bias (probability scale)
data_prop_upper <- 0.109  # 10.9% "Different" responses

cat("Test Case: Your Model Results\n")
cat(strrep("-", 80), "\n")
cat(sprintf("Parameters: v = %.3f, a = %.3f, z = %.3f\n", v_est, a_est, z_est))
cat(sprintf("Observed 'Different' Proportion: %.3f (%.1f%%)\n", data_prop_upper, 100 * data_prop_upper))
cat("\n")

# Calculate predicted proportion
pred_prop_upper <- prob_upper_analytical(v_est, a_est, z_est)

cat("Results:\n")
cat(strrep("-", 80), "\n")
cat(sprintf("Predicted 'Different' Proportion: %.3f (%.1f%%)\n", pred_prop_upper, 100 * pred_prop_upper))
cat(sprintf("Observed 'Different' Proportion: %.3f (%.1f%%)\n", data_prop_upper, 100 * data_prop_upper))
cat(sprintf("Difference: %.4f\n", abs(pred_prop_upper - data_prop_upper)))
cat("\n")

# Validation
diff <- abs(pred_prop_upper - data_prop_upper)

if (diff < 0.05) {
  cat("✅ VALIDATION PASSED: Model parameters accurately predict choice proportions.\n")
  cat("   (The negative drift overrides the bias to produce 'Same' responses.)\n")
} else if (diff < 0.10) {
  cat("⚠ VALIDATION WARNING: Small mismatch (acceptable).\n")
} else {
  cat("❌ VALIDATION FAILED: Large mismatch.\n")
}

cat("\n")

# Test edge cases
cat("Edge Case Tests:\n")
cat(strrep("-", 80), "\n")

# Test 1: v = 0 (should return z)
test1 <- prob_upper_analytical(0, a_est, z_est)
cat(sprintf("v=0: P(upper) = %.3f (should equal z=%.3f) %s\n", 
            test1, z_est, ifelse(abs(test1 - z_est) < 0.001, "✓", "✗")))

# Test 2: Very negative drift
test2 <- prob_upper_analytical(-2.0, a_est, 0.5)
cat(sprintf("v=-2.0, z=0.5: P(upper) = %.3f (should be very low) %s\n", 
            test2, ifelse(test2 < 0.2, "✓", "✗")))

# Test 3: Very positive drift
test3 <- prob_upper_analytical(2.0, a_est, 0.5)
cat(sprintf("v=2.0, z=0.5: P(upper) = %.3f (should be very high) %s\n", 
            test3, ifelse(test3 > 0.8, "✓", "✗")))

cat("\n")
cat(strrep("=", 80), "\n")

