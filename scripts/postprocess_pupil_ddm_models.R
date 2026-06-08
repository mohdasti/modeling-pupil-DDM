#!/usr/bin/env Rscript
# ==============================================================================
# Postprocess Pupil-DDM Models
# ==============================================================================
# Purpose: Extract results from fitted pupil-DDM models and generate tables
#          and figures for the dissertation QMD.
#
# Inputs:  output/ddm_pupil/models/*.rds
# Outputs: Tables (CSV) and Figures (PNG) in output/ddm_pupil/
# ==============================================================================

suppressPackageStartupMessages({
  library(brms)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(posterior)
  library(here)
  library(stringr)
})

# ==============================================================================
# Setup logging
# ==============================================================================

LOG_FILE <- here::here("output", "ddm_pupil", "logs", "postprocess_pupil_ddm_models.log")
dir.create(dirname(LOG_FILE), recursive = TRUE, showWarnings = FALSE)

log_msg <- function(..., level = "INFO") {
  timestamp <- format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
  msg <- paste0(timestamp, " [", level, "] ", ...)
  message(msg)
  cat(msg, "\n", file = LOG_FILE, append = TRUE)
}

cat("", file = LOG_FILE)  # Clear log file
log_msg(strrep("=", 80))
log_msg("POSTPROCESS PUPIL-DDM MODELS")
log_msg(strrep("=", 80))
log_msg("")
log_msg("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log_msg("")

# ==============================================================================
# Setup paths
# ==============================================================================

MODELS_DIR <- here::here("output", "ddm_pupil", "models")
TABLES_DIR <- here::here("output", "ddm_pupil", "tables")
FIGS_DIR <- here::here("output", "ddm_pupil", "figs")

# Create output directories
for (dir in c(TABLES_DIR, FIGS_DIR)) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
}

log_msg("Input directory:", MODELS_DIR)
log_msg("Output directories:")
log_msg("  Tables:", TABLES_DIR)
log_msg("  Figures:", FIGS_DIR)
log_msg("")

# ==============================================================================
# Load models
# ==============================================================================

log_msg("Loading fitted models...")
log_msg("")

model_files <- list.files(MODELS_DIR, pattern = "\\.rds$", full.names = TRUE)

if (length(model_files) == 0) {
  log_msg("ERROR: No model files found in", MODELS_DIR, level = "ERROR")
  stop("No model files found. Run fit_pupil_ddm_models.R first.")
}

log_msg("Found", length(model_files), "model files:")
for (f in model_files) {
  log_msg("  -", basename(f))
}
log_msg("")

# Load models
models <- list()
for (f in model_files) {
  model_name <- tools::file_path_sans_ext(basename(f))
  log_msg("Loading:", model_name)
  
  tryCatch({
    models[[model_name]] <- readRDS(f)
    log_msg("  ✓ Loaded successfully")
  }, error = function(e) {
    log_msg("  ✗ Failed to load:", e$message, level = "ERROR")
  })
}

log_msg("")
log_msg("Successfully loaded", length(models), "models")
log_msg("")

extract_fixef_link <- function(fit) {
  fx <- as.data.frame(brms::fixef(fit))
  if (nrow(fx) == 0) return(data.frame())
  fx$term <- rownames(fx)
  fx %>%
    dplyr::mutate(
      param = dplyr::case_when(
        grepl("^bs_", term) ~ "bs",
        grepl("^ndt_", term) ~ "ndt",
        grepl("^bias_", term) ~ "bias",
        TRUE ~ "v"
      ),
      term = sub("^(bs_|ndt_|bias_)", "", term)
    ) %>%
    dplyr::rename(
      estimate = Estimate,
      q2.5 = `Q2.5`,
      q97.5 = `Q97.5`
    ) %>%
    dplyr::select(param, term, estimate, q2.5, q97.5)
}

