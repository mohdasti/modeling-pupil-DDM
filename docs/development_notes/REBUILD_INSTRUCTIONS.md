# Rebuild Instructions: Running the Fixed Pipeline

This document provides step-by-step instructions to rebuild the analysis-ready datasets with the forensic fixes applied.

---

## Prerequisites

1. **MATLAB** (with required toolboxes)
2. **R** (with packages: `dplyr`, `readr`, `tidyr`, `purrr`, `stringr`)
3. **Quarto** (for rendering QMD files)

---

## Step 1: Run MATLAB Pipeline

**Purpose:** Process cleaned pupil data and create flat CSV files with `ses` column.

### File Location
```
01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m
```

### How to Run

**Option A: From MATLAB Command Window**
```matlab
% Navigate to the project directory
cd('/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM')

% Run the pipeline
BAP_Pupillometry_Pipeline()
```

**Option B: From MATLAB Script**
```matlab
% Create a run script: run_matlab_pipeline.m
% Then execute:
run('run_matlab_pipeline.m')
```

**Option C: From Terminal (if MATLAB command line available)**
```bash
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM
matlab -nodisplay -nosplash -r "BAP_Pupillometry_Pipeline(); exit"
```

### Expected Output
- **Location:** `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/`
- **Files:** `{subject}_{task}_flat.csv` (e.g., `BAP003_ADT_flat.csv`)
- **New Column:** Each file should now include a `ses` column with values 2 or 3

### Verification
After running, check one flat file:
```r
# In R
library(readr)
sample <- read_csv("/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/BAP003_ADT_flat.csv", n_max = 10)
print(names(sample))  # Should include "ses"
print(unique(sample$ses))  # Should show 2 or 3
print(unique(sample$run))  # Should show 1, 2, 3, 4, or 5
```

---

## Step 2: Run R Merger

**Purpose:** Merge pupil flat files with behavioral data, mapping `session_num` → `ses` and preserving `run`.

### File Location
```
01_data_preprocessing/r/Create merged flat file.R
```

### How to Run

**Option A: From R Console**
```r
# Set working directory
setwd("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")

# Source the script
source("01_data_preprocessing/r/Create merged flat file.R")
```

**Option B: From Terminal (Rscript)**
```bash
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM
Rscript "01_data_preprocessing/r/Create merged flat file.R"
```

**Option C: From RStudio**
- Open the file: `01_data_preprocessing/r/Create merged flat file.R`
- Click "Source" button or press `Ctrl+Shift+S` (Windows/Linux) or `Cmd+Shift+S` (Mac)

### Expected Output
- **Location:** `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/`
- **Files:** `{subject}_{task}_flat_merged.csv` (e.g., `BAP003_ADT_flat_merged.csv`)
- **New Columns:** Should include `ses` (from behavioral `session_num`) and preserve `run` from pupil files

### Verification
After running, check one merged file:
```r
# In R
library(readr)
sample <- read_csv("/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/BAP003_ADT_flat_merged.csv", n_max = 10)
print(names(sample))  # Should include "ses"
print(unique(sample$ses))  # Should show 2 or 3
print(unique(sample$run))  # Should show 1, 2, 3, 4, or 5
print(any(sample$run != sample$ses, na.rm = TRUE))  # Should be TRUE (run != ses)
```

---

## Step 3: Run QMD Report

**Purpose:** Generate final analysis-ready datasets (MERGED and TRIALLEVEL) with correct `ses` and `run` values.

### File Location
```
02_pupillometry_analysis/generate_pupil_data_report.qmd
```

### How to Run

**Option A: From Terminal (Quarto CLI)**
```bash
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM
quarto render "02_pupillometry_analysis/generate_pupil_data_report.qmd"
```

**Option B: From RStudio**
- Open the file: `02_pupillometry_analysis/generate_pupil_data_report.qmd`
- Click "Render" button or press `Ctrl+Shift+K` (Windows/Linux) or `Cmd+Shift+K` (Mac)

**Option C: From R Console**
```r
# Install quarto R package if needed
# install.packages("quarto")

# Render the QMD
quarto::quarto_render("02_pupillometry_analysis/generate_pupil_data_report.qmd")
```

### Expected Output
- **Location:** `data/analysis_ready/`
- **Files:**
  - `BAP_analysis_ready_MERGED.csv` (sample-level, ~4.8M rows)
  - `BAP_analysis_ready_TRIALLEVEL.csv` (trial-level, ~1,425 rows)
- **Columns:** Both should have `ses` (2 or 3) and `run` (1-5), with `run != ses`

