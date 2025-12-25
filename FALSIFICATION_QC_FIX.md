# Falsification QC Fix - Critical Bug

## Issue Found

The MATLAB pipeline was crashing with:
```
ERROR: Unrecognized function or variable 'trial_segments'.
```

This occurred for every run that successfully used logP segmentation (which is the fallback when event-code segmentation fails validation).

## Root Cause

The `trial_segments` structure was being used in the falsification checks (anti-copy/paste validation) but was **never initialized** before the trial processing loop. This structure stores:
- `start_idx`: Starting index of each trial segment in the pupil array
- `end_idx`: Ending index of each trial segment
- `trial_hash`: Hash value for duplicate detection

## Fix Applied

**File**: `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m`

**Location**: Before the trial processing loop (around line 608)

**Change**: Added initialization of `trial_segments` and falsification check counters:

```matlab
% FALSIFICATION CHECK C: Initialize trial_segments for anti-copy/paste checks
trial_segments = struct();
trial_segments.start_idx = [];
trial_segments.end_idx = [];
trial_segments.trial_hash = [];

% Initialize falsification check counters
window_oob_count = 0;
empty_trial_count = 0;
all_nan_trial_count = 0;
```

## Where QC Output Files Are Generated

The QC output files are generated **only when the pipeline runs successfully** (no errors). They are written to:

**Base directory**: `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/qc_matlab/`

**Files generated**:
1. `qc_matlab_run_trial_counts.csv` - Run-level QC statistics including:
   - `n_trials_extracted`
   - `segmentation_source` (event_code vs logP)
   - `window_oob_count`, `empty_trial_count`, `all_nan_trial_count`
   - `start_idx_monotonic`, `n_duplicate_segments`, `n_duplicate_hashes`
   - `logP_plausibility_valid`
   - `run_status`

2. `qc_matlab_skip_reasons.csv` - Reasons for skipped runs:
   - `logP_invalid`: logP timing intervals failed plausibility checks
   - `timebase_bug`: start_idx not monotonic or duplicate segments detected
   - `No trials extracted`: Other reasons (missing files, etc.)

3. `falsification_validation_summary.md` - Summary report with:
   - Overall statistics (% runs with 28-30 trials, 20-35 trials)
   - Skipped runs by reason
   - Window OOB distribution
   - Failure analysis and recommendations

## Why Files Weren't Found

The QC files weren't generated because:
1. The pipeline was crashing on every run with the `trial_segments` error
2. When the pipeline crashes, `write_qc_outputs()` is never called
3. The `qc_matlab/` directory may not even exist if no runs completed successfully

## Next Steps

1. **Re-run the MATLAB pipeline** with the fix applied:
   ```matlab
   cd('/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM/01_data_preprocessing/matlab');
   BAP_Pupillometry_Pipeline();
   ```

2. **Check for QC files** after successful completion:
   ```bash
   ls -la /Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/qc_matlab/
   ```

3. **Review the summary report**:
   ```bash
   cat /Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/qc_matlab/falsification_validation_summary.md
   ```

## Expected Behavior After Fix

After the fix, you should see:
- ✅ Runs processing successfully using logP segmentation
- ✅ Trial extraction completing (even if event-code validation fails)
- ✅ QC files being generated in `BAP_processed/qc_matlab/`
- ✅ Falsification summary printed at the end of the pipeline
- ✅ No more `trial_segments` errors

## Additional Notes

The error was occurring specifically for runs using **logP segmentation** because:
- Event-code segmentation was failing validation (median residual > 20ms)
- Pipeline correctly fell back to logP segmentation
- But `trial_segments` was only initialized in some code paths, not all

The fix ensures `trial_segments` is initialized **before** any trial processing, regardless of which segmentation method is used.

