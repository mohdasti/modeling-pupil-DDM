function BAP_Pupillometry_Pipeline()
%% BAP Pupillometry Processing Pipeline - FULLY CORRECTED FOR 8-PHASE PARADIGM
% This script processes pupillometry data with proper trial structure understanding

%% Configuration - FULLY CORRECTED FOR 8-PHASE PARADIGM
CONFIG = struct();
CONFIG.cleaned_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned';
CONFIG.raw_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data';
CONFIG.output_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed';
CONFIG.target_fs = 250; % Target sampling rate (Hz)
CONFIG.original_fs = 2000; % Original sampling rate (Hz)

% Experimental design parameters
CONFIG.experiment = struct();
CONFIG.experiment.trials_per_session = 150;  % Total trials per session
CONFIG.experiment.runs_per_session = 5;      % 5 runs per session

% Event codes
CONFIG.event_codes = struct();
CONFIG.event_codes.baseline = 3040;
CONFIG.event_codes.squeeze_start = 3044;     % Squeeze onset - trial start
CONFIG.event_codes.stimulus_start = 3042;    % Stimulus onset  
CONFIG.event_codes.response_start = 3041;    % "Different?" response
CONFIG.event_codes.confidence_start = 3048;  % Confidence rating

% FULLY CORRECTED paradigm timing (8 phases total)
CONFIG.timing = struct();
CONFIG.timing.iti_min = 1.5;                 % Minimum ITI (jittered baseline)
CONFIG.timing.iti_max = 4.5;                 % Maximum ITI 
CONFIG.timing.squeeze_duration = 3.0;        % 3000ms handgrip
CONFIG.timing.post_squeeze_blank = 0.25;     % 250ms blank after squeeze
CONFIG.timing.pre_stimulus_fixation = 0.5;   % 500ms fixation BEFORE stimulus (CRITICAL FIX!)
CONFIG.timing.stimulus_duration = 0.7;       % 700ms stimulus sequence
CONFIG.timing.post_stim_fixation = 0.25;     % 250ms post-stimulus fixation
CONFIG.timing.response_duration = 3.0;       % 3000ms "Different?" response
CONFIG.timing.confidence_duration = 3.0;     % 3000ms confidence rating

% CORRECTED total trial duration calculation
% ITI(max 4.5) + Squeeze(3.0) + Post_Squeeze(0.25) + Pre_Stim_Fix(0.5) + 
% Stimulus(0.7) + Post_Stim_Fix(0.25) + Response(3.0) + Confidence(3.0) = 15.2s
CONFIG.timing.max_trial_duration = 18.5;     % 15.2s + buffer for safety

% FULLY CORRECTED phase definitions (8 phases now)
CONFIG.phases = struct();
CONFIG.phases.count = 8;  % CRITICAL: Updated from 7 to 8
CONFIG.phases.names = {'ITI_Baseline', 'Squeeze', 'Post_Squeeze_Blank', ...
                      'Pre_Stimulus_Fixation', 'Stimulus', 'Post_Stimulus_Fixation', ...
                      'Response_Different', 'Confidence'};

% FULLY CORRECTED cumulative timing for phase boundaries (relative to squeeze onset)
CONFIG.phases.boundaries = [
    -3.0;    % ITI_Baseline starts (3s baseline window)
     0.0;    % Squeeze starts (t=0, reference point)
     3.0;    % Post_Squeeze_Blank starts  
     3.25;   % Pre_Stimulus_Fixation starts (CRITICAL FIX!)
     3.75;   % Stimulus starts (3.25 + 0.5)
     4.45;   % Post_Stimulus_Fixation starts (3.75 + 0.7)
     4.7;    % Response_Different starts (4.45 + 0.25)
     7.7;    % Confidence starts (4.7 + 3.0)
    10.7     % Trial ends (7.7 + 3.0) - CORRECTED from 10.2
];

% Data quality thresholds
CONFIG.quality = struct();
CONFIG.quality.min_valid_proportion = 0.5;   % 50% valid data per trial
CONFIG.quality.min_samples_per_trial = 100;  % Minimum samples per trial

CONFIG.analysis_mode = 'fMRI';  % or 'physiological'

% Create output directory
if ~exist(CONFIG.output_dir, 'dir')
    mkdir(CONFIG.output_dir);
end

