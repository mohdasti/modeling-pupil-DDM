# =========================================================================
# TONIC BASELINE EFFECTS ON BOUNDARY SEPARATION (α)
# =========================================================================
# Tests linear and quadratic within-person tonic baseline effects on α,
# plus trait-level between-person effects
# =========================================================================

suppressPackageStartupMessages({
  library(brms); library(dplyr); library(readr); library(ggplot2)
  library(bayesplot); library(patchwork)
})

# =========================================================================
# LOAD AND PREPARE DATA
# =========================================================================

cat("Loading data...\n")
data_file <- "data/analysis_ready/bap_clean_pupil.csv"
d <- read_csv(data_file, show_col_types = FALSE)

# Create trial-level identifier if missing
if (!"trial_id" %in% colnames(d)) {
  d$trial_id <- paste(d$subject_id, d$task, d$run, d$trial_index, sep = "_")
}

# Ensure we have tonic baseline
if (!"TONIC_BASELINE_scaled" %in% colnames(d)) {
  stop("TONIC_BASELINE_scaled not found in data. Please run state/trait decomposition first.")
}

# Create WP/BP decomposition for tonic baseline
cat("Creating within-person and between-person tonic baseline variables...\n")
d <- d %>%
  group_by(subject_id) %>%
  mutate(
    TONIC_BASELINE_wp = as.numeric(scale(TONIC_BASELINE_scaled)[,1]),
    TONIC_BASELINE_mean = mean(TONIC_BASELINE_scaled, na.rm = TRUE)
  ) %>% ungroup() %>%
  mutate(TONIC_BASELINE_bp = as.numeric(scale(TONIC_BASELINE_mean)[,1]))

# Filter to valid trials
d <- d %>%
  filter(
    !is.na(rt), !is.na(choice_binary),
    !is.na(TONIC_BASELINE_wp), !is.na(TONIC_BASELINE_bp),
    rt >= 0.2, rt <= 3.0
  ) %>%
  mutate(
    subj = as.factor(subject_id),
    choice = as.integer(choice_binary)
  )

cat("Data ready: ", nrow(d), " trials from ", length(unique(d$subject_id)), " participants\n")

# =========================================================================
# DDM MODEL WITH TONIC EFFECTS ON α
# =========================================================================

cat("\nFitting DDM model with tonic effects on boundary separation (α)...\n")

# Formula: tonic effects on bs (boundary separation = α)
f_tonic_alpha <- bf(
  rt | dec(choice) ~ 1 + difficulty_level + effort_condition + (1 | subj),
  bs   ~ 1 + difficulty_level + effort_condition + 
         TONIC_BASELINE_wp + I(TONIC_BASELINE_wp^2) + 
         TONIC_BASELINE_bp + (1 | subj),
  ndt  ~ 1 + difficulty_level + (1 | subj),
  bias ~ 1 + (1 | subj)
)

# STANDARDIZED PRIORS: Literature-justified for older adults + response-signal design
priors <- c(
  # Drift rate (v) - identity link
  prior(normal(0, 1), class = "Intercept"),
  prior(normal(0, 0.5), class = "b"),
  
  # Boundary separation (a/bs) - log link: center at log(1.7) for older adults
  prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
  prior(normal(0, 0.20), class = "b", dpar = "bs"),
  
  # Non-decision time (t0/ndt) - log link: center at log(0.35) for older adults + response-signal
  prior(normal(log(0.35), 0.25), class = "Intercept", dpar = "ndt"),
  prior(normal(0, 0.15), class = "b", dpar = "ndt"),
  
  # Starting point bias (z) - logit link: centered at 0.5 with moderate spread
  prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
  prior(normal(0, 0.3), class = "b", dpar = "bias"),
  
  # Random effects - subject-level variability
  prior(student_t(3, 0, 0.5), class = "sd")
)

# Fit model
fit_tonic <- brm(
  formula = f_tonic_alpha,
  data = d,
  family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
  prior = priors,
  backend = "cmdstanr",
  cores = max(2, parallel::detectCores() - 2),
  chains = 4, iter = 4000, warmup = 1000,
  control = list(adapt_delta = 0.9, max_treedepth = 12),
  seed = 123
)

# Save model
dir.create("models", showWarnings = FALSE, recursive = TRUE)
saveRDS(fit_tonic, "models/ddm_alpha_tonic.rds")
cat("Model saved to models/ddm_alpha_tonic.rds\n")

# Compute LOO
cat("\nComputing LOO for model evaluation...\n")
library(loo)
loo_tonic <- loo(fit_tonic, reloo = TRUE)

