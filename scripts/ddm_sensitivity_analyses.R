# =========================================================================
# DDM SENSITIVITY ANALYSES FOR REVIEWERS
# =========================================================================
# A) Exclude 6 sub-chance subjects, re-fit Model3_Difficulty & Model10_Param_v_bs
# B) Tighten RT upper bound to 2.5s, re-fit same models
# C) (Optional) Add ndt random intercepts with student_t(3,0,0.15) prior
# =========================================================================

library(brms)
library(dplyr)
library(readr)
library(posterior)

cat("\n")
cat("================================================================================\n")
cat("DDM SENSITIVITY ANALYSES\n")
cat("================================================================================\n")
cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Set working directory
if (!file.exists("output/models")) {
  if (file.exists("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")) {
    setwd("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")
  }
}

# Create output directories
dir.create("output/sensitivity", recursive = TRUE, showWarnings = FALSE)
dir.create("output/models/sensitivity", recursive = TRUE, showWarnings = FALSE)

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

cat("✓ Data loaded:", nrow(data), "trials\n")

# =========================================================================
# IDENTIFY SUB-CHANCE SUBJECTS
# =========================================================================

cat("\nIdentifying sub-chance subjects (accuracy < 0.5)...\n")

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

cat(sprintf("Found %d sub-chance subjects (< 50%% accuracy):\n", length(sub_chance_subjects)))
for (subj in sub_chance_subjects) {
  acc <- subject_accuracy$mean_accuracy[subject_accuracy$subject_id == subj]
  n <- subject_accuracy$n_trials[subject_accuracy$subject_id == subj]
  cat(sprintf("  %s: %.3f accuracy (%d trials)\n", subj, acc, n))
}

if (length(sub_chance_subjects) != 6) {
  cat(sprintf("⚠️  WARNING: Expected 6 sub-chance subjects, found %d\n", length(sub_chance_subjects)))
}

# Save sub-chance subject list
write.csv(data.frame(subject_id = sub_chance_subjects), 
          "output/sensitivity/sub_chance_subjects.csv", row.names = FALSE)

# =========================================================================
# LOAD ORIGINAL MODELS FOR COMPARISON
# =========================================================================

cat("\nLoading original models for comparison...\n")

load_original_model <- function(model_name) {
  model_path <- file.path("output/models", paste0(model_name, ".rds"))
  if (!file.exists(model_path)) {
    cat(sprintf("⚠️  Original model not found: %s\n", model_path))
    return(NULL)
  }
  return(readRDS(model_path))
}

orig_model3 <- load_original_model("Model3_Difficulty")
orig_model10 <- load_original_model("Model10_Param_v_bs")

# Extract original parameter estimates
extract_params <- function(fit, model_name) {
  if (is.null(fit)) return(NULL)
  
  # Get fixed effects summary
  fe <- fixef(fit, probs = c(0.025, 0.975))
  fe_df <- data.frame(
    model = model_name,
    parameter = rownames(fe),
    estimate = fe[, "Estimate"],
    se = fe[, "Est.Error"],
    ci_lower = fe[, "Q2.5"],
    ci_upper = fe[, "Q97.5"],
    stringsAsFactors = FALSE
  )
  
  return(fe_df)
}

orig_params <- list()
if (!is.null(orig_model3)) {
  orig_params[["Model3_Difficulty"]] <- extract_params(orig_model3, "Model3_Difficulty")
}
if (!is.null(orig_model10)) {
  orig_params[["Model10_Param_v_bs"]] <- extract_params(orig_model10, "Model10_Param_v_bs")
}

# =========================================================================
# BASE PRIORS (from original script)
# =========================================================================

base_priors <- c(
  prior(normal(0, 1), class = "Intercept"),
  prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
  prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
  prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
  prior(student_t(3, 0, 0.5), class = "sd")
)

# =========================================================================
# MODEL SPECIFICATIONS
# =========================================================================

# Model3_Difficulty
model3_spec <- list(
  formula = bf(
    rt | dec(decision) ~ difficulty_level + (1|subject_id),
    bs ~ 1 + (1|subject_id),
    ndt ~ 1,  # No RE (will add in C)
    bias ~ 1 + (1|subject_id)
  ),
  priors = c(base_priors, prior(normal(0, 0.5), class = "b"))
)

# Model10_Param_v_bs (parameter-specific effects: effort + difficulty on v and bs)
model10_spec <- list(
  formula = bf(
    rt | dec(decision) ~ effort_condition + difficulty_level + (1|subject_id),
    bs ~ effort_condition + difficulty_level + (1|subject_id),  # Effort + difficulty affect boundary
    ndt ~ 1,  # No RE (will add in C)
    bias ~ 1 + (1|subject_id)
  ),
  priors = c(
    base_priors,
    prior(normal(0, 0.5), class = "b"),
    prior(normal(0, 0.20), class = "b", dpar = "bs")  # Tighter prior for bs effects
  )
)

