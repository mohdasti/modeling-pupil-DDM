function logP_data = parse_logP_file(logP_path)
% Parse logP.txt file to extract PTB trial times
% Returns struct with trial information

logP_data = struct();
logP_data.success = false;
logP_data.n_trials = 0;
logP_data.trial_st = [];
logP_data.blank_st = [];
logP_data.fix_st = [];
logP_data.av_st = [];
logP_data.resp1_st = [];
logP_data.resp2_st = [];
logP_data.headers = {};

if ~exist(logP_path, 'file')
    return;
end

fid = fopen(logP_path, 'r');
if fid == -1
    return;
end

% Read header lines (start with %)
header_lines = {};
line = fgetl(fid);
while ~feof(fid) && ~isempty(line) && length(line) > 0 && line(1) == '%'
    header_lines{end+1} = line;
    line = fgetl(fid);
    % Skip empty lines
    while ~feof(fid) && (isempty(line) || length(line) == 0)
        line = fgetl(fid);
    end
end

% Parse header line for column names
% Handle case where line might be empty after headers
if isempty(line) || length(line) == 0
    line = fgetl(fid);
end

% Skip empty lines until we find the header
while ~feof(fid) && (isempty(line) || length(line) == 0 || line(1) == '%')
    line = fgetl(fid);
end

if isempty(line) || length(line) == 0
    fclose(fid);
    return;
end

headers = strsplit(line, '\t');
% Trim whitespace from headers
headers = cellfun(@strtrim, headers, 'UniformOutput', false);
logP_data.headers = headers;

% Find column indices (handle case-insensitive and variations, with trimmed headers)
trial_st_idx = [];
for i = 1:length(headers)
    h_trimmed = strtrim(headers{i});
    if contains(lower(h_trimmed), 'trialst') || contains(lower(h_trimmed), 'trial_st')
        trial_st_idx = i;
        break;
    end
end

blank_st_idx = [];
for i = 1:length(headers)
    h_trimmed = strtrim(headers{i});
    if contains(lower(h_trimmed), 'blankst') || contains(lower(h_trimmed), 'blank_st')
        blank_st_idx = i;
        break;
    end
end

fix_st_idx = [];
for i = 1:length(headers)
    h_trimmed = strtrim(headers{i});
    if contains(lower(h_trimmed), 'fixst') || contains(lower(h_trimmed), 'fix_st')
        fix_st_idx = i;
        break;
    end
end

av_st_idx = [];
for i = 1:length(headers)
    h_trimmed = strtrim(headers{i});
    if contains(h_trimmed, 'A/V_ST') || contains(lower(h_trimmed), 'av_st')
        av_st_idx = i;
        break;
    end
end

resp1_st_idx = [];
for i = 1:length(headers)
    h_trimmed = strtrim(headers{i});
    if contains(lower(h_trimmed), 'resp1st') || contains(lower(h_trimmed), 'resp1_st')
        resp1_st_idx = i;
        break;
    end
end

resp2_st_idx = [];
for i = 1:length(headers)
    h_trimmed = strtrim(headers{i});
    if contains(lower(h_trimmed), 'resp2st') || contains(lower(h_trimmed), 'resp2_st')
        resp2_st_idx = i;
        break;
    end
end

% Debug: print found indices
if isempty(trial_st_idx)
    fprintf('  WARNING: TrialST column not found in logP headers\n');
    fprintf('  Headers: %s\n', strjoin(headers, ', '));
    fclose(fid);
    return;
end

% Read data rows
trial_st = [];
blank_st = [];
fix_st = [];
av_st = [];
resp1_st = [];
resp2_st = [];

while ~feof(fid)
    line = fgetl(fid);
    if isempty(line) || (length(line) > 0 && line(1) == '%')
        continue;
    end
    
    % Skip empty lines
    if isempty(strtrim(line))
        continue;
    end
    
    parts = strsplit(line, '\t');
    % Trim whitespace from parts
    parts = cellfun(@strtrim, parts, 'UniformOutput', false);
    
    % Only process if we have enough columns
    max_idx = max([trial_st_idx, blank_st_idx, fix_st_idx, av_st_idx, resp1_st_idx, resp2_st_idx]);
    if length(parts) < max_idx
        continue;
    end
    
    if ~isempty(trial_st_idx) && length(parts) >= trial_st_idx
        trial_st_val = str2double(parts{trial_st_idx});
        if ~isnan(trial_st_val)
            trial_st(end+1) = trial_st_val;
        end
    end
    if ~isempty(blank_st_idx) && length(parts) >= blank_st_idx
        blank_st_val = str2double(parts{blank_st_idx});
        if ~isnan(blank_st_val)
            blank_st(end+1) = blank_st_val;
        end
    end
    if ~isempty(fix_st_idx) && length(parts) >= fix_st_idx
        fix_st_val = str2double(parts{fix_st_idx});
        if ~isnan(fix_st_val)
            fix_st(end+1) = fix_st_val;
        end
    end
    if ~isempty(av_st_idx) && length(parts) >= av_st_idx
        av_st_val = str2double(parts{av_st_idx});
        if ~isnan(av_st_val)
            av_st(end+1) = av_st_val;
        end
    end
    if ~isempty(resp1_st_idx) && length(parts) >= resp1_st_idx
        resp1_st_val = str2double(parts{resp1_st_idx});
        if ~isnan(resp1_st_val)
            resp1_st(end+1) = resp1_st_val;
        end
    end
    if ~isempty(resp2_st_idx) && length(parts) >= resp2_st_idx
        resp2_st_val = str2double(parts{resp2_st_idx});
        if ~isnan(resp2_st_val)
            resp2_st(end+1) = resp2_st_val;
        end
    end
end

fclose(fid);

% Store results
if isempty(trial_st)
    fprintf('  ERROR: No trial_st values extracted from logP file\n');
    logP_data.success = false;
    return;
end

logP_data.success = true;
logP_data.n_trials = length(trial_st);
logP_data.trial_st = trial_st;
logP_data.blank_st = blank_st;
logP_data.fix_st = fix_st;
logP_data.av_st = av_st;
logP_data.resp1_st = resp1_st;
logP_data.resp2_st = resp2_st;

fprintf('  Parsed logP: %d trials, TrialST range: %.3f to %.3f\n', ...
    logP_data.n_trials, min(trial_st), max(trial_st));

end
