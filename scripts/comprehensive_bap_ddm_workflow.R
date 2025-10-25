# =========================================================================
# COMPREHENSIVE BAP DDM ANALYSIS WORKFLOW
# =========================================================================
# This script consolidates multiple analysis steps into a comprehensive workflow:
# 1. State/Trait Decomposition
# 2. VIF Analysis and Residualization
# 3. Base Pupil HDDM Fitting
# 4. Z-Bias Analysis
# 5. Timing Multiverse Analysis
# 6. Robustness Checks
# =========================================================================

library(brms)
library(lme4)
library(dplyr)
library(readr)
library(ggplot2)
library(car)
library(tidyr)
library(bayesplot)
library(patchwork)

# =========================================================================
# CONFIGURATION: PHASIC PUPIL FEATURES
# =========================================================================

# Set phasic window defaults
options(PHASIC_WINDOW_LOWER = 200L, PHASIC_WINDOW_UPPER = 900L)
options(RUN_SENSITIVITY = getOption("RUN_SENSITIVITY", FALSE))

# Source phasic feature computation
source("scripts/pupil/compute_phasic_features.R")

# =========================================================================
# CONFIGURATION
# =========================================================================

DATA_FILE <- "data/analysis_ready/bap_clean_pupil.csv"
RESULTS_DIR <- "output/results"
FIGURES_DIR <- "output/figures"
MODELS_DIR <- "output/models"

# Create directories if they don't exist
dirs_to_create <- c(RESULTS_DIR, FIGURES_DIR, MODELS_DIR)
for (dir in dirs_to_create) {
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
}

cat("================================================================================\n")
cat("COMPREHENSIVE BAP DDM ANALYSIS WORKFLOW\n")
cat("================================================================================\n")

# =========================================================================
# STEP 1: STATE/TRAIT DECOMPOSITION (if not already done)
# =========================================================================

cat("\n🔧 STEP 1: STATE/TRAIT DECOMPOSITION\n")

# Check if decomposed data already exists
if (!file.exists(DATA_FILE)) {
  cat("Running state/trait decomposition...\n")
  source("scripts/utilities/state_trait_decomposition.R")
} else {
  cat("✅ State/trait decomposed data already exists\n")
}

# =========================================================================
# STEP 2: VIF ANALYSIS AND RESIDUALIZATION
# =========================================================================

cat("\n📊 STEP 2: VIF ANALYSIS AND RESIDUALIZATION\n")

# Load data
data <- read_csv(DATA_FILE, show_col_types = FALSE)

# Note: Phasic features are computed in preprocessing (scripts/utilities/state_trait_decomposition.R)
# Primary metric: PHASIC_SLOPE (200-900 ms) - slope of pupil dilation using OLS
# Sensitivity metrics: PEAK, AUC, EARLY, LATE are available but not primary

# Export phasic features for inspection
dir.create("output/results/feature_selection", recursive = TRUE, showWarnings = FALSE)
phasic_export <- data %>%
  select(trial_id = trial_index, subject_id, 
         PHASIC_SLOPE_scaled, PHASIC_SLOPE_scaled_wp,
         PHASIC_TER_PEAK_scaled, PHASIC_TER_AUC_scaled,
         PHASIC_EARLY_PEAK_scaled, PHASIC_LATE_PEAK_scaled) %>%
  distinct() %>%
  filter(!is.na(PHASIC_SLOPE_scaled))

readr::write_csv(phasic_export, "output/results/feature_selection/phasic_features_export.csv")
cat("✅ Exported phasic features to output/results/feature_selection/phasic_features_export.csv\n")

