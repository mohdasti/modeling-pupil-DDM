# Prompt for LLM: Pupil-DDM Integration Analysis for PhD Dissertation Chapter

## Context and Overall Goal

I am writing a PhD dissertation chapter on "Diffusion Modeling with Pupil-Linked Arousal (Response-Signal Design)" in older adults. The chapter investigates how effort-induced arousal modulates decision-making processes at a computational level using hierarchical Bayesian drift-diffusion modeling (HDDM).

**Central Research Question:** How does physical effort (manipulated via handgrip force: 5% vs. 40% MVC) affect latent decision-making processes in older adults, as revealed through drift-diffusion model parameters?

**Study Design:**
- **Sample:** 67 older adults (≥65 years, mean age = 71.3 years)
- **Tasks:** Auditory Detection Task (ADT) and Visual Detection Task (VDT)
- **Conditions:** 2 tasks × 3 difficulty levels (Standard/Δ=0, Easy, Hard) × 2 effort conditions (Low 5% MVC, High 40% MVC) = 12 cells per subject
- **Total trials analyzed:** 17,834 trials (after exclusions)
- **Design:** Response-signal design where RTs are measured from response-screen onset (not stimulus onset), constraining t₀ to primarily reflect motor execution

**Primary Model (Already Fitted and Documented):**
The primary DDM model is a hierarchical Wiener model with the following specification:

```r
rt | dec(dec_upper) ~ difficulty_level + task + effort_condition + (1 + difficulty_level | subject_id)
bs ~ difficulty_level + task + (1 | subject_id)
ndt ~ task + effort_condition  # no random effects
bias ~ task + effort_condition + (1 | subject_id)
```

**Key findings from primary model (already reported):**
1. Drift rate (v) decreases under high effort (40% MVC) relative to low effort
2. Boundary separation (a) did NOT increase under high effort (null finding - "strategic rigidity")
3. Non-decision time (t₀) increased modestly under high effort
4. Starting bias (z) shows task differences (VDT < ADT) but no effort effects

---

## The Role of Pupillometry in This Chapter

Pupillometry is **central to the theoretical framework** but **currently underutilized in the Results section**. The chapter's Introduction extensively discusses:

### Theoretical Foundation:

1. **Locus Coeruleus-Norepinephrine (LC-NE) System:** The pupil serves as a non-invasive proxy for LC-NE activity, with:
   - **Baseline pupil diameter** reflecting **tonic LC activity** (baseline arousal state)
   - **Task-evoked pupil response (TEPR)** reflecting **phasic LC activation** (event-related arousal mobilization)

2. **Key Theoretical Predictions:**
   - **Cavanagh et al. (2014) hypothesis:** Pupil dilation predicts increases in decision threshold (boundary separation, a) during high-conflict choices, reflecting a "hold your horses" cognitive control mechanism
   - **De Gee et al. (2020) hypothesis:** Phasic arousal (pupil dilation) can suppress pre-existing choice biases, "resetting" the decision process toward neutrality
   - **Adaptive Gain Theory:** Moderate arousal should enhance evidence accumulation (increase drift rate, v), but supra-optimal arousal in older adults may degrade it

3. **The Critical Question (stated in Introduction, line 438):**
   > "Does the physical arousal from a high-effort handgrip act as a beneficial boost that sharpens neural gain (increasing drift rate, $v$), as Adaptive Gain Theory might predict for moderate arousal? Or, does it trigger a conflict signal that prompts older adults to become more conservative (increasing threshold, $a$), as suggested by the work of Cavanagh et al. [-@cavanagh2014]? Alternatively, if the effort pushes older adults into a supra-optimal state, does the pupil signal reflect internal noise that degrades evidence quality (decreasing $v$)?"

4. **Hypothesis 4 (line 447):** Starting bias ($z$) may move toward 0.5 if high-effort trials evoke strong phasic LC-NE responses that "reset" pre-existing response tendencies [@deGee2020pupil].

### Current Status in Document:

- **Pupillometry Descriptives section (already exists):** Reports data quality, baseline pupil diameter by condition, and TEPR (cognitive AUC) by condition
- **Summary statement (line 2409):** "Future analyses will explore correlations between pupil measures and DDM parameters to test mechanistic hypotheses about how arousal modulates decision-making."
- **Discussion (line 3285):** Mentions that "Future work integrating direct pupillometry measures will be needed to test whether effort-induced phasic arousal responses are indeed present but insufficient to shift bias..."

