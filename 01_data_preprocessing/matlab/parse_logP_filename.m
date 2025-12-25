function metadata = parse_logP_filename(logP_path)
% Parse session and run from logP filename
% Returns struct with session and run, or empty if parsing fails

metadata = struct();

[~, filename, ~] = fileparts(logP_path);

% Extract session
session_match = regexp(filename, 'session(\d+)', 'tokens');
if isempty(session_match)
    session_match = regexp(filename, 'ses[-_]?(\d+)', 'tokens');
end
if isempty(session_match)
    return;
end
metadata.session = session_match{1}{1};

% Extract run
run_match = regexp(filename, 'run(\d+)', 'tokens');
if isempty(run_match)
    return;
end
metadata.run = str2double(run_match{1}{1});

end
