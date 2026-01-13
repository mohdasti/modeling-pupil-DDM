# Confound Mitigation Strategy: Motor/Response Screen Contamination

**Last Updated**: January 2026  
**Status**: Window definitions implemented; Full AUC computation pending  
**Based on**: Expert consultation addressing temporal overlap concerns

---

## The Problem

The cognitive AUC window faces unavoidable temporal overlap with multiple events:

1. **Target stimulus onset**: 4.35s
2. **Response screen appears**: 4.70s (only 350ms after target)
3. **Button press**: Variable (4.70s + RT, typically 5.3-5.4s for median RT)
4. **Handgrip release**: ~3.0s (may vary by participant)

**Key Concern**: The pupil response to the target doesn't really get going until ~300-500ms after 4.35s, but the response screen appears at 4.70s (only 350ms later). So cognitive dilation is **guaranteed to overlap** with:
- **(a) Response screen onset** (visual/attentional confound)
- **(b) Button press** (motor execution/blink confound, for many trials)

**Goal**: Not to "eliminate confounds" (impossible), but to **minimize them + model what we can't avoid + prove robustness**.

---

## Mitigation Strategy 1: Motor Buffer Truncation (IMPLEMENTED)

### Approach

Keep the stimulus-locked primary window start, but **truncate the end 150ms before button press** to avoid motor execution/movement/blink contamination.

**Primary Window (Motor-Buffered)**:
- **Start**: `t_target + 0.50s = 4.85s` (unchanged)
- **End (original)**: `t_target + 1.70s = 6.05s`
- **End (motor-buffered)**: `min(6.05s, t_resp - 0.15s)` ← 150ms buffer before button press
- **Duration**: Variable (truncated if button press occurs before 6.05s)

