# =========================================================================
# STATE/TRAIT DDM MODELS WITH RESIDUALIZED PUPILLOMETRY
# =========================================================================
# This script fits DDM models using state/trait decomposed pupillometry features
# =========================================================================

library(brms)
library(dplyr)
library(readr)
library(bayesplot)
library(tidyr)
library(ggplot2)

# =========================================================================
# CONFIGURATION
# =========================================================================

INPUT_FILE <- "data/analysis_ready/bap_clean_pupil.csv"
OUTPUT_DIR <- "output/models"
RESULTS_DIR <- "output/results"

# =========================================================================
# DATA PREPARATION
# =========================================================================

cat("================================================================================\n")
cat("STATE/TRAIT DDM MODELS\n")
cat("================================================================================\n")
cat("Loading data...\n")

# Load the clean dataset
data <- read_csv(INPUT_FILE, show_col_types = FALSE)

# Filter for valid trials with RT and choice data
# Standardized RT filtering: 0.2-3.0s (consistent with all other scripts)
ddm_data <- data %>%
    filter(!is.na(rt) & !is.na(choice_binary),
           rt >= 0.2 & rt <= 3.0) %>%  # Standardized RT filtering
    mutate(
        participant = factor(subject_id),
        log_rt = log(rt),
        choice_binary = as.numeric(choice_binary)
    )

cat("Valid trials for DDM modeling:", nrow(ddm_data), "\n")
cat("Participants:", length(unique(ddm_data$participant)), "\n")

# =========================================================================
# STANDARDIZED PRIORS: Literature-justified for older adults + response-signal design
# =========================================================================