%% Main Processing Pipeline
fprintf('=== BAP PUPILLOMETRY PROCESSING PIPELINE - FULLY CORRECTED ===\n\n');
fprintf('Cleaned files directory: %s\n', CONFIG.cleaned_dir);
fprintf('Raw files directory: %s\n', CONFIG.raw_dir);
fprintf('Output directory: %s\n\n', CONFIG.output_dir);

% Find all cleaned files
cleaned_files = dir(fullfile(CONFIG.cleaned_dir, '*_cleaned.mat'));
fprintf('Found %d cleaned files\n', length(cleaned_files));

if isempty(cleaned_files)
    fprintf('ERROR: No cleaned files found in %s\n', CONFIG.cleaned_dir);
    return;
end

% Organize files by subject and session
file_groups = organize_files_by_session(cleaned_files);
fprintf('Organized into %d subject/session groups\n\n', length(file_groups));

%% Process each subject/session combination
all_results = table();
all_quality_reports = {};

for group_idx = 1:length(file_groups)
    
    current_group = file_groups{group_idx};
    subject = current_group.subject;
    task = current_group.task;
    session = current_group.session;
    
    fprintf('=== PROCESSING %s - %s (Session %s) ===\n', subject, task, session);
    fprintf('Files: %d runs\n', height(current_group.files));
    
    % Process all runs for this subject/session
    [session_data, session_quality] = process_session(current_group, CONFIG);
    
    if ~isempty(session_data)
        all_results = [all_results; session_data];
        session_quality.subject = subject;
        session_quality.task = task;
        session_quality.session = session;
        all_quality_reports{end+1} = session_quality;
        
        fprintf('SUCCESS: %d trials processed\n', session_quality.total_trials);
    else
        fprintf('WARNING: No data processed for this session\n');
    end
end

%% Save results and quality reports
fprintf('\n=== SAVING RESULTS ===\n');

if height(all_results) > 0
    % Save flat files by subject/task
    unique_combos = unique(all_results(:, {'sub', 'task'}));
    
    for combo_idx = 1:height(unique_combos)
        current_sub = unique_combos.sub{combo_idx};
        current_task = unique_combos.task{combo_idx};
        
        combo_mask = strcmp(all_results.sub, current_sub) & strcmp(all_results.task, current_task);
        combo_data = all_results(combo_mask, :);
        combo_data = sortrows(combo_data, {'run', 'trial_index', 'time'});
        
        % Save CSV
        output_filename = sprintf('%s_%s_flat.csv', current_sub, current_task);
        output_path = fullfile(CONFIG.output_dir, output_filename);
        writetable(combo_data, output_path);

        n_trials = length(unique(combo_data.trial_index));
        n_runs = length(unique(combo_data.run));
        fprintf('Saved %s: %d trials across %d runs\n', output_filename, n_trials, n_runs);
    end
    
    % Save comprehensive quality report
    save_quality_reports(all_quality_reports, CONFIG);
    
    % Create validation plots
    create_validation_plots(all_results, CONFIG);
    
else
    fprintf('No data to save\n');
end

fprintf('\n=== PROCESSING COMPLETE ===\n');

end

%% ========================================================================
%% HELPER FUNCTIONS
%% ========================================================================

function file_groups = organize_files_by_session(cleaned_files)
% Organize files by subject/session/task for batch processing

% Pre-allocate cell arrays to store metadata
n_files = length(cleaned_files);
subjects = cell(n_files, 1);
tasks = cell(n_files, 1);
sessions = cell(n_files, 1);
runs = zeros(n_files, 1);
filenames = cell(n_files, 1);

% Parse all filenames first
valid_files = false(n_files, 1);

for i = 1:n_files
    filename = cleaned_files(i).name;
    metadata = parse_filename(filename);
    
    if ~isempty(metadata)
        subjects{i} = metadata.subject;
        tasks{i} = metadata.task;
        sessions{i} = metadata.session;
        runs(i) = metadata.run;
        filenames{i} = filename;
        valid_files(i) = true;
    end
end

% Create table from valid files only
if any(valid_files)
    file_info = table();
    file_info.subject = subjects(valid_files);
    file_info.task = tasks(valid_files);
    file_info.session = sessions(valid_files);
    file_info.run = runs(valid_files);
    file_info.filename = filenames(valid_files);
else
    file_groups = {};
    return;
end

% Group by subject, task, and session
unique_sessions = unique(file_info(:, {'subject', 'task', 'session'}));
file_groups = {};

