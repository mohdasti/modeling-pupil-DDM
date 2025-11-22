# --- refit_convergence_targets.R ----------------------------------------------

# Purpose: Refit only the models that fail convergence thresholds.

# Input:

#   - output/diagnostics/convergence_summary_all.csv (optional)

#   - brmsfit RDS models in output/models/

#   - output/diagnostics/convergence_summary_post_refit.csv (optional, to resume)

# Output:

#   - Overwrites model RDS with refit; writes a post-refit summary CSV.



suppressPackageStartupMessages({

  library(brms)

  library(data.table)

  library(dplyr)

  library(posterior)

})



# Set working directory to project root if needed --------------------------------

# Try to detect if we're in the project root

if (!file.exists("scripts/checks/refit_convergence_targets.R")) {

  # Try common project root paths

  possible_roots <- c(

    getwd(),

    "/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM"

  )

  

  # Try to get RStudio editor path if available

  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {

    tryCatch({

      script_path <- rstudioapi::getSourceEditorContext()$path

      if (nchar(script_path) > 0) {

        possible_roots <- c(

          dirname(dirname(dirname(script_path))),

          possible_roots

        )

      }

    }, error = function(e) NULL)

  }

  

  for (root in possible_roots) {

    if (!is.null(root) && !is.na(root) && 

        file.exists(file.path(root, "scripts/checks/refit_convergence_targets.R"))) {

      setwd(root)

      cat("Changed working directory to:", root, "\n")

      break

    }

  }

  

  # Final check

  if (!file.exists("scripts/checks/refit_convergence_targets.R")) {

    stop("Cannot find project root. Please set working directory to project root:\n",

         "setwd(\"/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM\")")

  }

}



# Set up logging ------------------------------------------------------------------

log_file <- "output/diagnostics/refit_convergence_targets.log"

dir.create("output/diagnostics", recursive = TRUE, showWarnings = FALSE)

# Logging function that writes to both console and file with timestamp

log_message <- function(...) {

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  msg <- paste(..., sep = "")

  log_line <- paste0("[", timestamp, "] ", msg)

  cat(log_line, "\n")

  cat(log_line, "\n", file = log_file, append = TRUE)

  flush.console()

}



# Start log file

log_message("=", strrep("=", 80))

log_message("REFIT CONVERGENCE TARGETS SCRIPT STARTED")

log_message("=", strrep("=", 80))

log_message("Script started at: ", Sys.time())

log_message("Working directory: ", getwd())

log_message("")



# Load existing post-refit summary if it exists ----------------------------------

post_refit_path <- "output/diagnostics/convergence_summary_post_refit.csv"

completed_models <- character(0)

completed_results <- NULL

if (file.exists(post_refit_path)) {

  log_message("Found existing post-refit summary: ", post_refit_path)

  completed_results <- fread(post_refit_path)

  # Check which models already converged

  converged_already <- character(0)

  col_names_post <- names(completed_results)

  has_rhat <- "max_rhat" %in% col_names_post

  has_bulk_ratio <- any(c("min_bulk_ESS_ratio", "min_bulk_ess_ratio") %in% col_names_post)

  has_tail_ratio <- any(c("min_tail_ESS_ratio", "min_tail_ess_ratio") %in% col_names_post)

  has_bulk_ess <- "min_bulk_ess" %in% col_names_post

  has_tail_ess <- "min_tail_ess" %in% col_names_post

  

  if (has_rhat && (has_bulk_ratio || has_bulk_ess) && (has_tail_ratio || has_tail_ess)) {

    # Get the correct column names

    bulk_ratio_col <- if("min_bulk_ESS_ratio" %in% col_names_post) "min_bulk_ESS_ratio"

                     else if("min_bulk_ess_ratio" %in% col_names_post) "min_bulk_ess_ratio"

                     else NA_character_

    tail_ratio_col <- if("min_tail_ESS_ratio" %in% col_names_post) "min_tail_ESS_ratio"

                     else if("min_tail_ess_ratio" %in% col_names_post) "min_tail_ess_ratio"

                     else NA_character_

    

    # Calculate ESS ratios if we have total draws info but not ratios

    n_draws_per_chain <- 8000 - 4000  # iter - warmup

    n_total_draws <- 6 * n_draws_per_chain  # chains * draws per chain

    

    if (!is.na(bulk_ratio_col) && !is.na(tail_ratio_col)) {

      # We have ratio columns directly

      converged_already <- completed_results %>%

        mutate(

          bulk_ess_ratio = .data[[bulk_ratio_col]],

          tail_ess_ratio = .data[[tail_ratio_col]],

          converged = (max_rhat <= 1.01) & 

                     (bulk_ess_ratio >= 0.10) & 

                     (tail_ess_ratio >= 0.10)

        ) %>%

        filter(converged) %>%

        pull(model)

    } else if (has_bulk_ess && has_tail_ess) {

      # Calculate ratios from absolute ESS

      converged_already <- completed_results %>%

        mutate(

          bulk_ess_ratio = min_bulk_ess / n_total_draws,

          tail_ess_ratio = min_tail_ess / n_total_draws,

          converged = (max_rhat <= 1.01) & 

                     (bulk_ess_ratio >= 0.10) & 

                     (tail_ess_ratio >= 0.10)

        ) %>%

        filter(converged) %>%

        pull(model)

    } else {

      # Can't check convergence properly

      converged_already <- character(0)

    }

    

    completed_models <- completed_results$model

    log_message(sprintf("Loaded %d models from post-refit summary (%d already converged)", 

                       length(completed_models), length(converged_already)))

    if (length(converged_already) > 0) {

      log_message("  Converged models: ", paste(converged_already, collapse=", "))

    }

  } else {

    completed_models <- completed_results$model

    log_message(sprintf("Loaded %d models from post-refit summary (unable to verify convergence)", 

                       length(completed_models)))

  }

  log_message("")

} else {

  log_message("No existing post-refit summary found. Starting fresh.")

  log_message("")

}



