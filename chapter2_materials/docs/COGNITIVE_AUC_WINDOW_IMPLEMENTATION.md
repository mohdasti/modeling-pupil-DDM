# Cognitive AUC Window Implementation: Expert-Recommended Approach

**Last Updated**: January 2026  
**Status**: Primary window implemented; Response-locked window pending  
**Based on**: Expert consultation following Mathôt (2022), Bauer et al. (2021), and related pupillometry best practices

---

## Executive Summary

The cognitive AUC window has been updated from a problematic **50ms fixed window** (4.65-4.70s) to an **expert-recommended 1.20s stimulus-locked fixed window** (4.85-6.05s). This change addresses critical limitations:

- **Previous window**: 50ms duration, ~10-15 samples → unreliable AUC estimates
- **New primary window**: 1.20s duration, ~300 samples → robust AUC estimates
- **Rationale**: Captures TEPR peak (~1s post-stimulus) while avoiding early reflex components and RT confounds

---

## Window Definitions

### Primary Window: Stimulus-Locked Fixed Window (RECOMMENDED FOR CHAPTER 2)

**Definition:**
- **Start**: `t_target + 0.50s = 4.85s` (relative to squeeze onset)
- **End**: `t_target + 1.70s = 6.05s` (relative to squeeze onset)
- **Duration**: Fixed **1.20 seconds**
- **Expected samples**: ~300 samples at 250 Hz sampling rate

**Rationale:**
1. **Captures TEPR peak**: Cognitive TEPRs typically peak around ~1s after stimulus onset (Mathôt, 2022; Bauer et al., 2021)
2. **Avoids early components**: Starting at +0.50s reduces contamination from earliest reflex/orienting components and visual transients
3. **RT-independent**: Fixed duration eliminates mechanical RT-AUC coupling confound
4. **Sufficient samples**: 1.20s window provides ~300 samples, ensuring robust AUC estimates

**Metrics Computed:**
- `cog_auc`: Area under the curve (trapezoidal integration)
- `cog_mean`: Mean dilation = `cog_auc / window_duration` (removes duration confounds)
- Gap-aware QC metrics: `cog_auc_n_valid`, `cog_window_duration`, `cog_auc_max_gap_ms`, etc.

**Quality Thresholds (Expert-Recommended):**
- **Minimum valid samples**: `n_valid ≥ 240` (80% of expected ~300 samples)
- **Minimum usable duration**: `duration_valid ≥ 0.90s` (75% of 1.20s window)
- **Maximum gap size**: `max_gap_ms ≤ 200-250ms` (Kret & Sjak-Shie, 2019)

---

### Secondary Window: Response-Locked Window (SENSITIVITY/INTERPRETATION)

**Definition:**
- **End**: `t_resp = 4.70s + RT` (trial-specific response onset)
- **Start**: `max(t_target + 0.50s, t_resp - 0.50s)` (ensures minimum 0.50s after target, targets last 0.50s before response)
- **Duration**: Variable, typically **0.45-0.60s** for median RTs (0.6-0.7s)

**Rationale:**
1. **Decision-aligned**: Captures pupil dynamics linked to decision formation right up to response
2. **Avoids fast RT artifacts**: Minimum start floor (target + 0.50s) prevents tiny windows for very fast RTs
3. **Captures pre-response dynamics**: 0.50s before response captures decision uncertainty/arousal (de Gee et al., 2014; Urai et al., 2017)

**Metrics Computed:**
- `cog_auc_resplocked`: Response-locked AUC
- `cog_mean_resplocked`: Response-locked mean dilation
- Gap-aware QC metrics: `cog_resplocked_n_valid`, `cog_resplocked_window_duration`, `cog_resplocked_max_gap_ms`

**Quality Thresholds (Expert-Recommended):**
- **Minimum duration**: `window_duration ≥ 0.35s` (≈88 samples)
- **Minimum valid samples**: `n_valid ≥ 75-100`
- **Maximum gap size**: `max_gap_ms ≤ 200-250ms`

**Status**: ⚠️ **Pending Implementation** - Requires re-processing flat files with RT information. Currently initialized as NA.

---

## Implementation Details

### Code Location

**Primary Script**: `scripts/make_quick_share_v7.R`

**Key Constants** (lines ~73-81):
```r
TARGET_ONSET_DEFAULT <- 4.35
RESP_START_DEFAULT <- 4.70
COG_WIN_PRIMARY_START <- 0.50  # Start 0.50s after target (4.85s)
COG_WIN_PRIMARY_END <- 1.70    # End 1.70s after target (6.05s)
COG_WIN_PRIMARY_DURATION <- 1.20  # Fixed 1.20s window
```

