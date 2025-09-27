#!/usr/bin/env python3
"""
Simple script to examine .mat file structure
"""

import scipy.io
import os
import glob
import numpy as np

def examine_file(filepath):
    """Examine a .mat file"""
    print(f"Examining: {os.path.basename(filepath)}")
    
    try:
        # Load the .mat file
        mat_data = scipy.io.loadmat(filepath, squeeze_me=True, struct_as_record=False)
        
        # Check top level
        print(f"Top level keys: {list(mat_data.keys())}")
        
        if 'S' in mat_data:
            S = mat_data['S']
            print(f"S type: {type(S)}")
            
            # List all attributes
            attrs = [attr for attr in dir(S) if not attr.startswith('_')]
            print(f"S attributes: {attrs}")
            
            # Check data field
            if hasattr(S, 'data'):
                data = S.data
                print(f"Data type: {type(data)}")
                if hasattr(data, 'dtype') and data.dtype.names:
                    print(f"Data fields: {data.dtype.names}")
                    
                    # Check each field
                    for field in data.dtype.names:
                        field_data = data[field]
                        print(f"  {field}: {type(field_data)}")
                        if hasattr(field_data, 'shape'):
                            print(f"    Shape: {field_data.shape}")
                            if field_data.size < 10:
                                print(f"    Values: {field_data}")
            
            # Check output field
            if hasattr(S, 'output'):
                output = S.output
                print(f"Output type: {type(output)}")
                if hasattr(output, 'dtype') and output.dtype.names:
                    print(f"Output fields: {output.dtype.names}")
                    for field in output.dtype.names:
                        field_data = output[field]
                        if hasattr(field_data, 'shape'):
                            print(f"  {field}: shape {field_data.shape}")
        
        return True
        
    except Exception as e:
        print(f"Error: {e}")
        return False

def main():
    base_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned'
    mat_files = glob.glob(os.path.join(base_dir, '*.mat'))
    
    # Examine first ADT file
    adt_files = [f for f in mat_files if 'Aoddball' in os.path.basename(f)]
    if adt_files:
        examine_file(adt_files[0])

if __name__ == "__main__":
    main() 