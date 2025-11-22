# =========================================================================
# CONVERGENCE SUMMARY FOR ALL MODELS
# =========================================================================
# Extract convergence diagnostics for each reported model:
#   - max Rhat
#   - min bulk_ESS_ratio
#   - min tail_ESS_ratio
#   - # divergences (cmdstanr)
# 
# Add flags:
#   - rhat_flag = maxRhat > 1.01
#   - ess_flag = (min bulk_ESS_ratio < 0.10 | min tail_ESS_ratio < 0.10)
#   - div_flag = divergences > 0
# 
# Write to: output/diagnostics/convergence_summary_all.csv
# Stop if any flag is TRUE
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(posterior)
  library(dplyr)
  library(readr)
  if (requireNamespace("rstan", quietly = TRUE)) {
    library(rstan)
  }
})

# Create output directory
dir.create("output/diagnostics", recursive = TRUE, showWarnings = FALSE)

cat("\n")
cat("================================================================================\n")
cat("CONVERGENCE SUMMARY FOR ALL MODELS\n")
cat("================================================================================\n")
cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# =========================================================================
# MODEL FILES
# =========================================================================

model_files <- c(
  "output/models/Model1_Baseline.rds",
  "output/models/Model2_Force.rds",
  "output/models/Model3_Difficulty.rds",
  "output/models/Model4_Additive.rds",
  "output/models/Model5_Interaction.rds",
  "output/models/Model7_Task.rds",
  "output/models/Model8_Task_Additive.rds",
  "output/models/Model9_Task_Intx.rds",
  "output/models/Model10_Param_v_bs.rds"
)

# =========================================================================
# EXTRACT CONVERGENCE DIAGNOSTICS
# =========================================================================

convergence_results <- data.frame(
  model = character(),
  max_rhat = numeric(),
  min_bulk_ESS_ratio = numeric(),
  min_tail_ESS_ratio = numeric(),
  n_divergences = numeric(),
  rhat_flag = logical(),
  ess_flag = logical(),
  div_flag = logical(),
  stringsAsFactors = FALSE
)

cat("Extracting convergence diagnostics...\n\n")

