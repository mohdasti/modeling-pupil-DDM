# =========================================================================
# DIFFICULTY MAPPING: WHERE DOES DIFFICULTY LIVE? (v vs. z vs. a)
# =========================================================================
# Fit six variants with difficulty on:
#   1) v-only:        rt|dec ~ difficulty + (1|subject); bias ~ 1;          bs ~ 1;          ndt ~ 1
#   2) z-only:        rt|dec ~ 1 + (1|subject);          bias ~ 1+difficulty + (1|subject); bs ~ 1; ndt ~ 1
#   3) a-only:        rt|dec ~ 1 + (1|subject);          bs   ~ 1+difficulty + (1|subject); bias ~ 1; ndt ~ 1
#   4) v+z:           rt|dec ~ difficulty + (1|subject); bias ~ 1+difficulty + (1|subject); bs ~ 1; ndt ~ 1
#   5) v+a:           rt|dec ~ difficulty + (1|subject); bs   ~ 1+difficulty + (1|subject); bias ~ 1; ndt ~ 1
#   6) v+z+a:         rt|dec ~ difficulty + (1|subject); bias ~ 1+difficulty + (1|subject); bs ~ 1+difficulty + (1|subject); ndt ~ 1
# 
# Use same priors/controls/inits as Model10
# Compute LOO for all, then write output/modelcomp/loo_difficulty_all.csv
# =========================================================================

library(brms)
library(dplyr)
library(readr)
library(loo)

cat("\n")
cat("================================================================================\n")
cat("DIFFICULTY MAPPING: v vs. z vs. a\n")
cat("================================================================================\n")
cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Set working directory
if (!file.exists("output/models")) {
  if (file.exists("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")) {
    setwd("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")
  }
}

# Create output directory
dir.create("output/modelcomp", recursive = TRUE, showWarnings = FALSE)

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

if (!"difficulty_level" %in% names(data)) {
  if ("stimulus_condition" %in% names(data)) {
    data$difficulty_level <- ifelse(
      data$stimulus_condition == "Standard", "Easy",
      ifelse(data$stimulus_condition == "Oddball", "Hard", NA_character_)
    )
  }
}

# Prepare data
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

cat("✓ Data loaded:", nrow(ddm_data), "trials\n\n")

# =========================================================================
# BASE PRIORS (Same as Model10)
# =========================================================================

base_priors <- c(
  # Drift rate (v) - identity link
  prior(normal(0, 1), class = "Intercept"),
  # Boundary separation (a/bs) - log link: center at log(1.7) for older adults
  prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
  # Non-decision time (t0/ndt) - log link: center at log(0.23) for response-signal design
  prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
  # Starting point bias (z) - logit link: centered at 0.5 with moderate spread
  prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
  # Random effects - subject-level variability
  prior(student_t(3, 0, 0.5), class = "sd")
)

# =========================================================================
# MODEL SPECIFICATIONS
# =========================================================================

# Model 1: v-only (difficulty on drift only)
model_v <- list(
  name = "v_only",
  formula = bf(
    rt | dec(decision) ~ difficulty_level + (1|subject_id),
    bs ~ 1 + (1|subject_id),
    ndt ~ 1,
    bias ~ 1 + (1|subject_id)
  ),
  priors = c(base_priors, prior(normal(0, 0.5), class = "b"))
)

# Model 2: z-only (difficulty on bias only)
model_z <- list(
  name = "z_only",
  formula = bf(
    rt | dec(decision) ~ 1 + (1|subject_id),
    bs ~ 1 + (1|subject_id),
    ndt ~ 1,
    bias ~ 1 + difficulty_level + (1|subject_id)
  ),
  priors = c(
    base_priors,
    prior(normal(0, 0.3), class = "b", dpar = "bias")  # Same as Model10
  )
)

# Model 3: a-only (difficulty on boundary only)
model_a <- list(
  name = "a_only",
  formula = bf(
    rt | dec(decision) ~ 1 + (1|subject_id),
    bs ~ 1 + difficulty_level + (1|subject_id),
    ndt ~ 1,
    bias ~ 1 + (1|subject_id)
  ),
  priors = c(
    base_priors,
    prior(normal(0, 0.20), class = "b", dpar = "bs")  # Same as Model10
  )
)

