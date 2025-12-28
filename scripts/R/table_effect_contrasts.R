# R/table_effect_contrasts.R
# Compute posterior contrasts and directional probabilities for v, bs, bias across Difficulty, Task, and Effort

suppressPackageStartupMessages({
  library(brms)
  library(tidyverse)
  library(posterior)
})

# Set working directory
if (basename(getwd()) == "R") {
  setwd("..")
}

# Load model
fit_file <- "output/publish/fit_primary_vza.rds"
if (!file.exists(fit_file)) {
  fit_file <- "output/models/primary_vza.rds"
}
if (!file.exists(fit_file)) {
  stop("Could not find primary model file. Expected: output/publish/fit_primary_vza.rds or output/models/primary_vza.rds")
}

fit <- readRDS(fit_file)
cat("Loaded model from:", fit_file, "\n")

# Get factor levels from model data and ensure proper factor encoding
model_data <- fit$data
unique_subjects <- unique(model_data$subject_id)

# Helper function to create proper newdata frame
create_newdata <- function(task_val, effort_val, diff_val, subject_val = NULL) {
  if (is.null(subject_val)) {
    subject_val <- unique_subjects[1]  # Use first subject as representative
  }
  tibble(
    task = factor(task_val, levels = levels(model_data$task)),
    effort_condition = factor(effort_val, levels = levels(model_data$effort_condition)),
    difficulty_level = factor(diff_val, levels = levels(model_data$difficulty_level)),
    subject_id = factor(subject_val, levels = levels(model_data$subject_id))
  )
}

# Helper function to compute contrasts
compute_contrast <- function(fit, dpar, num_task, num_effort, num_diff, 
                             den_task, den_effort, den_diff, rope = 0, contrast_label = "") {
  # Create proper newdata frames
  num_full <- create_newdata(num_task, num_effort, num_diff)
  den_full <- create_newdata(den_task, den_effort, den_diff)
  
  # Get posterior predictions on link scale (population-level, no random effects)
  num_pred <- posterior_linpred(fit, dpar = dpar, transform = FALSE, newdata = num_full, re_formula = NA)
  den_pred <- posterior_linpred(fit, dpar = dpar, transform = FALSE, newdata = den_full, re_formula = NA)
  
  # If multiple rows in newdata, average across them (for pooled contrasts)
  if (nrow(num_full) > 1) {
    num_pred <- rowMeans(num_pred)
  } else {
    num_pred <- as.numeric(num_pred)
  }
  if (nrow(den_full) > 1) {
    den_pred <- rowMeans(den_pred)
  } else {
    den_pred <- as.numeric(den_pred)
  }
  
  # Compute difference (num - den) for each posterior draw
  est <- num_pred - den_pred
  
  # Create contrast description
  if (contrast_label == "") {
    contrast_desc <- paste0(
      paste(capture.output(print(num_data)), collapse = " "),
      " - ",
      paste(capture.output(print(den_data)), collapse = " ")
    )
  } else {
    contrast_desc <- contrast_label
  }
  
  tibble(
    parameter = dpar,
    contrast_label = contrast_desc,
    mean = mean(est),
    q2.5 = quantile(est, 0.025),
    q97.5 = quantile(est, 0.975),
    p_gt0 = mean(est > 0),
    p_lt0 = mean(est < 0),
    p_in_rope = mean(abs(est) < rope)
  )
}

# Define ROPE thresholds (on link scale)
rope_v <- 0.02      # Drift (identity link)
rope_bs <- 0.05     # Boundary (log link)
rope_bias <- 0.05   # Bias (logit link)
rope_ndt <- 0.02    # NDT (log link)

results <- list()

# 1. Easy vs Hard on v, bs, bias (per task, holding effort at Low)
for (task_val in c("ADT", "VDT")) {
  results[[length(results) + 1]] <- compute_contrast(fit, "mu", task_val, "Low_5_MVC", "Easy",
                                                       task_val, "Low_5_MVC", "Hard", rope_v, 
                                                       paste0("Easy vs Hard (v, ", task_val, ")"))
  
  results[[length(results) + 1]] <- compute_contrast(fit, "bs", task_val, "Low_5_MVC", "Easy",
                                                       task_val, "Low_5_MVC", "Hard", rope_bs,
                                                       paste0("Easy vs Hard (bs, ", task_val, ")"))
  
  results[[length(results) + 1]] <- compute_contrast(fit, "bias", task_val, "Low_5_MVC", "Easy",
                                                       task_val, "Low_5_MVC", "Hard", rope_bias,
                                                       paste0("Easy vs Hard (bias, ", task_val, ")"))
}

# 2. Task (VDT - ADT) differences (per difficulty, holding effort at Low)
for (diff_val in c("Standard", "Hard", "Easy")) {
  results[[length(results) + 1]] <- compute_contrast(fit, "mu", "VDT", "Low_5_MVC", diff_val,
                                                       "ADT", "Low_5_MVC", diff_val, rope_v,
                                                       paste0("VDT - ADT (v, ", diff_val, ")"))
  
  results[[length(results) + 1]] <- compute_contrast(fit, "bs", "VDT", "Low_5_MVC", diff_val,
                                                       "ADT", "Low_5_MVC", diff_val, rope_bs,
                                                       paste0("VDT - ADT (bs, ", diff_val, ")"))
  
  results[[length(results) + 1]] <- compute_contrast(fit, "bias", "VDT", "Low_5_MVC", diff_val,
                                                       "ADT", "Low_5_MVC", diff_val, rope_bias,
                                                       paste0("VDT - ADT (bias, ", diff_val, ")"))
}

# 3. Effort (High - Low) on v and ndt
# For v: use Standard difficulty, ADT task as representative
results[[length(results) + 1]] <- compute_contrast(fit, "mu", "ADT", "High_MVC", "Standard",
                                                     "ADT", "Low_5_MVC", "Standard", rope_v,
                                                     "High - Low MVC (v, ADT/Standard)")

# For ndt: use ADT task as representative (ndt doesn't depend on difficulty)
results[[length(results) + 1]] <- compute_contrast(fit, "ndt", "ADT", "High_MVC", "Standard",
                                                     "ADT", "Low_5_MVC", "Standard", rope_ndt,
                                                     "High - Low MVC (ndt, ADT)")

# Combine all results
out <- bind_rows(results) %>%
  select(contrast_label, parameter, mean, q2.5, q97.5, p_gt0, p_lt0, p_in_rope)

# Save
dir.create("output/publish", recursive = TRUE, showWarnings = FALSE)
write_csv(out, "output/publish/table_effect_contrasts.csv")
cat("✓ Saved: output/publish/table_effect_contrasts.csv\n")
cat("Rows:", nrow(out), "\n")

