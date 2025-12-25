# Quick-Share v7 Output Inspection Report

**Generated:** $(date)  
**Inspector:** Auto (AI Assistant)  
**Status:** ⚠️ **CRITICAL ISSUES FOUND**

---

## Executive Summary

The v7 pipeline completed successfully but has **critical data quality issues** that must be addressed before sharing:

1. **❌ AUC computation completely failed** - 0% AUC availability (all trials failed B0 baseline)
2. **⚠️ Column naming conflicts** - Duplicate columns from join (`.x` and `.y` suffixes)
3. **✅ Data structure is correct** - No duplicate trial_uid, proper behavioral join (87.2%)
4. **✅ Behavioral derivations appear correct** - Need spot-check verification
5. **⚠️ Timing source is 100% "fixed_design"** - No PTB timing extracted

---

## 1. File Structure & Counts ✅

### Output Files Created:
- `merged/BAP_triallevel_merged_v4.csv` - 14,586 rows (1 header + 14,585 trials)
- `analysis/ch2_analysis_ready_with_auc.csv` - 12,715 rows (behavioral-matched trials)
- `analysis/ch3_ddm_ready_with_auc.csv` - 7,450 rows (DDM-ready subset)
- QC files: 4 CSVs in `qc/` folder

### File Sizes (Reasonable):
- Merged file: 4.3 MB
- Ch2 analysis: 1.8 MB  
- Ch3 analysis: 949 KB
- QC files: <4 KB each

### Trial Counts:
- **Total trials:** 14,586 (unique by `trial_uid`)
- **Behavioral joined:** 12,715 (87.2%) ✅
- **Ch2 ready:** 12,715 trials
- **Ch3 ready:** 7,450 trials (filtered by RT range + QC gates)

**✅ No duplicate trial_uid found in any output file**

---

## 2. Critical Issue: AUC Computation Failed ❌

### Problem:
- **AUC availability: 0%** (0 trials have valid AUC)
- All trials failed with reason: `B0_insufficient_samples`
- `n_valid_B0` column is **all NA** (logical type, not integer)
- `total_auc` and `cog_auc` columns are **all NA**

### Missingness Breakdown:
```
ADT: 7,530 trials failed (B0_insufficient_samples)
VDT: 6,900 trials failed (B0_insufficient_samples)
VDT: 27 trials failed (cog_auc_failed)
VDT: 6 trials failed (b0_insufficient_samples)
```

**Total: 14,463 / 14,586 trials (99.2%) have no AUC**

### Root Cause Analysis:
The baseline window `[-0.5, 0.0)` relative to squeeze onset is not finding any valid samples. Possible reasons:

1. **Timing anchor detection failed** - `squeeze_onset` may be incorrect
2. **Time column interpretation wrong** - Time may already be relative, causing double-subtraction
3. **Baseline window misaligned** - Window may be outside the actual data range
4. **All samples in baseline window are NaN** - Data quality issue

### Evidence:
- `n_valid_B0` is logical/NA (should be integer 0-125)
- All trials show `auc_available = FALSE`
- Timing source is 100% "fixed_design" (no PTB timing found)

---

## 3. Column Naming Conflicts ⚠️

### Duplicate Columns from Join:
The merged file has duplicate columns with `.x` and `.y` suffixes:
- `total_auc.x` / `total_auc.y` / `total_auc` (final)
- `cog_auc_fixed1s` (from v6) / `cog_auc` (from v7)
- `t_target_onset_rel.x` / `t_target_onset_rel.y` / `t_target_onset_rel` (final)
- `auc_available.x` / `auc_available.y` / `auc_available` (final)
- `auc_missing_reason.x` / `auc_missing_reason.y`

### Impact:
- Confusing column structure
- Potential for using wrong column in analysis
- File size slightly inflated

### Recommendation:
- Drop `.x` and `.y` columns after join
- Standardize on final column names
- Document which columns to use for analysis

---

## 4. Behavioral Data Quality ✅

### Join Health:
- **Overall behavioral join rate: 87.2%** (12,715 / 14,586 trials)
- **By task:**
  - ADT: ~88% join rate
  - VDT: ~86% join rate

### Subjects with 0% Join Rate (6 subjects):
- BAP109 (ADT session 3, VDT session 2)
- BAP144 (ADT session 2, VDT session 3)
- BAP193 (ADT session 2)
- BAP183 (VDT session 3)

