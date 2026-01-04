# Chapter 2 Materials - Portable Package

This directory contains all essential materials for Chapter 2 analysis (Psychometric-Pupil Coupling) and can be copied to a new project directory for standalone Chapter 2 work.

## Directory Structure

```
chapter2_materials/
├── data/
│   ├── ch2_triallevel.csv          # Primary analysis-ready dataset (from quick_share_v7)
│   └── README_data_source.md       # Documentation of data source and structure
├── docs/
│   ├── TIMESTAMP_DEFINITIONS.md    # Task timing definitions
│   ├── AUC_CALCULATION_METHOD.md   # AUC calculation methodology
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
- `cog_auc`: Cognitive AUC (baseline-corrected, 4.65s to response onset)
- `baseline_quality`: Proportion valid in baseline window (-0.5s to 0s)
- `cog_quality`: Proportion valid in cognitive window (4.65s to response onset)

### Quality Flags
- `gate_pupil_primary`: Chapter 2 ready (baseline_quality ≥ 0.60 AND cog_quality ≥ 0.60)
- `gate_baseline_60`: Baseline quality ≥ 0.60
- `gate_cog_60`: Cognitive quality ≥ 0.60

## Data Source

Data comes from `data/pupil_processed/` (formerly `quick_share_v7/`, most recent version with fixed baseline alignment). See `data/README_data_source.md` for details.

## Analysis Requirements

- **Primary threshold**: 60% validity (baseline AND cognitive)
- **Sensitivity checks**: 50% and 70% thresholds
- **Pupil features**: Cognitive AUC (baseline-corrected) for trial-wise coupling
- **Statistical approach**: GLMM with continuous stimulus intensity

## Additional Resources

- Original repository: `/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM`
- Full pipeline: See `02_pupillometry_analysis/` in original repository
- Latest data: `data/pupil_processed/` in original repository

