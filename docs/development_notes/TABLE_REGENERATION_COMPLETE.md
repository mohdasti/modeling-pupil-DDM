# Table Regeneration - COMPLETE ✅

**Date:** 2025-11-26  
**Status:** ✅ **All tables successfully regenerated from updated models**

---

## Script Created

**File:** `scripts/extract_regenerate_tables.R`

This script extracts parameter estimates from the updated model files and generates all CSV tables needed for the manuscript.

---

## Tables Regenerated

1. ✅ **`bias_standard_only_levels.csv`**
   - Bias parameter levels by task × effort
   - Both logit and probability scales
   - Source: `output/models/standard_bias_only.rds` (Nov 25)

2. ✅ **`bias_standard_only_contrasts.csv`**
   - Task contrast (VDT - ADT)
   - Effort contrast (High - Low)
   - Source: `output/models/standard_bias_only.rds` (Nov 25)

3. ✅ **`table_fixed_effects.csv`**
   - All fixed effects from primary model
   - Includes estimates, CIs, Rhat, ESS
   - Source: `output/models/primary_vza.rds` (Nov 26)

4. ✅ **`table_effect_contrasts.csv`**
   - Effect contrasts for difficulty, task, effort
   - For drift, boundary, bias parameters
   - Source: `output/models/primary_vza.rds` (Nov 26)

---

## Verification

All files have been regenerated with **current timestamps** (Nov 26).

**Before:** Tables from Nov 21 (4+ days old)  
**After:** Tables from Nov 26 (current)

---

## Next Steps

1. ✅ Tables regenerated
2. → Verify values match expected results
3. → Render manuscript to check table displays
4. → Confirm consistency with narrative text

---

**Status:** ✅ **Tables updated - ready for manuscript rendering!**

