#!/usr/bin/env python3
"""
Analyze behavioral data for subject BAP178
"""

import pandas as pd
import numpy as np
import os

def analyze_behavioral_data():
    """Analyze the behavioral data for subject BAP178"""
    
    # Load the behavioral data
    csv_file = 'bap_trial_data_grip_type1.csv'
    df = pd.read_csv(csv_file)
    
    # Filter for subject BAP178
    bap178_data = df[df['sub'] == 'BAP178'].copy()
    
    print(f"Total trials for BAP178: {len(bap178_data)}")
    
    # Check task distribution
    task_counts = bap178_data['task'].value_counts()
    print(f"\nTask distribution:")
    for task, count in task_counts.items():
        print(f"  {task}: {count} trials")
    
    # Check session distribution
    session_counts = bap178_data['ses'].value_counts()
    print(f"\nSession distribution:")
    for session, count in session_counts.items():
        print(f"  Session {session}: {count} trials")
    
    # Check run distribution
    run_counts = bap178_data['run'].value_counts()
    print(f"\nRun distribution:")
    for run, count in run_counts.items():
        print(f"  Run {run}: {count} trials")
    
    # Examine timing-related columns
    timing_columns = [col for col in bap178_data.columns if 'time' in col.lower()]
    print(f"\nTiming-related columns ({len(timing_columns)}):")
    for col in timing_columns:
        print(f"  {col}")
    
    # Show sample data for one task
    print(f"\nSample data for auditory task (first 5 trials):")
    aud_data = bap178_data[bap178_data['task'] == 'aud'].head()
    print(aud_data[['sub', 'ses', 'task', 'run', 'trial', 'stimLev', 'isOddball', 'isStrength', 'resp1RT', 'resp2RT']].to_string())
    
    print(f"\nSample data for visual task (first 5 trials):")
    vis_data = bap178_data[bap178_data['task'] == 'vis'].head()
    print(vis_data[['sub', 'ses', 'task', 'run', 'trial', 'stimLev', 'isOddball', 'isStrength', 'resp1RT', 'resp2RT']].to_string())
    
    # Check for timing information in the behavioral data
    print(f"\nChecking for timing information...")
    
    # Look for columns that might contain trial timing
    trial_timing_cols = [col for col in bap178_data.columns if any(word in col.lower() for word in ['start', 'end', 'duration', 'onset'])]
    print(f"Potential trial timing columns ({len(trial_timing_cols)}):")
    for col in trial_timing_cols:
        print(f"  {col}")
    
    # Check if there are any pupil diameter columns that might indicate timing windows
    pupil_cols = [col for col in bap178_data.columns if 'pupil' in col.lower()]
    print(f"\nPupil diameter columns ({len(pupil_cols)}):")
    for col in pupil_cols:
        print(f"  {col}")
    
    # Show the structure of timing windows
    timing_window_cols = [col for col in bap178_data.columns if any(word in col.lower() for word in ['preblank', 'prestim', 'prerelax', 'preconf', 'trial'])]
    print(f"\nTiming window columns ({len(timing_window_cols)}):")
    for col in timing_window_cols:
        if 'time_valid' in col:
            print(f"  {col}")
    
    # Check if there are any filepath references that might help with timing
    print(f"\nFilepath structure:")
    sample_filepath = bap178_data['filepath'].iloc[0]
    print(f"  Sample filepath: {sample_filepath}")
    
    return bap178_data

def main():
    """Main function"""
    bap178_data = analyze_behavioral_data()
    
    # Save filtered data for BAP178
    bap178_data.to_csv('BAP178_behavioral_data.csv', index=False)
    print(f"\nSaved BAP178 behavioral data to BAP178_behavioral_data.csv")

if __name__ == "__main__":
    main() 