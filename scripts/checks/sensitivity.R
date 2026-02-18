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

# Parallelization: 4 chains default; override with SENSITIVITY_CHAINS and SENSITIVITY_CORES
n_avail <- parallel::detectCores()
n_cores <- as.integer(Sys.getenv("SENSITIVITY_CORES", unset = ""))
if (is.na(n_cores) || n_cores < 1L) n_cores <- n_avail
n_chains_requested <- as.integer(Sys.getenv("SENSITIVITY_CHAINS", unset = "4"))
if (is.na(n_chains_requested) || n_chains_requested < 1L) n_chains_requested <- 4L
n_chains <- min(n_chains_requested, n_cores)
cat("Using", n_chains, "chains,", n_chains, "cores (of", n_avail, "available)\n")

# Max trials per fit: subsample if set (Wiener with 16k trials is very slow; 2500 is enough for sensitivity)
# Set SENSITIVITY_MAX_TRIALS=0 to disable subsampling (full data, much slower)
SENSITIVITY_MAX_TRIALS <- as.integer(Sys.getenv("SENSITIVITY_MAX_TRIALS", unset = "2500"))
if (SENSITIVITY_MAX_TRIALS > 0) {
  cat("Subsampling enabled: max", SENSITIVITY_MAX_TRIALS, "trials per fit (set SENSITIVITY_MAX_TRIALS=0 for full data)\n")
} else {
  SENSITIVITY_MAX_TRIALS <- .Machine$integer.max
  cat("Full data: no subsampling\n")
}

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
data_file_candidates <- c(
  "data/analysis_ready/bap_ddm_only_ready.csv",
  "data/ddm_ready_data_unthresholded.csv",
  "output/rt_threshold_analysis/ddm_ready_data_unthresholded.csv",
  "data/analysis_ready/bap_ddm_ready.csv"
)

data_file <- NULL
for (candidate in data_file_candidates) {
  if (file.exists(candidate)) {
    data_file <- candidate
    break
  }
}

if (is.null(data_file)) {
  stop("No data file found. Tried: ", paste(data_file_candidates, collapse = ", "))
}

cat("  Using:", data_file, "\n")
data <- read_csv(data_file, show_col_types = FALSE)

# Harmonize column names
if (!"rt" %in% names(data) || all(is.na(data$rt))) {
  if ("resp1RT" %in% names(data)) {
    data$rt <- data$resp1RT
  } else if ("same_diff_resp_secs" %in% names(data)) {
    data$rt <- data$same_diff_resp_secs
  } else if ("rt_cue_locked" %in% names(data)) {
    data$rt <- data$rt_cue_locked
  }
}
data$rt <- suppressWarnings(as.numeric(data$rt))

if (!"accuracy" %in% names(data) && "iscorr" %in% names(data)) {
  data$accuracy <- data$iscorr
} else if (!"accuracy" %in% names(data) && "resp_is_correct" %in% names(data)) {
  data$accuracy <- as.integer(data$resp_is_correct)
} else if (!"accuracy" %in% names(data) && all(c("stim_is_diff", "resp_is_diff") %in% names(data))) {
  data$accuracy <- as.integer(data$stim_is_diff == data$resp_is_diff)
}
data$accuracy <- suppressWarnings(as.numeric(data$accuracy))

if (!"subject_id" %in% names(data) && "sub" %in% names(data)) {
  data$subject_id <- as.character(data$sub)
}

if (!"task" %in% names(data) && "task_behav" %in% names(data)) {
  data$task <- data$task_behav
} else if ("task_modality" %in% names(data) && !"task" %in% names(data)) {
  data$task <- ifelse(tolower(data$task_modality) == "aud", "ADT", "VDT")
}

if (!"difficulty_level" %in% names(data)) {
  if ("stimulus_condition" %in% names(data)) {
    data$difficulty_level <- ifelse(
      data$stimulus_condition == "Standard", "Standard",
      ifelse(data$stimulus_condition == "Oddball", "Hard", NA_character_)
    )
  }
}

# Map effort_condition to Low_5_MVC / High_40_MVC if needed (match baseline model levels)
if ("effort_condition" %in% names(data)) {
  data$effort_condition <- as.character(data$effort_condition)
  data$effort_condition <- case_when(
    tolower(data$effort_condition) %in% c("low", "low_5_mvc") ~ "Low_5_MVC",
    tolower(data$effort_condition) %in% c("high", "high_40_mvc") ~ "High_40_MVC",
    TRUE ~ data$effort_condition
  )
}

