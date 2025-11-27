# Complete Pipeline Execution Guide

**Date:** 2025-01-XX  
**Purpose:** Guide for running the complete 7-step DDM analysis pipeline

---

## 🎯 Overview

There are **two pipeline options** depending on your needs:

1. **`run_ddm_pipeline.R`** - Fast pipeline (Steps 1 & 4 only)
   - For DDM-only analyses
   - Skips optional steps
   - Faster execution

2. **`run_complete_ddm_pipeline.R`** - Complete pipeline (All 7 steps)
   - Runs all steps in order
   - Includes validation and QC
   - Most comprehensive

---

## 📋 Step-by-Step Breakdown

### Step 1: Data Preprocessing (REQUIRED)

**What it does:**
- Loads raw behavioral data
- Maps column names to expected format
- Creates difficulty levels and effort conditions
- Implements response-side coding (`dec_upper`)
- Validates data integrity
- Creates `bap_ddm_only_ready.csv`

**Scripts:**
- `01_data_preprocessing/r/prepare_ddm_only_data.R` (REQUIRED)
- `01_data_preprocessing/r/prepare_ddm_pupil_data.R` (OPTIONAL - if pupil data available)

**Output:**
- `data/analysis_ready/bap_ddm_only_ready.csv`
- `data/analysis_ready/bap_ddm_pupil_ready.csv` (if pupil data available)
- Validation logs in `logs/`

**Time:** ~1-2 minutes

---

### Step 2: Pupillometry Analysis (OPTIONAL)

**What it does:**
- Extracts pupil features (tonic, phasic)
- Performs quality control checks
- Creates pupil feature summaries

**Scripts:**
- `02_pupillometry_analysis/feature_extraction/run_feature_extraction.R`
- `02_pupillometry_analysis/quality_control/run_pupil_qc.R`

**When to run:**
- Only if you have pupil data
- Only if you want DDM-pupil analyses (Step 1B creates this)

**Time:** ~5-10 minutes

---

### Step 3: Behavioral Analysis (RECOMMENDED)

**What it does:**
- Creates RT distribution plots
- Sanity checks on behavioral data
- Accuracy summaries
- Validates RT ranges

**Scripts:**
- `03_behavioral_analysis/reaction_time/run_rt_analysis.R`

**When to run:**
- **Recommended** before DDM fitting
- Helps validate data quality
- Creates diagnostic plots

**Time:** ~1-2 minutes

---

### Step 4: Computational Modeling (REQUIRED)

**What it does:**
- Fits hierarchical Bayesian DDM models
- Estimates drift rate, boundary, bias, NDT
- Validates parameter estimates
- Checks convergence

**Scripts:**
- `04_computational_modeling/drift_diffusion/fit_standard_bias_only.R` (RECOMMENDED FIRST)
- `04_computational_modeling/drift_diffusion/fit_primary_vza.R` (REQUIRED)

**Output:**
- `output/models/standard_bias_only.rds`
- `output/models/primary_vza.rds`
- Parameter validation logs

**Time:** ~30-60 minutes per model

---

### Step 5: Statistical Analysis (OPTIONAL)

**What it does:**
- Extracts model results
- Computes contrasts and comparisons
- Creates effect size summaries
- Model comparison (LOO, AIC)

**Scripts:**
- `scripts/02_statistical_analysis/02_ddm_analysis.R`

**When to run:**
- After model fitting (Step 4)
- Before creating figures (Step 6)

**Time:** ~5-10 minutes

---

### Step 6: Visualization (OPTIONAL)

**What it does:**
- Creates condition effects plots
- Forest plots for parameter estimates
- Diagnostic plots
- Publication-ready figures

**Scripts:**
- `scripts/02_statistical_analysis/create_results_visualizations.R`

**When to run:**
- After statistical analysis (Step 5)
- Before manuscript (Step 7)

**Time:** ~2-5 minutes

---

### Step 7: Manuscript Generation (OPTIONAL)

**What it does:**
- Renders Quarto manuscript
- Generates HTML/PDF/DOCX reports
- Includes tables and figures

**Script:**
- `reports/chap3_ddm_results.qmd`

**When to run:**
- After all analyses complete
- To generate final report

**Time:** ~5-10 minutes

---

## 🚀 Quick Start Options

