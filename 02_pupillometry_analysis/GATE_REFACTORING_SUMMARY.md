# Gate Refactoring Summary (Prompt 1)

## Overview

The gate system has been refactored from nested gates (Gate A/B/C) to independent analysis-specific gates. This allows each analysis type to have its own quality filter without requiring nested dependencies.

## Changes Made

### 1. New Gate System

**Function**: `add_analysis_gates(df, threshold, config = NULL)`

**Location**: `02_pupillometry_analysis/quality_control/build_pupil_trial_coverage_prefilter.R`

**Independent Gates** (NOT nested):
- `gate_stimlocked`: For stimulus-locked analyses
  - Requires: `valid_baseline500 >= threshold & valid_prestim_fix_interior >= threshold`
  - `valid_prestim_fix_interior` is event-relative: `[fixST + 0.10, fixOFSTP - 0.10]`
  
- `gate_total_auc`: For total AUC analyses
  - Requires: `valid_total_auc_window >= threshold`
  
- `gate_cog_auc`: For cognitive AUC analyses
  - Requires: `valid_cognitive_window >= threshold & valid_baseline500 >= threshold`

### 2. Trial UID

**Stable trial identifier**: `trial_uid = paste(subject_id, task, session, run, trial_index, sep = "_")`

- If `session` is missing, uses "NA" as placeholder
- Ensures unique, stable identification of trials across the pipeline

### 3. Output Files

**New Files**:
- `data/qc/gate_trial_summary.csv`: Trial-level counts by threshold (using `n_distinct(trial_uid)`)
  - Columns: `threshold`, `n_trials_stimlocked`, `n_trials_total_auc`, `n_trials_cog_auc`
  
- `data/qc/gate_subject_summary.csv`: Subject-level pass rates per gate
  - Columns: `subject_id`, `task`, `threshold`, `n_trials_total`, `n_trials_stimlocked`, `n_trials_total_auc`, `n_trials_cog_auc`, `pct_stimlocked`, `pct_total_auc`, `pct_cog_auc`

**Legacy File** (DEPRECATED):
- `data/qc/pupil_threshold_sweep.csv`: Old nested gate format (kept for backwards compatibility)
  - Maps: `gate_A ≈ gate_stimlocked`, `gate_B ≈ gate_total_auc`, `gate_C ≈ gate_cog_auc`
  - **Note**: This is an approximate mapping for backwards compatibility only

### 4. Updated Validation

**File**: `data/qc/gate_relationship_summary.csv`

- Replaced subset validation (which expected nested relationships)
- Now shows overlaps between independent gates (informational only)
- No violations expected since gates are independent

## Migration Guide

### For Analysis Scripts

**Old (nested)**:
```r
# Gate A required for B and C
gate_A = valid_iti >= thr & valid_prestim >= thr
gate_B = gate_A & valid_total_auc_window >= thr
gate_C = gate_B & valid_cognitive_window >= thr & valid_baseline500 >= thr
```

**New (independent)**:
```r
# Each gate is independent
gate_stimlocked = valid_baseline500 >= thr & valid_prestim_fix_interior >= thr
gate_total_auc = valid_total_auc_window >= thr
gate_cog_auc = valid_cognitive_window >= thr & valid_baseline500 >= thr
```

### For Filtering Trials

**Use trial_uid for stable identification**:
```r
# Load trial coverage
trial_coverage <- read_csv("data/qc/pupil_trial_coverage_prefilter.csv")

# Add gates for specific threshold
trial_coverage <- add_analysis_gates(trial_coverage, threshold = 0.80)

# Filter by gate
stimlocked_trials <- trial_coverage %>%
  filter(gate_stimlocked) %>%
  pull(trial_uid)
```

## Files Modified

1. `02_pupillometry_analysis/quality_control/build_pupil_trial_coverage_prefilter.R`
   - Added `add_analysis_gates()` function
   - Added `trial_uid` creation
   - Added `valid_prestim_fix_interior` alias
   - Updated threshold sweep to use new gates
   - Updated validation to reflect independent gates

## Files Still Using Old Gates (To Be Updated)

1. `02_pupillometry_analysis/generate_pupil_data_report.qmd`
   - Still references `gate_A`, `gate_B`, `gate_C`
   - Should be updated to use new gate names
   - Old gates marked as DEPRECATED

## Benefits

1. **Flexibility**: Each analysis can use the gate appropriate for its needs
2. **Clarity**: Gate names reflect their purpose (stimlocked, total_auc, cog_auc)
3. **No artificial dependencies**: Gates don't require each other unless logically necessary
4. **Stable trial identification**: `trial_uid` ensures consistent trial tracking

## Next Steps

1. Update `generate_pupil_data_report.qmd` to use new gate names
2. Update any downstream analysis scripts to use new gates
3. Remove deprecated gate columns once all scripts are migrated



