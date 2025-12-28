# D) DIRECTORY + PATH SANITY

## Current Path Configuration

### Hard-Coded Paths (Lines 8-10)
**Location**: `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m`, lines 8-10

```matlab
CONFIG.cleaned_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned';
CONFIG.raw_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data';
CONFIG.output_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed';
```

**Status**: ❌ **FAIL** - Hard-coded to user-specific path (`/Users/mohdasti/...`)

### Path Usage Throughout Pipeline

| Path Variable | Usage Location | Current Value | Portability |
|---------------|----------------|---------------|-------------|
| `CONFIG.cleaned_dir` | Line 98: `dir(fullfile(CONFIG.cleaned_dir, '*_cleaned.mat'))` | Hard-coded absolute | ❌ Not portable |
| `CONFIG.raw_dir` | Line 418-424: Raw file and logP path construction | Hard-coded absolute | ❌ Not portable |
| `CONFIG.output_dir` | Line 74-76: Base output directory creation | Hard-coded absolute | ❌ Not portable |
| `CONFIG.build_dir` | Line 79: `create_build_directory(CONFIG.output_dir)` | Derived from output_dir | ⚠️ Depends on output_dir |
| `CONFIG.qc_dir` | Line 80: `fullfile(CONFIG.build_dir, 'qc_matlab')` | Derived from build_dir | ⚠️ Depends on build_dir |

### Expected Directory Structure

#### Input Directories
```
CONFIG.cleaned_dir/
  ├─ subjectBAP202_Voddball_session2_run1_*_cleaned.mat
  ├─ subjectBAP202_Voddball_session2_run2_*_cleaned.mat
  └─ ...

CONFIG.raw_dir/
  ├─ sub-BAP202/
  │   ├─ ses-2/
  │   │   └─ InsideScanner/
  │   │       ├─ subjectBAP202_Voddball_session2_run1_*_eyetrack.mat
  │   │       ├─ subjectBAP202_Voddball_session2_run1_*_logP.txt
  │   │       └─ ...
  │   └─ ses-3/
  │       └─ InsideScanner/
  │           └─ ...
  └─ sub-BAP203/
      └─ ...
```

#### Output Directories
```
CONFIG.output_dir/
  └─ build_YYYYMMDD_HHMMSS/
      ├─ BAP202_ADT_flat.csv
      ├─ BAP202_VDT_flat.csv
      ├─ manifest_runs.csv
      ├─ BAP_pupillometry_data_quality_report.csv
      ├─ BAP_pupillometry_data_quality_detailed.txt
      └─ qc_matlab/
          ├─ qc_matlab_run_trial_counts.csv
          ├─ qc_matlab_skip_reasons.csv
          ├─ qc_matlab_trial_level_flags.csv
          └─ falsification_validation_summary.md
```

## Portability Issues

### Issue 1: Hard-Coded User Path
**Problem**: Paths are hard-coded to `/Users/mohdasti/Documents/LC-BAP/...`

**Impact**: 
- Pipeline will fail on any other machine
- Cannot be committed to version control without breaking
- No way to configure for different environments

### Issue 2: No Project Root Resolution
**Problem**: No mechanism to resolve paths relative to project root

**Impact**:
- Cannot use relative paths
- Cannot adapt to different directory structures

### Issue 3: No Configuration File
**Problem**: No external config file (like `config/paths_config.R.example` for R)

**Impact**:
- Users must edit MATLAB code to change paths
- Risk of committing personal paths

## Required Fixes

### Fix 1: Add CONFIG Section at Top with Clear Instructions
**Location**: `BAP_Pupillometry_Pipeline.m`, lines 6-12

