function generate_signoff_report(CONFIG)
% Generate MATLAB pipeline sign-off report
% Output: qc_matlab/MATLAB_PIPELINE_SIGNOFF.md

fprintf('\n=== GENERATING SIGN-OFF REPORT ===\n');

if isfield(CONFIG, 'qc_dir')
    qc_dir = CONFIG.qc_dir;
else
    qc_dir = fullfile(CONFIG.output_dir, 'qc_matlab');
end

report_path = fullfile(qc_dir, 'MATLAB_PIPELINE_SIGNOFF.md');
fid = fopen(report_path, 'w');

if fid == -1
    fprintf('  ERROR: Cannot create sign-off report\n');
    return;
end

%% Load QC data
qc_run_counts_path = fullfile(qc_dir, 'qc_matlab_run_trial_counts.csv');
qc_trial_flags_path = fullfile(qc_dir, 'qc_matlab_trial_level_flags.csv');
qc_skip_reasons_path = fullfile(qc_dir, 'qc_matlab_skip_reasons.csv');
inventory_path = fullfile(qc_dir, 'parsed_metadata_inventory.csv');
logp_integrity_path = fullfile(qc_dir, 'qc_logP_integrity_by_run.csv');
timebase_checks_path = fullfile(qc_dir, 'qc_timebase_and_iti_checks.csv');
qc_expected_path = fullfile(qc_dir, 'qc_expected_vs_observed_runs.csv');

%% Header
fprintf(fid, '# MATLAB Pipeline Sign-Off Report\n\n');
fprintf(fid, '**Generated**: %s\n\n', datestr(now));

% Try to get pipeline_run_id from QC data if available
if exist(qc_run_counts_path, 'file')
    qc_data = readtable(qc_run_counts_path);
    if ismember('pipeline_run_id', qc_data.Properties.VariableNames)
        pipeline_run_id = unique(qc_data.pipeline_run_id);
        if ~isempty(pipeline_run_id)
            fprintf(fid, '**Pipeline Run ID**: %s\n\n', pipeline_run_id{1});
        end
    end
end

fprintf(fid, '**Purpose**: Verify MATLAB stage extracts correct trial windows from valid scanner tasks (sessions 2-3), preserves run numbers (1-5), and produces internally consistent QC artifacts.\n\n');
fprintf(fid, '---\n\n');

%% 1. Counts Summary
fprintf(fid, '## 1. Counts Summary\n\n');

if exist(qc_run_counts_path, 'file')
    qc_data = readtable(qc_run_counts_path);
    
    n_subjects = length(unique(qc_data.subject));
    n_sessions = length(unique(qc_data.session));
    n_tasks = length(unique(qc_data.task));
    n_runs = height(qc_data);
    n_trials = sum(qc_data.n_trials_extracted);
    
    fprintf(fid, '| Metric | Count |\n');
    fprintf(fid, '|--------|-------|\n');
    fprintf(fid, '| Subjects | %d |\n', n_subjects);
    fprintf(fid, '| Sessions | %d |\n', n_sessions);
    fprintf(fid, '| Tasks | %d |\n', n_tasks);
    fprintf(fid, '| Runs | %d |\n', n_runs);
    fprintf(fid, '| Trials | %d |\n', n_trials);
    fprintf(fid, '\n');
else
    fprintf(fid, '⚠️ **WARNING**: qc_matlab_run_trial_counts.csv not found\n\n');
end

%% 2. Segmentation Source Distribution
fprintf(fid, '## 2. Segmentation Source Distribution\n\n');