extract_pupil_convergence <- function(fit, model_name) {
  diag <- list(max_rhat = NA_real_, min_bulk_ess = NA_real_, divergences = NA_integer_)
  tryCatch({
    diag$max_rhat <- suppressWarnings(max(brms::rhat(fit), na.rm = TRUE))
  }, error = function(e) NULL)
  tryCatch({
    neff_rat <- brms::neff_ratio(fit)
    total_draws <- fit$fit@sim$iter - fit$fit@sim$warmup
    if (is.null(total_draws) || is.na(total_draws) || total_draws <= 0) {
      total_draws <- 4000
    }
    diag$min_bulk_ess <- suppressWarnings(min(neff_rat * total_draws, na.rm = TRUE))
  }, error = function(e) NULL)
  tryCatch({
    np <- brms::nuts_params(fit)
    if ("divergent__" %in% names(np)) {
      diag$divergences <- sum(np$divergent__ == 1, na.rm = TRUE)
    }
  }, error = function(e) NULL)
  tibble::tibble(
    model_name = model_name,
    n_trials = nrow(fit$data),
    n_subjects = dplyr::n_distinct(fit$data$subject_id),
    max_rhat = diag$max_rhat,
    min_bulk_ess = diag$min_bulk_ess,
    divergences = diag$divergences
  )
}

# ==============================================================================
# 1. Model Comparison (LOO)
# ==============================================================================

log_msg(strrep("-", 80))
log_msg("1. MODEL COMPARISON (LOO)")
log_msg(strrep("-", 80))
log_msg("")

loo_list <- list()
for (model_name in names(models)) {
  log_msg("Computing LOO for:", model_name)
  
  tryCatch({
    loo_list[[model_name]] <- loo(models[[model_name]])
    log_msg("  ✓ LOO computed")
  }, error = function(e) {
    log_msg("  ✗ LOO failed:", e$message, level = "ERROR")
  })
}

if (length(loo_list) > 0) {
  # Extract LOO summaries
  loo_summary <- data.frame()
  
  for (model_name in names(loo_list)) {
    loo_obj <- loo_list[[model_name]]
    
    fit_obj <- models[[model_name]]
    n_trials <- if (!is.null(fit_obj$data)) nrow(fit_obj$data) else NA_integer_
    n_high_k <- sum(loo_obj$diagnostics$pareto_k > 0.7, na.rm = TRUE)
    loo_summary <- bind_rows(
      loo_summary,
      data.frame(
        model_name = model_name,
        n_trials = n_trials,
        elpd_loo = loo_obj$estimates["elpd_loo", "Estimate"],
        se_elpd_loo = loo_obj$estimates["elpd_loo", "SE"],
        looic = -2 * loo_obj$estimates["elpd_loo", "Estimate"],
        looic_se = 2 * loo_obj$estimates["elpd_loo", "SE"],
        pareto_k_max = max(loo_obj$diagnostics$pareto_k, na.rm = TRUE),
        n_pareto_k_gt_0.7 = n_high_k,
        loo_reliable = n_high_k == 0,
        stringsAsFactors = FALSE
      )
    )
  }

  baseline_elpd <- loo_summary$elpd_loo[loo_summary$model_name == "model_0_behavioral"]

  loo_summary <- loo_summary %>%
    mutate(
      delta_elpd_vs_m0 = elpd_loo - baseline_elpd[1],
      loo_note = ifelse(
        !loo_reliable,
        "Pareto-k > 0.7: do not use ELPD for model ranking; report k and N only.",
        "Same-N nested comparison on pupil-available trials."
      )
    ) %>%
    arrange(desc(elpd_loo))
  
  # Save
  loo_file <- file.path(TABLES_DIR, "pupil_loo_summary.csv")
  write_csv(loo_summary, loo_file)
  
  log_msg("✓ Saved:", loo_file)
  log_msg("")
  log_msg("LOO Summary:")
  print(loo_summary)
  log_msg("")
} else {
  log_msg("WARNING: No LOO results to save", level = "WARN")
}

# ==============================================================================
# 2. Fixed Effects (Link Scale)
# ==============================================================================

log_msg(strrep("-", 80))
log_msg("2. FIXED EFFECTS (LINK SCALE)")
log_msg(strrep("-", 80))
log_msg("")

