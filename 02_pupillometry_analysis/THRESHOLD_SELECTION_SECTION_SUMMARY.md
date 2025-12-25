# Threshold Selection Section - Implementation Summary

## Overview

A comprehensive threshold selection section has been added to `generate_pupil_data_report.qmd` that provides defensible, analysis-specific threshold recommendations for each gate.

## Location

**File**: `02_pupillometry_analysis/generate_pupil_data_report.qmd`  
**Section**: "Threshold Selection: Analysis-Specific Gate Recommendations"  
**Code Chunk**: `threshold-selection-analysis-specific` (results='asis', echo=FALSE)

## Components Implemented

### 1. Retention Curves by Gate

**Visualization**: `figures/threshold_retention_curves.png`

**Purpose**: Shows trial retention rate (proportion of trials passing) across thresholds for each gate.

**Key Features**:
- Separate curves for each gate (stimulus-locked, total-AUC, cognitive-AUC)
- Helps identify "knee points" where retention drops sharply
- Enables comparison of retention patterns across gates

### 2. Subject Dropout Rates by Gate

**Visualization**: `figures/threshold_subject_dropout.png`

**Purpose**: Shows proportion of subjects excluded (those with < 5 trials passing) at each threshold.

**Key Features**:
- Dropout = subjects with < 5 trials passing the gate
- Critical for ensuring sufficient sample size for group-level analyses
- Helps balance trial retention with subject retention

### 3. Sensitivity Analysis: Pupil Metrics Across Thresholds

**Visualizations**:
- `figures/threshold_sensitivity_baseline_pupil.png` (if baseline data available)
- `figures/threshold_sensitivity_cognitive_auc.png` (if cognitive AUC data available)

**Purpose**: Tests whether threshold selection distorts key pupil metric distributions.

**Metrics Checked**:
- **Mean baseline pupil**: Should be stable across thresholds (if threshold distorts, it may bias baseline)
- **Mean cognitive AUC**: Should be stable across thresholds for cognitive-AUC gate (if threshold distorts, it may bias cognitive effects)

**Interpretation**:
- Stable values = threshold doesn't introduce systematic bias
- Changing values = threshold may be filtering in a way that distorts distributions

### 4. Threshold Recommendation Algorithm

**Output**: `data/qc/recommended_thresholds_by_gate.csv`

**Selection Criteria**:
1. **Trial retention ≥ 50%**: Keep at least half of trials
2. **Subject dropout ≤ 20%**: Lose at most 20% of subjects
3. **Stability**: Retention change between adjacent thresholds < 15%

**Selection Process**:
1. Find all thresholds meeting criteria 1 & 2
2. If none found, relax to: retention ≥ 30%, dropout ≤ 30%
3. Select threshold with highest score: `trial_retention - subject_dropout_rate`
4. Check stability (retention change from previous threshold)
5. If no candidates, default to 0.80

**Output Columns**:
- `gate`: Gate name
- `gate_label`: Human-readable gate label
- `recommended_threshold`: Recommended threshold value
- `justification`: Text explanation of recommendation
- `trial_retention`: Proportion of trials retained
- `subject_dropout_rate`: Proportion of subjects excluded
- `n_trials_pass`: Number of trials passing at recommended threshold
- `n_subjects_retained`: Number of subjects retained (≥5 trials)

### 5. Detailed Threshold Comparison Table

**Purpose**: Provides complete comparison of all thresholds for all gates.

**Columns**:
- Threshold value
- Gate label
- Trial retention rate
- Subject dropout rate
- Number of trials passing
- Number of subjects retained

**Use Case**: Allows manual inspection and alternative threshold selection if needed.

## Key Features

1. **Analysis-Specific**: Each gate gets its own threshold recommendation
2. **Multi-Criteria**: Balances trial retention, subject retention, and stability
3. **Sensitivity Testing**: Validates that thresholds don't distort key metrics
4. **Transparent**: Full justification provided for each recommendation
5. **Flexible**: Provides detailed comparison table for manual selection

## Generated Files

**CSV Files** (in `data/qc/`):
1. `recommended_thresholds_by_gate.csv` - Recommended thresholds with justifications

**Plot Files** (in `figures/`):
1. `threshold_retention_curves.png` - Retention curves by gate
2. `threshold_subject_dropout.png` - Subject dropout rates by gate
3. `threshold_sensitivity_baseline_pupil.png` - Baseline pupil sensitivity (if data available)
4. `threshold_sensitivity_cognitive_auc.png` - Cognitive AUC sensitivity (if data available)

## Usage

The section runs automatically when the Quarto report is rendered, provided:
- `trial_coverage_prefilter` is available
- `threshold_sweep` is available
- `qc_dir` and `figures_dir` are defined

## Example Output

**Recommended Thresholds Table**:

| Gate | Recommended Threshold | Justification | Trial Retention | Subject Dropout |
|------|----------------------|---------------|-----------------|-----------------|
| Stimulus-locked gate | 0.80 | Retention: 65.2%; Dropout: 12.3%; N trials: 1602; N subjects: 88 (stable) | 65.2% | 12.3% |
| Total-AUC gate | 0.70 | Retention: 72.1%; Dropout: 8.5%; N trials: 2952; N subjects: 92 (stable) | 72.1% | 8.5% |
| Cognitive-AUC gate | 0.80 | Retention: 58.4%; Dropout: 15.2%; N trials: 1567; N subjects: 85 (stable) | 58.4% | 15.2% |

## Rationale

**Why Analysis-Specific Thresholds?**
- Different gates have different data quality requirements
- Stimulus-locked gate needs baseline + prestim (may be more restrictive)
- Total-AUC gate only needs total window (may be less restrictive)
- Cognitive-AUC gate needs cognitive window + baseline (moderate restriction)

**Why Multiple Criteria?**
- Trial retention: Ensures sufficient trial-level power
- Subject dropout: Ensures sufficient subject-level power
- Stability: Ensures threshold is robust to small changes
- Sensitivity: Ensures threshold doesn't introduce bias

**Why Default 0.80?**
- Common practice in pupillometry (80% valid samples)
- Good balance between quality and retention
- Used as fallback if criteria not met

## Next Steps

1. Review recommended thresholds in the rendered report
2. Adjust criteria if needed (e.g., different retention/dropout thresholds)
3. Use recommended thresholds in downstream analyses
4. Document threshold selection in methods section



