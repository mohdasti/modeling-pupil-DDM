# Merged Trial-Level Dataset v2

## Overview

This document explains the behavioral column derivations and correctness computation in `BAP_triallevel_merged_v2.csv`.

## Behavioral Column Derivation

### `isOddball` (derived)
- **Source**: `stimulus_intensity`
- **Rule**: `isOddball = 1` if `stimulus_intensity != 0`, else `0`
- **Rationale**: In this task, intensity = 0 means standard (non-oddball), and any non-zero intensity means oddball
- **NA handling**: `isOddball` is NA when `stimulus_intensity` is NA

### `choice_num` and `choice_label` (derived)
- **Source**: `choice` (boolean or numeric)
- **Conversion**:
  - `choice_num = 0` → `choice_label = "SAME"`
  - `choice_num = 1` → `choice_label = "DIFFERENT"`
- **Rationale**: Standardizes choice coding across different input formats
- **NA handling**: Both are NA when `choice` is NA

### `correct_calc` (computed)
- **Rule**: `correct_calc = 1` if `choice_num == isOddball`, else `0`
- **Rationale**: Correct response is when participant's choice matches the stimulus type
  - If stimulus is oddball (`isOddball = 1`) and choice is DIFFERENT (`choice_num = 1`) → correct
  - If stimulus is standard (`isOddball = 0`) and choice is SAME (`choice_num = 0`) → correct
- **NA handling**: `correct_calc` is NA when either `choice_num` or `isOddball` is NA

### `correct_final` (recommended)
- **Value**: `correct_final = correct_calc`
- **Rationale**: Uses internally consistent correctness computation, preventing legacy bugs
- **Usage**: Use `correct_final` for all analyses instead of `correct` (legacy)

## Legacy Columns Preserved

- **`correct`**: Original correctness from behavioral file (preserved for auditing)
- **`choice`**: Original choice column (preserved for reference)

## QC Artifacts

### `qc/qc_run_correctness_agreement.csv`
Run-level comparison of legacy `correct` vs computed `correct_calc`:
- `agree_correct`: Proportion of trials where `correct == correct_calc`
- `acc_correct_calc`: Accuracy using `correct_calc`
- `acc_correct_legacy`: Accuracy using legacy `correct`

### `qc/qc_runs_flagged_correctness.csv`
Runs flagged for correctness issues:
- Runs where `agree_correct < 0.90` or NA
- Use this to identify runs with potential data quality issues

## Usage Recommendations

1. **For analyses**: Use `correct_final` (not `correct`)
2. **For choice coding**: Use `choice_label` for human-readable labels, `choice_num` for numeric coding
3. **For oddball status**: Use `isOddball` (derived from intensity)
4. **For auditing**: Compare `correct` vs `correct_calc` using QC tables

## Validation

- `isOddball` NA rate should match `stimulus_intensity` NA rate
- `correct_final` should be used for all accuracy computations
- Check `qc_run_correctness_agreement.csv` for runs with low agreement

