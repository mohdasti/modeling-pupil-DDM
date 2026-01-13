# LLM Prompt: Cognitive AUC Window Selection for Dual-Task Pupillometry

**Purpose**: Get expert second opinion on cognitive AUC window implementation for Chapter 2 analyses

---

## Context: Dual-Task Paradigm with Handgrip Force and Cognitive Discrimination

I am conducting pupillometry analysis for a **dual-task paradigm** that combines physical effort (handgrip force manipulation) with cognitive discrimination. I need expert advice on the appropriate window for calculating **Cognitive AUC** that isolates task-evoked pupil response (TEPR) from physical effort effects, while ensuring reliable and interpretable AUC estimates.

---

## Experimental Paradigm: Task Structure and Timing

### Task Design Overview

The paradigm consists of two tasks:
- **ADT (Auditory Discrimination Task)**: Participants discriminate between two auditory tones
- **VDT (Visual Discrimination Task)**: Participants discriminate between two visual Gabor patches

Each trial requires participants to:
1. Maintain a handgrip force at a specified level (Low: 5% MVC or High: 40% MVC)
2. While maintaining grip, perceive and discriminate between two sequential stimuli
3. After grip release, report whether the stimuli were the same or different

### Detailed Trial Timeline (relative to squeeze onset = 0s)

| Phase | Time Window | Duration | Description |
|-------|-------------|----------|-------------|
| **ITI_Baseline** | -3.0 to 0.0s | 3.0s | Pre-trial baseline (variable ITI) |
| **Squeeze** | 0.0 to 3.0s | 3.0s | Handgrip force manipulation (grip gauge display) |
| **Post_Squeeze_Blank** | 3.0 to 3.25s | 0.25s | Blank screen after grip release |
| **Pre_Stimulus_Fixation** | 3.25 to 3.75s | 0.5s | Fixation dot display |
| **Stimulus Sequence** | 3.75 to 4.45s | 0.7s | **Standard (1st stimulus)** at 3.75s (100ms) → **ISI** 3.85-4.35s (500ms) → **Target (2nd stimulus)** at 4.35s (100ms) |
| **Post_Stimulus_Fixation** | 4.45 to 4.70s | 0.25s | Fixation dot after stimuli |
| **Response Window** | 4.70 to 7.70s | 3.0s | "Different?" response screen (participants select Same/Different) |
| **Confidence Rating** | 7.70 to 10.70s | 3.0s | Confidence rating (1-4 scale) |

**Key Timing Points:**
- **Target stimulus onset**: 4.35s (relative to squeeze onset)
- **Response window start**: 4.70s (when response prompt appears)
- **Actual response onset**: 4.70s + RT (trial-specific, when participant presses button)
- **RT range**: Typically 0.25s to 3.0s (median ~0.6-0.7s)

---

## Current Implementation: Cognitive AUC Window

### Current Approach (LEGACY - Fixed Short Window)

**Cognitive AUC Window Definition:**
- **Start**: 4.65s (target onset + 0.3s, accounting for ~300ms physiological latency)
- **End**: `min(4.35s + 1.3s, 4.70s) = 4.70s` (capped at response window start)
- **Actual Duration**: ~0.05s (50ms) - extremely short!

**Rationale for Capping at 4.70s:**
- The code uses `RESP_START_DEFAULT = 4.70s` as a fixed fallback
- The window is defined as: `cog_win_end <- min(TARGET_ONSET_DEFAULT + COG_WIN_POST_TARGET[2], RESP_START_DEFAULT)`
- Where `COG_WIN_POST_TARGET = c(0.3, 1.3)` (0.3s to 1.3s after target onset)
- This results in: `min(4.35 + 1.3, 4.70) = min(5.65, 4.70) = 4.70s`

**Current Window Characteristics:**
- **Duration**: ~0.05s (50ms) - all trials have similar duration
- **Valid samples**: ~10-15 samples (at 250 Hz sampling rate)
- **Gap metrics**: Available (cog_auc_max_gap_ms, cog_window_duration, cog_auc_n_valid, etc.)

### Problems with Current Implementation