for i = 1:height(unique_sessions)
    session_mask = strcmp(file_info.subject, unique_sessions.subject{i}) & ...
                  strcmp(file_info.task, unique_sessions.task{i}) & ...
                  strcmp(file_info.session, unique_sessions.session{i});
    
    session_files = file_info(session_mask, :);
    session_files = sortrows(session_files, 'run'); % Sort by run number
    
    group_struct = struct();
    group_struct.subject = unique_sessions.subject{i};
    group_struct.task = unique_sessions.task{i};
    group_struct.session = unique_sessions.session{i};
    group_struct.files = session_files;
    
    file_groups{end+1} = group_struct;
end
end

function metadata = parse_filename(filename)
% Parse filename to extract subject, task, session, run information

metadata = struct();

% Extract subject ID
subject_match = regexp(filename, 'subject([A-Z0-9]+)_', 'tokens');
if isempty(subject_match)
    metadata = [];
    return;
end
metadata.subject = subject_match{1}{1};

% Extract task
if contains(filename, 'Aoddball')
    metadata.task = 'ADT';
elseif contains(filename, 'Voddball')
    metadata.task = 'VDT';
else
    metadata.task = 'Unknown';
end

% Extract session and run
session_match = regexp(filename, 'session(\d+)', 'tokens');
if ~isempty(session_match)
    metadata.session = session_match{1}{1};
else
    metadata.session = '1';
end

run_match = regexp(filename, 'run(\d+)', 'tokens');
if ~isempty(run_match)
    metadata.run = str2double(run_match{1}{1});
else
    metadata.run = 1;
end
end

function [session_data, quality_report] = process_session(file_group, CONFIG)
% Process all runs for a single session with cumulative trial indexing

session_data = table();
quality_report = struct();

% CORRECTED: Initialize quality tracking for 8 phases
quality_report.total_trials = 0;
quality_report.valid_trials = 0;
quality_report.runs_processed = 0;
quality_report.phase_quality = zeros(CONFIG.phases.count, 1); % FIXED: Use CONFIG.phases.count
quality_report.phase_names = CONFIG.phases.names; % FIXED: Use CONFIG.phases.names

cumulative_trial_index = 0; % Track trials across runs

for run_idx = 1:height(file_group.files)
    
    file_info = file_group.files(run_idx, :);
    fprintf('  Processing Run %d: %s\n', file_info.run, file_info.filename{1});
    
    try
        % Load cleaned data
        cleaned_path = fullfile(CONFIG.cleaned_dir, file_info.filename{1});
        cleaned_data = load(cleaned_path);
        
        % Find corresponding raw file
        raw_filename = strrep(file_info.filename{1}, '_eyetrack_cleaned.mat', '_eyetrack.mat');
        raw_path = fullfile(CONFIG.raw_dir, sprintf('sub-%s/ses-%s/InsideScanner/%s', ...
            file_info.subject{1}, file_info.session{1}, raw_filename));
        
        if ~exist(raw_path, 'file')
            fprintf('    WARNING: Raw file not found: %s\n', raw_path);
            continue;
        end
        
        raw_data = load(raw_path);
        
        % Process this run with improved error handling
        [run_data, run_quality] = process_single_run_improved(cleaned_data, raw_data, ...
            file_info, cumulative_trial_index, CONFIG);
        
        if ~isempty(run_data)
            session_data = [session_data; run_data];
            
            % Update quality report
            quality_report.total_trials = quality_report.total_trials + run_quality.n_trials;
            quality_report.valid_trials = quality_report.valid_trials + run_quality.n_valid_trials;
            quality_report.runs_processed = quality_report.runs_processed + 1;
            quality_report.phase_quality = quality_report.phase_quality + run_quality.phase_samples;
            
            % Update cumulative trial index
            cumulative_trial_index = cumulative_trial_index + run_quality.n_trials;
            
            fprintf('    SUCCESS: %d trials processed\n', run_quality.n_trials);
        else
            fprintf('    WARNING: No trials processed for this run\n');
        end
        
    catch ME
        fprintf('    ERROR: %s\n', ME.message);
        continue;
    end
end

% Calculate final quality metrics
if quality_report.total_trials > 0
    quality_report.valid_trial_proportion = quality_report.valid_trials / quality_report.total_trials;
    total_samples = sum(quality_report.phase_quality);
    if total_samples > 0
        quality_report.phase_proportions = quality_report.phase_quality / total_samples;
    else
        quality_report.phase_proportions = zeros(CONFIG.phases.count, 1); % FIXED: Use CONFIG.phases.count
    end
