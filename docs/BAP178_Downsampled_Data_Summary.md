# BAP178 Downsampled Eye Tracking Data Summary

## Overview
This document summarizes the downsampled eye tracking data for BAP178, processed from 2000 Hz to 250 Hz with enhanced behavioral information and trial labels.

## Processing Specifications

### Downsampling
- **Original sampling rate**: 2000 Hz
- **Target sampling rate**: 250 Hz
- **Downsampling factor**: 8x (2000/250)
- **Method**: SciPy signal.decimate with 8th order filter for high quality

### File Naming Convention
- **Format**: `BAP178_{TASK}_DS250.csv`
- **Examples**: 
  - `BAP178_ADT_DS250.csv` (Auditory Discrimination Task)
  - `BAP178_VDT_DS250.csv` (Visual Discrimination Task)

## Output Files

### File Statistics
| Task | File Size | Total Samples | Total Trials | Samples per Trial (avg) |
|------|-----------|---------------|--------------|------------------------|
| ADT | 67 MB | 466,390 | 30 | ~15,546 |
| VDT | 81 MB | 502,226 | 30 | ~16,741 |

### Data Reduction
- **ADT**: 3,731,047 → 466,390 samples (87.5% reduction)
- **VDT**: 4,017,744 → 502,226 samples (87.5% reduction)

## Data Structure

### Columns Included

#### Eye Tracking Data
1. **`pupil`** - Pupil diameter (mm), downsampled to 250 Hz
2. **`time`** - Timestamp (seconds), downsampled to 250 Hz
3. **`trial_index`** - Trial number (numerical)
4. **`run_index`** - Run number (1-5)
5. **`duration_index`** - Trial part index (1-5)
6. **`trial_label`** - Descriptive trial part label

#### Behavioral Data (from bap_trial_data_grip_type1.csv)
7. **`sub`** - Subject ID (BAP178)
8. **`mvc`** - Maximum voluntary contraction
9. **`ses`** - Session number
10. **`task`** - Task type (aud/vis)
11. **`run`** - Run number
12. **`trial`** - Trial number
13. **`stimLev`** - Stimulus level
14. **`isOddball`** - Oddball condition (0/1)
15. **`isStrength`** - High strength condition (0/1)
16. **`iscorr`** - Response correctness
17. **`resp1`** - Response 1
18. **`resp1RT`** - Response 1 reaction time
19. **`resp2`** - Response 2
20. **`resp2RT`** - Response 2 reaction time
21. **`auc_rel_mvc`** - AUC relative to MVC
22. **`resp1_isdiff`** - Response 1 difference indicator

## Trial Structure

### Duration Index Mapping
| Duration Index | Trial Label | Description | Time Window |
|----------------|-------------|-------------|-------------|
| 1 | baseline | Pre-trial baseline | 0-20% |
| 2 | fixation | Pre-squeeze fixation | 20-40% |
| 3 | squeeze | Squeeze period | 40-60% |
| 4 | blank | Post-squeeze blank | 60-80% |
| 5 | response | Response period | 80-100% |

### Trial Label Distribution
Both ADT and VDT show approximately 20% of samples in each trial phase:

#### ADT Distribution
- **baseline**: 93,228 samples (20.0%)
- **fixation**: 93,304 samples (20.0%)
- **squeeze**: 93,249 samples (20.0%)
- **blank**: 93,304 samples (20.0%)
- **response**: 93,305 samples (20.0%)

#### VDT Distribution
- **baseline**: 100,402 samples (20.0%)
- **fixation**: 100,429 samples (20.0%)
- **squeeze**: 100,457 samples (20.0%)
- **blank**: 100,429 samples (20.0%)
- **response**: 100,509 samples (20.0%)

## Data Quality

### Preprocessing Applied
- **Blink removal**: Already applied in cleaned files
- **Artifact removal**: Already applied in cleaned files
- **Zero value conversion**: Pupil diameter values of 0 converted to NaN
- **Downsampling**: High-quality decimation with anti-aliasing filter

### Sampling Rate Benefits
- **File size**: ~87.5% reduction in file size
- **Processing speed**: Faster analysis and visualization
- **Memory usage**: Reduced memory requirements
- **Temporal resolution**: Still sufficient for pupillometry analysis (4ms intervals)

## Usage Recommendations

### For Analysis
1. **Trial-level analysis**: Group by `trial_index` and `run_index`
2. **Phase analysis**: Use `trial_label` or `duration_index` for trial phases
3. **Condition analysis**: Use `isStrength`, `isOddball`, `stimLev` for experimental conditions
4. **Performance analysis**: Use `iscorr`, `resp1RT`, `resp2RT` for behavioral measures

### For Visualization
1. **Time series**: Use `time` column for x-axis
2. **Trial alignment**: Use `trial_index` for trial-based plots
3. **Phase coloring**: Use `trial_label` for color coding different trial phases

## Files Created
- `BAP178_ADT_DS250.csv`: Auditory task data (67 MB)
- `BAP178_VDT_DS250.csv`: Visual task data (81 MB)
- `downsample_and_process.py`: Processing script

## Technical Notes
- **Downsampling method**: SciPy signal.decimate with 8th order Chebyshev filter
- **Data integrity**: All behavioral information preserved
- **Trial structure**: Maintained relative timing within trials
- **Missing data**: Some trials at run ends excluded due to data length limitations

## Next Steps
1. Verify trial structure aligns with experimental design
2. Consider additional preprocessing if needed
3. Use for statistical analysis and visualization
4. Apply to other subjects using the same processing pipeline 