# Model3 with ndt RE (for sensitivity C)
model3_ndt_re_spec <- list(
  formula = bf(
    rt | dec(decision) ~ difficulty_level + (1|subject_id),
    bs ~ 1 + (1|subject_id),
    ndt ~ 1 + (1|subject_id),  # Add RE for ndt
    bias ~ 1 + (1|subject_id)
  ),
  priors = c(
    base_priors,
    prior(normal(0, 0.5), class = "b"),
    prior(student_t(3, 0, 0.15), class = "sd", group = "subject_id", dpar = "ndt")  # NDT RE prior
  )
)

# Model10 with ndt RE (for sensitivity C)
model10_ndt_re_spec <- list(
  formula = bf(
    rt | dec(decision) ~ effort_condition + difficulty_level + (1|subject_id),
    bs ~ effort_condition + difficulty_level + (1|subject_id),
    ndt ~ 1 + (1|subject_id),  # Add RE for ndt
    bias ~ 1 + (1|subject_id)
  ),
  priors = c(
    base_priors,
    prior(normal(0, 0.5), class = "b"),
    prior(normal(0, 0.20), class = "b", dpar = "bs"),
    prior(student_t(3, 0, 0.15), class = "sd", group = "subject_id", dpar = "ndt")
  )
)

# =========================================================================
# INITIALIZATION FUNCTIONS
# =========================================================================

standard_init <- function() {
  list(
    Intercept = rnorm(1, 0, 0.5),
    Intercept_bs = log(1.3),
    Intercept_ndt = log(0.18),
    Intercept_bias = 0,
    sd_subject_id__Intercept = runif(1, 0.1, 0.3),
    sd_subject_id__bs_Intercept = runif(1, 0.05, 0.15),
    sd_subject_id__bias_Intercept = runif(1, 0.05, 0.15)
  )
}

# Zero initialization for ndt RE (sensitivity C)
ndt_re_zero_init <- function() {
  init <- standard_init()
  # Add ndt RE with zero initialization
  init$sd_subject_id__ndt_Intercept <- 0.0
  return(init)
}

# =========================================================================
# FIT MODEL FUNCTION
# =========================================================================

fit_sensitivity_model <- function(model_name, spec, data, sensitivity_type, 
                                  rt_max = 3.0, ndt_re = FALSE, init_func = standard_init) {
  
  cat("\n")
  cat("================================================================================\n")
  cat(sprintf("FITTING: %s (%s)\n", model_name, sensitivity_type))
  cat("================================================================================\n")
  cat("RT range: 0.25 -", rt_max, "s\n")
  cat("Subjects:", length(unique(data$subject_id)), "\n")
  cat("Trials:", nrow(data), "\n")
  if (ndt_re) cat("NDT: WITH random intercepts\n")
  cat("\n")
  
  # Filter data
  ddm_data <- data %>%
    filter(rt >= 0.25 & rt <= rt_max)
  
  if (nrow(ddm_data) == 0) {
    stop("No data after filtering!")
  }
  
  cat(sprintf("After filtering: %d trials\n\n", nrow(ddm_data)))
  
  # Fit model
  fit_start <- Sys.time()
  
  fit <- brm(
    formula = spec$formula,
    data = ddm_data,
    family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
    prior = spec$priors,
    chains = 4,
    iter = 4000,
    warmup = 2000,
    cores = 4,
    init = init_func,
    control = list(adapt_delta = 0.95, max_treedepth = 12),
    backend = "cmdstanr",
    file = file.path("output/models/sensitivity", 
                     paste0(model_name, "_", sensitivity_type, ".rds")),
    file_refit = "always",
    refresh = 200,
    seed = 123
  )
  
  fit_elapsed <- difftime(Sys.time(), fit_start, units = "mins")
  cat(sprintf("✓ Model fitted (%.1f minutes)\n\n", as.numeric(fit_elapsed)))
  
  # Extract parameters
  params <- extract_params(fit, model_name)
  params$sensitivity_type <- sensitivity_type
  params$n_trials <- nrow(ddm_data)
  params$n_subjects <- length(unique(ddm_data$subject_id))
  params$rt_max <- rt_max
  
  return(list(fit = fit, params = params))
}

# =========================================================================
# SENSITIVITY A: EXCLUDE SUB-CHANCE SUBJECTS
# =========================================================================

cat("\n")
cat("================================================================================\n")
cat("SENSITIVITY A: EXCLUDE SUB-CHANCE SUBJECTS\n")
cat("================================================================================\n\n")

