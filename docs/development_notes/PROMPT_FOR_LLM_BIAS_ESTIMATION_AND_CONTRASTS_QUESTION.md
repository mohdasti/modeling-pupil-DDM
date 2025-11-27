# Comprehensive Prompt: DDM Bias Estimation Strategy and Contrast Selection

## Context and Research Question

I am conducting a hierarchical Bayesian Drift Diffusion Model (DDM) analysis using `brms` in R to investigate how task difficulty and physical effort affect decision-making processes in older adults. I have a fundamental methodological question about:

1. **Bias Estimation Strategy**: Should starting-point bias (z) be estimated independently from Standard trials only, and then fixed/fixed in the primary model? Or should bias be estimated simultaneously with other parameters in a single comprehensive model?

2. **Contrast Selection**: Given that one of my main research questions is whether task difficulty (Easy vs. Hard) has an effect on DDM parameters, should I contrast Easy vs. Hard directly, or should I include Standard trials in contrasts (e.g., Easy vs. Standard, Hard vs. Standard)? 

3. **Role of Standard Trials**: What is the scientific purpose of Standard trials (Δ=0, zero-evidence trials) in DDM analysis? Are they primarily useful for bias estimation, or should they be included in the full model with all other conditions?

I am genuinely uncertain about the correct approach and seek expert guidance on which methodology is scientifically sound and appropriate for my research questions and experimental design.

---

## Experimental Design

### Task Structure

**Two Perceptual Tasks (Between-Subject Factor):**
- **ADT (Auditory Detection Task)**: Participants detect oddball tones
- **VDT (Visual Detection Task)**: Participants detect oddball visual stimuli

These are separate experimental tasks, not levels of a factor to contrast. Each task was performed by different participants or in separate blocks.

### Three Difficulty Levels (Within-Subject Factor)

1. **Standard (Δ=0)**: 
   - **Definition**: Both stimuli are identical (no difference between stimulus 1 and stimulus 2)
   - **Purpose**: Zero-evidence trials where there is no objective signal to detect
   - **Expected Behavior**: Participants should show random or biased responding (no true signal)
   - **Trial Count**: 3,597 trials across 67 subjects

2. **Hard (Low Signal Strength)**:
   - **Definition**: Stimuli differ, but the difference is small and difficult to detect
   - **Expected Behavior**: Low accuracy (~30% correct), slower RTs, indicating difficult discrimination
   - **Trial Count**: 7,173 trials

3. **Easy (High Signal Strength)**:
   - **Definition**: Stimuli differ substantially, making the difference easy to detect
   - **Expected Behavior**: High accuracy (~85% correct), faster RTs, indicating easy discrimination
   - **Trial Count**: 7,064 trials

### Effort Manipulation (Within-Subject Factor)

- **Low Effort**: 5% of maximum voluntary contraction (MVC) grip force
- **High Effort**: 40% MVC grip force

### Total Dataset

- **Total Trials**: 17,834 trials (after exclusions)
- **Subjects**: 67 older adults
- **Tasks**: ADT (8,828 trials), VDT (9,006 trials)
- **RT Filtering**: 250ms - 3000ms

### Observed Data Patterns

**Standard Trials:**
- Participants chose "same" on 89.1% of trials and "different" on 10.9% of trials
- Since both stimuli are identical (Δ=0), saying "same" is technically the correct response
- Observed "accuracy" (proportion "same") = 88.5%, which aligns with the 89.1% "same" response rate
- This indicates a strong conservative bias toward "same" responses

**Hard Trials:**
- Accuracy: ~30.5% (well below chance at 50%)
- Median RT: ~1.01 seconds
- This indicates that participants are performing below chance, suggesting they are systematically choosing the wrong option more often than the correct one

**Easy Trials:**
- Accuracy: ~85.2% (well above chance)
- Median RT: ~0.75 seconds
- This indicates successful discrimination

---

## Current Modeling Approach

### Model 1: Standard-Only Bias Calibration Model

**Purpose**: To isolate bias identification from drift, we fit a hierarchical Wiener DDM to **Standard trials only** (3,597 trials).