else
    quality_report.valid_trial_proportion = 0;
    quality_report.phase_proportions = zeros(CONFIG.phases.count, 1); % FIXED: Use CONFIG.phases.count
end
end

function [run_data, run_quality] = process_single_run_improved(cleaned_data, raw_data, file_info, trial_offset, CONFIG)
% Process a single run with FULLY CORRECTED trial windows and phase labeling

run_data = table();
run_quality = struct();
run_quality.n_trials = 0;
run_quality.n_valid_trials = 0;
run_quality.phase_samples = zeros(CONFIG.phases.count, 1); % FIXED: Use CONFIG.phases.count

% Extract pupil data
pupil = cleaned_data.S.data.sample;
timestamps = cleaned_data.S.data.smp_timestamp;
valid = cleaned_data.S.data.valid;

% Extract events from raw data
buffer_data = raw_data.bufferData;
event_times = buffer_data(:, 1);
event_codes = buffer_data(:, 8);

% Find ALL event transitions
transition_indices = find(diff(event_codes) ~= 0) + 1;
if isempty(transition_indices)
    fprintf('    No event transitions found\n');
    return;
end

transition_times = event_times(transition_indices);
transition_from = event_codes(transition_indices - 1);
transition_to = event_codes(transition_indices);

% Find squeeze onsets to define trial boundaries
squeeze_onsets = transition_times(transition_from == CONFIG.event_codes.baseline & ...
                                 transition_to == CONFIG.event_codes.squeeze_start);

if isempty(squeeze_onsets)
    fprintf('    No squeeze onsets found\n');
    return;
end

fprintf('    Found %d squeeze onsets (trials)\n', length(squeeze_onsets));

% Process each trial based on squeeze onsets
for trial_idx = 1:length(squeeze_onsets)
    
    squeeze_time = squeeze_onsets(trial_idx);
    
    % CORRECTED TRIAL WINDOW - Updated for 8-phase paradigm
    trial_start_time = squeeze_time - 3.0;  % 3s before squeeze (sufficient for baseline)
    trial_end_time = squeeze_time + 10.7;   % CORRECTED: 10.7s (was 10.2s)
    
    % Extract trial data
    trial_mask = timestamps >= trial_start_time & timestamps <= trial_end_time;
    
    if sum(trial_mask) < CONFIG.quality.min_samples_per_trial
        continue;
    end
    
    trial_pupil = pupil(trial_mask);
    trial_times = timestamps(trial_mask);
    trial_valid = valid(trial_mask);
    
    % Find all events within this trial
    trial_event_mask = transition_times >= trial_start_time & transition_times <= trial_end_time;
    trial_event_times = transition_times(trial_event_mask);
    trial_event_from = transition_from(trial_event_mask);
    trial_event_to = transition_to(trial_event_mask);
    
    % FULLY CORRECTED PHASE LABELING - Uses actual 8-phase paradigm timing
    trial_phases = create_correct_phase_labels(trial_times, squeeze_time, ...
        trial_event_times, trial_event_from, trial_event_to, CONFIG);
    
    % Create relative time (0 = squeeze onset)
    trial_times_rel = trial_times - squeeze_time;
    
    % Simple quality assessment
    baseline_mask = trial_times_rel >= -3.0 & trial_times_rel < 0;
    trial_mask_full = trial_times_rel >= 0 & trial_times_rel <= 10.7; % CORRECTED: 10.7s
    
    % Calculate quality metrics safely
    baseline_quality = 0;
    trial_quality = 0;
    
    if sum(baseline_mask) > 0
        baseline_quality = mean(trial_valid(baseline_mask));
    end
    
    if sum(trial_mask_full) > 0
        trial_quality = mean(trial_valid(trial_mask_full));
    end
    
    % Simple validity check
    trial_is_valid = true;
    overall_quality = mean(trial_valid);
    
    % Skip only if overall quality is very poor
    if overall_quality < CONFIG.quality.min_valid_proportion
        continue;
    end
    
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
    else
        trial_pupil_ds = trial_pupil;
        trial_times_rel_ds = trial_times_rel;
        trial_phases_ds = trial_phases;
        trial_valid_ds = trial_valid;
    end
    
    % Create table for this trial
    n_samples = length(trial_pupil_ds);
    global_trial_idx = trial_offset + trial_idx;
    
    trial_table = table();
    trial_table.sub = repmat({file_info.subject{1}}, n_samples, 1);
    trial_table.task = repmat({file_info.task{1}}, n_samples, 1);
    trial_table.run = repmat(file_info.run, n_samples, 1);
    trial_table.trial_index = repmat(global_trial_idx, n_samples, 1);
    trial_table.trial_label = trial_phases_ds; % CORRECTED: Use trial_label (matches R code)
    trial_table.time = trial_times_rel_ds;
    trial_table.pupil = trial_pupil_ds;
    trial_table.has_behavioral_data = repmat(trial_is_valid, n_samples, 1); % CORRECTED: Match R code
    trial_table.baseline_quality = repmat(baseline_quality, n_samples, 1);
    trial_table.trial_quality = repmat(trial_quality, n_samples, 1);
    trial_table.overall_quality = repmat(overall_quality, n_samples, 1);
    
    run_data = [run_data; trial_table];
    
    % Update quality metrics
    run_quality.n_trials = run_quality.n_trials + 1;
    if trial_is_valid
        run_quality.n_valid_trials = run_quality.n_valid_trials + 1;
    end
    
    % CORRECTED: Count samples per phase for 8 phases
    for p = 1:CONFIG.phases.count
        phase_samples = sum(strcmp(trial_phases_ds, CONFIG.phases.names{p}));
        run_quality.phase_samples(p) = run_quality.phase_samples(p) + phase_samples;
    end
