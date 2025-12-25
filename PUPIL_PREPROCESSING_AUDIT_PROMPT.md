# Comprehensive Pupil Data Preprocessing Audit Prompt

## INSTRUCTIONS FOR AUDITING LLM

You are tasked with conducting a critical scientific audit of a pupillometry data preprocessing pipeline. Your goal is to evaluate each preprocessing step against established best practices and literature standards, providing either a **GREEN FLAG** (acceptable/scientifically valid) or **RED FLAG** (problematic/needs revision) for each step, along with specific recommendations and APA-cited justifications.

**Context**: The researchers are concerned that their valid trial rates (currently reporting 95.2% overall, with individual files showing 30-100% merge rates) may be inflated due to overly lenient preprocessing criteria. They need a rigorous, literature-based assessment.

---

## PIPELINE OVERVIEW

The preprocessing pipeline processes pupillometry data collected during a cognitive effort task with the following structure:

**Experimental Paradigm:**
- 8-phase trial structure: ITI_Baseline → Squeeze (3s) → Post_Squeeze_Blank (250ms) → Pre_Stimulus_Fixation (500ms) → Stimulus (700ms) → Post_Stimulus_Fixation (250ms) → Response_Different (3s) → Confidence (3s)
- Total trial duration: ~13.7 seconds (3s baseline + 10.7s post-squeeze)
- Sampling rate: 2000 Hz original, downsampled to 250 Hz
- Data collection: MRI-compatible TRACKPixx binocular eye tracker
- Expected trials per run: ~30 trials
- Expected runs per session: 5 runs

**Pipeline Flow:**
1. Initial cleaning (external tool, creates `*_cleaned.mat` files)
2. MATLAB pipeline: Trial extraction, phase labeling, quality assessment, downsampling
3. R merger: Integration with behavioral data
4. Output: `*_flat_merged.csv` files with pupillometry + behavioral data

**Data Structure - Cleaned .mat Files:**
```matlab
cleaned_data.S.data.sample      % Pupil diameter (arbitrary units, typically pixels)
cleaned_data.S.data.smp_timestamp % Timestamps (seconds, relative to recording start)
cleaned_data.S.data.valid        % Binary validity flag (1 = valid, 0 = invalid/blink/missing)
```

**Data Structure - Behavioral Data:**
```r
# From bap_beh_trialdata_v2.csv
subject_id        # Participant ID (e.g., "BAP003")
task_modality     # "aud" or "vis" (maps to "ADT" or "VDT")
run_num           # Run number (1-5)
trial_num         # Trial number within run (1-30)
same_diff_resp_secs  # Reaction time (seconds)
resp_is_correct   # Accuracy (0/1)
stim_level_index  # Stimulus difficulty level
stim_is_diff      # Oddball status (0/1)
grip_targ_prop_mvc # Grip force target (0.05 or 0.40)
```

**Data Structure - Final Merged Output:**
```r
# Columns in *_flat_merged.csv files:
sub, task, run, trial_index, trial_label, time, pupil, 
has_behavioral_data, baseline_quality, trial_quality, overall_quality,
stimLev, isOddball, iscorr, resp1RT, gf_trPer, force_condition, stimulus_condition
```

**Current Results Summary:**
- Total processed files: 59 subject-task combinations
- Total trials: 3,107 trials
- Reported valid trial rate: 95.2%
- Behavioral merge rate: 97.2% (mean)
- Merge rate range: 30.1% to 100%

---

## STEP 1: INITIAL CLEANING (Pre-Pipeline)

### Technical Details

**Tool Used**: ET-remove-artifacts MATLAB toolbox (Huang et al., 2020)

**Process Description** (from `PUPIL_PREPROCESSING_METHODS.md`):
- Blink detection: Velocity-based algorithm using filtered derivative of pupil signal
- Filter: 100th-order low-pass filter (passband: 10 Hz, stopband: 12 Hz)
- Detection threshold: Peak/trough threshold factors of 5 standard deviations above baseline
- Artifact handling: Artifacts >2 seconds replaced with missing values (not interpolated)
- Manual inspection: All recordings manually inspected and edited using interactive plot editor
- Interpolation: Cubic spline interpolation for detected blinks (method not specified in detail)

