# Prompt for LLM: posterior_predict Signed RTs Issue

## Critical Issue

I'm validating a brms wiener DDM model using `posterior_predict()`, but getting 100% "Different" predictions when I should get ~11%.

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

**Data Coding:**
- `dec_upper = 1` means "Different" (upper boundary)
- `dec_upper = 0` means "Same" (lower boundary)
- Observed: 10.9% "Different", 89.1% "Same"

---

## What I'm Doing

```r
# Generate posterior predictions
post_preds <- posterior_predict(fit, newdata = pred_data, ndraws = 1000)

# Extract choices from sign
pred_choices <- post_preds > 0  # Positive = Different, Negative = Same

# Calculate proportion "Different"
pred_prop_diff <- apply(pred_choices, 1, function(x) mean(x, na.rm = TRUE))
```

---

## The Problem

**Result:** 100% "Different" predictions (ALL RTs are positive!)

This suggests either:
1. The sign interpretation is reversed
2. `posterior_predict()` doesn't return signed RTs for wiener models
3. There's a different way to extract choices

---

## Model Parameters

- **Drift (v):** -1.260 (negative = evidence for "Same")
- **Bias (z):** 0.567 (slightly toward "Different")
- **Boundary (a):** 2.275

With negative drift, we should see mostly "Same" responses (~89%), not 100% "Different"!

---

## Questions

1. **Does `posterior_predict()` for brms wiener models actually return signed RTs?**
   - Or does it return something else?
   - Should positive/negative indicate boundary hits?

2. **If it does return signed RTs, is my interpretation correct?**
   - Positive RT = Upper boundary = "Different"?
   - Or is it reversed?

3. **If it doesn't return signed RTs, how do I extract choices?**
   - Do I need to use `posterior_epred()` differently?
   - Should I extract parameters and calculate analytically?

4. **What's the standard way to validate choice proportions for brms wiener models?**
   - What do other researchers do?
   - Is there a built-in brms function for this?

5. **Why are ALL predicted RTs positive?**
   - This seems wrong - negative drift should produce negative RTs for "Same" responses
   - What could cause this?

---

## Additional Context

**Earlier test:**
- `posterior_epred()` returns values [0.58, 0.64] - these are expected RTs (seconds)
- We were told `posterior_predict()` returns signed RTs where sign indicates boundary

**But now:**
- ALL RTs from `posterior_predict()` are positive
- No negative values at all
- This suggests either interpretation is wrong or the output format is different

---

## Expected Output

Please provide:

1. **What `posterior_predict()` actually returns for brms wiener models**
2. **Correct way to extract choice predictions**
3. **Why all RTs might be positive**
4. **Standard validation approach for choice proportions**

---

**This is critical - I'm getting 100% "Different" when I should get ~11%!**

Thank you for your help!

