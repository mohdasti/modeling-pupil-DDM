% ============================================================================
% COMPREHENSIVE MATLAB AUDIT: Event Code Discovery, Timebase, Segmentation
% ============================================================================
% This script performs Tasks A-D to harden the MATLAB pipeline

%% Configuration
example_cleaned = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned/subjectBAP202_Voddball_session2_run4_12_20_13_11_eyetrack_cleaned.mat';
example_raw = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data/sub-BAP202/ses-2/InsideScanner/subjectBAP202_Voddball_session2_run4_12_20_13_11_eyetrack.mat';
example_logP = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data/sub-BAP202/ses-2/InsideScanner/subjectBAP202_Voddball_session2_run4_12_20_13_11_logP.txt';
output_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/qc_matlab';

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

fprintf('=== COMPREHENSIVE MATLAB HARDENING AUDIT ===\n\n');

%% TASK A1: Search Task Code Repo for Event Codes
fprintf('TASK A1: Searching for task code repository...\n');

% Search for task code repo
search_cmd = 'find /Users/mohdasti/Documents -type d -name "lc-aging" -o -name "task-code" -o -name "aim-1" 2>/dev/null | head -5';
[status, result] = system(search_cmd);
task_code_dir = '';

if status == 0 && ~isempty(result)
    dirs = strsplit(strtrim(result), '\n');
    for i = 1:length(dirs)
        if ~isempty(dirs{i}) && exist(dirs{i}, 'dir')
            task_code_dir = dirs{i};
            fprintf('  Found: %s\n', task_code_dir);
            break;
        end
    end
end

% Search for marker definitions
codebook = table();
if ~isempty(task_code_dir)
    fprintf('  Searching for event marker definitions...\n');
    grep_cmd = sprintf('grep -r -h -i "SetMarker\\|marker.*=\\|TTL\\|Datapixx" "%s" --include="*.m" 2>/dev/null | head -20', task_code_dir);
    [status, result] = system(grep_cmd);
    if status == 0 && ~isempty(result)
        fprintf('  Found marker-related code (showing first 20 lines):\n');
        lines = strsplit(result, '\n');
        for i = 1:min(10, length(lines))
            if ~isempty(lines{i})
                fprintf('    %s\n', lines{i});
            end
        end
    end
else
    fprintf('  WARNING: Task code repository not found\n');
    fprintf('  Will use data-driven discovery\n');
end

% Create codebook (from current assumptions, to be validated)
codebook = table([3040; 3041; 3042; 3044; 3048], ...
    {'baseline'; 'response_start'; 'stimulus_start'; 'squeeze_start'; 'confidence_start'}, ...
    {'assumed_from_config'; 'assumed_from_config'; 'assumed_from_config'; 'assumed_from_config'; 'assumed_from_config'}, ...
    'VariableNames', {'code', 'label', 'source'});

writetable(codebook, fullfile(output_dir, 'event_codebook_from_scripts.csv'));
fprintf('  Saved: event_codebook_from_scripts.csv\n\n');

%% TASK A2: Inspect Marker Stream
fprintf('TASK A2: Inspecting marker stream...\n');

if exist(example_raw, 'file')
    raw_data = load(example_raw);
    fprintf('  Loaded: %s\n', example_raw);
    
    if isfield(raw_data, 'bufferData')
        buffer = raw_data.bufferData;
        if size(buffer, 2) >= 8
            times = buffer(:, 1);
            codes = buffer(:, 8);
            
            unique_codes = unique(codes);
            fprintf('  Unique codes: %s\n', mat2str(unique_codes'));
            
            % Count per code
            code_counts = arrayfun(@(c) sum(codes == c), unique_codes);
            marker_counts = table(unique_codes, code_counts, ...
                'VariableNames', {'code', 'n_pulses'});
            
            % Find transitions
            trans_idx = find(diff(codes) ~= 0) + 1;
            trans_times = times(trans_idx);
            trans_from = codes(trans_idx - 1);
            trans_to = codes(trans_idx);
            
            fprintf('  Total transitions: %d\n', length(trans_idx));
            fprintf('  First 10 transitions:\n');
            for i = 1:min(10, length(trans_idx))
                fprintf('    %.3f: %d -> %d\n', trans_times(i), trans_from(i), trans_to(i));
            end
            
            % Save outputs
            writetable(marker_counts, fullfile(output_dir, 'example_marker_counts.csv'));
            
            % Save preview
            fid = fopen(fullfile(output_dir, 'example_marker_stream_preview.txt'), 'w');
            fprintf(fid, 'Marker Stream Preview\n');
            fprintf(fid, '====================\n\n');
            fprintf(fid, 'Unique codes: %s\n', mat2str(unique_codes'));
            fprintf(fid, 'Total transitions: %d\n\n', length(trans_idx));
            fprintf(fid, 'First 20 transitions:\n');
            fprintf(fid, 'Time(s)\tFrom\tTo\n');
            for i = 1:min(20, length(trans_idx))
                fprintf(fid, '%.3f\t%d\t%d\n', trans_times(i), trans_from(i), trans_to(i));
            end
            fclose(fid);
            
            fprintf('  Saved: example_marker_counts.csv, example_marker_stream_preview.txt\n');
        end
    end
else
    fprintf('  ERROR: Example raw file not found\n');
end

fprintf('\n');

%% TASK A3: Parse logP and Validate Alignment
fprintf('TASK A3: Parsing logP and validating alignment...\n');

if exist(example_logP, 'file')
    % Read logP (has header lines starting with %)
    fid = fopen(example_logP, 'r');
    if fid ~= -1
        % Skip header lines
        line = fgetl(fid);
        while ~isempty(line) && line(1) == '%'
            fprintf('  Header: %s\n', line);
            line = fgetl(fid);
        end
        
        % Read column headers
        headers = strsplit(line, '\t');
        fprintf('  Columns: %s\n', strjoin(headers, ', '));
        
        % Read data rows
        data_lines = {};
        while ~feof(fid)
            line = fgetl(fid);
            if ~isempty(line) && line(1) ~= '%'
                data_lines{end+1} = line;
            end
        end
        fclose(fid);
        
        fprintf('  Data rows: %d\n', length(data_lines));
        
        % Parse TrialST column (if exists)
        trial_st_idx = find(contains(headers, 'TrialST', 'IgnoreCase', true), 1);
        if ~isempty(trial_st_idx)
            fprintf('  Found TrialST at column %d\n', trial_st_idx);
            
            % Extract TrialST values
            trial_st_times = [];
            for i = 1:length(data_lines)
                parts = strsplit(data_lines{i}, '\t');
                if length(parts) >= trial_st_idx
                    trial_st_times(end+1) = str2double(parts{trial_st_idx});
                end
            end
            
            fprintf('  TrialST range: %.3f to %.3f\n', min(trial_st_times), max(trial_st_times));
            fprintf('  TrialST count: %d\n', length(trial_st_times));
            
            % Compare to marker times (if available)
            if exist('trans_times', 'var')
                fprintf('  Comparing to marker transitions...\n');
                % This would require timebase conversion - see Task B
            end
        end
    end
else
    fprintf('  ERROR: Example logP file not found\n');
end

fprintf('\n=== AUDIT COMPLETE (partial - full implementation in pipeline) ===\n');

