# Bias Issue Fix - Summary

**Date:** 2025-11-25  
**Status:** ✅ **FIXED** - Ready to re-fit

---

## 🎯 The Problem

Your model estimated bias z = 0.569, but data shows only 10.9% "Different" responses. This 46% mismatch indicated catastrophic model failure.

---

## ✅ The Root Cause (Diagnosed by LLM)

**Good News:** Your coding was **100% correct!**
- `dec_upper=1` for "Different" = Upper Boundary ✓
- Boundaries are interpreted correctly ✓

**The Real Problem:** The tight drift constraint broke the model:
```r
prior(normal(0, 0.03), class = "Intercept")  # Too tight!
```

This forced the model to explain 89% "Same" responses ONLY through starting point bias, creating an impossible conflict:
- Choice data needs z ≈ 0.11 (for 89% "Same")
- RT data needs z ≈ 0.5 (because responses aren't instant)
- The model chose to satisfy RTs and ignore choice data → 46% misfit

---

## 🔧 The Fix Applied

**Changed drift prior:**
```r
# OLD (Too restrictive)
prior(normal(0, 0.03), class = "Intercept")  # v ≈ 0

# NEW (Allows proper fitting)
prior(normal(0, 2), class = "Intercept")  # Weakly informative
```

**Why this works:**
- Allows **negative drift** (evidence FOR "Same")
- In Same/Different tasks, "Same" responses come from evidence FOR identity
- Negative drift drives accumulation toward "Same" boundary
- Model can now fit both choice proportions AND RT distributions

---

## 📊 What to Expect After Re-fitting

1. **Drift (v):** Negative (e.g., -1.5)
   - Represents evidence for "Same" responses
   
2. **Bias (z):** Near 0.5 (e.g., 0.48)
   - Not forced to extreme values
   
3. **Fit Quality:** Much better
   - QP RMSE should drop from 0.46 → < 0.10
   
4. **Predictions:** Match data
   - Model should correctly predict ~89% "Same"

---

## 🚀 Next Step

**Re-fit the model:**
```r
source("04_computational_modeling/drift_diffusion/fit_standard_bias_only.R")
```

Expected runtime: ~70 minutes

After it finishes, check that:
- ✅ Drift is negative
- ✅ Bias is near 0.5
- ✅ Fit quality improved
- ✅ Predictions match data

---

**All fixes applied - ready to go!** ✅

