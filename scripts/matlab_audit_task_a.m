% ============================================================================
% TASK A: Prove What Event Codes Mean (No Assumptions)
% ============================================================================
% This script discovers event codes from task code repo and validates against data

%% Configuration
cleaned_file = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned/subjectBAP202_Voddball_session2_run4_12_20_13_11_eyetrack_cleaned.mat';
raw_file = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data/sub-BAP202/ses-2/InsideScanner/subjectBAP202_Voddball_session2_run4_12_20_13_11_eyetrack.mat';
logP_file = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data/sub-BAP202/ses-2/InsideScanner/subjectBAP202_Voddball_session2_run4_12_20_13_11_logP.txt';
output_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/qc_matlab';

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

fprintf('=== TASK A: EVENT CODE DISCOVERY ===\n\n');

%% A1: Search Task Code Repo for Event Marker Definitions
fprintf('A1: Searching task code repo for event marker definitions...\n');

% Search for task code repo
task_code_dirs = {
    '/Users/mohdasti/Documents/GitHub/lc-aging/aim-1/task-code',
    '/Users/mohdasti/Documents/lc-aging/aim-1/task-code',
    '/Users/mohdasti/Documents/LC-BAP/task-code',
    '/Users/mohdasti/Documents/task-code'
};

task_code_found = false;
task_code_dir = '';

for i = 1:length(task_code_dirs)
    if exist(task_code_dirs{i}, 'dir')
        task_code_dir = task_code_dirs{i};
        task_code_found = true;
        fprintf('  Found task code directory: %s\n', task_code_dir);
        break;
    end
end

if ~task_code_found
    fprintf('  WARNING: Task code directory not found. Searching locally...\n');
    % Try to find any MATLAB files that might contain marker definitions
    search_dirs = {
        '/Users/mohdasti/Documents',
        '/Users/mohdasti/Documents/LC-BAP'
    };
    
    for search_dir = search_dirs
        if exist(search_dir{1}, 'dir')
            % Use system command to search
            cmd = sprintf('find "%s" -name "*.m" -type f 2>/dev/null | head -20', search_dir{1});
            [status, result] = system(cmd);
            if status == 0 && ~isempty(result)
                fprintf('  Found MATLAB files in: %s\n', search_dir{1});
            end
        end
    end
end

% Create codebook structure (will be populated)
codebook = table();
codebook.code = [];
codebook.label = {};
codebook.source = {};

fprintf('  NOTE: Codebook discovery requires access to task code repo.\n');
fprintf('  Creating placeholder codebook from current CONFIG assumptions...\n');

% Extract from current CONFIG (these are assumptions to be validated)
codebook = table([3040; 3041; 3042; 3044; 3048], ...
    {'baseline'; 'response_start'; 'stimulus_start'; 'squeeze_start'; 'confidence_start'}, ...
    {'assumed'; 'assumed'; 'assumed'; 'assumed'; 'assumed'}, ...
    'VariableNames', {'code', 'label', 'source'});

codebook_path = fullfile(output_dir, 'event_codebook_from_scripts.csv');
writetable(codebook, codebook_path);
fprintf('  Saved: %s\n', codebook_path);
fprintf('  WARNING: This is based on assumptions. Need task code repo to validate.\n\n');

%% A2: Inspect Marker Stream in Example Eyetrack File
fprintf('A2: Inspecting marker stream in example eyetrack file...\n');

if ~exist(raw_file, 'file')
    error('Raw eyetrack file not found: %s', raw_file);
end

raw_data = load(raw_file);
fprintf('  Loaded: %s\n', raw_file);
fprintf('  Variables in file:\n');
fprintf('    %s\n', strjoin(fieldnames(raw_data), ', '));

% Find marker/buffer data
marker_vars = {};
if isfield(raw_data, 'bufferData')
    marker_vars{end+1} = 'bufferData';
end
if isfield(raw_data, 'markers')
    marker_vars{end+1} = 'markers';
end
if isfield(raw_data, 'S')
    if isfield(raw_data.S, 'events')
        marker_vars{end+1} = 'S.events';
    end
    if isfield(raw_data.S, 'markers')
        marker_vars{end+1} = 'S.markers';
    end
end

fprintf('  Marker variables found: %s\n', strjoin(marker_vars, ', '));