priors_std <- c(
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

# =========================================================================
# MODEL 1: STATE-LEVEL EFFECTS (WITHIN-PERSON)
# =========================================================================

cat("\n🧠 Fitting Model 1: State-Level Effects (Within-Person)\n")

model1_state <- brm(
    rt | dec(choice_binary) ~ 1 + difficulty_level + effort_condition + 
                              TONIC_BASELINE_scaled_wp + 
                              PHASIC_TER_PEAK_scaled_wp_resid_wp + 
                              PHASIC_SLOPE_scaled_wp_resid_wp +
                              (1 | participant),
    data = ddm_data,
    family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
    prior = priors_std,
    chains = 4, cores = 4, iter = 2000, warmup = 1000, seed = 12345,
    control = list(adapt_delta = 0.95, max_treedepth = 12),
    file = file.path(OUTPUT_DIR, "DDM_State_Level_Effects"),
    file_refit = "on_change", refresh = 100, silent = 0
)

# Check convergence
cat("Model 1 convergence check:\n")
print(summary(model1_state))

# =========================================================================
# MODEL 2: TRAIT-LEVEL EFFECTS (BETWEEN-PERSON)
# =========================================================================

cat("\n🧠 Fitting Model 2: Trait-Level Effects (Between-Person)\n")

model2_trait <- brm(
    rt | dec(choice_binary) ~ 1 + difficulty_level + effort_condition + 
                              TONIC_BASELINE_scaled_bp + 
                              PHASIC_TER_PEAK_scaled_bp + 
                              PHASIC_SLOPE_scaled_bp +
                              (1 | participant),
    data = ddm_data,
    family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
    prior = priors_std,
    chains = 4, cores = 4, iter = 2000, warmup = 1000, seed = 12346,
    control = list(adapt_delta = 0.95, max_treedepth = 12),
    file = file.path(OUTPUT_DIR, "DDM_Trait_Level_Effects"),
    file_refit = "on_change", refresh = 100, silent = 0
)

# Check convergence
cat("Model 2 convergence check:\n")
print(summary(model2_trait))

# =========================================================================
# MODEL 3: COMBINED STATE-TRAIT EFFECTS
# =========================================================================

cat("\n🧠 Fitting Model 3: Combined State-Trait Effects\n")

model3_combined <- brm(
    rt | dec(choice_binary) ~ 1 + difficulty_level + effort_condition + 
                              # State effects (within-person)
                              TONIC_BASELINE_scaled_wp + 
                              PHASIC_TER_PEAK_scaled_wp_resid_wp + 
                              PHASIC_SLOPE_scaled_wp_resid_wp +
                              # Trait effects (between-person)
                              TONIC_BASELINE_scaled_bp + 
                              PHASIC_TER_PEAK_scaled_bp + 
                              PHASIC_SLOPE_scaled_bp +
                              # State-trait interactions
                              TONIC_BASELINE_scaled_wp:TONIC_BASELINE_scaled_bp +
                              PHASIC_TER_PEAK_scaled_wp_resid_wp:PHASIC_TER_PEAK_scaled_bp +
                              (1 | participant),
    data = ddm_data,
    family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
    prior = priors_std,
    chains = 4, cores = 4, iter = 2000, warmup = 1000, seed = 12347,
    control = list(adapt_delta = 0.95, max_treedepth = 12),
    file = file.path(OUTPUT_DIR, "DDM_Combined_State_Trait_Effects"),
    file_refit = "on_change", refresh = 100, silent = 0
)

# Check convergence
cat("Model 3 convergence check:\n")
print(summary(model3_combined))

# =========================================================================
# MODEL 4: FOCUSED STATE-TRAIT INTERACTION
# =========================================================================

cat("\n🧠 Fitting Model 4: Focused State-Trait Interaction\n")

model4_interaction <- brm(
    rt | dec(choice_binary) ~ 1 + difficulty_level + effort_condition + 
                              TONIC_BASELINE_scaled_wp + 
                              TONIC_BASELINE_scaled_bp +
                              TONIC_BASELINE_scaled_wp:TONIC_BASELINE_scaled_bp +
                              (1 | participant),
    data = ddm_data,
    family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
    prior = priors_std,
    chains = 4, cores = 4, iter = 2000, warmup = 1000, seed = 12348,
    control = list(adapt_delta = 0.95, max_treedepth = 12),
    file = file.path(OUTPUT_DIR, "DDM_Focused_State_Trait_Interaction"),
    file_refit = "on_change", refresh = 100, silent = 0
)

# Check convergence
cat("Model 4 convergence check:\n")
print(summary(model4_interaction))

# =========================================================================
# MODEL 5: TEMPORAL EFFECTS (EARLY VS LATE)
# =========================================================================

cat("\n🧠 Fitting Model 5: Temporal Effects (Early vs Late)\n")

# Check if orthogonal features exist
has_orthogonal <- all(c("PHASIC_EARLY_PEAK_scaled_orthogonal_wp", 
                       "PHASIC_LATE_PEAK_scaled_orthogonal_wp") %in% colnames(ddm_data))

if (has_orthogonal) {
    model5_temporal <- brm(
        rt | dec(choice_binary) ~ 1 + difficulty_level + effort_condition + 
                                  TONIC_BASELINE_scaled_wp + 
                                  PHASIC_EARLY_PEAK_scaled_orthogonal_wp + 
                                  PHASIC_LATE_PEAK_scaled_orthogonal_wp +
                                  (1 | participant),
        data = ddm_data,
        family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
        prior = priors_std,
        chains = 4, cores = 4, iter = 2000, warmup = 1000, seed = 12348,
        control = list(adapt_delta = 0.95, max_treedepth = 12),
        file = file.path(OUTPUT_DIR, "DDM_Temporal_Effects"),
        file_refit = "on_change", refresh = 100, silent = 0
    )
    
    # Check convergence
    cat("Model 5 convergence check:\n")
    print(summary(model5_temporal))
} else {
    cat("⚠️  Orthogonal temporal features not available, skipping Model 5\n")
    model5_temporal <- NULL
}

# =========================================================================
# MODEL COMPARISON
# =========================================================================

cat("\n📊 Model Comparison\n")

# Extract key parameters for comparison
extract_key_params <- function(model, model_name) {
    if (is.null(model)) return(NULL)
    
    summary_model <- summary(model)
    fixed_effects <- summary_model$fixed
    
    # Key parameters to extract
    key_params <- c(
        "b_TONIC_BASELINE_scaled_wp", "b_TONIC_BASELINE_scaled_bp",
        "b_PHASIC_TER_PEAK_scaled_wp_resid_wp", "b_PHASIC_TER_PEAK_scaled_bp",
        "b_PHASIC_SLOPE_scaled_wp_resid_wp", "b_PHASIC_SLOPE_scaled_bp",
        "b_difficulty_levelStandard", "b_difficulty_levelHard",
        "b_effort_conditionLow_5_MVC"
    )
    
    # Extract available parameters
    available_params <- intersect(key_params, rownames(fixed_effects))
    
    if (length(available_params) > 0) {
        param_summary <- fixed_effects[available_params, c("Estimate", "l-95% CI", "u-95% CI", "Rhat")]
        param_summary$model <- model_name
        param_summary$parameter <- available_params
        
        return(param_summary)
    }
    
    return(NULL)
}

# Extract parameters from all models
models_list <- list(
    "State_Level" = model1_state,
    "Trait_Level" = model2_trait,
    "Combined" = model3_combined,
    "Focused_Interaction" = model4_interaction,
    "Temporal" = model5_temporal
)

model_comparison <- do.call(rbind, lapply(names(models_list), function(model_name) {
    extract_key_params(models_list[[model_name]], model_name)
}))

# Save model comparison
if (!is.null(model_comparison)) {
    write_csv(model_comparison, file.path(RESULTS_DIR, "state_trait_ddm_comparison.csv"))
    cat("Model comparison saved to:", file.path(RESULTS_DIR, "state_trait_ddm_comparison.csv"), "\n")
}

# =========================================================================
# CONVERGENCE DIAGNOSTICS
# =========================================================================

cat("\n🔍 Convergence Diagnostics Summary\n")

convergence_summary <- data.frame(
    Model = character(),
    Max_Rhat = numeric(),
    Min_ESS = numeric(),
    Max_Treedepth = numeric(),
    Divergent_Transitions = numeric(),
    stringsAsFactors = FALSE
)

for (model_name in names(models_list)) {
    model <- models_list[[model_name]]
    if (!is.null(model)) {
        # Extract convergence diagnostics
        summary_model <- summary(model)
        
        max_rhat <- max(summary_model$fixed$Rhat, na.rm = TRUE)
        min_ess <- min(summary_model$fixed$Bulk_ESS, na.rm = TRUE)
        
        # Get sampler diagnostics
        nuts_diag <- nuts_params(model)
        max_treedepth <- max(nuts_diag$Value[nuts_diag$Parameter == "treedepth__"], na.rm = TRUE)
        divergent <- sum(nuts_diag$Value[nuts_diag$Parameter == "divergent__"], na.rm = TRUE)
        
        convergence_summary <- rbind(convergence_summary, data.frame(
            Model = model_name,
            Max_Rhat = round(max_rhat, 4),
            Min_ESS = round(min_ess, 0),
            Max_Treedepth = max_treedepth,
            Divergent_Transitions = divergent
        ))
    }
}

print(convergence_summary)

# Save convergence summary
write_csv(convergence_summary, file.path(RESULTS_DIR, "state_trait_ddm_convergence.csv"))

# =========================================================================
# POSTERIOR PREDICTIVE CHECKS
# =========================================================================

cat("\n📈 Generating Posterior Predictive Checks\n")

# Create output directory for figures
figures_dir <- file.path("output/figures", "state_trait_ddm")
if (!dir.exists(figures_dir)) {
    dir.create(figures_dir, recursive = TRUE)
}

# PPC for Model 1 (State-level)
if (!is.null(model1_state)) {
    png(file.path(figures_dir, "ppc_model1_state_level.png"), width = 12, height = 8, units = "in", res = 300)
    pp_check(model1_state, type = "dens_overlay") +
        labs(title = "Model 1: State-Level Effects - RT Distribution PPC",
             x = "Response Time", y = "Density") +
        theme_minimal()
    dev.off()
    
    png(file.path(figures_dir, "trace_plot_model1_state_level.png"), width = 12, height = 8, units = "in", res = 300)
    mcmc_trace(model1_state, pars = c("b_TONIC_BASELINE_scaled_wp", 
                                     "b_PHASIC_TER_PEAK_scaled_wp_resid_wp",
                                     "bs", "ndt"))
    dev.off()
}

# PPC for Model 2 (Trait-level)
if (!is.null(model2_trait)) {
    png(file.path(figures_dir, "ppc_model2_trait_level.png"), width = 12, height = 8, units = "in", res = 300)
    pp_check(model2_trait, type = "dens_overlay") +
        labs(title = "Model 2: Trait-Level Effects - RT Distribution PPC",
             x = "Response Time", y = "Density") +
        theme_minimal()
    dev.off()
    
    png(file.path(figures_dir, "trace_plot_model2_trait_level.png"), width = 12, height = 8, units = "in", res = 300)
    mcmc_trace(model2_trait, pars = c("b_TONIC_BASELINE_scaled_bp", 
                                     "b_PHASIC_TER_PEAK_scaled_bp",
                                     "bs", "ndt"))
    dev.off()
}

# PPC for Model 4 (Focused Interaction)
if (!is.null(model4_interaction)) {
    png(file.path(figures_dir, "ppc_model4_focused_interaction.png"), width = 12, height = 8, units = "in", res = 300)
    pp_check(model4_interaction, type = "dens_overlay") +
        labs(title = "Model 4: Focused State-Trait Interaction - RT Distribution PPC",
             x = "Response Time", y = "Density") +
        theme_minimal()
    dev.off()
    
    png(file.path(figures_dir, "trace_plot_model4_focused_interaction.png"), width = 12, height = 8, units = "in", res = 300)
    mcmc_trace(model4_interaction, pars = c("b_TONIC_BASELINE_scaled_wp", 
                                           "b_TONIC_BASELINE_scaled_bp",
                                           "b_TONIC_BASELINE_scaled_wp:TONIC_BASELINE_scaled_bp",
                                           "bs", "ndt"))
    dev.off()
}

# =========================================================================
# RESULTS SUMMARY
# =========================================================================

cat("\n📋 Results Summary\n")

# Create comprehensive results summary
results_summary <- list(
    data_info = list(
        total_trials = nrow(ddm_data),
        participants = length(unique(ddm_data$participant)),
        tasks = unique(ddm_data$task)
    ),
    models_fitted = names(models_list)[!sapply(models_list, is.null)],
    convergence_status = convergence_summary,
    output_files = list(
        models = file.path(OUTPUT_DIR, c("DDM_State_Level_Effects.rds", 
                                        "DDM_Trait_Level_Effects.rds",
                                        "DDM_Combined_State_Trait_Effects.rds",
                                        "DDM_Focused_State_Trait_Interaction.rds",
                                        "DDM_Temporal_Effects.rds")),
        results = file.path(RESULTS_DIR, c("state_trait_ddm_comparison.csv",
                                          "state_trait_ddm_convergence.csv")),
        figures = list.files(figures_dir, full.names = TRUE)
    )
)

# Save results summary
saveRDS(results_summary, file.path(RESULTS_DIR, "state_trait_ddm_results_summary.rds"))

cat("\n================================================================================\n")
cat("✅ STATE/TRAIT DDM MODELS COMPLETE!\n")
cat("================================================================================\n")
cat("Models fitted:", length(models_list), "\n")
cat("Converged models:", sum(convergence_summary$Max_Rhat < 1.01), "\n")
cat("Output directory:", OUTPUT_DIR, "\n")
cat("Results directory:", RESULTS_DIR, "\n")
cat("Figures directory:", figures_dir, "\n")

# Print key findings
cat("\n🎯 KEY FINDINGS:\n")

if (!is.null(model1_state)) {
    state_summary <- summary(model1_state)$fixed
    tonic_state_effect <- state_summary["b_TONIC_BASELINE_scaled_wp", "Estimate"]
    phasic_state_effect <- state_summary["b_PHASIC_TER_PEAK_scaled_wp_resid_wp", "Estimate"]
    
    cat("- State-level tonic effect on boundary separation:", round(tonic_state_effect, 3), "\n")
    cat("- State-level phasic effect on drift rate:", round(phasic_state_effect, 3), "\n")
}

if (!is.null(model2_trait)) {
    trait_summary <- summary(model2_trait)$fixed
    tonic_trait_effect <- trait_summary["b_TONIC_BASELINE_scaled_bp", "Estimate"]
    phasic_trait_effect <- trait_summary["b_PHASIC_TER_PEAK_scaled_bp", "Estimate"]
    
    cat("- Trait-level tonic effect on boundary separation:", round(tonic_trait_effect, 3), "\n")
    cat("- Trait-level phasic effect on drift rate:", round(phasic_trait_effect, 3), "\n")
}

if (!is.null(model4_interaction)) {
    interaction_summary <- summary(model4_interaction)$fixed
    interaction_effect <- interaction_summary["b_TONIC_BASELINE_scaled_wp:TONIC_BASELINE_scaled_bp", "Estimate"]
    interaction_ci_lower <- interaction_summary["b_TONIC_BASELINE_scaled_wp:TONIC_BASELINE_scaled_bp", "l-95% CI"]
    interaction_ci_upper <- interaction_summary["b_TONIC_BASELINE_scaled_wp:TONIC_BASELINE_scaled_bp", "u-95% CI"]
    
    cat("- Focused state-trait interaction effect:", round(interaction_effect, 3), 
        "95% CrI: [", round(interaction_ci_lower, 3), ",", round(interaction_ci_upper, 3), "]\n")
}

cat("\nReady for interpretation and reporting!\n")
