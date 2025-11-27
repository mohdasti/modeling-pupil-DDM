# Prompt: Evaluation of Standard Condition Usage for Bias Identification in DDM

## Context: Response-Signal Change-Detection Task

I am conducting a hierarchical Bayesian drift diffusion model (DDM) analysis of a **response-signal change-detection task** in older adults (N=67). The task design is critical:

**Task Structure:**
- **Standard tone/stimulus** (100 ms) → **ISI** (500 ms) → **Target tone/stimulus** (100 ms) → **Blank** (250 ms) → **Response screen onset** (RT measurement starts here)
- RTs are measured from **response-screen onset**, not stimulus onset
- This is a **response-signal design** where early perceptual/encoding processes are absorbed into the pre-response period

**Experimental Conditions:**
- **Difficulty levels**: Standard (Δ=0, "no change" trials), Easy (high signal strength), Hard (low signal strength)
- **Tasks**: ADT (Auditory Detection Task) and VDT (Visual Detection Task)
- **Effort**: Low (5% MVC) vs. High (40% MVC) grip force

**Data:**
- 17,243 trials total
- Standard: 3,472 trials (20.1%), accuracy = 87.8%
- Easy: 6,917 trials (40.1%), accuracy = 85.2%
- Hard: 6,932 trials (40.2%), accuracy = 30.5%

---

## Theoretical Rationale: Why Standard Should Identify Bias

**Theoretical expectation:** Standard trials (Δ=0) represent **zero-evidence** or **near-zero-evidence** trials. In a DDM framework:

1. **When drift rate (v) ≈ 0**, the decision process is driven primarily by:
   - Starting-point bias (z)
   - Boundary separation (a)
   - Random walk noise

2. **Bias identification:** With v ≈ 0, the starting-point bias (z) becomes the primary determinant of choice probability. This makes Standard trials ideal for identifying bias parameters because:
   - Bias effects are not confounded by strong drift signals
   - The relationship between z and accuracy is more direct
   - Individual differences in bias are more clearly observable

3. **Literature support:** Prior work (de Gee et al., 2017/2020; Cavanagh et al., 2014) has used zero-evidence or catch trials to identify bias and its modulation by arousal/pupil measures.

**Our original thinking:** We planned to use Standard trials to identify bias (z) because they should have minimal drift, making bias the dominant factor in decision-making.

---

## Current Model Implementation

**Model Family:** Wiener DDM with `brms`
- Drift (v): identity link
- Boundary separation (a/bs): log link  
- Non-decision time (t₀/ndt): log link
- Starting-point bias (z): logit link

**Model Formula (Primary Model):**
```r
rt | dec(decision) ~ difficulty_level + task + effort_condition + (1|subject_id)
bs   ~ difficulty_level + task + (1|subject_id)
ndt  ~ task + effort_condition
bias ~ difficulty_level + task + (1|subject_id)
```

**Factor Coding:**
- `difficulty_level` is a factor with levels: `c("Standard", "Hard", "Easy")`
- **Standard is the reference level** (first level in the factor)
- This means:
  - Intercept terms represent Standard condition
  - Hard and Easy coefficients are contrasts vs. Standard

**Priors:**
- Drift intercept: `Normal(0, 1)` (no constraint to zero)
- Bias intercept: `Normal(0, 0.5)` on logit scale (centered at 0.5, no bias)

---

## Current Parameter Estimates

From the fitted model (`output/publish/table_fixed_effects.csv`):

**Drift Rate (v):**
- Intercept (Standard): **1.02** (95% CrI: 0.92, 1.13)
- Hard vs Standard: -1.66 (so Hard drift ≈ -0.64)
- Easy vs Standard: -0.17 (so Easy drift ≈ 0.85)

**Starting-Point Bias (z):**
- Intercept (Standard, logit scale): **-0.22** (95% CrI: -0.30, -0.14)
- Intercept (Standard, probability scale): **0.446** (slightly below 0.5)
- Hard vs Standard: +0.43 (so Hard bias ≈ 0.69 on probability scale)
- Easy vs Standard: +0.43 (so Easy bias ≈ 0.69 on probability scale)

**Boundary Separation (a/bs):**
- Intercept (Standard): log(1.7) ≈ 0.78 on log scale
- Hard vs Standard: -0.05
- Easy vs Standard: -0.09

---

## The Problem: Standard Has Non-Zero Drift

**Observed behavior:**
- Standard accuracy = **87.8%** (well above chance)
- Standard drift = **1.02** (positive, not zero)

**Theoretical expectation if Standard were zero-evidence:**
- If v ≈ 0 and z ≈ 0.5 (unbiased), accuracy should be ≈ 0.5 (chance)
- If v ≈ 0 and z ≠ 0.5, accuracy would be determined primarily by bias

**What we're seeing:**
- Standard has high accuracy (87.8%) AND positive drift (1.02)
- This suggests Standard trials are **not** zero-evidence
- Instead, participants may be detecting "no change" as a signal itself
- OR Standard trials have some inherent evidence (e.g., absence of change is detectable)