**Output**: `*_cleaned.mat` files containing:
- `S.data.sample`: Pupil diameter values
- `S.data.smp_timestamp`: Timestamps
- `S.data.valid`: Binary validity flag (1 = valid, 0 = invalid/missing)

### Code Reference
```matlab
% From BAP_Pupillometry_Pipeline.m lines 357-360
pupil = cleaned_data.S.data.sample;
timestamps = cleaned_data.S.data.smp_timestamp;
valid = cleaned_data.S.data.valid;
```

### Literature Standards to Evaluate Against

**Blink Detection:**
- Mathôt (2018): Recommends velocity-based detection with thresholds typically 2-3 SD, not 5 SD
- Kret & Sjak-Shie (2019): Suggests velocity thresholds of 800-1200 pixels/sample for Eyelink systems
- Hershman et al. (2019): Warns against overly conservative thresholds that may miss blinks

**Interpolation:**
- Mathôt et al. (2018): Recommends linear or cubic spline interpolation for gaps <150ms
- Kret & Sjak-Shie (2019): Suggests maximum interpolatable gap of 200-300ms
- Hershman et al. (2019): Warns against interpolating gaps >500ms
- **CRITICAL**: No explicit mention of maximum gap size in current pipeline

**Manual Editing:**
- Mathôt (2018): Recommends automated preprocessing with minimal manual intervention to avoid bias
- Kret & Sjak-Shie (2019): Suggests manual inspection only for quality control, not primary cleaning

### Audit Questions for Step 1:
1. Is the 5 SD threshold for blink detection too conservative (may miss blinks) or appropriate?
2. Is cubic spline interpolation appropriate for all detected blinks, regardless of gap size?
3. Does the 2-second threshold for missing values (vs interpolation) align with literature?
4. Is the manual editing step introducing potential bias or necessary quality control?

**Provide**: GREEN FLAG or RED FLAG with specific recommendations and citations.

---

## STEP 2: TRIAL EXTRACTION AND WINDOWING

### Technical Details

**Trial Definition** (from `BAP_Pupillometry_Pipeline.m` lines 394-396):
```matlab
trial_start_time = squeeze_time - 3.0;  % 3s before squeeze (baseline)
trial_end_time = squeeze_time + 10.7;   % 10.7s after squeeze (trial end)
```

**Trial Detection** (lines 378-385):
```matlab
% Find squeeze onsets to define trial boundaries
squeeze_onsets = transition_times(transition_from == CONFIG.event_codes.baseline & ...
                                 transition_to == CONFIG.event_codes.squeeze_start);
```

**Minimum Sample Requirement** (lines 401-403):
```matlab
if sum(trial_mask) < CONFIG.quality.min_samples_per_trial
    continue;  % Skip trial
end
```
Where `CONFIG.quality.min_samples_per_trial = 100` (line 67)

**Calculation**:
- At 2000 Hz: 100 samples = 50ms minimum
- At 250 Hz (downsampled): 100 samples = 400ms minimum
- Trial duration: 13.7 seconds
- Expected samples at 2000 Hz: ~27,400 samples
- Expected samples at 250 Hz: ~3,425 samples

### Literature Standards

**Baseline Window:**
- Mathôt (2018): Recommends 200-1000ms baseline windows
- Kret & Sjak-Shie (2019): Suggests 500-2000ms for cognitive tasks
- **CURRENT**: 3000ms baseline - longer than typical but acceptable for effort tasks

**Trial Window:**
- Mathôt et al. (2018): Typical analysis windows 0-2000ms post-stimulus
- **CURRENT**: 10.7s post-squeeze includes full response period - appropriate for effort tasks

**Minimum Sample Threshold:**
- No explicit literature standard, but 100 samples at 2000 Hz (50ms) seems very lenient
- Typical: Require at least 50-80% of expected samples

### Audit Questions for Step 2:
1. Is the 3-second baseline window appropriate or excessive?
2. Is the 100-sample minimum threshold too lenient (allows trials with <0.4% of expected data)?
3. Should there be a maximum trial duration check to prevent overlap?

**Provide**: GREEN FLAG or RED FLAG with recommendations.

---

## STEP 3: PHASE LABELING

### Technical Details