**Model Formula:**
```r
rt | dec(dec_upper) ~ 1 + (1|subject_id)  # Drift: intercept only
bs ~ 1 + (1|subject_id)                   # Boundary: intercept + subject random effects
ndt ~ 1                                   # Non-decision time: intercept only
bias ~ task + effort_condition + (1|subject_id)  # Bias: task and effort effects
```

**Key Specification:**
- Drift rate (v) has a **relaxed prior** `normal(0, 2)` to allow for potential negative drift
- Estimated drift on Standard trials: **v = -1.404** (95% CrI: [-1.662, -1.147])
- Estimated bias: **z = 0.567** (95% CrI: [0.534, 0.601]) on probability scale
- The strong negative drift (-1.404) explains why participants choose "same" 89.1% of the time, despite a slight bias toward "different" (z = 0.567)

**Rationale for Relaxed Prior:**
While Standard trials theoretically have zero evidence (Δ=0), we used a relaxed drift prior rather than forcing drift to zero. This allows the model to capture systematic drift patterns that emerge from the data. The observed 89.1% "same" responses are explained by a strong negative drift toward "same" responses, consistent with participants actively accumulating evidence toward "sameness" as a signal.

### Model 2: Primary Analysis Model

**Purpose**: Full hierarchical DDM using **all trials** (17,834 trials) to estimate difficulty and effort effects on all DDM parameters.

**Model Formula:**
```r
rt | dec(dec_upper) ~ difficulty_level + task + effort_condition + (1 + difficulty_level | subject_id)
bs ~ difficulty_level + task + (1 | subject_id)
ndt ~ task + effort_condition
bias ~ difficulty_level + task + (1 | subject_id)
```

**Key Specifications:**
- Drift (v): Includes difficulty_level (Standard, Hard, Easy), task (ADT, VDT), and effort (Low, High)
- Boundary (a): Includes difficulty_level and task effects
- Non-decision time (t₀): Includes task and effort effects
- **Bias (z): Includes difficulty_level, task, and subject random effects**

**Current Contrasts Computed:**
From the primary model, we currently compute contrasts such as:
- "Easy - Standard" on drift rate (v)
- "Hard - Standard" on drift rate (v)
- "Easy - Hard" on drift rate (v)
- Similar contrasts for boundary (a) and bias (z)

**Current Results (Drift Rate):**
- Standard (Intercept): **v = -1.260** (95% CrI: [-1.365, -1.158])
- Hard (Intercept + Hard effect): **v = -0.643** (95% CrI: [-0.740, -0.546])
- Easy (Intercept + Easy effect): **v = +0.910** (95% CrI: [0.811, 1.008])
- Easy - Hard contrast: **Δ = +1.554** (95% CrI: [1.504, 1.604])

---

## Research Questions

1. **Primary Question**: Does task difficulty (Easy vs. Hard) affect drift rate, boundary separation, and bias?

2. **Secondary Questions**: 
   - Does effort (High vs. Low) affect decision parameters?
   - Are there task-specific (ADT vs. VDT) differences in decision parameters?

3. **Bias Question**: What is the starting-point bias in this population, and does it vary by task or effort?

---

## My Methodological Concern and Questions

### Concern 1: Purpose of Standard Trials

I am questioning the scientific purpose of Standard trials in my analysis. I was thinking that:

1. **Standard trials are primarily useful for bias estimation** because:
   - They have zero objective evidence (Δ=0), making them ideal for isolating response bias
   - On Standard trials, drift rate should theoretically be zero (no signal), so any preference for one response option reflects bias, not signal-driven drift
   - The observed 89.1% "same" responses can be interpreted as bias (or as evidence accumulation toward "sameness")

2. **Once bias is estimated from Standard trials, it might be fixed in the primary model** because:
   - Bias is a baseline response tendency that may not vary meaningfully across difficulty levels
   - Estimating bias from Standard trials provides a "clean" estimate unconfounded by signal strength
   - The primary model could then focus on difficulty and effort effects on drift and boundary, assuming bias is constant

**Question**: Is this reasoning correct? Should I:
- **Option A**: Estimate bias from Standard-only model, then fix it in primary model?
- **Option B**: Estimate bias simultaneously with other parameters in primary model (current approach)?
- **Option C**: Some other approach?

### Concern 2: Contrasts Involving Standard Trials

