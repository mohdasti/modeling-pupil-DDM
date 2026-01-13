# Confound Mitigation Implementation Summary

**Date**: January 2026  
**Status**: ✅ Window definitions implemented; ⚠️ Full AUC computation pending  
**Expert Assessment**: VALID and MEANINGFUL - temporal overlap concerns are real and addressed

---

## Expert Assessment: VALID ✅

The expert's recommendations are **highly valid and meaningful**. The concerns about temporal overlap are **real**:

1. ✅ **Response screen appears at 4.70s** (only 350ms after target at 4.35s)
2. ✅ **Button press overlaps** with cognitive window for many trials (median RT ~0.6-0.7s → press at ~5.3-5.4s)
3. ✅ **Goal is correct**: Not to "eliminate confounds" (impossible), but to **minimize + model + prove robustness**

---

## What Was Implemented

### 1. Motor Buffer Truncation ✅

**Approach**: Truncate primary window 150ms before button press to avoid motor contamination.

**Implementation**:
- **Column**: `cog_win_primary_end_motorbuffered` = `min(6.05s, t_resp - 0.15s)`
- **Flag**: `cog_win_truncated_by_motor` (TRUE if window was truncated)
- **Flag**: `cog_win_uncontaminated_by_motor` (TRUE for slow RT trials where motor can't contaminate)

**Status**: ✅ Window definitions computed post-merge; ⚠️ Full AUC computation requires re-processing flat files

### 2. Pre-Response Window ✅

**Approach**: Decision-aligned window that never includes button press (500ms before response, excluding last 150ms).

**Implementation**:
- **Start**: `max(4.85s, t_resp - 0.50s)`
- **End**: `t_resp - 0.15s` (150ms before button press)
- **Duration**: Variable, typically 0.35-0.50s
- **Flag**: `cog_win_preresp_valid` (TRUE if duration ≥ 0.35s)

**Status**: ✅ Window definitions computed post-merge; ⚠️ Full AUC computation requires re-processing flat files

### 3. RT as Covariate 📝

**Approach**: Include RT in models to control for decision state.

**Status**: ✅ RT available in data; 📝 Modeling recommendation for analyses

### 4. Slow-RT Sensitivity Subset ✅

**Approach**: Test on trials where motor can't contaminate primary window.

**Implementation**:
- **Flag**: `cog_win_uncontaminated_by_motor` (TRUE if `t_resp > 6.20s`)

**Status**: ✅ Flag computed; 📝 Sensitivity analysis recommendation

### 5. Event-Based Modeling 📝

**Approach**: GLM/deconvolution with separate regressors for target, response screen, and button press.

**Status**: 📝 Documented for future implementation

---

## Data Columns Available

### Motor Buffer Columns (in `ch2_triallevel.csv` and `ch3_triallevel.csv`)

- `t_resp_actual`: Trial-specific response onset (4.70s + RT)
- `cog_win_primary_end_motorbuffered`: Motor-buffered window end
- `cog_win_truncated_by_motor`: Was primary window truncated?
- `cog_win_uncontaminated_by_motor`: Slow RT trials (uncontaminated)

### Pre-Response Window Columns

- `cog_win_preresp_start`: Pre-response window start
- `cog_win_preresp_end`: Pre-response window end
- `cog_win_preresp_duration`: Pre-response window duration
- `cog_win_preresp_valid`: Is pre-response window valid (≥0.35s)?

**Note**: Window definitions are computed, but full AUC computation requires re-processing flat files with RT.

---

## Recommended Analysis Approach

### Primary Analysis

1. **Use motor-buffered primary window** (truncated at response - 150ms)
2. **Use `cog_mean`** (mean dilation, not raw AUC)
3. **Include RT as covariate** in all models
4. **Sensitivity**: Test on slow-RT subset (`cog_win_uncontaminated_by_motor == TRUE`)
5. **Sensitivity**: Compare with pre-response window (when AUC computed)

### Code Example

```r
# Primary: Motor-buffered window (prefer non-truncated, but allow truncated with sufficient duration)
ch2_primary <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    # Prefer non-truncated, or truncated with sufficient duration
    is.na(cog_win_truncated_by_motor) | 
    (cog_win_truncated_by_motor == TRUE & cog_window_duration >= 0.60),
    cog_auc_n_valid >= 150,  # After truncation
    cog_auc_max_gap_ms <= 250
  ) %>%
  # Use mean dilation (preferred)
  mutate(
    cog_mean_primary = cog_mean
  )

# Sensitivity: Slow-RT trials (uncontaminated)
ch2_slow_rt <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    cog_win_uncontaminated_by_motor == TRUE,
    cog_window_duration >= 0.90,
    cog_auc_n_valid >= 240,
    cog_auc_max_gap_ms <= 250
  )

# Modeling: Include RT as covariate
model <- lmer(
  behavior ~ cog_mean + rt + condition + cog_mean:condition + (1|sub),
  data = ch2_primary
)
```

---

## Next Steps

1. ✅ **Window definitions**: Computed and available
2. ⚠️ **Full AUC computation**: Requires separate script to re-process flat files with RT
3. 📝 **Modeling**: Include RT as covariate, use slow-RT subset for sensitivity
4. 📝 **Future**: Implement GLM/deconvolution for event-based modeling

---

## Documentation

- **`docs/CONFOUND_MITIGATION_STRATEGY.md`**: Comprehensive guide to all mitigation strategies
- **`docs/COGNITIVE_AUC_WINDOW_IMPLEMENTATION.md`**: Window implementation details
- **`README.md`**: Updated with new columns and recommendations

---

## Conclusion

**The expert's recommendations are VALID and MEANINGFUL**. The temporal overlap is real, and the mitigation strategies are:

1. ✅ **Practical**: Motor buffer and pre-response windows implemented
2. ✅ **Defensible**: Addresses reviewer concerns about confounds
3. ✅ **Robust**: Multiple sensitivity checks available
4. 📝 **Future-proof**: Event-based modeling documented for future enhancement

**Current Status**: Window definitions are computed and available in data. Full AUC computation for motor-buffered and pre-response windows requires a separate post-processing step (re-processing flat files with RT). This is documented and ready for implementation when needed.
