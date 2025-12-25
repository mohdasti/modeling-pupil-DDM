# MATLAB Pipeline Hardening Patch

## Overview

This document describes the surgical changes needed to harden the MATLAB pipeline for reliable trial extraction with logP fallback.

## Key Changes to `process_single_run_improved()`

### 1. Add logP Parsing (Lines ~340-350)

**BEFORE:**
```matlab
raw_data = load(raw_path);
```

**AFTER:**
```matlab
raw_data = load(raw_path);

% HARDENING: Try to load logP file for fallback segmentation
logP_path = strrep(raw_path, '_eyetrack.mat', '_logP.txt');
logP_data = struct();
logP_data.success = false;
if exist(logP_path, 'file')
    logP_data = parse_logP_file(logP_path);
    if logP_data.success
        fprintf('    Loaded logP: %d trials\n', logP_data.n_trials);
    end
end
```

### 2. Implement Dual-Mode Segmentation (Lines ~425-450)

**BEFORE:**
```matlab
% Find squeeze onsets to define trial boundaries
squeeze_onsets = transition_times(transition_from == CONFIG.event_codes.baseline & ...
                                 transition_to == CONFIG.event_codes.squeeze_start);

if isempty(squeeze_onsets)
    fprintf('    No squeeze onsets found\n');
    return;
end
```

**AFTER:**
```matlab
% HARDENING: Try event-code segmentation first
squeeze_onsets_event = transition_times(transition_from == CONFIG.event_codes.baseline & ...
                                        transition_to == CONFIG.event_codes.squeeze_start);

segmentation_source = 'unknown';
squeeze_onsets = [];

% Validate event-code segmentation
if ~isempty(squeeze_onsets_event) && length(squeeze_onsets_event) >= 28 && length(squeeze_onsets_event) <= 30
    % Event-code segmentation looks good
    squeeze_onsets = squeeze_onsets_event;
    segmentation_source = 'event_code';
    fprintf('    Event-code segmentation: %d trials\n', length(squeeze_onsets));
else
    % Try logP fallback
    if logP_data.success && logP_data.n_trials >= 28 && logP_data.n_trials <= 35
        % Convert logP TrialST to pupil timebase
        % TODO: Implement timebase conversion
        squeeze_onsets = logP_data.trial_st;  % Placeholder - needs timebase conversion
        segmentation_source = 'logP';
        fprintf('    logP fallback segmentation: %d trials\n', length(squeeze_onsets));
    else
        fprintf('    ERROR: Both event-code and logP segmentation failed\n');
        segmentation_source = 'failed';
    end
end

if isempty(squeeze_onsets)
    fprintf('    No trial anchors found - skipping run\n');
    % TODO: Document in skip_reasons.csv
    return;
end
```

### 3. Store Segmentation Source (Lines ~550-560)

**ADD:**
```matlab
% Store segmentation source in trial table
trial_table.segmentation_source = repmat({segmentation_source}, n_samples, 1);
```

### 4. Add QC Outputs (End of function)

**ADD:**
```matlab
% Store segmentation info in QC stats
run_quality.qc_stats.segmentation_source = segmentation_source;
run_quality.qc_stats.n_log_trials = logP_data.n_trials;
run_quality.qc_stats.n_marker_anchors = length(squeeze_onsets_event);
```

## New Helper Functions Required

### `parse_logP_file.m` (✅ CREATED)
- Parses logP.txt to extract PTB trial times
- Returns struct with trial_st, blank_st, fix_st, etc.

### `discover_event_codes.m` (✅ CREATED)
- Searches task code repo for event marker definitions
- Returns codebook table

### `convert_timebase.m` (⏳ NEEDED)
- Converts between timebases (pupil time → PTB time)
- Uses alignment markers to compute offset

### QC Output Functions (⏳ NEEDED)
- `write_qc_run_trial_counts.m`
- `write_qc_marker_counts.m`
- `write_qc_skip_reasons.m`
- `write_qc_trial_flags.m`
- `generate_matlab_audit_report.m`

## Testing Plan

1. Test on example run: BAP202 session2 run4
2. Verify:
   - Event-code segmentation works if codes present
   - logP fallback works if event codes fail
   - QC outputs are generated
   - All runs documented (success or failure)

## Implementation Priority

1. **CRITICAL**: logP parsing and fallback segmentation
2. **HIGH**: Timebase conversion
3. **MEDIUM**: QC output functions
4. **LOW**: Event code discovery (can use assumptions for now)

---

*This patch provides surgical fixes without full refactoring.*

