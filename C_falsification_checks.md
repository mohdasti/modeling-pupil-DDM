# C) LENIENCY / FALSE-PASS FALSIFICATION

## Current Implementation Status

### Check 1: Event-Code vs logP Residual Validation
**Location**: `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m`, lines 703-725

**Current Implementation**:
```matlab
% Check alignment with logP if available
if logP_data.success && ~isempty(logP_data.trial_st) && length(logP_data.trial_st) >= 20
    % Compare event anchors to logP anchors
    residuals = [];
    for i = 1:min(length(squeeze_onsets_event), length(logP_data.trial_st))
        [min_residual, ~] = min(abs(squeeze_onsets_event - logP_data.trial_st(i)));
        residuals(end+1) = min_residual;
    end
    median_residual = median(residuals);
    
    if median_residual < 0.02  % 20ms tolerance
        squeeze_onsets = squeeze_onsets_event;
        segmentation_source = 'event_code';
        % ... success path
    else
        fprintf('    Event-code segmentation failed validation (median residual: %.3f s > 20ms)\n', ...
            median_residual);
    end
end
```

**Status**: ⚠️ **PARTIAL** - Residuals computed but:
- Only used for validation decision (pass/fail)
- **NOT stored** in QC outputs
- **NOT written** to `qc_matlab_falsification_residuals_by_run.csv`
- Max residual not computed (only median)

### Check 2: logP-Driven Window Validation
**Location**: `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m`, lines 834-890

**Current Implementation**:
- Trial windows extracted using `trial_start_time` and `trial_end_time` (lines 835-836)
- Window OOB tracked via `window_oob` flag (line 1077)
- All-NaN trials tracked via `all_nan` flag (line 1090)

**Status**: ⚠️ **PARTIAL** - Window extraction exists but:
- **NOT validated** that expected logP events (blankST, fixST, A/V_ST, Resp1ST) are INSIDE window
- No explicit check for timebase_bug based on event positions

### Check 3: Trial Index Preservation
**Location**: `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m`, lines 1047-1053

**Current Implementation**:
```matlab
% CRITICAL FIX: Use original trial_idx (1..N) as trial_in_run_raw for merging
if strcmp(segmentation_source, 'logP') && logP_data.success
    % Use logP row number (trial_idx corresponds to logP row)
    trial_table.trial_in_run_raw = repmat(trial_idx, n_samples, 1);
else
    % Use event order
    trial_table.trial_in_run_raw = repmat(trial_idx, n_samples, 1);
end
```

**Status**: ✅ **PASS** - `trial_in_run_raw` preserves original index

## Required Implementations

### Implementation 1: Residual QC Table
**New File**: `qc_matlab_falsification_residuals_by_run.csv`

**Location**: Add to `write_qc_outputs.m` or create new function

**Columns**:
- `subject` (string)
- `task` (string)
- `session` (numeric)
- `run` (numeric)
- `segmentation_source` (string: "event_code", "logP", or "both_available")
- `n_trials` (numeric: number of trials extracted)
- `residual_median_abs` (numeric: median absolute residual in seconds)
- `residual_max_abs` (numeric: max absolute residual in seconds)
- `residual_iqr` (numeric: IQR of residuals)
- `flagged_falsification` (boolean: TRUE if max_abs > 0.05s OR median_abs > 0.02s)
- `n_event_anchors` (numeric: number of event-code anchors)
- `n_logP_anchors` (numeric: number of logP anchors)

**Implementation**:
```matlab
% In process_single_run_improved(), after segmentation decision (around line 798)
if logP_data.success && ~isempty(squeeze_onsets) && strcmp(segmentation_source, 'event_code')
    % Compute residuals for QC
    residuals = [];
    for i = 1:min(length(squeeze_onsets), length(logP_data.trial_st))
        [min_residual, ~] = min(abs(squeeze_onsets - logP_data.trial_st(i)));
        residuals(end+1) = min_residual;
    end
    
    run_quality.falsification_residuals = residuals;
    run_quality.residual_median_abs = median(abs(residuals));
    run_quality.residual_max_abs = max(abs(residuals));
    run_quality.residual_iqr = iqr(residuals);
    run_quality.flagged_falsification = (run_quality.residual_max_abs > 0.05) || ...
                                       (run_quality.residual_median_abs > 0.02);
end
```

