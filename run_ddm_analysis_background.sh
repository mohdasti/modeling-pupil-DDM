#!/bin/bash
# Run DDM analysis in background that survives sleep

cd "$(dirname "$0")"

# Prevent system sleep during analysis (requires caffeinate)
# -d: prevent display sleep
# -i: prevent system idle sleep
# -m: prevent disk idle sleep
# -s: prevent system sleep (requires AC power)

echo "Starting DDM analysis with sleep prevention..."
echo "This will keep your system awake during the analysis"
echo "Started at: $(date)"

# Run analysis with nohup AND caffeinate to prevent sleep
nohup caffeinate -d -i -m -s \
    Rscript scripts/02_statistical_analysis/02_ddm_analysis.R \
    > ddm_analysis_background.log 2>&1 &

PID=$!
echo "Analysis started with PID: $PID"
echo "To monitor: tail -f ddm_analysis_background.log"
echo "To check if running: ps -p $PID"
echo "To stop: kill $PID (or pkill -f '02_ddm_analysis')"

# Save PID for later reference
echo $PID > ddm_analysis.pid
echo "PID saved to: ddm_analysis.pid"