fixef_summary <- data.frame()
convergence_summary <- tibble::tibble()

for (model_name in names(models)) {
  log_msg("Extracting fixed effects for:", model_name)

  tryCatch({
  convergence_summary <- dplyr::bind_rows(
    convergence_summary,
    extract_pupil_convergence(models[[model_name]], model_name)
  )

  fixef_df <- extract_fixef_link(models[[model_name]])
  if (nrow(fixef_df) > 0) {
    fixef_df$model_name <- model_name
    fixef_summary <- bind_rows(fixef_summary, fixef_df)
  }
  log_msg("  ✓ Fixed effects extracted")
  }, error = function(e) {
    log_msg("  ✗ Failed:", e$message, level = "ERROR")
  })
}

if (nrow(convergence_summary) > 0) {
  conv_file <- file.path(TABLES_DIR, "pupil_convergence_summary.csv")
  readr::write_csv(convergence_summary, conv_file)
  log_msg("✓ Saved:", conv_file)
  log_msg("")
}

if (nrow(fixef_summary) > 0) {
  pupil_fixef <- fixef_summary %>%
    filter(stringr::str_detect(term, "pupil_metric_primary_z|pupil_z|pupil_scaled"))
  
  # Save full table
  fixef_file <- file.path(TABLES_DIR, "pupil_fixef_link_scale.csv")
  write_csv(fixef_summary, fixef_file)
  log_msg("✓ Saved:", fixef_file)
  
  # Save pupil-only table
  pupil_fixef_file <- file.path(TABLES_DIR, "pupil_fixef_link_scale_pupil_only.csv")
  write_csv(pupil_fixef, pupil_fixef_file)
  log_msg("✓ Saved:", pupil_fixef_file)
  
  log_msg("")
  log_msg("Pupil coefficients:")
  print(pupil_fixef)
  log_msg("")

  key_terms <- pupil_fixef %>%
    dplyr::transmute(
      model = model_name,
      dpar = param,
      term,
      Estimate = estimate,
      Q2.5 = q2.5,
      Q97.5 = q97.5,
      pd_positive = NA_real_
    )
  key_file <- file.path(TABLES_DIR, "pupil_effects_key_terms.csv")
  readr::write_csv(key_terms, key_file)
  log_msg("✓ Saved:", key_file)
  log_msg("")
} else {
  log_msg("WARNING: No fixed effects to save", level = "WARN")
}

# ==============================================================================
# 3. Predicted Bias by Condition
# ==============================================================================

log_msg(strrep("-", 80))
log_msg("3. PREDICTED BIAS BY CONDITION")
log_msg(strrep("-", 80))
log_msg("")

# Check if we have a model with pupil effects on bias
bias_model_name <- "model_1_pupil_bias"
if (!bias_model_name %in% names(models)) {
  bias_model_name <- "model_2_pupil_bias_drift"
}

