function write_manifest(manifest_data, build_dir)
% Write manifest_runs.csv with all run metadata
% manifest_data: cell array of structs, one per run

if isempty(manifest_data)
    fprintf('  WARNING: No manifest data to write\n');
    return;
end

% Convert to table
manifest_table = table();

for i = 1:length(manifest_data)
    m = manifest_data{i};
    
    % Ensure all required fields exist
    if ~isfield(m, 'subject'), m.subject = ''; end
    if ~isfield(m, 'task'), m.task = ''; end
    if ~isfield(m, 'session'), m.session = ''; end
    if ~isfield(m, 'run'), m.run = NaN; end
    if ~isfield(m, 'cleaned_mat_path'), m.cleaned_mat_path = ''; end
    if ~isfield(m, 'eyetrack_mat_path'), m.eyetrack_mat_path = ''; end
    if ~isfield(m, 'logP_path'), m.logP_path = ''; end
    if ~isfield(m, 'segmentation_source'), m.segmentation_source = 'unknown'; end
    if ~isfield(m, 'n_trials_extracted'), m.n_trials_extracted = 0; end
    if ~isfield(m, 'n_log_trials'), m.n_log_trials = 0; end
    if ~isfield(m, 'n_marker_anchors'), m.n_marker_anchors = 0; end
    if ~isfield(m, 'timebase_method'), m.timebase_method = 'unknown'; end
    if ~isfield(m, 'run_status'), m.run_status = 'unknown'; end
    if ~isfield(m, 'notes'), m.notes = ''; end
    
    row = table(...
        {m.subject}, {m.task}, {m.session}, m.run, ...
        {m.cleaned_mat_path}, {m.eyetrack_mat_path}, {m.logP_path}, ...
        {m.segmentation_source}, m.n_trials_extracted, m.n_log_trials, m.n_marker_anchors, ...
        {m.timebase_method}, {m.run_status}, {m.notes}, ...
        'VariableNames', {'subject', 'task', 'session', 'run', ...
        'cleaned_mat_path', 'eyetrack_mat_path', 'logP_path', ...
        'segmentation_source', 'n_trials_extracted', 'n_log_trials', 'n_marker_anchors', ...
        'timebase_method', 'run_status', 'notes'});
    
    manifest_table = [manifest_table; row];
end

% Write to file
manifest_path = fullfile(build_dir, 'manifest_runs.csv');
writetable(manifest_table, manifest_path);
fprintf('  Saved: manifest_runs.csv (%d runs)\n', height(manifest_table));

end

