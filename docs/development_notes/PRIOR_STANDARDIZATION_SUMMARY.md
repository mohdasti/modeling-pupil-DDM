# Prior Standardization Implementation Summary

**Date:** 2025-01-20  
**Status:** ✅ COMPLETE

---

## Overview

All DDM prior specifications have been standardized across the entire codebase based on the literature-justified evaluation. Critical bugs have been fixed, and all scripts now use a unified, defensible prior specification.

---

## ✅ CRITICAL FIXES APPLIED

### 1. Phase_B.R - Scale Bug Fix ⚠️ **CRITICAL**

**Before:**
```r
prior(normal(1, 0.5), class = "Intercept", dpar = "bs")  # ❌ WRONG - natural scale
family = wiener(link_bs = "log", link_ndt = "identity", link_bias = "identity")
```

**After:**
```r
prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs")  # ✅ CORRECT - log scale
family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit")  # ✅ Standardized
```

**Impact:** This was a fatal bug - bs prior was on natural scale but link was log, causing incorrect prior specification.

---

### 2. Set 2 Scripts - Wrong Centers Fixed

**Files Updated:**
- `scripts/tonic_alpha_analysis.R`
- `scripts/history_modeling.R`
- `scripts/qc/lapse_sensitivity_check.R`

**Before:**
```r
prior(normal(0, 0.2), class = "Intercept", dpar = "bs")   # centers at exp(0) = 1.0 ❌
prior(normal(0, 0.2), class = "Intercept", dpar = "ndt") # centers at exp(0) = 1.0s ❌
prior(normal(0, 0.2), class = "Intercept", dpar = "bias") # too tight ❌
```

**After:**
```r
prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs")   # ✅ appropriate for older adults
prior(normal(log(0.35), 0.25), class = "Intercept", dpar = "ndt") # ✅ appropriate for older adults + response-signal
prior(normal(0, 0.5), class = "Intercept", dpar = "bias")          # ✅ moderate spread
```

**Impact:** Centers were too low and inappropriate for older adults. Now properly centered based on aging DDM literature.

---

### 3. Set 3 (fit_ddm_brms.R) - NDT Too Low Fixed

**Before:**
```r
prior(normal(log(0.2), 0.3), class = "Intercept", dpar = "ndt")  # ❌ too low
prior(normal(0, 0.2), class = "Intercept", dpar = "bs")           # ❌ too low
```

**After:**
```r
prior(normal(log(0.35), 0.25), class = "Intercept", dpar = "ndt") # ✅ appropriate
prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs")  # ✅ appropriate
```

**Impact:** NDT center was appropriate for young adults but not older adults in a response-signal design.

---

### 4. Set 1 (02_ddm_analysis.R) - Missing Parameter-Specific Priors

**Before:**
```r
common_priors <- c(
    prior(normal(0, 1.5), class = "Intercept"),
    prior(normal(0, 1), class = "b"),
    prior(exponential(1), class = "sd")
    # ❌ Missing bs, ndt, bias priors
)
```

**After:**
```r
common_priors <- c(
    # ✅ Complete specification with all parameters
    prior(normal(0, 1), class = "Intercept"),
    prior(normal(0, 0.5), class = "b"),
    prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
    prior(normal(0, 0.20), class = "b", dpar = "bs"),
    prior(normal(log(0.35), 0.25), class = "Intercept", dpar = "ndt"),
    prior(normal(0, 0.15), class = "b", dpar = "ndt"),
    prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
    prior(normal(0, 0.3), class = "b", dpar = "bias"),
    prior(student_t(3, 0, 0.5), class = "sd")
)
```

**Impact:** Model was relying on brms defaults for bs, ndt, and bias, which is not explicit or defensible.

---

### 5. Set 6 (compare_models.R) - Standardized for Model Comparison

**Before:**
```r
prior = c(prior(normal(0,0.5), class="b"), prior(normal(0,1), class="sd"))  # ❌ minimal
```

**After:**
```r
prior = c(
    # ✅ Full specification to hold priors constant across models
    prior(normal(0, 1), class = "Intercept"),
    prior(normal(0, 0.5), class = "b"),
    prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
    # ... (full spec)
)
```

