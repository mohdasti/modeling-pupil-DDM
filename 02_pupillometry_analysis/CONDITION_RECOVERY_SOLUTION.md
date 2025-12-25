# Condition Recovery Solution

## Overview

We've implemented an automatic recovery mechanism that backfills missing condition labels (`effort_condition` and `difficulty_level`) from the behavioral data file. This should significantly increase the number of trials available for analysis by recovering trials that had missing conditions due to merge failures.

## What Was Implemented

### 1. Automatic Recovery Mechanism

After building the trial coverage data, the system now:

1. **Identifies trials with missing conditions** - Finds all trials where `effort_condition` or `difficulty_level` is `NA`

2. **Loads behavioral data directly** - Reads the behavioral CSV file to get condition information

3. **Matches trials** - Matches trials by:
   - `subject_id` (normalized)
   - `task` (normalized to ADT/VDT)
   - `run` (run number)
   - `trial_index` (trial number within run)

4. **Extracts condition information** from behavioral data:
   - **Effort condition**: From `grip_targ_prop_mvc` (0.05 = Low, 0.4 = High) or `force_condition`
   - **Difficulty level**: From `stim_is_diff`/`isOddball` and `stim_level_index`/`stimLev`

5. **Backfills missing conditions** - Updates `trial_coverage_prefilter` with recovered conditions

### 2. Recovery Statistics

The system tracks and reports:
- Number of trials attempted for recovery
- Number of effort conditions recovered
- Number of difficulty levels recovered
- Number of trials where both conditions were recovered
- Success rates (percentage of attempted recoveries)

### 3. Enhanced Reporting

The condition labeling summary now shows:
- **Recovery Statistics**: How many conditions were successfully recovered
- **Current Status**: Final state after recovery attempt
- **Diagnostics**: Detailed information about trials that still have missing conditions

## How It Works

### Recovery Process Flow

```
1. Build trial_coverage_prefilter from flat files
   ↓
2. Check for missing conditions
   ↓
3. If missing conditions found AND behavioral_file exists:
   ↓
4. Load behavioral data
   ↓
5. Normalize subject IDs, tasks, runs, trial indices
   ↓
6. Match trials by (subject_id, task, run, trial_index)
   ↓
7. Extract condition information from behavioral data
   ↓
8. Backfill missing conditions in trial_coverage_prefilter
   ↓
9. Report recovery statistics
```

### Condition Assignment Logic

**Effort Condition:**
- `gf_trPer == 0.05` → `"Low_5_MVC"`
- `gf_trPer == 0.4` or `0.40` → `"High_40_MVC"`
- `force_condition == "Low_Force_5pct"` → `"Low_5_MVC"`
- `force_condition == "High_Force_40pct"` → `"High_40_MVC"`

**Difficulty Level:**
- `isOddball == 0` → `"Standard"`
- `isOddball == 1` with `stimLev` in `[1, 2]` → `"Hard"`
- `isOddball == 1` with `stimLev` in `[3, 4]` → `"Easy"`
- Legacy values also supported (8, 16, 32, 64, etc.)

## Expected Benefits

1. **Increased trial counts**: Trials that were previously excluded due to missing conditions can now be included in analyses

2. **Better data utilization**: Recovers trials lost due to merge failures, not actual data quality issues

3. **Automatic process**: No manual intervention needed - recovery happens automatically when generating the report

4. **Transparent reporting**: Clear statistics on what was recovered and what remains missing

## Limitations

### Trials That Cannot Be Recovered

Trials that still have missing conditions after recovery are likely due to:

1. **No matching behavioral data**: The trial doesn't exist in the behavioral CSV file
2. **Invalid condition values**: The behavioral data has values that don't match expected patterns
3. **Mismatched identifiers**: Subject ID, task, run, or trial_index don't match between pupil and behavioral data
4. **Missing source columns**: Required columns (`grip_targ_prop_mvc`, `stim_level_index`, etc.) don't exist in behavioral data

### What to Do About Unrecoverable Trials

1. **Check behavioral data availability**: Verify the trial exists in the behavioral CSV
2. **Investigate merge process**: Check why the merge failed in `01_data_preprocessing/r/Create merged flat file.R`
3. **Examine source values**: Look at the raw values in behavioral data to see if they match expected patterns
4. **Fix at source**: Address data quality issues in the source behavioral files

## Usage

The recovery happens automatically when you generate the report. No additional steps are needed.

To see recovery statistics, look for the "Recovery Statistics" section in the "Condition Labeling Diagnostics" section of the report.

## Technical Details

### Code Location

The recovery code is in `generate_pupil_data_report.qmd`, inserted after `build_trial_coverage()` and before adding `trial_id` (around line 541-688).

### Key Functions

- **Recovery matching**: Uses `left_join()` to match trials between pupil and behavioral data
- **Condition extraction**: Uses the same logic as `build_trial_coverage()` to assign conditions
- **Statistics tracking**: Stores recovery stats in global environment for later reporting

### Error Handling

The recovery process is wrapped in `tryCatch()` so that:
- If recovery fails, the report still generates
- A warning message is displayed explaining why recovery failed
- Original data is preserved (recovery only adds, never removes)

## Next Steps

1. **Run the report** to see how many trials can be recovered
2. **Review recovery statistics** to understand the scope of the issue
3. **Investigate unrecoverable trials** to identify root causes
4. **Fix merge pipeline** if needed to prevent future missing conditions
5. **Re-run analyses** with the increased trial counts

## Related Files

- `generate_pupil_data_report.qmd` - Main report with recovery logic
- `01_data_preprocessing/r/Create merged flat file.R` - Merge pipeline (root cause of missing conditions)
- `CONDITION_LABELING_AUDIT.md` - Detailed audit of why conditions were missing