dir.create("output/loo", recursive = TRUE, showWarnings = FALSE)
saveRDS(loo_tonic, "output/loo/ddm_alpha_tonic_loo.rds")
cat("LOO saved to output/loo/ddm_alpha_tonic_loo.rds\n")

# Print LOO summary
cat("\nLOO Summary:\n")
print(loo_tonic)

# =========================================================================
# EXTRACT POSTERIOR ESTIMATES
# =========================================================================

cat("\nExtracting posterior estimates...\n")
post <- posterior_samples(fit_tonic)

# Key parameters for tonic effects on bs
tonic_params <- c(
  "b_bs_TONIC_BASELINE_wp",
  "b_bs_ITONIC_BASELINE_wpE2",
  "b_bs_TONIC_BASELINE_bp"
)

tonic_summary <- data.frame(
  Parameter = c("Linear WP", "Quadratic WP", "Linear BP"),
  Variable = c("TONIC_BASELINE_wp", "TONIC_BASELINE_wp²", "TONIC_BASELINE_bp")
)

for (i in seq_along(tonic_params)) {
  param <- tonic_params[i]
  if (param %in% colnames(post)) {
    samples <- post[[param]]
    tonic_summary$Mean[i] <- mean(samples)
    tonic_summary$SE[i] <- sd(samples)
    tonic_summary$`2.5%`[i] <- quantile(samples, 0.025)
    tonic_summary$`97.5%`[i] <- quantile(samples, 0.975)
    tonic_summary$P_effect[i] <- mean(samples > 0)
  } else {
    tonic_summary$Mean[i] <- NA
  }
}

cat("\nTonic effects on boundary separation (α):\n")
print(tonic_summary)

# =========================================================================
# CREATE TABLE
# =========================================================================

dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)

table_text <- paste0(
  "# Table: Tonic Baseline Effects on Boundary Separation (α)\n\n",
  "| Parameter | Estimate | 95% CrI | Pr(>0) | Notes |\n",
  "|-----------|----------|---------|--------|-------|\n",
  "| Linear WP | ", sprintf("%.3f", tonic_summary$Mean[1]), " | [", 
  sprintf("%.3f", tonic_summary$`2.5%`[1]), ", ", 
  sprintf("%.3f", tonic_summary$`97.5%`[1]), "] | ", 
  sprintf("%.3f", tonic_summary$P_effect[1]), " | Within-person tonic |\n",
  "| Quadratic WP | ", sprintf("%.3f", tonic_summary$Mean[2]), " | [", 
  sprintf("%.3f", tonic_summary$`2.5%`[2]), ", ", 
  sprintf("%.3f", tonic_summary$`97.5%`[2]), "] | ", 
  sprintf("%.3f", tonic_summary$P_effect[2]), " | Inverted-U? |\n",
  "| Linear BP | ", sprintf("%.3f", tonic_summary$Mean[3]), " | [", 
  sprintf("%.3f", tonic_summary$`2.5%`[3]), ", ", 
  sprintf("%.3f", tonic_summary$`97.5%`[3]), "] | ", 
  sprintf("%.3f", tonic_summary$P_effect[3]), " | Trait-level tonic |\n"
)

writeLines(table_text, "output/tables/Table_TonicEffects.md")
cat("\nTable saved to output/tables/Table_TonicEffects.md\n")

# =========================================================================
# VISUALIZATION: α vs TONIC_BASELINE_wp
# =========================================================================

cat("\nCreating visualization...\n")

# Generate predictions across range of tonic baseline
tonic_range <- seq(min(d$TONIC_BASELINE_wp, na.rm = TRUE), 
                   max(d$TONIC_BASELINE_wp, na.rm = TRUE), 
                   length.out = 100)

pred_data <- data.frame(
  TONIC_BASELINE_wp = tonic_range,
  TONIC_BASELINE_bp = 0,  # Set to zero for visualization
  difficulty_level = "Easy",
  effort_condition = "Low_5_MVC",
  subj = d$subj[1]
)

predictions <- fitted(fit_tonic, newdata = pred_data, dpar = "bs")

pred_plot <- data.frame(
  tonic = tonic_range,
  alpha_mean = apply(predictions, 2, mean),
  alpha_lower = apply(predictions, 2, quantile, 0.025),
  alpha_upper = apply(predictions, 2, quantile, 0.975)
)

dir.create("output/figures/tonic", showWarnings = FALSE, recursive = TRUE)

