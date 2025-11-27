# CRITICAL: Bias Interpretation Issue - Analysis & Fix

**Date:** 2025-11-25  
**Status:** ⚠️ **BLOCKING** - Must resolve before proceeding

---

## 🚨 The Problem

**Model Results:**
- Bias z = 0.569 (on probability scale)
- Data shows: 10.9% "Different" (dec_upper=1)
- Data shows: 89.1% "Same" (dec_upper=0)

**The Contradiction:**
- If `dec_upper=1` means "Different" = upper boundary
- And z = 0.569 means starting 56.9% toward upper boundary
- Then model predicts ~56.9% "Different" responses
- **But data shows only 10.9% "Different"!**

---

## 🔍 Key Finding

**Diagnostic Results:**
- Direct match difference: 0.460
- **Flipped match difference: 0.322** ← **Closer!**

This suggests boundaries might be **reversed**.

---

## 💡 Hypothesis

**Possible Issue:** In brms, `dec()` function might interpret:
- `dec_upper=1` as hitting the **LOWER** boundary (not upper!)
- `dec_upper=0` as hitting the **UPPER** boundary (not lower!)

**OR:** The bias parameter interpretation might be:
- z = starting point distance from **LOWER** boundary
- So z = 0.569 means 56.9% toward upper
- But if dec_upper=1 means lower, then z=0.569 → 56.9% hit lower = 56.9% "Different"
- And (1-z) = 0.431 → 43.1% hit upper = 43.1% "Same"
- Still doesn't match 89.1% "Same"

**OR:** Maybe brms uses different convention where:
- z = probability of hitting boundary corresponding to `dec()=1`
- If dec_upper=1 means "Different", then z should predict proportion "Different"
- But z = 0.569 predicts 56.9% "Different", data shows 10.9%

---

## ✅ Solution: Test with Flipped Coding

**Quick Test:**

1. Create a test version of data with flipped `dec_upper`
2. Fit a simple model
3. Check if bias matches data

**If flipped coding works:**
- Then update all data preparation scripts
- Re-fit models with correct coding

---

## 📋 Next Steps

1. **Test flipped coding** - See if boundaries are reversed
2. **Verify brms documentation** - Check exact interpretation
3. **Fix data preparation** - Update `dec_upper` coding if needed
4. **Re-fit Standard-only model** - Verify bias is correct
5. **Then proceed** - Continue with Primary model

---

**This MUST be resolved before proceeding!** 🚨

