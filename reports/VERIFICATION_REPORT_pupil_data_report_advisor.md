# Verification Report: pupil_data_report_advisor.qmd

**Date**: 2025-01-27  
**Report File**: `reports/pupil_data_report_advisor.qmd`  
**Purpose**: Comprehensive verification of data quality report accuracy

---

## Executive Summary

This verification identified **CRITICAL DISCREPANCIES** between the report documentation and the actual data processing code. The report's stated requirements do not match the actual gate definitions used in the data pipeline.

---

## Critical Issues Found

### 1. **CRITICAL: `ddm_ready` Flag Definition Mismatch**

**Report States (Section 6.1, 6.2)**:
- Chapter 3 DDM with Pupil Predictors requires:
  - Baseline validity ≥ 50% AND Cognitive validity ≥ 50%
  - RT between 0.2s and 3.0s

**Actual Code (`scripts/make_quick_share_v7.R`, lines 1449-1452)**:
```r
ddm_ready = (has_behavioral_data == TRUE | 
             (if ("has_behavioral_data" %in% names(.)) has_behavioral_data else 
              !is.na(rt) & !is.na(choice))) &
            (baseline_quality >= 0.50 | is.na(baseline_quality))
```

**Problems**:
1. ❌ **Missing `cog_quality >= 0.50` check** - Only checks baseline_quality
2. ❌ **Missing RT filter (0.2-3.0s)** - No RT range validation
3. ⚠️ **Allows `baseline_quality` to be NA** - Uses `| is.na(baseline_quality)` which means trials with missing baseline quality can still pass

**Impact**: The report's statistics for Chapter 3 readiness are **INCORRECT** because they're based on a different definition than what's actually in the data files.

**Recommendation**: 
- **URGENT**: Fix the `ddm_ready` calculation to match the report's stated requirements
- Update the code to: `ddm_ready = has_behavioral_data & baseline_quality >= 0.50 & cog_quality >= 0.50 & !is.na(rt) & rt >= 0.2 & rt <= 3.0`

---

### 2. **DISCREPANCY: `gate_pupil_primary` Includes Additional Requirements**

**Report States (Section 5.1, 5.2)**:
- Chapter 2 Primary requires:
  - Baseline validity ≥ 60% AND Cognitive validity ≥ 60%

**Actual Code (`scripts/make_quick_share_v7.R`, line 1397)**:
```r
gate_pupil_primary = gate_baseline_60 & gate_cog_60 & gate_auc_both & found_in_flat_run
```

**Additional Requirements Not Mentioned in Report**:
1. ⚠️ **`gate_auc_both`** - Requires both Total AUC and Cognitive AUC to be available
2. ⚠️ **`found_in_flat_run`** - Requires trial to be found in flat run data

**Impact**: The report's Chapter 2 statistics may be **UNDERESTIMATED** because the actual gate is stricter than documented. However, the report's fallback calculations (lines 276-282, 471-477) correctly use `baseline_quality >= 0.60 & cog_quality >= 0.60`, so if the flag is missing, the calculations would be correct.

**Recommendation**:
- **Option A**: Update the report to document the full requirements of `gate_pupil_primary`
- **Option B**: Simplify `gate_pupil_primary` to only check quality thresholds (if AUC availability and flat run presence are not essential for Chapter 2)

---

## Data Path Verification

### ✅ Paths Are Correct
- Report uses: `data/pupil_processed/` (line 63)
- This matches the current directory structure
- QC files are correctly referenced from `data/pupil_processed/qc/`
- Analysis-ready files from `data/pupil_processed/analysis_ready/`

### ⚠️ File Existence Not Verified
- The verification did not check if `ch2_triallevel.csv` and `ch3_triallevel.csv` actually exist
- The report will fail at runtime if these files are missing (which is appropriate)

---

## Calculation Logic Verification

