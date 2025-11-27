# Bias Interpretation Fix - Applied

**Date:** 2025-11-25  
**Status:** ✅ **FIX APPLIED** - Ready to re-fit model

---

## 🎯 The Root Cause (Diagnosed by LLM)

**The Problem:** The tight drift constraint (`normal(0, 0.03)`) was forcing the model to attribute ALL preference for "Same" to starting point bias, creating a conflict:

1. **Choice data** requires z ≈ 0.11 (to predict 89% "Same")
2. **RT data** requires z ≈ 0.5 (because "Same" responses aren't instant)
3. **Prior** prefers z ≈ 0.5

**Result:** Model kept z ≈ 0.5 to satisfy RTs and prior, completely ignoring choice proportions → catastrophic misfit (46% error).

---

## ✅ The Solution

**Key Insight:** In Same/Different tasks, "Same" responses aren't just absence of evidence - they're evidence FOR identity. This requires **negative drift** (accumulation toward "Same" boundary).

### Changes Made:

1. **Relaxed Drift Prior:**
   ```r
   # OLD (Too restrictive - caused misfit)
   prior(normal(0, 0.03), class = "Intercept")  # v ≈ 0 (very tight)
   
   # NEW (Allows negative drift)
   prior(normal(0, 2), class = "Intercept")  # Weakly informative, allows negative values
   ```

2. **Updated Initialization:**
   ```r
   # OLD
   Intercept = 0  # drift ≈ 0
   
   # NEW
   Intercept = rnorm(1, -1, 1)  # Negative drift more likely for Standard trials
   ```

3. **Updated Log Messages:**
   - Removed references to "tight constraint"
   - Added explanation that negative drift = evidence for "Same"

---

## 📋 Expected Results After Re-fitting

### What Should Change:

1. **Drift (v):** Should be **negative** (e.g., -1.0 to -2.0)
   - This indicates evidence accumulation toward "Same" (lower boundary)

2. **Bias (z):** Should be closer to **0.5** (e.g., 0.45 - 0.55)
   - No longer forced to extreme values

3. **Fit Quality:** `QP RMSE` should drop dramatically
   - From ~0.46 (catastrophic) to < 0.05 (good fit)

4. **Bias Validation:** Should now match data
   - Model should correctly predict ~89% "Same" responses

---

## 🔍 Verification Checklist

After re-fitting, verify:

- [ ] Drift intercept is negative (v < 0)
- [ ] Bias intercept is near 0.5 (z ≈ 0.5)
- [ ] Model predictions match data (89% "Same", 11% "Different")
- [ ] QP RMSE is low (< 0.10, ideally < 0.05)
- [ ] Convergence diagnostics still good (Rhat < 1.01, ESS > 400)

---

## 📝 Theoretical Update

### Old Understanding (WRONG):
- Standard trials (Δ=0) = no evidence → drift ≈ 0
- All "Same" preference → starting point bias (z)

### New Understanding (CORRECT):
- Standard trials = evidence FOR identity
- "Same" responses = negative drift (v < 0) driving accumulation toward lower boundary
- Starting point bias (z) explains residual preference, not the entire effect

---

## 🎯 Next Steps

1. **Re-fit the model:**
   ```r
   source("04_computational_modeling/drift_diffusion/fit_standard_bias_only.R")
   ```

2. **Verify results match expectations**

3. **Update manuscript interpretation** (if needed)

4. **Proceed with Primary model** (once Standard-only model is correct)

---

## 📚 References

- **LLM Diagnosis:** Confirmed coding is correct, issue was model specification
- **brms Documentation:** `dec_upper=1` = Upper Boundary (correct)
- **DDM Theory:** Negative drift = evidence accumulation toward lower boundary

---

**Status:** Fix applied and ready for re-fitting! ✅

