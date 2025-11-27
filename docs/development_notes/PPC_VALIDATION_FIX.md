# PPC Validation Script Fix

**Date:** 2025-11-26  
**Issues Fixed:** Choice extraction and sprintf formatting

---

## Issues Found

### 1. Choice Extraction Error
**Problem:** Script was using `post_preds > 0` to extract choices, but:
- `posterior_predict` for brms wiener returns RT values (always positive)
- RTs don't have sign indicating boundary
- Result: 100% "Different" (all RTs are positive)

**Fix:** Use `posterior_epred()` to get predicted choice probabilities, then sample binary choices from those probabilities.

### 2. sprintf Formatting Error
**Problem:** `sprintf` was failing on `"95% Credible Interval"` because `%` needs to be escaped.

**Fix:** Changed all `%` to `%%` in sprintf format strings.

---

## Changes Made

1. **Replaced choice extraction logic:**
   - Old: `pred_choices <- post_preds > 0` (wrong - RTs always positive)
   - New: Use `posterior_epred()` to get probabilities, then sample binary choices

2. **Fixed sprintf formatting:**
   - Changed `"95%"` to `"95%%"` in all sprintf calls

3. **Added support for custom ndraws:**
   - Can set `NDRAWS <- 1000` before sourcing to use 1000 draws instead of 500

---

## How to Use

### Default (500 draws):
```r
source("R/validate_ppc_proper.R")
```

### With 1000 draws:
```r
NDRAWS <- 1000
source("R/validate_ppc_proper.R")
```

---

## Expected Behavior

The script will now:
1. Generate RT predictions (for reference)
2. Generate choice probabilities using `posterior_epred()`
3. Sample binary choices from those probabilities
4. Calculate proportions "Different" for each draw
5. Compare observed (10.9%) to 95% credible interval

**Expected result:** Observed should fall within 95% CI, indicating model fits correctly.

---

**Status:** ✅ Fixed and ready to run

