# =========================================================================
# SENSITIVITY ANALYSES: SUBJECTS & RT UPPER BOUND
# =========================================================================
# (1) Drop subjects with overall accuracy < 0.5; refit Model3_Difficulty & Model4_Additive
# (2) Apply RT upper bound 2.5s; refit same models
# Extract drift and boundary effects; compute Δ relative to baseline fits
# Write table with Δ posterior means and overlap of 95% CIs
# Save to output/checks/sensitivity_summary.csv
# =========================================================================

library(brms)
library(dplyr)
library(readr)
library(posterior)

cat("\n")
cat("================================================================================\n")
cat("SENSITIVITY ANALYSES: SUBJECTS & RT UPPER BOUND\n")
cat("================================================================================\n")
cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Set working directory
if (!file.exists("output/models")) {
  if (file.exists("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")) {
    setwd("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")
  }
}

# Create output directory
dir.create("output/checks", recursive = TRUE, showWarnings = FALSE)

# =========================================================================
# LOAD DATA
# =========================================================================

cat("Loading data...\n")
data_file <- "data/analysis_ready/bap_ddm_ready.csv"

if (!file.exists(data_file)) {
  stop("Data file not found: ", data_file)
}

data <- read_csv(data_file, show_col_types = FALSE)

# Harmonize column names
if (!"rt" %in% names(data) && "resp1RT" %in% names(data)) {
  data$rt <- data$resp1RT
}
data$rt <- suppressWarnings(as.numeric(data$rt))

if (!"accuracy" %in% names(data) && "iscorr" %in% names(data)) {
  data$accuracy <- data$iscorr
}

if (!"subject_id" %in% names(data) && "sub" %in% names(data)) {
  data$subject_id <- as.character(data$sub)
}

if (!"task" %in% names(data) && "task_behav" %in% names(data)) {
  data$task <- data$task_behav
}

if (!"difficulty_level" %in% names(data)) {
  if ("stimulus_condition" %in% names(data)) {
    data$difficulty_level <- ifelse(
      data$stimulus_condition == "Standard", "Easy",
      ifelse(data$stimulus_condition == "Oddball", "Hard", NA_character_)
    )
  }
}

# Prepare base data
data <- data %>%
  mutate(
    response = as.integer(accuracy),
    effort_condition = as.factor(effort_condition),
    difficulty_level = as.factor(difficulty_level),
    subject_id = as.factor(subject_id),
    task = as.factor(task),
    decision = ifelse(accuracy == 1, 1, 0)
  )

cat("✓ Data loaded:", nrow(data), "trials\n\n")

# =========================================================================
# IDENTIFY SUB-CHANCE SUBJECTS
# =========================================================================

cat("Identifying sub-chance subjects (accuracy < 0.5)...\n")

