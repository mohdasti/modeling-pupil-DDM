#!/bin/bash
# Script to run MATLAB pipeline for processing new pupil data files
# This script handles MATLAB path issues

cd "$(dirname "$0")"

MATLAB_PATH="/Applications/MATLAB_R2023b.app/bin/matlab"

if [ ! -f "$MATLAB_PATH" ]; then
    echo "ERROR: MATLAB not found at $MATLAB_PATH"
    echo "Please update the MATLAB_PATH in this script to point to your MATLAB installation"
    exit 1
fi

echo "=== Running MATLAB Pipeline for New Pupil Data ==="
echo "This will process all new .mat files in BAP_cleaned and create flat CSV files"
echo ""

# Run MATLAB with the pipeline
"$MATLAB_PATH" -batch "cd('01_data_preprocessing/matlab'); BAP_Pupillometry_Pipeline(); exit;" 2>&1 | tee matlab_pipeline_run.log

echo ""
echo "=== MATLAB Pipeline Complete ==="
echo "Check matlab_pipeline_run.log for details"
echo ""
echo "Next step: Run the R merger script to create merged files:"
echo "  Rscript -e \"source('01_data_preprocessing/r/Create merged flat file.R')\""



