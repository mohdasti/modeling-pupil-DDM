# Next Steps After Running `make_quick_share_v7.R`

**Date**: January 2026  
**Status**: After script execution - verification and analysis preparation

---

## ✅ What's Done

1. **Primary cognitive window updated**: 4.85-6.05s (1.20s fixed window)
2. **Mean dilation computed**: `cog_mean = cog_auc / window_duration`
3. **Motor buffer definitions**: Window truncation flags computed
4. **Pre-response window definitions**: Decision-aligned window flags computed
5. **Quality thresholds updated**: Expert-recommended thresholds (n_valid ≥ 240, duration ≥ 0.90s)

---

## 📋 Immediate Next Steps

### 1. Verify Outputs

**Check data files:**
```r
library(readr)
library(dplyr)

# Load Chapter 2 data
ch2 <- read_csv("data/ch2_triallevel.csv", show_col_types = FALSE)

# Verify new columns exist
cat("New columns present:\n")
cat("  cog_mean:", "cog_mean" %in% names(ch2), "\n")
cat("  cog_win_primary_end_motorbuffered:", "cog_win_primary_end_motorbuffered" %in% names(ch2), "\n")
cat("  cog_win_preresp_start:", "cog_win_preresp_start" %in% names(ch2), "\n")

# Check primary window statistics
cat("\nPrimary window statistics:\n")
ch2 %>% 
  filter(!is.na(cog_window_duration)) %>%
  summarise(
    n = n(),
    mean_duration = mean(cog_window_duration, na.rm = TRUE),
    mean_n_valid = mean(cog_auc_n_valid, na.rm = TRUE),
    pct_truncated = 100 * mean(cog_win_truncated_by_motor == TRUE, na.rm = TRUE)
  ) %>%
  print()
```

**Expected results:**
- `cog_window_duration` should be ~1.20s (fixed window)
- `cog_auc_n_valid` should be ~300 samples (at 250 Hz)
- `cog_mean` should be computed for all trials with `cog_auc`

### 2. Update Your Analysis Scripts

**Switch to new primary metric:**
```r
# OLD (deprecated):
# cog_auc from 50ms window

# NEW (recommended):
# cog_mean from 1.20s window (4.85-6.05s)
ch2_primary <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 250,
    is.na(cog_window_duration) | cog_window_duration >= 0.90,
    is.na(cog_auc_n_valid) | cog_auc_n_valid >= 240
  ) %>%
  # Use mean dilation (preferred)
  mutate(
    pupil_metric = cog_mean  # Instead of cog_auc
  )
```

### 3. Apply Confound Mitigation Strategies

**Option A: Motor-Buffered Window (if AUC computed)**
```r
# Prefer non-truncated, or truncated with sufficient duration
ch2_clean <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    # Prefer non-truncated, or truncated with sufficient duration
    is.na(cog_win_truncated_by_motor) | 
    (cog_win_truncated_by_motor == TRUE & cog_window_duration >= 0.60),
    cog_auc_n_valid >= 150,  # After truncation
    cog_auc_max_gap_ms <= 250
  )
```

**Option B: Slow-RT Sensitivity Subset**
```r
# Test on trials where motor can't contaminate
ch2_slow_rt <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    cog_win_uncontaminated_by_motor == TRUE,  # Slow RT trials
    cog_window_duration >= 0.90,
    cog_auc_n_valid >= 240,
    cog_auc_max_gap_ms <= 250
  )
```

**Option C: Include RT as Covariate**
```r
# Always include RT in models
model <- lmer(
  behavior ~ cog_mean + rt + condition + cog_mean:condition + (1|sub),
  data = ch2_primary
)
```

---

## 📝 For Chapter 2: Documentation Status

**All documentation is in `chapter2_materials/`:**

