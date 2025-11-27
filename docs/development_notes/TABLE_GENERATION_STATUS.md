# Table Generation Status - CRITICAL ISSUE IDENTIFIED

**Date:** 2025-11-26  
**Status:** ⚠️ **TABLES ARE OUTDATED - NEED REGENERATION**

---

## Problem Identified

The tables in the Results section of `reports/chap3_ddm_results.qmd` load from CSV files in `output/publish/`, but these files are **outdated**:

### File Modification Dates

| File | Last Modified | Model Fit Date | Status |
|------|---------------|----------------|--------|
| `bias_standard_only_levels.csv` | Nov 21 | Nov 25 23:29 | ⚠️ **OUTDATED** |
| `bias_standard_only_contrasts.csv` | Nov 21 | Nov 25 23:29 | ⚠️ **OUTDATED** |
| `table_fixed_effects.csv` | (unknown) | Nov 26 04:20 | ⚠️ **OUTDATED** |

### Current Model Files (Up-to-Date)

- `output/models/standard_bias_only.rds` - Modified: **Nov 25 23:29**
- `output/models/primary_vza.rds` - Modified: **Nov 26 04:20**

---

## What This Means

The tables are showing **old results** from before:
- ✅ Updated dataset (17,834 trials vs 17,243)
- ✅ Response-side coding fix (`dec_upper` instead of `decision`)
- ✅ Relaxed drift prior for Standard-only model
- ✅ New negative drift rate estimates (v = -1.404)
- ✅ Updated Standard trial proportions (89.1% Same, 10.9% Different)

---

## Required Action

**The CSV table files need to be regenerated from the updated model RDS files.**

This requires:
1. Extracting parameter estimates from `standard_bias_only.rds`
2. Extracting parameter estimates from `primary_vza.rds`
3. Generating tables in the correct format for the manuscript
4. Saving to `output/publish/` directory

---

## Files That Need Regeneration

1. `bias_standard_only_levels.csv` - Bias parameter levels
2. `bias_standard_only_contrasts.csv` - Bias contrasts
3. `table_fixed_effects.csv` - Fixed effects from primary model
4. `table_effect_contrasts.csv` - Effect contrasts
5. Other PPC and convergence tables may also need updating

---

## Next Steps

1. Create/extract script to generate tables from updated models
2. Run extraction to regenerate all CSV files
3. Verify tables match current model results
4. Update manuscript if any hardcoded values remain

