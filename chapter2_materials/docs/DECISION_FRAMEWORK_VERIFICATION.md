# Decision Framework Verification

**Date**: January 2026  
**Purpose**: Verify that the decision framework and exclusion rules are properly implemented in `chapter2_materials/`

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

### 4. RT-Normalized Metrics
- **Status**: ⚠️ **Computed in Report, Not in CSV**
- **Current**: `cog_mean` is computed in `pupil_data_report_advisor.qmd` R chunks
- **Recommendation**: Compute `cog_mean = cog_auc / cog_window_duration` in your analysis scripts
- **Note**: Current implementation uses fixed short window (~0.05s), so RT-normalization may have limited utility until RT-dependent windows are implemented

---

## ⚠️ **PARTIALLY IMPLEMENTED / NOT APPLICABLE**

### 1. Window Duration Threshold (cog_window_duration >= 0.5s)
- **Status**: ⚠️ **Not Applicable with Current Implementation**
- **Reason**: Current implementation uses fixed short window (4.65s to 4.70s = ~0.05s)
- **Actual Values**: All `gate_pupil_primary` trials have `cog_window_duration` ~0.05s (median: 0.049s)
- **Framework Expectation**: RT-dependent window (4.65s to 4.70s + RT), which would yield 0.5s+ for most trials
- **Recommendation**: This threshold is documented for future use when RT-dependent windows are implemented

### 2. Valid Samples Threshold (cog_auc_n_valid >= 100)
- **Status**: ⚠️ **Not Applicable with Current Implementation**
- **Reason**: Current implementation uses fixed short window (~0.05s)
- **Actual Values**: All `gate_pupil_primary` trials have `cog_auc_n_valid` ~10-15 samples (median: 15)
- **Framework Expectation**: RT-dependent window would yield 100+ samples for most trials
- **Recommendation**: This threshold is documented for future use when RT-dependent windows are implemented

---

## 📋 **DECISION FRAMEWORK SUMMARY**

### Current Implementation (What Works Now):

**Primary Exclusion Rule**:
```r
ch2_primary <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,           # B1_quality >= 0.50 & cog_quality >= 0.60
    is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 250  # Gap-aware exclusion
  )
```

**Result**: 4,448 trials (30.5% of all trials)

### Framework (For Future RT-Dependent Windows):

**Primary (Strict)**:
```r
ch2_primary <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,           # B1_quality >= 0.50 & cog_quality >= 0.60
    is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 250,
    is.na(cog_window_duration) | cog_window_duration >= 0.5,  # Future use
    is.na(cog_auc_n_valid) | cog_auc_n_valid >= 100          # Future use
  )
```

**Sensitivity (Moderate)**:
```r
ch2_moderate <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 250,
    is.na(cog_window_duration) | cog_window_duration >= 0.3    # Future use
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
3. **For Window Duration/n_valid Thresholds**: These are documented for future use when RT-dependent windows are implemented
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

**Conclusion**: The decision framework is **properly documented and implemented** for the metrics that are applicable with the current fixed-window implementation. Window duration and n_valid thresholds are documented for future use when RT-dependent windows are implemented.
