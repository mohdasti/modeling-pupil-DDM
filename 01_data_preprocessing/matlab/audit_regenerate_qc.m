function audit_regenerate_qc(CONFIG)
% Regenerate QC artifacts from flat files to ensure consistency
% This ensures QC outputs are not stale

fprintf('\n=== REGENERATING QC ARTIFACTS ===\n');

% Find all flat files
if isfield(CONFIG, 'build_dir')
    build_dir = CONFIG.build_dir;
else
    build_dir = CONFIG.output_dir;
end

flat_files = dir(fullfile(build_dir, '*_flat.csv'));

if isempty(flat_files)
    fprintf('  WARNING: No flat CSV files found in %s\n', build_dir);
    return;
end

fprintf('  Found %d flat CSV files\n', length(flat_files));

% Regenerate run_trial_counts from flat files
% Use cell arrays to collect data, then convert to table
run_data_cells = {};
trial_data_cells = {};

run_counter = 0;
trial_counter = 0;

for i = 1:length(flat_files)
    flat_path = fullfile(build_dir, flat_files(i).name);
    fprintf('  Processing: %s\n', flat_files(i).name);
    
    try
        % Read the flat file with robust options
        opts = detectImportOptions(flat_path);
        flat_data = readtable(flat_path, opts);
        
        % Verify required columns exist
        required_cols = {'sub', 'task', 'ses', 'run', 'trial_in_run_raw'};
        missing_cols = setdiff(required_cols, flat_data.Properties.VariableNames);
        if ~isempty(missing_cols)
            fprintf('  WARNING: Missing columns in %s: %s\n', flat_files(i).name, strjoin(missing_cols, ', '));
            continue;
        end
        
        % Get unique runs
        run_keys = unique(flat_data(:, {'sub', 'task', 'ses', 'run'}));
        
        for j = 1:height(run_keys)
            % Extract run-level data
            run_mask = strcmp(flat_data.sub, run_keys.sub{j}) & ...
                      strcmp(flat_data.task, run_keys.task{j}) & ...
                      flat_data.ses == run_keys.ses(j) & ...
                      flat_data.run == run_keys.run(j);
            
            run_data = flat_data(run_mask, :);
            
            % Skip if run_data is empty
            if isempty(run_data) || height(run_data) == 0
                continue;
            end
            
            % Extract trial_in_run_raw as numeric vector
            trial_in_run_raw_vec = run_data.trial_in_run_raw;
            if istable(trial_in_run_raw_vec)
                trial_in_run_raw_vec = table2array(trial_in_run_raw_vec);
            end
            
            % Remove NaN values
            valid_trial_mask = ~isnan(trial_in_run_raw_vec);
            if ~any(valid_trial_mask)
                % No valid trials in this run
                continue;
            end
            
            trial_in_run_raw_vec_clean = trial_in_run_raw_vec(valid_trial_mask);
            n_trials = length(unique(trial_in_run_raw_vec_clean));
            
            % Get segmentation source
            if ismember('segmentation_source', run_data.Properties.VariableNames)
                seg_source = run_data.segmentation_source{1};
            else
                seg_source = 'unknown';
            end
            
            % Collect run-level data
            if iscell(run_keys.sub)
                subj_val = run_keys.sub{j};
            else
                subj_val = char(run_keys.sub(j));
            end
            if iscell(run_keys.task)
                task_val = run_keys.task{j};
            else
                task_val = char(run_keys.task(j));
            end
            
            run_counter = run_counter + 1;
            run_data_cells{run_counter, 1} = subj_val;
            run_data_cells{run_counter, 2} = task_val;
            run_data_cells{run_counter, 3} = run_keys.ses(j);
            run_data_cells{run_counter, 4} = run_keys.run(j);
            run_data_cells{run_counter, 5} = n_trials;
            run_data_cells{run_counter, 6} = seg_source;
            
            % Trial-level flags (one row per trial)
            trial_nums = unique(trial_in_run_raw_vec_clean);
            if istable(trial_nums)
                trial_nums = table2array(trial_nums);
            end
            
            for k = 1:length(trial_nums)
                current_trial_num = trial_nums(k);
                
                % Create trial mask using the extracted vector
                trial_mask_vec = (trial_in_run_raw_vec == current_trial_num);
                trial_data = run_data(trial_mask_vec, :);
                
                if isempty(trial_data) || height(trial_data) == 0
                    continue;
                end
                
                % Extract trial-level metrics
                seg_source_trial = 'unknown';
                if ismember('segmentation_source', trial_data.Properties.VariableNames)
                    seg_source_trial = trial_data.segmentation_source{1};
                end
                
                trial_start_ptb_val = NaN;
                if ismember('trial_start_time_ptb', trial_data.Properties.VariableNames)
                    trial_start_ptb_val = trial_data.trial_start_time_ptb(1);
                end
                
                n_samples_val = height(trial_data);
                
                pct_non_nan_overall_val = NaN;
                if ismember('pupil', trial_data.Properties.VariableNames)
                    valid = ~isnan(trial_data.pupil);
                    if n_samples_val > 0
                        pct_non_nan_overall_val = 100 * sum(valid) / n_samples_val;
                    end
                end
                
                pct_non_nan_baseline_val = NaN;
                if ismember('baseline_quality', trial_data.Properties.VariableNames)
                    pct_non_nan_baseline_val = trial_data.baseline_quality(1) * 100;
                end
                
                all_nan_val = false;
                if ismember('all_nan', trial_data.Properties.VariableNames)
                    all_nan_val = trial_data.all_nan(1);
                elseif ~isnan(pct_non_nan_overall_val) && pct_non_nan_overall_val == 0
                    all_nan_val = true;
                end
                
                window_oob_val = false;
                if ismember('window_oob', trial_data.Properties.VariableNames)
                    window_oob_val = trial_data.window_oob(1);
                end
                
                % Collect trial-level data
                trial_counter = trial_counter + 1;
                trial_data_cells{trial_counter, 1} = subj_val;
                trial_data_cells{trial_counter, 2} = task_val;
                trial_data_cells{trial_counter, 3} = run_keys.ses(j);
                trial_data_cells{trial_counter, 4} = run_keys.run(j);
                trial_data_cells{trial_counter, 5} = current_trial_num;
                trial_data_cells{trial_counter, 6} = seg_source_trial;
                trial_data_cells{trial_counter, 7} = trial_start_ptb_val;
                trial_data_cells{trial_counter, 8} = n_samples_val;
                trial_data_cells{trial_counter, 9} = pct_non_nan_overall_val;
                trial_data_cells{trial_counter, 10} = pct_non_nan_baseline_val;
                trial_data_cells{trial_counter, 11} = NaN;  % prestim
                trial_data_cells{trial_counter, 12} = NaN;  % stim
                trial_data_cells{trial_counter, 13} = NaN;  % response
                trial_data_cells{trial_counter, 14} = all_nan_val;
                trial_data_cells{trial_counter, 15} = window_oob_val;
                trial_data_cells{trial_counter, 16} = false;  % any_timebase_bug
            end
        end
        
    catch ME
        fprintf('  ERROR processing %s: %s\n', flat_files(i).name, ME.message);
        fprintf('    Line: %d\n', ME.stack(1).line);
        fprintf('    Stack trace: %s\n', getReport(ME, 'basic'));
        % Continue processing other files
        continue;
    end
