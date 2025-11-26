# Final Bias Diagnosis - What's Next

**Date:** 2025-11-25  
**Model Status:** ✅ Converged  
**Issue Status:** ⚠️ **CRITICAL** - Bias doesn't match data

---

## 📊 Summary

- ✅ Model converged perfectly (Rhat=1.0007, ESS>4000)
- ✅ Other parameters look reasonable
- ❌ **Bias estimate (z=0.569) contradicts data (10.9% "Different")**

---

## 🔍 What We Found

1. **Bias doesn't match data** (0.460 difference)
2. **Flipped is closer** (0.322 difference) but still not good
3. **Task/effort effects present** but don't explain mismatch
4. **None of the conditions match well**

---

## ✅ Next Steps (Priority Order)

### 1. Check brms Documentation on `dec()` Function

**Critical:** Understand exactly how brms interprets `dec(dec_upper)`.

**Questions:**
- Does `dec_upper=1` mean upper boundary or lower?
- How does bias z relate to the decision coding?
- Is there a default convention?

**Resources:**
- `?brms::dec` in R
- brms GitHub: https://github.com/paul-buerkner/brms
- brms documentation

### 2. Create Minimal Test Model

Fit a simpler model with NO task/effort effects:

```r
# Minimal model - just intercept
formula_minimal <- bf(
  rt | dec(dec_upper) ~ 1,
  bs ~ 1,
  ndt ~ 1,
  bias ~ 1
)

# Fit on Standard trials only
# Check if bias intercept matches data
```

This will isolate whether task/effort effects are causing the issue.

### 3. Review Your Existing Parameter Recovery Script

Look at `scripts/modeling/parameter_recovery.R`:
- It codes: `choice = as.integer(rw$resp=="upper")`
- This suggests `choice=1` means upper boundary
- Does this match brms interpretation?

### 4. Test with Known Data

If possible, test with a simple simulated dataset where you know the true bias, and verify brms recovers it correctly.

---

## ⚠️ DO NOT PROCEED

**Do NOT:**
- Run Primary model
- Continue with other analyses
- Write up results

**DO:**
- Resolve this bias issue first
- Verify interpretation is correct
- Then proceed with confidence

---

## 📝 Key Question

**In brms wiener model:**
- When you use `rt | dec(dec_upper)` where `dec_upper` is 0 or 1
- What does `dec_upper=1` actually mean in terms of boundaries?
- And how does `bias` (z) relate to this?

**This MUST be answered before proceeding!**

---

**Priority: Answer the boundary interpretation question!** 🚨

