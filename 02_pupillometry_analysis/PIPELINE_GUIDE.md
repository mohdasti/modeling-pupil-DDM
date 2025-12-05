# Pupillometry Pipeline Guide

## Overview

This guide explains how to use the automated pupillometry analysis pipeline. The pipeline is designed to automatically process new data when it's added to the system.

## Quick Start

**Run the complete pipeline:**

```r
source("02_pupillometry_analysis/run_full_pupillometry_pipeline.R")
```

Or from command line:
```bash
Rscript 02_pupillometry_analysis/run_full_pupillometry_pipeline.R
```

## What the Pipeline Does

The master pipeline script (`run_full_pupillometry_pipeline.R`) automatically:

1. **Checks for New Data**
   - Scans for new or updated flat CSV files
   - Compares file modification times
   - Only regenerates files if source data has changed

2. **Prepares Analysis-Ready Data** (if needed)
   - Creates `BAP_analysis_ready_PUPIL.csv`
   - Creates `BAP_analysis_ready_BEHAVIORAL.csv`
   - Calculates Total AUC and Cognitive AUC (Zenon et al. 2014 method)
   - Filters to subjects with complete data (≥5 runs)

3. **Extracts Features**
   - Integrates pupil features with subject-level data
   - Merges demographics, LC integrity, neuropsych data

4. **Runs Quality Control**
   - Validates data quality metrics
   - Checks difficulty level mapping
   - Verifies subject filtering
   - Generates QC reports and plots

5. **Generates Visualizations**
   - QC visualizations (quality metrics, distributions)
   - Waveform plots (ADT and VDT with event markers)

6. **Creates Summary Report**
   - Pipeline execution summary
   - Data statistics
   - File locations

## When to Run

Run the pipeline whenever:
- **New pupil data is added** (new flat CSV files)
- **Behavioral data is updated** (new version of behavioral file)
- **You want to regenerate all outputs** (delete analysis-ready files first)

## Pipeline Features

### Automatic Detection
- Detects new files by comparing modification times
- Only processes what's needed (idempotent)
- Safe to run multiple times

### Error Handling
- Continues with remaining steps if one step fails
- Provides clear error messages
- Logs all operations

### Output Organization
- Analysis-ready data: `data/analysis_ready/`
- QC reports: `02_pupillometry_analysis/quality_control/output/`
- Visualizations: `06_visualization/publication_figures/`
- Summary report: `02_pupillometry_analysis/pipeline_summary.txt`

## Manual Steps (if needed)

If you need to run individual steps:

```r
# 1. Data preparation only
source("02_pupillometry_analysis/feature_extraction/prepare_analysis_ready_data.R")

# 2. Feature extraction only
source("02_pupillometry_analysis/feature_extraction/run_feature_extraction.R")

# 3. QC only
source("02_pupillometry_analysis/quality_control/run_pupil_qc.R")

# 4. Visualizations only
source("02_pupillometry_analysis/visualization/plot_pupil_waveforms.R")
```

## Troubleshooting

### Pipeline says files are up-to-date but you want to regenerate

Delete the analysis-ready files:
```r
file.remove("data/analysis_ready/BAP_analysis_ready_PUPIL.csv")
file.remove("data/analysis_ready/BAP_analysis_ready_BEHAVIORAL.csv")
```

Then run the pipeline again.

### New files not detected

Check that:
1. Files are in the correct directory: `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/`
2. Files match the pattern: `*_flat_merged.csv` or `*_flat.csv`
3. Files have been saved (not just created in memory)

### Errors in specific steps

The pipeline will continue even if individual steps fail. Check the error messages and:
- Review the specific script that failed
- Check data file formats and column names
- Verify file paths are correct

## Data Flow

```
Merged Flat Files (CSV)
    ↓
[Data Preparation]
    ↓
Analysis-Ready Files (PUPIL.csv, BEHAVIORAL.csv)
    ↓
[Feature Extraction + Integration]
    ↓
Integrated Dataset (with subject-level data)
    ↓
[Quality Control]
    ↓
QC Reports & Plots
    ↓
[Visualizations]
    ↓
Publication Figures
```

## Notes

- The pipeline uses **Total AUC** and **Cognitive AUC** (Zenon et al. 2014) as primary metrics
- Legacy metrics (`tonic_arousal`, `effort_arousal_change`) are kept for backward compatibility
- All scripts handle NaN values correctly (zeros converted to NaN in MATLAB pipeline)
- Quality threshold is 80% valid data per trial
- Only subjects with ≥5 runs for at least one task are included in final analysis

