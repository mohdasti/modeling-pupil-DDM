# Response to Prior Evaluation

**Date:** 2025-01-20  
**Status:** ✅ FULLY AGREE - Critical bugs identified

---

## ✅ I AGREE WITH THIS EVALUATION

The evaluation is **excellent and accurate**. Here's what I verified and agree with:

---

## CRITICAL FINDINGS (ALL CONFIRMED)

### 1. Phase_B.R Scale Bug ⚠️ **CONFIRMED CRITICAL**

**The evaluation says:** `bs` prior is on natural scale but link is log = WRONG

**I verified:**
```r
family = wiener(link_bs = "log", link_ndt = "identity", link_bias = "identity")
prior(normal(1, 0.5), class = "Intercept", dpar = "bs")  # ❌ WRONG - on natural scale!
```

**Assessment:** ✅ **FATAL BUG** - The bs prior must be on log scale, not natural scale.

**Note:** Phase_B.R uses `link_ndt = "identity"` (not "log"), so the ndt prior `normal(0.2, 0.08)` is actually CORRECT for this script. But `bs` is still wrong!

---

### 2. Set 2 (Tonic/History) Wrong Centers ⚠️ **CONFIRMED**

**The evaluation says:** 
- `bs ~ normal(0, 0.2)` centers at exp(0) = 1.0 (too low for older adults)
- `ndt ~ normal(0, 0.2)` centers at exp(0) = 1.0s (wildly wrong)

**I verified:**
```r
family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit")
prior(normal(0, 0.2), class = "Intercept", dpar = "bs")   # centers at 1.0 ✅ confirmed
prior(normal(0, 0.2), class = "Intercept", dpar = "ndt") # centers at 1.0s ✅ confirmed
```

**Assessment:** ✅ **CORRECT** - These centers are inappropriate for older adults and response-signal design.

---

### 3. Set 3 NDT Too Low ⚠️ **CONFIRMED**

**The evaluation says:** `ndt` centered at `log(0.2)` = 0.2s is too low for older adults + response-signal

**Assessment:** ✅ **CORRECT** - Should be 0.35-0.40s for your sample.

---

### 4. Missing Drift Priors ⚠️ **CONFIRMED**

**The evaluation says:** Most scripts don't explicitly specify drift rate priors

**I verified:** Sets 2, 3 rely on brms defaults for drift. Only Set 1 explicitly sets drift Intercept.

**Assessment:** ✅ **CORRECT** - Should be explicit for consistency.

---

### 5. Inconsistent SD Values ⚠️ **CONFIRMED**

**The evaluation notes:** Different SD values (0.3, 0.5, 1.0, 1.5) without clear rationale

**Assessment:** ✅ **SHOULD BE STANDARDIZED** - Especially for production scripts.

---

## ✅ EVALUATION RECOMMENDATIONS - ALL SOUND

### Standardized Prior Spec

The recommended unified specification is:
- **Well-justified** by aging DDM literature
- **Appropriate** for response-signal design
- **Correct scale** for all link functions
- **Defensible** in peer review

**Key recommendations I agree with:**
1. ✅ bs centered at `log(1.7)` for older adults (not log(1.0))
2. ✅ ndt centered at `log(0.35)` for older adults + response-signal (not log(0.2))
3. ✅ bias SD = 0.5 on logit (not 0.2, too tight)
4. ✅ Explicit drift prior: `normal(0, 1)`
5. ✅ Coefficient SD = 0.5 (standardized predictors)
6. ✅ Consistent random effects prior

---

## ⚠️ ADDITIONAL OBSERVATION

**Phase_B.R Link Functions are DIFFERENT:**
```r
family = wiener(link_bs = "log", link_ndt = "identity", link_bias = "identity")
```

**Other scripts use:**
```r
family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit")
```

**This creates inconsistency:** Different link functions mean different parameter interpretations! Should Phase_B use `log` links like others?

---

## 🎯 ACTION PLAN

Based on this evaluation, we need to:

### Immediate Fixes (Critical Bugs)
1. **Fix Phase_B.R bs prior** - Change to log scale
2. **Fix Set 2 centers** - Update bs to log(1.7), ndt to log(0.35)
3. **Fix Set 3 centers** - Update bs to log(1.7), ndt to log(0.35)
4. **Standardize all sets** - Use unified specification

### Consistency Fixes
5. **Standardize link functions** - Decide: identity or log for ndt/bias?
6. **Add explicit drift priors** - All scripts should specify
7. **Standardize SD values** - Use consistent values

---

## 📋 RECOMMENDED STANDARDIZED SPEC

I recommend adopting the unified spec from the evaluation:

```r
priors_std <- c(
  # Drift (v) - identity link
  prior(normal(0, 1),     class = "Intercept"),
  prior(normal(0, 0.5),   class = "b"),
  
  # Boundary separation (a/bs) - log link
  prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
  prior(normal(0, 0.20),        class = "b", dpar = "bs"),
  
  # Non-decision time (t0/ndt) - log link
  prior(normal(log(0.35), 0.25), class = "Intercept", dpar = "ndt"),
  prior(normal(0, 0.15),         class = "b", dpar = "ndt"),
  
  # Starting point (z/bias) - logit link
  prior(normal(0, 0.5),   class = "Intercept", dpar = "bias"),
  prior(normal(0, 0.3),   class = "b", dpar = "bias"),
  
  # Random effects
  prior(student_t(3, 0, 0.5), class = "sd")
)
```

**With consistent link functions:**
```r
family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit")
```

---

## ✅ FINAL VERDICT

**The evaluation is:**
- ✅ Scientifically sound
- ✅ Technically accurate
- ✅ Well-justified by literature
- ✅ Actionable and specific

**I fully agree** and recommend implementing the standardized specification across all scripts.

---

**Next step:** Should I implement these fixes across all your scripts?














