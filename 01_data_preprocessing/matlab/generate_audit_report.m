function generate_audit_report(manifest_data, all_run_qc_stats, all_quality_reports, CONFIG)
% Generate comprehensive audit report markdown
% HARDENING: Ensures provenance isolation and internal consistency

fprintf('\n=== GENERATING AUDIT REPORT ===\n');

audit_path = fullfile(CONFIG.build_dir, 'matlab_audit_report.md');
fid = fopen(audit_path, 'w');

if fid == -1
    fprintf('  ERROR: Cannot create audit report file\n');
    return;
end

%% Header
fprintf(fid, '# MATLAB Pipeline Audit Report\n\n');
fprintf(fid, '**BUILD_ID**: %s\n\n', CONFIG.BUILD_ID);
if isfield(CONFIG, 'pipeline_run_id')
    fprintf(fid, '**Pipeline Run ID**: %s\n\n', CONFIG.pipeline_run_id);
end
fprintf(fid, '**Generated**: %s\n\n', datestr(now));
fprintf(fid, '**Build Directory**: `%s`\n\n', CONFIG.build_dir);
fprintf(fid, '---\n\n');

%% 1. Processed Runs Summary
fprintf(fid, '## 1. Processed Runs Summary\n\n');
fprintf(fid, 'Total runs in manifest: **%d**\n\n', length(manifest_data));

% Count by segmentation source
segmentation_sources = {};
for i = 1:length(manifest_data)
    if isfield(manifest_data{i}, 'segmentation_source')
        seg = manifest_data{i}.segmentation_source;
        if ~ismember(seg, segmentation_sources)
            segmentation_sources{end+1} = seg;
        end
    end
end

fprintf(fid, '### Segmentation Source Distribution\n\n');
fprintf(fid, '| Source | Count |\n');
fprintf(fid, '|--------|-------|\n');
for i = 1:length(segmentation_sources)
    seg = segmentation_sources{i};
    count = 0;
    for j = 1:length(manifest_data)
        if isfield(manifest_data{j}, 'segmentation_source') && strcmp(manifest_data{j}.segmentation_source, seg)
            count = count + 1;
        end
    end
    fprintf(fid, '| %s | %d |\n', seg, count);
end
fprintf(fid, '\n');

%% 2. Session 1 Exclusion Verification
fprintf(fid, '## 2. Session 1 Exclusion Verification\n\n');
session_1_count = 0;
for i = 1:length(manifest_data)
    if isfield(manifest_data{i}, 'session')
        ses_str = num2str(manifest_data{i}.session);
        if strcmp(ses_str, '1')
            session_1_count = session_1_count + 1;
        end
    end
end

if session_1_count == 0
    fprintf(fid, '✅ **PASS**: No session 1 files processed (session_1_count = 0)\n\n');
else
    fprintf(fid, '❌ **FAIL**: Found %d runs with session=1\n\n', session_1_count);
    fprintf(fid, '| Subject | Task | Session | Run | Status |\n');
    fprintf(fid, '|---------|------|---------|-----|--------|\n');
    for i = 1:length(manifest_data)
        if isfield(manifest_data{i}, 'session')
            ses_str = num2str(manifest_data{i}.session);
            if strcmp(ses_str, '1')
                fprintf(fid, '| %s | %s | %s | %d | %s |\n', ...
                    manifest_data{i}.subject, manifest_data{i}.task, ...
                    ses_str, manifest_data{i}.run, manifest_data{i}.run_status);
            end
        end
    end
    fprintf(fid, '\n');
end

%% 3. logP Missing Warnings
fprintf(fid, '## 3. logP Missing Warnings\n\n');
logp_missing = {};
for i = 1:length(manifest_data)
    if isfield(manifest_data{i}, 'run_status')
        if contains(manifest_data{i}.run_status, 'WARN_LOGP_MISSING') || ...
           (isfield(manifest_data{i}, 'n_log_trials') && manifest_data{i}.n_log_trials == 0 && ...
            manifest_data{i}.n_trials_extracted > 0)
            logp_missing{end+1} = manifest_data{i};
        end
    end
end

if isempty(logp_missing)
    fprintf(fid, '✅ **PASS**: No runs with missing logP files\n\n');
else
    fprintf(fid, '⚠️ **WARNING**: Found %d runs with missing logP files\n\n', length(logp_missing));
    fprintf(fid, '| Subject | Task | Session | Run | n_trials_extracted | Status |\n');
    fprintf(fid, '|---------|------|---------|-----|---------------------|--------|\n');
    for i = 1:length(logp_missing)
        m = logp_missing{i};
        fprintf(fid, '| %s | %s | %s | %d | %d | %s |\n', ...
            m.subject, m.task, num2str(m.session), m.run, ...
            m.n_trials_extracted, m.run_status);
    end
    fprintf(fid, '\n');
end

%% 4. Trial Count Analysis
fprintf(fid, '## 4. Trial Count Analysis\n\n');

