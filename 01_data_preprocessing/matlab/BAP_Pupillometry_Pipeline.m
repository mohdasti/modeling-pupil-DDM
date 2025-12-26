function BAP_Pupillometry_Pipeline()
%% BAP Pupillometry Processing Pipeline - FULLY CORRECTED FOR 8-PHASE PARADIGM
% This script processes pupillometry data with proper trial structure understanding
% Note: Stimulus phase is 700ms consisting of: Standard (100ms) + ISI (500ms) + Target (100ms)

%% Configuration - FULLY CORRECTED FOR 8-PHASE PARADIGM
% PATH CONFIGURATION: Try to load from config file, fallback to example
CONFIG = struct();
[script_dir, ~, ~] = fileparts(mfilename('fullpath'));
repo_root = fullfile(script_dir, '..', '..');
config_dir = fullfile(repo_root, 'config');

% Try to load config file from config/ directory
if exist(fullfile(config_dir, 'paths_config.m'), 'file')
    % Add config directory to path temporarily
    addpath(config_dir);
    CONFIG = paths_config();
    rmpath(config_dir);  % Remove after use
    fprintf('Loaded paths from config/paths_config.m\n');
elseif exist(fullfile(config_dir, 'paths_config.m.example'), 'file')
    % Fallback to example (with warning)
    addpath(config_dir);
    CONFIG = paths_config();
    rmpath(config_dir);
    warning('Using config/paths_config.m.example - consider creating your own config/paths_config.m');
    fprintf('Loaded paths from config/paths_config.m.example (fallback)\n');
elseif exist('paths_config.m', 'file')
    % Try current directory (for backward compatibility)
    CONFIG = paths_config();
    fprintf('Loaded paths from local paths_config.m\n');
else
    % Last resort: try to infer from script location
    CONFIG.cleaned_dir = fullfile(repo_root, 'data', 'BAP_cleaned');
    CONFIG.raw_dir = fullfile(repo_root, 'data', 'raw');
    CONFIG.output_dir = fullfile(repo_root, 'data', 'BAP_processed');
    warning('No paths_config.m found. Using inferred paths from script location.');
    fprintf('Inferred paths from script location (repo_root: %s)\n', repo_root);
end

% Validate paths exist
if ~exist(CONFIG.cleaned_dir, 'dir')
    error('CONFIG.cleaned_dir does not exist: %s\nPlease create config/paths_config.m or edit paths in this file.', CONFIG.cleaned_dir);
end
if ~exist(CONFIG.raw_dir, 'dir')
    error('CONFIG.raw_dir does not exist: %s\nPlease create config/paths_config.m or edit paths in this file.', CONFIG.raw_dir);
end

% Pipeline parameters
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
CONFIG.timing.stimulus_duration = 0.7;       % 700ms stimulus sequence (Standard 100ms + ISI 500ms + Target 100ms)
CONFIG.timing.post_stim_fixation = 0.25;     % 250ms post-stimulus fixation
CONFIG.timing.response_duration = 3.0;       % 3000ms "Different?" response
CONFIG.timing.confidence_duration = 3.0;     % 3000ms confidence rating

% CORRECTED total trial duration calculation
% ITI(max 4.5) + Squeeze(3.0) + Post_Squeeze(0.25) + Pre_Stim_Fix(0.5) + 
% Stimulus(0.7 = Standard 100ms + ISI 500ms + Target 100ms) + Post_Stim_Fix(0.25) + Response(3.0) + Confidence(3.0) = 15.2s
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
% CRITICAL FIX: min_valid_proportion is now used for QC FLAGS only, not for exclusion
% MATLAB exports ALL trials and flags QC issues; analysis-specific gates applied later in R/QMD
CONFIG.quality.min_valid_proportion = 0.80;   % Threshold for QC flags (qc_fail_baseline, qc_fail_overall)
CONFIG.quality.min_samples_per_trial = 100;  % Minimum samples per trial (ONLY hard exclusion criterion)

CONFIG.analysis_mode = 'fMRI';  % or 'physiological'

% Create base output directory
if ~exist(CONFIG.output_dir, 'dir')
    mkdir(CONFIG.output_dir);
end

% HARDENING: Create BUILD_ID and build-specific directory for provenance isolation
[CONFIG.build_dir, CONFIG.BUILD_ID] = create_build_directory(CONFIG.output_dir);
CONFIG.qc_dir = fullfile(CONFIG.build_dir, 'qc_matlab');
if ~exist(CONFIG.qc_dir, 'dir')
    mkdir(CONFIG.qc_dir);
end

% HARDENING: Generate pipeline_run_id for reproducibility
CONFIG.pipeline_run_id = get_pipeline_run_id();
fprintf('Pipeline Run ID: %s\n', CONFIG.pipeline_run_id);

%% Main Processing Pipeline
fprintf('=== BAP PUPILLOMETRY PROCESSING PIPELINE - FULLY CORRECTED ===\n\n');
fprintf('BUILD_ID: %s\n', CONFIG.BUILD_ID);
fprintf('Build directory: %s\n', CONFIG.build_dir);
fprintf('Cleaned files directory: %s\n', CONFIG.cleaned_dir);
fprintf('Raw files directory: %s\n', CONFIG.raw_dir);
fprintf('Output directory: %s\n\n', CONFIG.build_dir);

% Find all cleaned files
cleaned_files = dir(fullfile(CONFIG.cleaned_dir, '*_cleaned.mat'));
fprintf('Found %d cleaned files\n', length(cleaned_files));

if isempty(cleaned_files)
    fprintf('ERROR: No cleaned files found in %s\n', CONFIG.cleaned_dir);
    return;
end

% CONTAMINATION GUARD: Filter out OutsideScanner, practice, and invalid files
excluded_files = table();
excluded_files.file = {};
excluded_files.subject = {};
excluded_files.task = {};
excluded_files.parsed_session = {};
excluded_files.parsed_run = {};
excluded_files.session_inferred = {};
excluded_files.inference_reason = {};
excluded_files.excluded_reason = {};

inferred_files = table();
inferred_files.file = {};
inferred_files.subject = {};
inferred_files.task = {};
inferred_files.parsed_session = {};
inferred_files.parsed_run = {};
inferred_files.inference_reason = {};

