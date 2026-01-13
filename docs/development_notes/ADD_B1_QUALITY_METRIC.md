# Adding B1_quality Metric to Pipeline

## Overview

This document describes the changes needed to add `B1_quality` metric to the pupillometry pipeline. This metric measures the quality of the B1 baseline window (target-locked, 3.85s to 4.35s) used for Cognitive AUC baseline correction.

## Rationale

Currently, the pipeline has:
- `baseline_quality` (B0): Measures -0.5s to 0.0s baseline (used for Total AUC)
- `cog_quality`: Measures 4.65s to response onset (Cognitive AUC response window)

**Missing**: B1 baseline quality (3.85s to 4.35s) used for Cognitive AUC baseline correction.

## Changes Required

### 1. Add B1_quality calculation in `build_pupil_trial_coverage_prefilter.R`

**Location**: Line ~315 (in the analysis windows section)

**Change**: Add `valid_baseline_B1` calculation

### 2. Update gate calculations in `build_pupil_trial_coverage_prefilter.R`

**Location**: Line ~419 (gate_cog_auc calculation)

**Change**: Use `valid_baseline_B1` instead of `valid_baseline500` for cognitive AUC gates

### 3. Export B1_quality in `make_quick_share_v7.R`

**Location**: Multiple locations where quality metrics are selected/merged

**Change**: Include `B1_quality` (or `baseline_B1_quality`) in quality metric selections

### 4. Update gate calculations in `make_quick_share_v7.R`

**Location**: Lines ~1393-1397 (gate calculations)

**Change**: Add `gate_B1_60` and `gate_B1_50` flags, update `gate_pupil_primary` to use B1_quality for Cognitive AUC

### 5. Update Chapter 2 and Chapter 3 gate definitions

**Location**: Lines ~1397 and ~1453 (gate_pupil_primary and ddm_ready)

**Change**: Use B1_quality instead of baseline_quality for Cognitive AUC gates

## Optional: Rename baseline_quality to B0_quality

For clarity, consider renaming `baseline_quality` to `B0_quality` throughout the pipeline. However, this is a breaking change and should be done carefully with backward compatibility considerations.

## Files to Modify

1. `02_pupillometry_analysis/quality_control/build_pupil_trial_coverage_prefilter.R`
2. `scripts/make_quick_share_v7.R`
3. Any downstream analysis scripts that reference quality metrics

## Testing

After implementing:
1. Verify B1_quality is calculated correctly (should be ~125 samples at 250Hz for 0.5s window)
2. Verify gate calculations use correct baseline quality metrics
3. Verify merged datasets include B1_quality
4. Compare trial counts with old vs new gates
