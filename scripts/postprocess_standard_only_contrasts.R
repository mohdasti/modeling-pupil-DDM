#!/usr/bin/env Rscript
# Post-process standard-only bias contrasts from saved .rds models
# Recomputes contrasts from posterior draws to fix NaN quantiles
#
# Usage: Rscript scripts/postprocess_standard_only_contrasts.R [run_dir]
# Default: output/ddm_refits/runs/20260204_214842

suppressPackageStartupMessages({
  library(brms)
  library(dplyr)
  library(readr)
})

# Get run directory from command line or use default
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 0) {
  run_dir <- args[1]
} else {
  # Use most recent run or default
  runs_base <- "output/ddm_refits/runs"
  if (dir.exists(runs_base)) {
    runs <- list.dirs(runs_base, full.names = FALSE, recursive = FALSE)
    if (length(runs) > 0) {
      run_dir <- file.path(runs_base, sort(runs, decreasing = TRUE)[1])
      cat("Using most recent run:", run_dir, "\n")
    } else {
      run_dir <- "output/ddm_refits/runs/20260204_214842"
      cat("Using default run:", run_dir, "\n")
    }
  } else {
    stop("Runs directory not found: ", runs_base)
  }
}

if (!dir.exists(run_dir)) {
  stop("Run directory not found: ", run_dir)
}

# Set up paths
models_dir <- file.path(run_dir, "models")
tables_dir <- file.path(run_dir, "tables")
logs_dir <- file.path(run_dir, "logs")

# Create log file
log_file <- file.path(logs_dir, "postprocess_standard_only_contrasts.log")
log_con <- file(log_file, open = "wt")
sink(log_con, type = "output", split = TRUE)

cat("================================================================================\n")
cat("POST-PROCESSING STANDARD-ONLY BIAS CONTRASTS\n")
cat("================================================================================\n")
cat("Timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Run directory:", run_dir, "\n")
cat("Models directory:", models_dir, "\n")
cat("Output directory:", tables_dir, "\n")
cat("================================================================================\n\n")

# Find all standard-only model files
model_files <- list.files(models_dir, pattern = "^standard_only__.*\\.rds$", full.names = TRUE)
if (length(model_files) == 0) {
  stop("No standard-only model files found in ", models_dir)
}

cat("Found", length(model_files), "standard-only model files\n\n")

# Process each model
contrast_results <- list()