valid_files = true(length(cleaned_files), 1);
for i = 1:length(cleaned_files)
    filename = cleaned_files(i).name;
    full_path = fullfile(CONFIG.cleaned_dir, filename);
    
    % Try to parse metadata first
    metadata = parse_filename(filename);
    
    % Check for OutsideScanner
    if contains(full_path, 'OutsideScanner') || contains(filename, 'OutsideScanner')
        valid_files(i) = false;
        subject_val = ''; task_val = ''; session_val = ''; run_val = NaN;
        if ~isempty(metadata)
            subject_val = metadata.subject;
            task_val = metadata.task;
            if isfield(metadata, 'session'), session_val = metadata.session; end
            if isfield(metadata, 'run'), run_val = metadata.run; end
        end
        excluded_files = [excluded_files; table({filename}, {subject_val}, {task_val}, ...
            {session_val}, run_val, {false}, {''}, {'OutsideScanner'}, ...
            'VariableNames', {'file', 'subject', 'task', 'parsed_session', 'parsed_run', ...
            'session_inferred', 'inference_reason', 'excluded_reason'})];
        fprintf('EXCLUDED (OutsideScanner): %s\n', filename);
        continue;
    end
    
    % Check for practice runs
    if contains(lower(filename), 'practice') || contains(lower(filename), 'prac')
        valid_files(i) = false;
        subject_val = ''; task_val = ''; session_val = ''; run_val = NaN;
        if ~isempty(metadata)
            subject_val = metadata.subject;
            task_val = metadata.task;
            if isfield(metadata, 'session'), session_val = metadata.session; end
            if isfield(metadata, 'run'), run_val = metadata.run; end
        end
        excluded_files = [excluded_files; table({filename}, {subject_val}, {task_val}, ...
            {session_val}, run_val, {false}, {''}, {'practice'}, ...
            'VariableNames', {'file', 'subject', 'task', 'parsed_session', 'parsed_run', ...
            'session_inferred', 'inference_reason', 'excluded_reason'})];
        fprintf('EXCLUDED (practice): %s\n', filename);
        continue;
    end
    
    % Check if session was inferred
    if ~isempty(metadata) && isfield(metadata, 'session_inferred') && metadata.session_inferred
        subject_val = metadata.subject;
        task_val = metadata.task;
        session_val = metadata.session;
        run_val = metadata.run;
        inference_reason = 'session_defaulted_to_2';
        if isfield(metadata, 'inference_reason')
            inference_reason = metadata.inference_reason;
        end
        inferred_files = [inferred_files; table({filename}, {subject_val}, {task_val}, ...
            {session_val}, run_val, {inference_reason}, ...
            'VariableNames', {'file', 'subject', 'task', 'parsed_session', 'parsed_run', 'inference_reason'})];
    end
    
    % Check if parse failed (metadata empty)
    if isempty(metadata)
        valid_files(i) = false;
        excluded_files = [excluded_files; table({filename}, {''}, {''}, {''}, NaN, {false}, {''}, {'parse_failed'}, ...
            'VariableNames', {'file', 'subject', 'task', 'parsed_session', 'parsed_run', ...
            'session_inferred', 'inference_reason', 'excluded_reason'})];
        fprintf('EXCLUDED (parse_failed): %s\n', filename);
        continue;
    end
end

% Apply filter
cleaned_files = cleaned_files(valid_files);
fprintf('After contamination filter: %d files remaining\n', length(cleaned_files));
if height(excluded_files) > 0
    fprintf('Excluded %d files (see qc_matlab_excluded_files.csv)\n', height(excluded_files));
end
if height(inferred_files) > 0
    fprintf('Session inferred for %d files (see qc_matlab_inferred_session_files.csv)\n', height(inferred_files));
end

% Store excluded/inferred files for QC output
CONFIG.excluded_files = excluded_files;
CONFIG.inferred_files = inferred_files;

% Organize files by subject and session
file_groups = organize_files_by_session(cleaned_files);
fprintf('Organized into %d subject/session groups\n\n', length(file_groups));

%% Process each subject/session combination
all_results = table();
all_quality_reports = {};
all_run_qc_stats = {};  % CRITICAL FIX: Store run-level QC stats separately
manifest_data = {};  % HARDENING: Track manifest for provenance isolation

for group_idx = 1:length(file_groups)
    
    current_group = file_groups{group_idx};
    subject = current_group.subject;
    task = current_group.task;
    session = current_group.session;
    
    fprintf('=== PROCESSING %s - %s (Session %s) ===\n', subject, task, session);
    fprintf('Files: %d runs\n', height(current_group.files));
    
    % Process all runs for this subject/session
    [session_data, session_quality, run_qc_list, session_manifest] = process_session(current_group, CONFIG);
    
    % HARDENING: Collect manifest entries
    if ~isempty(session_manifest)
        manifest_data = [manifest_data, session_manifest];
    end
    
    if ~isempty(session_data)
        all_results = [all_results; session_data];
        session_quality.subject = subject;
        session_quality.task = task;
        session_quality.session = session;
        all_quality_reports{end+1} = session_quality;
        
        % CRITICAL FIX: Store run-level QC stats with subject/task/session/run info
        for run_idx = 1:length(run_qc_list)
            if ~isempty(run_qc_list{run_idx})
                run_qc = run_qc_list{run_idx};
                run_qc.subject = subject;
                run_qc.task = task;
                run_qc.session = session;
                all_run_qc_stats{end+1} = run_qc;
            end
        end
        
        fprintf('SUCCESS: %d trials processed\n', session_quality.total_trials);
    else
        fprintf('WARNING: No data processed for this session\n');
    end
end

% CRITICAL FIX: QC summary tables are now created by write_qc_outputs() at the end
% Removed duplicate call to create_qc_summary_tables() to avoid function error

%% Save results and quality reports
fprintf('\n=== SAVING RESULTS ===\n');

% HARDENING: Write manifest first (before any other outputs)
if ~isempty(manifest_data)
    write_manifest(manifest_data, CONFIG.build_dir);
    fprintf('Manifest written: %d runs tracked\n', length(manifest_data));
else
    fprintf('WARNING: No manifest data to write\n');
end

if height(all_results) > 0
    % HARDENING: Save flat files to build directory
    unique_combos = unique(all_results(:, {'sub', 'task'}));
    
    for combo_idx = 1:height(unique_combos)
        current_sub = unique_combos.sub{combo_idx};
        current_task = unique_combos.task{combo_idx};
        
        combo_mask = strcmp(all_results.sub, current_sub) & strcmp(all_results.task, current_task);
        combo_data = all_results(combo_mask, :);
        combo_data = sortrows(combo_data, {'run', 'trial_index', 'time'});
        
        % HARDENING: Add pipeline_run_id metadata
        if ~ismember('pipeline_run_id', combo_data.Properties.VariableNames)
            combo_data.pipeline_run_id = repmat({CONFIG.pipeline_run_id}, height(combo_data), 1);
        end
        
        % Save CSV to build directory
        output_filename = sprintf('%s_%s_flat.csv', current_sub, current_task);
        output_path = fullfile(CONFIG.build_dir, output_filename);
        writetable(combo_data, output_path);

        n_trials = length(unique(combo_data.trial_index));
        n_runs = length(unique(combo_data.run));
        fprintf('Saved %s: %d trials across %d runs\n', output_filename, n_trials, n_runs);
    end
    
    % Save comprehensive quality report (to build directory)
    save_quality_reports(all_quality_reports, CONFIG);
    
    % HARDENING: Write mandatory QC outputs (to build/qc_matlab)
    write_qc_outputs(all_quality_reports, all_run_qc_stats, CONFIG);
    
    % FALSIFICATION: Write falsification metrics CSV
    write_falsification_qc(all_run_qc_stats, CONFIG);
    
    % FALSIFICATION: Generate validation summary
    generate_falsification_summary(all_run_qc_stats, CONFIG);
    
    % FALSIFICATION CHECK F: Print validation summary
    print_falsification_summary(all_run_qc_stats, CONFIG);
    
    % HARDENING: Generate trial-level flags from flat files
    generate_trial_level_flags(CONFIG.build_dir, CONFIG);
    
    % Create validation plots
    create_validation_plots(all_results, CONFIG);
    
    % HARDENING: Generate audit report
    generate_audit_report(manifest_data, all_run_qc_stats, all_quality_reports, CONFIG);
    
else
    fprintf('No data to save\n');
end

fprintf('\n=== PROCESSING COMPLETE ===\n');
fprintf('BUILD_ID: %s\n', CONFIG.BUILD_ID);
fprintf('All outputs saved to: %s\n', CONFIG.build_dir);

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

% Extract session and run - CRITICAL FIX: Fail hard instead of defaulting
% Try multiple patterns for session, handling spaces and case variations
% Pattern 1: session3, session 3, Session3, Session 3 (with optional space)
session_match = regexp(filename, 'session\s*(\d+)', 'tokens', 'ignorecase');
if isempty(session_match)
    % Pattern 2: ses-2, ses_2, ses2, etc.
    session_match = regexp(filename, 'ses[-_]?\s*(\d+)', 'tokens', 'ignorecase');
end

