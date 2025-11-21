# R/ppc_joint_minimal.R

# Minimal PPC (subject-aware, conditional) for the joint model
# Computes QP RMSE and KS statistics per cell (task × effort × difficulty)

suppressPackageStartupMessages({
  library(brms)
  library(dplyr)
  library(readr)
  library(posterior)
})

# Ensure output directory exists
dir.create("output/publish", recursive = TRUE, showWarnings = FALSE)

cat("=== Loading Joint Model ===\n")

fit_path <- "output/publish/fit_joint_vza_stdconstrained.rds"
if (!file.exists(fit_path)) {
  stop("Joint model not found: ", fit_path)
}

fit <- readRDS(fit_path)
cat("✓ Loaded joint model\n")

cat("\n=== Loading Data ===\n")

dd <- read_csv("data/analysis_ready/bap_ddm_ready_with_upper.csv", show_col_types = FALSE) %>%
  mutate(
    subject_id = factor(subject_id),
    task = factor(task),
    effort_condition = factor(effort_condition, levels = c("Low_5_MVC", "High_MVC")),
    difficulty_level = factor(difficulty_level, levels = c("Standard", "Hard", "Easy")),
    decision = as.integer(dec_upper),
    is_nonstd = ifelse(difficulty_level == "Standard", 0L, 1L)  # Required for model predictions
  )

cat("✓ Loaded data: ", nrow(dd), " trials\n")
cat("  Subjects: ", n_distinct(dd$subject_id), "\n")
cat("  Cells (task × effort × difficulty): ", n_distinct(interaction(dd$task, dd$effort_condition, dd$difficulty_level)), "\n")

# Subject-aware, conditional predictions
cat("\n=== Generating Posterior Predictive Samples ===\n")
cat("This may take a while...\n")
cat("Using subject-aware predictions (re_formula=NULL)\n")
cat("Drawing 400 samples per trial...\n")

set.seed(20251119)

tryCatch({
  yrep <- posterior_predict(
    fit,
    newdata = dd,
    re_formula = NULL,  # Include random effects (subject-aware)
    ndraws = 400,
    allow_new_levels = FALSE
  )
  cat("✓ Generated posterior predictive samples\n")
  cat("  Dimensions: ", nrow(yrep), " draws × ", ncol(yrep), " trials\n")
}, error = function(e) {
  stop("Failed to generate posterior predictions: ", e$message)
})

# Simple cell-wise QP + KS (uses base R quantiles and ks.test)
cat("\n=== Computing PPC Metrics ===\n")

quantiles <- c(0.1, 0.3, 0.5, 0.7, 0.9)

# Create cell identifier
dd <- dd %>%
  mutate(
    cell = interaction(task, effort_condition, difficulty_level, drop = TRUE),
    row_idx = row_number()
  )

cat("Computing QP RMSE and KS per cell...\n")

summ <- dd %>%
  group_by(cell, task, effort_condition, difficulty_level) %>%
  group_map(~ {
    # Get indices for this cell
    cell_rows <- .x$row_idx
    rts <- .x$rt
    
    # Extract predictions for this cell (columns correspond to row indices)
    pred <- yrep[, cell_rows, drop = FALSE]
    
    # Pool draws across all trials in this cell
    pred_pool <- as.numeric(pred)
    
    # Remove any NA or invalid values
    rts_clean <- rts[!is.na(rts) & is.finite(rts)]
    pred_clean <- pred_pool[!is.na(pred_pool) & is.finite(pred_pool)]
    
    if (length(rts_clean) == 0 || length(pred_clean) == 0) {
      return(tibble(
        cell = as.character(.y$cell),
        task = as.character(.y$task),
        effort_condition = as.character(.y$effort_condition),
        difficulty_level = as.character(.y$difficulty_level),
        n_trials = length(rts),
        qp_rmse = NA_real_,
        ks = NA_real_
      ))
    }
    
    # QP RMSE: compare empirical vs model quantiles
    q_emp <- quantile(rts_clean, probs = quantiles, na.rm = TRUE)
    q_mod <- quantile(pred_clean, probs = quantiles, na.rm = TRUE)
    qp_rmse <- sqrt(mean((q_emp - q_mod)^2))
    
    # KS test: empirical vs pooled predictive
    # Suppress warnings about ties (common with discrete RTs)
    ks_result <- suppressWarnings(
      tryCatch(
        ks.test(rts_clean, pred_clean)$statistic,
        error = function(e) NA_real_
      )
    )
    
    tibble(
      cell = as.character(.y$cell),
      task = as.character(.y$task),
      effort_condition = as.character(.y$effort_condition),
      difficulty_level = as.character(.y$difficulty_level),
      n_trials = length(rts_clean),
      qp_rmse = as.numeric(qp_rmse),
      ks = as.numeric(ks_result)
    )
  }) %>%
  bind_rows()

cat("✓ Computed PPC metrics for ", nrow(summ), " cells\n")

# Summary statistics
cat("\n=== PPC Summary ===\n")
cat("QP RMSE:\n")
cat("  Mean: ", round(mean(summ$qp_rmse, na.rm = TRUE), 4), "\n", sep = "")
cat("  Median: ", round(median(summ$qp_rmse, na.rm = TRUE), 4), "\n", sep = "")
cat("  Max: ", round(max(summ$qp_rmse, na.rm = TRUE), 4), "\n", sep = "")
cat("  Cells with QP RMSE > 0.12: ", sum(summ$qp_rmse > 0.12, na.rm = TRUE), "\n", sep = "")

cat("\nKS statistic:\n")
cat("  Mean: ", round(mean(summ$ks, na.rm = TRUE), 4), "\n", sep = "")
cat("  Median: ", round(median(summ$ks, na.rm = TRUE), 4), "\n", sep = "")
cat("  Max: ", round(max(summ$ks, na.rm = TRUE), 4), "\n", sep = "")
cat("  Cells with KS > 0.20: ", sum(summ$ks > 0.20, na.rm = TRUE), "\n", sep = "")

# Write output
write_csv(summ, "output/publish/ppc_joint_minimal.csv")
cat("\n✓ Wrote output/publish/ppc_joint_minimal.csv\n")

cat("\n=== Cell-wise Results ===\n")
print(summ)

cat("\n✓ PPC complete!\n")

