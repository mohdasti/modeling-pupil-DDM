# =========================================================================
# DIAGNOSTIC: Test posterior_predict() to find the issue
# =========================================================================

library(brms)

cat("\n")
cat("================================================================================\n")
cat("DIAGNOSTIC: Testing posterior_predict() for Wiener models\n")
cat("================================================================================\n\n")

model_file <- "output/models/Model1_Baseline.rds"

if (!file.exists(model_file)) {
  stop("Model file not found: ", model_file)
}

cat("Loading Model1_Baseline...\n")
model <- readRDS(model_file)
cat("✓ Model loaded\n\n")

cat("Model info:\n")
cat("  Family:", model$family$family, "\n")
cat("  Trials in model:", nrow(model$data), "\n\n")

# Test with MINIMAL draws
cat("TEST: posterior_predict() with 1 draw (should be instant)\n")
cat("Starting at:", format(Sys.time(), "%H:%M:%S"), "\n")
flush.console()

test_start <- Sys.time()
tryCatch({
  pp_test <- posterior_predict(
    model,
    draws = 1,
    summary = FALSE
  )
  test_elapsed <- difftime(Sys.time(), test_start, units = "secs")
  cat("✓ SUCCESS: 1 draw took", round(as.numeric(test_elapsed), 1), "seconds\n")
  cat("  If this takes >10 seconds, posterior_predict() is the problem\n\n")
}, error = function(e) {
  cat("❌ FAILED:", e$message, "\n\n")
})
