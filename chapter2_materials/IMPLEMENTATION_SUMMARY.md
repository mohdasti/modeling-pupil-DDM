# Implementation Summary: Expert-Recommended Cognitive AUC Window

**Date**: January 2026  
**Status**: ✅ Primary window implemented; Response-locked window pending  
**Based on**: Expert consultation following Mathôt (2022), Bauer et al. (2021), and related pupillometry best practices

---

## What Changed

### Previous Implementation (PROBLEMATIC)
- **Window**: 4.65s to 4.70s (50ms fixed window)
- **Duration**: ~0.05s (extremely short)
- **Samples**: ~10-15 valid samples
- **Problem**: Too short to capture meaningful TEPR, unreliable AUC estimates

### New Implementation (EXPERT-RECOMMENDED)
- **Primary Window**: 4.85s to 6.05s (1.20s fixed window, stimulus-locked)
- **Duration**: Fixed 1.20 seconds
- **Samples**: ~300 valid samples at 250 Hz
- **Rationale**: Captures TEPR peak (~1s post-stimulus) while avoiding RT confounds

---

## Key Updates

### 1. Code Changes (`scripts/make_quick_share_v7.R`)

✅ **Primary Window Implemented**:
- Window: `[TARGET_ONSET + 0.50s, TARGET_ONSET + 1.70s]` = `[4.85s, 6.05s]`
- Computes `cog_auc` using gap-aware trapezoidal integration
- Computes `cog_mean = cog_auc / window_duration` (mean dilation, preferred metric)
- All gap-aware QC metrics available

✅ **Response-Locked Window (Pending)**:
- Window: `max(target+0.50s, resp-0.50s)` to `resp` (trial-specific)
- Status: Initialized as NA, requires post-processing with RT + flat files
- Can be computed in separate step when needed

✅ **Legacy Window (Deprecated)**:
- Old 50ms window kept as `cog_auc_legacy` for backward compatibility
- Not recommended for analyses

### 2. Documentation Updates

✅ **New Documentation Created**:
- `docs/COGNITIVE_AUC_WINDOW_IMPLEMENTATION.md`: Comprehensive guide to window implementation, rationale, and best practices

✅ **Updated Documentation**:
- `docs/AUC_CALCULATION_METHOD.md`: Updated window definitions and quality thresholds
- `docs/FILTERING_GUIDE.md`: Updated to reflect new window and thresholds
- `README.md`: Updated data column descriptions and exclusion rules
- `reports/pupil_data_report_advisor.qmd`: Updated window timing references

### 3. Quality Thresholds (Expert-Recommended)

**Primary Analysis (Strict)**:
- `B1_quality >= 0.50` AND `cog_quality >= 0.60`
- `cog_auc_max_gap_ms <= 250` (Kret & Sjak-Shie threshold)
- `cog_window_duration >= 0.90` (75% of 1.20s window)
- `cog_auc_n_valid >= 240` (80% of expected ~300 samples)

**Rationale**: 
- 1.20s window should have ~300 samples at 250 Hz
- 80% coverage = 240 valid samples ensures robust estimates
- 0.90s minimum duration ensures sufficient temporal coverage
- 250ms max gap prevents large missing segments from distorting AUC

---

## Migration Guide

### For Existing Analyses

**If using legacy `cog_auc` (50ms window)**:
1. ✅ **Switch to new `cog_auc`**: Now uses 1.20s primary window (4.85-6.05s)
2. ✅ **Use `cog_mean`**: Prefer mean dilation over raw AUC
3. ✅ **Update quality filters**: Apply new thresholds (n_valid ≥ 240, duration ≥ 0.90s, max_gap ≤ 250ms)
4. ⚠️ **Re-run analyses**: New window will yield different (more reliable) estimates

### For New Analyses

**Recommended Approach**:
1. **Primary metric**: `cog_mean` from primary window (stimulus-locked, 4.85-6.05s)
2. **Quality filtering**: Apply expert-recommended thresholds
3. **Sensitivity**: Compare with response-locked window (when available) and legacy windows
4. **Modeling**: Include RT as covariate if using response-locked metrics

---

## Data Columns

### New/Updated Columns

- **`cog_auc`**: Now uses 1.20s fixed window (4.85-6.05s) instead of 50ms window
- **`cog_mean`**: Mean dilation = `cog_auc / window_duration` - **PREFERRED METRIC**
- **`cog_window_duration`**: Should be ~1.20s (fixed window)
- **`cog_auc_n_valid`**: Should be ~300 samples (at 250 Hz)
- **`cog_auc_resplocked`**: Response-locked AUC (pending implementation, currently NA)
- **`cog_mean_resplocked`**: Response-locked mean dilation (pending implementation, currently NA)
- **`cog_auc_legacy`**: Legacy 50ms window (deprecated, kept for backward compatibility)

### Quality Metrics (Unchanged)

- **`B1_quality`**: B1 baseline quality (3.85s to 4.35s)
- **`cog_quality`**: Cognitive window quality (now 4.85s to 6.05s)
- **`cog_auc_max_gap_ms`**: Maximum gap in cognitive window
- **`gate_pupil_primary`**: Primary quality gate (B1_50 & cog_60)

---

## Next Steps

1. ✅ **Re-run `make_quick_share_v7.R`**: Generate new data with updated windows
2. ✅ **Verify outputs**: Check that `cog_window_duration` ≈ 1.20s and `cog_auc_n_valid` ≈ 300
3. ⚠️ **Re-run analyses**: Update existing analyses to use new window/metrics
4. 📝 **Response-locked window**: Implement when needed (requires RT + flat file re-processing)

---

## Key References

- **Mathôt (2022)**: *Methods in cognitive pupillometry* - Timing, RT/response confounds, practical guidance
- **Bauer et al. (2021)**: Pupil dilation peaks ~1-2s post-stimulus
- **Kret & Sjak-Shie (2019)**: Gap handling recommendations (≤250ms)
- **de Gee et al. (2014)**: Decision-aligned pupil dynamics
- **Urai et al. (2017)**: Post-choice pupil relates to decision uncertainty

---

## Questions?

- **Window too short?**: Primary window is 1.20s (fixed) - should be sufficient
- **Missing response-locked?**: Currently pending; can be computed post-hoc
- **Quality thresholds too strict?**: Start with expert recommendations; relax only if power is severely impacted
- **RT confounds?**: Use stimulus-locked primary window (RT-independent) or include RT as covariate

See `docs/COGNITIVE_AUC_WINDOW_IMPLEMENTATION.md` for detailed documentation.
