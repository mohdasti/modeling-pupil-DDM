#!/usr/bin/env python3
"""
Check all fields in the S structure for timing information
"""

import scipy.io
import os
import glob

def check_all_fields(filepath):
    """Check all fields in the S structure"""
    print(f"Checking all fields: {os.path.basename(filepath)}")
    
    try:
        mat_data = scipy.io.loadmat(filepath, squeeze_me=False, struct_as_record=False)
        
        if 'S' in mat_data:
            S = mat_data['S'][0, 0]
            
            # Check all fields in S
            for attr in dir(S):
                if not attr.startswith('_'):
                    attr_value = getattr(S, attr)
                    print(f"\n{attr}: {type(attr_value)}")
                    
                    # If it's a structured array, check its fields
                    if hasattr(attr_value, 'dtype') and attr_value.dtype.names:
                        print(f"  Fields: {attr_value.dtype.names}")
                        
                        # Look for timing-related fields
                        timing_fields = [field for field in attr_value.dtype.names 
                                       if any(word in field.lower() 
                                             for word in ['time', 'event', 'message', 'trial'])]
                        if timing_fields:
                            print(f"  Timing-related fields found: {timing_fields}")
                    
                    # If it's a simple array, show shape
                    elif hasattr(attr_value, 'shape'):
                        print(f"  Shape: {attr_value.shape}")
                        if attr_value.size < 10:
                            print(f"  Values: {attr_value}")
        
        return True
        
    except Exception as e:
        print(f"Error: {e}")
        return False

def main():
    base_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned'
    mat_files = glob.glob(os.path.join(base_dir, '*.mat'))
    
    adt_files = [f for f in mat_files if 'Aoddball' in os.path.basename(f)]
    if adt_files:
        check_all_fields(adt_files[0])

if __name__ == "__main__":
    main() 