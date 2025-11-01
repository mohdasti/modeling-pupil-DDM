function timing_sanity_check()
%% Timing Sanity Check for BAP Pupillometry Pipeline - CORRECTED FOR 8-PHASE PARADIGM
% Analyzes trial and phase durations from generated CSV files
% Note: Stimulus phase is 700ms consisting of: Standard (100ms) + ISI (500ms) + Target (100ms)

%% Configuration
output_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed';

% CORRECTED expected durations from your experimental paradigm (in seconds)
EXPECTED = struct();
EXPECTED.total_trial = 13.7;           % CORRECT: 3s baseline + 10.7s trial
EXPECTED.iti_baseline = 0;             % Variable duration - don't validate
EXPECTED.squeeze = 3.0;                % Squeeze period
EXPECTED.post_squeeze_blank = 0.25;    % Post-squeeze blank
EXPECTED.pre_stimulus_fixation = 0.5;  % ADDED: Pre-stimulus fixation (500ms)
EXPECTED.stimulus = 0.7;               % Stimulus presentation (700ms = Standard 100ms + ISI 500ms + Target 100ms)
EXPECTED.post_stimulus_fixation = 0.25; % Post-stimulus fixation
EXPECTED.response = 3.0;               % "Different?" response
EXPECTED.confidence = 3.0;             % Confidence rating

fprintf('=== BAP PUPILLOMETRY TIMING SANITY CHECK - CORRECTED FOR 8-PHASE PARADIGM ===\n\n');

%% Find and analyze CSV files
csv_files = dir(fullfile(output_dir, '*_flat.csv')); 

if isempty(csv_files)
    fprintf('ERROR: No CSV files found in %s\n', output_dir);
    return;
end

fprintf('Found %d CSV files to analyze:\n', length(csv_files));
for i = 1:length(csv_files)
    fprintf('  %s\n', csv_files(i).name);
end
fprintf('\n');

%% Analyze each file
all_trial_stats = table();
all_phase_stats = table();

for file_idx = 1:length(csv_files)
    
    csv_filename = csv_files(file_idx).name;
    csv_path = fullfile(output_dir, csv_filename);
    
    fprintf('=== ANALYZING %s ===\n', csv_filename);
    
    try
        % Load data
        data = readtable(csv_path);
        
        if height(data) == 0
            fprintf('  WARNING: Empty file\n\n');
            continue;
        end
        
        % Get basic info
        unique_trials = unique(data.trial_index);
        unique_phases = unique(data.trial_label); % CORRECTED: Use trial_label (matches R analysis)
        
        fprintf('  Trials found: %d\n', length(unique_trials));
        fprintf('  Phases found: %s\n', strjoin(unique_phases, ', '));
        fprintf('  Time range: %.2f to %.2f seconds\n', min(data.time), max(data.time));
        fprintf('  Sampling rate: ~%.0f Hz\n', 1/median(diff(data.time(1:100))));
        
        % Analyze trial durations
        [trial_stats, phase_stats] = analyze_timing(data, csv_filename, EXPECTED);
        
        % Accumulate results
        all_trial_stats = [all_trial_stats; trial_stats];
        all_phase_stats = [all_phase_stats; phase_stats];
        
    catch ME
        fprintf('  ERROR analyzing %s: %s\n\n', csv_filename, ME.message);
        continue;
    end
end

