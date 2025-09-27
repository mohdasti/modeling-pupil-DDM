#!/usr/bin/env python3
"""
Downsample BAP178 eye tracking data to 250 Hz and add trial labels
"""

import pandas as pd
import numpy as np
import scipy.io
import os
import glob
from scipy import signal

def downsample_data(data, original_fs, target_fs):
    """
    Downsample data from original_fs to target_fs
    """
    if original_fs == target_fs:
        return data
    
    # Calculate downsampling factor
    downsample_factor = int(original_fs / target_fs)
    
    # Use scipy's decimate function for better quality
    downsampled_data = signal.decimate(data, downsample_factor, n=8)
    
    return downsampled_data

def create_trial_label(duration_index):
    """
    Create descriptive trial labels based on duration index
    """
    label_mapping = {
        1: "baseline",
        2: "fixation", 
        3: "squeeze",
        4: "blank",
        5: "response"
    }
    return label_mapping.get(duration_index, "unknown")

def process_and_downsample():
    """Process and downsample the eye tracking data"""
    
    # Define parameters
    base_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned'
    original_fs = 2000  # Original sampling rate
    target_fs = 250     # Target sampling rate
    
    # Load behavioral data
    beh_data_file = 'bap_trial_data_grip_type1.csv'
    beh_data = pd.read_csv(beh_data_file, low_memory=False)
    bap178_beh = beh_data[beh_data['sub'] == 'BAP178'].copy()
    
    # Select only the specified columns
    selected_columns = ['sub', 'mvc', 'ses', 'task', 'run', 'trial', 'stimLev', 
                       'isOddball', 'isStrength', 'iscorr', 'resp1', 'resp1RT', 
                       'resp2', 'resp2RT', 'auc_rel_mvc', 'resp1_isdiff']
    
    bap178_beh = bap178_beh[selected_columns].copy()
    
    print(f"Loaded behavioral data for BAP178: {len(bap178_beh)} trials")
    
    # Process each task
    task_mappings = {
        'Aoddball': {'task_name': 'ADT', 'beh_task': 'aud'},
        'Voddball': {'task_name': 'VDT', 'beh_task': 'vis'}
    }
    
    for file_pattern, task_info in task_mappings.items():
        task_name = task_info['task_name']
        beh_task = task_info['beh_task']
        
        print(f"\nProcessing {task_name} ({file_pattern})...")
        
        # Filter behavioral data for this task
        task_beh_data = bap178_beh[bap178_beh['task'] == beh_task].copy()
        print(f"  Behavioral trials: {len(task_beh_data)}")
        
        # Find all files for this task
        file_pattern_full = f'subjectBAP178_{file_pattern}_session*_run*_eyetrack_cleaned.mat'
        files = glob.glob(os.path.join(base_dir, file_pattern_full))
        
        if not files:
            print(f"  No files found for pattern: {file_pattern_full}")
            continue
        
        print(f"  Found {len(files)} eye tracking files")
        
        # Initialize combined data
        all_data = []
        
        # Process each run
        for run_idx, file_path in enumerate(sorted(files), 1):
            print(f"  Processing run {run_idx}: {os.path.basename(file_path)}")
            
            # Filter behavioral data for this run
            run_beh_data = task_beh_data[task_beh_data['run'] == run_idx].copy()
            
            if len(run_beh_data) == 0:
                print(f"    Warning: No behavioral data for run {run_idx}")
                continue
            
            # Load eye tracking data
            try:
                mat_data = scipy.io.loadmat(file_path, squeeze_me=False, struct_as_record=False)
                S = mat_data['S'][0, 0]
                output = S.output[0, 0]
                
                pupil_size = output.sample.flatten()
                pupil_time = output.smp_timestamp.flatten()
                
                print(f"    Original data: {len(pupil_size)} samples at {original_fs} Hz")
                
                # Downsample the data
                pupil_size_ds = downsample_data(pupil_size, original_fs, target_fs)
                pupil_time_ds = downsample_data(pupil_time, original_fs, target_fs)
                
                print(f"    Downsampled data: {len(pupil_size_ds)} samples at {target_fs} Hz")
                
                # Calculate approximate trial boundaries
                total_trials = len(run_beh_data)
                samples_per_trial_actual = len(pupil_size_ds) // total_trials
                
                print(f"    Estimated {samples_per_trial_actual} samples per trial")
                
                # Process each trial
                for trial_idx, trial_beh in run_beh_data.iterrows():
                    # Calculate trial boundaries
                    start_sample = int((trial_beh['trial'] - 1) * samples_per_trial_actual)
                    end_sample = int(trial_beh['trial'] * samples_per_trial_actual)
                    
                    # Ensure we don't go beyond the data
                    if end_sample > len(pupil_size_ds):
                        end_sample = len(pupil_size_ds)
                    
                    if start_sample >= len(pupil_size_ds):
                        print(f"      Warning: Trial {trial_beh['trial']} starts beyond data range")
                        continue
                    
                    # Extract trial data
                    trial_pupil_size = pupil_size_ds[start_sample:end_sample].copy()
                    trial_pupil_time = pupil_time_ds[start_sample:end_sample]
                    
                    # Convert 0 values to NaN
                    trial_pupil_size[trial_pupil_size == 0] = np.nan
                    
                    # Create trial parts based on relative timing
                    trial_duration = len(trial_pupil_size)
                    part1_end = int(trial_duration * 0.2)    # 0-20%: Pre-trial baseline
                    part2_end = int(trial_duration * 0.4)    # 20-40%: Pre-squeeze fixation
                    part3_end = int(trial_duration * 0.6)    # 40-60%: Squeeze period
                    part4_end = int(trial_duration * 0.8)    # 60-80%: Post-squeeze blank
                    part5_end = trial_duration               # 80-100%: Response period
                    
                    # Create duration index
                    duration_index = np.full(trial_duration, np.nan)
                    duration_index[:part1_end] = 1      # Pre-trial baseline
                    duration_index[part1_end:part2_end] = 2    # Pre-squeeze fixation
                    duration_index[part2_end:part3_end] = 3    # Squeeze period
                    duration_index[part3_end:part4_end] = 4    # Post-squeeze blank
                    duration_index[part4_end:part5_end] = 5    # Response period
                    
                    # Create trial labels
                    trial_labels = [create_trial_label(int(d)) if not np.isnan(d) else "unknown" for d in duration_index]
                    
                    # Create trial data with all behavioral columns
                    trial_data = pd.DataFrame({
                        'pupil': trial_pupil_size,
                        'time': trial_pupil_time,
                        'trial_index': trial_beh['trial'],
                        'run_index': run_idx,
                        'duration_index': duration_index,
                        'trial_label': trial_labels,
                        'sub': trial_beh['sub'],
                        'mvc': trial_beh['mvc'],
                        'ses': trial_beh['ses'],
                        'task': trial_beh['task'],
                        'run': trial_beh['run'],
                        'trial': trial_beh['trial'],
                        'stimLev': trial_beh['stimLev'],
                        'isOddball': trial_beh['isOddball'],
                        'isStrength': trial_beh['isStrength'],
                        'iscorr': trial_beh['iscorr'],
                        'resp1': trial_beh['resp1'],
                        'resp1RT': trial_beh['resp1RT'],
                        'resp2': trial_beh['resp2'],
                        'resp2RT': trial_beh['resp2RT'],
                        'auc_rel_mvc': trial_beh['auc_rel_mvc'],
                        'resp1_isdiff': trial_beh['resp1_isdiff']
                    })
                    
                    all_data.append(trial_data)
                
            except Exception as e:
                print(f"    Error processing {file_path}: {e}")
                continue
        
        # Combine all data
        if all_data:
            combined_data = pd.concat(all_data, ignore_index=True)
            
            # Save to CSV with the specified naming format
            output_filename = f'BAP178_{task_name}_DS{target_fs}.csv'
            combined_data.to_csv(output_filename, index=False)
            
            print(f"  Saved {output_filename}")
            print(f"  Total trials: {combined_data['trial_index'].nunique()}")
            print(f"  Total samples: {len(combined_data)}")
            
            # Print duration index distribution
            duration_counts = combined_data['duration_index'].value_counts().sort_index()
            print(f"  Duration index distribution:")
            for duration, count in duration_counts.items():
                if not pd.isna(duration):
                    percentage = (count / len(combined_data)) * 100
                    print(f"    Duration {int(duration)}: {count} samples ({percentage:.1f}%)")
            
            # Print trial label distribution
            label_counts = combined_data['trial_label'].value_counts()
            print(f"  Trial label distribution:")
            for label, count in label_counts.items():
                percentage = (count / len(combined_data)) * 100
                print(f"    {label}: {count} samples ({percentage:.1f}%)")
        else:
            print(f"  No data to save for {task_name}")

def main():
    """Main function"""
    print("Downsampling BAP178 eye tracking data to 250 Hz...")
    process_and_downsample()
    print("\nProcessing complete!")

if __name__ == "__main__":
    main() 