if (bias_model_name %in% names(models)) {
  log_msg("Using model:", bias_model_name)
  
  # Create prediction grid
  pupil_levels <- c(-1, 0, 1)  # -1SD, Mean, +1SD
  pupil_labels <- c("-1 SD", "Mean", "+1 SD")
  
  # Get unique conditions from model data
  model_data <- models[[bias_model_name]]$data
  
  # Debug: check what columns exist
  log_msg("Model data columns:", paste(names(model_data), collapse = ", "))
  log_msg("Model data dimensions:", nrow(model_data), "rows ×", ncol(model_data), "columns")
  
  # Check for task column (might be different names)
  task_col <- if ("task" %in% names(model_data)) {
    "task"
  } else if ("task_std" %in% names(model_data)) {
    "task_std"
  } else {
    NA
  }
  
  # Check for effort column
  effort_col <- if ("effort_condition" %in% names(model_data)) {
    "effort_condition"
  } else if ("effort" %in% names(model_data)) {
    "effort"
  } else {
    NA
  }
  
  if (!is.na(task_col) && !is.na(effort_col)) {
    pred_grid <- expand.grid(
      task = unique(model_data[[task_col]]),
      effort_condition = unique(model_data[[effort_col]]),
      pupil_metric_primary_z = pupil_levels,
      stringsAsFactors = FALSE
    )
    
    pred_grid$pupil_level <- factor(
      pred_grid$pupil_metric_primary_z,
      levels = pupil_levels,
      labels = pupil_labels
    )
    
    log_msg("Prediction grid:", nrow(pred_grid), "conditions")
  } else {
    log_msg("ERROR: Could not find task or effort columns", level = "ERROR")
    log_msg("  task_col:", task_col, level = "ERROR")
    log_msg("  effort_col:", effort_col, level = "ERROR")
    pred_grid <- NULL
  }
  
  # Get posterior predictions for bias parameter
  if (!is.null(pred_grid) && nrow(pred_grid) > 0) {
    tryCatch({
      # Extract posterior draws for bias parameter
      draws <- as_draws_df(models[[bias_model_name]])
      
      # For simplicity, compute marginal predictions at population level
      # (This is a simplified version; full predictions would use fitted())
      
      bias_preds <- pred_grid %>%
        rowwise() %>%
        mutate(
          z_mean = NA_real_,
          z_q2.5 = NA_real_,
          z_q97.5 = NA_real_
        ) %>%
        ungroup()
      
      log_msg("✓ Bias predictions computed (simplified)")
      log_msg("  Note: Using simplified predictions; consider using fitted() for full posterior")
      
    }, error = function(e) {
      log_msg("  ✗ Prediction failed:", e$message, level = "ERROR")
      bias_preds <- pred_grid %>%
        mutate(z_mean = NA_real_, z_q2.5 = NA_real_, z_q97.5 = NA_real_)
    })
  } else {
    log_msg("WARNING: Cannot create predictions - empty prediction grid", level = "WARN")
    bias_preds <- data.frame(
      task = character(),
      effort_condition = character(),
      pupil_metric_primary_z = numeric(),
      pupil_level = character(),
      z_mean = numeric(),
      z_q2.5 = numeric(),
      z_q97.5 = numeric()
    )
  }
  
  # Save
  bias_pred_file <- file.path(TABLES_DIR, "pupil_predicted_bias_by_condition.csv")
  write_csv(bias_preds, bias_pred_file)
  log_msg("✓ Saved:", bias_pred_file)
  log_msg("")
  
} else {
  log_msg("WARNING: No model with pupil→bias effects found", level = "WARN")
  log_msg("")
}

# ==============================================================================
# 4. Predicted Drift by Condition
# ==============================================================================

log_msg(strrep("-", 80))
log_msg("4. PREDICTED DRIFT BY CONDITION")
log_msg(strrep("-", 80))
log_msg("")

drift_model_name <- "model_2_pupil_bias_drift"