%% Overall summary
if height(all_trial_stats) > 0
    fprintf('\n=== OVERALL TIMING SUMMARY ===\n');
    
    % Trial duration summary
    overall_trial_mean = mean(all_trial_stats.duration);
    overall_trial_std = std(all_trial_stats.duration);
    
    fprintf('\nTOTAL TRIAL DURATION:\n');
    fprintf('  Expected: %.2f seconds\n', EXPECTED.total_trial);
    fprintf('  Observed: %.2f ± %.2f seconds\n', overall_trial_mean, overall_trial_std);
    fprintf('  Difference: %.2f seconds (%.1f%%)\n', ...
        overall_trial_mean - EXPECTED.total_trial, ...
        100 * (overall_trial_mean - EXPECTED.total_trial) / EXPECTED.total_trial);
    
    if abs(overall_trial_mean - EXPECTED.total_trial) > 2.0
        fprintf('  *** WARNING: Trial duration differs significantly from expected!\n');
    else
        fprintf('  ✓ Trial duration is reasonable\n');
    end
    
    % Phase duration summary
    fprintf('\nPHASE DURATION ANALYSIS:\n');
    unique_phase_names = unique(all_phase_stats.phase);
    
    for i = 1:length(unique_phase_names)
        phase_name = unique_phase_names{i};
        phase_data = all_phase_stats(strcmp(all_phase_stats.phase, phase_name), :);
        
        if height(phase_data) > 0
            phase_mean = mean(phase_data.duration);
            phase_std = std(phase_data.duration);
            
            % Get expected duration
            expected_dur = get_expected_duration(phase_name, EXPECTED);
            
            fprintf('  %s:\n', phase_name);
            fprintf('    Expected: %.2f seconds\n', expected_dur);
            fprintf('    Observed: %.2f ± %.2f seconds\n', phase_mean, phase_std);
            
            if expected_dur > 0
                diff_pct = 100 * (phase_mean - expected_dur) / expected_dur;
                fprintf('    Difference: %.2f seconds (%.1f%%)\n', phase_mean - expected_dur, diff_pct);
                
                if abs(diff_pct) > 50
                    fprintf('    *** WARNING: Phase duration differs significantly!\n');
                elseif abs(diff_pct) > 20
                    fprintf('    * CAUTION: Phase duration somewhat different\n');
                else
                    fprintf('    ✓ Phase duration is reasonable\n');
                end
            end
        end
    end
    
    % Time reference validation
    fprintf('\n=== TIME REFERENCE VALIDATION ===\n');
    validate_time_reference(all_phase_stats);
    
else
    fprintf('No timing data to analyze\n');
end

fprintf('\n=== TIMING ANALYSIS COMPLETE ===\n');

end

function [trial_stats, phase_stats] = analyze_timing(data, filename, EXPECTED)
% Analyze timing for a single file

trial_stats = table();
phase_stats = table();

unique_trials = unique(data.trial_index);

fprintf('\n  --- TRIAL-BY-TRIAL ANALYSIS ---\n');

for trial_idx = 1:length(unique_trials)
    trial_num = unique_trials(trial_idx);
    trial_data = data(data.trial_index == trial_num, :);
    
    % Calculate total trial duration
    trial_duration = max(trial_data.time) - min(trial_data.time);
    
    % Add to trial stats
    trial_row = table();
    trial_row.file = {filename};
    trial_row.trial = trial_num;
    trial_row.duration = trial_duration;
    trial_row.start_time = min(trial_data.time);
    trial_row.end_time = max(trial_data.time);
    trial_stats = [trial_stats; trial_row];
    
    % Analyze phases within this trial
    unique_phases = unique(data.trial_label); % CORRECTED: Use trial_label column
    
    for phase_idx = 1:length(unique_phases)
        phase_name = unique_phases{phase_idx};
        phase_data = trial_data(strcmp(trial_data.trial_label, phase_name), :); % CORRECTED: Use trial_label
        
        if height(phase_data) > 0
            phase_duration = max(phase_data.time) - min(phase_data.time);
            phase_start = min(phase_data.time);
            phase_end = max(phase_data.time);
            
            % Add to phase stats
            phase_row = table();
            phase_row.file = {filename};
            phase_row.trial = trial_num;
            phase_row.phase = {phase_name};
            phase_row.duration = phase_duration;
            phase_row.start_time = phase_start;
            phase_row.end_time = phase_end;
            phase_stats = [phase_stats; phase_row];
        end
    end
end

