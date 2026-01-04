# Chapter 2 Setup: Quick Start Prompt for Cursor Agent

## Your Task
Set up Chapter 2 analysis pipeline: "Pupil-Indexed Arousal and Psychometric Sensitivity in Older Adults"

## Key Files Already Available

### ✅ Pre-Merged Trial-Level Data (USE THIS!)
**File**: `quick_share_v7/analysis_ready/ch2_triallevel.csv` (14,586 trials)
- **Already contains**: Behavioral + Pupil data merged
- **Key columns**:
  - Behavioral: `sub`, `task` (ADT/VDT), `effort` (Low/High), `stimulus_intensity` (continuous), `choice`, `rt`, `correct`
  - Pupil: `baseline_B0_mean`, `cog_auc`, `total_auc`, `baseline_quality`, `cog_quality`
  - Quality gates: `gate_pupil_primary`, `gate_baseline_60`, `gate_cog_60`

### ✅ Behavioral Data (For Reference/Validation)
**Source**: `/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/`
- `bap_beh_trialdata_v2.csv` - Full behavioral dataset (17,971 trials)
- `bap_beh_subjxtaskdata_v2.csv` - Subject-level summaries
- Use for: PF parameter computation, validation, or if ch2_triallevel.csv is incomplete

## What You Need to Do

### Step 1: Create Directory Structure
```
07_manuscript/
└── chapter2/
    ├── data/
    │   ├── raw/
    │   │   └── behavioral/          # Copy from /Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/
    │   ├── processed/
    │   │   └── ch2_triallevel_merged.csv  # Copy from quick_share_v7/analysis_ready/ch2_triallevel.csv
    │   └── qc/
    ├── scripts/
    │   ├── 01_validate_and_prepare_data.R
    │   ├── 02_compute_pf_parameters.R
    │   ├── 03_effort_pupil_manipulation_check.R
    │   ├── 04_missingness_diagnostic.R
    │   ├── 05_pupil_psychometric_coupling.R  # PRIMARY ANALYSIS
    │   ├── 06_pf_pupil_subject_coupling.R
    │   └── 07_generate_figures.R
    ├── output/
    │   ├── tables/
    │   ├── figures/
    │   └── models/
    └── reports/
        └── chap2_psychometric_pupil.qmd
```

### Step 2: Copy Required Files
```bash
# Copy behavioral data (for reference/validation)
cp /Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/*.csv 07_manuscript/chapter2/data/raw/behavioral/

# Copy pre-merged trial-level data (PRIMARY DATA SOURCE)
cp quick_share_v7/analysis_ready/ch2_triallevel.csv 07_manuscript/chapter2/data/processed/ch2_triallevel_merged.csv
```

### Step 3: Implement Analysis Scripts

#### Script 1: `01_validate_and_prepare_data.R`
- Load `ch2_triallevel_merged.csv`
- Validate required columns exist
- Create quality tier flags:
  - Primary: `gate_baseline_60 == TRUE & gate_cog_60 == TRUE`
  - Lenient: `baseline_quality >= 0.50 & cog_quality >= 0.50`
  - Strict: `baseline_quality >= 0.70 & cog_quality >= 0.70`
- Compute within-subject centered pupil metrics:
  - `pupil_cognitive_state = cog_auc - mean(cog_auc, by=subject)`
  - `pupil_cognitive_trait = mean(cog_auc, by=subject)`
- Save validated dataset

#### Script 2: `02_compute_pf_parameters.R`
- Fit psychometric functions using continuous stimulus intensity
- Model: `glmer(choice ~ stimulus_intensity + effort + task + (1|sub), family=binomial(link="probit"))`
- Extract thresholds and slopes per subject × task × effort
- Save: `output/tables/ch2_pf_parameters.csv`

#### Script 3: `03_effort_pupil_manipulation_check.R`
- Test: High effort > Low effort for pupil metrics
- Models:
  - `lmer(total_auc ~ effort + task + (1|sub))`
  - `lmer(cog_auc ~ effort + task + (1|sub))`
