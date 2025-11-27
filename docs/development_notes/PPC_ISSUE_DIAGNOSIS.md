# PPC Validation Issue - Diagnosis

**Date:** 2025-11-26  
**Root Cause:** ✅ **IDENTIFIED**

---

## The Problem

**Predicted:** 66.1% "Different"  
**Observed:** 10.9% "Different"  
**Difference:** 55.2% - **HUGE MISMATCH**

---

## Root Cause

**`posterior_epred()` returns EXPECTED RT, NOT choice probabilities!**

### Evidence:
- `posterior_epred` returns values [0.61, 0.64] 
- Observed RTs are [0.83, 1.39, 1.34, 0.64, 0.73]
- The values match RT scale (seconds), not probability scale
- One RT (0.6357s) is very close to epred values

### What We Did Wrong:
We treated RT values (0.6 seconds) as probabilities (60%), leading to:
- Predicted 66% "Different" instead of correct ~11%

---

## The Solution

**We need to extract parameters and calculate choice probabilities analytically!**

Use `posterior_linpred()` to get:
- Drift (v)
- Boundary (a)  
- Bias (z)

Then calculate choice probability using analytical formula:
$$P(\text{upper}) = \frac{e^{-2va(1-z)} - 1}{e^{-2va} - 1}$$

---

## Next Steps

1. Create corrected validation script using parameter extraction
2. Calculate choice probabilities analytically for each trial
3. Run proper PPC validation

---

**Status:** ✅ **Root cause identified - need to implement corrected validation method**

