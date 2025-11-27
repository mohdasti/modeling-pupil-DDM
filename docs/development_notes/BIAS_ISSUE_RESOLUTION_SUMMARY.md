# Bias Interpretation Issue - Resolution Summary

**Date:** 2025-11-25  
**Issue:** Bias estimate (z=0.569) contradicted data (10.9% "Different")  
**Root Cause:** Tight drift constraint causing model misfit  
**Status:** ✅ **RESOLVED** - Fix applied, ready to re-fit

---

## 🚨 The Problem

- **Model estimate:** Bias z = 0.569 (predicts ~57% "Different")
- **Data:** Only 10.9% "Different" responses
- **Mismatch:** 46% error - mathematically impossible!

---

## ✅ The Diagnosis (From LLM)

**Good News:** Your coding was **correct all along!**
- `dec_upper=1` for "Different" = Upper Boundary ✓
- `dec_upper=0` for "Same" = Lower Boundary ✓

**Bad News:** The tight drift constraint broke the model:
- `prior(normal(0, 0.03))` forced v ≈ 0
- Model couldn't simultaneously fit:
  - Choice proportions (needs z ≈ 0.11)
  - RT distributions (needs z ≈ 0.5)
- Result: Model kept z ≈ 0.5, ignored choice data → catastrophic misfit

---

## 🔧 The Fix

**Changed:**
```r
# OLD (Caused misfit)
prior(normal(0, 0.03), class = "Intercept")  # Too tight

# NEW (Allows proper fitting)
prior(normal(0, 2), class = "Intercept")  # Weakly informative
```

**Why:** Allows negative drift, which represents evidence FOR "Same" responses.

---

## 📊 Expected Results

After re-fitting with relaxed prior:

1. **Drift (v):** Negative (e.g., -1.5) → evidence for "Same"
2. **Bias (z):** Near 0.5 (e.g., 0.48) → not extreme
3. **Fit:** QP RMSE drops from 0.46 → < 0.05
4. **Predictions:** Model correctly predicts ~89% "Same"

---

## 🎯 Next Steps

1. ✅ Fix applied to `fit_standard_bias_only.R`
2. ⏳ **Re-fit the model** (will take ~70 minutes)
3. ⏳ Verify results match expectations
4. ⏳ Update validation checks if needed
5. ⏳ Proceed with Primary model

---

**Ready to re-fit!** The issue was model specification, not coding. ✅

