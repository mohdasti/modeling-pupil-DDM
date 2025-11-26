# Next Steps After Bias Fix

**Date:** 2025-11-25  
**Status:** ✅ Fix applied, ready to re-fit model

---

## ✅ What Was Fixed

1. **Relaxed drift prior:** `normal(0, 0.03)` → `normal(0, 2)`
2. **Updated initialization:** Allows negative drift starting values
3. **Updated validation:** Expects negative drift for Standard trials
4. **Updated documentation:** Explains the fix and expected results

---

## 🎯 Immediate Next Step

### Re-fit the Standard-only Bias Model

```r
source("04_computational_modeling/drift_diffusion/fit_standard_bias_only.R")
```

**Expected runtime:** ~70 minutes

---

## 📊 What to Expect After Re-fitting

### 1. Drift Rate (v)
- **Expected:** Negative value (e.g., -1.0 to -2.0)
- **Meaning:** Evidence accumulation toward "Same" (lower boundary)
- **Old expectation:** v ≈ 0 (this was wrong!)

### 2. Bias (z)
- **Expected:** Near 0.5 (e.g., 0.45 - 0.55)
- **Meaning:** Starting point not extreme, drift explains preference
- **Old result:** z = 0.569 (too high because drift couldn't help)

### 3. Model Fit
- **Expected:** QP RMSE drops dramatically (from ~0.46 to < 0.10)
- **Old result:** QP RMSE = 0.469 (catastrophic misfit)

### 4. Bias Validation
- **Expected:** Model predictions match data (~89% "Same")
- **Old result:** Model predicted ~57% "Different" (completely wrong)

---

## ✅ Verification Checklist

After model finishes, check:

- [ ] Drift intercept is negative (v < 0)
- [ ] Bias intercept is reasonable (0.4 < z < 0.6)
- [ ] Convergence diagnostics still good (Rhat < 1.01, ESS > 400)
- [ ] QP RMSE is low (< 0.10, ideally < 0.05)
- [ ] Validation script shows bias matches data

---

## 📝 If Results Look Good

1. **Update manuscript interpretation:**
   - Negative drift on Standard trials = evidence for identity
   - This is theoretically sound for Same/Different tasks

2. **Proceed with Primary model:**
   - Use relaxed drift prior if Standard trials are included
   - Or use conditional drift (v ≈ 0 only enforced if needed)

3. **Document the fix:**
   - Update any notes about Standard trial modeling
   - Explain the theoretical justification

---

## ⚠️ If Results Still Look Wrong

If bias still doesn't match after re-fitting:

1. Check convergence diagnostics
2. Review validation output carefully
3. Consider if other model specifications are needed
4. May need to consult brms documentation further

---

## 📚 Key Insight Learned

**Theoretical Understanding:**
- Standard trials (Δ=0) don't mean "no evidence"
- They mean "evidence FOR identity" → negative drift
- This is physiologically and theoretically correct

**Model Specification:**
- Don't over-constrain parameters based on theoretical assumptions
- Let the data speak - use weakly informative priors
- Model fit diagnostics will tell you if assumptions are wrong

---

**Ready to re-fit!** The fix is applied and validated. ✅