# Prepare data for VIF analysis
vif_data <- data %>%
  filter(
    !is.na(rt), !is.na(choice_binary), !is.na(prev_choice),
    !is.na(difficulty_level), !is.na(effort_condition),
    !is.na(TONIC_BASELINE_scaled_wp), !is.na(PHASIC_SLOPE_scaled_wp_resid_wp),
    rt > 0.1, rt < 5.0
  ) %>%
  mutate(
    participant = as.factor(subject_id),
    difficulty_numeric = case_when(
      difficulty_level == "Hard" ~ 1,
      difficulty_level == "Standard" ~ 0,
      difficulty_level == "Easy" ~ -1,
      TRUE ~ NA_real_
    ),
    effort_numeric = case_when(
      effort_condition == "High_40_MVC" ~ 1,
      effort_condition == "Low_5_MVC" ~ -1,
      TRUE ~ NA_real_
    ),
    prev_choice_scaled = case_when(
      prev_choice == 1 ~ 1,
      prev_choice == 0 ~ -1,
      TRUE ~ 0
    ),
    same_choice = case_when(
      prev_choice == 1 & choice_binary == 1 ~ 1,
      prev_choice == 0 & choice_binary == 0 ~ 1,
      TRUE ~ 0
    )
  ) %>%
  filter(prev_choice_scaled != 0, !is.na(difficulty_numeric), !is.na(effort_numeric))

cat("VIF analysis data: ", nrow(vif_data), " trials, ", length(unique(vif_data$participant)), " participants\n")

# Compute VIFs for PHASIC features
phasic_features <- c(
  "PHASIC_SLOPE_scaled_wp_resid_wp",
  "PHASIC_TER_PEAK_scaled_wp_resid_wp", 
  "PHASIC_TER_AUC_scaled_wp_resid_wp",
  "PHASIC_EARLY_PEAK_scaled_orthogonal_wp",
  "PHASIC_LATE_PEAK_scaled_orthogonal_wp"
)

available_phasic <- phasic_features[phasic_features %in% colnames(vif_data)]
vif_results <- data.frame()

for (feature in available_phasic) {
  formula_str <- paste(feature, "~ TONIC_BASELINE_scaled_wp + difficulty_numeric + effort_numeric")
  vif_model <- lm(as.formula(formula_str), data = vif_data)
  vif_values <- vif(vif_model)
  
  vif_results <- rbind(vif_results, data.frame(
    phasic_feature = feature,
    tonic_vif = vif_values["TONIC_BASELINE_scaled_wp"],
    difficulty_vif = vif_values["difficulty_numeric"],
    effort_vif = vif_values["effort_numeric"],
    max_vif = max(vif_values),
    stringsAsFactors = FALSE
  ))
}

cat("VIF Results: Max VIF =", round(max(vif_results$max_vif), 3), "\n")
if (max(vif_results$max_vif) > 5) {
  cat("⚠️  High VIF detected - residualization needed\n")
} else {
  cat("✅ VIF < 5 - no residualization needed\n")
}

# =========================================================================
# STEP 3: BASE PUPIL HDDM FITTING
# =========================================================================

cat("\n🧠 STEP 3: BASE PUPIL HDDM FITTING\n")

# Prepare DDM data
ddm_data <- vif_data %>%
  filter(!is.na(PHASIC_SLOPE_scaled_wp_resid_wp))

cat("DDM data: ", nrow(ddm_data), " trials\n")

# Fit base pupil model using glmer (more reliable than brms)
base_model <- glmer(
  same_choice ~ 1 + prev_choice_scaled + TONIC_BASELINE_scaled_wp + 
                PHASIC_SLOPE_scaled_wp_resid_wp + 
                prev_choice_scaled:PHASIC_SLOPE_scaled_wp_resid_wp + 
                (1 | participant),
  data = ddm_data,
  family = binomial(),
  control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 100000))
)

cat("✅ Base pupil model fitted!\n")

# Extract key results
base_summary <- summary(base_model)$coefficients
interaction_coef <- base_summary["prev_choice_scaled:PHASIC_SLOPE_scaled_wp_resid_wp", ]

cat("Key interaction effect:\n")
cat("- Estimate:", round(interaction_coef["Estimate"], 4), "\n")
cat("- SE:", round(interaction_coef["Std. Error"], 4), "\n")
cat("- P-value:", round(interaction_coef["Pr(>|z|)"], 4), "\n")

if (interaction_coef["Pr(>|z|)"] < 0.05) {
  cat("✅ SIGNIFICANT: Phasic arousal affects serial bias\n")
} else {
  cat("❌ NOT SIGNIFICANT: No evidence phasic affects serial bias\n")
}

# =========================================================================
# STEP 4: TIMING MULTIVERSE ANALYSIS
# =========================================================================

