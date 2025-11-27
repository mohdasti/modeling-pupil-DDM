# Prompt for Second Opinion: DDM NDT Initialization Issues

## Context

I'm working on fitting Bayesian drift diffusion models (DDM) using `brms` in R with the `wiener()` family for a response-signal design. The task involves modeling RTs measured from a "go" signal (response screen), not from stimulus onset.

**Dataset:**
- 17,243 trials from 67 older adult subjects
- RTs filtered: 250ms - 3000ms (floor raised from 200ms based on research guidance)
- Response-signal design (RTs measured from response screen onset)

**Model Structure:**
- Drift rate (v): `rt | dec(decision) ~ predictors + (1|subject_id)`
- Boundary separation (a/bs): `bs ~ 1 + (1|subject_id)` (log link)
- Non-decision time (t0/ndt): Originally `ndt ~ 1 + (1|subject_id)` (log link)
- Starting point bias (z): `bias ~ 1 + (1|subject_id)` (logit link)

---

## Problem: Initialization Failures

### Original Issue
All models failed with initialization errors:
```
wiener_lpdf: Random variable = 0.866433, but must be greater than nondecision time = 0.97-1.03
```

The NDT values at initialization were **exceeding observed RTs**, causing Stan to reject all initial values.

### Initial Attempts to Fix

1. **Raised RT floor:** 200ms → 250ms (following research guidance)
2. **Updated NDT prior:** `normal(log(0.23), 0.20)` for response-signal design
3. **Custom initialization:** Tried to initialize NDT components:
   - `b_ndt_Intercept = log(0.20)` (200ms on log scale)
   - `sd_ndt_subject_id__Intercept = 0.05` (small SD)
   - `z_ndt_subject_id = rep(0, n_subjects)` (zeroed raw RE)

**Result:** Still failed. Even with careful initialization, Stan's transformation could produce NDT values > RT.

---

## Solution Implemented: Remove NDT Random Effects

### Change Made
**All models:** Changed `ndt ~ 1 + (1|subject_id)` → `ndt ~ 1` (no random effects)

**Rationale:**
- Follows "simplify, then grow" approach
- Subject variation still captured in drift, boundary, and bias
- Many published DDM papers use fixed NDT with subject RE on other parameters

### Supporting Changes
1. **Priors:** Removed `prior(student_t(3, 0, 0.2), class = "sd", dpar = "ndt")`
2. **Init function:** Simplified to initialize only `b_ndt_Intercept = log(0.18)` (180ms)

---

## Test Results

### ✅ Test Model (No NDT RE) - SUCCESS
**Model:** Baseline intercept-only model without NDT RE
```r
rt | dec(decision) ~ 1 + (1|subject_id)
bs ~ 1 + (1|subject_id)
ndt ~ 1  # NO RE
bias ~ 1 + (1|subject_id)
```

**Init function:**
```r
safe_init <- function(chain_id = 1) {
    list(
        Intercept = rnorm(1, 0, 0.5),
        bs_Intercept = log(runif(1, 1.0, 2.0)),
        bias_Intercept = rnorm(1, 0, 0.3),
        b_ndt_Intercept = log(0.18)  # 180ms
    )
}
```

**Result:**
- ✅ Model completed successfully (21.5 minutes)
- ✅ NDT intercept: -1.473 (log scale) = 0.229s (229ms) on natural scale
- ✅ Safely below RT floor of 250ms
- ✅ All chains converged
- ⚠️ Some initialization rejections initially, but Stan found valid values

**Log excerpt:**
```
Chain 1: Rejecting initial value... [many rejections]
Chain 1: Gradient evaluation took 0.021913 seconds
Chain 1: Iteration:   1 / 500 [  0%]  (Warmup)
...
Chain 1: Iteration: 500 / 500 [100%]  (Sampling)
✅ SUCCESS! Model completed in 21.5 minutes
```

