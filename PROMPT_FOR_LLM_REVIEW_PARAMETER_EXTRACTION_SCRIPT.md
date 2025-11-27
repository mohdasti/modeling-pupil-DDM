# Prompt for LLM: Review Parameter Extraction and Statistical Analysis Script

**Date:** 2025-11-26  
**Purpose:** Get second opinion on parameter extraction script before running on production models

---

## Context

I am conducting hierarchical Bayesian drift-diffusion model (DDM) analysis using `brms` in R. I've created a comprehensive script to extract parameter estimates, compute contrasts, perform statistical tests, and calculate effect sizes from two fitted models:

1. **Standard-only bias model** (`standard_bias_only.rds`) - 3,597 Standard trials
2. **Primary model** (`primary_vza.rds`) - 17,834 total trials

The script needs to extract:
- Parameter estimates (fixed effects) on link scales
- Condition-specific parameter values (on natural scales where appropriate)
- Effect contrasts (difficulty, task, effort)
- Statistical hypothesis tests
- Effect sizes (Cohen's d approximations)

---

## Script Overview

**File:** `scripts/02_statistical_analysis/extract_comprehensive_parameters.R`

**Script Structure:**
1. **Part 1**: Extract bias levels and contrasts from Standard-only model
2. **Part 2**: Extract fixed effects from Primary model
3. **Part 3**: Extract effect contrasts from Primary model (difficulty, task, effort)
4. **Part 4**: Compute condition-specific parameter estimates (on natural scales)
5. **Part 5**: Perform statistical hypothesis tests using `brms::hypothesis()`
6. **Part 6**: Calculate effect sizes (Cohen's d approximations)

---

## Key Technical Details

### Model Structure

**Standard-only model:**
- Drift (v): `rt | dec(dec_upper) ~ 1 + (1|subject_id)`
- Boundary (a): `bs ~ 1 + (1|subject_id)`
- NDT (t₀): `ndt ~ 1`
- Bias (z): `bias ~ task + effort_condition + (1|subject_id)`

**Primary model:**
- Drift (v): `rt | dec(dec_upper) ~ difficulty_level + task + effort_condition + (1 + difficulty_level | subject_id)`
- Boundary (a): `bs ~ difficulty_level + task + (1 | subject_id)`
- NDT (t₀): `ndt ~ task + effort_condition`
- Bias (z): `bias ~ difficulty_level + task + (1 | subject_id)`

### Link Functions
- Drift (v): Identity link
- Boundary (a): Log link → `a = exp(bs)`
- NDT (t₀): Log link → `t₀ = exp(ndt)`
- Bias (z): Logit link → `z = inv_logit(bias)`

### Posterior Sample Column Names

**Standard-only model:**
- `b_bias_Intercept` - bias intercept (logit scale)
- `b_bias_taskVDT` - task effect on bias
- `b_bias_effort_conditionHigh_40_MVC` - effort effect on bias
- `Intercept` - drift intercept (identity scale)
- `b_bs_Intercept` - boundary intercept (log scale)
- `b_ndt_Intercept` - NDT intercept (log scale)

**Primary model:**
- `b_Intercept` - drift intercept (Standard, identity scale)
- `b_difficulty_levelHard` - Hard difficulty effect on drift
- `b_difficulty_levelEasy` - Easy difficulty effect on drift
- `b_taskVDT` - VDT task effect on drift
- `b_effort_conditionHigh_40_MVC` - High effort effect on drift
- `b_bs_Intercept` - boundary intercept (log scale)
- `b_bs_difficulty_levelHard` - Hard difficulty effect on boundary
- `b_bs_difficulty_levelEasy` - Easy difficulty effect on boundary
- `b_bs_taskVDT` - VDT task effect on boundary
- Similar patterns for `b_ndt_*` and `b_bias_*`

---

## Questions for Review

### 1. Parameter Extraction Correctness
- **Are the column name patterns correct?** I'm using `grepl()` patterns like `^b_bs_|^bs_` to find boundary separation columns. Is this robust?
- **Are the transformations correct?** For boundary and NDT, I'm using `exp()` to back-transform from log scale. For bias, I'm using `inv_logit()` to back-transform from logit scale. Are these correct?
- **Are intercept extractions correct?** For drift in primary model, I check for both `Intercept` and `b_Intercept`. Is this the right approach?

### 2. Contrast Computations
- **Difficulty contrasts**: For Hard trials, I compute `v_hard = v_intercept + b_difficulty_levelHard`. Is this correct?
- **Effect contrasts**: When computing "Easy - Hard", I use `b_difficulty_levelEasy - b_difficulty_levelHard`. Is this mathematically correct?
- **ROPE thresholds**: I use 0.02 for drift, 0.05 for boundary/bias on log/logit scales. Are these reasonable?

### 3. Condition-Specific Parameters (Part 4)
- **Back-transformations**: I back-transform boundary (`exp(bs)`) and bias (`inv_logit(bias)`) when computing condition-specific values. Is this correct?
- **NDT handling**: For NDT, I assume it doesn't vary by difficulty (only by task/effort). Is this assumption correct based on the model formula?

### 4. Hypothesis Testing (Part 5)
- **Hypothesis function usage**: I'm using `brms::hypothesis()` with formulas like `"difficulty_levelEasy = 0"`. Is this the correct syntax?
- **dpar specification**: For boundary and bias parameters, do I need to specify `dpar = "bs"` or `dpar = "bias"` in the hypothesis call?
- **Error handling**: I wrap hypothesis tests in `tryCatch()`. Is this sufficient, or should I add more robust error handling?

### 5. Effect Sizes (Part 6)
- **Cohen's d approximation**: I compute `mean / sd` for each contrast. Is this a reasonable approximation for Bayesian effect sizes?
- **Effect size categories**: I use thresholds (<0.2 negligible, <0.5 small, <0.8 medium, ≥0.8 large). Are these appropriate for DDM parameters?

### 6. Code Quality
- **Error handling**: Is the error handling sufficient?
- **Logging**: Is the logging comprehensive enough for debugging?
- **Robustness**: Will the script handle edge cases (missing columns, unexpected model structures)?
- **Performance**: Any performance optimizations needed for large posterior samples?

---

## Specific Code Sections to Review

### Section 1: Bias Level Computation
```r
# Compute bias levels for each condition (on probability scale)
compute_bias_level <- function(intercept, task_eff = 0, effort_eff = 0, logit_samples = TRUE) {
  if (logit_samples) {
    logit_vals <- intercept + task_eff + effort_eff
    prob_vals <- inv_logit(logit_vals)
    return(list(logit = logit_vals, prob = prob_vals))
  } else {
    return(list(logit = intercept + task_eff + effort_eff, prob = inv_logit(intercept + task_eff + effort_eff)))
  }
}
```

**Question:** Is this function correct? Should I be adding effects in this way, or do I need to handle them differently?

### Section 2: Contrast Extraction Pattern
```r
# Extract intercepts
v_intercept <- if ("Intercept" %in% colnames(post_primary)) {
  post_primary$Intercept
} else if ("b_Intercept" %in% colnames(post_primary)) {
  post_primary$b_Intercept
} else {
  NULL
}
```

**Question:** Is this fallback pattern correct? Are there other possible column names I should check?

### Section 3: Hypothesis Testing
```r
hyp_result <- hypothesis(fit_primary, paste0(hyp_formula, " = 0"))
```

**Question:** Is this the correct way to test if a parameter equals zero? Should I use `hypothesis()` differently for different parameter types?

### Section 4: Condition-Specific Parameter Computation
```r
hard_v <- v_intercept + post_primary$b_difficulty_levelHard
hard_bs <- bs_intercept + post_primary[[grep("^b_bs_difficulty_levelHard|^bs_difficulty_levelHard", ...)]]
```

**Question:** When computing condition-specific boundary values, should I:
1. Add on log scale: `bs_intercept + bs_effect`, then `exp(bs_total)`
2. Or: `exp(bs_intercept) * exp(bs_effect) = exp(bs_intercept + bs_effect)`?

Same question for bias (logit scale).

---

## Expected Outputs

The script should generate:

1. **output/publish/bias_standard_only_levels.csv** - Bias levels (logit and prob scales)
2. **output/publish/bias_standard_only_contrasts.csv** - Bias contrasts
3. **output/publish/table_fixed_effects.csv** - All fixed effects from primary model
4. **output/publish/table_effect_contrasts.csv** - Effect contrasts (difficulty, task, effort)
5. **output/results/parameter_summary_by_condition.csv** - Condition-specific parameters (natural scales)
6. **output/results/statistical_hypothesis_tests.csv** - Hypothesis test results
7. **output/results/effect_sizes.csv** - Effect size calculations

---

## What I Need

1. **Code Review**: Are there any bugs or incorrect assumptions in the script?
2. **Best Practices**: Are there `brms` best practices I'm missing?
3. **Robustness**: Will the script work with the actual model structure?
4. **Suggestions**: Any improvements or optimizations?

---

## Script Location

The full script is at: `scripts/02_statistical_analysis/extract_comprehensive_parameters.R`

Please review the script and provide feedback on:
- Correctness of parameter extraction
- Accuracy of transformations
- Robustness of column name matching
- Appropriateness of statistical tests
- Quality of error handling

Thank you!

