# Comprehensive Fixes Applied to make_quick_share_v7.R

## Summary

All critical fixes have been implemented to address the root causes identified:
1. ✅ Fixed AUC feature computation to group by FULL KEYS (not just trial_index)
2. ✅ Fixed merge cleanup to COALESCE .x/.y columns BEFORE dropping them
3. ✅ Fixed join to use atomic keys (not trial_uid string)
4. ✅ Added comprehensive STOP/GO checks
5. ✅ Added new QC outputs for coverage and non-NA rates

---

## Detailed Changes

### STEP A: Added normalize_keys() Helper Function

**Location:** Lines ~97-106

**Purpose:** Ensures consistent key types across all joins

**Implementation:**
```r
normalize_keys <- function(df) {
  df %>%
    mutate(
      sub = as.character(sub),
      task = as.character(task),
      session_used = as.integer(session_used),
      run_used = as.integer(run_used),
      trial_index = as.integer(trial_index)
    )
}
```

**Used in:**
- `process_flat_file_v7()` - before grouping
- `merged_base` - before join
- `auc_features_unique` - before join
- Waveform extraction - for matching trials

---

### STEP B: Fixed AUC Feature Computation Grouping

**Location:** Lines ~247-273

**Problem:** Was grouping only by `trial_index`, which mixed trials across runs/sessions

**Fix:** Changed to group by FULL KEYS:
```r
# OLD (WRONG):
trial_features <- df %>%
  group_by(trial_index) %>%
  group_map(~ {
    trial_num <- .y$trial_index
    # Used meta$sub, meta$task, etc. (single value from slice(1))
  })

# NEW (CORRECT):
trial_features <- df %>%
  group_by(sub, task, session_used, run_used, trial_index) %>%
  group_map(~ {
    trial_keys <- .y  # Full key set per trial
    trial_num <- trial_keys$trial_index
    # Uses trial_keys$sub, trial_keys$task, etc.
  })
```

**Impact:** Each trial now correctly labeled with its actual sub/task/session/run, not a single "meta" value.

---

### STEP C: Fixed t_rel Computation

**Location:** Lines ~275-297

**Changes:**
- Added fallback for `dt_median` if NA (uses 0.004 = 250 Hz)
- Ensured `t_rel` spans [-3.0, 10.7] via recalibration if needed
- Added defensive checks for time unit inference

---

### STEP D: Locked AUC Definitions

**Location:** Lines ~305-410

**Baseline Windows:**
- B0: [-0.5, 0.0) relative to trial onset
- b0: [target_onset - 0.5, target_onset) relative to trial onset
- Minimum samples: 10 valid samples required

**AUC Computations:**
- `total_auc`: Baseline-corrected using B0, integrate [0, RESP_START_DEFAULT]
- `cog_auc`: Baseline-corrected using b0, integrate [TARGET_ONSET_DEFAULT + 0.3, RESP_START_DEFAULT]

**AUC Availability Flags (NEW):**
- `auc_available_total`: !is.na(total_auc)
- `auc_available_cog`: !is.na(cog_auc)
- `auc_available_both`: auc_available_total & auc_available_cog
- `auc_available`: auc_available_both (backward compatibility)

**AUC Missing Reason:**
- "B0_insufficient_samples" if B0 < 10 samples
- "b0_insufficient_samples" if b0 < 10 samples
- "total_auc_failed" if B0/b0 OK but total_auc is NA
- "cog_auc_failed" if total_auc OK but cog_auc is NA
- "ok" if both AUCs computed

---

### STEP E: Fixed Merge to Use Atomic Keys

**Location:** Lines ~543-546

**Already fixed in previous iteration:**
- Join by `c("sub", "task", "session_used", "run_used", "trial_index")`
- Normalize keys on both sides before join

---

### STEP F: Fixed .x/.y Column Handling (CRITICAL FIX)

**Location:** Lines ~548-585

**Problem:** Was dropping .x/.y columns BEFORE coalescing, losing values

**Fix:** COALESCE first, then drop:
```r
# For each field that might have .x/.y:
for (field in coalesce_fields) {
  field_x <- paste0(field, ".x")
  field_y <- paste0(field, ".y")
  
  if (field_x %in% names(merged_v4) && field_y %in% names(merged_v4)) {
    # Both exist: coalesce (prefer .y, fallback to .x)
    merged_v4[[field]] <- dplyr::coalesce(merged_v4[[field_y]], merged_v4[[field_x]])
  } else if (field_x %in% names(merged_v4)) {
    # Only .x exists: use it
    merged_v4[[field]] <- merged_v4[[field_x]]
  } else if (field_y %in% names(merged_v4)) {
    # Only .y exists: use it
    merged_v4[[field]] <- merged_v4[[field_y]]
  }
}

# NOW drop all .x/.y columns
dup_cols <- grep("\\.(x|y)$", names(merged_v4), value = TRUE)
if (length(dup_cols) > 0) {
  merged_v4 <- merged_v4 %>% select(-any_of(dup_cols))
}
```