data_exclude_subchance <- data %>%
  filter(!subject_id %in% sub_chance_subjects) %>%
  filter(rt >= 0.25 & rt <= 3.0)

cat(sprintf("Excluded %d sub-chance subjects\n", length(sub_chance_subjects)))
cat(sprintf("Remaining: %d subjects, %d trials\n\n", 
            length(unique(data_exclude_subchance$subject_id)),
            nrow(data_exclude_subchance)))

# Fit Model3_Difficulty
sensA_model3 <- fit_sensitivity_model(
  "Model3_Difficulty", 
  model3_spec, 
  data_exclude_subchance,
  "A_exclude_subchance",
  rt_max = 3.0,
  ndt_re = FALSE
)

# Fit Model10_Param_v_bs
sensA_model10 <- fit_sensitivity_model(
  "Model10_Param_v_bs",
  model10_spec,
  data_exclude_subchance,
  "A_exclude_subchance",
  rt_max = 3.0,
  ndt_re = FALSE
)

# =========================================================================
# SENSITIVITY B: TIGHTEN RT UPPER BOUND TO 2.5s
# =========================================================================

cat("\n")
cat("================================================================================\n")
cat("SENSITIVITY B: RT UPPER BOUND = 2.5s\n")
cat("================================================================================\n\n")

data_rt25 <- data %>%
  filter(rt >= 0.25 & rt <= 2.5)

cat(sprintf("RT filter: 0.25 - 2.5s\n"))
cat(sprintf("Remaining: %d subjects, %d trials\n\n",
            length(unique(data_rt25$subject_id)),
            nrow(data_rt25)))

# Fit Model3_Difficulty
sensB_model3 <- fit_sensitivity_model(
  "Model3_Difficulty",
  model3_spec,
  data_rt25,
  "B_rt_max_25",
  rt_max = 2.5,
  ndt_re = FALSE
)

# Fit Model10_Param_v_bs
sensB_model10 <- fit_sensitivity_model(
  "Model10_Param_v_bs",
  model10_spec,
  data_rt25,
  "B_rt_max_25",
  rt_max = 2.5,
  ndt_re = FALSE
)

# =========================================================================
# SENSITIVITY C: ADD NDT RANDOM INTERCEPTS (OPTIONAL)
# =========================================================================

cat("\n")
cat("================================================================================\n")
cat("SENSITIVITY C: ADD NDT RANDOM INTERCEPTS (OPTIONAL)\n")
cat("================================================================================\n\n")

cat("Fitting with ndt random intercepts (prior: student_t(3,0,0.15))\n")
cat("Using zero initialization for ndt RE...\n\n")

data_base <- data %>%
  filter(rt >= 0.25 & rt <= 3.0)

# Fit Model3_Difficulty with ndt RE
sensC_model3 <- fit_sensitivity_model(
  "Model3_Difficulty",
  model3_ndt_re_spec,
  data_base,
  "C_ndt_re",
  rt_max = 3.0,
  ndt_re = TRUE,
  init_func = ndt_re_zero_init
)

# Fit Model10_Param_v_bs with ndt RE
sensC_model10 <- fit_sensitivity_model(
  "Model10_Param_v_bs",
  model10_ndt_re_spec,
  data_base,
  "C_ndt_re",
  rt_max = 3.0,
  ndt_re = TRUE,
  init_func = ndt_re_zero_init
)

# =========================================================================
# COMPUTE PARAMETER SHIFTS (DELTAS)
# =========================================================================

cat("\n")
cat("================================================================================\n")
cat("COMPUTING PARAMETER SHIFTS\n")
cat("================================================================================\n\n")

compute_delta <- function(orig_params, sens_params, model_name, sens_type) {
  if (is.null(orig_params) || is.null(sens_params)) {
    return(NULL)
  }
  
  # Merge by parameter name
  merged <- merge(
    orig_params,
    sens_params,
    by = "parameter",
    suffixes = c("_orig", "_sens"),
    all = TRUE
  )
  
  merged$model <- model_name
  merged$sensitivity <- sens_type
  merged$delta <- merged$estimate_sens - merged$estimate_orig
  merged$delta_se <- sqrt(merged$se_orig^2 + merged$se_sens^2)
  merged$delta_z <- merged$delta / merged$delta_se
  merged$delta_pct <- (merged$delta / abs(merged$estimate_orig)) * 100
  
  # Rename for clarity
  names(merged)[names(merged) == "estimate_orig"] <- "estimate_original"
  names(merged)[names(merged) == "estimate_sens"] <- "estimate_sensitivity"
  names(merged)[names(merged) == "se_orig"] <- "se_original"
  names(merged)[names(merged) == "se_sens"] <- "se_sensitivity"
  
  return(merged)
}

# Collect all sensitivity results
sensitivity_summary <- data.frame()