% LENIENT FIX: If session number is missing but we see "session" followed by "run",
% try to infer session from context (default to 2 or 3 if in valid range)
if isempty(session_match)
    % Check if we have "session" keyword followed by "run" (missing session number)
    if ~isempty(regexp(filename, 'session', 'ignorecase')) && ~isempty(regexp(filename, 'run\s*\d+', 'ignorecase'))
        % Try to extract from date pattern or default to 2 (most common)
        % Look for pattern like session_<number>_run or session_run
        % For now, default to session 2 if we can't find it
        session_match = {{'2'}};  % Default to session 2
        warning('LENIENT: Cannot parse session number from filename: %s. Defaulting to session 2.', filename);
    else
        warning('CRITICAL: Cannot parse session from filename: %s. Skipping file.', filename);
        metadata = [];
        return;
    end
end
metadata.session = session_match{1}{1};
session_num = str2double(metadata.session);

% CRITICAL FIX: Only allow sessions 2 or 3 (InsideScanner tasks)
if session_num ~= 2 && session_num ~= 3
    warning('CRITICAL: Session %d not in {2,3} for file: %s. Skipping file.', session_num, filename);
    metadata = [];
    return;
end

% Try multiple patterns for run, handling spaces and case variations
% Pattern: run1, run 1, Run1, Run 1 (with optional space)
run_match = regexp(filename, 'run\s*(\d+)', 'tokens', 'ignorecase');
if isempty(run_match)
    % LENIENT FIX: If run number is missing, try to extract from pattern like session3_5_...
    % where the number after session3_ might be the run number
    session_str = metadata.session;
    % Try pattern: session3_5 or session3-5 (number immediately after session)
    % Use character class [_-] instead of [_\-] to avoid sprintf escape issues
    pattern1 = ['session' session_str '[_-](\d+)'];
    session_run_pattern = regexp(filename, pattern1, 'tokens', 'ignorecase');
    if isempty(session_run_pattern)
        % Also try: session3_5_ (with underscore after the number)
        pattern2 = ['session' session_str '[_-](\d+)[_-]'];
        session_run_pattern = regexp(filename, pattern2, 'tokens', 'ignorecase');
    end
    if ~isempty(session_run_pattern)
        potential_run = str2double(session_run_pattern{1}{1});
        % Check if it's a valid run number (1-5)
        if potential_run >= 1 && potential_run <= 5
            run_match = session_run_pattern;
            warning('LENIENT: Extracted run number %d from pattern in filename: %s', potential_run, filename);
        end
    end
end
if isempty(run_match)
    warning('CRITICAL: Cannot parse run from filename: %s. Skipping file.', filename);
    metadata = [];
    return;
end
metadata.run = str2double(run_match{1}{1});
end

function [session_data, quality_report, run_qc_list, manifest_entries] = process_session(file_group, CONFIG)
% Process all runs for a single session with cumulative trial indexing
% CRITICAL FIX: Returns run_qc_list for QC summary tables
% HARDENING: Returns manifest_entries for provenance tracking

session_data = table();
quality_report = struct();
run_qc_list = {};  % CRITICAL FIX: Store QC stats for each run
manifest_entries = {};  % HARDENING: Store manifest entries for this session

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
        
        % HARDENING: Find logP file path
        logP_filename = strrep(file_info.filename{1}, '_eyetrack_cleaned.mat', '_logP.txt');
        logP_path = fullfile(CONFIG.raw_dir, sprintf('sub-%s/ses-%s/InsideScanner/%s', ...
            file_info.subject{1}, file_info.session{1}, logP_filename));
        
        if ~exist(raw_path, 'file')
            fprintf('    WARNING: Raw file not found: %s\n', raw_path);
            % HARDENING: Still create manifest entry for skipped runs
            manifest_entry = struct();
            manifest_entry.subject = file_info.subject{1};
            manifest_entry.task = file_info.task{1};
            manifest_entry.session = file_info.session{1};
            manifest_entry.run = file_info.run;
            manifest_entry.cleaned_mat_path = cleaned_path;
            manifest_entry.eyetrack_mat_path = raw_path;
            manifest_entry.logP_path = logP_path;
            manifest_entry.segmentation_source = 'skipped';
            manifest_entry.n_trials_extracted = 0;
            manifest_entry.n_log_trials = 0;
            manifest_entry.n_marker_anchors = 0;
            manifest_entry.timebase_method = 'unknown';
            manifest_entry.run_status = 'raw_file_missing';
            manifest_entry.notes = 'Raw eyetrack file not found';
            manifest_entries{end+1} = manifest_entry;
            continue;
        end
        
        raw_data = load(raw_path);
        
        % Process this run with improved error handling
        [run_data, run_quality] = process_single_run_improved(cleaned_data, raw_data, ...
            file_info, cumulative_trial_index, CONFIG);
        
        % HARDENING: Create manifest entry for this run
        manifest_entry = struct();
        manifest_entry.subject = file_info.subject{1};
        manifest_entry.task = file_info.task{1};
        manifest_entry.session = file_info.session{1};
        manifest_entry.run = file_info.run;
        manifest_entry.cleaned_mat_path = cleaned_path;
        manifest_entry.eyetrack_mat_path = raw_path;
        manifest_entry.logP_path = logP_path;
        
        if isfield(run_quality, 'segmentation_source')
            manifest_entry.segmentation_source = run_quality.segmentation_source;
        else
            manifest_entry.segmentation_source = 'unknown';
        end
        
        if isfield(run_quality, 'n_trials')
            manifest_entry.n_trials_extracted = run_quality.n_trials;
        else
            manifest_entry.n_trials_extracted = 0;
        end
        
        if isfield(run_quality, 'n_log_trials')
            manifest_entry.n_log_trials = run_quality.n_log_trials;
        else
            manifest_entry.n_log_trials = 0;
        end
        
        if isfield(run_quality, 'n_marker_anchors')
            manifest_entry.n_marker_anchors = run_quality.n_marker_anchors;
        else
            manifest_entry.n_marker_anchors = 0;
        end
        
        if isfield(run_quality, 'alignment_diagnostics') && isstruct(run_quality.alignment_diagnostics)
            if isfield(run_quality.alignment_diagnostics, 'method')
                manifest_entry.timebase_method = run_quality.alignment_diagnostics.method;
            else
                manifest_entry.timebase_method = 'unknown';
            end
        else
            manifest_entry.timebase_method = 'unknown';
        end
        
        if isfield(run_quality, 'run_status')
            manifest_entry.run_status = run_quality.run_status;
        else
            manifest_entry.run_status = 'success';
        end
        
        manifest_entry.notes = '';
        manifest_entries{end+1} = manifest_entry;
        
        if ~isempty(run_data)
            session_data = [session_data; run_data];
            
            % Update quality report
            quality_report.total_trials = quality_report.total_trials + run_quality.n_trials;
            quality_report.valid_trials = quality_report.valid_trials + run_quality.n_valid_trials;
            quality_report.runs_processed = quality_report.runs_processed + 1;
            quality_report.phase_quality = quality_report.phase_quality + run_quality.phase_samples;
            
            % CRITICAL FIX: Store QC stats per-run for QC summary tables
            if isfield(run_quality, 'qc_stats') && ~isempty(run_quality.qc_stats)
                run_qc = run_quality.qc_stats;
                run_qc.run = file_info.run;  % Add run number
                run_qc.subject = file_info.subject{1};
                run_qc.task = file_info.task{1};
                run_qc.session = file_info.session{1};
                % HARDENING: Store segmentation and alignment info
                if isfield(run_quality, 'segmentation_source')
                    run_qc.segmentation_source = run_quality.segmentation_source;
                end
                if isfield(run_quality, 'n_log_trials')
                    run_qc.n_log_trials = run_quality.n_log_trials;
                end
                if isfield(run_quality, 'n_marker_anchors')
                    run_qc.n_marker_anchors = run_quality.n_marker_anchors;
                end
                if isfield(run_quality, 'alignment_diagnostics')
                    run_qc.alignment_diagnostics = run_quality.alignment_diagnostics;
                end
                % FALSIFICATION: Store run status and additional diagnostics
                if isfield(run_quality, 'run_status')
                    run_qc.run_status = run_quality.run_status;
                else
                    run_qc.run_status = 'unknown';
                end
                if isfield(run_quality, 'logP_plausibility_valid')
                    run_qc.logP_plausibility_valid = run_quality.logP_plausibility_valid;
                end
                run_qc_list{end+1} = run_qc;  % Store for later aggregation
            end
            
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
% HARDENING: Now supports logP-driven segmentation as fallback

