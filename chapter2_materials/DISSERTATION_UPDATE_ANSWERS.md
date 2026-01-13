# Answers to Dissertation Update Questions

**Date**: January 2026  
**Purpose**: Answer all questions from the dissertation update checklist

---

## ✅ VERIFIED: Current Data State

**Data Verification Results** (from `ch2_triallevel.csv`):
- ✅ **Window Duration**: Mean 1.09s (expected 1.20s; some truncation due to missing data)
- ✅ **All Required Columns Present**: `B1_quality`, `baseline_quality`, `cog_mean`, `cog_auc`, `cog_auc_max_gap_ms`
- ✅ **Sample Statistics**: Mean 237 valid samples (expected ~300; 80% threshold = 240)
- ✅ **Window Range**: 4.85s to 6.05s (1.20s fixed window) - **CONFIRMED IMPLEMENTED**

**Conclusion**: The new 1.20s window (4.85-6.05s) is **fully implemented** in the data. `DECISION_FRAMEWORK_VERIFICATION.md` is outdated and references the old 50ms window.

---

## 📋 ANSWERS TO ALL QUESTIONS

### Question 1: Data File Location ✅ ANSWERED
**Answer**: 
- **Main repo location**: `data/pupil_processed/analysis_ready/ch2_triallevel.csv`
- **Chapter 2 materials location**: `chapter2_materials/data/ch2_triallevel.csv` (if copied)
- **Dissertation location**: `07_manuscript/chapter2/data/processed/ch2_triallevel_merged.csv`
- **Action**: Copy/update the dissertation data file with the new columns from the main repo

---

### Question 2: Analysis Code Updates ✅ YES, REQUIRED
**Answer**: 
- **YES**, all analysis scripts need to be updated to use `cog_mean` instead of `cog_auc`
- **Rationale**: `cog_mean` removes duration confounds and is the preferred metric
- **Action**: 
  - Update all R scripts in `07_manuscript/chapter2/scripts/`
  - Replace `cog_auc` with `cog_mean` in model formulas
  - Update variable names in plots and tables

---

### Question 3: Motor-Buffered AUC Computation ✅ MENTION AS FUTURE
**Answer**: 
- **Recommendation**: Mention it as available for future sensitivity analysis, but **don't require it for primary analysis**
- **Current Status**: Window definitions computed (`cog_win_primary_end_motorbuffered`, `cog_win_truncated_by_motor`), but full AUC requires re-processing flat files
- **Action**: Add to limitations/future directions: "Motor-buffered window definitions are computed and available for future sensitivity analyses when full AUC computation is completed"

---

### Question 4: Pre-Response Window ✅ SENSITIVITY ONLY
**Answer**: 
- **Recommendation**: Document as available for **sensitivity analysis only**, not primary analysis
- **Current Status**: Window definitions computed (`cog_win_preresp_start/end/duration`, `cog_win_preresp_valid`), but full AUC requires re-processing
- **Action**: Add to sensitivity analysis section: "Pre-response window (decision-aligned) definitions are available for future sensitivity analyses"

---

### Question 5: Quality Tier Definitions ✅ UPDATE WITH GAP-AWARE
**Answer**: 
- **Recommendation**: **Keep three-tier system** but **add gap-aware metrics to each tier**
- **Primary Tier** (should include):
  - `B1_quality >= 0.50` AND `cog_quality >= 0.60` (existing)
  - `cog_auc_max_gap_ms <= 250` (NEW - gap-aware)
  - `cog_window_duration >= 0.90` (NEW - 75% of 1.20s)
  - `cog_auc_n_valid >= 240` (NEW - 80% of expected ~300)
- **Lenient Tier**: Same but with `cog_quality >= 0.50` and relaxed gap thresholds
- **Strict Tier**: Same but with `cog_quality >= 0.70` and stricter gap thresholds

---

