# Manipulation Check: Should We Include Interactions?

## Question

Should the manipulation check models include interaction terms (difficulty × effort) or just main effects?

## Current Models

**Accuracy GLMM:** `decision ~ difficulty + effort + (1 | subject)`  
**RT LMM:** `rt_med ~ difficulty + effort + (1 | subject)`

Both are **additive models** (main effects only), no interactions.

---

## Data Summary

### Accuracy by Difficulty × Effort

| Difficulty | Effort | Accuracy | n_trials |
|------------|--------|----------|----------|
| Easy       | Low    | 85.1%    | 3,475    |
| Easy       | High   | 85.2%    | 3,364    |
| Hard       | Low    | 32.2%    | 3,527    |
| Hard       | High   | 28.8%    | 3,405    |

**Effort Effect by Difficulty:**
- Easy: High - Low = 0.0007 (almost no effect)
- Hard: High - Low = -0.0343 (High effort slightly worse)
- Difference: -0.035 (effort effect larger on Hard)

### RT by Difficulty × Effort

| Difficulty | Effort | Mean RT | Median RT |
|------------|--------|---------|-----------|
| Easy       | Low    | 0.895s  | 0.740s    |
| Easy       | High   | 0.909s  | 0.766s    |
| Hard       | Low    | 1.112s  | 1.000s    |
| Hard       | High   | 1.135s  | 1.020s    |

**Effort Effect on RT by Difficulty:**
- Easy: High - Low = 0.014s
- Hard: High - Low = 0.023s
- Difference: 0.009s (effort effect slightly larger on Hard)

---

## Interaction Model Results

### Accuracy GLMM WITH Interaction

| Term | Estimate | p-value | Interpretation |
|------|----------|---------|----------------|
| (Intercept) | 2.00 | < 0.001 | Easy + Low baseline |
| Difficulty: Hard | -2.89 | < 0.001 | Hard vs Easy (main effect) |
| Effort: High | -0.045 | 0.539 | High vs Low (main effect) |
| **Difficulty × Effort** | **-0.163** | **0.076** | **Interaction** |

**Interaction:** β = -0.163, p = 0.076 (marginal but NOT significant at α = 0.05)

### RT LMM WITH Interaction

| Term | Estimate | SE | t-value | Interpretation |
|------|----------|----|---------|----------------|
| (Intercept) | 0.780 | 0.034 | 23.0 | Easy + Low baseline |
| Difficulty: Hard | 0.240 | 0.022 | 10.7 | Hard vs Easy (main effect) |
| Effort: High | 0.015 | 0.022 | 0.68 | High vs Low (main effect) |
| **Difficulty × Effort** | **-0.002** | **0.032** | **-0.05** | **Interaction** |

**Interaction:** β = -0.002s, t = -0.05 (NOT significant)

---

## Analysis: Should We Include Interactions?

### Option 1: Main Effects Only (Current Approach) ✓

**Pros:**
1. **Focused on validation:** Manipulation checks should validate that each manipulation works, not explore interactions
2. **Simple and clear:** Easier to interpret - each manipulation has a main effect
3. **Sufficient for validation:** Main effects show both manipulations work
4. **Interactions not significant:** Both interactions are not statistically significant (p = 0.076 for accuracy, p >> 0.05 for RT)
5. **Interactions are secondary:** How manipulations interact is a substantive question, not a validation question

**Cons:**
1. **Might miss something:** If interactions are theoretically important, we'd miss them
2. **Less complete picture:** Doesn't show if effort affects difficulty differently

**Use When:**
- Goal is to validate manipulations work
- Interactions are not theoretically central
- Interactions can be tested in main analysis

### Option 2: Include Interactions

**Pros:**
1. **More complete:** Tests if manipulations interact
2. **Shows effort effect varies by difficulty:** Effort has larger effect on Hard trials
3. **Standard practice:** Some researchers include interactions in manipulation checks

**Cons:**
1. **Beyond validation scope:** Interaction tests substantive questions, not just validation
2. **Not significant:** Interactions are not statistically significant
3. **More complex:** Harder to interpret and communicate
4. **Confuses purpose:** Manipulation checks should be simple validation, not full analysis

**Use When:**
- Interactions are theoretically important
- Interactions are expected a priori
- Want complete picture of how manipulations combine

---

## Recommendation: **Keep Main Effects Only** ✓

### Rationale:

1. **Purpose of Manipulation Checks:** Validate that experimental manipulations work as intended. This requires:
   - Difficulty manipulation works (Easy ≠ Hard) ✓
   - Effort manipulation works (Low ≠ High) ✓
   - Interactions are NOT necessary for validation

2. **Interactions Are Not Significant:**
   - Accuracy interaction: p = 0.076 (marginal but not significant)
   - RT interaction: t = -0.05 (not significant)
   - Including non-significant interactions adds complexity without added value

3. **Interactions Are Substantive Questions, Not Validation:**
   - How difficulty and effort interact is a research question
   - This should be tested in the main DDM analysis (which likely includes interactions)
   - Manipulation checks should be simple and focused

4. **Standard Practice:**
   - Many manipulation checks use main effects only
   - The goal is validation, not comprehensive modeling
   - Interactions can be explored in the main analysis

5. **Current Approach Is Sufficient:**
   - Main effects show both manipulations work
   - Additive model controls for each manipulation while testing the other
   - Simple and interpretable

---

## Conclusion

**Current approach (main effects only) is CORRECT for manipulation checks.**

The manipulation check validates:
1. ✓ Difficulty manipulation works (Easy ≠ Hard, strong effect)
2. ✓ Effort manipulation works (Low ≠ High, small but significant effect)

Including interactions would:
- Go beyond validation scope
- Add complexity without significant findings
- Test substantive questions better addressed in main DDM analysis

**Recommendation: Keep current models (main effects only).**

