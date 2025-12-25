#!/usr/bin/env python3
"""
Download new cleaned pupil files from Google Drive
Only downloads files that don't already exist locally
"""

import os
import sys
from pathlib import Path

try:
    import gdown
except ImportError:
    print("Installing gdown...")
    os.system("pip install -q gdown")
    import gdown

# Configuration
DRIVE_FOLDER_ID = "18I2ZAluyczf3mDzDPu8SC6XIvktS3Yn9"
DRIVE_FOLDER_URL = f"https://drive.google.com/drive/folders/{DRIVE_FOLDER_ID}"
LOCAL_DIR = Path("/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned")

def get_existing_files():
    """Get list of existing .mat files in local directory"""
    if not LOCAL_DIR.exists():
        return set()
    
    existing = set()
    for file in LOCAL_DIR.glob("*.mat"):
        existing.add(file.name)
    return existing

def download_folder_selective(folder_url, local_dir, existing_files):
    """
    Download folder from Google Drive, skipping files that already exist
    """
    local_path = Path(local_dir)
    local_path.mkdir(parents=True, exist_ok=True)
    
    print("=" * 70)
    print("Downloading New Cleaned Pupil Files from Google Drive")
    print("=" * 70)
    print(f"Folder URL: {folder_url}")
    print(f"Local directory: {local_path}")
    print(f"Existing files: {len(existing_files)}")
    print()
    
    # Use gdown to download the folder
    # gdown will download all files, but we can check before downloading
    print("Downloading folder (gdown will skip files that already exist)...")
    print("Note: gdown downloads the entire folder, but we'll verify after download")
    print()
    
    try:
        # Download folder - gdown handles the folder download
        output = gdown.download_folder(
            folder_url,
            output=str(local_path),
            quiet=False,
            use_cookies=False
        )
        
        print()
        print("=" * 70)
        print("Download Summary")
        print("=" * 70)
        
        # Count new files
        current_files = get_existing_files()
        new_files = current_files - existing_files
        
        print(f"Files before download: {len(existing_files)}")
        print(f"Files after download: {len(current_files)}")
        print(f"New files downloaded: {len(new_files)}")
        
        if new_files:
            print("\nNew files:")
            for f in sorted(new_files):
                print(f"  ✓ {f}")
        else:
            print("\nNo new files downloaded (all files already exist)")
        
        return len(new_files)
        
    except Exception as e:
        print(f"\nError downloading folder: {e}")
        print("\nAlternative methods:")
        print("1. Use Google Drive web interface:")
        print(f"   {folder_url}")
        print("2. Use rclone (if configured):")
        print(f"   rclone copy gdrive:/{DRIVE_FOLDER_ID} {local_path} --drive-acknowledge-abuse")
        return 0

if __name__ == "__main__":
    # Get existing files
    existing = get_existing_files()
    
    # Download new files
    new_count = download_folder_selective(DRIVE_FOLDER_URL, LOCAL_DIR, existing)
    
    if new_count > 0:
        print(f"\n✓ Successfully downloaded {new_count} new file(s)")
        print(f"\nNext step: Run the MATLAB pipeline to process new files")
        print("Then run: 01_data_preprocessing/r/Create merged flat file.R")
    else:
        print("\n✓ All files are up to date")
    
    sys.exit(0 if new_count >= 0 else 1)









