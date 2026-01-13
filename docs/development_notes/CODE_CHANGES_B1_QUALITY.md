# Code Changes to Add B1_quality Metric

## Change 1: Add B1_quality calculation in `build_pupil_trial_coverage_prefilter.R`

**File**: `02_pupillometry_analysis/quality_control/build_pupil_trial_coverage_prefilter.R`

**Location**: Around line 315-317 (in the "Analysis windows" section)

**Current code**:
```r
      # ---- Analysis windows ----
      valid_baseline500        = prop_valid_window(time, pupil, -0.5, 0.0),
      valid_total_auc_window   = prop_valid_window(time, pupil,  0.0, response_onset),
      valid_cognitive_window   = prop_valid_window(time, pupil,  4.65, response_onset),
```

**Change to**:
```r
      # ---- Analysis windows ----
      valid_baseline500        = prop_valid_window(time, pupil, -0.5, 0.0),  # B0 baseline (for Total AUC)
      valid_baseline_B1        = prop_valid_window(time, pupil, 3.85, 4.35), # B1 baseline (for Cognitive AUC)
      valid_total_auc_window   = prop_valid_window(time, pupil,  0.0, response_onset),
      valid_cognitive_window   = prop_valid_window(time, pupil,  4.65, response_onset),
```

---

## Change 2: Update gate_cog_auc to use B1 baseline

**File**: `02_pupillometry_analysis/quality_control/build_pupil_trial_coverage_prefilter.R`

**Location**: Around line 418-420 (in `add_analysis_gates` function)

**Current code**:
```r
      # Gate for cognitive AUC analyses (includes baseline for correction)
      gate_cog_auc = !is.na(valid_cognitive_window) & !is.na(valid_baseline500) &
        valid_cognitive_window >= threshold & valid_baseline500 >= threshold,
```

**Change to**:
```r
      # Gate for cognitive AUC analyses (uses B1 baseline, not B0)
      gate_cog_auc = !is.na(valid_cognitive_window) & !is.na(valid_baseline_B1) &
        valid_cognitive_window >= threshold & valid_baseline_B1 >= threshold,
```

**Note**: Keep `gate_total_auc` using `valid_baseline500` (B0) since Total AUC uses B0 baseline.

---

## Change 3: Export B1_quality in quality control export

**File**: `02_pupillometry_analysis/quality_control/build_pupil_trial_coverage_prefilter.R`

**Location**: The output CSV file (around line 850+ where trial_coverage is written)

**Note**: The `valid_baseline_B1` column will be automatically included in the output since it's part of `trial_coverage`. However, you may want to rename it for clarity when merging.

**If merging with other quality metrics**, ensure `valid_baseline_B1` is included and optionally renamed:
```r
# When merging/exporting quality metrics:
B1_quality = valid_baseline_B1,        # B1 baseline (for Cognitive AUC)
baseline_quality = valid_baseline500,  # B0 baseline (for Total AUC) - keep for backward compat
cog_quality = valid_cognitive_window,  # Cognitive response window
```

**Note**: The actual rename might happen in `make_quick_share_v7.R` when merging with the merged_v4 file. Check where `baseline_quality` and `cog_quality` come from in the merged file - they might come from MATLAB pipeline or QC export scripts.

---

## Change 3b: Ensure B1_quality is available in merged file

**Note**: The `baseline_quality` and `cog_quality` in `merged_v4` may come from:
1. MATLAB pipeline (`BAP_Pupillometry_Pipeline.m`) - exports `baseline_quality`
2. QC export scripts (e.g., `quick_qc_export.R` or `build_pupil_trial_coverage_prefilter.R`)
3. Direct calculation in merge scripts

**Action needed**: 
- If quality metrics come from MATLAB pipeline, you'll need to add B1_quality calculation there
- If they come from QC export scripts, ensure `valid_baseline_B1` is exported and renamed to `B1_quality`
- If calculated in merge scripts, add B1_quality calculation there

**Quick check**: Search for where `baseline_quality` is first created/calculated in your pipeline to determine where to add B1_quality.

---

## Change 4: Update make_quick_share_v7.R to include B1_quality

**File**: `scripts/make_quick_share_v7.R`

**Location**: Around line 1409 (where quality metrics are selected for ch2_triallevel)

**Current code**:
```r
    # MATLAB quality metrics
    any_of(c("baseline_quality", "cog_quality", "posttarget_quality", "overall_quality")),
```

**Change to**:
```r
    # MATLAB quality metrics
    any_of(c("baseline_quality", "B1_quality", "cog_quality", "posttarget_quality", "overall_quality")),
```

**Also update around line 1464** (for ch3_triallevel):
```r
    # MATLAB quality metrics
    any_of(c("baseline_quality", "B1_quality", "cog_quality", "posttarget_quality", "overall_quality")),
```

---

## Change 5: Add B1_quality gates in make_quick_share_v7.R

**File**: `scripts/make_quick_share_v7.R`

**Location**: Around line 1393-1397 (gate calculations)

**Current code**:
```r
merged_v4_with_flags <- merged_v4_with_flags %>%
  mutate(
    gate_baseline_60 = if_else(!is.na(baseline_quality), baseline_quality >= 0.60, FALSE),
    gate_cog_60 = if_else(!is.na(cog_quality), cog_quality >= 0.60, FALSE),
    gate_baseline_50 = if_else(!is.na(baseline_quality), baseline_quality >= 0.50, FALSE),
    gate_auc_both = auc_available_both,
    gate_pupil_primary = gate_baseline_60 & gate_cog_60 & gate_auc_both & found_in_flat_run
  )
```

