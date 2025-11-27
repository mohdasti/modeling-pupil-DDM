# Critical PPC Validation Issue

**Date:** 2025-11-26  
**Status:** ⚠️ **CRITICAL - Massive mismatch detected**

---

## The Problem

**Observed:** 10.9% "Different"  
**Predicted:** 66.1% "Different" (95% CI: 64.3%-67.9%)  
**Difference:** 55.2%!

This is a **huge mismatch** - the model is predicting 6x more "Different" responses than observed.

---

## What We Know

### Data Coding:
- `dec_upper = 1` = "Different" (upper boundary)
- `dec_upper = 0` = "Same" (lower boundary)
- Observed: 10.9% "Different", 89.1% "Same" ✓

### Model Parameters:
- **Drift (v):** -1.260 (negative = evidence for "Same")
- **Bias (z):** 0.567 (slightly toward "Different")
- **Boundary (a):** 2.275
- **NDT (t₀):** 0.215s

**Parameters suggest strong "Same" bias, but predictions show "Different" bias!**

### posterior_epred Output:
- Returns values in range [0.58, 0.64]
- Looks like probabilities
- We're interpreting these as P("Different")
- But this gives 66% "Different" - completely wrong!

---

## Possible Issues

### 1. Wrong Interpretation of posterior_epred
- Maybe `posterior_epred` for wiener models doesn't return choice probabilities?
- Maybe it returns expected RT or something else?
- Need to verify what it actually returns

### 2. Reversed Interpretation
- Maybe `posterior_epred` returns P(LOWER boundary) not P(UPPER)?
- But even then, P(Same) = 0.62 → P(Different) = 0.38, still not 10.9%

### 3. Wrong Method
- Maybe we shouldn't use `posterior_epred` at all?
- Maybe we need to extract parameters and calculate analytically?
- Or use `posterior_predict` differently?

---

## Next Steps

1. **Verify what `posterior_epred` returns** for wiener models
2. **Check if interpretation is reversed**
3. **Consider alternative validation method**
4. **Get second opinion from another LLM**

---

## Prompt Created

Created `PROMPT_FOR_LLM_PPC_VALIDATION_ISSUE.md` to ask another LLM about:
- What `posterior_epred` returns for wiener models
- Correct way to validate choice proportions
- Why there's such a huge mismatch

---

**Status:** ⚠️ **Critical issue - validation shows model is completely wrong or method is incorrect**