- Use primary quality tier (`gate_pupil_primary == TRUE`)
- Generate figures: boxplots, scatter plots

#### Script 4: `04_missingness_diagnostic.R`
- Model pupil data missingness as outcome
- `glmer(pupil_usable ~ effort + stimulus_intensity + task + rt + (1|sub), family=binomial)`
- Test if retention depends on task variables
- Save diagnostic table

#### Script 5: `05_pupil_psychometric_coupling.R` ⭐ PRIMARY ANALYSIS
- Fit hierarchical GLMM with continuous stimulus intensity
- Model (probit link):
  ```
  glmer(choice ~ stimulus_intensity 
              + effort 
              + task 
              + pupil_cognitive_state 
              + stimulus_intensity:pupil_cognitive_state 
              + pupil_cognitive_trait
              + (1 + stimulus_intensity | sub),
        family = binomial(link = "probit"))
  ```
- **Key term**: `stimulus_intensity:pupil_cognitive_state` interaction
- Test robustness across quality tiers
- Generate psychometric curves by pupil tertiles

#### Script 6: `06_pf_pupil_subject_coupling.R`
- Compute subject-level changes:
  - `Δpupil = High effort pupil - Low effort pupil`
  - `ΔPF_threshold = High threshold - Low threshold`
  - `ΔPF_slope = High slope - Low slope`
- Correlate Δpupil with ΔPF parameters
- Generate scatter plots

#### Script 7: `07_generate_figures.R`
- Psychometric function plots by effort
- Pupil × effort manipulation check
- Psychometric curves by pupil state (high/medium/low)
- Subject-level coupling plots
- All figures → `output/figures/` (publication-ready)

### Step 4: Create Quarto Report
Create `reports/chap2_psychometric_pupil.qmd` with:
1. Introduction and Aims
2. Methods (Participants, Pupil Features, Quality Strategy, Models)
3. Results (PF outcomes, Effort-pupil check, Missingness, Primary coupling, Subject-level coupling)
4. Discussion

## Key Specifications from Prospectus

### Pupil Features
- **Total AUC**: Baseline-corrected area over global trial window
- **Cognitive pupil metric**: Fixed post-target window (target+0.3s → target+1.3s)
- **Quality tiers**: Primary (≥0.60), Lenient (≥0.50), Strict (≥0.70)

### Statistical Models
- **Probit link** (natural for psychometric modeling)
- **Within-subject centering** (critical for state vs trait separation)
- **Continuous stimulus intensity** (NOT binned into Easy/Hard)
- **Window-specific validity** (not global trial validity)

### Expected Outputs
1. Validated trial-level dataset
2. PF parameter table (subject × task × effort)
3. Effort-pupil manipulation check results
4. Missingness diagnostic
5. Primary GLMM results (pupil-psychometric coupling)
6. Subject-level coupling results
7. 6-8 publication-ready figures
8. Quarto report (HTML + PDF)

## Validation Checklist
- [ ] Data loaded with all required columns
- [ ] Quality tiers defined correctly
- [ ] PF parameters computed (by subject × task × effort)
- [ ] Within-subject centered pupil metrics computed
- [ ] Effort-pupil manipulation check shows High > Low
- [ ] Missingness diagnostic completed
- [ ] Primary GLMM fitted with continuous stimulus intensity
- [ ] Key interaction term (stimulus × pupil_state) tested
- [ ] Robustness checks across quality tiers
- [ ] All figures generated
- [ ] Quarto report renders

## Start Here
1. Create directory structure
2. Copy `ch2_triallevel.csv` to `data/processed/`
3. Copy behavioral files to `data/raw/behavioral/`
4. Begin with Script 1 (data validation)

---

**Full detailed prompt**: See `docs/development_notes/CHAPTER2_SETUP_PROMPT.md` for complete specifications.

