function audit_discovery(CONFIG)
% Discovery audit: Enumerate all cleaned.mat files and parse metadata
% Output: parsed_metadata_inventory.csv

fprintf('\n=== DISCOVERY AUDIT ===\n');

cleaned_dir = CONFIG.cleaned_dir;
cleaned_files = dir(fullfile(cleaned_dir, '*_cleaned.mat'));

fprintf('Found %d cleaned.mat files\n', length(cleaned_files));

inventory = table();

for i = 1:length(cleaned_files)
    filename = cleaned_files(i).name;
    filepath = fullfile(cleaned_dir, filename);
    
    % Attempt to parse metadata
    metadata = parse_filename(filename);
    
    row = table();
    row.filename = {filename};
    row.filepath = {filepath};
    
    if isempty(metadata)
        row.parse_success = false;
        row.subject = {''};
        row.task = {''};
        row.session = {''};
        row.run = NaN;
        row.parse_failure_reason = {'parse_filename returned empty'};
        row.would_default_session1 = false;
        row.would_default_run1 = false;
    else
        row.parse_success = true;
        row.subject = {metadata.subject};
        row.task = {metadata.task};
        row.session = {metadata.session};
        row.run = metadata.run;
        row.parse_failure_reason = {''};
        
        % Check what old code would have done
        session_num = str2double(metadata.session);
        row.would_default_session1 = (session_num == 1);
        row.would_default_run1 = (metadata.run == 1);
    end
    
    inventory = [inventory; row];
end

% Summary statistics
n_total = height(inventory);
n_parse_success = sum(inventory.parse_success);
n_parse_failure = n_total - n_parse_success;
n_would_default_session1 = sum(inventory.would_default_session1);
n_would_default_run1 = sum(inventory.would_default_run1);

fprintf('\nParse Summary:\n');
fprintf('  Total files: %d\n', n_total);
fprintf('  Parse success: %d (%.1f%%)\n', n_parse_success, 100*n_parse_success/n_total);
fprintf('  Parse failure: %d (%.1f%%)\n', n_parse_failure, 100*n_parse_failure/n_total);
fprintf('  Would default to session=1: %d\n', n_would_default_session1);
fprintf('  Would default to run=1: %d\n', n_would_default_run1);

% Save inventory
if isfield(CONFIG, 'qc_dir')
    output_path = fullfile(CONFIG.qc_dir, 'parsed_metadata_inventory.csv');
else
    output_path = fullfile(CONFIG.output_dir, 'qc_matlab', 'parsed_metadata_inventory.csv');
    qc_dir = fileparts(output_path);
    if ~exist(qc_dir, 'dir')
        mkdir(qc_dir);
    end
end

writetable(inventory, output_path);
fprintf('\nSaved: %s\n', output_path);

end

