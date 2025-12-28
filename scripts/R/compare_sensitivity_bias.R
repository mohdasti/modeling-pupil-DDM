# R/compare_sensitivity_bias.R

# Compare bias estimates from original vs sensitivity (tightened prior) model

suppressPackageStartupMessages({
  library(brms); library(dplyr); library(readr)
})

cat("=== Comparing Original vs Sensitivity Model ===\n\n")

# Load models
m_orig <- readRDS("output/publish/fit_standard_bias_only.rds")
m_sens <- readRDS("output/publish/fit_standard_bias_only_sens.rds")

# Extract fixed effects
fx_orig <- fixef(m_orig)
fx_sens <- fixef(m_sens)

cat("DRIFT (v) Comparison:\n")
cat("  Original (prior: normal(0, 0.03)):\n")
cat("    Estimate:", round(fx_orig["Intercept", "Estimate"], 4), "\n")
cat("    95% CrI: [", round(fx_orig["Intercept", "Q2.5"], 4), ", ", 
    round(fx_orig["Intercept", "Q97.5"], 4), "]\n", sep = "")
cat("  Sensitivity (prior: normal(0, 0.02)):\n")
cat("    Estimate:", round(fx_sens["Intercept", "Estimate"], 4), "\n")
cat("    95% CrI: [", round(fx_sens["Intercept", "Q2.5"], 4), ", ", 
    round(fx_sens["Intercept", "Q97.5"], 4), "]\n", sep = "")
cat("  Difference:", round(fx_sens["Intercept", "Estimate"] - fx_orig["Intercept", "Estimate"], 4), "\n\n")

cat("BIAS INTERCEPT (z) Comparison:\n")
z_orig <- plogis(fx_orig["bias_Intercept", "Estimate"])
z_sens <- plogis(fx_sens["bias_Intercept", "Estimate"])
cat("  Original: z =", round(z_orig, 3), "\n")
cat("  Sensitivity: z =", round(z_sens, 3), "\n")
cat("  Difference:", round(z_sens - z_orig, 4), "(", round((z_sens - z_orig) / z_orig * 100, 2), "%)\n\n")

cat("TASK EFFECT (VDT - ADT) Comparison:\n")
cat("  Original:", round(fx_orig["bias_taskVDT", "Estimate"], 4), "\n")
cat("  Sensitivity:", round(fx_sens["bias_taskVDT", "Estimate"], 4), "\n")
cat("  Difference:", round(fx_sens["bias_taskVDT", "Estimate"] - fx_orig["bias_taskVDT", "Estimate"], 4), "\n\n")

# Create comparison table
comparison <- tibble(
  parameter = c("v(Standard)", "z (bias intercept)", "Task effect (VDT-ADT)"),
  original = c(
    round(fx_orig["Intercept", "Estimate"], 4),
    round(z_orig, 3),
    round(fx_orig["bias_taskVDT", "Estimate"], 4)
  ),
  sensitivity = c(
    round(fx_sens["Intercept", "Estimate"], 4),
    round(z_sens, 3),
    round(fx_sens["bias_taskVDT", "Estimate"], 4)
  ),
  difference = c(
    round(fx_sens["Intercept", "Estimate"] - fx_orig["Intercept", "Estimate"], 4),
    round(z_sens - z_orig, 4),
    round(fx_sens["bias_taskVDT", "Estimate"] - fx_orig["bias_taskVDT", "Estimate"], 4)
  )
)

cat("=== Summary Table ===\n")
print(comparison)

# Save comparison
dir.create("output/publish", recursive = TRUE, showWarnings = FALSE)
write_csv(comparison, "output/publish/sensitivity_comparison.csv")
cat("\n✓ Saved: output/publish/sensitivity_comparison.csv\n")

cat("\n=== Conclusion ===\n")
if (abs(z_sens - z_orig) < 0.01) {
  cat("✅ Bias estimates are STABLE (difference < 1%)\n")
  cat("   Tightening drift prior does not meaningfully affect bias estimates.\n")
} else {
  cat("⚠️  Bias estimates show some variation (difference = ", 
      round((z_sens - z_orig) / z_orig * 100, 2), "%)\n", sep = "")
  cat("   Consider whether this variation is acceptable.\n")
}

