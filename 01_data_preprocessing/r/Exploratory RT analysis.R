# =========================================================================
# BAP Pupillometry Analysis - The Distributional Approach
#
# This script performs a complete analysis inspired by Lindeløv (2019),
# modeling the entire RT distribution to answer nuanced questions about
# processing speed, consistency, and readiness.
# =========================================================================

# =========================================================================
# SECTION 0: SETUP
# =========================================================================
# Install packages if you haven't already
# install.packages(c("tidyverse", "ggplot2", "gghalves", "brms", "bayesplot", "corrplot"))

library(tidyverse)
library(ggplot2)
library(gghalves) # For raincloud plots
library(brms)      # For Bayesian modeling
library(bayesplot) # For MCMC diagnostics
library(corrplot)  # For correlation heatmaps

# Set a consistent theme for all plots
theme_set(theme_minimal(base_size = 14))


# =========================================================================
# SECTION 1: DATA LOADING AND PREPARATION
# =========================================================================
cat("--- SECTION 1: LOADING AND PREPARING DATA ---\n")

# Load the clean, aggregated dataframe from Phase A
# Make sure this file is in your R working directory
file_path <- "BAP_all_subjects_aggregated_for_modeling.csv"
if (!file.exists(file_path)) {
    stop("Data file not found! Please ensure 'BAP_all_subjects_aggregated_for_modeling.csv' is in your directory.")
}
model_data <- read.csv(file_path)

# Prepare data for modeling: filter invalid trials and select final variables
model_data <- model_data %>%
    filter(!is.na(rt) & !is.na(accuracy) & !is.na(tonic_arousal)) %>%
    filter(rt > 0.250 & rt < 3.0) # Filter out extreme RTs

cat("Loaded and prepared", nrow(model_data), "trials for analysis.\n\n")


# =========================================================================
# SECTION 2: NEW VISUALIZATIONS FOR DATA EXPLORATION
# =========================================================================
cat("--- SECTION 2: GENERATING EXPLORATORY PLOTS ---\n")

# --- Visualization 1: Correlation Heatmap of Predictors ---
# This helps us understand the relationships between our key continuous variables.
predictor_cor_matrix <- model_data %>%
    select(rt, effort_continuous, tonic_arousal, force_evoked_arousal) %>%
    cor(use = "pairwise.complete.obs")

pdf("BAP_correlation_heatmap.pdf", width = 8, height = 8)
corrplot(predictor_cor_matrix, method = "circle", type = "upper", order = "hclust",
         addCoef.col = "black", tl.col = "black", tl.srt = 45, sig.level = 0.01, insig = "blank")
dev.off()
cat("✓ Correlation heatmap saved to BAP_correlation_heatmap.pdf\n")


# --- Visualization 2: Raincloud Plot of RT Distributions ---
# This provides a rich view of how the raw RT distributions differ by condition.
rt_raincloud_plot <- ggplot(model_data, aes(x = stimulus_condition, y = rt, fill = force_condition)) +
    geom_half_point(aes(color = force_condition), side = "l", shape = 19, alpha = 0.2,
                    position = position_nudge(x = 0.12)) +
    geom_half_violin(side = "r", position = position_nudge(x = 0.15), alpha = 0.7) +
    geom_half_boxplot(side = "r", position = position_nudge(x = 0.15), width = 0.1,
                      outlier.shape = NA, alpha = 0.7) +
    facet_wrap(~task) +
    coord_flip() +
    labs(title = "Reaction Time Distributions by Condition and Task",
         x = "Stimulus Condition", y = "Reaction Time (s)",
         fill = "Force", color = "Force") +
    scale_fill_viridis_d() +
    scale_color_viridis_d() +
    theme(legend.position = "bottom")

ggsave("BAP_rt_distribution_raincloud.png", rt_raincloud_plot, width = 12, height = 7, dpi = 300)
cat("✓ Raincloud plot saved to BAP_rt_distribution_raincloud.png\n\n")


# =========================================================================
# SECTION 3: DISTRIBUTIONAL MODELING
# =========================================================================
cat("--- SECTION 3: FITTING THE DISTRIBUTIONAL MODEL ---\n")

# --- Define the Distributional Model Formula ---
# This model directly addresses our new research questions.
distributional_formula <- bf(
    # Q1: How do variables affect processing speed (mu)?
    rt ~ tonic_arousal + force_evoked_arousal + effort_continuous * stimulus_condition + (1 | subject_id),
    
    # Q2: How does effort affect response consistency (sigma)?
    sigma ~ effort_continuous + (1 | subject_id),
    
    # Q3: How does tonic arousal affect non-decision time (ndt)?
    ndt ~ tonic_arousal + (1 | subject_id)
)

