#!/usr/bin/env python3
"""
List all fields in the .mat file structure
"""

import scipy.io
import os
import glob

def list_fields(filepath):
    """List all fields in the .mat file"""
    print(f"Listing fields: {os.path.basename(filepath)}")
    
    try:
        mat_data = scipy.io.loadmat(filepath, squeeze_me=False, struct_as_record=False)
        
        if 'S' in mat_data:
            S = mat_data['S'][0, 0]
            print(f"S fields: {[attr for attr in dir(S) if not attr.startswith('_')]}")
            
            if hasattr(S, 'data'):
                data = S.data[0, 0]
                print(f"Data fields: {[attr for attr in dir(data) if not attr.startswith('_')]}")
                
                # Check each field in data
                for attr in dir(data):
                    if not attr.startswith('_'):
                        attr_value = getattr(data, attr)
                        print(f"  {attr}: {type(attr_value)}")
                        
                        # If it's a structured array, list its fields
                        if hasattr(attr_value, 'dtype') and attr_value.dtype.names:
                            print(f"    Subfields: {attr_value.dtype.names}")
        
        return True
        
    except Exception as e:
        print(f"Error: {e}")
        return False

def main():
    base_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned'
    mat_files = glob.glob(os.path.join(base_dir, '*.mat'))
    
    adt_files = [f for f in mat_files if 'Aoddball' in os.path.basename(f)]
    if adt_files:
        list_fields(adt_files[0])

if __name__ == "__main__":
    main() 