### ✅ Executive Summary Calculations (Lines 117-165)
- Participant count: `length(unique(ch2_data$sub))` - **CORRECT**
- Total trials: `nrow(ch2_data)` - **CORRECT**
- Behavioral join coverage: Uses merged_data if available, otherwise join_health - **CORRECT**
- Chapter 2 metrics: Correctly checks for `gate_pupil_primary`, then `pass_primary_060`, then falls back to threshold calculation - **CORRECT**
- Chapter 3 metrics: Checks for `ddm_ready` flag, but **this flag is incorrectly calculated** (see Issue #1)
- AUC availability: Correctly filters by task - **CORRECT**

### ✅ Participant Summary (Lines 268-347)
- Chapter 2 summary: Correctly uses fallback logic - **CORRECT**
- Chapter 3 summary: Uses `ddm_ready` flag, but **this flag is incorrectly calculated** (see Issue #1)
- Full join logic: Correctly handles NA values - **CORRECT**

### ✅ Task and Condition Breakdown (Lines 465-522)
- Task summaries: Correctly calculate from actual data - **CORRECT**
- Join with gate_rates: Correctly uses left_join - **CORRECT**

### ✅ Threshold Sensitivity (Lines 592-676)
- Uses `gate_rates` data correctly - **CORRECT**
- Calculations are consistent - **CORRECT**

### ⚠️ Chapter 3 Availability (Lines 1076-1131)
- The calculation uses `ddm_ready` flag, which is **INCORRECTLY DEFINED** (see Issue #1)
- The fallback calculation (lines 1085-1087) is **CORRECT** and matches the report's stated requirements
- **Recommendation**: The report should use the fallback calculation instead of relying on the `ddm_ready` flag

---

## Consistency Checks

### ✅ Terminology Consistency
- "Baseline validity" consistently refers to `baseline_quality`
- "Cognitive validity" consistently refers to `cog_quality`
- Thresholds (50%, 60%, 70%) are consistently applied

### ✅ Cross-Reference Consistency
- Section 4.1 describes thresholds correctly
- Section 5.1 matches Section 4.1 for Chapter 2
- Section 6.1 describes Chapter 3 requirements, but **doesn't match actual code**

### ⚠️ Note on Data Files (Line 1943)
- Report mentions `quick_share_v7/merged/` but code uses `data/pupil_processed/merged/`
- This is a documentation issue, not a code issue

---

## RT-Normalized Metrics Section (Section 8)

### ✅ Calculations Are Correct
- `cog_window_duration` calculation (lines 1231-1233): **CORRECT**
- `cog_mean` calculation (lines 1236-1238): **CORRECT**
- RT binning (lines 1247-1254): **CORRECT**

### ✅ Diagnostic Plots
- Scatter plot logic: **CORRECT**
- Correlation calculations: **CORRECT**

---

## Gap-Aware QC Metrics Section (Section 8.3)

### ✅ Conditional Logic
- Checks for gap metrics availability: **CORRECT**
- Handles missing metrics gracefully: **CORRECT**

### ⚠️ Note
- The gap-aware metrics may not be available in current dataset
- Report correctly handles this with conditional checks

---

## Recommendations

### Priority 1: CRITICAL FIXES

1. **Fix `ddm_ready` calculation** in `scripts/make_quick_share_v7.R`:
   ```r
   ddm_ready = (has_behavioral_data == TRUE | 
                (!is.na(rt) & !is.na(choice))) &
               !is.na(baseline_quality) & baseline_quality >= 0.50 &
               !is.na(cog_quality) & cog_quality >= 0.50 &
               !is.na(rt) & rt >= 0.2 & rt <= 3.0
   ```

2. **Regenerate `ch3_triallevel.csv`** with corrected `ddm_ready` flag

3. **Update report documentation** to match actual gate definitions OR update gates to match documentation

### Priority 2: Documentation Updates

1. **Clarify `gate_pupil_primary` requirements** in report:
   - Document that it also requires `gate_auc_both` and `found_in_flat_run`
   - OR simplify the gate to only check quality thresholds

2. **Fix file path reference** in Section 9.3 (line 1943):
   - Change `quick_share_v7/merged/` to `data/pupil_processed/merged/`

### Priority 3: Verification

1. **Run the report** after fixes to verify all calculations match
2. **Cross-check** reported numbers with actual data counts
3. **Verify** that `ch2_triallevel.csv` and `ch3_triallevel.csv` exist and have expected columns

---

## Conclusion

The report contains **one critical error** and **one discrepancy** that must be addressed:

1. **CRITICAL**: The `ddm_ready` flag does not match the report's stated requirements for Chapter 3
2. **DISCREPANCY**: The `gate_pupil_primary` flag includes additional requirements not documented in the report

All other calculations and logic appear to be correct. The report's fallback calculations (when flags are missing) are correct and match the documented requirements.

**Action Required**: Fix the `ddm_ready` calculation and regenerate the data files before using this report for analysis decisions.
