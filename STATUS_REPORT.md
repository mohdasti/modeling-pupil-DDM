# DDM Analysis Status Report

**Date:** 2025-11-01  
**Last Update:** 12:00

---

## ✅ FIXES COMPLETED

### 1. Effort Condition - **FIXED** ✅
- **Problem:** Only 1 level detected ("High_MVC")
- **Solution:** Used `gf_trPer` column (Grip Force Trial Percent)
  - `0.05` → "Low_5_MVC" (8,837 trials)
  - `0.4` → "High_MVC" (8,537 trials)
- **Result:** 2 effort levels now detected correctly
- **Status:** ✅ Data verified, all models can now use effort

### 2. NDT Prior & Initialization - **FIXED** ✅
- **Problem:** NDT init values exceeding RT caused sampling failures
- **Solution:** Adjusted for response-signal design:
  - Prior center: `log(0.35)` → `log(0.23)` ✅
  - Prior spread: `0.25` → `0.20` ✅
  - Init value: `log(0.20)` = 200ms ✅
  - NDT RE prior: `student_t(3, 0, 0.3)` ✅
- **Status:** ✅ Code updated, ready to test

### 3. Factor Level Checks - **WORKING** ✅
- Effort levels: 2 (Low_5_MVC, High_MVC)
- Difficulty levels: 3 (Hard, Easy, Standard)
- Task levels: 2 (ADT, VDT)
- **Status:** ✅ All checks passing

---

## ❌ CURRENT ISSUE

### `init_r` Argument Error
- **Error:** `unused argument (init_r = 0.05)`
- **Cause:** `init_r` is not a valid argument for `brm()` in current brms version
- **Fix:** Removed `init_r` argument (not needed - init function handles jitter)
- **Status:** 🔧 Fixed in code, need to re-run

---

## 📊 PREVIOUSLY COMPLETED MODELS (from earlier runs)

1. ✅ Model1_Baseline (1.8M)
2. ✅ Model1_Baseline_ADT (1.9M)
3. ✅ Model1_Baseline_VDT (1.7M)
4. ✅ Model3_Difficulty (1.9M)
5. ✅ Model3_Difficulty_ADT (2.0M)
6. ✅ Model3_Difficulty_VDT (6.5M - largest, likely includes more samples)
7. ✅ Model4_Additive_NoEffort (2.1M)
8. ✅ Model7_Task (2.1M)
9. ✅ Model8_Task_Additive_NoEffort (2.1M)

---

## 🎯 MODELS TO RUN (with fixes)

All models failed due to `init_r` error, but will work after fix:

### Global Models:
- Model1_Baseline
- Model2_Force (effort) - **NOW POSSIBLE** ✅
- Model3_Difficulty
- Model4_Additive (effort) - **NOW POSSIBLE** ✅
- Model5_Interaction (effort) - **NOW POSSIBLE** ✅
- Model7_Task
- Model8_Task_Additive
- Model9_Task_Intx (effort) - **NOW POSSIBLE** ✅
- Model10_Param_v_bs (effort) - **NOW POSSIBLE** ✅

### Per-Task Models (ADT/VDT):
- All above models for ADT subset
- All above models for VDT subset
- (Task models skipped for per-task subsets as expected)

---

## 🔄 NEXT STEPS

1. ✅ Remove `init_r` argument (DONE)
2. ⏳ Re-run DDM analysis
3. ⏳ Verify all models complete successfully
4. ⏳ Check convergence diagnostics

---

## 📈 EXPECTED OUTCOMES

After fix, all models should:
- ✅ Initialize correctly (NDT < min RT)
- ✅ Use proper priors (NDT at log(0.23))
- ✅ Include effort models (2 levels available)
- ✅ Complete without argument errors

---

## 📝 NOTES

- RT floor: 0.2s (min RT = 0.243s in data, safe)
- NDT init: 0.20s = log(-1.609) (safe below floor)
- Data: 17,374 trials ready
- All factor level checks passing
















