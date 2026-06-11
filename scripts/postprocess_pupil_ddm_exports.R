#!/usr/bin/env Rscript
# ==============================================================================
# Postprocess Pupil-DDM Exports
# ==============================================================================
# Purpose: Extract LOO comparisons, fixef, predictions, and figures from
#          fitted pupil-DDM models for QMD integration.
#
# Inputs:  output/ddm_pupil/models/*.rds (or output/pupil_ddm/models/*.rds)
# Outputs: Tables (CSV) and Figures (PNG) in output/pupil_ddm/
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(brms)
  library(posterior)
  library(loo)
  library(digest)
})

# Load logging and validation utilities
source("R/utils/logging_validation.R")

# ==============================================================================
# A) Setup
# ==============================================================================

log_step("Starting pupil-DDM postprocessing...")

# ==============================================================================
# B) Locate models
# ==============================================================================

PUPIL_MODEL_DIR <- "output/ddm_pupil/models"

# Try primary location first
if (!dir.exists(PUPIL_MODEL_DIR)) {
  # Try alternative location
  PUPIL_MODEL_DIR <- "output/pupil_ddm/models"
  
  # If still not found, search recursively
  if (!dir.exists(PUPIL_MODEL_DIR)) {
    log_step("Primary model directory not found, searching recursively...")
    model_files <- list.files("output", pattern = "pupil.*\\.rds$", 
                               recursive = TRUE, full.names = TRUE)
    
    if (length(model_files) > 0) {
      # Use directory of first found file
      PUPIL_MODEL_DIR <- dirname(model_files[1])
      log_step(paste("Found models in:", PUPIL_MODEL_DIR))
    } else {
      stop("No pupil model files found. Searched recursively under output/ for *pupil*.rds")
    }
  }
}

# List model files
model_files <- list.files(PUPIL_MODEL_DIR, pattern = "\\.rds$", full.names = TRUE)

if (length(model_files) == 0) {
  stop("No .rds files found in ", PUPIL_MODEL_DIR, 
       ". Run fit_pupil_ddm_models.R first.")
}

log_step(paste("Found", length(model_files), "model files:"))
for (f in model_files) {
  log_step(paste("  -", basename(f)))
}

# ==============================================================================
# C) Load models into named list
# ==============================================================================

log_step("Loading models...")
models <- list()

for (f in model_files) {
  model_name <- tools::file_path_sans_ext(basename(f))
  
  # Extract model type from filename
  # Examples: "model_0_behavioral", "model_1_pupil_bias", "model_2_pupil_bias_drift"
  if (grepl("model_0|baseline|behavioral", model_name, ignore.case = TRUE)) {
    list_name <- "baseline_no_pupil"
  } else if (grepl("model_1|bias.*only", model_name, ignore.case = TRUE)) {
    list_name <- "bias_only"
  } else if (grepl("model_2|bias.*drift|drift.*bias", model_name, ignore.case = TRUE)) {
    list_name <- "bias_and_drift"
  } else {
    # Use sanitized filename
    list_name <- gsub("[^a-zA-Z0-9_]", "_", model_name)
  }
  
  tryCatch({
    models[[list_name]] <- readRDS(f)
    log_step(paste("  ✓ Loaded:", list_name, "from", basename(f)))
  }, error = function(e) {
    log_step(paste("  ✗ Failed to load", basename(f), ":", e$message))
  })
}

if (length(models) == 0) {
  stop("No models loaded successfully. Check model files.")
}

log_step(paste("Successfully loaded", length(models), "models"))

# ==============================================================================
# D) LOO Summary (only compare models on same dataset)
# ==============================================================================

log_step("Computing LOO comparisons (within-dataset only)...")

loo_results <- list()
dataset_signatures <- list()

