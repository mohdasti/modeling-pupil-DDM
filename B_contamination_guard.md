# B) STRICT CONTAMINATION PREVENTION

## Current Filter Implementation

### Session Filter (Lines 347-352 in parse_filename.m)
**Location**: `01_data_preprocessing/matlab/parse_filename.m`, lines 52-56 (standalone) or lines 347-352 (in main file)

```matlab
% CRITICAL FIX: Only allow sessions 2 or 3 (InsideScanner tasks)
if session_num ~= 2 && session_num ~= 3
    warning('CRITICAL: Session %d not in {2,3} for file: %s. Skipping file.', session_num, filename);
    metadata = [];
    return;
end
```

**Status**: ✅ **PASS** - Session 1 is explicitly excluded

### Location Filter (InsideScanner)
**Location**: `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m`, lines 418-424

**Current Implementation**:
```matlab
raw_path = fullfile(CONFIG.raw_dir, sprintf('sub-%s/ses-%s/InsideScanner/%s', ...
    file_info.subject{1}, file_info.session{1}, raw_filename));

logP_path = fullfile(CONFIG.raw_dir, sprintf('sub-%s/ses-%s/InsideScanner/%s', ...
    file_info.subject{1}, file_info.session{1}, logP_filename));
```

**Status**: ⚠️ **PARTIAL** - Path construction assumes InsideScanner, but:
1. **No explicit check** that cleaned files come from InsideScanner
2. **No validation** that raw file path exists before processing
3. **Silent failure** if raw file missing (line 426-445: creates manifest entry but continues)

### Cleaned File Discovery (Line 98)
**Location**: `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m`, line 98

```matlab
cleaned_files = dir(fullfile(CONFIG.cleaned_dir, '*_cleaned.mat'));
```

**Status**: ⚠️ **NEEDS HARDENING** - Enumerates ALL `*_cleaned.mat` files without filtering by:
- Session number (relies on parse_filename to reject, but doesn't log excluded files)
- Location (no check for OutsideScanner vs InsideScanner in filename/path)

## Excluded Patterns

### Examples of Files That Should Be Excluded

1. **Session 1 (structural only)**:
   - Pattern: `*session1*` or `*ses-1*` or `*ses1*`
   - Example: `subjectBAP202_Voddball_session1_run1_*_cleaned.mat`
   - **Current Status**: ✅ Excluded by parse_filename.m line 52-56

2. **OutsideScanner runs**:
   - Pattern: Files in `OutsideScanner/` directory or filename containing "OutsideScanner"
   - Example: `subjectBAP202_Voddball_session2_run1_OutsideScanner_*_cleaned.mat`
   - **Current Status**: ⚠️ **NOT EXPLICITLY CHECKED** - Relies on path construction assuming InsideScanner

3. **Practice runs**:
   - Pattern: Filename containing "practice" or "prac"
   - Example: `subjectBAP202_Voddball_session2_practice_*_cleaned.mat`
   - **Current Status**: ⚠️ **NOT CHECKED** - No explicit filter

4. **Session inference warnings**:
   - Pattern: Files where session is inferred (defaulted to 2)
   - Location: `parse_filename.m` lines 35-42
   - **Current Status**: ⚠️ **LENIENT** - Defaults to session 2 with warning, but should mark `session_inferred=TRUE`

## Required Fixes

### Fix 1: Add Explicit Location Check
**Location**: After line 98 in `BAP_Pupillometry_Pipeline.m`

Add filter to exclude files with "OutsideScanner" in path or filename:
```matlab
% Filter out OutsideScanner and practice runs
valid_files = true(length(cleaned_files), 1);
for i = 1:length(cleaned_files)
    filename = cleaned_files(i).name;
    full_path = fullfile(CONFIG.cleaned_dir, filename);
    
    % Check for OutsideScanner in path (if cleaned_dir structure preserves it)
    if contains(full_path, 'OutsideScanner') || contains(filename, 'OutsideScanner')
        valid_files(i) = false;
        fprintf('EXCLUDED (OutsideScanner): %s\n', filename);
        continue;
    end
    
    % Check for practice runs
    if contains(lower(filename), 'practice') || contains(lower(filename), 'prac')
        valid_files(i) = false;
        fprintf('EXCLUDED (practice): %s\n', filename);
        continue;
    end
end
cleaned_files = cleaned_files(valid_files);
```

### Fix 2: Track Session Inference
**Location**: `parse_filename.m`, lines 35-42

Add `session_inferred` flag:
```matlab
% LENIENT FIX: If session number is missing but we see "session" followed by "run",
% try to infer session from context (default to 2 or 3 if in valid range)
if isempty(session_match)
    % Check if we have "session" keyword followed by "run" (missing session number)
    if ~isempty(regexp(filename, 'session', 'ignorecase')) && ~isempty(regexp(filename, 'run\s*\d+', 'ignorecase'))
        % Try to extract from date pattern or default to 2 (most common)
        % Look for pattern like session_<number>_run or session_run
        % For now, default to session 2 if we can't find it
        session_match = {{'2'}};  % Default to session 2
        warning('LENIENT: Cannot parse session number from filename: %s. Defaulting to session 2.', filename);
        metadata.session_inferred = true;  % ADD THIS
    else
        warning('CRITICAL: Cannot parse session from filename: %s. Skipping file.', filename);
        metadata = [];
        return;
    end
else
    metadata.session_inferred = false;  % ADD THIS
end
```

### Fix 3: Create Excluded Files QC Output
**Location**: After `organize_files_by_session()` call (after line 108)

Add excluded files tracking:
```matlab
% Track excluded files
excluded_files = table();
excluded_files.filename = {};
excluded_files.reason = {};

% In parse_filename, when returning empty:
%   excluded_files = [excluded_files; table({filename}, {'session_not_2_or_3'}, 'VariableNames', {'filename', 'reason'})];
```

## Implementation Plan

### Step 1: Add Location/Practice Filter
- Modify `BAP_Pupillometry_Pipeline.m` after line 98
- Filter cleaned_files list before parsing
- Log excluded files to `qc_matlab_excluded_files.csv`

### Step 2: Add Session Inference Tracking
- Modify `parse_filename.m` to add `session_inferred` field
- Propagate to flat files (add column `session_inferred`)

### Step 3: Create Excluded Files QC
- Add `qc_matlab_excluded_files.csv` output in `write_qc_outputs.m`
- Columns: filename, reason, subject (if parseable), task (if parseable), session (if parseable), run (if parseable)

## Code Locations Summary

| Filter Type | Current Location | Status | Action Required |
|------------|------------------|--------|-----------------|
| Session 1 exclusion | `parse_filename.m:52-56` | ✅ PASS | None |
| InsideScanner check | `BAP_Pupillometry_Pipeline.m:418-424` | ⚠️ PARTIAL | Add explicit filename/path check |
| Practice run exclusion | None | ❌ MISSING | Add filter after line 98 |
| OutsideScanner exclusion | None | ❌ MISSING | Add filter after line 98 |
| Session inference tracking | `parse_filename.m:35-42` | ⚠️ PARTIAL | Add `session_inferred` flag |
| Excluded files QC | None | ❌ MISSING | Create `qc_matlab_excluded_files.csv` |

## Next Steps

1. **IMMEDIATE**: Add location/practice filter in main pipeline (after line 98)
2. **IMMEDIATE**: Add session_inferred tracking in parse_filename
3. **IMMEDIATE**: Create excluded files QC output
4. **VERIFY**: Test with known OutsideScanner/practice files to confirm exclusion