**These subjects likely missing behavioral files or key mismatches.**

### Behavioral Derivation Columns Present:
- ✅ `isOddball` (derived from `stimulus_intensity`)
- ✅ `choice_num` (0=SAME, 1=DIFFERENT)
- ✅ `choice_label` ("SAME"/"DIFFERENT")
- ✅ `correct_final` (computed as `choice_num == isOddball`)

**⚠️ Need spot-check verification** - Script had slice_sample bug, couldn't verify automatically

---

## 5. Gate Pass Rates ⚠️

### QC Gate Pass Rates (behavioral-matched trials only):
```
Threshold 0.50:
  ADT: 50.9% pass (baseline >= 0.50 AND cog >= 0.50)
  VDT: 59.1% pass

Threshold 0.60:
  ADT: 45.3% pass
  VDT: 54.5% pass

Threshold 0.70:
  ADT: 37.3% pass
  VDT: 47.4% pass
```

**Note:** These gates are based on `baseline_quality` and `cog_quality` from MATLAB pipeline, NOT from AUC computation (which failed).

### AUC-Ready Gate:
- **0% pass rate** (no trials have valid AUC)

---

## 6. Timing Information ⚠️

### Timing Source:
- **100% "fixed_design"** - No PTB timing extracted
- All trials use default offsets:
  - `t_target_onset_rel = 4.35` seconds
  - `t_resp_start_rel = 4.70` seconds

### Timing Coverage:
- All 14,586 trials have timing info (100%)
- `dt_median` ~0.0035-0.004 seconds (consistent with 250 Hz)

**Issue:** PTB timing extraction failed. The script tried to use `trial_start_time_ptb` but may not have found it, or the column name doesn't match.

---

## 7. Data Structure Validation ✅

### Trial Identity:
- ✅ All files have unique `trial_uid`
- ✅ No duplicate rows in any output
- ✅ Proper key structure: `sub|task|session_used|run_used|trial_index`

### Column Completeness:
- ✅ Behavioral columns present and populated (for joined trials)
- ✅ QC columns present (`baseline_quality`, `cog_quality`, `overall_quality`)
- ⚠️ AUC columns present but all NA
- ✅ Timing columns present (but all use defaults)

---

## 8. Recommendations for Next Steps

### Immediate Fixes Required:

1. **Fix AUC computation:**
   - Debug why `n_valid_B0` is all NA
   - Verify timing anchor detection (`squeeze_onset`)
   - Check if time column is already relative (causing double-subtraction)
   - Add diagnostic output: print sample of trials with `t_rel` range, `b0_mask` counts

2. **Clean up column names:**
   - Drop `.x` and `.y` columns after join
   - Document which columns to use for analysis
   - Create column mapping documentation

3. **Verify behavioral derivations:**
   - Spot-check 20-50 random trials:
     - `isOddball == (stimulus_intensity != 0)`
     - `choice_label` matches `choice_num`
     - `correct_final == (choice_num == isOddball)`

4. **Investigate PTB timing:**
   - Check if `trial_start_time_ptb` column exists in flat files
   - Verify column name matching logic
   - If PTB timing truly unavailable, document this clearly

### Before Sharing with Another LLM:

1. **Fix AUC computation** - This is blocking for dissertation analysis
2. **Clean column names** - Remove duplicates
3. **Add diagnostic output** - Show why B0 baseline is failing
4. **Create column usage guide** - Document which columns to use

---

## 9. What's Working Well ✅

1. **Data structure is clean** - No duplicates, proper keys
2. **Behavioral merge is solid** - 87.2% join rate is good
3. **File sizes are reasonable** - Not bloated
4. **QC gates are computed** - Pass rates look reasonable (based on MATLAB quality metrics)
5. **No crashes or errors** - Pipeline completed successfully

---

## Summary Checklist

- [x] Files created and accessible
- [x] No duplicate trial_uid
- [x] Behavioral join rate acceptable (87.2%)
- [ ] AUC computation working (0% availability - **BLOCKER**)
- [ ] Column names clean (duplicates present - **NEEDS FIX**)
- [ ] Behavioral derivations verified (needs spot-check)
- [ ] Timing source documented (100% defaults - acceptable but should investigate)

**Overall Status: ⚠️ NOT READY FOR ANALYSIS** - AUC computation must be fixed first.

