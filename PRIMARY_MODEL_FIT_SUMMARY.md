# Primary Wiener DDM Model Fit - Comprehensive Results Summary

**Date:** November 17, 2025  
**Model:** Primary "v+z+a" model (difficulty maps to drift v, boundary bs, and bias)  
**Model File:** `output/publish/fit_primary_vza.rds`  
**Fit Duration:** 209.5 minutes (3.5 hours)

---

## MODEL SPECIFICATION

### Formula
```
rt | dec(decision) ~ difficulty_level + task + effort_condition + (1|subject_id)
bs   ~ difficulty_level + task + (1|subject_id)
ndt  ~ task + effort_condition  # small condition effects, no random effects
bias ~ difficulty_level + task + (1|subject_id)
```

**Key features:**
- **Drift rate (v)**: Predictors: difficulty_level, task, effort_condition; Random intercept by subject
- **Boundary separation (bs/α)**: Predictors: difficulty_level, task; Random intercept by subject
- **Non-decision time (ndt/t₀)**: Predictors: task, effort_condition; **NO random effects** (to avoid initialization issues)
- **Bias (bias/z)**: Predictors: difficulty_level, task; Random intercept by subject

### Priors
- **v intercept**: Normal(0, 1)
- **bs intercept**: Normal(log(1.7), 0.30) → ~1.7 on natural scale
- **ndt intercept**: Normal(log(0.23), 0.12) → ~230ms on natural scale (tight prior)
- **ndt condition effects**: Normal(0, 0.08) → **very tight priors** for small effects
- **bias intercept**: Normal(0, 0.5) → ~0.5 on logit scale
- **Other effects**: Normal(0, 0.35-0.5)
- **Random effects SD**: Student_t(3, 0, 0.30)

### Sampling Settings
- **Chains**: 4
- **Iterations**: 8000 (warmup: 4000, sampling: 4000)
- **Cores**: 4 (2 threads per chain)
- **HMC control**: adapt_delta = 0.995, max_treedepth = 15
- **Backend**: cmdstanr
- **Seed**: 20251116

### Data
- **Total trials**: 17,243
- **Subjects**: 67
- **Minimum RT**: 0.250s (250ms)
- **RT range**: 0.250-2.977s
- **Tasks**: ADT (8,693 trials), VDT (8,681 trials)
- **Effort conditions**: Low_5_MVC, High_MVC
- **Difficulty levels**: Standard, Hard, Easy

---

## CONVERGENCE DIAGNOSTICS ✅

| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| **Max R-hat** | 1.0024 | ≤ 1.01 | ✅ **PASS** |
| **Min bulk ESS** | 478 | ≥ 400 | ✅ **PASS** |
| **Min tail ESS** | Inf/NA | ≥ 400 | ⚠️ **Infinite** (some parameters have perfect tail ESS) |
| **Divergent transitions** | 0 | = 0 | ✅ **PASS** |

**Interpretation:** The model converged successfully with excellent diagnostics:
- All parameters have R-hat ≤ 1.0024 (well below 1.01 threshold)
- Minimum bulk ESS of 478 exceeds the 400 threshold
- Zero divergent transitions
- Some parameters have infinite tail ESS (indicates very stable tail estimates)

---

## MODEL COMPARISON (LOO)

| Model | ELPD | SE | p_loo | ELPD diff from best |
|-------|------|----|----|---------------------|
| **v_z_a** | -17,007.01 | 148.39 | 192.35 | 0 |

**Interpretation:**
- **ELPD**: Expected log pointwise predictive density = -17,007.01
- **SE**: Standard error = 148.39
- **p_loo**: Effective number of parameters = 192.35 (indicates substantial regularization)
- **Warning**: 1 observation with pareto_k > 0.7 (recommended: use moment matching, but was not used here)

**Note:** This is a single-model fit (no comparison models run), so LOO is reported but not compared to alternatives.

---

## POSTERIOR PREDICTIVE CHECKS (PPC) ❌

### Summary
**Status:** ❌ **FAIL**

- **Cells flagged**: 12/12 (100.0%)
- **Max KS statistic**: 0.366 (threshold: ≤ 0.15, pass/fail gate: ≤ 0.20)
- **Max QP RMSE**: 0.222 (threshold: ≤ 0.09, pass/fail gate: ≤ 0.12)
- **CAF (Conditional Accuracy Function)**: Excluded from pass/fail gate

### Detailed Cell-by-Cell Results

