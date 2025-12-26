function write_falsification_qc(all_run_qc_stats, CONFIG)
% Write qc_matlab_falsification_by_run.csv with alignment metrics
% HARDENING: Comprehensive falsification metrics for event-code and logP segmentation

% Use build-specific QC directory if available
if isfield(CONFIG, 'qc_dir')
    qc_dir = CONFIG.qc_dir;
else
    qc_dir = fullfile(CONFIG.output_dir, 'qc_matlab');
end

if ~exist(qc_dir, 'dir')
    mkdir(qc_dir);
end

falsification_table = table();

for j = 1:length(all_run_qc_stats)
    run_qc = all_run_qc_stats{j};
    
    if ~isfield(run_qc, 'subject') || ~isfield(run_qc, 'task')
        continue;
    end
    
    % Extract basic info (ensure proper types)
    subject = run_qc.subject;
    task = run_qc.task;
    session = double(run_qc.session);  % Ensure numeric
    run = double(run_qc.run);  % Ensure numeric
    
    % Extract segmentation source
    if isfield(run_qc, 'segmentation_source')
        segmentation_source = run_qc.segmentation_source;
    else
        segmentation_source = 'unknown';
    end
    
    % Extract trial counts
    if isfield(run_qc, 'n_trials_exported')
        n_trials_extracted = run_qc.n_trials_exported;
    else
        n_trials_extracted = 0;
    end
    
    if isfield(run_qc, 'n_marker_anchors')
        n_marker_anchors = run_qc.n_marker_anchors;
    else
        n_marker_anchors = 0;
    end
    
    if isfield(run_qc, 'n_log_trials')
        n_log_trials = run_qc.n_log_trials;
    else
        n_log_trials = 0;
    end
    
    % Extract timebase method
    if isfield(run_qc, 'alignment_diagnostics') && isstruct(run_qc.alignment_diagnostics)
        if isfield(run_qc.alignment_diagnostics, 'method')
            timebase_method = run_qc.alignment_diagnostics.method;
        else
            timebase_method = 'unknown';
        end
    else
        timebase_method = 'unknown';
    end
    
    % Extract window OOB and NaN counts
    if isfield(run_qc, 'qc_stats')
        if isfield(run_qc.qc_stats, 'n_window_oob')
            window_oob_count = run_qc.qc_stats.n_window_oob;
        else
            window_oob_count = 0;
        end
        if isfield(run_qc.qc_stats, 'all_nan_trial_count')
            all_nan_trial_count = run_qc.qc_stats.all_nan_trial_count;
        else
            all_nan_trial_count = 0;
        end
        if isfield(run_qc.qc_stats, 'empty_trial_count')
            empty_trial_count = run_qc.qc_stats.empty_trial_count;
        else
            empty_trial_count = 0;
        end
    else
        window_oob_count = 0;
        all_nan_trial_count = 0;
        empty_trial_count = 0;
    end
    
    % Extract logP plausibility
    if isfield(run_qc, 'logP_plausibility_valid')
        logP_plausibility_valid = run_qc.logP_plausibility_valid;
    else
        logP_plausibility_valid = true;  % Default to true if not checked
    end
    
    % Extract event-code residual metrics (if available)
    if isfield(run_qc, 'residual_median_abs_ms')
        residual_median_abs_ms = run_qc.residual_median_abs_ms;
    else
        residual_median_abs_ms = NaN;
    end
    
    if isfield(run_qc, 'residual_max_abs_ms')
        residual_max_abs_ms = run_qc.residual_max_abs_ms;
    else
        residual_max_abs_ms = NaN;
    end
    
    if isfield(run_qc, 'residual_p95_abs_ms')
        residual_p95_abs_ms = run_qc.residual_p95_abs_ms;
    else
        residual_p95_abs_ms = NaN;
    end
    
    % Extract logP timing metrics (if available)
    if isfield(run_qc, 'index_in_bounds_rate')
        index_in_bounds_rate = run_qc.index_in_bounds_rate;
    else
        index_in_bounds_rate = NaN;
    end
    
    if isfield(run_qc, 'timing_error_ms_median')
        timing_error_ms_median = run_qc.timing_error_ms_median;
    else
        timing_error_ms_median = NaN;
    end
    
    if isfield(run_qc, 'timing_error_ms_p95')
        timing_error_ms_p95 = run_qc.timing_error_ms_p95;
    else
        timing_error_ms_p95 = NaN;
    end
    
    if isfield(run_qc, 'timing_error_ms_max')
        timing_error_ms_max = run_qc.timing_error_ms_max;
    else
        timing_error_ms_max = NaN;
    end
    
    % Create row (use cell array approach to avoid MATLAB table() parsing issues)
    % Convert all values to cell arrays, then convert to table
    row_data = {
        subject, task, session, run, ...
        segmentation_source, n_trials_extracted, ...
        n_marker_anchors, n_log_trials, timebase_method, ...
        window_oob_count, all_nan_trial_count, empty_trial_count, ...
        logP_plausibility_valid, ...
        residual_median_abs_ms, residual_max_abs_ms, residual_p95_abs_ms, ...
        index_in_bounds_rate, ...
        timing_error_ms_median, timing_error_ms_p95, timing_error_ms_max
    };
    
    row = cell2table(row_data, ...
        'VariableNames', {'subject', 'task', 'session', 'run', ...
        'segmentation_source', 'n_trials_extracted', ...
        'n_marker_anchors', 'n_log_trials', 'timebase_method', ...
        'window_oob_count', 'all_nan_trial_count', 'empty_trial_count', ...
        'logP_plausibility_valid', ...
        'residual_median_abs_ms', 'residual_max_abs_ms', 'residual_p95_abs_ms', ...
        'index_in_bounds_rate', ...
        'timing_error_ms_median', 'timing_error_ms_p95', 'timing_error_ms_max'});
    
    falsification_table = [falsification_table; row];
end

% Write to file
if ~isempty(falsification_table)
    falsification_path = fullfile(qc_dir, 'qc_matlab_falsification_by_run.csv');
    writetable(falsification_table, falsification_path);
    fprintf('  Saved: qc_matlab_falsification_by_run.csv (%d runs)\n', height(falsification_table));
else
    fprintf('  WARNING: No falsification data to write\n');
end

end

