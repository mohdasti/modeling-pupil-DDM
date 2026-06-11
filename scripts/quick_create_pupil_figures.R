#!/usr/bin/env Rscript
# Quick script to create pupil effect figures from existing model files

suppressPackageStartupMessages({
  library(brms)
  library(ggplot2)
  library(posterior)
  library(here)
})

cat("\nCreating pupil effect figures...\n\n")

MODELS_DIR <- here::here("output", "ddm_pupil", "models")
FIGS_DIR <- here::here("output", "ddm_pupil", "figs")
dir.create(FIGS_DIR, recursive = TRUE, showWarnings = FALSE)

# Load models
cat("Loading models...\n")
model_bias <- readRDS(file.path(MODELS_DIR, "model_1_pupil_bias.rds"))
model_drift <- readRDS(file.path(MODELS_DIR, "model_2_pupil_bias_drift.rds"))

# Figure 1: Pupil effect on bias
cat("Creating bias effect figure...\n")
draws_bias <- as_draws_df(model_bias)
pupil_col_bias <- grep("b_bias.*pupil", names(draws_bias), value = TRUE)[1]

if (!is.na(pupil_col_bias)) {
  pupil_draws_bias <- draws_bias[[pupil_col_bias]]
  
  fig_bias <- ggplot(data.frame(x = pupil_draws_bias), aes(x = x)) +
    geom_density(fill = "steelblue", alpha = 0.6, linewidth = 1) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "red", linewidth = 0.8) +
    geom_vline(xintercept = median(pupil_draws_bias), linetype = "solid", 
               color = "darkblue", linewidth = 1.2) +
    labs(
      title = "Effect of Phasic Arousal (Pupil) on Starting-Point Bias",
      subtitle = sprintf("Median = %.4f, 95%% CI = [%.4f, %.4f]",
                        median(pupil_draws_bias),
                        quantile(pupil_draws_bias, 0.025),
                        quantile(pupil_draws_bias, 0.975)),
      x = "Coefficient for pupil_z on bias (link scale)",
      y = "Posterior Density"
    ) +
    theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 16),
      plot.subtitle = element_text(hjust = 0.5, size = 12),
      panel.grid.minor = element_blank(),
      axis.title = element_text(size = 13),
      axis.text = element_text(size = 11)
    )
  
  ggsave(file.path(FIGS_DIR, "fig_pupil_bias_effect.png"), fig_bias, 
         width = 10, height = 7, dpi = 300)
  cat("  ✓ Saved: fig_pupil_bias_effect.png\n")
  cat("    Median:", round(median(pupil_draws_bias), 4), "\n")
  cat("    P(coef < 0):", round(mean(pupil_draws_bias < 0), 3), "\n")
}

# Figure 2: Pupil effect on drift
cat("\nCreating drift effect figure...\n")
draws_drift <- as_draws_df(model_drift)
pupil_col_drift <- grep("b_pupil.*z$", names(draws_drift), value = TRUE)[1]

if (!is.na(pupil_col_drift)) {
  pupil_draws_drift <- draws_drift[[pupil_col_drift]]
  
  fig_drift <- ggplot(data.frame(x = pupil_draws_drift), aes(x = x)) +
    geom_density(fill = "darkgreen", alpha = 0.6, linewidth = 1) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "red", linewidth = 0.8) +
    geom_vline(xintercept = median(pupil_draws_drift), linetype = "solid", 
               color = "darkgreen", linewidth = 1.2) +
    labs(
      title = "Effect of Phasic Arousal (Pupil) on Drift Rate",
      subtitle = sprintf("Median = %.4f, 95%% CI = [%.4f, %.4f]",
                        median(pupil_draws_drift),
                        quantile(pupil_draws_drift, 0.025),
                        quantile(pupil_draws_drift, 0.975)),
      x = "Coefficient for pupil_z on drift rate (link scale)",
      y = "Posterior Density"
    ) +
    theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 16),
      plot.subtitle = element_text(hjust = 0.5, size = 12),
      panel.grid.minor = element_blank(),
      axis.title = element_text(size = 13),
      axis.text = element_text(size = 11)
    )
  
  ggsave(file.path(FIGS_DIR, "fig_pupil_drift_effect.png"), fig_drift, 
         width = 10, height = 7, dpi = 300)
  cat("  ✓ Saved: fig_pupil_drift_effect.png\n")
  cat("    Median:", round(median(pupil_draws_drift), 4), "\n")
  cat("    P(coef > 0):", round(mean(pupil_draws_drift > 0), 3), "\n")
}

cat("\n✓ Figures created successfully!\n")
cat("  Directory:", FIGS_DIR, "\n\n")
