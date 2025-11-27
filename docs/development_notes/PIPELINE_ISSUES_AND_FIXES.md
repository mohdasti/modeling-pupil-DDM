# Pipeline Issues and Fixes

**Date:** 2025-11-01  
**Status:** Issues identified, fixes ready

---

## ✅ SUCCESSFULLY COMPLETED MODELS

From Nov 1 11:12-11:15 (later run):
1. ✅ Model1_Baseline (1.8M)
2. ✅ Model1_Baseline_ADT (1.9M)  
3. ✅ Model1_Baseline_VDT (1.7M)
4. ✅ Model3_Difficulty (1.9M)
5. ✅ Model3_Difficulty_ADT (2.0M)
6. ✅ Model4_Additive_NoEffort (2.1M)
7. ✅ Model7_Task (2.1M)
8. ✅ Model8_Task_Additive_NoEffort (2.1M)

---

## ❌ ISSUES IDENTIFIED

### Issue 1: effort_condition Has Only 1 Level
**Problem:** `effort_condition` only has "High_MVC" (1 level)
**Impact:** Models using `effort_condition` fail with:
```
contrasts can be applied only to factors with 2 or more levels
```
**Affected Models:**
- Model2_Force
- Model4_Additive (without NoEffort variant)
- Model5_Interaction
- Model8_Task_Additive (without NoEffort variant)
- Model10_Param_v_bs

**Solution:** 
- Skip models requiring effort_condition when only 1 level exists
- OR: Create effort condition from mvc values if continuous data available

### Issue 2: Prior Mismatch for Models with Predictors
**Problem:** Models like Model3_Difficulty include priors for `b_bs`, `b_ndt`, `b_bias` but formulas are intercept-only for these parameters
**Impact:**
```
The following priors do not correspond to any model parameter:
b_bs ~ normal(0, 0.2)
b_ndt ~ normal(0, 0.15)
b_bias ~ normal(0, 0.3)
```

**Solution:** Only include `b` priors when the formula actually has predictors for that parameter

### Issue 3: Initialization Issues
**Problem:** Many chains fail to initialize (RT < NDT violations)
**Impact:** Some models fail completely if all chains fail
**Solution:** Better initial values (already added in some scripts)

---

## 🔧 FIXES NEEDED

### Fix 1: Remove `b` priors when formulas are intercept-only

For models where bs/ndt/bias are intercept-only:
- Remove `prior(normal(...), class = "b", dpar = "...")` priors
- Keep only intercept priors

### Fix 2: Handle single-level factors

- Check factor levels before including in models
- Skip models that require factors with >1 level when data doesn't support it
- Create appropriate model variants (e.g., "NoEffort" variants)

### Fix 3: Better initialization

- Use data-driven initial values
- Ensure NDT init < min(RT)
- Set reasonable bounds

---

## 📋 MODELS TO FIX AND RE-RUN

Based on completed models, these need fixing:
- Model2_Force - Skip (only 1 effort level)
- Model4_Additive - Already have NoEffort variant ✅
- Model5_Interaction - Skip (requires effort)
- Model9_Task_Intx - Check task factor levels
- Model10_Param_v_bs - Skip (requires effort)
- Model3_Difficulty - Fix priors (remove b priors for intercept-only params)
- Model7_Task - Fix priors (already completed, but verify)

---

## 🎯 ACTION PLAN

1. Update prior specifications to match formulas
2. Add factor level checks before fitting
3. Re-run only failed models with fixes
4. Skip models that can't be fit due to data structure
















