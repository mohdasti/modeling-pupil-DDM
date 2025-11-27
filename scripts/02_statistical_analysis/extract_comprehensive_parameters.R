#!/usr/bin/env Rscript
# =========================================================================
# COMPREHENSIVE PARAMETER EXTRACTION AND STATISTICAL ANALYSIS
# =========================================================================
# Extracts all parameter estimates, contrasts, and effect sizes from
# Standard-only bias model and Primary model for manuscript tables and figures
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(dplyr)
  library(readr)
  library(posterior)
  library(tidyr)
  library(tibble)
  library(stringr)
})

# =========================================================================
# CONFIGURATION
# =========================================================================

OUTPUT_DIR <- "output/publish"
RESULTS_DIR <- "output/results"
LOG_DIR <- "logs"
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(RESULTS_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)

LOG_FILE <- file.path(LOG_DIR, sprintf("parameter_extraction_%s.log", 
                                        format(Sys.time(), "%Y%m%d_%H%M%S")))

MODEL_STD_BIAS <- "output/models/standard_bias_only.rds"
MODEL_PRIMARY <- "output/models/primary_vza.rds"

# Helper functions
log_msg <- function(..., level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  prefix <- switch(level, "INFO" = "[INFO]", "WARN" = "[WARN]", "ERROR" = "[ERROR]")
  msg <- paste(..., collapse = " ")
  cat(sprintf("[%s] %s %s\n", timestamp, prefix, msg))
  cat(sprintf("[%s] %s %s\n", timestamp, prefix, msg), file = LOG_FILE, append = TRUE)
}

inv_logit <- function(x) 1 / (1 + exp(-x))
logit <- function(p) log(p / (1 - p))

# Helper: NULL coalescing operator
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

# =========================================================================
# START LOGGING
# =========================================================================

