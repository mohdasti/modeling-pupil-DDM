# R/summarize_bias_and_compare.R

# Quick summaries (v(Standard), z, LOO) for both models:
# 1. Standard-only bias model (fit_standard_bias_only.rds)
# 2. Joint model with Standard drift constrained (fit_joint_vza_stdconstrained.rds)

suppressPackageStartupMessages({
  library(brms)
  library(dplyr)
  library(readr)
  library(posterior)
  library(loo)
})

# Ensure output directory exists
dir.create("output/publish", recursive = TRUE, showWarnings = FALSE)

cat("=== Loading Models ===\n")

# Load models
m_bias_path <- "output/publish/fit_standard_bias_only.rds"
m_joint_path <- "output/publish/fit_joint_vza_stdconstrained.rds"

if (!file.exists(m_bias_path)) {
  stop("Standard-only bias model not found: ", m_bias_path)
}
if (!file.exists(m_joint_path)) {
  stop("Joint model not found: ", m_joint_path)
}

m_bias <- readRDS(m_bias_path)
m_joint <- readRDS(m_joint_path)

cat("✓ Loaded Standard-only bias model\n")
cat("✓ Loaded Joint model\n")

# Function to extract fixed effects as a data frame
fx <- function(fit) {
  fe <- fixef(fit)
  as.data.frame(fe) %>%
    tibble::rownames_to_column("param") %>%
    as_tibble()
}

cat("\n=== Extracting Fixed Effects ===\n")

fx_bias <- fx(m_bias)
fx_joint <- fx(m_joint)

cat("Standard-only model: ", nrow(fx_bias), " fixed effects\n")
cat("Joint model: ", nrow(fx_joint), " fixed effects\n")

write_csv(fx_bias, "output/publish/fixed_effects_standard_bias_only.csv")
write_csv(fx_joint, "output/publish/fixed_effects_joint_vza_stdconstrained.csv")

cat("✓ Wrote fixed effects tables\n")

# Extract v(Standard) from the joint model
# With 0 + difficulty_level, the coefficient should be named "difficulty_levelStandard"
cat("\n=== Extracting v(Standard) from Joint Model ===\n")

# Try multiple possible parameter names
v_std_candidates <- fx_joint %>%
  filter(
    grepl("difficulty_levelStandard", param) |
    grepl("^b_rt\\|dec.*difficulty_levelStandard", param) |
    (grepl("^b_", param) & grepl("Standard", param) & !grepl("bias|bs|ndt", param))
  )

if (nrow(v_std_candidates) == 0) {
  cat("Warning: Could not find v(Standard) coefficient. Available drift parameters:\n")
  drift_params <- fx_joint %>%
    filter(grepl("^b_", param) & !grepl("bias|bs|ndt", param))
  print(drift_params)
  v_std <- tibble(
    param = "difficulty_levelStandard",
    Estimate = NA_real_,
    Est.Error = NA_real_,
    Q2.5 = NA_real_,
    Q97.5 = NA_real_,
    note = "Parameter not found - check model output"
  )
} else {
  v_std <- v_std_candidates
  cat("Found v(Standard) parameter:\n")
  print(v_std)
}

write_csv(v_std, "output/publish/v_standard_joint.csv")
cat("✓ Wrote v(Standard) summary\n")

# Extract bias (z) parameters from both models
cat("\n=== Extracting Bias (z) Parameters ===\n")

bias_bias <- fx_bias %>%
  filter(grepl("bias", param))

bias_joint <- fx_joint %>%
  filter(grepl("bias", param))

cat("Standard-only model bias parameters:\n")
print(bias_bias)
cat("\nJoint model bias parameters:\n")
print(bias_joint)

write_csv(bias_bias, "output/publish/bias_standard_bias_only.csv")
write_csv(bias_joint, "output/publish/bias_joint_vza_stdconstrained.csv")
cat("✓ Wrote bias parameter summaries\n")

# Compute LOO (optional but useful)
cat("\n=== Computing LOO ===\n")
cat("This may take a while...\n")

