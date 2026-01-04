# Comprehensive Pupil Data Report - Prompt Document

## Purpose

This document provides a comprehensive overview of all files, directories, scripts, methods, and thresholds used in the pupil data analysis pipeline. This information should be used to create a systematic, publication-quality HTML report documenting the pupil data structure, quality, and processing pipeline.

## Directory Structure

### Main Pupil Analysis Directory: `02_pupillometry_analysis/`

```
02_pupillometry_analysis/
├── README.md                          # Overview of the pipeline
├── PIPELINE_GUIDE.md                  # Detailed pipeline usage guide
├── run_full_pupillometry_pipeline.R   # Master pipeline script
│
├── feature_extraction/
│   ├── prepare_analysis_ready_data.R  # Creates trial-level summaries with AUC metrics
│   ├── run_feature_extraction.R       # Wrapper for feature extraction
│   └── AUC_CALCULATION_METHOD.md      # Detailed AUC calculation documentation
│
├── quality_control/
│   ├── run_pupil_qc.R                 # Comprehensive QC checks
│   ├── analyze_subject_run_distribution.R  # Subject-level statistics
│   ├── generate_trial_flow_report.R   # Trial flow through pipeline stages
│   ├── STAGE_DEFINITIONS.md           # Definitions of pipeline stages
│   └── output/                        # QC reports and plots
│
└── visualization/
    ├── plot_pupil_waveforms.R         # Publication-quality waveform plots (ADT/VDT)
    ├── run_pupil_visualizations.R     # QC visualizations
    └── README_WAVEFORMS.md            # Waveform plot documentation
```

## Data Flow and File Types

### Stage 1: Raw Flat Files (from MATLAB Pipeline)

**Location**: `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/`

**File Patterns**:
- `*_flat.csv` - Sample-level data from MATLAB pipeline
- `*_flat_merged.csv` - Sample-level data merged with behavioral data

**Data Structure**:
- Each row = one time sample (e.g., 250 Hz = 250 rows per second)
- Contains: pupil diameter measurements, trial labels, phase information
- May or may not have behavioral data merged
- Quality metrics (`baseline_quality`, `overall_quality`) may be present

**Key Variables**:
- `sub`: Subject identifier
- `task`: Task type (ADT, VDT)
- `run`: Run number
- `trial_index` or `trial_in_run`: Trial number within run
- `time`: Time relative to squeeze onset (0s = squeeze onset)
- `pupil`: Pupil diameter (NaN for invalid samples, zeros converted to NaN)
- `trial_label`: Phase label (ITI_Baseline, Pre_Stimulus_Fixation, etc.)
- `baseline_quality`: Quality metric for baseline period (if available)
- `overall_quality`: Quality metric for entire trial (if available)

### Stage 2: Merged Flat Files

**Location**: Same as Raw Flat Files

**File Pattern**: `*_flat_merged.csv`

**Data Structure**:
- Same sample-level structure as Raw Flat
- **Plus**: Behavioral data merged by `run` and `trial_in_run`
- Contains quality metrics from MATLAB pipeline
- Contains behavioral variables: `stimLev`, `isOddball`, `iscorr`, `resp1RT`, `gf_trPer`, etc.

**Key Additional Variables**:
- `stimLev`: Stimulus level (1-4 for ADT, 0.06-0.48 for VDT)
- `isOddball`: 0 = Standard, 1 = Oddball
- `iscorr` or `resp_is_correct`: Response accuracy
- `resp1RT`: Reaction time
- `gf_trPer` or `grip_targ_prop_mvc`: Grip force target (% MVC)
- `force_condition`: Low_Force_5pct or High_Force_40pct

### Stage 3: Analysis-Ready Files

**Location**: `data/analysis_ready/`

**File Patterns**:
- `BAP_analysis_ready_PUPIL.csv` - Trial-level pupil data (quality-filtered)
- `BAP_analysis_ready_BEHAVIORAL.csv` - Trial-level behavioral data (all trials)

**Data Structure**:
- Each row = one trial (aggregated from sample-level data)
- Filtered: Only trials with ≥80% valid data are included in PUPIL file
- Contains trial-level features: `total_auc`, `cognitive_auc`, `tonic_arousal`, etc.

