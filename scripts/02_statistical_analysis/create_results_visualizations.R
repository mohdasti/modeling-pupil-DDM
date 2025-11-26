#!/usr/bin/env Rscript
# Create high-priority visualizations for Results section
# 1. Subject-level parameter distribution
# 2. Parameter correlation matrix
# 3. Integrated condition effects (all parameters)
# 4. Brinley plot (RT relationships)

suppressPackageStartupMessages({
  library(brms)
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(ggplot2)
  library(readr)
  library(stringr)
  library(corrplot)
  library(viridis)
  library(gridExtra)
  library(posterior)
})

# =========================================================================
# SETUP
# =========================================================================

cat("Creating high-priority visualizations for Results section...\n\n")

# Directories
models_dir <- "output/models"
figures_dir <- "output/figures"
results_dir <- "output/results"
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)

# Try to load primary model (Model4_Additive or Model3_Difficulty)
primary_model_path <- file.path(models_dir, "Model4_Additive.rds")
if (!file.exists(primary_model_path)) {
  primary_model_path <- file.path(models_dir, "Model3_Difficulty.rds")
}

if (!file.exists(primary_model_path)) {
  cat("⚠️  Primary model not found. Trying alternative locations...\n")
  # Try other possible locations
  alt_paths <- c(
    "output/models/Model4_Additive.rds",
    "output/models/Model3_Difficulty.rds",
    "../output/models/Model4_Additive.rds",
    "../output/models/Model3_Difficulty.rds"
  )
  found <- FALSE
  for (p in alt_paths) {
    if (file.exists(p)) {
      primary_model_path <- p
      found <- TRUE
      break
    }
  }
  if (!found) {
    stop("Cannot find primary model file. Please ensure Model4_Additive.rds or Model3_Difficulty.rds exists in output/models/")
  }
}

cat("Loading primary model:", primary_model_path, "\n")
fit_primary <- readRDS(primary_model_path)
cat("✓ Model loaded successfully\n\n")

# Load data for Brinley plot
data_path <- "data/analysis_ready/bap_ddm_ready.csv"
if (!file.exists(data_path)) {
  data_path <- "../data/analysis_ready/bap_ddm_ready.csv"
}
if (file.exists(data_path)) {
  d <- read_csv(data_path, show_col_types = FALSE)
  cat("✓ Data loaded for Brinley plot\n\n")
} else {
  d <- NULL
  cat("⚠️  Data file not found. Brinley plot will be skipped.\n\n")
}

# =========================================================================
# 1. SUBJECT-LEVEL PARAMETER DISTRIBUTION
# =========================================================================

cat("1. Creating subject-level parameter distribution plot...\n")

