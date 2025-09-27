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

%%
% Process each subject and task
for sub_i = 1:length(sub_list)
    for file_i = 1:length(file_list)
        fprintf('Processing subject %s, task %s\n', sub_list(sub_i), file_list(file_i));
        
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
            
            % Load eye tracking data
            eye_filename = fullfile(file_info(run_i).folder, file_info(run_i).name);
            VPixxData = load(eye_filename);
            
            % Extract pupil data
            pupilSize = VPixxData.S.output.sample;
            pupilTime = VPixxData.S.output.smp_timestamp;
            
            %%%%%%%%%%%%%%%%%%%%%%%%
            % Initialize timing arrays. EL suffix means the Timestamp is from Eyelink
            TrialStartTimeEL = [];
            StimulusStartTimeEL = [];
            BlankStartTimeEL = [];
            FixationStartTimeEL = [];
            SoundStartTimeEL = [];
            SoundEndTimeEL = [];
            RelaxEndTimeEL = [];
            Resp1StartTimeEL = [];
            Resp1EndTimeEL = [];
            Resp2StartTimeEL = [];
            Resp2EndTimeEL = [];
            EndofTrialTimeEL = [];
            
            % Create timing arrays from event messages
            for i = 1:length(VPixxData.S.Events.Messages.time)
                if contains(VPixxData.S.Events.Messages.info(i), 'TrialStartTime')
                    TrialStartTimeEL(end+1) = VPixxData.S.Events.Messages.time(i);
                end
                if contains(VPixxData.S.Events.Messages.info(i), 'StimulusStartTime')
                    StimulusStartTimeEL(end+1) = VPixxData.S.Events.Messages.time(i);
                end
                if contains(VPixxData.S.Events.Messages.info(i), 'BlankStartTime')
                    BlankStartTimeEL(end+1) = VPixxData.S.Events.Messages.time(i);
                end
                if contains(VPixxData.S.Events.Messages.info(i), 'FixationStartTime')
                    FixationStartTimeEL(end+1) = VPixxData.S.Events.Messages.time(i);
                end
                if contains(VPixxData.S.Events.Messages.info(i), 'SoundStartTime')
                    SoundStartTimeEL(end+1) = VPixxData.S.Events.Messages.time(i);
                end
                if contains(VPixxData.S.Events.Messages.info(i), 'SoundEndTime')
                    SoundEndTimeEL(end+1) = VPixxData.S.Events.Messages.time(i);
                end
                if contains(VPixxData.S.Events.Messages.info(i), 'RelaxEndTime')
                    RelaxEndTimeEL(end+1) = VPixxData.S.Events.Messages.time(i);
                end
                if contains(VPixxData.S.Events.Messages.info(i), 'Resp1StartTime')
                    Resp1StartTimeEL(end+1) = VPixxData.S.Events.Messages.time(i);
                end
                if contains(VPixxData.S.Events.Messages.info(i), 'Resp1EndTime')
                    Resp1EndTimeEL(end+1) = VPixxData.S.Events.Messages.time(i);
                end
                if contains(VPixxData.S.Events.Messages.info(i), 'Resp2StartTime')
                    Resp2StartTimeEL(end+1) = VPixxData.S.Events.Messages.time(i);
                end
                if contains(VPixxData.S.Events.Messages.info(i), 'Resp2EndTime')
                    Resp2EndTimeEL(end+1) = VPixxData.S.Events.Messages.time(i);
                end
                if contains(VPixxData.S.Events.Messages.info(i), 'EndofTrialTime')
                    EndofTrialTimeEL(end+1) = VPixxData.S.Events.Messages.time(i);
                end
            end
            
            % Check if we have timing data
            if isempty(TrialStartTimeEL) || isempty(EndofTrialTimeEL)
                fprintf('  Warning: No timing data found in %s\n', file_info(run_i).name);
                continue;
            end
            
            fprintf('  Found %d trials in this run\n', length(TrialStartTimeEL));
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Eye tracking slices: to flat file
            run_data_flat = [];
            for trial_i = 1:length(TrialStartTimeEL)
                % Create boolean array for entire trial and index pupilTime
                trial_bool = (pupilTime > TrialStartTimeEL(trial_i) - time_before) & (pupilTime <= EndofTrialTimeEL(trial_i));
                trial_pupilTime = pupilTime(trial_bool, :);
                
                % Create boolean arrays for trial parts
                PreTrial_bool = (trial_pupilTime > TrialStartTimeEL(trial_i) - time_before) & (trial_pupilTime <= TrialStartTimeEL(trial_i));
                PreSqueezeFix_bool = (trial_pupilTime > TrialStartTimeEL(trial_i)) & (trial_pupilTime <= StimulusStartTimeEL(trial_i));
                Squeeze_bool = (trial_pupilTime > StimulusStartTimeEL(trial_i)) & (trial_pupilTime <= BlankStartTimeEL(trial_i));
                PostSqueezeBlank_bool = (trial_pupilTime > BlankStartTimeEL(trial_i)) & (trial_pupilTime <= FixationStartTimeEL(trial_i));
                PreSoundFix_bool = (trial_pupilTime > FixationStartTimeEL(trial_i)) & (trial_pupilTime <= SoundStartTimeEL(trial_i));
                Sound_bool = (trial_pupilTime > SoundStartTimeEL(trial_i)) & (trial_pupilTime <= SoundEndTimeEL(trial_i));
                PostSoundFix_bool = (trial_pupilTime > SoundEndTimeEL(trial_i)) & (trial_pupilTime <= RelaxEndTimeEL(trial_i));
                Response_bool = (trial_pupilTime > Resp1StartTimeEL(trial_i)) & (trial_pupilTime <= Resp1EndTimeEL(trial_i));
                Confidence_bool = (trial_pupilTime > Resp2StartTimeEL(trial_i)) & (trial_pupilTime <= Resp2EndTimeEL(trial_i));
                
                % Build duration_i, which is an index for each trial part
                duration_i = nan(size(trial_pupilTime)); % initialize with nans
                duration_i(PreTrial_bool, :) = 1;
                duration_i(PreSqueezeFix_bool, :) = 2;
                duration_i(Squeeze_bool, :) = 3;
                duration_i(PostSqueezeBlank_bool, :) = 4;
                duration_i(PreSoundFix_bool, :) = 5;
                duration_i(Sound_bool, :) = 6;
                duration_i(PostSoundFix_bool, :) = 7;
                duration_i(Response_bool, :) = 8;
                duration_i(Confidence_bool, :) = 9;
                
                % Eyelink1000 pupil values of 0 should be converted to nans
                sliced_pupil = pupilSize(trial_bool, :);
                sliced_pupil(sliced_pupil == 0) = nan;
                
                % Create trial metadata
                trial_idx = repmat(trial_i, size(pupilSize(trial_bool, :)));
                run_idx = repmat(run_i, size(pupilSize(trial_bool, :)));
                
                % For now, create placeholder for behavioral data (will be added later)
                trial_hiGrip = nan(size(pupilSize(trial_bool, :))); % Placeholder
                
                % Combine trial data
                trial_data_flat = [sliced_pupil, trial_pupilTime, trial_idx, run_idx, trial_hiGrip, duration_i];
                run_data_flat = [run_data_flat; trial_data_flat];
            end
            
            % Add run data to all data
            all_data_flat = [all_data_flat; run_data_flat];
        end
        
        % Create final table and save
        if ~isempty(all_data_flat)
            % Determine task name for output
            if strcmp(file_list(file_i), 'Aoddball')
                task_name = 'ADT';
            else
                task_name = 'VDT';
            end
            
            data_flat_t = array2table(all_data_flat, "VariableNames", ["pupil", "time", "trial_index", "run_index", "hiGrip", "duration_index"]);
            output_filename = sprintf('sub-%s_%s_eye_flat.csv', sub_list(sub_i), task_name);
            writetable(data_flat_t, output_filename);
            fprintf('Saved %s with %d rows\n', output_filename, height(data_flat_t));
        else
            fprintf('No data to save for subject %s, task %s\n', sub_list(sub_i), file_list(file_i));
        end
    end
end

fprintf('Processing complete!\n');
