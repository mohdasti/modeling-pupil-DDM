# Guide to Filtering Problematic Trials Using Gap-Aware QC Metrics

**Last Updated**: January 2026  
**Purpose**: This guide explains how to use gap-aware QC metrics to identify and exclude trials with problematic missing data patterns, following best-practice recommendations from Kret & Sjak-Shie (2019) and Burg et al.

**Key Principle**: Use RT-normalized metrics (`cog_mean`) and gap-aware quality checks to distinguish genuine low pupil dilation from data quality artifacts.

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
**What it is**: Actual duration of the cognitive window (seconds). 

**IMPORTANT NOTE**: In the current implementation, the cognitive window is a fixed 1.0s window (4.65s to 4.70s, capped at response start default), so `cog_window_duration` values are ~0.05s. This metric reflects the actual sampled window duration after accounting for data availability.

**How to use** (for future implementations with RT-dependent windows):
- **≥ 0.5s**: Sufficient duration - **KEEP** (stable estimates)
- **0.3-0.5s**: Short duration - **CONSIDER EXCLUDING** or flag for sensitivity analysis
- **< 0.3s**: Very short duration - **EXCLUDE** (unstable estimates, fast RTs)

**Rationale**: Short windows (fast RTs) yield less stable AUC estimates even with high quality. Minimum 0.5s recommended for primary analyses. **Current implementation uses fixed window, so this threshold may not be applicable.**

### 3. `cog_auc_n_valid`
**What it is**: Count of valid (non-NA) samples in the cognitive window.

**IMPORTANT NOTE**: In the current implementation, the cognitive window is a fixed short window (~0.05s), so `cog_auc_n_valid` values are typically ~10-15 samples. This metric reflects actual valid samples in the available window.

**How to use** (for future implementations with RT-dependent windows):
- **≥ 100**: Sufficient samples - **KEEP** (robust estimates)
- **75-100**: Moderate samples - **CONSIDER EXCLUDING** or flag for sensitivity analysis
- **< 75**: Insufficient samples - **EXCLUDE**

**Rationale**: At 250 Hz, a 0.5s window should have ~125 samples. With 60% validity, that's ~75 valid samples. We recommend `n_valid >= 100` for primary analyses to ensure robust estimates. **Current implementation uses fixed short window, so this threshold may not be applicable.**

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

**Recommended Exclusion Rule (Based on Literature):**

```r
# Option A (Recommended): Only filter trials that have gap metrics
ch2_primary <- ch2_data %>%
  filter(
    # Standard quality threshold: B1_quality >= 0.50 AND cog_quality >= 0.60
    gate_pupil_primary == TRUE,  # OR: B1_quality >= 0.50 & cog_quality >= 0.60
    
    # Gap-aware exclusions (only apply if metrics exist)
    is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 250           # No large gaps (Kret & Sjak-Shie)
    # Note: cog_window_duration and cog_auc_n_valid thresholds may not be applicable
    # with current fixed-window implementation. These metrics are available for
    # future use when RT-dependent windows are implemented.
  )
```

**Alternative (Option B - Strict)**: Only include trials with gap metrics:
```r
ch2_primary_strict <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    !is.na(cog_auc_max_gap_ms),      # Must have gap metrics
    cog_auc_max_gap_ms <= 250
    # Note: cog_window_duration and cog_auc_n_valid thresholds may not be applicable
    # with current fixed-window implementation
  )
```

**Rationale**: 
- Kret & Sjak-Shie recommend not interpolating gaps >250ms
- Burg et al. show large gaps can distort AUC even with acceptable %-valid
- **Note**: Window duration and n_valid thresholds are for future RT-dependent window implementations. Current implementation uses fixed short window.

**Expected retention**: Will depend on gap distribution. Primary filter is `gate_pupil_primary` (B1_50 & cog_60) + gap threshold (≤250ms).

### Sensitivity (Moderate)

**Use for**: Robustness checks, allows faster RTs.

**Rationale**: Allows shorter windows (faster RTs) but still enforces gap threshold.

```r
ch2_moderate <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,          # B1_quality >= 0.50 & cog_quality >= 0.60
    cog_auc_max_gap_ms <= 250,           # Still enforce gap threshold
    cog_window_duration >= 0.3,         # Allows faster RTs
    !is.na(cog_auc_max_gap_ms),
    !is.na(cog_window_duration)
  )
```

**Expected retention**: ~50-55% of trials

### Sensitivity (Lenient)

**Use for**: Maximum sample size, allows larger gaps.

**Rationale**: Allows larger gaps but still flags very problematic trials.

```r
ch2_lenient <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,          # B1_quality >= 0.50 & cog_quality >= 0.60
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

### Pattern 3: High Quality + Small Gap + Low RT-Normalized AUC = Genuine Low Dilation

```r
# First compute RT-normalized metric
ch2_data <- ch2_data %>%
  mutate(
    cog_mean = if_else(!is.na(cog_auc) & !is.na(cog_window_duration) & cog_window_duration > 0,
                       cog_auc / cog_window_duration,
                       NA_real_)
  )

