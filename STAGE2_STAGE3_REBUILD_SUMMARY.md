# Stage 2 (R) and Stage 3 (QMD) Pipeline Rebuild Summary

## Overview

This document summarizes the rebuild of Stage 2 (R) and Stage 3 (QMD) of the pupillometry pipeline to:
1. Use MATLAB flat files (`*_flat.csv`) as the ONLY pupil source
2. Merge pupil ↔ behavioral using robust trial keys that preserve session and run
3. Add hard falsification checks to detect wrong alignment
4. Update `generate_pupil_data_report.qmd` to reflect new MATLAB outputs
5. Ensure no session-1/practice/outside-scanner contamination

## Files Created/Modified

### New Files

1. **`01_data_preprocessing/r/rebuild_pupil_pipeline_stage2.R`**
   - Complete Stage 2 rebuild script
   - Implements all steps A-G as specified
   - Handles schema normalization, trial-level aggregation, merge, falsification checks, and final report generation

### Modified Files

1. **`02_pupillometry_analysis/generate_pupil_data_report.qmd`**
   - Updated to detect and use new Stage 2 pipeline outputs
   - Prefers new pipeline outputs when available, falls back to legacy approach
   - Added final readiness report section

## Pipeline Steps Implemented

### STEP A: Discovery + Schema Normalization

- Inspects representative `*_flat.csv` file to identify column names
- Normalizes to standard columns: `subject_id`, `task`, `session`, `run`, `trial_in_run`
- Creates `trial_uid = "{subject_id}:{task}:ses{session}:run{run}:t{trial_in_run}"`
- Validates schema: `session ∈ {2,3}`, `run ∈ {1..5}`, `trial_in_run ∈ {1..30}`
- Exports violations to `data/qc/merge_audit/pupil_schema_violations.csv`

### STEP B: Build Trial-Level Pupil Summary

- Aggregates sample-level pupil flats to trial level
- Computes:
  - `n_samples`: Number of samples per trial
  - Window validity proportions (baseline, cognitive, stimlocked if available)
  - `baseline_mean`: Pre-event baseline
  - `total_auc`: Global window AUC
  - `cog_auc_fixed`: Fixed post-target window AUC
- Preserves `segmentation_source` and `window_oob` flags
- Exports to:
  - `data/intermediate/pupil_TRIALLEVEL_from_matlab.csv`
  - `data/intermediate/pupil_TRIALLEVEL_from_matlab.parquet`

### STEP C: Behavioral Normalization

- Loads behavioral trialdata from `bap_beh_trialdata_v2.csv`
- Normalizes columns to: `subject_id`, `task`, `session`, `run`, `trial_in_run`
- Maps behavioral variables:
  - `intensity` (continuous from `stim_level_index`)
  - `effort` (Low/High from `grip_targ_prop_mvc`)
  - `choice`, `correct`, `rt`
- Filters to sessions 2-3 and tasks ADT/VDT only
- Exports to: `data/intermediate/behavior_TRIALLEVEL_normalized.csv`

### STEP D: Merge + Merge QC

- Inner join on `(subject_id, task, session, run, trial_in_run)`
- Computes anti-joins:
  - `pupil_no_behavior`: Trials in pupil but not behavioral
  - `behavior_no_pupil`: Trials in behavioral but not pupil
- Exports QC tables:
  - `data/qc/merge_audit/match_rate_by_subject_task_session_run.csv`
  - `data/qc/merge_audit/pupil_no_behavior.csv`
  - `data/qc/merge_audit/behavior_no_pupil.csv`
  - `data/qc/merge_audit/duplicate_trial_uid_checks.csv`
  - `data/qc/merge_audit/design_expected_vs_observed.csv`

### STEP E: Hard Falsification Checks

1. **RT-window plausibility**:
   - Verifies RT falls inside [0.2, 3.0] sec
   - Flags runs with >10% implausible RTs
   - Exports: `data/qc/merge_audit/rt_plausibility_by_run.csv`

2. **Intensity completeness**:
   - Checks distribution of intensity values is non-missing and non-degenerate
   - Exports: `data/qc/merge_audit/intensity_integrity_by_run.csv`

- Runs failing falsification checks are marked `run_status="FAIL_ALIGNMENT"` and excluded from analysis-ready exports