**Phase Labeling Logic** (from `BAP_Pupillometry_Pipeline.m` lines 497-547):
```matlab
function phase_labels = create_correct_phase_labels(trial_times, squeeze_time, ...
    event_times, event_from, event_to, CONFIG)

% Initialize all as ITI baseline
phase_labels = cell(length(trial_times), 1);
phase_labels(:) = {'ITI_Baseline'};

% Apply phase labels based on EXACT 8-phase paradigm timing
for i = 1:length(trial_times)
    t = trial_times(i);
    time_rel = t - squeeze_time;  % Relative to squeeze onset
    
    if time_rel < 0
        phase_labels{i} = 'ITI_Baseline';
    elseif time_rel >= 0 && time_rel < 3.0
        phase_labels{i} = 'Squeeze';
    elseif time_rel >= 3.0 && time_rel < 3.25
        phase_labels{i} = 'Post_Squeeze_Blank';
    elseif time_rel >= 3.25 && time_rel < 3.75
        phase_labels{i} = 'Pre_Stimulus_Fixation';
    elseif time_rel >= 3.75 && time_rel < 4.45
        phase_labels{i} = 'Stimulus';
    elseif time_rel >= 4.45 && time_rel < 4.7
        phase_labels{i} = 'Post_Stimulus_Fixation';
    elseif time_rel >= 4.7 && time_rel < 7.7
        phase_labels{i} = 'Response_Different';
    elseif time_rel >= 7.7 && time_rel <= 10.7
        phase_labels{i} = 'Confidence';
    else
        phase_labels{i} = 'ITI_Baseline';
    end
end
```

**Key Issue**: Phase labeling is based **entirely on time windows**, not on actual event markers. The function receives `event_times`, `event_from`, `event_to` but **does not use them** for phase assignment.

### Literature Standards

**Event-Based vs Time-Based Labeling:**
- Mathôt (2018): Recommends using actual event markers when available
- Kret & Sjak-Shie (2019): Time-based labeling acceptable if event markers unreliable, but should validate against events
- **CURRENT**: Pure time-based, no validation against events

### Audit Questions for Step 3:
1. Is time-based phase labeling acceptable, or should it validate against event markers?
2. Should there be checks to ensure events align with expected time windows?
3. What happens if events are misaligned (e.g., stimulus appears 100ms early)?

**Provide**: GREEN FLAG or RED FLAG with recommendations.

---

## STEP 4: QUALITY ASSESSMENT AND TRIAL EXCLUSION

### Technical Details

**Quality Metrics Calculated** (lines 422-440):
```matlab
% Simple quality assessment
baseline_mask = trial_times_rel >= -3.0 & trial_times_rel < 0;
trial_mask_full = trial_times_rel >= 0 & trial_times_rel <= 10.7;

baseline_quality = mean(trial_valid(baseline_mask));
trial_quality = mean(trial_valid(trial_mask_full));
overall_quality = mean(trial_valid);

% Simple validity check
trial_is_valid = true;  % ALWAYS TRUE INITIALLY
overall_quality = mean(trial_valid);

% Skip only if overall quality is very poor
if overall_quality < CONFIG.quality.min_valid_proportion
    continue;  % Skip trial
end
```

**Quality Thresholds** (lines 65-67):
```matlab
CONFIG.quality.min_valid_proportion = 0.5;   % 50% valid data per trial
CONFIG.quality.min_samples_per_trial = 100;  % Minimum samples per trial
```

**Critical Issue**: 
- `trial_is_valid` is **always set to `true`** (line 439)
- Only exclusion criterion: `overall_quality < 0.5` (50% valid samples)
- No exclusion based on baseline quality, trial quality, or phase-specific quality
- Trials with 50.1% valid data are included as "valid"
- **This means**: A trial with 50.1% valid samples is counted as "valid" even if:
  - Baseline has 0% valid data
  - Stimulus phase has 0% valid data
  - Only non-critical phases have valid data

**Quality Metrics Stored** (lines 477-479):
```matlab
trial_table.baseline_quality = repmat(baseline_quality, n_samples, 1);
trial_table.trial_quality = repmat(trial_quality, n_samples, 1);
trial_table.trial_quality = repmat(overall_quality, n_samples, 1);
```

### Literature Standards