# Model 4: v+z (difficulty on drift + bias)
model_vz <- list(
  name = "v_z",
  formula = bf(
    rt | dec(decision) ~ difficulty_level + (1|subject_id),
    bs ~ 1 + (1|subject_id),
    ndt ~ 1,
    bias ~ 1 + difficulty_level + (1|subject_id)
  ),
  priors = c(
    base_priors,
    prior(normal(0, 0.5), class = "b"),  # Drift effects
    prior(normal(0, 0.3), class = "b", dpar = "bias")  # Bias effects
  )
)

# Model 5: v+a (difficulty on drift + boundary)
model_va <- list(
  name = "v_a",
  formula = bf(
    rt | dec(decision) ~ difficulty_level + (1|subject_id),
    bs ~ 1 + difficulty_level + (1|subject_id),
    ndt ~ 1,
    bias ~ 1 + (1|subject_id)
  ),
  priors = c(
    base_priors,
    prior(normal(0, 0.5), class = "b"),  # Drift effects
    prior(normal(0, 0.20), class = "b", dpar = "bs")  # Boundary effects
  )
)

# Model 6: v+z+a (difficulty on all three)
model_vza <- list(
  name = "v_z_a",
  formula = bf(
    rt | dec(decision) ~ difficulty_level + (1|subject_id),
    bs ~ 1 + difficulty_level + (1|subject_id),
    ndt ~ 1,
    bias ~ 1 + difficulty_level + (1|subject_id)
  ),
  priors = c(
    base_priors,
    prior(normal(0, 0.5), class = "b"),  # Drift effects
    prior(normal(0, 0.20), class = "b", dpar = "bs"),  # Boundary effects
    prior(normal(0, 0.3), class = "b", dpar = "bias")  # Bias effects
  )
)

# Safe initialization (same as Model10)
safe_init <- function(chain_id = 1) {
  list(
    Intercept_ndt = log(0.20),  # 200ms on log scale; safely below 250ms RT floor
    Intercept_bs  = log(1.3),   # Optional: tamer init for older adults
    Intercept_bias = 0,          # Optional: z ≈ 0.5 on logit scale
    Intercept     = 0            # Optional: drift intercept at 0
  )
}

# =========================================================================
# FIT MODELS
# =========================================================================

models_to_fit <- list(model_v, model_z, model_a, model_vz, model_va, model_vza)
fits <- list()
loos <- list()

cat("Fitting six difficulty mapping models:\n")
cat("  1. v-only:        rt|dec ~ difficulty + (1|subject); bias ~ 1;          bs ~ 1;          ndt ~ 1\n")
cat("  2. z-only:        rt|dec ~ 1 + (1|subject);          bias ~ 1+difficulty + (1|subject); bs ~ 1; ndt ~ 1\n")
cat("  3. a-only:        rt|dec ~ 1 + (1|subject);          bs   ~ 1+difficulty + (1|subject); bias ~ 1; ndt ~ 1\n")
cat("  4. v+z:           rt|dec ~ difficulty + (1|subject); bias ~ 1+difficulty + (1|subject); bs ~ 1; ndt ~ 1\n")
cat("  5. v+a:           rt|dec ~ difficulty + (1|subject); bs   ~ 1+difficulty + (1|subject); bias ~ 1; ndt ~ 1\n")
cat("  6. v+z+a:         rt|dec ~ difficulty + (1|subject); bias ~ 1+difficulty + (1|subject); bs ~ 1+difficulty + (1|subject); ndt ~ 1\n\n")
cat("Using same priors/controls/inits as Model10\n\n")

