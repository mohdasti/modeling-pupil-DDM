# Action Items: Following Expert Guidance

## Status: Ready to Proceed ✅

Based on expert guidance, model comparison is **not necessary**. The new model is methodologically superior and should be reported exclusively.

---

## ✅ Completed Actions

1. ✅ **Model refitting**: Successfully completed (Nov 27, 04:53)
   - New model: `output/models/primary_vza.rds`
   - Bias formula: `bias ~ task + effort_condition + (1|subject_id)` (no difficulty)
   - Convergence: Excellent (Rhat ≤ 1.006, ESS ≥ 734)

2. ✅ **Parameter extraction scripts**: All use new model
   - `scripts/02_statistical_analysis/extract_comprehensive_parameters.R` ✅
   - `scripts/02_statistical_analysis/create_ddm_visualizations.R` ✅
   - `scripts/extract_regenerate_tables.R` ✅
   - `scripts/run_sanity_checks_llm_recommended.R` ✅

3. ✅ **Documentation created**: Expert guidance documented
   - `EXPERT_GUIDANCE_MODEL_COMPARISON_RESOLUTION.md` ✅

---

## ⏳ Remaining Actions

### 1. Verify Output Files Are Up-to-Date

**Check timestamps**: Some output files may predate the model refit (Nov 27, 04:53).

**Files to verify**:
- `output/publish/table_fixed_effects.csv` (Nov 26 21:22) - **Needs regeneration**
- `output/publish/table_effect_contrasts.csv` (Nov 26 21:22) - **Needs regeneration**
- `output/figures/plot1_drift_rate_by_difficulty.png`
- `output/figures/plot2_bias_by_task.png`
- `output/figures/plot3_ppc_validation.png`
- `output/figures/plot4_parameter_correlation.png`

**Action**: Re-run parameter extraction and visualization scripts to ensure all outputs reflect the new model.

### 2. Update Manuscript Methods Section

**Location**: `reports/chap3_ddm_results.qmd`

**Current status**: Need to find and update the bias formula description to explicitly state that bias does not vary by difficulty.

**Required text**:
> "Critically, starting-point bias ($z$) was allowed to vary by Task and Effort (which are known to the participant pre-trial) but was constrained to be constant across Difficulty levels, as trial difficulty was randomized and thus unknown at the onset of the decision process."

**Action**: Search for model specification section and add this explicit statement.

### 3. Remove References to Model Comparison

**Location**: Any scripts or documentation that reference comparing old vs. new models.

**Files to check**:
- `scripts/02_statistical_analysis/compare_bias_formulas_loo.R` - This script is now obsolete
- Any documentation mentioning "model comparison" or "old model"

**Action**: Document that model comparison is not needed per expert guidance.

### 4. Re-run Secondary Analyses (If Any)

**Check**: Are there any downstream analyses (correlations, etc.) that used old model parameters?

**Action**: Identify and re-run with new model parameters (though values are similar, ensures consistency).

---

## 📋 Verification Checklist

Before proceeding to Discussion section:

- [ ] All output CSV files regenerated after Nov 27, 04:53
- [ ] All figures regenerated after Nov 27, 04:53
- [ ] Manuscript Methods section updated with bias constraint explanation
- [ ] No references to "old model" or model comparison in manuscript
- [ ] All scripts verified to use `primary_vza.rds` (new model)

---

## 🎯 Next Steps

1. **Immediate**: Verify and regenerate output files
2. **Immediate**: Update manuscript Methods section
3. **Final**: Proceed to Discussion section
4. **Final**: Final manuscript review

---

## 💡 Key Insights from Expert Guidance

1. **Model comparison not needed**: Old model had causal error, making it invalid *a priori*
2. **Stability of drift estimates**: Validates robustness of core findings
3. **Bias interpretation**: Task differences are valid psychological findings
4. **Reporting strategy**: Report only new model, no need to confuse reader with modeling history

