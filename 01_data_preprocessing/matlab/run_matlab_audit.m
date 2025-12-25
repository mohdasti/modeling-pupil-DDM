function run_matlab_audit()
% Main audit script - runs all audit checks and generates sign-off report

fprintf('========================================\n');
fprintf('MATLAB PIPELINE AUDIT\n');
fprintf('========================================\n\n');

%% Configuration
CONFIG = struct();
CONFIG.cleaned_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned';
CONFIG.raw_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data';
CONFIG.output_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed';

% Use most recent build directory if available
build_dirs = dir(fullfile(CONFIG.output_dir, 'build_*'));
if ~isempty(build_dirs)
    [~, idx] = sort([build_dirs.datenum], 'descend');
    latest_build = build_dirs(idx(1)).name;
    CONFIG.build_dir = fullfile(CONFIG.output_dir, latest_build);
    CONFIG.qc_dir = fullfile(CONFIG.build_dir, 'qc_matlab');
    fprintf('Using build directory: %s\n', latest_build);
else
    CONFIG.qc_dir = fullfile(CONFIG.output_dir, 'qc_matlab');
    fprintf('No build directory found, using base output directory\n');
end

if ~exist(CONFIG.qc_dir, 'dir')
    mkdir(CONFIG.qc_dir);
end

%% Run all audits
fprintf('\n');

% A) Discovery audit
audit_discovery(CONFIG);

% A.5) Parse failure audit (ensure all failures logged)
audit_parse_failures(CONFIG);

% B) QC cross-check
audit_qc_crosscheck(CONFIG);

% C) logP integrity
audit_logp_integrity(CONFIG);

% D) Timebase and ITI
audit_timebase_iti(CONFIG);

% E) Regenerate QC artifacts
audit_regenerate_qc(CONFIG);

% F) Generate sign-off report
generate_signoff_report(CONFIG);

fprintf('\n========================================\n');
fprintf('AUDIT COMPLETE\n');
fprintf('========================================\n');
fprintf('\nCheck: %s/MATLAB_PIPELINE_SIGNOFF.md\n', CONFIG.qc_dir);

end

