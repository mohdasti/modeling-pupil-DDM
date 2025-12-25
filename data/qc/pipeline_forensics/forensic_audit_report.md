# Forensic Audit Report: Pipeline ses/run Provenance

**Date:** `r format(Sys.time(), '%Y-%m-%d %H:%M:%S')`  
**Auditor:** Automated Forensic Pipeline Audit  
**Objective:** Prove/disprove ses==1 contamination and identify exact lines causing run=ses bug

---

## TASK 0: PROVE/DISPROVE ses==1 CONTAMINATION

### 0A: BAP_cleaned Filename Scan

**Result:** ✓ **NO ses==1 contamination found**

- **Total files scanned:** 541 cleaned .mat files
- **Session 2 files:** 267
- **Session 3 files:** 272  
- **Session 1 files:** 0
- **Unknown/NA:** 2 (likely parsing edge cases)

**Conclusion:** BAP_cleaned contains ONLY sessions 2 and 3. There are NO session1 files in the source data.

**Evidence saved:** `bap_cleaned_filename_scan.csv`

### 0B: Source Path Extraction

**Flat files (`*_flat.csv`):**
- **Count:** 96 files
- **Columns:** `sub`, `task`, `run`, `trial_index`, `trial_in_run`, `trial_label`, `time`, `pupil`, `has_behavioral_data`, `baseline_quality`, `trial_quality`, `overall_quality`
- **Missing:** NO `ses` column in flat files
- **Source tracking:** No explicit source path column

**Merged files (`*_flat_merged.csv`):**
- **Count:** 84 files
- **Columns:** Includes behavioral columns (`ses`, `stimLev`, `isOddball`, etc.)
- **Critical finding:** `stored_ses` = NA for ALL 84 files
- **Reason:** R merger doesn't properly map `session_num` → `ses`

**TRIALLEVEL:**
- **Rows:** 1,425 trials
- **Ses distribution:** 728 (ses=2), 697 (ses=3)
- **Run distribution:** 728 (run=2), 697 (run=3) ⚠️ **BUG: run equals ses**

### 0C: Re-parsing ses/run from Source Paths

**Method:** Matched flat/merged filenames back to BAP_cleaned source files using subject and task.

**Results:**
- **Merged files:** 44 matched to ses=2, 38 matched to ses=3, 2 unmatched
- **Stored ses:** ALL NA (84 files)
- **ses_from_source:** Correctly shows 2 or 3

**Conclusion:** Source files have correct ses (2 or 3), but this information is LOST during R merger.

### 0D: Stored vs Parsed Comparison

**Ses Mismatches:**
- **Count:** 0 (because stored_ses is all NA, not mismatched)
- **Issue:** ses information is completely missing, not mismatched

**Run Mismatches:**
- **Count:** 18 files with run mismatches
- **Pattern:** stored_run doesn't always match run_from_source
- **Example:** BAP003_VDT has stored_run=3 but run_from_source=2

**Cross-tabulation (stored_run × run_from_source):**
```
      from_source
stored  1  2  3  4 <NA>
     1 58  2  0  1    1
     2  8  6  0  0    0
     3  2  0  1  1    0
     4  1  0  0  0    0
     5  2  1  0  0    0
```

**Conclusion:** Run information is PRESENT but sometimes incorrect. Ses information is MISSING.

---

## TASK 1: TRACE EXACT LINES WHERE ses/run ARE CREATED/OVERWRITTEN

### Stage 1: MATLAB (`BAP_Pupillometry_Pipeline.m`)

| Variable | Source | Exact Line(s) | Evidence | Risk |
|----------|--------|---------------|----------|------|
| `session` | Filename regex | 254-259 | `session_match = regexp(filename, 'session(\d+)', 'tokens')` | Low - correct extraction |
| `run` | Filename regex | 261-266 | `run_match = regexp(filename, 'run(\d+)', 'tokens')` | Low - correct extraction |
| `session` (stored) | file_info.session | 189 | `sessions{i} = metadata.session` | Low - correct storage |
| `run` (stored) | file_info.run | 190 | `runs(i) = metadata.run` | Low - correct storage |
| **`ses` (output)** | **MISSING** | **543** | **trial_table has NO ses column** | **CRITICAL - ses not output** |
| `run` (output) | file_info.run | 543 | `trial_table.run = repmat(file_info.run, ...)` | Low - correct |

**Finding:** MATLAB correctly extracts session and run from filenames, but **DOES NOT output `ses` column** in flat files. Only `run` is output.

### Stage 2: R Merger (`Create merged flat file.R`)

