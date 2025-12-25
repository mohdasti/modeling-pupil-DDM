% ============================================================================
% MATLAB HARDENING AUDIT: Comprehensive Event Code Discovery and Validation
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

fprintf('=== MATLAB HARDENING AUDIT ===\n\n');

%% TASK A1: Search Task Code Repo
fprintf('TASK A1: Searching for task code repository...\n');

% Search paths
search_paths = {
    '/Users/mohdasti/Documents/GitHub',
    '/Users/mohdasti/Documents',
    '/Users/mohdasti/Documents/LC-BAP'
};

task_code_found = false;
task_code_dir = '';

for base_path = search_paths
    if exist(base_path{1}, 'dir')
        % Search for lc-aging or task-code directories
        cmd = sprintf('find "%s" -type d -name "lc-aging" -o -name "task-code" -o -name "aim-1" 2>/dev/null | head -5', base_path{1});
        [status, result] = system(cmd);
        if status == 0 && ~isempty(result)
            dirs = strsplit(strtrim(result), '\n');
            for d = dirs
                if ~isempty(d{1})
                    task_code_dir = d{1};
                    task_code_found = true;
                    fprintf('  Found: %s\n', task_code_dir);
                    break;
                end
            end
            if task_code_found, break; end
        end
    end
end

if task_code_found
    fprintf('  Searching for event marker definitions in: %s\n', task_code_dir);
    
    % Search for MATLAB files with marker-related code
    cmd = sprintf('grep -r -l -i "SetMarker\\|marker\\|TTL\\|Datapixx\\|Cedrus\\|parallel\\|trigger" "%s" --include="*.m" 2>/dev/null | head -10', task_code_dir);
    [status, result] = system(cmd);
    if status == 0 && ~isempty(result)
        files = strsplit(strtrim(result), '\n');
        fprintf('  Found %d MATLAB files with marker-related code\n', length(files));
        for i = 1:min(5, length(files))
            fprintf('    %s\n', files{i});
        end
    end
else
    fprintf('  WARNING: Task code repository not found\n');
    fprintf('  Will proceed with data-driven discovery\n');
end

fprintf('\n');

%% TASK A2: Inspect Marker Stream
fprintf('TASK A2: Inspecting marker stream in example file...\n');

if exist(example_raw, 'file')
    raw_data = load(example_raw);
    fprintf('  Loaded: %s\n', basename(example_raw));
    
    % Find marker data
    if isfield(raw_data, 'bufferData')
        buffer = raw_data.bufferData;
        if size(buffer, 2) >= 8
            times = buffer(:, 1);
            codes = buffer(:, 8);
            
            unique_codes = unique(codes);
            fprintf('  Unique codes: %s\n', mat2str(unique_codes'));
            
            % Count per code
            code_counts = arrayfun(@(c) sum(codes == c), unique_codes);
            marker_table = table(unique_codes, code_counts, ...
                'VariableNames', {'code', 'n_pulses'});
            
            writetable(marker_table, fullfile(output_dir, 'example_marker_counts.csv'));
            fprintf('  Saved: example_marker_counts.csv\n');
        end
    end
else
    fprintf('  ERROR: Example raw file not found\n');
end

fprintf('\n');

%% TASK A3: Parse logP and Compare
fprintf('TASK A3: Parsing logP and comparing to markers...\n');

if exist(example_logP, 'file')
    % Read logP (tab-separated)
    fid = fopen(example_logP, 'r');
    if fid ~= -1
        % Read first few lines to understand format
        header = fgetl(fid);
        fprintf('  Header: %s\n', header);
        
        % Try to read as table
        fclose(fid);
        try
            logP_table = readtable(example_logP, 'Delimiter', '\t', 'FileType', 'text');
            fprintf('  logP rows: %d\n', height(logP_table));
            fprintf('  logP columns: %s\n', strjoin(logP_table.Properties.VariableNames, ', '));
            
            % Look for TrialST or similar
            if any(contains(logP_table.Properties.VariableNames, 'Trial', 'IgnoreCase', true))
                trial_col = logP_table.Properties.VariableNames{contains(logP_table.Properties.VariableNames, 'Trial', 'IgnoreCase', true)};
                fprintf('  Found trial column: %s\n', trial_col);
            end
        catch ME
            fprintf('  WARNING: Could not parse logP as table: %s\n', ME.message);
        end
    end
else
    fprintf('  ERROR: Example logP file not found\n');
end

fprintf('\n=== AUDIT COMPLETE (partial) ===\n');
fprintf('Next: Implement full discovery and hardening in BAP_Pupillometry_Pipeline.m\n');