# Identify models that need refitting --------------------------------------------

log_message("Identifying models that need refitting...")

conv_path <- "output/diagnostics/convergence_summary_all.csv"

if (file.exists(conv_path)) {

  log_message("  Loading convergence summary: ", conv_path)

  conv <- fread(conv_path)

  # Check column names and handle both uppercase/lowercase ESS variants

  col_names <- names(conv)

  bulk_col <- if("min_bulk_ESS_ratio" %in% col_names) "min_bulk_ESS_ratio" 

              else if("min_bulk_ess_ratio" %in% col_names) "min_bulk_ess_ratio" 

              else NA_character_

  tail_col <- if("min_tail_ESS_ratio" %in% col_names) "min_tail_ESS_ratio" 

              else if("min_tail_ess_ratio" %in% col_names) "min_tail_ess_ratio" 

              else NA_character_

  

  # Create flag based on available columns

  if (!is.na(bulk_col) && !is.na(tail_col)) {

    flagged <- conv %>%

      mutate(flag = (max_rhat > 1.01) |

                   (.data[[bulk_col]] < 0.10) |

                   (.data[[tail_col]] < 0.10) |

                   (n_divergences > 0)) %>%

      filter(flag) %>%

      pull(model)

  } else {

    log_message("  WARNING: Could not find ESS ratio columns. Using only R-hat and divergences.")

    flagged <- conv %>%

      mutate(flag = (max_rhat > 1.01) |

                   (n_divergences > 0)) %>%

      filter(flag) %>%

      pull(model)

  }

  log_message(sprintf("  Found %d flagged models from convergence summary", length(flagged)))

} else {

  # Fallback: refit the known shakier ones

  log_message("  Convergence summary not found. Using default flagged models.")

  flagged <- c("Model1_Baseline","Model2_Force","Model7_Task","Model8_Task_Additive")

  log_message(sprintf("  Using %d default flagged models", length(flagged)))

}

log_message("")



# Remove models that are already completed

if (length(completed_models) > 0) {

  skipped <- intersect(flagged, completed_models)

  to_refit <- setdiff(flagged, completed_models)

  log_message(sprintf("Skipping %d already-refitted models: %s", 

                     length(skipped),

                     paste(skipped, collapse=", ")))

  flagged <- to_refit

  log_message("")

}



if (length(flagged)==0) {

  log_message("No models need refitting. All flagged models are already done.")

  log_message("")

  log_message("=", strrep("=", 80))

  log_message("SCRIPT COMPLETED SUCCESSFULLY")

  log_message("=", strrep("=", 80))

  quit(save="no")

}



log_message("=", strrep("=", 80))

log_message(sprintf("STARTING REFITS: %d models to process", length(flagged)))

log_message("Models to refit: ", paste(flagged, collapse=", "))

log_message("=", strrep("=", 80))

log_message("")

