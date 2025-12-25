function [build_dir, BUILD_ID] = create_build_directory(base_output_dir)
% Create timestamped build directory for provenance isolation
% Returns: build_dir (full path) and BUILD_ID (string timestamp)

BUILD_ID = datestr(now, 'yyyymmdd_HHMMSS');
build_dir = fullfile(base_output_dir, ['build_' BUILD_ID]);

if ~exist(build_dir, 'dir')
    mkdir(build_dir);
    fprintf('Created build directory: %s\n', build_dir);
else
    fprintf('Build directory already exists: %s\n', build_dir);
end

end