**Key Variables**:
- `subject_id`: Subject identifier
- `task`: Task type (ADT, VDT)
- `run`: Run number
- `trial_index`: Trial number
- `effort_condition`: Low_5_MVC or High_40_MVC
- `difficulty_level`: Standard, Easy, or Hard
- `rt`: Reaction time
- `accuracy`: Response accuracy
- `total_auc`: Total AUC (raw pupil, 0s to response_onset)
- `cognitive_auc`: Cognitive AUC (baseline-corrected, 4.65s to response_onset)
- `baseline_B0`: Pre-trial baseline mean (-0.5s to 0s)
- `quality_iti`: ITI baseline quality (proportion valid)
- `quality_prestim`: Pre-stimulus quality (proportion valid)

## Processing Methods

### 1. Baseline Correction

**Method**: Global baseline correction per trial
- **Baseline Window**: -0.5s to 0s (last 500ms of ITI_Baseline)
- **Baseline (B₀)**: Mean pupil diameter in baseline window
- **Correction**: `pupil_isolated = pupil - baseline_B0`
- **Purpose**: Converge all conditions at squeeze onset (time = 0)

### 2. AUC Calculation (Zenon et al. 2014 Method)

**Total AUC**:
- **Data**: Raw pupil diameter (no baseline correction)
- **Window**: From trial onset (0s) to trial-specific response onset
- **Response Onset**: `4.7s + RT` (response window start + RT)
- **Method**: Trapezoidal integration
- **Formula**: `AUC = ∫(pupil) dt from 0s to response_onset`
- **Interpretation**: Full task-evoked pupil response (TEPR) including physical and cognitive demands

**Cognitive AUC**:
- **Data**: Baseline-corrected pupil (`pupil_isolated`)
- **Window**: From 300ms after target stimulus onset to trial-specific response onset
- **Target Stimulus Onset**: 4.35s (3.75s stimulus phase start + 0.1s Standard + 0.5s ISI)
- **Start**: 4.65s (4.35s + 0.3s latency offset)
- **End**: `4.7s + RT` (trial-specific response onset)
- **Method**: Trapezoidal integration
- **Formula**: `AUC = ∫(pupil_isolated) dt from 4.65s to response_onset`
- **Interpretation**: Isolated cognitive TEPR, controlling for physical effort and baseline differences

**Trapezoidal Integration**:
```r
AUC = sum(0.5 * (y[i] + y[i+1]) * diff(t[i]))
```

### 3. Quality Thresholds

**80% Valid Data Threshold**:
- Trials must have ≥80% valid (non-NaN) data in both:
  - ITI Baseline period (`quality_iti >= 0.80`)
  - Pre-Stimulus period (`quality_prestim >= 0.80`)
- Only trials meeting this threshold are included in `BAP_analysis_ready_PUPIL.csv`
- All trials (regardless of quality) are included in `BAP_analysis_ready_BEHAVIORAL.csv`

**Quality Metrics**:
- `baseline_quality`: Proportion of valid samples in baseline period
- `overall_quality`: Proportion of valid samples in entire trial
- If available from MATLAB pipeline, these are used; otherwise calculated from data

### 4. Difficulty Level Mapping

**Standard Trials**: `isOddball == 0`

**Easy Trials**: `isOddball == 1` AND `stimLev` in:
- ADT: `stimLev %in% c(3, 4)`
- VDT: `stimLev %in% c(0.24, 0.48)`

**Hard Trials**: `isOddball == 1` AND `stimLev` in:
- ADT: `stimLev %in% c(1, 2)`
- VDT: `stimLev %in% c(0.06, 0.12)`

### 5. Effort Condition Mapping

**Low Effort**: `gf_trPer == 0.05` or `force_condition == "Low_Force_5pct"`
- Maps to: `effort_condition = "Low_5_MVC"`

**High Effort**: `gf_trPer == 0.40` or `force_condition == "High_Force_40pct"`
- Maps to: `effort_condition = "High_40_MVC"`

## Trial Structure and Timing

**Time Reference**: Squeeze onset = 0s

| Phase | Time Window | Duration | Description |
|-------|-------------|----------|-------------|
| ITI_Baseline | -3.0 to 0s | 3s | Pre-trial baseline |
| Squeeze | 0 to 3.0s | 3s | Handgrip force manipulation |
| Post_Squeeze_Blank | 3.0 to 3.25s | 250ms | Post-squeeze blank |
| Pre_Stimulus_Fixation | 3.25 to 3.75s | 500ms | Pre-stimulus fixation |
| Stimulus | 3.75 to 4.45s | 700ms | Standard (100ms) + ISI (500ms) + Target (100ms) |
| Post_Stimulus_Fixation | 4.45 to 4.7s | 250ms | Post-stimulus fixation |
| Response_Different | 4.7 to 7.7s | 3000ms | Response period |
| Confidence | 7.7 to 10.7s | 3000ms | Confidence rating |

