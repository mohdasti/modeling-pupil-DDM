# Empirical Reality Check Summary

**Date:** November 2, 2024  
**Purpose:** Verify that negative drift rate estimates for Hard difficulty are justified by observed behavior

---

## 🎯 Key Question

**Do negative drift estimates on Hard difficulty match the observed accuracy data?**

---

## ✅ **ANSWER: YES - NEGATIVE DRIFT IS JUSTIFIED**

### Overall Accuracy by Difficulty

| Difficulty | Accuracy | n_trials | Interpretation |
|------------|----------|----------|----------------|
| **Easy** | **85.2%** | 6,839 | Well above chance |
| **Hard** | **30.5%** | 6,932 | **WELL BELOW CHANCE** |
| **Standard** | **87.8%** | 3,472 | Well above chance |

**Critical Finding:** Hard difficulty has **30.5% accuracy**, which is **well below 0.5 (chance)**. This justifies negative drift rate estimates.

---

## Detailed Breakdown

### Accuracy by Difficulty × Task

| Difficulty | Task | Accuracy | n_trials |
|------------|------|----------|----------|
| Easy | ADT | 80.1% | 3,464 |
| Easy | VDT | 90.4% | 3,375 |
| **Hard** | **ADT** | **29.6%** | 3,449 |
| **Hard** | **VDT** | **31.4%** | 3,483 |
| Standard | ADT | 84.1% | 1,722 |
| Standard | VDT | 91.4% | 1,750 |

**Observation:** All Hard conditions (both ADT and VDT) show accuracy well below 50%, ranging from 29.6% to 31.4%.

### Accuracy by Difficulty × Task × Effort

| Difficulty | Task | Effort | Accuracy | n_trials |
|------------|------|--------|----------|----------|
| Hard | ADT | High_MVC | 27.8% | 1,673 |
| Hard | ADT | Low_5_MVC | 31.2% | 1,776 |
| Hard | VDT | High_MVC | 29.7% | 1,732 |
| Hard | VDT | Low_5_MVC | 33.1% | 1,751 |

**Key Point:** **ALL** Hard condition combinations show accuracy below 0.5, ranging from 27.8% to 33.1%.

---

## RT Distributions

### Median RT by Difficulty × Task

| Difficulty | Task | Median RT (s) | p10 | p50 | p90 |
|------------|------|---------------|-----|-----|-----|
| Easy | ADT | 0.809 | 0.432 | 0.809 | 1.76 |
| Easy | VDT | 0.704 | 0.417 | 0.704 | 1.44 |
| **Hard** | **ADT** | **1.05** | 0.520 | 1.05 | 2.02 |
| **Hard** | **VDT** | **0.981** | 0.520 | 0.981 | 1.84 |
| Standard | ADT | 0.999 | 0.514 | 0.999 | 1.94 |
| Standard | VDT | 0.912 | 0.490 | 0.912 | 1.66 |

**Observation:** Hard conditions show slower RTs (~1.0s median) compared to Easy conditions (~0.7-0.8s), consistent with increased task difficulty.

---

## Drift Rate Estimates vs. Behavior

### Model Estimates

From the fitted models, Hard difficulty drift rate estimates:
- **Model3_Difficulty:** -1.53 (95% CI: -1.57, -1.49)
- **Model4_Additive:** -1.53 (95% CI: -1.57, -1.49)
- **Model5_Interaction:** -1.56 (95% CI: -1.61, -1.50)

### Consistency Check

**✓ CONSISTENT:** 
- Hard accuracy = 30.5% (below chance)
- Drift estimates = ~-1.5 (negative)
- **Negative drift with below-chance accuracy is the expected pattern**

---

## Interpretation

### Why Negative Drift Makes Sense

In the drift diffusion model:
- **Positive drift (v > 0):** Bias toward correct response boundary
- **Negative drift (v < 0):** Bias toward incorrect response boundary

When accuracy is **below 0.5** (below chance), negative drift is **theoretically appropriate** because:
1. Participants are more likely to choose the incorrect response
2. The drift process is biased toward the incorrect boundary
3. The negative drift captures this bias

### Alternative Interpretations (Not Applicable Here)

If Hard accuracy were > 0.5 but drift was negative, we would need to consider:
- Difficulty effects captured in boundary separation (a/bs)
- Difficulty effects captured in starting point bias (z)
- Response confusion or task-specific effects

**However, since Hard accuracy is 30.5%, negative drift is the correct interpretation.**

---

## Conditions with Accuracy < 0.5

**All Hard conditions** (regardless of task or effort level) show accuracy below 0.5:

1. Hard + ADT + High_MVC: 27.8%
2. Hard + ADT + Low_5_MVC: 31.2%
3. Hard + VDT + High_MVC: 29.7%
4. Hard + VDT + Low_5_MVC: 33.1%

**Conclusion:** Negative drift estimates are justified across all Hard condition combinations.

---

## Final Verdict

### ✅ **NEGATIVE DRIFT ESTIMATES ARE LEGITIMATE**

1. **Behavioral Evidence:** Hard difficulty shows 30.5% accuracy (well below chance)
2. **Model Estimates:** Negative drift (~-1.5) is consistent with below-chance accuracy
3. **Pattern Consistency:** All Hard conditions show low accuracy
4. **Theoretical Justification:** Negative drift is appropriate when accuracy < 0.5

### No Inconsistencies Detected

- ✓ Drift estimates match observed behavior
- ✓ All Hard conditions justify negative drift
- ✓ RT patterns support difficulty interpretation
- ✓ No need to attribute effects to boundary or bias parameters

---

## Files Generated

1. **`output/checks/empirical_by_condition.csv`** - Main summary with accuracy and RT by difficulty × task
2. **`output/checks/accuracy_by_condition_detailed.csv`** - Detailed accuracy by all condition combinations
3. **`output/checks/accuracy_by_difficulty.csv`** - Overall accuracy by difficulty level
4. **`output/checks/rt_by_difficulty_task.csv`** - RT distributions by difficulty × task

---

## Recommendations

1. **Report in Methods:** "Hard difficulty trials showed below-chance accuracy (30.5%), justifying negative drift rate estimates indicating bias toward the incorrect response boundary."

2. **Report in Results:** Present accuracy rates by difficulty to demonstrate that negative drift estimates align with observed behavior.

3. **Discussion:** The negative drift on Hard difficulty reflects the increased difficulty of the task, with participants more likely to select incorrect responses.

---

**Check Status:** ✅ **PASSED** - No inconsistencies between parameter estimates and observed behavior.










