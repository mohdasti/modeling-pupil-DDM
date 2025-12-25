# Quick-Share v6: AUC Features + Waveform Summaries

**Generated:** See file timestamps  
**Purpose:** Compact, shareable QC and analysis-ready datasets for dissertation Chapters 2 and 3

---

## Directory Structure

```
quick_share_v6/
├── merged/
│   └── BAP_triallevel_merged_v3.csv          # Full trial-level merge (behavior + pupil QC + AUC)
├── analysis/
│   ├── ch2_analysis_ready_with_auc.csv        # Chapter 2 analysis-ready (behavior + pupil + AUC)
│   ├── ch3_ddm_ready_with_auc.csv            # Chapter 3 DDM-ready (behavior + pupil + AUC)
│   └── pupil_auc_trial_level.csv             # Intermediate: AUC features only
├── waveforms/
│   ├── pupil_waveforms_condition_mean_ch2_50hz.csv   # Ch2 condition-mean waveforms (50 Hz)
│   └── pupil_waveforms_condition_mean_ch3_250hz.csv  # Ch3 condition-mean waveforms (250 Hz)
├── qc/
│   ├── auc_missingness_reasons.csv           # Counts by missingness reason
│   ├── auc_missingness_by_condition.csv       # Missingness rates by task/effort/isOddball
│   ├── timing_event_time_coverage.csv         # PTB vs default timing coverage
│   └── gate_pass_rates_overview.csv           # Pass rates at thresholds 0.50/0.60/0.70
├── figs/
│   ├── gate_pass_rates_overview.png
│   ├── auc_distributions.png
│   ├── waveform_panels_ch2.png
│   └── waveform_panels_ch3.png
└── README_quick_share_v6.md                   # This file
```

---

## Key Identifiers

**Trial-level key:** `(sub, task, session_used, run_used, trial_index)`

- `sub`: Subject ID (e.g., "BAP170")
- `task`: "ADT" or "VDT"
- `session_used`: 2 or 3 (scanner sessions only)
- `run_used`: 1-5 (run within session)
- `trial_index`: 1-30 (trial within run)

**Derived key:** `trial_uid = paste(sub, task, session_used, run_used, trial_index, sep = ":")`

---

## AUC Definitions

### Total AUC

- **Baseline B0:** 500 ms immediately pre-trial-onset (`[-0.5, 0]` seconds relative to squeeze onset)
- **Baseline correction:** `pupil_bc = pupil - mean(pupil in B0)`
- **Integration window:** From trial onset (`0`) to response-window start (`respwin_start`)
- **Exclusion rule:** Exclude if B0 has <10 valid samples

### Cognitive AUC

- **Baseline B1:** 500 ms immediately pre-target/probe onset (`[target_onset - 0.5, target_onset]`)
- **Baseline correction:** `pupil_bc_target = pupil - mean(pupil in B1)`
- **Integration window:** From `(target_onset + 0.300 s)` to response-window start
- **Exclusion rule:** Exclude if B1 has <10 valid samples OR if integration window is non-positive

### Additional Metrics

- `cog_mean_fixed1s`: Mean baseline-corrected pupil in cognitive window (target_onset + 0.3s to target_onset + 1.3s)
- `cog_auc_respwin`: Cognitive AUC integrated to response-window start (if different from fixed 1s window)

---

## Event Timing

**Preferred:** PTB-derived event timestamps (if available in flat files):
- `trial_start_time_ptb`
- `target_onset_time_ptb`
- `resp1_start_time_ptb` (or `resp1ST`)

**Fallback:** Fixed design offsets (documented in `timing_event_time_coverage.csv`):
- `target_onset = 4.35` seconds (relative to trial onset)
- `respwin_start = 4.70` seconds (relative to trial onset)

The `timing_source` column in AUC features indicates "ptb" vs "default".

---

## Recommended Columns for Modeling

### Chapter 2 (Psychometric + Pupil)

**Behavioral:**
- `effort`: Force condition (Low/High or equivalent)
- `stimulus_intensity`: Stimulus level (numeric)
- `isOddball`: 0 = Standard, 1 = Oddball
- `choice_num`: 0 = SAME, 1 = DIFFERENT
- `choice_label`: "SAME" / "DIFFERENT"
- `rt`: Reaction time (seconds)
- `correct_final`: Computed correctness (use this, not legacy `correct`)

