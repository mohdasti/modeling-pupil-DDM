# Prompt for LLM: Comprehensive Sanity Checks and Validation of DDM Results

**Date:** 2025-11-26  
**Purpose:** Get second opinion on current model results and request comprehensive sanity checks before proceeding with analysis

---

## Executive Summary

We have fitted two hierarchical Bayesian DDM models to older adult change-detection task data:
1. **Standard-only bias model** (3,597 trials) - estimates bias and drift on zero-evidence trials
2. **Primary model** (17,834 trials) - full model with difficulty, task, and effort effects

**Key findings:**
- Standard trials show strong negative drift (v = -1.404) and 89.1% "Same" responses
- Models converged well (Rhat ≤ 1.001, ESS ≥ 2,000)
- PPC validation passed (observed 10.9% vs predicted 11.2% "Different")
- All tables regenerated from updated models

**Questions:** Are parameter values realistic? Should we be concerned about anything? What sanity checks should we run?

---

## Context: Hierarchical Bayesian DDM Analysis

I am conducting a hierarchical Bayesian drift-diffusion model (DDM) analysis using `brms` in R (version 2.22.0) with CmdStan backend. The analysis uses a **response-signal design** where reaction times (RTs) are measured from **response-screen onset** (not stimulus onset). Participants are **older adults** (≥65 years, mean age = 71.3 years) performing a same/different change-detection task while maintaining isometric handgrip force.

**Key Change:** We recently updated the dataset and fixed response-side coding. This analysis uses the latest data with direct response-side coding from the raw data column `resp_is_diff`. All results reported here are from models fitted after these updates (Nov 25-26, 2025).

---

## Experimental Design

### Participants
- **N = 67** older adults (≥65 years)
- Mean age = 71.3 years (SD = 4.8)

### Task Structure
- **Response-signal design:** RT measured from response-screen onset (after stimulus presentation)
- **RT filtering:** 250 ms - 3,000 ms (250 ms floor accounts for age-related non-decision time)

### Conditions (Within-Subjects, Factorial Design)

**1. Task (2 levels):**
- **ADT** (Auditory Detection Task): Tone discrimination
- **VDT** (Visual Detection Task): Visual contrast discrimination

**2. Difficulty Level (3 levels):**
- **Standard** (Δ=0): Identical stimuli (zero-evidence trials)
- **Hard**: Small frequency/contrast differences (difficult to detect)
- **Easy**: Large frequency/contrast differences (easy to detect)

**3. Effort Condition (2 levels):**
- **Low_5_MVC**: 5% maximum voluntary contraction (MVC)
- **High_40_MVC**: 40% MVC

**Total design:** 2 tasks × 3 difficulty levels × 2 effort conditions = 12 cells per subject

### Current Dataset
- **Total trials:** 17,834 (after exclusions)
- **Standard trials:** 3,597 (20.2%)
- **Easy trials:** 7,064 (39.6%)
- **Hard trials:** 7,173 (40.2%)

---

## Response-Side Coding (Critical Detail)

We use **response-side coding** (not accuracy coding):
- **Upper boundary = "Different" responses** (`dec_upper = 1`)
- **Lower boundary = "Same" responses** (`dec_upper = 0`)
- Directly from raw data column `resp_is_diff` (TRUE = "Different", FALSE = "Same")

This allows modeling response bias independently of accuracy.

### Standard Trial Proportions
- **"Same" responses:** 3,205 trials (89.1%)
- **"Different" responses:** 392 trials (10.9%)

This strong "Same" bias is consistent with conservative responding in older adults.

---

## Model Specifications

### Standard-Only Bias Model
- **Trials:** 3,597 Standard trials only
- **Purpose:** Isolate bias estimation from drift effects
- **Formula:**
  - Drift (v): `rt | dec(dec_upper) ~ 1 + (1|subject_id)`
  - Boundary (a): `bs ~ 1 + (1|subject_id)`
  - Non-decision time (t₀): `ndt ~ 1`
  - Bias (z): `bias ~ task + effort_condition + (1|subject_id)`
- **Drift prior:** `normal(0, 2)` (relaxed, allows negative drift)
- **Chains:** 4, 8,000 iterations (4,000 warmup)

### Primary Model
- **Trials:** All 17,834 trials
- **Purpose:** Main analysis with difficulty, task, and effort effects
- **Formula:**
  - Drift (v): `rt | dec(dec_upper) ~ difficulty_level + task + effort_condition + (1 + difficulty_level | subject_id)`
  - Boundary (a): `bs ~ difficulty_level + task + (1 | subject_id)`
  - Non-decision time (t₀): `ndt ~ task + effort_condition`
  - Bias (z): `bias ~ difficulty_level + task + (1 | subject_id)`
