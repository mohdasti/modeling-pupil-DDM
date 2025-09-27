# BAP Eye Tracking Data Processing Tool

This interactive script automatically processes BAP eye tracking data with downsampling and behavioral data merging.

## Prerequisites

1. **Python packages required:**
   ```bash
   pip install pandas numpy scipy
   ```

2. **Required files in the directory:**
   - Cleaned eye tracking `.mat` files (e.g., `subjectBAP178_Aoddball_session2_run1_8_9_14_37_eyetrack_cleaned.mat`)
   - Behavioral data file: `bap_trial_data_grip_type1.csv`

## How to Use

1. **Place your files in the directory:**
   - Put all cleaned `.mat` files for the subjects you want to process
   - Ensure the behavioral data file `bap_trial_data_grip_type1.csv` is present

2. **Run the script:**
   ```bash
   python create_flat_files_interactive.py
   ```

3. **Follow the prompts:**
   - The script will automatically detect all available subjects and their files
   - It will show you a list of subjects with the number of ADT and VDT runs for each
   - Select the subject you want to process by entering the corresponding number

4. **Wait for processing:**
   - The script will automatically:
     - Downsample data from 2000 Hz to 250 Hz
     - Merge behavioral data with eye tracking data
     - Create trial labels and duration indices
     - Save output files with the format: `BAP{ID}_{TASK}_DS250.csv`

## Output Files

For each processed subject, you'll get:
- `BAP{ID}_ADT_DS250.csv` - Auditory Discrimination Task data
- `BAP{ID}_VDT_DS250.csv` - Visual Discrimination Task data

## File Structure

Each output file contains:
- **Eye tracking data:** `pupil`, `time`, `trial_index`, `run_index`, `session_index`
- **Trial phases:** `duration_index`, `trial_label` (baseline, fixation, squeeze, blank, response)
- **Behavioral data:** All relevant columns from the behavioral file including:
  - `sub`, `mvc`, `ses`, `task`, `run`, `trial`
  - `stimLev`, `isOddball`, `isStrength`, `iscorr`
  - `resp1`, `resp1RT`, `resp2`, `resp2RT`
  - `auc_rel_mvc`, `resp1_isdiff`

## Example Usage

```
BAP Eye Tracking Data Processing Tool
==================================================
Detecting available subjects and files...

============================================================
AVAILABLE SUBJECTS
============================================================
 1. BAP178 - ADT: 5 runs, VDT: 5 runs
 2. BAP179 - ADT: 4 runs, VDT: 3 runs
============================================================

Select subject (1-2): 1

Selected: BAP178

Processing BAP178...
Found 200 behavioral trials

Processing ADT...
  Found 5 files
  Behavioral trials: 100
  Processing session 2, run 1: subjectBAP178_Aoddball_session2_run1_8_9_14_37_eyetrack_cleaned.mat
    Original data: 120000 samples at 2000 Hz
    Downsampled data: 15000 samples at 250 Hz
    Estimated 150 samples per trial
  ...
  Saved BAP178_ADT_DS250.csv
  Total trials: 100
  Total samples: 15000
```

## Features

- **Automatic detection:** No need to manually specify file names
- **Interactive selection:** Easy subject selection from available options
- **Automatic downsampling:** Reduces file size while preserving data quality
- **Behavioral data merging:** Combines eye tracking with trial-level behavioral data
- **Trial phase labeling:** Creates meaningful labels for different trial phases
- **Comprehensive output:** Includes all relevant behavioral variables

## Troubleshooting

- **No subjects found:** Ensure your `.mat` files follow the naming convention: `subjectBAP{ID}_{TASK}_session{SES}_run{RUN}_eyetrack_cleaned.mat`
- **No behavioral data:** Make sure `bap_trial_data_grip_type1.csv` is in the same directory
- **Memory issues:** For very large datasets, consider processing one task at a time 