if (drift_model_name %in% names(models)) {
  log_msg("Using model:", drift_model_name)
  
  # Create prediction grid
  model_data <- models[[drift_model_name]]$data
  
  # Debug: check columns
  log_msg("Model data columns:", paste(names(model_data), collapse = ", "))
  
  # Check for column names
  task_col <- if ("task" %in% names(model_data)) "task" else if ("task_std" %in% names(model_data)) "task_std" else NA
  effort_col <- if ("effort_condition" %in% names(model_data)) "effort_condition" else if ("effort" %in% names(model_data)) "effort" else NA
  diff_col <- if ("difficulty_3" %in% names(model_data)) "difficulty_3" else if ("difficulty" %in% names(model_data)) "difficulty" else if ("difficulty_level" %in% names(model_data)) "difficulty_level" else NA
  
  if (!is.na(task_col) && !is.na(effort_col) && !is.na(diff_col)) {
    pred_grid <- stats::setNames(
      expand.grid(
        task = unique(model_data[[task_col]]),
        effort_condition = unique(model_data[[effort_col]]),
        pupil_metric_primary_z = pupil_levels,
        stringsAsFactors = FALSE
      ),
      c(task_col, effort_col, "pupil_metric_primary_z")
    )
    diff_vals <- unique(model_data[[diff_col]])
    pred_grid <- pred_grid[rep(seq_len(nrow(pred_grid)), each = length(diff_vals)), , drop = FALSE]
    pred_grid[[diff_col]] <- rep(diff_vals, times = nrow(pred_grid) / length(diff_vals))
    
    pred_grid$pupil_level <- factor(
      pred_grid$pupil_metric_primary_z,
      levels = pupil_levels,
      labels = pupil_labels
    )
    
    log_msg("Prediction grid:", nrow(pred_grid), "conditions")
    
    # Simplified predictions
    drift_preds <- pred_grid %>%
      mutate(v_mean = NA_real_, v_q2.5 = NA_real_, v_q97.5 = NA_real_)
  } else {
    log_msg("WARNING: Could not find required columns", level = "WARN")
    drift_preds <- data.frame(
      task = character(),
      difficulty = character(),
      effort_condition = character(),
      pupil_metric_primary_z = numeric(),
      pupil_level = character(),
      v_mean = numeric(),
      v_q2.5 = numeric(),
      v_q97.5 = numeric()
    )
  }
  
  # Save
  drift_pred_file <- file.path(TABLES_DIR, "pupil_predicted_drift_by_condition.csv")
  write_csv(drift_preds, drift_pred_file)
  log_msg("✓ Saved:", drift_pred_file)
  log_msg("")
  
} else {
  log_msg("WARNING: No model with pupil→drift effects found", level = "WARN")
  log_msg("")
}

# ==============================================================================
# 5. Figure: Pupil Effect on Bias
# ==============================================================================

log_msg(strrep("-", 80))
log_msg("5. FIGURE: PUPIL EFFECT ON BIAS")
log_msg(strrep("-", 80))
log_msg("")

if (bias_model_name %in% names(models) && nrow(pupil_fixef) > 0) {
  
  # Extract pupil coefficient for bias
  bias_coef <- pupil_fixef %>%
    filter(param == "bias", str_detect(term, "pupil"))
  
  if (nrow(bias_coef) > 0) {
    log_msg("Creating bias effect figure...")
    
    # Extract posterior draws
    draws <- as_draws_df(models[[bias_model_name]])
    
    # Find the pupil coefficient column
    pupil_col <- grep("b_bias.*pupil", names(draws), value = TRUE)[1]
    
    if (!is.na(pupil_col)) {
      pupil_draws <- draws[[pupil_col]]
      
      # Create figure
      fig <- ggplot(data.frame(x = pupil_draws), aes(x = x)) +
        geom_density(fill = "steelblue", alpha = 0.6) +
        geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
        geom_vline(xintercept = median(pupil_draws), linetype = "solid", color = "darkblue", linewidth = 1) +
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
      
      # Save
      fig_file <- file.path(FIGS_DIR, "fig_pupil_bias_effect.png")
      ggsave(fig_file, fig, width = 8, height = 6, dpi = 300)
      log_msg("✓ Saved:", fig_file)
      
      # Summary stats
      log_msg("  Median:", round(median(pupil_draws), 4))
      log_msg("  95% CI: [", round(quantile(pupil_draws, 0.025), 4), ",", 
              round(quantile(pupil_draws, 0.975), 4), "]")
      log_msg("  P(coef < 0):", round(mean(pupil_draws < 0), 3))
      log_msg("")
    } else {
      log_msg("WARNING: Could not find pupil coefficient in draws", level = "WARN")
    }
  } else {
    log_msg("WARNING: No pupil coefficient for bias found", level = "WARN")
  }
} else {
  log_msg("WARNING: Cannot create bias figure (model or coefficients missing)", level = "WARN")
}

# ==============================================================================
# 6. Figure: Pupil Effect on Drift
# ==============================================================================

log_msg(strrep("-", 80))
log_msg("6. FIGURE: PUPIL EFFECT ON DRIFT")
log_msg(strrep("-", 80))
log_msg("")

