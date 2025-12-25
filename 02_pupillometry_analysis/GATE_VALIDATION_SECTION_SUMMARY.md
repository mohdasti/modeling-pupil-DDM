# Gate Validation & Coverage Audit Section - Implementation Summary

## Overview

A comprehensive validation section has been added to `generate_pupil_data_report.qmd` that provides rigorous validation of the gate system with multiple diagnostic outputs.

## Location

**File**: `02_pupillometry_analysis/generate_pupil_data_report.qmd`  
**Section**: "Gate Validation & Coverage Audit" (added at end of file, ~line 5681)  
**Code Chunk**: `gate-validation-audit` (results='asis', echo=FALSE)

## Components Implemented

### A) Trial-Level Counts Per Threshold

**Output**: `data/qc/gate_trial_counts_validation.csv`

**Columns**:
- `threshold`: Quality threshold (0.50, 0.60, 0.70, 0.80, 0.90, 0.95)
- `N_total_trials`: Total unique trials (using `n_distinct(trial_uid)`)
- `N_gate_stimlocked`: Trials passing stimulus-locked gate
- `N_gate_total_auc`: Trials passing total-AUC gate
- `N_gate_cog_auc`: Trials passing cognitive-AUC gate

**Validation**: Uses `n_distinct(trial_uid)` to ensure accurate trial-level counting (not sample-level)

### B) Overlap Matrix Per Threshold

**Output**: `data/qc/gate_overlap_matrix.csv`

**Columns**:
- `threshold`: Quality threshold
- `size_S`, `size_T`, `size_C`: Set sizes for each gate
- `size_S_inter_T`, `size_S_inter_C`, `size_T_inter_C`: Pairwise intersections
- `size_S_inter_T_inter_C`: Triple intersection
- `prop_S_inter_T`, `prop_S_inter_C`, `prop_T_inter_C`: Intersection proportions
- `J_S_T`, `J_S_C`, `J_T_C`: Jaccard indices

**Visualization**: 
- Table display in report
- Heatmap: `figures/gate_jaccard_heatmap.png`

**Note**: Emphasizes that gates are independent (not nested), overlaps are informational

### C) Subject-Level Diagnostics

**Output**: `data/qc/gate_subject_diagnostics.csv`

**Columns**:
- `subject_id`, `task`, `threshold`
- `n_trials_total`: Total trials per subject-task
- `n_gate_stimlocked`, `n_gate_total_auc`, `n_gate_cog_auc`: Counts per gate
- `pass_rate_S`, `pass_rate_T`, `pass_rate_C`: Pass rates (0-1)

**Analyses**:
1. **Worst 10 subjects per gate** (at threshold 0.80):
   - Tables showing subjects with lowest pass rates
   - Separate tables for each gate

2. **Pass rate correlations**:
   - Correlation matrix: Stim-locked vs Total-AUC, Stim-locked vs Cog-AUC, Total-AUC vs Cog-AUC
   - Scatter plot: `figures/gate_pass_rate_correlation.png`
   - Focus on Stim-locked vs Cog-AUC correlation (most relevant for prestim dip analysis)

### D) Event-Locked Invalidity Stratified by Gate

**Output**: `data/qc/event_invalidity_stratified_by_gate.csv`

**Purpose**: Test if prestim dip is boundary-related (blinks at fixation onset/offset)

**Method**:
- Loads `data/qc/event_locked_invalidity.csv` (if available)
- Merges with gate status at threshold 0.80
- Computes invalidity curves separately for:
  - Trials that PASS `gate_stimlocked`
  - Trials that FAIL `gate_stimlocked`

**Visualization**: 
- Plot: `figures/event_invalidity_stratified_by_gate.png`
- Focuses on fixation onset event (most relevant for prestim window)
- If prestim dip is boundary-related, failing trials should show peaks at t=0 (fixation onset)

**Note**: Gracefully handles missing event invalidity data

### E) Unit of Counting Validation

**Checks**:

1. **Trial UID Uniqueness**:
   - Compares `n_distinct(trial_uid)` vs `nrow(trial_coverage_prefilter)`
   - ✓ PASS if equal (no duplicates)
   - ⚠ WARNING if duplicates found (shows examples)
   - **Assertion**: Stops execution if duplicates found

2. **Count Sanity Check**:
   - Computes max trials per subject-task
   - ✓ PASS if < 10,000 (expected range)
   - ⚠ CAUTION if 10,000-100,000
   - ⚠ WARNING if > 100,000 (suggests sample-level data)

**Purpose**: Ensures all summaries are based on trial-level data, not sample-level

## Validation Summary Table

At the end of the section, a summary table displays:

| Check | Status | Output File |
|-------|--------|-------------|
| Trial UID Uniqueness | ✓ PASS / ✗ FAIL | N/A |
| Count Sanity (max < 10k) | ✓ PASS / ⚠ WARNING | N/A |
| Trial Counts Generated | ✓ PASS / ✗ FAIL | `gate_trial_counts_validation.csv` |
| Overlap Matrix Generated | ✓ PASS / ✗ FAIL | `gate_overlap_matrix.csv` |
| Subject Diagnostics Generated | ✓ PASS / ✗ FAIL | `gate_subject_diagnostics.csv` |
| Event Invalidity Stratified | ✓ PASS / ⚠ SKIPPED | `event_invalidity_stratified_by_gate.csv` |

## Generated Files

All files are saved to `data/qc/` or `figures/` directories:

**CSV Files** (in `data/qc/`):
1. `gate_trial_counts_validation.csv` - Trial-level counts per threshold
2. `gate_overlap_matrix.csv` - Overlap matrix with Jaccard indices
3. `gate_subject_diagnostics.csv` - Subject-level pass rates
4. `event_invalidity_stratified_by_gate.csv` - Event invalidity stratified by gate status

**Plot Files** (in `figures/`):
1. `gate_jaccard_heatmap.png` - Jaccard index heatmap
2. `gate_pass_rate_correlation.png` - Pass rate correlation scatter plot
3. `event_invalidity_stratified_by_gate.png` - Event invalidity curves by gate status

## Key Features

1. **Rigorous Counting**: All counts use `n_distinct(trial_uid)` to ensure trial-level accuracy
2. **Comprehensive Validation**: Multiple checks ensure data integrity
3. **Graceful Degradation**: Handles missing data gracefully (e.g., event invalidity)
4. **Clear Outputs**: Both CSV files and visualizations for easy inspection
5. **Assertions**: Stops execution if critical validation fails (duplicate trial_uid)

## Usage

The section runs automatically when the Quarto report is rendered, provided:
- `trial_coverage_prefilter` is available
- `threshold_sweep` is available
- `qc_dir` and `figures_dir` are defined

All outputs are saved and displayed in the rendered report, providing a complete validation audit trail.



