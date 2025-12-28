# Audit Report Validation: ChatGPT & Gemini Reports vs. Actual Implementation

**Date**: December 2025  
**Purpose**: Validate audit report findings against actual code and data

---

## Executive Summary

This document validates the findings from two audit reports (ChatGPT and Gemini) against the actual preprocessing pipeline code and processed data. The validation reveals:

- **3 VALID concerns** requiring immediate attention
- **2 PARTIALLY VALID concerns** with important clarifications needed
- **3 INVALID/MISUNDERSTOOD concerns** based on incorrect assumptions about the pipeline

---

## VALIDATION BY AUDIT FINDING

### 1. POSITION-BASED MERGING (RED FLAG) ✅ **VALID CONCERN**

**Audit Report Claim**: The pipeline uses row-index matching rather than unique identifiers, creating high risk of desynchronization.

**Code Validation**:
- **File**: `01_data_preprocessing/r/Create merged flat file.R` (lines 158-175)
- **Actual Implementation**:
  ```r
  matched_trials <- pupil_subset %>%
      group_by(run) %>%
      mutate(trial_position_in_run = row_number()) %>%
      ungroup()
  
  merge_info <- matched_trials %>%
      left_join(
          behavioral_subset %>%
              group_by(run) %>%
              mutate(trial_position_in_run = row_number()) %>%
              ungroup(),
          by = c("run", "trial_position_in_run"),
          suffix = c("_pupil", "_behav")
      )
  ```

**Validation Result**: ✅ **CONFIRMED** - The code does use position-based matching within runs. This is a valid concern.

**Recommendation**: Implement unique trial identifier matching using event timestamps or trial numbers from behavioral data.

---

### 2. NAIVE DOWNSAMPLING (RED FLAG) ⚠️ **PARTIALLY VALID**

**Audit Report Claim**: The pipeline omits anti-aliasing filters prior to decimation, introducing high-frequency noise artifacts.

**Code Validation**:
- **File**: `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m` (lines 447-456)
- **Actual Implementation**:
  ```matlab
  if CONFIG.original_fs ~= CONFIG.target_fs
      downsample_factor = round(CONFIG.original_fs / CONFIG.target_fs);
      trial_pupil_ds = downsample(trial_pupil, downsample_factor);  % Simple downsample, no filter visible
  ```

- **Documentation Claim** (`PUPIL_PREPROCESSING_METHODS.md`):
  > "downsampled from 2000 Hz to 250 Hz using an 8th-order anti-aliasing filter"

- **Python Alternative** (`01_data_preprocessing/python/downsample_and_process.py`):
  ```python
  downsampled_data = signal.decimate(data, downsample_factor, n=8)  # Includes anti-aliasing
  ```

**Validation Result**: ⚠️ **DISCREPANCY** - The MATLAB code uses simple `downsample()` without visible anti-aliasing filter, but:
1. Documentation claims 8th-order filter is used
2. Python scripts use `scipy.signal.decimate()` with anti-aliasing
3. The audit reports may not have access to the ET-remove-artifacts toolbox configuration, which might apply filtering before the pipeline