**Impact:** Model comparison now holds priors constant, so Bayes factors/LOO target model structure, not prior differences.

---

## 📋 STANDARDIZED PRIOR SPECIFICATION

All scripts now use this unified specification:

```r
priors_std <- c(
  # Drift rate (v) - identity link
  prior(normal(0, 1), class = "Intercept"),
  prior(normal(0, 0.5), class = "b"),
  
  # Boundary separation (a/bs) - log link: center at log(1.7) for older adults
  prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
  prior(normal(0, 0.20), class = "b", dpar = "bs"),
  
  # Non-decision time (t0/ndt) - log link: center at log(0.35) for older adults + response-signal
  prior(normal(log(0.35), 0.25), class = "Intercept", dpar = "ndt"),
  prior(normal(0, 0.15), class = "b", dpar = "ndt"),
  
  # Starting point bias (z) - logit link: centered at 0.5 with moderate spread
  prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
  prior(normal(0, 0.3), class = "b", dpar = "bias"),
  
  # Random effects - subject-level variability
  prior(student_t(3, 0, 0.5), class = "sd")
)
```

**Link Functions (Standardized):**
```r
family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit")
```

---

## 📁 FILES MODIFIED

1. ✅ `01_data_preprocessing/r/Phase_B.R`
   - Fixed bs prior scale bug
   - Standardized link functions
   - Updated all priors to standardized spec

2. ✅ `scripts/02_statistical_analysis/02_ddm_analysis.R`
   - Added parameter-specific priors
   - Updated baseline model priors
   - Standardized link functions

3. ✅ `scripts/tonic_alpha_analysis.R`
   - Fixed bs/ndt/bias centers
   - Added explicit drift prior
   - Standardized to unified spec

4. ✅ `scripts/history_modeling.R`
   - Fixed bs/ndt/bias centers
   - Added explicit drift prior
   - Standardized to unified spec

5. ✅ `scripts/qc/lapse_sensitivity_check.R`
   - Fixed bs/ndt/bias centers
   - Added explicit drift prior
   - Standardized to unified spec

6. ✅ `scripts/modeling/fit_ddm_brms.R`
   - Fixed ndt/bs centers
   - Added explicit drift prior
   - Standardized to unified spec

7. ✅ `scripts/modeling/compare_models.R`
   - Expanded minimal priors to full spec
   - Ensures consistent priors across models for comparison

---

## ✅ VERIFICATION

**All scripts verified to have:**
- Standardized prior centers (bs: log(1.7), ndt: log(0.35))
- Standardized link functions (log/log/logit)
- Explicit drift rate priors
- Consistent random effects priors
- All priors on correct link scales

**Verification counts:**
- 7 scripts with standardized priors: ✅
- All link functions standardized: ✅
- No natural-scale priors with log links: ✅

---

## 🎯 RATIONALE

**Why these centers/spreads?**

1. **Boundary separation (bs = 1.7):** Older adults typically adopt more cautious thresholds (1.5–2.2 range). Centers at 1.7 with ±35% spread appropriate.

2. **Non-decision time (ndt = 0.35s):** With response-screen timing and older adults, expect 0.30–0.45s. Center at 0.35s covers this range.

3. **Starting point bias (z = 0.5):** Centered at 0.5 (no bias), moderate spread (0.5 on logit) allows movement in either direction.

4. **Drift rate (v = 0):** 0-centered to avoid baking in "easy > hard" before data.

**Literature Support:**
- Theisen et al. (2020) - Age differences in DDM parameters meta-analysis
- Ratcliff (2006) - Response-signal diffusion models
- de Gee et al. (2020) - Pupil-linked arousal and DDM

---

## 📝 NEXT STEPS

1. **Re-run models:** All existing model fits should be re-run with the corrected priors.

2. **Documentation:** Update any manuscripts/analyses to reference the standardized prior specification.

3. **Validation:** Consider running prior sensitivity analyses if needed for publication.

---

## 🔗 REFERENCES

- Evaluation document: External LLM evaluation (provided by user)
- Response document: `PRIOR_EVALUATION_RESPONSE.md`
- Original audit: `PROMPT_FOR_PRIOR_EVALUATION.md`

---

**Implementation Complete:** All critical bugs fixed, all scripts standardized. ✅
















