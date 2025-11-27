#!/usr/bin/env Rscript
# =========================================================================
# EXTRACT AND REGENERATE MANUSCRIPT TABLES FROM UPDATED MODELS
# =========================================================================
# This script extracts parameter estimates from the updated model files
# and regenerates all CSV table files for the manuscript
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(dplyr)
  library(readr)
  library(posterior)
  library(tidyr)
  library(tibble)
})

# =========================================================================
# CONFIGURATION
# =========================================================================

OUTPUT_DIR <- "output/publish"
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

MODEL_STD_BIAS <- "output/models/standard_bias_only.rds"
MODEL_PRIMARY <- "output/models/primary_vza.rds"

log_msg <- function(..., level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  prefix <- switch(level, "INFO" = "[INFO]", "WARN" = "[WARN]", "ERROR" = "[ERROR]")
  cat(sprintf("[%s] %s", timestamp, prefix), ..., "\n")
}

# Helper: Inverse logit
inv_logit <- function(x) 1 / (1 + exp(-x))

# =========================================================================
# STEP 1: EXTRACT BIAS LEVELS FROM STANDARD-ONLY MODEL
# =========================================================================

log_msg("=", strrep("=", 78))
log_msg("STEP 1: Extracting bias levels from Standard-only model")
log_msg("=", strrep("=", 78))

if (!file.exists(MODEL_STD_BIAS)) {
  stop("Standard-only bias model not found: ", MODEL_STD_BIAS)
}

fit_std <- readRDS(MODEL_STD_BIAS)
log_msg("  Loaded model:", MODEL_STD_BIAS)

# Get posterior samples
post_samples <- as_draws_df(fit_std)

# Extract bias intercept and slopes
bias_intercept <- post_samples$b_bias_Intercept
bias_task_vdt <- post_samples$b_bias_taskVDT
bias_effort_high <- post_samples$`b_bias_effort_conditionHigh_40_MVC`

# Compute bias levels for each condition combination
# Baseline: ADT, Low effort (Intercept only)
bias_ADT_Low_logit <- bias_intercept
bias_ADT_Low_prob <- inv_logit(bias_intercept)

# ADT, High effort
bias_ADT_High_logit <- bias_intercept + bias_effort_high
bias_ADT_High_prob <- inv_logit(bias_intercept + bias_effort_high)

# VDT, Low effort
bias_VDT_Low_logit <- bias_intercept + bias_task_vdt
bias_VDT_Low_prob <- inv_logit(bias_intercept + bias_task_vdt)

# VDT, High effort
bias_VDT_High_logit <- bias_intercept + bias_task_vdt + bias_effort_high
bias_VDT_High_prob <- inv_logit(bias_intercept + bias_task_vdt + bias_effort_high)

# Create summary statistics for each condition
compute_summary <- function(samples, name, scale_type) {
  tibble(
    param = name,
    scale = scale_type,
    mean = mean(samples),
    sd = sd(samples),
    q2.5 = quantile(samples, 0.025),
    q97.5 = quantile(samples, 0.975)
  )
}

bias_levels <- bind_rows(
  compute_summary(bias_ADT_Low_logit, "bias_ADT_Low", "logit"),
  compute_summary(bias_ADT_Low_prob, "bias_ADT_Low", "prob"),
  compute_summary(bias_ADT_High_logit, "bias_ADT_High", "logit"),
  compute_summary(bias_ADT_High_prob, "bias_ADT_High", "prob"),
  compute_summary(bias_VDT_Low_logit, "bias_VDT_Low", "logit"),
  compute_summary(bias_VDT_Low_prob, "bias_VDT_Low", "prob"),
  compute_summary(bias_VDT_High_logit, "bias_VDT_High", "logit"),
  compute_summary(bias_VDT_High_prob, "bias_VDT_High", "prob")
)

# Save bias levels
bias_levels_file <- file.path(OUTPUT_DIR, "bias_standard_only_levels.csv")
write_csv(bias_levels, bias_levels_file)
log_msg("  ✓ Saved:", bias_levels_file)

