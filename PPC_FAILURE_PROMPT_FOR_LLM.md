# Posterior Predictive Check (PPC) Failure - Seeking Recommendations

**Context:** Wiener Diffusion Decision Model (DDM) using `brms` in R with `wiener()` family  
**Dataset:** 17,243 trials from 67 older adult subjects  
**Design:** Response-signal (RTs measured from response screen, not stimulus onset)  
**RT Range:** 0.250-2.977 seconds (pre-filtered)

---

## CURRENT MODEL STATUS

### ✅ Model: Boundary Interaction Model (`fit_primary_vza_bsintx.rds`)

**Formula:**
```r
rt | dec(decision) ~ difficulty_level + task + effort_condition + (1 + difficulty_level | subject_id)
bs   ~ difficulty_level * task + (1 | subject_id)  # INTERACTION: difficulty × task
ndt  ~ task + effort_condition  # Small condition effects, NO random effects
bias ~ difficulty_level + task + (1 | subject_id)
```

**Convergence:** ✅ **PASS**
- Max R-hat: 1.005 (threshold: ≤1.01)
- Min bulk ESS: 805 (threshold: ≥400)
- Divergences: 0
- Model converged successfully with strict settings (adapt_delta=0.995, max_treedepth=15)

**PPC Status:** ❌ **FAIL**
- **100% of cells flagged** (12/12 cells fail)
- **Max KS statistic: 0.333** (threshold: ≤0.15, pass/fail gate: ≤0.20)
- **Max QP RMSE: 0.195** (threshold: ≤0.09, pass/fail gate: ≤0.12)

### Detailed PPC Results by Cell:

| Task | Effort | Difficulty | N | QP RMSE | KS | Status |
|------|--------|------------|---|---------|-----|--------|
| ADT | Low_5_MVC | Standard | 881 | 0.125 | 0.097 | ❌ QP |
| ADT | Low_5_MVC | Hard | 1,776 | 0.166 | 0.089 | ❌ QP |
| ADT | Low_5_MVC | Easy | 1,777 | 0.141 | 0.228 | ❌ Both |
| ADT | High_MVC | Standard | 841 | 0.108 | 0.116 | ❌ QP |
| ADT | High_MVC | Hard | 1,673 | 0.170 | 0.087 | ❌ QP |
| ADT | High_MVC | Easy | 1,687 | 0.169 | 0.259 | ❌ Both |
| VDT | Low_5_MVC | Standard | 882 | 0.100 | 0.170 | ❌ Both |
| VDT | Low_5_MVC | Hard | 1,751 | 0.195 | 0.103 | ❌ QP |
| VDT | Low_5_MVC | Easy | 1,698 | 0.127 | 0.297 | ❌ Both |
| VDT | High_MVC | Standard | 868 | 0.127 | 0.211 | ❌ Both |
| VDT | High_MVC | Hard | 1,732 | 0.187 | 0.099 | ❌ QP |
| VDT | High_MVC | Easy | 1,677 | 0.142 | 0.333 | ❌ Both |

**Patterns:**
1. **Easy condition**: Highest KS values (0.228-0.333), indicating distributional misfit
2. **QP RMSE**: All cells exceed 0.09 threshold (range: 0.094-0.195)
3. **VDT vs ADT**: VDT Easy condition shows worst misfit (KS = 0.333)
4. **Hard condition**: Generally better KS (< 0.10) but still fails QP

---

## WHAT WE'VE TRIED

### Attempt 1: Baseline Model (no interactions)
- **Result:** PPC failed (Max KS=0.366, Max QP=0.222)
- **Issues:** Worst overall fit

### Attempt 2: Added NDT Condition Effects
- **Change:** `ndt ~ 1` → `ndt ~ task + effort_condition` with tight priors (normal(0, 0.08))
- **Result:** Still failed PPC
- **Rationale:** Attempted to address systematic misfit with small NDT variations

### Attempt 3: Boundary Interaction Model (CURRENT)
- **Change:** Added `bs ~ difficulty_level * task` interaction (targeting Easy/VDT tails)
- **Change:** Added random slopes on drift: `(1 + difficulty_level | subject_id)`
- **Result:** ✅ Convergence improved, PPC still fails but Max KS improved (0.366 → 0.333)
- **Status:** This is our best-converging model so far

### Attempt 4: Bias Interaction Model
- **Planned:** `bias ~ difficulty_level * task` interaction
- **Status:** Abandoned due to extremely slow sampling (stuck at iteration 1 for hours)
- **Issue:** Model too complex, chains failing to initialize properly

---

## PPC METHODOLOGY

