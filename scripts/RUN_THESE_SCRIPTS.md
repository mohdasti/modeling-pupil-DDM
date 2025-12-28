# Scripts to Run for CH3 Extension

Run these scripts in RStudio **in order**:

## Step 1: Regenerate Waveform Summaries

```r
source("scripts/make_quick_share_v7.R")
```

**What it does:**
- Reads extended flat files from the MATLAB build directory
- Regenerates merged data, trial-level data, and waveform summaries
- Creates `quick_share_v7/analysis/pupil_waveforms_condition_mean.csv`

**Note:** This script searches recursively in `BAP_processed`, so it will find files in build directories automatically.

---

## Step 2: Window Selection Diagnostics

```r
source("scripts/ch3_window_selection_v2.R")
```

**What it does:**
- Verifies timing anchors (target onset, response start)
- Creates stimulus-locked waveform plots (by task, effort, oddball)
- Computes time-to-peak statistics within [0.3, 3.3]s post-target
- Analyzes window coverage for W2.0, W2.5, and W3.0 windows
- Generates window recommendation

**Outputs:**
- `quick_share_v7/qc/timing_sanity_summary.csv`
- `quick_share_v7/qc/ch3_time_to_peak_summary.csv`
- `quick_share_v7/qc/ch3_window_coverage.csv`
- `quick_share_v7/figs/ch3_waveform_by_task.png`
- `quick_share_v7/figs/ch3_waveform_by_effort.png`
- `quick_share_v7/figs/ch3_waveform_by_oddball.png`

---

## Step 3: STOP/GO Checks

```r
source("scripts/ch3_stopgo_checks.R")
```

**What it does:**
- Verifies waveform extension (>=7.65s from squeeze onset)
- Checks time-to-peak summary exists and is non-empty
- Validates window coverage (W2.0, W2.5, W3.0)
- Checks timing sanity (target onset near 4.35s)

**Outputs:**
- `quick_share_v7/qc/STOP_GO_ch3_extension.csv`

**Expected result:** All checks should be "GO" status.

---

## Quick Verification

After running all scripts, check:

1. **Waveform extension:**
   ```r
   waveform <- readr::read_csv("quick_share_v7/analysis/pupil_waveforms_condition_mean.csv")
   max(waveform$t_rel[waveform$chapter == "ch3"], na.rm = TRUE)
   # Should be >= 7.65
   ```

2. **STOP/GO status:**
   ```r
   stopgo <- data.table::fread("quick_share_v7/qc/STOP_GO_ch3_extension.csv")
   View(stopgo)
   # All should be "GO"
   ```

3. **Time-to-peak summary:**
   ```r
   peaks <- data.table::fread("quick_share_v7/qc/ch3_time_to_peak_summary.csv")
   nrow(peaks)  # Should be > 0
   ```

---

## Troubleshooting

- **"No flat CSV files found"**: Check that `config/data_paths.yaml` has `processed_dir` pointing to `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed` (it searches recursively)

- **"Waveform file not found"**: Run Step 1 first

- **STOP status in checks**: Check the specific failure message in `STOP_GO_ch3_extension.csv`

