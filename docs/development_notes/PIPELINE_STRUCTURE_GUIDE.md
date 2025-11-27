# Professional DDM Pipeline Structure Guide

**Version:** 2.0  
**Last Updated:** 2025-01-XX  
**Purpose:** Comprehensive guide to the reproducible 7-step DDM analysis pipeline

---

## 🏗️ Pipeline Architecture

### 7-Step Structure

```
modeling-pupil-DDM/
├── 01_data_preprocessing/          # Step 1: Data cleaning & preparation
│   └── r/
│       ├── prepare_ddm_only_data.R      # DDM-only path (no pupil)
│       └── prepare_ddm_pupil_data.R     # DDM-pupil path (with pupil)
│
├── 02_pupillometry_analysis/        # Step 2: Pupil feature extraction
│   └── (runs separately)
│
├── 03_behavioral_analysis/          # Step 3: Behavioral modeling
│   └── (runs separately)
│
├── 04_computational_modeling/       # Step 4: DDM model fitting
│   └── drift_diffusion/
│       ├── fit_standard_bias_only.R     # Standard-only bias model
│       └── fit_primary_vza.R            # Primary model (v+z+a)
│
├── 05_statistical_analysis/        # Step 5: Statistical tests & contrasts
│   └── (runs separately)
│
├── 06_visualization/                # Step 6: Figure generation
│   └── (runs separately)
│
├── 07_manuscript/                   # Step 7: Report generation
│   └── (runs separately)
│
├── run_ddm_pipeline.R              # Master pipeline runner
├── logs/                            # All log files (timestamped)
└── data/analysis_ready/             # Prepared data files
```

---

## 📊 Data Flow

### DDM-Only Path (Independent)

```
Raw Behavioral Data
    ↓
[Step 1A] prepare_ddm_only_data.R
    ↓
bap_ddm_only_ready.csv
    ↓
[Step 4] Model Fitting Scripts
    ↓
output/models/
```

**Advantages:**
- No dependency on pupil processing
- Faster data preparation
- Can run DDM analyses immediately

### DDM-Pupil Path (Integrated)

```
Raw Behavioral Data + Pupil Flat Files
    ↓
[Step 1B] prepare_ddm_pupil_data.R
    ↓
bap_ddm_pupil_ready.csv (with pupil features)
    ↓
[Step 4] Model Fitting Scripts
    ↓
output/models/
```

**Advantages:**
- Includes pupil features for later integration
- Ready for pupil-DDM analyses
- Single combined dataset

---

## 🔑 Key Features

### 1. Response-Side Coding

**All data files use:**
- `dec_upper`: Explicit integer (1="different", 0="same")
- `resp_is_diff`: Direct response choice from raw data
- `response_label`: Human-readable ("different"/"same")

**NOT accuracy coding:**
- ❌ `decision = iscorr` (1=correct, 0=incorrect)
- ✅ `dec_upper = resp_is_diff` (1="different", 0="same")

### 2. Professional Logging

**Every script:**
- Creates timestamped log file in `logs/` directory
- Logs all major steps with timestamps
- Includes error handling and warnings
- Provides runtime statistics

**Log Format:**
```
[YYYY-MM-DD HH:MM:SS] [LEVEL] Message
```

### 3. Validation Checks

**Data preparation scripts:**
- Verify `dec_upper` coding (only 0, 1, or NA)
- Check Standard trials distribution (~89% "same")
- Validate direct vs inferred coding match
- Report any mismatches or issues

**Model fitting scripts:**
- Verify data file exists
- Check required columns present
- Validate factor levels
- Check convergence diagnostics

### 4. Error Handling

**All scripts include:**
- Try-catch blocks for critical operations
- Informative error messages
- Graceful failure with logging
- Exit codes for pipeline automation

---

## 🚀 Usage

### Quick Start (DDM-Only)

```bash
# 1. Prepare data
Rscript 01_data_preprocessing/r/prepare_ddm_only_data.R

# 2. Fit Standard-only bias model
Rscript 04_computational_modeling/drift_diffusion/fit_standard_bias_only.R

# 3. Fit Primary model
Rscript 04_computational_modeling/drift_diffusion/fit_primary_vza.R
```

### Master Pipeline

```bash
# Run complete pipeline
Rscript run_ddm_pipeline.R
```

This will:
1. Prepare both DDM-only and DDM-pupil data (if available)
2. Fit Standard-only bias model
3. Fit Primary model
4. Generate comprehensive logs

---

## 📝 Script Conventions

### Naming
- Scripts: `verb_noun.R` (e.g., `fit_primary_vza.R`)
- Logs: `script_name_YYYYMMDD_HHMMSS.log`
- Data: `bap_ddm_[only|pupil]_ready.csv`

### Structure
Every script follows this structure:
1. Configuration & logging setup
2. Data loading with validation
3. Data preparation/transformation
4. Model definition
5. Model fitting
6. Diagnostics
7. Results saving
8. Final summary

### Logging
- Start: Header with script name, timestamp, paths
- Steps: Numbered steps with clear descriptions
- Progress: Timestamps for major operations
- End: Summary with elapsed time

---

## 🔍 Verification

### Data File Verification

```r
library(readr)
library(dplyr)

dd <- read_csv("data/analysis_ready/bap_ddm_only_ready.csv", show_col_types=FALSE)

# Check 1: dec_upper coding
table(dd$dec_upper, useNA="always")  # Should be only 0, 1, or NA

# Check 2: Standard trials
std <- dd %>% filter(difficulty_level == "Standard")
mean(std$dec_upper)  # Should be ~0.11 (11% "different")

# Check 3: Response labels match
all(dd$dec_upper[dd$response_label=="different"] == 1, na.rm=TRUE)
all(dd$dec_upper[dd$response_label=="same"] == 0, na.rm=TRUE)
```

### Model Verification

After fitting, check log files for:
- Convergence diagnostics (Rhat ≤ 1.01, ESS ≥ 400)
- Bias estimates (should be < 0.5 for Standard trials)
- Runtime statistics
- Any warnings or errors

---

## 📚 Documentation Files

- `NEXT_STEPS_AFTER_FIX.md`: Implementation guide
- `PIPELINE_STRUCTURE_GUIDE.md`: This file
- `CRITICAL_CODING_ISSUES.md`: Technical analysis
- `IMPLEMENTATION_SUMMARY.md`: Change summary
- `README.md`: Project overview

---

## 🎯 Best Practices

1. **Always check logs first** when debugging
2. **Verify data files** before model fitting
3. **Use DDM-only path** for initial analyses
4. **Run Standard-only bias model first** to validate coding
5. **Check bias estimates** match expected values (< 0.5)
6. **Keep logs** for reproducibility
7. **Follow 7-step structure** for organization

---

## 🔄 Migration from Old Structure

**Old scripts location:**
- `R/fit_primary_vza.R`
- `R/fit_standard_bias_only.R`
- `prepare_fresh_data.R`

**New scripts location:**
- `04_computational_modeling/drift_diffusion/fit_primary_vza.R`
- `04_computational_modeling/drift_diffusion/fit_standard_bias_only.R`
- `01_data_preprocessing/r/prepare_ddm_only_data.R`
- `01_data_preprocessing/r/prepare_ddm_pupil_data.R`

**Action:** Update any scripts that call the old locations, or remove old scripts after verification.

---

## ✅ Quality Assurance

All scripts include:
- ✅ Comprehensive logging
- ✅ Validation checks
- ✅ Error handling
- ✅ Timestamp tracking
- ✅ Professional documentation
- ✅ Reproducible structure

---

**This pipeline is production-ready and follows professional software development practices.**

