# Quick test of PPC approach on single model
library(brms)
library(posterior)

cat("\nTesting PPC approach on Model1_Baseline...\n\n")

model <- readRDS("output/models/Model1_Baseline.rds")
cat("✓ Model loaded\n\n")

# Test 1: posterior_linpred for drift
cat("TEST 1: posterior_linpred() for drift (main response)...\n")
tryCatch({
  drift_test <- posterior_linpred(model, summary = TRUE)
  cat("✓ SUCCESS: drift extraction worked\n")
  cat("  Dimensions:", dim(drift_test), "\n")
  cat("  Class:", class(drift_test), "\n")
  cat("  Structure:\n")
  print(str(drift_test))
}, error = function(e) {
  cat("❌ FAILED:", e$message, "\n")
})

cat("\n")

# Test 2: posterior_linpred for bs
cat("TEST 2: posterior_linpred() for bs (boundary)...\n")
tryCatch({
  bs_test <- posterior_linpred(model, dpar = "bs", summary = TRUE)
  cat("✓ SUCCESS: bs extraction worked\n")
  cat("  Dimensions:", dim(bs_test), "\n")
}, error = function(e) {
  cat("❌ FAILED:", e$message, "\n")
})

cat("\n")

# Test 3: Check if RWiener is available
cat("TEST 3: RWiener package...\n")
if (require(RWiener, quietly = TRUE)) {
  cat("✓ RWiener is installed\n")
} else {
  cat("❌ RWiener is NOT installed\n")
}

cat("\n")

# Test 4: Extract from draws directly
cat("TEST 4: Extract parameters from draws...\n")
tryCatch({
  post_draws <- as_draws_df(model)
  cat("✓ Successfully extracted draws\n")
  cat("  Number of draws:", nrow(post_draws), "\n")
  cat("  Parameter names (first 10):\n")
  print(head(names(post_draws), 10))
  cat("\n  Looking for drift intercept:\n")
  if ("Intercept" %in% names(post_draws)) {
    cat("    ✓ Found 'Intercept'\n")
  }
  if ("Intercept_bs" %in% names(post_draws)) {
    cat("    ✓ Found 'Intercept_bs'\n")
  }
  if ("Intercept_ndt" %in% names(post_draws)) {
    cat("    ✓ Found 'Intercept_ndt'\n")
  }
  if ("Intercept_bias" %in% names(post_draws)) {
    cat("    ✓ Found 'Intercept_bias'\n")
  }
}, error = function(e) {
  cat("❌ FAILED:", e$message, "\n")
})

cat("\nTest complete. Please share output above.\n")