**Change to**:
```r
merged_v4_with_flags <- merged_v4_with_flags %>%
  mutate(
    # B0 baseline gates (for Total AUC)
    gate_B0_60 = if_else(!is.na(baseline_quality), baseline_quality >= 0.60, FALSE),
    gate_B0_50 = if_else(!is.na(baseline_quality), baseline_quality >= 0.50, FALSE),
    # B1 baseline gates (for Cognitive AUC)
    gate_B1_60 = if_else(!is.na(B1_quality), B1_quality >= 0.60, FALSE),
    gate_B1_50 = if_else(!is.na(B1_quality), B1_quality >= 0.50, FALSE),
    # Cognitive response window gates
    gate_cog_60 = if_else(!is.na(cog_quality), cog_quality >= 0.60, FALSE),
    gate_cog_50 = if_else(!is.na(cog_quality), cog_quality >= 0.50, FALSE),
    # AUC availability
    gate_auc_both = auc_available_both,
    # Chapter 2 primary gate: B1 baseline + cognitive window (both at 60%)
    gate_pupil_primary = gate_B1_60 & gate_cog_60 & gate_auc_both & found_in_flat_run,
    # Backward compatibility aliases
    gate_baseline_60 = gate_B0_60,  # For Total AUC
    gate_baseline_50 = gate_B0_50   # For Total AUC
  )
```

---

## Change 6: Update Chapter 3 ddm_ready to use B1_quality

**File**: `scripts/make_quick_share_v7.R`

**Location**: Around line 1447-1455 (ddm_ready calculation)

**Current code**:
```r
ch3_triallevel <- merged_v4_with_flags %>%
  mutate(
    ddm_ready = (has_behavioral_data == TRUE | 
                 (if ("has_behavioral_data" %in% names(.)) has_behavioral_data else 
                  !is.na(rt) & !is.na(choice))) &
                !is.na(baseline_quality) & baseline_quality >= 0.50 &
                !is.na(cog_quality) & cog_quality >= 0.50 &
                !is.na(rt) & rt >= 0.2 & rt <= 3.0
  )
```

**Change to**:
```r
ch3_triallevel <- merged_v4_with_flags %>%
  mutate(
    ddm_ready = (has_behavioral_data == TRUE | 
                 (if ("has_behavioral_data" %in% names(.)) has_behavioral_data else 
                  !is.na(rt) & !is.na(choice))) &
                !is.na(B1_quality) & B1_quality >= 0.50 &  # Use B1 for Cognitive AUC
                !is.na(cog_quality) & cog_quality >= 0.50 &
                !is.na(rt) & rt >= 0.2 & rt <= 3.0
  )
```

---

## Change 7: Update gate selections in output datasets

**File**: `scripts/make_quick_share_v7.R`

**Location**: Around line 1422 (ch2_triallevel gate selections)

**Current code**:
```r
    # Gating flags
    gate_baseline_60, gate_cog_60, gate_baseline_50, gate_auc_both, gate_pupil_primary
```

**Change to**:
```r
    # Gating flags
    gate_B0_60, gate_B0_50, gate_B1_60, gate_B1_50, gate_cog_60, gate_cog_50,
    gate_auc_both, gate_pupil_primary,
    # Backward compatibility
    gate_baseline_60, gate_baseline_50
```

---

## Optional: Rename baseline_quality to B0_quality

If you want to rename `baseline_quality` to `B0_quality` for clarity:

1. **In MATLAB pipeline** (`BAP_Pupillometry_Pipeline.m`): Change `baseline_quality` to `B0_quality`
2. **In R scripts**: Replace all instances of `baseline_quality` with `B0_quality`
3. **Update documentation**: Update all references in reports and documentation

**Note**: This is a breaking change. Consider keeping both names for backward compatibility:
```r
B0_quality = baseline_quality,  # New name
baseline_quality = baseline_quality  # Keep for backward compatibility
```

---

## Testing Checklist

After implementing changes:

- [ ] Verify `B1_quality` is calculated (should be ~125 samples at 250Hz for 0.5s window)
- [ ] Verify `B1_quality` values are reasonable (0.0 to 1.0 range)
- [ ] Verify `gate_cog_auc` uses `valid_baseline_B1` instead of `valid_baseline500`
- [ ] Verify `gate_pupil_primary` uses B1 gates for Cognitive AUC
- [ ] Verify `ddm_ready` uses B1_quality
- [ ] Compare trial counts: old gates vs new gates (should see differences)
- [ ] Verify merged datasets include `B1_quality` column
- [ ] Check that existing analyses still work (backward compatibility)

---

## Summary

These changes will:
1. Add `B1_quality` metric (target-locked baseline, 3.85s-4.35s)
2. Update Cognitive AUC gates to use B1_quality instead of B0_quality
3. Keep Total AUC gates using B0_quality (correct baseline)
4. Maintain backward compatibility where possible

This creates a clean parallel structure:
- **B0_quality** (or `baseline_quality`): -0.5s to 0.0s → Total AUC baseline
- **B1_quality**: 3.85s to 4.35s → Cognitive AUC baseline  
- **cog_quality**: 4.65s to response onset → Cognitive AUC response window