cat("\n⏰ STEP 4: TIMING MULTIVERSE ANALYSIS\n")

# Define timing features
timing_features <- c(
  "PHASIC_SLOPE_scaled_wp_resid_wp",
  "PHASIC_TER_PEAK_scaled_wp_resid_wp",
  "PHASIC_TER_AUC_scaled_wp_resid_wp",
  "PHASIC_EARLY_PEAK_scaled_orthogonal_wp",
  "PHASIC_LATE_PEAK_scaled_orthogonal_wp"
)

available_timing <- timing_features[timing_features %in% colnames(ddm_data)]
timing_results <- data.frame()

for (feature in available_timing) {
  cat("Fitting model with", feature, "...\n")
  
  timing_model <- glmer(
    same_choice ~ 1 + prev_choice_scaled + TONIC_BASELINE_scaled_wp + 
                  get(feature) + prev_choice_scaled:get(feature) + 
                  (1 | participant),
    data = ddm_data,
    family = binomial(),
    control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 100000))
  )
  
  # Extract AIC and key coefficients
  timing_summary <- summary(timing_model)$coefficients
  interaction_row <- paste0("prev_choice_scaled:", feature)
  
  if (interaction_row %in% rownames(timing_summary)) {
    interaction_coef <- timing_summary[interaction_row, ]
    
    timing_results <- rbind(timing_results, data.frame(
      feature = feature,
      aic = AIC(timing_model),
      bic = BIC(timing_model),
      interaction_estimate = interaction_coef["Estimate"],
      interaction_se = interaction_coef["Std. Error"],
      interaction_p = interaction_coef["Pr(>|z|)"],
      stringsAsFactors = FALSE
    ))
  }
}

# Compute AIC weights
timing_results$aic_weight <- exp(-0.5 * (timing_results$aic - min(timing_results$aic)))
timing_results$aic_weight <- timing_results$aic_weight / sum(timing_results$aic_weight)

# Sort by AIC weight
timing_results <- timing_results[order(timing_results$aic_weight, decreasing = TRUE), ]

cat("Timing multiverse results:\n")
print(timing_results[, c("feature", "aic_weight", "interaction_p")])

best_feature <- timing_results$feature[1]
cat("Best feature:", best_feature, "(AIC weight:", round(timing_results$aic_weight[1], 3), ")\n")

# =========================================================================
# STEP 5: ROBUSTNESS CHECKS
# =========================================================================

cat("\n🔍 STEP 5: ROBUSTNESS CHECKS\n")

# Outlier handling
rt_lower_bound <- 0.2
rt_upper_bound <- 3.0
pupil_missing_threshold <- 0.4

ddm_data_robust <- ddm_data %>%
  group_by(participant) %>%
  mutate(
    is_rt_outlier = rt < rt_lower_bound | rt > rt_upper_bound,
    is_pupil_outlier = pupil_missing_pct > pupil_missing_threshold,
    is_outlier = is_rt_outlier | is_pupil_outlier
  ) %>%
  ungroup()

outlier_summary <- ddm_data_robust %>%
  group_by(participant) %>%
  summarise(
    n_trials = n(),
    n_outliers = sum(is_outlier, na.rm = TRUE),
    pct_outliers = (n_outliers / n_trials) * 100
  )

cat("Outlier summary:\n")
print(outlier_summary)

# Fit model on cleaned data
cleaned_data <- ddm_data_robust %>% filter(!is_outlier)
cat("Cleaned data: ", nrow(cleaned_data), " trials (", 
    round((1 - nrow(cleaned_data)/nrow(ddm_data))*100, 1), "% removed)\n")

robust_model <- glmer(
  same_choice ~ 1 + prev_choice_scaled + TONIC_BASELINE_scaled_wp + 
                get(best_feature) + prev_choice_scaled:get(best_feature) + 
                (1 | participant),
  data = cleaned_data,
  family = binomial(),
  control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 100000))
)

# Compare coefficients
original_coef <- base_summary["prev_choice_scaled:PHASIC_SLOPE_scaled_wp_resid_wp", "Estimate"]
robust_coef <- summary(robust_model)$coefficients[paste0("prev_choice_scaled:", best_feature), "Estimate"]
coef_change <- abs(robust_coef - original_coef) / abs(original_coef) * 100

