# Quick-Share v7 Output Inspection Report (v2 - After Fix Attempt)

**Status:** ⚠️ **AUC COMPUTATION STILL FAILING**

## Critical Finding

The AUC computation is still returning 0% availability. Root cause identified:

**The `time` column in flat files contains absolute PTB timestamps spanning the entire session, NOT per-trial relative times.**

### Evidence:
- Trial 1 has 3,425 samples (correct for ~13.7s at 250Hz)
- But time span is 3,087 seconds (should be ~13.7 seconds)
- This means `time` is session-absolute, not trial-relative

### Fix Applied:
Changed `t_rel` computation to use sample indices instead of absolute time:
```r
t_rel <- seq(from = -3.0, by = dt_median, length.out = n_samples)
```

This ensures:
- First sample at t_rel = -3.0 (trial window start)
- Last sample at t_rel ≈ 10.7 (trial window end)
- Baseline window [-0.5, 0.0) will correctly align

### Next Steps:
1. Re-run script with the fix
2. Verify `n_valid_B0` is populated (not all NA)
3. Check AUC availability improves to >0%

---

## Current Status (Before Fix)

- **AUC availability:** 0% (0 / 14,586 trials)
- **n_valid_B0:** All NA (logical type, should be integer)
- **timing_anchor_found:** All NA
- **Column duplicates:** Still present (.x/.y suffixes)
- **Behavioral join:** 87.2% ✅
- **Data structure:** Clean (no duplicate trial_uid) ✅

---

## Expected After Fix

- **AUC availability:** Should be >40% (target)
- **n_valid_B0:** Should be integer 0-125 range
- **Baseline window:** Should find ~125 samples at 250Hz (500ms window)
- **Column cleanup:** Should remove .x/.y duplicates

