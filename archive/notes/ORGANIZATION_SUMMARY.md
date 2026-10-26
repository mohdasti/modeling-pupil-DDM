# Directory Organization Summary

**Date**: January 3, 2025  
**Purpose**: Clean up and organize repository for Chapter 2 and Chapter 3 separation

## Current Structure

### Main Directory (Chapter 3 Focus)
The main directory `/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM` now serves as the **Chapter 3 dissertation materials** repository.

**Key Active Files:**
- `data/pupil_processed/` - Processed pupil data (formerly `quick_share_v7/`)
- `reports/pupil_data_report_advisor.qmd` - Latest comprehensive data quality report
- `reports/chap3_ddm_results.qmd` - Chapter 3 DDM results report
- `scripts/make_quick_share_v7.R` - Latest quick share generation script
- `scripts/02_statistical_analysis/` - DDM analysis scripts

### Chapter 2 Materials (Portable Package)
**Location**: `chapter2_materials/`

This directory contains all essential materials for Chapter 2 analysis and can be copied to a new project directory for standalone Chapter 2 work.

**Contents:**
- `data/ch2_triallevel.csv` - Primary analysis-ready dataset
- `docs/` - Key documentation files (timing, AUC, setup guides)
- `scripts/make_quick_share_v7.R` - Data regeneration script
- `reports/pupil_data_report_advisor.qmd` - Data quality report
- `README.md` - Complete usage guide

### Archive Directory
**Location**: `archive/`

Contains older versions of files that have been superseded:
- `old_reports/` - Old report backups and slim versions
- `old_scripts/` - Old quick_share generation scripts (v2, v3, v6)
- `old_quick_share/` - Old quick_share directories

## Latest Versions (Active)

### Data
- **Processed Pupil Data** - Most recent data package with fixed baseline alignment
  - Location: `data/pupil_processed/` (formerly `quick_share_v7/`)
  - Key files:
    - `analysis_ready/ch2_triallevel.csv` - Chapter 2 data
    - `analysis_ready/ch3_triallevel.csv` - Chapter 3 data
    - `qc/` - Quality control summaries

### Reports
- **pupil_data_report_advisor.qmd** - Latest comprehensive data quality report
  - Location: `reports/pupil_data_report_advisor.qmd`
  - Covers both Chapter 2 and Chapter 3 data readiness
  - Includes RT-normalized metrics and quality diagnostics

### Scripts
- **make_quick_share_v7.R** - Latest quick share generation
  - Location: `scripts/make_quick_share_v7.R`
  - Generates quick_share_v7 data package

## What Was Archived

### Reports
- `generate_pupil_data_report.qmd.bak*` (5 backup files)
- `generate_pupil_data_report.qmd.new`
- `generate_pupil_data_report_slim.qmd` and `.html`

### Scripts
- `make_quick_share_v3.R`
- `make_quick_share_v6.R`
- `make_quick_share_v6_auc_waveforms.R`
- `scripts/R/quick_share_v2_generate.R`
- `scripts/R/quick_share_export.R`
- `scripts/intermediary/run_quick_share.sh`

### Directories
- `02_pupillometry_analysis/quick_share/` (old version)

## Quick Reference

**For Chapter 2 work:**
1. Copy `chapter2_materials/` to new project directory
2. Load `data/ch2_triallevel.csv`
3. Follow `docs/CHAPTER2_SETUP_PROMPT_CONCISE.md`

**For Chapter 3 work:**
1. Use files in main directory
2. Data: `quick_share_v7/analysis_ready/ch3_triallevel.csv`
3. Report: `reports/chap3_ddm_results.qmd`
4. Scripts: `scripts/02_statistical_analysis/`

**To regenerate data:**
- Run `scripts/make_quick_share_v7.R` (outputs to `data/pupil_processed/`)

## Notes

- No files were deleted, only moved to archive
- All active files remain in their original locations
- Chapter 2 materials are copies (originals remain in main directory)
- Archive can be safely ignored for day-to-day work

