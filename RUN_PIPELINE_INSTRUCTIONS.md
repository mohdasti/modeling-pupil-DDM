# Instructions: Running MATLAB Pipeline with Audit Fixes

**Date**: December 2025  
**Purpose**: Re-run MATLAB pipeline for all subjects with audit fixes applied

---

## FIXES APPLIED

The following fixes have been implemented in `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m`:

1. ✅ **Zero-to-NaN Conversion** (lines 362-366)
   - Converts all zero values to NaN
   - Prevents statistical corruption

2. ✅ **Baseline Quality Check** (lines 442-445)
   - Excludes trials with baseline quality < 0.80
   - Prevents baseline-driven artifacts

3. ✅ **trial_in_run Tracking** (lines 393-394, 444-446, 491)
   - Exports trial_in_run column (1, 2, 3... within each run)
   - Enables robust merging in R

4. ✅ **Exclusion Threshold** (line 66)
   - Tightened to 80% (20% missing max)

5. ✅ **Anti-Aliasing Filter** (lines 451-459)
   - 8th-order Butterworth filter before downsampling

---

## HOW TO RUN

### Option 1: Run in MATLAB GUI (Recommended)

1. Open MATLAB
2. Navigate to project directory:
   ```matlab
   cd('/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM')
   ```
3. Add pipeline directory to path:
   ```matlab
   addpath('01_data_preprocessing/matlab')
   ```
4. Run the pipeline:
   ```matlab
   BAP_Pupillometry_Pipeline()
   ```

### Option 2: Run from Command Line

If MATLAB is in your PATH:
```bash
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM
matlab -nodisplay -nosplash -r "addpath('01_data_preprocessing/matlab'); BAP_Pupillometry_Pipeline(); exit;"
```

### Option 3: Use the Shell Script

```bash
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM
./run_pipeline.sh
```

---

## EXPECTED OUTPUT

The pipeline will:

1. Process all cleaned `.mat` files in:
   `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned/`

2. Generate flat CSV files in:
   `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/`

3. Output files will have:
   - **Zero values**: 0% (all converted to NaN)
   - **trial_in_run**: Present (sequential: 1, 2, 3...)
   - **Baseline quality**: Only trials with ≥0.80 included
   - **Overall quality**: Only trials with ≥0.80 included

---

## VERIFICATION

After running, verify the fixes worked:

```r
library(readr)
library(dplyr)

# Check a sample file
df <- read_csv('/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/BAP003_ADT_flat.csv', 
               n_max=10000, show_col_types=FALSE)

cat('Zero values:', sum(df$pupil == 0, na.rm=TRUE), '\n')
cat('NaN values:', sum(is.na(df$pupil)), '\n')
cat('Has trial_in_run:', 'trial_in_run' %in% names(df), '\n')
if('trial_in_run' %in% names(df)) {
  cat('Unique trial_in_run values:', paste(unique(df$trial_in_run), collapse=', '), '\n')
}
```

**Expected Results**:
- Zero values: 0
- NaN values: > 0 (zeros converted)
- Has trial_in_run: TRUE
- trial_in_run: Sequential (1, 2, 3...)

---

## PROCESSING TIME

Expected processing time:
- **Per subject-task**: ~1-5 minutes
- **All subjects**: ~1-2 hours (depending on number of files)

The pipeline processes files sequentially and will display progress messages.

---

## TROUBLESHOOTING

### MATLAB Not Found
If MATLAB is not in PATH, use Option 1 (MATLAB GUI) or locate MATLAB installation:
```bash
find /Applications -name "matlab" -type f 2>/dev/null
```

### Errors During Processing
Check the MATLAB command window or log file for error messages. Common issues:
- Missing raw files (pipeline will skip with warning)
- File format issues (check cleaned file structure)
- Memory issues (process fewer files at once)

### Verify Fixes Applied
Check that the fixes are in the code:
```matlab
% In MATLAB, check line 362-366 for zero-to-NaN conversion
% Check line 442-445 for baseline quality check
% Check line 491 for trial_in_run
```

---

## NEXT STEPS

After MATLAB pipeline completes:

1. **Re-run R merger**:
   ```r
   source('01_data_preprocessing/r/Create merged flat file.R')
   ```

2. **Verify merge accuracy**:
   - Check merge rates
   - Verify trial_in_run matching works
   - Compare before/after metrics

3. **Update quality reports**:
   - Re-run sanity checks
   - Update data quality reports
   - Compare valid trial rates

---

## FILES MODIFIED

- `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m` - All fixes applied
- `01_data_preprocessing/r/Create merged flat file.R` - Updated for trial_in_run

---

**Status**: Ready to run. All fixes are implemented and validated.









