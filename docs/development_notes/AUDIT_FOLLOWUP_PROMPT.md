# Follow-Up Prompt for Audit Reports: Clarifications and Data Context

**Purpose**: Provide additional context and clarifications to improve audit report accuracy

---

## CONTEXT: ACTUAL PIPELINE ARCHITECTURE

The audit reports made several valid points, but some recommendations were based on assumptions about the pipeline structure. This document provides the actual implementation details to enable more accurate recommendations.

### Pipeline Structure

The preprocessing pipeline has **TWO STAGES**:

1. **STAGE 1: ET-remove-artifacts Toolbox** (Huang et al., 2020)
   - This is where blink detection and interpolation actually occur
   - Uses velocity-based detection (NOT zero-based)
   - Configuration: 100th-order low-pass filter (passband: 10 Hz, stopband: 12 Hz), peak/trough threshold = 5 SD
   - Manual inspection/editing is performed using the toolbox's interactive editor
   - Output: "Cleaned" `.mat` files stored in `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned/`

2. **STAGE 2: MATLAB Pipeline** (`BAP_Pupillometry_Pipeline.m`)
   - Reads the cleaned `.mat` files from Stage 1
   - Performs trial alignment, phase labeling, and downsampling
   - Outputs flat CSV files for R analysis

**CRITICAL POINT**: The audit reports focused on Stage 2, but many concerns (blink detection, interpolation) actually occur in Stage 1, which the reports did not have access to.

---

## CLARIFICATIONS NEEDED

### 1. INTERPOLATION SETTINGS (HIGH PRIORITY)

**Audit Report Claim**: "1000ms interpolation windows effectively fabricate cognitive data"

**Actual Situation**:
- The MATLAB pipeline (`BAP_Pupillometry_Pipeline.m`) does NOT contain interpolation code
- Interpolation is handled by the **ET-remove-artifacts toolbox** during Stage 1
- Documentation states: "Artifacts exceeding 2 seconds in duration were replaced with missing values rather than interpolated"
- Manual editing is performed using the toolbox's interactive editor, but we don't have the exact interpolation settings

**Questions for Audit Reports**:
1. Where did the "1000ms interpolation window" claim come from? Was this inferred from the data or assumed?
2. If interpolation happens in ET-remove-artifacts toolbox (not visible in our code), how should we verify/fix this?
3. What is the recommended maximum interpolation window for pupillometry data? (Literature suggests 200-500ms max)

**Data Evidence**:
- Processed data shows 9-25% zero values across files
- These zeros may represent:
  - Failed blink detection (should have been interpolated)
  - Intentional missing data markers (should be handled)
  - Valid exclusions (should be excluded from analysis)

**Request**: Please clarify how to handle zeros in processed data and what interpolation settings are appropriate for the ET-remove-artifacts toolbox.

---

### 2. DOWNSAMPLING ANTI-ALIASING (MEDIUM PRIORITY)

**Audit Report Claim**: "Omission of anti-aliasing filters prior to decimation introduces high-frequency noise artifacts"

**Actual Situation**:
- **MATLAB Code** (`BAP_Pupillometry_Pipeline.m`, line 450): Uses `downsample(trial_pupil, downsample_factor)` - **NO visible anti-aliasing filter**
- **Documentation** (`PUPIL_PREPROCESSING_METHODS.md`): Claims "8th-order anti-aliasing filter" is used
- **Python Alternative** (`downsample_and_process.py`): Uses `scipy.signal.decimate(data, factor, n=8)` - **DOES include anti-aliasing**

**Discrepancy**:
- MATLAB's `downsample()` function does NOT apply anti-aliasing by default
- The documentation claims an 8th-order filter is used, but it's not visible in the code
- Possible explanations:
  1. The filter is applied in ET-remove-artifacts toolbox (Stage 1) before the pipeline
  2. The documentation is incorrect
  3. The code needs to be fixed

**Questions for Audit Reports**:
1. Should we replace `downsample()` with `resample()` or `decimate()` in MATLAB?
2. If filtering happens in Stage 1 (ET-remove-artifacts), is additional filtering needed in Stage 2?
3. What is the recommended anti-aliasing filter specification for 2000 Hz → 250 Hz downsampling?

**Request**: Please provide specific MATLAB code recommendations for proper anti-aliasing during downsampling.

---

### 3. BLINK DETECTION METHOD (MEDIUM PRIORITY)

**Audit Report Claim**: "Relying on zero-values fails to detect the 'penumbra' of blinks"

**Actual Situation**:
- The pipeline uses **ET-remove-artifacts toolbox** with **velocity-based detection** (NOT zero-based)
- Configuration: 100th-order low-pass filter, peak/trough threshold = 5 SD
- However, processed data contains **9-25% zero values**, which is concerning

**Questions for Audit Reports**:
1. If the toolbox uses velocity-based detection, why are there so many zeros in the processed data?
2. Are zeros intentional missing data markers that should be interpolated?
3. Should we add additional blink detection in Stage 2 to catch missed blinks?
4. What is the recommended approach for handling zeros in processed data?

