# QMD Report Audit - Issues Found

## Critical Issue: Missing Validity Proportions

**Problem**: The new Stage 2 pipeline creates `baseline_valid` and `cog_valid` columns but they are all `NA` because:
- The pipeline checks if these columns exist in the raw MATLAB flat files
- They don't exist - they need to be **computed** from sample-level pupil data
- Without valid proportions, all gates evaluate to FALSE (0 trials pass)

**Impact**: 
- Gate retention shows 0 trials for all gates (ch2_primary, ch2_sens_050, etc.)
- The QMD report sections that depend on validity proportions will fail or show empty results

## QMD Sections Status

### ✅ Still Valid Sections

1. **Data Inventory** (lines 126-380)
   - File discovery and subject inventory
   - Still works with flat files

2. **Raw Pupil Trial Coverage** (lines 381-552)
   - Builds `trial_coverage_prefilter` from sample-level data
   - **This is the correct approach** - computes validity proportions from samples
   - Should be used as the source of truth for validity

3. **Gate Configuration & Definitions** (lines 881-1005)
   - Gate logic is correct
   - Uses validity proportions from `trial_coverage_prefilter`

4. **Most visualization and analysis sections**
   - Depend on `trial_coverage_prefilter` which is built correctly
   - Will work once validity proportions are available

### ⚠️ Needs Update

1. **Export Analysis-Ready Datasets** (lines 6070-6248)
   - Currently tries to use new pipeline outputs
   - But new pipeline outputs have NA validity proportions
   - Should fall back to computing from `trial_coverage_prefilter` if validity is missing

2. **Final Readiness Report** (lines 8367-8387)
   - Shows 0 trials because gates depend on validity proportions
   - Will be fixed once validity proportions are computed

## Solution

The new Stage 2 pipeline needs to compute validity proportions from sample-level data, similar to how the QMD's `build_trial_coverage` function does it. The computation should:

1. For each trial, compute validity proportions for:
   - Baseline window (-0.5 to 0.0s): `baseline_valid`
   - Cognitive window (4.65s to response_onset): `cog_valid`
   - Stimulus-locked windows if needed

2. These should be computed as: `mean(!is.na(pupil[in_window]))`

## Recommended Fix

Update `rebuild_pupil_pipeline_stage2.R` STEP B to compute validity proportions from sample-level data instead of checking if they exist in raw data.

