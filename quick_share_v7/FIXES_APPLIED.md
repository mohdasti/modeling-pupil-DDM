# Fixes Applied to make_quick_share_v7.R

## Summary

All fixes from the LLM feedback have been implemented. The script now:
1. ✅ Joins by atomic keys (not trial_uid string)
2. ✅ Adds join diagnostics
3. ✅ Cleans duplicate columns
4. ✅ Makes timing columns self-contained
5. ✅ Creates slim QMD report

---

## Changes Made

### 1. Fixed Join to Use Atomic Keys (Lines ~450-509)

**Before:** Joined by `trial_uid` string (which had separator mismatch: `:` vs `|`)

**After:** 
- Join by atomic keys: `sub, task, session_used, run_used, trial_index`
- Ensure types match on both sides (character for sub/task, integer for session/run/trial)
- Create `trial_uid_auc` for reference in AUC features (pipe-delimited)
- Create canonical `trial_uid` in merged output (colon-delimited)

**Key code:**
```r
# Ensure types match
merged_base <- merged_base %>%
  mutate(
    sub = as.character(sub),
    task = as.character(task),
    session_used = as.integer(session_used),
    run_used = as.integer(run_used),
    trial_index = as.integer(trial_index)
  )

# Join by atomic keys
merged_v4 <- merged_base %>%
  left_join(auc_features_unique, by = c("sub", "task", "session_used", "run_used", "trial_index"), 
            relationship = "many-to-one")
```

### 2. Added Join Diagnostics (Lines ~554-599)

**Added:**
- Match rate calculation and printing
- Sample trial_uid formats from both datasets
- QC file: `05_auc_join_match_summary.csv`
- QC file: `06_auc_unmatched_key_patterns.csv` (grouped by sub/task/session/run)

**Output:**
- Prints match rate to console
- Saves diagnostic tables to `qc/` folder
- Shows top unmatched patterns

### 3. Clean Column Duplicates (Lines ~511-516)

**Added:**
- Automatic detection and removal of `.x` and `.y` duplicate columns
- Warning message if duplicates found

**Code:**
```r
dup_cols <- grep("\\.(x|y)$", names(merged_v4), value = TRUE)
if (length(dup_cols) > 0) {
  cat("  ⚠ Removing ", length(dup_cols), " duplicate columns (.x/.y suffixes)\n", sep = "")
  merged_v4 <- merged_v4 %>% select(-any_of(dup_cols))
}
```

### 4. Timing Columns Self-Contained (Lines ~546-552)

**Before:** `timing_source` was hard-set to `"fixed_design"` for all trials

**After:**
- `timing_source` is set based on `timing_anchor_found`:
  - `"ptb_anchor"` if `timing_anchor_found == TRUE`
  - `"fixed_design"` otherwise
- All timing columns included in merged dataset:
  - `t_target_onset_rel`, `t_resp_start_rel`
  - `timing_source`, `timing_anchor_found`
  - `dt_median`, `time_unit_inferred`

**Code:**
```r
timing_source = if_else(!is.na(timing_anchor_found) & timing_anchor_found == TRUE, 
                        "ptb_anchor", "fixed_design")
```

### 5. Created Slim QMD Report (`quick_share_v7/report.qmd`)

**New file:** `quick_share_v7/report.qmd`

**Contents:**
- Data coverage summary
- Gate pass rates table
- AUC availability by task
- Top missingness reasons
- Decision note on AUC viability for Ch2/Ch3

**To render:**
```bash
quarto render quick_share_v7/report.qmd
```

---

## Expected Results After Re-run

### Join Diagnostics Should Show:
- **Match rate:** Should be >= 98% (if computation is working)
- **n_valid_B0 non-NA:** Should be >= 98% of trials
- **No .x/.y columns:** Should be removed

### AUC Availability Should Improve:
- If computation is working: Should see non-zero AUC availability
- If data quality is poor: Will still be low, but at least we'll have diagnostic values

### Timing Source:
- Should show mix of `"ptb_anchor"` and `"fixed_design"` (or all `"fixed_design"` if PTB timing not found)

---

## Acceptance Criteria (Stop/Go Checks)

After re-running, verify:

1. **Join integrity:**
   - ✅ `n_valid_B0` non-NA rate >= 98%
   - ✅ Match rate >= 98%

2. **Column hygiene:**
   - ✅ 0 `.x`/`.y` duplicate columns

3. **AUC viability (if using AUC):**
   - ✅ Ch2: `auc_available` rate >= 25-30% (after Ch2 gate)
   - ✅ Ch3: `auc_available` rate >= 40-50% (after DDM gate)

4. **QC tables:**
   - ✅ All QC files generated
   - ✅ Join diagnostics saved

---

## Files Modified

1. **`scripts/make_quick_share_v7.R`**
   - Lines ~450-470: AUC feature deduplication (uses atomic keys)
   - Lines ~486-527: Join logic (atomic keys, column cleanup, trial_uid handling)
   - Lines ~546-552: Timing source logic
   - Lines ~554-599: Join diagnostics

2. **`quick_share_v7/report.qmd`** (NEW)
   - Slim Quarto report for QC summary

---

## Next Steps

1. **Re-run the script:**
   ```bash
   Rscript scripts/make_quick_share_v7.R
   ```

2. **Check join diagnostics:**
   - Review console output for match rate
   - Check `qc/05_auc_join_match_summary.csv`
   - Check `qc/06_auc_unmatched_key_patterns.csv`

3. **Verify outputs:**
   - `n_valid_B0` should be populated (not all NA)
   - No `.x`/`.y` columns in merged file
   - AUC availability should be > 0% if computation works

4. **Render QMD report:**
   ```bash
   quarto render quick_share_v7/report.qmd
   ```

---

**All fixes implemented and ready for testing.**