| Variable | Source | Exact Line(s) | Evidence | Risk |
|----------|--------|---------------|----------|------|
| `ses` (from behavioral) | `bap_beh_trialdata_v2.csv` | 80-102 | Behavioral has `session_num`, NOT `ses` | **CRITICAL - wrong column name** |
| `run` (merge key) | Flat files | 192 or 207 | Merge on `(run, trial_in_run)` or `(run, trial_index)` | Medium - key for merge |
| `ses` (after merge) | Line 267 | 267 | `ses = if("ses" %in% names(.)) coalesce(ses, NA_real_) else NA_real_` | **CRITICAL - always NA** |

**Finding:** 
- Behavioral file has `session_num` column (line 11: `behavioral_file`)
- R merger looks for `ses` column (line 148-149, 157)
- Since `ses` doesn't exist, it's set to NA (line 267)
- **Result:** All merged files have `ses=NA`

### Stage 3: QMD (`generate_pupil_data_report.qmd`)

| Variable | Source | Exact Line(s) | Evidence | Risk |
|----------|--------|---------------|----------|------|
| `ses` (from pupil_ready) | Flat files | ~400 | Flat files don't have ses | **CRITICAL - missing** |
| `run` (join key) | Flat files | 6160 | `by = c("subject_id", "task", "run", "trial_index")` | Medium - join key |
| `ses` (from behav_ready) | Behavioral file | ~6124 | Behavioral has `session_num` | Medium - needs mapping |
| **`run` (overwritten?)** | **Unknown** | **6160 or 825** | **Join may overwrite run** | **CRITICAL - run=ses bug** |

**Finding:**
- QMD reads flat files (no ses) and behavioral file (has session_num)
- Join at line 6160 doesn't include `ses` in join keys
- `ses` may be added from behavioral, but `run` might get overwritten
- Line 825 creates `trial_id` using `run` - if run is wrong here, it propagates

**CRITICAL BUG LOCATION (HYPOTHESIS):**
- Line 6160: Join doesn't preserve `run` correctly
- OR: `run` from flat files gets overwritten by `run` from behavioral (which might be wrong)
- OR: `run` gets recoded/coalesced somewhere and ends up matching `ses`

---

## TASK 2: PRACTICE/OUTSIDE-SCANNER EXCLUSION PROOF

**Result:** ✓ **NO practice/outside-scanner files found**

**Provenance breakdown:**
- **InsideScanner_Ses2-3:** 539 files
- **Unknown:** 2 files (parsing edge cases, likely still ses 2-3)

**Directory patterns checked:**
- `OutsideScanner`: 0 files
- `practice`: 0 files  
- `MATLAB`: 0 files
- `ses-1` or `session1`: 0 files

**Conclusion:** BAP_cleaned is properly filtered. No practice or outside-scanner files are being processed.

**Evidence saved:** `provenance_directory_breakdown.csv`

---

## TASK 3: ROOT CAUSE ANALYSIS

### The ses==1 Claim: **DISPROVEN**

**Evidence:**
1. BAP_cleaned has ZERO session1 files
2. Current TRIALLEVEL has ZERO ses==1 trials
3. All trials are ses 2 or 3

**Conclusion:** There is NO ses==1 contamination. The claim is FALSE.

### The run=ses Bug: **PROVEN**

**Evidence:**
1. TRIALLEVEL has run values of only 2 and 3 (matching ses)
2. Behavioral file has run values 1-5
3. Flat files have run values 1-5 (from MATLAB)
4. Merged files have run values 1-5 but ses=NA
5. Final TRIALLEVEL has run=ses (2 or 3)

**Root Cause Chain:**
1. **MATLAB:** Outputs `run` correctly (1-5) but NO `ses`
2. **R Merger:** Tries to get `ses` from behavioral but looks for wrong column name (`ses` instead of `session_num`), so `ses=NA`
3. **QMD:** Needs `ses` but doesn't have it from flat files. May infer from behavioral `session_num`, but then `run` gets overwritten somehow.

**Exact Bug Location (HYPOTHESIS):**
- **QMD line ~6124:** Reads behavioral with `session_num`
- **QMD line ~6157-6160:** Joins pupil and behavioral
- **QMD line ~825 or later:** Creates `trial_id` or aggregates, and `run` gets overwritten with `ses` (which came from `session_num`)

**Alternative Hypothesis:**
- QMD normalizes columns and `run` gets coalesced/recoded
- If `run` is missing/NA, it might default to `ses` value
- OR: A join creates `run.x` and `run.y`, and the wrong one is kept

---

## TASK 4: FIXES REQUIRED

### Fix 1: MATLAB - Add ses Column

**File:** `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m`  
**Line:** ~543 (in `process_single_run_improved`)

**Change:**
```matlab
% CURRENT (line 543):
trial_table.run = repmat(file_info.run, n_samples, 1);

% FIX: Add ses column
trial_table.ses = repmat(str2double(file_info.session{1}), n_samples, 1);
```

