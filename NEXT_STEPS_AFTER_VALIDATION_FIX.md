# Next Steps After Validation Fix

**Date:** 2025-11-25  
**Status:** ✅ Validation fixed, ready to proceed with model fitting

---

## ✅ What We've Accomplished

1. **Fixed drift constraint issue:**
   - Changed from tight `normal(0, 0.03)` to relaxed `normal(0, 2)`
   - Allows negative drift (evidence for "Same")

2. **Fixed validation logic:**
   - Now uses analytical solution for predicted proportions
   - Works correctly when drift is non-zero

3. **Model converged successfully:**
   - Standard-only bias model fits correctly
   - Drift v = -1.404 (negative, as expected)
   - Bias z = 0.573 (reasonable, near 0.5)

---

## 🎯 Next Steps: Model Fitting Strategy

### Priority 1: Primary Model
**File:** `04_computational_modeling/drift_diffusion/fit_primary_vza.R`

**What needs updating:**
- [ ] Ensure it uses `dec_upper` (response-side coding) ✓ (already done)
- [ ] Check drift prior - should be relaxed if Standard trials included
- [ ] Verify data file path: `data/analysis_ready/bap_ddm_only_ready.csv`
- [ ] Update validation to use analytical solution

**Then run:**
```r
source("04_computational_modeling/drift_diffusion/fit_primary_vza.R")
```

---

### Priority 2: Other Model Fitting Scripts

Check and update these scripts to use:
1. **Correct data file:** `bap_ddm_only_ready.csv` (with `dec_upper`)
2. **Relaxed drift prior** (if Standard trials included)
3. **Updated validation** (analytical solution)

**Scripts to review:**
- [ ] `R/fit_primary_vza_bsintx.R`
- [ ] `R/fit_primary_vza_vEff.R`
- [ ] `R/fit_taskwise_vza.R`
- [ ] Any other DDM fitting scripts

---

### Priority 3: Update All Model Scripts Systematically

**For each model fitting script:**

1. **Check data path:**
   ```r
   DATA_FILE <- "data/analysis_ready/bap_ddm_only_ready.csv"
   ```

2. **Verify dec_upper usage:**
   ```r
   rt | dec(dec_upper) ~ ...
   ```

3. **Update drift prior (if Standard trials included):**
   ```r
   # OLD (too tight if Standard trials included)
   prior(normal(0, 0.03), class = "Intercept")
   
   # NEW (allows negative drift for Standard trials)
   prior(normal(0, 2), class = "Intercept")
   ```

4. **Source updated validation:**
   ```r
   source("R/validate_ddm_parameters.R")
   ```

---

## 📋 Recommended Order

### Phase 1: Critical Models (Do First)
1. ✅ Standard-only bias model - **DONE**
2. ⏳ Primary model (`fit_primary_vza.R`) - **NEXT**
3. ⏳ Other primary variants (if needed)

### Phase 2: Secondary Models
4. Task-specific models
5. Effort-specific models
6. Interaction models

### Phase 3: Analysis
7. Extract parameter estimates
8. Statistical comparisons
9. Visualization
10. Manuscript updates

---

## 🔍 Pre-Flight Checklist for Each Model

Before running each model, verify:

- [ ] Data file path is correct
- [ ] Uses `dec_upper` for response-side coding
- [ ] Drift prior is appropriate (relaxed if Standard trials included)
- [ ] Validation uses analytical solution
- [ ] Logging is enabled
- [ ] Output directory exists

---

## 📝 Key Learnings

1. **Don't over-constrain drift:** Standard trials can have negative drift (evidence for identity)

2. **Use analytical validation:** When drift ≠ 0, compare predicted (from v+a+z) to observed, not bias to data

3. **Hierarchical models:** Perfect matches are rare; 8-10% differences are acceptable

---

## 🚀 Immediate Next Step

After commit/push:

1. **Review `fit_primary_vza.R`:**
   - Check drift prior
   - Verify data path
   - Update validation if needed

2. **Run primary model:**
   - Expected runtime: several hours
   - Monitor convergence
   - Check validation results

3. **Proceed systematically** through remaining models

---

**Ready to commit and proceed!** ✅

