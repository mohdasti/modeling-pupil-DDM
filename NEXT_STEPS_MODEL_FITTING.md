# Next Steps: Model Fitting

**Date:** 2025-11-25  
**Status:** ✅ Validation fixed, ready to proceed

---

## ✅ What's Complete

1. **Data Preparation:** ✓
   - DDM-only data ready: `bap_ddm_only_ready.csv`
   - Response-side coding (`dec_upper`) implemented
   - 17,834 trials validated

2. **Standard-Only Bias Model:** ✓
   - Converged successfully
   - Negative drift correctly estimated (v = -1.404)
   - Validation working correctly

3. **Validation System:** ✓
   - Analytical solution implemented
   - Experimental design checks
   - Parameter validation

---

## 🎯 Next Steps: Primary Model

### Step 1: Review Primary Model Script

**File:** `04_computational_modeling/drift_diffusion/fit_primary_vza.R`

**Check:**
- [x] Uses `dec_upper` for response-side coding ✓
- [x] Data path correct (`bap_ddm_only_ready.csv`) ✓
- [ ] Drift prior - needs review (may need relaxation for Standard trials)
- [x] Validation integrated ✓

**Drift Prior Check Needed:**
The primary model includes ALL difficulty levels (Standard, Hard, Easy). 
- Standard trials: May need relaxed prior (allows negative drift)
- Hard/Easy trials: Can have tighter prior

**Options:**
1. Use relaxed prior for all (simpler, consistent)
2. Use conditional prior (tighter for non-Standard, relaxed for Standard)
3. Use separate drift effects per difficulty level (most flexible)

---

### Step 2: Run Primary Model

```r
source("04_computational_modeling/drift_diffusion/fit_primary_vza.R")
```

**Expected:**
- Runtime: Several hours (more trials than Standard-only)
- Data: ~17,834 trials (all difficulty levels)
- Parameters: More complex (drift varies by difficulty)

**Monitor:**
- Convergence (Rhat < 1.01, ESS > 400)
- Parameter validation (analytical solution)
- Check for any warnings

---

### Step 3: Verify Results

After model finishes:

1. **Check convergence diagnostics**
   - Rhat, ESS, divergent transitions

2. **Run validation**
   - Should automatically run after fitting
   - Check if predictions match data

3. **Review parameter estimates**
   - Drift by difficulty level
   - Bias estimates
   - Boundary separation

4. **Check Standard trial drift**
   - Should be negative (like Standard-only model)
   - Explains "Same" bias

---

## 📋 Additional Models to Review

After Primary model:

1. **Other Primary Variants:**
   - `R/fit_primary_vza_bsintx.R` (boundary interactions)
   - `R/fit_primary_vza_vEff.R` (effort effects on drift)
   - `R/fit_taskwise_vza.R` (task-specific models)

2. **Update each to:**
   - Use correct data file
   - Use `dec_upper`
   - Use analytical validation
   - Check drift priors

---

## 🔍 Key Questions to Answer

### Before Running Primary Model:

1. **Drift Prior Strategy:**
   - Should Standard trials have relaxed prior?
   - Or use separate drift effects per difficulty?

2. **Model Complexity:**
   - Primary model includes all difficulty levels
   - May need to allow negative drift on Standard while keeping structure

3. **Validation Strategy:**
   - Validate overall model fit
   - Also validate Standard trials separately (should show negative drift)

---

## 💡 Recommendation

**For Primary Model:**

Option 1 (Simplest): Use relaxed drift prior for intercept
```r
prior(normal(0, 2), class = "Intercept")  # Allows negative drift
```

Option 2 (More precise): Separate drift effects
```r
# This would require model specification changes
# Drift intercept + difficulty effects
# Standard drift = intercept (relaxed)
# Hard/Easy drift = intercept + effects (can be constrained)
```

**Recommendation:** Start with Option 1 (simpler), verify it works, then refine if needed.

---

## ✅ Checklist Before Running

- [ ] Review drift prior in `fit_primary_vza.R`
- [ ] Verify data path is correct
- [ ] Confirm validation will run
- [ ] Check available disk space (models can be large)
- [ ] Ensure sufficient runtime (several hours)

---

## 📝 After Primary Model

Once Primary model is validated:

1. **Extract parameter estimates**
2. **Compare with Standard-only model**
3. **Run secondary models**
4. **Statistical analysis**
5. **Visualization**
6. **Manuscript updates**

---

**Ready to proceed when you are!** ✅