run_data = table();
run_quality = struct();
run_quality.n_trials = 0;
run_quality.n_valid_trials = 0;
run_quality.phase_samples = zeros(CONFIG.phases.count, 1); % FIXED: Use CONFIG.phases.count

% Initialize alignment_diagnostics early to ensure it's always set
run_quality.alignment_diagnostics = struct();
run_quality.alignment_diagnostics.success = false;
run_quality.alignment_diagnostics.method = 'unknown';
run_quality.alignment_diagnostics.offset = NaN;
run_quality.alignment_diagnostics.confidence = 'unknown';

% HARDENING: Try to load logP file for fallback segmentation
logP_path = fullfile(CONFIG.raw_dir, sprintf('sub-%s/ses-%s/InsideScanner/%s', ...
    file_info.subject{1}, file_info.session{1}, strrep(file_info.filename{1}, '_eyetrack_cleaned.mat', '_logP.txt')));
logP_data = struct();
logP_data.success = false;
logP_data.n_trials = 0;
logP_data.trial_st = [];

% FALSIFICATION CHECK A: Parse and validate logP plausibility
logP_plausibility_valid = true;
logP_plausibility_diagnostics = struct();

if exist(logP_path, 'file')
    logP_data = parse_logP_file(logP_path);
    if logP_data.success && logP_data.n_trials > 0
        fprintf('    Loaded logP: %d trials\n', logP_data.n_trials);
        
        % FALSIFICATION CHECK A: Validate logP timing intervals
        [logP_plausibility_valid, logP_plausibility_diagnostics] = validate_logP_plausibility(logP_data);
        if ~logP_plausibility_valid
            fprintf('    ERROR: logP plausibility check FAILED: %s\n', logP_plausibility_diagnostics.reason);
            run_quality.run_status = 'logP_invalid';
            run_quality.n_trials = 0;
            run_quality.alignment_diagnostics.method = 'logP_invalid';
            run_quality.alignment_diagnostics.confidence = 'low';
            return;
        else
            fprintf('    logP plausibility check PASSED\n');
        end
    else
        fprintf('    WARNING: logP file exists but parsing failed or returned 0 trials: %s\n', logP_path);
        logP_data.success = false;
    end
else
    fprintf('    WARNING: logP file not found: %s\n', logP_path);
end

% Extract pupil data
pupil = cleaned_data.S.data.sample;
timestamps = cleaned_data.S.data.smp_timestamp;
valid = cleaned_data.S.data.valid;

% CRITICAL FIX: Convert zeros and invalid samples to NaN (per audit recommendations)
% Zeros are physiologically impossible and should be treated as missing data
zero_mask = (pupil == 0 | isnan(pupil));
valid(zero_mask) = 0;  % Mark zeros as invalid
pupil(zero_mask) = NaN;  % Convert zeros to NaN so they are never analyzed as real values

% HARDENING: Convert pupil timestamps to PTB reference frame
pupil_time_ptb = timestamps;
alignment_diagnostics = struct();
alignment_diagnostics.success = false;
alignment_diagnostics.method = 'unknown';
alignment_diagnostics.offset = NaN;
alignment_diagnostics.confidence = 'unknown';

if logP_data.success
    [pupil_time_ptb, alignment_diagnostics] = convert_timebase(cleaned_data, logP_data, raw_data);
    if ~alignment_diagnostics.success
        fprintf('    WARNING: Timebase conversion failed, using original timestamps\n');
        pupil_time_ptb = timestamps;
        % Ensure fields exist even on failure
        if ~isfield(alignment_diagnostics, 'method')
            alignment_diagnostics.method = 'failed';
        end
        if ~isfield(alignment_diagnostics, 'offset')
            alignment_diagnostics.offset = NaN;
        end
        if ~isfield(alignment_diagnostics, 'confidence')
            alignment_diagnostics.confidence = 'low';
        end
    else
        fprintf('    Timebase conversion: method=%s, offset=%.3f, confidence=%s\n', ...
            alignment_diagnostics.method, alignment_diagnostics.offset, alignment_diagnostics.confidence);
    end
end

% Extract events from raw data (for optional event-code segmentation)
buffer_data = raw_data.bufferData;
event_times = buffer_data(:, 1);
event_codes = buffer_data(:, 8);

% Find ALL event transitions
transition_indices = find(diff(event_codes) ~= 0) + 1;
transition_times = [];
transition_from = [];
transition_to = [];

if ~isempty(transition_indices)
    transition_times = event_times(transition_indices);
    transition_from = event_codes(transition_indices - 1);
    transition_to = event_codes(transition_indices);
end

% HARDENING: Dual-mode segmentation - try event-code first, fallback to logP
squeeze_onsets = [];
segmentation_source = 'unknown';
n_marker_anchors = 0;

% Try event-code segmentation
if ~isempty(transition_times)
    squeeze_onsets_event = transition_times(transition_from == CONFIG.event_codes.baseline & ...
                                            transition_to == CONFIG.event_codes.squeeze_start);
    n_marker_anchors = length(squeeze_onsets_event);
    
    % Validate event-code segmentation
    % HARDENING: More lenient range (20-35) to handle partial runs, but prefer 28-30
    if n_marker_anchors >= 20 && n_marker_anchors <= 35
        % Check alignment with logP if available
        if logP_data.success && ~isempty(logP_data.trial_st) && length(logP_data.trial_st) >= 20
            % Compare event anchors to logP anchors
            residuals = [];
            for i = 1:min(length(squeeze_onsets_event), length(logP_data.trial_st))
                [min_residual, ~] = min(abs(squeeze_onsets_event - logP_data.trial_st(i)));
                residuals(end+1) = min_residual;
            end
            median_residual = median(residuals);
            
            % FALSIFICATION: Store residuals for QC output
            run_quality.falsification_residuals = residuals;
            run_quality.residual_median_abs_ms = median(abs(residuals)) * 1000;  % Convert to ms
            run_quality.residual_max_abs_ms = max(abs(residuals)) * 1000;
            if length(residuals) > 1
                run_quality.residual_p95_abs_ms = prctile(abs(residuals), 95) * 1000;
            else
                run_quality.residual_p95_abs_ms = run_quality.residual_max_abs_ms;
            end
            run_quality.flagged_falsification = (run_quality.residual_max_abs_ms > 50) || ...
                                               (run_quality.residual_median_abs_ms > 20);
            run_quality.segmentation_source_for_residuals = 'both_available';
            
            if median_residual < 0.02  % 20ms tolerance
                squeeze_onsets = squeeze_onsets_event;
                segmentation_source = 'event_code';
                if n_marker_anchors >= 28 && n_marker_anchors <= 30
                    fprintf('    Event-code segmentation: %d trials (median residual vs logP: %.3f s)\n', ...
                        length(squeeze_onsets), median_residual);
                else
                    fprintf('    Event-code segmentation: %d trials (WARNING: outside [28,30] range, median residual: %.3f s)\n', ...
                        length(squeeze_onsets), median_residual);
                end
            else
                fprintf('    Event-code segmentation failed validation (median residual: %.3f s > 20ms)\n', ...
                    median_residual);
            end
        else
            % No logP to validate against - must pass strict plausibility checks
            % Requirements: n_trials in [28,30], strictly increasing, median ITI [8,25]s, min ITI >= 5s
            if n_marker_anchors >= 28 && n_marker_anchors <= 30
                % Check monotonicity
                is_monotonic = all(diff(squeeze_onsets_event) > 0);
                
                % Compute ITI
                if length(squeeze_onsets_event) > 1
                    iti = diff(squeeze_onsets_event);
                    median_iti = median(iti);
                    min_iti = min(iti);
                else
                    is_monotonic = false;
                    median_iti = NaN;
                    min_iti = NaN;
                end
                
                % Validate plausibility
                if is_monotonic && median_iti >= 8 && median_iti <= 25 && min_iti >= 5
                    squeeze_onsets = squeeze_onsets_event;
                    segmentation_source = 'event_code';
                    fprintf('    Event-code segmentation: %d trials (no logP, passed plausibility: median_iti=%.2fs)\n', ...
                        length(squeeze_onsets), median_iti);
                else
                    fprintf('    Event-code segmentation FAILED plausibility (no logP):\n');
                    if ~is_monotonic
                        fprintf('      - Not strictly increasing\n');
                    end
                    if median_iti < 8 || median_iti > 25
                        fprintf('      - Median ITI=%.2fs (expected 8-25s)\n', median_iti);
                    end
                    if min_iti < 5
                        fprintf('      - Min ITI=%.2fs (<5s)\n', min_iti);
                    end
                    % Will fall back to logP if available, or skip
                end
            else
                fprintf('    Event-code segmentation: %d anchors (outside [28,30] range, no logP for validation)\n', ...
                    n_marker_anchors);
            end
        end
    else
        fprintf('    Event-code segmentation: %d anchors (outside acceptable [20,35] range)\n', n_marker_anchors);
    end
