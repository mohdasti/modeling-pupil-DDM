# PPC Fix: negative_rt Parameter

**Date:** 2025-11-26  
**Status:** ✅ **FIX FOUND!**

---

## The Solution

**`posterior_predict()` for wiener models has a `negative_rt` parameter!**

From brms help:
```
negative_rt: Only relevant for Wiener diffusion models. A flag
          indicating whether response times of responses on the lower
          boundary should be returned as negative values. This allows
          to distinguish responses on the upper and lower boundary.
          Defaults to 'FALSE'.
```

**The problem:** Default is `FALSE` → All RTs are positive!

**The fix:** Set `negative_rt = TRUE` → Get signed RTs!

---

## The Change

**Before:**
```r
post_preds <- posterior_predict(fit, newdata = pred_data, ndraws = ndraws)
# All RTs positive → Can't extract choices
```

**After:**
```r
post_preds <- posterior_predict(fit, newdata = pred_data, ndraws = ndraws, negative_rt = TRUE)
# Now RTs will be signed → Can extract choices from sign!
```

---

## How It Works

With `negative_rt = TRUE`:
- **Positive RT (>0):** Upper boundary hit = "Different" (dec_upper=1)
- **Negative RT (<0):** Lower boundary hit = "Same" (dec_upper=0)
- **Absolute value:** The actual reaction time

---

## Expected Result

Now validation should show:
- **Predicted:** ~3-12% "Different" (respecting negative drift)
- **Observed:** 10.9% "Different"
- **Difference:** Should be small (<5%)

---

## Files Updated

- ✅ `R/validate_ppc_proper.R` - Added `negative_rt = TRUE` parameter

---

**Status:** ✅ **Fixed - Ready to re-run!**