- **Chains:** 4, 8,000 iterations (4,000 warmup)

### Link Functions
- **Drift (v):** Identity link
- **Boundary (a/bs):** Log link → `a = exp(bs)`
- **Non-decision time (t₀/ndt):** Log link → `t₀ = exp(ndt)`
- **Bias (z):** Logit link → `z = inv_logit(bias)`

---

## Current Model Results

### Standard-Only Bias Model Results

**Drift Rate (v):**
- Intercept: **-1.404** (95% CrI: [-1.662, -1.147])
- Interpretation: Strong negative drift toward "Same" responses

**Boundary Separation (a):**
- Intercept (log scale): 0.864 → **a = 2.37** (natural scale)
- 95% CrI: [2.25, 2.51]

**Non-Decision Time (t₀):**
- Intercept (log scale): -1.494 → **t₀ = 0.225 s** (225 ms)
- 95% CrI: [217, 232 ms]

**Starting-Point Bias (z):**
- Intercept (logit): 0.293 → **z = 0.573** (probability scale)
- 95% CrI: [0.540, 0.604]

**Task Effect on Bias:**
- VDT - ADT: **-0.157** (logit scale) (95% CrI: [-0.232, -0.081])
- Interpretation: VDT has less bias toward "Different" than ADT
- P(Δ>0) < 0.001 (highly significant)

**Effort Effect on Bias:**
- High - Low: **0.029** (logit scale) (95% CrI: [-0.043, 0.101])
- P(Δ>0) = 0.787 (not significant)

**Bias Levels by Condition (probability scale):**
- ADT, Low: z = **0.573** (95% CrI: [0.540, 0.604])
- ADT, High: z = **0.580** (95% CrI: [0.547, 0.612])
- VDT, Low: z = **0.534** (95% CrI: [0.501, 0.566])
- VDT, High: z = **0.541** (95% CrI: [0.509, 0.573])

### Primary Model Results (Key Parameters)

**Drift Rate (v) Intercept (Standard trials, reference):**
- Intercept: **-1.260** (95% CrI: [-1.365, -1.158])
- Interpretation: Negative drift on Standard trials

**Difficulty Effects on Drift:**
- Hard - Standard: **+0.616** (95% CrI: [0.558, 0.674])
- Easy - Standard: **+2.170** (95% CrI: [2.108, 2.232])
- Interpretation: Easy trials have strong positive drift, Hard trials have moderate positive drift (relative to Standard)

**Task Effect on Drift:**
- VDT - ADT: **+0.142** (95% CrI: [0.098, 0.186])
- Interpretation: VDT has higher drift than ADT

**Effort Effect on Drift:**
- High - Low: **-0.052** (95% CrI: [-0.084, -0.020])
- Interpretation: High effort slightly reduces drift

**Boundary Separation (a) Intercept:**
- Intercept (log scale): 0.822 → **a = 2.28** (natural scale)
- 95% CrI: [2.16, 2.39]

**Non-Decision Time (t₀) Intercept:**
- Intercept (log scale): -1.536 → **t₀ = 0.215 s** (215 ms)
- 95% CrI: [211, 221 ms]

**Bias (z) Intercept:**
- Intercept (logit): 0.268 → **z = 0.567** (probability scale)
- 95% CrI: [0.547, 0.586]

---

## Observed Data (Reality Check)

### Standard Trial Response Proportions
- **"Same" (dec_upper=0):** 89.1% (3,205 / 3,597)
- **"Different" (dec_upper=1):** 10.9% (392 / 3,597)

### RT Summary (Standard trials)
- Mean RT: 1.060 s
- Median RT: 0.957 s
- Range: 0.251 - 2.977 s

### Accuracy by Difficulty (Easy/Hard trials only)

**Easy trials:**
- ADT: **81.4%** correct (3,525 trials)
- VDT: **90.4%** correct (3,539 trials)
- Overall: **~86%** correct (high accuracy, as expected)

**Hard trials:**
- ADT: **28.3%** correct (3,539 trials) - **WELL BELOW CHANCE**
- VDT: **31.6%** correct (3,634 trials) - **WELL BELOW CHANCE**
- Overall: **~30%** correct (below chance, indicating difficulty manipulation worked)

**Note:** Hard trials show accuracy well below 50% chance, which justifies negative drift rate estimates for Hard difficulty.