**Implication:** Bias and drift are **confounded** on Standard trials. We cannot cleanly identify bias from Standard alone because drift is also contributing to the decision.

---

## Questions for Evaluation

### 1. Is the Current Approach Correct?

**Current approach:**
- Standard is the reference level
- Standard has drift intercept = 1.02 (estimated from data, not constrained)
- Bias is estimated simultaneously with drift
- Bias intercept = 0.446 (slightly below 0.5)

**Is this theoretically sound?**
- Does it make sense that Standard has positive drift?
- Is bias being identified correctly despite non-zero drift?
- Are bias estimates confounded with drift on Standard trials?

### 2. Should We Constrain Standard Drift to Zero?

**Option A: Constrain v(Standard) = 0**
- Set a very tight prior: `Normal(0, 0.01)` for Standard drift
- OR use a custom parameterization where Standard drift is fixed at 0
- This would force bias to explain Standard accuracy

**Pros:**
- Aligns with theoretical expectation (Δ=0 = zero evidence)
- Cleaner bias identification
- Makes Standard trials maximally informative for bias

**Cons:**
- May be empirically wrong if Standard actually has detectable evidence
- Could worsen model fit if Standard truly has drift
- May require refitting all models

**Option B: Keep Current Approach**
- Let Standard drift be estimated from data
- Acknowledge that Standard may have detectable "no change" signal
- Document that bias identification is not optimal but still valid

**Pros:**
- Data-driven (lets the model determine if Standard has drift)
- Better fit if Standard truly has evidence
- More flexible

**Cons:**
- Bias and drift confounded on Standard
- Less clean bias identification
- May not align with theoretical rationale

### 3. Alternative Ways to Use Standard

**Option 1: Constrain Standard drift to zero**
- Force v(Standard) = 0
- Use Standard to identify bias cleanly
- Let Easy/Hard have free drift

**Option 2: Separate bias estimation**
- Fit a model where bias is estimated primarily from Standard
- Use a hierarchical approach where bias prior is informed by Standard trials
- Allow drift to vary freely

**Option 3: Model Standard as a special condition**
- Treat Standard as a "catch trial" with different properties
- Use a mixture model or special parameterization
- Explicitly model "no change detection" as a process

**Option 4: Keep current but document clearly**
- Acknowledge Standard has drift
- Explain why (e.g., "absence of change is detectable")
- Use Standard for relative comparisons (Hard/Easy vs Standard) rather than absolute bias identification

### 4. What Does the Literature Say?

**Key references:**
- de Gee et al. (2017/2020): Used zero-evidence trials to identify bias
- Cavanagh et al. (2014): Used catch trials for bias estimation
- Ratcliff (2006): Response-signal designs and parameter identification

**Questions:**
- How do other studies handle "no change" trials in change-detection tasks?
- Is it common for zero-evidence trials to have non-zero drift?
- Should we follow the literature (constrain to zero) or follow the data (allow drift)?

---

## Specific Questions for Evaluation

1. **Is our current model specification correct?** Should Standard be allowed to have drift, or should it be constrained to zero?

2. **Are we identifying bias correctly?** Given that Standard has drift = 1.02, can we still trust the bias estimates? Or are they confounded?

3. **What is the best way to use Standard?** Should we:
   - Constrain Standard drift to zero?
   - Keep current approach but document limitations?
   - Use a different parameterization?

4. **Is Standard actually zero-evidence?** The high accuracy (87.8%) suggests participants can detect "no change." Does this mean Standard is not truly zero-evidence, or does it mean bias is very strong?

5. **Model recommendations:** If we should constrain Standard drift, how should we implement this in `brms`? What are the technical considerations?

6. **Interpretation:** How should we interpret the current results? Is Standard drift = 1.02 meaningful, or is it an artifact of the model specification?

---

## Additional Context

**Response Coding:**
- `decision`: 1 = correct, 0 = incorrect
- Standard trials: Correct = "no change" response
- Easy/Hard trials: Correct = "change" response

**Model Convergence:**
- All parameters converged well (Rhat < 1.01, ESS > 400)
- Model fit is acceptable (subject-wise PPC: ≤15% flagged)
- LOO-CV strongly favors this model specification

**Current Interpretation:**
- We interpret Standard as having positive drift (participants can detect "no change")
- Bias on Standard = 0.446 (slightly biased away from "change" response)
- But we're uncertain if this is the optimal approach

---

## What We Need

Please evaluate:
1. **Theoretical soundness** of current approach
2. **Whether bias identification is compromised** by non-zero Standard drift
3. **Best practices** for using Standard condition in DDM
4. **Specific recommendations** for model specification
5. **Whether we need to refit models** with different constraints

We want to ensure our analysis is theoretically sound and methodologically rigorous. If constraining Standard drift to zero would improve bias identification, we're willing to refit models. If the current approach is acceptable, we need to document it clearly.

Thank you for your expert evaluation!

