# Guide to Filtering Problematic Trials Using Gap-Aware QC Metrics

**Last Updated**: January 2026  
**Purpose**: This guide explains how to use the new gap-aware QC metrics to identify and exclude trials with problematic missing data patterns.

---

## Overview

The gap-aware QC metrics (`cog_auc_max_gap_ms`, `cog_window_duration`, `cog_auc_n_valid`, etc.) help distinguish between:
- **Genuine low pupil dilation** (valid physiological data) - **KEEP**
- **Data quality artifacts** (missing data during critical periods) - **EXCLUDE**

### Why Gap-Aware Metrics Matter

Percentage-validity thresholds (50-60%) are necessary but **not sufficient**. A trial can have 60% valid samples overall, but if there's a **large contiguous gap** (e.g., 400ms) during the peak response period, the trapezoidal AUC will bridge across that gap with a straight line, potentially underestimating or distorting the true pupil response.

**Example**: A trial with 60% valid samples might have:
- 59% valid samples in the first half of the window
- 1% valid samples in the second half (one large 400ms gap)
- Standard AUC bridges the gap → **distorted estimate**
- Gap-aware AUC doesn't bridge → **more accurate estimate**

---

## The 5 New QC Metrics

### 1. `cog_auc_max_gap_ms`
**What it is**: Maximum contiguous missing segment (milliseconds) within the cognitive window.

**How to use**:
- **≤ 150ms**: Small gaps - **KEEP** (excellent data quality)
- **150-250ms**: Moderate gaps - **KEEP** (acceptable, within threshold)
- **> 250ms**: Large gaps - **EXCLUDE** (following Kret & Sjak-Shie recommendation)
- **> 400ms**: Very large gaps - **DEFINITELY EXCLUDE**

**Rationale**: Kret & Sjak-Shie (2019) recommend not interpolating gaps >250ms. Large gaps during the peak response period can severely distort AUC estimates even when percent-valid looks acceptable.

### 2. `cog_window_duration`
**What it is**: Actual duration of the cognitive window (seconds), determined by RT.

**How to use**:
- **≥ 0.5s**: Sufficient duration - **KEEP** (stable estimates)
- **0.3-0.5s**: Short duration - **CONSIDER EXCLUDING** or flag for sensitivity analysis
- **< 0.3s**: Very short duration - **EXCLUDE** (unstable estimates, fast RTs)

**Rationale**: Short windows (fast RTs) yield less stable AUC estimates even with high quality. Minimum 0.5s recommended for primary analyses.

### 3. `cog_auc_n_valid`
**What it is**: Count of valid (non-NA) samples in the cognitive window.

**How to use**:
- **≥ 100**: Sufficient samples - **KEEP** (robust estimates)
- **75-100**: Moderate samples - **CONSIDER EXCLUDING** or flag for sensitivity analysis
- **< 75**: Insufficient samples - **EXCLUDE**

**Rationale**: At 250 Hz, a 0.5s window should have ~125 samples. With 60% validity, that's ~75 valid samples. We recommend `n_valid >= 100` for primary analyses to ensure robust estimates.

### 4. `cog_auc_n_segments`
**What it is**: Number of contiguous valid segments (1 = continuous, >1 = fragmented).

**How to use**:
- **1**: Continuous - **KEEP** (ideal)
- **2-3**: Mildly fragmented - **KEEP** (acceptable)
- **4-5**: Moderately fragmented - **CONSIDER EXCLUDING**
- **> 5**: Highly fragmented - **EXCLUDE**

**Rationale**: More segments = more fragmented sampling. Highly fragmented trials may have unreliable AUC estimates even if total valid samples are acceptable.

### 5. `cog_auc_prop_valid`
**What it is**: Proportion of valid samples (n_valid / expected_samples_at_250Hz).

**How to use**: This is redundant with `cog_quality` but useful for cross-checking. Use `cog_quality` as primary metric.

---

## Recommended Exclusion Rules

### Primary (Strict) - Chapter 2

**Use for**: Main analyses where data quality is critical.

```r
ch2_primary <- ch2_data %>%
  filter(
    # Standard quality threshold
    gate_pupil_primary == TRUE,  # OR: baseline_quality >= 0.60 & cog_quality >= 0.60
    
    # Gap-aware exclusions
    cog_auc_max_gap_ms <= 250,           # No large gaps (Kret & Sjak-Shie)
    cog_window_duration >= 0.5,            # Sufficient window duration
    cog_auc_n_valid >= 100,               # Enough valid samples
    
    # Ensure gap metrics exist (not all trials have them)
    !is.na(cog_auc_max_gap_ms),
    !is.na(cog_window_duration),
    !is.na(cog_auc_n_valid)
  )
```

**Expected retention**: ~45-50% of trials (depending on task)

### Sensitivity (Moderate)

**Use for**: Robustness checks, allows faster RTs.

```r
ch2_moderate <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    cog_auc_max_gap_ms <= 250,           # Still enforce gap threshold
    cog_window_duration >= 0.3,           # Allows faster RTs
    !is.na(cog_auc_max_gap_ms),
    !is.na(cog_window_duration)
  )
```

**Expected retention**: ~50-55% of trials

### Sensitivity (Lenient)

**Use for**: Maximum sample size, allows larger gaps.

```r
ch2_lenient <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    cog_auc_max_gap_ms <= 400,           # Allows larger gaps
    !is.na(cog_auc_max_gap_ms)
  )
```

**Expected retention**: ~55-60% of trials

---

## Handling Trials Without Gap Metrics

**Important**: Not all trials have gap-aware metrics. These metrics are only computed for trials where:
- Cognitive AUC was successfully calculated
- Sufficient valid samples exist in the cognitive window