% Summary for this file
fprintf('  Trial durations: %.2f ± %.2f seconds (range: %.2f - %.2f)\n', ...
    mean(trial_stats.duration), std(trial_stats.duration), ...
    min(trial_stats.duration), max(trial_stats.duration));

% Check for expected total duration
expected_total = EXPECTED.total_trial;
actual_mean = mean(trial_stats.duration);
if abs(actual_mean - expected_total) > 2.0
    fprintf('  *** WARNING: Mean trial duration (%.2fs) differs from expected (%.2fs)\n', ...
        actual_mean, expected_total);
end

fprintf('\n');

end

function expected_dur = get_expected_duration(phase_name, EXPECTED)
% CORRECTED: Get expected duration for a phase including Pre_Stimulus_Fixation

switch phase_name
    case 'Squeeze'
        expected_dur = EXPECTED.squeeze;
    case 'Post_Squeeze_Blank'
        expected_dur = EXPECTED.post_squeeze_blank;
    case 'Pre_Stimulus_Fixation'  % ADDED: New phase
        expected_dur = EXPECTED.pre_stimulus_fixation;
    case 'Stimulus'
        expected_dur = EXPECTED.stimulus;
    case 'Post_Stimulus_Fixation'
        expected_dur = EXPECTED.post_stimulus_fixation;
    case 'Response_Different'
        expected_dur = EXPECTED.response;
    case 'Confidence'
        expected_dur = EXPECTED.confidence;
    case {'ITI_Baseline', 'Post_Trial'}
        expected_dur = 0; % Variable duration
    otherwise
        expected_dur = 0;
end

end

function validate_time_reference(phase_stats)
% Validate that time reference makes sense

% Check if squeeze starts around time 0 (since pipeline uses squeeze onset as t=0)
squeeze_data = phase_stats(strcmp(phase_stats.phase, 'Squeeze'), :);

if ~isempty(squeeze_data)
    squeeze_start_times = squeeze_data.start_time;
    fprintf('Squeeze start times: %.2f ± %.2f seconds\n', ...
        mean(squeeze_start_times), std(squeeze_start_times));
    
    if abs(mean(squeeze_start_times)) < 0.5
        fprintf('✓ Time reference appears correct (squeeze starts near t=0)\n');
    else
        fprintf('*** WARNING: Time reference may be incorrect (squeeze should start near t=0)\n');
    end
else
    fprintf('No squeeze phases found - cannot validate time reference\n');
end

% Check phase ordering and timing
fprintf('\nPhase timing validation:\n');
unique_files = unique(phase_stats.file);

for file_idx = 1:length(unique_files)
    filename = unique_files{file_idx};
    file_data = phase_stats(strcmp(phase_stats.file, filename), :);
    
    % Get first trial as example
    first_trial = min(file_data.trial);
    trial_data = file_data(file_data.trial == first_trial, :);
    
    if height(trial_data) > 0
        % Sort by start time
        trial_data = sortrows(trial_data, 'start_time');
        
        fprintf('  %s (Trial %d): ', filename, first_trial);
        for i = 1:height(trial_data)
            fprintf('%s(%.2fs) ', trial_data.phase{i}, trial_data.start_time(i));
        end
        fprintf('\n');
        
        % CORRECTED: Validate expected phase sequence and timing
        expected_sequence = {'ITI_Baseline', 'Squeeze', 'Post_Squeeze_Blank', ...
                            'Pre_Stimulus_Fixation', 'Stimulus', 'Post_Stimulus_Fixation', ...
                            'Response_Different', 'Confidence'};
        
        % CORRECTED: Expected cumulative start times (relative to squeeze onset)
        expected_start_times = [-3.0, 0.0, 3.0, 3.25, 3.75, 4.45, 4.7, 7.7];
        
        % Check if phases match expected sequence
        found_phases = trial_data.phase;
        timing_issues = false;
        
        for i = 1:length(found_phases)
            phase_name = found_phases{i};
            actual_start = trial_data.start_time(i);
            
            % Find expected start time
            phase_idx = find(strcmp(expected_sequence, phase_name));
            if ~isempty(phase_idx)
                expected_start = expected_start_times(phase_idx);
                time_diff = abs(actual_start - expected_start);
                
                if time_diff > 0.5  % Allow 500ms tolerance
                    fprintf('    *** WARNING: %s starts at %.2fs, expected %.2fs (diff: %.2fs)\n', ...
                        phase_name, actual_start, expected_start, time_diff);
                    timing_issues = true;
                end
            end
        end
        
        if ~timing_issues
            fprintf('    ✓ Phase timing appears correct\n');
        end
    end
