#!/usr/bin/env python3
"""
Detailed script to examine the structure of BAP eye tracking .mat files
and find timing information.
"""

import scipy.io
import os
import glob
import numpy as np

def examine_mat_file_detailed(filepath):
    """Examine the detailed structure of a .mat file"""
    print(f"\n{'='*60}")
    print(f"Detailed examination: {os.path.basename(filepath)}")
    print(f"{'='*60}")
    
    try:
        # Load the .mat file
        mat_data = scipy.io.loadmat(filepath, squeeze_me=True, struct_as_record=False)
        
        # Examine the S structure (main data structure)
        if 'S' in mat_data:
            S = mat_data['S']
            print(f"S structure type: {type(S)}")
            
            # Print all S attributes
            print("\nAll S attributes:")
            for attr in dir(S):
                if not attr.startswith('_'):
                    attr_value = getattr(S, attr)
                    print(f"  {attr}: {type(attr_value)}")
                    
                    # If it's a structured array, examine its contents
                    if hasattr(attr_value, 'dtype') and attr_value.dtype.names:
                        print(f"    Structured array with fields: {attr_value.dtype.names}")
                        for field in attr_value.dtype.names:
                            field_data = attr_value[field]
                            if hasattr(field_data, 'shape'):
                                print(f"      {field}: shape {field_data.shape}, type {field_data.dtype}")
                            else:
                                print(f"      {field}: {type(field_data)}")
            
            # Check if there's a data field that might contain events
            if hasattr(S, 'data'):
                data = S.data
                print(f"\nData structure type: {type(data)}")
                if hasattr(data, 'dtype') and data.dtype.names:
                    print(f"Data fields: {data.dtype.names}")
                    for field in data.dtype.names:
                        field_data = data[field]
                        if hasattr(field_data, 'shape'):
                            print(f"  {field}: shape {field_data.shape}, type {field_data.dtype}")
                        else:
                            print(f"  {field}: {type(field_data)}")
            
            # Check for Events in different possible locations
            print(f"\nSearching for Events structure...")
            
            # Check if Events is directly in S
            if hasattr(S, 'Events'):
                print("Found Events directly in S")
                events = S.Events
                examine_events_structure(events)
            
            # Check if Events is in data
            elif hasattr(S, 'data') and hasattr(S.data, 'Events'):
                print("Found Events in S.data")
                events = S.data.Events
                examine_events_structure(events)
            
            # Check all attributes for any structure that might contain timing
            print(f"\nSearching for timing-related structures...")
            for attr in dir(S):
                if not attr.startswith('_'):
                    attr_value = getattr(S, attr)
                    if hasattr(attr_value, 'dtype') and attr_value.dtype.names:
                        # Check if this structure has timing-related fields
                        timing_fields = [field for field in attr_value.dtype.names 
                                       if any(timing_word in field.lower() 
                                             for timing_word in ['time', 'event', 'message', 'trial'])]
                        if timing_fields:
                            print(f"  {attr} has timing-related fields: {timing_fields}")
                            for field in timing_fields:
                                field_data = attr_value[field]
                                if hasattr(field_data, 'shape'):
                                    print(f"    {field}: shape {field_data.shape}")
                                    if field_data.size < 20:  # Show small arrays
                                        print(f"      Values: {field_data}")
                                else:
                                    print(f"    {field}: {field_data}")
        
        return True
        
    except Exception as e:
        print(f"Error examining file: {e}")
        import traceback
        traceback.print_exc()
        return False

def examine_events_structure(events):
    """Examine the Events structure"""
    print(f"Events structure type: {type(events)}")
    
    if hasattr(events, 'dtype') and events.dtype.names:
        print(f"Events fields: {events.dtype.names}")
        for field in events.dtype.names:
            field_data = events[field]
            if hasattr(field_data, 'shape'):
                print(f"  {field}: shape {field_data.shape}, type {field_data.dtype}")
                if field_data.size < 50:  # Show small arrays
                    print(f"    Values: {field_data}")
            else:
                print(f"  {field}: {field_data}")
    
    elif hasattr(events, '__dict__'):
        print("Events attributes:")
        for attr in dir(events):
            if not attr.startswith('_'):
                attr_value = getattr(events, attr)
                print(f"  {attr}: {type(attr_value)}")
                if hasattr(attr_value, 'shape'):
                    print(f"    Shape: {attr_value.shape}")
                    if attr_value.size < 20:
                        print(f"    Values: {attr_value}")

def main():
    """Main function to examine .mat files in detail"""
    base_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned'
    
    # Find all .mat files
    mat_files = glob.glob(os.path.join(base_dir, '*.mat'))
    
    # Examine one ADT file in detail
    adt_files = [f for f in mat_files if 'Aoddball' in os.path.basename(f)]
    if adt_files:
        examine_mat_file_detailed(adt_files[0])

if __name__ == "__main__":
    main() 