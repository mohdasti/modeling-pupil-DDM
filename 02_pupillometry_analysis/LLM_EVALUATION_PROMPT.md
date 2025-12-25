# Comprehensive LLM Evaluation Prompt: Pupil Data Quality Report for Dissertation Chapters 2 & 3

## Context and Research Goals

I am preparing a comprehensive pupil data quality report to support two dissertation chapters that integrate pupillometry with psychometric and drift-diffusion modeling (DDM) analyses in older adults. The report needs to help me make data-driven decisions about **which subjects and trials to include** in each chapter's analyses, and **what quality thresholds are appropriate** given my research questions.

### Chapter 2: Psychometric–Pupil Coupling

**Primary Research Questions:**
1. **Effort–pupil manipulation check**: Do trial-wise Total AUC and Cognitive AUC differ between Low and High effort conditions?
2. **Trial-level psychometric modulation by pupil (primary analysis)**: How does within-subject Cognitive AUC (Low/Medium/High tertiles) modulate psychometric sensitivity (logistic mixed-effects models)?
3. **Secondary continuous-pupil and subject-level coupling**: Linear relationships between Cognitive AUC and sensitivity; subject-level coupling between arousal changes and threshold/slope changes.

**Pupil Requirements:**
- **Total AUC**: Needed for effort manipulation check and subject-level coupling (High–Low effort changes)
- **Cognitive AUC**: Primary analysis uses trial-wise Cognitive AUC tertiles; secondary uses continuous z-scored Cognitive AUC
- **Quality Threshold**: High and Medium quality trials (overall quality ≥ 0.60 for primary analysis, ≥ 0.50 for secondary)
- **Gate Requirements**: Gate C (minimum) for Cognitive AUC; Gate B + Gate C for effort manipulation check

### Chapter 3: DDM with Pupil Predictors

**Primary Research Questions:**
- DDM models with pupil as a predictor (arousal effects on drift rate, boundary separation, etc.)
- Behavior-only DDM models (no pupil predictors)

**Pupil Requirements:**
- **For DDM with pupil predictors**: Conservative subset of High and Medium quality trials (overall quality ≥ 0.60)
- **For behavior-only DDM**: No pupil quality gates required (uses full DDM-ready set)
- **Gate Requirements**: Gate C (minimum) for pupil predictor models (needs pupil data during response period: 4.65s to response onset)

## Current Report Structure

I have a Quarto Markdown report (`generate_pupil_data_report.qmd`) that includes:

### Section 1: Data Inventory
- File discovery and subject file inventory
- Identification of subjects missing merged files (with diagnostic reasons)

### Section 2: RAW PUPIL TRIAL COVERAGE (PRE-FILTER)
- Trial-level coverage metrics computed from raw sample data:
  - `recording_max_time`, `last_valid_time`
  - `valid_prop_baseline_500ms`, `valid_prop_prestim`, `valid_prop_total_auc`, `valid_prop_cognitive_auc`
  - `n_rows_*` for each window
  - `response_onset` (4.7s + RT)
- Condition labeling (effort_condition, difficulty_level) with diagnostics for missing labels

### Section 3: Methods and Quality Gates
- **Gate A (Baseline + Prestimulus)**: Baseline (-0.5s to 0s) + Prestimulus (3.25s to 3.75s)
- **Gate B (Total AUC Window)**: Gate A + Total AUC (0s to response_onset)
- **Gate C (Cognitive AUC Window)**: Gate A + Cognitive AUC (4.65s to response_onset)
- Research question → gate requirements mapping table
- Processing methods (baseline correction, AUC calculation, quality thresholds)

### Section 4: Coverage Statistics
- Subject overview (by subject × task) with gate-based usable trial counts at threshold 0.80
- Condition labeling diagnostics (showing why conditions are missing)
- Condition breakdown by threshold (Gate C at 0.70/0.80/0.90)
- Threshold sensitivity curves (how retained trials change across thresholds)
- Condition balance heatmaps (effort × difficulty)
- Threshold sweep dashboard
- Salvageability by research window
- Automated warnings (minimum per cell, threshold instability, effort asymmetry)

### Section 5: Diagnostic Dashboards
- **Filter Funnel / Loss Reasons**: Why trials fail (baseline vs prestim vs missing RT vs late dropout)
- **Time-Resolved Availability Curve**: Where dropout happens in time (stimulus-locked and response-locked)
- Shows availability by effort condition and difficulty level

### Section 6: Analysis-Ready Data Statistics (Post-Filter)
- Subject-level statistics from analysis-ready files
- Quality metrics distribution
- AUC metrics summary

### Section 7: Visualizations
- Pupil waveform plots

## Key Questions for Evaluation

### 1. Subject Inclusion Criteria

**For Chapter 2 (Psychometric–Pupil Coupling):**
- What minimum number of usable trials per subject should I require?
- Should I exclude subjects with:
  - < 10 trials per condition cell (effort × difficulty)?
  - < 50% of expected trials passing Gate C at threshold 0.80?
  - Asymmetric missingness (High effort has >2× missingness vs Low effort)?
  - Unstable retention (drop >30% when moving from 0.70 → 0.80 threshold)?
- How should I handle subjects with partial data (e.g., only ADT or only VDT)?
- Should I create separate inclusion criteria for primary (Cognitive AUC tertiles) vs secondary (continuous Cognitive AUC) analyses?