✅ **Core Documentation:**
- `docs/COGNITIVE_AUC_WINDOW_IMPLEMENTATION.md` - Window implementation details
- `docs/CONFOUND_MITIGATION_STRATEGY.md` - Comprehensive confound mitigation guide
- `docs/AUC_CALCULATION_METHOD.md` - Updated with new windows
- `docs/FILTERING_GUIDE.md` - Updated with new thresholds
- `IMPLEMENTATION_SUMMARY.md` - Quick reference
- `CONFOUND_MITIGATION_SUMMARY.md` - Confound mitigation summary

✅ **Data Files:**
- `data/ch2_triallevel.csv` - Contains all new columns

✅ **Scripts:**
- `scripts/make_quick_share_v7.R` - Updated with new windows

**You're ready to copy `chapter2_materials/` to your Chapter 2 project directory!**

---

## ⚠️ For Chapter 3: Confound Mitigation Needed

**Chapter 3 uses different windows:**
- **W3.0**: 4.65s to 7.65s (target+0.3 to target+3.3s) - **Primary**
- **W1.3**: 4.65s to 5.65s (target+0.3 to target+1.3s) - **Sensitivity**

**Same confound issues apply:**
- Response screen at 4.70s (overlaps with both windows)
- Button press variable (overlaps with W3.0 for many trials)

**Recommendations for Chapter 3:**
1. **Motor buffer for W3.0**: Truncate at `t_resp - 0.15s` (same as Chapter 2)
2. **W1.3 is already conservative**: Ends at 5.65s, minimal post-response contamination
3. **Include RT as covariate**: Same as Chapter 2
4. **Sensitivity**: Compare W3.0 vs W1.3 to show robustness

**Status**: Motor buffer columns are already in `ch3_triallevel.csv`. Need to:
- Update Chapter 3 documentation in main repo
- Consider motor-buffered W3.0 window computation
- Update `chap3_ddm_results.qmd` to mention confound mitigation

---

## 🔄 Full AUC Computation for Motor-Buffered Windows

**Current Status**: Window definitions computed, but full AUC requires re-processing flat files with RT.

**When needed**, create a separate script:
```r
# compute_motorbuffered_auc.R
# Re-process flat files with RT to compute:
# - cog_auc_motorbuffered (truncated at t_resp - 0.15s)
# - cog_auc_preresp (pre-response window AUC)
```

**For now**: Use existing `cog_auc` (full 1.20s window) with RT as covariate, or use slow-RT subset for sensitivity.

---

## 📊 Analysis Workflow

### Step 1: Primary Analysis
```r
ch2_primary <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 250,
    is.na(cog_window_duration) | cog_window_duration >= 0.90,
    is.na(cog_auc_n_valid) | cog_auc_n_valid >= 240
  )

# Use cog_mean as primary metric
model_primary <- lmer(
  behavior ~ cog_mean + rt + condition + (1|sub),
  data = ch2_primary
)
```

### Step 2: Sensitivity Analysis
```r
# Slow-RT subset (uncontaminated by motor)
ch2_slow_rt <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    cog_win_uncontaminated_by_motor == TRUE,
    cog_window_duration >= 0.90,
    cog_auc_n_valid >= 240,
    cog_auc_max_gap_ms <= 250
  )

model_slow_rt <- lmer(
  behavior ~ cog_mean + rt + condition + (1|sub),
  data = ch2_slow_rt
)
```

### Step 3: Report Results
- Primary analysis with full dataset
- Sensitivity analysis with slow-RT subset
- Note: RT included as covariate in all models
- Mention: Motor buffer truncation available for future analyses

---

## ❓ Questions?

- **Window too short?**: Primary window is 1.20s (fixed) - should be sufficient
- **Missing motor-buffered AUC?**: Use existing `cog_auc` with RT covariate, or slow-RT subset
- **Quality thresholds too strict?**: Start with expert recommendations; relax only if power severely impacted
- **Chapter 3 updates?**: See main repo for Chapter 3-specific documentation updates

---

**Last Updated**: January 2026  
**Ready for**: Chapter 2 analysis preparation
