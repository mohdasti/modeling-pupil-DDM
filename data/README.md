# Data Directory Structure

This directory contains the data files used by the DDM-Pupil modeling pipeline.

## Required Files

### For Feature Extraction
- `raw/trials_with_eyetracking.csv` - Raw eyetracking trial data with columns:
  - `pupil` - Raw pupil diameter
  - `time_ms` - Time in milliseconds relative to trial start
  - `trial_id` - Unique trial identifier
  - `stim_on_ms` - Stimulus onset time
  - `luminance` - Screen luminance value
  - `blink_flag` - 0/1 flag for blink samples
  - `subj` - Subject identifier
  - `condition` - Experimental condition

### For Behavioral Data
- `raw/behavior.csv` - Behavioral trial data with columns:
  - `trial_id` - Unique trial identifier (must match eyetracking)
  - `rt` - Reaction time in seconds
  - `choice` - Binary choice (0/1)
  - `prev_choice` - Previous trial choice
  - `prev_outcome` - Previous trial outcome

### For Analysis
- `analysis_ready/bap_clean_pupil.csv` - Final analysis-ready dataset with:
  - All behavioral variables
  - Pupil features (baseline, evoked, tonic, phasic)
  - Subject and trial metadata

## How to Obtain These Files

### Option 1: Run Preprocessing Pipeline

If you have raw .mat files from `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned`:

1. **MATLAB preprocessing** (recommended):
   ```matlab
   cd 01_data_preprocessing/matlab
   BAP_Pupillometry_Pipeline
   ```

2. **R preprocessing pipeline**:
   ```bash
   cd 01_data_preprocessing/r
   Rscript BAP_Complete_Pipeline_Automated.R
   ```

3. **Python preprocessing**:
   ```bash
   cd 01_data_preprocessing/python
   python create_flat_files_interactive.py
   ```

### Option 2: Use Existing Processed Data

If you already have processed CSV files, copy them to:
- Eyetracking data → `data/raw/trials_with_eyetracking.csv`
- Behavioral data → `data/raw/behavior.csv`
- Final dataset → `data/analysis_ready/bap_clean_pupil.csv`

### Option 3: Use the Pipeline in Demo Mode

The pipeline will check for required files and provide helpful error messages if they're missing.

## Directory Structure

```
data/
├── raw/                      # Raw input files
│   ├── trials_with_eyetracking.csv
│   └── behavior.csv
├── derived/                  # Intermediate processed files
│   └── trials_with_pupil.csv
└── analysis_ready/           # Final analysis-ready dataset
    └── bap_clean_pupil.csv
```

## File Preparation Commands

```bash
# Set up data directory structure
make setup-data

# Check if required files exist
ls -lh data/raw/ data/analysis_ready/

# Run the pipeline
make all
```
