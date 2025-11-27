# Manuscript Tables Status

**Date:** 2025-11-26  
**Check:** Verification of table data sources

---

## ✅ Manuscript Text: Clean

**Status:** All hardcoded values in narrative text have been updated.

- ✅ Standard proportions: **89.1% Same, 10.9% Different** (was 87.8%/12.2%)
- ✅ Trial counts: **17,834 total, 3,597 Standard** (was 17,243/3,472)
- ✅ Drift rate: **v = -1.404** (reflects relaxed prior results)
- ✅ No old values found in text

**Verification:** Searched for old values (87.8%, 12.2%, 3,472, 17,243) - **none found**

---

## ⚠️ Tables: OUTDATED

**Status:** Tables load from CSV files that are older than the current model fits.

### File Dates

| File | CSV Date | Model Date | Gap |
|------|----------|------------|-----|
| `bias_standard_only_levels.csv` | **Nov 21 14:19** | Nov 25 23:29 | ⚠️ 4 days old |
| `bias_standard_only_contrasts.csv` | **Nov 21 14:19** | Nov 25 23:29 | ⚠️ 4 days old |
| `table_fixed_effects.csv` | (unknown) | Nov 26 04:20 | ⚠️ Needs check |

### What This Means

The tables are showing results from **before** these critical updates:
- ❌ Updated dataset (17,834 vs 17,243 trials)
- ❌ Response-side coding (`dec_upper`)
- ❌ Relaxed drift prior
- ❌ New parameter estimates (v = -1.404)

### Tables Affected

1. **Bias Levels Table** (lines 832-857) - Shows bias by task/effort
2. **Bias Contrasts Table** (lines 860-907) - Shows task/effort contrasts
3. **Fixed Effects Table** (lines 936-1081) - Shows primary model fixed effects
4. **Effect Contrasts Table** (lines 1086-1256) - Shows difficulty/task/effort contrasts
5. **PPC Tables** (lines 1354+) - May also reference old models

---

## Impact Assessment

### Current State

- ✅ **Narrative text**: Matches new model results
- ❌ **Tables**: Show old results from Nov 21
- ⚠️ **Mismatch**: Text and tables will contradict each other!

### Example Mismatch

**Text says:**
> "With the relaxed drift prior, the Standard-only bias model estimated a negative drift rate on Standard trials (posterior mean v = -1.404..."

**Table shows:**
> Old values from Nov 21 (likely v ≈ 0 with tight prior)

---

## Required Action

**The CSV table files in `output/publish/` need to be regenerated from the updated model files:**

1. Extract from `output/models/standard_bias_only.rds` (Nov 25)
2. Extract from `output/models/primary_vza.rds` (Nov 26)
3. Generate CSV files in correct format
4. Save to `output/publish/`

---

## Recommendation

**Option 1:** Regenerate tables now
- Extract parameter estimates from updated models
- Generate all CSV files
- Verify consistency

**Option 2:** Add note to manuscript
- Note that tables will be updated in next revision
- Or render with "data not available" messages until tables are regenerated

---

## Files to Check/Regenerate

1. `output/publish/bias_standard_only_levels.csv`
2. `output/publish/bias_standard_only_contrasts.csv`
3. `output/publish/table_fixed_effects.csv`
4. `output/publish/table_effect_contrasts.csv`
5. PPC tables (if they reference model results)

---

**Status:** ⚠️ **Tables need regeneration before manuscript is complete**