**Primary Window Computation** (lines ~507-532):
- Window: `[TARGET_ONSET_DEFAULT + COG_WIN_PRIMARY_START, TARGET_ONSET_DEFAULT + COG_WIN_PRIMARY_END]`
- Uses `compute_auc_with_qc()` for gap-aware AUC computation
- Computes `cog_mean = cog_auc / cog_window_duration` to remove duration confounds

### Baseline Correction

**Current Implementation:**
- **B0 baseline**: -0.5s to 0.0s (pre-trial baseline)
- **B1 baseline**: 3.85s to 4.35s (pre-target baseline, used for Cognitive AUC correction)

**Expert Recommendation (Alternative):**
- **Pre-stim baseline**: 3.25s to 3.75s (pre-stimulus fixation period)
- Rationale: Subtracts residual effort tonic level from post-squeeze period
- **Status**: Documented for future consideration; current B1 baseline is appropriate for target-locked correction

---

## Quality Control and Filtering

### Recommended Exclusion Rules (Based on Expert Advice)

**Primary Analysis (Strict):**
```r
ch2_primary <- ch2_data %>%
  filter(
    # Quality thresholds
    gate_pupil_primary == TRUE,  # B1_quality >= 0.50 & cog_quality >= 0.60
    
    # Gap-aware exclusions (primary window)
    is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 250,  # No large gaps
    is.na(cog_window_duration) | cog_window_duration >= 0.90,  # Sufficient duration
    is.na(cog_auc_n_valid) | cog_auc_n_valid >= 240  # Enough valid samples
  )
```

**Sensitivity Analysis (Moderate):**
```r
ch2_moderate <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 250,
    is.na(cog_window_duration) | cog_window_duration >= 0.75  # Relaxed duration
  )
```

**Sensitivity Analysis (Lenient):**
```r
ch2_lenient <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 400  # Allows larger gaps
  )
```

---

## Handling RT-AUC Coupling

### Problem

If using RT-dependent windows, longer RT = more time to accumulate AUC, creating a mechanical confound.

### Solutions

**1. Use Mean Dilation (Simple Fix):**
```r
cog_mean = cog_auc / window_duration
```
This removes the pure "longer window → bigger number" artifact.

**2. Include RT as Covariate (Modeling Fix):**
```r
# Mixed model predicting behavior
model <- lmer(behavior ~ cog_mean + rt + (1|sub), data = ch2_data)
```
This directly addresses RT-driven response-locked pupil components.

**3. Residualize (Stronger Fix):**
```r
# Residualize pupil vs RT within participant
pupil_resid = pupil_metric - f(RT)  # Linear or spline
```
Then use `pupil_resid` for coupling analyses.

**Recommendation**: For Chapter 2 primary analyses, use **stimulus-locked fixed window** (primary window) to avoid RT confounds entirely. Use response-locked window (secondary) for sensitivity/interpretation analyses with RT as covariate.

---

## Distinguishing Genuine Low Dilation from Data Quality Artifacts

### Likely Genuine Low Dilation When:
- Coverage is high (≥80%)
- Max gap is small (≤150ms)
- Signal has reasonable within-window variance (not flatlined)
- Baseline looks stable
- **High quality + Small gap + Low RT-normalized AUC = Genuine low dilation** → **KEEP**

### Likely Data Quality Artifact When:
- Coverage is low / many gaps
- One big blink gap dominates the window (>250ms)
- Flat segments (tracker loss) or implausible spikes
- QC metrics cluster at "barely passing"
- **Low quality OR Large gap + Low RT-normalized AUC = Data quality artifact** → **EXCLUDE**

### Diagnostic Framework

Use **2D logic**, not just "AUC is small":
1. Plot `cog_mean` (RT-normalized) vs `cog_quality`
2. Points in **lower-right quadrant** (high quality, low dilation, small gap): Genuine low arousal - **KEEP**
3. Points in **lower-left quadrant** (low quality OR large gap, low dilation): Data quality artifact - **EXCLUDE**

---

## Data Availability

### Current Implementation Status

**Primary Window (Stimulus-Locked):**
- ✅ **Implemented**: Computed for all trials with valid pupil data
- ✅ **Metrics Available**: `cog_auc`, `cog_mean`, gap-aware QC metrics
- ✅ **Quality Gates**: Integrated into `gate_pupil_primary` definition

