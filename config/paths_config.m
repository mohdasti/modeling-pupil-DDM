function CONFIG = paths_config()
% MATLAB Paths Configuration
% 
% This file contains user-specific paths for the MATLAB pipeline.
% Edit the paths below to match your system.

CONFIG = struct();

% OPTION: Use absolute paths (for data outside repo)
% Based on D_paths.md documentation, these are the actual data locations
CONFIG.cleaned_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned';
CONFIG.raw_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/data';
CONFIG.output_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed';

% Validate paths exist (warn if not, but don't error - user may need to create)
if ~exist(CONFIG.cleaned_dir, 'dir')
    warning('CONFIG.cleaned_dir does not exist: %s', CONFIG.cleaned_dir);
end
if ~exist(CONFIG.raw_dir, 'dir')
    warning('CONFIG.raw_dir does not exist: %s', CONFIG.raw_dir);
end
% output_dir will be created by pipeline if missing, so no check needed

end