genuine_low_dilation <- ch2_data %>%
  filter(
    cog_quality >= 0.60,                 # High quality
    cog_auc_max_gap_ms <= 150,            # Small gaps
    cog_mean < quantile(ch2_data$cog_mean, 0.25, na.rm = TRUE),  # Low RT-normalized AUC
    !is.na(cog_auc_max_gap_ms),
    !is.na(cog_mean)
  )
```

**Interpretation**: These represent genuine low arousal/dilation responses with good data coverage - **KEEP** (valid physiological data). Use RT-normalized AUC (`cog_mean`) rather than raw AUC to avoid RT-duration confounds.

---

## Quick Reference: Decision Tree

**Overall Decision Framework**

For each trial, ask:

1. **Does it meet quality thresholds?** (`gate_pupil_primary == TRUE`, which requires `B1_quality >= 0.50 AND cog_quality >= 0.60`)
   - ❌ No → Exclude
   - ✅ Yes → Continue to step 2

2. **Does it have acceptable gaps?** (`cog_auc_max_gap_ms <= 250`)
   - ❌ No → Exclude (gap-aware exclusion)
   - ✅ Yes → Continue to step 3
   - **Note**: If gap metrics are missing (`is.na(cog_auc_max_gap_ms)`), use Option A (include) or Option B (exclude) based on your strategy

3. **Does it have sufficient window duration?** (`cog_window_duration >= 0.5s`)
   - **Note**: Current implementation uses fixed short window (~0.05s), so this step may not be applicable
   - ❌ No → Consider excluding or flag for sensitivity analysis (for future RT-dependent windows)
   - ✅ Yes → Continue to step 4

4. **Does it have enough valid samples?** (`cog_auc_n_valid >= 100`)
   - **Note**: Current implementation uses fixed short window, so n_valid is typically ~10-15 samples
   - ❌ No → Consider excluding or flag for sensitivity analysis (for future RT-dependent windows)
   - ✅ Yes → **INCLUDE in primary analysis**

**Key Takeaway**: Low RT-normalized AUC (`cog_mean`) is not necessarily a problem. The diagnostic plots help distinguish:
- **Genuine low dilation** (high quality, small gaps) → **KEEP**
- **Data quality artifacts** (low quality OR large gaps) → **EXCLUDE**

---

## Example: Complete Filtering Workflow

```r
library(dplyr)
library(readr)

# Load data
ch2_data <- read_csv("data/ch2_triallevel.csv", show_col_types = FALSE)

# Step 0: Compute RT-normalized metric (if not already in data)
ch2_data <- ch2_data %>%
  mutate(
    cog_mean = if_else(!is.na(cog_auc) & !is.na(cog_window_duration) & cog_window_duration > 0,
                       cog_auc / cog_window_duration,
                       NA_real_)
  )

# Step 1: Check gap metric availability
cat("Trials with gap metrics:", sum(!is.na(ch2_data$cog_auc_max_gap_ms)), "\n")
cat("Trials without gap metrics:", sum(is.na(ch2_data$cog_auc_max_gap_ms)), "\n\n")

# Step 2: Apply primary exclusion rule (Option A - Recommended)
ch2_primary <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,           # B1_quality >= 0.50 & cog_quality >= 0.60
    # Gap-aware filters (only apply if metrics exist)
    is.na(cog_auc_max_gap_ms) | cog_auc_max_gap_ms <= 250
    # Note: cog_window_duration and cog_auc_n_valid thresholds may not be applicable
    # with current fixed-window implementation
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

# Step 4: Diagnostic - identify genuine low dilation vs data quality artifacts
genuine_low_dilation <- ch2_primary %>%
  filter(
    cog_quality >= 0.60,
    cog_auc_max_gap_ms <= 150,
    !is.na(cog_mean),
    cog_mean < quantile(ch2_primary$cog_mean, 0.25, na.rm = TRUE)
  )
cat("Genuine low dilation trials (high quality, small gap, low RT-normalized AUC):", 
    nrow(genuine_low_dilation), "\n")

data_quality_artifacts <- ch2_data %>%
  filter(
    gate_pupil_primary == TRUE,
    !is.na(cog_mean),
    cog_mean < quantile(ch2_data$cog_mean, 0.25, na.rm = TRUE),
    (cog_quality < 0.50 | (cog_auc_max_gap_ms > 250 & !is.na(cog_auc_max_gap_ms)))
  )
cat("Data quality artifacts (low quality OR large gap, low RT-normalized AUC):", 
    nrow(data_quality_artifacts), "\n\n")

# Step 5: Save filtered dataset
write_csv(ch2_primary, "data/ch2_triallevel_primary.csv")
```

---

## References

- **Kret & Sjak-Shie (2019)**: Recommend not interpolating gaps >250ms
- **Burg et al.**: Show large gaps can distort AUC even with acceptable %-valid
- **Modern Pupillometry (Papesh & Goldinger, 2024)**: Best practices for preprocessing and quality control

See `AUC_CALCULATION_METHOD.md` for full methodology and implementation details.