### ❌ Full Pipeline - Still Failing
**Issue:** When running the full analysis pipeline with all 9+ models, getting:
```
[ERROR] FAILED to fit Model1_Baseline: argument 5 is empty
```

This error occurs **before** sampling starts, suggesting it's during model compilation or initialization setup, not during sampling.

**Observation:** The test model worked, but the full pipeline fails with a different error ("argument 5 is empty"), which suggests:
- The approach (removing NDT RE) is correct
- But there may be an issue with how `init` is passed or how the model is compiled in the pipeline context

---

## Current Code Structure

### Init Function (in `fit_ddm_model`)
```r
fit_ddm_model <- function(spec, data, model_name) {
    safe_init <- function(chain_id = 1) {
        list(
            Intercept = rnorm(1, 0, 0.5),
            bs_Intercept = log(runif(1, 1.0, 2.0)),
            bias_Intercept = rnorm(1, 0, 0.3),
            b_ndt_Intercept = log(0.18)
        )
    }
    
    brm(
        formula = spec$formula, 
        data = data, 
        family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
        prior = spec$priors, 
        chains = 4, iter = 2000, warmup = 1000, cores = 4,
        init = safe_init,
        control = list(adapt_delta = 0.95, max_treedepth = 12),
        backend = "cmdstanr",
        file = file.path(OUTPUT_PATHS$models, model_name),
        file_refit = "on_change",
        refresh = 100
    )
}
```

---

## Questions for Second Opinion

1. **Is removing NDT random effects a reasonable solution?**
   - The test model worked, but is this theoretically/methodologically sound?
   - Should I keep trying to make NDT RE work, or is fixed NDT acceptable?
   - Are there implications for model comparison or interpretation?

2. **Why does the test model work but the full pipeline fail with "argument 5 is empty"?**
   - This error appears before sampling, suggesting a compilation or setup issue
   - Could it be related to how `init` is scoped/defined within the function?
   - Could there be differences in data structure between test and pipeline?

3. **Should I initialize other random effects explicitly?**
   - The test model didn't initialize `sd_bs_subject_id__Intercept`, `z_bs_subject_id`, etc.
   - Is it safer to initialize ALL random effects, even if not causing explosions?
   - Or is minimal initialization (just NDT intercept) sufficient?

4. **Alternative approaches to consider:**
   - Should I try `init = "random"` or `init = 0` instead of custom init?
   - Would raising RT floor further (e.g., 300ms) help if we wanted to add NDT RE back?
   - Are there other reparameterizations or prior structures that would help?

5. **Error investigation:**
   - How can I debug "argument 5 is empty" more effectively?
   - Should I check Stan model compilation separately?
   - Are there common `brms`/Stan issues that cause this specific error?

---

## Additional Context

**Software Versions:**
- R 4.x
- `brms` 2.22.0
- `cmdstanr` backend
- Stan (via cmdstanr)

**Prior Specifications (Standardized):**
```r
base_priors <- c(
    # Drift rate (v) - identity link
    prior(normal(0, 1), class = "Intercept"),
    
    # Boundary separation (a/bs) - log link
    prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
    
    # Non-decision time (t0/ndt) - log link: response-signal design
    prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
    
    # Starting point bias (z) - logit link
    prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
    
    # Random effects - subject-level variability
    prior(student_t(3, 0, 0.5), class = "sd")
)
```

**Data Characteristics:**
- Min RT: 250ms (after filtering)
- Max RT: ~3000ms
- Subject-level trials: ~257 per subject (varies)
- Two effort conditions: Low_5_MVC, High_MVC
- Three difficulty levels: Easy, Hard, Standard

---

## What I Need

Please provide:
1. Evaluation of whether removing NDT RE is methodologically sound
2. Diagnosis of why test works but pipeline fails
3. Recommendations for proceeding (continue without NDT RE, or try alternative fixes)
4. Specific code suggestions if you identify the "argument 5 is empty" issue

Thank you for your time and expertise!
