# --- Define Priors to Guide the Model ---
model_priors <- c(
    prior(normal(0, 1), class = "b"),
    prior(exponential(2), class = "sd"),
    prior(normal(0, 1), class = "Intercept", dpar = "sigma"),
    prior(normal(-1.5, 0.5), class = "Intercept", dpar = "ndt") # Centered around ~220ms
)

# --- Fit the Model ---
distributional_model <- brm(
    formula = distributional_formula,
    data = model_data,
    family = shifted_lognormal(),
    prior = model_priors,
    chains = 4,
    iter = 4000,
    warmup = 1000,
    cores = 4,
    control = list(adapt_delta = 0.95),
    file = "BAP_distributional_model_fit" # Save the model object
)

cat("✓ Model fitting complete.\n\n")


# =========================================================================
# SECTION 4: MODEL VALIDATION AND VISUALIZATION OF RESULTS
# =========================================================================
cat("--- SECTION 4: VISUALIZING MODEL RESULTS ---\n")

# --- Visualization 3: Posterior Predictive Check ---
# This plot checks if the model's predictions look like the real data.
ppc_plot <- pp_check(distributional_model, ndraws = 100) +
    labs(title = "Posterior Predictive Check")
ggsave("BAP_distributional_model_pp_check.png", ppc_plot)
cat("✓ Posterior predictive check plot saved.\n")


# --- Visualization 4: Conditional Effects for Each Parameter ---
# This is the most powerful visualization. We create a plot for each research question.
# It shows how our predictors influence each parameter of the RT distribution.

# Plot for Question 1: How does effort affect processing speed (mu)?
mu_effects_plot <- conditional_effects(distributional_model,
                                       effects = "effort_continuous:stimulus_condition",
                                       dpar = "mu")[[1]] +
    labs(title = "Effect on Processing Speed (mu)",
         x = "Continuous Effort (AUC)", y = "Median RT (log scale)")
ggsave("BAP_effects_on_mu.png", mu_effects_plot)

# Plot for Question 2: How does effort affect response consistency (sigma)?
sigma_effects_plot <- conditional_effects(distributional_model,
                                          effects = "effort_continuous",
                                          dpar = "sigma")[[1]] +
    labs(title = "Effect on Response Consistency (sigma)",
         x = "Continuous Effort (AUC)", y = "RT Variability (log scale)")
ggsave("BAP_effects_on_sigma.png", sigma_effects_plot)

# Plot for Question 3: How does tonic arousal affect non-decision time (ndt)?
ndt_effects_plot <- conditional_effects(distributional_model,
                                        effects = "tonic_arousal",
                                        dpar = "ndt")[[1]] +
    labs(title = "Effect on Non-Decision Time (ndt)",
         x = "Tonic Arousal (z-score)", y = "Non-Decision Time (s)")
ggsave("BAP_effects_on_ndt.png", ndt_effects_plot)

cat("✓ Conditional effects plots saved for mu, sigma, and ndt.\n\n")


# --- Final Model Summary ---
cat("--- FINAL MODEL SUMMARY ---\n")
print(summary(distributional_model))

cat("\n🎉 Analysis Complete! Check your directory for saved plots and model objects. 🎉\n")



############### NEEDS CORRECTION and DOUBLE check

# =========================================================================
# BAP Pupillometry Analysis - Exploratory Data Visualization
#
# This script creates key plots to visualize the relationships between
# effort, stimulus level, and performance (RT and accuracy).
# =========================================================================

# --- 1. Setup ---
# Install packages if you haven't already
# install.packages(c("tidyverse", "ggplot2", "gghalves"))

library(tidyverse)
library(ggplot2)
library(gghalves)

# Set a consistent theme for all plots
theme_set(theme_minimal(base_size = 14) + theme(panel.border = element_rect(color = "grey80", fill = NA)))

# --- 2. Load Data ---
cat("--- Loading and Preparing Data ---\n")
# Load the clean, aggregated dataframe from our Phase A script
file_path <- "BAP_all_subjects_aggregated_for_modeling.csv"
if (!file.exists(file_path)) {
    stop("Data file not found! Please ensure 'BAP_all_subjects_aggregated_for_modeling.csv' is in your directory.")
}
vis_data <- read.csv(file_path)