### Option 1: Fast Pipeline (DDM Only)

**For:** Quick DDM analyses without pupil data

```r
source("run_ddm_pipeline.R")
```

**Runs:**
- ✅ Step 1A: DDM-only data prep
- ⏭️ Step 1B: DDM-pupil (skipped if no pupil data)
- ⏭️ Steps 2-3: Skipped
- ✅ Step 4A: Standard-only bias model
- ✅ Step 4B: Primary model

**Time:** ~60-120 minutes

---

### Option 2: Complete Pipeline (All Steps)

**For:** Full comprehensive analysis

```r
source("run_complete_ddm_pipeline.R")
```

**Runs:**
- ✅ Step 1A: DDM-only data prep (REQUIRED)
- ✅ Step 1B: DDM-pupil (if available)
- ✅ Step 2: Pupillometry analysis (if available)
- ✅ Step 3: Behavioral analysis
- ✅ Step 4A: Standard-only bias model
- ✅ Step 4B: Primary model
- ✅ Step 5: Statistical analysis
- ✅ Step 6: Visualization
- ✅ Step 7: Manuscript preparation

**Time:** ~90-180 minutes (depending on optional steps)

---

## 📊 Dependency Flow

```
Step 1 (Data Prep)
    ↓
Step 2 (Pupillometry) ──┐
    ↓                    │
Step 3 (Behavioral)      │
    ↓                    │
Step 4 (DDM Models) ←────┘
    ↓
Step 5 (Statistics)
    ↓
Step 6 (Visualization)
    ↓
Step 7 (Manuscript)
```

**Key dependencies:**
- Step 4 **requires** Step 1A (at minimum)
- Step 5 **requires** Step 4
- Step 6 **requires** Step 5
- Step 7 **requires** Step 6

---

## ✅ Recommended First Run

For your **first run with fresh data**, use the complete pipeline:

```r
source("run_complete_ddm_pipeline.R")
```

This ensures:
1. ✅ All data is validated
2. ✅ Behavioral checks are performed
3. ✅ Models are fit correctly
4. ✅ Results are extracted and visualized
5. ✅ Everything is ready for manuscript

---

## 🔍 What Gets Created

### Data Files
- `data/analysis_ready/bap_ddm_only_ready.csv`
- `data/analysis_ready/bap_ddm_pupil_ready.csv` (if pupil data)

### Model Files
- `output/models/standard_bias_only.rds`
- `output/models/primary_vza.rds`

### Logs
- `logs/complete_pipeline_YYYYMMDD_HHMMSS.log`
- `logs/ddm_only_data_prep_YYYYMMDD_HHMMSS.log`
- `logs/fit_standard_bias_YYYYMMDD_HHMMSS.log`
- `logs/fit_primary_vza_YYYYMMDD_HHMMSS.log`
- `logs/validation_YYYYMMDD_HHMMSS.log`

### Results
- `output/results/` (statistical summaries)
- `output/figures/` (plots and visualizations)
- `output/publish/` (publication-ready outputs)

---

## ⚠️ Important Notes

1. **Step 1A is REQUIRED** - Cannot proceed without it
2. **Step 4B is REQUIRED** - Primary model must be fit
3. **Steps 2-3 are OPTIONAL** but recommended for validation
4. **Steps 5-7 are OPTIONAL** but needed for complete analysis
5. **Validation runs automatically** at each step
6. **Check logs** if any step fails

---

## 🐛 Troubleshooting

### Pipeline stops at Step 1
- Check raw data file exists
- Verify column names match expected format
- Review validation log

### Pipeline stops at Step 4
- Ensure Step 1 completed successfully
- Check data file exists in `data/analysis_ready/`
- Review model fitting log for errors
- Verify R packages installed (brms, cmdstanr)

### Optional steps fail
- These are non-critical
- Pipeline continues even if they fail
- Check logs for details

---

## 📚 Related Documentation

- `NEXT_STEPS_AFTER_FIX.md` - Detailed implementation guide
- `PIPELINE_STRUCTURE_GUIDE.md` - Architecture details
- `SANITY_CHECKS_COMPLETE.md` - Validation system
- `VALIDATION_SYSTEM_SUMMARY.md` - Validation details

---

**Ready to run! Start with `run_complete_ddm_pipeline.R` for the full experience!** 🚀

