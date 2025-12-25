# Quick-Share v4: Merged Trial-Level Dataset + QC Bundle

## Overview

This directory contains the **v4 merged trial-level dataset** and **quick-share QC bundle** with proper behavioral merge and no double-counting.

## Files

### Merged Dataset
- **`merged/BAP_triallevel_merged.csv`** (2.4M)
  - One row per unique trial (`trial_uid`)
  - Contains: behavioral columns (rt, choice, correct, effort, intensity) + pupil QC + gate flags
  - **2,928 trials** have complete behavioral data (20.1% match rate)

### Quick-Share CSVs (8 files)
All counts use `n_distinct(trial_uid)` to prevent double-counting.

1. **`01_merge_diagnostics.csv`** - Match rates, unmatched key samples
2. **`02_trials_per_subject_task_ses.csv`** - Coverage by subject/task/session
3. **`03_condition_cell_counts.csv`** - Trials by condition (effort × intensity) with gate pass counts
4. **`04_run_level_counts.csv`** - QC metrics per run (median 30 trials/run)
5. **`05_window_validity_summary.csv`** - Window quality distributions by task/effort
6. **`06_gate_pass_rates_by_threshold.csv`** - Pass rates at 0.50/0.60/0.70
7. **`07_bias_checks_key_gates.csv`** - Bias analysis (effort/task effects)
8. **`08_trial_level_for_jitter.csv`** - Trial sequence data

### HTML Report
- **`../reports/slim_qc_report_v4.html`** - Slim Quarto report (no huge embedded data)

## Key Features

### ✅ Proper Merge
- Standardized keys: `sub`, `task`, `session_used`, `run_used`, `trial_index`
- Created `trial_uid = paste(sub, task, session_used, run_used, trial_index, sep=":")`
- Left join behavioral onto pupil data
- `has_behavioral_data` flag based on actual merge success (not hardcoded)

### ✅ Validation
- All trial_uids are unique
- Run integrity: median 30 trials per run (range: 20-30)
- Behavioral columns populated for matched trials: rt, choice, correct, intensity, effort

### ✅ No Double-Counting
- All trial counts use `n_distinct(trial_uid)`
- Condition cell counts are accurate
- Gate pass rates use correct denominators

## Match Rate

**Overall: 20.1%** (2,928 / 14,586 trials)

- **ADT**: 18.7% (1,407 / 7,530)
- **VDT**: 21.6% (1,521 / 7,056)

**Why low?** Many pupil trials have `trial_index > 30` (e.g., 31-48), which don't exist in behavioral data (which only has trials 1-30 per run). These are likely practice/extra trials in the pupil data.

## How to Regenerate

```bash
# Option 1: Makefile
make quick-share-v4

# Option 2: Direct R script
Rscript scripts/make_merged_quickshare_v4.R

# Option 3: Render report only
quarto render reports/slim_qc_report_v4.qmd
```

## Prerequisites

1. **Trial-level QC file**: `derived/triallevel_qc.csv`
   - Generate with: `Rscript R/quickshare_build_triallevel.R`

2. **Config file**: `config/data_paths.yaml`
   - Must specify `behavioral_csv` path

## Usage

The merged dataset (`BAP_triallevel_merged.csv`) is ready for analysis with:
- **2,928 trials** with complete behavioral + pupil data
- All behavioral columns populated (rt, choice, correct, effort, intensity)
- Pupil QC metrics (baseline_quality, cog_quality, overall_quality)
- Gate pass flags for thresholds 0.50, 0.60, 0.70

Filter to `has_behavioral_data == TRUE` for analysis-ready trials.

