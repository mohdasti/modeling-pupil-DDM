## BAP Pupillometry Data Quality – Detailed Summary

This document summarizes how **pupil/eye-tracking data quality** is defined and quantified in the BAP project, and reports the **current snapshot of subject- and trial-level quality** based on the analysis-ready pupil files in `data/analysis_ready/`. It is written to be machine-readable and self-contained so that another LLM agent can use it without re-scanning the entire codebase.

---

## 1. Key Files and Artifacts

- **MATLAB preprocessing pipeline (raw → processed)**  
  - `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m`
  - Produces subject/task-level flat files in a separate processed directory outside this repo (see `CONFIG.output_dir` in the script).
  - Writes a **session-level data quality report** per subject/session:
    - `BAP_pupillometry_data_quality_report.csv`
    - `BAP_pupillometry_data_quality_detailed.txt`

- **R QC suite for merged/processed files**  
  - `01_data_preprocessing/r/QC_of_merged_files.R`
  - Works from merged flat CSVs in the external processed directory (`BAP_processed`), performing high-level QC on **trial and DDM-readiness**.

- **Analysis-ready in-repo pupil data (current snapshot)**  
  Located in `data/analysis_ready/`:
  - `bap_processed_pupil_flat.csv`  
    - **Per-sample** pupil data with quality metrics.
  - `bap_trial_level_pupil.csv`  
    - **Per-trial** summary of pupil quality and basic statistics.
  - `bap_processed_summary.csv`  
    - Run-level summary: samples, trials, has_data flags.
  - `bap_trialwise_pupil_features.csv`  
    - Trialwise features (tonic/phasic, etc.) merged with behavior.
  - `bap_ddm_ready.csv`  
    - DDM-ready trialwise dataset (behavior + pupil features).

The **pupil data quality statistics** below are based on `bap_trial_level_pupil.csv` (trial-level QC) and the definitions implemented in `BAP_Pupillometry_Pipeline.m` and `QC_of_merged_files.R`.

---

## 2. Trial Window and Quality Metrics

### 2.1 Trial window and phases

In `BAP_Pupillometry_Pipeline.m`, each trial is defined relative to the **squeeze onset** (handgrip onset). The full trial window is:

- **Start**: 3 s before squeeze onset (baseline)  
- **End**: 10.7 s after squeeze onset (corrected for the 8-phase paradigm)  

The script defines 8 phases:

- `ITI_Baseline` (−3.0 s to 0.0 s)
- `Squeeze` (0.0–3.0 s)
- `Post_Squeeze_Blank` (3.0–3.25 s)
- `Pre_Stimulus_Fixation` (3.25–3.75 s)
- `Stimulus` (3.75–4.45 s)
- `Post_Stimulus_Fixation` (4.45–4.70 s)
- `Response_Different` (4.70–7.70 s)
- `Confidence` (7.70–10.70 s)

(See `CONFIG.phases` and `create_correct_phase_labels` in `BAP_Pupillometry_Pipeline.m`.)

### 2.2 Sample-level validity

EyeLink sample-wise validity (e.g., track loss, blinks) is stored in `trial_valid`, and propagated to:

- `bap_processed_pupil_flat.csv`:
  - Columns: `sub`, `task`, `run`, `trial_index`, `trial_label`, `time`, `pupil`, `has_behavioral_data`, `baseline_quality`, `trial_quality`, `overall_quality`.
  - `trial_valid` itself is not explicitly exposed in this file, but the quality metrics below are derived from it during preprocessing.

### 2.3 Quality metrics (per trial)

In `BAP_Pupillometry_Pipeline.m`, for each trial:

- Let `trial_valid` be a Boolean vector indicating valid pupil samples within the trial window.
- Time is expressed as `trial_times_rel` relative to squeeze onset.

The script computes:

- **Baseline quality**  
  Proportion of valid samples in the 3 s pre-squeeze baseline:

  \[
  \text{baseline\_quality} = \text{mean}(trial\_valid[t \in [-3.0, 0.0)])
  \]

- **Trial (task) quality**  
  Proportion of valid samples in the 0–10.7 s task period:

  \[
  \text{trial\_quality} = \text{mean}(trial\_valid[t \in [0, 10.7]])
  \]

- **Overall quality**  
  Proportion of valid samples across the full trial window (baseline + task):

  \[
  \text{overall\_quality} = \text{mean}(trial\_valid[\text{full trial window}])
  \]

These three metrics are **constant per trial** and are replicated across its samples in the flat file, and summarized as single values per trial in `bap_trial_level_pupil.csv`.

---

## 3. Inclusion Thresholds for “Acceptable” Pupil Trials

### 3.1 Pipeline thresholds

From `BAP_Pupillometry_Pipeline.m`:

- **Minimum samples per trial**

  - `CONFIG.quality.min_samples_per_trial = 100`
  - Trials with fewer than 100 samples **are discarded** outright.

- **Minimum valid proportion per trial (overall)**

  - `CONFIG.quality.min_valid_proportion = 0.5`
  - `overall_quality` is computed as the mean of `trial_valid` over the entire trial window.
  - Trials with `overall_quality < 0.5` are **discarded**.

