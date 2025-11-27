# Response-Side Coding Fix: Implementation Plan

## Critical Issue Identified

**Problem:** Bias parameter z = 0.567 contradicts 87.8% "same" responses on Standard trials.

**Root Cause:** Likely coding inversion or factor level ambiguity in R.

**Solution:** Use direct `resp_is_diff` column with explicit 0/1 integer coding.

---

## Implementation Steps

### Step 1: Update Data Preparation Script

**File:** `prepare_fresh_data.R` (or wherever DDM-ready data is created)

**Changes needed:**
1. Include `resp_is_diff` from raw behavioral data
2. Create explicit integer `dec_upper` column (1 = "different", 0 = "same")
3. Filter out missing responses
4. Add validation checks

### Step 2: Update Model Fitting Scripts

**Files:** All model fitting scripts (e.g., `R/fit_primary_vza.R`)

**Changes needed:**
1. Load data from updated file with `dec_upper`
2. Use `dec(dec_upper)` in model formulas
3. Verify factor levels are correct

### Step 3: Validation Checks

**Before refitting:**
1. Verify boundary proportions match expectations
2. Check that Standard trials show ~12% "different" responses
3. Validate that direct and inferred coding match (should be 100%)

### Step 4: Re-fit Models

**After validation:**
1. Re-fit all models with corrected coding
2. Verify bias estimates are now < 0.5 (around 0.12-0.15)
3. Update manuscript with corrected results

---

## Expected Results After Fix

**Bias (z) on Standard trials:**
- **Before fix:** z = 0.567 (impossible with 87.8% "same")
- **After fix:** z ≈ 0.12-0.15 (consistent with 87.8% "same")

**Drift (v) on Standard trials:**
- May be slightly negative (evidence for "same")
- Or near zero if tightly constrained

---

## Files to Modify

1. `prepare_fresh_data.R` - Add `resp_is_diff` handling
2. `R/fit_primary_vza.R` - Use `dec_upper` instead of `decision`
3. `R/00_build_decision_upper_diff.R` - Update to use direct column
4. All other model fitting scripts