**Problem:** The Results section lacks a **"Pupil-DDM Integration"** section that actually tests these mechanistic hypotheses. The chapter sets up these predictions but doesn't test them with the available pupil data.

---

## Available Data

### Pupil Data:
The chapter has access to trial-level pupil data with the following measures:

**Data File:** `quick_share_v7/analysis_ready/ch3_triallevel.csv` (or `analysis_ready/ch3_triallevel.csv`)

**Available Pupil Variables (verified in ch3_triallevel.csv):**

1. **Tonic Arousal:**
   - `baseline_B0_mean`: Mean pupil diameter in baseline window (-0.5s to 0s relative to squeeze onset)
   - Reflects **tonic LC activity** (baseline arousal state)

2. **Phasic Arousal (Primary):**
   - `cog_auc_w3`: Area under the curve from target+0.3s to target+3.3s (4.65s to 7.65s relative to squeeze onset)
   - This is the **primary phasic measure** (full TEPR window)
   - Reflects **phasic LC activation** during decision/response period

3. **Phasic Arousal (Sensitivity Analyses):**
   - `cog_auc_respwin`: AUC from target+0.3s until response (Resp1ET)
   - `cog_auc_w1p3`: Early cognitive window (target+0.3s to target+1.3s; 4.65s to 5.65s relative to squeeze onset)
     - More conservative, minimizes post-response contamination
     - Serves as robustness check

4. **Quality Control Flags:**
   - `ddm_ready`: Boolean flag indicating trial is ready for DDM analysis
   - `auc_available_*`: Flags for AUC availability by window
   - `baseline_quality`: Quality flag for baseline pupil (if present)
   - `cog_quality`: Quality flag for cognitive window (if present)

**Data Structure:**
- Trial-level data with columns: `subject_id`, `task`, `difficulty_level`, `effort_condition`, plus all pupil measures above
- Can be aggregated to subject-level means for correlation analysis

### DDM Model Results:
1. **Fitted Model Object:** `output/publish/fit_primary_vza.rds`
   - **Object name when loaded:** `fit_primary_vza`
   - **Load command:** `fit_primary_vza <- readRDS("output/publish/fit_primary_vza.rds")`
2. **Subject-level parameter estimates:** Can be extracted using `coef()`, `ranef()`, or posterior draws
3. **Available outputs:**
   - Fixed effects tables
   - Contrasts tables
   - Convergence diagnostics
   - PPC results

### What Can Be Extracted:

#### Option 1: `ranef()` - Summary Statistics Only
**Structure of `ranef(fit_primary_vza)`:**
```
List of 1
 $ subject_id: num [1:67, 1:4, 1:3]
  - 67 subjects (rows): "BAP001", "BAP003", "BAP101", etc.
  - 4 statistics (columns): "Estimate", "Est.Error", "Q2.5", "Q97.5"
  - 3 parameters (slices): "Intercept", "bs_Intercept", "bias_Intercept"
```

**Parameter slices:**
- `"Intercept"` - Drift rate (v) random effects (deviations from group mean)
- `"bs_Intercept"` - Boundary separation (a/bs) random effects
- `"bias_Intercept"` - Starting-point bias (z) random effects

**Note:** No `"ndt_Intercept"` because the primary model doesn't have subject-level random effects for non-decision time.

**Limitation:** `ranef()` provides only summary statistics (point estimates, SEs, CIs). This is fine for descriptive purposes but **insufficient for dissertation-grade correlation analyses** because it doesn't propagate uncertainty through the correlation calculation.

#### Option 2: Posterior Draws (RECOMMENDED for Correlation Analysis)
For proper statistical inference with uncertainty quantification, use **posterior draws** of subject-level parameters:

**Method A: `coef(fit_primary_vza, summary = FALSE)`**
- Returns subject-specific coefficients (fixed + random effects) for each posterior draw
- Structure: 3D array [draws, subjects, parameters]
- Allows draw-wise correlation computation

**Method B: Extract from posterior draws directly**
- Use `posterior::as_draws_df(fit_primary_vza)` to get all posterior variables
- Reconstruct subject-level intercepts per draw:
  - `v_subj_draw = b_Intercept + r_subject_id[SUBJECT,Intercept]`
  - `bs_subj_draw = b_bs_Intercept + r_subject_id__bs[SUBJECT,Intercept]`
  - `z_subj_draw = b_bias_Intercept + r_subject_id__bias[SUBJECT,Intercept]`

