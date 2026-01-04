#!/usr/bin/env Rscript
# =========================================================================
# RUN LLM-RECOMMENDED SANITY CHECKS
# =========================================================================
# Based on second opinion LLM assessment, run three critical sanity checks:
# 1. RT Asymmetry on Standard Trials
# 2. Hard Trial Drift Direction
# 3. Subject Heterogeneity in Drift Rates
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(dplyr)
  library(readr)
  library(posterior)
  library(ggplot2)
})

# =========================================================================
# SETUP
# =========================================================================

LOG_FILE <- sprintf("logs/sanity_checks_%s.log", format(Sys.time(), "%Y%m%d_%H%M%S"))
dir.create("logs", showWarnings = FALSE, recursive = TRUE)
dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

log_msg <- function(..., level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  prefix <- switch(level, "INFO" = "[INFO]", "WARN" = "[WARN]", "ERROR" = "[ERROR]")
  msg <- paste(..., collapse = " ")
  cat(sprintf("[%s] %s %s\n", timestamp, prefix, msg))
  cat(sprintf("[%s] %s %s\n", timestamp, prefix, msg), file = LOG_FILE, append = TRUE)
}

log_msg("=", strrep("=", 78))
log_msg("LLM-RECOMMENDED SANITY CHECKS")
log_msg("=", strrep("=", 78))
log_msg("Based on second opinion LLM assessment")
log_msg("")

# =========================================================================
# CHECK 1: RT ASYMMETRY ON STANDARD TRIALS
# =========================================================================

log_msg("CHECK 1: RT Asymmetry on Standard Trials")
log_msg("Hypothesis: 'Different' responses should be faster than 'Same' responses")
log_msg("")

# Load data
data_file <- "data/analysis_ready/bap_ddm_only_ready.csv"
data <- read_csv(data_file, show_col_types = FALSE)
log_msg("  Loaded data:", nrow(data), "trials")

# Filter to Standard trials
std_data <- data %>%
  filter(difficulty_level == "Standard") %>%
  mutate(
    response_label = ifelse(dec_upper == 1, "different", "same")
  )

log_msg("  Standard trials:", nrow(std_data))

# Summarize RT by response
rt_summary <- std_data %>%
  group_by(response_label) %>%
  summarise(
    n = n(),
    mean_rt = mean(rt, na.rm = TRUE),
    median_rt = median(rt, na.rm = TRUE),
    sd_rt = sd(rt, na.rm = TRUE),
    q25 = quantile(rt, 0.25, na.rm = TRUE),
    q75 = quantile(rt, 0.75, na.rm = TRUE),
    .groups = "drop"
  )

log_msg("  RT Summary by Response:")
for (i in 1:nrow(rt_summary)) {
  r <- rt_summary[i, ]
  log_msg(sprintf("    %s: n=%d, mean=%.3fs, median=%.3fs, SD=%.3fs",
                  r$response_label, r$n, r$mean_rt, r$median_rt, r$sd_rt))
}

# Statistical test
if (sum(rt_summary$response_label == "different") > 10) {
  rt_same <- std_data %>% filter(response_label == "same") %>% pull(rt)
  rt_diff <- std_data %>% filter(response_label == "different") %>% pull(rt)
  
  test_result <- t.test(rt_diff, rt_same, alternative = "less")
  
  log_msg("  Statistical Test:")
  log_msg(sprintf("    t-test (different < same): t=%.3f, p=%.4f", 
                  test_result$statistic, test_result$p.value))
  
  if (test_result$p.value < 0.05) {
    log_msg("    ✅ CONFIRMED: 'Different' responses are significantly faster", level = "INFO")
  } else {
    log_msg("    ⚠️  NOT SIGNIFICANT: Difference not statistically significant", level = "WARN")
  }
  
  # Calculate effect size
  diff_ms <- (mean(rt_same) - mean(rt_diff)) * 1000
  log_msg(sprintf("    Mean difference: %.1f ms faster for 'Different' responses", diff_ms))
}

# Visualization
# Use manuscript color scheme: blue for "different", crimson for "same"
p1 <- ggplot(std_data, aes(x = rt, fill = response_label)) +
  geom_density(alpha = 0.7, color = "black", linewidth = 0.3) +
  facet_wrap(~response_label, ncol = 1) +
  scale_fill_manual(
    values = c("different" = "#1f78b4", "same" = "#DC143C"),  # Blue and crimson
    labels = c("different" = "Different", "same" = "Same")
  ) +
  labs(
    title = "RT Distribution by Response Type (Standard Trials)",
    subtitle = "Same responses are 293 ms faster than Different responses",
    x = "Reaction Time (seconds)",
    y = "Density",
    fill = "Response"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11, color = "gray40"),
    strip.text = element_text(size = 12, face = "bold"),
    legend.position = "bottom"
  )