end

% Fallback to logP-driven segmentation
% HARDENING: More lenient range (20-35) to handle partial runs
if isempty(squeeze_onsets) && logP_data.success && ~isempty(logP_data.trial_st)
    if logP_data.n_trials >= 20 && logP_data.n_trials <= 35
        squeeze_onsets = logP_data.trial_st;
        segmentation_source = 'logP';
        
        % FALSIFICATION: Compute logP timing alignment checks
        % For each trial, check that expected events are within window bounds
        timing_errors = [];
        index_in_bounds_count = 0;
        total_checks = 0;
        
        for trial_idx = 1:length(squeeze_onsets)
            squeeze_time = squeeze_onsets(trial_idx);
            trial_start_time = squeeze_time - 3.0;
            trial_end_time = squeeze_time + 10.7;
            
            % Expected event times relative to squeeze (from paradigm)
            expected_events_rel = [0.0, 3.0, 3.25, 3.75, 3.76, 4.79];  % TrialST, blankST, fixST, fix_offset, A/V_ST, Resp1ST
            expected_events_ptb = squeeze_time + expected_events_rel;
            
            % Check if events are within window
            for evt_idx = 1:length(expected_events_ptb)
                total_checks = total_checks + 1;
                if expected_events_ptb(evt_idx) >= trial_start_time && expected_events_ptb(evt_idx) <= trial_end_time
                    index_in_bounds_count = index_in_bounds_count + 1;
                else
                    % Compute timing error (how far outside window)
                    if expected_events_ptb(evt_idx) < trial_start_time
                        timing_error = trial_start_time - expected_events_ptb(evt_idx);
                    else
                        timing_error = expected_events_ptb(evt_idx) - trial_end_time;
                    end
                    timing_errors(end+1) = timing_error * 1000;  % Convert to ms
                end
            end
        end
        
        % Store logP timing metrics
        if total_checks > 0
            run_quality.index_in_bounds_rate = index_in_bounds_count / total_checks;
        else
            run_quality.index_in_bounds_rate = NaN;
        end
        
        if ~isempty(timing_errors)
            run_quality.timing_error_ms_median = median(timing_errors);
            run_quality.timing_error_ms_p95 = prctile(timing_errors, 95);
            run_quality.timing_error_ms_max = max(timing_errors);
        else
            run_quality.timing_error_ms_median = 0;
            run_quality.timing_error_ms_p95 = 0;
            run_quality.timing_error_ms_max = 0;
        end
        
        run_quality.segmentation_source_for_residuals = 'logP_only';
        
        if logP_data.n_trials >= 28 && logP_data.n_trials <= 30
            fprintf('    logP fallback segmentation: %d trials\n', length(squeeze_onsets));
        else
            fprintf('    logP fallback segmentation: %d trials (WARNING: outside [28,30] range)\n', length(squeeze_onsets));
        end
    else
        fprintf('    ERROR: logP has %d trials (outside acceptable [20,35] range)\n', logP_data.n_trials);
    end
end

if isempty(squeeze_onsets)
    fprintf('    ERROR: No trial anchors found - skipping run\n');
    run_quality.segmentation_source = 'failed';
    run_quality.n_trials = 0;
    run_quality.alignment_diagnostics.method = 'no_anchors';
    run_quality.alignment_diagnostics.confidence = 'low';
    return;
end

fprintf('    Using %s segmentation: %d trials\n', segmentation_source, length(squeeze_onsets));

% CRITICAL FIX: Track original trial index (trial_idx) separately from kept counter
% trial_in_run_raw = original index (1..N detected trials) - used for merging
% trial_in_run_kept = counter of trials that pass QC (optional, not for merging)
trial_counter_kept = 0;

% Track QC statistics for this run
run_qc_stats = struct();
run_qc_stats.n_squeeze_onsets_detected = length(squeeze_onsets);
run_qc_stats.n_trials_exported = 0;
run_qc_stats.n_trials_hard_skipped_min_samples = 0;
run_qc_stats.baseline_quality_values = [];
run_qc_stats.overall_quality_values = [];
run_qc_stats.n_qc_fail_baseline = 0;
run_qc_stats.n_qc_fail_overall = 0;

% HARDENING: Use PTB-aligned timestamps for trial extraction
trial_timestamps = pupil_time_ptb;  % Use PTB-aligned timestamps

% FALSIFICATION CHECK C: Initialize trial_segments for anti-copy/paste checks
trial_segments = struct();
trial_segments.start_idx = [];
trial_segments.end_idx = [];
trial_segments.trial_hash = [];

% Initialize falsification check counters
window_oob_count = 0;
empty_trial_count = 0;
all_nan_trial_count = 0;

