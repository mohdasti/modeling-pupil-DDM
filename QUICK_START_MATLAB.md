# Quick Start: Run MATLAB Pipeline

## ⚙️ FIRST-TIME SETUP: Configure Paths

Before running the pipeline for the first time, configure paths:

1. **Copy config template** (if you want custom paths):
   ```bash
   cp config/paths_config.m.example config/paths_config.m
   ```

2. **Edit paths** (optional - pipeline will use relative paths if config not found):
   ```matlab
   % Edit config/paths_config.m and update:
   % - CONFIG.cleaned_dir (where cleaned .mat files are)
   % - CONFIG.raw_dir (where raw eyetrack.mat and logP.txt files are)
   % - CONFIG.output_dir (where outputs will be saved)
   ```

   **OR** use relative paths (default):
   - Pipeline automatically uses `data/BAP_cleaned/`, `data/raw/`, `data/BAP_processed/`
   - Relative to repository root

## 🚀 RUN THE PIPELINE

### Method 1: MATLAB GUI (Recommended)

1. **Open MATLAB** (from Applications or Spotlight)

2. **Navigate to project directory**:
   ```matlab
   cd('path/to/modeling-pupil-DDM')
   ```

3. **Run the pipeline**:
   ```matlab
   addpath('01_data_preprocessing/matlab')
   BAP_Pupillometry_Pipeline()
   ```

4. **Wait for completion** (~1-2 hours for all subjects)

5. **Verify fixes worked** (see below)

---

## ✅ VERIFY FIXES APPLIED

After pipeline completes, check a sample file:

```r
library(readr)
library(dplyr)

# Check BAP003_ADT as example
df <- read_csv('/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/BAP003_ADT_flat.csv', 
               n_max=10000, show_col_types=FALSE)

cat('=== VERIFICATION ===\n')
cat('Zero values:', sum(df$pupil == 0, na.rm=TRUE), '(should be 0)\n')
cat('NaN values:', sum(is.na(df$pupil)), '(should be > 0)\n')
cat('Has trial_in_run:', 'trial_in_run' %in% names(df), '(should be TRUE)\n')
if('trial_in_run' %in% names(df)) {
  cat('trial_in_run values:', paste(head(unique(df$trial_in_run), 5), collapse=', '), '...\n')
}
```

**Expected Results**:
- ✅ Zero values: **0** (all converted to NaN)
- ✅ NaN values: **> 0** (zeros converted)
- ✅ Has trial_in_run: **TRUE**
- ✅ trial_in_run: **Sequential (1, 2, 3...)**

---

## 📊 WHAT THE PIPELINE DOES

The pipeline processes all cleaned `.mat` files and generates flat CSV files with:

1. **Contamination filtering** - Excludes OutsideScanner, practice runs, session 1
2. **Dual-mode segmentation** - Event-code segmentation with logP fallback
3. **Zero-to-NaN conversion** - All zeros converted to NaN
4. **trial_in_run_raw tracking** - Preserves original trial indices for merging
5. **Anti-aliasing filter** - 8th-order Butterworth before downsampling
6. **Comprehensive QC** - Generates falsification metrics and excluded files log

### Output Files

**Flat CSV files**: `data/BAP_processed/build_*/[SUBJECT]_[TASK]_flat.csv`

**QC files** (in `build_*/qc_matlab/`):
- `qc_matlab_run_trial_counts.csv` - Run-level statistics
- `qc_matlab_falsification_by_run.csv` - Alignment metrics (residuals, timing errors)
- `qc_matlab_excluded_files.csv` - Log of excluded files with reasons
- `qc_matlab_inferred_session_files.csv` - Files with inferred sessions
- `qc_matlab_trial_level_flags.csv` - Trial-level QC flags
- `falsification_validation_summary.md` - Validation report

---

## ⏱️ PROCESSING TIME

- **Per subject-task**: ~1-5 minutes
- **All subjects**: ~1-2 hours (depends on number of files)

Progress messages will be displayed in MATLAB command window.

---

## 🔄 AFTER PIPELINE COMPLETES

1. **Re-run R merger**:
   ```r
   source('01_data_preprocessing/r/Create merged flat file.R')
   ```

2. **Check merge rates** - Should be accurate with trial_in_run matching

3. **Update quality reports** - Re-run sanity checks

---

## ❓ TROUBLESHOOTING

**MATLAB won't start?**
- Try opening MATLAB from Applications folder
- Check if MATLAB license is active

**Pipeline errors?**
- Check MATLAB command window for error messages
- Verify paths are configured correctly (see FIRST-TIME SETUP above)
- Verify cleaned files exist in configured `cleaned_dir`
- Verify raw files exist in configured `raw_dir` (sub-*/ses-*/InsideScanner/)
- Check `qc_matlab_excluded_files.csv` for excluded files and reasons

**Need help?**
- Check `RUN_PIPELINE_INSTRUCTIONS.md` for detailed instructions
- Review `AUDIT_FIXES_APPLIED.md` for fix details

---

**Status**: Ready to run! All fixes are implemented. Just open MATLAB and run `RUN_MATLAB_PIPELINE`.









