# Next Steps: Bias Interpretation Investigation

**Status:** Model converged but bias estimate contradicts data - **INVESTIGATION REQUIRED**

---

## 🎯 Current Situation

### ✅ What's Done:
1. ✅ Data preparation complete (17,834 trials)
2. ✅ Standard-only bias model converged (69.5 minutes)
3. ✅ All convergence diagnostics passed

### ⚠️ Critical Issue:
- **Data:** 89.1% "Same" responses → bias should be ~0.11
- **Model:** z = 0.569 → implies bias toward "Different" (contradiction!)

---

## 🔍 Immediate Actions Required

### Step 1: Understand brms Boundary Interpretation

**Question:** In brms `wiener()` family with `rt | dec(dec_upper)`:
- When `dec_upper = 1`, which boundary is hit?
- When `dec_upper = 0`, which boundary is hit?
- How does `bias` (z) relate to these boundaries?

**Action:** Check brms documentation or test with simulation

---

### Step 2: Test Interpretation with Simulation

Create a simple test:
1. Simulate data with known bias (e.g., z = 0.1, expecting 90% "Same")
2. Code responses appropriately
3. Fit model in brms
4. Verify model recovers correct bias

---

### Step 3: Check Current Coding

Verify what `dec_upper` actually represents:
- `dec_upper = 1` → What response? ("Different" or "Same"?)
- `dec_upper = 0` → What response? ("Same" or "Different"?)

**Current assumption:**
- `dec_upper = 1` = "Different" = Upper boundary
- `dec_upper = 0` = "Same" = Lower boundary

**But model results suggest this might be reversed!**

---

### Step 4: Fix Coding (If Needed)

If boundaries are reversed, we need to:
1. Flip `dec_upper` coding: `dec_upper = 1 - dec_upper`
2. Re-fit Standard-only model
3. Verify bias matches data

---

### Step 5: Re-fit Model (After Fix)

Once coding is corrected:
1. Re-run `fit_standard_bias_only.R`
2. Verify bias estimate is ~0.11 (matching 89.1% "Same")
3. Then proceed with Primary model

---

## 📋 Diagnostic Checklist

- [ ] Check brms documentation on `dec()` interpretation
- [ ] Verify boundary definitions in existing code
- [ ] Create simple simulation test
- [ ] Compare with previous model results (if any)
- [ ] Determine if coding needs to be flipped
- [ ] Fix data preparation script if needed
- [ ] Re-fit Standard-only model
- [ ] Verify bias matches data
- [ ] Proceed with Primary model

---

## 🚨 DO NOT PROCEED

**Do not run Primary model until this is resolved!**

The bias interpretation issue must be fixed first, otherwise:
- All bias estimates will be wrong
- Model interpretations will be backwards
- Manuscript results will be incorrect

---

## 💡 Quick Test You Can Do Now

In RStudio, try this quick check:

```r
# Load the model
fit <- readRDS("output/models/standard_bias_only.rds")

# Extract bias samples
library(posterior)
draws <- as_draws_df(fit)
bias_samples <- draws$b_bias_Intercept

# Check distribution
hist(plogis(bias_samples), main="Bias Distribution (Probability Scale)")
abline(v = 0.109, col="red", lwd=2, lty=2)  # Expected from data
abline(v = 0.891, col="blue", lwd=2, lty=2)  # Opposite

# Check what brms thinks the response mapping is
# (This requires checking the model structure)
```

---

**Priority: Resolve bias interpretation BEFORE proceeding!**

