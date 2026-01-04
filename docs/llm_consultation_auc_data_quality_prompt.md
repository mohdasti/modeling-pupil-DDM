# LLM Consultation: Distinguishing Low AUC from Poor Data Quality in Pupillometry

## Context and Research Background

I am conducting a pupillometry study as part of my dissertation research. The study examines how physical effort (handgrip force manipulation) and cognitive task difficulty interact to affect pupil-indexed arousal and decision-making in older adults. I have collected pupil data from multiple participants across two tasks (Auditory Discrimination Task, ADT; Visual Discrimination Task, VDT) and need to ensure my data quality assessments are appropriate before proceeding with analyses.

## Study Design and Data Collection

**Participants**: Older adults (age 60+)
**Tasks**: 
- ADT (Auditory Discrimination Task): Participants discriminate between auditory tones
- VDT (Visual Discrimination Task): Participants discriminate between visual stimuli

**Trial Structure** (time relative to squeeze onset = 0.0s):
- **-0.5s to 0s**: Baseline window (B₀) - used for baseline correction
- **0s to 3.0s**: Handgrip force manipulation (Low: 5% MVC, High: 40% MVC)
- **3.75s to 4.45s**: Stimulus presentation (Standard + Target, varying in difficulty)
- **4.35s**: Target stimulus onset (the stimulus that varies in intensity)
- **4.7s + RT**: Response onset (trial-specific reaction time)

**Data Quality Metrics Available**:
- `baseline_quality`: Proportion of valid (non-missing) samples in baseline window (-0.5s to 0s)
- `cog_quality`: Proportion of valid samples in cognitive window (4.65s to response onset)
- Both metrics range from 0.0 (all missing) to 1.0 (all valid)

## Pupil Metrics: Total AUC and Cognitive AUC

I am using two Area Under the Curve (AUC) metrics following Zenon et al. (2014):

### 1. Total AUC
- **Definition**: Area under the curve from trial onset (0s) until trial-specific response onset
- **Data**: Raw pupil diameter (NO baseline correction)
- **Window**: 0s to (4.7s + RT)
- **Interpretation**: Captures full task-evoked pupil response including both physical (squeeze) and cognitive (stimulus discrimination) demands
- **Calculation**: Trapezoidal integration of raw pupil values

### 2. Cognitive AUC
- **Definition**: Area under the curve from 300ms after target stimulus onset until response onset
- **Data**: Baseline-corrected pupil (`pupil_isolated = pupil - baseline_B0`)
- **Window**: 4.65s (4.35s + 0.3s latency) to (4.7s + RT)
- **Baseline Correction**: Uses mean pupil from -0.5s to 0s window (B₀)
- **Interpretation**: Isolates cognitive component of TEPR, controlling for physical effort and baseline differences
- **Calculation**: Trapezoidal integration of baseline-corrected pupil values

**AUC Calculation Requirements**:
- Requires at least 2 valid (non-NA) samples in the window
- Missing samples (NaN) are excluded from integration
- If too few valid samples, AUC = NA

## The Core Concern

**My primary concern**: When I observe low AUC values (either Total AUC or Cognitive AUC) for a participant, I need to distinguish between two scenarios:

1. **Low AUC due to poor data quality**: Many missing samples in the AUC calculation window, leading to incomplete or unreliable AUC values
2. **Low AUC due to genuine low pupil dilation**: Participant genuinely shows minimal pupil dilation response, but data quality is adequate

This distinction is critical because:
- If low AUC reflects poor data quality, I should exclude or flag those trials/participants
- If low AUC reflects genuine low dilation, this is valid physiological data that should be included in analyses
- Misclassifying one as the other could bias my results or lead to inappropriate exclusions

## Current Data Available

I have trial-level data with the following variables for each trial:

**AUC Metrics**:
- `total_auc`: Total AUC value (can be NA if insufficient valid samples)
- `cog_auc`: Cognitive AUC value (can be NA if insufficient valid samples)
- `auc_available`: Boolean flag indicating if both AUCs are available
- `auc_missing_reason`: Reason for missing AUC (e.g., "ok", "cog_auc_failed", "insufficient_samples")

