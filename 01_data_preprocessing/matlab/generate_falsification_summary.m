function generate_falsification_summary(all_run_qc_stats, CONFIG)
% Generate falsification validation summary report

% Use build-specific QC directory if available
if isfield(CONFIG, 'qc_dir')
    qc_dir = CONFIG.qc_dir;
else
    qc_dir = fullfile(CONFIG.output_dir, 'qc_matlab');
end
if ~exist(qc_dir, 'dir')
    mkdir(qc_dir);
end

% Load QC files if they exist
qc_file = fullfile(qc_dir, 'qc_matlab_run_trial_counts.csv');
falsification_file = fullfile(qc_dir, 'qc_matlab_falsification_by_run.csv');

if exist(qc_file, 'file')
    qc_data = readtable(qc_file);
else
    fprintf('  WARNING: QC file not found, cannot generate summary\n');
    return;
end

% Load falsification data if available
falsification_data = table();
if exist(falsification_file, 'file')
    falsification_data = readtable(falsification_file);
end

% Compute summary statistics
n_runs_total = height(qc_data);
n_runs_28_30 = sum(qc_data.n_trials_extracted >= 28 & qc_data.n_trials_extracted <= 30);
n_runs_20_35 = sum(qc_data.n_trials_extracted >= 20 & qc_data.n_trials_extracted <= 35);
pct_28_30 = 100 * n_runs_28_30 / n_runs_total;
pct_20_35 = 100 * n_runs_20_35 / n_runs_total;

% Count skipped runs by reason
skip_file = fullfile(qc_dir, 'qc_matlab_skip_reasons.csv');
skip_counts = struct();
if exist(skip_file, 'file')
    skip_data = readtable(skip_file);
    unique_reasons = unique(skip_data.skip_reason);
    for i = 1:length(unique_reasons)
        reason = unique_reasons{i};
        count = sum(strcmp(skip_data.skip_reason, reason));
        skip_counts.(matlab.lang.makeValidName(reason)) = count;
    end
end

% Count timebase_bug runs
n_timebase_bug = 0;
if ismember('run_status', qc_data.Properties.VariableNames)
    n_timebase_bug = sum(strcmp(qc_data.run_status, 'timebase_bug'));
end

% Distribution of window_oob_count
if ismember('window_oob_count', qc_data.Properties.VariableNames)
    window_oob_dist = tabulate(qc_data.window_oob_count);
else
    window_oob_dist = [];
end

% Write summary report
report_file = fullfile(qc_dir, 'falsification_validation_summary.md');
fid = fopen(report_file, 'w');

fprintf(fid, '# MATLAB Pipeline Falsification Validation Summary\n\n');
fprintf(fid, 'Generated: %s\n\n', datestr(now));

fprintf(fid, '## Overall Statistics\n\n');
fprintf(fid, '- **Total runs processed**: %d\n', n_runs_total);
fprintf(fid, '- **Runs with 28-30 trials extracted** (target): %d (%.1f%%)\n', n_runs_28_30, pct_28_30);
fprintf(fid, '- **Runs with 20-35 trials extracted** (acceptable): %d (%.1f%%)\n', n_runs_20_35, pct_20_35);
fprintf(fid, '- **Runs flagged with timebase_bug**: %d\n', n_timebase_bug);

% Add alignment metrics summary if available
if ~isempty(falsification_data) && height(falsification_data) > 0
    fprintf(fid, '\n## Alignment Metrics Summary\n\n');
    
    % Event-code residual stats
    event_code_runs = falsification_data(strcmp(falsification_data.segmentation_source, 'event_code'), :);
    if height(event_code_runs) > 0
        valid_residuals = ~isnan(event_code_runs.residual_median_abs_ms);
        if sum(valid_residuals) > 0
            fprintf(fid, '### Event-Code Segmentation (vs logP)\n\n');
            fprintf(fid, '- **Runs with event-code segmentation**: %d\n', height(event_code_runs));
            fprintf(fid, '- **Median residual (median across runs)**: %.2f ms\n', median(event_code_runs.residual_median_abs_ms(valid_residuals)));
            fprintf(fid, '- **Max residual (max across runs)**: %.2f ms\n', max(event_code_runs.residual_max_abs_ms(valid_residuals)));
            fprintf(fid, '- **P95 residual (p95 across runs)**: %.2f ms\n', prctile(event_code_runs.residual_p95_abs_ms(valid_residuals), 95));
            
            % Flagged runs
            if ismember('flagged_falsification', falsification_data.Properties.VariableNames)
                flagged = falsification_data.flagged_falsification == true;
                n_flagged = sum(flagged);
                if n_flagged > 0
                    fprintf(fid, '- **Runs flagged for falsification**: %d\n', n_flagged);
                end
            end
            fprintf(fid, '\n');
        end
    end
    
    % logP timing stats
    logP_runs = falsification_data(strcmp(falsification_data.segmentation_source, 'logP'), :);
    if height(logP_runs) > 0
        valid_timing = ~isnan(logP_runs.index_in_bounds_rate);
        if sum(valid_timing) > 0
            fprintf(fid, '### logP Segmentation (Timing Validation)\n\n');
            fprintf(fid, '- **Runs with logP segmentation**: %d\n', height(logP_runs));
            fprintf(fid, '- **Index in bounds rate (median)**: %.3f\n', median(logP_runs.index_in_bounds_rate(valid_timing)));
            valid_timing_errors = ~isnan(logP_runs.timing_error_ms_median) & logP_runs.timing_error_ms_median > 0;
            if sum(valid_timing_errors) > 0
                fprintf(fid, '- **Timing error (median)**: %.2f ms\n', median(logP_runs.timing_error_ms_median(valid_timing_errors)));
                fprintf(fid, '- **Timing error (max)**: %.2f ms\n', max(logP_runs.timing_error_ms_max(valid_timing_errors)));
            else
                fprintf(fid, '- **Timing error**: All events within bounds\n');
            end
            fprintf(fid, '\n');
        end
    end
