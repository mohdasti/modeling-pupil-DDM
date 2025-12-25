# AUC Feature Extraction Pipeline

This pipeline computes trial-level pupil AUC features from sample-level flat files and updates analysis-ready datasets for Chapter 2 (psychometric + pupil) and Chapter 3 (DDM).

## Overview

The pipeline consists of three main scripts:

1. **`compute_auc_features_from_flats.R`**: Extracts AUC features from 250 Hz flat files
2. **`update_ch2_ch3_with_auc.R`**: Updates Ch2/Ch3 analysis-ready datasets with AUC features
3. **`generate_waveform_summaries.R`**: Generates downsampled (50 Hz) waveform summaries (optional)

## Quick Start

Run the complete pipeline:

```bash
Rscript scripts/run_auc_pipeline.R
```

Or run scripts individually:

```bash
# Step 1: Compute AUC features
Rscript scripts/compute_auc_features_from_flats.R

# Step 2: Update Ch2/Ch3 datasets
Rscript scripts/update_ch2_ch3_with_auc.R

# Step 3: Generate waveform summaries (optional, can be slow)
Rscript scripts/generate_waveform_summaries.R
```

## Outputs

All outputs are saved to `quick_share_v5/`:

### Analysis-Ready Datasets
- `merged/BAP_triallevel_merged_v3.csv`: Full merged dataset with AUC features
- `analysis/ch2_analysis_ready.csv`: Chapter 2 analysis-ready (psychometric + pupil)
- `analysis/ch3_ddm_ready.csv`: Chapter 3 DDM-ready dataset
- `analysis/pupil_auc_trial_level.csv`: Raw AUC features per trial
- `analysis/ch2_waveform_means_50hz.csv`: Downsampled waveform summaries (if generated)

### QC Outputs
- `qc/qc_event_time_ranges.csv`: Event timing ranges by task
- `qc/qc_auc_missingness_by_condition.csv`: AUC missingness by condition
- `qc/qc_auc_missingness_reasons.csv`: Top reasons for missing AUC

### Figures
- `figures/auc_distributions.png`: AUC distribution histograms
- `figures/gate_pass_rates_overview.png`: Gate pass rates overview

## AUC Features Computed

### Total AUC
- **Window**: Trial onset (t=0) to response start (or 7.7s)
- **Baseline correction**: Mean pupil in [-0.5, 0] seconds (trial baseline B0)
- **Computation**: Trapezoidal integration of baseline-corrected pupil

### Cognitive/TEPR AUC (Fixed 1s Window)
- **Window**: [target_onset + 0.3s, target_onset + 1.3s] (or to response start)
- **Baseline correction**: Mean pupil in [target_onset - 0.5s, target_onset]
- **Computation**: Trapezoidal integration of target-baseline-corrected pupil
- **Also computed**: `cog_mean_fixed1s` (mean of corrected pupil in window)

## Quality Gates

### Baseline Requirements
- Minimum 10 valid (non-NA, finite) samples in trial baseline (B0)
- Minimum 10 valid samples in target baseline
- If either baseline fails, AUC is set to NA with reason code

### Chapter 2 Quality Pass
- `gate_primary_060`: baseline_quality >= 0.60 AND cog_quality >= 0.60
- `auc_quality_ok`: Both baselines have >= 10 valid samples
- `ch2_quality_pass`: Both conditions met

### Chapter 3 (DDM) Quality Pass
- RT range: 0.2s to 3.0s
- `gate_primary_050`: baseline_quality >= 0.50 AND cog_quality >= 0.50
- `auc_quality_ok`: Both baselines have >= 10 valid samples
- `ch3_ddm_ready`: All conditions met

## Event Timing

The pipeline uses fixed event timing based on known task structure:
- **Trial onset**: t = 0s (squeeze/grip gauge onset)
- **Target onset**: t ≈ 6.9s (after squeeze period)
- **Response start**: t ≈ 8.1s (after stimulus presentation)

If event timing columns exist in flat files (`trial_start_time_ptb`, `target_onset_time_ptb`, `resp1_start_time_ptb`), they are used instead of fixed values.

## Configuration

Paths are read from `config/data_paths.yaml`:
- `processed_dir`: Directory containing `*_flat.csv` files
- `behavioral_csv`: Behavioral trial-level CSV (used in merge step)

## Notes

- **Sampling rate**: AUC features are computed from 250 Hz data (no downsampling before AUC)
- **Waveform summaries**: Downsampled to 50 Hz for plotting (separate from AUC computation)
- **Memory efficiency**: Flat files are processed iteratively to avoid loading all data into memory
- **Processing time**: 
  - AUC computation: ~5-15 minutes for ~230 files
  - Waveform summaries: ~10-30 minutes (optional)

## Troubleshooting

### Missing AUC features
- Check `qc/qc_auc_missingness_reasons.csv` for common failure reasons
- Verify baseline windows contain sufficient samples (check `n_valid_b0`, `n_valid_target_base`)
- Ensure flat files have correct `time` column structure

### Event timing issues
- Check `qc/qc_event_time_ranges.csv` for timing ranges
- If timing seems wrong, verify flat files have event timing columns or update fixed timing in script

### Low coverage
- Verify flat files exist in `processed_dir`
- Check that files match pattern `*_(ADT|VDT)_flat.csv`
- Ensure sessions are 2-3 (session 1 is filtered out)