**Why posterior draws are critical:**
- Correlations computed on point estimates ignore uncertainty in DDM parameter estimates
- Draw-wise correlations allow proper Bayesian inference: compute correlation for each draw, then summarize the posterior distribution of correlation coefficients
- Provides credible intervals and probability statements (e.g., Pr(r > 0))
- Essential for testing mechanistic hypotheses (Cavanagh, de Gee predictions) with appropriate uncertainty quantification

---

## What's Missing / Needs to Be Calculated

### 1. Subject-Level Data Integration:
**Missing:** A merged dataset combining:
- Subject-level DDM parameter estimates (from primary model) **using posterior draws**
- Subject-level pupil measures (mean baseline pupil, mean cognitive AUC, aggregated across relevant conditions)

**Action Needed:**
- **Extract subject-level DDM parameters using posterior draws** (NOT just `ranef()` summaries)
  - Use `coef(fit_primary_vza, summary = FALSE)` OR
  - Extract from `as_draws_df(fit_primary_vza)` and reconstruct: `v_subj = b_Intercept + r_subject_id[...]`
  - This provides subject-level intercepts for each posterior draw (essential for proper correlation analysis)
- Aggregate trial-level pupil data to subject-level means
  - Apply quality filters: `ddm_ready == TRUE`, non-NA pupil measures
  - Compute means: `tonic_mean`, `phasic_mean_w3`, `phasic_mean_respwin`, `phasic_mean_w1p3`
  - Optionally: condition-specific means (by task, effort) for exploratory analyses
- Merge the two datasets by `subject_id`

### 2. Correlation Analyses:
**Missing:** Statistical tests of correlations between:
- Baseline pupil (tonic arousal) ↔ Drift rate (v)
- Baseline pupil (tonic arousal) ↔ Boundary separation (a)
- Baseline pupil (tonic arousal) ↔ Bias (z)
- Cognitive AUC (phasic arousal) ↔ Drift rate (v)
- Cognitive AUC (phasic arousal) ↔ Boundary separation (a)
- Cognitive AUC (phasic arousal) ↔ Bias (z)

**Critical Methodological Requirement:**
- **Use posterior draw-wise correlations**, not correlations on point estimates
- For each posterior draw: compute correlation between subject-level DDM parameter and subject-level pupil measure
- Summarize posterior distribution of correlation coefficients:
  - Mean, median
  - 95% credible interval (2.5%, 97.5%)
  - Probability statements: Pr(r > 0), Pr(r < 0)
- This properly propagates uncertainty from DDM parameter estimation through to correlation inference

**Questions:**
- Should correlations be computed overall or separately by task/effort condition?
  - **Recommendation:** Start with overall subject-level correlations (aggregated across all conditions) for primary analysis
  - Condition-specific analyses can be exploratory/sensitivity
- Should correlations use subject-level means aggregated across all trials, or condition-specific means?
  - **Recommendation:** Overall means for primary analysis (tests individual differences in tonic/phasic arousal and DDM parameters)
- Should we account for multiple comparisons?
  - Yes, if testing multiple pupil measures × multiple DDM parameters
  - Consider false discovery rate (FDR) correction or Bayesian multiplicity adjustments

### 3. Pupil-DDM Models:
**Defined but Status Unknown:** In the analysis code (`scripts/02_statistical_analysis/02_ddm_analysis.R`), there are two pupil-DDM models defined:

```r
"Model6_Pupillometry" = list(dataType = "pupil", formula = brms::bf(
    rt | dec(decision) ~ effort_arousal_scaled + tonic_arousal_scaled + (1|subject_id),
    bs ~ 1 + (1|subject_id),
    ndt ~ 1,
    bias ~ 1 + (1|subject_id)
)),
"Model6a_Pupil_Task" = list(dataType = "pupil", formula = brms::bf(
    rt | dec(decision) ~ effort_arousal_scaled + tonic_arousal_scaled + task + (1|subject_id),
    bs ~ 1 + (1|subject_id),
    ndt ~ 1,
    bias ~ 1 + (1|subject_id)
))
```

