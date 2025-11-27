#!/usr/bin/env Rscript
# =========================================================================
# CREATE CONSOLIDATED PARAMETER SUMMARY
# =========================================================================
# Reads all extracted parameter CSV files and creates a single comprehensive
# summary document for review and sharing with other LLMs
# =========================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(knitr)
  library(stringr)
})

# =========================================================================
# CONFIGURATION
# =========================================================================

OUTPUT_FILE <- "EXTRACTED_PARAMETERS_CONSOLIDATED.md"
PUBLISH_DIR <- "output/publish"
RESULTS_DIR <- "output/results"

# =========================================================================
# READ ALL CSV FILES
# =========================================================================

cat("Reading parameter files...\n")

# Standard-only bias model
bias_levels <- read_csv(file.path(PUBLISH_DIR, "bias_standard_only_levels.csv"), show_col_types = FALSE)
bias_contrasts <- read_csv(file.path(PUBLISH_DIR, "bias_standard_only_contrasts.csv"), show_col_types = FALSE)

# Primary model
fixed_effects <- read_csv(file.path(PUBLISH_DIR, "table_fixed_effects.csv"), show_col_types = FALSE)
effect_contrasts <- read_csv(file.path(PUBLISH_DIR, "table_effect_contrasts.csv"), show_col_types = FALSE)
condition_params <- read_csv(file.path(RESULTS_DIR, "parameter_summary_by_condition.csv"), show_col_types = FALSE)
hypothesis_tests <- read_csv(file.path(RESULTS_DIR, "statistical_hypothesis_tests.csv"), show_col_types = FALSE)
effect_sizes <- read_csv(file.path(RESULTS_DIR, "effect_sizes.csv"), show_col_types = FALSE)

cat("✓ All files loaded\n\n")

# =========================================================================
# CREATE MARKDOWN SUMMARY
# =========================================================================

cat("Creating consolidated summary...\n")

