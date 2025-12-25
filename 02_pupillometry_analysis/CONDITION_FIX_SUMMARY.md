# Summary: Unknown Condition Fix and Recovery Impact

## What Was The Problem Before?

### The "Unknown" Condition Issue

**Before the fix**, the code had a fundamental flaw in how it handled missing condition labels:

1. **Created "Unknown" as a valid category**: When `effort_condition` or `difficulty_level` was missing (NA), the code would:
   - Convert `NA` → `"Unknown"` 
   - Include "Unknown" as a valid factor level
   - Treat "Unknown" as a legitimate third/fourth condition in analyses

2. **Why conditions were missing**: Conditions became missing due to:
   - **Failed merges**: When pupil data didn't successfully merge with behavioral data during preprocessing
   - **Missing source columns**: When merged files didn't have `gf_trPer`, `stimLev`, etc.
   - **Trial alignment issues**: Mismatched trial counts between pupil and behavioral data

3. **The problem with "Unknown"**:
   - **Conceptually wrong**: You only have 2 effort levels (Low, High) and 3 difficulty levels (Standard, Easy, Hard). "Unknown" is not a valid experimental condition.
   - **Analytically problematic**: Including "Unknown" as a category would:
     - Create meaningless comparisons (e.g., "Low vs High vs Unknown")
     - Dilute statistical power by splitting data into an invalid category
     - Make results uninterpretable (what does "Unknown" mean scientifically?)

### Example of the Problem

**Before:**
```
Effort conditions: Low, High, Unknown  ← Wrong! Unknown is not a condition
Difficulty levels: Standard, Easy, Hard, Unknown  ← Wrong!
```

**After:**
```
Effort conditions: Low, High  ← Correct
Difficulty levels: Standard, Easy, Hard  ← Correct
Missing conditions: Excluded from condition-based analyses (or recovered)
```

## What We Fixed

### 1. Removed "Unknown" as a Valid Category

**Changes made:**
- Removed all code that converted `NA` → `"Unknown"`
- Removed "Unknown" from factor levels
- Changed filtering logic to exclude missing conditions instead of labeling them

**Before:**
```r
effort_condition = ifelse(is.na(effort_condition), "Unknown", effort_condition)
effort_condition = factor(effort_condition, levels = c("Low_5_MVC", "High_40_MVC", "Unknown"))
```

**After:**
```r
# Filter out missing conditions
filter(!is.na(effort_condition), !is.na(difficulty_level))
effort_condition = factor(effort_condition, levels = c("Low_5_MVC", "High_40_MVC"))
```

### 2. Added Automatic Recovery Mechanism

**New functionality:**
- After loading trial coverage data, the system now:
  1. Identifies trials with missing conditions
  2. Loads behavioral data directly from the CSV file
  3. Matches trials by `(subject_id, task, run, trial_index)`
  4. Extracts condition information from behavioral data
  5. Backfills missing conditions where possible

**Recovery logic:**
- Matches trials that failed to merge during preprocessing
- Extracts `gf_trPer` (0.05 or 0.4) for effort condition
- Extracts `isOddball` and `stimLev` for difficulty level
- Only backfills where conditions are actually missing (doesn't overwrite existing values)

### 3. Updated Reporting

**Changes:**
- Reports missing conditions as data quality issues (not as valid categories)
- Shows recovery statistics (how many conditions were recovered)
- Provides diagnostics for trials that couldn't be recovered

## Has This Increased Usable Trials?

### Yes, Potentially Significantly!

**The recovery mechanism should increase usable trials** by recovering trials that were previously excluded due to missing conditions. Here's why:

### Before the Fix:
1. **Trials with missing conditions** → Labeled as "Unknown" → Included but in wrong category
2. **Trials with missing conditions** → Couldn't be used in condition-based analyses anyway (because "Unknown" is meaningless)

### After the Fix:
1. **Trials with missing conditions** → Recovery attempt → If successful, conditions backfilled → **Trials now usable**
2. **Trials with missing conditions** → Recovery attempt → If unsuccessful, excluded (but at least we know why)

### Expected Impact

The recovery mechanism should recover trials where:
- ✅ Behavioral data exists but merge failed during preprocessing
- ✅ Trial identifiers match between pupil and behavioral data
- ✅ Condition values are valid in behavioral data

**You should see recovery statistics in your report** showing:
- How many trials had missing conditions (before recovery)
- How many effort conditions were recovered
- How many difficulty levels were recovered
- How many trials had both conditions recovered

### Example Recovery Scenario

**Scenario**: A trial has pupil data but the merge step failed, so `gf_trPer` is missing.

**Before fix:**
- Trial labeled as `effort_condition = "Unknown"`
- Included in dataset but can't be used in condition-based analyses
- **Result**: Trial effectively lost

**After fix:**
- Recovery mechanism finds the trial in behavioral data
- Extracts `gf_trPer = 0.05` from behavioral CSV
- Backfills `effort_condition = "Low_5_MVC"`
- **Result**: Trial now usable in analyses!

## How to Verify the Impact

### Check Your Report

Look for these sections in your generated report:

1. **"Recovery Statistics"** (in Condition Labeling Diagnostics):
   ```
   - Attempted recovery for X trials with missing conditions
   - Recovered Y effort conditions (Z% of attempted)
   - Recovered W difficulty levels (V% of attempted)
   - Recovered both conditions for U trials
   ```

2. **"Condition Labeling Summary (After Recovery Attempt)"**:
   - Shows final counts of missing conditions
   - Compare "before recovery" vs "after recovery" to see the impact

3. **Compare trial counts**:
   - Check condition-based analyses (e.g., Gate C trials by condition)
   - Compare to previous reports to see if trial counts increased

### Expected Outcomes

**Best case scenario:**
- Most missing conditions are recovered (80-100% recovery rate)
- Significant increase in usable trials for condition-based analyses
- Only a small number of trials remain unrecoverable (true data quality issues)

**Typical scenario:**
- Moderate recovery rate (50-80%)
- Noticeable increase in usable trials
- Some trials remain unrecoverable (need to investigate merge pipeline)

**Worst case scenario:**
- Low recovery rate (<50%)
- Suggests systematic issues with:
  - Trial alignment between pupil and behavioral data
  - Column name mismatches
  - Data quality issues in behavioral files

## What About Trials That Still Can't Be Recovered?

Trials that remain unrecoverable after the recovery attempt are likely due to:

1. **No matching behavioral data**: Trial doesn't exist in behavioral CSV
2. **Mismatched identifiers**: Subject ID, task, run, or trial_index don't match
3. **Invalid condition values**: Behavioral data has values that don't match expected patterns
4. **Missing source columns**: Required columns don't exist in behavioral data

**These should be investigated** to:
- Fix the merge pipeline to prevent future failures
- Understand why certain trials can't be matched
- Determine if these are systematic issues or one-off problems

## Summary

### The Problem
- "Unknown" was incorrectly treated as a valid condition category
- This was conceptually wrong and analytically problematic
- Trials with missing conditions were either mislabeled or excluded

### The Fix
- Removed "Unknown" as a valid category
- Added automatic recovery to backfill missing conditions from behavioral data
- Updated reporting to show recovery statistics

### The Impact
- **Should increase usable trials** by recovering trials lost due to merge failures
- **Improves data quality** by correctly categorizing conditions
- **Makes analyses valid** by only using legitimate condition categories
- **Provides transparency** about what was recovered and what remains missing

### Next Steps
1. Check your report's recovery statistics to see the actual impact
2. Compare trial counts before/after to quantify the increase
3. Investigate unrecoverable trials to fix root causes
4. Use the increased trial counts in your analyses!



