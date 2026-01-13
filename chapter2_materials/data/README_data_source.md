# Processed Pupil Data: Fixed Baseline Alignment + Robust AUC

**Location:** `data/pupil_processed/` (formerly `quick_share_v7/`)  
**Generated:** See file timestamps  
**Purpose:** Clean trial-level merged dataset with corrected baseline alignment and improved AUC coverage

---

## What Changed from v6

### Key Fixes

1. **B0 Baseline Alignment Fixed**
   - **v6 Problem:** B0 baseline was misaligned, causing ~11-15% AUC availability
   - **v7 Fix:** B0 baseline now correctly uses `[-0.5, 0.0)` seconds relative to **squeeze onset** (not ITI baseline)
   - **Result:** Expected AUC availability >= 40% per task

2. **Label-Based Timing Anchor**
   - **v6:** Relied on PTB timestamps (often missing) or fixed defaults
   - **v7:** Infers squeeze onset from `trial_label` transitions:
     - First tries explicit squeeze labels ("Squeeze", "Handgrip", "Grip")
     - Falls back to ITI → non-ITI transition
     - Last resort: minimum time in trial
   - **Result:** More robust timing anchor detection

3. **Time Unit Inference**
   - Automatically detects if time is in seconds or milliseconds
   - Converts milliseconds to seconds when needed
   - Records inferred unit in QC outputs

4. **Deduplication Guarantees**
   - All outputs guaranteed unique by `trial_uid`
   - Assertions stop pipeline if duplicates detected
   - Priority-based deduplication (best timing anchor wins)

---

## Directory Structure

```
data/pupil_processed/
├── merged/
│   └── BAP_triallevel_merged_v4.csv          # Full trial-level merge (behavior + pupil QC + AUC)
├── analysis/
│   ├── ch2_analysis_ready_with_auc.csv       # Chapter 2 analysis-ready (behavior + pupil + AUC)
│   ├── ch3_ddm_ready_with_auc.csv           # Chapter 3 DDM-ready (behavior + pupil + AUC)
│   └── pupil_waveforms_condition_mean.csv    # Condition-mean waveforms (ch2 50Hz + ch3 250Hz)
├── qc/
│   ├── 01_join_health_by_subject_task.csv    # Behavioral join coverage
│   ├── 02_gate_pass_rates_by_task_threshold.csv  # Gate pass rates
│   ├── 03_auc_missingness_reasons.csv        # AUC missingness breakdown
│   └── 04_timing_event_time_coverage.csv      # Timing anchor inference stats
└── README_quick_share_v7.md                  # Documentation (legacy name)
```

---

## Key Identifiers

**Trial-level key:** `trial_uid = paste(sub, task, session_used, run_used, trial_index, sep = "|")`

- `sub`: Subject ID (e.g., "BAP170")
- `task`: "ADT" or "VDT"
- `session_used`: 2 or 3 (scanner sessions only)
- `run_used`: 1-5 (run within session)
- `trial_index`: 1-30 (trial within run)

**All outputs are guaranteed unique by `trial_uid`** (assertions stop pipeline if duplicates found).

---

## AUC Definitions (v7)

### Baselines

- **B0 (pre-trial baseline):** 500 ms window immediately **before squeeze onset**
  - Window: `t_rel in [-0.5, 0.0)` seconds
  - Used for: Full-trial baseline correction (Total AUC)
  
- **b0 (pre-target baseline):** 500 ms window immediately **before target onset**
  - Window: `t_rel in [4.35 - 0.5, 4.35)` = `[3.85, 4.35)` seconds
  - Used for: Target-locked baseline correction (Cognitive AUC)

**Validity rule:** Each baseline requires >= 10 valid (non-NA) pupil samples.

### AUC Metrics

- **Total AUC:** Integrate **B0-corrected** waveform from trial onset (0.0) to response start (4.70s)
- **Cognitive AUC:** Integrate **b0-corrected** waveform from (target_onset + 0.3s) to response start
  - Window: `[4.35 + 0.3, 4.70]` = `[4.65, 4.70]` seconds

### Timing

- **Target onset:** Fixed at 4.35s (relative to squeeze onset)
- **Response start:** Fixed at 4.70s (relative to squeeze onset)
- **Timing source:** `"fixed_design"` (no per-trial jitter)

