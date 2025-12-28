# Quick Start: Rebuild Pipeline with Critical Fixes

**Status:** ✅ All critical MATLAB fixes applied  
**Next:** Run the pipeline in order

---

## Commands to Run (Copy/Paste)

### 1. MATLAB Pipeline

**From MATLAB:**
```matlab
cd('/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM/01_data_preprocessing/matlab')
BAP_Pupillometry_Pipeline()
```

**Or from Terminal:**
```bash
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM
matlab -nodisplay -nosplash -r "cd('01_data_preprocessing/matlab'); BAP_Pupillometry_Pipeline(); exit"
```

**Expected Output:**
- Flat files in: `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/`
- Files: `{subject}_{task}_flat.csv` (e.g., `BAP003_ADT_flat.csv`)
- **New columns:** `ses`, `trial_in_run_raw`, `qc_fail_baseline`, `qc_fail_overall`
- QC summaries: `qc_matlab_trial_yield_summary.csv`, `qc_matlab_session_yield_summary.csv`

---

### 2. R Merger

**From Terminal:**
```bash
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM
Rscript "01_data_preprocessing/r/Create merged flat file.R"
```

**Or from R:**
```r
setwd("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")
source("01_data_preprocessing/r/Create merged flat file.R")
```

**Expected Output:**
- Merged files in: `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/`
- Files: `{subject}_{task}_flat_merged.csv`
- **Should have:** `ses` (2 or 3), `run` (1-5), correct alignment with behavioral

---

### 3. QMD Report

**From Terminal:**
```bash
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM
quarto render "02_pupillometry_analysis/generate_pupil_data_report.qmd"
```

**Or from RStudio:**
- Open `02_pupillometry_analysis/generate_pupil_data_report.qmd`
- Click "Render"

**Expected Output:**
- `data/analysis_ready/BAP_analysis_ready_MERGED.csv`
- `data/analysis_ready/BAP_analysis_ready_TRIALLEVEL.csv`
- **Should have:** `ses` (2-3), `run` (1-5), `run != ses`

---

### 4. Verification

**From Terminal:**
```bash
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM
Rscript scripts/verify_forensic_fixes.R
```

**Expected:**
- ✓ All checks pass
- Reports saved to `data/qc/pipeline_forensics/`

---

## Quick Verification (After Each Step)

### After MATLAB:
```r
# In R
library(readr)
sample <- read_csv("/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/BAP003_ADT_flat.csv", n_max = 100)
print(names(sample))  # Should include: ses, trial_in_run_raw, qc_fail_baseline, qc_fail_overall
print(unique(sample$trial_in_run_raw))  # Should be 1..30 for each run
```

### After R Merger:
```r
# In R
sample <- read_csv("/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/BAP003_ADT_flat_merged.csv", n_max = 100)
print(unique(sample$ses))  # Should be 2 or 3
print(unique(sample$run))  # Should be 1, 2, 3, 4, or 5
print(any(sample$run != sample$ses, na.rm = TRUE))  # Should be TRUE
```

### After QMD:
```r
# In R
triallevel <- read_csv("data/analysis_ready/BAP_analysis_ready_TRIALLEVEL.csv")
print(table(triallevel$ses))  # Should show only 2 and 3
print(table(triallevel$run))  # Should show 1, 2, 3, 4, 5
print(any(triallevel$run != triallevel$ses, na.rm = TRUE))  # Should be TRUE
```

---

## All-in-One Script

**Use the shell script:**
```bash
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM
./run_pipeline.sh
```

This runs all steps in sequence (may require manual intervention for MATLAB).

---

*Quick start guide - see REBUILD_INSTRUCTIONS.md for detailed instructions*