# Prepare data for plotting: filter invalid trials and make factors for easier plotting
vis_data <- vis_data %>%
    filter(!is.na(rt) & !is.na(accuracy)) %>%
    filter(rt > 0.250 & rt < 3.0) %>%
    # For plotting, it's helpful to treat stimLev as a categorical factor
    mutate(stimLev_factor = as.factor(stimLev))

cat("Loaded and prepared", nrow(vis_data), "trials for visualization.\n\n")


# =========================================================================
# SECTION 3: GENERATING VISUALIZATIONS
# =========================================================================
cat("--- Generating Plots ---\n")

# --- Visualization 1: How does Effort affect Reaction Time? ---
# This plot shows how continuous effort influences RT, separated by stimulus
# difficulty (oddball/standard).

rt_by_effort_plot <- ggplot(vis_data, aes(x = effort_continuous, y = rt, color = stimulus_condition)) +
    geom_point(alpha = 0.4, shape = 16) +
    geom_smooth(method = "lm", formula = y ~ x, se = TRUE, alpha = 0.15) +
    facet_wrap(~task) + # Separate plots for ADT and VDT
    scale_color_viridis_d(option = "plasma", name = "Stimulus") +
    labs(
        title = "Reaction Time vs. Continuous Effort",
        subtitle = "Relationship between physical effort and RT for different stimulus types",
        x = "Continuous Effort (AUC relative to MVC)",
        y = "Reaction Time (s)"
    ) +
    theme(legend.position = "bottom")

ggsave("BAP_rt_by_effort.png", rt_by_effort_plot, width = 11, height = 7, dpi = 300)
cat("✓ Plot 1: RT vs. Effort saved to BAP_rt_by_effort.png\n")


# --- Visualization 2: How does Effort affect Accuracy? ---
# This plot shows how continuous effort influences the probability of a correct response.
# We use a logistic regression smooth (glm) because accuracy is a binary 0/1 variable.

accuracy_by_effort_plot <- ggplot(vis_data, aes(x = effort_continuous, y = accuracy, color = stimulus_condition)) +
    # We use a logistic regression smoother for binary outcomes
    geom_smooth(method = "glm", method.args = list(family = "binomial"), se = TRUE, alpha = 0.15) +
    geom_point(position = position_jitter(width = 0.02, height = 0.03), alpha = 0.3, shape = 16) +
    facet_wrap(~task) +
    scale_color_viridis_d(option = "plasma", name = "Stimulus") +
    scale_y_continuous(labels = scales::percent) + # Show y-axis as percentage
    labs(
        title = "Accuracy vs. Continuous Effort",
        subtitle = "Relationship between physical effort and probability of a correct response",
        x = "Continuous Effort (AUC relative to MVC)",
        y = "Accuracy"
    ) +
    theme(legend.position = "bottom")

ggsave("BAP_accuracy_by_effort.png", accuracy_by_effort_plot, width = 11, height = 7, dpi = 300)
cat("✓ Plot 2: Accuracy vs. Effort saved to BAP_accuracy_by_effort.png\n")


# --- Visualization 3: How does Stimulus Level change the RT distribution? ---
# Here we use the raincloud plot again, but this time we facet by the
# different stimulus levels to see how that manipulation affects the RT shape.

rt_by_stimlev_plot <- ggplot(vis_data, aes(x = force_condition, y = rt, fill = force_condition)) +
    geom_half_point(side = "l", shape = 19, alpha = 0.2) +
    geom_half_violin(side = "r", alpha = 0.7) +
    geom_half_boxplot(side = "r", width = 0.1, outlier.shape = NA, alpha = 0.7) +
    # Facet by both task and stimulus level factor
    facet_grid(task ~ stimLev_factor, labeller = label_both) +
    coord_flip() +
    scale_fill_viridis_d(option = "cividis") +
    labs(
        title = "RT Distributions by Force Condition Across Stimulus Levels",
        subtitle = "Each panel represents a different stimulus intensity level",
        x = "Force Condition",
        y = "Reaction Time (s)"
    ) +
    theme(legend.position = "none") # Remove legend as fill is redundant

ggsave("BAP_rt_by_stimulus_level.png", rt_by_stimlev_plot, width = 14, height = 8, dpi = 300)
cat("✓ Plot 3: RT by Stimulus Level saved to BAP_rt_by_stimulus_level.png\n")

cat("\n🎉 Visualization script complete! Check your directory for the PNG files. 🎉\n")