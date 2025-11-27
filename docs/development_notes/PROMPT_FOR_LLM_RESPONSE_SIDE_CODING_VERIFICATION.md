# Prompt for LLM: Response-Side Coding Verification and Implementation

## Context

I am conducting a hierarchical Bayesian Drift Diffusion Model (DDM) analysis using `brms` in R for a same/different discrimination task. My manuscript describes using **response-side coding** (also called "stimulus coding" or "response coding") where:
- Upper boundary = "different" responses  
- Lower boundary = "same" responses

However, I need to verify that my implementation is correct and that I'm using the proper data column for response-side coding.

## Task Design

**Same/Different Discrimination Task:**
- Participants see/hear two stimuli and respond "same" or "different"
- **Standard trials** (Δ=0): Stimuli are identical → correct response = "same"
- **Easy/Hard trials** (Δ>0): Stimuli differ → correct response = "different"
- Response measured from response-screen onset (response-signal design)

## Current Data Structure

### Available Columns

**From raw data (`bap_beh_trialdata_v2.csv`):**
- `resp_is_diff`: Boolean/logical (TRUE = participant chose "different", FALSE = participant chose "same") - **This is the actual response choice**
- `same_diff_resp_code`: Alternative column that may encode response choice
- `resp_is_correct`: Binary indicator (1 = correct, 0 = incorrect) - **This is accuracy, not response choice**
- `stim_is_diff`: Whether stimulus was actually different (1) or same (0)
- `difficulty_level`: Factor with levels "Standard", "Easy", "Hard"
- `rt`: Reaction time in seconds (stored as `same_diff_resp_secs`)

**NOTE:** `resp_is_diff` exists in raw data but appears to have missing values. It is NOT currently included in the analysis-ready file (`bap_ddm_ready.csv`).

**From processed data (`bap_ddm_ready_with_upper.csv`):**
- `response_label`: Character vector ("same" or "different") - **Inferred from iscorr + difficulty_level**
- `dec_upper`: Binary (1 = "different", 0 = "same") - **Created for DDM boundaries**

### Current Implementation Issue

My script `R/00_build_decision_upper_diff.R` currently **INFERS** response-side coding by combining:
- `iscorr` (correctness)
- `difficulty_level` (Standard vs Easy/Hard)

The logic is:
- **Standard trials**: `iscorr=1` → "same", `iscorr=0` → "different"
- **Easy/Hard trials**: `iscorr=1` → "different", `iscorr=0` → "same"

However, I discovered that the raw data file contains `resp_is_diff` which directly indicates the actual response choice. However, this column:
1. Is NOT currently included in the analysis-ready file (`bap_ddm_ready.csv`)
2. Appears to have missing values (NA) in some rows
3. Needs to be added to the data preparation pipeline if we want to use it directly

## Questions for Verification

### Question 1: Direct vs Inferred Response Coding

**Should I use the direct `resp1_isdiff` column, or is inferring from `iscorr + difficulty_level` acceptable?**

Considerations:
- **Direct approach (`resp1_isdiff`)**: Uses actual response data, no inference needed
- **Inferred approach**: More robust if `resp1_isdiff` has missing values or inconsistencies
- **Potential issues**: What if `resp1_isdiff` and the inferred `response_label` don't match? (This could indicate data quality issues)

**My concern**: If `resp1_isdiff` exists and accurately reflects participant responses, why would I infer it rather than use it directly?

### Question 2: Mathematical Formula Implications

**For response-side coding in DDM, do the mathematical formulas change compared to accuracy coding?**

Current model specification (using `brms`):
```r
family = wiener(
    link_bs = "log",      # Boundary separation on log scale
    link_ndt = "log",    # Non-decision time on log scale
    link_bias = "logit"  # Starting point bias on logit scale
)

formula = bf(
    rt | dec(dec_upper) ~ difficulty_level + task + effort_condition + (1|subject_id),
    bs   ~ difficulty_level + task + (1|subject_id),
    ndt  ~ task + effort_condition,
    bias ~ difficulty_level + task + (1|subject_id)
)
```

Where:
- `dec_upper = 1` means "different" (upper boundary)
- `dec_upper = 0` means "same" (lower boundary)

**Questions:**
1. Is this formula correct for response-side coding?
2. Does the interpretation of drift rate (v) change? (v > 0 = drift toward "different"?)
3. Does the interpretation of bias (z) change? (z > 0.5 = bias toward "different"?)
4. Are the link functions (log, logit) still appropriate?

### Question 3: Boundary Assignment Verification

**Is my boundary assignment correct for same/different tasks?**

Current assignment:
- Upper boundary (a) = "different" responses
- Lower boundary (0) = "same" responses