log_message("⚠️  LIGHTER SETTINGS ENABLED TO PREVENT CRASHES:")

log_message("   - Using 2 chains instead of 6 (safer, but slower)")

log_message("   - Using 2 cores instead of 6 (leaves resources free)")

log_message("   - Using 6000 iterations instead of 8000 (still enough)")

log_message("   - 10 second pause between models (lets system recover)")

log_message("   - Aggressive memory cleanup after each model")

log_message("")

log_message("This will take longer but is much safer for your laptop.")

log_message("")

log_message("=", strrep("=", 80))

log_message("")



# Create initialization function from existing model
create_init_from_model <- function(fit) {
  # Extract posterior means as initialization
  fixef_vals <- fixef(fit)
  
  # Initialize function that returns a list
  init_func <- function() {
    init_list <- list()
    
    # Get parameter names from the model
    param_names <- rownames(fixef_vals)
    
    # Add each parameter with a small amount of noise
    for (param in param_names) {
      mean_val <- fixef_vals[param, "Estimate"]
      # Add small random noise (5% of the estimate)
      init_list[[param]] <- mean_val + rnorm(1, 0, abs(mean_val) * 0.05)
    }
    
    # Also add random effects if present
    ranef_vals <- ranef(fit)
    if (length(ranef_vals) > 0) {
      # brms will handle RE initialization automatically, but we can provide a function
      # that returns a list with the right structure
      for (group in names(ranef_vals)) {
        # For random effects, we provide a function that samples from the group means
        # This is handled automatically by brms, so we don't need to do much here
      }
    }
    
    init_list
  }
  
  init_func
}



