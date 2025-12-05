# Stage Definitions for Trial Flow Report

This document explains the distinctions between the three preprocessing stages tracked in the trial flow report.

## Stage Definitions

### 1. Raw_Flat
**What it is**: Sample-level data files directly from the MATLAB pipeline
- **File pattern**: `*_flat.csv` (or `*_flat_merged.csv` if no separate raw file exists)
- **Data structure**: Each row = one time sample (e.g., at 250 Hz = 250 rows per second)
- **Source**: Output from `BAP_Pupillometry_Pipeline.m`
- **Contains**: 
  - Pupil diameter measurements at each time point
  - Trial labels and phase information
  - May or may not have behavioral data merged yet

**Metrics available**:
- `n_trials`: Number of unique trials in the file
- `n_samples`: Total number of time samples (rows) in the file
- `n_runs`: Number of unique runs (calculated from `run` column)
- `mean_quality`: **NA** (quality metrics not yet calculated at this stage)

**Why mean_quality is NA**: Quality metrics (`overall_quality`, `baseline_quality`) are calculated during the MATLAB pipeline processing, but may not be present in all raw flat files. If present, they would be sample-level, not file-level.

---

### 2. Merged_Flat
**What it is**: Sample-level data files after merging with behavioral data
- **File pattern**: `*_flat_merged.csv`
- **Data structure**: Each row = one time sample (same as Raw_Flat)
- **Source**: Output from `Create merged flat file.R` script
- **Contains**: 
  - All data from Raw_Flat stage
  - **Plus**: Behavioral data merged by `run` and `trial_in_run`
  - Quality metrics from MATLAB pipeline (`overall_quality`, `baseline_quality`, `trial_quality`)
  - Behavioral variables: `stimLev`, `isOddball`, `iscorr`, `resp1RT`, `gf_trPer`, etc.

**Metrics available**:
- `n_trials`: Number of unique trials in the file
- `n_samples`: Total number of time samples (rows) in the file
- `n_runs`: Number of unique runs (calculated from `run` column)
- `mean_quality`: Mean of `overall_quality` across all samples in the file
- `n_trials_with_behav`: Number of trials that successfully merged with behavioral data

**Key distinction from Raw_Flat**: 
- Has behavioral data merged
- Has quality metrics available
- Same sample-level structure (not aggregated)

---

### 3. Analysis_Ready
**What it is**: Trial-level summary data after quality filtering
- **File pattern**: `BAP_analysis_ready_PUPIL.csv` and `BAP_analysis_ready_BEHAVIORAL.csv`
- **Data structure**: Each row = one trial (aggregated from sample-level data)
- **Source**: Output from `prepare_analysis_ready_data.R` script
- **Contains**: 
  - One row per trial (not per sample)
  - Trial-level features: `total_auc`, `cognitive_auc`, `tonic_arousal`, etc.
  - Quality metrics per trial: `overall_quality`, `baseline_quality`
  - Behavioral data already integrated
  - **Filtered**: Only trials with ≥80% valid data are included

**Metrics available**:
- `n_trials`: Number of trials (rows) for this subject-task combination
- `n_runs`: Number of unique runs (calculated from `run` column)
- `mean_quality`: Mean of `overall_quality` across all trials (trial-level mean)
- `n_samples`: **NA** (not applicable - this is trial-level data, not sample-level)

**Why n_samples is NA**: 
- Analysis-ready files are **trial-level summaries**, not sample-level data
- Each row represents one trial, not one time sample
- To get sample counts, you would need to go back to the merged flat files
- Sample counts are not stored in the analysis-ready files

**Key distinctions from Merged_Flat**:
- **Aggregated**: Sample-level → trial-level
- **Filtered**: Only trials with ≥80% valid data
- **Features extracted**: AUC metrics, arousal measures calculated
- **Subject filtering**: Only subjects with ≥5 runs for at least one task

---

## Summary Table

| Stage | Data Level | Has Behavioral? | Has Quality? | Has Features? | Filtered? |
|-------|-----------|-----------------|--------------|---------------|-----------|
| **Raw_Flat** | Sample | Maybe | No | No | No |
| **Merged_Flat** | Sample | Yes | Yes | No | No |
| **Analysis_Ready** | Trial | Yes | Yes | Yes | Yes (80% threshold) |

## Why Certain Fields Are NA

### n_samples in Analysis_Ready
- **Reason**: Analysis-ready files are trial-level summaries, not sample-level data
- **To get sample counts**: Go back to merged flat files and count samples per trial

### mean_quality in Raw_Flat
- **Reason**: Quality metrics may not be calculated yet or may not be present in all raw files
- **Note**: If quality metrics exist in raw files, they would be sample-level, not file-level

### n_runs in Raw_Flat/Merged_Flat (FIXED)
- **Previously NA**: Script wasn't calculating run counts from sample-level data
- **Now fixed**: Script now counts unique `run` values from the data

---

## Data Flow

```
MATLAB Pipeline
    ↓
Raw_Flat (sample-level, no behavioral, quality may be missing)
    ↓
R Merger Script
    ↓
Merged_Flat (sample-level, with behavioral, with quality)
    ↓
Feature Extraction + Quality Filtering
    ↓
Analysis_Ready (trial-level, with behavioral, with quality, filtered ≥80%)
```