% Extract marker data (using current assumption: bufferData)
if isfield(raw_data, 'bufferData')
    buffer_data = raw_data.bufferData;
    fprintf('  bufferData size: %s\n', mat2str(size(buffer_data)));
    
    if size(buffer_data, 2) >= 8
        event_times = buffer_data(:, 1);
        event_codes = buffer_data(:, 8);
        
        unique_codes = unique(event_codes);
        fprintf('  Unique event codes: %s\n', mat2str(unique_codes'));
        
        % Count pulses per code
        code_counts = arrayfun(@(c) sum(event_codes == c), unique_codes);
        marker_counts = table(unique_codes, code_counts, ...
            'VariableNames', {'code', 'n_pulses'});
        
        % Find transitions
        transition_indices = find(diff(event_codes) ~= 0) + 1;
        transition_times = event_times(transition_indices);
        transition_from = event_codes(transition_indices - 1);
        transition_to = event_codes(transition_indices);
        
        fprintf('  Total transitions: %d\n', length(transition_indices));
        fprintf('  First 20 transitions:\n');
        for i = 1:min(20, length(transition_indices))
            fprintf('    %.3f: %d -> %d\n', transition_times(i), transition_from(i), transition_to(i));
        end
        
        % Save outputs
        marker_counts_path = fullfile(output_dir, 'example_marker_counts.csv');
        writetable(marker_counts, marker_counts_path);
        fprintf('  Saved: %s\n', marker_counts_path);
        
        % Save preview
        preview_path = fullfile(output_dir, 'example_marker_stream_preview.txt');
        fid = fopen(preview_path, 'w');
        fprintf(fid, 'Marker Stream Preview: %s\n', raw_file);
        fprintf(fid, '========================================\n\n');
        fprintf(fid, 'Unique codes: %s\n', mat2str(unique_codes'));
        fprintf(fid, 'Total transitions: %d\n\n', length(transition_indices));
        fprintf(fid, 'First 20 transitions:\n');
        fprintf(fid, 'Time(s)\tFrom\tTo\n');
        for i = 1:min(20, length(transition_indices))
            fprintf(fid, '%.3f\t%d\t%d\n', transition_times(i), transition_from(i), transition_to(i));
        end
        fclose(fid);
        fprintf('  Saved: %s\n', preview_path);
    else
        fprintf('  ERROR: bufferData does not have expected structure\n');
    end
else
    fprintf('  ERROR: bufferData not found in raw file\n');
end

fprintf('\n');

%% A3: Validate Mapping Against logP
fprintf('A3: Validating mapping against logP (PTB times)...\n');

if ~exist(logP_file, 'file')
    error('logP file not found: %s', logP_file);
end

% Read logP file (tab-separated)
fid = fopen(logP_file, 'r');
if fid == -1
    error('Cannot open logP file: %s', logP_file);
end

% Read header
header_line = fgetl(fid);
headers = strsplit(header_line, '\t');
fprintf('  logP headers: %s\n', strjoin(headers, ', '));

% Read data
logP_data = textscan(fid, '%s', 'Delimiter', '\t', 'HeaderLines', 0);
fclose(fid);

% Parse logP (this is a simplified parser - may need adjustment)
% Expected columns: Trial, TrialST, blankST, fixST, etc.
fprintf('  NOTE: logP parsing requires knowledge of exact format.\n');
fprintf('  Creating alignment report placeholder...\n');

% Create alignment report
alignment_report = fullfile(output_dir, 'example_code_alignment_report.md');
fid = fopen(alignment_report, 'w');
fprintf(fid, '# Event Code Alignment Report\n\n');
fprintf(fid, '**File:** %s\n\n', logP_file);
fprintf(fid, '## Status\n\n');
fprintf(fid, '⚠️ **PENDING:** Full alignment requires:\n');
fprintf(fid, '1. Task code repo to discover actual event codes\n');
fprintf(fid, '2. logP format specification\n');
fprintf(fid, '3. Timebase conversion between marker times and PTB times\n\n');
fprintf(fid, '## Next Steps\n\n');
fprintf(fid, '1. Locate task code repo\n');
fprintf(fid, '2. Search for SetMarker, Datapixx, or similar calls\n');
fprintf(fid, '3. Extract code->event mapping\n');
fprintf(fid, '4. Align marker times to logP PTB times\n');
fclose(fid);
fprintf('  Saved: %s\n', alignment_report);

fprintf('\n=== TASK A COMPLETE (partial - requires task code repo) ===\n');