**For Chapter 3 (DDM with Pupil Predictors):**
- What minimum number of usable trials per subject for stable DDM parameter estimation?
- Should I exclude subjects based on:
  - Gate C retention rates?
  - Response period data quality?
  - Overall quality metrics?
- How should I handle subjects that are usable for behavior-only DDM but not for pupil-predictor DDM?

**General:**
- Should I create a "subject inclusion matrix" showing which subjects qualify for which analyses?
- How should I handle subjects that are borderline (e.g., 8-12 trials per cell instead of 10)?

### 2. Sensitivity Analysis Needs

- **Threshold sensitivity**: Should I run analyses at multiple thresholds (0.70, 0.80, 0.90) to show robustness?
- **Trial count sensitivity**: Should I test how results change if I require 8 vs 10 vs 12 trials per cell?
- **Subject-level sensitivity**: Should I test how results change if I exclude the "worst" 5% of subjects by quality?
- **Window-specific sensitivity**: Should I test how Cognitive AUC results change if I use different cognitive window start times (e.g., 4.65s vs 4.7s vs 5.0s)?

### 3. Report Enhancements

**What additional sections/analyses would make this report more useful for:**
- **Supervisor review**: What do supervisors need to see to approve data quality?
- **Publication readiness**: What quality checks are expected by reviewers?
- **Decision-making**: What metrics help decide inclusion/exclusion?
- **Transparency**: What should be documented for reproducibility?

**Specific questions:**
- Should I add a "Subject Inclusion Decision Matrix" showing which subjects qualify for each analysis?
- Should I add "Quality Tiers" (e.g., Tier 1: High quality, Tier 2: Medium quality, Tier 3: Low quality) with recommended uses?
- Should I add "Power Analysis" estimates (e.g., expected effect sizes detectable with current sample sizes)?
- Should I add "Missing Data Patterns" analysis (e.g., is missingness related to age, task difficulty, effort condition)?
- Should I add "Cross-Validation" checks (e.g., do subjects with good pupil data also have good behavioral data quality)?
- Should I add "Temporal Stability" checks (e.g., does quality degrade across runs/trials within a session)?

### 4. Data Presentation

**Current report shows:**
- Tables with trial counts at different thresholds
- Plots showing threshold sensitivity
- Diagnostic tables for missing conditions

**What additional visualizations would be helpful?**
- Subject-level quality "report cards"?
- Heatmaps showing quality by subject × condition?
- Flowcharts showing trial loss at each gate?
- Quality distribution plots by subject?

### 5. Actionable Recommendations

**Please provide:**
1. **Specific inclusion criteria** for Chapter 2 and Chapter 3 (with justifications)
2. **Recommended sensitivity analyses** (which ones are essential vs optional)
3. **New report sections** to add (with specific content descriptions)
4. **Visualization recommendations** (what plots would be most informative)
5. **Quality tier system** (if recommended, with clear definitions)
6. **Decision framework** (step-by-step process for determining subject inclusion)

## Files Provided

1. **`generate_pupil_data_report.qmd`**: The complete Quarto Markdown report (note: this file contains the code structure but not the actual data; data is loaded from external CSV files during rendering)
2. **Dissertation Prospectus**: Detailed descriptions of Chapter 2 and Chapter 3 analyses (provided separately)

## Data Context (Not in QMD File)

**Data Sources:**
- **Pupil data**: Flat CSV files in `BAP_processed/` directory (either `*_flat.csv` or `*_flat_merged.csv`)
- **Behavioral data**: `bap_beh_trialdata_v2.csv` in `Nov2025/` directory
- **Analysis-ready data**: `BAP_analysis_ready_PUPIL.csv` and `BAP_analysis_ready_BEHAVIORAL.csv` in `data/analysis_ready/`

**Key Variables:**
- **Subject identifiers**: `subject_id` (e.g., "BAP003", "BAP109")
- **Tasks**: ADT (auditory), VDT (visual)
- **Conditions**: 
  - Effort: Low_5_MVC, High_40_MVC
  - Difficulty: Standard, Easy, Hard
- **Quality metrics**: `valid_prop_*` (proportions), `overall_quality` (0-1 scale)
- **AUC metrics**: `total_auc`, `cognitive_auc` (calculated post-filter)

**Current Quality Gates:**
- **Gate A**: `valid_prop_baseline_500ms >= threshold` AND `valid_prop_prestim >= threshold`
- **Gate B**: Gate A AND `valid_prop_total_auc >= threshold`
- **Gate C**: Gate A AND `valid_prop_cognitive_auc >= threshold`

**Default Threshold**: 0.80 (80% valid samples required)

## Expected Output

Please provide:
1. **Comprehensive evaluation** of the current report structure
2. **Specific recommendations** for:
   - Subject inclusion criteria (with thresholds and justifications)
   - Sensitivity analyses to run
   - New report sections to add
   - Visualizations to create
3. **Prioritized action items** (what's most critical vs nice-to-have)
4. **Example code/structure** for recommended additions (if helpful)

## Constraints

- The report must be renderable as HTML via Quarto
- All analyses must be reproducible (use cached data where appropriate)
- The report should be suitable for supervisor review and publication documentation
- Processing time should be reasonable (current report takes ~5-10 minutes to render)

---

**Note**: This prompt will be provided along with the QMD file and dissertation prospectus. Please evaluate the report comprehensively and provide actionable recommendations for making it maximally useful for data quality decision-making.



