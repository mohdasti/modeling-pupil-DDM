# Manipulation Check Model Specification: Justification

## Data Summary (Easy vs Hard only)

| Difficulty | Task | Accuracy | n_trials |
|------------|------|----------|----------|
| Easy       | ADT  | 80.1%    | 3,464    |
| Easy       | VDT  | 90.4%    | 3,375    |
| Hard       | ADT  | 29.6%    | 3,449    |
| Hard       | VDT  | 31.4%    | 3,483    |

**Difficulty Effect (Easy - Hard):**
- ADT: 50.5% difference (80.1% - 29.6%)
- VDT: 59.0% difference (90.4% - 31.4%)

**Observations:**
1. Difficulty manipulation works strongly in BOTH tasks
2. Task differences exist (VDT > ADT overall)
3. Difficulty effect slightly larger in VDT but strong in both

---

## Model Specification Options

### Option 1: Without Task
**Model:** `decision ~ difficulty + (1 | subject)`

**Questions Answered:**
- Does Easy differ from Hard? (main effect of difficulty)

**Assumptions:**
- No task differences OR task differences are irrelevant
- Difficulty effect is identical across tasks (strong assumption)

**Pros:**
- Simplest model
- Focused on primary question: "Does difficulty work?"
- Maximum power (pooling across tasks)

**Cons:**
- Ignores known task differences (VDT > ADT)
- Assumes difficulty effect is identical across tasks
- Cannot test if manipulation generalizes across modalities

**Use When:**
- Only question is "Does difficulty manipulation work overall?"
- Task differences are not of interest
- Willing to assume effect is identical across tasks

---

### Option 2: With Task (Additive)
**Model:** `decision ~ difficulty + task + (1 | subject)`

**Questions Answered:**
- Does Easy differ from Hard? (main effect of difficulty)
- Does VDT differ from ADT? (main effect of task)

**Assumptions:**
- Difficulty effect is identical across tasks (no interaction)
- Task differences are additive

**Pros:**
- Accounts for task differences statistically
- Tests both difficulty AND task effects
- More realistic than ignoring task differences
- Still pools across tasks for power

**Cons:**
- Assumes difficulty effect is identical across tasks
- Cannot test if manipulation generalizes across modalities

**Use When:**
- Want to account for task differences
- Believe difficulty effect is similar across tasks
- Interested in both difficulty and task effects

---

### Option 3: With Task Interaction (Current)
**Model:** `decision ~ difficulty * task + (1 | subject)`

**Questions Answered:**
- Does Easy differ from Hard? (main effect of difficulty)
- Does VDT differ from ADT? (main effect of task)
- Does the difficulty effect differ between tasks? (interaction)

**Assumptions:**
- None (most flexible)

**Pros:**
- Tests if manipulation generalizes across tasks
- Accounts for task differences
- Most realistic model
- Can detect if difficulty works differently in ADT vs VDT

**Cons:**
- More complex
- Lower power for interaction test
- If interaction is significant, need to interpret task-specific effects

**Use When:**
- Want to test if manipulation generalizes across modalities
- Not sure if difficulty effect is identical across tasks
- Want most complete picture

---

## Current Approach: Option 3 (With Interaction)

### Justification:

1. **Research Question:** The manipulation check should validate that the difficulty manipulation works. But we also want to know if it works **across both perceptual modalities** (auditory vs visual), not just on average.

2. **Data Shows Task Differences:** VDT has higher accuracy than ADT (90.4% vs 80.1% for Easy; 31.4% vs 29.6% for Hard). Ignoring this would violate model assumptions if we pooled without accounting for task.

3. **Generalizability:** If we're using both ADT and VDT in the DDM analysis, we should verify that the manipulation works in both tasks. If the difficulty effect only worked in one task, that would be a major concern.

4. **Statistical Rigor:** When pooling across factors (tasks), we should account for those factors in the model. Otherwise, we're violating the assumption of homogeneity.

### What We Found:

- **Main effect of difficulty:** β = -2.63, p < .001 ✓ (Strong effect: Easy > Hard)
- **Main effect of task:** β = 0.96, p < .001 ✓ (VDT > ADT)
- **Interaction:** β = -0.86, p < .001 (Difficulty effect larger in VDT, but strong in both)

**Interpretation:** The difficulty manipulation works strongly in BOTH tasks. While the effect is slightly larger in VDT (59% vs 50.5% difference), it's substantial in both, validating the manipulation.

---

## Alternative Approach: Separate Models Per Task

**Models:** 
- ADT: `decision ~ difficulty + (1 | subject)`
- VDT: `decision ~ difficulty + (1 | subject)`

**Questions Answered:**
- Does Easy differ from Hard in ADT?
- Does Easy differ from Hard in VDT?
- Are these effects similar? (compare coefficients)

**Pros:**
- Tests manipulation separately in each task
- No assumptions about task differences
- Clear task-specific interpretation

**Cons:**
- Less power (half the data per model)
- More complex reporting (two sets of results)
- Harder to statistically compare effects across tasks

**Use When:**
- Tasks are fundamentally different and shouldn't be pooled
- Want task-specific parameter estimates
- Don't care about testing if effects generalize

---

## Recommendation for Manipulation Check

### Current Approach (Option 3: With Interaction) is **APPROPRIATE** IF:

1. ✅ Primary goal is to validate manipulation works
2. ✅ Secondary goal is to verify it works across modalities
3. ✅ Tasks are similar enough to pool (both are change detection)
4. ✅ Want maximum statistical power
5. ✅ Want to account for task differences

### Alternative Approach (Separate Models) would be better IF:

1. ❌ Tasks are fundamentally different (e.g., one is detection, one is discrimination)
2. ❌ Only want task-specific validation
3. ❌ Don't care about generalizability across modalities
4. ❌ Want to allow completely different effects per task

---

## For This Study:

**Recommendation: KEEP Option 3 (with interaction)**

**Reasoning:**
- Both tasks use the same design (change detection)
- Both use the same difficulty manipulation (stimulus offset size)
- Want to validate manipulation works in both modalities
- Interaction test confirms generalizability
- Results show strong effects in both tasks

**However, we could simplify to Option 2 (additive, no interaction)** if:
- We're willing to assume difficulty effect is identical across tasks
- We only need to show it works on average
- The interaction test is not central to the manipulation check

**Or we could simplify to Option 1 (no task)** if:
- The ONLY question is "Does difficulty work overall?"
- Task differences are irrelevant for the manipulation check
- We don't care about generalizability

---

## Suggested Model Change

For a **pure manipulation check** (validating the manipulation works), **Option 1 or 2 might be more appropriate**:

**Simplified Model:** `decision ~ difficulty + (1 | subject)`
- Directly answers: "Does the difficulty manipulation work?"
- Pools across tasks for maximum power
- Simple, focused interpretation

**Or with task control:** `decision ~ difficulty + task + (1 | subject)`
- Answers: "Does difficulty work?" (controlling for task)
- Accounts for task differences
- Still simple interpretation

**Current model (with interaction)** is better if we want to test generalizability, but for a manipulation check, it might be asking more than necessary.


