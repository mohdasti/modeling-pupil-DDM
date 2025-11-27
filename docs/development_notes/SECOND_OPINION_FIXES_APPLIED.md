# Fixes Applied Based on Second Opinion

**Date:** 2025-11-01  
**Source:** Expert second opinion on DDM initialization issues

---

## ✅ FIXES IMPLEMENTED

### 1. Defensive Prior Builder (Fixes "argument 5 is empty")
**Problem:** Trailing commas or empty arguments in `c(...)` when building priors

**Solution:** Added `build_priors()` function that filters out NULL/empty arguments:
```r
build_priors <- function(...) {
    pieces <- list(...)
    pieces <- Filter(function(x) !is.null(x) && length(x) > 0, pieces)
    if (length(pieces) == 0) return(NULL)
    do.call(c, pieces)
}
```

**Location:** `scripts/02_statistical_analysis/02_ddm_analysis.R` (before prior assignment)

---

### 2. Updated Prior Assembly Logic
**Changed from:**
```r
if (condition) {
    model_priors <- c(model_priors, prior(...))
}
```

**Changed to:**
```r
model_priors <- build_priors(
    base_priors,
    if (condition) prior(...) else NULL,
    ...
)
```

**Prevents:** Empty arguments being passed to `c()`

---

### 3. Minimal Safe Init Function
**Updated to match second opinion recommendations:**
```r
safe_init <- function(chain_id = 1) {
    list(
        b_ndt_Intercept = log(0.18),  # CRITICAL: 180ms, below RT floor
        bs_Intercept    = log(1.3),   # Tamer init for older adults
        bias_Intercept  = 0,          # z ≈ 0.5 on logit scale
        Intercept       = 0           # Drift at 0
    )
}
```

**Note:** Only NDT initialization is critical (must be < every RT). Others are optional but safer.

---

### 4. Prior Validation (Preflight Check)
**Added:** `brms::validate_prior()` before fitting to catch mismatches early:
```r
tryCatch({
    brms::validate_prior(spec$formula, data = data, prior = spec$priors)
}, error = function(e) {
    log_message(sprintf("Prior validation warning: %s", e$message), "WARN")
})
```

**Also added:** Preflight compile check (1-iter, sample_prior="only") on Model1_Baseline before full pipeline

---

## 📝 METHODOLOGICAL NOTES

### NDT Random Effects Removal
**Decision:** Keep NDT fixed (no RE) for all models

**Justification:**
- ✅ Methodologically acceptable (documented)
- ✅ Subject variation still captured in drift, boundary, bias
- ✅ Stabilizes bring-up (avoids initialization explosions)
- ✅ Many published DDM papers use fixed NDT

**Future:** Plan sensitivity check with NDT RE reinstated after pipeline is stable

---

## ✅ EXPECTED OUTCOMES

1. **"argument 5 is empty" error:** Should be fixed by defensive prior builder
2. **Initialization:** Should work with minimal safe init (test validated)
3. **Compilation:** Preflight check will catch any naming/shape issues early

---

## 🚀 NEXT STEPS

1. Run full pipeline with these fixes
2. Monitor for "argument 5 is empty" (should not appear)
3. Verify all models complete successfully
4. Document decision to use fixed NDT in methods section

---

## 📚 REFERENCE

Second opinion confirmed:
- Dropping NDT RE is methodologically OK (with documentation)
- "argument 5 is empty" from prior assembly issues
- Minimal init sufficient (only NDT critical)
- Prior validation recommended

