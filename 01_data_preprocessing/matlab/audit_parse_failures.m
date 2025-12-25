function audit_parse_failures(CONFIG)
% Audit parse failures and ensure all are logged to skip_reasons
% This ensures no silent defaults

fprintf('\n=== PARSE FAILURE AUDIT ===\n');

cleaned_files = dir(fullfile(CONFIG.cleaned_dir, '*_cleaned.mat'));
skip_reasons = table();

for i = 1:length(cleaned_files)
    filename = cleaned_files(i).name;
    metadata = parse_filename(filename);
    
    if isempty(metadata)
        % Parse failure - log to skip_reasons
        row = table(...
            {filename}, {''}, {''}, NaN, NaN, ...
            {'parse_failure'}, {'parse_filename returned empty - cannot extract metadata'}, ...
            'VariableNames', {'file_stem', 'subject', 'task', 'session', 'run', 'skip_reason', 'details'});
        skip_reasons = [skip_reasons; row];
    else
        session_num = str2double(metadata.session);
        run_num = metadata.run;
        
        % Check for invalid session
        if session_num ~= 2 && session_num ~= 3
            row = table(...
                {filename}, {metadata.subject}, {metadata.task}, session_num, run_num, ...
                {'invalid_session'}, {sprintf('Session %d not in {2,3}', session_num)}, ...
                'VariableNames', {'file_stem', 'subject', 'task', 'session', 'run', 'skip_reason', 'details'});
            skip_reasons = [skip_reasons; row];
        end
        
        % Check for invalid run
        if run_num < 1 || run_num > 5
            row = table(...
                {filename}, {metadata.subject}, {metadata.task}, session_num, run_num, ...
                {'invalid_run'}, {sprintf('Run %d not in {1,2,3,4,5}', run_num)}, ...
                'VariableNames', {'file_stem', 'subject', 'task', 'session', 'run', 'skip_reason', 'details'});
            skip_reasons = [skip_reasons; row];
        end
    end
end

% Save skip reasons
if isfield(CONFIG, 'qc_dir')
    output_path = fullfile(CONFIG.qc_dir, 'qc_matlab_skip_reasons.csv');
else
    output_path = fullfile(CONFIG.output_dir, 'qc_matlab', 'qc_matlab_skip_reasons.csv');
    qc_dir = fileparts(output_path);
    if ~exist(qc_dir, 'dir')
        mkdir(qc_dir);
    end
end

if ~isempty(skip_reasons)
    writetable(skip_reasons, output_path);
    fprintf('  Saved: qc_matlab_skip_reasons.csv (%d skipped files)\n', height(skip_reasons));
else
    % Create empty file
    empty_table = table('Size', [0, 7], 'VariableTypes', {'cell', 'cell', 'cell', 'double', 'double', 'cell', 'cell'}, ...
        'VariableNames', {'file_stem', 'subject', 'task', 'session', 'run', 'skip_reason', 'details'});
    writetable(empty_table, output_path);
    fprintf('  Saved: qc_matlab_skip_reasons.csv (empty - no skipped files)\n');
end

end

