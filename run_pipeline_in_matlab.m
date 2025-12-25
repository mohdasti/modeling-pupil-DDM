% Script to run the BAP Pupillometry Pipeline from within MATLAB
% Run this script from MATLAB's command window

fprintf('=== Running BAP Pupillometry Pipeline ===\n');
fprintf('Current directory: %s\n', pwd);

% Change to the pipeline directory
cd('01_data_preprocessing/matlab');

% Run the pipeline
try
    BAP_Pupillometry_Pipeline();
    fprintf('\n=== Pipeline completed successfully ===\n');
catch ME
    fprintf('\n=== ERROR occurred ===\n');
    fprintf('Error message: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('Error location: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
    end
    rethrow(ME);
end