---

## Recommended Columns for Modeling

### Chapter 2 (Psychometric + Pupil)

**Behavioral:**
- `effort`: Force condition (Low/High)
- `stimulus_intensity`: Stimulus level (numeric)
- `isOddball`: 0 = Standard, 1 = Oddball
- `choice_num`: 0 = SAME, 1 = DIFFERENT
- `choice_label`: "SAME" / "DIFFERENT"
- `rt`: Reaction time (seconds)
- `correct_final`: Computed correctness

**Pupil:**
- `total_auc`: Total AUC (B0-corrected, 0 to 4.70s)
- `cog_auc`: Cognitive AUC (b0-corrected, 4.65 to 4.70s) - **PRIMARY METRIC FOR ANALYSES**
- `auc_available`: TRUE if both AUCs computed
- `n_valid_B0`, `n_valid_b0`: Baseline valid sample counts

**QC (Standard):**
- `baseline_quality`, `cog_quality`: Window validity metrics
- `gate_pupil_primary`: Primary gate (B1_quality >= 0.50 AND cog_quality >= 0.60)

**QC (Gap-Aware - NEW as of January 2026):**
- `cog_auc_n_valid`: Number of valid samples in cognitive window
- `cog_window_duration`: Cognitive window duration (seconds, determined by RT)
- `cog_auc_prop_valid`: Proportion of valid samples
- `cog_auc_max_gap_ms`: Maximum contiguous missing segment (ms) - **KEY FOR FILTERING**
- `cog_auc_n_segments`: Number of contiguous valid segments (1 = continuous, >1 = fragmented)

**See `docs/FILTERING_GUIDE.md` for how to use gap-aware metrics to filter problematic trials.**

### Chapter 3 (DDM)

**Behavioral:**
- `choice_num`: 0 = SAME, 1 = DIFFERENT (DDM choice)
- `rt`: Reaction time (seconds) - filtered to [0.2, 3.0]
- `stimulus_intensity`: Stimulus level
- `isOddball`: 0 = Standard, 1 = Oddball

**Pupil (covariates):**
- `total_auc`: Total AUC
- `cog_auc`: Cognitive AUC
- `baseline_quality`, `cog_quality`: Quality metrics

**QC:**
- `auc_available`: TRUE if both AUCs computed
- `baseline_quality >= 0.50`: DDM-ready gate

---

## Acceptance Criteria (v7)

- ✅ **Unique trial_uid:** All outputs have no duplicates
- ✅ **Behavioral join rate:** ~87% or better
- ✅ **AUC availability:** >= 40% per task (improved from ~11-15% in v6)
- ✅ **Baseline alignment:** B0 uses correct window `[-0.5, 0.0)` relative to squeeze onset
- ✅ **Timing anchor:** >90% trials have valid timing anchor from labels

---

## Regeneration

To regenerate all v7 outputs:

```bash
Rscript scripts/make_quick_share_v7.R
```

**Prerequisites:**
- `quick_share_v6/merged/BAP_triallevel_merged_v3.csv` (or provide merged trial file)
- Flat CSV files in `BAP_processed/` (or path in `config/data_paths.yaml`)
- Behavioral file: `bap_beh_trialdata_v2.csv` (or path in config)

**Expected runtime:** 10-20 minutes (depends on number of flat files)

---

## Troubleshooting

**AUC availability still < 40%:**
- Check `qc/03_auc_missingness_reasons.csv` for top reasons
- Verify baseline windows contain >= 10 valid samples
- Check timing anchor inference rate in `qc/04_timing_event_time_coverage.csv`

**Duplicate trial_uid errors:**
- Pipeline stops automatically if duplicates found
- Check source files for duplicate trial keys
- Verify deduplication logic in STEP 2

**Timing anchor not found:**
- Check if `trial_label` column exists in flat files
- Verify label naming matches expected patterns
- Review `qc/04_timing_event_time_coverage.csv` for inference rates

---

## Notes

- All trial counts use **distinct trial_uid** (no double-counting)
- Session 1 and practice trials are excluded (session_used ∈ {2, 3})
- Timing is fixed relative to squeeze onset (no per-trial jitter)
- Waveforms are condition means only (not per-trial timecourses)

