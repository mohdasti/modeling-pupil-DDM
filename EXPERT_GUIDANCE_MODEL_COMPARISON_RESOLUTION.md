# Expert Guidance: Model Comparison Resolution

## Executive Summary

**Verdict**: Model comparison is **not necessary**. The loss of the old model is **scientifically irrelevant**. Proceed with the new model exclusively.

**Key Insight**: The old model contained a **causal error** (allowing bias to vary by unknown future event), making it invalid *a priori*, regardless of fit quality.

---

## 1. Is Model Comparison Necessary? **NO**

### Rationale

- **Theoretical trump card**: The old model had a causal error (bias varying by difficulty, which is unknown pre-trial)
- A model with a causal error is invalid regardless of its LOO score
- Even if the old model had slightly better fit (by overfitting noise), the new model must be chosen because it respects physical reality

**Action**: Do NOT restore the old model. Proceed with the new one.

---

## 2. Interpreting Similarity in Drift Estimates

### Finding

Drift estimates are nearly identical between old and new models:
- Standard: Old = -1.260, New = -1.230 (very similar)
- Hard: Both = -0.643 (identical)
- Easy: Both = +0.910 (identical)

### Interpretation

This is **excellent news**. It indicates:
- The inclusion of `difficulty` in the old bias formula was largely capturing noise, not stealing variance from drift rate
- The "Hard vs. Easy" signal in the data is robust
- The drift parameter was correctly estimated even when the model was slightly misspecified
- This validates earlier findings and strengthens the story

**Conclusion**: The "Hard" trials have negative drift because the signal is weak, not because the bias parameter was soaking up variance.

---

## 3. Interpreting Bias Results

### Current Findings (New Model)

**Task Effect**:
- ADT bias: z ≈ 0.553 (95% CrI: [0.536, 0.570])
- VDT bias: z ≈ 0.538 (95% CrI: [0.521, 0.555])
- **Interpretation**: Since tasks were blocked, participants adopted slightly different "baseline caution" or "starting assumption" for each modality. This is a valid psychological finding (e.g., "participants were slightly more ready to say 'Different' in the auditory block").

**Effort Effect**:
- Negligible (~0.003 difference on probability scale)
- **Interpretation**: Physical effort (unlike task context) did not systematically shift starting strategy.

**Key Observation**: Bias no longer varies by difficulty level (as intended), only by task and effort.

---

## 4. Reporting Strategy for Manuscript

### Recommendation

Report **only** the new model. Do not confuse the reader with modeling history unless it adds pedagogical value (which it doesn't here).

### How to Write It

**Methods Section**:
> "We fitted a hierarchical Bayesian DDM using `brms` [citation]. Critically, starting-point bias ($z$) was allowed to vary by Task and Effort (which are known to the participant pre-trial) but was constrained to be constant across Difficulty levels, as trial difficulty was randomized and thus unknown at the onset of the decision process."

**Results Section**:
- Report bias estimates by task and effort only
- Note that bias does not vary by difficulty (as theoretically expected)
- Interpret task differences in bias as modality-specific decision criteria

### Handling Old Analyses

Any secondary analyses (e.g., correlations with other variables) that used the old model parameters should be **re-run** with the new parameters. Since the values are so similar, this will likely be a "check-box" exercise, but it ensures internal consistency.

---

## 5. Action Items

### Immediate Actions

1. ✅ **Do NOT restore the old model** - It is obsolete
2. ✅ **Confirm**: All current tables/figures use the new `primary_vza.rds` file
3. ⏳ **Update Methods Section**: Explicitly state the constraint on bias ("bias did not vary by difficulty")
4. ⏳ **Re-run Secondary Analyses**: Any correlations or downstream analyses should use new parameters

### Verification Checklist

- [ ] All parameter extraction scripts use `primary_vza.rds` (new model)
- [ ] All visualization scripts use `primary_vza.rds` (new model)
- [ ] Manuscript tables are generated from new model
- [ ] Manuscript methods section explains bias constraint
- [ ] No references to "old model" or "model comparison" in manuscript

---

## 6. Scientific Implications

### Strengths

- **Robust findings**: Stability of drift rates across model variations indicates core findings are real
- **Methodologically sound**: New model respects causal structure of experimental design
- **Interpretable bias**: Task-specific bias differences are valid psychological findings

### Key Findings to Emphasize

1. **Negative drift on Hard trials** is robust (confirmed across model specifications)
2. **Task differences in bias** represent modality-specific decision criteria
3. **Bias does not vary by difficulty** - validates theoretical expectation that bias is pre-stimulus setting

---

## 7. Next Steps

**Ready to finish the chapter**:

1. Update manuscript methods section
2. Finalize all tables and figures (verify they use new model)
3. Write Discussion section emphasizing robustness of findings
4. Proceed to final manuscript review

---

## Conclusion

The model overwrite incident is scientifically irrelevant. The new model is methodologically superior, and the stability of drift estimates across specifications validates the robustness of your core findings. Proceed with confidence!

