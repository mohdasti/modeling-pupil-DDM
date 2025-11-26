# PPC Issue: ALL RTs Are Positive

**Date:** 2025-11-26  
**Status:** ⚠️ Critical - All predicted RTs are positive

---

## The Problem

**`posterior_predict()` returns ALL positive RTs - no negative values!**

- Range: [0.38, 2.84] seconds
- Negative values: 0
- Positive values: 100% (all trials)

**Result:** Can't use sign to extract choices → Getting 100% "Different"

---

## What This Means

Either:
1. `posterior_predict()` for wiener models doesn't return signed RTs
2. We need a different method to extract choices
3. There's a setting or option we're missing

---

## Evidence

**Test on 10 trials:**
- ALL predicted RTs positive [0.38, 2.84]
- Observed data: Mostly "Same" (8 out of 10)
- Model drift: -1.260 (should favor "Same")

**This is contradictory!**

---

## Possible Solutions

### Option 1: Extract Parameters Analytically
```r
# Extract parameters using posterior_linpred
v_samples <- posterior_linpred(fit, newdata = pred_data, dpar = NULL)
a_samples <- posterior_linpred(fit, newdata = pred_data, dpar = "bs")
z_samples <- posterior_linpred(fit, newdata = pred_data, dpar = "bias")

# Calculate choice probabilities analytically
# P(upper) = (exp(-2*v*a*(1-z)) - 1) / (exp(-2*v*a) - 1)
```

### Option 2: Check What `dec()` Actually Does
- Maybe choices are stored elsewhere?
- Maybe we need to check model output differently?

### Option 3: Use Alternative Method
- Extract from posterior draws directly
- Use RWiener package to simulate

---

## Prompt Created

Created `PROMPT_FOR_LLM_POSTERIOR_PREDICT_ALL_POSITIVE.md` to ask another LLM:
- Why all RTs are positive
- How to extract choices correctly
- What `dec()` does in brms wiener models

---

**Status:** ⚠️ **Awaiting clarification on correct method**

