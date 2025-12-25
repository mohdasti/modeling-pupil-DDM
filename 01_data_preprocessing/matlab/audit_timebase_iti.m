function audit_timebase_iti(CONFIG)
% Validate timebase and inter-trial intervals
% Output: qc_timebase_and_iti_checks.csv

fprintf('\n=== TIMEBASE AND ITI AUDIT ===\n');

% Load QC run counts if available
qc_file = '';
if isfield(CONFIG, 'qc_dir')
    qc_file = fullfile(CONFIG.qc_dir, 'qc_matlab_run_trial_counts.csv');
else
    qc_file = fullfile(CONFIG.output_dir, 'qc_matlab', 'qc_matlab_run_trial_counts.csv');
end

if ~exist(qc_file, 'file')
    fprintf('  WARNING: qc_matlab_run_trial_counts.csv not found. Cannot perform timebase audit.\n');
    return;
end

qc_data = readtable(qc_file);
timebase_checks = table();

for i = 1:height(qc_data)
    row_qc = qc_data(i, :);
    
    % Initialize all columns to ensure consistent table structure
    row = table();
    row.subject = row_qc.subject;
    row.task = row_qc.task;
    row.session = row_qc.session;
    row.run = row_qc.run;
    row.segmentation_source = row_qc.segmentation_source;
    row.n_trials_extracted = row_qc.n_trials_extracted;
    
    % Initialize timebase columns
    if ismember('timebase_method', row_qc.Properties.VariableNames)
        row.timebase_method = row_qc.timebase_method;
    else
        row.timebase_method = {''};
    end
    
    if ismember('timebase_offset', row_qc.Properties.VariableNames)
        row.timebase_offset = row_qc.timebase_offset;
    else
        row.timebase_offset = NaN;
    end
    
    if ismember('n_window_oob', row_qc.Properties.VariableNames)
        row.window_oob = row_qc.n_window_oob;
    else
        row.window_oob = NaN;
    end
    
    % Initialize all output columns
    row.timebase_offset_plausible = true;
    row.window_oob_ok = true;
    row.timebase_issue = {''};
    row.median_iti = NaN;
    row.min_iti = NaN;
    row.max_iti = NaN;
    
    % For logP segmentation: check timebase offset
    if strcmp(row.segmentation_source{1}, 'logP')
        if isfinite(row.timebase_offset)
            offset_ok = abs(row.timebase_offset) < 10000;  % Reasonable range
            row.timebase_offset_plausible = offset_ok;
            if ~offset_ok
                row.timebase_issue = {sprintf('offset=%.2f (outside plausible range)', row.timebase_offset)};
            end
        else
            row.timebase_offset_plausible = false;
            row.timebase_issue = {'offset_NaN'};
        end
        
        % Window OOB should be 0 for logP
        row.window_oob_ok = (row.window_oob == 0);
        if row.window_oob > 0
            row.timebase_issue = {sprintf('window_oob=%d (should be 0)', row.window_oob)};
        end
    else
        % For event_code: check ITI from flat files if available
        row.timebase_offset_plausible = true;  % N/A for event_code
        row.window_oob_ok = true;  % N/A for event_code
        
        % Try to compute ITI from flat files
        flat_file = sprintf('%s_%s_flat.csv', row.subject{1}, row.task{1});
        if isfield(CONFIG, 'build_dir')
            flat_path = fullfile(CONFIG.build_dir, flat_file);
        else
            flat_path = fullfile(CONFIG.output_dir, flat_file);
        end
        
        if exist(flat_path, 'file')
            try
                flat_data = readtable(flat_path);
                run_mask = flat_data.ses == row.session & flat_data.run == row.run;
                run_data = flat_data(run_mask, :);
                
                if ismember('trial_start_time_ptb', run_data.Properties.VariableNames)
                    trial_starts = unique(run_data.trial_start_time_ptb);
                    if length(trial_starts) > 1
                        iti = diff(sort(trial_starts));
                        row.median_iti = median(iti);
                        row.min_iti = min(iti);
                        row.max_iti = max(iti);
                        
                        % Check ITI plausibility
                        if row.median_iti < 8 || row.median_iti > 25
                            row.timebase_issue = {sprintf('median_iti=%.2f (expected 8-25s)', row.median_iti)};
                        elseif row.min_iti < 5
                            row.timebase_issue = {sprintf('min_iti=%.2f (<5s)', row.min_iti)};
                        end
                    end
                end
            catch
                % Skip if flat file read fails
            end
        end
    end
    
    timebase_checks = [timebase_checks; row];
end

% Save checks
if isfield(CONFIG, 'qc_dir')
    output_path = fullfile(CONFIG.qc_dir, 'qc_timebase_and_iti_checks.csv');
else
    output_path = fullfile(CONFIG.output_dir, 'qc_matlab', 'qc_timebase_and_iti_checks.csv');
    qc_dir = fileparts(output_path);
    if ~exist(qc_dir, 'dir')
        mkdir(qc_dir);
    end
end

writetable(timebase_checks, output_path);
fprintf('\nSaved: %s\n', output_path);
fprintf('  Total runs checked: %d\n', height(timebase_checks));

logp_runs = timebase_checks(strcmp(timebase_checks.segmentation_source, 'logP'), :);
if ~isempty(logp_runs)
    fprintf('  logP runs: %d\n', height(logp_runs));
    fprintf('  logP runs with window_oob=0: %d (%.1f%%)\n', ...
        sum(logp_runs.window_oob == 0), 100*sum(logp_runs.window_oob == 0)/height(logp_runs));
end

end