# =========================================================================
# STEP 2: EXTRACT BIAS CONTRASTS FROM STANDARD-ONLY MODEL
# =========================================================================

log_msg("")
log_msg("STEP 2: Extracting bias contrasts from Standard-only model")

# Task contrast: VDT - ADT (on logit scale)
task_contrast_logit <- bias_task_vdt

# Effort contrast: High - Low (on logit scale)
effort_contrast_logit <- bias_effort_high

# Create contrasts table
bias_contrasts <- bind_rows(
  tibble(
    contrast = "VDT - ADT (bias, logit)",
    mean = mean(task_contrast_logit),
    sd = sd(task_contrast_logit),
    q2.5 = quantile(task_contrast_logit, 0.025),
    q97.5 = quantile(task_contrast_logit, 0.975),
    Pr_gt_0 = mean(task_contrast_logit > 0)
  ),
  tibble(
    contrast = "High - Low (bias, logit)",
    mean = mean(effort_contrast_logit),
    sd = sd(effort_contrast_logit),
    q2.5 = quantile(effort_contrast_logit, 0.025),
    q97.5 = quantile(effort_contrast_logit, 0.975),
    Pr_gt_0 = mean(effort_contrast_logit > 0)
  )
)

# Save bias contrasts
bias_contrasts_file <- file.path(OUTPUT_DIR, "bias_standard_only_contrasts.csv")
write_csv(bias_contrasts, bias_contrasts_file)
log_msg("  ✓ Saved:", bias_contrasts_file)

# =========================================================================
# STEP 3: EXTRACT FIXED EFFECTS FROM PRIMARY MODEL
# =========================================================================

log_msg("")
log_msg("=", strrep("=", 78))
log_msg("STEP 3: Extracting fixed effects from Primary model")
log_msg("=", strrep("=", 78))

if (!file.exists(MODEL_PRIMARY)) {
  stop("Primary model not found: ", MODEL_PRIMARY)
}

fit_primary <- readRDS(MODEL_PRIMARY)
log_msg("  Loaded model:", MODEL_PRIMARY)

# Extract fixed effects summary
fixef_summary <- fixef(fit_primary, summary = TRUE)

# Convert to data frame
fx_table <- as.data.frame(fixef_summary)
fx_table$parameter <- rownames(fx_table)
fx_table <- fx_table %>%
  transmute(
    parameter = parameter,
    estimate = Estimate,
    conf.low = `Q2.5`,
    conf.high = `Q97.5`,
    est.error = `Est.Error`,
    rhat = NA_real_,  # Will add if available
    ess = NA_real_     # Will add if available
  )

# Add Rhat and ESS if available from summary
summary_primary <- summary(fit_primary)
if (!is.null(summary_primary$fixed)) {
  fx_table <- fx_table %>%
    mutate(
      rhat = summary_primary$fixed$Rhat[match(parameter, rownames(summary_primary$fixed))],
      ess = summary_primary$fixed$Bulk_ESS[match(parameter, rownames(summary_primary$fixed))]
    )
}

# Save fixed effects
fx_table_file <- file.path(OUTPUT_DIR, "table_fixed_effects.csv")
write_csv(fx_table, fx_table_file)
log_msg("  ✓ Saved:", fx_table_file)

# =========================================================================
# STEP 4: EXTRACT EFFECT CONTRASTS FROM PRIMARY MODEL
# =========================================================================

log_msg("")
log_msg("STEP 4: Extracting effect contrasts from Primary model")

# Get posterior samples for primary model
post_primary <- as_draws_df(fit_primary)

# Extract key parameters for contrasts
# Note: Adjust column names based on actual model structure
contrast_list <- list()

# Helper function to compute contrasts
compute_contrast <- function(samples, name) {
  tibble(
    contrast = name,
    parameter = "Drift (v)",
    mean = mean(samples),
    q05 = quantile(samples, 0.05),
    q95 = quantile(samples, 0.95),
    p_gt0 = mean(samples > 0),
    p_lt0 = mean(samples < 0),
    p_in_rope = mean(abs(samples) < 0.02)  # ROPE for drift
  )
}

