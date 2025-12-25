#!/bin/bash
# Download new cleaned pupil files from Google Drive
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
    echo "Or use the setup script: scripts/utilities/sync_gdrive_rclone.sh"
    exit 1
fi

# Create local directory if needed
mkdir -p "$LOCAL_DIR"

# First, let's try to list files in the folder using rclone
echo -e "${YELLOW}Checking Google Drive folder for new files...${NC}"
echo "Folder ID: $DRIVE_FOLDER_ID"
echo "Local directory: $LOCAL_DIR"
echo ""

# Try different methods to access the folder
# Method 1: Try accessing as a shared folder
echo "Attempting to list files in Google Drive folder..."
FILES=$(rclone lsf "$REMOTE_NAME:" --drive-shared-with-me 2>/dev/null | grep -i "eyetrack_cleaned.mat" || true)

if [ -z "$FILES" ]; then
    # Method 2: Try using the folder ID directly with proper syntax
    echo "Trying alternative method to access folder..."
    FILES=$(rclone lsf "$REMOTE_NAME:/$DRIVE_FOLDER_ID" 2>/dev/null | grep -i "eyetrack_cleaned.mat" || true)
fi

if [ -z "$FILES" ]; then
    echo -e "${YELLOW}Could not automatically list files.${NC}"
    echo "This might be because:"
    echo "  1. The folder is not shared with your Google account"
    echo "  2. The folder ID format needs adjustment"
    echo ""
    echo "Alternative: Use Google Drive web interface to download files manually"
    echo "Or use: rclone copy with explicit file paths"
    echo ""
    echo "For now, let's try a direct sync approach..."
    
    # Try sync with the folder ID - rclone should handle it
    echo -e "${YELLOW}Attempting sync (will only download new/modified files)...${NC}"
    rclone sync \
        "$REMOTE_NAME:/$DRIVE_FOLDER_ID" \
        "$LOCAL_DIR" \
        --drive-acknowledge-abuse \
        --progress \
        --stats-one-line \
        --stats=5s \
        --include "*.mat" \
        --exclude "*.{png,jpg,jpeg,zip}" || {
        echo -e "${RED}Sync failed.${NC}"
        echo ""
        echo "Please try one of these alternatives:"
        echo "1. Use Google Drive web interface:"
        echo "   https://drive.google.com/drive/folders/$DRIVE_FOLDER_ID"
        echo "2. Use gdown (if installed):"
        echo "   pip install gdown"
        echo "   gdown --folder https://drive.google.com/drive/folders/$DRIVE_FOLDER_ID"
        echo "3. Manually download files and place them in:"
        echo "   $LOCAL_DIR"
        exit 1
    }
else
    echo "Found files in Google Drive. Downloading only new files..."
    # Process each file
    for file in $FILES; do
        local_file="$LOCAL_DIR/$file"
        if [ ! -f "$local_file" ]; then
            echo -e "${GREEN}Downloading: $file${NC}"
            rclone copy "$REMOTE_NAME:/$DRIVE_FOLDER_ID/$file" "$LOCAL_DIR" \
                --drive-acknowledge-abuse \
                --progress
        else
            echo -e "Skipping (exists): $file"
        fi
    done
fi

echo ""
echo -e "${GREEN}Download check complete!${NC}"
echo ""
echo "Files are in: $LOCAL_DIR"
echo ""
echo "Current file count: $(ls -1 "$LOCAL_DIR"/*.mat 2>/dev/null | wc -l | tr -d ' ')"