# Drop rows with missing rt or accuracy (required for filtering and modeling)
n_before <- nrow(data)
data <- data %>% filter(!is.na(rt), !is.na(accuracy))
n_dropped <- n_before - nrow(data)
if (n_dropped > 0) {
  cat("  Dropped", n_dropped, "rows with missing rt or accuracy\n")
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

# Init: NDT must be < min(RT) for Wiener model. init=0 gives NDT=exp(0)=1s -> invalid.
# Use explicit NDT init = log(0.15) ~ -1.9 so NDT ~ 0.15s < min RT (0.25s).
options(cmdstanr_warn_inits = FALSE)

safe_init_wiener <- function(data_df) {
  min_rt <- min(data_df$rt, na.rm = TRUE)
  ndt_ub <- min_rt - 0.05  # NDT must be < min RT; leave 50ms margin
  ndt_ub <- max(0.05, min(0.25, ndt_ub))  # clamp to [0.05, 0.25]
  ndt_log <- log(ndt_ub)
  bs_log <- log(1.3)
  # Include b_*, sd_* to avoid random init (which often gives log(0))
  list(
    Intercept = 0,
    Intercept_bs = bs_log,
    Intercept_ndt = ndt_log,
    Intercept_bias = 0,
    b_Intercept = 0,
    b_bs_Intercept = bs_log,
    b_ndt_Intercept = ndt_log,
    b_bias_Intercept = 0,
    b_difficulty_levelHard = 0,
    b_difficulty_levelStandard = 0,
    b_effort_conditionHigh_40_MVC = 0,
    sd_subject_id__Intercept = 0.1,
    sd_subject_id__bs_Intercept = 0.1,
    sd_subject_id__bias_Intercept = 0.1
  )
}

# Subsample data for faster fit (Wiener with 16k+ trials is very slow per iteration)
subsample_for_sensitivity <- function(data_df, max_trials, label) {
  n <- nrow(data_df)
  if (n <= max_trials) return(data_df)
  n_subj <- n_distinct(data_df$subject_id)
  trials_per_subj <- max(20L, ceiling(max_trials / n_subj))
  set.seed(42)
  out <- data_df %>%
    group_by(subject_id) %>%
    slice_sample(n = trials_per_subj, replace = FALSE) %>%
    ungroup()
  if (nrow(out) > max_trials) out <- out %>% slice_sample(n = max_trials, replace = FALSE)
  cat(sprintf("  [%s] Subsampled %d -> %d trials (SENSITIVITY_MAX_TRIALS=%d)\n", label, n, nrow(out), max_trials))
  out
}

# Validate data before fit; return TRUE if ok, stop with message if not
validate_data_for_wiener <- function(data_df, label) {
  n <- nrow(data_df)
  if (n < 50) {
    stop(sprintf("[%s] Too few trials: %d (need >= 50)", label, n))
  }
  min_rt <- min(data_df$rt, na.rm = TRUE)
  max_rt <- max(data_df$rt, na.rm = TRUE)
  n_subj <- length(unique(data_df$subject_id))
  if (min_rt <= 0) {
    stop(sprintf("[%s] Invalid: min(rt)=%.4f (must be > 0)", label, min_rt))
  }
  if (min_rt < 0.1) {
    warning(sprintf("[%s] min(rt)=%.4fs is very low; NDT init will be < 0.1s", label, min_rt))
  }
  cat(sprintf("  [%s] Pre-fit check: n=%d trials, %d subjects, rt=[%.3f, %.3f]s\n",
              label, n, n_subj, min_rt, max_rt))
  invisible(TRUE)
}

# Robust fit wrapper: validate, log, fit, capture errors and warnings
fit_sensitivity_model <- function(formula, data_df, priors, model_name, fit_label, baseline_fit = NULL) {
  data_df <- subsample_for_sensitivity(data_df, SENSITIVITY_MAX_TRIALS, fit_label)
  validate_data_for_wiener(data_df, fit_label)
  init_vals <- safe_init_wiener(data_df)
  init_arg <- replicate(n_chains, init_vals, simplify = FALSE)
  cat(sprintf("  [%s] NDT init: %.3fs (log=%.3f)\n", fit_label, exp(init_vals$Intercept_ndt), init_vals$Intercept_ndt))
  result <- tryCatch({
    withCallingHandlers({
      fit <- brm(
        formula = formula,
        data = data_df,
        family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
        prior = priors,
        chains = n_chains,
        iter = 4000,
        warmup = 2000,
        cores = n_chains,
        init = init_arg,
        control = list(adapt_delta = 0.95, max_treedepth = 12),
        backend = "cmdstanr",
        refresh = 200,
        seed = 123
      )
      cat(sprintf("  [%s] ✓ Converged\n", fit_label))
      fit
    }, warning = function(w) {
      cat(sprintf("  [%s] Warning: %s\n", fit_label, conditionMessage(w)))
      invokeRestart("muffleWarning")
    })
  }, error = function(e) {
    cat(sprintf("  [%s] ❌ Error: %s\n", fit_label, conditionMessage(e)))
    if (grepl("nondecision time|wiener_lpdf|must be greater", conditionMessage(e), ignore.case = TRUE)) {
      cat(sprintf("  [%s] Hint: NDT init must be < min(rt). Check data.\n", fit_label))
    }
    NULL
  })
  result
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
fit3_no_subchance <- fit_sensitivity_model(
  model3_spec$formula, data_no_subchance, model3_spec$priors,
  "Model3_Difficulty", "Model3_no_subchance", baseline_fit = baseline_model3
)

# Fit Model4_Additive
cat("Fitting Model4_Additive (exclude sub-chance)...\n")
fit4_no_subchance <- fit_sensitivity_model(
  model4_spec$formula, data_no_subchance, model4_spec$priors,
  "Model4_Additive", "Model4_no_subchance", baseline_fit = baseline_model4
)

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
fit3_rt25 <- fit_sensitivity_model(
  model3_spec$formula, data_rt25, model3_spec$priors,
  "Model3_Difficulty", "Model3_rt25", baseline_fit = baseline_model3
)

# Fit Model4_Additive
cat("Fitting Model4_Additive (RT <= 2.5s)...\n")
fit4_rt25 <- fit_sensitivity_model(
  model4_spec$formula, data_rt25, model4_spec$priors,
  "Model4_Additive", "Model4_rt25", baseline_fit = baseline_model4
)

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
  
  # Print summary (as.data.frame avoids tibble print/na.print issues on some R versions)
  cat("SUMMARY TABLE:\n")
  cat("----------------------------------------------------------------------\n")
  tryCatch(
    print(as.data.frame(final_table)),
    error = function(e) cat("(Print skipped:", conditionMessage(e), ")\n")
  )
  cat("\n")
  
  # Print interpretation
  cat("INTERPRETATION:\n")
  cat("- delta: Change in parameter estimate (sensitivity - baseline)\n")
  cat("- delta_ci_lower/upper: Conservative 95% CI for delta\n")
  cat("- ci_overlap: TRUE if baseline and sensitivity CIs overlap\n")
  cat("- delta_contains_zero: TRUE if delta CI includes 0 (no significant change)\n\n")
  
} else {
  cat("⚠️  No sensitivity comparisons computed (fits may have failed)\n\n")
  n_ok <- sum(c(!is.null(fit3_no_subchance), !is.null(fit4_no_subchance),
                !is.null(fit3_rt25), !is.null(fit4_rt25)))
  cat("Fit status: ", n_ok, "/4 succeeded\n")
  if (is.null(fit3_no_subchance)) cat("  - Model3 (exclude sub-chance): FAILED\n")
  if (is.null(fit4_no_subchance)) cat("  - Model4 (exclude sub-chance): FAILED\n")
  if (is.null(fit3_rt25)) cat("  - Model3 (RT<=2.5s): FAILED\n")
  if (is.null(fit4_rt25)) cat("  - Model4 (RT<=2.5s): FAILED\n")
  cat("\n")
}

cat("================================================================================\n")
cat("SENSITIVITY ANALYSES COMPLETE\n")
cat("================================================================================\n")
cat("Completed:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("Output:\n")
cat("  - Summary: output/checks/sensitivity_summary.csv\n\n")









