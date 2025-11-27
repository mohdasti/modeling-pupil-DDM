# Critical PPC Validation Issue - Analysis

**Date:** 2025-11-26  
**Status:** ⚠️ **CRITICAL - Massive 55% mismatch**

---

## Summary

**Observed:** 10.9% "Different"  
**Predicted:** 66.1% "Different"  
**Difference:** 55.2% - **COMPLETELY WRONG!**

---

## The Problem

The PPC validation shows the model is predicting **6x more "Different" responses** than observed. This suggests either:
1. The validation method is incorrect
2. The model is fundamentally wrong
3. There's a coding/interpretation mismatch

---

## Investigation

### What `posterior_epred` Returns

From help file:
> "Compute posterior draws of the expected value of the posterior predictive distribution"

**For wiener models, this likely returns EXPECTED RT, NOT choice probabilities!**

Test output showed values [0.58, 0.64], which we interpreted as probabilities, but these could be:
- Expected RT in seconds (makes sense - 0.58-0.64s RTs)
- Or some other metric

### Current Method (WRONG?)

```r
pred_choice_probs <- posterior_epred(fit, newdata = pred_data, ndraws = 1000)
# This might return expected RT, not choice probabilities!
```

---

## Possible Solutions

### Option 1: Extract Parameters and Calculate Analytically
Use `posterior_linpred()` to get v, a, z parameters, then calculate choice probabilities using the analytical formula.

### Option 2: Use `posterior_predict()` and Extract Choices
Use `posterior_predict()` which generates full RT samples, then extract choices from the sign or use simulated RTs with observed choices.

### Option 3: Check What posterior_epred Actually Returns
Verify whether it returns RT or probabilities by comparing to known values.

---

## Next Steps

1. **Verify what `posterior_epred` actually returns** (RT or probabilities?)
2. **Try alternative validation method** (extract parameters analytically)
3. **Get second opinion** from another LLM

---

## Prompt Created

Created `PROMPT_FOR_LLM_PPC_VALIDATION_ISSUE.md` with detailed questions about:
- What `posterior_epred` returns for wiener models
- Correct validation approach
- Why there's such a huge mismatch

---

**Status:** ⚠️ **Needs immediate investigation - validation method likely incorrect**