Implementation snippet (simplified paraphrase):

- If `sum(trial_mask) < min_samples_per_trial` → skip trial.  
- Compute `baseline_quality`, `trial_quality`, and `overall_quality`.  
- If `overall_quality < min_valid_proportion` → skip trial.  
- Otherwise, the trial is **retained**, and the quality metrics are saved.

### 3.2 “Acceptable” pupil trial definition

Thus, **within this project**:

- A **pupil trial is considered acceptable and kept** if:
  - It contains **≥ 100 samples** in the full trial window, **and**
  - At least **50% of those samples are valid** (`overall_quality ≥ 0.50`).

All subsequent analysis-ready pupil datasets in `data/analysis_ready/` (including `bap_trial_level_pupil.csv`) are downstream of this filter. That is, **trials failing these criteria are not present** in the analysis-ready files.

---

## 4. Additional QC Categorization in R

The R script `01_data_preprocessing/r/QC_of_merged_files.R` builds additional trial-level quality categorization, focusing on **DDM-readiness** and quality bands.

### 4.1 Trial-quality aggregation and DDM readiness

Within `qc4_ddm_readiness()` and `qc5_survival_analysis()` (sections near the bottom of the file), the code:

1. Aggregates merged pupil+behavior trials to one row per trial.  
2. Brings forward:
   - `baseline_quality`
   - `trial_quality`
   - `overall_quality`
   - A Boolean flag `has_complete_phases` (e.g., `ITI_Baseline`, `Squeeze`, `Stimulus`, `Response_Different` present).
   - RT (`rt`) and accuracy (`accuracy`).

3. Defines a **DDM-ready** trial (`ddm_success`) as:

   - Non-missing RT and accuracy.
   - `has_complete_phases` is `TRUE`.
   - `baseline_quality ≥ 0.5`.
   - `trial_quality ≥ 0.5`.

4. Defines a **quality_category** based on `overall_quality`:

- `overall_quality ≥ 0.80` → `"High"`
- `0.60 ≤ overall_quality < 0.80` → `"Medium"`
- `0.50 ≤ overall_quality < 0.60` → `"Low"` (still acceptable by the main pipeline, but flagged as lower quality for interpretability).

The script then produces:

- **Per subject/task summary**:  
  `total_trials`, `ddm_ready_trials`, `survival_rate`, mean baseline/trial quality, etc.
- **Overall survival**:  
  total DDM-ready trials, overall survival rate, survival rates by quality band.

This is a **post-hoc QC layer**; the **core acceptability filter** is still applied via `overall_quality ≥ 0.5` in the MATLAB pipeline.

---

## 5. Current Snapshot: Subject-Level Pupil Quality (Analysis-Ready Data)

The following summary is computed from the **current** `data/analysis_ready/bap_trial_level_pupil.csv` file in this repo. This file contains one row per pupil trial with:

- `sub`, `task`, `run`, `trial_index`, `trial_label`, `n_samples`, `mean_pupil`, `sd_pupil`, `baseline_quality`, `trial_quality`, `overall_quality`.

### 5.1 Dataset-level counts

- **Number of subjects with pupil data in this file**: **34**
- **Total number of pupil trials in this file**: **3,131**

(**Note**: These are trials that *have already passed* the `overall_quality ≥ 0.5` and `min_samples_per_trial ≥ 100` criteria.)

### 5.2 Trial-quality bands across all trials

Using the `overall_quality`-based categories defined above:

- **High quality**: `overall_quality ≥ 0.80`
- **Medium quality**: `0.60 ≤ overall_quality < 0.80`
- **Low (but acceptable)**: `0.50 ≤ overall_quality < 0.60`

The trial-wise proportions across the entire dataset are:

- **High-quality trials**: ~**65.6%**
- **Medium-quality trials**: ~**25.9%**
- **Low-quality (0.50–0.59) trials**: ~**8.5%**

All trials in this file are **“acceptable”** by the primary pipeline definition (`overall_quality ≥ 0.50`), but they differ in how far above that threshold they are.

### 5.3 Per-subject distribution of trial quality

For each subject, we computed:

- `n_trials`: number of trials in `bap_trial_level_pupil.csv`.
- `prop_high`: proportion of trials with `overall_quality ≥ 0.80`.
- `prop_med`: proportion of trials with `0.60 ≤ overall_quality < 0.80`.
- `prop_low`: proportion of trials with `0.50 ≤ overall_quality < 0.60`.

Summary of the **per-subject high-quality proportions** (`prop_high`):

- **Median** `prop_high` across subjects: ~**0.59**
- **Minimum** `prop_high`: **0.00** (subject with no “High” trials; all are Medium/Low but still ≥ 0.50).
- **Maximum** `prop_high`: **1.00** (subjects with all retained trials having overall_quality ≥ 0.80).

Illustrative examples (not exhaustive):