**Implementation**:
```matlab
%% Configuration - EDIT THESE PATHS FOR YOUR SYSTEM
CONFIG = struct();

% OPTION 1: Use absolute paths (edit these)
CONFIG.cleaned_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned';
CONFIG.raw_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data';
CONFIG.output_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed';

% OPTION 2: Use relative paths from MATLAB script location (recommended)
% [script_dir, ~, ~] = fileparts(mfilename('fullpath'));
% project_root = fullfile(script_dir, '..', '..');  % Go up to repo root
% CONFIG.cleaned_dir = fullfile(project_root, 'data', 'BAP_cleaned');
% CONFIG.raw_dir = fullfile(project_root, 'data', 'raw');
% CONFIG.output_dir = fullfile(project_root, 'data', 'BAP_processed');

% Validate paths exist
if ~exist(CONFIG.cleaned_dir, 'dir')
    error('CONFIG.cleaned_dir does not exist: %s', CONFIG.cleaned_dir);
end
if ~exist(CONFIG.raw_dir, 'dir')
    error('CONFIG.raw_dir does not exist: %s', CONFIG.raw_dir);
end
```

### Fix 2: Create paths_config.m.example
**Location**: `config/paths_config.m.example`

**Content**:
```matlab
% MATLAB Paths Configuration
% Copy this file to paths_config.m and edit paths for your system

function CONFIG = paths_config()
    CONFIG = struct();
    
    % Project root (adjust to your system)
    project_root = '/path/to/modeling-pupil-DDM';
    
    % Input directories
    CONFIG.cleaned_dir = fullfile(project_root, 'data', 'BAP_cleaned');
    CONFIG.raw_dir = fullfile(project_root, 'data', 'raw');
    
    % Output directory
    CONFIG.output_dir = fullfile(project_root, 'data', 'BAP_processed');
    
    % Validate
    if ~exist(CONFIG.cleaned_dir, 'dir')
        warning('CONFIG.cleaned_dir does not exist: %s', CONFIG.cleaned_dir);
    end
    if ~exist(CONFIG.raw_dir, 'dir')
        warning('CONFIG.raw_dir does not exist: %s', CONFIG.raw_dir);
    end
end
```

**Then modify main pipeline**:
```matlab
%% Configuration
% Try to load from config file, fall back to defaults
if exist('paths_config.m', 'file')
    CONFIG = paths_config();
else
    % Default paths (edit these if no config file)
    CONFIG = struct();
    CONFIG.cleaned_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned';
    CONFIG.raw_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data';
    CONFIG.output_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed';
end
```

### Fix 3: Add Path Validation
**Location**: After CONFIG definition, before processing

**Implementation**:
```matlab
% Validate all paths exist
required_paths = {'cleaned_dir', 'raw_dir', 'output_dir'};
for i = 1:length(required_paths)
    path_field = required_paths{i};
    if ~isfield(CONFIG, path_field) || isempty(CONFIG.(path_field))
        error('CONFIG.%s is not set', path_field);
    end
    if ~exist(CONFIG.(path_field), 'dir')
        error('CONFIG.%s does not exist: %s', path_field, CONFIG.(path_field));
    end
end

fprintf('Path Configuration:\n');
fprintf('  cleaned_dir: %s\n', CONFIG.cleaned_dir);
fprintf('  raw_dir: %s\n', CONFIG.raw_dir);
fprintf('  output_dir: %s\n', CONFIG.output_dir);
```

## Verification Checklist

- [ ] CONFIG section clearly labeled at top of file
- [ ] Paths can be edited without modifying code logic
- [ ] Path validation checks exist
- [ ] Example config file created (`config/paths_config.m.example`)
- [ ] .gitignore excludes `paths_config.m` (user-specific)
- [ ] Documentation explains how to set paths

## Current Status Summary

| Component | Status | Portability | Action Required |
|-----------|--------|-------------|-----------------|
| CONFIG.cleaned_dir | ❌ Hard-coded | Not portable | Add config file or relative path option |
| CONFIG.raw_dir | ❌ Hard-coded | Not portable | Add config file or relative path option |
| CONFIG.output_dir | ❌ Hard-coded | Not portable | Add config file or relative path option |
| Path validation | ❌ Missing | N/A | Add validation checks |
| Config file | ❌ Missing | N/A | Create `paths_config.m.example` |

## Next Steps

1. **IMMEDIATE**: Add clear CONFIG section with instructions at top of `BAP_Pupillometry_Pipeline.m`
2. **IMMEDIATE**: Create `config/paths_config.m.example`
3. **IMMEDIATE**: Add path validation
4. **FOLLOW-UP**: Update README with path configuration instructions

