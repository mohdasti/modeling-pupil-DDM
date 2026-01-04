#!/usr/bin/env Rscript
# =========================================================================
# CREATE DDM PARAMETER VISUALIZATIONS
# =========================================================================
# Generates publication-ready visualizations for DDM parameter estimates:
# 1. Drift Rate Story (across Difficulty levels)
# 2. Bias Story (ADT vs VDT)
# 3. PPC Validation Plot (if available)
# 4. Parameter Correlations (Subject Random Effects)
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(posterior)
  library(tidyr)
  library(stringr)
  library(patchwork)
})

# =========================================================================
# CONFIGURATION
# =========================================================================

MODEL_PRIMARY <- "output/models/primary_vza.rds"
MODEL_STD_BIAS <- "output/models/standard_bias_only.rds"
RESULTS_DIR <- "output/results"
FIGURES_DIR <- "output/figures"
LOG_DIR <- "logs"

dir.create(FIGURES_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)

LOG_FILE <- file.path(LOG_DIR, sprintf("visualizations_%s.log", 
                                        format(Sys.time(), "%Y%m%d_%H%M%S")))

# Color scheme (consistent with manuscript)
COLOR_DIFFERENT <- "#1f78b4"  # Blue
COLOR_SAME <- "#DC143C"       # Crimson
COLOR_ADT <- "#1f78b4"        # Blue
COLOR_VDT <- "#DC143C"        # Crimson

# Helper functions
log_msg <- function(..., level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  prefix <- switch(level, "INFO" = "[INFO]", "WARN" = "[WARN]", "ERROR" = "[ERROR]")
  msg <- paste(..., collapse = " ")
  cat(sprintf("[%s] %s %s\n", timestamp, prefix, msg))
  cat(sprintf("[%s] %s %s\n", timestamp, prefix, msg), file = LOG_FILE, append = TRUE)
}

# Theme for publication-ready plots
theme_publication <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(size = base_size + 2, face = "bold", hjust = 0.5),
      plot.subtitle = element_text(size = base_size - 1, hjust = 0.5, color = "gray50"),
      axis.title = element_text(size = base_size, face = "bold"),
      axis.text = element_text(size = base_size - 1),
      legend.title = element_text(size = base_size, face = "bold"),
      legend.text = element_text(size = base_size - 1),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "gray90", linewidth = 0.5),
      strip.text = element_text(size = base_size, face = "bold"),
      plot.margin = margin(10, 10, 10, 10)
    )
}

# =========================================================================
# START LOGGING
# =========================================================================

log_msg("=", strrep("=", 78))
log_msg("DDM PARAMETER VISUALIZATIONS")
log_msg("=", strrep("=", 78))
log_msg("")
log_msg("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log_msg("")

# =========================================================================
# LOAD MODELS AND DATA
# =========================================================================

log_msg("Loading models...")

if (!file.exists(MODEL_PRIMARY)) {
  stop("Primary model not found: ", MODEL_PRIMARY)
}

fit_primary <- readRDS(MODEL_PRIMARY)
log_msg("  ✓ Loaded primary model")

if (!file.exists(MODEL_STD_BIAS)) {
  log_msg("  ⚠️  Standard-only bias model not found", level = "WARN")
  fit_std <- NULL
} else {
  fit_std <- readRDS(MODEL_STD_BIAS)
  log_msg("  ✓ Loaded standard-only bias model")
}

# Load parameter summaries
condition_params_file <- file.path(RESULTS_DIR, "parameter_summary_by_condition.csv")
if (file.exists(condition_params_file)) {
  condition_params <- read_csv(condition_params_file, show_col_types = FALSE)
  log_msg("  ✓ Loaded condition-specific parameters")
} else {
  stop("Condition parameters file not found: ", condition_params_file)
}

# Load effect contrasts
contrasts_file <- file.path("output/publish/table_effect_contrasts.csv")
if (file.exists(contrasts_file)) {
  effect_contrasts <- read_csv(contrasts_file, show_col_types = FALSE)
  log_msg("  ✓ Loaded effect contrasts")
} else {
  stop("Effect contrasts file not found: ", contrasts_file)
}

# Load bias levels
bias_levels_file <- file.path("output/publish/bias_standard_only_levels.csv")
if (file.exists(bias_levels_file)) {
  bias_levels <- read_csv(bias_levels_file, show_col_types = FALSE)
  log_msg("  ✓ Loaded bias levels")
} else {
  bias_levels <- NULL
  log_msg("  ⚠️  Bias levels file not found", level = "WARN")
}

log_msg("")

# =========================================================================
# PLOT 1: DRIFT RATE STORY - ACROSS DIFFICULTY LEVELS
# =========================================================================

log_msg("=", strrep("=", 78))
log_msg("PLOT 1: Drift Rate Story - Across Difficulty Levels")
log_msg("=", strrep("=", 78))
log_msg("")

# Extract drift rate estimates for each difficulty level
drift_data <- condition_params %>%
  filter(parameter == "v") %>%
  mutate(
    difficulty = factor(condition, levels = c("Standard", "Hard", "Easy")),
    difficulty_label = case_when(
      difficulty == "Standard" ~ "Standard (Δ=0)",
      difficulty == "Hard" ~ "Hard (Low Signal)",
      difficulty == "Easy" ~ "Easy (High Signal)"
    )
  )

# Create forest plot style visualization
p1 <- ggplot(drift_data, aes(x = difficulty, y = mean)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray60", linewidth = 0.8) +
  geom_point(size = 4, color = COLOR_DIFFERENT) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), 
                width = 0.15, linewidth = 1.2, color = COLOR_DIFFERENT) +
  scale_x_discrete(labels = c("Standard\n(Δ=0)", "Hard\n(Low Signal)", "Easy\n(High Signal)")) +
  scale_y_continuous(breaks = scales::pretty_breaks(n = 8)) +
  labs(
    title = "Drift Rate (v) Across Difficulty Levels",
    subtitle = "Signal-to-noise ratio of information accumulation",
    x = "Difficulty Level",
    y = "Drift Rate (v)",
    caption = "Error bars show 95% credible intervals. Positive values indicate drift toward 'Different' (upper boundary); negative values indicate drift toward 'Same' (lower boundary)."
  ) +
  theme_publication() +
  theme(plot.caption = element_text(size = 9, hjust = 0, color = "gray50"))

