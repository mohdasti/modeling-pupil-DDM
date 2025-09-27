#!/usr/bin/env python3
"""
Script to examine the structure of BAP eye tracking .mat files
and verify labels and timing information.
"""

import scipy.io
import os
import glob
import numpy as np
import pandas as pd

def examine_mat_file(filepath):
    """Examine the structure of a .mat file"""
    print(f"\n{'='*60}")
    print(f"Examining: {os.path.basename(filepath)}")
    print(f"{'='*60}")
    
    try:
        # Load the .mat file
        mat_data = scipy.io.loadmat(filepath, squeeze_me=True, struct_as_record=False)
        
        # Print top-level structure
        print("Top-level keys:")
        for key in mat_data.keys():
            if not key.startswith('__'):
                print(f"  {key}")
        
        # Examine the S structure (main data structure)
        if 'S' in mat_data:
            S = mat_data['S']
            print(f"\nS structure type: {type(S)}")
            
            # Print S attributes
            if hasattr(S, '__dict__'):
                print("S attributes:")
                for attr in dir(S):
                    if not attr.startswith('_'):
                        print(f"  {attr}")
            
            # Examine output data
            if hasattr(S, 'output'):
                output = S.output
                print(f"\nOutput structure type: {type(output)}")
                if hasattr(output, '__dict__'):
                    print("Output attributes:")
                    for attr in dir(output):
                        if not attr.startswith('_'):
                            print(f"  {attr}")
                
                # Check sample data
                if hasattr(output, 'sample'):
                    sample = output.sample
                    print(f"\nSample data shape: {sample.shape if hasattr(sample, 'shape') else 'scalar'}")
                    if hasattr(sample, 'shape') and len(sample.shape) > 0:
                        print(f"Sample data type: {sample.dtype}")
                        print(f"Sample data range: {np.nanmin(sample)} to {np.nanmax(sample)}")
                        print(f"Number of non-zero samples: {np.sum(sample != 0)}")
                        print(f"Number of zero samples: {np.sum(sample == 0)}")
                
                # Check timestamp data
                if hasattr(output, 'smp_timestamp'):
                    timestamp = output.smp_timestamp
                    print(f"\nTimestamp data shape: {timestamp.shape if hasattr(timestamp, 'shape') else 'scalar'}")
                    if hasattr(timestamp, 'shape') and len(timestamp.shape) > 0:
                        print(f"Timestamp data type: {timestamp.dtype}")
                        print(f"Timestamp range: {np.min(timestamp)} to {np.max(timestamp)}")
            
            # Examine Events data
            if hasattr(S, 'Events'):
                events = S.Events
                print(f"\nEvents structure type: {type(events)}")
                if hasattr(events, '__dict__'):
                    print("Events attributes:")
                    for attr in dir(events):
                        if not attr.startswith('_'):
                            print(f"  {attr}")
                
                # Examine Messages
                if hasattr(events, 'Messages'):
                    messages = events.Messages
                    print(f"\nMessages structure type: {type(messages)}")
                    if hasattr(messages, '__dict__'):
                        print("Messages attributes:")
                        for attr in dir(messages):
                            if not attr.startswith('_'):
                                print(f"  {attr}")
                    
                    # Check timing information
                    if hasattr(messages, 'time') and hasattr(messages, 'info'):
                        time_data = messages.time
                        info_data = messages.info
                        
                        print(f"\nMessages time shape: {time_data.shape if hasattr(time_data, 'shape') else 'scalar'}")
                        print(f"Messages info shape: {info_data.shape if hasattr(info_data, 'shape') else 'scalar'}")
                        
                        # Convert to arrays if they're not already
                        if not hasattr(time_data, 'shape'):
                            time_data = np.array([time_data])
                        if not hasattr(info_data, 'shape'):
                            info_data = np.array([info_data])
                        
                        # Find unique message types
                        unique_messages = set()
                        for msg in info_data:
                            if isinstance(msg, str):
                                unique_messages.add(msg)
                        
                        print(f"\nUnique message types ({len(unique_messages)}):")
                        for msg in sorted(unique_messages):
                            count = sum(1 for m in info_data if m == msg)
                            print(f"  {msg}: {count} occurrences")
                        
                        # Check for specific timing messages
                        timing_messages = [
                            'TrialStartTime', 'StimulusStartTime', 'BlankStartTime',
                            'FixationStartTime', 'SoundStartTime', 'SoundEndTime',
                            'RelaxEndTime', 'Resp1StartTime', 'Resp1EndTime',
                            'Resp2StartTime', 'Resp2EndTime', 'EndofTrialTime'
                        ]
                        
                        print(f"\nTiming message analysis:")
                        for timing_msg in timing_messages:
                            count = sum(1 for msg in info_data if timing_msg in str(msg))
                            if count > 0:
                                print(f"  {timing_msg}: {count} occurrences")
        
        return True
        
    except Exception as e:
        print(f"Error examining file: {e}")
        return False

def main():
    """Main function to examine all .mat files"""
    base_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned'
    
    # Find all .mat files
    mat_files = glob.glob(os.path.join(base_dir, '*.mat'))
    
    print(f"Found {len(mat_files)} .mat files")
    
    # Group files by task type
    adt_files = [f for f in mat_files if 'Aoddball' in os.path.basename(f)]
    vdt_files = [f for f in mat_files if 'Voddball' in os.path.basename(f)]
    
    print(f"\nADT files (Aoddball): {len(adt_files)}")
    for f in sorted(adt_files):
        print(f"  {os.path.basename(f)}")
    
    print(f"\nVDT files (Voddball): {len(vdt_files)}")
    for f in sorted(vdt_files):
        print(f"  {os.path.basename(f)}")
    
    # Examine one file from each task type
    if adt_files:
        print(f"\n{'='*80}")
        print("EXAMINING ADT FILE")
        print(f"{'='*80}")
        examine_mat_file(adt_files[0])
    
    if vdt_files:
        print(f"\n{'='*80}")
        print("EXAMINING VDT FILE")
        print(f"{'='*80}")
        examine_mat_file(vdt_files[0])

if __name__ == "__main__":
    main() 