if exist(qc_run_counts_path, 'file')
    % Use groupsummary to count rows per segmentation_source
    % 'numel' counts non-NaN elements, or we can use automatic counting
    seg_counts = groupsummary(qc_data, 'segmentation_source');
    fprintf(fid, '| Source | Count | Percentage |\n');
    fprintf(fid, '|--------|-------|------------|\n');
    for i = 1:height(seg_counts)
        pct = 100 * seg_counts.GroupCount(i) / n_runs;
        fprintf(fid, '| %s | %d | %.1f%% |\n', ...
            seg_counts.segmentation_source{i}, seg_counts.GroupCount(i), pct);
    end
    fprintf(fid, '\n');
    
    % Check segmentation confidence
    logp_runs = sum(strcmp(qc_data.segmentation_source, 'logP'));
    eventcode_runs = sum(strcmp(qc_data.segmentation_source, 'event_code'));
    fprintf(fid, '### Segmentation Confidence\n\n');
    fprintf(fid, '- **logP-driven (primary)**: %d runs (%.1f%%)\n', logp_runs, 100*logp_runs/n_runs);
    fprintf(fid, '- **event-code (fallback)**: %d runs (%.1f%%)\n', eventcode_runs, 100*eventcode_runs/n_runs);
    fprintf(fid, '\n');
    
    if exist(timebase_checks_path, 'file')
        timebase_data = readtable(timebase_checks_path);
        eventcode_runs_data = timebase_data(strcmp(timebase_data.segmentation_source, 'event_code'), :);
        if ~isempty(eventcode_runs_data)
            fprintf(fid, '**Event-code segmentation validation**:\n');
            fprintf(fid, '- Runs with valid ITI (median 8-25s, min >=5s): %d\n', ...
                sum(eventcode_runs_data.median_iti >= 8 & eventcode_runs_data.median_iti <= 25 & ...
                    eventcode_runs_data.min_iti >= 5));
            fprintf(fid, '\n');
        end
    end
end

%% 3. Session 1 Exclusion
fprintf(fid, '## 3. Session 1 Exclusion Verification\n\n');

if exist(qc_run_counts_path, 'file')
    session_1_count = sum(qc_data.session == 1);
    if session_1_count == 0
        fprintf(fid, '✅ **PASS**: No session 1 files processed (count = 0)\n\n');
    else
        fprintf(fid, '❌ **FAIL**: Found %d runs with session=1\n\n', session_1_count);
        fprintf(fid, '| Subject | Task | Session | Run |\n');
        fprintf(fid, '|---------|------|---------|-----|\n');
        session_1_runs = qc_data(qc_data.session == 1, :);
        for i = 1:height(session_1_runs)
            fprintf(fid, '| %s | %s | %d | %d |\n', ...
                session_1_runs.subject{i}, session_1_runs.task{i}, ...
                session_1_runs.session(i), session_1_runs.run(i));
        end
        fprintf(fid, '\n');
    end
end

%% 4. Run Number Validation
fprintf(fid, '## 4. Run Number Validation\n\n');

if exist(qc_run_counts_path, 'file')
    invalid_runs = qc_data(qc_data.run < 1 | qc_data.run > 5, :);
    if isempty(invalid_runs)
        fprintf(fid, '✅ **PASS**: All runs have valid run numbers (1-5)\n\n');
    else
        fprintf(fid, '❌ **FAIL**: Found %d runs with invalid run numbers\n\n', height(invalid_runs));
        fprintf(fid, '| Subject | Task | Session | Run |\n');
        fprintf(fid, '|---------|------|---------|-----|\n');
        for i = 1:height(invalid_runs)
            fprintf(fid, '| %s | %s | %d | %d |\n', ...
                invalid_runs.subject{i}, invalid_runs.task{i}, ...
                invalid_runs.session(i), invalid_runs.run(i));
        end
        fprintf(fid, '\n');
    end
end

%% 5. Skipped Runs
fprintf(fid, '## 5. Skipped Runs\n\n');

if exist(qc_skip_reasons_path, 'file')
    skip_data = readtable(qc_skip_reasons_path);
    fprintf(fid, 'Total skipped runs: **%d**\n\n', height(skip_data));
    
    if ~isempty(skip_data)
        skip_reasons = unique(skip_data.skip_reason);
        fprintf(fid, '| Reason | Count |\n');
        fprintf(fid, '|--------|-------|\n');
        for i = 1:length(skip_reasons)
            count = sum(strcmp(skip_data.skip_reason, skip_reasons{i}));
            fprintf(fid, '| %s | %d |\n', skip_reasons{i}, count);
        end
        fprintf(fid, '\n');
    end
