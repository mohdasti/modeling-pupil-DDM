function generate_trial_level_flags(build_dir, CONFIG)
% Generate qc_matlab_trial_level_flags.csv from all flat files in build directory
% Reads flat CSV files and aggregates trial-level QC flags

fprintf('\n=== GENERATING TRIAL-LEVEL FLAGS ===\n');

% Find all flat CSV files in build directory
flat_files = dir(fullfile(build_dir, '*_flat.csv'));

if isempty(flat_files)
    fprintf('  WARNING: No flat CSV files found in %s\n', build_dir);
    return;
end

all_trial_flags = table();

for i = 1:length(flat_files)
    flat_path = fullfile(build_dir, flat_files(i).name);
    fprintf('  Processing: %s\n', flat_files(i).name);
    
    try
        flat_data = readtable(flat_path);
        
        % Group by trial to compute trial-level metrics
        trial_keys = unique(flat_data(:, {'sub', 'task', 'ses', 'run', 'trial_in_run_raw'}));
        
        for j = 1:height(trial_keys)
            trial_mask = strcmp(flat_data.sub, trial_keys.sub{j}) & ...
                        strcmp(flat_data.task, trial_keys.task{j}) & ...
                        flat_data.ses == trial_keys.ses(j) & ...
                        flat_data.run == trial_keys.run(j) & ...
                        flat_data.trial_in_run_raw == trial_keys.trial_in_run_raw(j);
            
            trial_data = flat_data(trial_mask, :);
            
            % Extract trial-level metrics
            subject = trial_keys.sub{j};
            task = trial_keys.task{j};
            session = trial_keys.ses(j);
            run = trial_keys.run(j);
            trial_in_run_raw = trial_keys.trial_in_run_raw(j);
            
            % Get segmentation source (should be same for all samples in trial)
            if ismember('segmentation_source', trial_data.Properties.VariableNames)
                segmentation_source = trial_data.segmentation_source{1};
            else
                segmentation_source = 'unknown';
            end
            
            % Get trial start time (PTB)
            if ismember('trial_start_time_ptb', trial_data.Properties.VariableNames)
                trial_start_ptb = trial_data.trial_start_time_ptb(1);
            else
                trial_start_ptb = NaN;
            end
            
            % Sample count
            n_samples = height(trial_data);
            
            % Validity proportions
            if ismember('pupil', trial_data.Properties.VariableNames) && ismember('has_behavioral_data', trial_data.Properties.VariableNames)
                valid_mask = ~isnan(trial_data.pupil) & trial_data.has_behavioral_data == 1;
                pct_non_nan_overall = 100 * sum(valid_mask) / n_samples;
            else
                pct_non_nan_overall = NaN;
            end
            
            % Baseline validity (if baseline_quality exists)
            if ismember('baseline_quality', trial_data.Properties.VariableNames)
                pct_non_nan_baseline = trial_data.baseline_quality(1) * 100;
            else
                pct_non_nan_baseline = NaN;
            end
            
            % Prestim validity (approximate from phase labels)
            if ismember('trial_label', trial_data.Properties.VariableNames)
                prestim_phases = {'ITI_Baseline', 'Squeeze', 'Post_Squeeze_Blank', 'Pre_Stimulus_Fixation'};
                prestim_mask = ismember(trial_data.trial_label, prestim_phases);
                if any(prestim_mask)
                    prestim_data = trial_data(prestim_mask, :);
                    if ismember('pupil', prestim_data.Properties.VariableNames)
                        valid_prestim = ~isnan(prestim_data.pupil) & prestim_data.has_behavioral_data == 1;
                        pct_non_nan_prestim = 100 * sum(valid_prestim) / height(prestim_data);
                    else
                        pct_non_nan_prestim = NaN;
                    end
                else
                    pct_non_nan_prestim = NaN;
                end
            else
                pct_non_nan_prestim = NaN;
            end
            
            % Stim validity
            if ismember('trial_label', trial_data.Properties.VariableNames)
                stim_phases = {'Stimulus', 'Post_Stimulus_Fixation'};
                stim_mask = ismember(trial_data.trial_label, stim_phases);
                if any(stim_mask)
                    stim_data = trial_data(stim_mask, :);
                    if ismember('pupil', stim_data.Properties.VariableNames)
                        valid_stim = ~isnan(stim_data.pupil) & stim_data.has_behavioral_data == 1;
                        pct_non_nan_stim = 100 * sum(valid_stim) / height(stim_data);
                    else
                        pct_non_nan_stim = NaN;
                    end
                else
                    pct_non_nan_stim = NaN;
                end
            else
                pct_non_nan_stim = NaN;
            end
            
            % Response validity
            if ismember('trial_label', trial_data.Properties.VariableNames)
                response_phases = {'Response_Different', 'Confidence'};
                response_mask = ismember(trial_data.trial_label, response_phases);
                if any(response_mask)
                    response_data = trial_data(response_mask, :);
                    if ismember('pupil', response_data.Properties.VariableNames)
                        valid_response = ~isnan(response_data.pupil) & response_data.has_behavioral_data == 1;
                        pct_non_nan_response = 100 * sum(valid_response) / height(response_data);
                    else
                        pct_non_nan_response = NaN;
                    end
                else
                    pct_non_nan_response = NaN;
                end
            else
                pct_non_nan_response = NaN;
            end
            
            % All-NaN trial flag
            if ismember('all_nan', trial_data.Properties.VariableNames)
                all_nan_trial_combined = trial_data.all_nan(1);
            else
                all_nan_trial_combined = (pct_non_nan_overall == 0);
            end
            
            % Window OOB flag
            if ismember('window_oob', trial_data.Properties.VariableNames)
                window_oob = trial_data.window_oob(1);
            else
                window_oob = false;
            end
            
            % Timebase bug flag (from run-level, would need to be propagated)
            any_timebase_bug = false;  % Would need run-level info
            
            % HARDENING: Get pipeline_run_id from flat file if available
            pipeline_run_id = '';
            if ismember('pipeline_run_id', trial_data.Properties.VariableNames)
                pipeline_run_id = trial_data.pipeline_run_id{1};
            elseif isfield(CONFIG, 'pipeline_run_id')
                pipeline_run_id = CONFIG.pipeline_run_id;
            end
            
            % Create row
            row = table(...
                {subject}, {task}, session, run, trial_in_run_raw, ...
                {segmentation_source}, trial_start_ptb, n_samples, ...
                pct_non_nan_overall, pct_non_nan_baseline, pct_non_nan_prestim, ...
                pct_non_nan_stim, pct_non_nan_response, ...
                all_nan_trial_combined, window_oob, any_timebase_bug, ...
                {pipeline_run_id}, ...
                'VariableNames', {'subject', 'task', 'session', 'run', 'trial_in_run_raw', ...
                'segmentation_source', 'trial_start_ptb', 'n_samples', ...
                'pct_non_nan_overall', 'pct_non_nan_baseline', 'pct_non_nan_prestim', ...
                'pct_non_nan_stim', 'pct_non_nan_response', ...
                'all_nan_trial_combined', 'window_oob', 'any_timebase_bug', 'pipeline_run_id'});
            
            all_trial_flags = [all_trial_flags; row];
        end
        
    catch ME
        fprintf('  ERROR processing %s: %s\n', flat_files(i).name, ME.message);
    end
end

% Write to file
if ~isempty(all_trial_flags)
    flags_path = fullfile(build_dir, 'qc_matlab', 'qc_matlab_trial_level_flags.csv');
    qc_dir = fileparts(flags_path);
    if ~exist(qc_dir, 'dir')
        mkdir(qc_dir);
    end
    writetable(all_trial_flags, flags_path);
    fprintf('  Saved: qc_matlab_trial_level_flags.csv (%d trials)\n', height(all_trial_flags));
else
    fprintf('  WARNING: No trial flags generated\n');
end

end

