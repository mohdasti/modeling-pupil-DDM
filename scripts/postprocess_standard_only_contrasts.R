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

# Load logging and validation utilities
source("R/utils/logging_validation.R")

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
  # Match the exact factor levels used in the model
  # Check model data to get correct factor levels
  model_data <- fit$data
  task_levels <- levels(factor(model_data$task))
  effort_levels <- levels(factor(model_data$effort_condition))
  
  if (length(task_levels) == 0) {
    task_levels <- c("ADT", "VDT")
  }
  if (length(effort_levels) == 0) {
    # Try common variations
    effort_levels <- c("Low_5_MVC", "High_40_MVC")
  }
  
  cat("  Task levels:", paste(task_levels, collapse = ", "), "\n")
  cat("  Effort levels:", paste(effort_levels, collapse = ", "), "\n")
  
  newdata <- expand.grid(
    task = task_levels,
    effort_condition = effort_levels,
    stringsAsFactors = FALSE
  )
  newdata$task <- factor(newdata$task, levels = task_levels)
  newdata$effort_condition <- factor(newdata$effort_condition, levels = effort_levels)
  
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
      
      # Find bias coefficients - be flexible with naming
      bias_cols <- grep("^b_bias_", names(post_draws), value = TRUE)
      intercept_col <- grep("^b_bias_Intercept$|^b_bias_Intercept\\.", bias_cols, value = TRUE)[1]
      
      # Find task coefficient (VDT relative to ADT)
      task_col <- grep("taskVDT|task_VDT|taskVDT|task.*VDT", bias_cols, value = TRUE, ignore.case = TRUE)[1]
      if (is.na(task_col)) {
        # Try alternative patterns
        task_col <- grep("^b_bias_task", bias_cols, value = TRUE)[1]
      }
      
      # Find effort coefficient (high relative to low)
      effort_col <- grep("effort_conditionhigh|effort.*high|effort.*High", bias_cols, value = TRUE, ignore.case = TRUE)[1]
      if (is.na(effort_col)) {
        # Try alternative patterns
        effort_col <- grep("^b_bias_effort", bias_cols, value = TRUE)[1]
      }
      
      if (is.na(intercept_col)) {
        cat("  ERROR: Could not find bias_Intercept. Available bias columns:\n")
        cat("    ", paste(bias_cols, collapse = "\n    "), "\n")
        stop("Could not find bias_Intercept in posterior draws")
      }
      
      intercept_draws <- post_draws[[intercept_col]]
      n_draws <- length(intercept_draws)
      
      task_draws <- if (!is.na(task_col)) post_draws[[task_col]] else rep(0, n_draws)
      effort_draws <- if (!is.na(effort_col)) post_draws[[effort_col]] else rep(0, n_draws)
      
      # Compute z for each condition on natural scale (plogis transforms from logit)
      # ADT_low: intercept only
      z_adt_low <- plogis(intercept_draws)
      # ADT_high: intercept + effort
      z_adt_high <- plogis(intercept_draws + effort_draws)
      # VDT_low: intercept + task
      z_vdt_low <- plogis(intercept_draws + task_draws)
      # VDT_high: intercept + task + effort
      z_vdt_high <- plogis(intercept_draws + task_draws + effort_draws)
      
      # Return as matrix: draws × conditions (matching newdata order)
      # Order: ADT/Low, ADT/High, VDT/Low, VDT/High
      matrix(c(z_adt_low, z_adt_high, z_vdt_low, z_vdt_high), 
             ncol = 4, nrow = n_draws, byrow = FALSE)
    })
  })
  
  # Verify matrix shape
  if (!is.matrix(z_draws_matrix) || ncol(z_draws_matrix) != 4) {
    cat("  ERROR: z_draws_matrix has unexpected shape:", 
        ifelse(is.matrix(z_draws_matrix), paste(dim(z_draws_matrix), collapse = "x"), "not a matrix"), "\n")
    next
  }
  
  # Extract draws for each condition
  # Map conditions based on newdata order
  # newdata order: ADT/Low, ADT/High, VDT/Low, VDT/High (if 2x2)
  # But need to handle any order - match by task and effort
  condition_map <- data.frame(
    row_idx = 1:nrow(newdata),
    task = as.character(newdata$task),
    effort = as.character(newdata$effort_condition)
  )
  
  # Find indices for each condition
  adt_low_idx <- which(condition_map$task == "ADT" & 
                       (grepl("Low|low", condition_map$effort) | condition_map$effort == "low"))[1]
  adt_high_idx <- which(condition_map$task == "ADT" & 
                        (grepl("High|high", condition_map$effort) | condition_map$effort == "high"))[1]
  vdt_low_idx <- which(condition_map$task == "VDT" & 
                       (grepl("Low|low", condition_map$effort) | condition_map$effort == "low"))[1]
  vdt_high_idx <- which(condition_map$task == "VDT" & 
                        (grepl("High|high", condition_map$effort) | condition_map$effort == "high"))[1]
  
  # Fallback: if only 4 conditions, assume standard order
  if (nrow(newdata) == 4 && (is.na(adt_low_idx) || is.na(adt_high_idx) || 
                              is.na(vdt_low_idx) || is.na(vdt_high_idx))) {
    adt_low_idx <- 1
    adt_high_idx <- 2
    vdt_low_idx <- 3
    vdt_high_idx <- 4
  }
  
  if (any(is.na(c(adt_low_idx, adt_high_idx, vdt_low_idx, vdt_high_idx)))) {
    cat("  ERROR: Could not map conditions correctly\n")
    cat("  Condition map:\n")
    print(condition_map)
    next
  }
  
  z_adt_low_draws <- z_draws_matrix[, adt_low_idx]
  z_adt_high_draws <- z_draws_matrix[, adt_high_idx]
  z_vdt_low_draws <- z_draws_matrix[, vdt_low_idx]
  z_vdt_high_draws <- z_draws_matrix[, vdt_high_idx]
  
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
  
  # Summarize contrasts with dissertation-grade format
  # Compute quantiles explicitly to catch any issues
  task_q2.5 <- quantile(task_contrast_draws, 0.025, na.rm = TRUE, names = FALSE)
  task_q97.5 <- quantile(task_contrast_draws, 0.975, na.rm = TRUE, names = FALSE)
  task_mean <- mean(task_contrast_draws, na.rm = TRUE)
  task_median <- median(task_contrast_draws, na.rm = TRUE)
  task_p_gt0 <- mean(task_contrast_draws > 0, na.rm = TRUE)
  
  effort_q2.5 <- quantile(effort_contrast_draws, 0.025, na.rm = TRUE, names = FALSE)
  effort_q97.5 <- quantile(effort_contrast_draws, 0.975, na.rm = TRUE, names = FALSE)
  effort_mean <- mean(effort_contrast_draws, na.rm = TRUE)
  effort_median <- median(effort_contrast_draws, na.rm = TRUE)
  effort_p_gt0 <- mean(effort_contrast_draws > 0, na.rm = TRUE)
  
  # Check for NA/NaN quantiles immediately
  if (is.na(task_q2.5) || is.na(task_q97.5) || is.na(effort_q2.5) || is.na(effort_q97.5)) {
    cat("  ERROR: Found NA quantile values\n")
    cat("    Task contrast: q2.5 =", task_q2.5, ", q97.5 =", task_q97.5, "\n")
    cat("    Effort contrast: q2.5 =", effort_q2.5, ", q97.5 =", effort_q97.5, "\n")
    cat("    Task draws: n =", length(task_contrast_draws), ", valid =", sum(!is.na(task_contrast_draws)), "\n")
    cat("    Effort draws: n =", length(effort_contrast_draws), ", valid =", sum(!is.na(effort_contrast_draws)), "\n")
    stop("Cannot compute quantiles: NA values detected")
  }
  
  # Check quantile ordering
  if (task_q2.5 > task_q97.5) {
    stop("Task contrast quantiles out of order: q2.5 (", task_q2.5, ") > q97.5 (", task_q97.5, ")")
  }
  if (effort_q2.5 > effort_q97.5) {
    stop("Effort contrast quantiles out of order: q2.5 (", effort_q2.5, ") > q97.5 (", effort_q97.5, ")")
  }
  
  contrast_rows <- list(
    data.frame(
      rt_def = rt_def,
      threshold = threshold,
      contrast = "Visual_Auditory",
      estimate = task_median,  # Use median as estimate (can also use mean)
      q2.5 = task_q2.5,
      q97.5 = task_q97.5,
      p_gt0 = task_p_gt0,
      stringsAsFactors = FALSE
    ),
    data.frame(
      rt_def = rt_def,
      threshold = threshold,
      contrast = "Low_High",
      estimate = effort_median,  # Use median as estimate (can also use mean)
      q2.5 = effort_q2.5,
      q97.5 = effort_q97.5,
      p_gt0 = effort_p_gt0,
      stringsAsFactors = FALSE
    )
  )
  
  cat("  ✓ Quantiles computed successfully (no NA)\n")
  
  # Store results
  key <- paste0(rt_def, "__", formatC(threshold, format="f", digits=2))
  contrast_results[[key]] <- bind_rows(contrast_rows)
  
  cat("\n")
}

