function codebook = discover_event_codes(task_code_dir, raw_file)
% Discover event codes from task code repo or data
% Returns codebook table with code, label, source

codebook = table();

% Try to find task code repo
if nargin < 1 || isempty(task_code_dir)
    search_cmd = 'find /Users/mohdasti/Documents -type d -name "lc-aging" -o -name "task-code" -o -name "aim-1" 2>/dev/null | head -1';
    [status, result] = system(search_cmd);
    if status == 0 && ~isempty(result)
        task_code_dir = strtrim(result);
    end
end

% Search for marker definitions in task code
if ~isempty(task_code_dir) && exist(task_code_dir, 'dir')
    grep_cmd = sprintf('grep -r -h "SetMarker\\|marker.*=\\|304[0-9]" "%s" --include="*.m" 2>/dev/null | head -20', task_code_dir);
    [status, result] = system(grep_cmd);
    % Parse results (simplified - would need more sophisticated parsing)
end

% Fallback: use current assumptions (to be validated)
codebook = table([3040; 3041; 3042; 3044; 3048], ...
    {'baseline'; 'response_start'; 'stimulus_start'; 'squeeze_start'; 'confidence_start'}, ...
    {'assumed_from_config'; 'assumed_from_config'; 'assumed_from_config'; 'assumed_from_config'; 'assumed_from_config'}, ...
    'VariableNames', {'code', 'label', 'source'});

end

