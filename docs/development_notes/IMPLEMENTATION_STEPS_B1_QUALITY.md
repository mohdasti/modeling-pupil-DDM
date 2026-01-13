# Implementation Steps for B1_quality

## Overview

This document outlines the steps needed to fully implement B1_quality in your pipeline.

## Files Already Modified

✅ **`02_pupillometry_analysis/quality_control/build_pupil_trial_coverage_prefilter.R`**
- Added `valid_baseline_B1` calculation
- Updated `gate_cog_auc` to use B1 baseline

✅ **`scripts/make_quick_share_v7.R`**
- Added B1 gates and updated gate calculations
- Updated Chapter 2 and Chapter 3 gate definitions

## Steps to Complete Implementation

### Step 1: Run QC Export Script (RStudio)

**File**: `02_pupillometry_analysis/quality_control/build_pupil_trial_coverage_prefilter.R`

**Action**: Run this script in RStudio to regenerate the QC export with `valid_baseline_B1`.

**Expected output**: 
- `data/qc/pupil_trial_coverage_prefilter.csv` (or `.csv.gz`)
- Should now include `valid_baseline_B1` column

**How to run**:
```r
# In RStudio, open and run:
source("02_pupillometry_analysis/quality_control/build_pupil_trial_coverage_prefilter.R")
```

**Or from command line**:
```bash
Rscript 02_pupillometry_analysis/quality_control/build_pupil_trial_coverage_prefilter.R
```

---

### Step 2: Add B1_quality to Merged Dataset (RStudio)

**File**: `scripts/add_B1_quality_to_merged.R` (NEW - created for you)

**Action**: Run this script to merge `valid_baseline_B1` (renamed to `B1_quality`) into your existing `merged_v4` file.

**What it does**:
1. Loads QC export (`pupil_trial_coverage_prefilter.csv`)
2. Extracts `valid_baseline_B1` and renames to `B1_quality`
3. Merges into `BAP_triallevel_merged_v4.csv`
4. Creates backup of original file

**How to run**:
```r
# In RStudio:
source("scripts/add_B1_quality_to_merged.R")
```

**Or from command line**:
```bash
Rscript scripts/add_B1_quality_to_merged.R
```

**Expected output**:
- Updated `data/pupil_processed/merged/BAP_triallevel_merged_v4.csv` with `B1_quality` column
- Backup file created automatically

---

### Step 3: Regenerate Analysis-Ready Datasets (RStudio)

**File**: `scripts/make_quick_share_v7.R`

**Action**: Run this script to regenerate Chapter 2 and Chapter 3 analysis-ready datasets with the new B1 gates.

**What it does**:
- Loads updated `merged_v4` (now with `B1_quality`)
- Creates gates using B1_quality for Cognitive AUC
- Regenerates `ch2_triallevel.csv` and `ch3_triallevel.csv`

**How to run**:
```r
# In RStudio:
source("scripts/make_quick_share_v7.R")
```

**Or from command line**:
```bash
Rscript scripts/make_quick_share_v7.R
```

**Expected output**:
- `data/pupil_processed/analysis_ready/ch2_triallevel.csv` (with B1 gates)
- `data/pupil_processed/analysis_ready/ch3_triallevel.csv` (with B1 gates)
- Updated gate counts (should see differences if B1_quality differs from baseline_quality)

---

## Verification Steps

After completing all steps, verify:

1. **Check merged file has B1_quality**:
   ```r
   merged <- read_csv("data/pupil_processed/merged/BAP_triallevel_merged_v4.csv")
   summary(merged$B1_quality)  # Should show values 0.0-1.0
   sum(!is.na(merged$B1_quality))  # Should be > 0
   ```

2. **Check analysis-ready files have B1 gates**:
   ```r
   ch2 <- read_csv("data/pupil_processed/analysis_ready/ch2_triallevel.csv")
   "gate_B1_60" %in% names(ch2)  # Should be TRUE
   sum(ch2$gate_B1_60, na.rm = TRUE)  # Should be > 0
   ```

3. **Compare gate counts**:
   ```r
   # Old gates (using baseline_quality for Cognitive AUC)
   sum(ch2$gate_baseline_60 & ch2$gate_cog_60, na.rm = TRUE)
   
   # New gates (using B1_quality for Cognitive AUC)
   sum(ch2$gate_B1_60 & ch2$gate_cog_60, na.rm = TRUE)
   
   # These may differ if B1_quality differs from baseline_quality
   ```

---

## Troubleshooting

### Issue: `valid_baseline_B1` not in QC export

**Solution**: Make sure you've saved `build_pupil_trial_coverage_prefilter.R` after the changes, and re-run it.

### Issue: No trials matched when merging

**Solution**: Check that key columns (`sub`, `task`, `session_used`, `run_used`, `trial_index`) match between QC export and merged file. The merge script will print sample keys for debugging.

### Issue: B1_quality is all NA

**Solution**: 
1. Check that `valid_baseline_B1` was calculated correctly in QC export
2. Verify the merge keys match
3. Check that the time window (3.85s-4.35s) is correct for your data

### Issue: Gate counts are the same as before

**Solution**: This is expected if B1_quality values are similar to baseline_quality. Check the actual values:
```r
merged <- read_csv("data/pupil_processed/merged/BAP_triallevel_merged_v4.csv")
cor(merged$B1_quality, merged$baseline_quality, use = "complete.obs")
# If correlation is very high (>0.95), gates will be similar
```

---

## Summary

**Three scripts to run in order**:
1. `build_pupil_trial_coverage_prefilter.R` - Generate QC export with B1_quality
2. `add_B1_quality_to_merged.R` - Merge B1_quality into merged_v4
3. `make_quick_share_v7.R` - Regenerate analysis-ready datasets

**All can be run in RStudio or from command line.**
