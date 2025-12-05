# Pupil Waveform Visualization

## Overview

This script generates publication-quality pupil waveform plots showing baseline-corrected pupil traces across experimental conditions, with event markers and AUC window annotations.

## Script

**File**: `plot_pupil_waveforms.R`

## Features

- **Baseline-corrected traces**: Creates `pupil_isolated = pupil - baseline_B0` where baseline is calculated from -0.5s to 0s (500ms before squeeze onset)
- **Condition grouping**: Groups by Difficulty (Easy/Hard/Standard) × Effort (Low/High)
- **Smoothing**: Uses GAM (Generalized Additive Model) with confidence intervals
- **Event markers**: Vertical dashed lines at:
  - Trial onset (0s)
  - Target stimulus onset (4.35s)
  - Response onset (median from actual RT data, or 4.7s if RT unavailable)
- **Timeline bars**: Horizontal bars showing:
  - Baseline window (-0.5 to 0s)
  - Total AUC window (0 to response onset)
  - Cognitive AUC window (4.65s to response onset)

## Usage

```r
# Run from project root
source("02_pupillometry_analysis/visualization/plot_pupil_waveforms.R")
```

Or from command line:
```bash
Rscript 02_pupillometry_analysis/visualization/plot_pupil_waveforms.R
```

## Output

Plots are saved to `06_visualization/publication_figures/`:
- `Figure3_Pupil_Waveforms_ADT_VDT.png` - Combined ADT and VDT plots
- `Pupil_Waveform_ADT.png` - ADT only
- `Pupil_Waveform_VDT.png` - VDT only

## Data Requirements

- Merged flat CSV files in `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/`
- Files should have:
  - `time` (relative to squeeze onset)
  - `pupil` (pupil diameter)
  - `isOddball` and `stimLev` (for difficulty mapping)
  - `force_condition` (for effort mapping)
  - `resp1RT` (for response onset calculation)

## Customization

### Exclude Standard Trials

To exclude Standard trials and only show Easy/Hard:
```r
# In the script, uncomment this line:
filter(!grepl("Standard", condition))
```

### Adjust Colors

Modify the `condition_colors` vector at the top of the script to change color scheme.

### Adjust Timing

Modify `task_configs` to change event timing if your experiment differs.

## Notes

- The script automatically calculates median response onset from actual RT data
- If RT data is unavailable, uses fixed response window start (4.7s)
- Target stimulus onset is fixed at 4.35s (after Standard 100ms + ISI 500ms)
- Cognitive AUC window starts 300ms after target onset (4.65s)

