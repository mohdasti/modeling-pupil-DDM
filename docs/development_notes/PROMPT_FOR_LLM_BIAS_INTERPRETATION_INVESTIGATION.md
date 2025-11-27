# Prompt for LLM: brms Wiener Model Bias Interpretation Investigation

## Context and Problem Statement

I am fitting Bayesian drift diffusion models (DDM) using the `brms` package in R with the `wiener()` family. I'm encountering a **critical bias interpretation issue** where the model's bias parameter estimate contradicts the observed data distribution, suggesting either a coding error or a fundamental misunderstanding of how `brms` interprets the `dec()` function for decision boundaries.

---

## The Critical Problem

### Model Results
- **Model converged successfully:** Rhat = 1.0007, ESS > 4000, no divergent transitions
- **Bias estimate (z):** 0.569 on probability scale (logit scale: 0.277)
- **Other parameters look reasonable:** Drift v ≈ -0.036, Boundary a = 2.38, NDT = 0.225s

### Data Distribution
- **Standard (Δ=0) trials:** 3,597 trials from 67 subjects
- **Response distribution:**
  - 89.1% "Same" responses (dec_upper = 0)
  - 10.9% "Different" responses (dec_upper = 1)

### The Contradiction
- If bias z = 0.569, the model predicts ~57% of responses should be "Different" (upper boundary)
- But the data shows only 10.9% "Different" responses
- **This is a 46% mismatch - mathematically impossible!**

---

## Model Specification

### Formula Structure
```r
form <- bf(
  rt | dec(dec_upper) ~ 1 + (1 | subject_id),
  bs   ~ 1 + (1 | subject_id),
  ndt  ~ 1,
  bias ~ task + effort_condition + (1 | subject_id)
)

fit <- brm(
  formula = form,
  data = dd,  # Standard trials only
  family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
  prior = priors,
  chains = 4,
  iter = 8000,
  warmup = 4000,
  ...
)
```

### Data Coding
From our data preparation scripts:
```r
# Response-side coding
dec_upper = case_when(
  resp_is_diff == TRUE  ~ 1L,  # Upper = Different
  resp_is_diff == FALSE ~ 0L   # Lower = Same
)
```

**Our interpretation:**
- `dec_upper = 1` means "Different" response = **upper boundary**
- `dec_upper = 0` means "Same" response = **lower boundary**

This matches our manuscript description: *"the upper boundary corresponds to 'different' responses and the lower boundary corresponds to 'same' responses"*

### Model Family
```r
family = wiener(
  link_bs = "log",      # Boundary separation on log scale
  link_ndt = "log",     # Non-decision time on log scale  
  link_bias = "logit"   # Starting point bias on logit scale
)
```

---

## Key Diagnostic Results

### Test 1: Direct Comparison
- **Model bias (z):** 0.569
- **Data proportion "Different":** 0.109
- **Difference:** 0.460 ✗

### Test 2: Flipped Comparison
- **Model bias (z):** 0.569
- **Flipped bias (1-z):** 0.431
- **Data proportion "Same":** 0.891
- **Difference:** 0.460 ✗
- **BUT:** Difference from "Different" when flipped: 0.322 ⚠️ (closer, but still not good)

### Test 3: By Condition (Task × Effort)
None of the conditions match well (all differences > 0.40):
- ADT-High: bias=0.576, data=0.128 (diff=0.447)
- ADT-Low: bias=0.569, data=0.158 (diff=0.411)
- VDT-High: bias=0.538, data=0.075 (diff=0.463)
- VDT-Low: bias=0.531, data=0.078 (diff=0.453)

---

## What We Need to Understand

### Critical Question 1: How does brms interpret `dec()`?
In `rt | dec(dec_upper)` where `dec_upper` is binary (0/1):
- **Does `dec_upper = 1` correspond to the upper boundary or lower boundary?**
- **What is the default convention in brms?**
- **Is there documentation or examples that clarify this?**

### Critical Question 2: How does bias (z) relate to decision boundaries?
In DDM terminology:
- **z** = starting point as proportion of boundary separation (0 = lower, 1 = upper)
- **If `dec_upper = 1` means upper boundary:**
  - Does z = 0.569 mean starting 56.9% toward the upper boundary?
  - Should this predict ~56.9% upper boundary hits?
  - **If so, why does our model predict 56.9% "Different" but data shows 10.9%?**

### Critical Question 3: Could boundaries be reversed?
Given that:
- Data shows 89.1% "Same" (which we coded as lower boundary)
- Model estimates z = 0.569 (toward upper boundary)
- **Flipped match is closer (0.322 vs 0.460)**

