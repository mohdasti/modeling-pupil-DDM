# B1_quality Implementation - Complete

## ✅ Changes Made

### 1. `scripts/make_quick_share_v7.R`

**Added B1_quality calculation** (around line 473-485):
- Calculates `B1_quality` as `n_valid_b0 / expected_samples_B1`
- Uses actual sampling rate (`dt_median`) to compute expected samples
- Falls back to 250Hz assumption if `dt_median` is missing
- B1 window: 3.85s to 4.35s (0.5 seconds)

**Added B1_quality to output** (line 607):
- Included in the tibble returned from `process_flat_file_v7()`

**Added B1_quality to merge process**:
- Included in `auc_features_unique` selection (line 984)
- Included in `coalesce_fields` for merge (line 1010)
- Ensured it exists in `merged_v4` (line 1050)

**Updated gates** (already done in previous changes):
- `gate_B1_60` and `gate_B1_50` use B1_quality
- `gate_pupil_primary` uses B1 gates for Cognitive AUC
- `ddm_ready` uses B1_quality for Cognitive AUC

## 🚀 How to Run

**Single script to run**:
```r
# In RStudio:
source("scripts/make_quick_share_v7.R")
```

**Or from command line**:
```bash
Rscript scripts/make_quick_share_v7.R
```

## ✅ What Will Happen

1. **Processes flat files** and calculates:
   - `n_valid_b0` (count of valid samples in B1 window)
   - `B1_quality` (proportion: n_valid_b0 / expected_samples)

2. **Merges into merged_v4**:
   - `B1_quality` column added to `BAP_triallevel_merged_v4.csv`

3. **Creates analysis-ready datasets**:
   - `ch2_triallevel.csv` with `gate_B1_60`, `gate_B1_50` columns
   - `ch3_triallevel.csv` with `ddm_ready` using B1_quality

## 🔍 Verification

After running, check:

```r
# Check merged file
merged <- read_csv("data/pupil_processed/merged/BAP_triallevel_merged_v4.csv")
summary(merged$B1_quality)  # Should show 0.0-1.0 range
sum(!is.na(merged$B1_quality))  # Should be > 0

# Check analysis-ready files
ch2 <- read_csv("data/pupil_processed/analysis_ready/ch2_triallevel.csv")
"gate_B1_60" %in% names(ch2)  # Should be TRUE
sum(ch2$gate_B1_60, na.rm = TRUE)  # Should be > 0

# Compare old vs new gates
sum(ch2$gate_baseline_60 & ch2$gate_cog_60, na.rm = TRUE)  # Old (B0 for Cognitive AUC)
sum(ch2$gate_B1_60 & ch2$gate_cog_60, na.rm = TRUE)       # New (B1 for Cognitive AUC)
```

## 📝 Notes

- **No QC script needed**: B1_quality is calculated directly from flat files
- **Backward compatible**: If B1_quality is missing, gates fall back to baseline_quality
- **Memory efficient**: Only processes what's needed, no huge QC export required

## 🎯 Result

You now have:
- **B0_quality** (baseline_quality): -0.5s to 0.0s → Total AUC baseline
- **B1_quality**: 3.85s to 4.35s → Cognitive AUC baseline  
- **cog_quality**: 4.65s to response onset → Cognitive AUC response window

All three metrics are properly aligned with their respective AUC calculations!
