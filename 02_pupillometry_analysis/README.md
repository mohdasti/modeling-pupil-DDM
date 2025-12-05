# 02 Pupillometry Analysis

## Overview

This directory contains scripts for pupillometry feature extraction and quality control. **All scripts have been updated to work with the improved MATLAB pipeline output** (post-audit fixes).

## Quick Start: Full Pipeline

**To run the complete pupillometry analysis pipeline** (recommended when adding new data):

```r
source("02_pupillometry_analysis/run_full_pupillometry_pipeline.R")
```

This master script will automatically:
1. **Check for new data**: Detects new or updated flat files
2. **Prepare analysis-ready data**: Creates `BAP_analysis_ready_PUPIL.csv` and `BAP_analysis_ready_BEHAVIORAL.csv` (only if needed)
3. **Extract features**: Calculates Total AUC and Cognitive AUC (Zenon et al. 2014 method)
4. **Run quality control**: Comprehensive QC checks and reports
5. **Generate visualizations**: QC plots and waveform plots
6. **Create summary report**: Pipeline execution summary

The pipeline is **idempotent** - it only regenerates files if source data has changed, making it safe to run repeatedly.

## Key Updates (Post-Audit Fixes)

1. **Zero-to-NaN Conversion**: All scripts now handle NaN values properly (zeros converted to NaN in MATLAB pipeline)
2. **Quality Metrics**: Scripts use `baseline_quality` and `overall_quality` from MATLAB pipeline when available
3. **Quality Thresholds**: Updated to 80% valid data standard (matching MATLAB pipeline)
4. **trial_in_run**: Merging logic uses `trial_in_run` for accurate trial alignment

## Scripts

### Master Pipeline (Recommended)
- **`run_full_pupillometry_pipeline.R`**: Complete automated pipeline
  - Automatically detects new data
  - Runs all steps in sequence
  - Only regenerates files if source data changed
  - See `PIPELINE_GUIDE.md` for detailed documentation

### Individual Components

- **feature_extraction**: 
  - `prepare_analysis_ready_data.R`: Creates analysis-ready files with Total AUC and Cognitive AUC
  - `run_feature_extraction.R`: Wrapper that prepares data and integrates with subject-level data
  - Updated to use MATLAB pipeline quality metrics
  - Handles NaN values correctly (no zero checks)
  
- **quality_control**: 
  - `run_pupil_qc.R`: Comprehensive pupil QC
  - Validates analysis-ready data
  - Checks quality metrics (80% threshold validation)
  - Verifies difficulty level mapping (Standard, Easy, Hard)
  - Validates subject filtering (subjects with complete data)
  - Checks for zero values (should be 0 after MATLAB pipeline)
  - Creates QC plots (quality distributions, difficulty by task, etc.)
  - Generates detailed QC report

- **visualization**: 
  - `run_pupil_visualizations.R`: QC visualizations (quality metrics, distributions)
  - `plot_pupil_waveforms.R`: Publication-quality waveform plots (ADT/VDT)
  - Data quality plots (quality metrics, NaN percentages)
  - Pupil timecourse plots (by force and stimulus conditions)
  - Feature distributions (tonic arousal, effort arousal change)
  - Quality metrics distributions

## Data Requirements

Input files should be:
- Flat CSV files from MATLAB pipeline (with `trial_in_run`, `baseline_quality`, `overall_quality` columns)
- Merged flat files (with behavioral data) from R merger script

## Notes

- All pupil calculations use `na.rm = TRUE` to handle NaN values correctly
- Quality checks use `!is.na(pupil)` instead of `pupil > 0` (zeros are now NaN)
- Merging uses `trial_in_run` when available for accurate alignment