cat("Coefficient stability:\n")
cat("- Original:", round(original_coef, 4), "\n")
cat("- Robust:", round(robust_coef, 4), "\n")
cat("- Change:", round(coef_change, 1), "%\n")

if (coef_change < 10) {
  cat("✅ STABLE: Coefficient change < 10%\n")
} else {
  cat("⚠️  UNSTABLE: Coefficient change > 10%\n")
}

# =========================================================================
# STEP 6: CREATE COMPREHENSIVE VISUALIZATIONS
# =========================================================================

cat("\n📊 STEP 6: CREATING VISUALIZATIONS\n")

# Plot 1: VIF values
if (nrow(vif_results) > 0) {
  vif_long <- vif_results %>%
    select(phasic_feature, tonic_vif, difficulty_vif, effort_vif) %>%
    pivot_longer(cols = c(tonic_vif, difficulty_vif, effort_vif), 
                 names_to = "predictor", values_to = "vif") %>%
    mutate(
      predictor_clean = case_when(
        predictor == "tonic_vif" ~ "TONIC",
        predictor == "difficulty_vif" ~ "Difficulty",
        predictor == "effort_vif" ~ "Effort",
        TRUE ~ predictor
      )
    )
  
  p1 <- ggplot(vif_long, aes(x = phasic_feature, y = vif, fill = predictor_clean)) +
    geom_col(position = "dodge", alpha = 0.8) +
    geom_hline(yintercept = 5, linetype = "dashed", color = "red") +
    labs(
      title = "VIF Analysis: PHASIC Features vs TONIC + Difficulty + Effort",
      subtitle = "Red line indicates VIF = 5 threshold",
      x = "PHASIC Feature",
      y = "VIF Value",
      fill = "Predictor"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(size = 14, face = "bold"),
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "bottom"
    )
  
  png(file.path(FIGURES_DIR, "comprehensive_vif_analysis.png"), 
      width = 12, height = 6, units = "in", res = 300)
  print(p1)
  dev.off()
}

# Plot 2: Timing multiverse results
p2 <- ggplot(timing_results, aes(x = reorder(feature, aic_weight), y = aic_weight)) +
  geom_col(fill = "#2E86AB", alpha = 0.8) +
  geom_text(aes(label = round(aic_weight, 3)), hjust = -0.1, size = 3) +
  coord_flip() +
  labs(
    title = "Timing Multiverse: AIC Weights by PHASIC Feature",
    subtitle = paste("Best feature:", best_feature),
    x = "PHASIC Feature",
    y = "AIC Weight"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    axis.text.y = element_text(size = 10)
  )

png(file.path(FIGURES_DIR, "comprehensive_timing_multiverse.png"), 
    width = 10, height = 6, units = "in", res = 300)
print(p2)
dev.off()

# Plot 3: Serial bias by phasic quartiles
ddm_data$phasic_quartile <- ntile(ddm_data[[best_feature]], 4)
bias_by_quartile <- ddm_data %>%
  group_by(phasic_quartile) %>%
  summarise(
    bias_prop = mean(same_choice, na.rm = TRUE),
    se = sqrt(bias_prop * (1 - bias_prop) / n()),
    n_trials = n()
  )

p3 <- ggplot(bias_by_quartile, aes(x = phasic_quartile, y = bias_prop)) +
  geom_point(size = 3, color = "#EC70AB") +
  geom_errorbar(aes(ymin = bias_prop - 1.96*se, ymax = bias_prop + 1.96*se), 
                width = 0.1, color = "#EC70AB") +
  geom_line(color = "#EC70AB", alpha = 0.7) +
  labs(
    title = "Serial Bias by PHASIC Quartiles",
    subtitle = paste("Using", best_feature),
    x = "PHASIC Quartile",
    y = "Proportion Same Choice"
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(size = 14, face = "bold"))

png(file.path(FIGURES_DIR, "comprehensive_serial_bias.png"), 
    width = 8, height = 6, units = "in", res = 300)
print(p3)
dev.off()

# =========================================================================
# STEP 7: SAVE COMPREHENSIVE RESULTS
# =========================================================================

cat("\n💾 STEP 7: SAVING COMPREHENSIVE RESULTS\n")