for (model_spec in models_to_fit) {
  model_name <- model_spec$name
  
  cat("================================================================================\n")
  cat(sprintf("FITTING: %s\n", model_name))
  cat("================================================================================\n")
  
  # Check if model already exists
  model_path <- file.path("output/models", paste0(model_name, ".rds"))
  if (file.exists(model_path)) {
    cat(sprintf("Loading existing model: %s\n", model_path))
    fit <- readRDS(model_path)
    fits[[model_name]] <- fit
  } else {
    cat("Fitting model...\n")
    fit_start <- Sys.time()
    
    fit <- brm(
      formula = model_spec$formula,
      data = ddm_data,
      family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
      prior = model_spec$priors,
      chains = 4,
      iter = 4000,
      warmup = 2000,
      cores = 4,
      init = safe_init,
      control = list(adapt_delta = 0.95, max_treedepth = 12),  # Same as Model10
      backend = "cmdstanr",
      file = model_path,
      file_refit = "on_change",
      refresh = 200,
      seed = 123
    )
    
    fit_elapsed <- difftime(Sys.time(), fit_start, units = "mins")
    cat(sprintf("✓ Model fitted (%.1f minutes)\n\n", as.numeric(fit_elapsed)))
    
    fits[[model_name]] <- fit
  }
  
  # Compute LOO
  cat("Computing LOO...\n")
  loo_fit <- tryCatch({
    loo(fit, cores = 4)
  }, error = function(e) {
    cat(sprintf("⚠️  LOO computation failed: %s\n", e$message))
    cat("  Trying with reloo=TRUE...\n")
    tryCatch({
      loo(fit, cores = 4, reloo = TRUE)
    }, error = function(e2) {
      cat(sprintf("❌ reloo also failed: %s\n", e2$message))
      NULL
    })
  })
  
  if (!is.null(loo_fit)) {
    loos[[model_name]] <- loo_fit
    cat(sprintf("✓ LOO: elpd = %.2f, SE = %.2f\n", loo_fit$estimates["elpd_loo", "Estimate"], 
                loo_fit$estimates["elpd_loo", "SE"]))
  } else {
    cat("❌ LOO computation failed for this model\n")
  }
  
  cat("\n")
}

# =========================================================================
# MODEL COMPARISON: LOO COMPARE
# =========================================================================

cat("================================================================================\n")
cat("MODEL COMPARISON\n")
cat("================================================================================\n\n")

if (length(loos) >= 2) {
  # LOO comparison
  loo_compare_result <- loo_compare(loos)
  
  cat("LOO Comparison (elpd_diff):\n")
  print(loo_compare_result)
  cat("\n")
  
  # Stacking weights
  cat("Computing stacking weights...\n")
  stacking_weights <- tryCatch({
    loo_model_weights(loos, method = "stacking")
  }, error = function(e) {
    cat(sprintf("⚠️  Stacking weights failed: %s\n", e$message))
    NULL
  })
  
  if (!is.null(stacking_weights)) {
    cat("Stacking weights:\n")
    print(stacking_weights)
    cat("\n")
  }
  
  # Pseudo-BMA weights (with Bayesian bootstrap)
  pseudo_bma_weights <- tryCatch({
    loo_model_weights(loos, method = "pseudobma")
  }, error = function(e) {
    cat(sprintf("⚠️  Pseudo-BMA weights failed: %s\n", e$message))
    NULL
  })
  
  if (!is.null(pseudo_bma_weights)) {
    cat("Pseudo-BMA weights:\n")
    print(pseudo_bma_weights)
    cat("\n")
  }
} else {
  cat("⚠️  Need at least 2 models with successful LOO for comparison\n\n")
  loo_compare_result <- NULL
  stacking_weights <- NULL
  pseudo_bma_weights <- NULL
}

# =========================================================================
# EXTRACT DETAILED RESULTS
# =========================================================================

cat("Extracting detailed results...\n")

# LOO statistics with weights and differences
loo_details <- data.frame(
  model = character(),
  elpd = numeric(),
  se = numeric(),
  p_loo = numeric(),
  weight_stack = numeric(),
  weight_pbma = numeric(),
  elpd_diff_from_best = numeric(),
  se_diff = numeric(),
  stringsAsFactors = FALSE
)

# Get best model from loo_compare
best_model_name <- NULL
if (!is.null(loo_compare_result) && nrow(loo_compare_result) > 0) {
  best_model_name <- rownames(loo_compare_result)[1]
}

