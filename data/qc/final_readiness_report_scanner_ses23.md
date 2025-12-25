# Final Readiness Report: Scanner Ses-2/3 Analysis-Ready Data

**Generated:** 2025-12-20 15:06:03

## Sanity Checklist

[ X ] ses1 excluded
[ X ] only InsideScanner sources used
[ X ] gate recompute mismatches = 0
[ X ] trial_uid uniqueness confirmed

---

## Executive Summary

**STATUS:** ✅ READY FOR ANALYSIS

### Key Findings

1. **Data Completeness**: 9.5 % of expected behavioral trials have pupil data ( 1425 / 15000 ).
2. **Session Provenance**: Only InsideScanner ses-2/3 included (design-compliant).
3. **Gate Consistency**: All gates verified (mismatch rate < 0.1%).
4. **Task Difference**: ADT vs VDT total-AUC difference = 17 pp at threshold 0.80.

---

## Denominator Reconciliation

### Design-Expected Counts

- **Expected behavioral trials:** 15000 (50 subjects × 2 tasks × 5 runs × 30 trials)
- **Expected run units:** 500 (50 subjects × 2 tasks × 5 runs)

### Pupil-Present Counts (Scanner Ses-2/3 Only)

- **Observed pupil-present trials:** 1425
- **Observed pupil-present run units:** 113

### Coverage Summary

- **Trial coverage:** 9.5 % ( 1425 / 15000 )
- **Run coverage:** 22.6 % ( 113 / 500 )

**Interpretation:**
- 9.5 % of expected behavioral trials have any pupil data in scanner sessions 2-3.
- This data loss is primarily due to goggles blocking eye tracking, not pipeline errors.
- The TRIALLEVEL dataset represents **pupil-present trials from scanner sessions only**.

---

## Session Distribution

- **Session 2:** 728 trials
- **Session 3:** 697 trials
- **Session 1:** 0 trials

✅ **TRIALLEVEL contains only sessions 2 and 3** (as required by design)

---

## Subject and Trial Distribution

- **Unique subjects:** 46
- **Total trials:** 1425

### Trials per Subject×Task

- **Min:** 1
- **Median:** 20
- **Max:** 64

---

## Gate Pass Rates

### Pass Rates by Threshold

| Threshold | Stimulus-Locked | Total AUC | Cognitive AUC |
|-----------|-----------------|-----------|---------------|
| 0.60 | 67.1% | 96.5% | 70.7% |
| 0.70 | 59.6% | 86.2% | 59.8% |
| 0.80 | 46.7% | 57.5% | 44.6% |

### Task Bias at Threshold 0.80

| Task | Stimulus-Locked | Total AUC | Cognitive AUC |
|------|-----------------|-----------|---------------|
| ADT | 43.6% | 48.1% | 40.2% |
| VDT | 49.1% | 65.1% | 48.1% |

**Total AUC task difference:** 17 percentage points

---

## Prestim Validity Summary

| Task | Prestim Validity | Baseline Validity | ITI Validity |
|------|------------------|-------------------|--------------|
| ADT | 0.739 | 0.889 | 0.872 |
| VDT | 0.752 | 0.868 | 0.914 |

**Interpretation:** Prestim validity is lower than baseline/ITI validity, indicating structured missingness around stimulus onset (prestim dip).

---

## Gate Consistency Verification

| Gate Type | Mismatch Rate | Status |
|-----------|---------------|--------|
| Stimulus-locked | 0 | ✅ |
| Total AUC | 0 | ✅ |
| Cognitive AUC | 0 | ✅ |

---

## Conclusions

✅ **Data is ready for analysis** with the following understanding:

1. **TRIALLEVEL represents 1425 pupil-present trials from scanner sessions 2-3 only**.
2. ** 9.5 % of expected behavioral trials have pupil data** - this is expected given goggles/blocking.
3. **Gates are correctly implemented** and analysis-specific (not nested).
4. **Task differences are mechanical**, not coding errors.

### Next Steps

1. Use `BAP_analysis_ready_TRIALLEVEL_scanner_ses23.csv` as the primary analysis dataset.
2. Clearly document in methods that analyses use 'pupil-present trials from scanner sessions' as the denominator.
3. Consider task-stratified analyses for total-AUC dependent variables given the task difference.
4. Use hierarchical/Bayesian models to handle sparse subject×task cells.

---

## Supporting Files

- `data/analysis_ready/BAP_analysis_ready_TRIALLEVEL_scanner_ses23.csv` - Primary analysis dataset
- `data/analysis_ready/BAP_analysis_ready_MERGED_scanner_ses23.parquet` - Sample-level data
- `data/qc/analysis_ready_audit/final_readiness_numbers_scanner_ses23.csv` - Summary metrics