refit_one <- function(model_name, model_index, total_models) {

  start_time <- Sys.time()

  

  log_message("")

  log_message("-", strrep("-", 80))

  log_message(sprintf("[%d/%d] STARTING REFIT: %s", model_index, total_models, model_name))

  log_message("-", strrep("-", 80))

  log_message("  Started at: ", format(start_time, "%Y-%m-%d %H:%M:%S"))

  

  path <- file.path("output/models", paste0(model_name, ".rds"))

  

  if (!file.exists(path)) {

    log_message("  ERROR: Missing model file: ", path)

    return(NULL)

  }

  

  log_message("  Model file: ", path)

  log_message("  File size: ", round(file.info(path)$size / 1024^2, 2), " MB")

  

  tryCatch({

    log_message("  Loading model from RDS...")

    load_start <- Sys.time()

    fit <- readRDS(path)

    load_time <- as.numeric(difftime(Sys.time(), load_start, units = "secs"))

    log_message(sprintf("  Model loaded in %.1f seconds", load_time))

    

    # Clean up any previous model data

    gc(verbose = FALSE)

    

    log_message("  Extracting initialization values from existing model...")

    # Create initialization function from existing model's posterior means

    init_func <- create_init_from_model(fit)

    log_message("  Initialization values extracted")

    

    # Free memory from original fit object (we'll reload if needed)

    # But keep it for now since update() might need it

    

    log_message("  Starting model refit with LIGHTER settings (to prevent crashes)...")

    log_message("    chains = 2, iter = 6000, warmup = 3000, cores = 2")

    log_message("    adapt_delta = 0.98, max_treedepth = 13")

    log_message("    Using existing model parameters as initialization")

    log_message("    NOTE: Lighter settings = slower but safer for your laptop")

    

    refit_start <- Sys.time()

    

    # Update with lighter NUTS settings to prevent crashes

    # Using fewer chains/cores/iterations but still enough for convergence

    fit2 <- update(

      fit,

      chains = 2, iter = 6000, warmup = 3000, cores = 2,

      control = list(adapt_delta = 0.98, max_treedepth = 13),

      init = init_func,

      backend = "cmdstanr",

      file = path,           # overwrite cached compiled model & draws

      file_refit = "always",  # force refit

      refresh = 500           # Less frequent output to reduce overhead

    )

    

    refit_time <- as.numeric(difftime(Sys.time(), refit_start, units = "mins"))

    log_message(sprintf("  ✓ Model refit completed in %.1f minutes", refit_time))

    

    log_message("  Extracting convergence diagnostics...")

    diag_start <- Sys.time()

    

    # Extract quick convergence summary using brms functions
    log_message("  Computing R-hat diagnostics...")
    rhat_vals <- rhat(fit2)
    max_rhat <- max(rhat_vals, na.rm=TRUE)
    
    log_message("  Computing ESS diagnostics...")
    ess_bulk_vals <- ess_bulk(fit2)
    ess_tail_vals <- ess_tail(fit2)
    
    # Handle empty or all-NA ESS values
    if (length(ess_bulk_vals) == 0 || all(is.na(ess_bulk_vals))) {
      min_bulk_ess <- NA_real_
      min_bulk_ess_ratio <- NA_real_
      log_message("    WARNING: No bulk ESS values available")
    } else {
      min_bulk_ess <- min(ess_bulk_vals, na.rm=TRUE)
    }
    
    if (length(ess_tail_vals) == 0 || all(is.na(ess_tail_vals))) {
      min_tail_ess <- NA_real_
      min_tail_ess_ratio <- NA_real_
      log_message("    WARNING: No tail ESS values available")
    } else {
      min_tail_ess <- min(ess_tail_vals, na.rm=TRUE)
    }
    
    # Calculate ESS ratios
    n_draws <- ndraws(fit2)
    if (!is.na(min_bulk_ess)) {
      min_bulk_ess_ratio <- min_bulk_ess / n_draws
    }
    if (!is.na(min_tail_ess)) {
      min_tail_ess_ratio <- min_tail_ess / n_draws
    }
    
    # Check divergences
    log_message("  Checking for divergent transitions...")
    nuts_diag <- nuts_params(fit2)
    n_divergences <- 0
    if (!is.null(nuts_diag) && "divergent__" %in% nuts_diag$Parameter) {
      n_divergences <- sum(nuts_diag$Value[nuts_diag$Parameter == "divergent__"], 
                          na.rm = TRUE)
    }
    
    diag_time <- as.numeric(difftime(Sys.time(), diag_start, units = "secs"))
    log_message(sprintf("  Diagnostics extracted in %.1f seconds", diag_time))

    

    # Check convergence (handle NA values)
    converged <- (max_rhat <= 1.01) & 

                 (ifelse(is.na(min_bulk_ess_ratio), FALSE, min_bulk_ess_ratio >= 0.10)) & 

                 (ifelse(is.na(min_tail_ess_ratio), FALSE, min_tail_ess_ratio >= 0.10)) &

                 (n_divergences == 0)

    

    total_time <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))

    

    log_message("  Convergence diagnostics:")

    log_message(sprintf("    Max R-hat: %.4f %s", max_rhat, ifelse(max_rhat <= 1.01, "✓", "✗")))

    log_message(sprintf("    Min bulk ESS ratio: %.4f %s", min_bulk_ess_ratio, 

                       ifelse(min_bulk_ess_ratio >= 0.10, "✓", "✗")))

    log_message(sprintf("    Min tail ESS ratio: %.4f %s", min_tail_ess_ratio, 

                       ifelse(min_tail_ess_ratio >= 0.10, "✓", "✗")))

    log_message(sprintf("    Divergences: %d %s", n_divergences, 

                       ifelse(n_divergences == 0, "✓", "✗")))

    log_message(sprintf("  Status: %s", ifelse(converged, "CONVERGED ✓", "STILL HAS ISSUES ✗")))

    log_message(sprintf("  Total time: %.1f minutes", total_time))

    log_message(sprintf("  Completed at: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))

    

    result <- data.frame(model=model_name, max_rhat=max_rhat,

               min_bulk_ess=min_bulk_ess, min_tail_ess=min_tail_ess,

               min_bulk_ess_ratio=min_bulk_ess_ratio,

               min_tail_ess_ratio=min_tail_ess_ratio,

               n_divergences=n_divergences,

               refit_time_minutes=refit_time,

               total_time_minutes=total_time,

               converged=converged,

               completed_at=as.character(format(Sys.time(), "%Y-%m-%d %H:%M:%S")),

               stringsAsFactors = FALSE)

    

    # Clean up memory after each model

    log_message("  Cleaning up memory...")

    rm(fit2, rhat_vals, ess_bulk_vals, ess_tail_vals, nuts_diag, 

       max_rhat, min_bulk_ess, min_tail_ess, min_bulk_ess_ratio, 

       min_tail_ess_ratio, n_divergences, converged, n_draws, total_time)

    gc(verbose = FALSE)

    

    result

    

  }, error = function(e) {

    error_time <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))

    log_message("  ✗ ERROR during refit:")

    log_message("    Error message: ", e$message)

    log_message("    Error occurred after: ", sprintf("%.1f minutes", error_time))

    log_message(sprintf("    Failed at: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))

    

    data.frame(model=model_name, max_rhat=NA_real_,

               min_bulk_ess=NA_real_, min_tail_ess=NA_real_,

               min_bulk_ess_ratio=NA_real_,

               min_tail_ess_ratio=NA_real_,

               n_divergences=NA_real_,

               refit_time_minutes=NA_real_,

               total_time_minutes=error_time,

               converged=FALSE,

               completed_at=as.character(format(Sys.time(), "%Y-%m-%d %H:%M:%S")),

               stringsAsFactors = FALSE)

  })

}