**Issues:**
- These models use `effort_arousal_scaled` and `tonic_arousal_scaled` - I need to verify these variables exist in the pupil dataset
- Models are conditional on `PUPIL_FEATURES_AVAILABLE` flag - unclear if they were actually fitted
- Model specification only includes pupil measures on drift rate (v), not on boundary or bias - this may be suboptimal for testing the theoretical hypotheses
- No models test whether phasic arousal predicts boundary separation (a) - which is the key Cavanagh et al. prediction

**Questions:**
- Were these models fitted? If not, should they be?
- Are the variable names (`effort_arousal_scaled`, `tonic_arousal_scaled`) correct, or should they map to `cognitive_auc` and `baseline_B0`?
- Should we fit additional models that test pupil effects on boundary (a) and bias (z), not just drift (v)?
- Should models include trial-level pupil measures or subject-level means?

### 4. Visualizations:
**Missing:**
- Scatter plots: Pupil measure (x-axis) vs. DDM parameter (y-axis) with regression lines
- Correlation matrix/heatmap showing all pupil-DDM relationships
- Potentially: Separate visualizations by task or effort condition

### 5. Results Section Content:
**Missing:** A complete "Pupil-DDM Integration" section in the Results that includes:
- Introduction/subsection header
- Text describing the analyses
- Tables of correlation results
- Figures showing relationships
- Interpretation connecting to theoretical predictions

---

## Key Methodological Considerations

### 1. Aggregation Level:
**Question:** Should correlations be computed at:
- **Subject level** (mean pupil measures vs. subject-level DDM parameter estimates)? ← Most common approach
- **Trial level** (trial-level pupil measures vs. trial-level DDM parameter predictions)? ← More complex, requires different approach

**My preference:** Subject-level correlations are more appropriate for testing individual differences and are less susceptible to within-subject dependencies. However, I'm open to suggestions.

### 2. Pupil Measure Aggregation:
**Question:** When aggregating to subject level, should we:
- Compute overall mean across all trials?
- Compute separate means by task (ADT vs. VDT)?
- Compute separate means by effort condition (Low vs. High)?
- Compute separate means by difficulty level?

**My thinking:** For testing the mechanistic hypotheses (Cavanagh, de Gee, etc.), we likely want to see if:
- Baseline pupil (tonic) relates to individual differences in bias/decision threshold
- Cognitive AUC (phasic) relates to individual differences in drift rate/boundary separation

This suggests subject-level means aggregated across conditions might be most appropriate, but condition-specific analyses could be informative.

### 3. Model Specification for Pupil-DDM Models:
**Current Model6 specification:**
- Only includes pupil on drift rate (v)
- Does NOT test pupil effects on boundary (a) or bias (z)
- Uses scaled variables that may not match available data

**Theoretical predictions suggest we need:**
- **Phasic arousal (cognitive AUC) → Boundary separation (a)**: Cavanagh et al. prediction
- **Phasic arousal (cognitive AUC) → Bias (z)**: de Gee et al. prediction
- **Tonic arousal (baseline pupil) → Bias (z) or Boundary (a)**: Baseline arousal effects

**Questions:**
- Should we fit models with pupil measures as predictors on multiple DDM parameters (v, a, z)?
- Should we fit separate models for each parameter, or one comprehensive model?
- How should we handle scaling/normalization of pupil measures?

