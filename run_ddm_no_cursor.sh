#!/bin/bash
# Run DDM analysis WITHOUT risking Cursor crash
# This uses a separate R process and limits resource usage

cd "$(dirname "$0")"

# Limit resources to prevent overwhelming Cursor
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export NUMEXPR_NUM_THREADS=1

# Create log with timestamp
LOG_FILE="ddm_analysis_$(date +%Y%m%d_%H%M%S).log"

echo "=========================================="
echo "Running DDM Analysis (Cursor-Safe Mode)"
echo "=========================================="
echo "Started: $(date)"
echo "Log: $LOG_FILE"
echo ""
echo "NOTE: This may take several hours for all models"
echo "You can monitor progress: tail -f $LOG_FILE"
echo "=========================================="
echo ""

# Run with caffeinate to prevent sleep, nohup to survive closure
nohup caffeinate -d -i -m \
    /usr/local/bin/Rscript scripts/02_statistical_analysis/02_ddm_analysis.R \
    > "$LOG_FILE" 2>&1 &

PID=$!
echo "Analysis PID: $PID"
echo "$PID" > ddm_analysis.pid

echo ""
echo "✅ Analysis started successfully!"
echo "📊 Monitor: tail -f $LOG_FILE"
echo "🔍 Status: ./MONITOR_ANALYSIS.sh"
echo "🛑 Stop: kill $PID"
echo ""

# Wait a moment then show first few log lines
sleep 2
if [ -f "$LOG_FILE" ]; then
    echo "First 20 lines of log:"
    echo "----------------------------------------"
    head -20 "$LOG_FILE"
    echo "----------------------------------------"
fi

