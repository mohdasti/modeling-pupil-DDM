# Chapter 3 Window Selection Analysis Summary

## Analysis Date
2024-12-25

## Overview
This analysis was performed to:
1. Verify timing anchors against MATLAB/log definitions
2. Plot stimulus-locked pupil waveforms to select cognitive window length
3. Provide window selection diagnostics
4. (Planned) Response-locked exploratory plots

## Part 1: Timing Verification ✓ COMPLETE

**Output**: `timing_sanity_summary.csv`, `timing_outlier_runs.csv`

All timing values match expected values:
- `stim1_onset_rel`: ~3.75s (stimulus pair onset relative to TrialST)
- `target_onset_rel`: ~4.35s (target onset relative to TrialST) 
- `resp_start_rel`: ~4.70s (response window start relative to TrialST)
- `target_stim1_diff`: ~0.60s (expected: 0.6s = Standard 100ms + ISI 500ms)

**No outlier runs detected** (all runs within 0.05s of expected target_onset).

## Part 2: Stimulus-Locked Waveform Plotting ✓ COMPLETE (Limited)

**Output**: 
- `figs/ch3_waveform_by_task.png`
- `figs/ch3_waveform_by_effort.png`
- `figs/ch3_waveform_by_oddball.png`

**Data Limitation**: The waveform summary file only extends to 4.7s from squeeze onset, which is only **0.35s post-target** (target onset = 4.35s). This is insufficient for the full planned analysis window of -0.5 to +4.0s from target.

**Plots Generated**: Waveforms were plotted with the available data window (-0.5 to +0.35s from target). These plots show the immediate post-target response but cannot capture the full cognitive window dynamics.

## Part 3: Window Selection Diagnostics ⚠ LIMITED

**Output**: 
- `ch3_time_to_peak_summary.csv` (empty - insufficient data for peak detection)
- `ch3_window_coverage.csv`
- `ch3_window_recommendation.md`

**Data Limitation**: Cannot compute time-to-peak or test window coverage because waveform data only extends 0.35s post-target, while cognitive windows need at least 2.0-3.0s post-target.

**Recommendation**: Based on expected timing structure:
- **Recommended Window**: W2.0 (target + 0.3s to target + 2.3s)
- However, this recommendation cannot be validated with current data

## Part 4: Response-Locked Plot ✗ NOT COMPLETED

**Reason**: Insufficient data extension. Waveform data ends at 4.7s (response window start), so there is no pre-response data available for response-locked analysis.

## Next Steps

To complete the full analysis as planned, you need to:

1. **Regenerate waveform summaries** with extended window:
   - Current: extends to 4.7s from squeeze onset
   - Needed: extends to at least **8.35s from squeeze onset** (target 4.35s + 4.0s post-target)
   - This requires re-running `make_quick_share_v7.R` or the waveform generation script with extended trial windows

2. **Or use flat files directly** with proper time alignment:
   - Load sample-level flat files
   - Compute time relative to squeeze onset correctly
   - Extract waveforms for ddm_ready trials only
   - This would require fixing the time alignment issue encountered in the script

## Files Generated

### QC Files
- `timing_sanity_summary.csv` - Median and IQR of timing offsets by task
- `timing_outlier_runs.csv` - Runs with timing deviations >0.05s (none found)
- `ch3_time_to_peak_summary.csv` - Time to peak for each condition (empty due to data limitation)
- `ch3_window_coverage.csv` - Window coverage estimates
- `ch3_window_recommendation.md` - Recommended cognitive window

### Figures
- `figs/ch3_waveform_by_task.png` - Grand mean waveforms by task (ADT vs VDT)
- `figs/ch3_waveform_by_effort.png` - Waveforms by effort level (Low vs High)
- `figs/ch3_waveform_by_oddball.png` - Waveforms by stimulus type (Standard vs Oddball)

All figures are limited to -0.5 to +0.35s from target onset due to data availability.

