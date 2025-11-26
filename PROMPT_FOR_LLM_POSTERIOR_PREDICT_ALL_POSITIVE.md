# Prompt for LLM: posterior_predict Returns All Positive RTs

## Critical Issue

I'm trying to validate a brms wiener DDM model, but `posterior_predict()` returns **ALL positive RT values** - no negative values at all. This means I can't use sign to extract choices.

---

## Model Details

**Formula:**
```r
rt | dec(dec_upper) ~ difficulty_level + task + effort_condition + (1|subject_id)
bs   ~ difficulty_level + task + (1|subject_id)
ndt  ~ task + effort_condition
bias ~ difficulty_level + task + (1|subject_id)
```

**Family:** `wiener(link_bs = "log", link_ndt = "log", link_bias = "logit")`

**Data:**
- `dec_upper = 1` means "Different" (upper boundary)
- `dec_upper = 0` means "Same" (lower boundary)
- Observed: 10.9% "Different", 89.1% "Same"

---

## The Problem

**What I'm doing:**
```r
post_preds <- posterior_predict(fit, newdata = pred_data, ndraws = 1000)
# ALL values are positive! Range: [0.38, 2.84] seconds
# No negative values at all

pred_choices <- post_preds > 0  # This gives 100% "Different"!
```

**Result:** 100% "Different" predictions (because ALL RTs are positive)

---

## Test Results

**Test on 10 trials:**
- `posterior_predict()` returns: ALL positive values [0.38, 2.84]
- Negative values: **0**
- Positive values: **30** (all of them!)

**Observed data for those trials:**
- `dec_upper`: [0, 0, 0, 0, 0, 0, 0, 1, 0, 1] (mostly "Same")
- Observed RTs: [0.83, 1.39, 1.34, 0.64, 0.73, 0.67, 0.99, 0.50, 0.63, 0.50]

**Model parameters:**
- Drift (v): -1.260 (negative = evidence for "Same")
- With negative drift, we should see mostly "Same" responses, not 100% "Different"!

---

## Key Questions

1. **Does `posterior_predict()` for brms wiener models return signed RTs?**
   - The documentation suggests it should
   - But ALL my values are positive
   - Is there a setting or option I'm missing?

2. **If it doesn't return signed RTs, how do I extract choices?**
   - Do I need to extract parameters and calculate analytically?
   - Is there a different function I should use?
   - How does brms handle the `dec()` part of the formula?

3. **What does the `dec()` in `rt | dec(dec_upper)` actually do?**
   - Does it encode the choice in the RT somehow?
   - Or is it just metadata that brms uses during fitting?
   - Does it affect what `posterior_predict()` returns?

4. **Alternative approach:**
   - Should I use `posterior_linpred()` to extract parameters (v, a, z)?
   - Then calculate choice probabilities analytically?
   - Then sample choices from those probabilities?

5. **What's the standard approach in brms wiener models?**
   - How do researchers validate choice proportions?
   - Is there a built-in function or standard method?

---

## Codebase Evidence

Found this comment in the codebase:
```r
# posterior_predict() for wiener returns RT samples; to get choices we simulate
# from the model-implied boundary crossing sign via posterior_epred on bias and drift.
```

This suggests we need to use `posterior_epred` on bias and drift to get choices, not just `posterior_predict()`.

---

## What I've Tried

1. **Using `posterior_predict()` directly** - All RTs positive, can't extract choices
2. **Using `posterior_epred()`** - Returns expected RT (0.58-0.64s), not probabilities
3. **Sign-based extraction** - Doesn't work (all positive)

---

## Expected Output

Please provide:

1. **Why ALL RTs are positive** from `posterior_predict()`
2. **How to extract choices** from brms wiener model predictions
3. **What the `dec()` part does** and how it relates to predictions
4. **The correct validation approach** for choice proportions

---

**This is critical - I need to validate that my model predicts ~11% "Different" not 100%!**

Thank you for your help!