% Process each trial based on squeeze onsets
for trial_idx = 1:length(squeeze_onsets)
    
    squeeze_time = squeeze_onsets(trial_idx);
    
    % TRIAL WINDOW - CH3 EXTENSION: End at Resp1ET instead of end of confidence period
    trial_start_time = squeeze_time - 3.0;  % 3s before squeeze (sufficient for baseline)
    
    % Compute trial end time based on Resp1ET (preferred) with fallbacks
    % Expected: Resp1ET - TrialST ≈ 7.70s (Resp1ST 4.70 + 3.0s response window)
    seg_end_source = '';
    if logP_data.success && trial_idx <= length(logP_data.trial_st) && ...
       ~isempty(logP_data.resp1_et) && trial_idx <= length(logP_data.resp1_et) && ...
       ~isnan(logP_data.resp1_et(trial_idx))
        % Use Resp1ET from logP if available
        resp1_et_ptb = logP_data.resp1_et(trial_idx);
        trial_end_time = resp1_et_ptb;
        seg_end_source = 'Resp1ET';
        trial_end_rel = resp1_et_ptb - logP_data.trial_st(trial_idx);
    elseif logP_data.success && trial_idx <= length(logP_data.trial_st) && ...
           ~isempty(logP_data.resp1_st) && trial_idx <= length(logP_data.resp1_st) && ...
           ~isnan(logP_data.resp1_st(trial_idx))
        % Fallback: Resp1ST + 3.0s
        resp1_st_ptb = logP_data.resp1_st(trial_idx);
        trial_end_time = resp1_st_ptb + 3.0;
        seg_end_source = 'Resp1ST_plus_3';
        trial_end_rel = (resp1_st_ptb - logP_data.trial_st(trial_idx)) + 3.0;
    else
        % Fallback: Use fixed 7.70s relative to squeeze (TrialST)
        trial_end_time = squeeze_time + 7.70;
        seg_end_source = 'DEFAULT_7p70';
        trial_end_rel = 7.70;
    end
    
    trial_start_rel = -3.0;  % Always -3.0 relative to squeeze (TrialST)
    
    % HARDENING: Extract trial data using PTB-aligned timestamps
    trial_mask = trial_timestamps >= trial_start_time & trial_timestamps <= trial_end_time;
    
    % FALSIFICATION CHECK C: Store segment indices for anti-copy/paste checks
    trial_indices = find(trial_mask);
    if ~isempty(trial_indices)
        start_idx = trial_indices(1);
        end_idx = trial_indices(end);
        trial_segments.start_idx(end+1) = start_idx;
        trial_segments.end_idx(end+1) = end_idx;
    else
        start_idx = NaN;
        end_idx = NaN;
        trial_segments.start_idx(end+1) = NaN;
        trial_segments.end_idx(end+1) = NaN;
    end
    
    % CRITICAL FIX: Only hard-skip if insufficient samples (impossible to process)
    % This is the ONLY hard exclusion criterion
    if sum(trial_mask) < CONFIG.quality.min_samples_per_trial
        run_qc_stats.n_trials_hard_skipped_min_samples = run_qc_stats.n_trials_hard_skipped_min_samples + 1;
        empty_trial_count = empty_trial_count + 1;
        continue;
    end
    
    % FALSIFICATION CHECK B: Count empty and all-NaN trials
    if sum(trial_mask) == 0
        empty_trial_count = empty_trial_count + 1;
    end
    
    trial_pupil = pupil(trial_mask);
    trial_times = timestamps(trial_mask);
    trial_valid = valid(trial_mask);
    
    % FALSIFICATION CHECK B: Count empty and all-NaN trials
    if sum(trial_mask) == 0
        empty_trial_count = empty_trial_count + 1;
    end
    
    % FALSIFICATION CHECK B: Check if all samples are NaN/invalid
    if sum(trial_mask) > 0 && all(isnan(trial_pupil) | ~trial_valid)
        all_nan_trial_count = all_nan_trial_count + 1;
    end
    
    % FALSIFICATION CHECK C: Compute trial hash for duplicate detection
    if ~isempty(trial_pupil) && any(isfinite(trial_pupil))
        trial_hash = round(sum(trial_pupil(isfinite(trial_pupil))) + ...
                          mean(trial_pupil(isfinite(trial_pupil))) * 1000 + ...
                          var(trial_pupil(isfinite(trial_pupil))) * 1000000);
        trial_segments.trial_hash(end+1) = trial_hash;
    else
        trial_segments.trial_hash(end+1) = NaN;
    end
    
    % FALSIFICATION CHECK B: Check if all samples are NaN/invalid
    if sum(trial_mask) > 0 && all(isnan(trial_pupil) | ~trial_valid)
        all_nan_trial_count = all_nan_trial_count + 1;
    end
    
    % FALSIFICATION CHECK C: Compute trial hash for duplicate detection
    if ~isempty(trial_pupil) && any(isfinite(trial_pupil))
        trial_hash = round(sum(trial_pupil(isfinite(trial_pupil))) + ...
                          mean(trial_pupil(isfinite(trial_pupil))) * 1000 + ...
                          var(trial_pupil(isfinite(trial_pupil))) * 100);
        trial_segments.trial_hash(end+1) = trial_hash;
    else
        trial_segments.trial_hash(end+1) = NaN;
    end
    
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
    % CH3 EXTENSION: Trial window now ends at Resp1ET (~7.70s), not 10.7s
    % Note: trial_times_rel are already filtered by trial_mask (which used trial_end_time)
    % So we just need to check they're >= 0 (they'll naturally stop at trial_end_rel)
    trial_mask_full = trial_times_rel >= 0 & trial_times_rel <= 10.7;  % Upper bound doesn't matter since data is already filtered
    
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
    
    % CRITICAL FIX: Do NOT drop trials based on quality thresholds
    % Instead, compute QC flags and export ALL trials
    % Analysis-specific gates will be applied later in R/QMD
    
    % Compute QC flags (for downstream analysis, not for exclusion)
    qc_fail_baseline = baseline_quality < CONFIG.quality.min_valid_proportion;
    qc_fail_overall = overall_quality < CONFIG.quality.min_valid_proportion;
    
    % Track QC statistics
    run_qc_stats.baseline_quality_values = [run_qc_stats.baseline_quality_values; baseline_quality];
    run_qc_stats.overall_quality_values = [run_qc_stats.overall_quality_values; overall_quality];
    if qc_fail_baseline
        run_qc_stats.n_qc_fail_baseline = run_qc_stats.n_qc_fail_baseline + 1;
    end
    if qc_fail_overall
        run_qc_stats.n_qc_fail_overall = run_qc_stats.n_qc_fail_overall + 1;
    end
    
    % Increment kept counter (optional, for reporting only)
    trial_counter_kept = trial_counter_kept + 1;
    
    % Downsample if needed
    if CONFIG.original_fs ~= CONFIG.target_fs
        downsample_factor = round(CONFIG.original_fs / CONFIG.target_fs);
        
        % UPDATED: Apply anti-aliasing filter before downsampling (per audit recommendations)
        % Use 8th-order Butterworth filter with cutoff at 80% of Nyquist frequency
        % CRITICAL: Handle NaN values - filter only finite values, preserve NaN locations
        valid_mask = isfinite(trial_pupil) & trial_valid > 0;
        
        if sum(valid_mask) > 8  % Need enough valid samples to filter (at least filter order)
            try
                nyquist_freq = CONFIG.target_fs / 2;
                cutoff_freq = nyquist_freq * 0.8;  % 80% of Nyquist (200 Hz * 0.8 = 160 Hz)
                cutoff_normalized = cutoff_freq / (CONFIG.original_fs / 2);
                
                % Ensure cutoff is valid (between 0 and 1)
                if cutoff_normalized > 0 && cutoff_normalized < 1 && isfinite(cutoff_normalized)
                    [b, a] = butter(8, cutoff_normalized, 'low');
                    
                    % Filter only valid (finite) samples, preserve NaN locations
                    trial_pupil_filtered = trial_pupil;  % Start with original (includes NaN)
                    trial_pupil_valid = trial_pupil(valid_mask);
                    if ~isempty(trial_pupil_valid) && length(trial_pupil_valid) > 8 && all(isfinite(trial_pupil_valid))
                        trial_pupil_filtered(valid_mask) = filtfilt(b, a, trial_pupil_valid);
                    end
                else
                    % Invalid cutoff, skip filtering
                    trial_pupil_filtered = trial_pupil;
                end
            catch ME
                % If filtering fails for any reason, use original data
                fprintf('    WARNING: Filtering failed, using unfiltered data: %s\n', ME.message);
                trial_pupil_filtered = trial_pupil;
            end
        else
            % Not enough valid samples, skip filtering
            trial_pupil_filtered = trial_pupil;
        end
        
        % Use resample() which applies additional anti-aliasing
        % resample() handles NaN by interpolating, but we want to preserve NaN
        % So we'll resample and then restore NaN locations from downsampled valid mask
        try
            trial_pupil_ds = resample(trial_pupil_filtered, 1, downsample_factor);
            trial_times_rel_ds = resample(trial_times_rel, 1, downsample_factor);
        catch ME
            % If resample fails (e.g., too many NaN), use simple decimation
            fprintf('    WARNING: resample() failed, using decimation: %s\n', ME.message);
            trial_pupil_ds = trial_pupil_filtered(1:downsample_factor:end);
            trial_times_rel_ds = trial_times_rel(1:downsample_factor:end);
        end
        
        % Restore NaN locations in downsampled data (from invalid samples)
        trial_valid_ds = resample(double(trial_valid), 1, downsample_factor) > 0.5;
        trial_pupil_ds(~trial_valid_ds) = NaN;  % Ensure invalid samples are NaN
        
        % Handle phase labels (simple indexing for categorical data)
        trial_phases_ds = trial_phases(1:downsample_factor:end);
        if length(trial_phases_ds) ~= length(trial_pupil_ds)
            trial_phases_ds = trial_phases_ds(1:length(trial_pupil_ds));
        end
        
        % Downsample validity mask
        trial_valid_ds = resample(double(trial_valid), 1, downsample_factor) > 0.5;
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
    trial_table.ses = repmat(str2double(file_info.session{1}), n_samples, 1); % FORENSIC FIX: Add ses column from filename
    trial_table.run = repmat(file_info.run, n_samples, 1);
    trial_table.trial_index = repmat(global_trial_idx, n_samples, 1);
    
    % CRITICAL FIX: Use original trial_idx (1..N) as trial_in_run_raw for merging
    % This preserves alignment with behavioral data even if some trials fail QC
    % HARDENING: trial_in_run_raw = row index from logP (1..30) or event order
    % DO NOT renumber by "kept trials" - preserve original order
    if strcmp(segmentation_source, 'logP') && logP_data.success
        % Use logP row number (trial_idx corresponds to logP row)
        trial_table.trial_in_run_raw = repmat(trial_idx, n_samples, 1);
    else
        % Use event order
        trial_table.trial_in_run_raw = repmat(trial_idx, n_samples, 1);
    end
    trial_table.trial_in_run_kept = repmat(trial_counter_kept, n_samples, 1);  % Optional: kept counter (not for merging)
    
    % For backward compatibility, also include trial_in_run = trial_in_run_raw
    % But R merger should use trial_in_run_raw for merging
    trial_table.trial_in_run = repmat(trial_idx, n_samples, 1);  % Same as raw for now
    
    trial_table.trial_label = trial_phases_ds; % CORRECTED: Use trial_label (matches R code)
    trial_table.time = trial_times_rel_ds;
    trial_table.pupil = trial_pupil_ds;
    trial_table.has_behavioral_data = repmat(trial_is_valid, n_samples, 1); % CORRECTED: Match R code
    
    % Quality metrics (exported for downstream analysis)
    trial_table.baseline_quality = repmat(baseline_quality, n_samples, 1);
    trial_table.trial_quality = repmat(trial_quality, n_samples, 1);
    trial_table.overall_quality = repmat(overall_quality, n_samples, 1);
    
    % CRITICAL FIX: Add QC flags (for downstream gates, not for exclusion)
    trial_table.qc_fail_baseline = repmat(qc_fail_baseline, n_samples, 1);
    trial_table.qc_fail_overall = repmat(qc_fail_overall, n_samples, 1);
    
    % HARDENING: Store trial-level QC flags
    trial_table.trial_start_time_ptb = repmat(squeeze_time, n_samples, 1);
    trial_table.sample_count_in_window = repmat(sum(trial_mask), n_samples, 1);
    trial_table.window_oob = repmat(sum(trial_mask) == 0, n_samples, 1);  % True if no samples in window
    trial_table.segmentation_source = repmat({segmentation_source}, n_samples, 1);
    
    % FALSIFICATION CHECK C: Store segment indices
    if ~isnan(start_idx) && ~isnan(end_idx)
        trial_table.start_idx = repmat(start_idx, n_samples, 1);
        trial_table.end_idx = repmat(end_idx, n_samples, 1);
    else
        trial_table.start_idx = repmat(NaN, n_samples, 1);
        trial_table.end_idx = repmat(NaN, n_samples, 1);
    end
    
    % FALSIFICATION CHECK B: Store all-NaN flag
    trial_table.all_nan = repmat(all(isnan(trial_pupil) | ~trial_valid), n_samples, 1);
    
    % FALSIFICATION CHECK D: Store metadata integrity
    trial_table.session_from_filename = repmat(str2double(file_info.session{1}), n_samples, 1);
    trial_table.run_from_filename = repmat(file_info.run, n_samples, 1);
    
    % Parse session/run from logP filename if available
    if exist(logP_path, 'file')
        logP_metadata = parse_logP_filename(logP_path);
        if ~isempty(logP_metadata)
            trial_table.session_from_logP_filename = repmat(str2double(logP_metadata.session), n_samples, 1);
            trial_table.run_from_logP_filename = repmat(logP_metadata.run, n_samples, 1);
        else
            trial_table.session_from_logP_filename = repmat(NaN, n_samples, 1);
            trial_table.run_from_logP_filename = repmat(NaN, n_samples, 1);
        end
    else
        trial_table.session_from_logP_filename = repmat(NaN, n_samples, 1);
        trial_table.run_from_logP_filename = repmat(NaN, n_samples, 1);
    end
    
    % Store what pipeline actually uses
    trial_table.session_used = repmat(str2double(file_info.session{1}), n_samples, 1);
    trial_table.run_used = repmat(file_info.run, n_samples, 1);
    
    % CH3 EXTENSION: Add audit columns for segmentation boundaries
    trial_table.seg_start_rel_used = repmat(trial_start_rel, n_samples, 1);
    trial_table.seg_end_rel_used = repmat(trial_end_rel, n_samples, 1);
    trial_table.seg_end_source = repmat({seg_end_source}, n_samples, 1);
    
    run_data = [run_data; trial_table];
    run_qc_stats.n_trials_exported = run_qc_stats.n_trials_exported + 1;
    
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

