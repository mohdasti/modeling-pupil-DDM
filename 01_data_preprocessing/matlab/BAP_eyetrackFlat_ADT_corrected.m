clear

% Working directory should be BAP_cleaned
% This is intended for perceptual task (ADT and VDT)
% Define the base directory for cleaned eye tracking files
base_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned';

% Define subject and task lists
sub_list = ["178"];
file_list = ["Aoddball", "Voddball"]; % Aoddball = ADT, Voddball = VDT

% Parameters
time_before = 1.75; % seconds before trial start to include (used for baseline)
time2sample_converter = 2000; % Depends on sampling rate. 2000 for 2000Hz sampling rate
sample_before = time_before*time2sample_converter; % number of eyetracking samples before trial start to include (used for baseline)

% Load behavioral data
beh_data_file = 'bap_trial_data_grip_type1.csv';
beh_data = readtable(beh_data_file);
bap178_beh = beh_data(strcmp(beh_data.sub, 'BAP178'), :);

%%
% Process each subject and task
for sub_i = 1:length(sub_list)
    for file_i = 1:length(file_list)
        fprintf('Processing subject %s, task %s\n', sub_list(sub_i), file_list(file_i));
        
        % Determine task name for behavioral data filtering
        if strcmp(file_list(file_i), 'Aoddball')
            task_name = 'ADT';
            beh_task = 'aud';
        else
            task_name = 'VDT';
            beh_task = 'vis';
        end
        
        % Filter behavioral data for this task
        task_beh_data = bap178_beh(strcmp(bap178_beh.task, beh_task), :);
        
        % Find all files for this subject and task
        file_pattern = sprintf('subjectBAP%s_%s_session*_run*_eyetrack_cleaned.mat', sub_list(sub_i), file_list(file_i));
        file_info = dir(fullfile(base_dir, file_pattern));
        
        if isempty(file_info)
            fprintf('No files found for pattern: %s\n', file_pattern);
            continue;
        end
        
        % Initialize combined data structure
        all_data_flat = [];
        
        % Process each run
        for run_i = 1:length(file_info)
            fprintf('  Processing run %d: %s\n', run_i, file_info(run_i).name);
            
            % Filter behavioral data for this run
            run_beh_data = task_beh_data(task_beh_data.run == run_i, :);
            
            if isempty(run_beh_data)
                fprintf('  Warning: No behavioral data found for run %d\n', run_i);
                continue;
            end
            
            % Load eye tracking data
            eye_filename = fullfile(file_info(run_i).folder, file_info(run_i).name);
            VPixxData = load(eye_filename);
            
            % Extract pupil data
            pupilSize = VPixxData.S.output.sample;
            pupilTime = VPixxData.S.output.smp_timestamp;
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Eye tracking slices: to flat file using behavioral timing
            run_data_flat = [];
            
            for trial_i = 1:height(run_beh_data)
                trial_beh = run_beh_data(trial_i, :);
                
                % Get timing windows from behavioral data
                time_preblank = trial_beh.time_valid_preblank;
                time_prestim = trial_beh.time_valid_prestim;
                time_prerelax = trial_beh.time_valid_prerelax;
                time_preconf = trial_beh.time_valid_preconf;
                time_trial = trial_beh.time_valid_trial;
                
                % Calculate trial start time (approximate from behavioral data)
                % We'll use the trial duration to estimate timing
                trial_start_time = time_preblank - time_before; % Start 1.75s before preblank
                trial_end_time = time_preconf + 2.0; % End 2s after preconf
                
                % Create boolean array for entire trial and index pupilTime
                trial_bool = (pupilTime >= trial_start_time) & (pupilTime <= trial_end_time);
                trial_pupilTime = pupilTime(trial_bool, :);
                
                if sum(trial_bool) == 0
                    fprintf('    Warning: No eye tracking data found for trial %d\n', trial_i);
                    continue;
                end
                
                % Create boolean arrays for trial parts based on behavioral timing
                PreTrial_bool = (trial_pupilTime >= trial_start_time) & (trial_pupilTime < time_preblank);
                PreSqueezeFix_bool = (trial_pupilTime >= time_preblank) & (trial_pupilTime < time_prestim);
                Squeeze_bool = (trial_pupilTime >= time_prestim) & (trial_pupilTime < time_prerelax);
                PostSqueezeBlank_bool = (trial_pupilTime >= time_prerelax) & (trial_pupilTime < time_preconf);
                Response_bool = (trial_pupilTime >= time_preconf) & (trial_pupilTime <= trial_end_time);
                
                % Build duration_i, which is an index for each trial part
                duration_i = nan(size(trial_pupilTime)); % initialize with nans
                duration_i(PreTrial_bool, :) = 1;      % Pre-trial baseline
                duration_i(PreSqueezeFix_bool, :) = 2; % Pre-squeeze fixation
                duration_i(Squeeze_bool, :) = 3;       % Squeeze period
                duration_i(PostSqueezeBlank_bool, :) = 4; % Post-squeeze blank
                duration_i(Response_bool, :) = 5;      % Response period
                
                % Eyelink1000 pupil values of 0 should be converted to nans
                sliced_pupil = pupilSize(trial_bool, :);
                sliced_pupil(sliced_pupil == 0) = nan;
                
                % Create trial metadata
                trial_idx = repmat(trial_i, size(pupilSize(trial_bool, :)));
                run_idx = repmat(run_i, size(pupilSize(trial_bool, :)));
                
                % Add behavioral information
                trial_isStrength = repmat(trial_beh.isStrength, length(pupilSize(trial_bool, :)), 1);
                trial_isOddball = repmat(trial_beh.isOddball, length(pupilSize(trial_bool, :)), 1);
                trial_stimLev = repmat(trial_beh.stimLev, length(pupilSize(trial_bool, :)), 1);
                trial_resp1RT = repmat(trial_beh.resp1RT, length(pupilSize(trial_bool, :)), 1);
                trial_resp2RT = repmat(trial_beh.resp2RT, length(pupilSize(trial_bool, :)), 1);
                
                % Combine trial data
                trial_data_flat = [sliced_pupil, trial_pupilTime, trial_idx, run_idx, trial_isStrength, trial_isOddball, trial_stimLev, trial_resp1RT, trial_resp2RT, duration_i];
                run_data_flat = [run_data_flat; trial_data_flat];
            end
            
            % Add run data to all data
            all_data_flat = [all_data_flat; run_data_flat];
        end
        
        % Create final table and save
        if ~isempty(all_data_flat)
            data_flat_t = array2table(all_data_flat, "VariableNames", ["pupil", "time", "trial_index", "run_index", "isStrength", "isOddball", "stimLev", "resp1RT", "resp2RT", "duration_index"]);
            output_filename = sprintf('sub-%s_%s_eye_flat.csv', sub_list(sub_i), task_name);
            writetable(data_flat_t, output_filename);
            fprintf('Saved %s with %d rows\n', output_filename, height(data_flat_t));
            
            % Print summary statistics
            fprintf('Summary for %s:\n', task_name);
            fprintf('  Total trials: %d\n', length(unique(data_flat_t.trial_index)));
            fprintf('  Total samples: %d\n', height(data_flat_t));
            fprintf('  Duration index distribution:\n');
            duration_counts = tabulate(data_flat_t.duration_index);
            for i = 1:size(duration_counts, 1)
                if ~isnan(duration_counts(i, 1))
                    fprintf('    Duration %d: %d samples (%.1f%%)\n', duration_counts(i, 1), duration_counts(i, 2), duration_counts(i, 3));
                end
            end
        else
            fprintf('No data to save for subject %s, task %s\n', sub_list(sub_i), file_list(file_i));
        end
    end
end

fprintf('Processing complete!\n'); 