# Expert Guidance: Bias Estimation and Contrast Selection

**Date**: 2025-11-26  
**Source**: Expert LLM Consultation  
**Status**: Accepted - Implementing Recommendations

---

## Executive Summary

Based on expert guidance, we will implement the following changes to our DDM analysis:

1. **Bias Strategy**: Remove `difficulty_level` from bias formula. Bias should only vary by `task` and `effort_condition` (known pre-trial factors), not by `difficulty_level` (unknown pre-trial).

2. **Role of Standard Trials**: Standard trials are **not** zero-drift trials. They represent **negative drift** (evidence for "Same"). They must remain in the Primary Model.

3. **Contrasts**: Focus on **Easy vs. Hard** as the primary contrast for difficulty effects. Comparisons against Standard are valid but answer different questions.

---

## Key Findings from Expert Guidance

### 1. The Purpose of Standard Trials (Correcting the "Zero Evidence" Misconception)

**Previous Understanding (INCORRECT)**:
- Standard trials (Δ=0) have zero evidence → drift rate should be zero
- Standard trials are only useful for bias estimation

**Correct Understanding**:
- In Same/Different tasks, Standard trials have **negative drift** (evidence for "Same")
- Participants are actively processing "sameness" as a signal (89.1% "Same" responses, v = -1.404)
- Standard trials represent the **strongest possible evidence for the Lower Boundary**
- They are essential experimental trials that define processing dynamics for "Same" responses

**Scientific Conclusion**: Standard trials are active experimental trials that anchor the lower boundary dynamics. They must remain in the full model.

---

### 2. Bias Estimation Strategy

**Recommendation**: Estimate bias simultaneously in the Primary Model, but **remove `difficulty_level` from the bias formula**.

**Rationale**:
- Difficulty levels are **interleaved (randomized)** - participants don't know if the next trial will be Easy or Hard
- At fixation cross (start of trial), participants cannot adjust starting point strategically based on difficulty
- Including `difficulty_level` in bias formula likely captures noise or "leakage" from drift rate into bias
- Bias should only vary by factors known **pre-trial**: Task (if blocked) and Effort (if cued)

**Current Formula** (INCORRECT):
```r
bias ~ difficulty_level + task + (1|subject_id)
```

**Recommended Formula** (CORRECT):
```r
bias ~ task + effort_condition + (1|subject_id)
```

**Why NOT fix bias from Standard-only model?**
- Two-step modeling discards parameter uncertainty
- Hierarchical Bayesian models benefit from "borrowing strength" across all trials
- Simultaneous estimation allows strong signals (Easy trials) to help constrain parameters for weaker signals (Hard trials)

---

### 3. Contrast Selection

**Primary Contrast**: **Easy vs. Hard**
- This directly tests signal strength sensitivity
- Answers: "Does increasing physical difference increase evidence accumulation rate?"
- This is the cleanest test of difficulty effects

**Secondary Contrasts**: Easy/Hard vs. Standard
- These compare **Category** (Different vs. Same), not Signal Strength
- Standard: Negative drift (towards "Same")
- Easy: Positive drift (towards "Different")
- Hard: Weak negative drift (towards "Same" because signal too weak)

**Recommendation**: Focus on **Easy vs. Hard** contrast for drift and boundary in statistical reporting.

---

### 4. Interpretation of Hard Condition Results

**Observation**: Hard trials have accuracy ~30% and v ≈ -0.64

**Previous Interpretation**: This might indicate a model failure

**Correct Interpretation**: This captures a psychological phenomenon:
- The signal was too weak to overcome the drift toward "Same"
- Older adults are conservative (high boundary) and biased toward "Same"
- When signal is weak, the "Same" attractor wins
- The model correctly identifies this as negative drift, even though "correct" answer was Different

---

### 5. Final Recommended Model Specification

**Updated `brms` Formula**:

```r
formula_final <- bf(
  # Drift: Varies by everything (Signal processing changes with difficulty)
  rt | dec(dec_upper) ~ difficulty_level + task + effort_condition + 
                        (1 + difficulty_level | subject_id),
  
  # Boundary: Can vary by difficulty (subjects may adjust caution dynamically)
  bs ~ difficulty_level + task + (1 | subject_id),
  
  # NDT: Motor/Encoding speed varies by Task and Effort
  ndt ~ task + effort_condition,
  
  # Bias: VARIES BY TASK/EFFORT ONLY (Constraint: no difficulty)
  bias ~ task + effort_condition + (1 | subject_id)
)
```

---

## Answers to Specific Questions

### 1. Bias Estimation Strategy
**Answer**: Estimate simultaneously using all trials. Do not fix from step 1.

### 2. Contrasts
**Answer**: Contrast **Easy vs. Hard** to answer your difficulty question. Contrasting against Standard compares "Signal Types" rather than "Signal Strengths."

### 3. Bias Variation
**Answer**: Conceptually, bias should **not** vary by difficulty if trials are interleaved. It is a stable pre-stimulus setting.

### 4. Model Specification
**Answer**: **Option B (modified)**: Include Standard trials, estimate simultaneously, but remove `difficulty` from the bias formula.

### 5. Reference Level
**Answer**: **Standard** is the best reference level mathematically because it represents the "Zero Difference" point on the x-axis of signal strength, allowing progression from Negative Drift (Standard) → Less Negative (Hard) → Positive (Easy).

---

## Next Steps

1. ✅ **Update Primary Model Script**: Modify `fit_primary_vza.R` to remove `difficulty_level` from bias formula
2. ✅ **Refit Primary Model**: Run the updated model specification
3. ✅ **Model Comparison**: Compare old vs. new model using `loo()` cross-validation
4. ✅ **Update Documentation**: Update manuscript and analysis scripts to reflect new understanding
5. ✅ **Regenerate Tables**: Extract parameters and contrasts from the new model
6. ✅ **Update Contrasts**: Focus on Easy vs. Hard as primary contrast

---

## Files to Update

1. `04_computational_modeling/drift_diffusion/fit_primary_vza.R` - Update bias formula
2. `reports/chap3_ddm_results.qmd` - Update model specifications and interpretations
3. `scripts/02_statistical_analysis/extract_comprehensive_parameters.R` - Update contrast extraction to focus on Easy vs. Hard
4. Create model comparison script for LOO comparison

---

## Implementation Status

- [x] Expert guidance received and documented
- [ ] Primary model script updated
- [ ] Model refitted with new specification
- [ ] Model comparison completed
- [ ] Documentation updated
- [ ] Tables regenerated

