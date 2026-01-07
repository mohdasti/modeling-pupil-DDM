# Pupil AUC Calculation Method (Zenon et al. 2014) - Gap-Aware Implementation

## Overview

The feature extraction now uses **Total AUC** and **Cognitive AUC** instead of simple mean-based metrics, following the method described in Zenon et al. (2014) and adapted for the BAP paradigm. **As of January 2026, the implementation includes gap-aware QC metrics** that help identify trials with problematic missing data patterns.

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

### Gap-Aware Trapezoidal Integration

The AUC is calculated using a **gap-aware** trapezoidal rule that addresses a critical limitation: percentage-validity thresholds alone are insufficient. A trial can have 60% valid samples overall, but if there's a large contiguous gap (e.g., 400ms) during the peak response period, the standard trapezoidal rule will bridge across that gap with a straight line, potentially underestimating or distorting the true pupil response (Burg et al.; Kret & Sjak-Shie, 2019).

**Gap-Aware Implementation**:

The `calculate_auc_with_qc()` function:
1. Identifies gaps larger than a threshold (default: 250ms, following Kret & Sjak-Shie recommendations)
2. Splits the window into contiguous segments where time differences ≤ gap threshold
3. Computes trapezoidal AUC within each segment separately
4. Sums segment AUCs to get total AUC
5. Returns both AUC value and QC metrics

This ensures AUC reflects "area under observed signal where we had continuous coverage" rather than bridging across large missing segments.

**Key Implementation Details**:
- **Gap Threshold**: Default 250ms (configurable via `gap_max_ms` parameter)
- **Sampling Rate**: Assumes 250 Hz (4ms per sample) for expected sample count calculations
- **Segment Handling**: Each contiguous segment is integrated separately; gaps > threshold are not bridged
- **QC Metrics**: Returns `n_valid`, `window_duration`, `prop_valid`, `max_gap_ms`, `n_segments` alongside AUC

### Handling Missing Data

- Only valid (non-NA) samples are used in calculations
- Baseline means are calculated using `na.rm = TRUE`
- AUC returns `NA` if fewer than 2 valid samples in the window
- **Gap-Aware**: Large gaps (>250ms) are not bridged; AUC is computed only within contiguous segments
- **Quality Control**: Additional metrics (`max_gap_ms`, `n_segments`) help identify trials with problematic missingness patterns

## Output Variables

The feature extraction script now creates:

1. **`total_auc`**: Total AUC (primary metric for full TEPR)
   - Raw pupil data from 0s to trial-specific response_onset
   - No baseline correction
   - **QC Metrics** (if using `calculate_auc_with_qc()`):
     - `total_auc_n_valid`: Count of valid samples
     - `total_auc_window_duration`: Window duration (s)
     - `total_auc_prop_valid`: Proportion of valid samples
     - `total_auc_max_gap_ms`: Maximum contiguous gap (ms)
     - `total_auc_n_segments`: Number of contiguous segments

2. **`cog_auc`**: Cognitive AUC (primary metric for cognitive TEPR) - **USE THIS FOR CHAPTER 2 ANALYSES**
   - Baseline-corrected pupil (`pupil_isolated`) from 4.65s to trial-specific response_onset
   - Baseline correction: `pupil_isolated = pupil - baseline_B0`
   - **QC Metrics** (available in `ch2_triallevel.csv`):
     - `cog_auc_n_valid`: Count of valid samples in cognitive window
     - `cog_window_duration`: Cognitive window duration (s)
     - `cog_auc_prop_valid`: Proportion of valid samples
     - `cog_auc_max_gap_ms`: Maximum contiguous gap in cognitive window (ms) - **KEY FOR FILTERING**
     - `cog_auc_n_segments`: Number of contiguous segments

3. **`baseline_B0`**: Pre-trial baseline mean (for reference)
   - Calculated from -0.5s to 0s window

4. **`tonic_arousal`**: Legacy metric (kept for backward compatibility)

5. **`effort_arousal_change`**: Legacy metric (kept for backward compatibility)

## Quality Control Recommendations

Based on best-practice literature (Burg et al.; Kret & Sjak-Shie, 2019; Modern Pupillometry), we recommend the following exclusion rules:

### Chapter 2 (Psychometric Coupling - High Quality)

**Primary (Strict)**:
- `baseline_quality >= 0.60` AND `cog_quality >= 0.60` 
- AND `cog_auc_max_gap_ms <= 250` (Kret & Sjak-Shie threshold)
- AND `cog_window_duration >= 0.50` (minimum window duration)
- AND `cog_auc_n_valid >= 100` (minimum valid samples)

**Sensitivity Analyses**:
- Moderate: Same as primary but `cog_window_duration >= 0.30`
- Lenient: Same as primary but `cog_auc_max_gap_ms <= 400`

**See `FILTERING_GUIDE.md` for detailed filtering code examples.**

## Advantages Over Mean-Based Metrics

1. **Sensitive to temporal dynamics**: AUC captures the full timecourse, not just mean values
2. **Accounts for baseline**: Properly baseline-corrected before integration
3. **Separates physical and cognitive effects**: Total AUC vs Cognitive AUC
4. **Standardized method**: Follows established literature (Zenon et al. 2014)
5. **Gap-aware**: Prevents distortion from large missing segments

## Important Notes

- **`cog_auc` values are unchanged**: The gap-aware implementation produces identical AUC values to previous versions because your data has no large gaps (>250ms). The gap-aware logic is a safety net for future data.
- **Use `cog_auc` as primary metric**: This is still the most accurate column for AUC analyses.
- **Use gap-aware QC metrics for filtering**: See `FILTERING_GUIDE.md` for how to use the new QC metrics to exclude problematic trials.

## References

Zenon, A., Sidibé, M., & Olivier, E. (2014). Pupil size variations correlate with physical effort perception. *Frontiers in Neuroscience*, 8, 286.

Kret, M. E., & Sjak-Shie, E. E. (2019). Preprocessing pupil size data: Guidelines and code. *Behavior Research Methods*, 51(3), 1336-1342. https://doi.org/10.3758/s13428-018-1075-y

Burg, E., et al. (see full citation in main report). Discusses importance of gap-based quality metrics beyond percentage-validity.

Papesh, M. H., & Goldinger, S. D. (2024). *Modern Pupillometry: Cognition, Neuroscience, and Practical Applications*. Springer Nature. (Chapter on preprocessing and quality control)