p <- ggplot(pred_plot, aes(x = tonic)) +
  geom_ribbon(aes(ymin = alpha_lower, ymax = alpha_upper), alpha = 0.3, fill = "steelblue") +
  geom_line(aes(y = alpha_mean), color = "steelblue", size = 1.2) +
  labs(
    x = "Within-Person Tonic Baseline (standardized)",
    y = "Boundary Separation (α)",
    title = "Tonic Baseline Effects on Boundary Separation",
    subtitle = "Posterior mean with 95% credible interval"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 12)
  )

ggsave("output/figures/tonic/alpha_vs_tonic.png", p, 
       width = 8, height = 6, dpi = 300)
cat("Figure saved to output/figures/tonic/alpha_vs_tonic.png\n")

# =========================================================================
# VIF CHECK
# =========================================================================

cat("\nChecking for multicollinearity...\n")

# Create simple linear model to check VIF
vif_model <- lm(
  TONIC_BASELINE_wp ~ difficulty_level + effort_condition + TONIC_BASELINE_bp,
  data = d
)

vif_values <- car::vif(vif_model)
max_vif <- max(vif_values)

cat("VIF values:\n")
print(vif_values)
cat("Max VIF:", round(max_vif, 3), "\n")

dir.create("output/logs", showWarnings = FALSE, recursive = TRUE)

if (max_vif > 5) {
  warning_msg <- paste0(
    "WARNING: High VIF detected\n",
    "Max VIF: ", round(max_vif, 3), "\n",
    "Consider residualization or removing predictors\n",
    "Generated: ", Sys.time(), "\n"
  )
  writeLines(warning_msg, "output/logs/tonic_vif.txt")
  cat("⚠️  WARNING: High VIF > 5 logged to output/logs/tonic_vif.txt\n")
} else {
  cat("✅ VIF < 5 - No multicollinearity issues\n")
}

# =========================================================================
# POSTERIOR PREDICTIVE CHECKS
# =========================================================================

cat("\nCreating posterior predictive checks...\n")

dir.create("output/figures/ppc", recursive = TRUE, showWarnings = FALSE)

# 1. RT distribution overlay
cat("Creating RT distribution overlay...\n")
png("output/figures/ppc/tonic_alpha_rt_dist.png", width = 1200, height = 800, res = 150)
pp_check(fit_tonic, type = "dens_overlay", ndraws = 50) +
  labs(title = "Posterior Predictive Check: RT Distribution",
       subtitle = "Tonic → α Model")
dev.off()

# 2. Accuracy by condition (if available)
if ("difficulty_level" %in% colnames(d)) {
  cat("Creating accuracy by condition...\n")
  d$correct <- ifelse(d$choice == 1, 1, 0)
  
  # Observe accuracy by condition
  obs_acc <- d %>%
    group_by(difficulty_level) %>%
    summarise(
      mean_acc = mean(correct, na.rm = TRUE),
      se_acc = sd(correct, na.rm = TRUE) / sqrt(n()),
      .groups = "drop"
    )
  
  # Simulate from posterior
  post_pred <- posterior_predict(fit_tonic, ndraws = 200)
  
  # Compute accuracy for simulated data (simplified, uses observed grouping)
  sim_acc <- matrix(NA, nrow = 200, ncol = length(unique(d$difficulty_level)))
  for (i in 1:200) {
    for (j in seq_along(unique(d$difficulty_level))) {
      cond_mask <- d$difficulty_level == unique(d$difficulty_level)[j]
      sim_acc[i, j] <- mean(post_pred[i, cond_mask], na.rm = TRUE)
    }
  }
  
  # Create comparison plot
  sim_acc_df <- data.frame(
    condition = rep(unique(d$difficulty_level), each = 200),
    accuracy = as.vector(sim_acc)
  )
  
  p_acc <- ggplot(sim_acc_df, aes(x = condition, y = accuracy)) +
    geom_violin(alpha = 0.3, fill = "steelblue") +
    geom_boxplot(alpha = 0.5, width = 0.2) +
    geom_point(data = obs_acc, aes(y = mean_acc), color = "red", size = 3) +
    geom_errorbar(data = obs_acc, aes(ymin = mean_acc - se_acc, ymax = mean_acc + se_acc),
                  color = "red", width = 0.1, linewidth = 1) +
    labs(
      title = "Posterior Predictive Check: Accuracy by Condition",
      subtitle = "Red dots = observed, Blue = predicted",
      x = "Condition",
      y = "Accuracy"
    ) +
    theme_minimal()
  
  ggsave("output/figures/ppc/tonic_alpha_acc_by_condition.png", p_acc,
         width = 10, height = 6, dpi = 300)
}

cat("PPC plots saved to output/figures/ppc/\n")

cat("\n✅ Tonic→α analysis complete!\n")