**Implementation**:
- Window end computed post-merge when RT is available
- Column: `cog_win_primary_end_motorbuffered`
- Flag: `cog_win_truncated_by_motor` (TRUE if window was truncated)
- Flag: `cog_win_uncontaminated_by_motor` (TRUE for slow RT trials where motor can't contaminate)

**QC Guardrails**:
- Require `valid_duration ≥ 0.6s` (or `n_valid ≥ 150` at 250 Hz) after truncation
- Keep `max_gap ≤ 250ms` threshold
- Use **mean dilation** (`cog_mean = AUC / valid_duration`) not raw AUC

**Status**: ✅ Window definitions computed; ⚠️ Full AUC computation requires re-processing flat files with RT

---

## Mitigation Strategy 2: Pre-Response Window (IMPLEMENTED)

### Approach

Add a second metric that is explicitly decision-aligned and **never includes the button press itself**.

**Pre-Response Window (Decision-Aligned)**:
- **End**: `t_resp - 0.15s` (150ms before button press, excludes motor)
- **Start**: `max(t_target + 0.50s, t_resp - 0.50s)` (ensures minimum 0.50s after target, targets last 0.50s before response)
- **Duration**: Variable, typically 0.35-0.50s for median RTs

**Rationale**:
- Captures decision-aligned pupil dynamics right before response
- Excludes motor execution/blink contamination
- Aligns with decision commitment/uncertainty (de Gee et al., 2014; Urai et al., 2017)

**Implementation**:
- Window definitions computed post-merge when RT is available
- Columns: `cog_win_preresp_start`, `cog_win_preresp_end`, `cog_win_preresp_duration`
- Flag: `cog_win_preresp_valid` (TRUE if duration ≥ 0.35s, expert-recommended minimum)

**Status**: ✅ Window definitions computed; ⚠️ Full AUC computation requires re-processing flat files with RT

---

## Mitigation Strategy 3: Event-Based Modeling (FUTURE ENHANCEMENT)

### Approach

The most principled solution: **GLM/deconvolution with separate regressors** for each event.

**Model Structure**:
- Include regressors (events) for:
  1. `target_onset` (4.35s)
  2. `response_screen_onset` (4.70s)
  3. `button_press` (t_resp, trial-specific)
- Estimate each event's pupil impulse response (FIR / deconvolution)
- Cognitive effect = **beta/area associated with target regressor**, not a raw time-window integral

**Advantages**:
- Directly separates "target-driven" vs "response-screen-driven" vs "motor-driven" pupil change
- Most defensible approach for reviewers
- Handles overlapping events naturally

**Status**: 📝 Documented for future implementation; Requires GLM/deconvolution pipeline

**References**: Wierda et al. (2012) - deconvolution approach for overlapping events

---

## Mitigation Strategy 4: Design-Consistent Controls (IMPLEMENTED)

### A) Post-Grip, Pre-Stim Baseline

**Current Implementation**: B1 baseline (3.85s to 4.35s, target-locked)

**Expert Recommendation**: Use 3.25-3.75s fixation baseline (post-grip, pre-stim) to subtract residual effort/tonic level.

**Status**: ✅ B1 baseline is appropriate for target-locked correction; Pre-stim baseline (3.25-3.75s) available as alternative

### B) RT as Nuisance Covariate

**Approach**: Include RT as covariate in mixed models, even with fixed windows.

**Model Structure**:
```r
outcome ~ cog_mean + rt + condition + interactions + (1|sub)
```

**Rationale**: RT correlates with decision state; prevents RT from "pretending" to be pupil coupling.

**Status**: ✅ RT available in data; 📝 Modeling recommendation for analyses

### C) Sensitivity Subset: Slow-RT Trials

**Approach**: Compute stimulus-locked metric **only in trials where** `t_resp > t_target + 1.70 + 0.15 = 6.20s`.

**Rationale**: If pattern holds in slow-RT trials where motor can't contaminate primary window, shows it's not driven by motor press.

**Implementation**:
- Flag: `cog_win_uncontaminated_by_motor` (TRUE for slow RT trials)
- Use this subset for sensitivity analysis

**Status**: ✅ Flag computed; 📝 Sensitivity analysis recommendation

---

## Recommended Analysis Approach for Chapter 2

### Primary Analysis (Minimal Change, Maximum Defensibility)

1. **Keep the new stimulus-locked window** (4.85-6.05s), but **truncate at (response − 150ms)** and use **cog_mean**
2. **Add pre-response window** (−500 to −150ms) as **secondary/sensitivity** metric
3. **Run robustness check** on "slow-RT subset" where motor can't contaminate primary window
4. **Include RT as covariate** in all models
5. **If bandwidth allows**: Move to GLM/deconvolution for "gold standard" confirmation

### Code Example

```r
# Primary analysis: Motor-buffered stimulus-locked window
ch2_primary <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    # Use motor-buffered window if available
    is.na(cog_win_truncated_by_motor) | !cog_win_truncated_by_motor,  # Prefer non-truncated
    # OR: Include truncated but ensure sufficient duration
    cog_window_duration >= 0.60,  # After truncation
    cog_auc_n_valid >= 150,  # After truncation
    cog_auc_max_gap_ms <= 250
  ) %>%
  # Use mean dilation (preferred)
  mutate(
    cog_mean_primary = cog_mean  # Already computed: AUC / duration
  )

# Sensitivity: Slow-RT trials (uncontaminated by motor)
ch2_slow_rt <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    cog_win_uncontaminated_by_motor == TRUE,  # Slow RT trials
    cog_window_duration >= 0.90,
    cog_auc_n_valid >= 240,
    cog_auc_max_gap_ms <= 250
  )

# Sensitivity: Pre-response window (decision-aligned)
ch2_preresp <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    cog_win_preresp_valid == TRUE,  # Valid pre-response window
    !is.na(cog_win_preresp_duration)
  )
# Note: cog_auc_preresp would need to be computed from flat files with RT

# Modeling: Include RT as covariate
model <- lmer(
  behavior ~ cog_mean + rt + condition + cog_mean:condition + (1|sub),
  data = ch2_primary
)
```

---

## Data Columns Available

### Motor Buffer Columns

- **`t_resp_actual`**: Trial-specific response onset (4.70s + RT)
- **`cog_win_primary_end_motorbuffered`**: Motor-buffered window end (min(6.05s, t_resp - 0.15s))
- **`cog_win_truncated_by_motor`**: Flag: Was primary window truncated by motor buffer?
- **`cog_win_uncontaminated_by_motor`**: Flag: Slow RT trials where motor can't contaminate

### Pre-Response Window Columns

- **`cog_win_preresp_start`**: Pre-response window start (max(4.85s, t_resp - 0.50s))
- **`cog_win_preresp_end`**: Pre-response window end (t_resp - 0.15s)
- **`cog_win_preresp_duration`**: Pre-response window duration
- **`cog_win_preresp_valid`**: Flag: Is pre-response window valid (duration ≥ 0.35s)?

**Note**: Window definitions are computed, but full AUC computation (`cog_auc_motorbuffered`, `cog_auc_preresp`) requires re-processing flat files with RT. This can be done in a separate post-processing step.

---

## Next Steps

1. ✅ **Window definitions**: Computed and available in data
2. ⚠️ **Full AUC computation**: Requires re-processing flat files with RT (separate script)
3. 📝 **Modeling recommendations**: Include RT as covariate, use slow-RT subset for sensitivity
4. 📝 **Future enhancement**: Implement GLM/deconvolution for event-based modeling

---

## Key References

- **de Gee et al. (2014)**: Decision-related pupil dilation reflects upcoming choice
- **Urai et al. (2017)**: Post-choice pupil relates to decision uncertainty/arousal
- **Wierda et al. (2012)**: Deconvolution approach for overlapping events
- **Mathôt (2022)**: Methods in cognitive pupillometry - RT/response confounds

---

## Summary

**The expert's recommendations are VALID and MEANINGFUL**. The temporal overlap is real, and the mitigation strategies are:

1. ✅ **Practical**: Motor buffer and pre-response windows can be implemented
2. ✅ **Defensible**: Addresses reviewer concerns about confounds
3. ✅ **Robust**: Multiple sensitivity checks (slow-RT subset, pre-response window, RT covariate)
4. 📝 **Future-proof**: Event-based modeling as gold standard

**Current Status**: Window definitions are computed and available. Full AUC computation for motor-buffered and pre-response windows requires a separate post-processing step (re-processing flat files with RT). This is documented and ready for implementation when needed.
