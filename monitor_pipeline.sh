#!/bin/bash
# Quick script to monitor pipeline progress

echo "=================================================================================="
echo "PIPELINE MONITORING"
echo "=================================================================================="
echo ""

# Check if pipeline is running
if pgrep -f "run_full_pipeline.R" > /dev/null; then
    echo "✅ Pipeline is RUNNING"
    echo ""
    ps aux | grep "run_full_pipeline.R" | grep -v grep | awk '{print "  PID:", $2, "| Started:", $9, $10}'
else
    echo "❌ Pipeline is NOT running"
    echo "   (Either finished or never started)"
fi

echo ""
echo "=================================================================================="
echo "RECENT OUTPUT (last 20 lines)"
echo "=================================================================================="
if [ -f pipeline_output.log ]; then
    tail -20 pipeline_output.log
else
    echo "No output log found"
fi

echo ""
echo "=================================================================================="
echo "MODEL FILES STATUS"
echo "=================================================================================="
if [ -d "output/models" ]; then
    echo "Generated models:"
    ls -lh output/models/*.rds 2>/dev/null | tail -10 | awk '{print "  " $9, "(" $5 ")"}'
    echo ""
    echo "Total model files: $(ls output/models/*.rds 2>/dev/null | wc -l)"
else
    echo "Output directory not yet created"
fi

echo ""
echo "=================================================================================="
echo "TO MONITOR IN REAL-TIME:"
echo "  tail -f pipeline_output.log"
echo "=================================================================================="














