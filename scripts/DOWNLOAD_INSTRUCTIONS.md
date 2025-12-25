# Downloading New Cleaned Pupil Files from Google Drive

## Current Status
- **Local directory:** `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned`
- **Current files:** 331 `.mat` files
- **Google Drive folder:** https://drive.google.com/drive/folders/18I2ZAluyczf3mDzDPu8SC6XIvktS3Yn9

## Download Methods

### Method 1: Google Drive Web Interface (Recommended)
1. Open the Google Drive folder: https://drive.google.com/drive/folders/18I2ZAluyczf3mDzDPu8SC6XIvktS3Yn9
2. Select all new files (or use Ctrl/Cmd+A for all)
3. Right-click → Download
4. Extract the zip file
5. Copy only the `.mat` files to: `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned`

### Method 2: Using rclone (If folder is accessible)
If the folder is shared with your Google account, you can try:
```bash
# First, find the folder in your shared files
rclone lsf gdrive: --drive-shared-with-me --recursive | grep "18I2ZAluyczf3mDzDPu8SC6XIvktS3Yn9"

# Then copy files
rclone copy "gdrive:/path/to/folder" "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned" \
    --include "*.mat" \
    --drive-acknowledge-abuse \
    --progress
```

### Method 3: Using Google Drive Desktop App
1. Install Google Drive for Desktop
2. Sync the folder
3. Files will appear in the local Google Drive folder
4. Copy `.mat` files to the cleaned directory

## After Downloading New Files

Once you've downloaded new files, run:

```bash
# 1. Check which files are new
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM
Rscript scripts/check_new_files.R

# 2. Process new files with MATLAB pipeline (if needed)
# Run the MATLAB script to create flat files from new cleaned files

# 3. Merge new files with behavioral data
Rscript -e "source('01_data_preprocessing/r/Create merged flat file.R')"
```

The merger script will automatically:
- Detect new flat files
- Merge them with the latest behavioral data
- Create `*_flat_merged.csv` files for analysis









