# Response-Side Coding Fix: Implementation Summary

## Critical Issue Resolved

**Problem:** Bias parameter z = 0.567 contradicted 87.8% "same" responses on Standard trials.

**Root Cause:** Likely coding inversion or factor level ambiguity in R factor handling.

**Solution:** Use direct `resp_is_diff` column with explicit 0/1 integer coding.

---

## Changes Made

### 1. Updated `prepare_fresh_data.R`

**Changes:**
- Added `resp_is_diff` from raw behavioral data (line 97)
- Created explicit integer `dec_upper` column (1 = "different", 0 = "same")
- Added filter to exclude trials with missing `resp_is_diff`
- Added validation checks:
  - Boundary proportions on Standard trials
  - Direct vs inferred coding match rate
  - Verification that `dec_upper` contains only 0, 1, or NA

**Key Code:**
```r
resp_is_diff = resp_is_diff,  # Include from behavioral data
# ... later ...
dec_upper = case_when(
    resp_is_diff == TRUE  ~ 1L,  # Upper = Different
    resp_is_diff == FALSE ~ 0L,  # Lower = Same
    TRUE ~ NA_integer_
)
```

### 2. Created `R/fix_response_side_coding.R`

**Purpose:** Fix existing data files that don't have `resp_is_diff`

**What it does:**
- Loads raw behavioral data
- Merges `resp_is_diff` into existing `bap_ddm_ready.csv`
- Creates `dec_upper` column with explicit 0/1 coding
- Validates the coding
- Saves fixed files

**Usage:**
```r
source("R/fix_response_side_coding.R")
```

### 3. Created Documentation

- `RESPONSE_SIDE_CODING_FIX.md`: Implementation plan
- `PROMPT_FOR_LLM_RESPONSE_SIDE_CODING_VERIFICATION.md`: Comprehensive prompt for LLM verification
- `CRITICAL_CODING_ISSUES.md`: Detailed analysis of contradictions
- `DECISION_CODING_ANALYSIS.md`: Resolution options

---

## Next Steps

### Step 1: Fix Existing Data Files

Run the fix script:
```r
source("R/fix_response_side_coding.R")
```

This will create:
- `data/analysis_ready/bap_ddm_ready_fixed.csv`
- `data/analysis_ready/bap_ddm_ready_with_upper_fixed.csv`

### Step 2: Update Model Fitting Scripts

**Files to update:**
- `R/fit_primary_vza.R`
- `R/fit_standard_bias_only.R`
- `R/fit_joint_vza_standard_constrained.R`
- Any other model fitting scripts

**Change needed:**
```r
# OLD (accuracy coding):
rt | dec(decision) ~ ...

# NEW (response-side coding):
rt | dec(dec_upper) ~ ...
```

And update data loading:
```r
# OLD:
dd <- read_csv("data/analysis_ready/bap_ddm_ready.csv", ...)

# NEW:
dd <- read_csv("data/analysis_ready/bap_ddm_ready_fixed.csv", ...)
```

### Step 3: Validation Before Refitting

Run these checks:
```r
library(readr)
library(dplyr)

dd <- read_csv("data/analysis_ready/bap_ddm_ready_fixed.csv", show_col_types=FALSE)

# Check 1: Boundary proportions
prop_std <- mean(subset(dd, difficulty_level=="Standard")$dec_upper, na.rm=TRUE)
cat("Standard trials - Proportion 'Different':", prop_std, "\n")
# Expected: ~0.12 (12%)

# Check 2: Verify dec_upper is only 0 or 1
table(dd$dec_upper, useNA="always")

# Check 3: Verify response_label matches
table(dd$response_label, dd$dec_upper, useNA="always")
```

### Step 4: Re-fit Models

After validation:
1. Update all model scripts to use `dec_upper`
2. Re-fit all models
3. Verify bias estimates are now < 0.5 (around 0.12-0.15)
4. Update manuscript with corrected results

---

## Expected Results After Fix

**Bias (z) on Standard trials:**
- **Before:** z = 0.567 (impossible with 87.8% "same")
- **After:** z ≈ 0.12-0.15 (consistent with 87.8% "same")

**Drift (v) on Standard trials:**
- May be slightly negative (evidence for "same")
- Or near zero if tightly constrained

**Manuscript updates needed:**
- Correct bias interpretation
- Update all bias-related results tables
- Fix discussion of bias effects

---

## Files Modified

1. ✅ `prepare_fresh_data.R` - Added `resp_is_diff` handling and validation
2. ✅ `R/fix_response_side_coding.R` - Created fix script for existing files
3. ⏳ `R/fit_primary_vza.R` - Needs update to use `dec_upper`
4. ⏳ Other model fitting scripts - Need updates

---

## Validation Checklist

Before refitting models, verify:

- [ ] `dec_upper` contains only 0, 1, or NA
- [ ] Standard trials show ~12% "different" responses
- [ ] Direct vs inferred coding matches 100%
- [ ] No missing `resp_is_diff` values in final dataset
- [ ] Model scripts updated to use `dec_upper`
- [ ] Data files point to fixed versions

---

## Questions?

If you encounter issues:
1. Check validation output from `prepare_fresh_data.R`
2. Review `CRITICAL_CODING_ISSUES.md` for detailed analysis
3. Consult `PROMPT_FOR_LLM_RESPONSE_SIDE_CODING_VERIFICATION.md` for LLM verification

