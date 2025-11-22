# =========================================================================
# FIT MODEL3D: Difficulty Effects on Boundary and Bias (Not Just Drift)
# =========================================================================
# Compare Model3_Difficulty vs Model3D (difficulty on bs and bias)
# =========================================================================

library(brms)
library(dplyr)
library(readr)
library(loo)

cat("\n")
cat("================================================================================\n")
cat("FITTING MODEL3D: DIFFICULTY ON BOUNDARY & BIAS\n")
cat("================================================================================\n")
cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Set working directory
if (!file.exists("output/models")) {
  if (file.exists("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")) {
    setwd("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")
  }
}

# Create output directory
dir.create("output/model_comp", recursive = TRUE, showWarnings = FALSE)

# =========================================================================
# LOAD DATA
# =========================================================================

cat("Loading data...\n")

data_file <- "data/analysis_ready/bap_ddm_ready.csv"
if (!file.exists(data_file)) {
  stop("Data file not found: ", data_file)
}

data <- read_csv(data_file, show_col_types = FALSE)

# Harmonize column names (as in main script)
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

# Apply filters
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
# LOAD EXISTING MODEL3_Difficulty
# =========================================================================

cat("Loading existing Model3_Difficulty...\n")

model3_file <- "output/models/Model3_Difficulty.rds"
if (!file.exists(model3_file)) {
  stop("Model3_Difficulty not found. Please run the main DDM analysis first.")
}

model3 <- readRDS(model3_file)
cat("✓ Model3_Difficulty loaded\n\n")

# =========================================================================
# FIT MODEL3D: Difficulty on bs and bias (not drift)
# =========================================================================

cat("================================================================================\n")
cat("FITTING MODEL3D\n")
cat("================================================================================\n\n")

cat("Model specification:\n")
cat("  rt | dec(decision) ~ difficulty_level + (1|subject_id)\n")
cat("  bs  ~ 1 + difficulty_level + (1|subject_id)\n")
cat("  bias ~ 1 + difficulty_level + (1|subject_id)\n")
cat("  ndt  ~ 1\n\n")

# Define Model3D formula
model3d_formula <- brms::bf(
  rt | dec(decision) ~ difficulty_level + (1|subject_id),
  bs ~ 1 + difficulty_level + (1|subject_id),
  ndt ~ 1,
  bias ~ 1 + difficulty_level + (1|subject_id)
)

# Define priors for Model3D
# Base priors (same as standard models)
base_priors <- c(
  prior(normal(0, 1), class = "Intercept"),
  prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
  prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
  prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
  prior(student_t(3, 0, 0.5), class = "sd")
)

# Priors for difficulty effects
model3d_priors <- c(
  base_priors,
  prior(normal(0, 0.5), class = "b"),  # Drift predictors
  prior(normal(0, 0.20), class = "b", dpar = "bs"),  # bs predictors (log scale)
  prior(normal(0, 0.30), class = "b", dpar = "bias")  # bias predictors (logit scale)
)

# Safe initialization (as in main script)
safe_init <- function(chain_id = 1) {
  list(
    Intercept_ndt = log(0.18),
    Intercept_bs  = log(1.3),
    Intercept_bias = 0,
    Intercept     = 0
  )
}

cat("Fitting Model3D...\n")
cat("  Chains: 4\n")
cat("  Iterations: 6000 (warmup: 2000)\n")
cat("  adapt_delta: 0.98\n")
cat("  This may take 1-2 hours...\n\n")

fit_start_time <- Sys.time()

model3d <- brm(
  formula = model3d_formula,
  data = ddm_data,
  family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
  prior = model3d_priors,
  chains = 4,
  iter = 6000,
  warmup = 2000,
  cores = 4,
  init = safe_init,
  control = list(adapt_delta = 0.98, max_treedepth = 12),
  backend = "cmdstanr",
  file = "output/models/Model3D_Difficulty_bs_bias",
  file_refit = "on_change",
  refresh = 100
)

fit_duration <- difftime(Sys.time(), fit_start_time, units = "mins")
cat("\n✓ Model3D fitted successfully!\n")
cat("  Duration:", round(fit_duration, 1), "minutes\n\n")

# =========================================================================
# EXTRACT LOO FOR BOTH MODELS
# =========================================================================

cat("================================================================================\n")
cat("EXTRACTING LOO (Leave-One-Out) COMPARISON\n")
cat("================================================================================\n\n")

cat("Computing LOO for Model3_Difficulty...\n")
loo3 <- loo(model3, cores = 4)
cat("✓ Model3_Difficulty LOO computed\n\n")

cat("Computing LOO for Model3D...\n")
loo3d <- loo(model3d, cores = 4)
cat("✓ Model3D LOO computed\n\n")

# =========================================================================
# MODEL COMPARISON
# =========================================================================

cat("================================================================================\n")
cat("MODEL COMPARISON: LOO\n")
cat("================================================================================\n\n")

loo_compare_result <- loo_compare(loo3, loo3d)