tryCatch({
  cat("Computing LOO for Standard-only model...\n")
  loo_bias <- loo(m_bias, cores = 2)
  loo_bias_df <- as.data.frame(loo_bias$estimates) %>%
    tibble::rownames_to_column("metric")
  write_csv(loo_bias_df, "output/publish/loo_standard_bias_only.csv")
  cat("✓ LOO for Standard-only model:\n")
  print(loo_bias)
}, error = function(e) {
  warning("LOO computation failed for Standard-only model: ", e$message)
  cat("Skipping LOO for Standard-only model\n")
})

tryCatch({
  cat("\nComputing LOO for Joint model...\n")
  loo_joint <- loo(m_joint, cores = 2)
  loo_joint_df <- as.data.frame(loo_joint$estimates) %>%
    tibble::rownames_to_column("metric")
  write_csv(loo_joint_df, "output/publish/loo_joint_vza_stdconstrained.csv")
  cat("✓ LOO for Joint model:\n")
  print(loo_joint)
}, error = function(e) {
  warning("LOO computation failed for Joint model: ", e$message)
  cat("Skipping LOO for Joint model\n")
})

# Summary comparison
cat("\n=== Summary Comparison ===\n")

cat("\n1. Drift (v) on Standard trials:\n")
cat("   Standard-only model: v = intercept (should be ≈ 0)\n")
if (nrow(v_std) > 0 && !is.na(v_std$Estimate[1])) {
  cat("   Joint model: v(Standard) = ", round(v_std$Estimate[1], 4), 
      " [", round(v_std$Q2.5[1], 4), ", ", round(v_std$Q97.5[1], 4), "]\n", sep = "")
} else {
  cat("   Joint model: v(Standard) not found (check parameter names)\n")
}

cat("\n2. Bias (z) intercept (logit scale):\n")
bias_int_bias <- bias_bias %>% filter(grepl("Intercept", param))
bias_int_joint <- bias_joint %>% filter(grepl("Intercept", param))
if (nrow(bias_int_bias) > 0) {
  cat("   Standard-only model: ", round(bias_int_bias$Estimate[1], 4),
      " [", round(bias_int_bias$Q2.5[1], 4), ", ", round(bias_int_bias$Q97.5[1], 4), "]\n", sep = "")
}
if (nrow(bias_int_joint) > 0) {
  cat("   Joint model: ", round(bias_int_joint$Estimate[1], 4),
      " [", round(bias_int_joint$Q2.5[1], 4), ", ", round(bias_int_joint$Q97.5[1], 4), "]\n", sep = "")
}

cat("\n3. Model comparison (if LOO computed):\n")
if (exists("loo_bias") && exists("loo_joint")) {
  cat("   Standard-only ELPD: ", round(loo_bias$estimates["elpd_loo", "Estimate"], 2), "\n", sep = "")
  cat("   Joint ELPD: ", round(loo_joint$estimates["elpd_loo", "Estimate"], 2), "\n", sep = "")
  elpd_diff <- loo_joint$estimates["elpd_loo", "Estimate"] - loo_bias$estimates["elpd_loo", "Estimate"]
  cat("   ΔELPD (Joint - Standard-only): ", round(elpd_diff, 2), "\n", sep = "")
  cat("   Note: Models use different data (Standard-only vs all trials), so direct comparison may not be meaningful\n")
} else {
  cat("   LOO not computed for both models\n")
}

cat("\n=== Output Files ===\n")
cat("✓ output/publish/fixed_effects_standard_bias_only.csv\n")
cat("✓ output/publish/fixed_effects_joint_vza_stdconstrained.csv\n")
cat("✓ output/publish/v_standard_joint.csv\n")
cat("✓ output/publish/bias_standard_bias_only.csv\n")
cat("✓ output/publish/bias_joint_vza_stdconstrained.csv\n")
if (exists("loo_bias")) cat("✓ output/publish/loo_standard_bias_only.csv\n")
if (exists("loo_joint")) cat("✓ output/publish/loo_joint_vza_stdconstrained.csv\n")

cat("\n✓ Summary complete!\n")

