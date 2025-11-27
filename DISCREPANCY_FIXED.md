# Discrepancy Fix: Standard Drift Parameter ✅

**Date:** 2025-11-26  
**Issue:** Standard drift was showing -0.107 instead of correct -1.260  
**Status:** ✅ **FIXED**

---

## Problem Identified

The LLM reviewer correctly identified a discrepancy:
- **Section 3 (Fixed Effects)**: Standard drift = -1.260 ✅ (correct)
- **Section 5 (Condition-Specific Parameters)**: Standard drift = -0.107 ❌ (incorrect)

## Root Cause

The posterior samples contain **two intercept columns**:
1. `Intercept` = -0.107 (wrong - appears to be from a different source)
2. `b_Intercept` = -1.260 (correct - this is the brms main formula intercept)

The script was checking `Intercept` first, which gave the wrong value.

## Fix Applied

**File:** `scripts/02_statistical_analysis/extract_comprehensive_parameters.R`

**Change:** Reversed the priority to check `b_Intercept` first:

```r
# BEFORE (wrong):
v_intercept <- if ("Intercept" %in% colnames(post_primary)) {
  post_primary$Intercept  # This gave -0.107
} else if ("b_Intercept" %in% colnames(post_primary)) {
  post_primary$b_Intercept
}

# AFTER (correct):
v_intercept <- if ("b_Intercept" %in% colnames(post_primary)) {
  post_primary$b_Intercept  # This gives -1.260 ✅
} else if ("Intercept" %in% colnames(post_primary)) {
  post_primary$Intercept
}
```

## Verification

After fix, Standard drift parameter:
- ✅ **Mean**: -1.260
- ✅ **95% CrI**: [-1.365, -1.158]
- ✅ **Matches Fixed Effects table**

## Files Updated

1. ✅ `scripts/02_statistical_analysis/extract_comprehensive_parameters.R` - Fixed intercept extraction priority
2. ✅ `output/results/parameter_summary_by_condition.csv` - Regenerated with correct values
3. ✅ Summary documents will reflect correct value on next regeneration

---

## Status

✅ **Discrepancy resolved**  
✅ **All tables now consistent**  
✅ **Ready for visualizations and statistical analysis**

---

**Thank you to the LLM reviewer for catching this critical discrepancy!**