% Aggregate by subject×task×session
subject_task_session = struct();
for i = 1:length(manifest_data)
    m = manifest_data{i};
    key = sprintf('%s_%s_%s', m.subject, m.task, num2str(m.session));
    if ~isfield(subject_task_session, key)
        subject_task_session.(key) = struct();
        subject_task_session.(key).subject = m.subject;
        subject_task_session.(key).task = m.task;
        subject_task_session.(key).session = m.session;
        subject_task_session.(key).n_trials_extracted = 0;
        subject_task_session.(key).n_runs = 0;
    end
    subject_task_session.(key).n_trials_extracted = ...
        subject_task_session.(key).n_trials_extracted + m.n_trials_extracted;
    subject_task_session.(key).n_runs = subject_task_session.(key).n_runs + 1;
end

fprintf(fid, '### Per Subject×Task×Session Extracted Trials\n\n');
fprintf(fid, '| Subject | Task | Session | Extracted Trials | Expected (150) | Coverage | Runs |\n');
fprintf(fid, '|---------|------|---------|-------------------|----------------|----------|------|\n');

keys = fieldnames(subject_task_session);
for i = 1:length(keys)
    key = keys{i};
    s = subject_task_session.(key);
    coverage = 100 * s.n_trials_extracted / 150;
    fprintf(fid, '| %s | %s | %d | %d | 150 | %.1f%% | %d |\n', ...
        s.subject, s.task, s.session, s.n_trials_extracted, coverage, s.n_runs);
end
fprintf(fid, '\n');

%% 5. Internal Consistency Check
fprintf(fid, '## 5. Internal Consistency Check\n\n');

% Compare manifest totals vs QC totals
manifest_total_trials = 0;
for i = 1:length(manifest_data)
    manifest_total_trials = manifest_total_trials + manifest_data{i}.n_trials_extracted;
end

qc_total_trials = 0;
for i = 1:length(all_run_qc_stats)
    if isfield(all_run_qc_stats{i}, 'n_trials_exported')
        qc_total_trials = qc_total_trials + all_run_qc_stats{i}.n_trials_exported;
    end
end

quality_total_trials = 0;
for i = 1:length(all_quality_reports)
    if isfield(all_quality_reports{i}, 'total_trials')
        quality_total_trials = quality_total_trials + all_quality_reports{i}.total_trials;
    end
end

fprintf(fid, '| Source | Total Trials |\n');
fprintf(fid, '|--------|--------------|\n');
fprintf(fid, '| Manifest | %d |\n', manifest_total_trials);
fprintf(fid, '| QC Stats | %d |\n', qc_total_trials);
fprintf(fid, '| Quality Reports | %d |\n', quality_total_trials);
fprintf(fid, '\n');

if abs(manifest_total_trials - qc_total_trials) <= 1 && abs(manifest_total_trials - quality_total_trials) <= 1
    fprintf(fid, '✅ **PASS**: All counts align (within 1 trial tolerance)\n\n');
else
    fprintf(fid, '⚠️ **WARNING**: Count mismatch detected\n\n');
    fprintf(fid, '- Manifest vs QC: %d difference\n', abs(manifest_total_trials - qc_total_trials));
    fprintf(fid, '- Manifest vs Quality: %d difference\n', abs(manifest_total_trials - quality_total_trials));
    fprintf(fid, '\n');
end

%% 6. What MATLAB Guarantees vs Downstream Gates
fprintf(fid, '## 6. What MATLAB Guarantees vs What Downstream Gates Decide\n\n');

fprintf(fid, '### MATLAB Stage Guarantees:\n\n');
fprintf(fid, '1. **Trial extraction**: MATLAB extracts all trials that meet minimum sample count (100 samples)\n');
fprintf(fid, '2. **Provenance**: Only sessions 2-3, InsideScanner files are processed\n');
fprintf(fid, '3. **Trial indexing**: `trial_in_run_raw` preserves original trial order (1-30) for merging\n');
fprintf(fid, '4. **QC flags**: MATLAB computes validity proportions and flags but does NOT exclude trials\n');
fprintf(fid, '5. **Segmentation**: Uses event-codes if validated, otherwise logP fallback\n');
fprintf(fid, '6. **Timebase**: Converts pupil timestamps to PTB reference frame when logP available\n\n');

fprintf(fid, '### Downstream Gates Decide:\n\n');
fprintf(fid, '1. **Analysis-specific inclusion**: R/QMD stages apply gates (stimlocked, total_auc, cog_auc)\n');
fprintf(fid, '2. **Threshold selection**: Downstream chooses validity thresholds (0.60, 0.70, 0.80, etc.)\n');
fprintf(fid, '3. **Final usability**: Only downstream stages determine which trials are "usable" for analysis\n');
fprintf(fid, '4. **Missing data handling**: Downstream decides interpolation vs exclusion policies\n\n');

fprintf(fid, '### Key Principle:\n\n');
fprintf(fid, '**MATLAB exports ALL extracted trials with QC flags. Downstream gates decide final inclusion.**\n\n');

%% Footer
fprintf(fid, '---\n\n');
fprintf(fid, '**End of Audit Report**\n');

fclose(fid);
fprintf('  Saved: matlab_audit_report.md\n');

end

