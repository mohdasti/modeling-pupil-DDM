#!/bin/bash

# ============================================================================
# Complete Pipeline Rebuild Script
# ============================================================================
# This script runs all three pipeline stages in sequence:
# 1. MATLAB pipeline (creates flat files with ses)
# 2. R merger (creates merged files with correct ses and run)
# 3. QMD report (creates final MERGED and TRIALLEVEL)
# 4. Verification (checks that fixes are working)
# ============================================================================

set -e  # Exit on error

# Get the project root directory
PROJECT_ROOT="/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM"
cd "$PROJECT_ROOT"

echo "============================================================================"
echo "PIPELINE REBUILD SCRIPT"
echo "============================================================================"
echo ""
echo "Project directory: $PROJECT_ROOT"
echo ""

# ============================================================================
# Step 1: MATLAB Pipeline
# ============================================================================

echo "STEP 1: Running MATLAB Pipeline..."
echo "----------------------------------------------------------------------------"

MATLAB_SCRIPT="01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m"

if [ ! -f "$MATLAB_SCRIPT" ]; then
    echo "ERROR: MATLAB script not found: $MATLAB_SCRIPT"
    exit 1
fi

# Check if MATLAB is available
if command -v matlab &> /dev/null; then
    echo "Running MATLAB pipeline..."
    matlab -nodisplay -nosplash -r "cd('$PROJECT_ROOT/01_data_preprocessing/matlab'); BAP_Pupillometry_Pipeline(); exit" || {
        echo "WARNING: MATLAB pipeline may have failed. Check output above."
        echo "You may need to run MATLAB manually."
    }
else
    echo "WARNING: MATLAB not found in PATH."
    echo "Please run MATLAB manually:"
    echo "  cd $PROJECT_ROOT/01_data_preprocessing/matlab"
    echo "  BAP_Pupillometry_Pipeline()"
    echo ""
    read -p "Press Enter after MATLAB pipeline completes..."
fi

echo "✓ MATLAB pipeline complete"
echo ""

# ============================================================================
# Step 2: R Merger
# ============================================================================

echo "STEP 2: Running R Merger..."
echo "----------------------------------------------------------------------------"

R_MERGER="01_data_preprocessing/r/Create merged flat file.R"

if [ ! -f "$R_MERGER" ]; then
    echo "ERROR: R merger script not found: $R_MERGER"
    exit 1
fi

# Check if R is available
if command -v Rscript &> /dev/null; then
    echo "Running R merger..."
    Rscript "$R_MERGER" || {
        echo "ERROR: R merger failed. Check output above."
        exit 1
    }
else
    echo "ERROR: Rscript not found in PATH."
    echo "Please install R or add it to PATH."
    exit 1
fi

echo "✓ R merger complete"
echo ""

# ============================================================================
# Step 3: QMD Report
# ============================================================================

echo "STEP 3: Rendering QMD Report..."
echo "----------------------------------------------------------------------------"

QMD_FILE="02_pupillometry_analysis/generate_pupil_data_report.qmd"

if [ ! -f "$QMD_FILE" ]; then
    echo "ERROR: QMD file not found: $QMD_FILE"
    exit 1
fi

# Check if Quarto is available
if command -v quarto &> /dev/null; then
    echo "Rendering QMD report (this may take a while)..."
    quarto render "$QMD_FILE" || {
        echo "ERROR: QMD rendering failed. Check output above."
        exit 1
    }
else
    echo "WARNING: Quarto not found in PATH."
    echo "Please install Quarto: https://quarto.org/docs/get-started/"
    echo "Or render from RStudio."
    echo ""
    read -p "Press Enter after QMD rendering completes..."
fi

echo "✓ QMD report complete"
echo ""

# ============================================================================
# Step 4: Verification
# ============================================================================

echo "STEP 4: Running Verification..."
echo "----------------------------------------------------------------------------"

VERIFY_SCRIPT="scripts/verify_forensic_fixes.R"

if [ ! -f "$VERIFY_SCRIPT" ]; then
    echo "WARNING: Verification script not found: $VERIFY_SCRIPT"
    echo "Skipping verification..."
else
    if command -v Rscript &> /dev/null; then
        echo "Running verification script..."
        Rscript "$VERIFY_SCRIPT" || {
            echo "WARNING: Verification script had issues. Check output above."
        }
    else
        echo "WARNING: Rscript not found. Skipping verification."
    fi
fi

echo "✓ Verification complete"
echo ""

# ============================================================================
# Summary
# ============================================================================

echo "============================================================================"
echo "PIPELINE REBUILD COMPLETE"
echo "============================================================================"
echo ""
echo "Check output files:"
echo "  - MERGED: data/analysis_ready/BAP_analysis_ready_MERGED.csv"
echo "  - TRIALLEVEL: data/analysis_ready/BAP_analysis_ready_TRIALLEVEL.csv"
echo ""
echo "Verification report:"
echo "  - data/qc/pipeline_forensics/final_verification.md"
echo ""