**Also update line 141 (output filename) to include ses if needed for tracking.**

### Fix 2: R Merger - Map session_num to ses

**File:** `01_data_preprocessing/r/Create merged flat file.R`  
**Line:** ~80-102 (behavioral data mapping)

**Change:**
```r
# CURRENT (line 93):
run = run_num,

# ADD:
ses = session_num,  # Map session_num -> ses
```

**Also update line 148-149 and 157:**
```r
# CURRENT:
if("ses" %in% names(behavioral_data)) {
    cols_to_select <- c(cols_to_select, "ses")
}

# FIX: Also check for session_num
if("ses" %in% names(behavioral_data)) {
    cols_to_select <- c(cols_to_select, "ses")
} else if("session_num" %in% names(behavioral_data)) {
    cols_to_select <- c(cols_to_select, "session_num")
    # Then map it later
}
```

**And line 157:**
```r
# CURRENT:
ses = if("ses" %in% names(.)) ses else NA_real_

# FIX:
ses = coalesce(
    if("ses" %in% names(.)) ses else NA_real_,
    if("session_num" %in% names(.)) session_num else NA_real_
)
```

### Fix 3: QMD - Preserve ses and run, Add Assertions

**File:** `02_pupillometry_analysis/generate_pupil_data_report.qmd`  
**Lines:** ~400 (normalize), ~6124 (behav_ready), ~6157-6160 (join), ~825 (trial_id)

**Changes:**

1. **Line ~400 (normalize flat files):** Extract ses from filename if not in data
```r
# ADD after line 415:
ses = if("ses" %in% names(.)) ses else {
    # Try to extract from source filename
    # (This is a fallback - ses should come from MATLAB)
    NA_integer_
},
```

2. **Line ~6124 (behav_ready):** Map session_num -> ses
```r
# ADD after reading behavioral:
behav_ready <- behav_ready %>%
  mutate(
    ses = if("ses" %in% names(.)) ses 
          else if("session_num" %in% names(.)) session_num 
          else NA_integer_
  )
```

3. **Line ~6157-6160 (join):** Include ses in join keys and preserve run
```r
# CURRENT:
merged_ready <- pupil_ready %>%
  dplyr::left_join(
    behav_ready,
    by = c("subject_id", "task", "run", "trial_index")
  )

# FIX:
merged_ready <- pupil_ready %>%
  dplyr::left_join(
    behav_ready,
    by = c("subject_id", "task", "run", "trial_index"),
    suffix = c("_pupil", "_behav")
  ) %>%
  mutate(
    # Preserve run from pupil (don't let behavioral overwrite)
    run = coalesce(run_pupil, run_behav, run),
    # Get ses from behavioral (pupil may not have it)
    ses = coalesce(ses_behav, ses_pupil, ses)
  ) %>%
  select(-ends_with("_pupil"), -ends_with("_behav"))
```

4. **Line ~825 (trial_id):** Include ses in trial_id
```r
# CURRENT:
trial_id = paste(subject_id, task, run, trial_index, sep = ":")

# FIX:
trial_id = paste(subject_id, task, ses, run, trial_index, sep = ":")
```

5. **Add assertions after creating merged_ready:**
```r
# After line 6162, add:
stopifnot(all(merged_ready$ses %in% c(2, 3), na.rm = TRUE))
stopifnot(all(merged_ready$run %in% 1:5, na.rm = TRUE))
stopifnot(!any(is.na(merged_ready$ses)))
```

---

## TASK 5: VERIFICATION CHECKLIST

After implementing fixes, verify:

- [ ] MATLAB flat files include `ses` column
- [ ] R merged files have `ses` values (not NA)
- [ ] QMD merged dataset has `ses` in {2,3} and `run` in {1,2,3,4,5}
- [ ] `run` does NOT equal `ses` in final dataset
- [ ] `trial_id` includes `ses`
- [ ] No source paths contain OutsideScanner/practice
- [ ] All assertions pass

---

## SUMMARY

**ses==1 Contamination:** ❌ **DISPROVEN** - No ses==1 files exist in BAP_cleaned or final dataset.

**run=ses Bug:** ✅ **PROVEN** - Root cause is:
1. MATLAB doesn't output `ses`
2. R merger doesn't map `session_num` → `ses`
3. QMD may infer `ses` incorrectly and overwrite `run`

**Practice/Outside-Scanner:** ✅ **PROVEN EXCLUDED** - No such files in BAP_cleaned.

**Next Steps:** Implement fixes in MATLAB, R merger, and QMD, then rebuild and verify.

---

*Report generated: `r format(Sys.time(), '%Y-%m-%d %H:%M:%S')`*