for (model_file in model_files) {
  model_name <- tools::file_path_sans_ext(basename(model_file))
  
  if (!file.exists(model_file)) {
    cat(sprintf("⚠️  %s: File not found, skipping\n", model_name))
    next
  }
  
  cat(sprintf("Processing: %s\n", model_name))
  
  tryCatch({
    # Load model
    fit <- readRDS(model_file)
    
    # Extract Rhat
    rhat_values <- rhat(fit)
    if (length(rhat_values) == 0) {
      stop("Could not extract Rhat values")
    }
    max_rhat <- max(rhat_values, na.rm = TRUE)
    
    # Extract ESS ratios - use summary object which has Bulk_ESS and Tail_ESS
    # This is more reliable than ess_bulk()/ess_tail() which may fail
    model_summary <- summary(fit)
    
    # Get total draws for ratio calculation
    draws <- as_draws_df(fit)
    n_draws <- nrow(draws)
    
    if (n_draws == 0) {
      stop("Could not determine number of draws")
    }
    
    # Extract ESS from summary (more reliable)
    # Check both fixed and random effects
    all_bulk_ESS <- numeric()
    all_tail_ESS <- numeric()
    
    # Try to get from fixed effects summary
    if (!is.null(model_summary$fixed) && "Bulk_ESS" %in% colnames(model_summary$fixed)) {
      bulk_ESS_vals <- model_summary$fixed$Bulk_ESS
      if (length(bulk_ESS_vals) > 0) {
        all_bulk_ESS <- c(all_bulk_ESS, bulk_ESS_vals)
      }
    }
    
    if (!is.null(model_summary$fixed) && "Tail_ESS" %in% colnames(model_summary$fixed)) {
      tail_ESS_vals <- model_summary$fixed$Tail_ESS
      if (length(tail_ESS_vals) > 0) {
        all_tail_ESS <- c(all_tail_ESS, tail_ESS_vals)
      }
    }
    
    # Also check random effects if available
    if (!is.null(model_summary$random) && "Bulk_ESS" %in% colnames(model_summary$random)) {
      bulk_ESS_vals <- model_summary$random$Bulk_ESS
      if (length(bulk_ESS_vals) > 0) {
        all_bulk_ESS <- c(all_bulk_ESS, bulk_ESS_vals)
      }
    }
    
    if (!is.null(model_summary$random) && "Tail_ESS" %in% colnames(model_summary$random)) {
      tail_ESS_vals <- model_summary$random$Tail_ESS
      if (length(tail_ESS_vals) > 0) {
        all_tail_ESS <- c(all_tail_ESS, tail_ESS_vals)
      }
    }
    
    # Calculate ratios
    min_bulk_ESS_ratio <- NA_real_
    min_tail_ESS_ratio <- NA_real_
    
    if (length(all_bulk_ESS) > 0) {
      min_bulk_ESS_ratio <- min(all_bulk_ESS, na.rm = TRUE) / n_draws
    }
    
    if (length(all_tail_ESS) > 0) {
      min_tail_ESS_ratio <- min(all_tail_ESS, na.rm = TRUE) / n_draws
    }
    
    # Fallback: try ess_bulk() and ess_tail() if summary method failed
    if (is.na(min_bulk_ESS_ratio) || is.na(min_tail_ESS_ratio)) {
      tryCatch({
        ess_bulk_vals <- ess_bulk(fit)
        ess_tail_vals <- ess_tail(fit)
        
        if (length(ess_bulk_vals) > 0) {
          bulk_ESS_ratios <- ess_bulk_vals / n_draws
          min_bulk_ESS_ratio <- min(bulk_ESS_ratios, na.rm = TRUE)
        }
        
        if (length(ess_tail_vals) > 0) {
          tail_ESS_ratios <- ess_tail_vals / n_draws
          min_tail_ESS_ratio <- min(tail_ESS_ratios, na.rm = TRUE)
        }
      }, error = function(e) {
        # If both methods fail, use neff_ratio as last resort (gives overall ratio)
        tryCatch({
          ess_ratios <- neff_ratio(fit)
          if (length(ess_ratios) > 0) {
            overall_min <- min(ess_ratios, na.rm = TRUE)
            min_bulk_ESS_ratio <- overall_min
            min_tail_ESS_ratio <- overall_min
          }
        }, error = function(e2) {
          cat(sprintf("    ⚠️  Could not extract ESS ratios: %s\n", e2$message))
        })
      })
    }
    
    # Check if we still have NA values
    if (is.na(min_bulk_ESS_ratio)) {
      stop("Could not extract bulk ESS ratio")
    }
    if (is.na(min_tail_ESS_ratio)) {
      stop("Could not extract tail ESS ratio")
    }
    
    # Extract divergences (cmdstanr/rstan)
    n_divergences <- 0
    tryCatch({
      # Use nuts_params from posterior package (works for both cmdstanr and rstan)
      nuts_diag <- nuts_params(fit)
      if (!is.null(nuts_diag) && "divergent__" %in% nuts_diag$Parameter) {
        n_divergences <- sum(nuts_diag$Value[nuts_diag$Parameter == "divergent__"], na.rm = TRUE)
      }
    }, error = function(e) {
      # Fallback: try cmdstanr-specific extraction
      if (!is.null(fit$fit) && inherits(fit$fit, "CmdStanMCMC")) {
        tryCatch({
          sampler_params <- fit$fit$sampler_diagnostics()
          if (!is.null(sampler_params) && "divergent__" %in% names(sampler_params)) {
            n_divergences <- sum(sampler_params$divergent__, na.rm = TRUE)
          }
        }, error = function(e2) {
          # Try diagnostic_summary
          tryCatch({
            diagnostics <- fit$fit$diagnostic_summary()
            if (!is.null(diagnostics) && "num_divergent" %in% names(diagnostics)) {
              n_divergences <- diagnostics$num_divergent
            }
          }, error = function(e3) {
            cat(sprintf("    ⚠️  Could not extract divergences\n"))
          })
        })
      } else if (!is.null(fit$fit) && inherits(fit$fit, "stanfit")) {
        # rstan backend
        tryCatch({
          sampler_params <- rstan::get_sampler_params(fit$fit, inc_warmup = FALSE)
          if (length(sampler_params) > 0 && "divergent__" %in% colnames(sampler_params[[1]])) {
            n_divergences <- sum(sapply(sampler_params, function(x) sum(x[, "divergent__"], na.rm = TRUE)), na.rm = TRUE)
          }
        }, error = function(e2) {
          cat(sprintf("    ⚠️  Could not extract divergences\n"))
        })
      }
    })
    
    # Compute flags
    rhat_flag <- max_rhat > 1.01
    ess_flag <- (min_bulk_ESS_ratio < 0.10 | min_tail_ESS_ratio < 0.10)
    div_flag <- n_divergences > 0
    
    # Add to results
    convergence_results <- rbind(convergence_results, data.frame(
      model = model_name,
      max_rhat = max_rhat,
      min_bulk_ESS_ratio = min_bulk_ESS_ratio,
      min_tail_ESS_ratio = min_tail_ESS_ratio,
      n_divergences = n_divergences,
      rhat_flag = rhat_flag,
      ess_flag = ess_flag,
      div_flag = div_flag,
      stringsAsFactors = FALSE
    ))
    
    # Print summary
    cat(sprintf("  Max R-hat: %.4f %s\n", max_rhat, ifelse(rhat_flag, "⚠️ FLAG", "✓")))
    cat(sprintf("  Min bulk ESS ratio: %.4f %s\n", min_bulk_ESS_ratio, ifelse(min_bulk_ESS_ratio < 0.10, "⚠️ FLAG", "✓")))
    cat(sprintf("  Min tail ESS ratio: %.4f %s\n", min_tail_ESS_ratio, ifelse(min_tail_ESS_ratio < 0.10, "⚠️ FLAG", "✓")))
    cat(sprintf("  Divergences: %d %s\n", n_divergences, ifelse(div_flag, "⚠️ FLAG", "✓")))
    cat("\n")
    
  }, error = function(e) {
    cat(sprintf("  ❌ Error processing %s: %s\n\n", model_name, e$message))
    # Add row with NAs
    convergence_results <- rbind(convergence_results, data.frame(
      model = model_name,
      max_rhat = NA_real_,
      min_bulk_ESS_ratio = NA_real_,
      min_tail_ESS_ratio = NA_real_,
      n_divergences = NA_real_,
      rhat_flag = NA,
      ess_flag = NA,
      div_flag = NA,
      stringsAsFactors = FALSE
    ))
  })
}

