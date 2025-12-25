function [pupil_time_ptb, alignment_diagnostics] = convert_timebase(cleaned_data, logP_data, raw_data)
% Convert pupil timestamps to PTB reference frame (same as logP times)
%
% Inputs:
%   cleaned_data: struct from _eyetrack_cleaned.mat
%   logP_data: struct from parse_logP_file() with PTB times
%   raw_data: struct from _eyetrack.mat (for marker alignment if needed)
%
% Outputs:
%   pupil_time_ptb: pupil timestamps in PTB reference frame
%   alignment_diagnostics: struct with offset, confidence, method

pupil_time_ptb = [];
alignment_diagnostics = struct();
alignment_diagnostics.success = false;
alignment_diagnostics.method = 'unknown';
alignment_diagnostics.offset = NaN;
alignment_diagnostics.confidence = 'low';
alignment_diagnostics.pupil_time_range = [];
alignment_diagnostics.ptb_time_range = [];

% Extract pupil time vector from cleaned data
if isfield(cleaned_data, 'S') && isfield(cleaned_data.S, 'data')
    if isfield(cleaned_data.S.data, 'smp_timestamp')
        pupil_time = cleaned_data.S.data.smp_timestamp;
    elseif isfield(cleaned_data.S.data, 'time')
        pupil_time = cleaned_data.S.data.time;
    else
        fprintf('  ERROR: Cannot find pupil time vector in cleaned data\n');
        return;
    end
else
    fprintf('  ERROR: cleaned_data.S.data not found\n');
    return;
end

% Check if logP data is available
if ~logP_data.success || isempty(logP_data.trial_st)
    fprintf('  ERROR: logP data not available for timebase conversion\n');
    return;
end

% Determine timebase type
pupil_time_min = min(pupil_time);
pupil_time_max = max(pupil_time);
pupil_time_range = pupil_time_max - pupil_time_min;

% PTB/GetSecs times are typically large (millions of seconds since boot)
% Relative times start near 0
if pupil_time_min > 1e6
    % Likely already PTB/GetSecs absolute time
    fprintf('  Detected: Pupil time appears to be PTB/GetSecs absolute (min=%.3f)\n', pupil_time_min);
    pupil_time_ptb = pupil_time;
    alignment_diagnostics.method = 'already_ptb';
    alignment_diagnostics.offset = 0;
    alignment_diagnostics.confidence = 'high';
    alignment_diagnostics.success = true;
    alignment_diagnostics.pupil_time_range = [pupil_time_min, pupil_time_max];
    alignment_diagnostics.ptb_time_range = [min(logP_data.trial_st), max(logP_data.trial_st)];
    
    % Verify alignment by checking if pupil time covers logP trial windows
    logP_min = min(logP_data.trial_st);
    logP_max = max(logP_data.trial_st);
    window_start = -3.0;  % 3s before trial start
    window_end = 10.7;    % 10.7s after trial start
    
    if pupil_time_min <= (logP_min + window_start) && pupil_time_max >= (logP_max + window_end)
        fprintf('  Verified: Pupil time covers logP trial windows\n');
        alignment_diagnostics.confidence = 'high';
    else
        fprintf('  WARNING: Pupil time may not cover all logP trial windows\n');
        alignment_diagnostics.confidence = 'medium';
    end
    
    return;
end

% Relative timebase - need to align
fprintf('  Detected: Pupil time appears to be relative (min=%.3f)\n', pupil_time_min);

