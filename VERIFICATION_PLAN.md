# Verification Plan: MATLAB Critical Fixes

After running the fixed MATLAB pipeline, verify the following:

---

## Step 1: Check One Flat File

**In MATLAB or R:**
```matlab
% MATLAB
data = readtable('BAP_processed/BAP003_ADT_flat.csv');
fprintf('Columns: %s\n', strjoin(data.Properties.VariableNames, ', '));
fprintf('trial_in_run_raw range: %d to %d\n', min(data.trial_in_run_raw), max(data.trial_in_run_raw));
fprintf('QC fail baseline: %d trials\n', sum(data.qc_fail_baseline));
fprintf('QC fail overall: %d trials\n', sum(data.qc_fail_overall));
```

**Expected:**
- ✓ `trial_in_run_raw` column exists
- ✓ `trial_in_run_raw` spans 1..30 for each run (not renumbered)
- ✓ `qc_fail_baseline` and `qc_fail_overall` columns exist
- ✓ Many trials may have QC flags = true (expected with goggles)

---

## Step 2: Check QC Summary Tables

**In MATLAB:**
```matlab
% Run-level summary
qc_run = readtable('BAP_processed/qc_matlab_trial_yield_summary.csv');
fprintf('Run-level QC summary:\n');
disp(qc_run(1:5, :));  % Show first 5 runs

% Session-level summary
qc_session = readtable('BAP_processed/qc_matlab_session_yield_summary.csv');
fprintf('Session-level QC summary:\n');
disp(qc_session(1:3, :));  % Show first 3 sessions
```

**Expected:**
- ✓ `n_squeeze_onsets_detected` ≈ 30 per run
- ✓ `n_trials_exported` ≈ 30 per run (all detected, unless < min_samples)
- ✓ `n_trials_hard_skipped_min_samples` is small (only impossible trials)
- ✓ `n_qc_fail_baseline` and `n_qc_fail_overall` are > 0 (many trials fail QC, but are still exported)

---

## Step 3: Verify R Merger Alignment

**In R:**
```r
# Load merged file
merged <- read_csv("BAP_processed/BAP003_ADT_flat_merged.csv", n_max = 1000)

# Check that trial_in_run_raw aligns with behavioral trial numbers
# (behavioral trial should match trial_in_run_raw for correct alignment)
print(table(merged$trial_in_run_raw, merged$behavioral_trial, useNA = "ifany"))
```

**Expected:**
- ✓ `trial_in_run_raw` aligns with behavioral trial numbers (diagonal pattern)
- ✓ No systematic misalignment

---

## Step 4: Check Sanity Check Printouts

**Review MATLAB console output:**
- ✓ Each run shows: detected trials, exported trials, `trial_in_run_raw` range
- ✓ Warnings if detected trials are not near 30
- ✓ QC fail counts and percentages

---

## Success Criteria

✅ **All checks pass:**
1. `trial_in_run_raw` preserves original index (1..30 per run)
2. All detected trials are exported (unless < min_samples)
3. QC flags are present and many trials fail (expected)
4. R merger aligns correctly using `trial_in_run_raw`
5. QC summary tables show expected statistics

---

*Verification plan for MATLAB critical fixes*

