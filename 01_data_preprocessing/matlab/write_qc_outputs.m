function write_qc_outputs(all_quality_reports, all_run_qc_stats, CONFIG)
% Write mandatory QC outputs to build-specific qc_matlab directory
% HARDENING: Uses CONFIG.qc_dir (build-specific) instead of base output_dir

% Use build-specific QC directory if available, otherwise fall back
if isfield(CONFIG, 'qc_dir')
    qc_dir = CONFIG.qc_dir;
else
    qc_dir = fullfile(CONFIG.output_dir, 'qc_matlab');
end

if ~exist(qc_dir, 'dir')
    mkdir(qc_dir);
end

%% A) qc_matlab_run_trial_counts.csv
run_trial_counts = table();
skip_reasons = table();

% Process all_run_qc_stats (one per run)
for j = 1:length(all_run_qc_stats)
    run_qc = all_run_qc_stats{j};
    
    if isfield(run_qc, 'segmentation_source') && isfield(run_qc, 'subject')
        % Extract alignment diagnostics safely
        if isfield(run_qc, 'alignment_diagnostics') && isstruct(run_qc.alignment_diagnostics) && ...
           ~isempty(fieldnames(run_qc.alignment_diagnostics))
            if isfield(run_qc.alignment_diagnostics, 'method')
                timebase_method = run_qc.alignment_diagnostics.method;
            else
                timebase_method = 'unknown';
            end
            if isfield(run_qc.alignment_diagnostics, 'offset')
                timebase_offset = run_qc.alignment_diagnostics.offset;
            else
                timebase_offset = NaN;
            end
            if isfield(run_qc.alignment_diagnostics, 'confidence')
                confidence = run_qc.alignment_diagnostics.confidence;
            else
                confidence = 'unknown';
            end
        else
            timebase_method = 'unknown';
            timebase_offset = NaN;
            confidence = 'unknown';
        end
        
        % FALSIFICATION: Extract additional diagnostics
        window_oob_count = 0;
        empty_trial_count = 0;
        all_nan_trial_count = 0;
        start_idx_monotonic = true;
        n_duplicate_segments = 0;
        n_duplicate_hashes = 0;
        logP_plausibility_valid = true;
        run_status = 'success';
        
        if isfield(run_qc, 'window_oob_count')
            window_oob_count = run_qc.window_oob_count;
        end
        if isfield(run_qc, 'empty_trial_count')
            empty_trial_count = run_qc.empty_trial_count;
        end
        if isfield(run_qc, 'all_nan_trial_count')
            all_nan_trial_count = run_qc.all_nan_trial_count;
        end
        if isfield(run_qc, 'start_idx_monotonic')
            start_idx_monotonic = run_qc.start_idx_monotonic;
        end
        if isfield(run_qc, 'n_duplicate_segments')
            n_duplicate_segments = run_qc.n_duplicate_segments;
        end
        if isfield(run_qc, 'n_duplicate_hashes')
            n_duplicate_hashes = run_qc.n_duplicate_hashes;
        end
        if isfield(run_qc, 'logP_plausibility_valid')
            logP_plausibility_valid = run_qc.logP_plausibility_valid;
        end
        if isfield(run_qc, 'run_status')
            run_status = run_qc.run_status;
        end
        
        % HARDENING: Add pipeline_run_id
        pipeline_run_id = '';
        if isfield(CONFIG, 'pipeline_run_id')
            pipeline_run_id = CONFIG.pipeline_run_id;
        end
        
        row = table(...
            {run_qc.subject}, {run_qc.task}, {run_qc.session}, run_qc.run, ...
            run_qc.n_log_trials, ...
            run_qc.n_marker_anchors, ...
            run_qc.n_trials_exported, ...
            {run_qc.segmentation_source}, ...
            run_qc.n_window_oob, ...
            {timebase_method}, ...
            timebase_offset, ...
            {confidence}, ...
            window_oob_count, ...
            empty_trial_count, ...
            all_nan_trial_count, ...
            start_idx_monotonic, ...
            n_duplicate_segments, ...
            n_duplicate_hashes, ...
            logP_plausibility_valid, ...
            {run_status}, ...
            {pipeline_run_id}, ...
            {''}, ...
            'VariableNames', {'subject', 'task', 'session', 'run', ...
            'n_log_trials', 'n_marker_anchors', 'n_trials_extracted', ...
            'segmentation_source', 'n_window_oob', 'timebase_method', ...
            'timebase_offset', 'confidence', 'window_oob_count', ...
            'empty_trial_count', 'all_nan_trial_count', ...
            'start_idx_monotonic', 'n_duplicate_segments', 'n_duplicate_hashes', ...
            'logP_plausibility_valid', 'run_status', 'pipeline_run_id', 'notes'});
        run_trial_counts = [run_trial_counts; row];
    end