### Verification
After rendering, verify the output:
```r
# In R
library(readr)

# Check MERGED
merged <- read_csv("data/analysis_ready/BAP_analysis_ready_MERGED.csv", n_max = 10000)
print("MERGED ses distribution:")
print(table(merged$ses, useNA = "ifany"))
print("MERGED run distribution:")
print(table(merged$run, useNA = "ifany"))
print("MERGED run != ses:", any(merged$run != merged$ses, na.rm = TRUE))

# Check TRIALLEVEL
triallevel <- read_csv("data/analysis_ready/BAP_analysis_ready_TRIALLEVEL.csv")
print("TRIALLEVEL ses distribution:")
print(table(triallevel$ses, useNA = "ifany"))
print("TRIALLEVEL run distribution:")
print(table(triallevel$run, useNA = "ifany"))
print("TRIALLEVEL run != ses:", any(triallevel$run != triallevel$ses, na.rm = TRUE))
```

---

## Step 4: Run Verification Script

**Purpose:** Verify that all fixes are working correctly.

### File Location
```
scripts/verify_forensic_fixes.R
```

### How to Run

**Option A: From Terminal (Rscript)**
```bash
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM
Rscript scripts/verify_forensic_fixes.R
```

**Option B: From R Console**
```r
setwd("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")
source("scripts/verify_forensic_fixes.R")
```

### Expected Output
- Console output showing:
  - ✓ ses column found in flat files
  - ✓ ses values are 2 or 3
  - ✓ run values are 1-5
  - ✓ run != ses (fix working!)
- **Files created:**
  - `data/qc/pipeline_forensics/final_verification_numbers.csv`
  - `data/qc/pipeline_forensics/final_verification.md`

---

## Complete Rebuild Sequence

Run all steps in order:

```bash
# Step 1: MATLAB Pipeline
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM
matlab -nodisplay -nosplash -r "cd('01_data_preprocessing/matlab'); BAP_Pupillometry_Pipeline(); exit"

# Step 2: R Merger
Rscript "01_data_preprocessing/r/Create merged flat file.R"

# Step 3: QMD Report
quarto render "02_pupillometry_analysis/generate_pupil_data_report.qmd"

# Step 4: Verification
Rscript scripts/verify_forensic_fixes.R
```

---

## Troubleshooting

### MATLAB Issues

**Problem:** MATLAB can't find the function
```matlab
% Solution: Make sure you're in the right directory
cd('/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM/01_data_preprocessing/matlab')
BAP_Pupillometry_Pipeline()
```

**Problem:** Output directory doesn't exist
```matlab
% The script should create it, but if not:
mkdir('/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed')
```

### R Merger Issues

**Problem:** Can't find behavioral file
```r
# Check if file exists:
file.exists("/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv")
# If FALSE, update the path in the script (line 11)
```

**Problem:** Missing R packages
```r
# Install required packages:
install.packages(c("dplyr", "readr", "tidyr", "purrr", "stringr"))
```

### QMD Issues

**Problem:** Quarto not found
```bash
# Install Quarto: https://quarto.org/docs/get-started/
# Or use RStudio which includes Quarto
```

**Problem:** QMD fails during rendering
```r
# Check for errors in the QMD file
# Common issues:
# - Missing data files
# - R package not installed
# - Path issues
```

---

## Quick Reference: File Paths

### Input Files
- **Cleaned pupil data:** `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned/*_cleaned.mat`
- **Raw pupil data:** `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data/sub-*/ses-*/InsideScanner/*_eyetrack.mat`
- **Behavioral data:** `/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv`

### Intermediate Files
- **Flat files:** `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/*_flat.csv`
- **Merged files:** `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/*_flat_merged.csv`

### Final Output Files
- **MERGED:** `data/analysis_ready/BAP_analysis_ready_MERGED.csv`
- **TRIALLEVEL:** `data/analysis_ready/BAP_analysis_ready_TRIALLEVEL.csv`

---

## Success Criteria

After completing all steps, verify:

1. ✓ Flat files have `ses` column (values 2 or 3)
2. ✓ Merged files have `ses` column (values 2 or 3) and `run` column (values 1-5)
3. ✓ MERGED has `ses` (2-3) and `run` (1-5), with `run != ses`
4. ✓ TRIALLEVEL has `ses` (2-3) and `run` (1-5), with `run != ses`
5. ✓ `trial_uid` includes `ses`: format `subject:task:ses:run:trial_index`
6. ✓ Verification script reports all checks passed

---

*Last updated: After forensic audit fixes*

