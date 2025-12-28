# Falsification QC Checks Implementation Summary

## Overview
This document summarizes the falsification QC checks that have been added to the MATLAB pipeline to prove it is not over-lenient (i.e., not extracting wrong windows or duplicating data).

## Changes Made

### 1. LogP Plausibility Checks (Task A)
**Location**: `validate_logP_plausibility.m` (already implemented)

**What it does**:
- Validates timing intervals from parsed logP files:
  - `blankST - TrialST`: Expected 3.00 ± 0.05 seconds
  - `fixST - blankST`: Expected 0.25 ± 0.05 seconds
  - `A/V_ST - fixST`: Expected 0.50-0.55 seconds (accepts 0.40-0.70)

**Integration**:
- Called in `process_single_run_improved()` before trial extraction
- If validation fails, sets `run_status = 'logP_invalid'` and skips extraction
- Diagnostics stored in `run_quality.logP_plausibility_diagnostics`

### 2. Timebase Confidence Diagnostics (Task B)
**Location**: `BAP_Pupillometry_Pipeline.m` (lines 600-650, 978-980)

**What it tracks**:
- `window_oob_count`: Number of trials where `[TrialST+win_start, TrialST+win_end]` intersects `pupil_time_ptb` with < 50% expected samples
- `empty_trial_count`: Number of trials with extracted samples = 0
- `all_nan_trial_count`: Number of trials with extracted samples > 0 but all pupil invalid/NaN

**Storage**:
- Tracked per run in `run_qc_stats`
- Written to `qc_matlab_run_trial_counts.csv`
- Stored in trial-level table as `window_oob`, `all_nan` flags

### 3. Anti-"Copy/Paste Window" Checks (Task C)
**Location**: `BAP_Pupillometry_Pipeline.m` (lines 607-610, 844-850, 919-963)

**What it checks**:
- **Start index monotonicity**: Verifies `start_idx` is strictly increasing across trials
- **Duplicate segments**: Counts number of duplicated `(start_idx, end_idx)` pairs
- **Trial hash duplicates**: Computes cheap hash (sum+mean+var rounded) for each trial segment and counts duplicates

**Storage**:
- `start_idx` and `end_idx` stored in trial table for each trial
- `start_idx_monotonic` (boolean) stored in `run_qc_stats`
- `n_duplicate_segments` and `n_duplicate_hashes` stored in `run_qc_stats`

**Action on failure**:
- If `start_idx` not monotonic OR `n_duplicate_segments > 0`, sets `run_status = 'timebase_bug'` and skips writing flat file

### 4. Metadata Integrity (Task D)
**Location**: `BAP_Pupillometry_Pipeline.m` (lines 856-876)

**What it stores**:
- `session_from_filename`: Session parsed from cleaned.mat filename
- `run_from_filename`: Run parsed from cleaned.mat filename
- `session_from_logP_filename`: Session parsed from logP.txt filename (if available)
- `run_from_logP_filename`: Run parsed from logP.txt filename (if available)
- `session_used`: Session actually used by pipeline
- `run_used`: Run actually used by pipeline

**Purpose**:
- Enables downstream validation that stored `ses`/`run` match parsed values
- Flags mismatches that could indicate labeling bugs

### 5. More Lenient Segmentation Range
**Location**: `BAP_Pupillometry_Pipeline.m` (lines 523-576)

**Change**:
- Previously required exactly 28-30 anchors for event-code segmentation
- Now accepts 20-35 anchors (with warnings for 20-27 or 31-35)
- Same leniency applied to logP-driven segmentation fallback

**Rationale**:
- Many runs have partial data (10-25 anchors) due to aborted runs or missing event codes
- Still prefer 28-30, but allow 20-35 to maximize trial extraction
- Warnings alert user to suboptimal extraction counts

### 6. Falsification Summary Reports
**Location**: `generate_falsification_summary.m`, `print_falsification_summary.m`

**Outputs**:
- **Markdown report**: `BAP_processed/qc_matlab/falsification_validation_summary.md`
  - Overall statistics (runs with 28-30 trials, 20-35 trials)
  - Skipped runs by reason
  - Window OOB distribution
  - Failure analysis and recommendations

- **Console summary**: Printed at end of pipeline
  - Total runs processed
  - Runs with 28-30 trials (target)
  - Runs with 20-35 trials (acceptable)
  - Skipped runs by reason
  - Timebase bugs detected
  - Window OOB distribution

## QC Output Files

All falsification checks are written to:
- `BAP_processed/qc_matlab/qc_matlab_run_trial_counts.csv`: Run-level QC stats including all falsification metrics
- `BAP_processed/qc_matlab/qc_matlab_skip_reasons.csv`: Reasons for skipped runs (including `logP_invalid`, `timebase_bug`)
- `BAP_processed/qc_matlab/qc_matlab_trial_level_flags.csv`: Trial-level flags (requires post-processing aggregation)
- `BAP_processed/qc_matlab/falsification_validation_summary.md`: Summary report

## Running Validation

To run the pipeline with falsification checks across multiple subjects:

```matlab
% In MATLAB, navigate to project directory
cd('/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM/01_data_preprocessing/matlab');

% Run the pipeline
BAP_Pupillometry_Pipeline();
```

Or use the helper script:
```matlab
run_matlab_pipeline();
```

## Expected Output

After running, you should see:

1. **Console output** for each run showing:
   - Segmentation method used (event_code vs logP)
   - Number of trials extracted
   - Warnings if outside [28,30] range
   - Sanity check summary per run

2. **Falsification QC Summary** at the end:
   - Total runs processed
   - % runs with 28-30 trials (target: >=90%)
   - % runs with 20-35 trials (acceptable: >=95%)
   - Count of skipped runs by reason
   - Any runs flagged with `timebase_bug`
   - Distribution of `window_oob_count`

3. **QC CSV files** in `BAP_processed/qc_matlab/`:
   - `qc_matlab_run_trial_counts.csv` with all falsification metrics
   - `qc_matlab_skip_reasons.csv` with skip reasons
   - `falsification_validation_summary.md` with full report

## PASS/FAIL Criteria

The pipeline PASSES falsification validation if:
- ≥ 95% of runs extract 20-35 trials OR are explicitly marked as aborted/unusable
- Zero runs flagged with `timebase_bug`
- Zero runs with `start_idx` not monotonic
- Zero runs with duplicate segments

The pipeline FAILS if:
- < 95% of runs extract 20-35 trials (excluding explicitly aborted runs)
- Any runs flagged with `timebase_bug`
- Systematic failures in logP plausibility checks

## Next Steps

1. Run the pipeline on at least 5 subjects (across both ADT and VDT tasks)
2. Review `falsification_validation_summary.md` for any failures
3. Investigate any runs flagged with `timebase_bug` or `logP_invalid`
4. Check `window_oob_count` distribution for systematic issues
5. Verify that `session_from_filename` matches `session_used` (and same for `run`)

## Notes

- The falsification checks are designed to catch systematic errors (wrong windows, duplicated data, timebase bugs)
- They do NOT catch random missingness or low-quality data (that's handled by QC flags)
- The more lenient segmentation range (20-35) allows partial runs while still preferring complete runs (28-30)
- All checks are non-destructive: they flag issues but don't prevent extraction unless critical (timebase_bug, logP_invalid)