cat("LOO Comparison:\n")
print(loo_compare_result)
cat("\n")

# Extract comparison statistics
comparison_summary <- data.frame(
  model = rownames(loo_compare_result),
  elpd_diff = loo_compare_result[, "elpd_diff"],
  se_diff = loo_compare_result[, "se_diff"],
  stringsAsFactors = FALSE
)

cat("Interpretation:\n")
best_model <- rownames(loo_compare_result)[1]
if (best_model == "model3d") {
  cat("  ✓ Model3D (difficulty on bs & bias) is preferred\n")
  cat("    Elpd difference:", round(loo_compare_result[1, "elpd_diff"], 2), "\n")
  cat("    SE:", round(loo_compare_result[1, "se_diff"], 2), "\n")
} else {
  cat("  ✓ Model3_Difficulty (difficulty on drift only) is preferred\n")
  cat("    Elpd difference:", round(loo_compare_result[1, "elpd_diff"], 2), "\n")
  cat("    SE:", round(loo_compare_result[1, "se_diff"], 2), "\n")
}
cat("\n")

# =========================================================================
# SAVE RESULTS
# =========================================================================

cat("================================================================================\n")
cat("SAVING RESULTS\n")
cat("================================================================================\n\n")

# Save LOO comparison
write.csv(comparison_summary,
          file = "output/model_comp/loo_difficulty_vs_bias.csv",
          row.names = FALSE)

# Create detailed summary with both LOO values
loo_summary <- data.frame(
  model = c("Model3_Difficulty", "Model3D_Difficulty_bs_bias"),
  elpd_loo = c(loo3$estimates["elpd_loo", "Estimate"], 
               loo3d$estimates["elpd_loo", "Estimate"]),
  se_elpd_loo = c(loo3$estimates["elpd_loo", "SE"],
                  loo3d$estimates["elpd_loo", "SE"]),
  p_loo = c(loo3$estimates["p_loo", "Estimate"],
            loo3d$estimates["p_loo", "Estimate"]),
  se_p_loo = c(loo3$estimates["p_loo", "SE"],
               loo3d$estimates["p_loo", "SE"]),
  looic = c(loo3$estimates["looic", "Estimate"],
            loo3d$estimates["looic", "Estimate"]),
  se_looic = c(loo3$estimates["looic", "SE"],
               loo3d$estimates["looic", "SE"])
)

# Add comparison info
loo_summary$elpd_diff <- c(
  ifelse(best_model == "model3", 0, loo_compare_result["model3", "elpd_diff"]),
  ifelse(best_model == "model3d", 0, loo_compare_result["model3d", "elpd_diff"])
)
loo_summary$se_diff <- c(
  ifelse(best_model == "model3", 0, loo_compare_result["model3", "se_diff"]),
  ifelse(best_model == "model3d", 0, loo_compare_result["model3d", "se_diff"])
)

write.csv(loo_summary,
          file = "output/model_comp/loo_difficulty_vs_bias_detailed.csv",
          row.names = FALSE)

# Save individual LOO objects
saveRDS(loo3, "output/model_comp/loo_Model3_Difficulty.rds")
saveRDS(loo3d, "output/model_comp/loo_Model3D.rds")
saveRDS(loo_compare_result, "output/model_comp/loo_compare_result.rds")

cat("✓ Results saved:\n")
cat("  - output/model_comp/loo_difficulty_vs_bias.csv\n")
cat("  - output/model_comp/loo_difficulty_vs_bias_detailed.csv\n")
cat("  - output/model_comp/loo_Model3_Difficulty.rds\n")
cat("  - output/model_comp/loo_Model3D.rds\n")
cat("  - output/model_comp/loo_compare_result.rds\n")
cat("  - output/models/Model3D_Difficulty_bs_bias.rds\n\n")

# =========================================================================
# SUMMARY STATISTICS
# =========================================================================

cat("================================================================================\n")
cat("MODEL SUMMARY\n")
cat("================================================================================\n\n")

cat("Model3_Difficulty:\n")
cat("  LOOIC:", round(loo3$estimates["looic", "Estimate"], 2), 
    "±", round(loo3$estimates["looic", "SE"], 2), "\n")
cat("  ELPD:", round(loo3$estimates["elpd_loo", "Estimate"], 2), "\n")
cat("  p_loo:", round(loo3$estimates["p_loo", "Estimate"], 2), "\n\n")

cat("Model3D (difficulty on bs & bias):\n")
cat("  LOOIC:", round(loo3d$estimates["looic", "Estimate"], 2),
    "±", round(loo3d$estimates["looic", "SE"], 2), "\n")
cat("  ELPD:", round(loo3d$estimates["elpd_loo", "Estimate"], 2), "\n")
cat("  p_loo:", round(loo3d$estimates["p_loo", "Estimate"], 2), "\n\n")

cat("================================================================================\n")
cat("COMPARISON COMPLETE\n")
cat("================================================================================\n\n")