extract_subject_params <- function(fit) {
  # Extract random effects for each parameter
  re_list <- list()
  
  # Get all random effects (without pars argument)
  tryCatch({
    re_all <- ranef(fit)
    
    if (length(re_all) > 0 && "subject_id" %in% names(re_all)) {
      re_subj <- re_all$subject_id
      
      # re_subj is a 3D array: [subject, statistic, parameter]
      # Extract each parameter slice
      
      # Drift (v) - Intercept slice
      if ("Intercept" %in% dimnames(re_subj)[[3]]) {
        re_intercept <- re_subj[, , "Intercept", drop = FALSE]
        re_list$v <- data.frame(
          subject_id = rownames(re_intercept),
          Estimate = re_intercept[, "Estimate", 1],
          `Q2.5` = re_intercept[, "Q2.5", 1],
          `Q97.5` = re_intercept[, "Q97.5", 1],
          parameter = "Drift (v)",
          estimate = re_intercept[, "Estimate", 1],
          ci_lower = re_intercept[, "Q2.5", 1],
          ci_upper = re_intercept[, "Q97.5", 1],
          stringsAsFactors = FALSE
        )
      }
      
      # Boundary (a/bs) - bs_Intercept slice
      if ("bs_Intercept" %in% dimnames(re_subj)[[3]]) {
        re_bs <- re_subj[, , "bs_Intercept", drop = FALSE]
        re_list$bs <- data.frame(
          subject_id = rownames(re_bs),
          Estimate = re_bs[, "Estimate", 1],
          `Q2.5` = re_bs[, "Q2.5", 1],
          `Q97.5` = re_bs[, "Q97.5", 1],
          parameter = "Boundary (a)",
          estimate = re_bs[, "Estimate", 1],
          ci_lower = re_bs[, "Q2.5", 1],
          ci_upper = re_bs[, "Q97.5", 1],
          stringsAsFactors = FALSE
        )
      }
      
      # Bias (z) - bias_Intercept slice
      if ("bias_Intercept" %in% dimnames(re_subj)[[3]]) {
        re_bias <- re_subj[, , "bias_Intercept", drop = FALSE]
        re_list$bias <- data.frame(
          subject_id = rownames(re_bias),
          Estimate = re_bias[, "Estimate", 1],
          `Q2.5` = re_bias[, "Q2.5", 1],
          `Q97.5` = re_bias[, "Q97.5", 1],
          parameter = "Bias (z)",
          estimate = re_bias[, "Estimate", 1],
          ci_lower = re_bias[, "Q2.5", 1],
          ci_upper = re_bias[, "Q97.5", 1],
          stringsAsFactors = FALSE
        )
      }
      
      # Non-decision time (t0/ndt) - if random effects exist
      if ("ndt_Intercept" %in% dimnames(re_subj)[[3]]) {
        re_ndt <- re_subj[, , "ndt_Intercept", drop = FALSE]
        re_list$ndt <- data.frame(
          subject_id = rownames(re_ndt),
          Estimate = re_ndt[, "Estimate", 1],
          `Q2.5` = re_ndt[, "Q2.5", 1],
          `Q97.5` = re_ndt[, "Q97.5", 1],
          parameter = "Non-decision time (t₀)",
          estimate = re_ndt[, "Estimate", 1],
          ci_lower = re_ndt[, "Q2.5", 1],
          ci_upper = re_ndt[, "Q97.5", 1],
          stringsAsFactors = FALSE
        )
      }
    }
  }, error = function(e) {
    cat("Error extracting random effects:", e$message, "\n")
  })
  
  # Combine all
  if (length(re_list) > 0) {
    re_df <- bind_rows(re_list) %>%
      mutate(subject_id = factor(subject_id),
             parameter = factor(parameter, levels = c("Drift (v)", "Boundary (a)", 
                                                      "Bias (z)", "Non-decision time (t₀)")))
    return(re_df)
  } else {
    return(NULL)
  }
}

re_df <- extract_subject_params(fit_primary)

if (!is.null(re_df) && nrow(re_df) > 0) {
  # Create violin + point plot
  p1 <- ggplot(re_df, aes(x = parameter, y = estimate, fill = parameter)) +
    geom_violin(alpha = 0.3, trim = FALSE) +
    geom_boxplot(width = 0.2, alpha = 0.7, outlier.shape = NA) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.5) +
    scale_fill_viridis_d(option = "plasma", begin = 0.2, end = 0.8) +
    labs(
      title = "Subject-Level Parameter Estimates (Random Effects)",
      subtitle = "Individual differences in DDM parameters across 67 participants",
      x = "DDM Parameter",
      y = "Random Effect Estimate (link scale)",
      fill = "Parameter"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(size = 14, face = "bold", hjust = 0.5),
      plot.subtitle = element_text(size = 11, hjust = 0.5, color = "gray60"),
      axis.text.x = element_text(angle = 0, hjust = 0.5),
      legend.position = "none",
      panel.grid.minor = element_blank()
    )
  
  ggsave(file.path(figures_dir, "fig_subject_parameter_distribution.pdf"),
         p1, width = 10, height = 6, device = cairo_pdf)
  ggsave(file.path(figures_dir, "fig_subject_parameter_distribution.png"),
         p1, width = 10, height = 6, dpi = 300, bg = "white")
  
  # Save data
  write_csv(re_df, file.path(results_dir, "subject_random_effects.csv"))
  cat("✓ Saved: fig_subject_parameter_distribution.pdf/png\n")
} else {
  cat("⚠️  Could not extract subject-level random effects. Skipping plot 1.\n")
}

