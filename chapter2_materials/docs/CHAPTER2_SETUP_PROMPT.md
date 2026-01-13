# Chapter 2 Setup Prompt for Cursor Agent

## Context
You are setting up Chapter 2 of a PhD dissertation: "Pupil-Indexed Arousal and Psychometric Sensitivity in Older Adults". This chapter extends the dual-task paradigm (handgrip + perceptual discrimination) to older adults and tests how physical effort and pupil-indexed arousal relate to psychometric sensitivity.

## Key Requirements from Prospectus

### Primary Aims
1. **Behavioral backbone (PF outcomes)**: Report PF-derived thresholds and slopes from existing behavioral manuscript, showing how High vs Low effort alters psychometric parameters
2. **Effort-pupil manipulation check**: Test whether High effort increases tonic and task-evoked pupil dynamics
3. **Pupil-psychometric coupling (primary)**: Test whether trial-wise phasic arousal predicts psychometric sensitivity when stimulus intensity is modeled continuously

### Data Requirements

#### 1. Behavioral Data (Trial-Level)
**Source**: `/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/`
- `bap_beh_trialdata_v2.csv` - Main trial-level behavioral data
- `bap_beh_subjxtaskdata_v2.csv` - Subject-level summaries by task
- Required columns:
  - Subject ID (`sub` or `subject_id`)
  - Task (`task`: ADT/VDT)
  - Effort condition (`effort_condition`: Low_5_MVC, High_40_MVC, or similar)
  - Stimulus intensity (continuous):
    - Auditory: frequency offset (±8, ±16, ±32, ±64 Hz)
    - Visual: contrast difference (±0.06, ±0.12, ±0.24, ±0.48)
  - Choice/decision (`decision`, `choice`, or `correct`): same/different or 0/1
  - Response time (`rt`, `response_time`): in seconds
  - Trial metadata (session, run, trial number)

#### 2. Pupil Data (Trial-Level with Quality Metrics)
**Source**: `quick_share_v7/analysis_ready/ch2_triallevel.csv` (PRIMARY SOURCE - already merged!)
- This file contains trial-level data with both behavioral and pupil measures
- Trial-level pupil features with:
  - **Tonic baseline**: Pre-event window pupil diameter (e.g., -0.5s to 0s relative to target)
  - **Phasic task-evoked**: Fixed post-target window (e.g., target+0.3s → target+1.3s)
  - **Total AUC**: Baseline-corrected area under curve over global trial window
  - **Window-specific validity**: Proportion of valid samples in each window
  - Quality flags: `baseline_quality`, `cog_quality`, `overall_quality`, `gate_pupil_primary`
- Alternative sources (if ch2_triallevel.csv is incomplete):
  - `data/analysis_ready/BAP_analysis_ready_PUPIL_full.csv`
  - `data/analysis_ready/BAP_trialwise_pupil_features.csv`
  - `data/analysis_ready/BAP_triallevel_merged.csv` (merged behavioral + pupil)

#### 3. Psychometric Function (PF) Fits
**Source**: May need to be located or re-estimated
- Subject-level PF parameters:
  - Thresholds (PSE or JND)
  - Slopes (sensitivity)
  - Separated by: Task (ADT/VDT) × Effort (Low/High)
- If PF fits don't exist, they need to be computed from behavioral data using:
  - Probit or logit link functions
  - Continuous stimulus intensity as predictor
  - Subject-level random effects

#### 4. Analysis-Ready Merged Data
**Target**: Create `data/analysis_ready/ch2_triallevel_merged.csv`
- Merge behavioral + pupil data on: `subject_id`, `task`, `trial_number` (or equivalent)
- Include quality tiers:
  - Primary: B1 baseline validity ≥ 0.50 AND cognitive window validity ≥ 0.60
  - Sensitivity tier 1: ≥ 0.50 (lenient)
  - Sensitivity tier 2: ≥ 0.70 (stricter)
- Compute within-subject centered pupil metrics:
  - `pupil_state` = trial pupil - subject mean pupil
  - `pupil_trait` = subject mean pupil

## Directory Structure to Create