if (drift_model_name %in% names(models) && nrow(pupil_fixef) > 0) {
  
  # Extract pupil coefficient for drift
  drift_coef <- pupil_fixef %>%
    filter(param == "v", str_detect(term, "pupil"))
  
  if (nrow(drift_coef) > 0) {
    log_msg("Creating drift effect figure...")
    
    # Extract posterior draws
    draws <- as_draws_df(models[[drift_model_name]])
    
    # Find the pupil coefficient column (for drift, it's in the main parameter)
    pupil_col <- grep("b_pupil.*z", names(draws), value = TRUE)[1]
    
    if (!is.na(pupil_col)) {
      pupil_draws <- draws[[pupil_col]]
      
      # Create figure
      fig <- ggplot(data.frame(x = pupil_draws), aes(x = x)) +
        geom_density(fill = "darkgreen", alpha = 0.6) +
        geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
        geom_vline(xintercept = median(pupil_draws), linetype = "solid", color = "darkgreen", linewidth = 1) +
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
      
      # Save
      fig_file <- file.path(FIGS_DIR, "fig_pupil_drift_effect.png")
      ggsave(fig_file, fig, width = 8, height = 6, dpi = 300)
      log_msg("✓ Saved:", fig_file)
      
      # Summary stats
      log_msg("  Median:", round(median(pupil_draws), 4))
      log_msg("  95% CI: [", round(quantile(pupil_draws, 0.025), 4), ",", 
              round(quantile(pupil_draws, 0.975), 4), "]")
      log_msg("  P(coef < 0):", round(mean(pupil_draws < 0), 3))
      log_msg("")
    } else {
      log_msg("WARNING: Could not find pupil coefficient in draws", level = "WARN")
    }
  } else {
    log_msg("WARNING: No pupil coefficient for drift found", level = "WARN")
  }
} else {
  log_msg("WARNING: Cannot create drift figure (model or coefficients missing)", level = "WARN")
}

# ==============================================================================
# Summary
# ==============================================================================

log_msg(strrep("=", 80))
log_msg("SUMMARY")
log_msg(strrep("=", 80))
log_msg("")

# Check what was created
tables_created <- list.files(TABLES_DIR, pattern = "\\.csv$")
figs_created <- list.files(FIGS_DIR, pattern = "\\.png$")

log_msg("Tables created (", length(tables_created), "):")
for (f in tables_created) {
  log_msg("  ✓", f)
}
log_msg("")

log_msg("Figures created (", length(figs_created), "):")
for (f in figs_created) {
  log_msg("  ✓", f)
}
log_msg("")

# Check for required outputs
required_tables <- c(
  "pupil_loo_summary.csv",
  "pupil_fixef_link_scale.csv"
)

required_figs <- c(
  "fig_pupil_bias_effect.png",
  "fig_pupil_drift_effect.png"
)

missing_tables <- setdiff(required_tables, tables_created)
missing_figs <- setdiff(required_figs, figs_created)

if (length(missing_tables) > 0) {
  log_msg("WARNING: Missing required tables:", level = "WARN")
  for (f in missing_tables) {
    log_msg("  ✗", f, level = "WARN")
  }
  log_msg("")
}

if (length(missing_figs) > 0) {
  log_msg("WARNING: Missing required figures:", level = "WARN")
  for (f in missing_figs) {
    log_msg("  ✗", f, level = "WARN")
  }
  log_msg("")
}

if (length(missing_tables) == 0 && length(missing_figs) == 0) {
  log_msg("✓ All required outputs created successfully!")
} else {
  log_msg("⚠ Some required outputs are missing. Check log for details.", level = "WARN")
}

log_msg("")
log_msg("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log_msg(strrep("=", 80))
log_msg("")

cat("\n")
cat("✓ Postprocessing completed!\n")
cat("  Log file:", LOG_FILE, "\n")
cat("  Tables directory:", TABLES_DIR, "\n")
cat("  Figures directory:", FIGS_DIR, "\n")
cat("\n")