end

end

%%
function comprehensive_sanity_check()
%% CORRECTED Comprehensive Sanity Check for BAP Pupillometry Pipeline
% Validates trial counts, phase sequences, event detection, and data quality

output_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed';

fprintf('=== COMPREHENSIVE BAP SANITY CHECK - CORRECTED FOR 8-PHASE PARADIGM ===\n\n');

%% 1. Load and basic validation
csv_files = dir(fullfile(output_dir, '*_flat_merged.csv')); % CORRECTED: Look for _flat_merged.csv
if isempty(csv_files)
    fprintf('ERROR: No CSV files found\n');
    return;
end

%% 2. Trial count validation
fprintf('=== TRIAL COUNT VALIDATION ===\n');
for i = 1:length(csv_files)
    data = readtable(fullfile(output_dir, csv_files(i).name));
    
    [subject, task] = parse_csv_filename(csv_files(i).name);
    unique_trials = unique(data.trial_index);
    unique_runs = unique(data.run);
    
    fprintf('%s %s:\n', subject, task);
    fprintf('  Total trials: %d (expected: ~150)\n', length(unique_trials));
    fprintf('  Runs: %d (expected: 5)\n', length(unique_runs));
    
    % Trials per run
    for run = unique_runs'
        run_trials = unique(data.trial_index(data.run == run));
        fprintf('    Run %d: %d trials\n', run, length(run_trials));
    end
    
    if length(unique_trials) < 120
        fprintf('  *** WARNING: Missing many trials (<%d/150)\n', length(unique_trials));
    elseif length(unique_trials) < 140
        fprintf('  * CAUTION: Some trials missing (%d/150)\n', length(unique_trials));
    else
        fprintf('  ✓ Trial count is good (%d/150)\n', length(unique_trials));
    end
    fprintf('\n');
end

%% 3. Phase sequence validation
fprintf('=== PHASE SEQUENCE VALIDATION ===\n');
for i = 1:length(csv_files)
    data = readtable(fullfile(output_dir, csv_files(i).name));
    
    fprintf('%s:\n', csv_files(i).name);
    
    % Check first few trials for proper phase sequence
    unique_trials = unique(data.trial_index);
    first_trials = unique_trials(1:min(3, length(unique_trials)));
    
    for trial_num = first_trials'
        trial_data = data(data.trial_index == trial_num, :);
        
        % Get phase sequence using trial_label column
        phase_changes = find(diff(categorical(trial_data.trial_label)) ~= 0); % CORRECTED: Use trial_label
        phase_sequence = {};
        phase_times = [];
        
        if ~isempty(phase_changes)
            phase_sequence{1} = trial_data.trial_label{1}; % CORRECTED: Use trial_label
            phase_times(1) = trial_data.time(1);
            
            for j = 1:length(phase_changes)
                idx = phase_changes(j) + 1;
                phase_sequence{end+1} = trial_data.trial_label{idx}; % CORRECTED: Use trial_label
                phase_times(end+1) = trial_data.time(idx);
            end
        else
            phase_sequence{1} = trial_data.trial_label{1}; % CORRECTED: Use trial_label
            phase_times(1) = trial_data.time(1);
        end
        
        fprintf('  Trial %d: ', trial_num);
        for j = 1:length(phase_sequence)
            fprintf('%s(%.1fs) ', phase_sequence{j}, phase_times(j));
        end
        fprintf('\n');
    end
    fprintf('\n');