# Combine all contrasts
if (length(contrast_results) > 0) {
  contrasts_df <- bind_rows(contrast_results)
  
  # Remove any NaN values (convert to NA for explicit checking)
  contrasts_df <- contrasts_df %>%
    mutate(across(where(is.numeric), ~ ifelse(is.nan(.x), NA_real_, .x)))
  
  # DISSERTATION-GRADE VALIDATION: Assert no NA in CI columns
  na_q2.5 <- sum(is.na(contrasts_df$q2.5))
  na_q97.5 <- sum(is.na(contrasts_df$q97.5))
  
  if (na_q2.5 > 0 || na_q97.5 > 0) {
    cat("ERROR: Validation failed - NA values in CI columns!\n")
    cat("  NA in q2.5:", na_q2.5, "rows\n")
    cat("  NA in q97.5:", na_q97.5, "rows\n")
    cat("\nRows with missing CIs:\n")
    broken_rows <- contrasts_df %>%
      filter(is.na(q2.5) | is.na(q97.5)) %>%
      select(rt_def, threshold, contrast, estimate, q2.5, q97.5, p_gt0)
    print(broken_rows)
    stop("Contrasts CSV contains NA quantiles - cannot export")
  }
  
  # DISSERTATION-GRADE VALIDATION: Assert quantile ordering (q2.5 <= estimate <= q97.5)
  ordering_violations <- contrasts_df %>%
    filter(q2.5 > estimate | estimate > q97.5)
  
  if (nrow(ordering_violations) > 0) {
    cat("ERROR: Validation failed - quantile ordering violations!\n")
    cat("  Violations:", nrow(ordering_violations), "rows\n")
    cat("\nRows with ordering violations:\n")
    print(ordering_violations %>% select(rt_def, threshold, contrast, estimate, q2.5, q97.5))
    stop("Contrasts CSV has quantile ordering violations - cannot export")
  }
  
  # All validations passed - write output
  output_file <- file.path(tables_dir, "standard_only_bias_contrasts.csv")
  write_csv(contrasts_df, output_file)
  cat("================================================================================\n")
  cat("SAVED:", output_file, "\n")
  cat("Rows:", nrow(contrasts_df), "\n")
  cat("✓ Validation passed: all CIs non-NA and properly ordered\n")
  cat("================================================================================\n\n")
  
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