end

fprintf(fid, '\n## Skipped Runs by Reason\n\n');
if exist(skip_file, 'file') && ~isempty(skip_data)
    fprintf(fid, '| Reason | Count |\n');
    fprintf(fid, '|--------|-------|\n');
    for i = 1:length(unique_reasons)
        reason = unique_reasons{i};
        count = sum(strcmp(skip_data.skip_reason, reason));
        fprintf(fid, '| %s | %d |\n', reason, count);
    end
else
    fprintf(fid, 'No skipped runs recorded.\n');
end

fprintf(fid, '\n## Window OOB Distribution\n\n');
if ~isempty(window_oob_dist)
    fprintf(fid, '| window_oob_count | Frequency | Percentage |\n');
    fprintf(fid, '|------------------|-----------|------------|\n');
    for i = 1:size(window_oob_dist, 1)
        fprintf(fid, '| %d | %d | %.1f%% |\n', ...
            window_oob_dist(i,1), window_oob_dist(i,2), window_oob_dist(i,3));
    end
else
    fprintf(fid, 'window_oob_count data not available.\n');
end

% Check for failures
fprintf(fid, '\n## Failure Analysis\n\n');
failures = {};

if pct_28_30 < 90
    failures{end+1} = sprintf('Low extraction rate: Only %.1f%% of runs extracted 28-30 trials (target: >=90%%)', pct_28_30);
end

if pct_20_35 < 95
    failures{end+1} = sprintf('Low acceptable extraction rate: Only %.1f%% of runs extracted 20-35 trials (target: >=95%%)', pct_20_35);
end

if n_timebase_bug > 0
    failures{end+1} = sprintf('Timebase bugs detected: %d runs flagged with timebase_bug', n_timebase_bug);
end

if exist(skip_file, 'file') && ismember('logP_invalid', skip_data.skip_reason)
    n_logp_invalid = sum(strcmp(skip_data.skip_reason, 'logP_invalid'));
    if n_logp_invalid > 0
        failures{end+1} = sprintf('logP validation failures: %d runs failed logP plausibility checks', n_logp_invalid);
    end
end

if isempty(failures)
    fprintf(fid, '✅ **No critical failures detected.**\n');
    fprintf(fid, '\nAll falsification checks passed. Pipeline appears to be extracting trials correctly.\n');
else
    fprintf(fid, '❌ **Failures detected:**\n\n');
    for i = 1:length(failures)
        fprintf(fid, '%d. %s\n', i, failures{i});
    end
    fprintf(fid, '\n### Recommendations\n\n');
    fprintf(fid, '1. Review runs with timebase_bug flags\n');
    fprintf(fid, '2. Investigate logP_invalid runs\n');
    fprintf(fid, '3. Check window_oob_count distribution for systematic issues\n');
end

fclose(fid);

% Print summary to console
fprintf('\n=== FALSIFICATION VALIDATION SUMMARY ===\n');
fprintf('Total runs: %d\n', n_runs_total);
fprintf('Runs with 28-30 trials (target): %d (%.1f%%)\n', n_runs_28_30, pct_28_30);
fprintf('Runs with 20-35 trials (acceptable): %d (%.1f%%)\n', n_runs_20_35, pct_20_35);
fprintf('Timebase bugs: %d\n', n_timebase_bug);
if exist(skip_file, 'file') && ~isempty(skip_data)
    fprintf('Skipped runs:\n');
    for i = 1:length(unique_reasons)
        reason = unique_reasons{i};
        count = sum(strcmp(skip_data.skip_reason, reason));
        fprintf('  %s: %d\n', reason, count);
    end
end
fprintf('Summary saved to: %s\n', report_file);
fprintf('==========================================\n\n');

end

