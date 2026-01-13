# Chapter 2 Materials - Portable Package

This directory contains all essential materials for Chapter 2 analysis (Psychometric-Pupil Coupling) and can be copied to a new project directory for standalone Chapter 2 work.

**📖 Quick Start**: See `README_NEXT_STEPS.md` for immediate next steps after running the data pipeline.

## Directory Structure

```
chapter2_materials/
├── data/
│   ├── ch2_triallevel.csv          # Primary analysis-ready dataset (from quick_share_v7)
│   └── README_data_source.md       # Documentation of data source and structure
├── docs/
│   ├── TIMESTAMP_DEFINITIONS.md    # Task timing definitions
│   ├── AUC_CALCULATION_METHOD.md   # AUC calculation methodology (gap-aware)
│   ├── COGNITIVE_AUC_WINDOW_IMPLEMENTATION.md  # Expert-recommended window implementation (NEW)
│   ├── CONFOUND_MITIGATION_STRATEGY.md  # Motor/response screen confound mitigation (NEW)
│   ├── FILTERING_GUIDE.md          # Guide to filtering problematic trials
│   ├── DECISION_FRAMEWORK_VERIFICATION.md  # Decision framework verification
│   ├── PUPIL_DATA_REPORT_PROMPT.md # Data structure documentation
│   ├── CHAPTER2_SETUP_PROMPT.md    # Detailed Chapter 2 setup guide
│   └── CHAPTER2_SETUP_PROMPT_CONCISE.md  # Concise setup guide
├── scripts/
│   └── make_quick_share_v7.R       # Script to regenerate data if needed
├── reports/
│   ├── pupil_data_report_advisor.qmd  # Comprehensive data quality report
│   └── references.bib              # Bibliography for reports
└── README.md                       # This file
```

## Quick Start

1. **Copy this entire directory** to your new Chapter 2 project location
2. **Load the data**: `ch2_triallevel.csv` contains all trial-level data with:
   - Behavioral variables (effort, stimulus_intensity, choice, rt, etc.)
   - Pupil metrics (total_auc, cog_auc, baseline_quality, cog_quality)
   - Quality flags (gate_pupil_primary, gate_baseline_60, gate_cog_60)
3. **Review documentation**: Start with `docs/CHAPTER2_SETUP_PROMPT_CONCISE.md` for setup instructions
4. **Check data quality**: Review `reports/pupil_data_report_advisor.qmd` for data quality assessment

## Key Data Columns

### Behavioral
- `sub`: Participant ID
- `task`: Task type (ADT or VDT)
- `effort`: Effort condition (Low or High)
- `stimulus_intensity`: Continuous stimulus intensity (1-4 for ADT, 0.06-0.48 for VDT)
- `choice`: Response choice (0/1 or same/different)
- `rt`: Reaction time in seconds

### Pupil Metrics
- `total_auc`: Total AUC (raw pupil, 0s to response onset)
- `cog_auc`: Cognitive AUC (baseline-corrected, **4.85s to 6.05s fixed window**) - **PRIMARY METRIC FOR ANALYSES**
- `cog_mean`: Mean dilation = `cog_auc / window_duration` - **PREFERRED METRIC** (removes duration confounds)
- `baseline_quality`: Proportion valid in baseline window (-0.5s to 0s)
- `B1_quality`: Proportion valid in B1 baseline window (3.85s to 4.35s, target-locked)
- `cog_quality`: Proportion valid in cognitive window (4.85s to 6.05s)

### Gap-Aware QC Metrics (NEW - Added January 2026)
These metrics help identify trials with problematic missing data patterns, even when overall quality looks acceptable:

- `cog_auc_n_valid`: Number of valid (non-NA) samples in cognitive window (expected ~300 at 250 Hz)
- `cog_window_duration`: Actual duration of cognitive window (seconds) - should be ~1.20s (fixed window)
- `cog_auc_prop_valid`: Proportion of valid samples (n_valid / expected at 250Hz)
- `cog_auc_max_gap_ms`: Maximum contiguous missing segment (milliseconds) - **KEY FOR FILTERING**
- `cog_auc_n_segments`: Number of contiguous valid segments (1 = continuous, >1 = fragmented)

### Confound Mitigation Metrics (NEW - Added January 2026)
Window definitions for minimizing motor/response screen contamination:

- `t_resp_actual`: Trial-specific response onset (4.70s + RT)
- `cog_win_primary_end_motorbuffered`: Motor-buffered window end (truncates 150ms before button press)
- `cog_win_truncated_by_motor`: Flag: Was primary window truncated by motor buffer?
- `cog_win_uncontaminated_by_motor`: Flag: Slow RT trials where motor can't contaminate
- `cog_win_preresp_start/end/duration`: Pre-response window (decision-aligned, excludes motor)
- `cog_win_preresp_valid`: Flag: Is pre-response window valid (duration ≥ 0.35s)?

**Note**: The cognitive AUC window has been updated from a problematic 50ms window (4.65-4.70s) to an expert-recommended 1.20s fixed window (4.85-6.05s). Motor buffer truncation and pre-response windows are defined to minimize confounds. See `docs/COGNITIVE_AUC_WINDOW_IMPLEMENTATION.md` and `docs/CONFOUND_MITIGATION_STRATEGY.md` for details.

### Quality Flags
- `gate_pupil_primary`: Chapter 2 ready (B1_quality ≥ 0.50 AND cog_quality ≥ 0.60)
- `gate_baseline_60`: Baseline quality ≥ 0.60
- `gate_cog_60`: Cognitive quality ≥ 0.60

## Data Source

Data comes from `data/pupil_processed/` (formerly `quick_share_v7/`, most recent version with fixed baseline alignment). See `data/README_data_source.md` for details.

## Analysis Requirements

- **Primary threshold**: B1 baseline 50% validity AND cognitive window 60% validity
- **Sensitivity checks**: 50% and 70% thresholds
- **Pupil features**: Cognitive AUC (baseline-corrected) for trial-wise coupling
- **Statistical approach**: GLMM with continuous stimulus intensity

## Filtering Problematic Trials

See `docs/FILTERING_GUIDE.md` for detailed guidance on using gap-aware QC metrics to filter problematic trials. See `docs/DECISION_FRAMEWORK_VERIFICATION.md` for verification that the decision framework is properly implemented.

**Quick reference:**

**Primary (Strict) Exclusion Rule** (Expert-Recommended - Option A):
```r
ch2_primary <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,           # B1_quality >= 0.50 & cog_quality >= 0.60
    # Gap-aware exclusions (only apply if metrics exist)
    is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 250,            # No large gaps (Kret & Sjak-Shie)
    is.na(cog_window_duration) | cog_window_duration >= 0.90,         # Sufficient duration (75% of 1.20s)
    is.na(cog_auc_n_valid) | cog_auc_n_valid >= 240                   # Enough samples (80% of ~300)
  )
```

**Rationale**: 
- 1.20s window should have ~300 samples at 250 Hz
- 80% coverage = 240 valid samples ensures robust estimates
- 0.90s minimum duration ensures sufficient temporal coverage
- 250ms max gap prevents large missing segments from distorting AUC

**Rationale**: Kret & Sjak-Shie recommend not interpolating gaps >250ms; Burg et al. show large gaps can distort AUC even with acceptable %-valid.

**Sensitivity (Moderate)**:
```r
ch2_moderate <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,           # B1_quality >= 0.50 & cog_quality >= 0.60
    is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 250,            # Still enforce gap threshold
    is.na(cog_window_duration) | cog_window_duration >= 0.75          # Relaxed duration (62.5% of 1.20s)
  )
```

**Sensitivity (Lenient)**:
```r
ch2_lenient <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,           # B1_quality >= 0.50 & cog_quality >= 0.60
    is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 400             # Allows larger gaps
  )
```

## Recent Updates (January 2026)

**Expert-Recommended Cognitive AUC Window Implementation**:
- ✅ Primary window updated from 50ms (4.65-4.70s) to 1.20s fixed window (4.85-6.05s)
- ✅ Mean dilation metric (`cog_mean`) added - preferred over raw AUC
- ✅ Quality thresholds updated based on expert recommendations
- ✅ **Motor buffer truncation** implemented to minimize button press contamination
- ✅ **Pre-response window** definitions added for decision-aligned analyses

**Documentation**:
- 📖 `NEXT_STEPS.md` - Step-by-step guide for analysis preparation
- 📖 `IMPLEMENTATION_SUMMARY.md` - Quick reference for window changes
- 📖 `CONFOUND_MITIGATION_SUMMARY.md` - Confound mitigation summary
- 📖 `docs/COGNITIVE_AUC_WINDOW_IMPLEMENTATION.md` - Comprehensive window guide
- 📖 `docs/CONFOUND_MITIGATION_STRATEGY.md` - Detailed confound mitigation strategies

## Additional Resources

- Original repository: `/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM`
- Full pipeline: See `02_pupillometry_analysis/` in original repository
- Latest data: `data/pupil_processed/` in original repository

