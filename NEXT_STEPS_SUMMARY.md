# Summary: PPC Validation Critical Issue

**Date:** 2025-11-26  
**Status:** ⚠️ Issue identified, fix needed

---

## The Problem

**Predicted:** 66.1% "Different"  
**Observed:** 10.9% "Different"  
**Difference:** 55.2% - **COMPLETELY WRONG!**

---

## Root Cause Identified ✅

**`posterior_epred()` returns EXPECTED RT, NOT choice probabilities!**

We were treating RT values (0.6 seconds) as probabilities (60%), leading to completely wrong predictions.

---

## The Fix

**Need to use parameter extraction + analytical formula:**

1. Extract parameters using `posterior_linpred()`:
   - Drift (v)
   - Boundary (a)
   - Bias (z)

2. Calculate choice probabilities analytically:
   $$P(\text{upper}) = \frac{e^{-2va(1-z)} - 1}{e^{-2va} - 1}$$

3. Sample choices from these probabilities for PPC

---

## Documents Created

1. `PPC_VALIDATION_CRITICAL_ISSUE.md` - Issue summary
2. `PROMPT_FOR_LLM_PPC_VALIDATION_ISSUE.md` - Prompt for LLM
3. `PPC_CRITICAL_ISSUE_ANALYSIS.md` - Detailed analysis  
4. `PPC_ISSUE_DIAGNOSIS.md` - Root cause diagnosis
5. `NEXT_STEPS_PPC_ISSUE.md` - Next steps
6. `NEXT_STEPS_SUMMARY.md` - This summary

---

## Recommendation

**Before proceeding:**
1. Get second opinion using the prompt (optional but recommended)
2. OR implement corrected validation method immediately

**After fix:**
- Run corrected PPC validation
- Expect to see predicted ~11% "Different" matching observed

---

**Status:** ⚠️ **Root cause identified - needs corrected validation implementation**

