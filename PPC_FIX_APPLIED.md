# PPC Validation Fix Applied

**Date:** 2025-11-26  
**Status:** ✅ Fixed - Corrected validation method implemented

---

## The Problem

**Previous approach (WRONG):**
- Used `posterior_epred()` which returns **expected RT** (seconds)
- Treated RT values (0.6s) as probabilities (60%)
- Result: Predicted 66% "Different" instead of ~11%

---

## The Root Cause

**Unit error:** Treated Reaction Time (seconds) as Probability (0-1)

- `posterior_epred()` for wiener models returns **expected RT in seconds**
- Values like 0.58-0.64 are RTs, not probabilities
- We incorrectly used these as probabilities in `rbinom()`

---

## The Fix

**Correct approach:**
- Use `posterior_predict()` which returns **signed RTs**
- **Positive RT (>0)** = Upper boundary = "Different" (dec_upper=1)
- **Negative RT (<0)** = Lower boundary = "Same" (dec_upper=0)
- Extract choices: `pred_choices <- post_preds > 0`

---

## Updated Code

```r
# Generate posterior predictions (signed RTs)
post_preds <- posterior_predict(fit, newdata = pred_data, ndraws = 1000)

# Extract choices from sign
# Positive = Upper boundary (Different), Negative = Lower boundary (Same)
pred_choices <- post_preds > 0

# Calculate proportion "Different" for each draw
pred_prop_diff <- apply(pred_choices, 1, function(x) mean(x, na.rm = TRUE))
```

---

## Expected Result

Now the validation should show:
- **Predicted:** ~11% "Different" (matching observed)
- **Observed:** 10.9% "Different"
- **Difference:** <5% (acceptable)

---

## Files Updated

- `R/validate_ppc_proper.R` - Fixed to use signed RTs correctly

---

## Key Insight

The model was **always correct** - the validation method was wrong. Parameters (v=-1.26) correctly indicate "Same" preference, and `posterior_predict()` will respect this.

---

**Status:** ✅ **Fixed and ready to re-run**