| Task | Effort | Difficulty | N | QP RMSE | KS | QP Flag | KS Flag | Any Flag |
|------|--------|------------|---|---------|-----|---------|---------|----------|
| ADT | Low_5_MVC | Standard | 881 | 0.129 | 0.158 | ❌ | ❌ | ❌ |
| ADT | Low_5_MVC | Hard | 1,776 | 0.148 | 0.102 | ❌ | ✅ | ❌ |
| ADT | Low_5_MVC | Easy | 1,777 | 0.164 | 0.252 | ❌ | ❌ | ❌ |
| ADT | High_MVC | Standard | 841 | 0.112 | 0.167 | ❌ | ❌ | ❌ |
| ADT | High_MVC | Hard | 1,673 | 0.154 | 0.086 | ❌ | ✅ | ❌ |
| ADT | High_MVC | Easy | 1,687 | 0.197 | 0.282 | ❌ | ❌ | ❌ |
| VDT | Low_5_MVC | Standard | 882 | 0.094 | 0.219 | ❌ | ❌ | ❌ |
| VDT | Low_5_MVC | Hard | 1,751 | 0.222 | 0.097 | ❌ | ✅ | ❌ |
| VDT | Low_5_MVC | Easy | 1,698 | 0.144 | 0.331 | ❌ | ❌ | ❌ |
| VDT | High_MVC | Standard | 868 | 0.124 | 0.289 | ❌ | ❌ | ❌ |
| VDT | High_MVC | Hard | 1,732 | 0.212 | 0.093 | ❌ | ✅ | ❌ |
| VDT | High_MVC | Easy | 1,677 | 0.156 | 0.366 | ❌ | ❌ | ❌ |

**Patterns observed:**
1. **QP RMSE**: All cells exceed threshold (0.09). Range: 0.094-0.222. Worst: VDT Low_5_MVC Hard (0.222)
2. **KS statistic**: 9/12 cells exceed threshold (0.15). Range: 0.086-0.366. Worst: VDT High_MVC Easy (0.366)
3. **Easy condition**: Shows highest KS values (0.252-0.366), suggesting model struggles with easy trials
4. **VDT vs ADT**: VDT generally shows higher misfit (especially Easy condition)

### PPC Methodology
- **Method**: Pooled posterior predictive checks (subject-aware, includes random effects)
- **Draws per cell**: 400
- **Conditional simulation**: RTs simulated conditional on observed decisions
- **Metrics computed**:
  - **QP RMSE**: Quantile-quantile RMSE comparing empirical vs. predicted RT quantiles (0.1, 0.3, 0.5, 0.7, 0.9) for correct and error responses separately, then weighted average
  - **KS statistic**: Kolmogorov-Smirnov test comparing empirical vs. predicted RT distributions for correct and error responses, then max of both

---

## KEY FINDINGS

### ✅ What Worked
1. **Convergence**: Model converged excellently with strict settings (adapt_delta=0.995, max_treedepth=15)
2. **Sampling**: No divergent transitions despite tight priors and complex structure
3. **Stability**: Good effective sample sizes and R-hat values
4. **Initialization**: Fixed initialization issues that previously caused crashes (using `Intercept_ndt = log(0.075)`)

### ❌ What Didn't Work
1. **PPC failures**: 100% of cells fail posterior predictive checks
2. **Systematic misfit**: 
   - QP RMSE consistently too high (all > 0.09 threshold)
   - KS statistic shows distributional mismatches, especially for Easy condition
   - Model appears to systematically mispredict RT distributions

### ⚠️ Concerns
1. **NDT condition effects**: Allowed small condition effects on NDT (task + effort_condition) with tight priors (normal(0, 0.08)), but PPC still fails
2. **Easy condition**: Highest misfit for Easy difficulty trials (KS = 0.252-0.366)
3. **Task differences**: VDT shows worse fit than ADT, particularly for Easy condition
4. **LOO pareto_k**: 1 observation with pareto_k > 0.7 suggests potential influential outlier

---

## CONTEXT & HISTORY

### Previous Attempts
- Original model had `ndt ~ 1` (no condition effects) → PPC failed
- Added small condition effects on NDT (`ndt ~ task + effort_condition`) with very tight priors → **Still failing**
- Initialization was problematic (NDT > RT errors) → **Fixed** by using data-aware conservative initialization

### Rationale for Current Specification
- **NDT without random effects**: Previous attempts with `(1|subject_id)` on NDT caused initialization explosions (NDT > RT violations)
- **Small condition effects on NDT**: Allowed task and effort condition effects to address persistent PPC failures, constrained with very tight priors (normal(0, 0.08))
- **Tight priors on NDT effects**: Prevents large effects that would violate RT > NDT constraint

---

## DECISION POINTS

1. **Should we continue to allow condition effects on NDT?** Currently allowed but not helping PPC
2. **Should we try other model modifications?** Possible options:
   - Different link functions
   - Additional predictors on other parameters (e.g., effort on drift)
   - Lapse/contamination process
   - Different prior specifications
3. **Is the PPC failure acceptable?** 100% cells flagged suggests systematic model misspecification
4. **Should we investigate parameter estimates?** Check if estimated NDT condition effects are informative or near-zero
5. **Should we use moment matching for LOO?** 1 observation with high pareto_k might benefit from moment matching

---

## OUTPUT FILES

- `output/publish/fit_primary_vza.rds` - Fitted model object
- `output/publish/table1_loo_primary.csv` - LOO diagnostics
- `output/publish/table2_convergence_primary.csv` - Convergence diagnostics
- `output/publish/table3_ppc_primary_pooled.csv` - Detailed PPC results by cell
- `output/publish/ppc_passfail_pooled.txt` - PPC pass/fail summary

---

**END OF SUMMARY**