**Trial Exclusion Criteria:**
- Mathôt (2018): Recommends excluding trials with >40% missing data
- Kret & Sjak-Shie (2019): Suggests 30-50% missing as exclusion threshold
- Hershman et al. (2019): Recommends phase-specific quality checks (e.g., baseline must have >70% valid)
- **CURRENT**: 50% threshold aligns with literature, BUT:
  - No phase-specific checks
  - No baseline quality requirement
  - No check for critical phases (e.g., stimulus window)

**Quality Reporting:**
- Mathôt et al. (2018): Recommends reporting quality per phase, not just overall
- **CURRENT**: Calculates phase-specific quality but doesn't use it for exclusion

### Audit Questions for Step 4:
1. Is the 50% valid data threshold appropriate, or should it be stricter (e.g., 60-70%)?
2. Should baseline quality be required (e.g., >70% valid in baseline window)?
3. Should critical phases (stimulus, response) have higher quality requirements?
4. Is it problematic that `trial_is_valid` is always true regardless of quality metrics?
5. Should trials be excluded if specific phases have <30% valid data?

**Provide**: GREEN FLAG or RED FLAG with specific threshold recommendations.

---

## STEP 5: DOWNSAMPLING

### Technical Details

**Downsampling Method** (lines 447-462):
```matlab
% Downsample if needed
if CONFIG.original_fs ~= CONFIG.target_fs
    downsample_factor = round(CONFIG.original_fs / CONFIG.target_fs);
    trial_pupil_ds = downsample(trial_pupil, downsample_factor);
    trial_times_rel_ds = downsample(trial_times_rel, downsample_factor);
    trial_phases_ds = trial_phases(1:downsample_factor:end);
    if length(trial_phases_ds) ~= length(trial_pupil_ds)
        trial_phases_ds = trial_phases_ds(1:length(trial_pupil_ds));
    end
    trial_valid_ds = downsample(double(trial_valid), downsample_factor) > 0.5;
end
```

**Parameters**:
- Original: 2000 Hz
- Target: 250 Hz
- Downsample factor: 8
- Method: MATLAB `downsample()` function (simple decimation)

**Critical Issues**:
1. No anti-aliasing filter mentioned in code (though documentation mentions "8th-order anti-aliasing filter")
2. `trial_valid_ds` uses threshold >0.5, meaning if >50% of downsampled window is valid, entire sample marked valid
3. Phase labels simply decimated (every 8th label), not recalculated

### Literature Standards

**Downsampling Best Practices:**
- Mathôt (2018): Recommends anti-aliasing filter before downsampling
- Kret & Sjak-Shie (2019): Suggests low-pass filter at Nyquist frequency (125 Hz for 250 Hz target)
- **CURRENT**: Documentation mentions filter, but code doesn't show it

**Valid Flag Downsampling:**
- No explicit literature standard
- **CURRENT**: >0.5 threshold may inflate valid sample count if original data has 51% valid in window

### Audit Questions for Step 5:
1. Is the downsampling method (simple decimation) appropriate without visible anti-aliasing filter?
2. Is the >0.5 threshold for valid flags appropriate, or should it require >80%?
3. Should phase labels be recalculated after downsampling rather than decimated?

**Provide**: GREEN FLAG or RED FLAG with recommendations.

---

## STEP 6: BEHAVIORAL DATA MERGING

### Technical Details

**Merging Logic** (from `Create merged flat file.R` lines 158-178):
```r
# Position-based matching within each run
matched_trials <- pupil_subset %>%
    group_by(run) %>%
    mutate(
        trial_position_in_run = row_number()
    ) %>%
    ungroup()

# Manual matching with proper scoping
merge_info <- matched_trials %>%
    left_join(
        behavioral_subset %>%
            group_by(run) %>%
            mutate(trial_position_in_run = row_number()) %>%
            ungroup(),
        by = c("run", "trial_position_in_run"),
        suffix = c("_pupil", "_behav")
    )

merge_rate <- mean(!is.na(merge_info$trial), na.rm = TRUE)
```