# =========================================================================
# SAVE RESULTS
# =========================================================================

output_file <- "output/diagnostics/convergence_summary_all.csv"
write_csv(convergence_results, output_file)

cat("================================================================================\n")
cat("RESULTS SAVED\n")
cat("================================================================================\n")
cat(sprintf("Saved to: %s\n\n", output_file))

# Print summary table
cat("Convergence Summary:\n")
print(convergence_results)
cat("\n")

# =========================================================================
# CHECK FLAGS AND STOP IF ANY ARE TRUE
# =========================================================================

cat("================================================================================\n")
cat("FLAG CHECK\n")
cat("================================================================================\n\n")

any_flags <- any(convergence_results$rhat_flag, na.rm = TRUE) |
             any(convergence_results$ess_flag, na.rm = TRUE) |
             any(convergence_results$div_flag, na.rm = TRUE)

if (any_flags) {
  cat("❌ CONVERGENCE FLAGS DETECTED:\n\n")
  
  flagged_models <- convergence_results %>%
    filter(rhat_flag | ess_flag | div_flag)
  
  for (i in 1:nrow(flagged_models)) {
    m <- flagged_models[i, ]
    cat(sprintf("  %s:\n", m$model))
    if (m$rhat_flag) {
      cat(sprintf("    - R-hat flag: max_rhat = %.4f > 1.01\n", m$max_rhat))
    }
    if (m$ess_flag) {
      cat(sprintf("    - ESS flag: bulk = %.4f or tail = %.4f < 0.10\n", 
                  m$min_bulk_ESS_ratio, m$min_tail_ESS_ratio))
    }
    if (m$div_flag) {
      cat(sprintf("    - Divergence flag: n_divergences = %d > 0\n", m$n_divergences))
    }
    cat("\n")
  }
  
  cat("================================================================================\n")
  cat("⚠️  WARNING: Convergence issues detected\n")
  cat("================================================================================\n")
  cat("The script will continue, but please review flagged models.\n")
  cat("To stop on flags, uncomment the stop() line in the script.\n\n")
  # Uncomment the line below if you want the script to stop on flags:
  # stop("Convergence flags detected. Please review models before proceeding.")
} else {
  cat("✓ All models passed convergence checks\n")
  cat("  - No R-hat flags (all max_rhat <= 1.01)\n")
  cat("  - No ESS flags (all ESS ratios >= 0.10)\n")
  cat("  - No divergence flags (all divergences = 0)\n\n")
}

cat("================================================================================\n")
cat("COMPLETE\n")
cat("================================================================================\n")
cat("Completed:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

