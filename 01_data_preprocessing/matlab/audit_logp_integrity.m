function audit_logp_integrity(CONFIG)
% Validate logP integrity for all runs
% Output: qc_logP_integrity_by_run.csv

fprintf('\n=== logP INTEGRITY AUDIT ===\n');

cleaned_files = dir(fullfile(CONFIG.cleaned_dir, '*_cleaned.mat'));
logp_integrity = table();

for i = 1:length(cleaned_files)
    filename = cleaned_files(i).name;
    metadata = parse_filename(filename);
    
    if isempty(metadata)
        continue;
    end
    
    session_num = str2double(metadata.session);
    if session_num ~= 2 && session_num ~= 3
        continue;  % Skip non-scanner sessions
    end
    
    % Find logP file
    logP_filename = strrep(filename, '_eyetrack_cleaned.mat', '_logP.txt');
    logP_path = fullfile(CONFIG.raw_dir, sprintf('sub-%s/ses-%s/InsideScanner/%s', ...
        metadata.subject, metadata.session, logP_filename));
    
    row = table();
    row.subject = {metadata.subject};
    row.task = {metadata.task};
    row.session = str2double(metadata.session);
    row.run = metadata.run;
    row.logP_exists = exist(logP_path, 'file');
    row.n_trial_anchors = NaN;
    row.trial_st_monotonic = false;
    row.trial_st_min = NaN;
    row.trial_st_max = NaN;
    row.median_iti = NaN;
    row.min_iti = NaN;
    row.max_iti = NaN;
    row.plausibility_check = false;
    row.integrity_status = {'logP_missing'};
    
    if row.logP_exists
        try
            logP_data = parse_logP_file(logP_path);
            
            if logP_data.success && ~isempty(logP_data.trial_st)
                row.n_trial_anchors = length(logP_data.trial_st);
                row.trial_st_min = min(logP_data.trial_st);
                row.trial_st_max = max(logP_data.trial_st);
                
                % Check monotonicity
                row.trial_st_monotonic = all(diff(logP_data.trial_st) > 0);
                
                % Compute ITI
                if length(logP_data.trial_st) > 1
                    iti = diff(logP_data.trial_st);
                    row.median_iti = median(iti);
                    row.min_iti = min(iti);
                    row.max_iti = max(iti);
                end
                
                % Plausibility checks
                plausibility_ok = true;
                if row.n_trial_anchors ~= 30
                    plausibility_ok = false;
                    row.integrity_status = {sprintf('n_trials=%d (expected 30)', row.n_trial_anchors)};
                elseif ~row.trial_st_monotonic
                    plausibility_ok = false;
                    row.integrity_status = {'trial_st_not_monotonic'};
                elseif row.median_iti < 8 || row.median_iti > 25
                    plausibility_ok = false;
                    row.integrity_status = {sprintf('median_iti=%.2f (expected 8-25s)', row.median_iti)};
                elseif row.min_iti < 5
                    plausibility_ok = false;
                    row.integrity_status = {sprintf('min_iti=%.2f (<5s)', row.min_iti)};
                else
                    row.integrity_status = {'PASS'};
                end
                
                row.plausibility_check = plausibility_ok;
            else
                row.integrity_status = {'parse_failed'};
            end
        catch ME
            row.integrity_status = {sprintf('error: %s', ME.message)};
        end
    end
    
    logp_integrity = [logp_integrity; row];
end

% Save integrity check
if isfield(CONFIG, 'qc_dir')
    output_path = fullfile(CONFIG.qc_dir, 'qc_logP_integrity_by_run.csv');
else
    output_path = fullfile(CONFIG.output_dir, 'qc_matlab', 'qc_logP_integrity_by_run.csv');
    qc_dir = fileparts(output_path);
    if ~exist(qc_dir, 'dir')
        mkdir(qc_dir);
    end
end

writetable(logp_integrity, output_path);
fprintf('\nSaved: %s\n', output_path);
fprintf('  Total runs checked: %d\n', height(logp_integrity));
fprintf('  logP exists: %d (%.1f%%)\n', sum(logp_integrity.logP_exists), ...
    100*sum(logp_integrity.logP_exists)/height(logp_integrity));
fprintf('  Plausibility PASS: %d\n', sum(strcmp(logp_integrity.integrity_status, 'PASS')));

end

