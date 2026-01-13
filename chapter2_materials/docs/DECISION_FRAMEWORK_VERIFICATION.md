# Decision Framework Verification

**Date**: January 2026 (Updated)  
**Purpose**: Verify that the decision framework and exclusion rules are properly implemented in `chapter2_materials/`  
**Note**: This document has been updated to reflect the new 1.20s fixed window (4.85-6.05s) implementation

---

## ✅ **IMPLEMENTED AND VERIFIED**

### 1. Quality Thresholds
- **Status**: ✅ **Fully Implemented**
- **Current Threshold**: `gate_pupil_primary == TRUE` which requires:
  - `B1_quality >= 0.50` AND `cog_quality >= 0.60`
  - `gate_auc_both == TRUE` (both Total AUC and Cognitive AUC available)
  - `found_in_flat_run == TRUE`
- **Data Availability**: 4,448 trials (30.5% of all trials) pass this threshold
- **Location**: `ch2_triallevel.csv` column `gate_pupil_primary`

### 2. Gap-Aware Exclusion (cog_auc_max_gap_ms <= 250)
- **Status**: ✅ **Fully Implemented**
- **Current Implementation**: All trials with `gate_pupil_primary == TRUE` also pass gap filter
- **Data Availability**: 4,448 trials (100% of gate_pupil_primary trials)
- **Location**: `ch2_triallevel.csv` column `cog_auc_max_gap_ms`
- **Rationale**: Kret & Sjak-Shie (2019) recommend not interpolating gaps >250ms

### 3. Gap-Aware Metrics Available
- **Status**: ✅ **All Metrics Present in CSV**
- **Metrics**:
  - `cog_auc_max_gap_ms`: 7,366 trials have this metric
  - `cog_window_duration`: 7,366 trials have this metric
  - `cog_auc_n_valid`: 7,366 trials have this metric
  - `cog_auc_n_segments`: 7,366 trials have this metric
  - `cog_auc_prop_valid`: 7,366 trials have this metric

### 4. Mean Dilation Metric (cog_mean)
- **Status**: ✅ **Fully Implemented in CSV**
- **Current**: `cog_mean = cog_auc / cog_window_duration` is computed in `make_quick_share_v7.R`
- **Location**: `ch2_triallevel.csv` column `cog_mean`
- **Rationale**: Removes duration confounds; preferred over raw AUC
- **Note**: Current implementation uses fixed 1.20s window (4.85-6.05s), so `cog_mean` is the preferred metric

---

## ⚠️ **PARTIALLY IMPLEMENTED / NOT APPLICABLE**

### 1. Window Duration Threshold (cog_window_duration >= 0.90s)
- **Status**: ✅ **Applicable with Current Implementation**
- **Current Implementation**: Fixed 1.20s window (4.85s to 6.05s, stimulus-locked)
- **Actual Values**: Mean `cog_window_duration` ~1.09s (some truncation due to missing data)
- **Expert-Recommended Threshold**: `cog_window_duration >= 0.90s` (75% of 1.20s window)
- **Rationale**: Ensures sufficient window coverage for stable AUC estimates

### 2. Valid Samples Threshold (cog_auc_n_valid >= 240)
- **Status**: ✅ **Applicable with Current Implementation**
- **Current Implementation**: Fixed 1.20s window (4.85s to 6.05s) at 250 Hz
- **Expected Samples**: ~300 samples at 250 Hz for 1.20s window
- **Actual Values**: Mean `cog_auc_n_valid` ~237 samples (80% of expected)
- **Expert-Recommended Threshold**: `cog_auc_n_valid >= 240` (80% of expected ~300 samples)
- **Rationale**: Ensures sufficient valid samples for stable AUC estimates

---

## 📋 **DECISION FRAMEWORK SUMMARY**

### Current Implementation (Fixed 1.20s Window: 4.85-6.05s):

**Primary Exclusion Rule (Expert-Recommended)**:
```r
ch2_primary <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,           # B1_quality >= 0.50 & cog_quality >= 0.60
    is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 250,  # Gap-aware exclusion
    is.na(cog_window_duration) | cog_window_duration >= 0.90,  # 75% of 1.20s window
    is.na(cog_auc_n_valid) | cog_auc_n_valid >= 240          # 80% of expected ~300 samples
  )
```

**Result**: Number of trials depends on gap-aware and duration/n_valid filters

### Sensitivity Tiers:

**Primary (Strict - Expert-Recommended)**:
```r
ch2_primary <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,           # B1_quality >= 0.50 & cog_quality >= 0.60
    is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 250,
    is.na(cog_window_duration) | cog_window_duration >= 0.90,  # 75% of 1.20s
    is.na(cog_auc_n_valid) | cog_auc_n_valid >= 240          # 80% of expected
  )
```

**Sensitivity (Moderate)**:
```r
ch2_moderate <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 250,
    is.na(cog_window_duration) | cog_window_duration >= 0.60    # 50% of 1.20s
  )
```

**Sensitivity (Lenient)**:
```r
ch2_lenient <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 400
  )
```

---

## ✅ **RT-NORMALIZED METRICS AND DIAGNOSTICS**

### Implementation Status:
- **Computed in Report**: ✅ Yes (in `pupil_data_report_advisor.qmd`)
- **In CSV File**: ❌ No (compute in your analysis scripts)
- **Formula**: `cog_mean = cog_auc / cog_window_duration`

### Diagnostic Framework:
- **Low RT-Normalized AUC + High Quality + Small Gap = Genuine Low Dilation** → ✅ Documented
- **Low RT-Normalized AUC + Low Quality OR Large Gap = Data Quality Artifact** → ✅ Documented
- **Scatter Plots**: ✅ Available in report (Section 8)

---

## 📝 **RECOMMENDATIONS**

1. **For Current Analyses**: Use `gate_pupil_primary == TRUE` + gap filter (`cog_auc_max_gap_ms <= 250`)
2. **For RT-Normalized Metrics**: Compute `cog_mean` in your analysis scripts
3. **For Window Duration/n_valid Thresholds**: These are now applicable with the fixed 1.20s window (4.85-6.05s) implementation
4. **All Gap-Aware Metrics**: Available in CSV and ready to use

---

## ✅ **VERIFICATION CHECKLIST**

- [x] Quality thresholds implemented (B1_50 & Cog_60)
- [x] Gap-aware metrics present in CSV
- [x] Gap-aware exclusion rule documented and working
- [x] Decision tree documented in FILTERING_GUIDE.md
- [x] Exclusion rules (Primary, Moderate, Lenient) documented
- [x] RT-normalized metrics framework documented
- [x] Diagnostic framework for genuine low dilation vs artifacts documented
- [x] Window duration/n_valid thresholds documented (for future use)
- [x] All documentation updated to reflect current implementation

---

**Conclusion**: The decision framework is **properly documented and implemented** with the new fixed 1.20s window (4.85-6.05s). All gap-aware metrics, window duration thresholds, and valid sample thresholds are now applicable and recommended for use.