# =========================================================================
# 2. PARAMETER CORRELATION MATRIX
# =========================================================================

cat("\n2. Creating parameter correlation matrix...\n")

extract_param_correlations <- function(fit) {
  # Extract posterior samples for key parameters
  tryCatch({
    post_samples <- as_draws_df(fit)
    
    # Find intercept columns for each parameter type
    # These are the group-level (fixed) intercepts
    # Based on diagnostic output:
    # - Drift: "b_Intercept"
    # - Boundary: "b_bs_Intercept"
    # - Bias: "b_bias_Intercept" (need to check)
    # - Non-decision time: "b_ndt_Intercept"
    
    v_intercept <- grep("^b_Intercept$", names(post_samples), value = TRUE)
    bs_intercept <- grep("^b_bs_Intercept$", names(post_samples), value = TRUE)
    bias_intercept <- grep("^b_bias_Intercept$", names(post_samples), value = TRUE)
    ndt_intercept <- grep("^b_ndt_Intercept$", names(post_samples), value = TRUE)
    
    # Collect all intercepts
    key_params <- c(v_intercept, bs_intercept, bias_intercept, ndt_intercept)
    key_params <- key_params[!is.na(key_params) & key_params != "" & key_params %in% names(post_samples)]
    
    if (length(key_params) >= 2) {
      param_data <- post_samples[, key_params, drop = FALSE]
      
      # Clean parameter names
      clean_names <- function(x) {
        x <- gsub("^b_Intercept$", "Drift (v)", x)
        x <- gsub("^b_bs_Intercept$", "Boundary (a)", x)
        x <- gsub("^b_bias_Intercept$", "Bias (z)", x)
        x <- gsub("^b_ndt_Intercept$", "Non-decision time (t₀)", x)
        return(x)
      }
      
      names(param_data) <- clean_names(names(param_data))
      
      # Remove any columns that are all NA
      param_data <- param_data[, colSums(!is.na(param_data)) > 0, drop = FALSE]
      
      if (ncol(param_data) >= 2) {
        # Compute correlation matrix
        cor_matrix <- cor(param_data, use = "complete.obs")
        return(cor_matrix)
      }
    }
    
    return(NULL)
  }, error = function(e) {
    cat("Error extracting correlations:", e$message, "\n")
    return(NULL)
  })
}

cor_matrix <- extract_param_correlations(fit_primary)

if (!is.null(cor_matrix)) {
  # Clean parameter names to avoid Unicode issues in corrplot
  # Replace subscript ₀ (U+2080) with regular 0 for plotting
  rownames(cor_matrix) <- gsub("t₀", "t0", rownames(cor_matrix))
  colnames(cor_matrix) <- gsub("t₀", "t0", colnames(cor_matrix))
  
  # Create correlation plot
  pdf(file.path(figures_dir, "fig_parameter_correlation_matrix.pdf"),
      width = 8, height = 8)
  corrplot(cor_matrix, method = "circle", type = "upper", order = "original",
           tl.col = "black", tl.srt = 45, tl.cex = 0.9,
           addCoef.col = "black", number.cex = 0.8,
           col = colorRampPalette(c("#67001f", "#d6604d", "#f7f7f7", "#4393c3", "#053061"))(200),
           diag = TRUE)
  title("DDM Parameter Correlations", line = 2.5, cex.main = 1.2, font.main = 2)
  dev.off()
  
  # PNG version
  png(file.path(figures_dir, "fig_parameter_correlation_matrix.png"),
      width = 8, height = 8, units = "in", res = 300, bg = "white")
  corrplot(cor_matrix, method = "circle", type = "upper", order = "original",
           tl.col = "black", tl.srt = 45, tl.cex = 0.9,
           addCoef.col = "black", number.cex = 0.8,
           col = colorRampPalette(c("#67001f", "#d6604d", "#f7f7f7", "#4393c3", "#053061"))(200),
           diag = TRUE)
  title("DDM Parameter Correlations", line = 2.5, cex.main = 1.2, font.main = 2)
  dev.off()
  
  # Save correlation matrix (with original names including subscript)
  cor_matrix_df <- as.data.frame(cor_matrix)
  # Restore original names for CSV (t0 -> t₀)
  rownames(cor_matrix_df) <- gsub("t0", "t₀", rownames(cor_matrix_df))
  colnames(cor_matrix_df) <- gsub("t0", "t₀", colnames(cor_matrix_df))
  write_csv(cor_matrix_df %>% rownames_to_column("Parameter"),
            file.path(results_dir, "parameter_correlations.csv"))
  cat("✓ Saved: fig_parameter_correlation_matrix.pdf/png\n")
} else {
  cat("⚠️  Could not extract parameter correlations. Skipping plot 2.\n")
}