### RT Summary by Difficulty
- **Easy:** Mean = 0.898 s, Median = 0.747 s (fastest)
- **Hard:** Mean = 1.12 s, Median = 1.01 s (slowest)
- **Standard:** Mean = 1.06 s, Median = 0.956 s (intermediate)

**Pattern:** Hard trials are slower than Easy (as expected), validating difficulty manipulation.

---

## Model Validation

### Convergence Diagnostics (Both Models)
- **Max Rhat:** ≤ 1.001 (target: ≤ 1.01) ✅
- **Min Bulk ESS:** ≥ 2,000 (target: ≥ 400) ✅
- **Min Tail ESS:** ≥ 4,500 (target: ≥ 400) ✅
- **Divergent transitions:** 0 ✅

### Posterior Predictive Check (Primary Model)
- **Method:** Generated 1,000 posterior predictive draws using `posterior_predict()` with `negative_rt = TRUE`
- **Observed proportion "Different" (Standard):** 10.9%
- **Predicted proportion "Different":** 11.2% (95% CI: [9.9%, 12.7%])
- **Difference:** 0.3% (minimal!)
- **Status:** ✅ **Validation passed** - Observed falls within 95% credible interval

**Note on Analytical Formula vs PPC:**
- **Analytical formula** (using group-level mean parameters): Predicts 2.1-3.6% "Different"
- **PPC** (using full posterior with subject heterogeneity): Predicts 11.2% "Different"
- **Difference:** The analytical formula under-predicts due to aggregation bias (Jensen's Inequality) when using group means in a non-linear formula. The PPC approach correctly accounts for subject-level heterogeneity and matches observed data well.

---

## Key Questions for Sanity Checks

### 1. Parameter Magnitudes
- **Are these parameter values realistic for older adults?**
  - Drift rate: v = -1.404 (Standard), -1.26 + 2.17 = +0.91 (Easy)
  - Boundary separation: a ≈ 2.3
  - Non-decision time: t₀ ≈ 220 ms
  - Bias: z ≈ 0.57

### 2. Negative Drift on Standard Trials
- **Is negative drift (v = -1.404) on Standard trials reasonable?**
  - Standard trials have 89.1% "Same" responses
  - Negative drift would push toward "Same" boundary
  - Combined with bias z = 0.573 (slight bias toward "Different")
  - **Question:** Does this make sense given the high "Same" rate?

### 3. Bias Interpretation
- **Bias parameter z = 0.573 suggests slight bias toward "Different"**
- **But observed data shows 89.1% "Same" responses**
- **Question:** How can we reconcile this? Is it because negative drift dominates?

### 4. Mathematical Consistency
- **Given v = -1.404, a = 2.37, z = 0.573 on Standard trials:**
  - Analytical formula (group means): Predicts ~2.1% "Different"
  - PPC (respecting subject heterogeneity): Predicts 11.2% "Different"
  - Observed: 10.9% "Different"
  - **Question:** The analytical formula under-predicts due to aggregation bias, but PPC matches well. Is this expected for hierarchical models? Should we be concerned about the 7-8% discrepancy in the analytical prediction?

### 5. Difficulty Effects
- **Easy - Standard drift difference: +2.170**
- **Hard - Standard drift difference: +0.616**
- **Question:** Are these magnitudes reasonable? Do they align with accuracy differences (Easy: 81-90%, Hard: 28-32%)?
- **Reality check:** Hard trials show below-chance accuracy (28-32%), which should correspond to negative or near-zero drift relative to Standard

### 6. Non-Decision Time
- **t₀ ≈ 220 ms in response-signal design**
- **Question:** Is this reasonable for older adults in a response-signal task (RT measured from response-screen onset)?

### 7. Boundary Separation
- **a ≈ 2.3 for older adults**
- **Question:** Is this consistent with typical values? Does it reflect conservative responding?

### 8. Task and Effort Effects
- **Task effect on drift:** VDT > ADT (+0.142)
- **Effort effect on drift:** High < Low (-0.052, small)
- **Question:** Are these effects sizes reasonable and interpretable?

---

## Specific Sanity Checks Requested

Please help us verify:

1. **Parameter Magnitude Checks**
   - Are drift rates, boundary separation, non-decision time, and bias within expected ranges for older adults?
   - Are the effect sizes (difficulty, task, effort) reasonable?

2. **Mathematical Consistency Checks**
   - Given the parameter estimates, do predicted choice proportions match observed data?
   - Does the combination of drift + bias mathematically produce the observed 89.1% "Same" responses?

3. **Theoretical Plausibility**
   - Is negative drift on Standard trials theoretically justifiable?
   - Does it make sense that participants accumulate evidence toward "Same" when stimuli are identical?
   - How does this relate to the "conservative" response bias interpretation?

4. **Data-Model Alignment**
   - Do parameter estimates align with observed accuracy patterns (Easy: 85%, Hard: 30.5%)?
   - Do RT patterns match expectations (Hard slower than Easy)?

5. **Response-Side Coding Validation**
   - Is the response-side coding interpretation correct?
   - Are we correctly interpreting upper="Different", lower="Same"?

6. **Model Specification Checks**
   - Are the priors appropriate?
   - Is the hierarchical structure correct?
   - Should we be concerned about any parameter estimates?

7. **Additional Checks**
   - What other sanity checks should we run?
   - Are there any red flags in these results?
   - What should we check before proceeding with analysis?

---

## What We Need

1. **Direct Feedback:** Are these parameter values reasonable and interpretable?

2. **Sanity Check Recommendations:** What additional checks should we run?

3. **Red Flags:** Are there any concerning patterns or inconsistencies?

4. **Validation Approach:** Should we perform additional validations beyond PPC?

5. **Interpretation Guidance:** How should we interpret the negative drift on Standard trials?

---

## Output Format Requested

Please provide:
1. ✅/⚠️/❌ assessment for each parameter/result
2. Specific sanity checks to run (with R code if possible)
3. Any concerns or red flags
4. Recommendations for additional validations
5. Interpretation guidance for key findings

---

## Additional Context

### Recent Updates Made
1. **Dataset updated:** From old dataset (17,243 trials) to new dataset (17,834 trials)
2. **Response-side coding:** Now using direct `resp_is_diff` column from raw data
3. **Drift prior relaxed:** Changed from tight prior (v ≈ 0) to relaxed prior (normal(0, 2)) for Standard trials
4. **PPC validation:** Fixed method to use `negative_rt = TRUE` for correct choice extraction
5. **Tables regenerated:** All CSV tables extracted from updated model fits (Nov 26, 2025)

### Model File Locations
- Standard-only bias model: `output/models/standard_bias_only.rds` (fitted Nov 25)
- Primary model: `output/models/primary_vza.rds` (fitted Nov 26)
- Data file: `data/analysis_ready/bap_ddm_only_ready.csv` (17,834 trials)

---

## Critical Questions for You

1. **Are these parameter values realistic and interpretable?**
2. **Should we be concerned about the analytical vs PPC discrepancy (2.1% vs 11.2%)?**
3. **Is negative drift on Standard trials theoretically justifiable?**
4. **What additional sanity checks should we run before proceeding?**
5. **Are there any red flags or inconsistencies in these results?**

---

---

## Quick Reference: Key Numbers Summary

| Metric | Value | Notes |
|--------|-------|-------|
| **Dataset** | 17,834 trials, 67 subjects | Updated Nov 2025 |
| **Standard trials** | 3,597 (20.2%) | Zero-evidence trials |
| **Standard: Same responses** | 89.1% | Conservative bias |
| **Standard: Different responses** | 10.9% | |
| **Easy accuracy** | ADT: 81.4%, VDT: 90.4% | High accuracy expected |
| **Hard accuracy** | ADT: 28.3%, VDT: 31.6% | Below chance - justifies negative drift |
| **Standard-only drift (v)** | -1.404 | Negative drift toward "Same" |
| **Standard-only bias (z)** | 0.573 | Slight bias toward "Different" |
| **Standard-only boundary (a)** | 2.37 | |
| **Standard-only NDT (t₀)** | 225 ms | |
| **Primary drift intercept** | -1.260 | Standard trial reference |
| **Easy - Standard drift** | +2.170 | Strong positive drift |
| **Hard - Standard drift** | +0.616 | Moderate positive drift |
| **Primary boundary (a)** | 2.28 | |
| **Primary NDT (t₀)** | 215 ms | |
| **PPC: Observed Different** | 10.9% | |
| **PPC: Predicted Different** | 11.2% (95% CI: [9.9%, 12.7%]) | Excellent match |

---

## Files Referenced

- **Standard-only model:** `output/models/standard_bias_only.rds`
- **Primary model:** `output/models/primary_vza.rds`
- **Data:** `data/analysis_ready/bap_ddm_only_ready.csv`
- **Tables:** `output/publish/` directory

---

Thank you for your thorough review! We value your expertise in validating these results before proceeding with the next analysis steps.