**Key Time Points**:
- **Trial Onset (Squeeze)**: 0s
- **Baseline Window**: -0.5s to 0s (for B₀ calculation)
- **Stimulus Phase Start**: 3.75s
- **Standard Onset**: 3.75s
- **ISI Start**: 3.85s
- **Target Onset**: 4.35s (3.75s + 0.1s Standard + 0.5s ISI)
- **Response Window Start**: 4.7s
- **Cognitive AUC Start**: 4.65s (4.35s + 0.3s latency)

## Subject and Trial Filtering

### Current Approach (No Run-Based Filtering)

**All subjects with data are included**, regardless of number of runs. This allows for more inclusive analysis and better data utilization.

**Previous Approach (Deprecated)**:
- Only subjects with ≥5 runs for at least one task were included
- This filtering has been disabled

### Quality Filtering

- **Behavioral Data**: All trials included (no quality filtering)
- **Pupil Data**: Only trials with ≥80% valid data in both ITI and pre-stimulus periods

## Visualization

### Waveform Plots

**Script**: `02_pupillometry_analysis/visualization/plot_pupil_waveforms.R`

**Output**: 
- `06_visualization/publication_figures/Figure3_Pupil_Waveforms_ADT_VDT.png`
- Individual plots: `Pupil_Waveform_ADT.png`, `Pupil_Waveform_VDT.png`

**Features**:
- Baseline-corrected pupil traces (`pupil_isolated`)
- Condition-specific averages (Easy/Low, Easy/High, Hard/Low, Hard/High)
- Smoothed lines with confidence intervals (GAM smoothing)
- Event markers: Trial onset, Target onset, Response
- Timeline bars: Baseline window, Total AUC window, Cognitive AUC window
- Color scheme: Blue (Easy), Pink (Hard), Light/Dark for Low/High effort

**Data Used**: All available data (no run-based subject filtering)

## Report Requirements

The comprehensive report should include:

1. **Data Inventory Section**:
   - List of all subjects with available files
   - File types per subject (raw flat, merged flat, analysis-ready)
   - File counts and sizes

2. **Subject-Level Statistics**:
   - For each subject with pupil data:
     - Number of runs per task
     - Number of trials per task
     - Number of trials per condition (effort × difficulty)
     - Quality metrics summary
     - Data availability by task

3. **Trial-Level Statistics**:
   - Total trials across all subjects
   - Trials by task (ADT, VDT)
   - Trials by effort condition (Low, High)
   - Trials by difficulty level (Standard, Easy, Hard)
   - Trials by condition combination
   - Quality distribution

4. **Quality Control Summary**:
   - Quality metrics distribution
   - Trials excluded due to quality threshold
   - Quality by task, condition, subject
   - NaN/valid data percentages

5. **Feature Extraction Summary**:
   - AUC metrics summary (Total AUC, Cognitive AUC)
   - Feature availability by subject/task
   - Missing data patterns

6. **Methods and Thresholds**:
   - Baseline correction method
   - AUC calculation method (Zenon et al. 2014)
   - Quality thresholds (80% valid data)
   - Difficulty and effort mapping rules
   - Trial structure and timing

7. **Visualizations**:
   - Quality metrics distributions
   - Trial counts by condition
   - Feature distributions
   - **Waveform plots** (from `plot_pupil_waveforms.R`)

8. **Data Flow Summary**:
   - Pipeline stages
   - File transformations
   - Filtering steps

## Key Paths and Locations

- **Processed Data**: `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/`
- **Behavioral Data**: `/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv`
- **Analysis-Ready Data**: `data/analysis_ready/`
- **QC Output**: `02_pupillometry_analysis/quality_control/output/`
- **Visualizations**: `06_visualization/publication_figures/`

## References

- **AUC Method**: Zenon, A., Sidibé, M., & Olivier, E. (2014). Pupil size variations correlate with physical effort perception. *Frontiers in Neuroscience*, 8, 286.
- **Pipeline Documentation**: See `02_pupillometry_analysis/README.md` and `PIPELINE_GUIDE.md`
- **AUC Calculation Details**: See `02_pupillometry_analysis/feature_extraction/AUC_CALCULATION_METHOD.md`
- **Stage Definitions**: See `02_pupillometry_analysis/quality_control/STAGE_DEFINITIONS.md`



