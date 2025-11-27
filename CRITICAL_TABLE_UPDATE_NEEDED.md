# ⚠️ CRITICAL: Tables Need Regeneration

**Date:** 2025-11-26  
**Status:** **TABLES ARE OUTDATED - Manuscript tables show old results!**

---

## The Problem

The tables in the Results section of `reports/chap3_ddm_results.qmd` load data from CSV files in `output/publish/`. These CSV files were generated from **OLD model fits** (before our recent updates).

### Timeline

- **Nov 21**: Table CSV files last modified (from old analysis)
- **Nov 25 23:29**: Standard-only bias model fitted (with updated data & relaxed prior)
- **Nov 26 04:20**: Primary model fitted (with updated data & response-side coding)

**Result:** Tables show results from November 21, not from the current models!

---

## What's Wrong

The tables are showing results from models that:
- ❌ Used old dataset (17,243 trials instead of 17,834)
- ❌ Used old decision coding (not response-side `dec_upper`)
- ❌ Used tight drift prior (not relaxed prior)
- ❌ Don't reflect negative drift rate estimates
- ❌ Don't show updated Standard trial proportions (89.1% Same, 10.9% Different)

---

## Tables That Need Regeneration

1. **`bias_standard_only_levels.csv`** - Bias parameter levels by condition
2. **`bias_standard_only_contrasts.csv`** - Bias contrasts (task, effort)
3. **`table_fixed_effects.csv`** - Fixed effects from primary model
4. **`table_effect_contrasts.csv`** - Effect contrasts from primary model
5. **PPC tables** - May also need updating if they reference old models

---

## Required Action

**Extract parameter estimates from the UPDATED model files and regenerate all CSV tables.**

### Steps Needed:

1. Extract from `output/models/standard_bias_only.rds`:
   - Bias parameter levels (logit and probability scales)
   - Bias contrasts (task, effort effects)
   - Drift rate estimates (should show v ≈ -1.404 for Standard)
   - All with correct credible intervals

2. Extract from `output/models/primary_vza.rds`:
   - Fixed effects for all parameters (v, a, t₀, z)
   - Effect contrasts (difficulty, task, effort)
   - Convergence diagnostics

3. Save in correct format to `output/publish/` directory

4. Verify tables match the narrative text we just updated

---

## Impact on Manuscript

- ✅ **Narrative text**: Updated with correct numbers (89.1%, 17,834 trials, etc.)
- ❌ **Tables**: Still showing old results from Nov 21
- ⚠️ **Risk**: Mismatch between text and tables will confuse readers!

---

## Next Steps

1. Create extraction script to pull results from updated model files
2. Regenerate all table CSV files
3. Verify consistency between tables and narrative
4. Check all hardcoded values in manuscript