1. **Extremely Short Window**: 50ms is far too short to capture meaningful TEPR
   - TEPR typically peaks 1-2 seconds after stimulus onset
   - 50ms window captures only the very beginning of the response
   - Cannot distinguish between different response magnitudes

2. **Fixed Duration**: Window doesn't extend to actual response onset
   - Should extend to `4.70s + RT` (trial-specific response onset)
   - Current implementation caps at 4.70s regardless of RT
   - Misses the critical period between response prompt and actual button press

3. **Insufficient Samples**: ~10-15 valid samples is too few for reliable AUC
   - Literature recommends minimum 100+ samples for robust estimates
   - At 250 Hz, a 0.5s window should have ~125 samples
   - Current window has <20 samples, making AUC estimates unreliable

4. **Cannot Apply Quality Thresholds**: 
   - `cog_window_duration >= 0.5s` threshold is not applicable (all values ~0.05s)
   - `cog_auc_n_valid >= 100` threshold is not applicable (all values ~10-15)
   - Only gap-aware exclusion (`cog_auc_max_gap_ms <= 250`) is currently usable

---

## Research Question for Chapter 2

**Primary Goal**: Examine psychometric-pupil coupling - how pupil responses relate to cognitive discrimination performance and decision-making processes.

**Key Analyses:**
- Relationship between Cognitive AUC and discrimination accuracy
- Modulation by handgrip force condition (Low vs High)
- Individual differences in pupil-cognition coupling
- Potential mediation/moderation effects

**Requirements:**
- Reliable, interpretable Cognitive AUC estimates
- Sufficient window duration to capture meaningful TEPR
- Ability to distinguish genuine low dilation from data quality artifacts
- Compatibility with gap-aware quality control metrics

---

## Alternative Approaches Under Consideration

### Option 1: RT-Dependent Window (Extend to Response Onset)

**Window Definition:**
- **Start**: 4.65s (target onset + 0.3s)
- **End**: `4.70s + RT` (trial-specific response onset)
- **Duration**: Variable, depends on RT (typically 0.5s to 3.0s)

**Advantages:**
- Captures full cognitive response period
- Window duration scales with decision time
- More samples for reliable AUC estimates
- Aligns with decision-making process (response onset marks decision completion)

**Concerns:**
- RT-dependent window introduces confound: longer RT = more time to accumulate AUC
- Need RT-normalized metrics (`cog_mean = cog_auc / window_duration`) to separate amplitude from duration
- Fast RTs (<0.3s) may still have insufficient samples
- Very slow RTs (>2.5s) may include post-decision processes

### Option 2: Fixed Post-Target Window (e.g., 0.3s to 1.3s after target)

**Window Definition:**
- **Start**: 4.65s (target onset + 0.3s)
- **End**: 5.65s (target onset + 1.3s)
- **Duration**: Fixed 1.0s

**Advantages:**
- Fixed duration eliminates RT confound
- Captures early TEPR peak (typically 0.5-1.0s after target)
- Consistent across all trials
- Sufficient samples (~250 samples at 250 Hz)

**Concerns:**
- May miss later components of TEPR
- Doesn't align with decision-making process
- Fast responders may have already responded before window ends
- May include post-response processes for slow responders

### Option 3: Fixed Pre-Response Window (e.g., 1.0s before response onset)

**Window Definition:**
- **Start**: `(4.70s + RT) - 1.0s` (1.0s before response onset)
- **End**: `4.70s + RT` (response onset)
- **Duration**: Fixed 1.0s

**Advantages:**
- Aligns with decision-making process
- Captures pre-response TEPR
- Fixed duration eliminates RT confound
- Sufficient samples

**Concerns:**
- Requires RT for each trial (missing RT = cannot calculate)
- Window position varies with RT (may miss early TEPR components)
- Fast RTs (<1.0s) may have insufficient window

### Option 4: Hybrid Approach (Multiple Windows)

**Window Definitions:**
- **Early Window**: 4.65s to 5.65s (fixed 1.0s, captures initial TEPR)
- **Decision Window**: `(4.70s + RT) - 0.5s` to `4.70s + RT` (0.5s before response, RT-dependent)
- **Full Window**: 4.65s to `4.70s + RT` (RT-dependent, full response period)

