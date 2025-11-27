#!/usr/bin/env Rscript
# =========================================================================
# MODEL COMPARISON: Bias Formula with vs. without difficulty_level
# =========================================================================
# Compares the original primary model (bias ~ difficulty_level + task + ...)
# with the updated model (bias ~ task + effort_condition + ...) using
# Leave-One-Out Cross-Validation (LOO)
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(loo)
  library(dplyr)
  library(readr)
})

# =========================================================================
# CONFIGURATION
# =========================================================================

MODEL_OLD <- "output/models/primary_vza.rds"
MODEL_NEW <- "output/models/primary_vza_bias_constrained.rds"  # Will be created after refitting
OUTPUT_DIR <- "output/results"
LOG_DIR <- "logs"

dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)

LOG_FILE <- file.path(LOG_DIR, sprintf("model_comparison_bias_%s.log", 
                                        format(Sys.time(), "%Y%m%d_%H%M%S")))

log_msg <- function(..., level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  prefix <- switch(level, "INFO" = "[INFO]", "WARN" = "[WARN]", "ERROR" = "[ERROR]")
  msg <- paste(..., collapse = " ")
  cat(sprintf("[%s] %s %s\n", timestamp, prefix, msg))
  cat(sprintf("[%s] %s %s\n", timestamp, prefix, msg), file = LOG_FILE, append = TRUE)
}

# =========================================================================
# LOAD MODELS
# =========================================================================

log_msg("=", strrep("=", 78))
log_msg("MODEL COMPARISON: Bias Formula Specification")
log_msg("=", strrep("=", 78))
log_msg("")

log_msg("Loading models...")

if (!file.exists(MODEL_OLD)) {
  log_msg("ERROR: Old model not found:", MODEL_OLD, level = "ERROR")
  stop("Old model file not found")
}

fit_old <- readRDS(MODEL_OLD)
log_msg("  ✓ Loaded old model (bias ~ difficulty_level + task + ...)")

if (!file.exists(MODEL_NEW)) {
  log_msg("WARNING: New model not found:", MODEL_NEW, level = "WARN")
  log_msg("  This script will compare models after the new model is fitted.")
  log_msg("  Please run fit_primary_vza.R first to create the new model.")
  fit_new <- NULL
} else {
  fit_new <- readRDS(MODEL_NEW)
  log_msg("  ✓ Loaded new model (bias ~ task + effort_condition + ...)")
}

# =========================================================================
# COMPUTE LOO FOR EACH MODEL
# =========================================================================

log_msg("")
log_msg("Computing LOO for each model...")

log_msg("  Computing LOO for old model...")
loo_old <- tryCatch({
  loo(fit_old, cores = 4)
}, error = function(e) {
  log_msg("  ERROR computing LOO for old model:", e$message, level = "ERROR")
  NULL
})

if (!is.null(loo_old)) {
  log_msg("  ✓ LOO computed for old model")
  log_msg(sprintf("    ELPD: %.2f (SE: %.2f)", loo_old$estimates["elpd_loo", "Estimate"], 
                  loo_old$estimates["elpd_loo", "SE"]))
}

if (!is.null(fit_new)) {
  log_msg("  Computing LOO for new model...")
  loo_new <- tryCatch({
    loo(fit_new, cores = 4)
  }, error = function(e) {
    log_msg("  ERROR computing LOO for new model:", e$message, level = "ERROR")
    NULL
  })
  
  if (!is.null(loo_new)) {
    log_msg("  ✓ LOO computed for new model")
    log_msg(sprintf("    ELPD: %.2f (SE: %.2f)", loo_new$estimates["elpd_loo", "Estimate"], 
                    loo_new$estimates["elpd_loo", "SE"]))
  }
} else {
  loo_new <- NULL
}

# =========================================================================
# COMPARE MODELS
# =========================================================================

if (!is.null(loo_old) && !is.null(loo_new)) {
  log_msg("")
  log_msg("Comparing models...")
  
  comparison <- tryCatch({
    loo_compare(loo_old, loo_new)
  }, error = function(e) {
    log_msg("  ERROR comparing models:", e$message, level = "ERROR")
    NULL
  })
  
  if (!is.null(comparison)) {
    log_msg("  ✓ Model comparison completed")
    log_msg("")
    log_msg("  LOO Comparison Results:")
    print(comparison)
    
    # Save comparison
    comparison_file <- file.path(OUTPUT_DIR, "loo_comparison_bias_formulas.csv")
    write_csv(as.data.frame(comparison), comparison_file)
    log_msg("")
    log_msg("  ✓ Saved comparison to:", comparison_file)
    
    # Interpretation
    log_msg("")
    log_msg("  Interpretation:")
    elpd_diff <- comparison[2, "elpd_diff"]
    se_diff <- comparison[2, "se_diff"]
    
    if (abs(elpd_diff) < se_diff) {
      log_msg(sprintf("    Models are equivalent (|ΔELPD| = %.2f < SE = %.2f)", 
                      abs(elpd_diff), se_diff))
      log_msg("    Recommendation: Use simpler model (new model without difficulty in bias)")
    } else if (elpd_diff > 0) {
      log_msg(sprintf("    New model is BETTER (ΔELPD = +%.2f, SE = %.2f)", 
                      elpd_diff, se_diff))
      log_msg("    Recommendation: Use new model (bias ~ task + effort_condition)")
    } else {
      log_msg(sprintf("    Old model is BETTER (ΔELPD = %.2f, SE = %.2f)", 
                      elpd_diff, se_diff))
      log_msg("    WARNING: Removing difficulty from bias formula worsens fit")
    }
  }
} else {
  log_msg("")
  log_msg("  Cannot compare models - LOO computation failed or new model not found", level = "WARN")
}

# =========================================================================
# SUMMARY
# =========================================================================

log_msg("")
log_msg("=", strrep("=", 78))
log_msg("MODEL COMPARISON COMPLETE")
log_msg("=", strrep("=", 78))