**Critical Issues**:
1. **Position-based matching only**: Matches by trial position (1st, 2nd, 3rd...) within each run
2. **No validation**: No check that trial numbers, timestamps, or event codes align
3. **No handling of missing trials**: If pupil data has 30 trials but behavioral has 35, first 30 are matched regardless of which behavioral trials they correspond to
4. **No exclusion for mismatches**: All pupil trials are kept, even if they don't match behavioral data
5. **Example problem**: If pupil run has trials [1,2,3,5,6] (trial 4 missing) and behavioral has [1,2,3,4,5], then:
   - Pupil trial 1 → Behavioral trial 1 ✓
   - Pupil trial 2 → Behavioral trial 2 ✓
   - Pupil trial 3 → Behavioral trial 3 ✓
   - Pupil trial 5 → Behavioral trial 4 ✗ (WRONG MATCH)
   - Pupil trial 6 → Behavioral trial 5 ✗ (WRONG MATCH)

**Valid Trial Counting** (lines 259-260):
```r
n_trials_with_behavioral <- length(unique(final_merged$trial_index[final_merged$has_behavioral_data]))
n_total_trials <- length(unique(final_merged$trial_index))
```

**Current Results**:
- Mean merge rate: 97.2%
- Range: 30.1% to 100%
- Files with <70% merge rate: 2 files (BAP201_ADT: 30.1%, BAP156_ADT: 54.4%)

### Literature Standards

**Data Merging Best Practices:**
- Mathôt (2018): Recommends validating merges using multiple identifiers (trial number, timestamp, event codes)
- Kret & Sjak-Shie (2019): Suggests excluding trials where behavioral and pupillometry data don't align
- **CURRENT**: Position-based only, no validation

**Merge Rate Interpretation:**
- No explicit literature standard for acceptable merge rates
- **CURRENT**: 30.1% merge rate suggests significant misalignment, but trials still included

### Audit Questions for Step 6:
1. Is position-based matching acceptable, or should it validate against trial numbers/timestamps?
2. Should trials with <70% merge rate be flagged for exclusion or investigation?
3. Should there be checks for trial order mismatches (e.g., behavioral trial 5 matched to pupil trial 3)?
4. Is it problematic that all pupil trials are kept even without behavioral data?

**Provide**: GREEN FLAG or RED FLAG with recommendations.

---

## STEP 7: VALID TRIAL COUNTING AND REPORTING

### Technical Details

**Valid Trial Definition** (from quality reports):
- **Total trials**: All trials that pass minimum quality threshold (50% valid data)
- **Valid trials**: Trials where `trial_is_valid == true` (which is always true if trial passes quality threshold)
- **Valid trial proportion**: `valid_trials / total_trials`

**Current Reporting** (from `BAP_pupillometry_data_quality_detailed.txt`):
```
Total sessions processed: 59
Total trials processed: 3107
Overall valid trial rate: 95.2%
```

**Quality Report Generation** (lines 333-345):
```matlab
if quality_report.total_trials > 0
    quality_report.valid_trial_proportion = quality_report.valid_trials / quality_report.total_trials;
    ...
end
```

**Critical Issue**: 
- `valid_trials` count is incremented whenever `trial_is_valid == true` (line 485-486)
- But `trial_is_valid` is **always true** if trial passes the 50% quality threshold
- Therefore, "valid trials" = "trials with >50% valid data", not "trials with behavioral data" or "trials meeting stricter criteria"
- **This inflates valid trial counts**: A trial with 51% valid pupillometry data but no behavioral match is still counted as "valid"
- **Current reporting**: 95.2% valid trial rate includes trials without behavioral data, making it appear higher than the 97.2% merge rate suggests

### Literature Standards

**Valid Trial Definition:**
- Mathôt (2018): Recommends separate reporting for:
  - Trials with sufficient pupillometry data
  - Trials with behavioral data
  - Trials meeting both criteria
- Kret & Sjak-Shie (2019): Suggests reporting exclusion reasons separately
- **CURRENT**: Single "valid trial" metric that conflates pupillometry quality and behavioral matching

**Reporting Standards:**
- Mathôt et al. (2018): Recommends reporting:
  - Total trials collected
  - Trials excluded for pupillometry quality
  - Trials excluded for behavioral mismatch
  - Final analysis sample
- **CURRENT**: Only reports "valid trials" without breakdown

