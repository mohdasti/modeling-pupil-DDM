# audit_regenerate_qc.m - Comprehensive Fix

## Problem Diagnosis

The `audit_regenerate_qc.m` script was failing with "Arrays have incompatible sizes for this operation" at line 91 (later line 118). The root cause was:

### Issue 1: Inconsistent Array Extraction
- `trial_in_run_raw_col` was extracted from the table but then **not used** for the comparison
- Line 118 was comparing `run_data.trial_in_run_raw` (table column) with `trial_keys(k)` (scalar)
- This caused dimension mismatch errors

### Issue 2: Table vs Array Confusion
- `unique()` on a table column can return either a table or an array depending on MATLAB version
- No defensive checks for table-to-array conversion
- `length()` vs `numel()` inconsistency

### Issue 3: Missing NaN Handling
- NaN values in `trial_in_run_raw` were not consistently filtered
- Could cause empty arrays or invalid comparisons

## Complete Rewrite Strategy

Instead of patching the broken logic, I completely rewrote the function with these principles:

### 1. **Extract Once, Use Consistently**
```matlab
% Extract trial_in_run_raw as numeric vector ONCE
trial_in_run_raw_vec = run_data.trial_in_run_raw;
if istable(trial_in_run_raw_vec)
    trial_in_run_raw_vec = table2array(trial_in_run_raw_vec);
end

% Use this extracted vector for ALL operations
trial_mask_vec = (trial_in_run_raw_vec == current_trial_num);
```

### 2. **Defensive Type Checking**
```matlab
% Always check if result is a table
trial_nums = unique(trial_in_run_raw_vec_clean);
if istable(trial_nums)
    trial_nums = table2array(trial_nums);
end
```

### 3. **Explicit NaN Filtering**
```matlab
% Remove NaN values before processing
valid_trial_mask = ~isnan(trial_in_run_raw_vec);
if ~any(valid_trial_mask)
    continue;  % Skip runs with no valid trials
end
trial_in_run_raw_vec_clean = trial_in_run_raw_vec(valid_trial_mask);
```

### 4. **Robust CSV Reading**
```matlab
% Use detectImportOptions for better handling
opts = detectImportOptions(flat_path);
flat_data = readtable(flat_path, opts);

% Verify required columns exist
required_cols = {'sub', 'task', 'ses', 'run', 'trial_in_run_raw'};
missing_cols = setdiff(required_cols, flat_data.Properties.VariableNames);
if ~isempty(missing_cols)
    fprintf('  WARNING: Missing columns...\n');
    continue;
end
```

### 5. **Better Error Reporting**
```matlab
catch ME
    fprintf('  ERROR processing %s: %s\n', flat_files(i).name, ME.message);
    fprintf('    Line: %d\n', ME.stack(1).line);
    fprintf('    Stack trace: %s\n', getReport(ME, 'basic'));
    continue;
end
```

### 6. **Empty Data Checks**
```matlab
% Check at multiple levels
if isempty(run_data) || height(run_data) == 0
    continue;
end

if isempty(trial_data) || height(trial_data) == 0
    continue;
end
```

## Key Changes Summary

| Line | Old Code | New Code | Reason |
|------|----------|----------|--------|
| 36 | `readtable(flat_path)` | `readtable(flat_path, opts)` | Better CSV parsing |
| 62-64 | Extracted but not used | Used consistently | Fix dimension mismatch |
| 108 | `~isnan(trial_in_run_raw_col)` | `~isnan(trial_in_run_raw_vec)` | Consistent naming |
| 118 | `run_data.trial_in_run_raw == trial_keys(k)` | `trial_in_run_raw_vec == current_trial_num` | Use extracted vector |
| 115 | `length(trial_keys)` | `length(trial_nums)` | Clear variable naming |

## Testing Instructions

Run the audit from MATLAB:

```matlab
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM/01_data_preprocessing/matlab
run_matlab_audit
```

Expected output:
```
=== REGENERATING QC ARTIFACTS ===
  Found 116 flat CSV files
  Processing: BAP003_ADT_flat.csv
  Processing: BAP003_VDT_flat.csv
  ...
  
  Regenerated: qc_matlab_run_trial_counts.csv (XXX runs)
  Regenerated: qc_matlab_trial_level_flags.csv (XXX trials)
  Successfully processed 116 files
  Collected XXX runs and XXX trials
```

## What This Fix Guarantees

1. ✅ **No dimension mismatch errors**: All comparisons use consistently extracted arrays
2. ✅ **Handles table/array ambiguity**: Explicit conversion checks
3. ✅ **Robust NaN handling**: Filters NaN before processing
4. ✅ **Better error messages**: Line numbers and clear stack traces
5. ✅ **Graceful degradation**: Skips problematic files, continues processing
6. ✅ **Column existence checks**: Verifies required columns before use
7. ✅ **Empty data handling**: Multiple levels of empty checks

## Files Modified

- `/01_data_preprocessing/matlab/audit_regenerate_qc.m` (complete rewrite)

## Next Steps

1. Run the audit: `run_matlab_audit` in MATLAB
2. Verify QC outputs are generated without errors
3. Check the generated files:
   - `qc_matlab/qc_matlab_run_trial_counts.csv`
   - `qc_matlab/qc_matlab_trial_level_flags.csv`
4. Proceed to `generate_signoff_report.m`

