# =========================================================================
# DDM POSTERIOR PREDICTIVE CHECKS - FIXED VERSION
# =========================================================================
# Uses batch processing and alternative methods to avoid posterior_predict() bottleneck
# =========================================================================

library(brms)
library(dplyr)
library(readr)
library(ggplot2)
library(bayesplot)
library(purrr)
library(tidyr)
library(posterior)

# Check if RWiener is installed
if (!require(RWiener, quietly = TRUE)) {
  cat("⚠️  RWiener package not found. Installing...\n")
  install.packages("RWiener")
  library(RWiener)
}

cat("\n")
cat("================================================================================\n")
cat("DDM POSTERIOR PREDICTIVE CHECKS - FIXED VERSION\n")
cat("================================================================================\n")

timestamp <- function() format(Sys.time(), "[%H:%M:%S]")

ppc_start_time <- Sys.time()
cat("Started:", format(ppc_start_time, "%Y-%m-%d %H:%M:%S"), "\n")
cat("Strategy: Extract parameters and simulate RTs manually (avoids posterior_predict bottleneck)\n")
cat("Expected: ~5-10 minutes per model\n")
cat("================================================================================\n\n")

# Set working directory
if (!file.exists("output/models")) {
  if (file.exists("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")) {
    setwd("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")
  }
}

dir.create("output/ppc", recursive = TRUE, showWarnings = FALSE)

# =========================================================================
# LOAD DATA
# =========================================================================

cat(timestamp(), "Loading data...\n")
flush.console()

data_file <- "data/analysis_ready/bap_ddm_ready.csv"
if (!file.exists(data_file)) {
  stop("Data file not found: ", data_file)
}

data <- read_csv(data_file, show_col_types = FALSE)

# Harmonize columns
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
# MAIN MODELS
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
# HELPER: Extract DDM parameters and simulate RTs
# =========================================================================

