#!/bin/bash
# Download new cleaned pupil files from Google Drive using rclone
# Only downloads files that don't already exist locally

set -e

# Configuration
DRIVE_FOLDER_ID="18I2ZAluyczf3mDzDPu8SC6XIvktS3Yn9"
LOCAL_DIR="/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_cleaned"
REMOTE_NAME="gdrive"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Downloading New Cleaned Pupil Files from Google Drive${NC}"
echo "=================================================================="
echo ""

# Check if rclone is installed
if ! command -v rclone &> /dev/null; then
    echo -e "${RED}Error: rclone is not installed${NC}"
    echo "Install with: brew install rclone"
    exit 1
fi

# Check if rclone is configured
if ! rclone listremotes | grep -q "$REMOTE_NAME:"; then
    echo -e "${YELLOW}rclone is not configured for Google Drive${NC}"
    echo "Please run: rclone config"
    exit 1
fi

# Create local directory if needed
mkdir -p "$LOCAL_DIR"

# Count existing files
EXISTING_COUNT=$(ls -1 "$LOCAL_DIR"/*.mat 2>/dev/null | wc -l | tr -d ' ')
echo "Existing files in local directory: $EXISTING_COUNT"
echo ""

# Try to copy files from Google Drive
# rclone copy will only copy files that don't exist or are newer
echo -e "${YELLOW}Downloading new/modified files from Google Drive...${NC}"
echo "This may take a while depending on the number of new files..."
echo ""

# Try different methods to access the folder
# Method 1: Try as a file ID (if folder is accessible)
rclone copy \
    "$REMOTE_NAME:/$DRIVE_FOLDER_ID" \
    "$LOCAL_DIR" \
    --drive-acknowledge-abuse \
    --include "*.mat" \
    --exclude "*.{png,jpg,jpeg,zip,txt,xlsx,docx}" \
    --progress \
    --stats-one-line \
    --stats=5s \
    --transfers=4 \
    --checkers=8 \
    2>&1 | tee /tmp/rclone_download.log || {
    
    echo ""
    echo -e "${YELLOW}Direct folder access failed. Trying alternative method...${NC}"
    echo ""
    
    # Method 2: List all shared files and filter
    echo "Searching for files in shared Google Drive folders..."
    rclone lsf "$REMOTE_NAME:" --drive-shared-with-me --recursive 2>/dev/null | \
        grep -i "eyetrack_cleaned.mat" | while read -r file_path; do
            filename=$(basename "$file_path")
            local_file="$LOCAL_DIR/$filename"
            
            if [ ! -f "$local_file" ]; then
                echo -e "${GREEN}Downloading: $filename${NC}"
                rclone copy "$REMOTE_NAME:/$file_path" "$LOCAL_DIR" \
                    --drive-acknowledge-abuse \
                    --progress
            else
                echo "Skipping (exists): $filename"
            fi
        done
}

# Count files after download
NEW_COUNT=$(ls -1 "$LOCAL_DIR"/*.mat 2>/dev/null | wc -l | tr -d ' ')
NEW_FILES=$((NEW_COUNT - EXISTING_COUNT))

echo ""
echo "=" * 70
echo -e "${GREEN}Download Summary${NC}"
echo "=" * 70
echo "Files before: $EXISTING_COUNT"
echo "Files after:  $NEW_COUNT"
echo "New files:    $NEW_FILES"
echo ""

if [ "$NEW_FILES" -gt 0 ]; then
    echo -e "${GREEN}✓ Successfully downloaded $NEW_FILES new file(s)${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Run MATLAB pipeline to process new files (if needed)"
    echo "2. Run merger script: 01_data_preprocessing/r/Create merged flat file.R"
else
    echo -e "${GREEN}✓ All files are up to date${NC}"
fi

echo ""
echo "Files location: $LOCAL_DIR"









