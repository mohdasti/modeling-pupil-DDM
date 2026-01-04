# Processed Pupil Data

**Location:** `data/pupil_processed/`  
**Former name:** `quick_share_v7/` (renamed for clarity)

This directory contains the processed, analysis-ready pupil data with behavioral data merged.

## Contents

- **`analysis_ready/`** - Chapter-specific analysis-ready datasets
  - `ch2_triallevel.csv` - Chapter 2 (Psychometric-Pupil Coupling)
  - `ch3_triallevel.csv` - Chapter 3 (DDM with Pupil Predictors)
  
- **`merged/`** - Full merged trial-level dataset
  - `BAP_triallevel_merged_v4.csv` - Complete merge (behavior + pupil QC + AUC)
  
- **`qc/`** - Quality control summaries and diagnostics
  - Gate pass rates, join health, AUC missingness, timing coverage, etc.
  
- **`analysis/`** - Additional analysis files
  - Condition-mean waveforms, extended analysis datasets

## Key Features

- **Fixed baseline alignment**: B0 baseline correctly uses `[-0.5, 0.0)` relative to squeeze onset
- **Robust AUC coverage**: >= 40% AUC availability per task
- **Label-based timing anchor**: Robust timing inference from trial labels
- **Quality metrics**: Comprehensive QC summaries for both Chapter 2 and Chapter 3

## Regeneration

To regenerate this data:

```r
source("scripts/make_quick_share_v7.R")
```

**Note:** The script name still references "v7" for historical reasons, but output goes to `data/pupil_processed/`.

## Documentation

For detailed documentation, see:
- `README_quick_share_v7.md` - Detailed technical documentation (legacy filename)
- `qc/ch3_timing_reference.md` - Chapter 3 timing definitions
- `qc/README_ch3_qc.md` - Chapter 3 QC documentation

