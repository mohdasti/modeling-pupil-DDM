# Gap Analysis and Event Timing Validation (Prompts 5 & 6)

## Summary

This document describes the implementation of gap-length classification in the prestim region (Prompt 5) and event timing validation from task logs (Prompt 6).

## Prompt 5: Gap-Length Classification in Prestim Region

### Purpose

Classify invalid segment durations (gaps) in the prestim region to determine:
- **Short gaps (≤200ms)**: Likely blinks → can be interpolated
- **Medium gaps (200-500ms)**: Possibly blinks or brief tracking loss
- **Long gaps (>500ms)**: Likely tracking loss → Gate A may need redesign

### Implementation

**Script**: `analyze_prestim_gaps.R`

**Analysis Windows**:
- **Window A**: Fixation-only window (fixST to A/V_ST = 3.25 to 3.75s)
- **Window B**: Old prestim window (3.25 to 3.75s) - same as Window A

**Gap Detection**:
- Identifies consecutive invalid pupil samples within each window
- Computes gap duration (time between first and last invalid sample)
- Classifies gaps into three categories: ≤200ms, 200-500ms, >500ms

**Outputs**:
- `data/qc/prestim_gap_analysis.csv`: Individual gap records with duration and category
- `data/qc/prestim_gap_summary.csv`: Summary statistics by:
  - Task (ADT vs VDT)
  - Effort condition (Low_5_MVC vs High_40_MVC)
  - Difficulty level (Standard, Easy, Hard)
  - Gap category

**Interpretation**:
- If **most gaps are ≤200ms**: Blink interpolation is justified
- If **many gaps are >500ms**: It's tracking loss and Gate A must be redesigned

### Usage

```r
source("02_pupillometry_analysis/quality_control/analyze_prestim_gaps.R")
```

## Prompt 6: Event Timing Validation from Task Log

### Purpose

Validate that event timing in the analysis pipeline matches the task code by:
- Loading behavioral log files (with TrialST, blankST, fixST, A/V_ST, Resp1ST)
- Computing distributions of inter-event intervals
- Comparing against expected values from task code
- Flagging systematic offsets that would indicate misalignment

### Expected Intervals (from task code)

| Interval | Expected Value | Description |
|----------|---------------|-------------|
| `blankST - TrialST` | 3.00s | Grip duration |
| `fixST - blankST` | 0.25s | Blank duration |
| `A/V_ST - fixST` | 0.50s | Fixation duration |
| `Resp1ST - A/V_ST` | ~0.95s | Relax period (0.25s) + gap to response (~0.70s) |

**Tolerance**: ±50ms (0.05s)

### Implementation

**Script**: `validate_event_timing.R`

**Log File Detection**:
- Searches for files matching pattern: `*_logP.txt`
- Looks in common directories:
  - `/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025`
  - `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data`
  - `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed`
  - `data/raw`, `data/logs`

**Log File Parsing**:
- Extracts subject, task, session, run from filename
- Parses tab/space-separated columns: TrialST, blankST, fixST, A/V_ST, Resp1ST
- Handles header lines (starting with `%`)

**Validation**:
- Computes mean, SD, min, max, median for each interval
- Compares against expected values
- Flags intervals outside tolerance as "⚠ MISALIGNED"

**Outputs**:
- `data/qc/event_timing_validation.csv`: Individual trial intervals
- `data/qc/event_timing_summary.csv`: Summary statistics with validation flags

### Usage

```r
source("02_pupillometry_analysis/quality_control/validate_event_timing.R")
```

**Note**: If log files are in a non-standard location, modify the `log_dirs` vector in the script.

## Files Created

### Scripts
- `02_pupillometry_analysis/quality_control/analyze_prestim_gaps.R`
- `02_pupillometry_analysis/quality_control/validate_event_timing.R`

### Output Files
- `data/qc/prestim_gap_analysis.csv`
- `data/qc/prestim_gap_summary.csv`
- `data/qc/event_timing_validation.csv`
- `data/qc/event_timing_summary.csv`

## Integration with Previous Prompts

These analyses complement the previous prompts:

- **Prompt 3**: Event-relative prestim window definition
- **Prompt 4**: Event-locked invalidity analysis
- **Prompt 5**: Gap-length classification (this document)
- **Prompt 6**: Event timing validation (this document)

Together, these analyses provide a comprehensive understanding of:
1. Whether prestim data loss is due to boundary artifacts (blinks) vs tracking loss
2. Whether event timing is correctly aligned between task code and analysis pipeline
3. Whether Gate A retention can be improved with better window definitions

## Next Steps

1. **Run gap analysis** to determine if gaps are blink-like (≤200ms) or dropout-like (>500ms)
2. **Run timing validation** to confirm event alignment
3. **If gaps are mostly short**: Consider blink interpolation to recover trials
4. **If gaps are mostly long**: Redesign Gate A to be more lenient or use different windows
5. **If timing is misaligned**: Investigate and fix alignment issues in the pipeline

## Notes

- Gap analysis uses the same windows as Prompt 3 (fixation-only and old prestim)
- Timing validation assumes log files follow the naming convention from the MATLAB task script
- Both scripts handle missing data gracefully and provide detailed error messages
- Results can be used to inform decisions about data quality thresholds and window definitions