# Compute dataset signatures and LOO for each model
for (model_name in names(models)) {
  fit <- models[[model_name]]
  
  if (!inherits(fit, "brmsfit")) {
    log_step(paste("  Skipping", model_name, "(not a brmsfit)"))
    next
  }
  
  # Compute dataset signature
  sig <- paste(
    nrow(fit$data),
    ncol(fit$data),
    digest::digest(head(fit$data, 50))
  )
  
  dataset_signatures[[model_name]] <- sig
  
  # Compute LOO
  tryCatch({
    loo_results[[model_name]] <- loo(fit)
    log_step(paste("  ✓ LOO computed for", model_name))
  }, error = function(e) {
    log_step(paste("  ✗ LOO failed for", model_name, ":", e$message))
  })
}

# Group models by dataset signature
sig_groups <- split(names(dataset_signatures), unlist(dataset_signatures))

# Extract LOO summaries (only for models with successful LOO)
loo_summary_list <- list()

for (model_name in names(loo_results)) {
  loo_obj <- loo_results[[model_name]]
  sig <- dataset_signatures[[model_name]]
  
  loo_summary_list[[model_name]] <- data.frame(
    signature = sig,
    model = model_name,
    elpd_loo = loo_obj$estimates["elpd_loo", "Estimate"],
    se_elpd_loo = loo_obj$estimates["elpd_loo", "SE"],
    p_loo = loo_obj$estimates["p_loo", "Estimate"],
    looic = -2 * loo_obj$estimates["elpd_loo", "Estimate"],
    stringsAsFactors = FALSE
  )
}

if (length(loo_summary_list) > 0) {
  loo_summary <- bind_rows(loo_summary_list)
  
  # Validate no NA
  assert_no_na(loo_summary, c("elpd_loo", "se_elpd_loo", "p_loo", "looic"), 
               "pupil_loo_summary")
  
  # Export
  loo_file <- file.path("output", "pupil_ddm", "tables", "pupil_loo_summary.csv")
  dir.create(dirname(loo_file), recursive = TRUE, showWarnings = FALSE)
  write_csv_logged(loo_summary, loo_file)
  
  log_step("LOO summary:")
  print(loo_summary)
} else {
  log_step("WARNING: No LOO results to export")
}

# ==============================================================================
# E) Fixef Extraction (using tidy_fixef_wiener pattern)
# ==============================================================================

log_step("Extracting fixed effects...")

# Tidy fixef function (adapted from ddm_refit_with_new_threshold.R)
tidy_fixef_wiener <- function(fit, meta) {
  # Extract fixef matrix
  fx <- brms::fixef(fit)
  
  # Convert to tibble with rownames
  df <- tibble::as_tibble(fx, rownames = "raw_term")
  
  # Create dpar and clean term columns
  df <- df %>%
    mutate(
      dpar = case_when(
        startsWith(raw_term, "bs_") ~ "bs",
        startsWith(raw_term, "ndt_") ~ "ndt",
        startsWith(raw_term, "bias_") ~ "bias",
        TRUE ~ "v"
      ),
      term = case_when(
        startsWith(raw_term, "bs_") ~ sub("^bs_", "", raw_term),
        startsWith(raw_term, "ndt_") ~ sub("^ndt_", "", raw_term),
        startsWith(raw_term, "bias_") ~ sub("^bias_", "", raw_term),
        TRUE ~ raw_term
      )
    )
  
  # Verify required columns exist
  required_cols <- c("Estimate", "Est.Error", "Q2.5", "Q97.5")
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop("Missing required columns in fixef: ", paste(missing_cols, collapse = ", "))
  }
  
  # Select columns
  df <- df %>%
    select(raw_term, dpar, term, Estimate, Est.Error, Q2.5, Q97.5)
  
  # Bind meta columns
  df$model <- meta$model
  df$rt_type <- meta$rt_type
  df$threshold <- meta$threshold
  df$n_trials <- meta$n_trials
  
  # Validate
  assert_no_na(df, c("Estimate", "Q2.5", "Q97.5"), "pupil fixef tidy")
  
  # Stop if ANY raw_term contains "bias_" but dpar != "bias"
  bias_mismatch <- df %>%
    filter(grepl("^bias_", raw_term) & dpar != "bias")
  if (nrow(bias_mismatch) > 0) {
    stop("Found raw_term with 'bias_' prefix but dpar != 'bias': ", 
         paste(bias_mismatch$raw_term, collapse = ", "))
  }
  
  # Stop if ANY raw_term contains "bs_" but dpar != "bs"
  bs_mismatch <- df %>%
    filter(grepl("^bs_", raw_term) & dpar != "bs")
  if (nrow(bs_mismatch) > 0) {
    stop("Found raw_term with 'bs_' prefix but dpar != 'bs': ", 
         paste(bs_mismatch$raw_term, collapse = ", "))
  }
  
  # Stop if ANY dpar is NA
  if (any(is.na(df$dpar))) {
    na_dpar_terms <- df$raw_term[is.na(df$dpar)]
    stop("Found NA dpar values for terms: ", paste(na_dpar_terms, collapse = ", "))
  }
  
  return(df)
}