end

%% 4. Data quality assessment
fprintf('=== DATA QUALITY ASSESSMENT ===\n');

% Load quality report if available
quality_file = fullfile(output_dir, 'BAP_pupillometry_data_quality_report.csv');
if exist(quality_file, 'file')
    quality_data = readtable(quality_file);
    
    for i = 1:height(quality_data)
        fprintf('%s %s (Session %s):\n', ...
            quality_data.subject{i}, quality_data.task{i}, quality_data.session{i});
        fprintf('  Valid trials: %d/%d (%.1f%%)\n', ...
            quality_data.valid_trials(i), quality_data.total_trials(i), ...
            100 * quality_data.valid_trial_proportion(i));
        fprintf('  Runs processed: %d/5\n', quality_data.runs_processed(i));
        
        if quality_data.valid_trial_proportion(i) < 0.7
            fprintf('  *** WARNING: Low valid trial rate (<70%%)\n');
        else
            fprintf('  ✓ Good data quality\n');
        end
    end
else
    fprintf('Quality report not found\n');
end

%% 5. CORRECTED: Check for expected phases (8 phases total)
fprintf('\n=== PHASE COVERAGE CHECK ===\n');
expected_phases = {'ITI_Baseline', 'Squeeze', 'Post_Squeeze_Blank', 'Pre_Stimulus_Fixation', ...
                   'Stimulus', 'Post_Stimulus_Fixation', 'Response_Different', 'Confidence'}; % CORRECTED: Added Pre_Stimulus_Fixation

for i = 1:length(csv_files)
    data = readtable(fullfile(output_dir, csv_files(i).name));
    
    fprintf('%s:\n', csv_files(i).name);
    found_phases = unique(data.trial_label); % CORRECTED: Use trial_label
    
    for phase = expected_phases
        if any(strcmp(found_phases, phase{1}))
            fprintf('  ✓ %s\n', phase{1});
        else
            fprintf('  ❌ %s - MISSING!\n', phase{1});
        end
    end
    fprintf('\n');
end

%% 6. Sample distribution check
fprintf('=== SAMPLING DISTRIBUTION CHECK ===\n');
for i = 1:length(csv_files)
    data = readtable(fullfile(output_dir, csv_files(i).name));
    
    fprintf('%s:\n', csv_files(i).name);
    
    % Check sampling rate consistency
    time_diffs = diff(data.time(1:1000)); % First 1000 samples
    median_interval = median(time_diffs(time_diffs > 0));
    estimated_fs = 1 / median_interval;
    
    fprintf('  Estimated sampling rate: %.0f Hz (expected: 250 Hz)\n', estimated_fs);
    
    if abs(estimated_fs - 250) > 10
        fprintf('  *** WARNING: Sampling rate differs from expected\n');
    else
        fprintf('  ✓ Sampling rate is correct\n');
    end
    
    % Check for data gaps
    large_gaps = time_diffs > (2 * median_interval);
    if any(large_gaps)
        fprintf('  * CAUTION: Found %d large time gaps\n', sum(large_gaps));
    else
        fprintf('  ✓ No large time gaps detected\n');
    end
    fprintf('\n');
end

fprintf('=== COMPREHENSIVE SANITY CHECK COMPLETE ===\n');
end

function [subject, task] = parse_csv_filename(filename)
% CORRECTED: Parse CSV filename to extract subject and task info
subject_match = regexp(filename, '(BAP\d+)', 'tokens');
if ~isempty(subject_match)
    subject = subject_match{1}{1};
else
    subject = 'Unknown';
end

if contains(filename, 'ADT')
    task = 'ADT';
elseif contains(filename, 'VDT')
    task = 'VDT';
else
    task = 'Unknown';
end
end