**Secondary Window (Response-Locked):**
- ⚠️ **Pending**: Requires re-processing flat files with RT information
- ⚠️ **Metrics**: Initialized as NA, to be computed in separate step
- 📝 **Note**: Can be computed post-hoc by re-processing flat files with RT from behavioral data

**Legacy Window (50ms):**
- ⚠️ **Deprecated**: Kept as `cog_auc_legacy` for backward compatibility only
- ❌ **Not Recommended**: Too short for reliable AUC estimates

---

## Confound Mitigation: Motor/Response Screen Contamination

**Important**: The cognitive AUC window faces unavoidable temporal overlap with response screen onset (4.70s) and button press (variable). See `CONFOUND_MITIGATION_STRATEGY.md` for detailed mitigation approaches:

1. **Motor Buffer Truncation**: Truncate primary window 150ms before button press
2. **Pre-Response Window**: Decision-aligned window that excludes motor execution
3. **RT as Covariate**: Include RT in models to control for decision state
4. **Slow-RT Sensitivity**: Test on trials where motor can't contaminate
5. **Event-Based Modeling**: GLM/deconvolution for future enhancement

**Status**: Window definitions computed; Full AUC computation pending (requires re-processing flat files with RT)

---

## Key References

1. **Mathôt (2022)**: *Methods in cognitive pupillometry* - Timing, RT/response confounds, practical design/analysis guidance
2. **Mathôt (2018)**: *Pupillometry: Psychology, Physiology, and Function* - Orienting vs slower arousal/effort responses and typical timing
3. **Bauer et al. (2021)**: Clear statement that pupil dilation peaks ~1-2s post-stimulus and supports trial-wise baseline correction
4. **de Gee et al. (2014)**: Pupil dilation reflects evolving decision/choice content during decisions
5. **Urai et al. (2017)**: Post-choice pupil relates to decision uncertainty/arousal
6. **Kret & Sjak-Shie (2019)**: Practical pupillometry methodological guide, gap handling recommendations
7. **Steinhauer et al. (2022)**: Publication guidelines for pupillary measurement, artifact handling/reporting
8. **Wierda et al. (2012)**: Deconvolution approach for overlapping events (event-based modeling)

---

## Migration Guide

### For Existing Analyses

**If using legacy `cog_auc` (50ms window):**
1. **Switch to new `cog_auc`**: Now uses 1.20s primary window (4.85-6.05s)
2. **Use `cog_mean`**: Prefer mean dilation over raw AUC to remove duration confounds
3. **Update quality filters**: Apply new thresholds (n_valid ≥ 240, duration ≥ 0.90s, max_gap ≤ 250ms)
4. **Re-run analyses**: New window will yield different (more reliable) estimates

**If using `cog_auc_w1p3` (1.0s window, 4.65-5.65s):**
- Similar to new primary window but starts earlier (0.30s vs 0.50s after target)
- Consider switching to new primary window for consistency with expert recommendations
- Or use both for sensitivity analysis

### For New Analyses

**Recommended Approach:**
1. **Primary metric**: `cog_mean` from primary window (stimulus-locked, 4.85-6.05s)
2. **Quality filtering**: Apply expert-recommended thresholds
3. **Sensitivity**: Compare with response-locked window (when available) and legacy windows
4. **Modeling**: Include RT as covariate if using response-locked metrics

---

## Sanity Checks (Non-Negotiable)

Before finalizing analyses, verify:

1. **Average pupil time courses**: Plot by condition, aligned to target and aligned to response
2. **Window placement**: Confirm primary window (4.85-6.05s) sits on sensible rising/peak region
3. **TEPR timing**: Verify window captures expected TEPR dynamics (~1s post-stimulus peak)
4. **Quality distribution**: Check that quality thresholds don't exclude too many trials
5. **Gap distribution**: Verify max_gap_ms distribution and identify problematic trials

---

## Questions or Issues?

- **Window too short?**: Primary window is 1.20s (fixed) - should be sufficient for most analyses
- **Missing response-locked?**: Currently pending implementation; can be computed post-hoc
- **Quality thresholds too strict?**: Start with expert recommendations; relax only if power is severely impacted
- **RT confounds?**: Use stimulus-locked primary window (RT-independent) or include RT as covariate

---

**Last Updated**: January 2026  
**Maintained By**: Data Pipeline Team  
**Contact**: See project README