# Save plot
plot1_file <- file.path(FIGURES_DIR, "plot1_drift_rate_by_difficulty.png")
ggsave(plot1_file, p1, width = 6.18, height = 3.70, units = "in", dpi = 300, bg = "white")
log_msg("  ✓ Saved:", plot1_file)

# =========================================================================
# PLOT 2: BIAS STORY - ADT vs VDT
# =========================================================================

log_msg("")
log_msg("=", strrep("=", 78))
log_msg("PLOT 2: Bias Story - ADT vs VDT")
log_msg("=", strrep("=", 78))
log_msg("")

# Extract bias estimates for ADT and VDT from Standard-only model
if (!is.null(bias_levels)) {
  bias_adtdt <- bias_levels %>%
    filter(scale == "prob", 
           param %in% c("bias_ADT_Low", "bias_VDT_Low")) %>%
    mutate(
      task = case_when(
        param == "bias_ADT_Low" ~ "ADT",
        param == "bias_VDT_Low" ~ "VDT"
      ),
      task = factor(task, levels = c("ADT", "VDT"))
    )
  
  # Create bar plot with error bars
  # Bars start from 0, error bars show 95% CI on top
  p2 <- ggplot(bias_adtdt, aes(x = task, y = mean, fill = task)) +
    geom_hline(yintercept = 0.5, linetype = "dashed", color = "gray60", linewidth = 0.8) +
    geom_col(width = 0.6, alpha = 0.8) +
    geom_errorbar(aes(ymin = q2.5, ymax = q97.5), 
                  width = 0.25, linewidth = 1.2, color = "black") +
    scale_fill_manual(values = c("ADT" = COLOR_ADT, "VDT" = COLOR_VDT), guide = "none") +
    scale_y_continuous(
      limits = c(0, 0.65),
      breaks = seq(0, 0.65, 0.1),
      labels = scales::percent_format(accuracy = 1),
      expand = expansion(mult = c(0, 0.05))
    ) +
    labs(
      title = "Starting-Point Bias (z) by Task Modality",
      subtitle = "Probability of bias toward 'Different' boundary",
      x = "Task Modality",
      y = "Bias (z)",
      caption = "Error bars show 95% credible intervals. Values above 0.5 indicate bias toward 'Different' (upper boundary).\nDashed line at 0.5 indicates no bias."
    ) +
    theme_publication() +
    theme(plot.caption = element_text(size = 9, hjust = 0, color = "gray50"))
  
  # Save plot
  plot2_file <- file.path(FIGURES_DIR, "plot2_bias_by_task.png")
  ggsave(plot2_file, p2, width = 6.18, height = 4.63, units = "in", dpi = 300, bg = "white")
  log_msg("  ✓ Saved:", plot2_file)
} else {
  log_msg("  ⚠️  Skipping bias plot (bias levels not available)", level = "WARN")
}

# =========================================================================
# PLOT 3: PPC VALIDATION PLOT
# =========================================================================

log_msg("")
log_msg("=", strrep("=", 78))
log_msg("PLOT 3: PPC Validation Plot")
log_msg("=", strrep("=", 78))
log_msg("")

# Check if PPC validation plot exists (multiple possible locations/names)
ppc_plot_candidates <- c(
  file.path("output", "ppc_primary_model_standard_trials.png"),
  file.path(FIGURES_DIR, "ppc_validation_choice_proportions.png"),
  file.path(FIGURES_DIR, "fig_ppc_choice_proportions.png"),
  file.path("output", "figures", "ppc_validation_choice_proportions.png")
)

