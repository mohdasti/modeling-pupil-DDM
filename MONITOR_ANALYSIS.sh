#!/bin/bash
# Monitor DDM analysis status

cd "$(dirname "$0")"

if [ -f "ddm_analysis.pid" ]; then
    PID=$(cat ddm_analysis.pid)
    if ps -p $PID > /dev/null 2>&1; then
        echo "✅ Analysis is RUNNING (PID: $PID)"
        echo "   Started: $(ps -p $PID -o lstart=)"
        echo "   CPU time: $(ps -p $PID -o etime=)"
        echo ""
        echo "Latest log entries:"
        tail -5 ddm_analysis_background.log 2>/dev/null || echo "   (log file not found)"
    else
        echo "❌ Analysis is NOT running (PID $PID not found)"
        echo "   Check log file: ddm_analysis_background.log"
    fi
else
    echo "⚠️  No PID file found. Checking for any running analysis..."
    if ps aux | grep -E "02_ddm_analysis|Rscript.*ddm" | grep -v grep > /dev/null; then
        echo "✅ Found running R process (may be analysis):"
        ps aux | grep -E "02_ddm_analysis|Rscript.*ddm" | grep -v grep
    else
        echo "❌ No analysis process found"
    fi
fi

echo ""
echo "Recent log activity (last 10 lines):"
tail -10 ddm_analysis_background.log 2>/dev/null || tail -10 ddm_analysis_with_fixes.log 2>/dev/null || echo "   (no log file found)"
