- **Subjects with very high-quality pupil data**:
  - BAP193: 55 trials, **100%** High-quality.
  - BAP194: 104 trials, **100%** High-quality.
  - BAP195: 84 trials, **100%** High-quality.
  - BAP186: 85 trials, ~**98.8%** High-quality.
  - BAP178: 178 trials, ~**91.6%** High-quality.

- **Subjects with mixed quality**:
  - BAP003: 91 trials; ~50.5% High, 41.8% Medium, 7.7% Low.
  - BAP106: 147 trials; ~55.8% High, 38.1% Medium, 6.1% Low.
  - BAP170: 50 trials; 52% High, 40% Medium, 8% Low.
  - BAP199: 146 trials; ~53.4% High, 30.1% Medium, 16.4% Low.

- **Subjects with more challenging pupil data**:
  - BAP144: 8 trials; 0% High, 25% Medium, 75% Low (all `overall_quality ∈ [0.5, 0.6)`).
  - BAP171: 41 trials; ~7.3% High, 53.7% Medium, 39.0% Low.
  - BAP184: 42 trials; ~4.8% High, 57.1% Medium, 38.1% Low.
  - BAP196: 48 trials; ~10.4% High, 58.3% Medium, 31.2% Low.
  - BAP180: 151 trials; ~18.5% High, 80.1% Medium, 1.3% Low.

Even for these more difficult subjects, **all reported trials still satisfy** the core acceptance rule (`overall_quality ≥ 0.5`); what differs is their positioning within the High/Medium/Low bands.

---

## 6. Relationship to DDM-Ready Trials

The **pupil-side QC** described above is the first gate. The **DDM-ready subset** then applies additional behavioral and coverage constraints (implemented in `QC_of_merged_files.R` and downstream modeling scripts):

- A trial is **DDM-ready** (`ddm_success = TRUE`) if:
  - `rt` and `accuracy` are non-missing,
  - The trial contains all necessary phases: at minimum `ITI_Baseline`, `Squeeze`, `Stimulus`, and `Response_Different`,
  - `baseline_quality ≥ 0.5` and `trial_quality ≥ 0.5`.

The dataset `data/analysis_ready/bap_ddm_ready.csv` further restricts to DDM-appropriate RTs and coding:

- Example filters (see modeling scripts such as `scripts/tonic_alpha_analysis.R`):
  - `rt >= 0.2` and `rt <= 3.0`.
  - Non-missing choice and choice/accuracy recoding.

Thus, for any future agent:

- **Acceptable pupil trials** = trials that passed `overall_quality ≥ 0.5` and `min_samples ≥ 100`; these are already reflected in `bap_trial_level_pupil.csv`.  
- **DDM-ready trials** = acceptable pupil trials **plus** behavior and phase completeness constraints; these are reflected in the merged QC outputs and `bap_ddm_ready.csv`.

---

## 7. How to Reproduce the Quality Statistics

To recompute or extend the current summaries, another agent can:

1. **Load the analysis-ready trial-level pupil file**:
   - `data/analysis_ready/bap_trial_level_pupil.csv`

2. **Compute per-trial quality category**:

   - If `overall_quality ≥ 0.80` → `High`
   - Else if `overall_quality ≥ 0.60` → `Medium`
   - Else (since file already filtered to `≥ 0.50`) → `Low`

3. **Compute per-subject stats**:

   - Group by `sub` (subject ID).
   - For each subject: count `n_trials`, `n_high`, `n_med`, `n_low`, and derive `prop_*`.

4. **Compute dataset-level stats**:

   - `n_subj = number of distinct sub`.
   - `total_trials = total row count`.
   - Overall proportion of each quality band across all rows.

No additional external files are required for these summaries beyond the CSVs in `data/analysis_ready/`.

---

## 8. Summary for Methods/Reporting

For convenience, here is a succinct prose summary that can be reused in methods or higher-level reports:

- Pupil data were processed using a custom MATLAB pipeline (`BAP_Pupillometry_Pipeline.m`) that defined an 8-phase trial structure around handgrip onset and stimulus presentation. For each trial, sample-wise validity (blinks, track loss) was used to compute baseline (−3 to 0 s), task (0–10.7 s), and overall pupil data quality as the proportion of valid samples. Trials with fewer than 100 samples or with less than 50% valid samples across the full window (`overall_quality < 0.50`) were excluded. The resulting analysis-ready dataset (`bap_trial_level_pupil.csv`) contained 3,131 trials from 34 participants, all of which met these minimum criteria. Within this set, 65.6% of trials were classified as “High” pupil quality (overall valid proportion ≥ 0.80), 25.9% as “Medium” (0.60–0.79), and 8.5% as “Low but acceptable” (0.50–0.59). Per-subject, the median fraction of “High” quality trials was approximately 0.59 (range 0–1), with several participants showing nearly all trials in the High band and a small number showing more mixed-quality data. DDM analyses further restricted to trials with complete behavioral data, complete trial phases, and baseline/trial quality ≥ 0.50 (see `QC_of_merged_files.R` and `bap_ddm_ready.csv`).




