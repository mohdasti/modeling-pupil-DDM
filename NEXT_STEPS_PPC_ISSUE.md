# Next Steps: PPC Validation Critical Issue

**Date:** 2025-11-26  
**Status:** ⚠️ Critical issue detected

---

## The Problem

**Predicted:** 66.1% "Different"  
**Observed:** 10.9% "Different"  
**Difference:** 55.2% - **HUGE MISMATCH!**

---

## Likely Cause

**`posterior_epred()` probably returns EXPECTED RT, NOT choice probabilities!**

The values [0.58, 0.64] we're seeing are likely RTs in seconds, not probabilities of "Different" responses.

---

## Immediate Actions Needed

### 1. Verify What `posterior_epred` Returns
- Check if values are RTs (seconds) or probabilities
- Compare to observed RTs in data

### 2. Use Alternative Validation Method
Instead of `posterior_epred`, we should:

**Option A: Extract Parameters Analytically**
```r
# Extract parameters using posterior_linpred
v_samples <- posterior_linpred(fit, newdata = pred_data, dpar = NULL)  # drift
a_samples <- posterior_linpred(fit, newdata = pred_data, dpar = "bs")  # boundary
z_samples <- posterior_linpred(fit, newdata = pred_data, dpar = "bias") # bias

# Calculate choice probabilities using analytical formula
# P(upper) = (exp(-2*v*a*(1-z)) - 1) / (exp(-2*v*a) - 1)
```

**Option B: Use posterior_predict and Extract Choices**
- Use `posterior_predict()` to get RT samples
- Extract choices from the sign of RT (if brms uses signed RTs)
- Or simulate choices based on parameters

### 3. Get Second Opinion
- Use `PROMPT_FOR_LLM_PPC_VALIDATION_ISSUE.md`
- Ask another LLM what `posterior_epred` returns for wiener models
- Get correct validation approach

---

## Files Created

1. `PPC_VALIDATION_CRITICAL_ISSUE.md` - Issue summary
2. `PROMPT_FOR_LLM_PPC_VALIDATION_ISSUE.md` - Prompt for LLM
3. `PPC_CRITICAL_ISSUE_ANALYSIS.md` - Detailed analysis
4. `NEXT_STEPS_PPC_ISSUE.md` - This file

---

## Recommendation

**Wait for second opinion** from another LLM before proceeding, OR:
- Test what `posterior_epred` actually returns (RT vs probabilities)
- Implement alternative validation method using parameter extraction

---

**Status:** ⚠️ **On hold - awaiting clarification on correct validation method**

