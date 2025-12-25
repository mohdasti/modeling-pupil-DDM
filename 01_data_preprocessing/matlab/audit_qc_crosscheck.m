function audit_qc_crosscheck(CONFIG)
% Cross-check against BAP_QC spreadsheet
% Output: qc_expected_vs_observed_runs.csv

fprintf('\n=== QC SPREADSHEET CROSS-CHECK ===\n');

% Try to find BAP_QC spreadsheet
qc_spreadsheet_path = '';
possible_paths = {
    fullfile(CONFIG.output_dir, '..', 'BAP_QC - Sheet1.csv'),
    fullfile(CONFIG.output_dir, 'BAP_QC - Sheet1.csv'),
    fullfile(fileparts(CONFIG.output_dir), 'BAP_QC - Sheet1.csv'),
    '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_QC - Sheet1.csv'
};

for i = 1:length(possible_paths)
    if exist(possible_paths{i}, 'file')
        qc_spreadsheet_path = possible_paths{i};
        break;
    end
end

if isempty(qc_spreadsheet_path)
    fprintf('  WARNING: BAP_QC spreadsheet not found. Skipping cross-check.\n');
    fprintf('  Searched paths:\n');
    for i = 1:length(possible_paths)
        fprintf('    %s\n', possible_paths{i});
    end
    return;
end

fprintf('  Found QC spreadsheet: %s\n', qc_spreadsheet_path);

try
    qc_data = readtable(qc_spreadsheet_path);
catch ME
    fprintf('  ERROR: Cannot read QC spreadsheet: %s\n', ME.message);
    return;
end

% Get observed runs from manifest or cleaned files
cleaned_files = dir(fullfile(CONFIG.cleaned_dir, '*_cleaned.mat'));
observed_runs = struct();

for i = 1:length(cleaned_files)
    metadata = parse_filename(cleaned_files(i).name);
    if ~isempty(metadata)
        session_num = str2double(metadata.session);
        if session_num == 2 || session_num == 3
            key = sprintf('%s_%s_%s', metadata.subject, metadata.task, metadata.session);
            if ~isfield(observed_runs, key)
                observed_runs.(key) = [];
            end
            observed_runs.(key) = [observed_runs.(key), metadata.run];
        end
    end
end

% Compare with QC spreadsheet
comparison = table();

% Extract subject IDs from QC spreadsheet (assuming first column or specific column)
if ismember('Subject', qc_data.Properties.VariableNames)
    subject_col = 'Subject';
elseif ismember('subject', qc_data.Properties.VariableNames)
    subject_col = 'subject';
else
    subject_col = qc_data.Properties.VariableNames{1};
end

unique_subjects = unique(qc_data.(subject_col));

for i = 1:length(unique_subjects)
    subject = unique_subjects{i};
    if iscell(subject)
        subject = subject{1};
    end
    
    % Get expected from QC spreadsheet
    subject_rows = qc_data(strcmp(qc_data.(subject_col), subject), :);
    
    % Check for ADT and VDT
    for task = {'ADT', 'VDT'}
        task_key = sprintf('%s_%s_2', subject, task{1});
        task_key_3 = sprintf('%s_%s_3', subject, task{1});
        
        expected_runs = [];
        observed_runs_list = [];
        
        % Check session 2
        if isfield(observed_runs, task_key)
            observed_runs_list = unique(observed_runs.(task_key));
        end
        
        % Check session 3
        if isfield(observed_runs, task_key_3)
            observed_runs_list = [observed_runs_list, unique(observed_runs.(task_key_3))];
        end
        
        % Try to get expected from QC (this is approximate - adjust based on actual QC format)
        expected_count = NaN;
        mismatch_reason = '';
        
        if length(observed_runs_list) < 5
            mismatch_reason = sprintf('Only %d runs observed (expected 5)', length(observed_runs_list));
        elseif length(observed_runs_list) > 5
            mismatch_reason = sprintf('%d runs observed (expected 5)', length(observed_runs_list));
        end
        
        row = table();
        row.subject = {subject};
        row.task = task;
        row.expected_runs = 5;
        row.observed_runs = length(observed_runs_list);
        row.observed_run_numbers = {mat2str(unique(observed_runs_list))};
        row.mismatch = ~isempty(mismatch_reason);
        row.mismatch_reason = {mismatch_reason};
        comparison = [comparison; row];
    end
end

% Save comparison
if isfield(CONFIG, 'qc_dir')
    output_path = fullfile(CONFIG.qc_dir, 'qc_expected_vs_observed_runs.csv');
else
    output_path = fullfile(CONFIG.output_dir, 'qc_matlab', 'qc_expected_vs_observed_runs.csv');
    qc_dir = fileparts(output_path);
    if ~exist(qc_dir, 'dir')
        mkdir(qc_dir);
    end
end

writetable(comparison, output_path);
fprintf('\nSaved: %s\n', output_path);
fprintf('  Total comparisons: %d\n', height(comparison));
fprintf('  Mismatches: %d\n', sum(comparison.mismatch));

end

