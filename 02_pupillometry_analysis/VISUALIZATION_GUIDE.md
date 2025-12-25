# Pupillometry Visualization Guide

## Overview

The visualization script creates comprehensive plots for pupillometry data analysis, updated to work with the improved MATLAB pipeline output (post-audit fixes).

## Running Visualizations

### Basic Usage

```r
source('02_pupillometry_analysis/visualization/run_pupil_visualizations.R')
```

### Prerequisites

1. **Merged flat files** (already created ✓)
   - Location: `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/`
   - Pattern: `*_flat_merged.csv`

2. **Analysis-ready data** (after feature extraction)
   - File: `data/analysis_ready/BAP_analysis_ready_PUPIL.csv`
   - Created by: `02_pupillometry_analysis/feature_extraction/run_feature_extraction.R`

## Generated Visualizations

### 1. Data Quality Plots

- **`quality_by_file.png`**: Overall quality metrics across files (with 80% threshold line)
- **`nan_percentage_by_file.png`**: Missing data (NaN) percentage by file
  - Shows impact of zero-to-NaN conversion
  - Helps identify files with high missing data

### 2. Pupil Timecourse Plots

- **`pupil_timecourse_example.png`**: Example timecourse plot
  - Shows pupil diameter over time
  - Separated by force condition (Low vs High)
  - Faceted by stimulus condition (Standard vs Oddball)
  - Only includes valid (non-NaN) data

### 3. Feature Distributions

- **`tonic_arousal_distribution.png`**: Distribution of baseline (tonic) arousal
- **`effort_arousal_change_distribution.png`**: Distribution of effort-induced arousal change
- **`quality_metrics_distribution.png`**: Distribution of quality metrics (ITI and pre-stimulus)

### 4. Summary Report

- **`visualization_summary.txt`**: Text summary of visualization statistics

## Output Location

All plots are saved to: `06_visualization/pupillometry/`

## Workflow Integration

### Recommended Order

1. ✅ **Create merged flat files** (already done)
2. **Run feature extraction**:
   ```r
   source('02_pupillometry_analysis/feature_extraction/run_feature_extraction.R')
   ```
3. **Run quality control**:
   ```r
   source('02_pupillometry_analysis/quality_control/run_pupil_qc.R')
   ```
4. **Run visualizations**:
   ```r
   source('02_pupillometry_analysis/visualization/run_pupil_visualizations.R')
   ```

## Customization

### Update Paths

Edit the configuration section in `run_pupil_visualizations.R`:

```r
flat_files_dir <- "/path/to/your/processed/files"
output_dir <- "06_visualization/pupillometry"
analysis_ready_dir <- "data/analysis_ready"
```

### Add Custom Plots

The script is modular - you can add additional plots by:

1. Adding new plot code in the appropriate section
2. Using `ggsave()` to save plots
3. Following the existing pattern for data loading and processing

## Notes

- **NaN Handling**: All plots automatically filter out NaN values (zeros converted to NaN)
- **Quality Metrics**: Plots use `baseline_quality` and `overall_quality` from MATLAB pipeline when available
- **Thresholds**: Quality plots show the 80% threshold line (matching MATLAB pipeline standard)

## Troubleshooting

### "No merged flat files found"

- Check that merged files exist in the specified directory
- Verify file pattern matches `*_flat_merged.csv`

### "Analysis-ready pupil data not found"

- Run feature extraction first: `source('02_pupillometry_analysis/feature_extraction/run_feature_extraction.R')`

### Empty plots

- Check that data has valid (non-NaN) pupil values
- Verify quality thresholds are met (80% valid data)

---

**Status**: ✅ Ready to use with updated pipeline