# Sensitivity A
if (!is.null(orig_params[["Model3_Difficulty"]])) {
  sensA_delta3 <- compute_delta(
    orig_params[["Model3_Difficulty"]],
    sensA_model3$params,
    "Model3_Difficulty",
    "A_exclude_subchance"
  )
  if (!is.null(sensA_delta3)) {
    sensitivity_summary <- rbind(sensitivity_summary, sensA_delta3)
  }
}

if (!is.null(orig_params[["Model10_Param_v_bs"]])) {
  sensA_delta10 <- compute_delta(
    orig_params[["Model10_Param_v_bs"]],
    sensA_model10$params,
    "Model10_Param_v_bs",
    "A_exclude_subchance"
  )
  if (!is.null(sensA_delta10)) {
    sensitivity_summary <- rbind(sensitivity_summary, sensA_delta10)
  }
}

# Sensitivity B
if (!is.null(orig_params[["Model3_Difficulty"]])) {
  sensB_delta3 <- compute_delta(
    orig_params[["Model3_Difficulty"]],
    sensB_model3$params,
    "Model3_Difficulty",
    "B_rt_max_25"
  )
  if (!is.null(sensB_delta3)) {
    sensitivity_summary <- rbind(sensitivity_summary, sensB_delta3)
  }
}

if (!is.null(orig_params[["Model10_Param_v_bs"]])) {
  sensB_delta10 <- compute_delta(
    orig_params[["Model10_Param_v_bs"]],
    sensB_model10$params,
    "Model10_Param_v_bs",
    "B_rt_max_25"
  )
  if (!is.null(sensB_delta10)) {
    sensitivity_summary <- rbind(sensitivity_summary, sensB_delta10)
  }
}

# Sensitivity C
if (!is.null(orig_params[["Model3_Difficulty"]])) {
  sensC_delta3 <- compute_delta(
    orig_params[["Model3_Difficulty"]],
    sensC_model3$params,
    "Model3_Difficulty",
    "C_ndt_re"
  )
  if (!is.null(sensC_delta3)) {
    sensitivity_summary <- rbind(sensitivity_summary, sensC_delta3)
  }
}

if (!is.null(orig_params[["Model10_Param_v_bs"]])) {
  sensC_delta10 <- compute_delta(
    orig_params[["Model10_Param_v_bs"]],
    sensC_model10$params,
    "Model10_Param_v_bs",
    "C_ndt_re"
  )
  if (!is.null(sensC_delta10)) {
    sensitivity_summary <- rbind(sensitivity_summary, sensC_delta10)
  }
}

# =========================================================================
# SAVE SENSITIVITY SUMMARY
# =========================================================================

if (nrow(sensitivity_summary) > 0) {
  # Reorder columns for clarity
  summary_cols <- c(
    "model", "sensitivity", "parameter",
    "estimate_original", "se_original",
    "estimate_sensitivity", "se_sensitivity",
    "delta", "delta_se", "delta_z", "delta_pct"
  )
  
  # Add any extra columns
  extra_cols <- setdiff(names(sensitivity_summary), summary_cols)
  final_cols <- c(summary_cols[summary_cols %in% names(sensitivity_summary)], extra_cols)
  
  sensitivity_summary <- sensitivity_summary[, final_cols]
  
  # Sort
  sensitivity_summary <- sensitivity_summary %>%
    arrange(model, sensitivity, parameter)
  
  # Save
  csv_file <- "output/sensitivity/sensitivity_summary.csv"
  write.csv(sensitivity_summary, csv_file, row.names = FALSE)
  
  cat("✓ Sensitivity summary saved to:", csv_file, "\n")
  cat(sprintf("  %d parameter comparisons\n\n", nrow(sensitivity_summary)))
  
  # Print summary
  cat("SUMMARY OF PARAMETER SHIFTS:\n")
  cat("----------------------------------------------------------------------\n")
  print(sensitivity_summary %>%
    group_by(model, sensitivity) %>%
    summarise(
      max_abs_delta = round(max(abs(delta), na.rm = TRUE), 4),
      max_abs_delta_pct = round(max(abs(delta_pct), na.rm = TRUE), 2),
      n_params = n(),
      .groups = "drop"
    ))
  cat("\n")
} else {
  cat("⚠️  No sensitivity comparisons computed (original models may be missing)\n\n")
}

cat("================================================================================\n")
cat("SENSITIVITY ANALYSES COMPLETE\n")
cat("================================================================================\n")
cat("Completed:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("Outputs:\n")
cat("  - Models: output/models/sensitivity/\n")
cat("  - Summary: output/sensitivity/sensitivity_summary.csv\n")
cat("  - Sub-chance subjects: output/sensitivity/sub_chance_subjects.csv\n\n")

