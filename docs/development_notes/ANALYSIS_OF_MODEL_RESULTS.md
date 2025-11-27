# Analysis of Standard-Only Bias Model Results

**Date:** 2025-11-25  
**Model:** Standard-only bias model (fit_standard_bias_only.R)  
**Status:** ✅ Model converged, but ⚠️ bias interpretation issue detected

---

## ✅ What Worked

1. **Model converged successfully:**
   - Rhat = 1.0007 (excellent)
   - Bulk ESS = 4,270 (excellent)
   - Tail ESS = 7,040 (excellent)
   - No divergent transitions

2. **Data preparation:**
   - 3,597 Standard trials from 67 subjects
   - 89.1% "Same" responses (10.9% "Different")
   - All validations passed

3. **Parameter estimates (look reasonable):**
   - Drift v = -0.036 ≈ 0 ✓
   - Boundary a = 2.38 (reasonable)
   - NDT = 0.225s (< min RT) ✓

---

## ⚠️ CRITICAL ISSUE: Bias Interpretation

**Problem:**
- **Data:** 89.1% "Same" responses (only 10.9% "Different")
- **Model:** Bias z = 0.569 (> 0.5, implying bias toward "Different")

**This is mathematically contradictory!**

### Why This Is Impossible

In a Standard-only model with drift ≈ 0, the bias (z) directly determines response probabilities:
- If z = 0.569, we should see ~56.9% "Different" responses
- But data shows only 10.9% "Different" responses

### Possible Explanations

1. **Coding is reversed:** Maybe `dec_upper = 1` actually means "Same" in brms interpretation?
2. **Boundary interpretation:** Maybe brms uses different boundary conventions?
3. **Drift masking:** Could drift be affecting this even though estimate is near 0?

---

## 🔍 What to Check Next

1. **Verify boundary definitions in brms:**
   - What does `dec(dec_upper)` interpret as upper/lower?
   - How does brms map 0/1 to boundaries?

2. **Check if coding needs to be flipped:**
   - Maybe we need `dec_upper = 0` for "Different"?
   - Or maybe `1 - dec_upper`?

3. **Create a simple test:**
   - Simulate data with known bias
   - Verify brms recovers it correctly
   - Check interpretation

---

## 📊 Current Model Output

```
Bias intercept (logit scale): 0.277
Bias intercept (probability scale): 0.569
Standard trial data - Proportion 'Same': 0.891
```

**Expected:** If 89.1% "Same", bias should be ~0.109 (not 0.569)

---

## ✅ Next Steps

**DO NOT run Primary model yet!** First:

1. ✅ **Investigate brms boundary interpretation**
2. ✅ **Test with simple simulation** 
3. ✅ **Verify if coding needs to be flipped**
4. ✅ **Fix coding if needed**
5. ✅ **Re-fit Standard-only model**
6. ✅ **Then proceed with Primary model**

---

## 📝 Key Question

**In brms wiener model with `rt | dec(dec_upper)`:**
- If `dec_upper = 1` and we want "Different" = upper boundary
- And if z = 0.569 (on probability scale)
- Does this mean starting point is 56.9% toward the upper boundary?

**OR is the interpretation different in brms?**

---

**This needs to be resolved before proceeding!**

