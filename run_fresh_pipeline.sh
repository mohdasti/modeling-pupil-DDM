#!/bin/bash
# Fresh pipeline run with improved logging

cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM

echo "=================================================================================="
echo "FRESH PIPELINE RUN - ALL OLD FILES CLEANED"
echo "=================================================================================="
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "Starting fresh pipeline with:"
echo "  - Latest data: bap_trial_data_grip.csv"
echo "  - Pupil data: /Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/"
echo "  - Standardized priors"
echo "  - Standardized RT filtering (0.2-3.0s)"
echo "  - Standard trials included"
echo "  - Improved timestamped logging"
echo "=================================================================================="
echo ""

# Run pipeline with timestamped output
Rscript run_full_pipeline.R 2>&1 | tee pipeline_fresh_run.log

echo ""
echo "=================================================================================="
echo "PIPELINE COMPLETE"
echo "=================================================================================="
echo "End time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Check pipeline_fresh_run.log for detailed output"
