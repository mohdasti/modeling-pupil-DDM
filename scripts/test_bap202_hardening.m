% ============================================================================
% TEST BAP202 HARDENING: Verify logP-driven segmentation works
% ============================================================================
% This script tests the hardening implementation on BAP202 session2 run4

fprintf('=== TESTING BAP202 HARDENING ===\n\n');

%% Configuration
cleaned_file = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned/subjectBAP202_Voddball_session2_run4_12_20_13_11_eyetrack_cleaned.mat';
raw_file = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data/sub-BAP202/ses-2/InsideScanner/subjectBAP202_Voddball_session2_run4_12_20_13_11_eyetrack.mat';
logP_file = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data/sub-BAP202/ses-2/InsideScanner/subjectBAP202_Voddball_session2_run4_12_20_13_11_logP.txt';
output_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/qc_matlab';

%% Test 1: Parse logP
fprintf('TEST 1: Parsing logP file...\n');
logP_data = parse_logP_file(logP_file);
if logP_data.success
    fprintf('  ✓ logP parsed: %d trials\n', logP_data.n_trials);
    fprintf('  TrialST range: %.3f to %.3f\n', min(logP_data.trial_st), max(logP_data.trial_st));
else
    fprintf('  ✗ logP parsing failed\n');
    return;
end

%% Test 2: Timebase conversion
fprintf('\nTEST 2: Timebase conversion...\n');
cleaned_data = load(cleaned_file);
raw_data = load(raw_file);

[pupil_time_ptb, alignment_diagnostics] = convert_timebase(cleaned_data, logP_data, raw_data);
if alignment_diagnostics.success
    fprintf('  ✓ Timebase conversion successful\n');
    fprintf('    Method: %s\n', alignment_diagnostics.method);
    fprintf('    Offset: %.3f s\n', alignment_diagnostics.offset);
    fprintf('    Confidence: %s\n', alignment_diagnostics.confidence);
    fprintf('    Pupil time range (PTB): %.3f to %.3f\n', ...
        alignment_diagnostics.pupil_time_range(1), alignment_diagnostics.pupil_time_range(2));
    fprintf('    logP time range: %.3f to %.3f\n', ...
        alignment_diagnostics.ptb_time_range(1), alignment_diagnostics.ptb_time_range(2));
else
    fprintf('  ✗ Timebase conversion failed\n');
    return;
end

%% Test 3: Check window coverage
fprintf('\nTEST 3: Checking trial window coverage...\n');
window_start = -3.0;
window_end = 10.7;
window_oob = 0;
coverage = 0;

for i = 1:length(logP_data.trial_st)
    trial_start_ptb = logP_data.trial_st(i);
    window_start_ptb = trial_start_ptb + window_start;
    window_end_ptb = trial_start_ptb + window_end;
    
    if window_start_ptb >= pupil_time_ptb(1) && window_end_ptb <= pupil_time_ptb(end)
        coverage = coverage + 1;
    else
        window_oob = window_oob + 1;
    end
end

fprintf('  Coverage: %d/%d trials fully within pupil time range\n', coverage, length(logP_data.trial_st));
fprintf('  Window OOB: %d trials\n', window_oob);

%% Test 4: Run full pipeline on BAP202
fprintf('\nTEST 4: Running full pipeline on BAP202...\n');
fprintf('  (This will process all BAP202 runs)\n');

% Change to pipeline directory and run
cd('/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM/01_data_preprocessing/matlab');
BAP_Pupillometry_Pipeline();

%% Test 5: Check QC outputs
fprintf('\nTEST 5: Checking QC outputs...\n');
qc_file = fullfile(output_dir, 'qc_matlab_run_trial_counts.csv');
if exist(qc_file, 'file')
    qc_data = readtable(qc_file);
    bap202_runs = qc_data(strcmp(qc_data.subject, 'BAP202'), :);
    if ~isempty(bap202_runs)
        fprintf('  ✓ Found QC data for BAP202:\n');
        for i = 1:height(bap202_runs)
            fprintf('    Run %d: %d trials extracted, source=%s, oob=%d\n', ...
                bap202_runs.run(i), bap202_runs.n_trials_extracted(i), ...
                bap202_runs.segmentation_source{i}, bap202_runs.n_window_oob(i));
        end
        
        % Check run 4 specifically
        run4 = bap202_runs(bap202_runs.run == 4, :);
        if ~isempty(run4)
            fprintf('\n  BAP202 Run 4 Results:\n');
            fprintf('    n_log_trials: %d\n', run4.n_log_trials);
            fprintf('    n_trials_extracted: %d\n', run4.n_trials_extracted);
            fprintf('    segmentation_source: %s\n', run4.segmentation_source{1});
            fprintf('    n_window_oob: %d\n', run4.n_window_oob);
            fprintf('    timebase_method: %s\n', run4.timebase_method{1});
            fprintf('    timebase_offset: %.3f\n', run4.timebase_offset);
        end
    else
        fprintf('  ✗ No BAP202 data found in QC file\n');
    end
else
    fprintf('  ✗ QC file not found: %s\n', qc_file);
end

fprintf('\n=== TESTING COMPLETE ===\n');