# Refit models --------------------------------------------------------------------

script_start_time <- Sys.time()

log_message("")

log_message("=", strrep("=", 80))

log_message(sprintf("BEGINNING MODEL REFITS AT %s", format(script_start_time, "%Y-%m-%d %H:%M:%S")))

log_message("=", strrep("=", 80))

log_message("")



res_list <- list()

for (i in seq_along(flagged)) {

  model_name <- flagged[i]

  result <- refit_one(model_name, i, length(flagged))

  if (!is.null(result)) {

    res_list[[length(res_list) + 1]] <- result

    # Save progress after each model

    if (length(res_list) > 0) {

      temp_res <- bind_rows(res_list)

      if (!is.null(completed_results)) {

        # Ensure completed_at is character in both data frames to avoid type mismatch

        if ("completed_at" %in% names(completed_results)) {

          completed_results$completed_at <- as.character(completed_results$completed_at)

        }

        if ("completed_at" %in% names(temp_res)) {

          temp_res$completed_at <- as.character(temp_res$completed_at)

        }

        

        temp_res <- bind_rows(completed_results, temp_res) %>%

          group_by(model) %>%

          slice_tail(n = 1) %>%

          ungroup()

      }

      fwrite(temp_res, post_refit_path)

      log_message("")

      log_message(sprintf("  Progress saved: %d/%d models completed (%.1f%%)", 

                         length(res_list), length(flagged), 

                         100 * length(res_list) / length(flagged)))

    }

  }

  

  # Pause between models to let system recover and prevent crashes

  if (i < length(flagged)) {

    log_message("")

    log_message("  Pausing 10 seconds before next model to let system recover...")

    Sys.sleep(10)

    gc(verbose = FALSE)  # Force garbage collection

    log_message("  Continuing to next model...")

  }

  

  log_message("")

}



# Combine results

if (length(res_list) > 0) {

  res <- dplyr::bind_rows(res_list)

  

  # Combine with existing results if any

  if (!is.null(completed_results)) {

    # Bind new results after old ones, then keep last (most recent) per model

    res <- bind_rows(completed_results, res) %>%

      group_by(model) %>%

      slice_tail(n = 1) %>%

      ungroup()

  }

} else {

  # No new results, use existing if available

  log_message("No new models were refitted in this run.")

  if (!is.null(completed_results)) {

    res <- completed_results

  } else {

    res <- data.frame()

  }

}



# Save final results

dir.create("output/diagnostics", recursive = TRUE, showWarnings = FALSE)

fwrite(res, post_refit_path)

script_total_time <- as.numeric(difftime(Sys.time(), script_start_time, units = "mins"))

log_message("")

log_message("=", strrep("=", 80))

log_message("REFITTING COMPLETE")

log_message("=", strrep("=", 80))

log_message("")

log_message("Results saved to: ", post_refit_path)

log_message("Total models processed in this run: ", length(res_list))

log_message("Total models in summary file: ", nrow(res))

log_message("")

# Count converged models

if (nrow(res) > 0 && "converged" %in% names(res)) {

  n_converged <- sum(res$converged, na.rm = TRUE)

  log_message(sprintf("Converged models: %d/%d (%.1f%%)", 

                     n_converged, nrow(res), 

                     100 * n_converged / nrow(res)))

  if (n_converged < nrow(res)) {

    still_issues <- res %>% filter(!converged) %>% pull(model)

    log_message("Models still with issues: ", paste(still_issues, collapse=", "))

  }

  log_message("")

}

log_message(sprintf("Total script runtime: %.1f minutes", script_total_time))

log_message("Completed at: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))

log_message("")

log_message("=", strrep("=", 80))

log_message("SCRIPT COMPLETED SUCCESSFULLY")

log_message("=", strrep("=", 80))

log_message("")

# -------------------------------------------------------------------------



# Now run this script from project root:

# source('scripts/checks/refit_convergence_targets.R')