**Verification needed:**
- This seems standard for same/different tasks, but I want confirmation
- Does this match standard DDM practice for detection/discrimination tasks?
- Are there cases where it should be reversed?

### Question 4: Data Validation

**How should I validate that my response-side coding is correct?**

Planned checks:
1. Compare `resp1_isdiff` with inferred `response_label` - should match 100% if inference is correct
2. On Standard trials: Most responses should be "same" (lower boundary = 0)
3. On Easy/Hard trials: Most responses should be "different" (upper boundary = 1)
4. Bias parameter z should reflect the response distribution (if 87.8% "same" on Standard, z should be < 0.5)

**Are there other validation checks I should perform?**

### Question 5: Bias Interpretation with Response-Side Coding

**Given that participants chose "same" on 87.8% of Standard trials, what should the bias parameter (z) be?**

Current results show:
- z = 0.567 (probability scale) > 0.5
- This was interpreted as "bias toward different" in the manuscript

**Problem**: If 87.8% of responses are "same" (lower boundary), and z > 0.5 means bias toward upper boundary ("different"), this is **mathematically impossible**.

**Expected**: With 87.8% "same" responses, z should be approximately 0.12-0.22 (very close to lower boundary).

**Questions:**
1. Is my interpretation correct? (z > 0.5 = bias toward upper boundary)
2. What does z = 0.567 actually mean if using response-side coding?
3. Could this indicate the model is actually using accuracy coding, not response-side coding?

## Code to Review

### Current Response-Side Coding Script

```r
# From R/00_build_decision_upper_diff.R
# INFERS response side from correctness + difficulty level
dd$response_label <- dplyr::case_when(
  dd$difficulty_level == "Standard" & dd$iscorr == 1 ~ "same",
  dd$difficulty_level == "Standard" & dd$iscorr == 0 ~ "different",
  dd$difficulty_level %in% c("Easy", "Hard") & dd$iscorr == 1 ~ "different",
  dd$difficulty_level %in% c("Easy", "Hard") & dd$iscorr == 0 ~ "same",
  TRUE ~ NA_character_
)

dd$dec_upper <- ifelse(dd$response_label == "different", 1L,
                  ifelse(dd$response_label == "same", 0L, NA_integer_))
```

### Proposed Direct Approach

```r
# Step 1: Add resp_is_diff to data preparation pipeline
# In prepare_fresh_data.R or similar, add:
ddm_ready <- ddm_ready %>%
  mutate(
    resp_is_diff = as.logical(resp_is_diff),  # Ensure boolean
    # Convert to DDM boundary coding
    dec_upper = ifelse(resp_is_diff == TRUE, 1L,
                  ifelse(resp_is_diff == FALSE, 0L, NA_integer_)),
    response_label = ifelse(resp_is_diff == TRUE, "different", 
                       ifelse(resp_is_diff == FALSE, "same", NA_character_))
  )

# Step 2: Use dec_upper in model (instead of inferring)
# In model fitting scripts, use:
formula = bf(
    rt | dec(dec_upper) ~ difficulty_level + task + effort_condition + (1|subject_id),
    # ... rest of formula ...
)
```

**Validation Results:**
I validated the inference logic against the direct `resp_is_diff` column in the raw data:
- **100% match** between inferred and direct coding (tested on 1000 rows)
- This confirms the inference logic is mathematically correct

**Questions:**
1. Given that inference matches direct data 100%, does it matter which approach we use?
2. Should we still use the direct column for clarity and robustness?
3. What should we do if `resp_is_diff` has missing values - infer those or exclude them?

## Summary of Concerns

1. **Data Source**: 
   - The raw data HAS `resp_is_diff` (direct response choice) but it's not in analysis-ready file
   - Should I add `resp_is_diff` to the pipeline and use it directly?
   - Or is inferring from `iscorr + difficulty_level` acceptable (and why)?

2. **Formula Correctness**: Are my DDM formulas correct for response-side coding?

3. **Boundary Assignment**: Is upper="different", lower="same" the standard approach?

4. **Bias Interpretation**: Why does z = 0.567 when 87.8% responses are "same"? This suggests either:
   - The model is using accuracy coding (not response-side), OR
   - There's an error in boundary assignment, OR
   - The bias interpretation is incorrect

5. **Validation**: What checks should I perform to ensure coding is correct?

6. **Missing Data**: If `resp_is_diff` has missing values, should we:
   - Infer those from `iscorr + difficulty_level`?
   - Exclude those trials?
   - Use a validation check to ensure inference matches direct data where both exist?

## Expected Output

Please provide:
1. Clear recommendation on using direct vs inferred response coding
2. Verification that my DDM formulas are correct for response-side coding
3. Explanation of the bias (z) interpretation contradiction
4. Step-by-step validation checklist
5. Any necessary corrections to the mathematical formulation or code

Thank you for your thorough review!

