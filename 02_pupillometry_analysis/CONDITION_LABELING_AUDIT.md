# Audit: Why "Unknown" Conditions Exist

## Executive Summary

**The "Unknown" conditions are NOT caused by pupil data quality thresholds.** They are caused by **data merging and alignment issues** between pupil recordings and behavioral data. Specifically:

1. **Missing or failed merges**: When pupil data doesn't successfully merge with behavioral data, the condition variables (`gf_trPer`, `force_condition`, `isOddball`, `stimLev`) are missing
2. **Invalid or unexpected values**: When the source values exist but don't match the expected patterns in the condition assignment logic
3. **Data alignment issues**: When trials are misaligned between pupil and behavioral data during the merge process

## Root Cause Analysis

### Where Conditions Are Assigned

Conditions are assigned in `generate_pupil_data_report.qmd` (lines 486-513) during the `build_trial_coverage()` function:

```r
effort_condition = factor(dplyr::case_when(
  !is.na(gf_trPer) & gf_trPer == 0.05 ~ "Low_5_MVC",
  !is.na(gf_trPer) & gf_trPer == 0.40 ~ "High_40_MVC",
  force_condition == "Low_Force_5pct" ~ "Low_5_MVC",
  force_condition == "High_Force_40pct" ~ "High_40_MVC",
  TRUE ~ NA_character_  # ← This creates missing conditions
), levels = c("Low_5_MVC", "High_40_MVC")),

difficulty_level = factor(dplyr::case_when(
  isOddball == 0 ~ "Standard",
  !is.na(stimLev) & stimLev == 0 ~ "Standard",
  isOddball == 1 & !is.na(stimLev) & stimLev %in% c(1, 2) ~ "Hard",
  isOddball == 1 & !is.na(stimLev) & stimLev %in% c(3, 4) ~ "Easy",
  # ... more patterns ...
  TRUE ~ NA_character_  # ← This creates missing conditions
), levels = c("Standard", "Easy", "Hard")),
```

### Source of Condition Variables

These variables come from **merged flat files** (`*_flat_merged.csv`) which are created by merging:
- **Pupil data** (from MATLAB pipeline)
- **Behavioral data** (from behavioral CSV files)

The merge happens in `01_data_preprocessing/r/Create merged flat file.R` using:
- Primary key: `(run, trial_in_run)` 
- Fallback: Position-based matching (if `trial_in_run` not available)

### Why Conditions Become Missing

#### 1. **Failed Merges** (Most Common)
When the merge between pupil and behavioral data fails:
- The behavioral variables (`gf_trPer`, `stimLev`, `isOddball`, `force_condition`) are `NA`
- The condition assignment logic returns `NA_character_` (the `TRUE ~ NA_character_` fallback)

**Causes of failed merges:**
- Mismatched trial counts between pupil and behavioral data
- Missing behavioral data for some trials
- Misaligned `trial_in_run` values
- Trials excluded in MATLAB pipeline but present in behavioral data (or vice versa)

#### 2. **Invalid/Out-of-Range Values** (Less Common)
When source values exist but don't match expected patterns:
- `gf_trPer` should only be `0.05` or `0.4` - if it's anything else, it's a data quality issue
- `stimLev` is not in expected sets (e.g., `5`, `6`, `7` instead of `1,2,3,4`)
- `isOddball` is `NA` or has unexpected values
- `force_condition` doesn't match exact strings `"Low_Force_5pct"` or `"High_Force_40pct"`

**Note**: Since `gf_trPer` should only have two exact values (0.05 and 0.4), if it doesn't match, it's either:
- Missing (`NA`) due to failed merge
- A data quality issue in the source behavioral files

#### 3. **Missing Source Columns**
If the merged files don't have the expected column names:
- Code tries alternative names (`grip_targ_prop_mvc` instead of `gf_trPer`)
- But if neither exists, variable becomes `NA`

## Evidence from Code

### Data Loading (lines 423-429)
```r
gf_trPer = dplyr::coalesce(
  if ("gf_trPer" %in% names(.)) gf_trPer else NA_real_,
  if ("grip_targ_prop_mvc" %in% names(.)) grip_targ_prop_mvc else NA_real_
),
force_condition = if ("force_condition" %in% names(.)) force_condition else NA_character_,
stimLev = if ("stimLev" %in% names(.)) stimLev else if ("stim_level_index" %in% names(.)) stim_level_index else NA_real_,
isOddball = if ("isOddball" %in% names(.)) isOddball else if ("stim_is_diff" %in% names(.)) as.integer(stim_is_diff) else NA_integer_
```

**If columns don't exist → `NA` → Condition becomes `NA`**

### Merge Process (Create merged flat file.R)
The merge uses `left_join()`, which means:
- If behavioral data is missing for a trial → All behavioral columns become `NA`
- If merge key doesn't match → Behavioral columns become `NA`

**Merge success rate is monitored** (line 209-216):
```r
merge_rate <- mean(!is.na(merge_info$behavioral_trial), na.rm = TRUE)
if (merge_rate < 0.7) {
  warning(sprintf("Low merge rate (%.1f%%) for %s-%s. Check for misaligned trials.\n", 
                merge_rate * 100, current_sub, current_task))
}
```

## What This Means

### ❌ NOT Caused By:
- Pupil data quality thresholds (validity thresholds, gate filters)
- Low pupil signal quality
- Missing pupil samples within trials
- Data quality filtering in the report generation
- Floating point precision issues (0.05 and 0.4 are exact values)

### ✅ Actually Caused By:
- **Data pipeline issues**: Failed merges between pupil and behavioral data (most likely)
- **Missing source data**: Behavioral data not available for some trials
- **Trial alignment problems**: Mismatched trial counts or ordering between pupil and behavioral data
- **Column name mismatches**: Expected columns (`gf_trPer`, `grip_targ_prop_mvc`) not present in merged files

## Recommendations

### 1. **Investigate Merge Success Rates**
Check the merge logs from `Create merged flat file.R` to see which subject-task combinations have low merge rates.

### 2. **Examine Source Behavioral Data**
For trials with missing conditions, check:
- Do they exist in the behavioral CSV?
- Do they have valid `gf_trPer`, `stimLev`, `isOddball` values?
- Are the values in expected ranges?

### 3. **Verify Exact Values Match**
Since `gf_trPer` should only be exactly `0.05` or `0.4`:
- The strict matching (`==`) is correct and appropriate
- If values don't match, it means either:
  - The merge failed and `gf_trPer` is `NA`
  - There's a data quality issue in the source behavioral files
  - The values are stored incorrectly (e.g., as strings or with unexpected precision)

### 4. **Add Diagnostic Columns**
The report already attempts to show raw values (lines 1026-1047), but this requires `raw_*` columns. Ensure these are preserved during data loading.

### 5. **Fix at Source**
The best solution is to fix the data merging pipeline to ensure:
- All trials have matching behavioral data
- All behavioral data has valid condition values
- Trial alignment is correct

## Current Status

After the recent fixes:
- ✅ "Unknown" is no longer treated as a valid condition category
- ✅ Missing conditions are filtered out from analyses
- ✅ Missing conditions are reported as data quality issues
- ⚠️ Root cause (merge failures) still needs investigation
- ⚠️ Source data quality issues still need to be addressed

## Next Steps

1. Run the merge script and check merge success rates
2. For subject-task combinations with >20% missing conditions, investigate:
   - Behavioral data availability
   - Trial alignment issues
   - Value ranges in source data
3. Consider adding tolerance-based matching for `gf_trPer`
4. Add validation checks in the merge script to flag problematic merges early