I am questioning whether contrasts that include Standard trials (e.g., "Easy - Standard", "Hard - Standard") are scientifically meaningful given my research questions.

**My Reasoning:**
1. **One of my main research questions is whether difficulty has an effect**: I want to know if Easy vs. Hard differ on drift rate, boundary, etc.

2. **Standard trials serve a different purpose**: They are zero-evidence trials used for bias estimation. They are not part of the difficulty manipulation (Easy vs. Hard).

3. **Contrasting Easy/Hard against Standard may not answer my question**: 
   - Standard trials are fundamentally different from Easy/Hard (no signal vs. signal present)
   - The contrast "Easy - Standard" tells me how Easy differs from zero-evidence baseline, but that's not my main question
   - The contrast "Easy - Hard" directly answers whether difficulty has an effect

4. **Including Standard in contrasts dilutes the difficulty effect**: If Standard is included as a reference level, it forces Easy and Hard to be contrasted against a baseline that is qualitatively different (zero evidence vs. signal present).

**Question**: Given that:
- My main question is about difficulty effects (Easy vs. Hard)
- Standard trials serve a specific purpose (bias estimation, zero evidence)
- Standard trials are fundamentally different from Easy/Hard (no signal vs. signal present)

Should I:
- **Option A**: Only contrast Easy vs. Hard (exclude Standard from contrasts)?
- **Option B**: Include Standard as a reference level (current approach: Easy - Standard, Hard - Standard)?
- **Option C**: Use Standard for bias estimation only, then remove it from the primary model entirely?

### Concern 3: Bias Estimation in Primary Model

Currently, my primary model includes:
```r
bias ~ difficulty_level + task + (1 | subject_id)
```

This estimates bias separately for Standard, Hard, and Easy conditions. However, I'm wondering:

1. **Should bias vary by difficulty?** 
   - Conceptually, bias is a baseline response tendency (e.g., tendency to say "same" vs. "different")
   - Does it make sense that bias would change based on signal strength?
   - Or is bias a stable trait that should be constant across difficulty levels?

2. **Should bias be estimated from Standard trials only?**
   - If Standard trials have zero evidence, they provide the "cleanest" estimate of bias
   - On Easy/Hard trials, bias and drift are confounded (both affect choice proportions)
   - Estimating bias from Standard trials might provide a more accurate baseline

**Question**: Should bias be:
- **Option A**: Estimated separately for each difficulty level (current approach)?
- **Option B**: Estimated from Standard trials only, then fixed or constrained in primary model?
- **Option C**: Estimated as a single value across all conditions (bias ~ 1 + task)?

---

## Current Results Summary

### Standard-Only Bias Model Results

**Drift Rate (v):**
- Mean: -1.404
- 95% CrI: [-1.662, -1.147]
- Interpretation: Strong negative drift toward "same" responses

**Bias (z) on Probability Scale:**
- ADT, Low Effort: z = 0.573 (95% CrI: [0.540, 0.604])
- ADT, High Effort: z = 0.569 (95% CrI: [0.536, 0.600])
- VDT, Low Effort: z = 0.534 (95% CrI: [0.501, 0.566])
- VDT, High Effort: z = 0.530 (95% CrI: [0.497, 0.562])
- Interpretation: Slight bias toward "different" responses (z > 0.5), but negative drift dominates

### Primary Model Results

**Drift Rate (v) by Difficulty:**
- Standard (Intercept): -1.260 (95% CrI: [-1.365, -1.158])
- Hard (Intercept + Hard effect): -0.643 (95% CrI: [-0.740, -0.546])
- Easy (Intercept + Easy effect): +0.910 (95% CrI: [0.811, 1.008])

**Contrasts:**
- Easy - Hard: +1.554 (95% CrI: [1.504, 1.604]) - Strong positive effect
- Easy - Standard: +2.170 (95% CrI: [2.108, 2.232]) - Strong positive effect
- Hard - Standard: +0.616 (95% CrI: [0.558, 0.674]) - Moderate positive effect

**Boundary (a) by Difficulty (on log scale):**
- Standard (Intercept): 0.822 (natural scale: a ≈ 2.27)
- Easy effect: -0.131 (natural scale: a ≈ 2.04, ~10% reduction)
- Hard effect: -0.066 (natural scale: a ≈ 2.17, ~4% reduction)

