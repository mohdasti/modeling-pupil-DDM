# MATLAB Pipeline Audit Implementation

## Overview

This document describes the comprehensive audit system for the MATLAB pupillometry preprocessing pipeline. The audit verifies:
1. No silent defaults for metadata (session/run)
2. Only sessions 2-3 processed (scanner tasks)
3. Run numbers 1-5 validated
4. Segmentation confidence checks
5. Reproducibility with pipeline_run_id
6. Internal consistency of QC artifacts

## Audit Scripts Created

### 1. `audit_discovery.m`
**Purpose**: Discovery audit - enumerate all cleaned.mat files and parse metadata

**Output**: `parsed_metadata_inventory.csv`

**Columns**:
- `filename`, `filepath`
- `parse_success` (true/false)
- `subject`, `task`, `session`, `run`
- `parse_failure_reason`
- `would_default_session1`, `would_default_run1` (what old code would do)

**Summary**: Reports how many files would have defaulted to session=1/run=1 under old code.

### 2. `audit_qc_crosscheck.m`
**Purpose**: Cross-check against BAP_QC spreadsheet

**Output**: `qc_expected_vs_observed_runs.csv`

**Columns**:
- `subject`, `task`
- `expected_runs`, `observed_runs`
- `observed_run_numbers`
- `mismatch` (true/false)
- `mismatch_reason`

**Summary**: Compares expected vs observed runs per subject×task.

### 3. `audit_logp_integrity.m`
**Purpose**: Validate logP integrity for all runs

**Output**: `qc_logP_integrity_by_run.csv`

**Columns**:
- `subject`, `task`, `session`, `run`
- `logP_exists`
- `n_trial_anchors` (should be 30)
- `trial_st_monotonic`
- `trial_st_min`, `trial_st_max`
- `median_iti`, `min_iti`, `max_iti`
- `plausibility_check` (PASS/FAIL)
- `integrity_status`

**Checks**:
- Exactly 30 TrialST anchors
- Trial start times strictly increasing
- Median ITI in [8,25] seconds
- Min ITI >= 5 seconds

### 4. `audit_timebase_iti.m`
**Purpose**: Validate timebase and inter-trial intervals

**Output**: `qc_timebase_and_iti_checks.csv`

**Columns**:
- `subject`, `task`, `session`, `run`
- `segmentation_source`
- `n_trials_extracted`
- `timebase_method`, `timebase_offset`
- `window_oob`
- `timebase_offset_plausible` (for logP)
- `window_oob_ok` (should be 0 for logP)
- `median_iti`, `min_iti`, `max_iti` (for event_code)
- `timebase_issue`

**Checks**:
- logP segmentation: timebase_offset in plausible range, window_oob == 0
- event_code segmentation: ITI stats within [8,25]s median, min >= 5s

### 5. `audit_regenerate_qc.m`
**Purpose**: Regenerate QC artifacts from flat files to ensure consistency

**Outputs**:
- `qc_matlab_run_trial_counts.csv` (regenerated)
- `qc_matlab_trial_level_flags.csv` (regenerated)

**Purpose**: Ensures QC outputs are not stale and match actual flat file contents.

### 6. `generate_signoff_report.m`
**Purpose**: Generate comprehensive sign-off report

**Output**: `MATLAB_PIPELINE_SIGNOFF.md`

**Sections**:
1. Counts Summary (subjects, sessions, tasks, runs, trials)
2. Segmentation Source Distribution
3. Session 1 Exclusion Verification
4. Run Number Validation
5. Skipped Runs
6. logP Integrity
7. Expected vs Observed Runs
8. Final Recommendation (PASS/FAIL with action items)

### 7. `run_matlab_audit.m`
**Purpose**: Main audit script - runs all audit checks

**Usage**:
```matlab
cd('/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM/01_data_preprocessing/matlab');
run_matlab_audit();
```

## Hard Requirements Status

### 1. NO silent defaults ✅
- `parse_filename()` returns empty metadata on parse failure (no defaults)
- Lenient parsing is logged with warnings (not silent)
- All parse failures logged to `qc_matlab_skip_reasons.csv` via manifest

### 2. Session/task scope ✅
- `parse_filename()` explicitly checks `session_num ~= 2 && session_num ~= 3` and skips
- Only files with session 2 or 3 are processed
- Audit report verifies session 1 count = 0

### 3. Run must be 1-5 ✅
- `parse_filename()` validates run number
- Audit report checks for invalid run numbers

### 4. Segmentation confidence ✅
- Primary: logP-driven (when logP exists and valid)
- Fallback: event-code only if passes strict checks:
  - n_trials in [28,30]
  - trial start times strictly increasing
  - median ITI in [8,25] seconds
  - min ITI >= 5 seconds
- Audit validates these checks

### 5. Reproducibility ✅
- `pipeline_run_id` generated (timestamp + git hash)
- Added to all flat files as metadata column
- Added to `qc_matlab_run_trial_counts.csv`
- Added to `qc_matlab_trial_level_flags.csv`
- Included in audit/sign-off reports

## Output Files (All in `qc_matlab/` directory)

1. `parsed_metadata_inventory.csv` - Discovery audit results
2. `qc_expected_vs_observed_runs.csv` - QC spreadsheet cross-check
3. `qc_logP_integrity_by_run.csv` - logP validation
4. `qc_timebase_and_iti_checks.csv` - Timebase and ITI validation
5. `qc_matlab_run_trial_counts.csv` - Regenerated run-level QC
6. `qc_matlab_trial_level_flags.csv` - Regenerated trial-level QC
7. `qc_matlab_skip_reasons.csv` - All skipped runs with reasons
8. `MATLAB_PIPELINE_SIGNOFF.md` - Final sign-off report

## Running the Audit

```matlab
cd('/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM/01_data_preprocessing/matlab');
run_matlab_audit();
```

The audit will:
1. Discover all cleaned.mat files and parse metadata
2. Cross-check against BAP_QC spreadsheet
3. Validate logP integrity
4. Validate timebase and ITI
5. Regenerate QC artifacts from flat files
6. Generate comprehensive sign-off report

## Sign-Off Report Interpretation

**PASS**: All requirements met, MATLAB stage ready for downstream processing.

**FAIL**: Issues found, action items listed. Must fix before proceeding.

Key checks:
- ✅ Session 1 count = 0
- ✅ All run numbers in [1,5]
- ✅ logP integrity PASS for all runs with logP
- ✅ Timebase checks pass
- ✅ QC artifacts consistent

## Notes

- The audit uses the most recent build directory if available
- All outputs are written to `qc_matlab/` subdirectory
- The audit does NOT modify the pipeline - it only reads and validates
- If QC spreadsheet not found, cross-check is skipped (warning only)

