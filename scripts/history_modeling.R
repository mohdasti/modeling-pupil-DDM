# =========================================================================
# EXPLICIT HISTORY MODELING: BIAS vs DRIFT ROUTES
# =========================================================================
# Tests whether trial history (prev_choice, prev_outcome) affects
# decision-making through the bias (z) route, drift (v) route, or both
# =========================================================================

suppressPackageStartupMessages({
  library(brms); library(dplyr); library(readr); library(loo); library(tidyr)
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

# Check if history variables exist, create if not
if (!"prev_choice" %in% colnames(d)) {
  cat("Creating prev_choice variable...\n")
  d <- d %>%
    arrange(subject_id, task, run, trial_index) %>%
    group_by(subject_id, task) %>%
    mutate(
      prev_choice = lag(choice_binary),
      prev_choice = ifelse(is.na(prev_choice), 0, prev_choice)
    ) %>%
    ungroup()
}

if (!"prev_outcome" %in% colnames(d)) {
  cat("Creating prev_outcome variable...\n")
  d <- d %>%
    arrange(subject_id, task, run, trial_index) %>%
    group_by(subject_id, task) %>%
    mutate(
      prev_outcome = lag(choice_binary),  # Using choice_binary as proxy for outcome
      prev_outcome = ifelse(is.na(prev_outcome), 0, prev_outcome)
    ) %>%
    ungroup()
}

# Code history variables as -1/1
d <- d %>%
  mutate(
    prev_choice_scaled = case_when(
      prev_choice == 1 ~ 1,
      prev_choice == 0 ~ -1,
      TRUE ~ 0
    ),
    prev_outcome_scaled = case_when(
      prev_outcome == 1 ~ 1,
      prev_outcome == 0 ~ -1,
      TRUE ~ 0
    )
  )

# Filter to valid trials
d <- d %>%
  filter(
    !is.na(rt), !is.na(choice_binary),
    !is.na(prev_choice_scaled), !is.na(prev_outcome_scaled),
    rt > 0.15, rt < 5.0,
    difficulty_level != "Standard",
    prev_choice_scaled != 0  # Only include trials with valid history
  ) %>%
  mutate(
    subj = as.factor(subject_id),
    choice = as.integer(choice_binary),
    difficulty = as.factor(difficulty_level),
    effort = as.factor(effort_condition)
  )

cat("Data ready: ", nrow(d), " trials from ", length(unique(d$subject_id)), " participants\n")

# =========================================================================
# MODEL SPECIFICATIONS
# =========================================================================

cat("\nDefining model specifications...\n")

# M0: No history (baseline)
f_M0 <- bf(
  rt | dec(choice) ~ 1 + difficulty + effort + (1 | subj),
  bs   ~ 1 + difficulty + effort + (1 | subj),
  ndt  ~ 1 + difficulty + (1 | subj),
  bias ~ 1 + (1 | subj)
)

# Mz: History affects bias (z) route only
f_Mz <- bf(
  rt | dec(choice) ~ 1 + difficulty + effort + (1 | subj),
  bs   ~ 1 + difficulty + effort + (1 | subj),
  ndt  ~ 1 + difficulty + (1 | subj),
  bias ~ 1 + difficulty + effort + prev_choice_scaled + prev_outcome_scaled + (1 | subj)
)

# Mv: History affects drift (v) route only
f_Mv <- bf(
  rt | dec(choice) ~ 1 + difficulty + effort + prev_choice_scaled + prev_outcome_scaled + (1 + prev_choice_scaled | subj),
  bs   ~ 1 + difficulty + effort + (1 | subj),
  ndt  ~ 1 + difficulty + (1 | subj),
  bias ~ 1 + difficulty + effort + (1 | subj)
)

# Mb: History affects both routes
f_Mb <- bf(
  rt | dec(choice) ~ 1 + difficulty + effort + prev_choice_scaled + prev_outcome_scaled + (1 + prev_choice_scaled | subj),
  bs   ~ 1 + difficulty + effort + (1 | subj),
  ndt  ~ 1 + difficulty + (1 | subj),
  bias ~ 1 + difficulty + effort + prev_choice_scaled + prev_outcome_scaled + (1 | subj)
)

# Priors
priors <- c(
  prior(normal(0, 0.5), class = "b"),
  prior(normal(0, 1), class = "sd"),
  prior(normal(0, 0.2), class = "Intercept", dpar = "bias"),
  prior(normal(0, 0.2), class = "Intercept", dpar = "bs"),
  prior(normal(0, 0.2), class = "Intercept", dpar = "ndt")
)

# =========================================================================
# FIT MODELS
# =========================================================================

models_to_fit <- list(
  "M0_baseline" = list(formula = f_M0, name = "M0: No history"),
  "Mz_bias" = list(formula = f_Mz, name = "Mz: History → bias"),
  "Mv_drift" = list(formula = f_Mv, name = "Mv: History → drift"),
  "Mb_both" = list(formula = f_Mb, name = "Mb: History → both")
)

fits <- list()
dir.create("models/history", showWarnings = FALSE, recursive = TRUE)

for (model_id in names(models_to_fit)) {
  spec <- models_to_fit[[model_id]]
  
  cat("\nFitting", spec$name, "...\n")
  
  tryCatch({
    fit <- brm(
      formula = spec$formula,
      data = d,
      family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
      prior = priors,
      backend = "cmdstanr",
      cores = max(2, parallel::detectCores() - 2),
      chains = 4, iter = 4000, warmup = 1000,
      control = list(adapt_delta = 0.9, max_treedepth = 12),
      seed = 123,
      file = paste0("models/history/", model_id, ".rds"),
      refresh = 500
    )
    
    fits[[model_id]] <- fit
    cat("✓", spec$name, "fitted successfully\n")
    
  }, error = function(e) {
    cat("✗ Error fitting", spec$name, ":", e$message, "\n")
  })
}

# =========================================================================
# LOO COMPARISON
# =========================================================================

cat("\nComputing LOO for model comparison...\n")

loo_results <- list()
for (model_id in names(fits)) {
  tryCatch({
    loo_fit <- loo(fits[[model_id]], reloo = TRUE)
    loo_results[[model_id]] <- loo_fit
    cat("✓", model_id, "LOO computed\n")
  }, error = function(e) {
    cat("✗ Error computing LOO for", model_id, ":", e$message, "\n")
  })
}

# Save individual LOO files
dir.create("output/loo", recursive = TRUE, showWarnings = FALSE)
for (model_id in names(loo_results)) {
  saveRDS(loo_results[[model_id]], paste0("output/loo/", model_id, "_loo.rds"))
  cat("Saved", paste0("output/loo/", model_id, "_loo.rds"), "\n")
}

# Compare models
if (length(loo_results) > 0) {
  cat("\nPerforming LOO comparison...\n")
  loo_compare_result <- loo_compare(loo_results)
  
  print(loo_compare_result)
  
  # Save comparison output
  writeLines(capture.output(loo_compare_result), "output/loo/history_models_loo_compare.txt")
  
  # Extract comparison table
  comparison_data <- data.frame(
    model = rownames(loo_compare_result),
    elpd_loo = loo_compare_result$elpd_loo,
    se = loo_compare_result$se,
    dELPD = 0,
    weight = 0
  )
  
  # Calculate dELPD (difference from best model)
  best_model_idx <- which.max(comparison_data$elpd_loo)
  comparison_data$dELPD <- comparison_data$elpd_loo - comparison_data$elpd_loo[best_model_idx]
  
  # Calculate Akaike weights
  comparison_data$weight <- exp(-0.5 * abs(comparison_data$dELPD))
  comparison_data$weight <- comparison_data$weight / sum(comparison_data$weight)
  
  # Add model descriptions
  comparison_data$description <- sapply(comparison_data$model, function(x) {
    models_to_fit[[x]]$name
  })
  
  # Sort by elpd_loo (descending)
  comparison_data <- comparison_data[order(comparison_data$elpd_loo, decreasing = TRUE), ]
  
  # Save comparison table
  dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)
  readr::write_csv(comparison_data, "output/tables/history_model_compare.csv")
  
  cat("\nModel comparison saved to output/tables/history_model_compare.csv\n")
  
  # Print results
  cat("\nLOO Comparison Results:\n")
  cat(sprintf("%-20s %10s %10s %10s %10s\n", "Model", "elpd_loo", "SE", "dELPD", "Weight"))
  cat(paste(rep("-", 70), collapse = ""), "\n")
  for (i in 1:nrow(comparison_data)) {
    cat(sprintf("%-20s %10.1f %10.1f %10.1f %10.3f\n",
                comparison_data$model[i],
                comparison_data$elpd_loo[i],
                comparison_data$se[i],
                comparison_data$dELPD[i],
                comparison_data$weight[i]))
  }
  
  cat("\nBest model:", comparison_data$model[1], "(", comparison_data$description[1], ")\n")
  cat("Weight:", sprintf("%.1f%%", comparison_data$weight[1] * 100), "\n")
} else {
  cat("\n⚠️  No LOO results available for comparison\n")
}

# =========================================================================
# CREATE SUMMARY TABLE
# =========================================================================

cat("\nCreating summary tables...\n")

# Extract key coefficients from best model
best_model_id <- comparison_data$model[1]
best_fit <- fits[[best_model_id]]

post <- posterior_samples(best_fit)

# History-related parameters
history_params <- grep("prev_(choice|outcome)", names(post), value = TRUE)

if (length(history_params) > 0) {
  history_summary <- data.frame(
    Parameter = history_params,
    Mean = sapply(history_params, function(x) mean(post[[x]])),
    `2.5%` = sapply(history_params, function(x) quantile(post[[x]], 0.025)),
    `97.5%` = sapply(history_params, function(x) quantile(post[[x]], 0.975)),
    Pr_effect = sapply(history_params, function(x) mean(post[[x]] > 0))
  )
  
  cat("\nHistory effects in best model:\n")
  print(history_summary)
  
  # Save summary
  readr::write_csv(history_summary, "output/tables/history_effects_summary.csv")
} else {
  cat("\nNo history parameters in best model\n")
}

cat("\n✅ History modeling analysis complete!\n")
cat("Best model:", best_model_id, "\n")
cat("LOO comparison: output/tables/history_model_compare.csv\n")
