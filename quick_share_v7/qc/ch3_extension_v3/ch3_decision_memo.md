# Chapter 3 Cognitive AUC Window Decision Memo

**Date**: 2025-12-26  
**Purpose**: Document the methodological decision for cognitive AUC window selection in Chapter 3 DDM analysis

---

## Recommended Cognitive Window

**Primary Window: W3.0**  
- **Time Range**: Target onset + 0.3s to Target onset + 3.3s
- **Absolute Time**: 4.65s to 7.65s (relative to squeeze onset = 0s)
- **Duration**: 3.0s

---

## Rationale for Window Selection

### 1. Temporal Constraints of the Paradigm

The dual-task paradigm combines physical effort (handgrip force) with cognitive discrimination, creating inherent temporal constraints:

- **Target stimulus onset**: 4.35s (relative to squeeze onset)
- **Physiological latency**: ~300ms (delay before measurable pupil response)
- **Earliest measurable cognitive response**: 4.35s + 0.3s = **4.65s**
- **Response window start (Resp1ST)**: **4.70s** (when "Different?" question appears)

**Critical observation**: There is only **0.05s (50ms)** between accounting for physiological latency (4.65s) and the response window starting (4.70s). This means:
- Any target-evoked TEPR will necessarily unfold **during the response window**
- The cognitive window must extend into the response period to capture the full TEPR

### 2. Empirical Evidence from Time-to-Peak Analysis

Time-to-peak analysis across all conditions shows:
- **Maximum peak time**: 2.95s post-target
- **Peak occurs at**: 4.35s + 2.95s = **7.30s**
- This peak location is **well inside** the response window (4.70-7.70s)

Therefore, if the cognitive window ends at response onset (4.70s), it would truncate the TEPR before it reaches its peak, capturing only the initial rise phase.

### 3. Window Coverage Analysis

All candidate windows have complete data coverage:
- **W1.3** (target+0.3 to target+1.3): ✓ Coverage
- **W2.0** (target+0.3 to target+2.3): ✓ Coverage  
- **W2.5** (target+0.3 to target+2.8): ✓ Coverage
- **W3.0** (target+0.3 to target+3.3): ✓ Coverage

W3.0 was selected as the **smallest window that captures the full TEPR peak** (max peak at 2.95s, window extends to 3.3s).

---

## DDM Interpretation Considerations

### Temporal Overlap with Response Period

**Important caveat**: The W3.0 cognitive window (4.65-7.65s) extends **2.95s into the response window** (which starts at 4.70s and ends at 7.70s). This means:

1. **W3.0 captures post-response time**: For trials with fast RTs (<2.95s), the cognitive AUC includes substantial post-response data
2. **Not a "pre-response predictor"**: W3.0 should be interpreted as **TEPR magnitude** during the decision/response period, not as a pure pre-response causal predictor
3. **Best described as**: "Post-target decision/response-period TEPR"

### Recommended Analysis Strategy

For DDM coupling analyses, we recommend:

1. **Primary TEPR metric**: `cog_auc_w3` (W3.0 window: target+0.3 to target+3.3s)
   - Captures the full evoked response magnitude
   - Appropriate for quantifying overall cognitive TEPR

2. **Sensitivity/robustness check**: `cog_auc_w1p3` (W1.3 window: target+0.3 to target+1.3s)
   - Early window with minimal post-response contamination
   - Ends at 5.65s, which is only 0.95s into the response window
   - Provides a more conservative estimate of pre-response cognitive processing
   - Useful for robustness checks and addressing reviewer concerns about post-response contamination

3. **Alternative metric**: `cog_mean_w1p3` (mean pupil in W1.3 window)
   - Less dependent on missing samples than AUC
   - Provides complementary information

---

## Why Response-Window Inclusion is Unavoidable

The paradigm structure makes response-window inclusion necessary for several reasons:

1. **Physiological latency**: The 300ms delay between target onset (4.35s) and measurable pupil response (4.65s) leaves minimal time before response onset (4.70s)

2. **TEPR peak location**: The pupil response peaks at ~7.30s, well within the response window, indicating that cognitive processing continues during active decision-making

3. **Task design**: The response-signal change-detection design means participants are engaged in stimulus comparison and decision-making throughout the response period, and pupil dilation reflects this ongoing cognitive load

---

## Data Quality Validation

All STOP/GO checks passed:

- ✓ Waveform data extends to 7.70s (covers full W3.0 window)
- ✓ Time-to-peak summary available with valid peak times
- ✓ Window coverage confirmed for all candidate windows
- ✓ New W1.3 features computed successfully (62.4% non-NA rate)
- ✓ Timing sanity confirmed (target onset at 4.35s as expected)
- ✓ No duplicate trial_uid

---

## Summary for Methods Section

### Cognitive AUC Window Definition

The cognitive AUC was calculated from **300ms after target stimulus onset until 3.3s post-target** (4.65s to 7.65s relative to squeeze onset), using baseline-corrected pupil data. This window (W3.0) was selected to capture the full task-evoked pupil response (TEPR) peak, which occurs at ~2.95s post-target. 

**Justification for extending into response window**: Due to the 300ms physiological latency and the response window starting only 50ms later (at 4.70s), the cognitive TEPR necessarily unfolds during the response period. The peak response occurs at ~7.30s, well within the response window, indicating that cognitive processing (stimulus comparison, decision-making) continues during active responding.

**Interpretation**: This cognitive AUC should be interpreted as **TEPR magnitude during the decision/response period**, rather than a pure pre-response predictor. For robustness, we also computed an early window (W1.3: target+0.3 to target+1.3s) that minimizes post-response contamination and serves as a sensitivity check.

### Sensitivity Analysis

To address potential concerns about post-response contamination, we computed an early cognitive window (W1.3: target+0.3 to target+1.3s) that extends only 0.95s into the response period. This provides a more conservative estimate of pre-response cognitive processing and serves as a robustness check for our primary analyses.

---

## Files Referenced

- Timing reference: `qc/ch3_timing_reference.md`
- Window recommendation: `qc/ch3_extension_v3/ch3_window_recommendation.md`
- Time-to-peak summary: `qc/ch3_extension_v3/ch3_time_to_peak_summary.csv`
- Window coverage: `qc/ch3_extension_v3/ch3_window_coverage.csv`
- STOP/GO validation: `qc/ch3_extension_v3/STOP_GO_ch3_v3.csv`

---

**Last updated**: 2025-12-26