```
07_manuscript/
├── chapter2/
│   ├── data/
│   │   ├── raw/
│   │   │   ├── behavioral/          # Copy from /Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/
│   │   │   └── pupil/               # Link or copy from data/analysis_ready/
│   │   ├── processed/
│   │   │   ├── ch2_triallevel_merged.csv
│   │   │   ├── ch2_pf_parameters.csv
│   │   │   └── ch2_subject_summary.csv
│   │   └── qc/
│   │       ├── pupil_quality_summary.csv
│   │       ├── missingness_diagnostic.csv
│   │       └── inclusion_bias_table.csv
│   ├── scripts/
│   │   ├── 01_load_and_merge_data.R
│   │   ├── 02_compute_pf_parameters.R
│   │   ├── 03_pupil_quality_tiers.R
│   │   ├── 04_effort_pupil_manipulation_check.R
│   │   ├── 05_missingness_diagnostic.R
│   │   ├── 06_pupil_psychometric_coupling.R
│   │   ├── 07_pf_pupil_subject_coupling.R
│   │   └── 08_generate_figures.R
│   ├── output/
│   │   ├── tables/
│   │   ├── figures/
│   │   └── models/
│   └── reports/
│       └── chap2_psychometric_pupil.qmd
```

## Analysis Scripts to Create

### Script 1: `01_load_and_validate_data.R`
- **Primary approach**: Load pre-merged data from `quick_share_v7/analysis_ready/ch2_triallevel.csv`
- **Alternative approach** (if pre-merged file is incomplete):
  - Load behavioral data from `/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv`
  - Load pupil data from `data/analysis_ready/BAP_analysis_ready_PUPIL_full.csv` or similar
  - Merge on subject_id, task, trial identifier
- Validate data structure:
  - Check required columns exist
  - Check for missing matches, duplicates
  - Verify quality flags are present
  - Check stimulus intensity is continuous (not binned)
- Save validated dataset: `data/processed/ch2_triallevel_merged.csv`

### Script 2: `02_compute_pf_parameters.R`
- If PF fits exist: Load and format them
- If PF fits don't exist: Fit psychometric functions using:
  - `glmer()` or `brm()` with probit link
  - Formula: `choice ~ stimulus_intensity + effort + task + (1|subject_id)`
  - Extract thresholds and slopes per subject × task × effort
- Save: `data/processed/ch2_pf_parameters.csv`

### Script 3: `03_pupil_quality_tiers.R`
- Define quality tiers based on window validity:
  - Primary: baseline ≥ 0.60 AND cognitive ≥ 0.60
  - Lenient: baseline ≥ 0.50 AND cognitive ≥ 0.50
  - Strict: baseline ≥ 0.70 AND cognitive ≥ 0.70
- Create quality flags for each tier
- Compute within-subject centered pupil metrics:
  - `pupil_cognitive_state` = trial value - subject mean
  - `pupil_cognitive_trait` = subject mean
- Save quality summary: `data/qc/pupil_quality_summary.csv`

### Script 4: `04_effort_pupil_manipulation_check.R`
- Test whether High effort increases pupil metrics relative to Low effort
- Models:
  - `Total AUC ~ effort + task + (1|subject_id)`
  - `Cognitive pupil ~ effort + task + (1|subject_id)`
- Use primary quality tier (B1 ≥0.50 & Cog ≥0.60)
- Report effect sizes, credible intervals, and p-values
- Generate figures: effort × pupil scatter plots, boxplots

### Script 5: `05_missingness_diagnostic.R`
- Model pupil data missingness as outcome
- Logistic mixed-effects model:
  - `pupil_usable ~ effort + stimulus_intensity + task + rt + (1|subject_id)`
- Test whether retention is predicted by task variables
- If systematic bias detected, document and plan robustness checks
- Save: `data/qc/missingness_diagnostic.csv`

### Script 6: `06_pupil_psychometric_coupling.R` (PRIMARY ANALYSIS)
- Fit hierarchical GLMM with continuous stimulus intensity
- Model specification (probit link):
  ```
  choice ~ stimulus_intensity 
         + effort 
         + task 
         + pupil_cognitive_state 
         + stimulus_intensity:pupil_cognitive_state 
         + pupil_cognitive_trait
         + (1 + stimulus_intensity | subject_id)
  ```
- Key term: `stimulus_intensity:pupil_cognitive_state` interaction
- Test robustness across quality tiers (primary, lenient, strict)
- Generate figures: psychometric curves by pupil tertiles, interaction plots
- Save model outputs and summaries

### Script 7: `07_pf_pupil_subject_coupling.R`
- Compute subject-level changes:
  - Δpupil = High effort pupil - Low effort pupil
  - ΔPF_threshold = High effort threshold - Low effort threshold
  - ΔPF_slope = High effort slope - Low effort slope
- Correlate Δpupil with ΔPF parameters
- Test consistency between full behavioral dataset and pupil subset
- Generate figures: scatter plots of Δpupil vs ΔPF parameters