**Strategy**:
1. **Option A (Recommended)**: Only filter trials that have gap metrics
   ```r
   ch2_clean <- ch2_data %>%
     filter(
       gate_pupil_primary == TRUE,
       # Only apply gap-aware filters if metrics exist
       is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 250,
       is.na(cog_window_duration) | cog_window_duration >= 0.5,
       is.na(cog_auc_n_valid) | cog_auc_n_valid >= 100
     )
   ```

2. **Option B (Strict)**: Only include trials with gap metrics
   ```r
   ch2_clean <- ch2_data %>%
     filter(
       gate_pupil_primary == TRUE,
       !is.na(cog_auc_max_gap_ms),      # Must have gap metrics
       cog_auc_max_gap_ms <= 250,
       cog_window_duration >= 0.5,
       cog_auc_n_valid >= 100
     )
   ```

**Recommendation**: Use Option A for primary analyses (maximizes sample size while still filtering problematic trials). Use Option B for strictest quality control.

---

## Diagnostic: Identifying Problematic Trials

### Pattern 1: High Quality + Large Gap = Data Quality Artifact

```r
problematic_large_gaps <- ch2_data %>%
  filter(
    cog_quality >= 0.60,                 # High overall quality
    cog_auc_max_gap_ms > 250,            # But large gap present
    !is.na(cog_auc_max_gap_ms)
  )
```

**Interpretation**: These trials have good overall coverage but large contiguous missing segments. The high quality is misleading - **EXCLUDE**.

### Pattern 2: Low Quality + Large Gap = Multiple Issues

```r
problematic_multiple_issues <- ch2_data %>%
  filter(
    cog_quality < 0.50,                  # Low quality
    cog_auc_max_gap_ms > 250,            # AND large gap
    !is.na(cog_auc_max_gap_ms)
  )
```

**Interpretation**: Multiple data quality issues - **DEFINITELY EXCLUDE**.

### Pattern 3: High Quality + Small Gap + Low AUC = Genuine Low Dilation

```r
genuine_low_dilation <- ch2_data %>%
  filter(
    cog_quality >= 0.60,                 # High quality
    cog_auc_max_gap_ms <= 150,          # Small gaps
    cog_auc < quantile(ch2_data$cog_auc, 0.25, na.rm = TRUE),  # Low AUC
    !is.na(cog_auc_max_gap_ms)
  )
```

**Interpretation**: These represent genuine low arousal/dilation responses with good data coverage - **KEEP** (valid physiological data).

---

## Quick Reference: Decision Tree

For each trial, ask:

1. **Does it meet quality thresholds?** (`gate_pupil_primary == TRUE`)
   - ❌ No → Exclude
   - ✅ Yes → Continue

2. **Does it have gap metrics?** (`!is.na(cog_auc_max_gap_ms)`)
   - ❌ No → Include (if using Option A) OR Exclude (if using Option B)
   - ✅ Yes → Continue

3. **Does it have acceptable gaps?** (`cog_auc_max_gap_ms <= 250`)
   - ❌ No → Exclude
   - ✅ Yes → Continue

4. **Does it have sufficient window duration?** (`cog_window_duration >= 0.5`)
   - ❌ No → Consider excluding or flag for sensitivity analysis
   - ✅ Yes → Continue

5. **Does it have enough valid samples?** (`cog_auc_n_valid >= 100`)
   - ❌ No → Consider excluding or flag for sensitivity analysis
   - ✅ Yes → **INCLUDE in primary analysis**

---

## Example: Complete Filtering Workflow

```r
library(dplyr)
library(readr)

# Load data
ch2_data <- read_csv("data/ch2_triallevel.csv", show_col_types = FALSE)

# Step 1: Check gap metric availability
cat("Trials with gap metrics:", sum(!is.na(ch2_data$cog_auc_max_gap_ms)), "\n")
cat("Trials without gap metrics:", sum(is.na(ch2_data$cog_auc_max_gap_ms)), "\n\n")

# Step 2: Apply primary exclusion rule
ch2_primary <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    # Gap-aware filters (only apply if metrics exist)
    is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 250,
    is.na(cog_window_duration) | cog_window_duration >= 0.5,
    is.na(cog_auc_n_valid) | cog_auc_n_valid >= 100
  )

cat("Primary analysis set:", nrow(ch2_primary), "trials\n")
cat("Retention rate:", sprintf("%.1f%%", 100*nrow(ch2_primary)/nrow(ch2_data)), "\n\n")

# Step 3: Diagnostic - check gap distribution
if (sum(!is.na(ch2_primary$cog_auc_max_gap_ms)) > 0) {
  gap_summary <- ch2_primary %>%
    filter(!is.na(cog_auc_max_gap_ms)) %>%
    summarise(
      n = n(),
      mean_gap = mean(cog_auc_max_gap_ms, na.rm = TRUE),
      max_gap = max(cog_auc_max_gap_ms, na.rm = TRUE),
      pct_continuous = 100 * sum(cog_auc_n_segments == 1, na.rm = TRUE) / n()
    )
  print(gap_summary)
}

# Step 4: Save filtered dataset
write_csv(ch2_primary, "data/ch2_triallevel_primary.csv")
```

---

## References

- **Kret & Sjak-Shie (2019)**: Recommend not interpolating gaps >250ms
- **Burg et al.**: Show large gaps can distort AUC even with acceptable %-valid
- **Modern Pupillometry (Papesh & Goldinger, 2024)**: Best practices for preprocessing and quality control

See `AUC_CALCULATION_METHOD.md` for full methodology and implementation details.

