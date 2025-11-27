#!/bin/bash
# Run DDM analysis in a completely separate terminal to avoid crashing Cursor
# This script opens a NEW Terminal window and runs the analysis there

cd "$(dirname "$0")"

# Get the absolute path to the script
SCRIPT_PATH="$(pwd)/scripts/02_statistical_analysis/02_ddm_analysis.R"

# Create a log file with timestamp
LOG_FILE="ddm_analysis_$(date +%Y%m%d_%H%M%S).log"

echo "============================================"
echo "Starting DDM Analysis in Separate Terminal"
echo "============================================"
echo "Log file: $LOG_FILE"
echo "Analysis will run in a NEW Terminal window"
echo "You can close this window safely"
echo "============================================"
echo ""

# Open new Terminal window and run the analysis
osascript << APPLESCRIPT
tell application "Terminal"
    activate
    do script "cd '$PWD' && echo 'Starting DDM Analysis...' && echo 'Log: $LOG_FILE' && echo '' && nohup Rscript '$SCRIPT_PATH' > '$LOG_FILE' 2>&1 && echo '' && echo '=== ANALYSIS COMPLETE ===' && echo 'Check log: $LOG_FILE' && read -p 'Press Enter to close this window'"
end tell
APPLESCRIPT

echo ""
echo "✅ Analysis started in new Terminal window"
echo "📝 Monitor progress: tail -f $LOG_FILE"
echo "📂 View full log: $LOG_FILE"

