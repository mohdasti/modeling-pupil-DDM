%% Test Script: Run Pipeline on BAP003_ADT with New Fixes
% This script tests the audit fixes on a single subject (BAP003_ADT)

clear; close all; clc;

%% Configuration
CONFIG = struct();
CONFIG.cleaned_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned';
CONFIG.raw_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data';
CONFIG.output_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed';
CONFIG.target_fs = 250;
CONFIG.original_fs = 2000;

% Experimental design parameters
CONFIG.experiment = struct();
CONFIG.experiment.trials_per_session = 150;
CONFIG.experiment.runs_per_session = 5;

% Event codes
CONFIG.event_codes = struct();
CONFIG.event_codes.baseline = 3040;
CONFIG.event_codes.squeeze_start = 3044;
CONFIG.event_codes.stimulus_start = 3042;
CONFIG.event_codes.response_start = 3041;
CONFIG.event_codes.confidence_start = 3048;

% Timing
CONFIG.timing = struct();
CONFIG.timing.iti_min = 1.5;
CONFIG.timing.iti_max = 4.5;
CONFIG.timing.squeeze_duration = 3.0;
CONFIG.timing.post_squeeze_blank = 0.25;
CONFIG.timing.pre_stimulus_fixation = 0.5;
CONFIG.timing.stimulus_duration = 0.7;
CONFIG.timing.post_stim_fixation = 0.25;
CONFIG.timing.response_duration = 3.0;
CONFIG.timing.confidence_duration = 3.0;
CONFIG.timing.max_trial_duration = 18.5;

% Phase definitions
CONFIG.phases = struct();
CONFIG.phases.count = 8;
CONFIG.phases.names = {'ITI_Baseline', 'Squeeze', 'Post_Squeeze_Blank', ...
                      'Pre_Stimulus_Fixation', 'Stimulus', 'Post_Stimulus_Fixation', ...
                      'Response_Different', 'Confidence'};
CONFIG.phases.boundaries = [
    -3.0;    % ITI_Baseline starts
     0.0;    % Squeeze starts
     3.0;    % Post_Squeeze_Blank starts
     3.25;   % Pre_Stimulus_Fixation starts
     3.75;   % Stimulus starts
     4.45;   % Post_Stimulus_Fixation starts
     4.7;    % Response_Different starts
     7.7;    % Confidence starts
    10.7     % Trial ends
];

% Data quality thresholds
CONFIG.quality = struct();
CONFIG.quality.min_valid_proportion = 0.80;   % 80% valid data per trial
CONFIG.quality.min_samples_per_trial = 100;

%% Find BAP003 ADT files
fprintf('=== TESTING FIXES ON BAP003_ADT ===\n\n');

cleaned_files = dir(fullfile(CONFIG.cleaned_dir, 'subjectBAP003_Aoddball*_cleaned.mat'));
fprintf('Found %d cleaned files for BAP003_ADT\n', length(cleaned_files));

if isempty(cleaned_files)
    error('No cleaned files found for BAP003_ADT');
end

%% Process files
% We'll use the main pipeline function but filter for BAP003 only
% For testing, let's process just the first run
test_file = cleaned_files(1);
fprintf('\nProcessing test file: %s\n', test_file.name);

% Extract subject info from filename
filename_parts = strsplit(test_file.name, '_');
subject = 'BAP003';
task = 'ADT';
session = '3';
run_num = 1;  % Will need to extract from filename

% Load and process
cleaned_path = fullfile(CONFIG.cleaned_dir, test_file.name);
cleaned_data = load(cleaned_path);

% Find corresponding raw file
raw_filename = strrep(test_file.name, '_eyetrack_cleaned.mat', '_eyetrack.mat');
raw_path = fullfile(CONFIG.raw_dir, sprintf('sub-%s/ses-%s/InsideScanner/%s', ...
    subject, session, raw_filename));

if ~exist(raw_path, 'file')
    error('Raw file not found: %s', raw_path);
end

raw_data = load(raw_path);

% Create file_info structure
file_info = struct();
file_info.subject = {subject};
file_info.task = {task};
file_info.session = {session};
file_info.run = run_num;
file_info.filename = {test_file.name};

% Process with fixes
fprintf('\n--- Processing with NEW FIXES ---\n');
[run_data, run_quality] = process_single_run_improved(cleaned_data, raw_data, ...
    file_info, 0, CONFIG);

%% Display results
fprintf('\n=== RESULTS ===\n');
fprintf('Trials processed: %d\n', run_quality.n_trials);
fprintf('Valid trials: %d\n', run_quality.n_valid_trials);

if ~isempty(run_data)
    fprintf('\nSample data check:\n');
    fprintf('Total samples: %d\n', height(run_data));
    
    % Check for zeros
    zero_count = sum(run_data.pupil == 0);
    nan_count = sum(isnan(run_data.pupil));
    fprintf('Zero values: %d (%.2f%%)\n', zero_count, 100*zero_count/height(run_data));
    fprintf('NaN values: %d (%.2f%%)\n', nan_count, 100*nan_count/height(run_data));
    
    % Check trial_in_run
    if ismember('trial_in_run', run_data.Properties.VariableNames)
        fprintf('trial_in_run present: YES\n');
        unique_trials = unique(run_data.trial_in_run);
        fprintf('Unique trial_in_run values: %s\n', mat2str(unique_trials));
    else
        fprintf('trial_in_run present: NO\n');
    end
    
    % Quality metrics
    if ismember('baseline_quality', run_data.Properties.VariableNames)
        fprintf('Mean baseline quality: %.3f\n', mean(run_data.baseline_quality, 'omitnan'));
    end
    if ismember('overall_quality', run_data.Properties.VariableNames)
        fprintf('Mean overall quality: %.3f\n', mean(run_data.overall_quality, 'omitnan'));
    end
    
    % Save test output
    output_file = fullfile(CONFIG.output_dir, 'BAP003_ADT_test_fixed.csv');
    writetable(run_data, output_file);
    fprintf('\nTest output saved to: %s\n', output_file);
else
    fprintf('WARNING: No data processed!\n');
end

fprintf('\n=== TEST COMPLETE ===\n');