**Method:** Pooled posterior predictive checks (subject-aware, includes random effects)
- **Draws per cell:** 400 posterior predictive draws
- **Simulation:** RTs simulated conditional on observed decisions using `posterior_predict(fit, re_formula = NULL)`
- **Pooling:** All draws pooled into single predictive sample per cell (more stable than averaging)

**Metrics:**
1. **QP RMSE:** Quantile-quantile RMSE comparing empirical vs. predicted RT quantiles (0.1, 0.3, 0.5, 0.7, 0.9) for correct and error responses separately, then weighted average by trial counts
2. **KS statistic:** Kolmogorov-Smirnov test comparing empirical vs. predicted RT distributions for correct and error responses, then max of both

**Thresholds:**
- QP RMSE: ≤ 0.09 (warning), ≤ 0.12 (pass/fail gate)
- KS: ≤ 0.15 (warning), ≤ 0.20 (pass/fail gate)
- CAF excluded from pass/fail gate (requires unconditional simulation)

---

## KEY CONSTRAINTS & DESIGN FACTORS

### Design Constraints:
1. **Response-signal design:** RTs measured from response screen (not stimulus), so NDT should be lower (~200-250ms) than standard designs
2. **NDT without random effects:** Adding `(1|subject_id)` to NDT causes initialization explosions (NDT > RT violations)
3. **Subject-level variation:** Must be captured in other parameters (drift, boundary, bias)

### Data Characteristics:
- **Minimum RT:** 0.250s (250ms)
- **Mean RT:** ~1.018s
- **Median RT:** ~0.887s
- **Maximum RT:** 2.977s
- **Tasks:** ADT (8,693 trials), VDT (8,681 trials)
- **Effort conditions:** Low_5_MVC, High_MVC
- **Difficulty levels:** Standard, Hard, Easy

---

## SPECIFIC QUESTIONS & REQUESTS

### 1. Model Specification Issues
- **Is the model misspecified?** What structural issues might cause systematic PPC failures?
- **Are we missing key predictors?** Should we add effort_condition to drift or boundary?
- **Should we try different link functions?** Currently using log links for bs and ndt, logit for bias
- **Do we need a lapse/contamination process?** To handle outliers or extreme responses?

### 2. PPC Methodology Questions
- **Are our thresholds appropriate?** QP ≤ 0.09, KS ≤ 0.15 seem strict - are they reasonable for DDM?
- **Should we use different PPC metrics?** E.g., accuracy-by-bin (CAF), distributional comparisons, etc.
- **Is conditional simulation the issue?** Should we simulate unconditional on decisions?

### 3. Prior Specification
- **Are our priors too tight/loose?** Current priors:
  - NDT intercept: normal(log(0.23), 0.12) → ~230ms
  - NDT effects: normal(0, 0.08) → very tight
  - Boundary: normal(log(1.7), 0.30) → ~1.7
  - Drift effects: normal(0, 0.5)
- **Should we use different priors for Easy condition?** Since it shows worst fit

### 4. Implementation Recommendations
- **What model modifications should we try next?**
- **What specific code changes would you recommend?**
- **Should we investigate parameter estimates first?** Check if estimated effects are reasonable

---

## REQUEST FOR CURSOR PROMPTS

**Please provide specific prompts that I can use in Cursor (the AI code editor) to implement your recommendations.** 

For each recommendation, please format it as:

```
PROMPT: [Specific instruction for what to implement]

FILE: [Which file(s) to modify]

EXPLANATION: [Brief rationale]
```

For example:
```
PROMPT: Add effort_condition as a predictor to the drift rate formula, removing it from the main formula and adding it specifically to the drift equation. Update priors accordingly.

FILE: R/fit_primary_vza_bsintx.R

EXPLANATION: Effort may affect information accumulation rate (drift) rather than decision threshold (boundary), and may help explain misfit in High_MVC conditions.
```

Please prioritize:
1. **Most likely to improve PPC** based on the patterns we see (Easy condition, VDT task)
2. **Practically implementable** given our constraints (no NDT random effects, response-signal design)
3. **Theoretically justified** for aging/adult populations and response-signal designs

---

## AVAILABLE RESOURCES

- **Model file:** `output/publish/fit_primary_vza_bsintx.rds` (converged, ready for analysis)
- **PPC results:** `output/publish/table3_ppc_primary_pooled.csv` (detailed cell-by-cell metrics)
- **Convergence diagnostics:** `output/publish/convergence_gate.txt` (all passed)
- **Scripts:** `R/fit_primary_vza_bsintx.R`, `R/export_ppc_primary_pooled.R`
- **Data:** `data/analysis_ready/bap_ddm_ready.csv`

---

**Thank you for your recommendations!**