**Data Evidence**:
```
File                    Zero %    Mean Quality
BAP003_ADT             11.3%     0.890
BAP003_VDT             24.7%     0.758
BAP101_ADT             11.8%     0.883
BAP102_ADT             12.1%     0.869
BAP102_VDT              9.3%     0.903
```

**Request**: Please clarify how to handle zeros in processed data and whether additional blink detection is needed.

---

### 4. TRIAL EXCLUSION THRESHOLD (LOW PRIORITY - VALID CONCERN)

**Audit Report Claim**: "50% missing data threshold is scientifically indefensible"

**Actual Situation**:
- Code uses `CONFIG.quality.min_valid_proportion = 0.5` (50% threshold)
- **BUT** actual data quality is quite good:
  - Mean valid % per trial: **82.3%**
  - Trials with <50% valid: **0** (in sample)
  - Trials with <60% valid: **1** (in sample)

**Questions for Audit Reports**:
1. Given that actual data quality is 82% mean valid, is the 50% threshold still problematic?
2. Should we tighten the threshold to 80% (20% missing max) or 85% (15% missing max)?
3. What is the recommended threshold for pupillometry data? (Winn et al., 2018 suggests 15-20% missing max)

**Request**: Please confirm the recommended threshold and whether current data quality (82% mean valid) is acceptable.

---

### 5. POSITION-BASED MERGING (HIGH PRIORITY - VALID CONCERN)

**Audit Report Claim**: "Row-index matching creates high risk of desynchronization"

**Actual Situation**:
- ✅ **CONFIRMED**: The R merger script uses position-based matching within runs
- Code: `trial_position_in_run = row_number()` then `left_join(..., by = c("run", "trial_position_in_run"))`
- Behavioral data has trial numbers, but they're not used for matching

**Questions for Audit Reports**:
1. Should we match using behavioral trial numbers instead of position?
2. How should we handle cases where trial numbers don't match (e.g., skipped trials)?
3. What validation checks should we add to verify merge accuracy?

**Request**: Please provide specific code recommendations for implementing unique identifier matching.

---

## ACTUAL DATA QUALITY METRICS

To provide context, here are the actual data quality metrics from processed files:

### Overall Quality (Sample: BAP003_ADT, 50,000 samples)
- **Zero values**: 11.3% (5,622 out of 50,000)
- **Baseline quality**: Mean 0.90 (Range: 0.73-1.00)
- **Trial quality**: Mean 0.82 (Range: 0.62-0.94)
- **Overall quality**: Mean 0.83 (Range: 0.70-0.95)
- **Mean valid % per trial**: 82.3%
- **Trials with <50% valid**: 0
- **Trials with <60% valid**: 1
- **Trials with <70% valid**: 1

### Multi-File Summary
```
File                    Zero %    Mean Quality    Trials
BAP003_ADT             11.3%     0.890           3
BAP003_VDT             24.7%     0.758           3
BAP101_ADT             11.8%     0.883           3
BAP102_ADT             12.1%     0.869           3
BAP102_VDT              9.3%     0.903           3
```

**Key Observations**:
1. Data quality is actually quite good (82% mean valid per trial)
2. Zero percentage varies significantly (9-25%), suggesting inconsistent cleaning
3. Quality metrics are reasonable but could be improved

---

## REQUESTED REVISIONS TO AUDIT REPORTS

Given the above clarifications, please provide:

1. **Specific code fixes** for:
   - Position-based merging (with example R code)
   - Downsampling anti-aliasing (with example MATLAB code)
   - Zero value handling (with example R/MATLAB code)

2. **Clarifications on**:
   - Interpolation settings in ET-remove-artifacts toolbox
   - Recommended maximum interpolation window
   - How to handle zeros in processed data

3. **Revised recommendations** that account for:
   - Two-stage pipeline architecture (ET-remove-artifacts → MATLAB pipeline)
   - Actual data quality (82% mean valid is actually good)
   - Manual editing procedures

4. **Priority ranking** of issues:
   - Which issues are most critical given actual data quality?
   - Which issues can be addressed in Stage 1 vs Stage 2?
   - What is the expected impact on valid trial rates after fixes?

---

## FILES FOR REFERENCE

1. **MATLAB Pipeline**: `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m`
2. **R Merger Script**: `01_data_preprocessing/r/Create merged flat file.R`
3. **Documentation**: `PUPIL_PREPROCESSING_METHODS.md`
4. **Sample Data**: `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/BAP003_ADT_flat_merged.csv`

---

## EXPECTED OUTPUT FORMAT

Please provide:

1. **Revised audit report** with:
   - Updated findings based on actual pipeline structure
   - Specific code recommendations for each issue
   - Priority ranking of fixes
   - Expected impact on valid trial rates

2. **Code snippets** showing:
   - Current problematic code (with line numbers)
   - Recommended replacement code
   - Brief explanation of changes

3. **Clarifications** on:
   - Interpolation settings
   - Zero value handling
   - Anti-aliasing filter specifications

Thank you for your thorough review. This additional context should enable more accurate and actionable recommendations.









