#!/usr/bin/env python3
"""
Check data structure of .mat files
"""

import scipy.io
import os
import glob
import numpy as np

def check_file(filepath):
    """Check the structure of a .mat file"""
    print(f"Checking: {os.path.basename(filepath)}")
    
    try:
        mat_data = scipy.io.loadmat(filepath, squeeze_me=True, struct_as_record=False)
        
        if 'S' in mat_data:
            S = mat_data['S']
            
            # Check data field
            if hasattr(S, 'data'):
                data = S.data
                print(f"Data type: {type(data)}")
                
                # Try to access as structured array
                try:
                    if hasattr(data, 'dtype') and data.dtype.names:
                        print(f"Data fields: {data.dtype.names}")
                        
                        # Look for Events or timing-related fields
                        for field in data.dtype.names:
                            if 'event' in field.lower() or 'time' in field.lower() or 'message' in field.lower():
                                field_data = data[field]
                                print(f"  Found timing-related field: {field}")
                                print(f"    Type: {type(field_data)}")
                                if hasattr(field_data, 'shape'):
                                    print(f"    Shape: {field_data.shape}")
                                    if field_data.size < 20:
                                        print(f"    Sample values: {field_data}")
                except Exception as e:
                    print(f"Error accessing data fields: {e}")
            
            # Check output field
            if hasattr(S, 'output'):
                output = S.output
                print(f"Output type: {type(output)}")
                if hasattr(output, 'dtype') and output.dtype.names:
                    print(f"Output fields: {output.dtype.names}")
        
        return True
        
    except Exception as e:
        print(f"Error: {e}")
        return False

def main():
    base_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned'
    mat_files = glob.glob(os.path.join(base_dir, '*.mat'))
    
    # Check first ADT file
    adt_files = [f for f in mat_files if 'Aoddball' in os.path.basename(f)]
    if adt_files:
        check_file(adt_files[0])

if __name__ == "__main__":
    main() 