# Event-Relative Prestim Window Implementation (Prompts 3 & 4)

## Summary

This document describes the implementation of event-relative prestim window definitions and event-locked invalidity analysis, addressing Prompts 3 and 4.

## Prompt 3: Event-Relative Prestim Window

### Changes Made

1. **Modified `build_pupil_trial_coverage_prefilter.R`**:
   - Added per-trial detection of fixation onset (fixST) and stimulus pair onset (A/V_ST)
   - Changed prestim window from hard-coded `[3.25, 3.75]` to event-relative:
     - **New definition**: `[fixation_onset + 0.10, stimulus_onset - 0.10]`
     - **Old definition**: `[3.25, 3.75]` (preserved as `valid_prestim_old` for comparison)
   
2. **Event Detection Logic**:
   - Uses `trial_label` column when available to detect event boundaries
   - Falls back to canonical offsets from task code if `trial_label` not available:
     - `fixation_onset = 3.25s` (fixST)
     - `stimulus_onset = 3.75s` (A/V_ST)

3. **Gate A Retention Comparison**:
   - Computes Gate A retention with both old and new definitions
   - Reports:
     - Number of trials recovered with new definition
     - Number of trials lost with new definition
     - Subject-level recovery statistics
   - Saves comparison to `data/qc/prestim_window_comparison.csv`

### Expected Benefits

- **More accurate window**: Avoids including boundary artifacts (blinks/transitions) at fixation and stimulus onsets
- **Per-trial flexibility**: Accounts for any trial-to-trial timing variation
- **Better data quality**: Should recover trials that were excluded due to boundary artifacts

### Usage

Run the coverage builder script:
```r
source("02_pupillometry_analysis/quality_control/build_pupil_trial_coverage_prefilter.R")
```

Results will be in:
- `data/qc/pupil_trial_coverage_prefilter.csv` (includes both `valid_prestim` and `valid_prestim_old`)
- `data/qc/prestim_window_comparison.csv` (Gate A retention comparison)

## Prompt 4: Event-Locked Invalidity Analysis

### Purpose

Determine if the prestim dip in pupil availability is due to:
- **Boundary artifacts** (blinks/eye movements during event transitions) → Sharp peaks in P(invalid) at event boundaries
- **True dropout** (random missingness) → Flat or gradual increase in P(invalid)

### Implementation

1. **Added to `build_pupil_trial_coverage_prefilter.R`**:
   - Computes P(invalid pupil) time-locked to events:
     - Grip gauge onset (TrialST = 0.0s)
     - Blank onset (blankST = 3.0s)
     - Fixation onset (fixST = 3.25s)
     - Stimulus pair onset (A/V_ST = 3.75s)
   - Time window: ±500ms around each event
   - Bin size: 20ms
   - Saves to `data/qc/event_locked_invalidity.csv`

2. **Visualization Script**: `plot_event_locked_invalidity.R`
   - Creates overlay plots of ADT vs VDT for each event
   - Focused plots for fixation and stimulus onsets
   - Saves to `02_pupillometry_analysis/quality_control/figures/`

### Interpretation

- **Sharp peak at t=0**: Boundary artifact (blinks/transitions) → Prestim dip is artifact, not true dropout
- **Flat or gradual increase**: True dropout → Prestim dip reflects genuine data loss

### Usage

1. Run coverage builder (computes invalidity data):
```r
source("02_pupillometry_analysis/quality_control/build_pupil_trial_coverage_prefilter.R")
```

2. Generate plots:
```r
source("02_pupillometry_analysis/quality_control/plot_event_locked_invalidity.R")
```

## Files Modified/Created

### Modified
- `02_pupillometry_analysis/quality_control/build_pupil_trial_coverage_prefilter.R`
  - Added event-relative prestim window computation
  - Added Gate A retention comparison
  - Added event-locked invalidity analysis

### Created
- `02_pupillometry_analysis/quality_control/plot_event_locked_invalidity.R`
  - Visualization script for event-locked invalidity
- `02_pupillometry_analysis/EVENT_RELATIVE_PRESTIM_IMPLEMENTATION.md` (this file)

### Output Files
- `data/qc/pupil_trial_coverage_prefilter.csv` (updated with new columns)
- `data/qc/prestim_window_comparison.csv` (new)
- `data/qc/event_locked_invalidity.csv` (new)
- `02_pupillometry_analysis/quality_control/figures/event_locked_invalidity_overlay.png` (new)
- `02_pupillometry_analysis/quality_control/figures/event_locked_invalidity_focused.png` (new)

## Next Steps

1. **Run the updated coverage builder** to generate new prestim windows and invalidity data
2. **Review Gate A retention comparison** to see how many trials/subjects are recovered
3. **Examine event-locked invalidity plots** to determine if prestim dip is boundary artifact
4. **Update analysis pipelines** to use event-relative prestim window if results are favorable
5. **Update `generate_pupil_data_report.qmd`** if it computes prestim windows independently (currently uses hard-coded 3.25-3.75)

## Notes

- The event-relative definition uses a 0.10s buffer on each side to avoid boundary artifacts
- If `trial_label` is not available in the data, the code falls back to canonical offsets
- The old prestim definition is preserved as `valid_prestim_old` for comparison purposes
- Event-locked invalidity analysis uses canonical event times; per-trial event detection could be added if needed