**Recommendation**: 
- **IMMEDIATE**: Verify if `downsample()` in MATLAB is actually applying anti-aliasing (MATLAB's `downsample()` does NOT apply anti-aliasing by default)
- **FIX**: Replace with `resample()` or `decimate()` with proper anti-aliasing filter
- **CLARIFICATION NEEDED**: Where exactly is the 8th-order filter applied? Is it in ET-remove-artifacts toolbox?

---

### 3. THRESHOLD-BASED BLINK DETECTION (RED FLAG) ⚠️ **MISUNDERSTOOD**

**Audit Report Claim**: Relying on zero-values fails to detect the "penumbra" of blinks, leaving massive artifactual spikes.

**Code Validation**:
- **File**: `PUPIL_PREPROCESSING_METHODS.md`
- **Actual Implementation**:
  > "Blink artifacts and invalid samples were removed using the ET-remove-artifacts MATLAB toolbox (Huang et al., 2020), which employs a **velocity-based detection algorithm** that identifies blink onsets and offsets by detecting peaks and troughs in the filtered derivative of the pupil signal."

- **Data Validation**:
  - Zero values in processed data: **9-25%** across files (BAP003_ADT: 11.3%, BAP003_VDT: 24.7%, etc.)
  - This suggests blinks were NOT fully cleaned, OR zeros represent valid missing data markers

**Validation Result**: ⚠️ **MISUNDERSTOOD** - The audit reports assume the pipeline uses zero-based blink detection, but:
1. The pipeline uses **ET-remove-artifacts toolbox** with **velocity-based detection**
2. The toolbox is configured with: "100th-order low-pass filter (passband: 10 Hz, stopband: 12 Hz) and peak/trough threshold factors of 5 standard deviations"
3. However, the high percentage of zeros (9-25%) suggests either:
   - Blinks weren't fully cleaned by the toolbox
   - Zeros are valid markers for missing data that should be interpolated
   - The toolbox configuration needs adjustment

**Recommendation**:
- **CLARIFICATION NEEDED**: What does the ET-remove-artifacts toolbox actually output? Are zeros intentional missing data markers or failed blink detection?
- **INVESTIGATION**: Check if zeros should be interpolated or if they represent valid exclusions
- **VALID CONCERN**: The high zero percentage (9-25%) is concerning regardless of detection method

---

### 4. EXCESSIVE INTERPOLATION (RED FLAG) ❓ **NEEDS CLARIFICATION**

**Audit Report Claim**: The allowance of 1000ms interpolation windows effectively fabricates cognitive data over periods of missing input.

**Code Validation**:
- **File**: `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m`
- **Search Results**: No explicit interpolation code found in the pipeline
- **Documentation** (`PUPIL_PREPROCESSING_METHODS.md`):
  > "Artifacts exceeding 2 seconds in duration were replaced with missing values rather than interpolated"
  > "Following automated blink detection, all recordings underwent manual inspection and editing using the toolbox's interactive plot editor to identify and correct any remaining undetected artifacts and ensure proper interpolation across blink events."

**Validation Result**: ❓ **NOT FOUND IN CODE** - The audit reports claim 1000ms interpolation windows, but:
1. No interpolation code is visible in the MATLAB pipeline
2. Interpolation appears to be handled by the **ET-remove-artifacts toolbox** during manual editing
3. The documentation states artifacts >2 seconds are NOT interpolated (replaced with missing values)
4. The audit reports may be referring to the toolbox's default behavior, not the pipeline code

**Recommendation**:
- **CRITICAL CLARIFICATION NEEDED**: What are the actual interpolation settings in ET-remove-artifacts toolbox?
- **INVESTIGATION**: Check the toolbox configuration files or manual editing logs
- **VALID CONCERN IF TRUE**: If 1000ms gaps are being interpolated, this is problematic

---

### 5. LENIENT EXCLUSION CRITERIA (RED FLAG) ✅ **VALID CONCERN**

**Audit Report Claim**: A 50% missing data threshold is scientifically indefensible, retaining trials that lack sufficient physiological grounding.

**Code Validation**:
- **File**: `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m` (line 66)
- **Actual Implementation**:
  ```matlab
  CONFIG.quality.min_valid_proportion = 0.5;   % 50% valid data per trial
  ```
- **Usage** (line 443):
  ```matlab
  if overall_quality < CONFIG.quality.min_valid_proportion
      continue;  % Skip trial
  end
  ```

**Data Validation**:
- Mean valid % per trial: **82.3%** (from BAP003_ADT sample)
- Trials with <50% valid: **0** (from sample)
- Trials with <60% valid: **1** (from sample)
- Trials with <70% valid: **1** (from sample)

**Validation Result**: ✅ **CONFIRMED** - The code does use a 50% threshold, BUT:
1. The actual data shows mean 82% valid per trial, which is actually quite good
2. Very few trials fall below 50% in practice
3. However, the threshold is still lenient compared to literature standards (15-20% missing data recommended by Winn et al., 2018)

**Recommendation**:
- **VALID CONCERN**: 50% threshold is lenient; literature recommends 15-20% missing data maximum
- **PRACTICAL NOTE**: Current data quality is actually good (82% mean valid), but threshold should be tightened for scientific rigor
- **ACTION**: Consider reducing to 0.80 (20% missing max) or 0.85 (15% missing max)

---

## ADDITIONAL FINDINGS NOT IN AUDIT REPORTS

### 6. ZERO VALUES IN PROCESSED DATA ⚠️ **CRITICAL ISSUE**

**Finding**: Processed data contains 9-25% zero values across files.

**Implications**:
- If zeros represent failed blink detection, this is a major quality issue
- If zeros are intentional missing data markers, they should be handled (interpolated or excluded)
- Current pipeline does not appear to handle zeros explicitly

**Recommendation**: **HIGH PRIORITY** - Investigate and address zero values in processed data.

---

## SUMMARY TABLE

| Audit Finding | Status | Priority | Action Required |
|--------------|--------|----------|----------------|
| Position-based merging | ✅ VALID | HIGH | Implement unique identifier matching |
| Naive downsampling | ⚠️ PARTIALLY VALID | MEDIUM | Verify/fix anti-aliasing filter |
| Threshold-based blink detection | ⚠️ MISUNDERSTOOD | MEDIUM | Clarify ET-remove-artifacts output |
| Excessive interpolation | ❓ NEEDS CLARIFICATION | HIGH | Verify toolbox interpolation settings |
| Lenient exclusion criteria | ✅ VALID | MEDIUM | Tighten to 80-85% valid threshold |
| Zero values in data | ⚠️ CRITICAL | HIGH | Investigate and handle zeros |

---

## RECOMMENDATIONS FOR AUDIT REPORTS

The audit reports made several valid points but also made assumptions without access to:
1. **ET-remove-artifacts toolbox configuration** - This is where blink detection and interpolation actually happen
2. **Manual editing procedures** - The documentation mentions manual inspection/editing
3. **Actual data structure** - The reports may not have seen the processed data files

**Next Steps**:
1. Provide audit reports with ET-remove-artifacts toolbox configuration
2. Clarify interpolation settings used during manual editing
3. Show actual data quality metrics (82% mean valid is actually good)
4. Address valid concerns (position-based merging, 50% threshold)
5. Investigate zero values in processed data

---

## FILES REFERENCED

- `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m`
- `01_data_preprocessing/r/Create merged flat file.R`
- `01_data_preprocessing/python/downsample_and_process.py`
- `PUPIL_PREPROCESSING_METHODS.md`
- Processed data: `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/*_flat_merged.csv`









