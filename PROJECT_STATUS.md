# Project Status Summary
**Last Updated:** November 3, 2024

## 🎯 **What You're Working On**
A comprehensive Bayesian Drift Diffusion Model (DDM) analysis for a response-signal detection task with older adults. You're preparing results for publication/review.

---

## ✅ **What's Been Completed**

### 1. **Main Model Fitting** ✓
- **9 main DDM models** fitted using `brms` with Wiener likelihood
- Models: Baseline, Force, Difficulty, Additive, Interaction, Task variants, Parametric (v+bs)
- All models saved to `output/models/`

### 2. **Empirical Reality Checks** ✓
- ✅ Accuracy/RT by difficulty/task computed
- ✅ Saved to: `output/checks/empirical_by_condition.csv`
- ✅ Flagged inconsistencies with negative drift

### 3. **Model Comparison** ✓
- ✅ **Difficulty mapping:** 6 variants (v-only, z-only, a-only, v+z, v+a, v+z+a)
- ✅ LOO comparison completed
- ✅ Saved to: `output/modelcomp/loo_difficulty_all.csv`
- ✅ Summary: `output/modelcomp/difficulty_mapping_summary.md`

### 4. **Sensitivity Analyses** ✓
- ✅ Excluded sub-chance subjects (< 0.5 accuracy)
- ✅ Applied RT upper bound (2.5s)
- ✅ Refit Model3_Difficulty and Model4_Additive
- ✅ Parameter deltas computed
- ✅ Saved to: `output/checks/sensitivity_summary.csv`

### 5. **Parameter Scale Cleanup** ✓
- ✅ All parameters transformed to natural scales
- ✅ Multiplicative/probability shifts computed
- ✅ Saved to: `output/tables/parameter_estimates_clean.csv`

### 6. **Posterior Predictive Checks (PPCs) - Plots** ✓
- ✅ QP plots (quantile-probability fits)
- ✅ CAF plots (conditional accuracy functions)
- ✅ RT distribution plots
- ✅ Saved to: `output/ppc/*.pdf` (all 9 models)

### 7. **Methods Documentation** ✓
- ✅ NDT decision rationale documented
- ✅ Saved to: `docs/methods_addendum_ndt.md`

---

## 🔄 **Currently In Progress**

### **PPC Numeric Metrics Export** (Running/Interrupted)
- **Script:** `scripts/checks/ppc_numeric_export.R`
- **Purpose:** Export numeric PPC metrics (no plots) per cell (model×task×effort×difficulty)
- **Metrics:** Accuracy differences, QP RMSE, KS D-stat, CAF RMSE
- **Status:** 
  - ✅ Completed: Model1_Baseline, Model2_Force, Model3_Difficulty, Model4_Additive, Model5_Interaction
  - ⏳ In progress: Model7_Task (was interrupted)
  - ⏳ Pending: Model8_Task_Additive, Model9_Task_Intx, Model10_Param_v_bs
- **Output:** `output/ppc/metrics/ppc_metrics_all_models.csv`
- **Resume capability:** ✅ Just added! Script will skip completed models and continue from where it left off

---

## 📋 **Remaining Tasks** (If Needed)

### 1. **Model Stabilization** (Optional - Not Recommended)
- ⚠️ **Status:** Attempted but made convergence worse
- **Models:** Model1_Baseline, Model2_Force, Model7_Task, Model8_Task_Additive
- **Recommendation:** Don't continue with current approach (R-hat got worse, ESS dropped)

### 2. **Re-fit Borderline Models** (Optional)
- **Script:** `scripts/02_statistical_analysis/02_ddm_analysis.R` (updated)
- **Settings:** chains=6, iter=8000, warmup=4000, adapt_delta=0.99
- **Status:** Script ready, not yet run

### 3. **Difficulty on Bias/Boundary** (Optional)
- **Model3D:** Clone Model3 with difficulty on `bs` and `bias` (not just drift)
- **Status:** Script exists (`scripts/fit_model3d_comparison.R`), not yet run

---

## 📊 **Key Results So Far**

### Convergence Status
- **5 of 9 models** show acceptable convergence (R-hat < 1.05, ESS > 0.05)
- **4 models** need attention but are usable (R-hat < 1.1)

### Main Findings
- **Difficulty effects:** Strong negative drift on Hard trials
- **Effort effects:** Small positive drift for Low 5 MVC
- **Task effects:** VDT shows higher drift than ADT
- **Boundary effects:** Model10 shows difficulty affects both drift and boundary

---

## 🚀 **Next Steps**

### **Immediate:**
1. **Resume PPC numeric export:**
   ```r
   source("scripts/checks/ppc_numeric_export.R")
   ```
   - Will automatically skip completed models (1-5)
   - Continue from Model7_Task
   - Estimated time: ~2-3 hours per remaining model

### **After PPC completes:**
2. Review PPC metrics to identify model misfits
3. Update `DDM_ANALYSIS_APA_REPORT.md` with PPC results
4. Finalize results for publication

---

## 📁 **Key Files & Locations**

### Scripts
- Main analysis: `scripts/02_statistical_analysis/02_ddm_analysis.R`
- PPC plots: `scripts/ddm_posterior_predictive_checks_FIXED.R`
- PPC metrics: `scripts/checks/ppc_numeric_export.R` ⬅️ **Currently running**
- Sensitivity: `scripts/checks/sensitivity.R`
- Difficulty mapping: `scripts/modeling/difficulty_mapping_loo.R`

### Outputs
- Models: `output/models/Model*.rds`
- PPC plots: `output/ppc/*.pdf`
- PPC metrics: `output/ppc/metrics/*.csv` (in progress)
- Parameter tables: `output/tables/parameter_estimates_clean.csv`
- Model comparison: `output/modelcomp/loo_difficulty_all.csv`
- Sensitivity: `output/checks/sensitivity_summary.csv`
- Report: `DDM_ANALYSIS_APA_REPORT.md`

---

## 💡 **Tips**

1. **Resume PPC script:** It now has resume capability - just run it again and it will continue from Model7_Task
2. **Check progress:** Look for files in `output/ppc/metrics/` - each model creates 4 CSV files
3. **Force re-run:** Set `FORCE_RERUN <- TRUE` in `ppc_numeric_export.R` if needed
4. **Time estimates:** Each model takes ~2-3 hours for PPC metrics (1000 draws × 17,243 trials)

---

## ❓ **Questions?**

- **"Where are my results?"** → Check `output/` subdirectories
- **"What's running?"** → Check `output/ppc/metrics/` for completed models
- **"How do I resume?"** → Just run `source("scripts/checks/ppc_numeric_export.R")` again






