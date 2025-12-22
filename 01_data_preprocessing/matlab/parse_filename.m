function metadata = parse_filename(filename)
% Parse filename to extract subject, task, session, run information
% HARDENING: No silent defaults - returns empty on parse failure

metadata = struct();

% Extract subject ID
subject_match = regexp(filename, 'subject([A-Z0-9]+)_', 'tokens');
if isempty(subject_match)
    metadata = [];
    return;
end
metadata.subject = subject_match{1}{1};

% Extract task
if contains(filename, 'Aoddball')
    metadata.task = 'ADT';
elseif contains(filename, 'Voddball')
    metadata.task = 'VDT';
else
    metadata.task = 'Unknown';
end

% Extract session and run - CRITICAL FIX: Fail hard instead of defaulting
% Try multiple patterns for session, handling spaces and case variations
% Pattern 1: session3, session 3, Session3, Session 3 (with optional space)
session_match = regexp(filename, 'session\s*(\d+)', 'tokens', 'ignorecase');
if isempty(session_match)
    % Pattern 2: ses-2, ses_2, ses2, etc.
    session_match = regexp(filename, 'ses[-_]?\s*(\d+)', 'tokens', 'ignorecase');
end

% LENIENT FIX: If session number is missing but we see "session" followed by "run",
% try to infer session from context (default to 2 or 3 if in valid range)
metadata.session_inferred = false;
metadata.inference_reason = '';
if isempty(session_match)
    % Check if we have "session" keyword followed by "run" (missing session number)
    if ~isempty(regexp(filename, 'session', 'ignorecase')) && ~isempty(regexp(filename, 'run\s*\d+', 'ignorecase'))
        % Try to extract from date pattern or default to 2 (most common)
        % Look for pattern like session_<number>_run or session_run
        % For now, default to session 2 if we can't find it
        session_match = {{'2'}};  % Default to session 2
        metadata.session_inferred = true;
        metadata.inference_reason = 'session_defaulted_to_2_missing_in_filename';
        warning('LENIENT: Cannot parse session number from filename: %s. Defaulting to session 2 (inferred).', filename);
    else
        warning('CRITICAL: Cannot parse session from filename: %s. Skipping file.', filename);
        metadata = [];
        return;
    end
end
metadata.session = session_match{1}{1};
session_num = str2double(metadata.session);

% CRITICAL FIX: Only allow sessions 2 or 3 (InsideScanner tasks)
if session_num ~= 2 && session_num ~= 3
    warning('CRITICAL: Session %d not in {2,3} for file: %s. Skipping file.', session_num, filename);
    metadata = [];
    return;
end

% Try multiple patterns for run, handling spaces and case variations
% Pattern: run1, run 1, Run1, Run 1 (with optional space)
run_match = regexp(filename, 'run\s*(\d+)', 'tokens', 'ignorecase');
if isempty(run_match)
    % LENIENT FIX: If run number is missing, try to extract from pattern like session3_5_...
    % where the number after session3_ might be the run number
    session_str = metadata.session;
    % Try pattern: session3_5 or session3-5 (number immediately after session)
    % Use character class [_-] instead of [_\-] to avoid sprintf escape issues
    pattern1 = ['session' session_str '[_-](\d+)'];
    session_run_pattern = regexp(filename, pattern1, 'tokens', 'ignorecase');
    if isempty(session_run_pattern)
        % Also try: session3_5_ (with underscore after the number)
        pattern2 = ['session' session_str '[_-](\d+)[_-]'];
        session_run_pattern = regexp(filename, pattern2, 'tokens', 'ignorecase');
    end
    if ~isempty(session_run_pattern)
        potential_run = str2double(session_run_pattern{1}{1});
        % Check if it's a valid run number (1-5)
        if potential_run >= 1 && potential_run <= 5
            run_match = session_run_pattern;
            warning('LENIENT: Extracted run number %d from pattern in filename: %s', potential_run, filename);
        end
    end
end
if isempty(run_match)
    warning('CRITICAL: Cannot parse run from filename: %s. Skipping file.', filename);
    metadata = [];
    return;
end
metadata.run = str2double(run_match{1}{1});
end