subject_accuracy <- data %>%
  filter(!is.na(accuracy)) %>%
  group_by(subject_id) %>%
  summarise(
    n_trials = n(),
    mean_accuracy = mean(accuracy, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(mean_accuracy)

sub_chance_subjects <- subject_accuracy %>%
  filter(mean_accuracy < 0.5) %>%
  pull(subject_id) %>%
  as.character()

cat(sprintf("Found %d sub-chance subjects (< 50%% accuracy)\n", length(sub_chance_subjects)))

# =========================================================================
# LOAD BASELINE MODELS
# =========================================================================

cat("\nLoading baseline models...\n")

load_model <- function(model_name) {
  model_path <- file.path("output/models", paste0(model_name, ".rds"))
  if (!file.exists(model_path)) {
    cat(sprintf("⚠️  Model not found: %s\n", model_path))
    return(NULL)
  }
  return(readRDS(model_path))
}

baseline_model3 <- load_model("Model3_Difficulty")
baseline_model4 <- load_model("Model4_Additive")

if (is.null(baseline_model3) || is.null(baseline_model4)) {
  stop("Baseline models not found. Run main analysis first.")
}

cat("✓ Baseline models loaded\n\n")

# =========================================================================
# EXTRACT BASELINE PARAMETERS
# =========================================================================

extract_key_params <- function(fit, model_name) {
  if (is.null(fit)) return(NULL)
  
  fe <- fixef(fit, probs = c(0.025, 0.975))
  
  # Extract key parameters for drift and boundary effects
  params <- data.frame(
    model = model_name,
    parameter = rownames(fe),
    estimate = fe[, "Estimate"],
    ci_lower = fe[, "Q2.5"],
    ci_upper = fe[, "Q97.5"],
    stringsAsFactors = FALSE
  )
  
  # Filter to drift (v) and boundary (bs) effects only
  # Drift effects: Intercept, difficulty_levelHard, difficulty_levelStandard, effort_conditionLow_5_MVC
  # Boundary effects: bs_Intercept, bs_difficulty_levelHard, bs_effort_conditionLow_5_MVC, etc.
  key_params <- params %>%
    filter(
      parameter == "Intercept" |
      startsWith(parameter, "difficulty_level") |
      startsWith(parameter, "effort_condition") |
      parameter == "bs_Intercept" |
      startsWith(parameter, "bs_difficulty_level") |
      startsWith(parameter, "bs_effort_condition")
    )
  
  return(key_params)
}

baseline_params3 <- extract_key_params(baseline_model3, "Model3_Difficulty")
baseline_params4 <- extract_key_params(baseline_model4, "Model4_Additive")

# =========================================================================
# MODEL SPECIFICATIONS
# =========================================================================

base_priors <- c(
  prior(normal(0, 1), class = "Intercept"),
  prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
  prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
  prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
  prior(student_t(3, 0, 0.5), class = "sd")
)

model3_spec <- list(
  formula = bf(
    rt | dec(decision) ~ difficulty_level + (1|subject_id),
    bs ~ 1 + (1|subject_id),
    ndt ~ 1,
    bias ~ 1 + (1|subject_id)
  ),
  priors = c(base_priors, prior(normal(0, 0.5), class = "b"))
)

model4_spec <- list(
  formula = bf(
    rt | dec(decision) ~ effort_condition + difficulty_level + (1|subject_id),
    bs ~ 1 + (1|subject_id),
    ndt ~ 1,
    bias ~ 1 + (1|subject_id)
  ),
  priors = c(base_priors, prior(normal(0, 0.5), class = "b"))
)

safe_init <- function() {
  list(
    Intercept = rnorm(1, 0, 0.5),
    Intercept_bs = log(1.3),
    Intercept_ndt = log(0.20),
    Intercept_bias = 0
  )
}

# =========================================================================
# SENSITIVITY ANALYSIS 1: DROP SUB-CHANCE SUBJECTS
# =========================================================================

cat("\n")
cat("================================================================================\n")
cat("SENSITIVITY 1: EXCLUDE SUB-CHANCE SUBJECTS\n")
cat("================================================================================\n\n")

data_no_subchance <- data %>%
  filter(!subject_id %in% sub_chance_subjects) %>%
  filter(rt >= 0.25 & rt <= 3.0)

cat(sprintf("Excluded %d sub-chance subjects\n", length(sub_chance_subjects)))
cat(sprintf("Remaining: %d subjects, %d trials\n\n",
            length(unique(data_no_subchance$subject_id)),
            nrow(data_no_subchance)))

# Fit Model3_Difficulty
cat("Fitting Model3_Difficulty (exclude sub-chance)...\n")
fit3_no_subchance <- tryCatch({
  brm(
    formula = model3_spec$formula,
    data = data_no_subchance,
    family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
    prior = model3_spec$priors,
    chains = 4,
    iter = 4000,
    warmup = 2000,
    cores = 4,
    init = safe_init,
    control = list(adapt_delta = 0.95, max_treedepth = 12),
    backend = "cmdstanr",
    refresh = 200,
    seed = 123
  )
}, error = function(e) {
  cat("❌ Error:", e$message, "\n")
  NULL
})

# Fit Model4_Additive
cat("Fitting Model4_Additive (exclude sub-chance)...\n")
fit4_no_subchance <- tryCatch({
  brm(
    formula = model4_spec$formula,
    data = data_no_subchance,
    family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
    prior = model4_spec$priors,
    chains = 4,
    iter = 4000,
    warmup = 2000,
    cores = 4,
    init = safe_init,
    control = list(adapt_delta = 0.95, max_treedepth = 12),
    backend = "cmdstanr",
    refresh = 200,
    seed = 123
  )
}, error = function(e) {
  cat("❌ Error:", e$message, "\n")
  NULL
})

# =========================================================================
# SENSITIVITY ANALYSIS 2: RT UPPER BOUND 2.5s
# =========================================================================

cat("\n")
cat("================================================================================\n")
cat("SENSITIVITY 2: RT UPPER BOUND = 2.5s\n")
cat("================================================================================\n\n")

data_rt25 <- data %>%
  filter(rt >= 0.25 & rt <= 2.5)

cat(sprintf("RT filter: 0.25 - 2.5s\n"))
cat(sprintf("Remaining: %d subjects, %d trials\n\n",
            length(unique(data_rt25$subject_id)),
            nrow(data_rt25)))

# Fit Model3_Difficulty
cat("Fitting Model3_Difficulty (RT <= 2.5s)...\n")
fit3_rt25 <- tryCatch({
  brm(
    formula = model3_spec$formula,
    data = data_rt25,
    family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
    prior = model3_spec$priors,
    chains = 4,
    iter = 4000,
    warmup = 2000,
    cores = 4,
    init = safe_init,
    control = list(adapt_delta = 0.95, max_treedepth = 12),
    backend = "cmdstanr",
    refresh = 200,
    seed = 123
  )
}, error = function(e) {
  cat("❌ Error:", e$message, "\n")
  NULL
})

# Fit Model4_Additive
cat("Fitting Model4_Additive (RT <= 2.5s)...\n")
fit4_rt25 <- tryCatch({
  brm(
    formula = model4_spec$formula,
    data = data_rt25,
    family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
    prior = model4_spec$priors,
    chains = 4,
    iter = 4000,
    warmup = 2000,
    cores = 4,
    init = safe_init,
    control = list(adapt_delta = 0.95, max_treedepth = 12),
    backend = "cmdstanr",
    refresh = 200,
    seed = 123
  )
}, error = function(e) {
  cat("❌ Error:", e$message, "\n")
  NULL
})

# =========================================================================
# EXTRACT PARAMETERS AND COMPUTE DELTAS
# =========================================================================

cat("\n")
cat("================================================================================\n")
cat("COMPUTING PARAMETER DELTAS\n")
cat("================================================================================\n\n")

compute_delta <- function(baseline_params, sensitivity_params, sensitivity_name) {
  if (is.null(baseline_params) || is.null(sensitivity_params)) {
    return(NULL)
  }
  
  # Merge by parameter name
  merged <- merge(
    baseline_params,
    sensitivity_params,
    by = "parameter",
    suffixes = c("_baseline", "_sens"),
    all = TRUE
  )
  
  merged$sensitivity <- sensitivity_name
  merged$delta <- merged$estimate_sens - merged$estimate_baseline
  merged$delta_ci_lower <- merged$ci_lower_sens - merged$ci_upper_baseline  # Conservative lower bound
  merged$delta_ci_upper <- merged$ci_upper_sens - merged$ci_lower_baseline  # Conservative upper bound
  
  # Check CI overlap: if baseline and sensitivity CIs overlap
  merged$ci_overlap <- (merged$ci_upper_baseline >= merged$ci_lower_sens) & 
                       (merged$ci_lower_baseline <= merged$ci_upper_sens)
  
  # Check if delta CI contains zero (no significant change)
  merged$delta_contains_zero <- (merged$delta_ci_lower <= 0) & (merged$delta_ci_upper >= 0)
  
  # Rename for clarity
  names(merged)[names(merged) == "estimate_baseline"] <- "baseline_estimate"
  names(merged)[names(merged) == "estimate_sens"] <- "sensitivity_estimate"
  names(merged)[names(merged) == "ci_lower_baseline"] <- "baseline_ci_lower"
  names(merged)[names(merged) == "ci_upper_baseline"] <- "baseline_ci_upper"
  names(merged)[names(merged) == "ci_lower_sens"] <- "sensitivity_ci_lower"
  names(merged)[names(merged) == "ci_upper_sens"] <- "sensitivity_ci_upper"
  
  return(merged)
}

# Extract parameters from sensitivity fits
sens1_params3 <- if (!is.null(fit3_no_subchance)) extract_key_params(fit3_no_subchance, "Model3_Difficulty") else NULL
sens1_params4 <- if (!is.null(fit4_no_subchance)) extract_key_params(fit4_no_subchance, "Model4_Additive") else NULL
sens2_params3 <- if (!is.null(fit3_rt25)) extract_key_params(fit3_rt25, "Model3_Difficulty") else NULL
sens2_params4 <- if (!is.null(fit4_rt25)) extract_key_params(fit4_rt25, "Model4_Additive") else NULL

# Compute deltas
summary_rows <- list()

if (!is.null(baseline_params3)) {
  if (!is.null(sens1_params3)) {
    delta1_3 <- compute_delta(baseline_params3, sens1_params3, "exclude_subchance")
    if (!is.null(delta1_3)) {
      delta1_3$model <- "Model3_Difficulty"
      summary_rows[[length(summary_rows) + 1]] <- delta1_3
    }
  }
  if (!is.null(sens2_params3)) {
    delta2_3 <- compute_delta(baseline_params3, sens2_params3, "rt_max_25")
    if (!is.null(delta2_3)) {
      delta2_3$model <- "Model3_Difficulty"
      summary_rows[[length(summary_rows) + 1]] <- delta2_3
    }
  }
}

if (!is.null(baseline_params4)) {
  if (!is.null(sens1_params4)) {
    delta1_4 <- compute_delta(baseline_params4, sens1_params4, "exclude_subchance")
    if (!is.null(delta1_4)) {
      delta1_4$model <- "Model4_Additive"
      summary_rows[[length(summary_rows) + 1]] <- delta1_4
    }
  }
  if (!is.null(sens2_params4)) {
    delta2_4 <- compute_delta(baseline_params4, sens2_params4, "rt_max_25")
    if (!is.null(delta2_4)) {
      delta2_4$model <- "Model4_Additive"
      summary_rows[[length(summary_rows) + 1]] <- delta2_4
    }
  }
}

# =========================================================================
# CREATE SUMMARY TABLE
# =========================================================================

if (length(summary_rows) > 0) {
  sensitivity_summary <- do.call(rbind, summary_rows)
  
  # Select key columns for final table
  final_table <- sensitivity_summary %>%
    select(
      model,
      parameter,
      sensitivity,
      baseline_estimate,
      sensitivity_estimate,
      delta,
      delta_ci_lower,
      delta_ci_upper,
      ci_overlap,
      delta_contains_zero
    ) %>%
    arrange(model, sensitivity, parameter)
  
  # Save to CSV
  csv_file <- "output/checks/sensitivity_summary.csv"
  write.csv(final_table, csv_file, row.names = FALSE)
  
  cat("✓ Sensitivity summary saved to:", csv_file, "\n")
  cat(sprintf("  %d parameter comparisons\n\n", nrow(final_table)))
  
  # Print summary
  cat("SUMMARY TABLE:\n")
  cat("----------------------------------------------------------------------\n")
  print(final_table, n = 100)
  cat("\n")
  
  # Print interpretation
  cat("INTERPRETATION:\n")
  cat("- delta: Change in parameter estimate (sensitivity - baseline)\n")
  cat("- delta_ci_lower/upper: Conservative 95% CI for delta\n")
  cat("- ci_overlap: TRUE if baseline and sensitivity CIs overlap\n")
  cat("- delta_contains_zero: TRUE if delta CI includes 0 (no significant change)\n\n")
  
} else {
  cat("⚠️  No sensitivity comparisons computed (fits may have failed)\n\n")
}

cat("================================================================================\n")
cat("SENSITIVITY ANALYSES COMPLETE\n")
cat("================================================================================\n")
cat("Completed:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("Output:\n")
cat("  - Summary: output/checks/sensitivity_summary.csv\n\n")









