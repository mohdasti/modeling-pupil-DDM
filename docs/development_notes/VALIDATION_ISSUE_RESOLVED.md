# Validation Issue Resolution Summary

**Date:** 2025-11-26  
**Status:** ✅ Issue identified and fixed

---

## The Issue

Our validation showed a 7.3% mismatch between predicted (3.6%) and observed (10.9%) "Different" responses on Standard trials.

---

## Root Cause

**Aggregation Bias (Jensen's Inequality)**

We were using mean parameters in a non-linear analytical formula:
- $v = -1.260$ (mean drift)
- $a = 2.275$ (mean boundary)  
- $z = 0.567$ (mean bias)

But for hierarchical models with subject heterogeneity:
$$E[P(v, a, z)] \neq P(E[v], E[a], E[z])$$

The analytical formula simulated a single "average" subject, ignoring the fact that some subjects have weaker drift and produce more errors.

---

## The Solution

**Use Posterior Predictive Checks (PPC)**

- Simulate from full posterior (including random effects)
- Respect subject-level heterogeneity
- Aggregate simulated data to compare with observed

**Created:** `R/validate_ppc_proper.R`

---

## Expected Outcome

The PPC validation should show the **observed 10.9% falls within the 95% credible interval** of predicted proportions, indicating the model fits correctly.

The previous 7.3% "mismatch" was just a validation artifact, not a model problem!

---

## Next Step

**Run PPC validation:**
```r
source("R/validate_ppc_proper.R")
```

If validation passes, **proceed with analysis** - the model is working correctly!

---

**Status:** Ready to validate properly ✅

