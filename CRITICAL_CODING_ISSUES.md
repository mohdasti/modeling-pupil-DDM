# Critical Decision Coding and Interpretation Issues

## Executive Summary

Your manuscript and model code have **severe contradictions** that must be resolved before publication. The primary model is using **accuracy coding** (1=correct, 0=incorrect), but your manuscript describes **response-side coding** (upper="different", lower="same"). This creates mathematical impossibilities in your reported results.

---

## Issue #1: Decision Coding Mismatch

### What the Code Actually Does

**File:** `R/fit_primary_vza.R` (line 113)
```r
decision = as.integer(decision)  # 1=correct, 0=incorrect
```

The model derives `decision` from `iscorr` (accuracy coding):
- `decision = 1` means **correct response**
- `decision = 0` means **incorrect response**

### What the Manuscript Says

**File:** `reports/chap3_ddm_results.qmd` (line 341)
> "We employed **response-side coding** (also called "stimulus coding" or "response coding") where the upper boundary corresponds to "different" responses and the lower boundary corresponds to "same" responses"

### The Problem

With accuracy coding:
- On **Standard trials**: `decision=1` means "same" (correct when stimuli are identical)
- On **Easy/Hard trials**: `decision=1` means "different" (correct when there's a difference)

**This means the boundary meaning changes depending on difficulty level**, which is theoretically incoherent for a DDM. The model cannot distinguish between:
- Bias toward "same" responses
- Bias toward "different" responses  
- Bias toward correct responses

### The Solution File Exists But Isn't Used

**File:** `R/00_build_decision_upper_diff.R` creates proper response-side coding:
- `dec_upper = 1` means "different" response (upper boundary)
- `dec_upper = 0` means "same" response (lower boundary)

But this creates `bap_ddm_ready_with_upper.csv`, which is **NOT** what the primary model loads.

---

## Issue #2: Bias Interpretation Contradiction

### The Data
- Participants chose "same" on **87.8%** of Standard trials
- Reported bias: **z = 0.567** (probability scale, > 0.5)

### The Contradiction

**If using accuracy coding (which the model actually uses):**
- On Standard trials, "same" = correct → `decision = 1`
- z > 0.5 means bias toward `decision = 1` (correct responses)
- This would be **consistent** with 87.8% "same" responses

**If using response-side coding (which the manuscript claims):**
- Upper boundary = "different" → `dec_upper = 1`
- Lower boundary = "same" → `dec_upper = 0`
- z > 0.5 means bias toward upper boundary ("different")
- With 87.8% "same" responses, z **MUST** be < 0.5 (around z ≈ 0.12-0.22)

**Conclusion:** The reported z = 0.567 is **mathematically impossible** if using response-side coding with 87.8% "same" responses.

---

## Issue #3: Drift Rate Reference Levels

### What You Reported
Fixed Effects Table shows:
- Intercept = 1.024 (claimed to be Standard drift)
- Difficulty: Easy = -0.165
- Difficulty: Hard = -1.665

This would imply:
- Standard drift = 1.024 (strong positive drift toward "different") ❌ **IMPOSSIBLE** for identical stimuli
- Easy drift = 1.024 - 0.165 = 0.859 (lower than Standard) ❌ **IMPOSSIBLE**

### The Problem
The reference level for `difficulty_level` is likely **not** "Standard". Check:
1. Factor level ordering in your model
2. Whether contrasts are set up correctly
3. If "Easy" is actually the intercept

---

## Required Fixes

### Fix #1: Verify Actual Decision Coding Used

**Action:** Check which decision variable the fitted models actually used:

```r
# Load your fitted model
model <- readRDS("output/models/primary_vza.rds")

# Check the data used to fit it
model_data <- model$data
head(model_data[, c("decision", "difficulty_level", "iscorr")])
table(model_data$decision, model_data$difficulty_level)
```

### Fix #2: Correct the Manuscript OR Re-fit Models

**Option A: Update Manuscript to Match Code (if accuracy coding is correct)**
- Remove claims about response-side coding
- Clarify that bias is toward correct responses, not specific response alternatives
- Acknowledge limitations of accuracy coding for bias estimation

**Option B: Re-fit All Models with Response-Side Coding (RECOMMENDED)**
- Use `R/00_build_decision_upper_diff.R` output (`bap_ddm_ready_with_upper.csv`)
- Change model to use `dec_upper` instead of `decision`
- Re-fit all models
- Re-calculate all bias estimates and contrasts

### Fix #3: Verify and Fix Bias Interpretation

**If using accuracy coding:**
- z > 0.5 = bias toward **correct responses**
- On Standard trials, this means bias toward "same" (which is correct)
- This would be **consistent** with 87.8% "same" responses

**If using response-side coding:**
- z > 0.5 = bias toward upper boundary = "different"
- With 87.8% "same" responses, z should be around **0.12-0.22**
- Current z = 0.567 is **mathematically impossible**

### Fix #4: Check Drift Rate Reference Levels

```r
# Check factor levels
levels(model$data$difficulty_level)

# Check contrast matrix
contrasts(model$data$difficulty_level)

# Verify Standard is the reference
model$data$difficulty_level <- relevel(model$data$difficulty_level, ref = "Standard")
```

---

## Immediate Action Items

1. ✅ **Verify which decision coding was actually used** in the fitted models
2. ✅ **Check bias z values** - are they > 0.5 or < 0.5?
3. ✅ **Verify drift rate reference levels** in Fixed Effects table
4. ✅ **Decide on coding approach** - accuracy or response-side?
5. ✅ **Re-fit models if necessary** to match manuscript description
6. ✅ **Update manuscript** to match actual model implementation

---

## Recommendation

**I strongly recommend Option B:** Re-fit all models with proper response-side coding. This will:
- Allow proper bias estimation (bias toward "same" vs "different")
- Enable testing of your hypotheses about arousal effects on bias
- Match what your manuscript claims
- Make the results theoretically coherent

The script `R/00_build_decision_upper_diff.R` already exists and creates the correct coding. You just need to:
1. Use `bap_ddm_ready_with_upper.csv` instead of `bap_ddm_ready.csv`
2. Change `dec(decision)` to `dec(dec_upper)` in all model formulas
3. Re-fit all models
4. Re-calculate all results

---

## Questions to Answer Before Proceeding

1. What decision variable does your fitted `primary_vza` model actually use?
2. What are the actual z values from your bias model? (Check `output/publish/bias_standard_only_levels.csv`)
3. What is the reference level for `difficulty_level` in your fixed effects?
4. Do you want to use accuracy coding or response-side coding?

Once we answer these, we can fix the manuscript accordingly.

