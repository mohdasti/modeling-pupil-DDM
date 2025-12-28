# Fix: Regenerate Waveforms from Extended Flat Files

## Problem
The waveform file was generated from OLD flat files (ending at 4.7s) instead of NEW extended files (ending at 7.7s).

There are **230 old flat files** in the base `BAP_processed` directory and **113 new extended files** in `build_20251225_154443`. The script is finding the old files first.

## Solution

**Option 1: Temporarily point to latest build (RECOMMENDED)**

1. Edit `config/data_paths.yaml` and change `processed_dir` to point to the latest build:

```yaml
# Change this line:
processed_dir: "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"

# To this (point directly to the build directory):
processed_dir: "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/build_20251225_154443"
```

2. Delete the old waveform file:
```r
file.remove("quick_share_v7/analysis/pupil_waveforms_condition_mean.csv")
```

3. Regenerate waveforms:
```r
source("scripts/make_quick_share_v7.R")
```

4. **IMPORTANT:** After running, change `config/data_paths.yaml` back to:
```yaml
processed_dir: "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
```

---

**Option 2: Use a modified version (alternative)**

Run this in RStudio to regenerate using only the latest build:

```r
# Set path to latest build
LATEST_BUILD <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/build_20251225_154443"

# Delete old waveform file
if (file.exists("quick_share_v7/analysis/pupil_waveforms_condition_mean.csv")) {
  file.remove("quick_share_v7/analysis/pupil_waveforms_condition_mean.csv")
  cat("Deleted old waveform file\n")
}

# Temporarily modify the script to use only latest build
# (You'll need to edit make_quick_share_v7.R around line 682-687)
# Or use this workaround:
source("scripts/make_quick_share_v7.R")  # But first update config/data_paths.yaml as in Option 1
```

---

## Verification

After regenerating, verify the waveforms are extended:

```r
waveform <- readr::read_csv("quick_share_v7/analysis/pupil_waveforms_condition_mean.csv")
ch3 <- waveform[waveform$chapter == "ch3", ]
max(ch3$t_rel, na.rm = TRUE)
# Should be >= 7.65 (ideally ~7.7)
```

If it's still 4.7, the script is still using old files. Make sure `processed_dir` points to the build directory.

