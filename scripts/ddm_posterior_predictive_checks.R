# =========================================================================
# DDM POSTERIOR PREDICTIVE CHECKS (PPCs)
# =========================================================================
# DDM-specific PPCs: QP plots and Conditional Accuracy Functions
# =========================================================================

library(brms)
library(dplyr)
library(readr)
library(ggplot2)
library(bayesplot)
library(purrr)
library(tidyr)
library(posterior)  # For as_draws_df()

cat("\n")
cat("================================================================================\n")
cat("DDM POSTERIOR PREDICTIVE CHECKS\n")
cat("================================================================================\n")

# Helper function for timestamps (define early)
timestamp <- function() format(Sys.time(), "[%H:%M:%S]")

ppc_start_time <- Sys.time()
cat("Started:", format(ppc_start_time, "%Y-%m-%d %H:%M:%S"), "\n")
cat("Configuration: 150 draws per model (good quality/speed balance)\n")
cat("Expected: ~15-25 minutes per model\n")
cat("================================================================================\n\n")

# Set working directory
if (!file.exists("output/models")) {
  if (file.exists("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")) {
    setwd("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")
  }
}

# Create output directories
dir.create("output/ppc", recursive = TRUE, showWarnings = FALSE)

# =========================================================================
# HELPER FUNCTIONS
# =========================================================================

# Function to extract RT quantiles from posterior predictions
get_rt_quantiles <- function(rt_vector, quantiles = c(0.1, 0.3, 0.5, 0.7, 0.9)) {
  quantile(rt_vector, quantiles, na.rm = TRUE)
}