log_msg("=", strrep("=", 78))
log_msg("COMPREHENSIVE PARAMETER EXTRACTION AND STATISTICAL ANALYSIS")
log_msg("=", strrep("=", 78))
log_msg("")
log_msg("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log_msg("Working directory:", getwd())
log_msg("Log file:", LOG_FILE)
log_msg("")

# =========================================================================
# PART 1: STANDARD-ONLY BIAS MODEL - BIAS LEVELS AND CONTRASTS
# =========================================================================

log_msg("=", strrep("=", 78))
log_msg("PART 1: STANDARD-ONLY BIAS MODEL")
log_msg("=", strrep("=", 78))
log_msg("")

if (!file.exists(MODEL_STD_BIAS)) {
  log_msg("ERROR: Standard-only bias model not found:", MODEL_STD_BIAS, level = "ERROR")
  stop("Model file not found")
}

fit_std <- readRDS(MODEL_STD_BIAS)
log_msg("  ✓ Loaded Standard-only bias model")

# Extract posterior samples
post_std <- as_draws_df(fit_std)

# Extract bias parameters (logit scale)
bias_intercept <- post_std$b_bias_Intercept
bias_task_vdt <- post_std$`b_bias_taskVDT`
bias_effort_high <- post_std$`b_bias_effort_conditionHigh_40_MVC`

log_msg("  Extracted bias parameters:")
log_msg(sprintf("    Intercept (logit): mean = %.3f", mean(bias_intercept)))
log_msg(sprintf("    Task VDT effect (logit): mean = %.3f", mean(bias_task_vdt)))
log_msg(sprintf("    Effort High effect (logit): mean = %.3f", mean(bias_effort_high)))

# Compute bias levels for each condition (on probability scale)
compute_bias_level <- function(intercept, task_eff = 0, effort_eff = 0, logit_samples = TRUE) {
  if (logit_samples) {
    logit_vals <- intercept + task_eff + effort_eff
    prob_vals <- inv_logit(logit_vals)
    return(list(logit = logit_vals, prob = prob_vals))
  } else {
    return(list(logit = intercept + task_eff + effort_eff, prob = inv_logit(intercept + task_eff + effort_eff)))
  }
}

# ADT, Low effort (baseline)
bias_ADT_Low <- compute_bias_level(bias_intercept, 0, 0)

# ADT, High effort
bias_ADT_High <- compute_bias_level(bias_intercept, 0, bias_effort_high)

# VDT, Low effort
bias_VDT_Low <- compute_bias_level(bias_intercept, bias_task_vdt, 0)

# VDT, High effort
bias_VDT_High <- compute_bias_level(bias_intercept, bias_task_vdt, bias_effort_high)

# Create summary function
summarize_samples <- function(samples, param_name, scale_type) {
  tibble(
    param = param_name,
    scale = scale_type,
    mean = mean(samples),
    sd = sd(samples),
    q2.5 = quantile(samples, 0.025),
    q97.5 = quantile(samples, 0.975),
    median = median(samples)
  )
}

# Create bias levels table
bias_levels_table <- bind_rows(
  summarize_samples(bias_ADT_Low$logit, "bias_ADT_Low", "logit"),
  summarize_samples(bias_ADT_Low$prob, "bias_ADT_Low", "prob"),
  summarize_samples(bias_ADT_High$logit, "bias_ADT_High", "logit"),
  summarize_samples(bias_ADT_High$prob, "bias_ADT_High", "prob"),
  summarize_samples(bias_VDT_Low$logit, "bias_VDT_Low", "logit"),
  summarize_samples(bias_VDT_Low$prob, "bias_VDT_Low", "prob"),
  summarize_samples(bias_VDT_High$logit, "bias_VDT_High", "logit"),
  summarize_samples(bias_VDT_High$prob, "bias_VDT_High", "prob")
)

# Save bias levels
bias_levels_file <- file.path(OUTPUT_DIR, "bias_standard_only_levels.csv")
write_csv(bias_levels_table, bias_levels_file)
log_msg("  ✓ Saved bias levels:", bias_levels_file)

# Compute contrasts
task_contrast <- bias_task_vdt  # VDT - ADT
effort_contrast <- bias_effort_high  # High - Low

bias_contrasts_table <- bind_rows(
  tibble(
    contrast = "VDT - ADT (bias, logit)",
    mean = mean(task_contrast),
    sd = sd(task_contrast),
    q2.5 = quantile(task_contrast, 0.025),
    q97.5 = quantile(task_contrast, 0.975),
    Pr_gt_0 = mean(task_contrast > 0),
    Pr_lt_0 = mean(task_contrast < 0),
    Pr_rope = mean(abs(task_contrast) < 0.05)  # ROPE for bias on logit scale
  ),
  tibble(
    contrast = "High - Low (bias, logit)",
    mean = mean(effort_contrast),
    sd = sd(effort_contrast),
    q2.5 = quantile(effort_contrast, 0.025),
    q97.5 = quantile(effort_contrast, 0.975),
    Pr_gt_0 = mean(effort_contrast > 0),
    Pr_lt_0 = mean(effort_contrast < 0),
    Pr_rope = mean(abs(effort_contrast) < 0.05)
  )
)

# Save bias contrasts
bias_contrasts_file <- file.path(OUTPUT_DIR, "bias_standard_only_contrasts.csv")
write_csv(bias_contrasts_table, bias_contrasts_file)
log_msg("  ✓ Saved bias contrasts:", bias_contrasts_file)

log_msg("")
log_msg("  Bias Summary:")
log_msg(sprintf("    ADT Low: z = %.3f (prob)", mean(bias_ADT_Low$prob)))
log_msg(sprintf("    VDT Low: z = %.3f (prob)", mean(bias_VDT_Low$prob)))
log_msg(sprintf("    Task contrast (VDT-ADT): Δ = %.3f, P(Δ>0) = %.3f", 
                mean(task_contrast), mean(task_contrast > 0)))

# =========================================================================
# PART 2: PRIMARY MODEL - FIXED EFFECTS
# =========================================================================

log_msg("")
log_msg("=", strrep("=", 78))
log_msg("PART 2: PRIMARY MODEL - FIXED EFFECTS")
log_msg("=", strrep("=", 78))
log_msg("")

if (!file.exists(MODEL_PRIMARY)) {
  log_msg("ERROR: Primary model not found:", MODEL_PRIMARY, level = "ERROR")
  stop("Model file not found")
}

fit_primary <- readRDS(MODEL_PRIMARY)
log_msg("  ✓ Loaded Primary model")

# Extract fixed effects
fixef_summary <- fixef(fit_primary, summary = TRUE)
summary_primary <- summary(fit_primary)

# Create comprehensive fixed effects table
# CRITICAL: ADT and VDT are separate perceptual tasks, not conditions to contrast
# We need to compute separate intercepts for ADT and VDT for each parameter

# Extract posterior samples to compute task-specific intercepts
post_primary <- as_draws_df(fit_primary)

# Create base fixed effects table
fx_table <- as.data.frame(fixef_summary) %>%
  rownames_to_column("parameter") %>%
  transmute(
    parameter = parameter,
    estimate = Estimate,
    conf.low = `Q2.5`,
    conf.high = `Q97.5`,
    est.error = `Est.Error`,
    rhat = NA_real_,
    ess = NA_real_
  )

# Add Rhat and ESS from summary
if (!is.null(summary_primary$fixed)) {
  fx_table <- fx_table %>%
    mutate(
      rhat = summary_primary$fixed$Rhat[match(parameter, rownames(summary_primary$fixed))],
      ess = summary_primary$fixed$Bulk_ESS[match(parameter, rownames(summary_primary$fixed))]
    )
}

# Compute task-specific intercepts and replace task effects with separate task rows
# ADT and VDT are separate perceptual tasks, not conditions to contrast
fx_table_expanded <- fx_table
task_effect_rows <- which(grepl("^taskVDT$|^bs_taskVDT$|^ndt_taskVDT$|^bias_taskVDT$", fx_table$parameter))

if (length(task_effect_rows) > 0) {
  log_msg("  Computing task-specific intercepts for ADT and VDT...")
  
  # Collect new rows to add and rows to remove
  rows_to_add <- list()
  rows_to_remove <- integer()
  
  # Process each parameter type that has task effects
  for (row_idx in task_effect_rows) {
    param_row <- fx_table[row_idx, ]
    param_name <- param_row$parameter
    
    # Determine parameter type
    if (param_name == "taskVDT") {
      param_type <- "drift"
      intercept_col <- "Intercept"
      task_effect_col <- "b_taskVDT"
      param_label_prefix <- "Drift (v)"
    } else if (param_name == "bs_taskVDT") {
      param_type <- "boundary"
      intercept_col <- "bs_Intercept"
      task_effect_col <- "b_bs_taskVDT"
      param_label_prefix <- "Boundary (a)"
    } else if (param_name == "ndt_taskVDT") {
      param_type <- "ndt"
      intercept_col <- "ndt_Intercept"
      task_effect_col <- "b_ndt_taskVDT"
      param_label_prefix <- "Non-decision time (t₀)"
    } else if (param_name == "bias_taskVDT") {
      param_type <- "bias"
      intercept_col <- "bias_Intercept"
      task_effect_col <- "b_bias_taskVDT"
      param_label_prefix <- "Bias (z)"
    } else {
      next
    }
    
    # Extract intercept and task effect columns from posterior
    intercept_samples <- NULL
    task_effect_samples <- NULL
    
    # Find intercept column
    intercept_cols <- grep(paste0("^", intercept_col, "$|^b_", intercept_col, "$"), 
                          colnames(post_primary), value = TRUE)
    if (length(intercept_cols) > 0) {
      intercept_samples <- post_primary[[intercept_cols[1]]]
    }
    
    # Find task effect column
    task_cols <- grep(paste0("^", task_effect_col, "$"), colnames(post_primary), value = TRUE)
    if (length(task_cols) > 0) {
      task_effect_samples <- post_primary[[task_cols[1]]]
    }
    
    if (!is.null(intercept_samples) && !is.null(task_effect_samples)) {
      # ADT intercept = Intercept (reference level)
      adt_samples <- intercept_samples
      
      # VDT intercept = Intercept + taskVDT
      vdt_samples <- intercept_samples + task_effect_samples
      
      # Compute statistics for ADT
      adt_row <- tibble(
        parameter = paste0(param_label_prefix, ": ADT"),
        estimate = mean(adt_samples),
        conf.low = quantile(adt_samples, 0.025),
        conf.high = quantile(adt_samples, 0.975),
        est.error = sd(adt_samples),
        rhat = param_row$rhat,
        ess = param_row$ess
      )
      
      # Compute statistics for VDT
      vdt_row <- tibble(
        parameter = paste0(param_label_prefix, ": VDT"),
        estimate = mean(vdt_samples),
        conf.low = quantile(vdt_samples, 0.025),
        conf.high = quantile(vdt_samples, 0.975),
        est.error = sd(vdt_samples),
        rhat = param_row$rhat,
        ess = param_row$ess
      )
      
      # Mark row for removal and add new rows
      rows_to_remove <- c(rows_to_remove, row_idx)
      rows_to_add[[length(rows_to_add) + 1]] <- adt_row
      rows_to_add[[length(rows_to_add) + 1]] <- vdt_row
      
      log_msg(sprintf("    Replaced %s with ADT and VDT intercepts", param_name))
    }
  }
  
  # Remove task effect rows and add task-specific rows
  if (length(rows_to_remove) > 0 && length(rows_to_add) > 0) {
    fx_table_expanded <- fx_table_expanded[-rows_to_remove, ]
    fx_table_expanded <- bind_rows(fx_table_expanded, bind_rows(rows_to_add)) %>%
      arrange(parameter)
    fx_table <- fx_table_expanded
  }
}

# Save fixed effects
fx_table_file <- file.path(OUTPUT_DIR, "table_fixed_effects.csv")
write_csv(fx_table, fx_table_file)
log_msg("  ✓ Saved fixed effects:", fx_table_file)
log_msg(sprintf("    Total parameters: %d", nrow(fx_table)))

# =========================================================================
# PART 3: PRIMARY MODEL - EFFECT CONTRASTS
# =========================================================================

log_msg("")
log_msg("=", strrep("=", 78))
log_msg("PART 3: PRIMARY MODEL - EFFECT CONTRASTS")
log_msg("=", strrep("=", 78))
log_msg("")

# Extract posterior samples
post_primary <- as_draws_df(fit_primary)

# Helper function to compute contrast summaries
compute_contrast_summary <- function(samples, contrast_name, param_type, rope_threshold = 0.02) {
  tibble(
    contrast = contrast_name,
    parameter = param_type,
    mean = mean(samples),
    sd = sd(samples),
    q05 = quantile(samples, 0.05),
    q95 = quantile(samples, 0.95),
    q2.5 = quantile(samples, 0.025),
    q97.5 = quantile(samples, 0.975),
    p_gt0 = mean(samples > 0),
    p_lt0 = mean(samples < 0),
    p_in_rope = mean(abs(samples) < rope_threshold),
    credible = ifelse(quantile(samples, 0.025) > 0 || quantile(samples, 0.975) < 0, 
                     "credible", "not_credible")
  )
}

contrast_list <- list()

# --- Drift Rate (v) Contrasts ---
log_msg("  Computing drift rate (v) contrasts...")

# Standard is reference (Intercept)
# Note: b_Intercept is the correct column for brms main formula intercept
std_intercept_col <- if ("b_Intercept" %in% colnames(post_primary)) {
  "b_Intercept"
} else if ("Intercept" %in% colnames(post_primary)) {
  "Intercept"
} else {
  NULL
}

if (!is.null(std_intercept_col)) {
  # Difficulty contrasts
  if ("b_difficulty_levelHard" %in% colnames(post_primary)) {
    hard_v <- post_primary[[std_intercept_col]] + post_primary$b_difficulty_levelHard
    contrast_list[[length(contrast_list) + 1]] <- compute_contrast_summary(
      post_primary$b_difficulty_levelHard,
      "Hard - Standard",
      "v",
      rope_threshold = 0.02
    )
    contrast_list[[length(contrast_list) + 1]] <- compute_contrast_summary(
      hard_v,
      "Hard (absolute)",
      "v",
      rope_threshold = 0.02
    )
  }
  
  if ("b_difficulty_levelEasy" %in% colnames(post_primary)) {
    easy_v <- post_primary[[std_intercept_col]] + post_primary$b_difficulty_levelEasy
    contrast_list[[length(contrast_list) + 1]] <- compute_contrast_summary(
      post_primary$b_difficulty_levelEasy,
      "Easy - Standard",
      "v",
      rope_threshold = 0.02
    )
    contrast_list[[length(contrast_list) + 1]] <- compute_contrast_summary(
      easy_v,
      "Easy (absolute)",
      "v",
      rope_threshold = 0.02
    )
    
    # Easy - Hard contrast
    if ("b_difficulty_levelHard" %in% colnames(post_primary)) {
      easy_minus_hard <- post_primary$b_difficulty_levelEasy - post_primary$b_difficulty_levelHard
      contrast_list[[length(contrast_list) + 1]] <- compute_contrast_summary(
        easy_minus_hard,
        "Easy - Hard",
        "v",
        rope_threshold = 0.02
      )
    }
  }
  
  # NOTE: Task differences (ADT vs VDT) are NOT experimental contrasts.
  # ADT and VDT are separate perceptual tasks with their own parameter estimates.
  # Task-specific intercepts are now presented separately in the Fixed Effects table.
  # If needed for descriptive purposes, task differences can be computed from task-specific intercepts.
  
  # Effort contrast
  effort_col <- "b_effort_conditionHigh_40_MVC"
  if (effort_col %in% colnames(post_primary)) {
    contrast_list[[length(contrast_list) + 1]] <- compute_contrast_summary(
      post_primary[[effort_col]],
      "High - Low",
      "v",
      rope_threshold = 0.02
    )
  }
}

# --- Boundary Separation (a/bs) Contrasts ---
log_msg("  Computing boundary separation (a) contrasts...")

bs_cols <- colnames(post_primary)[grepl("^b_bs_|^bs_", colnames(post_primary))]
if (length(bs_cols) > 0) {
  for (col in bs_cols) {
    term_name <- gsub("^b_bs_|^bs_", "", col)
    # Skip task effects - they are presented as separate task intercepts in Fixed Effects table
    if (term_name != "Intercept" && !grepl("^taskVDT$", term_name)) {
      contrast_list[[length(contrast_list) + 1]] <- compute_contrast_summary(
        post_primary[[col]],
        term_name,
        "bs",
        rope_threshold = 0.05  # ROPE for boundary on log scale
      )
    }
  }
}

# --- Non-Decision Time (t₀/ndt) Contrasts ---
log_msg("  Computing non-decision time (t₀) contrasts...")

ndt_cols <- colnames(post_primary)[grepl("^b_ndt_|^ndt_", colnames(post_primary))]
if (length(ndt_cols) > 0) {
  for (col in ndt_cols) {
    term_name <- gsub("^b_ndt_|^ndt_", "", col)
    # Skip task effects - they are presented as separate task intercepts in Fixed Effects table
    if (term_name != "Intercept" && !grepl("^taskVDT$", term_name)) {
      contrast_list[[length(contrast_list) + 1]] <- compute_contrast_summary(
        post_primary[[col]],
        term_name,
        "ndt",
        rope_threshold = 0.05  # ROPE for NDT on log scale
      )
    }
  }
}

# --- Starting-Point Bias (z) Contrasts ---
log_msg("  Computing bias (z) contrasts...")

bias_cols <- colnames(post_primary)[grepl("^b_bias_|^bias_", colnames(post_primary))]
if (length(bias_cols) > 0) {
  for (col in bias_cols) {
    term_name <- gsub("^b_bias_|^bias_", "", col)
    # Skip task effects - they are presented as separate task intercepts in Fixed Effects table
    if (term_name != "Intercept" && !grepl("^taskVDT$", term_name)) {
      contrast_list[[length(contrast_list) + 1]] <- compute_contrast_summary(
        post_primary[[col]],
        term_name,
        "bias",
        rope_threshold = 0.05  # ROPE for bias on logit scale
      )
    }
  }
}

# Combine all contrasts
if (length(contrast_list) > 0) {
  contrasts_table <- bind_rows(contrast_list) %>%
    arrange(parameter, contrast)
  
  # Save contrasts
  contrasts_file <- file.path(OUTPUT_DIR, "table_effect_contrasts.csv")
  write_csv(contrasts_table, contrasts_file)
  log_msg("  ✓ Saved effect contrasts:", contrasts_file)
  log_msg(sprintf("    Total contrasts: %d", nrow(contrasts_table)))
  log_msg(sprintf("    By parameter: v=%d, bs=%d, ndt=%d, bias=%d",
                  sum(contrasts_table$parameter == "v"),
                  sum(contrasts_table$parameter == "bs"),
                  sum(contrasts_table$parameter == "ndt"),
                  sum(contrasts_table$parameter == "bias")))
} else {
  log_msg("  ⚠️  No contrasts extracted (check column names)", level = "WARN")
}

# =========================================================================
# PART 4: PRIMARY MODEL - PARAMETER SUMMARIES BY CONDITION
# =========================================================================

log_msg("")
log_msg("=", strrep("=", 78))
log_msg("PART 4: PRIMARY MODEL - CONDITION-SPECIFIC PARAMETER ESTIMATES")
log_msg("=", strrep("=", 78))
log_msg("")

# Extract intercepts for each parameter
# Note: b_Intercept is the correct column for brms main formula intercept
# Intercept (without b_) may be from a different source or transformation
v_intercept <- if ("b_Intercept" %in% colnames(post_primary)) {
  post_primary$b_Intercept
} else if ("Intercept" %in% colnames(post_primary)) {
  post_primary$Intercept
} else {
  NULL
}

# Extract intercepts safely
bs_intercept_col <- grep("^b_bs_Intercept|^bs_Intercept", colnames(post_primary), value = TRUE)
bs_intercept <- if (length(bs_intercept_col) > 0) post_primary[[bs_intercept_col[1]]] else NULL

ndt_intercept_col <- grep("^b_ndt_Intercept|^ndt_Intercept", colnames(post_primary), value = TRUE)
ndt_intercept <- if (length(ndt_intercept_col) > 0) post_primary[[ndt_intercept_col[1]]] else NULL

bias_intercept_col <- grep("^b_bias_Intercept|^bias_Intercept", colnames(post_primary), value = TRUE)
bias_intercept_primary <- if (length(bias_intercept_col) > 0) post_primary[[bias_intercept_col[1]]] else NULL

# Compute condition-specific parameters
condition_params <- list()

# Standard trials (reference)
if (!is.null(v_intercept) && !is.null(bs_intercept) && !is.null(ndt_intercept) && !is.null(bias_intercept_primary)) {
  condition_params[["Standard"]] <- list(
    v_mean = mean(v_intercept),
    v_ci_lower = quantile(v_intercept, 0.025),
    v_ci_upper = quantile(v_intercept, 0.975),
    # Transform each draw first, then compute statistics (preserves correlation structure)
    a_mean = mean(exp(bs_intercept)),
    a_ci_lower = quantile(exp(bs_intercept), 0.025),
    a_ci_upper = quantile(exp(bs_intercept), 0.975),
    t0_mean = mean(exp(ndt_intercept)),
    t0_ci_lower = quantile(exp(ndt_intercept), 0.025),
    t0_ci_upper = quantile(exp(ndt_intercept), 0.975),
    z_mean = mean(inv_logit(bias_intercept_primary)),
    z_ci_lower = quantile(inv_logit(bias_intercept_primary), 0.025),
    z_ci_upper = quantile(inv_logit(bias_intercept_primary), 0.975)
  )
}

# Hard trials
if ("b_difficulty_levelHard" %in% colnames(post_primary) && !is.null(v_intercept) && 
    !is.null(bs_intercept) && !is.null(bias_intercept_primary) && 
    length(condition_params) > 0 && "Standard" %in% names(condition_params)) {
  hard_v <- v_intercept + post_primary$b_difficulty_levelHard
  
  hard_bs_col <- grep("^b_bs_difficulty_levelHard|^bs_difficulty_levelHard", colnames(post_primary), value = TRUE)
  hard_bs <- if (length(hard_bs_col) > 0) {
    bs_intercept + post_primary[[hard_bs_col[1]]]
  } else {
    bs_intercept
  }
  
  hard_bias_col <- grep("^b_bias_difficulty_levelHard|^bias_difficulty_levelHard", colnames(post_primary), value = TRUE)
  hard_bias <- if (length(hard_bias_col) > 0) {
    bias_intercept_primary + post_primary[[hard_bias_col[1]]]
  } else {
    bias_intercept_primary
  }
  
  condition_params[["Hard"]] <- list(
    v_mean = mean(hard_v),
    v_ci_lower = quantile(hard_v, 0.025),
    v_ci_upper = quantile(hard_v, 0.975),
    # Transform each draw first, then compute statistics
    a_mean = mean(exp(hard_bs)),
    a_ci_lower = quantile(exp(hard_bs), 0.025),
    a_ci_upper = quantile(exp(hard_bs), 0.975),
    t0_mean = condition_params[["Standard"]]$t0_mean,  # NDT same across difficulty
    t0_ci_lower = condition_params[["Standard"]]$t0_ci_lower,
    t0_ci_upper = condition_params[["Standard"]]$t0_ci_upper,
    # Transform each draw on logit scale first, then compute statistics
    z_mean = mean(inv_logit(hard_bias)),
    z_ci_lower = quantile(inv_logit(hard_bias), 0.025),
    z_ci_upper = quantile(inv_logit(hard_bias), 0.975)
  )
}

# Easy trials
if ("b_difficulty_levelEasy" %in% colnames(post_primary) && !is.null(v_intercept) &&
    !is.null(bs_intercept) && !is.null(bias_intercept_primary) && 
    length(condition_params) > 0 && "Standard" %in% names(condition_params)) {
  easy_v <- v_intercept + post_primary$b_difficulty_levelEasy
  
  easy_bs_col <- grep("^b_bs_difficulty_levelEasy|^bs_difficulty_levelEasy", colnames(post_primary), value = TRUE)
  easy_bs <- if (length(easy_bs_col) > 0) {
    bs_intercept + post_primary[[easy_bs_col[1]]]
  } else {
    bs_intercept
  }
  
  easy_bias_col <- grep("^b_bias_difficulty_levelEasy|^bias_difficulty_levelEasy", colnames(post_primary), value = TRUE)
  easy_bias <- if (length(easy_bias_col) > 0) {
    bias_intercept_primary + post_primary[[easy_bias_col[1]]]
  } else {
    bias_intercept_primary
  }
  
  condition_params[["Easy"]] <- list(
    v_mean = mean(easy_v),
    v_ci_lower = quantile(easy_v, 0.025),
    v_ci_upper = quantile(easy_v, 0.975),
    # Transform each draw on log/logit scale first, then compute statistics
    a_mean = mean(exp(easy_bs)),
    a_ci_lower = quantile(exp(easy_bs), 0.025),
    a_ci_upper = quantile(exp(easy_bs), 0.975),
    t0_mean = condition_params[["Standard"]]$t0_mean,
    t0_ci_lower = condition_params[["Standard"]]$t0_ci_lower,
    t0_ci_upper = condition_params[["Standard"]]$t0_ci_upper,
    # Transform each draw on logit scale first, then compute statistics
    z_mean = mean(inv_logit(easy_bias)),
    z_ci_lower = quantile(inv_logit(easy_bias), 0.025),
    z_ci_upper = quantile(inv_logit(easy_bias), 0.975)
  )
}

# Create condition summary table
if (length(condition_params) > 0) {
  condition_summary <- bind_rows(
    lapply(names(condition_params), function(cond) {
      params <- condition_params[[cond]]
      bind_rows(
        tibble(condition = cond, parameter = "v", mean = params$v_mean,
               ci_lower = params$v_ci_lower, ci_upper = params$v_ci_upper),
        tibble(condition = cond, parameter = "a", mean = params$a_mean,
               ci_lower = params$a_ci_lower, ci_upper = params$a_ci_upper),
        tibble(condition = cond, parameter = "t0", mean = params$t0_mean,
               ci_lower = params$t0_ci_lower, ci_upper = params$t0_ci_upper),
        tibble(condition = cond, parameter = "z", mean = params$z_mean,
               ci_lower = params$z_ci_lower, ci_upper = params$z_ci_upper)
      )
    })
  )
  
  condition_summary_file <- file.path(RESULTS_DIR, "parameter_summary_by_condition.csv")
  write_csv(condition_summary, condition_summary_file)
  log_msg("  ✓ Saved condition summary:", condition_summary_file)
}

# =========================================================================
# PART 5: STATISTICAL TESTS USING HYPOTHESIS FUNCTION
# =========================================================================

log_msg("")
log_msg("=", strrep("=", 78))
log_msg("PART 5: STATISTICAL HYPOTHESIS TESTS")
log_msg("=", strrep("=", 78))
log_msg("")

# Define key hypotheses to test
hypotheses_to_test <- list()

# Primary model hypotheses
if (!is.null(fit_primary)) {
  log_msg("  Testing primary model hypotheses...")
  
  # Note: hypothesis() in brms uses the parameter names from the model summary
  # For main formula (drift), use names without b_ prefix
  # For dpar parameters, brms handles them differently
  
  # Difficulty effects on drift - brms hypothesis() uses term names without b_ prefix
  hypotheses_to_test[["v_Easy_vs_Standard"]] <- "difficulty_levelEasy = 0"
  hypotheses_to_test[["v_Hard_vs_Standard"]] <- "difficulty_levelHard = 0"
  
  # NOTE: Task differences (ADT vs VDT) are NOT experimental contrasts.
  # ADT and VDT are separate perceptual tasks with their own parameter estimates.
  # Task-specific intercepts are presented separately in the Fixed Effects table.
  # We do not test task differences as hypotheses.
  
  # Effort effect on drift
  hypotheses_to_test[["v_High_vs_Low"]] <- "effort_conditionHigh_40_MVC = 0"
  
  # Boundary separation effects - need to specify dpar
  hypotheses_to_test[["a_Easy_vs_Standard"]] <- "bs_difficulty_levelEasy = 0"
  hypotheses_to_test[["a_Hard_vs_Standard"]] <- "bs_difficulty_levelHard = 0"
  
  # Bias effects - need to specify dpar
  # NOTE: Task differences in bias are NOT tested as hypotheses (see note above)
  hypotheses_to_test[["z_Easy_vs_Standard"]] <- "bias_difficulty_levelEasy = 0"
  
  # Test hypotheses
  hypothesis_results <- list()
  
  for (hyp_name in names(hypotheses_to_test)) {
    hyp_formula <- hypotheses_to_test[[hyp_name]]
    
    # Use the formula directly - it already contains the full parameter name with b_ prefix
    # brms hypothesis() expects "parameter = 0" format
    tryCatch({
      hyp_result <- hypothesis(fit_primary, hyp_formula)
      
      # Extract results from hypothesis output
      hyp_df <- hyp_result$hypothesis
      
      hypothesis_results[[hyp_name]] <- tibble(
        hypothesis = hyp_name,
        formula = hyp_formula,
        estimate = hyp_df$Estimate,
        ci_lower = hyp_df$`CI.Lower`,
        ci_upper = hyp_df$`CI.Upper`,
        probability_direction = if ("P(H1 > 0)" %in% names(hyp_df)) {
          hyp_df$`P(H1 > 0)`
        } else if ("Evid.Ratio" %in% names(hyp_df)) {
          # Convert evidence ratio to probability
          hyp_df$`Evid.Ratio` / (1 + hyp_df$`Evid.Ratio`)
        } else {
          NA_real_
        },
        evidence_ratio = if ("Evid.Ratio" %in% names(hyp_df)) {
          hyp_df$`Evid.Ratio`
        } else {
          NA_real_
        },
        star = if ("Star" %in% names(hyp_df)) hyp_df$Star else ""
      )
      
      pd <- hypothesis_results[[hyp_name]]$probability_direction
      log_msg(sprintf("    ✓ %s: est=%.3f, CI=[%.3f, %.3f], P(>0)=%.3f",
                      hyp_name,
                      hyp_df$Estimate,
                      hyp_df$`CI.Lower`,
                      hyp_df$`CI.Upper`,
                      pd))
    }, error = function(e) {
      log_msg(sprintf("    ⚠️  Failed to test %s: %s", hyp_name, e$message), level = "WARN")
    })
  }
  
  if (length(hypothesis_results) > 0) {
    hypothesis_table <- bind_rows(hypothesis_results)
    hypothesis_file <- file.path(RESULTS_DIR, "statistical_hypothesis_tests.csv")
    write_csv(hypothesis_table, hypothesis_file)
    log_msg("  ✓ Saved hypothesis test results:", hypothesis_file)
  }
}

# =========================================================================
# PART 6: EFFECT SIZE REPORTING
# =========================================================================

log_msg("")
log_msg("=", strrep("=", 78))
log_msg("PART 6: EFFECT SIZE REPORTING")
log_msg("=", strrep("=", 78))
log_msg("")

# Note: For DDM, drift rate differences ARE the effect sizes (signal-to-noise ratio)
# We report raw mean differences and probability of direction, not Cohen's d
# For log/logit-linked parameters, effects are on link scales

if (length(contrast_list) > 0 && exists("contrasts_table")) {
  effect_sizes_table <- contrasts_table %>%
    mutate(
      # Raw mean difference is the effect size for DDM
      # For drift (v), the difference represents standardized signal-to-noise ratio
      effect_size_mean = mean,
      # Evidence ratio (z-score-like statistic) for reference only
      evidence_ratio_stat = mean / sd,
      # Probability of direction (pd) - percentage of posterior > 0
      probability_direction = ifelse(p_gt0 > 0.5, p_gt0, p_lt0),
      # Effect magnitude interpretation (for drift rate only)
      effect_magnitude = case_when(
        parameter == "v" & abs(mean) < 0.2 ~ "negligible",
        parameter == "v" & abs(mean) < 0.5 ~ "small",
        parameter == "v" & abs(mean) < 1.0 ~ "medium",
        parameter == "v" & abs(mean) >= 1.0 ~ "large",
        TRUE ~ NA_character_  # For log/logit parameters, raw differences don't map to standard effect sizes
      )
    ) %>%
    select(contrast, parameter, effect_size_mean, sd, q2.5, q97.5, 
           probability_direction, evidence_ratio_stat, effect_magnitude, 
           p_gt0, p_lt0, p_in_rope, credible)
  
  effect_sizes_file <- file.path(RESULTS_DIR, "effect_sizes.csv")
  write_csv(effect_sizes_table, effect_sizes_file)
  log_msg("  ✓ Saved effect sizes:", effect_sizes_file)
  log_msg("    Note: Raw mean differences are reported as effect sizes")
  log_msg("    For drift rate (v), differences represent signal-to-noise ratios")
  if (sum(!is.na(effect_sizes_table$effect_magnitude)) > 0) {
    log_msg(sprintf("    Large drift effects (|v| ≥ 1.0): %d", 
                    sum(effect_sizes_table$effect_magnitude == "large", na.rm = TRUE)))
  }
}

# =========================================================================
# SUMMARY
# =========================================================================

log_msg("")
log_msg("=", strrep("=", 78))
log_msg("PARAMETER EXTRACTION COMPLETE")
log_msg("=", strrep("=", 78))
log_msg("")

log_msg("Files generated in output/publish/:")
log_msg("  1. bias_standard_only_levels.csv")
log_msg("  2. bias_standard_only_contrasts.csv")
log_msg("  3. table_fixed_effects.csv")
log_msg("  4. table_effect_contrasts.csv")

log_msg("")
log_msg("Files generated in output/results/:")
log_msg("  5. parameter_summary_by_condition.csv")
log_msg("  6. statistical_hypothesis_tests.csv (if hypothesis tests succeeded)")
log_msg("  7. effect_sizes.csv (raw mean differences as effect sizes)")

log_msg("")
log_msg("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log_msg("=", strrep("=", 78))

