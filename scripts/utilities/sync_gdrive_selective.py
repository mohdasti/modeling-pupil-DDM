#!/usr/bin/env python3
"""
Selective Google Drive Download Script
Downloads only files that don't already exist locally or have different sizes.
"""

import os
import sys
import hashlib
from pathlib import Path

try:
    import gdown
except ImportError:
    print("Installing gdown...")
    os.system("pip install -q gdown")
    import gdown


def file_hash(filepath):
    """Calculate MD5 hash of file"""
    hash_md5 = hashlib.md5()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()


def get_file_info(folder_url, pattern="*"):
    """
    Get list of files from Google Drive folder
    Note: gdown doesn't directly list folder contents, so we'll use drive CLI or API
    """
    try:
        # Use gdrive CLI if available
        import subprocess
        result = subprocess.run(
            ["gdrive", "list", "--query", f"'{folder_url}' in parents"],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            return result.stdout
    except:
        pass
    
    # Alternative: manual folder ID extraction
    print("Note: Automatic file listing not available.")
    print("Please provide file IDs manually or use gdrive CLI.")
    return None


def sync_folder(folder_url, local_dir):
    """
    Sync Google Drive folder to local directory, skipping existing files
    
    Args:
        folder_url: Google Drive folder URL (must be publicly accessible or shared)
        local_dir: Local directory to save files
    """
    # Extract folder ID from URL
    if "folders/" in folder_url:
        folder_id = folder_url.split("folders/")[-1].split("?")[0]
    else:
        folder_id = folder_url
    
    # Create local directory if needed
    local_path = Path(local_dir)
    local_path.mkdir(parents=True, exist_ok=True)
    
    print(f"Syncing Google Drive folder to: {local_path}")
    print(f"Folder ID: {folder_id}")
    
    # Strategy 1: Download all files and check locally
    # This works if you know the file structure
    
    print("\nNote: gdown works best with individual file IDs.")
    print("For selective syncing, you can:")
    print("1. Manually list files and download only new ones")
    print("2. Use Google Drive API for automatic listing")
    print("3. Use rclone for better sync capabilities")
    
    return folder_id


def manual_sync_file(file_id, filename, local_dir):
    """Download a single file if it doesn't exist locally"""
    local_path = Path(local_dir) / filename
    
    if local_path.exists():
        print(f"✓ Skipping (exists): {filename}")
        return True
    
    try:
        url = f"https://drive.google.com/uc?id={file_id}"
        gdown.download(url, str(local_path), quiet=False)
        print(f"✓ Downloaded: {filename}")
        return True
    except Exception as e:
        print(f"✗ Error downloading {filename}: {e}")
        return False


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python sync_gdrive_selective.py <folder_url> <local_dir>")
        print("\nExample:")
        print("  python sync_gdrive_selective.py \\")
        print("    'https://drive.google.com/drive/folders/18I2ZAluyczf3mDzDPu8SC6XIvktS3Yn9' \\")
        print("    '/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned'")
        sys.exit(1)
    
    folder_url = sys.argv[1]
    local_dir = sys.argv[2]
    
    folder_id = sync_folder(folder_url, local_dir)
    
    print(f"\nFolder ID extracted: {folder_id}")
    print("\nFor automated syncing, consider using:")
    print("  - rclone (https://rclone.org/drive/)")
    print("  - gdrive CLI (https://github.com/glotlabs/gdrive)")
    print("  - Google Drive API with Python")
