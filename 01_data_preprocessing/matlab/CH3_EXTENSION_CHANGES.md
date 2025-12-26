# CH3 Extension: Trial Segmentation Changes

## Overview
Extended trial segmentation to end at Resp1ET (end of Response 1 window) instead of end of confidence period, providing ~3.35s post-target instead of ~0.35s.

## Changes Made

### 1. `parse_logP_file.m`
- Added extraction of `Resp1ET` (Resp1EndTimeP) from logP files
- New field: `logP_data.resp1_et`

### 2. `BAP_Pupillometry_Pipeline.m`

#### Trial End Time Computation (lines ~1038-1067)
- **Before**: Fixed `trial_end_time = squeeze_time + 10.7` (end of confidence period)
- **After**: Dynamic computation with fallbacks:
  1. **Preferred**: Use `Resp1ET` from logP if available
  2. **Fallback 1**: Use `Resp1ST + 3.0s` if Resp1ET not available
  3. **Fallback 2**: Use fixed `7.70s` relative to squeeze (TrialST)

#### New Audit Columns (lines ~1315-1318)
Added to each flat file row:
- `seg_start_rel_used`: Always -3.0 (relative to squeeze)
- `seg_end_rel_used`: Actual end time relative to squeeze (typically ~7.70s)
- `seg_end_source`: Source of end time ('Resp1ET', 'Resp1ST_plus_3', or 'DEFAULT_7p70')

#### QC Check (lines ~1368-1395)
- Added check that ≥90% of trials extend to ≥7.65s
- Reports warning if check fails
- Stores statistics in `run_qc_stats.ch3_extension_*`

#### Phase Labeling
- No changes needed - phase labeling function naturally handles data ending at 7.7s
- Data beyond 7.7s (Confidence phase) simply won't exist in the segments

## Expected Outcomes

### Before Extension
- Trials extended: squeeze-3.0s to squeeze+10.7s (13.7s total)
- Post-target data: ~0.35s (target at 4.35s, response start at 4.7s)

### After Extension  
- Trials extend: squeeze-3.0s to squeeze+7.7s (10.7s total)
- Post-target data: ~3.35s (target at 4.35s, response end at 7.7s)
- Sufficient for TEPR latency/peak analysis

## Testing Requirements

1. Regenerate flat files for all subjects/runs
2. Verify `seg_end_rel_used` values are ~7.70s
3. Verify `seg_end_source` is primarily 'Resp1ET' when logP available
4. Verify QC check passes (≥90% trials ≥7.65s)
5. Verify waveform data now extends to at least 7.7s from squeeze

## Notes

- Baseline definitions unchanged (still -3.0s to 0s relative to squeeze)
- AUC calculations unchanged (only data availability extended)
- Trial UID construction unchanged
- Join keys unchanged