end
end

function phase_labels = create_correct_phase_labels(trial_times, squeeze_time, ...
    event_times, event_from, event_to, CONFIG)
% FULLY CORRECTED phase labeling based on your exact 8-phase paradigm timing

% Initialize all as ITI baseline
phase_labels = cell(length(trial_times), 1);
phase_labels(:) = {'ITI_Baseline'};

% Apply phase labels based on EXACT 8-phase paradigm timing
for i = 1:length(trial_times)
    t = trial_times(i);
    time_rel = t - squeeze_time;  % Relative to squeeze onset
    
    % FULLY CORRECTED PHASE ASSIGNMENTS
    if time_rel < 0
        phase_labels{i} = 'ITI_Baseline';
        
    % Phase 2: Squeeze period (3000ms handgrip - EXACT timing)
    elseif time_rel >= 0 && time_rel < 3.0
        phase_labels{i} = 'Squeeze';
        
    % Phase 3: Post-squeeze blank (250ms - EXACT timing)
    elseif time_rel >= 3.0 && time_rel < 3.25
        phase_labels{i} = 'Post_Squeeze_Blank';
        
    % Phase 4: Pre-stimulus fixation (500ms - CRITICAL FIX!)
    elseif time_rel >= 3.25 && time_rel < 3.75
        phase_labels{i} = 'Pre_Stimulus_Fixation';
        
    % Phase 5: Stimulus presentation (700ms - CORRECTED timing)
    elseif time_rel >= 3.75 && time_rel < 4.45
        phase_labels{i} = 'Stimulus';
        
    % Phase 6: Post-stimulus fixation (250ms - CORRECTED timing)
    elseif time_rel >= 4.45 && time_rel < 4.7
        phase_labels{i} = 'Post_Stimulus_Fixation';
        
    % Phase 7: Response period (3000ms - CORRECTED timing)
    elseif time_rel >= 4.7 && time_rel < 7.7
        phase_labels{i} = 'Response_Different';
        
    % Phase 8: Confidence rating (3000ms - CORRECTED timing)
    elseif time_rel >= 7.7 && time_rel <= 10.7
        phase_labels{i} = 'Confidence';
        
    % Anything beyond paradigm duration
    else
        phase_labels{i} = 'ITI_Baseline';
    end
end
end

function save_quality_reports(quality_reports, CONFIG)
% Save comprehensive data quality reports

% Create summary table
summary_table = table();

for i = 1:length(quality_reports)
    report = quality_reports{i};
    
    row = table();
    row.subject = {report.subject};
    row.task = {report.task};
    row.session = {report.session};
    row.total_trials = report.total_trials;
    row.valid_trials = report.valid_trials;
    row.valid_trial_proportion = report.valid_trial_proportion;
    row.runs_processed = report.runs_processed;
    
    % Add phase proportions for all 8 phases
    for p = 1:length(report.phase_names)
        col_name = sprintf('phase_%d_%s_proportion', p, strrep(report.phase_names{p}, ' ', '_'));
        row.(col_name) = report.phase_proportions(p);
    end
    
    summary_table = [summary_table; row];