for (model_name in names(loos)) {
  loo_fit <- loos[[model_name]]
  if (!is.null(loo_fit)) {
    # Get stacking weight
    stack_wt <- if (!is.null(stacking_weights) && model_name %in% names(stacking_weights)) {
      as.numeric(stacking_weights[model_name])
    } else {
      NA_real_
    }
    
    # Get pseudo-BMA weight
    pbma_wt <- if (!is.null(pseudo_bma_weights) && model_name %in% names(pseudo_bma_weights)) {
      as.numeric(pseudo_bma_weights[model_name])
    } else {
      NA_real_
    }
    
    # Get elpd_diff and se_diff from loo_compare
    elpd_diff_val <- NA_real_
    se_diff_val <- NA_real_
    if (!is.null(loo_compare_result) && model_name %in% rownames(loo_compare_result)) {
      elpd_diff_val <- loo_compare_result[model_name, "elpd_diff"]
      se_diff_val <- loo_compare_result[model_name, "se_diff"]
    } else if (!is.null(best_model_name) && model_name == best_model_name) {
      # Best model has elpd_diff = 0
      elpd_diff_val <- 0
      se_diff_val <- 0
    }
    
    loo_details <- rbind(loo_details, data.frame(
      model = model_name,
      elpd = loo_fit$estimates["elpd_loo", "Estimate"],
      se = loo_fit$estimates["elpd_loo", "SE"],
      p_loo = loo_fit$estimates["p_loo", "Estimate"],
      weight_stack = stack_wt,
      weight_pbma = pbma_wt,
      elpd_diff_from_best = elpd_diff_val,
      se_diff = se_diff_val,
      stringsAsFactors = FALSE
    ))
  }
}

# =========================================================================
# SAVE RESULTS
# =========================================================================

csv_file <- "output/modelcomp/loo_difficulty_all.csv"
write.csv(loo_details, csv_file, row.names = FALSE)

cat("✓ LOO results saved to:", csv_file, "\n")
cat("  Columns: model, elpd, se, p_loo, weight_stack, weight_pbma, elpd_diff_from_best, se_diff\n\n")

# =========================================================================
# CREATE 1-PAGE SUMMARY
# =========================================================================

cat("Creating 1-page summary...\n")

summary_file <- "output/modelcomp/difficulty_mapping_summary.md"

summary_content <- paste0(
  "# Difficulty Mapping: Where Does Difficulty Live? (v vs. z vs. a)\n\n",
  "**Analysis Date:** ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n",
  "## Model Variants\n\n",
  "1. **Difficulty on v (drift)**: Current Model3_Difficulty\n",
  "2. **Difficulty on z (bias)**: Starting point bias varies with difficulty\n",
  "3. **Difficulty on a (boundary)**: Boundary separation varies with difficulty\n\n",
  "## LOO Comparison\n\n"
)

if (!is.null(loo_compare_result) && nrow(loo_compare_result) > 0) {
  summary_content <- paste0(summary_content,
    "| Model | elpd_diff | SE_diff |\n",
    "|-------|-----------|---------|\n"
  )
  
  for (i in 1:nrow(loo_compare_result)) {
    model_name <- rownames(loo_compare_result)[i]
    elpd_diff <- loo_compare_result[i, "elpd_diff"]
    se_diff <- loo_compare_result[i, "se_diff"]
    
    # Format model name for readability
    model_display <- gsub("Difficulty_on_", "", model_name)
    if (model_display == "v") model_display <- "v (drift)"
    if (model_display == "z") model_display <- "z (bias)"
    if (model_display == "a") model_display <- "a (boundary)"
    
    summary_content <- paste0(summary_content,
      "| ", model_display, " | ", 
      sprintf("%.2f", elpd_diff), " | ",
      sprintf("%.2f", se_diff), " |\n"
    )
  }
  
  summary_content <- paste0(summary_content, "\n")
  summary_content <- paste0(summary_content,
    "**Best model:** ", gsub("Difficulty_on_", "", rownames(loo_compare_result)[1]), "\n\n"
  )
}

# LOO Statistics Table
summary_content <- paste0(summary_content,
  "## LOO Statistics\n\n",
  "| Model | elpd_loo | SE | p_loo | SE | LOOIC | SE |\n",
  "|-------|----------|----|----|----|----|----|\n"
)