### 4. Statistical Approach:
**For correlations:**
- Pearson correlations with confidence intervals?
- Bayesian correlations (given we're using Bayesian DDM)?
- Partial correlations controlling for task/effort?

**For pupil-DDM models:**
- Trial-level models with pupil as trial-varying predictor?
- Subject-level models with mean pupil as subject-level predictor?
- Hierarchical models that account for both trial-level and subject-level variation?

---

## Specific Questions and Requests for Suggestions

### Primary Questions:

1. **What analyses should I prioritize for a PhD dissertation chapter?**
   - Should I focus on subject-level correlations, or also fit pupil-DDM models?
   - Is one approach more appropriate for testing the theoretical hypotheses?

2. **How should I structure the Pupil-DDM Integration Results section?**
   - What subsections should it include?
   - What order should analyses be presented in?
   - How much detail is appropriate for a dissertation chapter?

3. **Regarding Model6_Pupillometry:**
   - Should I attempt to fit these models, or are subject-level correlations sufficient?
   - If I fit them, how should I modify the specification to better test the theoretical predictions?
   - What variable names/mappings should I use for the pupil measures?

4. **What level of aggregation is most appropriate?**
   - Subject-level means across all conditions?
   - Condition-specific means?
   - Task-specific means?

5. **How should I handle the multiple theoretical predictions?**
   - Should I test each hypothesis separately (Cavanagh: phasic → a; de Gee: phasic → z; etc.)?
   - Should I present results in order of theoretical importance?
   - How should I interpret null findings?

6. **What visualizations are essential vs. optional?**
   - Minimum required figures for dissertation quality?
   - Suggested additional visualizations that would strengthen the chapter?

7. **Should I include any sensitivity analyses?**
   - Test with early cognitive window (W1.3) instead of full window?
   - Test separately by task or effort condition?
   - Test with different aggregation methods?

8. **How should I connect these results to the primary DDM findings?**
   - The primary model already found effort effects on v and t₀, but null on a
   - How should pupil-DDM integration results complement or extend these findings?
   - Should I discuss whether pupil measures "explain" the effort effects found in the primary model?

9. **Code implementation suggestions:**
   - What R packages/functions should I use for extracting subject-level DDM parameters?
   - What's the best approach for merging DDM parameters with pupil data?
   - Any specific considerations for Bayesian models (if using Bayesian correlations)?

10. **Interpretation and discussion:**
    - How should I interpret correlations in the context of the null findings (e.g., no effort effect on boundary separation)?
    - Should I discuss potential mechanisms (LC-NE system dynamics) even if results are null/weak?
    - How should I reconcile the Introduction's strong theoretical predictions with potentially null results?

---

## Additional Context

### Existing Code Infrastructure:
- I have scripts for extracting DDM parameters: `scripts/02_statistical_analysis/create_ddm_visualizations.R` (lines 281-324) shows extraction using `coef()`
- I have pupil data loading code in the Quarto document that tries multiple file paths
- I have correlation visualization code (though for DDM-DDM correlations, not pupil-DDM)

### Dissertation Timeline:
- This is a critical missing piece of the chapter
- I want to implement this properly rather than rush it
- Quality and methodological rigor are priorities

### Chapter Structure (Current):
- Introduction (sets up pupil-DDM integration)
- Methods (includes pupillometry preprocessing)
- Results:
  - Sample characteristics
  - Behavioral performance
  - **Pupillometry Descriptives** ← exists
  - **Pupil-DDM Integration** ← MISSING (needs to be added here)
  - Bias estimates
  - Fixed effects
  - Parameter contrasts
  - Individual differences
  - Model convergence & selection
  - Difficulty/effort/task effects
  - Model fit (PPC)
- Discussion (currently mentions future work for pupil integration)

---

## My Request

Please provide:
1. **Prioritized recommendations** for what analyses to implement first
2. **Specific methodological guidance** on aggregation level, model specification, and statistical approach
3. **Suggested structure** for the Results section (subsections, order, level of detail)
4. **Code implementation suggestions** or pseudo-code for key analyses
5. **Interpretation guidance** for how to connect results to theoretical predictions, especially if results are null/weak
6. **Quality standards** for what constitutes "dissertation-ready" analysis of pupil-DDM integration

---

## Technical Implementation Details (For Reference)

### Exact Model Object:
- **File:** `output/publish/fit_primary_vza.rds`
- **Object name:** `fit_primary_vza`
- **Load:** `fit_primary_vza <- readRDS("output/publish/fit_primary_vza.rds")`

### `ranef(fit_primary_vza)` Structure:
```
List of 1
 $ subject_id: num [1:67, 1:4, 1:3]
  - 67 subjects (rows)
  - 4 statistics: "Estimate", "Est.Error", "Q2.5", "Q97.5"
  - 3 parameters: "Intercept" (v), "bs_Intercept" (a), "bias_Intercept" (z)
```

**Note:** `ranef()` provides summaries only. For correlation analysis, use posterior draws via `coef(fit_primary_vza, summary = FALSE)` or `as_draws_df(fit_primary_vza)`.

### Pupil Data Variables (in ch3_triallevel.csv):
- **Tonic:** `baseline_B0_mean`
- **Phasic (primary):** `cog_auc_w3`
- **Phasic (sensitivity):** `cog_auc_respwin`, `cog_auc_w1p3`
- **QC flags:** `ddm_ready`, `auc_available_*`, `baseline_quality`, `cog_quality`

---

Thank you for your detailed consideration!