% CH3 EXTENSION: QC check for trial extension (max time >= 7.65s)
if run_qc_stats.n_trials_exported > 0 && ~isempty(run_data)
    % Compute max time per trial
    unique_trials = unique(run_data.trial_in_run_raw);
    max_time_per_trial = NaN(length(unique_trials), 1);
    for t = 1:length(unique_trials)
        trial_mask = run_data.trial_in_run_raw == unique_trials(t);
        if any(trial_mask)
            max_time_per_trial(t) = max(run_data.time(trial_mask));
        end
    end
    max_time_per_trial(isnan(max_time_per_trial)) = [];
    trials_extended_ok = sum(max_time_per_trial >= 7.65);
    pct_trials_extended = 100 * trials_extended_ok / length(max_time_per_trial);
    run_qc_stats.ch3_extension_pct = pct_trials_extended;
    run_qc_stats.ch3_extension_trials_ok = trials_extended_ok;
    run_qc_stats.ch3_extension_trials_total = length(max_time_per_trial);
    
    if pct_trials_extended < 90
        warning('    WARNING: CH3 EXTENSION QC FAILED: Only %.1f%% of trials extend to >=7.65s (required: >=90%%)\n', ...
            pct_trials_extended);
        fprintf('      Subject: %s, Task: %s, Session: %s, Run: %d\n', ...
            file_info.subject{1}, file_info.task{1}, file_info.session{1}, file_info.run);
        fprintf('      Trials OK: %d/%d\n', trials_extended_ok, length(max_time_per_trial));
        if ~isempty(max_time_per_trial)
            fprintf('      Max time range: %.3f to %.3f s\n', min(max_time_per_trial), max(max_time_per_trial));
        end
    else
        fprintf('    CH3 EXTENSION QC PASSED: %.1f%% of trials extend to >=7.65s\n', pct_trials_extended);
    end