**Advantages:**
- Captures multiple components of TEPR
- Allows comparison across different time windows
- Early window is RT-independent
- Decision window aligns with decision-making

**Concerns:**
- Multiple comparisons issue
- More complex analysis
- Need to decide which window(s) to use for primary analyses

---

## Specific Questions for Expert Advice

1. **Window Duration**: What is the minimum window duration needed for reliable Cognitive AUC estimates in pupillometry? Is 0.05s (current) acceptable, or should we aim for 0.5s+ or 1.0s+?

2. **RT-Dependent vs Fixed Window**: Given our research question (psychometric-pupil coupling), should the cognitive window:
   - Extend to actual response onset (RT-dependent) to capture the full decision-making period?
   - Use a fixed post-target window to avoid RT confounds?
   - Use a hybrid approach?

3. **RT Confound**: If we use RT-dependent windows, how should we handle the mechanical coupling between RT and AUC (longer RT = more time to accumulate area)? Is RT-normalization (`cog_mean = cog_auc / window_duration`) sufficient, or are there better approaches?

4. **Quality Thresholds**: What are appropriate quality thresholds for:
   - Minimum window duration (0.3s, 0.5s, 1.0s)?
   - Minimum valid samples (75, 100, 125+)?
   - Maximum gap size (250ms, 400ms)?

5. **Best Practice Recommendations**: Based on pupillometry literature (e.g., Kret & Sjak-Shie 2019, Burg et al., Zenon et al. 2014), what is the recommended approach for:
   - Defining cognitive response windows in decision-making tasks?
   - Handling variable RTs?
   - Ensuring reliable AUC estimates?

6. **Data Quality vs Genuine Low Dilation**: How can we best distinguish between:
   - Genuine low pupil dilation (valid physiological data)
   - Data quality artifacts (missing data, large gaps, insufficient samples)?

7. **Implementation Priority**: Given our current data (4,448 trials passing quality gates), which approach would you recommend for Chapter 2 analyses, and why?

---

## Current Data Characteristics

- **Total trials**: 14,586
- **Trials passing quality gates**: 4,448 (30.5%)
- **Quality criteria**: `B1_quality >= 0.50` AND `cog_quality >= 0.60`
- **RT range**: 0.25s to 3.0s (median ~0.6-0.7s)
- **Sampling rate**: 250 Hz
- **Gap metrics available**: Yes (cog_auc_max_gap_ms, cog_window_duration, cog_auc_n_valid, etc.)
- **Current window duration**: ~0.05s (all trials)
- **Current valid samples**: ~10-15 (all trials)

---

## Constraints and Considerations

1. **Data Availability**: We have trial-specific RT data, so RT-dependent windows are feasible
2. **Missing RT**: Some trials may have missing RT - need fallback strategy
3. **Fast RTs**: Trials with RT <0.3s may have insufficient samples even with RT-dependent windows
4. **Slow RTs**: Trials with RT >2.5s may include post-decision processes
5. **Gap-Aware Metrics**: We have implemented gap-aware QC metrics and want to use them effectively
6. **Backward Compatibility**: Current analyses may depend on existing window definitions

---

## Requested Output

Please provide:

1. **Recommended Window Approach**: Which option (1-4) or alternative approach would you recommend for Chapter 2 analyses, and why?

2. **Specific Window Definition**: Exact start and end times (or formulas) for the recommended window

3. **Quality Thresholds**: Recommended minimum window duration, minimum valid samples, and maximum gap size

4. **RT Confound Handling**: How to handle RT-AUC coupling if using RT-dependent windows

5. **Implementation Guidance**: Step-by-step recommendations for implementing the recommended approach

6. **Literature Support**: Key references supporting your recommendations

7. **Trade-offs**: What are the main trade-offs of your recommended approach vs alternatives?

8. **Data Quality Strategy**: How to effectively use gap-aware metrics to distinguish genuine low dilation from artifacts

Thank you for your expert guidance on this methodological decision!