**Fields Coalesced:**
- `total_auc`, `cog_auc`
- `n_valid_B0`, `n_valid_b0`
- `baseline_B0_mean`, `baseline_b0_mean`
- `auc_available_total`, `auc_available_cog`, `auc_available_both`, `auc_available`
- `auc_missing_reason`
- `t_target_onset_rel`, `t_resp_start_rel`
- `timing_anchor_found`, `dt_median`, `time_unit_inferred`
- `squeeze_onset_time`

---

### STEP G: Timing Columns Self-Contained

**Location:** Lines ~629-635

**Columns Added:**
- `t_target_onset_rel`: Default 4.35 if missing
- `t_resp_start_rel`: Default 4.70 if missing
- `timing_source`: "ptb_anchor" if `timing_anchor_found == TRUE`, else "fixed_design"

---

### STEP H: New QC Outputs

**Location:** Lines ~637-720

**New Files:**
1. `qc/05_auc_join_match_summary.csv` - Overall match rate
2. `qc/06_auc_unmatched_key_patterns.csv` - Unmatched patterns by sub/task/session/run
3. `qc/07_auc_feature_coverage_by_run.csv` - Coverage per run (NEW)
4. `qc/08_auc_non_na_rates.csv` - Non-NA rates overall and by task (NEW)
5. `qc/STOP_GO_checks.csv` - All stop/go check results (NEW)

---

### STEP I: Comprehensive STOP/GO Checks

**Location:** Lines ~1000-1135

**Checks Implemented:**

**A) Join Integrity:**
- Match rate >= 98% (warns if < 98%, stops if < 90%)
- Prints top 20 unmatched keys if match rate < 98%

**B) AUC Integrity:**
- `total_auc` non-NA count > 0 and > 10
- Stops if `total_auc` all NA but `cog_auc` exists (coalesce bug indicator)

**C) Column Hygiene:**
- Count of .x/.y columns must be 0
- Stops if any found

**D) AUC Flags Consistency:**
- `auc_available_total == !is.na(total_auc)`
- `auc_available_cog == !is.na(cog_auc)`
- `auc_available_both == (total & cog)`

**E) Timing Sanity:**
- `t_target_onset_rel` and `t_resp_start_rel` must be non-NA (defaults filled)
- `timing_source` must be in {fixed_design, ptb_anchor}

---

## Expected Results After Re-run

### Match Rate
- **Before:** ~23.7% (3,457 / 14,586)
- **Expected After:** >= 98% (assuming flat files contain all trials)

### AUC Availability
- **Before:** total_auc all NA, cog_auc some values (coalesce bug)
- **Expected After:** Both total_auc and cog_auc populated for trials with valid baselines

### Column Hygiene
- **Before:** May have had .x/.y columns
- **Expected After:** 0 .x/.y columns (coalesced then dropped)

### Coverage by Run
- **Before:** Many runs unmatched (run 2/3/4/etc missing)
- **Expected After:** All runs should have coverage (if flat files contain them)

---

## Files Modified

1. **`scripts/make_quick_share_v7.R`** - All fixes applied
   - Lines ~97-106: normalize_keys() helper
   - Lines ~233-273: Fixed grouping in process_flat_file_v7()
   - Lines ~305-410: AUC definitions and flags
   - Lines ~548-585: Coalesce logic for .x/.y columns
   - Lines ~637-720: New QC outputs
   - Lines ~1000-1135: STOP/GO checks

---

## Next Steps

1. **Re-run the script:**
   ```bash
   Rscript scripts/make_quick_share_v7.R
   ```

2. **Check STOP/GO results:**
   - Review console output
   - Check `qc/STOP_GO_checks.csv`
   - Verify match rate >= 98%

3. **Verify outputs:**
   - `n_valid_B0` should be populated for >= 98% of trials
   - `total_auc` and `cog_auc` should have non-zero non-NA counts
   - No .x/.y columns in merged file
   - Coverage by run should show all runs

4. **If match rate still < 98%:**
   - Check `qc/06_auc_unmatched_key_patterns.csv`
   - Verify flat files contain all expected runs
   - Check if key derivation in flat files is correct

---

**All critical fixes implemented. Ready for testing.**

