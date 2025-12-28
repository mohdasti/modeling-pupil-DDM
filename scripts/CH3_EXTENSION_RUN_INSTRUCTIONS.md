# CH3 Extension Pipeline - Run Instructions

This document explains how to run the CH3 extension pipeline in RStudio.

## Prerequisites

1. MATLAB flat files have been regenerated with extended segmentation (ending at Resp1ET)
2. Latest build directory: `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/build_20251225_154443`
3. R packages installed: `dplyr`, `readr`, `data.table`, `ggplot2`, `here`, `yaml`, `purrr`, `tidyr`

## Quick Start

The simplest approach is to run the scripts in order:

### Option 1: Run All Scripts Manually (Recommended)

1. **Regenerate waveform summaries** (uses extended flat files):
   ```r
   source("scripts/make_quick_share_v7.R")
   ```
   This script will:
   - Find all `*_flat.csv` files recursively in `BAP_processed` (includes build directories)
   - Regenerate merged data, trial-level data, and waveform summaries
   - Save outputs to `quick_share_v7/`

2. **Run window selection diagnostics**:
   ```r
   source("scripts/ch3_window_selection_v2.R")
   ```
   This script will:
   - Verify timing anchors
   - Create stimulus-locked waveform plots
   - Compute time-to-peak statistics
   - Generate window coverage analysis
   - Save outputs to `quick_share_v7/qc/` and `quick_share_v7/figs/`

3. **Run STOP/GO checks**:
   ```r
   source("scripts/ch3_stopgo_checks.R")
   ```
   This script will:
   - Verify waveform extension (>=7.65s)
   - Check time-to-peak summary exists
   - Validate window coverage
   - Check timing sanity
   - Save `quick_share_v7/qc/STOP_GO_ch3_extension.csv`

### Option 2: Use the Runner Script

```r
source("scripts/run_ch3_extension_pipeline.R")
```

This script will prompt you and run all steps sequentially.

## Expected Outputs

After running all scripts, you should have:

### Waveform Data
- `quick_share_v7/analysis/pupil_waveforms_condition_mean.csv` - Condition-mean waveforms at 50Hz and 250Hz

### QC Files
- `quick_share_v7/qc/timing_sanity_summary.csv` - Timing verification summary
- `quick_share_v7/qc/timing_outlier_runs.csv` - Runs with timing deviations
- `quick_share_v7/qc/ch3_time_to_peak_summary.csv` - Time-to-peak statistics
- `quick_share_v7/qc/ch3_window_coverage.csv` - Window coverage analysis
- `quick_share_v7/qc/STOP_GO_ch3_extension.csv` - Overall status checks
- `quick_share_v7/qc/ch3_window_recommendation.md` - Window selection recommendation

### Figures
- `quick_share_v7/figs/ch3_waveform_by_task.png` - Waveforms by task (ADT vs VDT)
- `quick_share_v7/figs/ch3_waveform_by_effort.png` - Waveforms by effort level
- `quick_share_v7/figs/ch3_waveform_by_oddball.png` - Waveforms by stimulus type

## Verification

Check that:
1. Waveform data extends to at least 7.65s from squeeze onset
2. All STOP/GO checks pass (status = "GO")
3. Time-to-peak summary is non-empty
4. Window coverage shows W3.0 is now feasible

## Troubleshooting

- **"No flat CSV files found"**: Ensure `config/data_paths.yaml` points to the base `BAP_processed` directory (it will search recursively)
- **"Waveform file not found"**: Run `make_quick_share_v7.R` first
- **"STOP" status**: Check the `STOP_GO_ch3_extension.csv` file for specific failure reasons