end

% Also check quality reports for skipped runs
for i = 1:length(all_quality_reports)
    qr = all_quality_reports{i};
    if qr.total_trials == 0
        % Run was skipped - check if already in skip_reasons
        already_skipped = false;
        for k = 1:height(skip_reasons)
            if strcmp(skip_reasons.subject{k}, qr.subject) && ...
               strcmp(skip_reasons.task{k}, qr.task) && ...
               strcmp(skip_reasons.session{k}, qr.session)
                already_skipped = true;
                break;
            end
        end
        if ~already_skipped
            skip_row = table(...
                {qr.subject}, {qr.task}, {qr.session}, NaN, ...
                {'No trials extracted'}, {''}, ...
                'VariableNames', {'subject', 'task', 'session', 'run', 'skip_reason', 'details'});
            skip_reasons = [skip_reasons; skip_row];
        end
    end
end

% FALSIFICATION: Add skip reasons from run_status
for j = 1:length(all_run_qc_stats)
    run_qc = all_run_qc_stats{j};
    if isfield(run_qc, 'run_status') && isfield(run_qc, 'subject')
        if strcmp(run_qc.run_status, 'logP_invalid') || strcmp(run_qc.run_status, 'timebase_bug')
            skip_row = table(...
                {run_qc.subject}, {run_qc.task}, {run_qc.session}, run_qc.run, ...
                {run_qc.run_status}, {''}, ...
                'VariableNames', {'subject', 'task', 'session', 'run', 'skip_reason', 'details'});
            skip_reasons = [skip_reasons; skip_row];
        end
    end
end

if ~isempty(run_trial_counts)
    writetable(run_trial_counts, fullfile(qc_dir, 'qc_matlab_run_trial_counts.csv'));
    fprintf('  Saved: qc_matlab_run_trial_counts.csv (%d runs)\n', height(run_trial_counts));
end

if ~isempty(skip_reasons)
    writetable(skip_reasons, fullfile(qc_dir, 'qc_matlab_skip_reasons.csv'));
    fprintf('  Saved: qc_matlab_skip_reasons.csv (%d skipped runs)\n', height(skip_reasons));
end

%% C) qc_matlab_trial_level_flags.csv (aggregate from all flat files)
% This would require reading all flat files - for now, create placeholder
% In full implementation, this would be populated during processing

fprintf('  NOTE: qc_matlab_trial_level_flags.csv requires aggregation from flat files\n');
fprintf('  (Can be generated in post-processing step)\n');

%% D) qc_matlab_excluded_files.csv
if isfield(CONFIG, 'excluded_files') && ~isempty(CONFIG.excluded_files)
    excluded_path = fullfile(qc_dir, 'qc_matlab_excluded_files.csv');
    writetable(CONFIG.excluded_files, excluded_path);
    fprintf('  Saved: qc_matlab_excluded_files.csv (%d excluded files)\n', height(CONFIG.excluded_files));
end

%% E) qc_matlab_inferred_session_files.csv
if isfield(CONFIG, 'inferred_files') && ~isempty(CONFIG.inferred_files)
    inferred_path = fullfile(qc_dir, 'qc_matlab_inferred_session_files.csv');
    writetable(CONFIG.inferred_files, inferred_path);
    fprintf('  Saved: qc_matlab_inferred_session_files.csv (%d inferred files)\n', height(CONFIG.inferred_files));
end

end