### STEP F: Update QMD

- Updated `generate_pupil_data_report.qmd` to:
  - Detect new pipeline outputs
  - Prefer new outputs when available
  - Implement analysis-specific gates:
    - `ch2_primary`: `baseline_valid>=0.60 & cog_valid>=0.60`
    - `ch2_sens_050`, `ch2_sens_070` variants
    - `ch3_ddm_ready`: Behavioral RT filter + minimal pupil tier
  - Add missingness-as-outcome tables
  - Export final datasets:
    - `data/analysis_ready/BAP_TRIALLEVEL.csv` (+ parquet)
    - `data/analysis_ready/BAP_TRIALLEVEL_DDM_READY.csv`

### STEP G: Final Report

- Generates comprehensive PASS/FAIL summary:
  - Contamination checks (should be none)
  - Alignment failures detected
  - Final N subjects, trials (overall and by task)
  - Trial counts retained under each gate tier
  - Exact paths of final outputs
- Exports: `data/qc/analysis_ready_audit/final_readiness_report.md`

## Usage

### Running Stage 2 Rebuild

```r
# Set environment variables (optional, defaults provided)
Sys.setenv(BAP_PROCESSED_DIR = "/path/to/BAP_processed")
Sys.setenv(BAP_BEHAVIORAL_FILE = "/path/to/bap_beh_trialdata_v2.csv")

# Run the rebuild script
source("01_data_preprocessing/r/rebuild_pupil_pipeline_stage2.R")
```

### Outputs

The script generates:

1. **Intermediate files**:
   - `data/intermediate/pupil_TRIALLEVEL_from_matlab.csv`
   - `data/intermediate/behavior_TRIALLEVEL_normalized.csv`

2. **Analysis-ready files**:
   - `data/analysis_ready/BAP_TRIALLEVEL.csv`
   - `data/analysis_ready/BAP_TRIALLEVEL_DDM_READY.csv`

3. **QC artifacts**:
   - `data/qc/merge_audit/*.csv` (merge diagnostics, falsification checks)
   - `data/qc/analysis_ready_audit/final_readiness_report.md`

### Rendering QMD Report

```bash
quarto render 02_pupillometry_analysis/generate_pupil_data_report.qmd
```

The QMD will automatically detect and use new pipeline outputs if available.

## Key Features

### Contamination Prevention

- Schema validation ensures `session ∈ {2,3}` (no session 1)
- Filters out practice/outside-scanner data at MATLAB stage (preserved in R)
- All violations logged to `pupil_schema_violations.csv`

### Robust Merge Keys

- Uses `(subject_id, task, session, run, trial_in_run)` for merging
- Preserves both session and run (never overwrites run with session)
- Creates `trial_uid` for unique identification

### Hard Falsification Checks

- RT plausibility: Catches alignment errors even if trial counts look correct
- Intensity completeness: Detects degenerate or missing intensity distributions
- Failed runs excluded from analysis-ready exports

### Analysis-Ready Gates

- **ch2_primary**: `baseline_valid>=0.60 & cog_valid>=0.60`
- **ch2_sens_050**: `baseline_valid>=0.50 & cog_valid>=0.50`
- **ch2_sens_070**: `baseline_valid>=0.70 & cog_valid>=0.70`
- **ch3_ddm_ready**: RT filter + minimal pupil tier

## Validation

The pipeline includes comprehensive validation:

1. **Schema validation**: All rows must pass session/run/trial constraints
2. **Merge validation**: Match rates computed and logged
3. **Falsification checks**: RT and intensity integrity verified
4. **Gate validation**: Pass rates computed and reported

## Next Steps

1. Run `rebuild_pupil_pipeline_stage2.R` to generate new pipeline outputs
2. Review QC artifacts in `data/qc/merge_audit/`
3. Check `final_readiness_report.md` for overall status
4. Render QMD report to see comprehensive analysis
5. Use `BAP_TRIALLEVEL.csv` or `BAP_TRIALLEVEL_DDM_READY.csv` for downstream analysis

## Notes

- The R script does NOT edit MATLAB code (as requested)
- Focus is on R + QMD stages only
- All paths are configurable via environment variables
- Script handles missing columns gracefully with fallbacks

