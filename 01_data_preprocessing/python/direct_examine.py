#!/usr/bin/env python3
"""
Direct examination of .mat file structure
"""

import scipy.io
import os
import glob
import numpy as np

def examine_directly(filepath):
    """Examine .mat file directly"""
    print(f"Direct examination: {os.path.basename(filepath)}")
    
    try:
        # Load without squeeze_me to see original structure
        mat_data = scipy.io.loadmat(filepath, squeeze_me=False, struct_as_record=False)
        
        print(f"Top level keys: {list(mat_data.keys())}")
        
        if 'S' in mat_data:
            S = mat_data['S']
            print(f"S type: {type(S)}")
            print(f"S shape: {S.shape}")
            
            # Access first element if it's an array
            if S.size > 0:
                S_item = S[0, 0] if S.shape[0] > 0 and S.shape[1] > 0 else S
                print(f"S item type: {type(S_item)}")
                
                # List all attributes
                attrs = [attr for attr in dir(S_item) if not attr.startswith('_')]
                print(f"S attributes: {attrs}")
                
                # Check data field
                if hasattr(S_item, 'data'):
                    data = S_item.data
                    print(f"Data type: {type(data)}")
                    print(f"Data shape: {data.shape}")
                    
                    if data.size > 0:
                        data_item = data[0, 0] if data.shape[0] > 0 and data.shape[1] > 0 else data
                        print(f"Data item type: {type(data_item)}")
                        
                        if hasattr(data_item, 'dtype') and data_item.dtype.names:
                            print(f"Data fields: {data_item.dtype.names}")
                            
                            # Look for Events
                            for field in data_item.dtype.names:
                                if 'event' in field.lower():
                                    field_data = data_item[field]
                                    print(f"  Found Events field: {field}")
                                    print(f"    Type: {type(field_data)}")
                                    if hasattr(field_data, 'shape'):
                                        print(f"    Shape: {field_data.shape}")
                
                # Check output field
                if hasattr(S_item, 'output'):
                    output = S_item.output
                    print(f"Output type: {type(output)}")
                    print(f"Output shape: {output.shape}")
                    
                    if output.size > 0:
                        output_item = output[0, 0] if output.shape[0] > 0 and output.shape[1] > 0 else output
                        print(f"Output item type: {type(output_item)}")
                        
                        if hasattr(output_item, 'dtype') and output_item.dtype.names:
                            print(f"Output fields: {output_item.dtype.names}")
        
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
        examine_directly(adt_files[0])

if __name__ == "__main__":
    main() 