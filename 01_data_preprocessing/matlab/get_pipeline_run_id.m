function pipeline_run_id = get_pipeline_run_id()
% Generate pipeline_run_id: timestamp + git hash
% Format: YYYYMMDD_HHMMSS_<git_hash_short>

timestamp = datestr(now, 'yyyymmdd_HHMMSS');

% Try to get git hash
git_hash = '';
try
    % Try to get git hash from current directory
    [status, result] = system('git rev-parse --short HEAD');
    if status == 0
        git_hash = strtrim(result);
    else
        git_hash = 'nogit';
    end
catch
    git_hash = 'nogit';
end

pipeline_run_id = sprintf('%s_%s', timestamp, git_hash);

end

