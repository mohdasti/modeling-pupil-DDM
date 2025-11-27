# Bias Interpretation Issue - Complete Summary

**Date:** 2025-11-25  
**Status:** ⚠️ **BLOCKING** - Must resolve before proceeding

---

## 🚨 The Problem

**Your Model Results:**
- Bias z = 0.569 (on probability scale)
- Standard trials: 10.9% "Different" (dec_upper=1), 89.1% "Same" (dec_upper=0)

**The Contradiction:**
- If z = 0.569, model predicts ~57% "Different" responses
- But data shows only 10.9% "Different"
- **This is a 46% mismatch!**

---

## 🔍 What We Tested

### Test 1: Simple Diagnostic
- Checked if bias matches data directly → ✗ No match (0.460 difference)
- Checked if (1 - bias) matches data → ✗ Still no match (0.322 difference, but closer)

### Test 2: Including Task/Effort Effects
- Checked bias by condition (ADT/VDT × High/Low effort)
- **None of the conditions matched** (all differences > 0.40)

### Test 3: Flipped Coding Test
- Tested if boundaries are reversed
- **Still no good match** (best difference = 0.322)

---

## 💡 Key Findings

1. **Task/effort effects are present** but don't explain the mismatch
2. **Flipped difference (0.322) is closer** than direct (0.460), suggesting possible boundary confusion
3. **None of the conditions match well**, so it's not just a coding issue

---

## 🤔 Possible Explanations

### Option 1: Boundary Interpretation Wrong
Maybe in brms, `dec()` interprets boundaries differently than expected:
- `dec_upper=1` might actually mean lower boundary?
- Or brms uses different conventions?

**Evidence:** Flipped match is closer (0.322 vs 0.460)

### Option 2: Bias Parameter Interpretation
Maybe z doesn't directly predict response proportions when:
- Drift is present (even if small, v = -0.036)
- Random effects are large
- Task/effort effects interact

**Evidence:** Task/effort effects are present and may be large

### Option 3: Model Misspecification
Maybe the model structure doesn't match the data:
- Missing interactions?
- Wrong link functions?
- Other issues?

---

## ✅ What to Check Next

### Priority 1: Verify brms Documentation

**Critical Question:** In brms `wiener()` with `dec()`:
- What does `dec(decision)` where `decision=1` actually mean?
- Upper boundary or lower boundary?
- How does bias z relate to this?

**Action:** Check brms documentation or brms GitHub issues

### Priority 2: Review Existing Code

Looking at your codebase:
- `scripts/modeling/parameter_recovery.R` uses: `choice = as.integer(rw$resp=="upper")`
- This suggests `choice=1` when `resp=="upper"` (upper boundary)
- Your code uses: `dec_upper=1` when `resp_is_diff==TRUE` ("Different")
- Your manuscript says: "upper boundary = Different"

**So coding should be correct IF:**
- `resp=="upper"` in rtdists means upper boundary
- And brms interprets `dec(1)` as upper boundary

**But maybe:** brms interprets `dec(1)` as lower boundary?

### Priority 3: Check rtdists Convention

**Question:** In `rwiener()` from rtdists package:
- What does `resp=="upper"` actually mean?
- Does it match brms interpretation?

---

## 🎯 Recommended Next Steps

### Step 1: Consult brms Documentation

1. Check brms documentation on `dec()` function
2. Look for examples in brms GitHub
3. Check Stack Overflow for similar issues

### Step 2: Simple Test Model

Create a minimal test:
```r
# Simple model with NO task/effort effects
formula_simple <- bf(
  rt | dec(dec_upper) ~ 1,
  bs ~ 1,
  ndt ~ 1,
  bias ~ 1
)

# Fit on Standard trials only
# Check if intercept bias matches data
```

This will isolate whether task/effort effects are the issue.

### Step 3: Manual Verification

Manually check what the model predicts:
```r
# Extract fitted values
predicted <- predict(fit)

# Check predicted vs actual response proportions
# This will show what the model actually thinks
```

---

## ⚠️ DO NOT PROCEED

**Do NOT run Primary model until this is resolved!**

If the bias interpretation is wrong:
- All bias estimates will be incorrect
- All interpretations will be backwards
- Manuscript results will be wrong
- You'll waste hours on incorrect models

---

## 📋 Files Created

1. **`R/simple_bias_diagnostic.R`** - Quick bias check
2. **`R/diagnose_bias_with_effects.R`** - Check including task/effort
3. **`R/test_flipped_coding.R`** - Test reversed boundaries
4. **`WHAT_NEXT_SUMMARY.md`** - Action items
5. **`CRITICAL_BIAS_INTERPRETATION_FIX.md`** - Analysis

---

## 💡 Key Insight

The fact that **(1 - bias) is closer** to the data than bias itself suggests:
- Boundaries might be reversed
- OR bias interpretation is different than expected
- OR there's a systematic offset

**But the mismatch is still large (0.322),** so there's more going on than just a simple reversal.

---

**Priority: Resolve bias interpretation BEFORE proceeding!** 🚨

