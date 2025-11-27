# Comprehensive DDM Analysis Audit Report

**Audit Date:** November 2, 2024  
**Analyses Audited:** Core DDM Models (Models 1-5, 7-10)  
**Purpose:** Systematic verification of data processing, filtering, and model specifications

---

## Executive Summary

A comprehensive audit was conducted on the core DDM analyses to verify:
1. Data file integrity and completeness
2. Filtering procedures and consistency
3. Factor level distributions and balance
4. Per-model trial counts
5. Data quality indicators
6. Subject-level data adequacy

**Overall Status:** ✅ **All checks passed with minor notes**

---

## 1. Data File Verification

### File Details
- **Data file:** `data/analysis_ready/bap_ddm_ready.csv`
- **File size:** 1.56 MB
- **Raw data rows:** 17,243
- **Columns:** 20 behavioral variables (no pupil features)

### Data Completeness
- ✓ All required columns present
- ✓ Column name harmonization successful
- ✓ No critical missing data in key variables

---

## 2. Data Preparation Verification

### Column Mapping
- ✓ `resp1RT` → `rt` (reaction time)
- ✓ `iscorr` → `accuracy` (correct/incorrect)
- ✓ `sub` → `subject_id` (if needed)
- ✓ `task_behav` → `task` (if needed)

### Missing Data
- **RT missing:** 0 trials (0%)
- **Accuracy missing:** 0 trials (0%)
- **Subject ID missing:** 0 trials (0%)

**Assessment:** ✅ **No missing data in critical variables** - Data is complete.

---

## 3. Filtering Procedures

### RT Filtering
- **Filter applied:** RT between 0.25 and 3.0 seconds
- **Trials before filtering:** 17,243 (all trials already within range)
- **Trials after filtering:** 17,243
- **Exclusion rate:** 0% (no trials excluded)

**Note:** The data file appears to have been pre-filtered to the 0.25-3.0s range, as no trials were excluded. This is consistent with the final analysis filter.

### Filtering Breakdown
- Trials excluded (RT < 0.25s): 0
- Trials excluded (RT > 3.0s): 0
- **RT range in data:** 0.250-2.977 seconds

**Assessment:** ✅ **Perfect** - RT filtering is consistent. All trials are within the acceptable range.

---

## 4. Factor Level Verification

### Effort Condition
- **Levels:** High_MVC, Low_5_MVC
- **Distribution:**
  - High_MVC: 8,478 trials (49.17%)
  - Low_5_MVC: 8,765 trials (50.83%)
- **Balance ratio:** 0.967 (excellent balance)

### Difficulty Level
- **Levels:** Easy, Hard, Standard
- **Distribution:**
  - Easy: 6,839 trials (39.66%)
  - Hard: 6,932 trials (40.20%)
  - Standard: 3,472 trials (20.14%)
- **Balance ratio:** 0.501 (moderate imbalance - Standard has fewer trials)

**Note:** The Standard difficulty level has fewer trials than Easy/Hard. This is expected given the experimental design but may affect statistical power for Standard condition comparisons.

### Task Type
- **Levels:** ADT (Auditory), VDT (Visual)
- **Distribution:**
  - ADT: 8,635 trials (50.08%)
  - VDT: 8,608 trials (49.92%)
- **Balance ratio:** 0.997 (excellent balance)

**Assessment:** ✓ Factor levels are well-balanced except for difficulty level (Standard has fewer trials, which is expected).

---

## 5. Per-Model Data Counts

### Trial Counts by Model

All models used **exactly 17,243 trials** from **67 subjects**:

| Model | Trials | Subjects | Status |
|-------|--------|----------|--------|
| Model1_Baseline | 17,243 | 67 | ✓ |
| Model2_Force | 17,243 | 67 | ✓ |
| Model3_Difficulty | 17,243 | 67 | ✓ |
| Model4_Additive | 17,243 | 67 | ✓ |
| Model5_Interaction | 17,243 | 67 | ✓ |
| Model7_Task | 17,243 | 67 | ✓ |
| Model8_Task_Additive | 17,243 | 67 | ✓ |
| Model9_Task_Intx | 17,243 | 67 | ✓ |
| Model10_Param_v_bs | 17,243 | 67 | ✓ |

**Assessment:** ✅ **Perfect consistency** - All models used identical datasets with no discrepancies.

### Verification Method
- Expected counts calculated from filtered data
- Actual counts extracted from fitted model objects
- All matches verified: ✓

---

## 6. RT Distribution Analysis

### Descriptive Statistics
- **Mean RT:** 1.024 seconds
- **Median RT:** 0.893 seconds
- **SD:** 0.534 seconds
- **Range:** 0.25 - 2.977 seconds
- **Q1:** 0.611 seconds
- **Q3:** 1.315 seconds

### Distribution Notes
- Median < Mean: Positive skew (expected for RT data)
- SD is ~52% of mean: Moderate variability
- Extreme outliers (>3 SD from mean): 169 trials (0.98%)