**Question:** Is it possible that in brms:
- `dec_upper = 1` actually means **lower** boundary?
- `dec_upper = 0` actually means **upper** boundary?

**OR:** Is our understanding of z wrong? Maybe:
- z represents something different than we think?
- z doesn't directly predict response proportions in this context?

### Critical Question 4: What about task/effort effects?
Our model includes task and effort effects on bias:
```r
bias ~ task + effort_condition + (1 | subject_id)
```

**Questions:**
- Could these effects be shifting the interpretation?
- Should we check bias including these effects rather than just the intercept?
- (We did this - none of the conditions matched)

### Critical Question 5: Reference to existing code
In our codebase, we have a parameter recovery script that uses:
```r
rw <- rwiener(n_trials, alpha = a, tau = ndt, beta = z, delta = v)
tibble(..., choice = as.integer(rw$resp=="upper"), ...)

# Then fits with:
rt | dec(choice) ~ ...
```

**Questions:**
- Does `rw$resp=="upper"` in `rtdists::rwiener()` correspond to upper boundary?
- Does this match how brms interprets `dec(choice)` when `choice=1`?
- Is this the same convention we should be using?

---

## Specific Questions for the LLM

### Question 1: Boundary Interpretation
**"In brms wiener model with `rt | dec(dec_upper)`, when `dec_upper` is binary (0/1), what does `dec_upper = 1` actually mean in terms of the DDM boundaries (upper vs lower)? Can you cite brms documentation or examples?"**

### Question 2: Bias Parameter Interpretation
**"In brms wiener model, the bias parameter (z) is on logit scale but can be transformed to probability scale [0,1]. If z = 0.569 (on probability scale), what does this predict in terms of response proportions? Does it directly predict the proportion of trials hitting the boundary corresponding to `dec()=1`?"**

### Question 3: Diagnostic Interpretation
**"Given that our model estimates z = 0.569, but data shows only 10.9% of responses hit the boundary we coded as `dec_upper=1`, what are the possible explanations? Could this indicate: (a) reversed boundary coding, (b) different bias interpretation, (c) model misspecification, or (d) something else?"**

### Question 4: Coding Convention
**"We code `dec_upper=1` when response is 'Different' (which we believe should be upper boundary based on DDM convention). Our existing parameter recovery script codes `choice=1` when `rw$resp=="upper"` from rtdists. Are these consistent? Should we be using a different coding?"**

### Question 5: Solution Approach
**"What diagnostic tests or checks would you recommend to definitively determine if our boundary coding is correct? How can we verify the correct interpretation of bias in brms wiener models?"**

---

## Files You Can Reference

I can attach the following files for detailed context:

1. **`R/simple_bias_diagnostic.R`** - Quick diagnostic script showing the mismatch
2. **`R/diagnose_bias_with_effects.R`** - Diagnostic including task/effort effects
3. **`R/test_flipped_coding.R`** - Test of reversed boundary coding
4. **`04_computational_modeling/drift_diffusion/fit_standard_bias_only.R`** - The actual model fitting script
5. **`BIAS_INTERPRETATION_SUMMARY.md`** - Complete summary of our findings
6. **`scripts/modeling/parameter_recovery.R`** - Existing parameter recovery script that uses `dec(choice)`
7. **`reports/chap3_ddm_results.qmd`** - Manuscript section describing the boundary mapping

---

## Expected Output

Please provide:

1. **Clear answer** to how brms interprets `dec()` function and boundaries
2. **Explanation** of how bias (z) should be interpreted in this context
3. **Diagnosis** of what might be wrong with our current setup
4. **Specific recommendations** for fixing the issue
5. **Code examples** or references to verify the correct interpretation

---

## Additional Context

- **Task:** Same/different discrimination task
- **Standard trials:** Δ=0 (no stimulus difference, drift ≈ 0)
- **Expected behavior:** On Standard trials, participants show strong "Same" bias (89.1%)
- **Model goal:** Estimate starting-point bias (z) that captures this preference
- **Issue:** Model estimates z = 0.569 (suggesting bias toward "Different"), contradicting the 89.1% "Same" responses

---

## Why This Matters

This is **blocking all further analysis**. If we can't correctly interpret the bias parameter:
- All bias estimates will be wrong
- All interpretations will be backwards
- Manuscript results will be incorrect
- We'll waste hours on incorrect models

**Any insight you can provide would be extremely valuable!**

---

Thank you for your help!

