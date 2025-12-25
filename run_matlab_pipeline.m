% ============================================================================
% Run MATLAB Pipeline
% ============================================================================
% This script runs the BAP Pupillometry Pipeline from MATLAB
% ============================================================================

% Get the project root directory
project_root = '/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM';

% Change to MATLAB script directory
matlab_dir = fullfile(project_root, '01_data_preprocessing', 'matlab');
cd(matlab_dir);

% Display status
fprintf('============================================================================\n');
fprintf('RUNNING MATLAB PIPELINE\n');
fprintf('============================================================================\n');
fprintf('Working directory: %s\n', pwd);
fprintf('Script: BAP_Pupillometry_Pipeline.m\n');
fprintf('\n');

% Run the pipeline
try
    BAP_Pupillometry_Pipeline();
    fprintf('\n============================================================================\n');
    fprintf('MATLAB PIPELINE COMPLETE\n');
    fprintf('============================================================================\n');
catch ME
    fprintf('\n============================================================================\n');
    fprintf('ERROR: MATLAB PIPELINE FAILED\n');
    fprintf('============================================================================\n');
    fprintf('Error message: %s\n', ME.message);
    fprintf('Error location: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
    rethrow(ME);
end