# Difficulty contrasts (Easy - Hard, Easy - Standard, Hard - Standard)
if ("b_difficulty_levelEasy" %in% colnames(post_primary)) {
  easy_v <- post_primary$b_difficulty_levelEasy
  hard_v <- post_primary$`b_difficulty_levelHard`
  
  contrast_list[[length(contrast_list) + 1]] <- compute_contrast(
    easy_v - hard_v, 
    "Easy - Hard"
  )
  contrast_list[[length(contrast_list) + 1]] <- compute_contrast(
    easy_v, 
    "Easy - Standard"
  )
  contrast_list[[length(contrast_list) + 1]] <- compute_contrast(
    hard_v, 
    "Hard - Standard"
  )
}

# Task contrast (VDT - ADT)
if ("b_taskVDT" %in% colnames(post_primary)) {
  contrast_list[[length(contrast_list) + 1]] <- compute_contrast(
    post_primary$b_taskVDT,
    "VDT - ADT"
  )
}

# Effort contrast (High - Low)
if ("b_effort_conditionHigh_40_MVC" %in% colnames(post_primary)) {
  contrast_list[[length(contrast_list) + 1]] <- compute_contrast(
    post_primary$`b_effort_conditionHigh_40_MVC`,
    "High - Low"
  )
}

# Similar for boundary separation (bs) and bias (bias) parameters
# Boundary separation contrasts
bs_terms <- colnames(post_primary)[grepl("^bs_", colnames(post_primary))]
if (length(bs_terms) > 0) {
  for (term in bs_terms) {
    term_clean <- gsub("^bs_", "", term)
    contrast_list[[length(contrast_list) + 1]] <- tibble(
      contrast = term_clean,
      parameter = "Boundary (a)",
      mean = mean(post_primary[[term]]),
      q05 = quantile(post_primary[[term]], 0.05),
      q95 = quantile(post_primary[[term]], 0.95),
      p_gt0 = mean(post_primary[[term]] > 0),
      p_lt0 = mean(post_primary[[term]] < 0),
      p_in_rope = mean(abs(post_primary[[term]]) < 0.05)  # ROPE for boundary
    )
  }
}

# Bias contrasts
bias_terms <- colnames(post_primary)[grepl("^bias_", colnames(post_primary))]
if (length(bias_terms) > 0) {
  for (term in bias_terms) {
    term_clean <- gsub("^bias_", "", term)
    contrast_list[[length(contrast_list) + 1]] <- tibble(
      contrast = term_clean,
      parameter = "Bias (z)",
      mean = mean(post_primary[[term]]),
      q05 = quantile(post_primary[[term]], 0.05),
      q95 = quantile(post_primary[[term]], 0.95),
      p_gt0 = mean(post_primary[[term]] > 0),
      p_lt0 = mean(post_primary[[term]] < 0),
      p_in_rope = mean(abs(post_primary[[term]]) < 0.05)  # ROPE for bias
    )
  }
}

if (length(contrast_list) > 0) {
  contrasts_table <- bind_rows(contrast_list)
  
  # Save contrasts
  contrasts_file <- file.path(OUTPUT_DIR, "table_effect_contrasts.csv")
  write_csv(contrasts_table, contrasts_file)
  log_msg("  ✓ Saved:", contrasts_file)
} else {
  log_msg("  ⚠️  No contrasts extracted (check column names)", level = "WARN")
}

# =========================================================================
# STEP 5: SUMMARY
# =========================================================================

log_msg("")
log_msg("=", strrep("=", 78))
log_msg("TABLE EXTRACTION COMPLETE")
log_msg("=", strrep("=", 78))
log_msg("")
log_msg("Files generated:")
log_msg("  1. bias_standard_only_levels.csv")
log_msg("  2. bias_standard_only_contrasts.csv")
log_msg("  3. table_fixed_effects.csv")
log_msg("  4. table_effect_contrasts.csv")
log_msg("")
log_msg("Location:", OUTPUT_DIR)
log_msg("")

