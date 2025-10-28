#!/bin/bash
# Selective Google Drive Sync with rclone
# Downloads only files that don't exist locally or have been modified

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

echo -e "${GREEN}Google Drive Selective Sync${NC}"
echo "=============================="
echo ""

# Check if rclone is installed
if ! command -v rclone &> /dev/null; then
    echo -e "${RED}Error: rclone is not installed${NC}"
    echo "Install with: brew install rclone"
    exit 1
fi

# Configure rclone (if not already configured)
if ! rclone listremotes | grep -q "$REMOTE_NAME:"; then
    echo -e "${YELLOW}Setting up Google Drive connection...${NC}"
    echo "You'll need to authenticate with Google Drive"
    echo ""
    echo "Steps:"
    echo "1. Follow the browser authentication"
    echo "2. Copy the auth code"
    echo "3. Paste it in the terminal"
    echo ""
    read -p "Press Enter to start authentication..."
    
    rclone config create $REMOTE_NAME drive \
        scope drive.readonly \
        team_drive "" \
        -y
    
    echo -e "${GREEN}Configuration complete!${NC}"
fi

# Create local directory if needed
mkdir -p "$LOCAL_DIR"

# Sync with selective download
echo -e "${YELLOW}Syncing files (downloads only new/modified files)...${NC}"
echo "Remote: $REMOTE_NAME:/$DRIVE_FOLDER_ID"
echo "Local:  $LOCAL_DIR"
echo ""

rclone sync \
    "$REMOTE_NAME:/$DRIVE_FOLDER_ID" \
    "$LOCAL_DIR" \
    --drive-acknowledge-abuse \
    --progress \
    --verbose \
    --stats-one-line \
    --stats=5s

echo ""
echo -e "${GREEN}Sync complete!${NC}"
echo ""
echo "Files are in: $LOCAL_DIR"
echo ""
echo "To check for changes without syncing, run:"
echo "  rclone check $REMOTE_NAME:/$DRIVE_FOLDER_ID $LOCAL_DIR --one-way"
echo ""
echo "To see what would be transferred:"
echo "  rclone sync $REMOTE_NAME:/$DRIVE_FOLDER_ID $LOCAL_DIR --dry-run"