**Pupil:**
- `total_auc`: Total AUC (baseline-corrected, 0 to respwin_start)
- `cog_auc_fixed1s`: Cognitive AUC (target-locked baseline-corrected)
- `cog_mean_fixed1s`: Cognitive mean (optional)

**QC:**
- `auc_available`: TRUE if both total_auc and cog_auc_fixed1s are present
- `b0_n_valid`: Number of valid samples in B0 baseline
- `b1_n_valid`: Number of valid samples in B1 baseline
- `pass_primary_060`: Primary gate pass at threshold 0.60 (baseline≥0.60 & cog≥0.60)

### Chapter 3 (DDM)

**Behavioral:**
- `choice_num`: 0 = SAME, 1 = DIFFERENT (use as DDM choice)
- `rt`: Reaction time (seconds) - already filtered to [0.2, 3.0] in ch3_ddm_ready
- `stimulus_intensity`: Stimulus level (numeric)
- `isOddball`: 0 = Standard, 1 = Oddball

**Pupil (covariates):**
- `total_auc`: Total AUC
- `cog_auc_fixed1s`: Cognitive AUC
- `cog_mean_fixed1s`: Cognitive mean (optional)

**QC:**
- `auc_available`: TRUE if both AUCs present
- `b0_n_valid`, `b1_n_valid`: Baseline valid sample counts
- `ch3_ddm_ready`: DDM-ready flag (RT filter + minimal pupil tier)

---

## Quality Gates

**Primary gate (Ch2):** `baseline_quality >= threshold & cog_quality >= threshold`
- Thresholds: 0.50, 0.60, 0.70
- Columns: `pass_primary_050`, `pass_primary_060`, `pass_primary_070`

**AUC-ready gate:** `auc_available == TRUE`
- Requires: B0 ≥10 valid samples AND B1 ≥10 valid samples AND both AUCs computed

**DDM-ready gate (Ch3):** `ch3_ddm_ready == TRUE`
- Requires: RT in [0.2, 3.0] AND baseline_quality ≥0.50 AND cog_quality ≥0.50

---

## Waveform Files

**Format:** Condition-mean timecourses (one row per timepoint × condition)

**Columns:**
- `task`: "ADT" or "VDT"
- `effort`: Force condition (Low/High/Unknown)
- `isOddball`: 0 or 1
- `t`: Time relative to squeeze onset (seconds)
- `mean_pupil`: Mean baseline-corrected pupil across trials
- `sem_pupil`: Standard error of the mean
- `n_trials`: Number of trials contributing to this mean

**Time range:** From -0.5 seconds to response-window start (typically ~4.7s)

**Sampling:**
- Ch2: 50 Hz (downsampled for plotting)
- Ch3: 250 Hz (native rate)

**Baseline correction:** Full-trial baseline (B0: [-0.5, 0] seconds)

---

## Usage

### Load analysis-ready datasets:

```r
library(readr)
ch2 <- read_csv("quick_share_v6/analysis/ch2_analysis_ready_with_auc.csv")
ch3 <- read_csv("quick_share_v6/analysis/ch3_ddm_ready_with_auc.csv")
```

### Filter to AUC-ready trials:

```r
ch2_auc <- ch2 %>% filter(auc_available)
ch3_auc <- ch3 %>% filter(auc_available)
```

### Load waveforms for plotting:

```r
waveforms_ch2 <- read_csv("quick_share_v6/waveforms/pupil_waveforms_condition_mean_ch2_50hz.csv")
waveforms_ch3 <- read_csv("quick_share_v6/waveforms/pupil_waveforms_condition_mean_ch3_250hz.csv")
```

---

## Regeneration

To regenerate all v6 outputs:

```bash
Rscript scripts/make_quick_share_v6.R
```

**Prerequisites:**
- `quick_share_v5/analysis/ch2_analysis_ready.csv`
- `quick_share_v5/analysis/ch3_ddm_ready.csv`
- `quick_share_v4/merged/BAP_triallevel_merged_v2.csv`
- Flat CSV files in `BAP_processed/` (or path specified in `config/data_paths.yaml`)

**Expected runtime:** 10-20 minutes (depends on number of flat files)

---

## Notes

- All trial counts use **distinct trial keys** (no double-counting)
- Session 1 and practice trials are excluded (session_used ∈ {2, 3})
- Behavioral join rate is typically ~87% (see QC tables for details)
- AUC availability depends on baseline valid sample requirements (≥10 samples each)
- Event timing uses PTB timestamps when available; otherwise defaults to fixed offsets (4.35s/4.7s)
