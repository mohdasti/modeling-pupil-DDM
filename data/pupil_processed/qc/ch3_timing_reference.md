# Chapter 3 Timing Reference

This document provides authoritative timing definitions for Chapter 3 pupillometry analysis, extracted from MATLAB task code and timestamp documentation.

## Time Reference Point

All times are **relative to squeeze onset (TrialST) = 0.0s**.

**TrialST**: Screen flip onset for the grip gauge display (handgrip force feedback screen). This is the reference point (t = 0) for all trial-relative timestamps.

---

## Key Event Timestamps

### Standard Stimulus Onset (1st Stimulus)

- **Timestamp Name**: `A/V_ST`
- **Definition**: Screen flip onset that coincides with stimulus pair onset
  - **ADT (Auditory)**: Audio playback start
  - **VDT (Visual)**: Gabor 1 (G1) display onset
- **Expected Time**: **3.75s** relative to squeeze onset
- **Duration**: 100ms
- **Column in merged data**: `stim1_onset_rel` or `A_V_ST - TrialST`

---

### Target Stimulus Onset (2nd Stimulus)

- **Timestamp Name**: `G2_ONST` (for VDT) or `A/V_ST + 0.6s` (for ADT)
- **Definition**: 
  - **VDT**: Screen flip onset for Gabor 2 (G2) display (the target stimulus that varies in intensity)
  - **ADT**: Standard onset + 0.6s (where 0.6s = Standard 100ms + ISI 500ms)
- **Expected Time**: **4.35s** relative to squeeze onset
- **Duration**: 100ms
- **Calculation**: 
  - VDT: `G2_ONST - TrialST`
  - ADT: `(A/V_ST - TrialST) + 0.6` or `stim1_onset_rel + 0.6`
- **Column in merged data**: `t_target_onset_rel` or `target_onset_rel`

---

### Response Window Start

- **Timestamp Name**: `Resp1ST`
- **Definition**: Screen flip onset for the Response 1 screen ("Different?" question with Yes/No buttons)
- **Expected Time**: **4.70s** relative to squeeze onset
- **Duration**: 3.0s (fixed)
- **Column in merged data**: `t_resp_start_rel` or `resp_start_rel`

**Note**: This is when participants see the response prompt and can begin making their Same/Different choice.

---

### Response Window End

- **Timestamp Name**: `Resp1ET`
- **Definition**: Screen flip offset that ends the Response 1 window (canonical end time after Resp1_Duration, not the actual keypress time)
- **Expected Time**: **7.70s** relative to squeeze onset (Resp1ST + 3.0s)
- **Column in merged data**: May not be directly available; calculated as `Resp1ST + 3.0` or `t_resp_start_rel + 3.0`

**Note**: This is the canonical end of the response window, not the actual button press time.

---

## Reaction Time (RT) Measurement

- **RT Definition**: Time from response window start (Resp1ST) to button press
- **Calculation**: `RT = ButtonRT` (where ButtonRT is measured relative to Resp1ST)
- **Column in merged data**: `rt` or `resp1RT`
- **Range**: Typically 0.25s to 3.0s (trial-specific)
- **Actual Response Onset**: `Resp1ST + RT = 4.70s + RT`

**For Total AUC and Cognitive AUC calculations:**
- Trial-specific response onset = `4.70s + RT` (when participant actually presses button)
- If RT is missing/NA, fallback to `4.70s` (response window start)

---

## Complete Trial Timeline

| Phase | Time Window | Duration | Description |
|-------|-------------|----------|-------------|
| ITI_Baseline | -3.0 to 0.0s | 3.0s | Pre-trial baseline (variable ITI) |
| Squeeze | 0.0 to 3.0s | 3.0s | Handgrip force manipulation (grip gauge display) |
| Post_Squeeze_Blank | 3.0 to 3.25s | 0.25s | Blank screen after grip release |
| Pre_Stimulus_Fixation | 3.25 to 3.75s | 0.5s | Fixation dot display |
| **Standard (1st stimulus)** | 3.75 to 3.85s | 0.1s | Standard stimulus (A/V_ST) |
| **ISI** | 3.85 to 4.35s | 0.5s | Inter-stimulus interval |
| **Target (2nd stimulus)** | 4.35 to 4.45s | 0.1s | Target stimulus (G2_ONST) |
| Post_Stimulus_Fixation | 4.45 to 4.70s | 0.25s | Fixation dot after stimuli |
| **Response Window** | 4.70 to 7.70s | 3.0s | "Different?" response screen (Resp1ST to Resp1ET) |
| Confidence Rating | 7.70 to 10.70s | 3.0s | Confidence rating (1-4 scale) |

---

## Implications for Cognitive AUC Windows

Given the timing structure:

1. **Target stimulus onset**: 4.35s
2. **Physiological latency**: ~300ms
3. **Cognitive window start**: 4.35s + 0.3s = **4.65s**
4. **Response window start**: **4.70s**

**Critical observation**: There is only **0.05s (50ms)** between accounting for physiological latency and the response window starting. This means:
- Any target-evoked TEPR will necessarily unfold **during the response window**
- Cognitive AUC windows must extend into the response period to capture the full TEPR
- The peak TEPR (time-to-peak ≈ 2.94s post-target) occurs around **7.29s**, which is **inside** the response window

**Recommended windows:**
- **W1.3**: target+0.3 → target+1.3 = 4.65 → 5.95s (early cognitive, minimal post-response)
- **W2.0**: target+0.3 → target+2.3 = 4.65 → 6.65s (extends into response)
- **W3.0**: target+0.3 → target+3.3 = 4.65 → 7.65s (captures full TEPR peak, extends deep into response)
- **RespWin**: target+0.3 → Resp1ET = 4.65 → 7.70s (full response window)

---

## Data Sources

This timing reference is based on:
- MATLAB task code: `cogdisc_task_v11c_1_eyetrack_AS.m`
- Timestamp definitions: `02_pupillometry_analysis/TIMESTAMP_DEFINITIONS.md`
- Task log mapping: `02_pupillometry_analysis/TASK_LOG_COLUMN_MAPPING.md`
- MATLAB pipeline: `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m`

**Last updated**: 2025-12-26