# Function to compute conditional accuracy function (CAF)
compute_caf <- function(data, drift_bins = 10) {
  # Estimate drift for each trial (simplified - using predicted values)
  # In practice, you'd extract from posterior samples
  data$drift_bin <- cut(data$rt, breaks = drift_bins, labels = FALSE)
  
  data %>%
    group_by(drift_bin) %>%
    summarise(
      mean_accuracy = mean(decision, na.rm = TRUE),
      n_trials = n(),
      mean_rt = mean(rt, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    filter(!is.na(drift_bin))
}

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

# Apply filters (same as analysis)
ddm_data <- data %>%
  filter(rt >= 0.25 & rt <= 3.0) %>%
  mutate(
    response = as.integer(accuracy),
    effort_condition = as.factor(effort_condition),
    difficulty_level = as.factor(difficulty_level),
    subject_id = as.factor(subject_id),
    task = as.factor(task),
    decision = ifelse(accuracy == 1, 1, 0)
  )

cat(timestamp(), "✓ Data loaded:", nrow(ddm_data), "trials\n\n")
flush.console()

# =========================================================================
# MAIN MODELS TO CHECK
# =========================================================================

main_models <- c(
  "Model1_Baseline",
  "Model2_Force",
  "Model3_Difficulty",
  "Model4_Additive",
  "Model5_Interaction",
  "Model7_Task",
  "Model8_Task_Additive",
  "Model9_Task_Intx",
  "Model10_Param_v_bs"
)

ppc_results <- list()

# =========================================================================
# PPC FOR EACH MODEL
# =========================================================================

for (model_name in main_models) {
    cat("\n")
    cat("================================================================================\n")
    cat("PROCESSING:", model_name, "\n")
    cat("================================================================================\n")
    cat(timestamp(), "Starting", model_name, "\n\n")
  
  model_file <- paste0("output/models/", model_name, ".rds")
  
  if (!file.exists(model_file)) {
    cat("⚠️  Model file not found, skipping:", model_file, "\n\n")
    next
  }
  
  model_start_time <- Sys.time()
  
  tryCatch({
    # Load model
    cat(timestamp(), "Loading model...\n")
    flush.console()
    model <- readRDS(model_file)
    cat(timestamp(), "✓ Model loaded\n")
    flush.console()
    
    # Get model data
    model_data <- model$data
    
    # =====================================================================
    # 1. GENERATE POSTERIOR PREDICTIVE SAMPLES
    # =====================================================================
    
    cat(timestamp(), "Generating posterior predictive samples...\n")
    flush.console()
    
    # Use 150 draws - good balance of quality and speed
    # 100 is minimum for reliable PPCs, 150 gives better estimates
    n_draws <- 150
    
    n_trials <- nrow(model_data)
    total_predictions <- n_trials * n_draws
    
    cat(timestamp(), "Using", n_draws, "posterior draws\n")
    cat(timestamp(), "  Trials:", format(n_trials, big.mark = ","), "\n")
    cat(timestamp(), "  Total predictions:", format(total_predictions, big.mark = ","), "\n")
    cat(timestamp(), "  Estimated time: 15-25 minutes per model\n")
    cat(timestamp(), "  Status: Starting posterior_predict()...\n")
    flush.console()
    
    pp_start_time <- Sys.time()
    
    # Generate predictions with progress monitoring
    cat(timestamp(), "  [This is the slowest step - generating RT samples from Wiener distribution]\n")
    cat(timestamp(), "  [You'll see this message for 15-20 minutes - this is NORMAL]\n")
    cat(timestamp(), "  [Be patient - no output here means it's working!]\n")
    flush.console()
    
    pp_samples <- posterior_predict(
      model,
      draws = n_draws,
      summary = FALSE
    )
    
    pp_elapsed <- difftime(Sys.time(), pp_start_time, units = "mins")
    
    cat(timestamp(), "✓ Generated", n_draws, "posterior predictive samples\n")
    cat(timestamp(), "  Time elapsed:", round(as.numeric(pp_elapsed), 1), "minutes\n")
    cat(timestamp(), "  Sample matrix size:", dim(pp_samples)[1], "draws ×", dim(pp_samples)[2], "trials\n")
    flush.console()
    
    # =====================================================================
    # 2. QUANTILE-PROBABILITY (QP) PLOTS
    # =====================================================================
    
    cat(timestamp(), "Computing QP plots (quantiles: 10/30/50/70/90)...\n")
    flush.console()
    
    # Get empirical RT quantiles by decision
    empirical_quantiles <- model_data %>%
      group_by(decision) %>%
      summarise(
        q10 = quantile(rt, 0.1, na.rm = TRUE),
        q30 = quantile(rt, 0.3, na.rm = TRUE),
        q50 = quantile(rt, 0.5, na.rm = TRUE),
        q70 = quantile(rt, 0.7, na.rm = TRUE),
        q90 = quantile(rt, 0.9, na.rm = TRUE),
        .groups = "drop"
      )
    
    # Get predicted RT quantiles from posterior samples
    # Convert pp_samples matrix to long format for easier processing
    pred_quantiles_list <- list()
    
    # Use subset of draws for QP computation (50 is sufficient for stable quantiles)
    n_qp_draws <- min(50, n_draws)
    
    cat(timestamp(), "  Computing QP statistics from", n_qp_draws, "draws\n")
    cat(timestamp(), "  Progress: [", sep = "", append = FALSE)
    flush.console()
    
    for (i in 1:n_qp_draws) {
      # Progress indicator every 10%
      if (i %% max(1, floor(n_qp_draws / 10)) == 0) {
        cat(".", sep = "", append = TRUE)
        flush.console()
      }
      pred_rts <- pp_samples[i, ]
      pred_decisions <- model_data$decision  # Use observed decisions for matching
      
      pred_df <- data.frame(
        rt = pred_rts,
        decision = pred_decisions,
        draw = i
      )
      
      pred_quant <- pred_df %>%
        group_by(decision) %>%
        summarise(
          q10 = quantile(rt, 0.1, na.rm = TRUE),
          q30 = quantile(rt, 0.3, na.rm = TRUE),
          q50 = quantile(rt, 0.5, na.rm = TRUE),
          q70 = quantile(rt, 0.7, na.rm = TRUE),
          q90 = quantile(rt, 0.9, na.rm = TRUE),
          .groups = "drop"
        ) %>%
        mutate(draw = i)
      
      pred_quantiles_list[[i]] <- pred_quant
    }
    
    cat("] Done\n")
    flush.console()
    
    pred_quantiles <- bind_rows(pred_quantiles_list)
    
    cat(timestamp(), "✓ QP statistics computed\n")
    flush.console()
    
    # Create QP plot
    qp_data <- bind_rows(
      empirical_quantiles %>%
        mutate(type = "Empirical") %>%
        select(decision, q10, q30, q50, q70, q90, type),
      pred_quantiles %>%
        group_by(decision) %>%
        summarise(
          q10 = mean(q10, na.rm = TRUE),
          q30 = mean(q30, na.rm = TRUE),
          q50 = mean(q50, na.rm = TRUE),
          q70 = mean(q70, na.rm = TRUE),
          q90 = mean(q90, na.rm = TRUE),
          .groups = "drop"
        ) %>%
        mutate(type = "Predicted")
    ) %>%
      pivot_longer(cols = c(q10, q30, q50, q70, q90),
                   names_to = "quantile",
                   values_to = "rt_value") %>%
      mutate(
        quantile_prob = case_when(
          quantile == "q10" ~ 0.1,
          quantile == "q30" ~ 0.3,
          quantile == "q50" ~ 0.5,
          quantile == "q70" ~ 0.7,
          quantile == "q90" ~ 0.9
        ),
        decision_label = ifelse(decision == 1, "Correct", "Incorrect")
      )
    
    # QP Plot
    qp_plot <- ggplot(qp_data, aes(x = quantile_prob, y = rt_value, 
                                   color = type, linetype = type)) +
      geom_line(size = 1.2) +
      geom_point(size = 2) +
      facet_wrap(~ decision_label, scales = "free_y") +
      labs(
        title = paste0("QP Plot: ", model_name),
        subtitle = "RT Quantiles (10/30/50/70/90) by Decision",
        x = "Quantile Probability",
        y = "RT (seconds)",
        color = "Type",
        linetype = "Type"
      ) +
      theme_bw() +
      theme(
        plot.title = element_text(size = 14, face = "bold"),
        strip.text = element_text(size = 12)
      ) +
      scale_color_manual(values = c("Empirical" = "black", "Predicted" = "red"))
    
    # =====================================================================
    # 3. CONDITIONAL ACCURACY FUNCTION (CAF)
    # =====================================================================
    
    cat(timestamp(), "Computing Conditional Accuracy Function (by drift bins)...\n")
    flush.console()
    
    # Extract posterior drift estimates using fitted() with dpar="mu" for drift
    # For wiener family, drift is the main parameter (mu)
    fitted_drift_samples <- fitted(model, summary = FALSE, dpar = NULL, resp = NULL)
    
    # For wiener models, fitted() returns drift (mu) predictions
    # Get posterior mean drift for each trial
    if (is.array(fitted_drift_samples) && length(dim(fitted_drift_samples)) == 2) {
      trial_drift_means <- apply(fitted_drift_samples, 2, mean, na.rm = TRUE)
    } else {
      # Fallback: extract drift from posterior draws
      post_draws <- as_draws_df(model)
      drift_intercept <- mean(post_draws$Intercept, na.rm = TRUE)
      trial_drift_means <- rep(drift_intercept, nrow(model_data))
      
      # Add fixed effects if available
      if ("difficulty_level" %in% names(model_data)) {
        diff_params <- post_draws %>% select(matches("difficulty_level"))
        if (ncol(diff_params) > 0) {
          diff_means <- colMeans(diff_params, na.rm = TRUE)
          # Simple approximation: add average difficulty effect
          trial_drift_means <- trial_drift_means + mean(diff_means, na.rm = TRUE)
        }
      }
    }
    
    # Bin by estimated drift (10 bins)
    drift_bins <- 10
    drift_quantiles <- quantile(trial_drift_means, 
                                probs = seq(0, 1, length.out = drift_bins + 1), 
                                na.rm = TRUE)
    
    model_data$drift_bin <- cut(trial_drift_means, 
                                breaks = drift_quantiles,
                                labels = FALSE,
                                include.lowest = TRUE)
    
    # Empirical CAF: Accuracy in each drift bin
    empirical_caf <- model_data %>%
      filter(!is.na(drift_bin)) %>%
      group_by(drift_bin) %>%
      summarise(
        mean_accuracy = mean(decision, na.rm = TRUE),
        mean_drift = mean(trial_drift_means[drift_bin == first(drift_bin)], na.rm = TRUE),
        mean_rt = mean(rt, na.rm = TRUE),
        n_trials = n(),
        .groups = "drop"
      ) %>%
      mutate(type = "Empirical")
    
    # Predicted CAF: Bin posterior predictive RTs as proxy for drift
    # Faster RTs indicate higher drift (standard DDM relationship)
    cat(timestamp(), "  Extracting posterior drift estimates...\n")
    flush.console()
    
    fitted_drift_samples <- fitted(model, summary = FALSE, dpar = NULL, resp = NULL)
    
    if (is.array(fitted_drift_samples) && length(dim(fitted_drift_samples)) == 2) {
      trial_drift_means <- apply(fitted_drift_samples, 2, mean, na.rm = TRUE)
      cat(timestamp(), "  ✓ Extracted drift estimates from fitted()\n")
    } else {
      # Fallback: use posterior draws
      cat(timestamp(), "  Using fallback method (posterior draws)...\n")
      post_draws <- as_draws_df(model)
      drift_intercept <- mean(post_draws$Intercept, na.rm = TRUE)
      trial_drift_means <- rep(drift_intercept, nrow(model_data))
      cat(timestamp(), "  ✓ Computed drift estimates\n")
    }
    flush.console()
    
    cat(timestamp(), "  Computing predicted RT medians...\n")
    flush.console()
    
    pred_rt_medians <- apply(pp_samples[1:min(100, n_draws), ], 2, median, na.rm = TRUE)
    
    # Create drift proxy from predicted RTs (inverse: fastest = highest drift)
    pred_drift_proxy <- -pred_rt_medians  # Negative RT as drift proxy (faster = more positive)
    pred_drift_quantiles <- quantile(pred_drift_proxy,
                                    probs = seq(0, 1, length.out = drift_bins + 1),
                                    na.rm = TRUE)
    
    pred_data_binned <- model_data %>%
      mutate(
        pred_rt = pred_rt_medians,
        pred_drift_proxy = pred_drift_proxy,
        drift_bin = cut(pred_drift_proxy,
                       breaks = pred_drift_quantiles,
                       labels = FALSE,
                       include.lowest = TRUE)
      )
    
    pred_caf <- pred_data_binned %>%
      filter(!is.na(drift_bin)) %>%
      group_by(drift_bin) %>%
      summarise(
        mean_accuracy = mean(decision, na.rm = TRUE),
        mean_drift = NA,  # Proxy not directly interpretable
        mean_rt = mean(pred_rt, na.rm = TRUE),
        n_trials = n(),
        .groups = "drop"
      ) %>%
      mutate(type = "Predicted")
    
    caf_data <- bind_rows(empirical_caf, pred_caf)
    
    # CAF Plot
    caf_plot <- ggplot(caf_data %>% filter(!is.na(drift_bin)), 
                       aes(x = drift_bin, y = mean_accuracy, 
                           color = type, linetype = type)) +
      geom_line(size = 1.2) +
      geom_point(size = 2) +
      labs(
        title = paste0("Conditional Accuracy Function: ", model_name),
        subtitle = "Accuracy as Function of Predicted Drift Bins (from posterior estimates)",
        x = "Drift Bin (1=low drift, 10=high drift)",
        y = "Accuracy Rate",
        color = "Type",
        linetype = "Type"
      ) +
      theme_bw() +
      theme(
        plot.title = element_text(size = 14, face = "bold")
      ) +
      scale_color_manual(values = c("Empirical" = "black", "Predicted" = "red")) +
      scale_y_continuous(limits = c(0, 1)) +
      scale_x_continuous(breaks = 1:10)
    
    # =====================================================================
    # 4. POSTERIOR PREDICTIVE RT DISTRIBUTIONS BY CONDITION
    # =====================================================================
    
    cat(timestamp(), "Creating RT distribution plots by condition...\n")
    flush.console()
    
    # Identify key conditions for this model
    if ("effort_condition" %in% names(model_data) && 
        "difficulty_level" %in% names(model_data)) {
      
      # Create condition combinations
      model_data$condition <- paste0(
        ifelse("effort_condition" %in% names(model_data), 
               as.character(model_data$effort_condition), ""),
        ifelse("difficulty_level" %in% names(model_data),
               paste0("_", as.character(model_data$difficulty_level)), "")
      )
      
      # Sample predictions for plot
      sample_pred <- as.vector(pp_samples[1:50, ])  # Sample 50 draws
      empirical_rts <- rep(model_data$rt, 50)
      condition_rep <- rep(model_data$condition, 50)
      
      rt_dist_data <- data.frame(
        rt = c(empirical_rts, sample_pred),
        type = rep(c("Empirical", "Predicted"), each = length(empirical_rts)),
        condition = rep(condition_rep, 2)
      )
      
      rt_dist_plot <- ggplot(rt_dist_data, aes(x = rt, fill = type, color = type)) +
        geom_density(alpha = 0.5) +
        facet_wrap(~ condition, scales = "free_y") +
        labs(
          title = paste0("RT Distributions by Condition: ", model_name),
          x = "RT (seconds)",
          y = "Density",
          fill = "Type",
          color = "Type"
        ) +
        theme_bw() +
        theme(
          plot.title = element_text(size = 14, face = "bold")
        ) +
        scale_fill_manual(values = c("Empirical" = "black", "Predicted" = "red")) +
        scale_color_manual(values = c("Empirical" = "black", "Predicted" = "red"))
      
    } else {
      rt_dist_plot <- NULL
    }
    
    # =====================================================================
    # 5. DEVIATION CHECKS
    # =====================================================================
    
    cat(timestamp(), "Checking for systematic deviations...\n")
    flush.console()
    
    deviations <- list()
    
    # Check 1: Underpredicted long RTs
    empirical_long_rt <- quantile(model_data$rt, 0.9, na.rm = TRUE)
    pred_long_rt <- quantile(as.vector(pp_samples), 0.9, na.rm = TRUE)
    
    if (pred_long_rt < 0.9 * empirical_long_rt) {
      deviations$underpredicted_long_rt <- TRUE
      cat("  ⚠️  Warning: Model underpredicts long RTs\n")
    }
    
    # Check 2: Misfit around boundary (decision = 0.5 equivalent)
    # Check accuracy in middle RT bins
    middle_rt_bin <- model_data %>%
      mutate(rt_bin = ntile(rt, 10)) %>%
      filter(rt_bin == 5) %>%
      summarise(mean_acc = mean(decision, na.rm = TRUE)) %>%
      pull(mean_acc)
    
    if (abs(middle_rt_bin - 0.5) > 0.2) {
      deviations$boundary_misfit <- TRUE
      cat("  ⚠️  Warning: Possible boundary misfit (middle RT accuracy:", 
          round(middle_rt_bin, 2), ")\n")
    }
    
    # Check 3: QP plot deviations
    qp_deviation <- qp_data %>%
      group_by(decision, quantile) %>%
      summarise(
        emp_rt = rt_value[type == "Empirical"],
        pred_rt = rt_value[type == "Predicted"],
        deviation = abs(emp_rt - pred_rt) / emp_rt,
        .groups = "drop"
      )
    
    large_deviations <- qp_deviation %>%
      filter(deviation > 0.15)  # >15% deviation
    
    if (nrow(large_deviations) > 0) {
      deviations$qp_deviations <- TRUE
      cat("  ⚠️  Warning:", nrow(large_deviations), 
          "quantile-probability points show >15% deviation\n")
    }
    
    if (length(deviations) == 0) {
      cat("  ✓ No major systematic deviations detected\n")
    }
    
    # =====================================================================
    # 6. SAVE PLOTS
    # =====================================================================
    
    cat(timestamp(), "Saving plots...\n")
    flush.console()
    
    # Save QP plot
    qp_file <- paste0("output/ppc/", model_name, "_qp_plot.pdf")
    ggsave(qp_file, qp_plot, width = 10, height = 6, units = "in")
    cat(timestamp(), "  ✓ Saved:", qp_file, "\n")
    flush.console()
    
    # Save CAF plot
    caf_file <- paste0("output/ppc/", model_name, "_caf_plot.pdf")
    ggsave(caf_file, caf_plot, width = 8, height = 6, units = "in")
    cat(timestamp(), "  ✓ Saved:", caf_file, "\n")
    flush.console()
    
    # Save RT distribution plot if created
    if (!is.null(rt_dist_plot)) {
      rt_file <- paste0("output/ppc/", model_name, "_rt_distribution.pdf")
      ggsave(rt_file, rt_dist_plot, width = 12, height = 8, units = "in")
      cat(timestamp(), "  ✓ Saved:", rt_file, "\n")
      flush.console()
    }
    
    # Store results
    ppc_results[[model_name]] <- list(
      deviations = deviations,
      qp_deviation_summary = qp_deviation,
      empirical_long_rt = empirical_long_rt,
      pred_long_rt = pred_long_rt
    )
    
    model_end_time <- Sys.time()
    model_duration <- difftime(model_end_time, model_start_time, units = "mins")
    
    cat(timestamp(), "✓", model_name, "complete\n")
    cat(timestamp(), "  Total time for this model:", round(as.numeric(model_duration), 1), "minutes\n\n")
    flush.console()
    
  }, error = function(e) {
    cat(timestamp(), "❌ Error processing", model_name, ":", e$message, "\n\n")
    flush.console()
  })
}

# =========================================================================
# SUMMARY REPORT
# =========================================================================

cat("\n")
cat("================================================================================\n")
cat("PPC SUMMARY\n")
cat("================================================================================\n")
cat(timestamp(), "Generating summary...\n\n")

# Create deviation summary
deviation_summary <- data.frame(
  model = character(),
  underpredicted_long_rt = logical(),
  boundary_misfit = logical(),
  qp_deviations = logical(),
  stringsAsFactors = FALSE
)

for (model_name in names(ppc_results)) {
  devs <- ppc_results[[model_name]]$deviations
  deviation_summary <- rbind(deviation_summary, data.frame(
    model = model_name,
    underpredicted_long_rt = ifelse(is.null(devs$underpredicted_long_rt), FALSE, TRUE),
    boundary_misfit = ifelse(is.null(devs$boundary_misfit), FALSE, TRUE),
    qp_deviations = ifelse(is.null(devs$qp_deviations), FALSE, TRUE),
    stringsAsFactors = FALSE
  ))
}

print(deviation_summary)

# Save summary
write.csv(deviation_summary,
          file = "output/ppc/ppc_deviation_summary.csv",
          row.names = FALSE)

cat(timestamp(), "✓ Summary saved to: output/ppc/ppc_deviation_summary.csv\n\n")

ppc_end_time <- Sys.time()
total_duration <- difftime(ppc_end_time, ppc_start_time, units = "mins")

cat("================================================================================\n")
cat("PPC COMPLETE\n")
cat("================================================================================\n")
cat("Completed:", format(ppc_end_time, "%Y-%m-%d %H:%M:%S"), "\n")
cat("Total duration:", round(as.numeric(total_duration), 1), "minutes (", 
    round(as.numeric(total_duration)/60, 2), "hours)\n")
cat("================================================================================\n\n")
cat("All plots saved to: output/ppc/\n")
cat("  - *_qp_plot.pdf (Quantile-Probability plots)\n")
cat("  - *_caf_plot.pdf (Conditional Accuracy Functions)\n")
cat("  - *_rt_distribution.pdf (RT distributions by condition)\n\n")