# =========================================================================
# 3. INTEGRATED CONDITION EFFECTS (ALL PARAMETERS)
# =========================================================================

cat("\n3. Creating integrated condition effects plot...\n")

# Load fixed effects table if available
fx_table_path <- "output/publish/table_fixed_effects.csv"
if (!file.exists(fx_table_path)) {
  fx_table_path <- "../output/publish/table_fixed_effects.csv"
}

if (file.exists(fx_table_path)) {
  fx_table <- read_csv(fx_table_path, show_col_types = FALSE)
  
  # Extract key effects for each parameter
  # Note: In an additive model, difficulty and effort effects are identical across tasks
  prepare_integrated_plot <- function(fx_df) {
    # Separate by parameter type
    fx_df <- fx_df %>%
      mutate(
        param_type = case_when(
          grepl("^b_|^Intercept$", parameter) & !grepl("^bs_|^bias_|^ndt_", parameter) ~ "Drift (v)",
          grepl("^bs_", parameter) ~ "Boundary (a)",
          grepl("^bias_", parameter) ~ "Bias (z)",
          grepl("^ndt_", parameter) ~ "Non-decision time (t₀)",
          TRUE ~ "Other"
        ),
        term_clean = case_when(
          grepl("difficulty_levelEasy", parameter) ~ "Difficulty: Easy",
          grepl("difficulty_levelHard", parameter) ~ "Difficulty: Hard",
          grepl("effort_conditionLow", parameter) ~ "Effort: Low",
          grepl("effort_conditionHigh", parameter) ~ "Effort: High",
          grepl("Intercept", parameter) & !grepl("task", parameter, ignore.case = TRUE) ~ "Intercept",
          TRUE ~ parameter
        )
      ) %>%
      filter(
        param_type != "Other",
        # Include intercepts (general, not task-specific)
        (grepl("Intercept", parameter) & !grepl("task", parameter, ignore.case = TRUE)) |
        # Include difficulty and effort effects (same across tasks in additive model)
        (!grepl("Intercept|task", parameter, ignore.case = TRUE) & 
         term_clean %in% c("Difficulty: Easy", "Difficulty: Hard", "Effort: Low", "Effort: High"))
      )
    
    return(fx_df)
  }
  
  # Create single combined plot
  fx_plot <- prepare_integrated_plot(fx_table)
  
  if (nrow(fx_plot) > 0) {
    p3 <- ggplot(fx_plot, aes(x = estimate, y = term_clean)) +
      geom_vline(xintercept = 0, linetype = "dashed", color = "gray60", linewidth = 0.5) +
      geom_point(aes(color = param_type), size = 2.5) +
      geom_errorbarh(aes(xmin = conf.low, xmax = conf.high, color = param_type),
                     height = 0.2, linewidth = 1) +
      facet_wrap(~ param_type, scales = "free_x", ncol = 2) +
      scale_color_viridis_d(option = "plasma", begin = 0.2, end = 0.8) +
      labs(
        title = "Integrated Condition Effects on DDM Parameters",
        subtitle = "Posterior means with 95% credible intervals (link scale). Effects are identical across ADT and VDT due to additive model structure.",
        x = "Effect Estimate (95% CrI)",
        y = "Condition",
        color = "Parameter"
      ) +
      theme_minimal(base_size = 11) +
      theme(
        plot.title = element_text(size = 13, face = "bold", hjust = 0.5),
        plot.subtitle = element_text(size = 10, hjust = 0.5, color = "gray60"),
        strip.text = element_text(face = "bold", size = 10),
        axis.text.y = element_text(size = 9),
        axis.text.x = element_text(size = 9),
        legend.position = "bottom",
        panel.grid.minor = element_blank()
      )
    
    ggsave(file.path(figures_dir, "fig_integrated_condition_effects.pdf"),
           p3, width = 12, height = 8, device = cairo_pdf)
    ggsave(file.path(figures_dir, "fig_integrated_condition_effects.png"),
           p3, width = 12, height = 8, dpi = 300, bg = "white")
    
    cat("✓ Saved: fig_integrated_condition_effects.pdf/png\n")
  } else {
    cat("⚠️  No suitable effects found in fixed effects table. Skipping plot 3.\n")
  }
} else {
  cat("⚠️  Fixed effects table not found. Skipping plot 3.\n")
}