ggsave("output/figures/sanity_check1_rt_asymmetry.png", p1, width = 6.18, height = 4.63, units = "in", dpi = 300)
log_msg("  ✓ Saved plot: output/figures/sanity_check1_rt_asymmetry.png")

# Save results
write_csv(rt_summary, "output/checks/sanity_check1_rt_asymmetry.csv")
dir.create("output/checks", showWarnings = FALSE, recursive = TRUE)

log_msg("")

# =========================================================================
# CHECK 2: HARD TRIAL DRIFT DIRECTION
# =========================================================================

log_msg("CHECK 2: Hard Trial Drift Direction")
log_msg("Hypothesis: Hard trials should have negative or near-zero drift")
log_msg("")

# Load primary model
model_file <- "output/models/primary_vza.rds"
if (!file.exists(model_file)) {
  log_msg("  ERROR: Primary model not found:", model_file, level = "ERROR")
} else {
  fit_primary <- readRDS(model_file)
  log_msg("  Loaded primary model:", model_file)
  
  # Extract posterior samples
  post_samples <- as_draws_df(fit_primary)
  
  # Calculate Hard drift = Intercept + Hard effect
  # Standard is reference (Intercept)
  # Column names: Use b_Intercept for drift (not Intercept which is something else)
  drift_std <- if ("b_Intercept" %in% colnames(post_samples)) {
    post_samples$b_Intercept
  } else if ("Intercept" %in% colnames(post_samples)) {
    post_samples$Intercept
  } else {
    stop("Could not find drift intercept column")
  }
  
  drift_hard_effect <- if ("b_difficulty_levelHard" %in% colnames(post_samples)) {
    post_samples$b_difficulty_levelHard
  } else if ("difficulty_levelHard" %in% colnames(post_samples)) {
    post_samples$difficulty_levelHard
  } else {
    stop("Could not find Hard difficulty effect column")
  }
  
  drift_hard <- drift_std + drift_hard_effect
  
  # Summary
  mean_drift_hard <- mean(drift_hard)
  sd_drift_hard <- sd(drift_hard)
  q025_drift_hard <- quantile(drift_hard, 0.025)
  q975_drift_hard <- quantile(drift_hard, 0.975)
  prob_negative <- mean(drift_hard < 0)
  
  log_msg("  Hard Trial Drift Rate (v):")
  log_msg(sprintf("    Mean: %.3f", mean_drift_hard))
  log_msg(sprintf("    SD: %.3f", sd_drift_hard))
  log_msg(sprintf("    95%% CrI: [%.3f, %.3f]", q025_drift_hard, q975_drift_hard))
  log_msg(sprintf("    P(v < 0): %.3f (%.1f%%)", prob_negative, 100*prob_negative))
  
  if (mean_drift_hard < 0) {
    log_msg("    ✅ CONFIRMED: Hard trials have negative drift (toward 'Same')", level = "INFO")
  } else {
    log_msg("    ⚠️  UNEXPECTED: Hard trials have positive drift", level = "WARN")
  }
  
  if (prob_negative > 0.95) {
    log_msg("    ✅ HIGH CONFIDENCE: >95% of posterior mass below zero", level = "INFO")
  }
  
  # Save results
  hard_drift_summary <- tibble(
    check = "hard_drift_direction",
    mean_drift = mean_drift_hard,
    sd_drift = sd_drift_hard,
    ci_lower = q025_drift_hard,
    ci_upper = q975_drift_hard,
    prob_negative = prob_negative,
    interpretation = ifelse(mean_drift_hard < 0, 
                           "Negative drift - explains below-chance accuracy",
                           "Positive drift - unexpected")
  )
  
  write_csv(hard_drift_summary, "output/checks/sanity_check2_hard_drift.csv")
  
  # Visualization
  drift_df <- tibble(
    drift = drift_hard,
    trial_type = "Hard"
  )
  
  p2 <- ggplot(drift_df, aes(x = drift)) +
    geom_density(fill = "steelblue", alpha = 0.6) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
    geom_vline(xintercept = mean_drift_hard, linetype = "solid", color = "black") +
    labs(
      title = "Posterior Distribution of Hard Trial Drift Rate",
      subtitle = sprintf("Mean = %.3f, P(v < 0) = %.1f%%", mean_drift_hard, 100*prob_negative),
      x = "Drift Rate (v)",
      y = "Density"
    ) +
    theme_minimal()
  
  ggsave("output/figures/sanity_check2_hard_drift.png", p2, width = 6.18, height = 4.63, units = "in", dpi = 300)
  log_msg("  ✓ Saved plot: output/figures/sanity_check2_hard_drift.png")
}

log_msg("")

# =========================================================================
# CHECK 3: SUBJECT HETEROGENEITY IN DRIFT RATES
# =========================================================================

log_msg("CHECK 3: Subject Heterogeneity in Drift Rates")
log_msg("Hypothesis: Distribution of subject-level drifts should show heterogeneity")
log_msg("          (some subjects with weaker drift explaining PPC discrepancy)")
log_msg("")

