#!/usr/bin/env Rscript

# ============================================================================
# Trace Pipeline: Understand Data Flow
# ============================================================================

cat("=== PIPELINE TRACE ===\n\n")

cat("1. MATLAB PIPELINE (BAP_Pupillometry_Pipeline.m):\n")
cat("   - Reads from: BAP_cleaned/*_cleaned.mat\n")
cat("   - Also reads from: data/sub-*/ses-*/InsideScanner/*_eyetrack.mat (raw)\n")
cat("   - Outputs to: BAP_processed/*_flat.csv\n")
cat("   - Does NOT include behavioral data in flat files\n")
cat("   - Extracts run from filename: 'run(\\d+)'\n")
cat("   - Extracts session from filename: 'session(\\d+)'\n")
cat("   - Creates trial_index (cumulative across runs)\n\n")

cat("2. R MERGER (Create merged flat file.R):\n")
cat("   - Reads from: BAP_processed/*_flat.csv\n")
cat("   - Reads behavioral from: bap_beh_trialdata_v2.csv\n")
cat("   - Merges on: (subject, task, run, trial_index)\n")
cat("   - Outputs: BAP_processed/*_flat_merged.csv\n\n")

cat("3. QMD REPORT (generate_pupil_data_report.qmd):\n")
cat("   - Reads from: BAP_processed/*_flat_merged.csv (preferred)\n")
cat("   - Falls back to: BAP_processed/*_flat.csv\n")
cat("   - Creates: BAP_analysis_ready_MERGED.csv\n")
cat("   - Creates: BAP_analysis_ready_TRIALLEVEL.csv\n\n")

cat("=== KEY QUESTIONS ===\n")
cat("1. Does MATLAB filter for InsideScanner only?\n")
cat("2. Does MATLAB filter for sessions 2-3 only?\n")
cat("3. Where does run information get lost (run=ses)?\n")
cat("4. How were practice/outside-scanner trials included?\n")