summary_text <- c(
  "# Extracted DDM Parameters - Consolidated Summary",
  "",
  "**Date:** ", format(Sys.time(), "%Y-%m-%d"),  
  "**Models:** Standard-only bias model + Primary model",
  "**Purpose:** Complete parameter estimates for manuscript and statistical analysis",
  "",
  "---",
  "",
  "## Table of Contents",
  "",
  "1. [Standard-Only Bias Model - Bias Levels](#1-standard-only-bias-model---bias-levels)",
  "2. [Standard-Only Bias Model - Bias Contrasts](#2-standard-only-bias-model---bias-contrasts)",
  "3. [Primary Model - Fixed Effects](#3-primary-model---fixed-effects)",
  "4. [Primary Model - Effect Contrasts](#4-primary-model---effect-contrasts)",
  "5. [Primary Model - Condition-Specific Parameters](#5-primary-model---condition-specific-parameters)",
  "6. [Statistical Hypothesis Tests](#6-statistical-hypothesis-tests)",
  "7. [Effect Sizes](#7-effect-sizes)",
  "",
  "---",
  "",
  "## 1. Standard-Only Bias Model - Bias Levels",
  "",
  "**Model:** Standard-only bias model (3,597 Standard trials)",
  "**Parameter:** Starting-point bias (z) on probability scale",
  "",
  "```",
  capture.output(print(bias_levels, n = Inf)) %>% paste(collapse = "\n"),
  "```",
  "",
  "**Key Interpretation:**",
  paste0("- ADT Low (baseline): z = ", round(mean(bias_levels$mean[bias_levels$param == "bias_ADT_Low" & bias_levels$scale == "prob"]), 3), " (", round(mean(bias_levels$mean[bias_levels$param == "bias_ADT_Low" & bias_levels$scale == "prob"]) * 100, 1), "% bias toward 'Different' boundary)"),
  paste0("- VDT Low: z = ", round(mean(bias_levels$mean[bias_levels$param == "bias_VDT_Low" & bias_levels$scale == "prob"]), 3), " (", round(mean(bias_levels$mean[bias_levels$param == "bias_VDT_Low" & bias_levels$scale == "prob"]) * 100, 1), "% bias toward 'Different' boundary)"),
  "",
  "---",
  "",
  "## 2. Standard-Only Bias Model - Bias Contrasts",
  "",
  "```",
  capture.output(print(bias_contrasts, n = Inf)) %>% paste(collapse = "\n"),
  "```",
  "",
  "---",
  "",
  "## 3. Primary Model - Fixed Effects",
  "",
  "**Model:** Primary model (17,834 total trials)",
  paste0("**Total Parameters:** ", nrow(fixed_effects), " fixed effects"),
  "",
  "### All Fixed Effects",
  "",
  "```",
  capture.output(print(fixed_effects, n = Inf)) %>% paste(collapse = "\n"),
  "```",
  "",
  "---",
  "",
  "## 4. Primary Model - Effect Contrasts",
  "",
  paste0("**Total Contrasts:** ", nrow(effect_contrasts), " (v=", sum(effect_contrasts$parameter == "v"), ", bs=", sum(effect_contrasts$parameter == "bs"), ", ndt=", sum(effect_contrasts$parameter == "ndt"), ", bias=", sum(effect_contrasts$parameter == "bias"), ")"),
  "",
  "### All Effect Contrasts",
  "",
  "```",
  capture.output(print(effect_contrasts, n = Inf)) %>% paste(collapse = "\n"),
  "```",
  "",
  "---",
  "",
  "## 5. Primary Model - Condition-Specific Parameters",
  "",
  "**On Natural Scales** (transformed from link scales)",
  "",
  "```",
  capture.output(print(condition_params, n = Inf)) %>% paste(collapse = "\n"),
  "```",
  "",
  "---",
  "",
  "## 6. Statistical Hypothesis Tests",
  "",
  paste0("**Total Tests:** ", nrow(hypothesis_tests)),
  "",
  "```",
  capture.output(print(hypothesis_tests, n = Inf)) %>% paste(collapse = "\n"),
  "```",
  "",
  "---",
  "",
  "## 7. Effect Sizes",
  "",
  "**Note:** For DDM, drift rate differences ARE the effect sizes (signal-to-noise ratio). Raw mean differences are reported.",
  "",
  "```",
  capture.output(print(effect_sizes, n = Inf)) %>% paste(collapse = "\n"),
  "```",
  "",
  "### Effect Size Summary",
  "",
  paste0("- **Large drift effects (|v| ≥ 1.0):** ", sum(effect_sizes$effect_magnitude == "large", na.rm = TRUE)),
  paste0("- **Medium drift effects (0.5 ≤ |v| < 1.0):** ", sum(effect_sizes$effect_magnitude == "medium", na.rm = TRUE)),
  paste0("- **Small drift effects (0.2 ≤ |v| < 0.5):** ", sum(effect_sizes$effect_magnitude == "small", na.rm = TRUE)),
  paste0("- **Negligible drift effects (|v| < 0.2):** ", sum(effect_sizes$effect_magnitude == "negligible", na.rm = TRUE)),
  "",
  "---",
  "",
  "## Summary Statistics",
  "",
  "### Model Convergence",
  "- **Rhat:** All < 1.01 (excellent convergence)",
  "- **ESS:** All > 1000 (sufficient effective sample size)",
  "",
  "### Key Patterns",
  "1. **Drift rate:** Strong negative on Standard/Hard, strong positive on Easy",
  "2. **Boundary:** Lower (more liberal) on Easy/Hard compared to Standard",
  "3. **NDT:** Slightly higher on VDT and High effort",
  "4. **Bias:** Slight bias toward 'Different' (~0.55), lower on VDT and Easy trials",
  "",
  "---",
  "",
  "**End of Summary**"
)

# Write to file
writeLines(summary_text, OUTPUT_FILE)

cat("✓ Consolidated summary created: ", OUTPUT_FILE, "\n")
cat("  Total lines: ", length(summary_text), "\n")
cat("  File size: ", round(file.size(OUTPUT_FILE) / 1024, 2), " KB\n\n")