# Extract fixef for all models
fixef_all_list <- list()

for (model_name in names(models)) {
  fit <- models[[model_name]]
  
  if (!inherits(fit, "brmsfit")) {
    next
  }
  
  # Create meta (extract from model if available, otherwise use defaults)
  meta <- list(
    model = model_name,
    rt_type = if ("rt_type" %in% names(fit$data)) unique(fit$data$rt_type)[1] else "unknown",
    threshold = if ("threshold" %in% names(fit$data)) unique(fit$data$threshold)[1] else NA_real_,
    n_trials = nrow(fit$data)
  )
  
  tryCatch({
    fx_tidy <- tidy_fixef_wiener(fit, meta)
    fixef_all_list[[model_name]] <- fx_tidy
    log_step(paste("  ✓ Extracted fixef for", model_name))
  }, error = function(e) {
    log_step(paste("  ✗ Failed to extract fixef for", model_name, ":", e$message))
  })
}

# Combine and filter pupil-related terms
if (length(fixef_all_list) > 0) {
  fixef_all <- bind_rows(fixef_all_list)
  
  # Filter ONLY rows where term includes "pupil"
  pupil_fixef <- fixef_all %>%
    filter(grepl("pupil", term, ignore.case = TRUE) | 
           grepl("pupil", raw_term, ignore.case = TRUE))
  
  # Export full pupil fixef table
  fixef_file <- file.path("output", "pupil_ddm", "tables", "pupil_fixef_link_scale.csv")
  dir.create(dirname(fixef_file), recursive = TRUE, showWarnings = FALSE)
  write_csv_logged(pupil_fixef, fixef_file)
  
  # Extract key terms (drift and bias pupil effects)
  key_terms_list <- list()
  
  for (model_name in names(models)) {
    fit <- models[[model_name]]
    if (!inherits(fit, "brmsfit")) next
    
    # Get posterior draws
    tryCatch({
      draws <- as_draws_df(fit)
    }, error = function(e) {
      log_step(paste("  ✗ Failed to extract draws for", model_name, ":", e$message))
      return(NULL)
    })
    
    if (is.null(draws)) next
    
    # Find pupil effect on drift (dpar="v")
    drift_term <- pupil_fixef %>%
      filter(model == model_name, dpar == "v", grepl("pupil", term, ignore.case = TRUE))
    
    if (nrow(drift_term) > 0) {
      # Find coefficient name in draws (brms uses "b_pupil_z" for drift)
      drift_coef_name <- NULL
      # Try exact match first using raw_term
      raw_term_name <- drift_term$raw_term[1]
      if (raw_term_name %in% names(draws)) {
        drift_coef_name <- raw_term_name
      } else {
        # Try patterns
        for (pattern in c("^b_pupil", "^b_.*pupil.*z$", "pupil.*z$")) {
          matches <- grep(pattern, names(draws), value = TRUE, ignore.case = TRUE)
          matches <- matches[!grepl("bias|bs|ndt", matches, ignore.case = TRUE)]
          if (length(matches) > 0) {
            drift_coef_name <- matches[1]
            break
          }
        }
      }
      
      if (!is.null(drift_coef_name) && drift_coef_name %in% names(draws)) {
        drift_draws <- draws[[drift_coef_name]]
        pd_positive <- mean(drift_draws > 0, na.rm = TRUE)
        
        key_terms_list[[paste(model_name, "drift", sep = "_")]] <- data.frame(
          model = model_name,
          dpar = "v",
          term = drift_term$term[1],
          Estimate = drift_term$Estimate[1],
          Q2.5 = drift_term$Q2.5[1],
          Q97.5 = drift_term$Q97.5[1],
          pd_positive = pd_positive,
          stringsAsFactors = FALSE
        )
      }
    }
    
    # Find pupil effect on bias (dpar="bias")
    bias_term <- pupil_fixef %>%
      filter(model == model_name, dpar == "bias", grepl("pupil", term, ignore.case = TRUE))
    
    if (nrow(bias_term) > 0) {
      # Find coefficient name in draws (brms uses "b_bias_pupil_z" for bias)
      bias_coef_name <- NULL
      # Try exact match first
      raw_term_name <- bias_term$raw_term[1]
      if (raw_term_name %in% names(draws)) {
        bias_coef_name <- raw_term_name
      } else {
        # Try patterns
        for (pattern in c("^b_bias.*pupil.*z$", "^b_bias_pupil", "bias.*pupil.*z$")) {
          matches <- grep(pattern, names(draws), value = TRUE, ignore.case = TRUE)
          if (length(matches) > 0) {
            bias_coef_name <- matches[1]
            break
          }
        }
      }
      
      if (!is.null(bias_coef_name) && bias_coef_name %in% names(draws)) {
        bias_draws <- draws[[bias_coef_name]]
        pd_positive <- mean(bias_draws > 0, na.rm = TRUE)
        
        key_terms_list[[paste(model_name, "bias", sep = "_")]] <- data.frame(
          model = model_name,
          dpar = "bias",
          term = bias_term$term[1],
          Estimate = bias_term$Estimate[1],
          Q2.5 = bias_term$Q2.5[1],
          Q97.5 = bias_term$Q97.5[1],
          pd_positive = pd_positive,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  
  # Export key terms
  if (length(key_terms_list) > 0) {
    key_terms <- bind_rows(key_terms_list)
    key_terms_file <- file.path("output", "pupil_ddm", "tables", "pupil_effects_key_terms.csv")
    write_csv_logged(key_terms, key_terms_file)
  } else {
    log_step("WARNING: No key pupil terms found")
    key_terms <- data.frame()  # Initialize empty for later checks
  }
} else {
  log_step("WARNING: No fixef extracted")
}

# ==============================================================================
# F) Predicted drift/bias by condition (low vs high pupil)
# ==============================================================================

log_step("Computing predicted drift/bias by condition...")

# Find models with pupil effects
drift_model <- NULL
bias_model <- NULL

for (model_name in names(models)) {
  fit <- models[[model_name]]
  if (!inherits(fit, "brmsfit")) next
  
  # Check if model has pupil on drift
  if (any(grepl("pupil", names(fixef(fit)), ignore.case = TRUE)) &&
      !any(grepl("bias.*pupil|pupil.*bias", names(fixef(fit)), ignore.case = TRUE))) {
    # Check if it's actually on drift (not bias)
    fx <- fixef(fit)
    if (any(grepl("^b_pupil|^b_.*pupil", rownames(fx), ignore.case = TRUE)) &&
        !any(grepl("bias", rownames(fx), ignore.case = TRUE))) {
      drift_model <- model_name
    }
  }
  
  # Check if model has pupil on bias
  fx_bias <- tryCatch(fixef(fit, dpar = "bias"), error = function(e) NULL)
  if (!is.null(fx_bias) && any(grepl("pupil", rownames(fx_bias), ignore.case = TRUE))) {
    bias_model <- model_name
  }
}

# If not found by inspection, use naming convention
if (is.null(drift_model)) {
  if ("bias_and_drift" %in% names(models)) {
    drift_model <- "bias_and_drift"
  }
}

if (is.null(bias_model)) {
  if ("bias_only" %in% names(models)) {
    bias_model <- "bias_only"
  } else if ("bias_and_drift" %in% names(models)) {
    bias_model <- "bias_and_drift"
  }
}

# Create prediction grid
# Use pupil_z at -1 and +1 (low vs high, 1 SD)
pupil_levels <- c(-1, 1)
pupil_labels <- c("low", "high")

# Get unique conditions from model data
if (!is.null(drift_model) || !is.null(bias_model)) {
  # Use first available model to get condition structure
  ref_model <- if (!is.null(drift_model)) drift_model else bias_model
  ref_fit <- models[[ref_model]]
  ref_data <- ref_fit$data
  
  # Identify condition columns
  task_col <- if ("task" %in% names(ref_data)) "task" else 
    if ("task_modality" %in% names(ref_data)) "task_modality" else NULL
  
  effort_col <- if ("effort_condition" %in% names(ref_data)) "effort_condition" else
    if ("effort" %in% names(ref_data)) "effort" else NULL
  
  difficulty_col <- if ("difficulty" %in% names(ref_data)) "difficulty" else
    if ("difficulty_3" %in% names(ref_data)) "difficulty_3" else
    if ("stim_offset" %in% names(ref_data)) "stim_offset" else NULL
  
  # Build grid
  grid_list <- list()
  if (!is.null(task_col)) {
    task_vals <- unique(ref_data[[task_col]])
    task_vals <- task_vals[!is.na(task_vals)]
    if (length(task_vals) > 0) grid_list[[task_col]] <- task_vals
  }
  if (!is.null(effort_col)) {
    effort_vals <- unique(ref_data[[effort_col]])
    effort_vals <- effort_vals[!is.na(effort_vals)]
    if (length(effort_vals) > 0) grid_list[[effort_col]] <- effort_vals
  }
  if (!is.null(difficulty_col)) {
    diff_vals <- unique(ref_data[[difficulty_col]])
    diff_vals <- diff_vals[!is.na(diff_vals)]
    if (length(diff_vals) > 0) grid_list[[difficulty_col]] <- diff_vals
  }
  
  # Add pupil_z (use -1 and +1 SD as specified)
  pupil_col_name <- if ("pupil_z" %in% names(ref_data)) "pupil_z" else
    if ("pupil_metric_primary_z" %in% names(ref_data)) "pupil_metric_primary_z" else
    "pupil_z"  # Default (will be added to model if needed)
  
  grid_list[[pupil_col_name]] <- pupil_levels
  
  if (length(grid_list) > 0) {
    pred_grid <- expand.grid(grid_list, stringsAsFactors = FALSE)
    pred_grid$pupil_level <- factor(
      pred_grid[[pupil_col_name]],
      levels = pupil_levels,
      labels = pupil_labels
    )
    
    log_step(paste("Prediction grid:", nrow(pred_grid), "conditions"))
    log_step(paste("  Columns:", paste(names(pred_grid), collapse = ", ")))
  } else {
    log_step("WARNING: Could not build prediction grid (no valid condition columns)")
    pred_grid <- NULL
  }
  
  # Predict drift
  if (!is.null(drift_model) && !is.null(pred_grid) && nrow(pred_grid) > 0) {
    log_step(paste("Predicting drift using model:", drift_model))
    drift_fit <- models[[drift_model]]
    
    tryCatch({
      # Use posterior_linpred for drift (default dpar)
      drift_pred <- posterior_linpred(drift_fit, newdata = pred_grid, 
                                       re_formula = NA)  # Population-level only
      
      # Summarize
      drift_summary <- pred_grid %>%
        mutate(
          Estimate = apply(drift_pred, 2, mean, na.rm = TRUE),
          Q2.5 = apply(drift_pred, 2, quantile, 0.025, na.rm = TRUE),
          Q97.5 = apply(drift_pred, 2, quantile, 0.975, na.rm = TRUE)
        )
      
      # Validate
      assert_no_all_na(drift_summary, c("Estimate", "Q2.5", "Q97.5"), 
                       "drift predictions")
      
      # Export
      drift_file <- file.path("output", "pupil_ddm", "tables", 
                              "pupil_predicted_drift_by_condition.csv")
      dir.create(dirname(drift_file), recursive = TRUE, showWarnings = FALSE)
      write_csv_logged(drift_summary, drift_file)
    }, error = function(e) {
      log_step(paste("  ✗ Drift prediction failed:", e$message))
    })
  } else if (!is.null(drift_model)) {
    log_step("WARNING: Cannot predict drift (prediction grid is empty)")
  }
  
  # Predict bias
  if (!is.null(bias_model) && !is.null(pred_grid) && nrow(pred_grid) > 0) {
    log_step(paste("Predicting bias using model:", bias_model))
    bias_fit <- models[[bias_model]]
    
    tryCatch({
      # Use posterior_linpred for bias (dpar="bias", transform=TRUE)
      bias_pred <- posterior_linpred(bias_fit, newdata = pred_grid, 
                                      dpar = "bias", transform = TRUE,
                                      re_formula = NA)
      
      # Summarize
      bias_summary <- pred_grid %>%
        mutate(
          Estimate = apply(bias_pred, 2, mean, na.rm = TRUE),
          Q2.5 = apply(bias_pred, 2, quantile, 0.025, na.rm = TRUE),
          Q97.5 = apply(bias_pred, 2, quantile, 0.975, na.rm = TRUE)
        )
      
      # Validate
      assert_no_all_na(bias_summary, c("Estimate", "Q2.5", "Q97.5"), 
                       "bias predictions")
      
      # Export
      bias_file <- file.path("output", "pupil_ddm", "tables", 
                             "pupil_predicted_bias_by_condition.csv")
      dir.create(dirname(bias_file), recursive = TRUE, showWarnings = FALSE)
      write_csv_logged(bias_summary, bias_file)
    }, error = function(e) {
      log_step(paste("  ✗ Bias prediction failed:", e$message))
    })
  } else if (!is.null(bias_model)) {
    log_step("WARNING: Cannot predict bias (prediction grid is empty)")
  }
} else {
  log_step("WARNING: No models with pupil effects found for predictions")
}

# ==============================================================================
# G) Plots (save to output/pupil_ddm/figures/)
# ==============================================================================

log_step("Creating density plots...")

figures_dir <- file.path("output", "pupil_ddm", "figures")
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

# Plot drift effect
if (!is.null(drift_model)) {
  drift_fit <- models[[drift_model]]
  
  tryCatch({
    draws <- as_draws_df(drift_fit)
    
    # Find drift coefficient (try multiple patterns)
    drift_coef_name <- NULL
    for (pattern in c("^b_pupil.*z$", "^b_pupil", "^b_.*pupil.*z$")) {
      matches <- grep(pattern, names(draws), value = TRUE, ignore.case = TRUE)
      matches <- matches[!grepl("bias|bs|ndt", matches, ignore.case = TRUE)]
      if (length(matches) > 0) {
        drift_coef_name <- matches[1]
        break
      }
    }
    
    if (!is.null(drift_coef_name) && drift_coef_name %in% names(draws)) {
      drift_draws <- draws[[drift_coef_name]]
      drift_draws <- drift_draws[!is.na(drift_draws)]
      
      if (length(drift_draws) > 0) {
        fig_drift <- ggplot(data.frame(x = drift_draws), aes(x = x)) +
          geom_density(fill = "steelblue", alpha = 0.6) +
          geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
          geom_vline(xintercept = median(drift_draws), linetype = "solid", 
                     color = "darkblue", linewidth = 1) +
          labs(
            title = "Effect of Phasic Arousal (Pupil) on Drift Rate",
            x = "Coefficient for pupil_z on drift rate (link scale)",
            y = "Posterior Density"
          ) +
          theme_minimal(base_size = 14) +
          theme(
            plot.title = element_text(hjust = 0.5, face = "bold"),
            panel.grid.minor = element_blank()
          )
        
        drift_fig_file <- file.path(figures_dir, "fig_pupil_drift_effect.png")
        ggsave(drift_fig_file, fig_drift, width = 8, height = 6, dpi = 300)
        log_step(paste("  ✓ Saved:", drift_fig_file))
      }
    } else {
      log_step("  ✗ Could not find drift coefficient in draws")
    }
  }, error = function(e) {
    log_step(paste("  ✗ Failed to create drift plot:", e$message))
  })
}

# Plot bias effect
if (!is.null(bias_model)) {
  bias_fit <- models[[bias_model]]
  
  tryCatch({
    draws <- as_draws_df(bias_fit)
    
    # Find bias coefficient (try multiple patterns)
    bias_coef_name <- NULL
    for (pattern in c("^b_bias.*pupil.*z$", "^b_bias_pupil", "bias.*pupil.*z$")) {
      matches <- grep(pattern, names(draws), value = TRUE, ignore.case = TRUE)
      if (length(matches) > 0) {
        bias_coef_name <- matches[1]
        break
      }
    }
    
    if (!is.null(bias_coef_name) && bias_coef_name %in% names(draws)) {
      bias_draws <- draws[[bias_coef_name]]
      bias_draws <- bias_draws[!is.na(bias_draws)]
      
      if (length(bias_draws) > 0) {
        fig_bias <- ggplot(data.frame(x = bias_draws), aes(x = x)) +
          geom_density(fill = "darkgreen", alpha = 0.6) +
          geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
          geom_vline(xintercept = median(bias_draws), linetype = "solid", 
                     color = "darkgreen", linewidth = 1) +
          labs(
            title = "Effect of Phasic Arousal (Pupil) on Starting-Point Bias",
            x = "Coefficient for pupil_z on bias (link scale)",
            y = "Posterior Density"
          ) +
          theme_minimal(base_size = 14) +
          theme(
            plot.title = element_text(hjust = 0.5, face = "bold"),
            panel.grid.minor = element_blank()
          )
        
        bias_fig_file <- file.path(figures_dir, "fig_pupil_bias_effect.png")
        ggsave(bias_fig_file, fig_bias, width = 8, height = 6, dpi = 300)
        log_step(paste("  ✓ Saved:", bias_fig_file))
      }
    } else {
      log_step("  ✗ Could not find bias coefficient in draws")
    }
  }, error = function(e) {
    log_step(paste("  ✗ Failed to create bias plot:", e$message))
  })
}

# ==============================================================================
# H) Logging summary
# ==============================================================================

log_step("DONE: pupil exports ready for QMD.")

# List all exported files
tables_dir <- file.path("output", "pupil_ddm", "tables")
if (dir.exists(tables_dir)) {
  tables <- list.files(tables_dir, pattern = "\\.csv$", full.names = TRUE)
  log_step(paste("Exported", length(tables), "tables:"))
  for (f in tables) {
    df <- read_csv(f, show_col_types = FALSE, n_max = 1)
    log_step(paste("  -", basename(f), "(", nrow(read_csv(f, show_col_types = FALSE)), "rows)"))
  }
}

figures_dir <- file.path("output", "pupil_ddm", "figures")
if (dir.exists(figures_dir)) {
  figs <- list.files(figures_dir, pattern = "\\.png$", full.names = TRUE)
  log_step(paste("Exported", length(figs), "figures:"))
  for (f in figs) {
    log_step(paste("  -", basename(f)))
  }
}

log_step("Postprocessing complete!")
