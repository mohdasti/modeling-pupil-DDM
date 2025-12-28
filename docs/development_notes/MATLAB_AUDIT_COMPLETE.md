# MATLAB Pipeline Audit - Complete Implementation

## Summary

All audit scripts and hardening features have been implemented. The MATLAB pipeline now includes:

1. ✅ **BUILD_ID system** - Timestamped build directories for provenance isolation
2. ✅ **Manifest tracking** - Complete run manifest with all metadata
3. ✅ **Trial-level flags** - Comprehensive QC metrics for downstream gates
4. ✅ **Pipeline run ID** - Reproducibility tracking (timestamp + git hash)
5. ✅ **Strict segmentation validation** - ITI checks for event-code when logP missing
6. ✅ **Comprehensive audit suite** - 7 audit scripts covering all requirements

## Audit Scripts

### Main Entry Point
**`run_matlab_audit.m`** - Runs all audit checks and generates sign-off report

**Usage**:
```matlab
cd('/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM/01_data_preprocessing/matlab');
run_matlab_audit();
```

### Individual Audit Scripts

1. **`audit_discovery.m`** → `parsed_metadata_inventory.csv`
2. **`audit_parse_failures.m`** → `qc_matlab_skip_reasons.csv` (parse failures)
3. **`audit_qc_crosscheck.m`** → `qc_expected_vs_observed_runs.csv`
4. **`audit_logp_integrity.m`** → `qc_logP_integrity_by_run.csv`
5. **`audit_timebase_iti.m`** → `qc_timebase_and_iti_checks.csv`
6. **`audit_regenerate_qc.m`** → Regenerates `qc_matlab_run_trial_counts.csv` and `qc_matlab_trial_level_flags.csv`
7. **`generate_signoff_report.m`** → `MATLAB_PIPELINE_SIGNOFF.md`

## Hard Requirements Status

### 1. NO silent defaults ✅
- `parse_filename()` returns empty on failure (no defaults to session=1/run=1)
- Lenient parsing logged with warnings (not silent)
- All parse failures logged to `qc_matlab_skip_reasons.csv`
- Audit verifies no silent defaults

### 2. Session/task scope ✅
- Only sessions 2-3 processed (explicit check in `parse_filename()`)
- Files with session 1 skipped with warning
- Audit report verifies session 1 count = 0

### 3. Run must be 1-5 ✅
- `parse_filename()` validates run number
- Invalid runs skipped and logged
- Audit report checks for invalid run numbers

### 4. Segmentation confidence ✅
- **Primary**: logP-driven (when logP exists and valid)
- **Fallback**: event-code ONLY if passes strict checks:
  - n_trials in [28,30] ✅
  - Trial start times strictly increasing ✅
  - Median ITI in [8,25] seconds ✅
  - Min ITI >= 5 seconds ✅
- Added ITI validation for event-code when logP missing (line 726-750 in BAP_Pupillometry_Pipeline.m)

### 5. Reproducibility ✅
- `pipeline_run_id` generated (timestamp + git hash)
- Added to all flat files as metadata column
- Added to `qc_matlab_run_trial_counts.csv`
- Added to `qc_matlab_trial_level_flags.csv`
- Included in all reports

## Output Files

All audit outputs are written to:
- If build directory exists: `BAP_processed/build_<BUILD_ID>/qc_matlab/`
- Otherwise: `BAP_processed/qc_matlab/`

### Required Deliverables

1. ✅ `parsed_metadata_inventory.csv` - Discovery audit results
2. ✅ `qc_expected_vs_observed_runs.csv` - QC spreadsheet cross-check
3. ✅ `qc_logP_integrity_by_run.csv` - logP validation
4. ✅ `qc_timebase_and_iti_checks.csv` - Timebase and ITI validation
5. ✅ `qc_matlab_run_trial_counts.csv` - Regenerated run-level QC
6. ✅ `qc_matlab_trial_level_flags.csv` - Regenerated trial-level QC
7. ✅ `qc_matlab_skip_reasons.csv` - All skipped runs with reasons
8. ✅ `MATLAB_PIPELINE_SIGNOFF.md` - Final sign-off report

## Key Code Changes

### BAP_Pupillometry_Pipeline.m
- **Line 78-83**: BUILD_ID creation and build directory setup
- **Line 85**: Pipeline run ID generation
- **Line 110**: Manifest data collection
- **Line 123**: Modified process_session to return manifest entries
- **Line 160-180**: Save flat files to build directory with pipeline_run_id
- **Line 391-450**: Manifest entry creation for all runs (including skipped)
- **Line 726-750**: ITI validation for event-code segmentation when logP missing

### New Functions
- `create_build_directory.m` - BUILD_ID system
- `write_manifest.m` - Manifest writer
- `generate_trial_level_flags.m` - Trial-level QC flags
- `generate_audit_report.m` - Comprehensive audit report
- `get_pipeline_run_id.m` - Pipeline run ID generator
- All audit scripts (7 total)

## Running the Audit

**After running the pipeline**, run the audit:

```matlab
cd('/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM/01_data_preprocessing/matlab');
run_matlab_audit();
```

**Output location**: Check `BAP_processed/build_<BUILD_ID>/qc_matlab/MATLAB_PIPELINE_SIGNOFF.md`

## Sign-Off Report Interpretation

The sign-off report will show:

- **PASS**: All requirements met, ready for downstream processing
- **FAIL**: Issues found, action items listed

**Key checks**:
- Session 1 count = 0
- All run numbers in [1,5]
- logP integrity PASS for runs with logP
- Event-code segmentation passes ITI checks when logP missing
- Timebase checks pass
- QC artifacts consistent

## Next Steps

1. Run the MATLAB pipeline to generate a build
2. Run `run_matlab_audit()` to perform comprehensive audit
3. Review `MATLAB_PIPELINE_SIGNOFF.md` for PASS/FAIL status
4. Fix any issues identified in the audit
5. Re-run audit until PASS

All deliverables are implemented and ready for use.

