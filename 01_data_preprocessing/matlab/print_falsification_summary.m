function print_falsification_summary(all_run_qc_stats, CONFIG)
% Print falsification validation summary

fprintf('\n=== FALSIFICATION QC SUMMARY ===\n');

% Count runs with n_trials_extracted in [28,30]
n_runs_total = length(all_run_qc_stats);
n_runs_28_30 = 0;
n_runs_skipped = 0;
skip_reasons_count = containers.Map();
n_timebase_bug = 0;
window_oob_distribution = [];

for j = 1:length(all_run_qc_stats)
    run_qc = all_run_qc_stats{j};
    
    if isfield(run_qc, 'n_trials_exported')
        if run_qc.n_trials_exported >= 28 && run_qc.n_trials_exported <= 30
            n_runs_28_30 = n_runs_28_30 + 1;
        end
        
        % Collect window_oob_count
        if isfield(run_qc, 'window_oob_count')
            window_oob_distribution(end+1) = run_qc.window_oob_count;
        end
    end
    
    % Count skipped runs
    if isfield(run_qc, 'run_status')
        if strcmp(run_qc.run_status, 'logP_invalid') || ...
           strcmp(run_qc.run_status, 'timebase_bug') || ...
           strcmp(run_qc.run_status, 'failed')
            n_runs_skipped = n_runs_skipped + 1;
            if skip_reasons_count.isKey(run_qc.run_status)
                skip_reasons_count(run_qc.run_status) = skip_reasons_count(run_qc.run_status) + 1;
            else
                skip_reasons_count(run_qc.run_status) = 1;
            end
        end
        
        if strcmp(run_qc.run_status, 'timebase_bug')
            n_timebase_bug = n_timebase_bug + 1;
        end
    end
end

% Count runs in acceptable range (20-35)
n_runs_20_35 = 0;
for j = 1:length(all_run_qc_stats)
    run_qc = all_run_qc_stats{j};
    if isfield(run_qc, 'n_trials_exported')
        if run_qc.n_trials_exported >= 20 && run_qc.n_trials_exported <= 35
            n_runs_20_35 = n_runs_20_35 + 1;
        end
    end
end

% Print summary
fprintf('Total runs processed: %d\n', n_runs_total);
fprintf('Runs with n_trials_extracted in [28,30] (target): %d (%.1f%%)\n', ...
    n_runs_28_30, 100 * n_runs_28_30 / max(n_runs_total, 1));
fprintf('Runs with n_trials_extracted in [20,35] (acceptable): %d (%.1f%%)\n', ...
    n_runs_20_35, 100 * n_runs_20_35 / max(n_runs_total, 1));

fprintf('\nSkipped runs by reason:\n');
if skip_reasons_count.Count > 0
    keys = skip_reasons_count.keys;
    for k = 1:length(keys)
        fprintf('  %s: %d\n', keys{k}, skip_reasons_count(keys{k}));
    end
else
    fprintf('  None\n');
end

fprintf('\nRuns flagged timebase_bug: %d\n', n_timebase_bug);

if ~isempty(window_oob_distribution)
    fprintf('\nWindow OOB distribution:\n');
    fprintf('  Min: %d\n', min(window_oob_distribution));
    fprintf('  Median: %.1f\n', median(window_oob_distribution));
    fprintf('  Max: %d\n', max(window_oob_distribution));
    fprintf('  Mean: %.1f\n', mean(window_oob_distribution));
end

fprintf('\n=== END FALSIFICATION QC SUMMARY ===\n');

end

