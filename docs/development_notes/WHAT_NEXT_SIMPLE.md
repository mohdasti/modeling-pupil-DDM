# What's Next - Simple Guide

**Status:** ✅ Fix applied - Ready to re-fit model

---

## 🎯 What Was Fixed

The tight drift constraint (`normal(0, 0.03)`) was preventing the model from fitting. Changed to `normal(0, 2)` to allow negative drift (evidence for "Same").

---

## 🚀 Next Step: Re-fit Model

```r
source("04_computational_modeling/drift_diffusion/fit_standard_bias_only.R")
```

**Time:** ~70 minutes

---

## ✅ What to Expect

After re-fitting, you should see:

1. **Drift (v):** Negative (e.g., -1.5) ✓
2. **Bias (z):** Near 0.5 (e.g., 0.48) ✓  
3. **Fit:** Much better (RMSE < 0.10) ✓
4. **Predictions:** Match data (~89% "Same") ✓

---

## 📝 Key Insight

**Old assumption:** Standard trials = no evidence → drift ≈ 0  
**New understanding:** Standard trials = evidence FOR identity → negative drift

This is physiologically correct for Same/Different tasks!

---

**Ready to run!** ✅