% Method 1: Try marker alignment if available
if isfield(raw_data, 'bufferData') && size(raw_data.bufferData, 2) >= 8
    marker_times = raw_data.bufferData(:, 1);
    marker_codes = raw_data.bufferData(:, 8);
    
    % Check if marker times are in PTB reference (large values)
    if min(marker_times) > 1e6
        fprintf('  Attempting marker-based alignment...\n');
        
        % Find transitions that might correspond to logP events
        % Look for blankST events (should occur ~30 times)
        if ~isempty(logP_data.blank_st) && length(logP_data.blank_st) >= 28
            % Try to align marker transitions to blankST
            % Find transitions that occur ~30 times
            transition_indices = find(diff(marker_codes) ~= 0) + 1;
            transition_times = marker_times(transition_indices);
            
            % Find a recurring transition pattern
            % For now, use a simple heuristic: find transitions that occur ~30 times
            % and align to blankST
            if length(transition_times) >= 28
                % Try aligning first marker transition to first blankST
                offset_candidate = logP_data.blank_st(1) - transition_times(1);
                
                % Verify alignment by checking if offset aligns multiple events
                aligned_marker = transition_times + offset_candidate;
                residuals = [];
                for i = 1:min(10, length(logP_data.blank_st))
                    [min_residual, idx] = min(abs(aligned_marker - logP_data.blank_st(i)));
                    residuals(end+1) = min_residual;
                end
                
                median_residual = median(residuals);
                if median_residual < 0.1  % 100ms tolerance
                    fprintf('  Marker alignment successful (median residual: %.3f s)\n', median_residual);
                    pupil_time_ptb = pupil_time + offset_candidate;
                    alignment_diagnostics.method = 'marker_alignment';
                    alignment_diagnostics.offset = offset_candidate;
                    alignment_diagnostics.confidence = 'high';
                    alignment_diagnostics.success = true;
                    alignment_diagnostics.pupil_time_range = [pupil_time_min, pupil_time_max];
                    alignment_diagnostics.ptb_time_range = [min(logP_data.trial_st), max(logP_data.trial_st)];
                    return;
                end
            end
        end
    end
end

% Method 2: Fit offset to minimize window_oob
fprintf('  Attempting offset fitting to minimize window_oob...\n');

% Define trial window
window_start = -3.0;  % 3s before trial start
window_end = 10.7;    % 10.7s after trial start

% Try different offsets and find one that minimizes out-of-bounds
logP_min = min(logP_data.trial_st);
logP_max = max(logP_data.trial_st);

% Search for offset that maximizes coverage
best_offset = 0;
best_coverage = 0;
best_window_oob = inf;

% Search range: from (logP_min - pupil_max) to (logP_max - pupil_min)
search_start = logP_min + window_start - pupil_time_max;
search_end = logP_max + window_end - pupil_time_min;
search_step = 0.1;  % 100ms steps

for test_offset = search_start:search_step:search_end
    pupil_time_test = pupil_time + test_offset;
    
    % Count how many trial windows are fully within pupil time range
    window_oob = 0;
    coverage = 0;
    
    for i = 1:length(logP_data.trial_st)
        trial_start_ptb = logP_data.trial_st(i);
        window_start_ptb = trial_start_ptb + window_start;
        window_end_ptb = trial_start_ptb + window_end;
        
        % Check if window is within pupil time range
        if window_start_ptb >= pupil_time_test(1) && window_end_ptb <= pupil_time_test(end)
            coverage = coverage + 1;
        else
            window_oob = window_oob + 1;
        end
    end
    
    if coverage > best_coverage || (coverage == best_coverage && window_oob < best_window_oob)
        best_offset = test_offset;
        best_coverage = coverage;
        best_window_oob = window_oob;
    end
end

if best_coverage >= 25  % At least 25/30 trials covered
    fprintf('  Offset fitting successful: offset=%.3f, coverage=%d/30, oob=%d\n', ...
        best_offset, best_coverage, best_window_oob);
    pupil_time_ptb = pupil_time + best_offset;
    alignment_diagnostics.method = 'offset_fitting';
    alignment_diagnostics.offset = best_offset;
    if best_coverage >= 28
        alignment_diagnostics.confidence = 'high';
    else
        alignment_diagnostics.confidence = 'medium';
    end
    alignment_diagnostics.success = true;
    alignment_diagnostics.pupil_time_range = [pupil_time_min + best_offset, pupil_time_max + best_offset];
    alignment_diagnostics.ptb_time_range = [min(logP_data.trial_st), max(logP_data.trial_st)];
    alignment_diagnostics.window_oob = best_window_oob;
    alignment_diagnostics.coverage = best_coverage;
else
    fprintf('  WARNING: Offset fitting failed (coverage=%d/30)\n', best_coverage);
    alignment_diagnostics.success = false;
end

end