for (i in 1:nrow(loo_details)) {
  row <- loo_details[i, ]
  model_display <- gsub("Difficulty_on_", "", row$model)
  if (model_display == "v") model_display <- "v (drift)"
  if (model_display == "z") model_display <- "z (bias)"
  if (model_display == "a") model_display <- "a (boundary)"
  
  summary_content <- paste0(summary_content,
    "| ", model_display, " | ",
    sprintf("%.2f", row$elpd_loo), " | ",
    sprintf("%.2f", row$se_elpd_loo), " | ",
    sprintf("%.2f", row$p_loo), " | ",
    sprintf("%.2f", row$se_p_loo), " | ",
    sprintf("%.2f", row$looic), " | ",
    sprintf("%.2f", row$se_looic), " |\n"
  )
}

summary_content <- paste0(summary_content, "\n")

# Weights
if (!is.null(stacking_weights) || !is.null(pseudo_bma_weights)) {
  summary_content <- paste0(summary_content, "## Model Weights\n\n")
  
  if (!is.null(stacking_weights)) {
    summary_content <- paste0(summary_content, "### Stacking Weights\n\n")
    for (i in 1:length(stacking_weights)) {
      model_name <- names(stacking_weights)[i]
      weight <- stacking_weights[i]
      model_display <- gsub("Difficulty_on_", "", model_name)
      if (model_display == "v") model_display <- "v (drift)"
      if (model_display == "z") model_display <- "z (bias)"
      if (model_display == "a") model_display <- "a (boundary)"
      
      summary_content <- paste0(summary_content,
        "- **", model_display, "**: ", sprintf("%.3f", weight), "\n"
      )
    }
    summary_content <- paste0(summary_content, "\n")
  }
  
  if (!is.null(pseudo_bma_weights)) {
    summary_content <- paste0(summary_content, "### Pseudo-BMA Weights\n\n")
    for (i in 1:length(pseudo_bma_weights)) {
      model_name <- names(pseudo_bma_weights)[i]
      weight <- pseudo_bma_weights[i]
      model_display <- gsub("Difficulty_on_", "", model_name)
      if (model_display == "v") model_display <- "v (drift)"
      if (model_display == "z") model_display <- "z (bias)"
      if (model_display == "a") model_display <- "a (boundary)"
      
      summary_content <- paste0(summary_content,
        "- **", model_display, "**: ", sprintf("%.3f", weight), "\n"
      )
    }
    summary_content <- paste0(summary_content, "\n")
  }
}

# Interpretation
summary_content <- paste0(summary_content,
  "## Interpretation\n\n",
  "- **elpd_diff**: Expected log pointwise predictive density difference relative to best model\n",
  "- **Negative elpd_diff**: Worse than best model (more negative = worse)\n",
  "- **p_loo**: Effective number of parameters (higher = more complex)\n",
  "- **LOOIC**: Leave-one-out information criterion (-2 × elpd_loo)\n",
  "- **Stacking weights**: Optimal predictive weights (sum to 1)\n",
  "- **Pseudo-BMA weights**: Bayesian model averaging weights\n\n"
)

# Conclusion
if (!is.null(loo_compare_result) && nrow(loo_compare_result) > 0) {
  best_model <- rownames(loo_compare_result)[1]
  best_display <- gsub("Difficulty_on_", "", best_model)
  
  summary_content <- paste0(summary_content,
    "## Conclusion\n\n",
    "The **", best_display, "** model shows the best predictive performance.\n",
    "This suggests that difficulty effects are primarily captured in the **",
    ifelse(best_display == "v", "drift rate", 
           ifelse(best_display == "z", "starting point bias", "boundary separation")),
    "** parameter.\n"
  )
}

writeLines(summary_content, summary_file)
cat("✓ Summary saved to:", summary_file, "\n\n")

cat("================================================================================\n")
cat("ANALYSIS COMPLETE\n")
cat("================================================================================\n")
cat("Completed:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("Outputs:\n")
cat("  - LOO results: output/modelcomp/loo_difficulty_all.csv\n")
cat("    Columns: model, elpd, se, p_loo, weight_stack, weight_pbma\n")
cat("  - Summary: output/modelcomp/difficulty_mapping_summary.md\n\n")