end

% Save summary
summary_path = fullfile(CONFIG.output_dir, 'BAP_pupillometry_data_quality_report.csv');
writetable(summary_table, summary_path);

% Save detailed text report
report_path = fullfile(CONFIG.output_dir, 'BAP_pupillometry_data_quality_detailed.txt');
fid = fopen(report_path, 'w');

fprintf(fid, 'BAP PUPILLOMETRY DATA QUALITY REPORT\n');
fprintf(fid, '====================================\n\n');
fprintf(fid, 'Generated: %s\n\n', datestr(now));

fprintf(fid, 'OVERALL SUMMARY:\n');
fprintf(fid, 'Total sessions processed: %d\n', length(quality_reports));

if ~isempty(quality_reports)
    total_trials_all = cellfun(@(x) x.total_trials, quality_reports);
    valid_trials_all = cellfun(@(x) x.valid_trials, quality_reports);
    
    fprintf(fid, 'Total trials processed: %d\n', sum(total_trials_all));
    fprintf(fid, 'Overall valid trial rate: %.1f%%\n\n', ...
        100 * sum(valid_trials_all) / sum(total_trials_all));
end

fprintf(fid, 'BY SESSION:\n');
fprintf(fid, 'Subject\tTask\tSession\tTrials\tValid\tRate\tRuns\n');
fprintf(fid, '-------\t----\t-------\t------\t-----\t----\t----\n');

for i = 1:length(quality_reports)
    report = quality_reports{i};
    fprintf(fid, '%s\t%s\t%s\t%d\t%d\t%.1f%%\t%d\n', ...
        report.subject, report.task, report.session, ...
        report.total_trials, report.valid_trials, ...
        100 * report.valid_trial_proportion, report.runs_processed);
end

fclose(fid);

fprintf('Quality reports saved:\n');
fprintf('  Summary: BAP_pupillometry_data_quality_report.csv\n');
fprintf('  Detailed: BAP_pupillometry_data_quality_detailed.txt\n');
end

function create_validation_plots(all_results, CONFIG)
% Create validation plots for the first subject

try
    unique_subs = unique(all_results.sub);
    if isempty(unique_subs)
        return;
    end
    
    first_sub = unique_subs{1};
    sub_data = all_results(strcmp(all_results.sub, first_sub), :);
    unique_trials = unique(sub_data.trial_index);
    
    % Plot first 3 trials
    plot_trials = unique_trials(1:min(3, length(unique_trials)));
    
    figure('Name', sprintf('Validation - %s', first_sub), 'Position', [100 100 1400 800]);
    
    colors = lines(CONFIG.phases.count); % CORRECTED: Use CONFIG.phases.count
    
    for i = 1:length(plot_trials)
        trial_num = plot_trials(i);
        trial_data = sub_data(sub_data.trial_index == trial_num, :);
        
        subplot(length(plot_trials), 1, i);
        hold on;
        
        % Plot by phase - CORRECTED for 8 phases
        for phase = 1:CONFIG.phases.count
            phase_mask = strcmp(trial_data.trial_label, CONFIG.phases.names{phase});
            if any(phase_mask)
                plot(trial_data.time(phase_mask), trial_data.pupil(phase_mask), ...
                    'Color', colors(phase, :), 'LineWidth', 1.5);
            end
        end
        
        % Add phase boundary lines
        for boundary_idx = 2:length(CONFIG.phases.boundaries)-1
            xline(CONFIG.phases.boundaries(boundary_idx), '--', 'Color', [0.5 0.5 0.5], 'Alpha', 0.7);
        end
        
        xline(0, 'k--', 'Squeeze Onset', 'LabelVerticalAlignment', 'top');
        title(sprintf('Trial %d - Full 8-Phase Timeline', trial_num));
        xlabel('Time (s, relative to squeeze onset)');
        ylabel('Pupil Diameter');
        grid on;
        
        if i == 1
            legend(CONFIG.phases.names, 'Location', 'eastoutside');
        end
    end
    
    % Save plot
    plot_path = fullfile(CONFIG.output_dir, sprintf('%s_validation_plot.png', first_sub));
    saveas(gcf, plot_path);
    
    fprintf('Validation plot saved: %s_validation_plot.png\n', first_sub);
    
catch ME
    fprintf('Could not create validation plot: %s\n', ME.message);
end
end