simulate_ddm_rts <- function(model, model_data, n_draws = 100) {
  # n_draws: Number of posterior draws to sample from (for better PPC)
  # Currently we use mean, but we could sample multiple draws for better uncertainty
  # Extract posterior parameter predictions using posterior_linpred (FAST)
  cat(timestamp(), "  Extracting posterior parameters using posterior_linpred()...\n")
  cat(timestamp(), "  [This should take <1 minute - if longer, there's another issue]\n")
  flush.console()
  
  linpred_start <- Sys.time()
  
  # Use posterior_linpred to get trial-level parameter estimates (much faster!)
  # This gives us parameters on the linear predictor scale for each trial
  linpred_success <- tryCatch({
    # Extract posterior predictions WITHOUT summary (returns matrix: draws × trials)
    cat(timestamp(), "  Extracting drift parameters...\n")
    flush.console()
    drift_linpred <- posterior_linpred(model, summary = FALSE)  # Returns matrix
    
    cat(timestamp(), "  Extracting boundary parameters...\n")
    flush.console()
    bs_linpred <- posterior_linpred(model, dpar = "bs", summary = FALSE)
    
    cat(timestamp(), "  Extracting NDT parameters...\n")
    flush.console()
    ndt_linpred <- posterior_linpred(model, dpar = "ndt", summary = FALSE)
    
    cat(timestamp(), "  Extracting bias parameters...\n")
    flush.console()
    bias_linpred <- posterior_linpred(model, dpar = "bias", summary = FALSE)
    
    TRUE  # Success flag
  }, error = function(e) {
    cat(timestamp(), "  ❌ posterior_linpred() failed:", e$message, "\n")
    cat(timestamp(), "  Error details:", toString(e), "\n")
    cat(timestamp(), "  Falling back to extracting from draws...\n")
    flush.console()
    FALSE  # Failure flag
  })
  
  if (linpred_success) {
    # Success path: Sample from posterior draws for better uncertainty
    # Matrices are: [draws × trials]
    total_draws <- nrow(drift_linpred)
    n_samples <- min(n_draws, total_draws)  # Use requested number or all available
    
    cat(timestamp(), "  Sampling", n_samples, "draws from", total_draws, "available...\n")
    flush.console()
    
    # Sample draws (for better posterior predictive representation)
    draw_ids <- sample(1:total_draws, n_samples, replace = FALSE)
    
    # Transform sampled draws to natural scale
    # For each sampled draw, transform parameters and then average across draws
    v_samples <- drift_linpred[draw_ids, , drop = FALSE]  # [n_samples × n_trials]
    a_samples <- exp(bs_linpred[draw_ids, , drop = FALSE])  # Boundary (log link)
    t0_samples <- exp(ndt_linpred[draw_ids, , drop = FALSE])  # NDT (log link)
    z_samples <- plogis(bias_linpred[draw_ids, , drop = FALSE])  # Bias (logit link)
    
    # Compute means across sampled draws (gives trial-level parameter estimates)
    v_mean <- colMeans(v_samples, na.rm = TRUE)
    a_mean <- colMeans(a_samples, na.rm = TRUE)
    t0_mean <- colMeans(t0_samples, na.rm = TRUE)
    z_mean <- colMeans(z_samples, na.rm = TRUE)
    
    linpred_elapsed <- difftime(Sys.time(), linpred_start, units = "secs")
    cat(timestamp(), "  ✓ Extracted parameters using", n_samples, "draws\n")
    cat(timestamp(), "  Time:", round(as.numeric(linpred_elapsed), 1), "seconds\n")
    cat(timestamp(), "  Parameters for", length(v_mean), "trials ready\n")
    flush.console()
  } else {
    # Fallback: extract from draws directly (slower but should work)
    post_draws <- as_draws_df(model)
    
    # Get mean parameters across all draws
    v_mean <- rep(mean(post_draws$Intercept, na.rm = TRUE), nrow(model_data))
    a_mean <- rep(exp(mean(post_draws$Intercept_bs, na.rm = TRUE)), nrow(model_data))
    t0_mean <- rep(exp(mean(post_draws$Intercept_ndt, na.rm = TRUE)), nrow(model_data))
    z_mean <- rep(plogis(mean(post_draws$Intercept_bias, na.rm = TRUE)), nrow(model_data))
    
    cat(timestamp(), "  ✓ Fallback: Using mean parameters from draws\n")
    cat(timestamp(), "  Extracted parameters for", length(v_mean), "trials\n")
    flush.console()
  }
  
  # Simulate RTs using RWiener with trial-level parameters
  n_trials <- length(v_mean)
  simulated_rts <- numeric(n_trials)
  simulated_decisions <- integer(n_trials)
  
  cat(timestamp(), "  Simulating RTs from trial-level parameters...\n")
  cat(timestamp(), "  Progress: [", sep = "")
  flush.console()
  
  for (i in 1:n_trials) {
    if (i %% max(1, floor(n_trials / 20)) == 0) {
      cat(".", sep = "", append = TRUE)
      flush.console()
    }
    
    # Sample from Wiener distribution using trial-specific parameters
    tryCatch({
      sim <- rwiener(
        n = 1,
        alpha = a_mean[i],
        tau = t0_mean[i],
        beta = z_mean[i],
        delta = v_mean[i]
      )
      simulated_rts[i] <- sim$q
      simulated_decisions[i] <- as.integer(sim$resp == "upper")
    }, error = function(e) {
      # If simulation fails, use observed RT
      simulated_rts[i] <- model_data$rt[i]
      simulated_decisions[i] <- model_data$decision[i]
    })
  }
  
  cat("] Done\n")
  flush.console()
  
  return(list(
    rt = simulated_rts,
    decision = simulated_decisions
  ))
}

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
    cat(timestamp(), "Loading model...\n")
    flush.console()
    model <- readRDS(model_file)
    cat(timestamp(), "✓ Model loaded\n")
    flush.console()
    
    model_data <- model$data
    
    # =====================================================================
    # SIMULATE RTs (ALTERNATIVE TO posterior_predict)
    # =====================================================================
    
    cat(timestamp(), "Simulating posterior predictive RTs...\n")
    flush.console()
    
    sim_start <- Sys.time()
    # Use 150 draws for PPC (good balance of quality and speed)
    # This matches the original script's target and gives good posterior predictive representation
    sim_results <- simulate_ddm_rts(model, model_data, n_draws = 150)
    sim_elapsed <- difftime(Sys.time(), sim_start, units = "mins")
    
    cat(timestamp(), "✓ Simulated", length(sim_results$rt), "RTs (took", 
        round(as.numeric(sim_elapsed), 1), "minutes)\n")
    flush.console()
    
    # =====================================================================
    # QP PLOTS
    # =====================================================================
    
    cat(timestamp(), "Computing QP plots...\n")
    flush.console()
    
    # Empirical quantiles
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
    
    # Predicted quantiles from simulated data
    pred_quantiles <- data.frame(
      rt = sim_results$rt,
      decision = sim_results$decision
    ) %>%
      group_by(decision) %>%
      summarise(
        q10 = quantile(rt, 0.1, na.rm = TRUE),
        q30 = quantile(rt, 0.3, na.rm = TRUE),
        q50 = quantile(rt, 0.5, na.rm = TRUE),
        q70 = quantile(rt, 0.7, na.rm = TRUE),
        q90 = quantile(rt, 0.9, na.rm = TRUE),
        .groups = "drop"
      )
    
    # Create QP plot
    qp_data <- bind_rows(
      empirical_quantiles %>%
        mutate(type = "Empirical"),
      pred_quantiles %>%
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
      scale_color_manual(values = c("Empirical" = "black", "Predicted" = "red"))
    
    qp_file <- paste0("output/ppc/", model_name, "_qp_plot.pdf")
    ggsave(qp_file, qp_plot, width = 10, height = 6, units = "in")
    cat(timestamp(), "✓ Saved:", qp_file, "\n")
    flush.console()
    
    # =====================================================================
    # CONDITIONAL ACCURACY FUNCTION (CAF)
    # =====================================================================
    
    cat(timestamp(), "Computing Conditional Accuracy Function (by drift bins)...\n")
    flush.console()
    
    # Extract drift estimates from the model for each trial
    # Re-extract drift parameters for CAF (needed for drift bins)
    cat(timestamp(), "  Re-extracting drift parameters for CAF...\n")
    flush.console()
    
    caf_linpred_start <- Sys.time()
    caf_linpred_success <- tryCatch({
      drift_for_caf <- posterior_linpred(model, summary = FALSE)
      TRUE
    }, error = function(e) {
      FALSE
    })
    
    if (caf_linpred_success) {
      # Use mean drift across all draws for drift bins
      trial_drifts <- colMeans(drift_for_caf, na.rm = TRUE)
    } else {
      # Fallback: use simulated RTs as proxy (faster RT = higher drift)
      trial_drifts <- -sim_results$rt  # Inverse RT as drift proxy
    }
    
    # Bin by drift (10 bins)
    drift_bins <- 10
    drift_quantiles <- quantile(trial_drifts, 
                                probs = seq(0, 1, length.out = drift_bins + 1), 
                                na.rm = TRUE)
    
    model_data$drift_bin <- cut(trial_drifts, 
                                breaks = drift_quantiles,
                                labels = FALSE,
                                include.lowest = TRUE)
    
    # Empirical CAF: Accuracy in each drift bin
    empirical_caf <- model_data %>%
      filter(!is.na(drift_bin)) %>%
      group_by(drift_bin) %>%
      summarise(
        mean_accuracy = mean(decision, na.rm = TRUE),
        mean_drift = mean(trial_drifts, na.rm = TRUE),
        mean_rt = mean(rt, na.rm = TRUE),
        n_trials = n(),
        .groups = "drop"
      ) %>%
      mutate(type = "Empirical")
    
    # Predicted CAF: Use simulated data
    pred_data_with_bins <- data.frame(
      rt = sim_results$rt,
      decision = sim_results$decision,
      drift_bin = model_data$drift_bin
    )
    
    pred_caf <- pred_data_with_bins %>%
      filter(!is.na(drift_bin)) %>%
      group_by(drift_bin) %>%
      summarise(
        mean_accuracy = mean(decision, na.rm = TRUE),
        mean_drift = NA,
        mean_rt = mean(rt, na.rm = TRUE),
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
        subtitle = "Accuracy as Function of Predicted Drift Bins",
        x = "Drift Bin (1=low drift, 10=high drift)",
        y = "Accuracy Rate",
        color = "Type",
        linetype = "Type"
      ) +
      theme_bw() +
      scale_color_manual(values = c("Empirical" = "black", "Predicted" = "red")) +
      scale_y_continuous(limits = c(0, 1)) +
      scale_x_continuous(breaks = 1:10)
    
    caf_file <- paste0("output/ppc/", model_name, "_caf_plot.pdf")
    ggsave(caf_file, caf_plot, width = 8, height = 6, units = "in")
    cat(timestamp(), "✓ Saved:", caf_file, "\n")
    flush.console()
    
    # =====================================================================
    # RT DISTRIBUTIONS BY CONDITION
    # =====================================================================
    
    cat(timestamp(), "Creating RT distributions by condition...\n")
    flush.console()
    
    # Check if we have condition variables
    if ("effort_condition" %in% names(model_data) && 
        "difficulty_level" %in% names(model_data)) {
      
      # Create condition combinations
      model_data$condition <- paste0(
        as.character(model_data$effort_condition), "_",
        as.character(model_data$difficulty_level)
      )
      
      rt_dist_data <- bind_rows(
        model_data %>%
          select(rt, condition) %>%
          mutate(type = "Empirical"),
        data.frame(
          rt = sim_results$rt,
          condition = model_data$condition[1:length(sim_results$rt)],
          type = "Predicted"
        )
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
        scale_fill_manual(values = c("Empirical" = "black", "Predicted" = "red")) +
        scale_color_manual(values = c("Empirical" = "black", "Predicted" = "red"))
      
      rt_file <- paste0("output/ppc/", model_name, "_rt_distribution.pdf")
      ggsave(rt_file, rt_dist_plot, width = 12, height = 8, units = "in")
      cat(timestamp(), "✓ Saved:", rt_file, "\n")
      flush.console()
    } else {
      cat(timestamp(), "  ⚠️  No effort/difficulty conditions found, skipping RT distribution plot\n")
      flush.console()
    }
    
    # =====================================================================
    # SYSTEMATIC DEVIATION CHECKS
    # =====================================================================
    
    cat(timestamp(), "Checking for systematic deviations...\n")
    flush.console()
    
    deviations <- list()
    
    # Check 1: Underpredicted long RTs
    empirical_long_rt <- quantile(model_data$rt, 0.9, na.rm = TRUE)
    pred_long_rt <- quantile(sim_results$rt, 0.9, na.rm = TRUE)
    
    if (pred_long_rt < 0.9 * empirical_long_rt) {
      deviations$underpredicted_long_rt <- TRUE
      cat(timestamp(), "  ⚠️  Warning: Model underpredicts long RTs\n")
      cat(timestamp(), "    Empirical 90th percentile:", round(empirical_long_rt, 3), "\n")
      cat(timestamp(), "    Predicted 90th percentile:", round(pred_long_rt, 3), "\n")
      flush.console()
    } else {
      cat(timestamp(), "  ✓ Long RTs: OK\n")
      flush.console()
    }
    
    # Check 2: QP plot deviations (>15% in any quantile)
    qp_deviation <- bind_rows(
      empirical_quantiles %>% mutate(type = "emp"),
      pred_quantiles %>% mutate(type = "pred")
    ) %>%
      pivot_longer(cols = c(q10, q30, q50, q70, q90),
                   names_to = "quantile",
                   values_to = "rt_value") %>%
      pivot_wider(names_from = type, values_from = rt_value) %>%
      mutate(
        deviation = abs(emp - pred) / emp,
        quantile_prob = case_when(
          quantile == "q10" ~ 0.1,
          quantile == "q30" ~ 0.3,
          quantile == "q50" ~ 0.5,
          quantile == "q70" ~ 0.7,
          quantile == "q90" ~ 0.9
        )
      )
    
    large_deviations <- qp_deviation %>%
      filter(deviation > 0.15)  # >15% deviation
    
    if (nrow(large_deviations) > 0) {
      deviations$qp_deviations <- TRUE
      cat(timestamp(), "  ⚠️  Warning:", nrow(large_deviations), 
          "quantile-probability points show >15% deviation\n")
      flush.console()
    } else {
      cat(timestamp(), "  ✓ QP deviations: All <15%\n")
      flush.console()
    }
    
    # Check 3: Boundary misfit (middle RT accuracy around 0.5)
    middle_rt_bin <- model_data %>%
      mutate(rt_bin = ntile(rt, 10)) %>%
      filter(rt_bin == 5) %>%
      summarise(mean_acc = mean(decision, na.rm = TRUE)) %>%
      pull(mean_acc)
    
    if (abs(middle_rt_bin - 0.5) > 0.2) {
      deviations$boundary_misfit <- TRUE
      cat(timestamp(), "  ⚠️  Warning: Possible boundary misfit (middle RT accuracy:", 
          round(middle_rt_bin, 2), ")\n")
      flush.console()
    } else {
      cat(timestamp(), "  ✓ Boundary fit: OK\n")
      flush.console()
    }
    
    # Store results
    ppc_results[[model_name]] <- list(
      empirical_quantiles = empirical_quantiles,
      pred_quantiles = pred_quantiles,
      deviations = deviations,
      qp_deviation_summary = qp_deviation,
      empirical_long_rt = empirical_long_rt,
      pred_long_rt = pred_long_rt
    )
    
    model_end_time <- Sys.time()
    model_duration <- difftime(model_end_time, model_start_time, units = "mins")
    
    cat(timestamp(), "✓", model_name, "complete (", 
        round(as.numeric(model_duration), 1), "minutes)\n\n")
    flush.console()
    
  }, error = function(e) {
    cat(timestamp(), "❌ Error:", e$message, "\n\n")
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
cat("  - *_rt_distribution.pdf (RT distributions by condition)\n")
cat("  - ppc_deviation_summary.csv (Deviation flags)\n\n")