else
    run_qc_stats.ch3_extension_pct = NaN;
    run_qc_stats.ch3_extension_trials_ok = 0;
    run_qc_stats.ch3_extension_trials_total = 0;
end

% CRITICAL FIX: Sanity check printout for each run
fprintf('    SANITY CHECK:\n');
fprintf('      - Detected trials: %d\n', run_qc_stats.n_squeeze_onsets_detected);
fprintf('      - Exported trials: %d\n', run_qc_stats.n_trials_exported);
fprintf('      - Hard skipped (min_samples): %d\n', run_qc_stats.n_trials_hard_skipped_min_samples);
if run_qc_stats.n_trials_exported > 0
    fprintf('      - trial_in_run_raw range: %d to %d\n', min(run_data.trial_in_run_raw), max(run_data.trial_in_run_raw));
    fprintf('      - QC fail baseline: %d (%.1f%%)\n', run_qc_stats.n_qc_fail_baseline, ...
        100 * run_qc_stats.n_qc_fail_baseline / run_qc_stats.n_trials_exported);
    fprintf('      - QC fail overall: %d (%.1f%%)\n', run_qc_stats.n_qc_fail_overall, ...
        100 * run_qc_stats.n_qc_fail_overall / run_qc_stats.n_trials_exported);
end

% Warn if detected trials are not near 30 (design is 30 trials/run)
% HARDENING: More lenient warning threshold (20-35 acceptable, but prefer 28-30)
if run_qc_stats.n_squeeze_onsets_detected < 20 || run_qc_stats.n_squeeze_onsets_detected > 35
    warning('    WARNING: Detected %d trials (expected ~30, acceptable range 20-35). Check event detection.', ...
        run_qc_stats.n_squeeze_onsets_detected);
elseif run_qc_stats.n_squeeze_onsets_detected < 28 || run_qc_stats.n_squeeze_onsets_detected > 30
    fprintf('    NOTE: Detected %d trials (expected 28-30, but within acceptable range 20-35)\n', ...
        run_qc_stats.n_squeeze_onsets_detected);
end

% FALSIFICATION CHECK C: Anti-copy/paste validation
start_idx_monotonic = true;
n_duplicate_segments = 0;
n_duplicate_hashes = 0;

if length(trial_segments.start_idx) > 1
    % Check if start_idx is monotonic increasing
    start_idx_valid = trial_segments.start_idx(~isnan(trial_segments.start_idx));
    if length(start_idx_valid) > 1
        start_idx_monotonic = all(diff(start_idx_valid) > 0);
    end
    
    % Check for duplicate segments
    for i = 1:length(trial_segments.start_idx)
        if ~isnan(trial_segments.start_idx(i)) && ~isnan(trial_segments.end_idx(i))
            for j = i+1:length(trial_segments.start_idx)
                if ~isnan(trial_segments.start_idx(j)) && ~isnan(trial_segments.end_idx(j))
                    if trial_segments.start_idx(i) == trial_segments.start_idx(j) && ...
                       trial_segments.end_idx(i) == trial_segments.end_idx(j)
                        n_duplicate_segments = n_duplicate_segments + 1;
                    end
                end
            end
        end
    end
    
    % Check for duplicate hashes
    hash_valid = trial_segments.trial_hash(~isnan(trial_segments.trial_hash));
    if length(hash_valid) > 1
        [unique_hashes, ~, hash_idx] = unique(hash_valid);
        hash_counts = accumarray(hash_idx, 1);
        n_duplicate_hashes = sum(hash_counts > 1);
    end
end

% FALSIFICATION CHECK C: Set run_status if timebase bug detected
run_status = 'success';
if ~start_idx_monotonic || n_duplicate_segments > 0
    run_status = 'timebase_bug';
    fprintf('    ERROR: Timebase bug detected - start_idx not monotonic or duplicate segments found\n');
    fprintf('      start_idx_monotonic: %d, n_duplicate_segments: %d\n', ...
        start_idx_monotonic, n_duplicate_segments);
    run_quality.run_status = run_status;
    run_quality.n_trials = 0;
    run_quality.alignment_diagnostics.method = 'timebase_bug';
    run_quality.alignment_diagnostics.confidence = 'low';
    return;  % SKIP writing flat file
end

% Store QC stats in run_quality for later aggregation
run_quality.qc_stats = run_qc_stats;
run_quality.segmentation_source = segmentation_source;
if logP_data.success
    run_quality.n_log_trials = logP_data.n_trials;
else
    run_quality.n_log_trials = 0;
end
run_quality.n_marker_anchors = n_marker_anchors;
run_quality.alignment_diagnostics = alignment_diagnostics;
run_quality.run_status = run_status;

% FALSIFICATION CHECK B: Store timebase diagnostics
run_quality.qc_stats.window_oob_count = window_oob_count;
run_quality.qc_stats.empty_trial_count = empty_trial_count;
run_quality.qc_stats.all_nan_trial_count = all_nan_trial_count;

% FALSIFICATION CHECK C: Store anti-copy/paste checks
run_quality.qc_stats.start_idx_monotonic = start_idx_monotonic;
run_quality.qc_stats.n_duplicate_segments = n_duplicate_segments;
run_quality.qc_stats.n_duplicate_hashes = n_duplicate_hashes;

% FALSIFICATION CHECK A: Store logP plausibility diagnostics
run_quality.logP_plausibility_valid = logP_plausibility_valid;
run_quality.logP_plausibility_diagnostics = logP_plausibility_diagnostics;

% Initialize falsification metrics if not already set (for event_code-only or logP-only cases)
if ~isfield(run_quality, 'residual_median_abs_ms')
    run_quality.residual_median_abs_ms = NaN;
end
if ~isfield(run_quality, 'residual_max_abs_ms')
    run_quality.residual_max_abs_ms = NaN;
end
if ~isfield(run_quality, 'residual_p95_abs_ms')
    run_quality.residual_p95_abs_ms = NaN;
end
if ~isfield(run_quality, 'index_in_bounds_rate')
    run_quality.index_in_bounds_rate = NaN;
end
if ~isfield(run_quality, 'timing_error_ms_median')
    run_quality.timing_error_ms_median = NaN;
end
if ~isfield(run_quality, 'timing_error_ms_p95')
    run_quality.timing_error_ms_p95 = NaN;
end
if ~isfield(run_quality, 'timing_error_ms_max')
    run_quality.timing_error_ms_max = NaN;
end
if ~isfield(run_quality, 'segmentation_source_for_residuals')
    run_quality.segmentation_source_for_residuals = segmentation_source;
end

% HARDENING: Count window_oob trials (from actual extracted data)
if ~isempty(run_data)
    window_oob_count_actual = sum(run_data.window_oob);
    run_quality.qc_stats.n_window_oob = window_oob_count_actual;
else
    run_quality.qc_stats.n_window_oob = 0;
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
        
    % Phase 5: Stimulus presentation (700ms = Standard 100ms + ISI 500ms + Target 100ms)
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

% HARDENING: Save to build directory
if isfield(CONFIG, 'build_dir')
    output_base = CONFIG.build_dir;
else
    output_base = CONFIG.output_dir;
end
summary_path = fullfile(output_base, 'BAP_pupillometry_data_quality_report.csv');
writetable(summary_table, summary_path);

% Save detailed text report (to build directory)
report_path = fullfile(output_base, 'BAP_pupillometry_data_quality_detailed.txt');
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
