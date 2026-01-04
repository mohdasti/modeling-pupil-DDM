# Pupil AUC Calculation Method (Zenon et al. 2014)

## Overview

The feature extraction now uses **Total AUC** and **Cognitive AUC** instead of simple mean-based metrics, following the method described in Zenon et al. (2014) and adapted for the BAP paradigm.

## Trial Structure

Based on the MATLAB pipeline, trials are structured as follows (time relative to squeeze onset = 0):

| Phase | Time Window | Duration | Description |
|-------|-------------|----------|-------------|
| ITI_Baseline | -3.0 to 0s | 3s | Pre-trial baseline |
| Squeeze | 0 to 3.0s | 3s | Handgrip force manipulation |
| Post_Squeeze_Blank | 3.0 to 3.25s | 250ms | Post-squeeze blank |
| Pre_Stimulus_Fixation | 3.25 to 3.75s | 500ms | Pre-stimulus fixation |
| Stimulus | 3.75 to 4.45s | 700ms | Standard (100ms, 3.75-3.85s) + ISI (500ms, 3.85-4.35s) + **Target (100ms, 4.35-4.45s)** |
| Post_Stimulus_Fixation | 4.45 to 4.7s | 250ms | Post-stimulus fixation |
| Response_Different | 4.7 to 7.7s | 3000ms | Response period |
| Confidence | 7.7 to 10.7s | 3000ms | Confidence rating |

## AUC Calculations

### 1. Total AUC

**Definition**: Area under the curve from trial onset until trial-specific response onset, using **raw pupil data** (no baseline correction).

**Calculation**:
- **Data**: Raw pupil diameter (not baseline-corrected)
- **AUC Window**: From trial onset (0s) until trial-specific response onset
  - Start: 0s (squeeze onset)
  - End: `response_onset = 4.7s + RT` (response window start + trial-specific RT)
  - If RT is not available, uses fixed 4.7s (response window start)
- **Method**: Trapezoidal integration of raw pupil diameter
  - AUC = ∫(pupil) dt from 0s to response_onset
  - **No baseline correction** - uses raw pupil values

**Interpretation**: Captures the full task-evoked pupil response (TEPR) including both physical (squeeze) and cognitive (stimulus) demands, measured from raw pupil data.

### 2. Cognitive AUC

**Definition**: Area under the curve from 300ms after **TARGET stimulus onset** until trial-specific response onset, using **baseline-corrected pupil data**.

**Calculation**:
- **Baseline (B₀)**: Mean pupil diameter in 500ms window before trial onset
  - Time window: -0.5s to 0s (last 500ms of ITI_Baseline)
- **Baseline Correction**: Create `pupil_isolated = pupil - baseline_B0`
  - Applied throughout the trial to converge all conditions at squeeze onset (time = 0)
- **AUC Window**: From 300ms after **TARGET stimulus onset** until trial-specific response onset
  - **Target stimulus onset**: 4.35s (3.75s stimulus phase start + 0.1s Standard + 0.5s ISI)
  - Start: 4.65s (4.35s + 0.3s to account for physiological latency)
  - End: `response_onset = 4.7s + RT` (trial-specific response onset)
  - If RT is not available, uses fixed 4.7s
  - **Note**: The target stimulus is the second stimulus (after Standard + ISI) and is the one that varies in intensity across trials
- **Method**: Trapezoidal integration of baseline-corrected pupil diameter
  - AUC = ∫(pupil_isolated) dt from 4.65s to response_onset

**Note**: The 300ms offset accounts for physiological latency in the pupil response. The baseline correction isolates cognitive effects by removing pre-trial baseline differences.

**Interpretation**: Isolates the TEPR to cognitive demands of the task, controlling for physical effort effects and baseline differences.

## Implementation Details

### Trapezoidal Integration

The AUC is calculated using the trapezoidal rule (matching Zenon et al. 2014 method):

```r
calculate_auc <- function(time_series, data_series, start_time, end_time) {
  # Filter data for the specified window
  # Filter out NA values from data_series as it would invalidate AUC for that trial
  valid_indices <- !is.na(data_series) & (time_series >= start_time & time_series <= end_time)
  
  if (sum(valid_indices) < 2) { # Need at least 2 points for trapezoidal rule
    return(NA_real_)
  }
  
  t <- time_series[valid_indices]
  y <- data_series[valid_indices]
  
  # Sort by time to ensure correct trapezoidal calculation
  order_idx <- order(t)
  t <- t[order_idx]
  y <- y[order_idx]
  
  # Calculate AUC using trapezoidal rule
  auc_val <- sum(0.5 * (y[-length(y)] + y[-1]) * diff(t), na.rm = TRUE)
  return(auc_val)
}
```

**Key differences from previous implementation**:
- No baseline correction within the function (applied beforehand for Cognitive AUC)
- Uses the exact formula: `0.5 * (y[i] + y[i+1]) * dt`
- Handles NA values by filtering before calculation

### Handling Missing Data

- Only valid (non-NaN) samples are used in calculations
- Baseline means are calculated using `na.rm = TRUE`
- AUC returns `NA` if fewer than 2 valid samples in the window

## Output Variables

The feature extraction script now creates:

1. **`total_auc`**: Total AUC (primary metric for full TEPR)
   - Raw pupil data from 0s to trial-specific response_onset
   - No baseline correction
2. **`cognitive_auc`**: Cognitive AUC (primary metric for cognitive TEPR)
   - Baseline-corrected pupil (`pupil_isolated`) from 4.05s to trial-specific response_onset
   - Baseline correction: `pupil_isolated = pupil - baseline_B0`
3. **`baseline_B0`**: Pre-trial baseline mean (for reference)
   - Calculated from -0.5s to 0s window
4. **`tonic_arousal`**: Legacy metric (kept for backward compatibility)
5. **`effort_arousal_change`**: Legacy metric (kept for backward compatibility)

## Advantages Over Mean-Based Metrics

1. **Sensitive to temporal dynamics**: AUC captures the full timecourse, not just mean values
2. **Accounts for baseline**: Properly baseline-corrected before integration
3. **Separates physical and cognitive effects**: Total AUC vs Cognitive AUC
4. **Standardized method**: Follows established literature (Zenon et al. 2014)

## References

Zenon, A., Sidibé, M., & Olivier, E. (2014). Pupil size variations correlate with physical effort perception. *Frontiers in Neuroscience*, 8, 286.

