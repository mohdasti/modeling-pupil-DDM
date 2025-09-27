#!/usr/bin/env python3
"""
Examine the data field structure in .mat files
"""

import scipy.io
import os
import glob
import numpy as np

def examine_data_field(filepath):
    """Examine the data field structure"""
    print(f"Examining data field: {os.path.basename(filepath)}")
    
    try:
        # Load the file
        mat_data = scipy.io.loadmat(filepath, squeeze_me=False, struct_as_record=False)
        
        if 'S' in mat_data:
            S = mat_data['S'][0, 0]  # Get the actual struct
            
            if hasattr(S, 'data'):
                data = S.data[0, 0]  # Get the actual struct
                print(f"Data type: {type(data)}")
                
                # List all fields in data
                if hasattr(data, 'dtype') and data.dtype.names:
                    print(f"Data fields: {data.dtype.names}")
                    
                    # Examine each field
                    for field in data.dtype.names:
                        field_data = data[field]
                        print(f"\nField: {field}")
                        print(f"  Type: {type(field_data)}")
                        
                        if hasattr(field_data, 'shape'):
                            print(f"  Shape: {field_data.shape}")
                            
                            # If it's a structured array, examine its contents
                            if hasattr(field_data, 'dtype') and field_data.dtype.names:
                                print(f"  Sub-fields: {field_data.dtype.names}")
                                
                                # Look for Events or Messages
                                for subfield in field_data.dtype.names:
                                    if 'event' in subfield.lower() or 'message' in subfield.lower():
                                        subfield_data = field_data[subfield]
                                        print(f"    Found timing-related subfield: {subfield}")
                                        print(f"      Type: {type(subfield_data)}")
                                        if hasattr(subfield_data, 'shape'):
                                            print(f"      Shape: {subfield_data.shape}")
                                            
                                            # If it's another structured array, examine further
                                            if hasattr(subfield_data, 'dtype') and subfield_data.dtype.names:
                                                print(f"      Sub-sub-fields: {subfield_data.dtype.names}")
                                                
                                                # Look for time and info fields
                                                for subsubfield in subfield_data.dtype.names:
                                                    if subsubfield in ['time', 'info']:
                                                        subsubfield_data = subfield_data[subsubfield]
                                                        print(f"        {subsubfield}: shape {subsubfield_data.shape}")
                                                        if subsubfield_data.size < 10:
                                                            print(f"        Sample values: {subsubfield_data}")
                        
                        # If it's a simple array, show some values
                        elif field_data.size < 20:
                            print(f"  Values: {field_data}")
        
        return True
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    base_dir = '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned'
    mat_files = glob.glob(os.path.join(base_dir, '*.mat'))
    
    # Examine first ADT file
    adt_files = [f for f in mat_files if 'Aoddball' in os.path.basename(f)]
    if adt_files:
        examine_data_field(adt_files[0])

if __name__ == "__main__":
    main() 