**Bias (z) by Difficulty:**
- Standard: Not directly estimated (depends on task/effort)
- Easy effect: -0.078 (95% CrI: [-0.145, -0.011]) - Slight reduction in bias
- Hard effect: -0.050 (95% CrI: [-0.113, 0.011]) - Not credible (CI includes 0)

---

## Technical Details

### Response-Side Coding

We use **response-side coding** (not accuracy coding):
- Upper boundary (1) = "different" responses
- Lower boundary (0) = "same" responses

This allows us to model response bias (preference for "same" vs. "different") independently from accuracy.

### Model Family and Link Functions

```r
family = wiener(
    link_bs = "log",      # Boundary separation on log scale (ensures a > 0)
    link_ndt = "log",     # Non-decision time on log scale (ensures t₀ > 0)
    link_bias = "logit"   # Starting-point bias on logit scale (ensures z ∈ [0,1])
)
```

### Priors

**Drift Rate (v):**
- Intercept: `normal(0, 1)` - Allows for negative drift
- Difficulty/Effort effects: `normal(0, 0.5)`

**Boundary Separation (a):**
- Intercept: `normal(log(1.7), 0.30)` → natural scale a ≈ 1.7
- Effects: `normal(0, 0.35)`

**Bias (z):**
- Intercept: `normal(0, 0.5)` → natural scale z ≈ 0.5 (no bias)
- Effects: `normal(0, 0.35)`

### Software and Methods

- **Package**: `brms` (Bayesian Regression Models using Stan) in R
- **Backend**: `cmdstanr`
- **MCMC**: 4 chains, 8,000 iterations (4,000 warmup)
- **Convergence**: Rhat < 1.01, ESS > 1000 for all parameters
- **Model Validation**: Posterior Predictive Checks (PPC) confirm excellent fit

---

## Specific Questions for Expert Guidance

1. **Bias Estimation Strategy**: Given that Standard trials have zero evidence (Δ=0), is it methodologically sound to:
   - Estimate bias from Standard trials only (Standard-only model)
   - Then fix or constrain this bias estimate in the primary model?
   - Or should bias be estimated simultaneously with other parameters using all trials?

2. **Contrast Selection**: Given that my main research question is about difficulty effects (Easy vs. Hard), and Standard trials serve a different purpose (bias estimation, zero evidence):
   - Should I contrast Easy vs. Hard directly (exclude Standard from contrasts)?
   - Or is it scientifically valid to include Standard as a reference level (Easy - Standard, Hard - Standard)?
   - What is the interpretation of contrasts that include Standard?

3. **Bias Variation Across Conditions**: Conceptually, should starting-point bias vary by difficulty level, or is it a stable trait?
   - If bias is a baseline response tendency, should it be constant across difficulty levels?
   - Or can bias legitimately vary with signal strength (difficulty)?

4. **Model Specification**: Should the primary model:
   - **Option A**: Include Standard trials but fix bias from Standard-only model?
   - **Option B**: Include Standard trials and estimate bias separately for each difficulty level (current approach)?
   - **Option C**: Exclude Standard trials from primary model entirely (use only for bias estimation)?

5. **Reference Level Selection**: In the primary model, should:
   - **Option A**: Standard be the reference level (current: Intercept = Standard)?
   - **Option B**: Easy be the reference level (Intercept = Easy)?
   - **Option C**: Use a different parameterization (e.g., separate intercepts for each difficulty)?

---

## What I Need

I am genuinely seeking expert guidance on the **scientifically correct and methodologically sound** approach for:
1. Bias estimation in the context of zero-evidence (Standard) trials
2. Contrast selection when one condition (Standard) serves a different purpose than others (Easy, Hard)
3. Model specification that best answers my research questions

I understand that different approaches may be valid depending on the specific research question and theoretical framework. I want to ensure that my methodology is:
- **Scientifically defensible**
- **Appropriate for my research questions**
- **Consistent with DDM modeling best practices**
- **Statistically sound**

Please provide detailed guidance on which approach is most appropriate for my specific situation, including:
- Rationale for the recommended approach
- Potential pitfalls of alternative approaches
- How to interpret results under the recommended approach
- Any relevant literature or examples

Thank you for your expert guidance!