end

% Convert cell arrays to tables
if ~isempty(run_data_cells)
    run_trial_counts = cell2table(run_data_cells, ...
        'VariableNames', {'subject', 'task', 'session', 'run', 'n_trials_extracted', 'segmentation_source'});
else
    run_trial_counts = table();
end

if ~isempty(trial_data_cells)
    trial_level_flags = cell2table(trial_data_cells, ...
        'VariableNames', {'subject', 'task', 'session', 'run', 'trial_in_run_raw', ...
        'segmentation_source', 'trial_start_ptb', 'n_samples', ...
        'pct_non_nan_overall', 'pct_non_nan_baseline', 'pct_non_nan_prestim', ...
        'pct_non_nan_stim', 'pct_non_nan_response', ...
        'all_nan_trial_combined', 'window_oob', 'any_timebase_bug'});
else
    trial_level_flags = table();
end

% Save regenerated QC files
if isfield(CONFIG, 'qc_dir')
    qc_dir = CONFIG.qc_dir;
else
    qc_dir = fullfile(CONFIG.output_dir, 'qc_matlab');
    if ~exist(qc_dir, 'dir')
        mkdir(qc_dir);
    end
end

if ~isempty(run_trial_counts)
    output_path = fullfile(qc_dir, 'qc_matlab_run_trial_counts.csv');
    writetable(run_trial_counts, output_path);
    fprintf('\n  Regenerated: qc_matlab_run_trial_counts.csv (%d runs)\n', height(run_trial_counts));
end

if ~isempty(trial_level_flags)
    output_path = fullfile(qc_dir, 'qc_matlab_trial_level_flags.csv');
    writetable(trial_level_flags, output_path);
    fprintf('  Regenerated: qc_matlab_trial_level_flags.csv (%d trials)\n', height(trial_level_flags));
end

fprintf('  Successfully processed %d files\n', length(flat_files));
fprintf('  Collected %d runs and %d trials\n', run_counter, trial_counter);

end
