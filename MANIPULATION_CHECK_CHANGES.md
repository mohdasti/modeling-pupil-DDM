# Manipulation Check Model Specification Changes

## Summary

**Date:** 2025-01-XX  
**Change:** Simplified manipulation check model to remove `task` factor  
**Rationale:** For a manipulation check, the core question is "Does the difficulty manipulation work?" This is best answered by testing Easy vs Hard pooled across tasks, not by testing task differences or interactions.

---

## Files Modified

### 1. `R/extract_manip_checks.R`

**Before:**
```r
glmm <- glmer(
  decision ~ difficulty_level * task + (1 | subject_id),
  data = dd_manip,
  family = binomial()
)

lmm <- lmer(rt_med ~ difficulty_level * task + (1 | subject_id), data = rt_med)
```

**After:**
```r
glmm <- glmer(
  decision ~ difficulty_level + (1 | subject_id),
  data = dd_manip,
  family = binomial()
)

lmm <- lmer(rt_med ~ difficulty_level + (1 | subject_id), data = rt_med)
```

**Changes:**
- Removed `task` factor and interaction from both models
- Added documentation explaining why task is excluded
- Model now focuses on core manipulation check question: Does Easy differ from Hard?

### 2. `reports/chap3_ddm_results.qmd`

**Changes:**
- Updated model specification description
- Removed task-related findings from results
- Updated coefficient values to match simplified model
- Added explanation of why task is excluded from manipulation check

**New Results:**
- Accuracy: Hard vs Easy: β = -2.97, p < .001
- RT: Hard vs Easy: β = 0.23 s, 95% CI [0.18, 0.28]

---

## Pipeline Integration

### Scripts That Call This:

1. **`R/run_extract_all.R`** - Main extraction pipeline
   - Line 12: `"R/extract_manip_checks.R"`
   - ✅ No changes needed - script path is correct

2. **Output Files Generated:**
   - `output/publish/checks_accuracy_glmm.csv`
   - `output/publish/checks_rt_lmm.csv`
   - ✅ Files are regenerated with new model specification

### No Other Scripts Need Changes

- Makefile: Does not directly call manipulation checks
- Other analysis scripts: Do not reference manipulation check model specification
- DDM model fitting scripts: Use different models (include task where appropriate)

---

## Justification

### Why Remove Task?

1. **Purpose of Manipulation Check:** Validate that the experimental manipulation (difficulty: Easy vs Hard) works as intended.

2. **Core Question:** "Does Easy differ from Hard?" - This is answered by pooling across tasks.

3. **Task Differences Are Secondary:** While VDT shows higher accuracy than ADT, this is not the focus of a manipulation check. The manipulation check should validate the difficulty manipulation works, not test task differences.

4. **Statistical Power:** Pooling across tasks maximizes power for the primary question.

5. **Simplicity:** A manipulation check should be simple and focused. Testing task differences or interactions goes beyond validation.

### Alternative Approaches Considered:

1. **Separate Models Per Task:** Would test if manipulation works in each task separately, but:
   - Less power (half the data per model)
   - More complex reporting
   - Not necessary if we just want to validate it works overall

2. **Model With Task (Additive):** `decision ~ difficulty + task + (1|subject)`
   - Would control for task differences
   - Still assumes difficulty effect is identical across tasks
   - More complex than needed for manipulation check

3. **Model With Interaction (Previous):** `decision ~ difficulty * task + (1|subject)`
   - Tests if manipulation generalizes across tasks
   - Goes beyond pure manipulation check
   - Interaction was significant but not central to validation question

### Decision: Simple Model (No Task)

For a manipulation check, the simple model is most appropriate:
- Directly answers: "Does the difficulty manipulation work?"
- Maximum power
- Simple interpretation
- Focused on core validation question

---

## Verification

### Data Summary (Easy vs Hard only):
- Easy: 85.2% accuracy, median RT 0.75s
- Hard: 30.5% accuracy, median RT 1.01s
- Strong manipulation effect in both tasks

### Model Results:
- Accuracy GLMM: Hard vs Easy: β = -2.97, p < .001 ✓
- RT LMM: Hard vs Easy: β = 0.23s, 95% CI [0.18, 0.28] ✓

**Conclusion:** The manipulation works strongly, validating the experimental design.

---

## Impact on Other Analyses

### DDM Models:
- ✅ **No impact** - DDM models still include task where appropriate
- DDM models test different questions (parameter estimation, not manipulation validation)

### Other Checks:
- ✅ **No impact** - Other quality checks are independent
- Reality checks, PPC checks, etc. use different models

### Report:
- ✅ **Updated** - Report now reflects simplified model
- All coefficient values updated to match new results

---

## Testing

To verify the changes work correctly:

```r
# Run the extraction script
source("R/extract_manip_checks.R")

# Check output files exist
file.exists("output/publish/checks_accuracy_glmm.csv")
file.exists("output/publish/checks_rt_lmm.csv")

# Verify model specification
acc <- read.csv("output/publish/checks_accuracy_glmm.csv")
# Should only have: (Intercept), difficulty_levelHard
# Should NOT have: taskVDT, difficulty_levelHard:taskVDT
```

---

## Commit Message Suggestion

```
Simplify manipulation check model: Remove task factor

- Remove task from manipulation check GLMM/LMM models
- Focus on core question: Does difficulty manipulation work?
- Pool across tasks for maximum power
- Update report to reflect simplified model
- Add documentation explaining rationale

Rationale: Manipulation checks should validate the experimental
manipulation works, not test task differences. Task differences
are secondary and can be tested separately if needed.
```