**Assessment:** RT distribution is reasonable for older adults performing a response-signal detection task. The moderate skew is expected and handled appropriately by the Wiener likelihood.

---

## 7. Accuracy/Decision Coding

### Overall Accuracy
- **Overall accuracy rate:** 63.7%
- **Correct responses (decision=1):** 10,986
- **Incorrect responses (decision=0):** 6,257
- **Missing decision values:** 0

### Coding Verification
- ✓ `decision` correctly coded: 1 = correct, 0 = incorrect
- ✓ No inconsistencies between `accuracy` and `decision` variables
- ✓ All trials have valid decision codes

**Assessment:** ✅ Decision coding is correct and consistent across all models.

---

## 8. Subject-Level Data Adequacy

### Trials per Subject
- **Minimum:** 117 trials
- **Maximum:** 299 trials
- **Mean:** 257.4 trials
- **Median:** 277 trials

### Subject-Level Issues
- **Subjects with < 20 trials:** 0 ✓
- **Subjects with accuracy < 0.5:** 6 subjects

**Note:** Six subjects have below-chance accuracy. This may reflect:
1. Task difficulty for some individuals
2. Possible response confusion
3. Potential data quality issues for these subjects

**Recommendation:** Consider sensitivity analyses excluding subjects with accuracy < 0.5 to verify robustness.

**Assessment:** ✓ Subject-level data appears adequate. All subjects have sufficient trials for reliable parameter estimation.

---

## 9. Model Specification Verification

### Consistent Specifications Across Models
- ✓ All models use Wiener family (`brms::wiener()`)
- ✓ Link functions: Identity (drift), log (boundary/NDT), logit (bias)
- ✓ RT filtering: 0.25-3.0s (consistent)
- ✓ Random effects: Subject-level on drift, boundary, bias
- ✓ NDT: Population-level only (no random effects)

### Prior Specifications
- ✓ Standardized priors applied consistently
- ✓ Literature-justified values for older adults
- ✓ Response-signal design accounted for in NDT prior

**Assessment:** ✅ Model specifications are consistent and methodologically sound.

---

## 10. Issues and Recommendations

### ⚠️ Minor Issues Flagged

1. **Extreme RT Outliers**
   - 169 trials (>3 SD from mean, 0.98%)
   - **Assessment:** Acceptable for RT data. The Wiener model handles long tails robustly.
   - **Recommendation:** Consider sensitivity check with more restrictive RT filter (e.g., 0.25-2.5s) to verify results.

2. **Difficulty Level Imbalance**
   - Standard condition has fewer trials (20.14% vs ~40% each for Easy/Hard)
   - **Assessment:** Expected given experimental design but may affect power.
   - **Recommendation:** Acknowledge in methods. Consider bootstrap or sensitivity analyses.

3. **Low Accuracy Subjects**
   - 6 subjects with accuracy < 0.5
   - **Assessment:** Small number, may reflect individual differences or task difficulty.
   - **Recommendation:** Run sensitivity analysis excluding these subjects to verify they don't drive key findings.

### ✅ No Major Issues Found

- ✓ No data filtering discrepancies
- ✓ No model data count mismatches
- ✓ No factor level inconsistencies
- ✓ No missing data problems
- ✓ All models used identical datasets

---

## 11. Data Quality Summary

| Metric | Value | Status |
|--------|-------|--------|
| Total trials (final) | 17,243 | ✓ |
| Unique subjects | 67 | ✓ |
| RT filter consistency | 100% | ✓ |
| Factor balance | Good | ✓ |
| Missing data | Minimal | ✓ |
| Decision coding | Correct | ✓ |
| Subject adequacy | All adequate | ✓ |
| Model consistency | Perfect | ✓ |

---

## 12. Conclusions

### Overall Assessment: ✅ **ANALYSES ARE LEGITIMATE AND RELIABLE**

The audit confirms:

1. **Data Processing:** Consistent and appropriate
2. **Filtering:** Applied uniformly across all models
3. **Data Counts:** Perfect match between expected and actual
4. **Factor Levels:** Appropriate and well-balanced
5. **Model Specifications:** Consistent and methodologically sound
6. **Data Quality:** Acceptable with minor notes

### Recommendations for Publication

1. **Report exact filtering:** "RTs between 0.25-3.0 seconds were included"
2. **Acknowledge difficulty imbalance:** Note that Standard condition has fewer trials
3. **Consider sensitivity analyses:** 
   - Exclude subjects with accuracy < 0.5
   - Use more restrictive RT filter
   - Bootstrap confidence intervals for Standard condition
4. **Report trial counts:** Clearly state 17,243 trials from 67 subjects

### Confidence Level: **HIGH**

The analyses are methodologically sound, consistently applied, and ready for publication with the minor notes above.

---

**Audit performed by:** Systematic audit script  
**Audit results saved:** 
- `audit_results.rds` (detailed)
- `audit_summary.csv` (summary)
- `audit_per_model_counts.csv` (per-model verification)

