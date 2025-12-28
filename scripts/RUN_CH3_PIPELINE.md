# Running CH3 Feature Regeneration Pipeline

## Quick Start

In RStudio, run:

```r
source("scripts/REGENERATE_CH3_FEATURES.R")
```

## What This Does

This script runs `make_quick_share_v7.R`, which:

1. **Processes flat pupil files** from your MATLAB output directory
2. **Computes AUC features** including:
   - `total_auc` (legacy: 0s to response onset)
   - `cog_auc` (legacy: target+0.3 to response onset)
   - `cog_auc_w3` (target+0.3 to target+3.3s) 
   - `cog_auc_respwin` (target+0.3 to Resp1ET = 7.70s)
   - **`cog_auc_w1p3`** (target+0.3 to target+1.3s) **[NEW - early window for DDM sensitivity]**
   - **`cog_mean_w1p3`** (mean pupil in W1.3 window) **[NEW - alternative metric]**

3. **Merges with behavioral data** to create `BAP_triallevel_merged_v4.csv`
4. **Generates analysis-ready datasets**:
   - `ch2_triallevel.csv`
   - `ch3_triallevel.csv`

## Prerequisites

- Ensure `config/data_paths.yaml` points to your MATLAB build directory with extended flat files (extending to Resp1ET = 7.70s)
- The MATLAB pipeline should have already run and generated flat files with `seg_end_rel_used` columns

## Expected Outputs

After running, you should have:

- `quick_share_v7/merged/BAP_triallevel_merged_v4.csv` (with new columns)
- `quick_share_v7/analysis_ready/ch3_triallevel.csv` (with new columns)
- QC files in `quick_share_v7/qc/`

## Next Steps

After regeneration completes:

1. **Run window selection diagnostics:**
   ```r
   source("scripts/ch3_window_selection_v3.R")
   ```
   This generates QC outputs in `quick_share_v7/qc/ch3_extension_v3/`

2. **Review QC outputs** and create STOP/GO checks

3. **Create decision memo** for Methods section documentation

