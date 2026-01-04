# CH3 Extension Implementation Status

## Completed ✅

### PART A: MATLAB Segmentation Changes
- ✅ Updated `parse_logP_file.m` to extract Resp1ET
- ✅ Updated `BAP_Pupillometry_Pipeline.m` to compute trial_end_time using Resp1ET with fallbacks
- ✅ Added audit columns: `seg_start_rel_used`, `seg_end_rel_used`, `seg_end_source`
- ✅ Added QC check for max(t_rel) >= 7.65s (warns if <90% of trials pass)

### PART B: R Script Updates  
- ✅ Updated `scripts/ch3_window_selection_v2.R`:
  - Extended plot window to -0.5 to +3.5s from target
  - Updated peak search window to 0.3 to 3.3s post-target
  - Window coverage now includes W3.0 (target+0.3 to target+3.3)

### PART C: STOP/GO Checks
- ✅ Created `scripts/ch3_stopgo_checks.R` to validate extension worked
- ✅ Checks:
  - Waveform extension >= 7.65s
  - Time-to-peak summary exists and non-empty
  - Window coverage for W2.0
  - Timing sanity (target onset near 4.35s)

### Documentation
- ✅ Created `01_data_preprocessing/matlab/CH3_EXTENSION_CHANGES.md`
- ✅ Created `quick_share_v7/qc/CH3_EXTENSION_NOTE.md`

## Pending ⏳

### PART B: Re-run Pipeline
1. **Regenerate MATLAB flat files**:
   - Run `BAP_Pupillometry_Pipeline.m` on all subjects/runs
   - Verify QC checks pass (≥90% trials extend to ≥7.65s)
   - Check audit columns show correct segmentation boundaries

2. **Regenerate waveform summaries**:
   - Run `scripts/make_quick_share_v7.R` (or waveform generation script)
   - Verify waveform data extends to at least 7.7s from squeeze
   - Confirm waveforms computed at both 50 Hz (Ch2) and 250 Hz (Ch3)

3. **Run window selection analysis**:
   - Run `scripts/ch3_window_selection_v2.R`
   - Verify outputs:
     - `qc/ch3_time_to_peak_summary.csv` (should be non-empty)
     - `qc/ch3_window_coverage.csv` (should include W3.0)
     - `figs/ch3_waveform_by_task.png`
     - `figs/ch3_waveform_by_effort.png`
     - `figs/ch3_waveform_by_oddball.png`

4. **Run STOP/GO checks**:
   - Run `scripts/ch3_stopgo_checks.R`
   - Verify all checks pass (status = GO)
   - Review `qc/STOP_GO_ch3_extension.csv`

## Expected Outputs After Completion

### QC Files
- `qc/timing_sanity_summary.csv` - Updated timing verification
- `qc/ch3_time_to_peak_summary.csv` - **Must be non-empty** (was empty before)
- `qc/ch3_window_coverage.csv` - Coverage for W2.0, W2.5, W3.0
- `qc/STOP_GO_ch3_extension.csv` - Validation results

### Figures
- `figs/ch3_waveform_by_task.png` - Extended to +3.5s from target
- `figs/ch3_waveform_by_effort.png` - Extended to +3.5s from target
- `figs/ch3_waveform_by_oddball.png` - Extended to +3.5s from target

## Verification Checklist

Before committing, verify:
- [ ] All MATLAB flat files regenerated with new segmentation
- [ ] Audit columns present in flat files
- [ ] QC check shows ≥90% trials extend to ≥7.65s
- [ ] Waveform data extends to ≥7.7s from squeeze
- [ ] Time-to-peak summary is non-empty
- [ ] Window coverage includes W3.0
- [ ] All STOP/GO checks pass
- [ ] Waveform plots show extended time range
- [ ] No changes to baseline definitions or AUC math
- [ ] Trial UIDs and join keys unchanged