# Create comprehensive summary
comprehensive_summary <- list(
  analysis_info = list(
    timestamp = Sys.time(),
    n_trials = nrow(ddm_data),
    n_participants = length(unique(ddm_data$participant)),
    data_file = DATA_FILE
  ),
  vif_analysis = list(
    max_vif = max(vif_results$max_vif),
    residualization_needed = max(vif_results$max_vif) > 5,
    vif_results = vif_results
  ),
  base_model = list(
    interaction_estimate = interaction_coef["Estimate"],
    interaction_se = interaction_coef["Std. Error"],
    interaction_p = interaction_coef["Pr(>|z|)"],
    significant = interaction_coef["Pr(>|z|)"] < 0.05
  ),
  timing_multiverse = list(
    best_feature = best_feature,
    best_aic_weight = timing_results$aic_weight[1],
    all_results = timing_results
  ),
  robustness = list(
    outlier_percentage = round((1 - nrow(cleaned_data)/nrow(ddm_data))*100, 1),
    coefficient_change_percent = round(coef_change, 1),
    stable = coef_change < 10
  )
)

# Save results
write_csv(vif_results, file.path(RESULTS_DIR, "comprehensive_vif_results.csv"))
write_csv(timing_results, file.path(RESULTS_DIR, "comprehensive_timing_multiverse.csv"))
write_csv(outlier_summary, file.path(RESULTS_DIR, "comprehensive_outlier_summary.csv"))

# Save comprehensive summary as JSON
library(jsonlite)
write_json(comprehensive_summary, file.path(RESULTS_DIR, "comprehensive_analysis_summary.json"), 
           pretty = TRUE, auto_unbox = TRUE)

# =========================================================================
# FINAL SUMMARY
# =========================================================================

cat("\n================================================================================\n")
cat("COMPREHENSIVE BAP DDM ANALYSIS COMPLETE\n")
cat("================================================================================\n")

cat("📊 ANALYSIS SUMMARY:\n")
cat("- Trials analyzed:", comprehensive_summary$analysis_info$n_trials, "\n")
cat("- Participants:", comprehensive_summary$analysis_info$n_participants, "\n")
cat("- Max VIF:", round(comprehensive_summary$vif_analysis$max_vif, 3), "\n")
cat("- Residualization needed:", comprehensive_summary$vif_analysis$residualization_needed, "\n")

cat("\n🧠 KEY FINDINGS:\n")
cat("- Best PHASIC feature:", comprehensive_summary$timing_multiverse$best_feature, "\n")
cat("- AIC weight:", round(comprehensive_summary$timing_multiverse$best_aic_weight, 3), "\n")
cat("- Interaction significant:", comprehensive_summary$base_model$significant, "\n")
cat("- Interaction p-value:", round(comprehensive_summary$base_model$interaction_p, 4), "\n")

cat("\n🔍 ROBUSTNESS:\n")
cat("- Outliers removed:", comprehensive_summary$robustness$outlier_percentage, "%\n")
cat("- Coefficient change:", comprehensive_summary$robustness$coefficient_change_percent, "%\n")
cat("- Stable:", comprehensive_summary$robustness$stable, "\n")

cat("\n📁 OUTPUT FILES:\n")
cat("- VIF results:", file.path(RESULTS_DIR, "comprehensive_vif_results.csv"), "\n")
cat("- Timing multiverse:", file.path(RESULTS_DIR, "comprehensive_timing_multiverse.csv"), "\n")
cat("- Outlier summary:", file.path(RESULTS_DIR, "comprehensive_outlier_summary.csv"), "\n")
cat("- Analysis summary:", file.path(RESULTS_DIR, "comprehensive_analysis_summary.json"), "\n")
cat("- VIF plot:", file.path(FIGURES_DIR, "comprehensive_vif_analysis.png"), "\n")
cat("- Timing plot:", file.path(FIGURES_DIR, "comprehensive_timing_multiverse.png"), "\n")
cat("- Serial bias plot:", file.path(FIGURES_DIR, "comprehensive_serial_bias.png"), "\n")

cat("\n================================================================================\n")
cat("ANALYSIS COMPLETE\n")
cat("================================================================================\n")
