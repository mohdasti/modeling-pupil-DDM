# =========================================================================
# DDM POSTERIOR PREDICTIVE CHECKS - FAST VERSION
# =========================================================================
# Uses 50 draws for initial checks (very fast, still reasonable quality)
# Switch to main script for final publication-quality PPCs
# =========================================================================

library(brms)
library(dplyr)
library(readr)
library(ggplot2)
library(bayesplot)
library(purrr)
library(tidyr)
library(posterior)

cat("\n")
cat("================================================================================\n")
cat("DDM POSTERIOR PREDICTIVE CHECKS - FAST VERSION (50 draws)\n")
cat("================================================================================\n")

timestamp <- function() format(Sys.time(), "[%H:%M:%S]")

ppc_start_time <- Sys.time()
cat("Started:", format(ppc_start_time, "%Y-%m-%d %H:%M:%S"), "\n")
cat("Configuration: 50 draws per model (fast for initial checks)\n")
cat("Expected: ~5-10 minutes per model\n")
cat("Note: Use main script (150 draws) for final publication-quality PPCs\n")
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
# PPC FOR EACH MODEL (SAME AS MAIN SCRIPT, BUT 50 DRAWS)
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
    # GENERATE POSTERIOR PREDICTIVE SAMPLES - 50 DRAWS (FAST)
    # =====================================================================
    
    cat(timestamp(), "Generating posterior predictive samples (50 draws)...\n")
    flush.console()
    
    n_draws <- 50  # Fast version
    
    n_trials <- nrow(model_data)
    total_predictions <- n_trials * n_draws
    
    cat(timestamp(), "  Trials:", format(n_trials, big.mark = ","), "\n")
    cat(timestamp(), "  Total predictions:", format(total_predictions, big.mark = ","), "\n")
    cat(timestamp(), "  Estimated time: 5-10 minutes\n")
    cat(timestamp(), "  Starting posterior_predict()...\n")
    cat(timestamp(), "  [This step has no progress output - it's working if CPU >30%]\n")
    flush.console()
    
    pp_start_time <- Sys.time()
    pp_samples <- posterior_predict(
      model,
      draws = n_draws,
      summary = FALSE
    )
    pp_elapsed <- difftime(Sys.time(), pp_start_time, units = "mins")
    
    cat(timestamp(), "✓ Generated", n_draws, "samples (took", 
        round(as.numeric(pp_elapsed), 1), "minutes)\n")
    flush.console()
    
    # Rest of the script is same as main version
    # (QP plots, CAF, RT distributions, etc.)
    # For brevity, copying key sections...
    
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
    
    # Predicted quantiles (use 25 draws for speed)
    n_qp_draws <- min(25, n_draws)
    pred_quantiles_list <- list()
    
    cat(timestamp(), "  Computing QP stats (", n_qp_draws, "draws)... [", sep = "")
    flush.console()
    
    for (i in 1:n_qp_draws) {
      if (i %% max(1, floor(n_qp_draws / 5)) == 0) {
        cat(".", sep = "", append = TRUE)
        flush.console()
      }
      pred_rts <- pp_samples[i, ]
      pred_df <- data.frame(
        rt = pred_rts,
        decision = model_data$decision
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
    
    # Create QP plot (simplified)
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
    
    qp_plot <- ggplot(qp_data, aes(x = quantile_prob, y = rt_value, 
                                   color = type, linetype = type)) +
      geom_line(size = 1.2) +
      geom_point(size = 2) +
      facet_wrap(~ decision_label, scales = "free_y") +
      labs(
        title = paste0("QP Plot: ", model_name, " (50 draws - FAST)"),
        subtitle = "RT Quantiles (10/30/50/70/90) by Decision",
        x = "Quantile Probability",
        y = "RT (seconds)",
        color = "Type",
        linetype = "Type"
      ) +
      theme_bw() +
      scale_color_manual(values = c("Empirical" = "black", "Predicted" = "red"))
    
    # Save plot
    qp_file <- paste0("output/ppc/", model_name, "_qp_plot_FAST.pdf")
    ggsave(qp_file, qp_plot, width = 10, height = 6, units = "in")
    cat(timestamp(), "✓ Saved:", qp_file, "\n")
    flush.console()
    
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

cat("================================================================================\n")
cat("FAST PPC COMPLETE\n")
cat("================================================================================\n")
cat("Note: This used 50 draws for speed. For publication, use main script (150 draws).\n\n")