ppc_plot_file <- NULL
for (candidate in ppc_plot_candidates) {
  if (file.exists(candidate)) {
    ppc_plot_file <- candidate
    break
  }
}

if (!is.null(ppc_plot_file)) {
  log_msg("  ✓ PPC validation plot found:", ppc_plot_file)
  log_msg("    Copying to standardized name...")
  plot3_file <- file.path(FIGURES_DIR, "plot3_ppc_validation.png")
  file.copy(ppc_plot_file, plot3_file, overwrite = TRUE)
  log_msg("  ✓ Saved:", plot3_file)
} else {
  log_msg("  ⚠️  PPC validation plot not found. Will skip Plot 3.", level = "WARN")
  log_msg("    To generate it, run: Rscript R/validate_ppc_proper.R")
  plot3_file <- NULL
}

# =========================================================================
# PLOT 4: PARAMETER CORRELATIONS - SUBJECT RANDOM EFFECTS
# =========================================================================

log_msg("")
log_msg("=", strrep("=", 78))
log_msg("PLOT 4: Parameter Correlations - Subject Random Effects")
log_msg("=", strrep("=", 78))
log_msg("")

# Extract subject-level random effects using coef() function
log_msg("  Extracting subject-level random effects using coef()...")

tryCatch({
  # Use coef() to get subject-level coefficients (includes fixed + random effects)
  coef_subjects <- coef(fit_primary, summary = TRUE)
  
  if (!is.null(coef_subjects) && "subject_id" %in% names(coef_subjects)) {
    # Extract drift and bias intercepts for each subject
    drift_coefs <- coef_subjects$subject_id[, , "Intercept"]
    bias_coefs <- coef_subjects$subject_id[, , "bias_Intercept"]
    
    # Create data frame
    subject_cor_data <- tibble(
      subject_id = rownames(drift_coefs),
      drift_intercept = drift_coefs[, "Estimate"],
      bias_intercept = bias_coefs[, "Estimate"]
    )
    
    # Calculate correlation
    cor_val <- cor(subject_cor_data$drift_intercept, 
                   subject_cor_data$bias_intercept, 
                   use = "complete.obs")
    log_msg(sprintf("    Extracted %d subjects", nrow(subject_cor_data)))
    log_msg(sprintf("    Correlation: r = %.3f", cor_val))
    
    # Create scatter plot
    p4 <- ggplot(subject_cor_data, aes(x = drift_intercept, y = bias_intercept)) +
      geom_point(size = 3, alpha = 0.7, color = COLOR_DIFFERENT) +
      geom_smooth(method = "lm", se = TRUE, color = COLOR_SAME, 
                  linewidth = 1.2, fill = "gray90", alpha = 0.3) +
      scale_x_continuous(breaks = scales::pretty_breaks(n = 6)) +
      scale_y_continuous(breaks = scales::pretty_breaks(n = 6)) +
      labs(
        title = "Subject-Level Parameter Correlation",
        subtitle = paste0("Drift Intercept vs. Bias Intercept (r = ", round(cor_val, 3), ")"),
        x = "Drift Intercept (Subject-Level)",
        y = "Bias Intercept (Subject-Level, logit scale)",
        caption = "Each point represents one subject. Subject-level estimates include fixed + random effects.\nPositive drift = stronger positive drift; positive bias = bias toward 'Different'."
      ) +
      theme_publication() +
      theme(plot.caption = element_text(size = 9, hjust = 0, color = "gray50"))
    
    # Save plot
    plot4_file <- file.path(FIGURES_DIR, "plot4_parameter_correlation.png")
    ggsave(plot4_file, p4, width = 6.18, height = 4.63, units = "in", dpi = 300, bg = "white")
    log_msg("  ✓ Saved:", plot4_file)
    
  } else {
    log_msg("  ⚠️  Could not extract subject-level coefficients from coef()", level = "WARN")
  }
}, error = function(e) {
  log_msg(sprintf("  ⚠️  Failed to extract subject-level effects: %s", e$message), level = "WARN")
  log_msg("    Skipping parameter correlation plot")
})

# =========================================================================
# SUMMARY
# =========================================================================

log_msg("")
log_msg("=", strrep("=", 78))
log_msg("VISUALIZATION COMPLETE")
log_msg("=", strrep("=", 78))
log_msg("")

log_msg("Plots generated:")
log_msg("  1. plot1_drift_rate_by_difficulty.png - Drift rate across difficulty levels")
if (!is.null(bias_levels)) {
  log_msg("  2. plot2_bias_by_task.png - Bias by task modality")
}
if (file.exists(ppc_plot_file)) {
  log_msg("  3. plot3_ppc_validation.png - PPC validation plot")
}
log_msg("  4. plot4_parameter_correlation.png - Subject-level parameter correlations")

log_msg("")
log_msg("Location:", FIGURES_DIR)
log_msg("")
log_msg("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log_msg("=", strrep("=", 78))

