# Blocking Fixes Implementation Plan

## Status: ❌ **DO NOT PUSH YET**

The other LLM's assessment is **100% correct**. These 4 blocking issues must be fixed before commit:

1. **D) Hard-coded paths** (lines 8-10) - ❌ FAIL
2. **B) Missing contamination filters** (after line 98) - ❌ FAIL  
3. **C) Residuals not persisted** (lines 705-710) - ❌ FAIL
4. **F) .gitignore missing MATLAB exclusions** - ❌ FAIL

---

## Quick Fix Checklist (Do These Now)

### ✅ Fix 1: Path Configuration (D) - 5 minutes

**File**: `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m`

**Replace lines 6-10** with:
```matlab
%% Configuration - EDIT THESE PATHS FOR YOUR SYSTEM
CONFIG = struct();

% OPTION 1: Use absolute paths (edit these for your system)
CONFIG.cleaned_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned';
CONFIG.raw_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data';
CONFIG.output_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed';

% OPTION 2: Use relative paths from script location (uncomment to use)
% [script_dir, ~, ~] = fileparts(mfilename('fullpath'));
% project_root = fullfile(script_dir, '..', '..');  % Go up to repo root
% CONFIG.cleaned_dir = fullfile(project_root, 'data', 'BAP_cleaned');
% CONFIG.raw_dir = fullfile(project_root, 'data', 'raw');
% CONFIG.output_dir = fullfile(project_root, 'data', 'BAP_processed');

% Validate paths exist
if ~exist(CONFIG.cleaned_dir, 'dir')
    error('CONFIG.cleaned_dir does not exist: %s\nEdit paths at top of file.', CONFIG.cleaned_dir);
end
if ~exist(CONFIG.raw_dir, 'dir')
    error('CONFIG.raw_dir does not exist: %s\nEdit paths at top of file.', CONFIG.raw_dir);
end
```

**Pass condition**: Pipeline can run by editing one config block only.

---

### ✅ Fix 2: Contamination Filter (B) - 10 minutes

**File**: `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m`

**Add after line 98** (after `cleaned_files = dir(...)`):
```matlab
% Find all cleaned files
cleaned_files = dir(fullfile(CONFIG.cleaned_dir, '*_cleaned.mat'));
fprintf('Found %d cleaned files\n', length(cleaned_files));

% CONTAMINATION GUARD: Filter out OutsideScanner, practice, and invalid files
excluded_files = table();
excluded_files.filename = {};
excluded_files.reason = {};

valid_files = true(length(cleaned_files), 1);
for i = 1:length(cleaned_files)
    filename = cleaned_files(i).name;
    full_path = fullfile(CONFIG.cleaned_dir, filename);
    
    % Check for OutsideScanner
    if contains(full_path, 'OutsideScanner') || contains(filename, 'OutsideScanner')
        valid_files(i) = false;
        excluded_files = [excluded_files; table({filename}, {'OutsideScanner'}, 'VariableNames', {'filename', 'reason'})];
        fprintf('EXCLUDED (OutsideScanner): %s\n', filename);
        continue;
    end
    
    % Check for practice runs
    if contains(lower(filename), 'practice') || contains(lower(filename), 'prac')
        valid_files(i) = false;
        excluded_files = [excluded_files; table({filename}, {'practice'}, 'VariableNames', {'filename', 'reason'})];
        fprintf('EXCLUDED (practice): %s\n', filename);
        continue;
    end
end

% Apply filter
cleaned_files = cleaned_files(valid_files);
fprintf('After contamination filter: %d files remaining\n', length(cleaned_files));
if height(excluded_files) > 0
    fprintf('Excluded %d files (see qc_matlab_excluded_files.csv)\n', height(excluded_files));
end
```

**Also update `write_qc_outputs.m`** to write excluded files:
```matlab
% After line 167, add:
if exist('excluded_files', 'var') && ~isempty(excluded_files)
    excluded_path = fullfile(qc_dir, 'qc_matlab_excluded_files.csv');
    writetable(excluded_files, excluded_path);
    fprintf('  Saved: qc_matlab_excluded_files.csv (%d excluded files)\n', height(excluded_files));
end
```

**Pass condition**: Can print `n_files_ok`, `n_files_excluded` with reasons.

---

### ✅ Fix 3: Store Residuals (C) - 10 minutes

**File**: `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m`