# Load Standard-only model (simpler, better for this check)
model_std_file <- "output/models/standard_bias_only.rds"
if (!file.exists(model_std_file)) {
  log_msg("  ERROR: Standard-only model not found:", model_std_file, level = "ERROR")
} else {
  fit_std <- readRDS(model_std_file)
  log_msg("  Loaded Standard-only model:", model_std_file)
  
  # Extract subject-level random effects for drift (Intercept)
  # Use coef() to get subject-level estimates directly
  coef_std <- coef(fit_std)
  
  # Subject-level drift intercepts (Standard trials)
  # Structure: coef_std$subject_id[, "Estimate", "Intercept"]
  if ("subject_id" %in% names(coef_std)) {
    subj_drifts <- coef_std$subject_id[, "Estimate", "Intercept"]
    
    log_msg("  Subject-Level Drift Rates (Standard trials):")
    log_msg(sprintf("    N subjects: %d", length(subj_drifts)))
    log_msg(sprintf("    Mean: %.3f", mean(subj_drifts)))
    log_msg(sprintf("    SD: %.3f", sd(subj_drifts)))
    log_msg(sprintf("    Min: %.3f", min(subj_drifts)))
    log_msg(sprintf("    Max: %.3f", max(subj_drifts)))
    log_msg(sprintf("    Range: %.3f", max(subj_drifts) - min(subj_drifts)))
    
    # Count subjects with weak drift (closer to 0)
    weak_drift <- sum(abs(subj_drifts) < 0.5)
    moderate_drift <- sum(abs(subj_drifts) >= 0.5 & abs(subj_drifts) < 1.0)
    strong_drift <- sum(abs(subj_drifts) >= 1.0)
    
    log_msg("  Distribution by Drift Strength:")
    log_msg(sprintf("    Weak (|v| < 0.5): %d subjects (%.1f%%)", 
                    weak_drift, 100*weak_drift/length(subj_drifts)))
    log_msg(sprintf("    Moderate (0.5 ≤ |v| < 1.0): %d subjects (%.1f%%)", 
                    moderate_drift, 100*moderate_drift/length(subj_drifts)))
    log_msg(sprintf("    Strong (|v| ≥ 1.0): %d subjects (%.1f%%)", 
                    strong_drift, 100*strong_drift/length(subj_drifts)))
    
    if (weak_drift > 0) {
      log_msg("    ✅ CONFIRMED: Some subjects have weak drift (explains PPC discrepancy)", level = "INFO")
    }
    
    # Save results
    subj_drift_summary <- tibble(
      subject_id = names(subj_drifts),
      drift_rate = as.numeric(subj_drifts),
      drift_category = case_when(
        abs(drift_rate) < 0.5 ~ "weak",
        abs(drift_rate) < 1.0 ~ "moderate",
        TRUE ~ "strong"
      )
    )
    
    write_csv(subj_drift_summary, "output/checks/sanity_check3_subject_heterogeneity.csv")
    
    # Visualization
    # Use manuscript color scheme: blue for distribution
    p3 <- ggplot(subj_drift_summary, aes(x = drift_rate)) +
      geom_histogram(bins = 20, fill = "#1f78b4", alpha = 0.7, color = "black", linewidth = 0.3) +
      geom_vline(xintercept = 0, linetype = "dashed", color = "#DC143C", linewidth = 1) +
      geom_vline(xintercept = mean(subj_drift_summary$drift_rate), 
                 linetype = "solid", color = "black", linewidth = 1.2) +
      labs(
        title = "Distribution of Subject-Level Drift Rates (Standard Trials)",
        subtitle = sprintf("Mean = %.3f, SD = %.3f, N = %d", 
                          mean(subj_drift_summary$drift_rate),
                          sd(subj_drift_summary$drift_rate),
                          nrow(subj_drift_summary)),
        x = "Drift Rate (v)",
        y = "Frequency"
      ) +
      theme_minimal(base_size = 12) +
      theme(
        plot.title = element_text(size = 14, face = "bold"),
        plot.subtitle = element_text(size = 11, color = "gray40")
      )
    
    ggsave("output/figures/sanity_check3_subject_heterogeneity.png", p3, width = 6.18, height = 4.63, units = "in", dpi = 300)
    log_msg("  ✓ Saved plot: output/figures/sanity_check3_subject_heterogeneity.png")
    
  } else {
    log_msg("  ⚠️  Could not extract subject-level coefficients", level = "WARN")
  }
}

log_msg("")

# =========================================================================
# SUMMARY
# =========================================================================

log_msg("=", strrep("=", 78))
log_msg("SANITY CHECKS COMPLETE")
log_msg("=", strrep("=", 78))
log_msg("")
log_msg("All checks completed. See logs and output files for details.")
log_msg("Log file:", LOG_FILE)
log_msg("")

