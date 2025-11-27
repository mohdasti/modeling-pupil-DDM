# Critical Fix Applied: Figure Caption Numeric Contradiction

## Date: November 27, 2025

## Issue Identified

A critical numeric contradiction was found between two figure captions regarding the drift rate for Hard trials:

1. **Plot 1 caption** (`plot1_drift_rate_by_difficulty.png`): Stated Hard drift as **v ≈ -1.88** ❌
2. **Sanity Check 2 caption** (`sanity_check2_hard_drift.png`): Correctly stated Hard drift as **v ≈ -0.643** ✅

## Verification from Model

Checked actual model estimates:
- **Standard drift**: v = -1.230 (95% CrI: [-1.332, -1.131])
- **Hard drift**: v = -0.642 (95% CrI: [-0.737, -0.547]) ✅
- **Easy drift**: v = +0.896 (95% CrI: [0.800, 0.991]) ✅

## Why -1.88 Was Wrong

The value **-1.88** was physically impossible because:
- Standard trials (identical stimuli) have drift v = -1.23
- Hard trials (slightly different stimuli) should have **less negative** drift (closer to zero)
- **-1.88** would be more negative than Standard, implying Hard trials are "more same-like" than identical stimuli, which is impossible
- The correct value **-0.64** makes sense: less negative than Standard, but still negative (toward "Same")

## Fix Applied

Updated the caption for `plot1_drift_rate_by_difficulty.png` to reflect correct values:

**Before**:
- Standard: v ≈ -1.26
- Hard: v ≈ -1.88 ❌
- Easy: v ≈ +1.76 ❌

**After**:
- Standard: v ≈ -1.23 ✅
- Hard: v ≈ -0.64 ✅
- Easy: v ≈ +0.90 ✅

## Physical Consistency Check

All values now follow the expected pattern:
1. **Standard (Δ=0)**: Strong negative drift (v ≈ -1.23) toward "Same"
2. **Hard (small Δ)**: Less negative drift (v ≈ -0.64), still toward "Same" but weaker
3. **Easy (large Δ)**: Positive drift (v ≈ +0.90), toward "Different"

This pattern makes physical sense: as stimulus difference increases, drift moves from strongly negative (Standard) → less negative (Hard) → positive (Easy).

## Status

✅ **FIXED** - All numeric values in figure captions now match actual model estimates and are physically consistent.

---

## Expert Feedback Summary

The expert review confirmed:
- The manuscript is in **excellent shape**
- Structurally sound and scientifically rigorous
- Narrative flow is consistent
- Only issue was this numeric contradiction, which has now been fixed

**Verdict**: Ready to render! 🚀