**Add after line 710** (after `median_residual = median(residuals);`):
```matlab
            median_residual = median(residuals);
            
            % FALSIFICATION: Store residuals for QC output
            run_quality.falsification_residuals = residuals;
            run_quality.residual_median_abs = median(abs(residuals));
            run_quality.residual_max_abs = max(abs(residuals));
            if length(residuals) > 1
                run_quality.residual_iqr = iqr(residuals);
            else
                run_quality.residual_iqr = 0;
            end
            run_quality.flagged_falsification = (run_quality.residual_max_abs > 0.05) || ...
                                               (run_quality.residual_median_abs > 0.02);
            run_quality.n_event_anchors = length(squeeze_onsets_event);
            run_quality.n_logP_anchors = length(logP_data.trial_st);
            run_quality.segmentation_source_for_residuals = 'both_available';
```

**Also add to `write_qc_outputs.m`** (after line 176, before `end`):
```matlab
%% D) qc_matlab_falsification_residuals_by_run.csv
falsification_residuals = table();

for j = 1:length(all_run_qc_stats)
    run_qc = all_run_qc_stats{j};
    
    if isfield(run_qc, 'falsification_residuals') && ~isempty(run_qc.falsification_residuals)
        row = table(...
            {run_qc.subject}, {run_qc.task}, {run_qc.session}, run_qc.run, ...
            {run_qc.segmentation_source_for_residuals}, ...
            run_qc.n_trials_exported, ...
            run_qc.residual_median_abs, ...
            run_qc.residual_max_abs, ...
            run_qc.residual_iqr, ...
            run_qc.flagged_falsification, ...
            run_qc.n_event_anchors, ...
            run_qc.n_logP_anchors, ...
            'VariableNames', {'subject', 'task', 'session', 'run', ...
            'segmentation_source', 'n_trials', 'residual_median_abs', ...
            'residual_max_abs', 'residual_iqr', 'flagged_falsification', ...
            'n_event_anchors', 'n_logP_anchors'});
        falsification_residuals = [falsification_residuals; row];
    end
end

if ~isempty(falsification_residuals)
    writetable(falsification_residuals, fullfile(qc_dir, 'qc_matlab_falsification_residuals_by_run.csv'));
    fprintf('  Saved: qc_matlab_falsification_residuals_by_run.csv (%d runs)\n', height(falsification_residuals));
end
```

**Pass condition**: `qc_matlab_falsification_residuals_by_run.csv` exists with residual stats.

---

### ✅ Fix 4: .gitignore Updates (F) - 2 minutes

**File**: `.gitignore`

**Add at end of file**:
```gitignore
# MATLAB-specific data directories
01_data_preprocessing/matlab/paths_config.m
BAP_cleaned/
BAP_processed/
data/raw/
data/BAP_cleaned/
data/BAP_processed/
build_*/
```

**Pass condition**: `git status` doesn't show any data files after running pipeline.

---

## Verification Commands

After fixes, run these:

```bash
# 1. Check no hard-coded paths in committed code
grep -r "/Users/" 01_data_preprocessing/matlab/ --include="*.m" | grep -v ".example"

# 2. Check no large files staged
git ls-files | xargs ls -lh 2>/dev/null | awk '$5 ~ /M/ {print $5, $9}'

# 3. Check .gitignore works
git status | grep -E "\.(mat|csv)$" | head -5
```

---

## Recommended Commit Sequence

### Commit 1: "Portability + hygiene"
```
feat(matlab): Make paths configurable and update .gitignore

- Add configurable paths with clear instructions
- Add path validation
- Update .gitignore to exclude MATLAB data directories
- Add excluded files QC output

Fixes: D (paths), F (.gitignore)
```

### Commit 2: "Correctness guards + falsification QC"
```
feat(matlab): Add contamination filters and falsification QC

- Add OutsideScanner/practice file filters
- Store and export residual validation stats
- Create qc_matlab_falsification_residuals_by_run.csv
- Create qc_matlab_excluded_files.csv

Fixes: B (contamination), C (falsification)
```

---

## Time Estimate

- **Fix 1 (Paths)**: 5 minutes
- **Fix 2 (Contamination)**: 10 minutes  
- **Fix 3 (Residuals)**: 10 minutes
- **Fix 4 (.gitignore)**: 2 minutes
- **Testing**: 10 minutes

**Total**: ~40 minutes to greenlight

---

## After Fixes: Greenlight Checklist

- [ ] No hard-coded `/Users/...` paths in committed code
- [ ] Pipeline runs with configurable paths
- [ ] Contamination filter excludes OutsideScanner/practice
- [ ] `qc_matlab_excluded_files.csv` created
- [ ] `qc_matlab_falsification_residuals_by_run.csv` created
- [ ] `.gitignore` excludes data directories
- [ ] `git status` shows no data files

**Once all checked**: ✅ **READY TO PUSH**