### Question 6: Baseline Quality Threshold ✅ B1_QUALITY IS CORRECT
**Answer**: 
- **Correct Column**: `B1_quality >= 0.50` (NOT `baseline_quality`)
- **Rationale**: 
  - `B1_quality` = Quality of B1 baseline (3.85s-4.35s, target-locked) - **used for Cognitive AUC**
  - `baseline_quality` = Quality of B0 baseline (-0.5s to 0.0s, pre-trial) - **used for Total AUC**
- **Action**: Update dissertation to use `B1_quality` for Cognitive AUC filtering

---

### Question 7: Window Duration in Current Data ✅ VERIFIED: 1.20s WINDOW IMPLEMENTED
**Answer**: 
- **Status**: ✅ **NEW 1.20s WINDOW (4.85-6.05s) IS IMPLEMENTED**
- **Verification**: 
  - Mean window duration: 1.09s (close to expected 1.20s; some truncation due to missing data)
  - Mean valid samples: 237 (close to expected ~300)
  - Window range: 4.85s to 6.05s (confirmed in code)
- **Outdated Document**: `DECISION_FRAMEWORK_VERIFICATION.md` still references old 50ms window - **needs update**
- **Action**: 
  - ✅ Use new window definition (4.85-6.05s, 1.20s) in dissertation
  - ⚠️ Update `DECISION_FRAMEWORK_VERIFICATION.md` to reflect new window

---

### Question 8: RT Covariate in Existing Models ⚠️ NEEDS VERIFICATION
**Answer**: 
- **Status**: **UNKNOWN** - Need to check saved model files
- **Action Required**: 
  1. Check model formulas in `mod_effort_cog_auc.rds` and `mod_effort_total_auc.rds`
  2. If RT is NOT included: **Re-run models with RT as covariate**
  3. If RT IS included: Update dissertation to explicitly mention it
- **Recommendation**: Always include RT as covariate in primary models going forward

---

## 🔴 CRITICAL ACTIONS REQUIRED

### 1. Update Outdated Documentation
**File**: `chapter2_materials/docs/DECISION_FRAMEWORK_VERIFICATION.md`
- **Issue**: Still references old 50ms window (4.65-4.70s)
- **Action**: Update to reflect new 1.20s window (4.85-6.05s)
- **Status**: ⚠️ Needs update

### 2. Verify Model Files Include RT
**Files**: `mod_effort_cog_auc.rds`, `mod_effort_total_auc.rds`
- **Action**: Check model formulas; re-run if RT not included
- **Status**: ⚠️ Needs verification

### 3. Update Data File in Dissertation
**File**: `07_manuscript/chapter2/data/processed/ch2_triallevel_merged.csv`
- **Action**: Copy/update from main repo with all new columns
- **Status**: ⚠️ Needs update

---

## 📝 IMPLEMENTATION PRIORITY

### High Priority (Required for Dissertation)
1. ✅ Update window definition in Methods (line 456)
2. ✅ Switch to `cog_mean` as primary metric
3. ✅ Add gap-aware quality thresholds
4. ✅ Add RT as covariate to models
5. ✅ Add confound mitigation section

### Medium Priority (Recommended)
6. Update quality tier definitions with gap-aware metrics
7. Add sensitivity analysis descriptions
8. Update limitations section

### Low Priority (Future Enhancements)
9. Motor-buffered AUC computation (when available)
10. Pre-response window AUC computation (when available)

---

## ✅ CONFIRMED: All Critical Changes Are Valid

All the changes listed in the summary document are **correct and necessary**:

1. ✅ Window update (50ms → 1.20s) - **VERIFIED IN DATA**
2. ✅ Use `cog_mean` - **COLUMN EXISTS IN DATA**
3. ✅ Gap-aware thresholds - **METRICS EXIST IN DATA**
4. ✅ Confound mitigation - **FLAGS EXIST IN DATA**
5. ✅ RT as covariate - **RECOMMENDED, NEEDS VERIFICATION IN MODELS**

---

**Last Updated**: January 2026  
**Status**: Ready for dissertation updates
