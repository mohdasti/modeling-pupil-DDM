# Prompt: Cognitive AUC Window Selection Dilemma in Dual-Task Pupillometry

## Context: Dual-Task Paradigm with Handgrip Force and Cognitive Discrimination

I am conducting pupillometry analysis for a **dual-task paradigm** that combines physical effort (handgrip force manipulation) with cognitive discrimination. I'm facing a methodological dilemma regarding the appropriate window for calculating **Cognitive AUC** that isolates task-evoked pupil response (TEPR) from physical effort effects.

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

Based on the MATLAB task code (`cogdisc_task_v11c_1_eyetrack_AS.m`), the trial structure is:

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

**Key Event Timestamps:**
- **Squeeze onset (TrialST)**: 0.0s (reference point)
- **Standard stimulus onset (A/V_ST)**: 3.75s (1st stimulus, 100ms duration)
- **Target stimulus onset (G2_ONST)**: 4.35s (2nd stimulus, 100ms duration)
- **Response window start (Resp1ST)**: 4.70s (when "Different?" question appears)
- **Response window end (Resp1ET)**: 7.70s (3.0s duration)

---

## Current AUC Calculation Approach

Following Zenon et al. (2014) and adapted for dual-task designs, I'm calculating two types of AUC:

### 1. Total AUC

**Definition**: Area under the curve from squeeze onset until trial-specific response onset, using **raw pupil data** (no baseline correction).

- **Start**: 0.0s (squeeze onset)
- **End**: Trial-specific response onset = 4.7s + RT (response window start + reaction time)
- **Data**: Raw pupil diameter (not baseline-corrected)
- **Interpretation**: Captures the full task-evoked pupil response including both physical (squeeze) and cognitive (stimulus discrimination) demands

**Rationale**: This captures the complete TEPR across the entire trial, including the physical effort component from the handgrip manipulation.

### 2. Cognitive AUC

**Definition**: Area under the curve from 300ms after **target stimulus onset** until trial-specific response onset, using **baseline-corrected pupil data**.

- **Start**: Target onset + 0.3s = 4.35s + 0.3s = **4.65s** (accounts for ~300ms physiological latency)
- **End**: Currently set to trial-specific response onset = 4.7s + RT
- **Data**: Baseline-corrected pupil diameter (corrected for baseline period -0.5 to 0s)
- **Interpretation**: Attempts to isolate the cognitive component of TEPR, controlling for physical effort and baseline differences

**Rationale**: The 300ms latency accounts for the delay between stimulus presentation and measurable pupil response. The window should capture the cognitive processing related to stimulus discrimination while excluding the physical effort component that occurs earlier in the trial.

---

## The Dilemma: Temporal Constraints on Cognitive AUC Window

### Problem 1: Extremely Short Window if Ending at Response Start

If Cognitive AUC ends when the response window **starts** (4.70s), we have:
- **Start**: 4.65s (target + 0.3s latency)
- **End**: 4.70s (response window start)
- **Duration**: **Only 0.05s (50ms)**

This is clearly insufficient for meaningful AUC calculation. There is essentially **no time** between accounting for physiological latency (0.3s) and the response window starting (only 0.05s later).

### Problem 2: Should Cognitive AUC Extend Into Response Window?

If we extend Cognitive AUC **into** the response window (e.g., target + 2.3s = 6.65s), we capture:
- **Start**: 4.65s (target + 0.3s latency)
- **End**: 6.65s (target + 2.3s, extending 1.95s into the 3.0s response window)
- **Duration**: 2.0s

**Arguments FOR extending into response window:**
- Cognitive processing (stimulus comparison, decision-making) continues during the response period
- Pupil dilation related to cognitive load may peak during active decision-making
- Provides sufficient duration (2.0s) for reliable AUC calculation
- Common practice in pupillometry (e.g., W2.0, W2.5, W3.0 windows extending post-stimulus)

**Arguments AGAINST extending into response window:**
- Response-related processes (motor preparation, button press) may confound cognitive TEPR
- The handgrip has been released by this point, so physical effort is no longer present
- If Total AUC ends at response onset (grip release), Cognitive AUC ending later creates an inconsistency

### Problem 3: Alignment with Total AUC

Currently, Total AUC ends at trial-specific response onset (4.7s + RT), which represents when participants **release the handgrip** and start responding. If Cognitive AUC should align with Total AUC:

- Both would end at the same time (response onset ≈ 4.7s + RT)
- But this gives Cognitive AUC only 0.05s duration (from 4.65s to 4.70s)
- This is methodologically problematic for AUC calculation

### Problem 4: The Temporal Gap Issue

The paradigm has a **very short gap** (0.25s) between:
- Target stimulus end: 4.45s
- Response window start: 4.70s

After accounting for physiological latency (0.3s), this leaves essentially no time for a "pure" cognitive window before response processes begin.

---

## Questions for Expert Consultation

1. **Is it methodologically valid to extend Cognitive AUC into the response window** (e.g., target + 2.3s = 6.65s), even though this captures response-related processes alongside cognitive processing?

2. **Should Cognitive AUC and Total AUC end at the same time** (both at response onset), even if this makes Cognitive AUC extremely short (0.05s)? Or is it acceptable to have Cognitive AUC extend longer than Total AUC?

3. **For dual-task paradigms combining physical effort with cognition**, what is the best approach to isolate cognitive TEPR? Should we:
   - Accept that cognitive and physical components cannot be fully temporally separated?
   - Use a longer window extending into response period, accepting some contamination from response processes?
   - Use a different analytical approach (e.g., contrast-based methods, modeling approaches)?

4. **Given the 250ms gap between target end (4.45s) and response start (4.70s)**, combined with the 300ms physiological latency requirement, is this paradigm structure fundamentally problematic for calculating Cognitive AUC? Or are there established methodological solutions for such temporal constraints?

5. **What is the minimum duration required for a valid Cognitive AUC window** in pupillometry? Is there a consensus on acceptable window lengths for TEPR quantification?

6. **Are there alternative approaches** to isolating cognitive TEPR in dual-task designs that might be more appropriate given these temporal constraints? For example:
   - Using contrast-based comparisons (cognitive trials vs. control trials)
   - Statistical modeling approaches that partial out physical effort effects
   - Different baseline correction strategies

---

## Current Data Characteristics

- **Sample size**: ~14,586 trials across 67 participants
- **Task conditions**: ADT and VDT, each with Low/High effort and Easy/Hard/Standard difficulty levels
- **Data availability**: Pupil data extends to 7.70s (end of response window) relative to squeeze onset
- **Current approach**: Using baseline-corrected pupil data with AUC calculated via trapezoidal integration

---

## Desired Outcome

I need expert guidance on:
1. The most methodologically sound approach to defining Cognitive AUC window in this dual-task paradigm
2. Whether extending into the response window is acceptable or problematic
3. If the current temporal structure is incompatible with Cognitive AUC calculation, what alternatives exist
4. Best practices for TEPR quantification when temporal separation of cognitive and physical components is limited

Thank you for your expertise and guidance on this methodological challenge.