# =========================================================================
# 4. BRINLEY PLOT (RT RELATIONSHIPS)
# =========================================================================

cat("\n4. Creating Brinley plot...\n")

if (!is.null(d) && nrow(d) > 0) {
  # Prepare data for Brinley plot
  # Classic Brinley plot: RT in one condition vs RT in another condition
  brinley_data <- d %>%
    filter(!is.na(rt), !is.na(difficulty_level), !is.na(effort_condition)) %>%
    group_by(subject_id, difficulty_level, effort_condition) %>%
    summarise(
      mean_rt = mean(rt, na.rm = TRUE),
      median_rt = median(rt, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    pivot_wider(
      names_from = difficulty_level,
      values_from = c(mean_rt, median_rt),
      names_sep = "_"
    )
  
  # Create Easy vs Hard comparison
  if ("mean_rt_Easy" %in% names(brinley_data) && "mean_rt_Hard" %in% names(brinley_data)) {
    brinley_plot_data <- brinley_data %>%
      filter(!is.na(mean_rt_Easy), !is.na(mean_rt_Hard)) %>%
      mutate(
        effort = effort_condition,
        # Convert RT from seconds to milliseconds
        mean_rt_Easy_ms = mean_rt_Easy * 1000,
        mean_rt_Hard_ms = mean_rt_Hard * 1000
      )
    
    # Check unique effort values to create proper color mapping
    unique_effort <- unique(brinley_plot_data$effort)
    cat("Unique effort values:", paste(unique_effort, collapse = ", "), "\n")
    
    # Create color mapping - identify high vs low effort
    effort_levels <- if (any(grepl("High|40", unique_effort, ignore.case = TRUE))) {
      high_effort <- unique_effort[grepl("High|40", unique_effort, ignore.case = TRUE)][1]
      low_effort <- unique_effort[grepl("Low|5", unique_effort, ignore.case = TRUE)][1]
      list(high = high_effort, low = low_effort)
    } else {
      # Fallback: use first two unique values
      list(high = unique_effort[1], low = unique_effort[2])
    }
    
    # Create color vector
    color_map <- setNames(
      c("#DC143C", "#1E90FF"),  # Crimson and Blue
      c(effort_levels$high, effort_levels$low)
    )
    
    # Fit regression line (using milliseconds)
    fit_line <- lm(mean_rt_Hard_ms ~ mean_rt_Easy_ms, data = brinley_plot_data)
    slope <- coef(fit_line)[2]
    intercept <- coef(fit_line)[1]
    
    p4 <- ggplot(brinley_plot_data, aes(x = mean_rt_Easy_ms, y = mean_rt_Hard_ms)) +
      geom_point(aes(color = effort), size = 2.5, alpha = 0.7) +
      geom_abline(slope = 1, intercept = 0, linetype = "dashed", 
                  color = "gray50", linewidth = 0.5) +
      geom_smooth(method = "lm", se = TRUE, color = "black", 
                  linewidth = 1, alpha = 0.2) +
      scale_color_manual(values = color_map,
                        labels = c("High Effort", "Low Effort")) +
      labs(
        title = "Brinley Plot: Reaction Time Relationships",
        subtitle = paste0("Easy vs. Hard difficulty (slope = ", round(slope, 2), ")"),
        x = "Mean RT: Easy Trials (ms)",
        y = "Mean RT: Hard Trials (ms)",
        color = "Effort Condition"
      ) +
      theme_minimal(base_size = 12) +
      theme(
        plot.title = element_text(size = 13, face = "bold", hjust = 0.5),
        plot.subtitle = element_text(size = 10, hjust = 0.5, color = "gray60"),
        legend.position = "bottom",
        panel.grid.minor = element_blank()
      )
    
    ggsave(file.path(figures_dir, "fig_brinley_plot.pdf"),
           p4, width = 8, height = 7, device = cairo_pdf)
    ggsave(file.path(figures_dir, "fig_brinley_plot.png"),
           p4, width = 8, height = 7, dpi = 300, bg = "white")
    
    # Save data
    write_csv(brinley_plot_data, file.path(results_dir, "brinley_plot_data.csv"))
    cat("✓ Saved: fig_brinley_plot.pdf/png\n")
  } else {
    cat("⚠️  Required difficulty levels not found in data. Skipping plot 4.\n")
  }
} else {
  cat("⚠️  Data not available. Skipping plot 4.\n")
}

# =========================================================================
# 5. INDIVIDUAL SUBJECT TRAJECTORIES
# =========================================================================

cat("\n5. Creating individual subject trajectories plot...\n")

if (!is.null(d) && nrow(d) > 0) {
  # Extract subject-level parameter estimates across conditions
  # We'll use posterior predictions or coef() to get subject-specific estimates
  
  tryCatch({
    # Get subject-level coefficients (combined fixed + random effects)
    coef_subj <- coef(fit_primary)
    
    if (length(coef_subj) > 0 && "subject_id" %in% names(coef_subj)) {
      # Extract drift rate estimates by subject and condition
      # This is a simplified approach - we'll show how drift changes across difficulty
      
      # Get posterior predictions for each subject-condition combination
      # Create a grid of conditions
      condition_grid <- expand_grid(
        subject_id = unique(d$subject_id),
        difficulty_level = c("Easy", "Hard", "Standard"),
        effort_condition = unique(d$effort_condition),
        task = unique(d$task)
      ) %>%
        filter(!is.na(subject_id), !is.na(difficulty_level))
      
      # Get predicted drift rates for each condition
      # Use posterior_linpred to get predictions on link scale
      tryCatch({
        pred_drift <- posterior_linpred(
          fit_primary, 
          newdata = condition_grid,
          dpar = "mu",
          re_formula = NULL  # Include random effects
        )
        
        # Summarize across posterior draws
        condition_grid$drift_mean <- apply(pred_drift, 2, mean)
        condition_grid$drift_lower <- apply(pred_drift, 2, function(x) quantile(x, 0.025))
        condition_grid$drift_upper <- apply(pred_drift, 2, function(x) quantile(x, 0.975))
        
        # Create trajectory plot - show a sample of subjects
        # Select a representative sample (e.g., 12 subjects)
        n_show <- min(12, length(unique(condition_grid$subject_id)))
        sample_subjects <- sample(unique(condition_grid$subject_id), n_show)
        
        trajectory_data <- condition_grid %>%
          filter(subject_id %in% sample_subjects) %>%
          mutate(
            difficulty_num = case_when(
              difficulty_level == "Easy" ~ 1,
              difficulty_level == "Standard" ~ 2,
              difficulty_level == "Hard" ~ 3,
              TRUE ~ NA_real_
            ),
            effort_num = ifelse(grepl("Low|5", effort_condition, ignore.case = TRUE), 1, 2)
          ) %>%
          filter(!is.na(difficulty_num)) %>%
          arrange(subject_id, difficulty_num, effort_num)
        
        # Create color mapping for effort conditions
        unique_effort_traj <- unique(trajectory_data$effort_condition)
        high_effort_traj <- unique_effort_traj[grepl("High|40", unique_effort_traj, ignore.case = TRUE)][1]
        low_effort_traj <- unique_effort_traj[grepl("Low|5", unique_effort_traj, ignore.case = TRUE)][1]
        color_map_traj <- setNames(
          c("#DC143C", "#1E90FF"),  # Crimson for High, Blue for Low
          c(high_effort_traj, low_effort_traj)
        )
        
        # Create a simpler plot without ribbons to avoid grouping issues
        p5 <- ggplot(trajectory_data, aes(x = difficulty_num, y = drift_mean)) +
          geom_line(aes(group = interaction(subject_id, effort_condition), 
                        color = effort_condition), 
                   alpha = 0.6, linewidth = 0.8) +
          geom_point(aes(color = effort_condition), size = 2, alpha = 0.7) +
          geom_errorbar(aes(ymin = drift_lower, ymax = drift_upper, color = effort_condition),
                       width = 0.1, alpha = 0.5, linewidth = 0.5) +
          facet_wrap(~ subject_id, ncol = 4, scales = "free_y") +
          scale_x_continuous(breaks = 1:3, labels = c("Easy", "Standard", "Hard")) +
          scale_color_manual(values = color_map_traj,
                           labels = c("High Effort", "Low Effort"),
                           name = "Effort") +
          labs(
            title = "Individual Subject Trajectories: Drift Rate Across Difficulty",
            subtitle = paste("Sample of", n_show, "participants showing heterogeneity in responses"),
            x = "Difficulty Level",
            y = "Drift Rate (v)",
            color = "Effort"
          ) +
          theme_minimal(base_size = 10) +
          theme(
            plot.title = element_text(size = 12, face = "bold", hjust = 0.5),
            plot.subtitle = element_text(size = 9, hjust = 0.5, color = "gray60"),
            strip.text = element_text(size = 8),
            axis.text.x = element_text(size = 8, angle = 45, hjust = 1),
            axis.text.y = element_text(size = 7),
            legend.position = "bottom",
            panel.grid.minor = element_blank()
          )
        
        ggsave(file.path(figures_dir, "fig_subject_trajectories.pdf"),
               p5, width = 14, height = 10, device = cairo_pdf)
        ggsave(file.path(figures_dir, "fig_subject_trajectories.png"),
               p5, width = 14, height = 10, dpi = 300, bg = "white")
        
        cat("✓ Saved: fig_subject_trajectories.pdf/png\n")
      }, error = function(e) {
        cat("⚠️  Could not create trajectory plot:", e$message, "\n")
      })
    } else {
      cat("⚠️  Could not extract subject-level coefficients. Skipping plot 5.\n")
    }
  }, error = function(e) {
    cat("⚠️  Error creating subject trajectories:", e$message, "\n")
  })
} else {
  cat("⚠️  Data not available. Skipping plot 5.\n")
}

# =========================================================================
# 6. EFFECT SIZE COMPARISON
# =========================================================================

cat("\n6. Creating effect size comparison plot...\n")

# Load contrasts table if available
contrasts_path <- "output/publish/table_effect_contrasts.csv"
if (!file.exists(contrasts_path)) {
  contrasts_path <- "../output/publish/table_effect_contrasts.csv"
}

if (file.exists(contrasts_path)) {
  contrasts_table <- read_csv(contrasts_path, show_col_types = FALSE)
  
  # Calculate standardized effect sizes
  # For DDM parameters, we can standardize by dividing by the standard error
  # or by using Cohen's d approximation: d = mean / SE
  prepare_effect_sizes <- function(contrasts_df) {
    contrasts_df <- contrasts_df %>%
      mutate(
        param_type = case_when(
          parameter == "mu" | grepl("^b_|^Intercept$", parameter) & !grepl("^bs_|^bias_|^ndt_", parameter) ~ "Drift (v)",
          parameter == "bs" | grepl("^bs_", parameter) ~ "Boundary (a)",
          parameter == "bias" | grepl("^bias_", parameter) ~ "Bias (z)",
          parameter == "ndt" | grepl("^ndt_", parameter) ~ "Non-decision time (t₀)",
          TRUE ~ "Other"
        ),
        # Standardized effect size: use mean as effect size (on link scale)
        # For comparison across parameters, the link scale provides standardization
        effect_size = mean,
        # Get CI bounds - check for different column name variations
        ci_lower = if("q2.5" %in% names(.)) q2.5 else if("q05" %in% names(.)) q05 else NA_real_,
        ci_upper = if("q97.5" %in% names(.)) q97.5 else if("q95" %in% names(.)) q95 else NA_real_,
        # Clean contrast names - handle the format "Easy - Hard (ADT, Low)"
        contrast_clean = case_when(
          grepl("Easy.*Hard|Hard.*Easy", contrast, ignore.case = TRUE) ~ "Easy vs Hard",
          grepl("Easy.*Standard|Standard.*Easy", contrast, ignore.case = TRUE) ~ "Easy vs Standard",
          grepl("Hard.*Standard|Standard.*Hard", contrast, ignore.case = TRUE) ~ "Hard vs Standard",
          grepl("Low.*High|High.*Low", contrast, ignore.case = TRUE) ~ "Low vs High Effort",
          TRUE ~ gsub(" \\(.*\\)", "", as.character(contrast))  # Remove task/effort context
        )
      ) %>%
      filter(param_type != "Other",
             !is.na(effect_size),
             !is.na(ci_lower),
             !is.na(ci_upper))
    
    return(contrasts_df)
  }
  
  effect_sizes <- prepare_effect_sizes(contrasts_table)
  
  if (nrow(effect_sizes) > 0) {
    # Create forest plot of effect sizes
    p6 <- ggplot(effect_sizes, aes(x = effect_size, y = reorder(contrast_clean, effect_size))) +
      geom_vline(xintercept = 0, linetype = "dashed", color = "gray60", linewidth = 0.5) +
      geom_point(aes(color = param_type), size = 2.5) +
      geom_errorbarh(aes(xmin = ci_lower, xmax = ci_upper, color = param_type),
                     height = 0.2, linewidth = 1) +
      facet_wrap(~ param_type, scales = "free_x", ncol = 2) +
      scale_color_viridis_d(option = "plasma", begin = 0.2, end = 0.8) +
      labs(
        title = "Standardized Effect Sizes: Parameter Contrasts",
        subtitle = "Posterior mean contrasts with 95% credible intervals (link scale)",
        x = "Effect Size (95% CrI)",
        y = "Contrast",
        color = "Parameter"
      ) +
      theme_minimal(base_size = 11) +
      theme(
        plot.title = element_text(size = 13, face = "bold", hjust = 0.5),
        plot.subtitle = element_text(size = 10, hjust = 0.5, color = "gray60"),
        strip.text = element_text(face = "bold", size = 10),
        axis.text.y = element_text(size = 9),
        axis.text.x = element_text(size = 9),
        legend.position = "bottom",
        panel.grid.minor = element_blank()
      )
    
    ggsave(file.path(figures_dir, "fig_effect_size_comparison.pdf"),
           p6, width = 12, height = 10, device = cairo_pdf)
    ggsave(file.path(figures_dir, "fig_effect_size_comparison.png"),
           p6, width = 12, height = 10, dpi = 300, bg = "white")
    
    # Save data
    write_csv(effect_sizes, file.path(results_dir, "effect_sizes_comparison.csv"))
    cat("✓ Saved: fig_effect_size_comparison.pdf/png\n")
  } else {
    cat("⚠️  No suitable contrasts found. Skipping plot 6.\n")
  }
} else {
  cat("⚠️  Contrasts table not found. Skipping plot 6.\n")
}

# =========================================================================
# SUMMARY
# =========================================================================

cat("\n" , strrep("=", 60), "\n")
cat("Visualization creation complete!\n")
cat("Figures saved to:", figures_dir, "\n")
cat(strrep("=", 60), "\n")