### Audit Questions for Step 7:
1. Is the current "valid trial" definition (trials with >50% valid data) appropriate, or should it require behavioral data match?
2. Should valid trial counts be reported separately for:
   - Pupillometry quality (e.g., >70% valid data)
   - Behavioral data availability
   - Both criteria met
3. Is the 95.2% valid trial rate inflated because it doesn't account for behavioral mismatches?
4. Should trials with <70% merge rate be excluded from "valid" counts?

**Provide**: GREEN FLAG or RED FLAG with recommendations for reporting standards.

---

## STEP 8: OVERALL PIPELINE ASSESSMENT

### Key Concerns Raised by Researchers

1. **Inflated valid trial rates**: 95.2% seems high - is this due to lenient criteria?
2. **Quality threshold**: 50% valid data may be too lenient
3. **No phase-specific checks**: Critical phases (baseline, stimulus) may have poor quality
4. **Position-based matching**: May match incorrect trials if data is misaligned
5. **No validation of merges**: Behavioral and pupillometry data not validated for alignment

### Current Data Quality Metrics

From sanity checks:
- Mean missing data: 0.0% (no NA values in pupil column)
- Mean merge rate: 97.2% (when behavioral data is merged)
- Files with issues: 59/59 (all flagged for "unrealistic values" - zeros, which are expected)
- Merge rate range: 30.1% to 100%

### Literature-Based Recommendations Needed

For each step, provide:
1. **GREEN FLAG** or **RED FLAG**
2. **Specific threshold recommendations** (e.g., "Increase min_valid_proportion to 0.7")
3. **Code modifications suggested** (if RED FLAG)
4. **APA citations** supporting recommendations
5. **Expected impact** on valid trial rates if changes are made

### Key References to Consider

- Mathôt, S. (2018). Pupillometry: Psychology, physiology, and function. *Journal of Cognition*, 1(1), 16.
- Mathôt, S., Fabius, J., Van Heusden, E., & Van der Stigchel, S. (2018). Safe and sensible preprocessing and baseline correction of pupil-size data. *Behavior Research Methods*, 50(1), 94-106.
- Kret, M. E., & Sjak-Shie, E. E. (2019). Preprocessing pupil size data: Guidelines and code. *Behavior Research Methods*, 51(3), 1336-1342.
- Hershman, R., Henik, A., & Cohen, N. (2019). A novel blink detection method based on pupillometry noise. *Behavior Research Methods*, 51(3), 1072-1086.
- Huang, J., et al. (2020). ET-remove-artifacts: A MATLAB toolbox for removing artifacts from eye-tracking data. [Toolbox reference]

### Additional Context: Example Data Quality Patterns

**From actual processed files:**
- BAP003_ADT: 66 trials, 100% merge rate, 0% missing data
- BAP101_ADT: 68 trials, 86.8% merge rate, 0% missing data  
- BAP104_ADT: 166 trials, 87.2% merge rate, 0% missing data
- BAP156_ADT: 114 trials, 54.4% merge rate, 0% missing data
- BAP201_ADT: 93 trials, 30.1% merge rate, 0% missing data

**Note**: All files show 0% missing data in pupil column, but this may be because:
- Zeros are used to represent missing/invalid data (not NA)
- Interpolation has filled all gaps
- Valid flag indicates quality, but zeros are still present in pupil values

**Quality metric examples** (from sample data):
- `baseline_quality`: Mean of `valid` flag in baseline window (typically 0.85-1.0)
- `trial_quality`: Mean of `valid` flag in trial window (typically 0.85-1.0)
- `overall_quality`: Mean of `valid` flag across entire trial (typically 0.90-1.0)

---

## FINAL ASSESSMENT REQUEST

Please provide:

1. **Step-by-step audit** with GREEN/RED flags for each of the 8 steps above
2. **Overall pipeline assessment**: Is the 95.2% valid trial rate scientifically defensible?
3. **Specific recommendations** for each RED FLAG, including:
   - Code modifications
   - Threshold adjustments
   - Additional validation steps
4. **Expected impact**: If recommendations are implemented, what would be the expected valid trial rate?
5. **Priority ranking**: Which issues are most critical to address?

**Format your response** as:
```
STEP X: [GREEN/RED FLAG]
Justification: [Brief explanation with citation]
Recommendation: [Specific action if RED FLAG]
Expected Impact: [How this would change valid trial rates]
```