else
    fprintf(fid, '⚠️ **WARNING**: qc_matlab_skip_reasons.csv not found\n\n');
end

%% 6. logP Integrity
fprintf(fid, '## 6. logP Integrity\n\n');

if exist(logp_integrity_path, 'file')
    logp_data = readtable(logp_integrity_path);
    n_logp_exists = sum(logp_data.logP_exists);
    n_logp_pass = sum(strcmp(logp_data.integrity_status, 'PASS'));
    
    fprintf(fid, '| Metric | Count |\n');
    fprintf(fid, '|--------|-------|\n');
    fprintf(fid, '| Runs with logP | %d |\n', n_logp_exists);
    fprintf(fid, '| logP integrity PASS | %d |\n', n_logp_pass);
    fprintf(fid, '\n');
else
    fprintf(fid, '⚠️ **WARNING**: qc_logP_integrity_by_run.csv not found\n\n');
end

%% 7. Expected vs Observed
fprintf(fid, '## 7. Expected vs Observed Runs\n\n');

if exist(qc_expected_path, 'file')
    expected_data = readtable(qc_expected_path);
    n_mismatches = sum(expected_data.mismatch);
    
    if n_mismatches == 0
        fprintf(fid, '✅ **PASS**: All expected runs observed\n\n');
    else
        fprintf(fid, '⚠️ **WARNING**: %d mismatches found\n\n', n_mismatches);
        fprintf(fid, '| Subject | Task | Expected | Observed | Reason |\n');
        fprintf(fid, '|---------|------|----------|----------|--------|\n');
        mismatches = expected_data(expected_data.mismatch, :);
        for i = 1:height(mismatches)
            fprintf(fid, '| %s | %s | %d | %d | %s |\n', ...
                mismatches.subject{i}, mismatches.task{i}, ...
                mismatches.expected_runs(i), mismatches.observed_runs(i), ...
                mismatches.mismatch_reason{i});
        end
        fprintf(fid, '\n');
    end
else
    fprintf(fid, '⚠️ **WARNING**: qc_expected_vs_observed_runs.csv not found\n\n');
end

%% 8. Final Recommendation
fprintf(fid, '## 8. Final Recommendation\n\n');

% Determine PASS/FAIL
status = 'PASS';
action_items = {};

if exist(qc_run_counts_path, 'file')
    if any(qc_data.session == 1)
        status = 'FAIL';
        action_items{end+1} = 'Remove session 1 files from processing';
    end
    
    if any(qc_data.run < 1 | qc_data.run > 5)
        status = 'FAIL';
        action_items{end+1} = 'Fix invalid run numbers';
    end
end

if exist(logp_integrity_path, 'file')
    logp_data = readtable(logp_integrity_path);
    n_logp_fail = sum(~strcmp(logp_data.integrity_status, 'PASS') & logp_data.logP_exists);
    if n_logp_fail > 0
        status = 'FAIL';
        action_items{end+1} = sprintf('Fix %d runs with logP integrity issues', n_logp_fail);
    end
end

if strcmp(status, 'PASS')
    fprintf(fid, '✅ **STATUS: PASS**\n\n');
    fprintf(fid, 'The MATLAB pipeline stage is ready for downstream processing.\n\n');
else
    fprintf(fid, '❌ **STATUS: FAIL**\n\n');
    fprintf(fid, 'The MATLAB pipeline stage requires fixes before proceeding.\n\n');
    fprintf(fid, '### Action Items:\n\n');
    for i = 1:length(action_items)
        fprintf(fid, '%d. %s\n', i, action_items{i});
    end
    fprintf(fid, '\n');
end

fprintf(fid, '---\n\n');
fprintf(fid, '**End of Sign-Off Report**\n');

fclose(fid);
fprintf('  Saved: MATLAB_PIPELINE_SIGNOFF.md\n');

end

