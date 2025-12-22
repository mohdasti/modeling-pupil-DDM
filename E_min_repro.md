# E) MINIMAL REPRO RUN

## Test Case: BAP202 Session 2 Run 4

### Expected Input Files

1. **Cleaned file**:
   ```
   BAP_cleaned/subjectBAP202_Voddball_session2_run4_12_20_13_11_eyetrack_cleaned.mat
   ```

2. **Raw eyetrack file**:
   ```
   data/sub-BAP202/ses-2/InsideScanner/subjectBAP202_Voddball_session2_run4_12_20_13_11_eyetrack.mat
   ```

3. **logP file**:
   ```
   data/sub-BAP202/ses-2/InsideScanner/subjectBAP202_Voddball_session2_run4_12_20_13_11_logP.txt
   ```

## Execution Steps

### Step 1: Configure Paths
Edit `BAP_Pupillometry_Pipeline.m` lines 8-10:
```matlab
CONFIG.cleaned_dir = '/path/to/BAP_cleaned';
CONFIG.raw_dir = '/path/to/data';
CONFIG.output_dir = '/path/to/BAP_processed';
```

### Step 2: Run Pipeline
```matlab
% In MATLAB
cd('01_data_preprocessing/matlab');
BAP_Pupillometry_Pipeline();
```

### Step 3: Verify Outputs

#### Expected Output Files (in build directory)
1. **Flat file**: `BAP202_VDT_flat.csv`
   - Should contain ~30 trials (one run)
   - Columns: sub, task, ses, run, trial_index, trial_in_run_raw, time, pupil, segmentation_source, etc.

2. **QC files** (in `build_*/qc_matlab/`):
   - `qc_matlab_run_trial_counts.csv`: 1 row for BAP202-VDT-ses2-run4
   - `qc_matlab_trial_level_flags.csv`: ~30 rows (one per trial)
   - `falsification_validation_summary.md`: Summary report

3. **Manifest**: `manifest_runs.csv`
   - 1 row for BAP202-VDT-ses2-run4
   - Should show `segmentation_source` = "event_code" or "logP"
   - Should show `n_trials_extracted` = 28-30

## Validation Checks

### Check 1: Trial Count
```matlab
% Load flat file
data = readtable('BAP_processed/build_*/BAP202_VDT_flat.csv');

% Verify trial count
unique_trials = unique(data.trial_index);
fprintf('Number of trials: %d\n', length(unique_trials));
% Expected: 28-30 trials
```

### Check 2: Segmentation Source
```matlab
% Check segmentation source
unique(data.segmentation_source)
% Expected: {'event_code'} or {'logP'}
```

### Check 3: QC Flags
```matlab
% Load QC file
qc = readtable('BAP_processed/build_*/qc_matlab/qc_matlab_run_trial_counts.csv');

% Verify run processed
fprintf('Runs processed: %d\n', height(qc));
% Expected: 1

% Check segmentation
fprintf('Segmentation source: %s\n', qc.segmentation_source{1});
% Expected: 'event_code' or 'logP'

% Check trial count
fprintf('Trials extracted: %d\n', qc.n_trials_extracted(1));
% Expected: 28-30
```

### Check 4: Trial-Level Flags
```matlab
% Load trial flags
flags = readtable('BAP_processed/build_*/qc_matlab/qc_matlab_trial_level_flags.csv');

% Verify trial count
fprintf('Trials in flags: %d\n', height(flags));
% Expected: 28-30

% Check for timebase bugs
fprintf('Timebase bugs: %d\n', sum(flags.any_timebase_bug));
% Expected: 0

% Check window OOB
fprintf('Window OOB trials: %d\n', sum(flags.window_oob));
% Expected: 0
```

### Check 5: Falsification Summary
```matlab
% Read summary
fid = fopen('BAP_processed/build_*/qc_matlab/falsification_validation_summary.md', 'r');
summary = fread(fid, '*char')';
fclose(fid);

% Check for failures
if contains(summary, '❌')
    fprintf('WARNING: Failures detected in falsification summary\n');
else
    fprintf('PASS: No failures in falsification summary\n');
end
```

## Expected Console Output

```
=== BAP PUPILLOMETRY PROCESSING PIPELINE - FULLY CORRECTED ===

BUILD_ID: 20250101_120000
Build directory: /path/to/BAP_processed/build_20250101_120000
Cleaned files directory: /path/to/BAP_cleaned
Raw files directory: /path/to/data
Output directory: /path/to/BAP_processed/build_20250101_120000

Found 1 cleaned files
Organized into 1 subject/session groups

=== PROCESSING BAP202 - VDT (Session 2) ===
Files: 1 runs
  Processing Run 4: subjectBAP202_Voddball_session2_run4_12_20_13_11_eyetrack_cleaned.mat
    Loaded logP: 30 trials
    logP plausibility check PASSED
    Timebase conversion: method=already_ptb, offset=0.000, confidence=high
    Event-code segmentation: 30 trials (median residual vs logP: 0.008 s)
    Using event_code segmentation: 30 trials
    SUCCESS: 30 trials processed
    SANITY CHECK:
      - Detected trials: 30
      - Exported trials: 30
      - Hard skipped (min_samples): 0
      - trial_in_run_raw range: 1 to 30
      - QC fail baseline: 0 (0.0%)
      - QC fail overall: 0 (0.0%)

SUCCESS: 30 trials processed

=== SAVING RESULTS ===
Manifest written: 1 runs tracked
Saved BAP202_VDT_flat.csv: 30 trials across 1 runs
  Saved: qc_matlab_run_trial_counts.csv (1 runs)
  Saved: qc_matlab_skip_reasons.csv (0 skipped runs)
  Saved: qc_matlab_trial_level_flags.csv (30 trials)
Summary saved to: .../falsification_validation_summary.md

=== PROCESSING COMPLETE ===
BUILD_ID: 20250101_120000
All outputs saved to: /path/to/BAP_processed/build_20250101_120000
```

## Troubleshooting

### Issue: "No cleaned files found"
**Solution**: Check `CONFIG.cleaned_dir` path is correct

### Issue: "Raw file not found"
**Solution**: Check `CONFIG.raw_dir` path and file structure matches expected:
```
data/sub-BAP202/ses-2/InsideScanner/subjectBAP202_Voddball_session2_run4_*_eyetrack.mat
```

### Issue: "logP file not found"
**Solution**: Check logP file exists in same directory as raw file

### Issue: "No trial anchors found"
**Solution**: Check event markers in raw file or logP file validity

### Issue: "Timebase bug detected"
**Solution**: Check timebase conversion diagnostics in QC file

## Success Criteria

✅ **PASS** if:
1. Flat file created with 28-30 trials
2. QC files created with 1 run entry
3. No timebase_bug flags
4. Segmentation source is "event_code" or "logP" (not "failed")
5. Falsification summary shows no critical failures

❌ **FAIL** if:
1. No output files created
2. Trial count < 20 or > 35
3. timebase_bug = true
4. Segmentation source = "failed"
5. Falsification summary shows failures