### Implementation 2: logP Window Event Validation
**Location**: `process_single_run_improved()`, after trial extraction (around line 1120)

**Required Check**:
For logP-driven runs, verify that within each extracted trial window:
- TrialST at t=0 (relative to squeeze onset) ✅ Already correct (trial window starts at squeeze_time)
- blankST around +3.0s ✅ Should be inside window
- fixST around +3.25s ✅ Should be inside window
- fix offset around +3.75s ✅ Should be inside window
- A/V_ST around +3.76–3.81s ✅ Should be inside window
- Resp1ST around +4.79s ✅ Should be inside window

**Implementation**:
```matlab
% After trial extraction, if segmentation_source == 'logP'
if strcmp(segmentation_source, 'logP') && logP_data.success
    timebase_bug_detected = false;
    
    for trial_idx = 1:length(squeeze_onsets)
        squeeze_time = squeeze_onsets(trial_idx);
        trial_start_time = squeeze_time - 3.0;
        trial_end_time = squeeze_time + 10.7;
        
        % Check expected event times (relative to squeeze_time)
        expected_events = [
            squeeze_time + 0.0;      % TrialST (squeeze onset)
            squeeze_time + 3.0;       % blankST
            squeeze_time + 3.25;      % fixST
            squeeze_time + 3.75;      % fix offset
            squeeze_time + 3.76;      % A/V_ST (min)
            squeeze_time + 4.79;     % Resp1ST
        ];
        
        % Verify all events are within window
        if any(expected_events < trial_start_time) || any(expected_events > trial_end_time)
            timebase_bug_detected = true;
            fprintf('    WARNING: Trial %d has events outside window\n', trial_idx);
        end
    end
    
    if timebase_bug_detected
        run_quality.run_status = 'timebase_bug';
        run_quality.timebase_bug_reason = 'logP_events_outside_window';
    end
end
```

### Implementation 3: Update falsification_validation_summary.md
**Location**: `generate_falsification_summary.m`

**Required Additions**:
1. Load `qc_matlab_falsification_residuals_by_run.csv` if it exists
2. Count flagged runs: `n_flagged = sum(flagged_falsification == true)`
3. List top 10 worst runs by `residual_max_abs`
4. Add section:
   ```markdown
   ## Residual Validation (Event-Code vs logP)
   
   - **Runs with both event-code and logP available**: X
   - **Runs flagged for falsification** (max_abs > 0.05s OR median_abs > 0.02s): Y
   - **Top 10 worst runs** (by residual_max_abs):
     | Subject | Task | Session | Run | residual_max_abs | residual_median_abs | flagged |
     |---------|------|---------|-----|------------------|---------------------|---------|
     | ...     | ...  | ...     | ... | ...              | ...                 | ...     |
   ```

## Code Locations for Implementation

| Check | Current Status | Implementation Location | Priority |
|-------|---------------|------------------------|----------|
| Residual computation | ✅ Exists (line 705-710) | Add to QC output | HIGH |
| Residual QC table | ❌ Missing | `write_qc_outputs.m` or new function | HIGH |
| logP window validation | ⚠️ Partial (window_oob exists) | `process_single_run_improved()` after line 1120 | HIGH |
| Trial index preservation | ✅ PASS | Already correct | N/A |
| Falsification summary update | ⚠️ Partial | `generate_falsification_summary.m` | MEDIUM |

## Testing Plan

1. **Test residual computation**:
   - Run on BAP202 session2 run4 (known to have both event-code and logP)
   - Verify residuals computed and stored
   - Verify QC table created

2. **Test window validation**:
   - Run on logP-only run
   - Verify timebase_bug flag set if events outside window
   - Verify run_status = 'timebase_bug'

3. **Test falsification summary**:
   - Verify top 10 worst runs listed
   - Verify flagged count accurate

## Next Steps

1. **IMMEDIATE**: Add residual computation and storage in `process_single_run_improved()`
2. **IMMEDIATE**: Create `qc_matlab_falsification_residuals_by_run.csv` output
3. **IMMEDIATE**: Add logP window event validation
4. **FOLLOW-UP**: Update `falsification_validation_summary.md` generation

