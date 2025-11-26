# CRITICAL BIAS INTERPRETATION ISSUE

**Date:** 2025-11-25  
**Status:** ⚠️ NEEDS IMMEDIATE INVESTIGATION

---

## 🚨 Problem

Model converged successfully BUT bias estimate contradicts data:

- **Data shows:** 89.1% "Same" responses (10.9% "Different")
- **Model estimates:** Bias z = 0.569 (> 0.5, meaning bias toward upper/"Different")

**This is mathematically impossible!** If participants show 89% "Same" responses, bias should be < 0.1, not 0.569.

---

## 📊 What Happened

### Model Fitting Results:
- ✅ Model converged (Rhat = 1.0007, ESS > 4000)
- ✅ Drift v ≈ 0 (-0.036) ✓
- ✅ Boundary a = 2.38 ✓
- ✅ NDT = 0.225s ✓
- ✗ **Bias z = 0.569** ✗

### Validation Results:
- ✗ Bias estimate (0.569) does NOT match data (0.109)
- ✗ Data shows 'Same' bias (>80%), but model estimates bias > 0.5!

---

## 🔍 Possible Causes

### 1. Boundary Interpretation Reversed
Maybe `brms` interprets boundaries differently than expected?

### 2. Coding Interpretation Issue
Maybe `dec_upper = 1` means something different in brms?

### 3. Formula/Boundary Definition
Need to verify how `rt | dec(dec_upper)` interprets the boundaries

---

## ✅ Next Steps

1. **Check brms documentation** on `dec()` function interpretation
2. **Verify boundary definitions** - what does upper/lower mean?
3. **Check if we need to flip** the coding
4. **Test with simple simulation** to verify interpretation

---

## 📝 Key Question

**What does `z = 0.569` mean in brms wiener model when:**
- `dec_upper = 1` means "Different" (upper boundary)
- `dec_upper = 0` means "Same" (lower boundary)

**Does z represent:**
- Starting point as proportion from lower to upper? (z = 0.569 means closer to upper)
- OR something else?

---

**DO NOT PROCEED WITH PRIMARY MODEL until this is resolved!**

