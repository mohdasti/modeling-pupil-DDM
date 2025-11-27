# Manuscript Updates Summary

**Date:** 2025-11-26  
**File:** `reports/chap3_ddm_results.qmd`

## Changes Made

### 1. Decision Coding Section (Line ~345)
- ✅ Updated Standard trial proportions: **89.1% "Same", 10.9% "Different"** (was 87.8%/12.2%)
- ✅ Added note about using direct response-side column (`resp_is_diff`) from raw data

### 2. Total Trials Count (Line ~377)
- ✅ Updated: **17,834 trials** (was 17,243)
- ✅ Added: Standard trials: 3,597 (20.2%)

### 3. Standard-Only Bias Model Section (Line ~645)
- ✅ Updated trial count: **3,597 trials** (was 3,472)
- ✅ Changed from tight drift prior to **relaxed drift prior** (`normal(0, 2)`)
- ✅ Updated formula to use `dec_upper` instead of `decision`
- ✅ Added rationale for relaxed drift prior

### 4. Primary Analysis Model Section (Line ~669)
- ✅ Updated formula to use `dec_upper` instead of `decision`
- ✅ Added note about direct extraction from raw data

### 5. Bias Estimates Results Section (Line ~829)
- ✅ Updated interpretation to reflect negative drift rate (v = -1.404)
- ✅ Explained that drift dominates bias, resulting in 89.1% "Same" responses

### 6. PPC Validation Section (Line ~1341)
- ✅ **NEW**: Added comprehensive PPC Validation Method section
- ✅ Described implementation using `posterior_predict()` with `negative_rt = TRUE`
- ✅ Reported successful validation results: 10.9% observed vs 11.2% predicted (0.3% difference)

### 7. Joint Confirmation Model Section (Line ~660)
- ✅ Updated trial count: **17,834 trials** (was 17,243)
- ✅ Updated formula to use `dec_upper` instead of `decision`

### 8. Other Updates
- ✅ Updated Pareto-k diagnostics: 1/17,834 observations (was 1/17,243)
- ✅ Updated sample size description: ~266 trials per subject (was ~260)
- ✅ Updated figure caption for Standard drift posterior plot

## Key Conceptual Updates

1. **Response-Side Coding**: Now explicitly mentions using direct `resp_is_diff` column from raw data
2. **Drift Prior**: Changed from tight prior (forcing v ≈ 0) to relaxed prior (allowing negative drift)
3. **Bias Interpretation**: Updated to reflect that negative drift explains the high "Same" rate, not just bias
4. **PPC Validation**: Added comprehensive section explaining method and successful results

## Status

✅ **All major updates complete!**