### Script 8: `08_generate_figures.R`
- Psychometric function plots by effort condition
- Pupil × effort manipulation check plots
- Psychometric curves by pupil state (high/medium/low tertiles)
- Subject-level coupling plots (Δpupil vs ΔPF)
- Missingness diagnostic plots
- All figures saved to `output/figures/` in publication-ready format

## Quarto Report Template

Create `reports/chap2_psychometric_pupil.qmd` with sections:
1. Introduction and Aims
2. Methods
   - Participants and Task
   - Pupil Features and Quality Strategy
   - Statistical Models
3. Results
   - Behavioral Backbone (PF Outcomes)
   - Effort-Pupil Manipulation Check
   - Missingness Diagnostic
   - Pupil-Psychometric Coupling (Primary)
   - Subject-Level PF-Pupil Coupling
4. Discussion
   - Integration with Chapter 1
   - Implications for Chapter 3

## Key Files to Copy/Link

### From `/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/`:
- `bap_beh_trialdata_v2.csv` → `07_manuscript/chapter2/data/raw/behavioral/`
- `bap_beh_subjxtaskdata_v2.csv` → `07_manuscript/chapter2/data/raw/behavioral/`
- `bap_beh_trialdata_v2_report.txt` → `07_manuscript/chapter2/data/raw/behavioral/` (for reference)

### From Current Repository:
- **PRIMARY**: `quick_share_v7/analysis_ready/ch2_triallevel.csv` (already merged behavioral + pupil)
  - Copy to: `07_manuscript/chapter2/data/processed/ch2_triallevel_merged.csv`
- Alternative pupil data files (if needed):
  - `data/analysis_ready/BAP_analysis_ready_PUPIL_full.csv`
  - `data/analysis_ready/BAP_trialwise_pupil_features.csv`
  - `data/analysis_ready/BAP_triallevel_merged.csv`
- Configuration files:
  - `config/paths_config.R.example` → adapt for Chapter 2 paths
  - `config/pipeline_config.R` → reference for structure

### Helper Functions to Reuse:
- From `scripts/02_statistical_analysis/`:
  - Data loading helpers
  - Quality control functions
  - Figure generation utilities
- From `02_pupillometry_analysis/`:
  - Pupil preprocessing functions
  - Window validity computation

## Implementation Steps

1. **Create directory structure** as outlined above
2. **Copy behavioral data** from `/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/`
3. **Locate and copy pupil data** (identify correct source files)
4. **Create data loading script** (`01_load_and_merge_data.R`)
5. **Validate merged dataset** (check N, missingness, variable names)
6. **Create PF computation script** (or locate existing PF fits)
7. **Implement quality tier system** (`03_pupil_quality_tiers.R`)
8. **Implement analysis scripts** (04-07) following prospectus specifications
9. **Create Quarto report** with integrated results
10. **Generate all figures and tables** for dissertation

## Validation Checklist

- [ ] Behavioral data loaded with all required columns
- [ ] Pupil data merged successfully with quality metrics
- [ ] Quality tiers defined and applied correctly
- [ ] PF parameters computed or loaded (by subject × task × effort)
- [ ] Effort-pupil manipulation check shows High > Low effort
- [ ] Missingness diagnostic completed
- [ ] Primary GLMM fitted with continuous stimulus intensity
- [ ] Within-subject centered pupil metrics computed correctly
- [ ] Key interaction term (stimulus × pupil_state) tested
- [ ] Robustness checks across quality tiers completed
- [ ] Subject-level PF-pupil coupling computed
- [ ] All figures generated in publication-ready format
- [ ] Quarto report renders without errors

## Notes

- **Stimulus intensity**: Must be continuous (not binned into Easy/Hard)
- **Pupil windows**: Fixed post-target window (e.g., 300ms-1.3s) to avoid RT confounding
- **Quality strategy**: Window-specific validity, not global trial validity
- **Within-subject centering**: Critical for separating state vs trait arousal effects
- **Probit link**: Natural for psychometric modeling (can also use logit)
- **Robustness**: Test across multiple quality thresholds (0.50, 0.60, 0.70)

## Expected Outputs

1. **Merged trial-level dataset** with behavioral + pupil + quality flags
2. **PF parameter table** (subject × task × effort)
3. **Effort-pupil manipulation check results** (tables + figures)
4. **Missingness diagnostic results** (table)
5. **Primary GLMM results** (pupil-psychometric coupling)
6. **Subject-level coupling results** (Δpupil vs ΔPF)
7. **Publication-ready figures** (6-8 figures)
8. **Quarto report** (HTML + PDF)

---

**Start by**: Creating the directory structure, copying behavioral data, and identifying the correct pupil data source files.