---

## APPENDIX: COMPLETE CODE SNIPPETS FOR REFERENCE

### MATLAB Pipeline - Quality Assessment (Complete Function)
```matlab
function [run_data, run_quality] = process_single_run_improved(cleaned_data, raw_data, file_info, trial_offset, CONFIG)
    % Extract pupil data
    pupil = cleaned_data.S.data.sample;
    timestamps = cleaned_data.S.data.smp_timestamp;
    valid = cleaned_data.S.data.valid;
    
    % Find squeeze onsets to define trial boundaries
    squeeze_onsets = transition_times(transition_from == CONFIG.event_codes.baseline & ...
                                     transition_to == CONFIG.event_codes.squeeze_start);
    
    % Process each trial
    for trial_idx = 1:length(squeeze_onsets)
        squeeze_time = squeeze_onsets(trial_idx);
        trial_start_time = squeeze_time - 3.0;
        trial_end_time = squeeze_time + 10.7;
        
        trial_mask = timestamps >= trial_start_time & timestamps <= trial_end_time;
        if sum(trial_mask) < CONFIG.quality.min_samples_per_trial
            continue;
        end
        
        trial_pupil = pupil(trial_mask);
        trial_times = timestamps(trial_mask);
        trial_valid = valid(trial_mask);
        
        % Quality assessment
        baseline_mask = trial_times_rel >= -3.0 & trial_times_rel < 0;
        trial_mask_full = trial_times_rel >= 0 & trial_times_rel <= 10.7;
        
        baseline_quality = mean(trial_valid(baseline_mask));
        trial_quality = mean(trial_valid(trial_mask_full));
        overall_quality = mean(trial_valid);
        
        % Simple validity check
        trial_is_valid = true;  % ALWAYS TRUE
        if overall_quality < CONFIG.quality.min_valid_proportion  % 0.5
            continue;  % Skip trial
        end
        
        % Downsample
        if CONFIG.original_fs ~= CONFIG.target_fs
            downsample_factor = round(CONFIG.original_fs / CONFIG.target_fs);
            trial_pupil_ds = downsample(trial_pupil, downsample_factor);
            trial_valid_ds = downsample(double(trial_valid), downsample_factor) > 0.5;
        end
        
        % Update quality metrics
        run_quality.n_trials = run_quality.n_trials + 1;
        if trial_is_valid  % Always true if we reach here
            run_quality.n_valid_trials = run_quality.n_valid_trials + 1;
        end
    end
end
```

### R Merger - Behavioral Data Integration (Complete Function)
```r
merge_with_data_loss_fixed <- function() {
    # Load pupillometry data
    pupil_data <- csv_files %>% map_dfr(~read_csv(.x, show_col_types = FALSE))
    
    # Load behavioral data
    behavioral_data <- read_csv(behavioral_file, show_col_types = FALSE) %>%
        mutate(
            sub = as.character(subject_id),
            task_pupil = case_when(
                task_modality == "aud" ~ "ADT",
                task_modality == "vis" ~ "VDT"
            ),
            run = run_num,
            trial = trial_num
        )
    
    # Position-based matching
    matched_trials <- pupil_subset %>%
        group_by(run) %>%
        mutate(trial_position_in_run = row_number()) %>%
        ungroup()
    
    merge_info <- matched_trials %>%
        left_join(
            behavioral_subset %>%
                group_by(run) %>%
                mutate(trial_position_in_run = row_number()) %>%
                ungroup(),
            by = c("run", "trial_position_in_run")
        )
    
    # Merge with full pupil data
    final_merged <- full_pupil_data %>%
        left_join(merge_info, by = c("run", "trial_index")) %>%
        mutate(
            has_behavioral_data = !is.na(trial),
            # ... other columns
        )
}
```

### Configuration Parameters
```matlab
CONFIG.quality.min_valid_proportion = 0.5;   % 50% valid data per trial
CONFIG.quality.min_samples_per_trial = 100;  % Minimum samples per trial
CONFIG.original_fs = 2000;  % Original sampling rate (Hz)
CONFIG.target_fs = 250;     % Target sampling rate (Hz)
```

---

Thank you for conducting this critical audit. Please provide a comprehensive, step-by-step assessment with specific, actionable recommendations.