for (model_file in model_files) {
  # Parse filename: standard_only__cue_locked__thr0.20.rds
  basename_file <- basename(model_file)
  cat("Processing:", basename_file, "\n")
  
  # Extract rt_def and threshold from filename
  parts <- strsplit(basename_file, "__")[[1]]
  if (length(parts) != 3) {
    cat("  WARNING: Unexpected filename format, skipping\n")
    next
  }
  
  rt_def <- parts[2]  # cue_locked or probe_onset_locked
  threshold_str <- gsub("thr|\\.rds", "", parts[3])
  threshold <- as.numeric(threshold_str)
  
  cat("  RT definition:", rt_def, "\n")
  cat("  Threshold:", threshold, "\n")
  
  # Load model
  fit <- tryCatch({
    readRDS(model_file)
  }, error = function(e) {
    cat("  ERROR: Failed to load model:", e$message, "\n")
    return(NULL)
  })
  
  if (is.null(fit) || !inherits(fit, "brmsfit")) {
    cat("  ERROR: Model is not a valid brmsfit object\n")
    next
  }
  
  # Get number of draws
  n_draws <- brms::ndraws(fit)
  cat("  Posterior draws:", n_draws, "\n")
  
  # Create prediction grid: Task × Effort
  newdata <- expand.grid(
    task = c("ADT", "VDT"),
    effort_condition = c("low", "high"),
    stringsAsFactors = FALSE
  )
  newdata$task <- factor(newdata$task, levels = c("ADT", "VDT"))
  newdata$effort_condition <- factor(newdata$effort_condition, levels = c("low", "high"))
  
  # Get posterior predictions for bias (z on natural scale)
  z_draws_matrix <- tryCatch({
    # Try posterior_epred first (returns natural scale for bias with logit link)
    brms::posterior_epred(fit, dpar = "bias", newdata = newdata)
  }, error = function(e1) {
    # Fallback: use posterior_linpred and transform manually
    tryCatch({
      linpred_draws <- brms::posterior_linpred(fit, dpar = "bias", newdata = newdata)
      plogis(linpred_draws)  # Transform from logit to natural scale
    }, error = function(e2) {
      # Final fallback: manual computation from coefficient draws
      cat("  WARNING: posterior_epred/linpred failed, using manual computation\n")
      post_draws <- brms::as_draws_df(fit)
      
      # Find bias coefficients
      bias_cols <- grep("^b_bias_", names(post_draws), value = TRUE)
      intercept_col <- grep("^b_bias_Intercept$", bias_cols, value = TRUE)[1]
      task_col <- grep("taskVDT|task_VDT", bias_cols, value = TRUE, ignore.case = TRUE)[1]
      effort_col <- grep("effort_conditionhigh|effort.*high", bias_cols, value = TRUE, ignore.case = TRUE)[1]
      
      if (is.na(intercept_col)) {
        stop("Could not find bias_Intercept in posterior draws")
      }
      
      intercept_draws <- post_draws[[intercept_col]]
      task_draws <- if (!is.na(task_col)) post_draws[[task_col]] else rep(0, length(intercept_draws))
      effort_draws <- if (!is.na(effort_col)) post_draws[[effort_col]] else rep(0, length(intercept_draws))
      
      # Compute z for each condition: ADT_low, ADT_high, VDT_low, VDT_high
      z_adt_low <- plogis(intercept_draws)
      z_adt_high <- plogis(intercept_draws + effort_draws)
      z_vdt_low <- plogis(intercept_draws + task_draws)
      z_vdt_high <- plogis(intercept_draws + task_draws + effort_draws)
      
      # Return as matrix: draws × conditions
      matrix(c(z_adt_low, z_adt_high, z_vdt_low, z_vdt_high), 
             ncol = 4, nrow = length(intercept_draws))
    })
  })
  
  # Verify matrix shape
  if (!is.matrix(z_draws_matrix) || ncol(z_draws_matrix) != 4) {
    cat("  ERROR: z_draws_matrix has unexpected shape:", 
        ifelse(is.matrix(z_draws_matrix), paste(dim(z_draws_matrix), collapse = "x"), "not a matrix"), "\n")
    next
  }
  
  # Extract draws for each condition
  z_adt_low_draws <- z_draws_matrix[, 1]
  z_adt_high_draws <- z_draws_matrix[, 2]
  z_vdt_low_draws <- z_draws_matrix[, 3]
  z_vdt_high_draws <- z_draws_matrix[, 4]
  
  cat("  Condition z means: ADT_low=", round(mean(z_adt_low_draws), 4),
      ", ADT_high=", round(mean(z_adt_high_draws), 4),
      ", VDT_low=", round(mean(z_vdt_low_draws), 4),
      ", VDT_high=", round(mean(z_vdt_high_draws), 4), "\n")
  
  # Compute contrasts from posterior draws
  # Task contrast: VDT - ADT (averaged across effort)
  task_contrast_draws <- (z_vdt_low_draws + z_vdt_high_draws) / 2 - 
                         (z_adt_low_draws + z_adt_high_draws) / 2
  
  # Effort contrast: high - low (averaged across task)
  effort_contrast_draws <- (z_adt_high_draws + z_vdt_high_draws) / 2 - 
                           (z_adt_low_draws + z_vdt_low_draws) / 2
  
  # Summarize contrasts
  contrast_rows <- list(
    data.frame(
      rt_def = rt_def,
      threshold = threshold,
      contrast = "Visual_Auditory",
      z_diff_mean = mean(task_contrast_draws, na.rm = TRUE),
      z_diff_median = median(task_contrast_draws, na.rm = TRUE),
      z_diff_q2.5 = quantile(task_contrast_draws, 0.025, na.rm = TRUE),
      z_diff_q97.5 = quantile(task_contrast_draws, 0.975, na.rm = TRUE),
      p_gt0 = mean(task_contrast_draws > 0, na.rm = TRUE),
      stringsAsFactors = FALSE
    ),
    data.frame(
      rt_def = rt_def,
      threshold = threshold,
      contrast = "Low_High",
      z_diff_mean = mean(effort_contrast_draws, na.rm = TRUE),
      z_diff_median = median(effort_contrast_draws, na.rm = TRUE),
      z_diff_q2.5 = quantile(effort_contrast_draws, 0.025, na.rm = TRUE),
      z_diff_q97.5 = quantile(effort_contrast_draws, 0.975, na.rm = TRUE),
      p_gt0 = mean(effort_contrast_draws > 0, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  )
  
  # Check for NA quantiles
  na_check <- sum(is.na(contrast_rows[[1]]$z_diff_q2.5), is.na(contrast_rows[[1]]$z_diff_q97.5),
                  is.na(contrast_rows[[2]]$z_diff_q2.5), is.na(contrast_rows[[2]]$z_diff_q97.5))
  if (na_check > 0) {
    cat("  ERROR: Found", na_check, "NA quantile values\n")
  } else {
    cat("  ✓ Quantiles computed successfully (no NA)\n")
  }
  
  # Store results
  key <- paste0(rt_def, "__", formatC(threshold, format="f", digits=2))
  contrast_results[[key]] <- bind_rows(contrast_rows)
  
  cat("\n")
}

# Combine all contrasts
if (length(contrast_results) > 0) {
  contrasts_df <- bind_rows(contrast_results)
  
  # Remove any NaN values
  contrasts_df <- contrasts_df %>%
    mutate(across(where(is.numeric), ~ ifelse(is.nan(.x), NA_real_, .x)))
  
  # Write output
  output_file <- file.path(tables_dir, "standard_only_bias_contrasts.csv")
  write_csv(contrasts_df, output_file)
  cat("================================================================================\n")
  cat("SAVED:", output_file, "\n")
  cat("Rows:", nrow(contrasts_df), "\n")
  cat("================================================================================\n\n")
  
  # Sanity check: assert no NA in quantile columns
  na_q2.5 <- sum(is.na(contrasts_df$z_diff_q2.5))
  na_q97.5 <- sum(is.na(contrasts_df$z_diff_q97.5))
  
  if (na_q2.5 > 0 || na_q97.5 > 0) {
    cat("ERROR: Validation failed!\n")
    cat("  NA in z_diff_q2.5:", na_q2.5, "\n")
    cat("  NA in z_diff_q97.5:", na_q97.5, "\n")
    stop("Contrasts CSV contains NA quantiles")
  } else {
    cat("✓ Validation passed: no NA in quantile columns\n\n")
  }
  
  # Print preview
  cat("Preview (first 5 rows):\n")
  print(head(contrasts_df, 5))
  cat("\n")
  
} else {
  stop("No contrast results to export")
}

# Close log
sink(type = "output")
close(log_con)

cat("Post-processing complete. Log saved to:", log_file, "\n")