**Quality Metrics**:
- `baseline_quality`: Proportion valid in baseline window (0.0 to 1.0)
- `cog_quality`: Proportion valid in cognitive window (0.0 to 1.0)
- `overall_quality`: Overall proportion valid across trial
- `n_valid_B0`: Number of valid samples in baseline window
- `n_valid_b0`: Number of valid samples in baseline window (alternative name)

**Trial Information**:
- `sub`: Participant ID
- `task`: Task type (ADT or VDT)
- `trial_index`: Trial number
- `effort`: Effort condition (Low or High)
- `stimulus_intensity`: Stimulus difficulty level
- `rt`: Reaction time

**Sample-Level Data** (available but not currently in report):
- Raw flat files (`*_flat.csv`) with sample-level pupil data (250 Hz sampling rate)
- Each file contains time series data with pupil diameter at each time point
- Can be used to generate waveform plots if needed

## Current Approach in Report

I have created a "Participant-Level Data Quality Supplement" section that includes:

1. **Summary Plot**: Mean AUC values (Total and Cognitive) by participant-task combination
   - Helps identify participants with consistently low AUC across trials

2. **Detailed Plots** (for each participant-task combination):
   - **AUC Barplot**: Total AUC and Cognitive AUC values across individual trials
   - **Quality Summary**: 
     - Number of trials
     - Number of trials with AUC available
     - Mean baseline quality and cognitive quality
     - Data quality label (High/Moderate/Low based on quality thresholds)

3. **Interpretation Guidelines**:
   - Low AUC + Low Quality → Likely data quality issue
   - Low AUC + High Quality → Likely genuine low dilation
   - Mixed quality → Consider excluding low-quality trials

## Questions for Consultation

1. **Is AUC the right metric for this concern?**
   - Are Total AUC and/or Cognitive AUC appropriate for distinguishing data quality issues from genuine low dilation?
   - Should I be using different metrics (e.g., peak dilation, mean dilation, slope) instead of or in addition to AUC?
   - Are there better ways to quantify pupil responses that are less sensitive to missing data?

2. **What visualizations/analyses would best address this concern?**
   - I currently show AUC barplots with quality metrics. Is this sufficient?
   - Should I include waveform plots for each participant? (These would require processing sample-level data)
   - Are there other diagnostic plots or metrics I should consider?

3. **How should I interpret the relationship between quality metrics and AUC?**
   - What threshold of `baseline_quality` or `cog_quality` indicates "adequate" data quality for reliable AUC calculation?
   - How does missing data affect AUC calculation? (e.g., if 30% of samples are missing, how reliable is the AUC?)
   - Should I exclude trials/participants based on quality metrics alone, or only when quality is low AND AUC is low?

4. **Best practices for handling this in the report?**
   - Should I create individual plots for ALL participant-task combinations, or is a summary sufficient?
   - What information should I present to my advisor to demonstrate I've adequately addressed this concern?
   - Are there standard approaches in the pupillometry literature for this type of data quality assessment?

5. **Statistical considerations:**
   - Should I test for correlations between quality metrics and AUC values?
   - Are there formal statistical tests to distinguish "low AUC due to quality" from "low AUC due to low dilation"?
   - How should I handle participants with mixed quality (some high-quality trials, some low-quality trials)?

## Additional Context

**Current Quality Thresholds Used**:
- Chapter 2 analyses: Require `baseline_quality >= 0.60` AND `cog_quality >= 0.60`
- Chapter 3 analyses: Require `baseline_quality >= 0.50` AND `cog_quality >= 0.50`

**Data Characteristics**:
- Older adult population (may have higher rates of missing data due to blinks, head movements)
- Dual-task design (physical effort + cognitive task) may increase missing data
- Sample rate: 250 Hz (downsampled from higher rate)
- Typical trial duration: ~5-8 seconds (depending on RT)

**Report Audience**:
- Primary: PhD advisor (needs to approve data quality and analysis plan)
- Secondary: Dissertation committee, peer reviewers
- Report should be standalone and self-explanatory

## What I Need

I need expert guidance on:
1. Whether my current approach (AUC barplots + quality metrics) adequately addresses the concern
2. Whether I should add waveform plots or other visualizations
3. Best practices for interpreting and reporting this type of data quality assessment
4. Recommendations for handling participants/trials where the distinction is unclear

Please provide specific, actionable recommendations based on pupillometry best practices and statistical considerations.

