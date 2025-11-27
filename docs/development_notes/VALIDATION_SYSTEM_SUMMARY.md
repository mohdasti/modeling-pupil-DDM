# Comprehensive Validation System Summary

**Date:** 2025-01-XX  
**Purpose:** Professional-grade validation checks for DDM pipeline

---

## 🎯 Overview

A comprehensive validation system has been implemented to ensure data integrity, experimental design consistency, and realistic DDM parameter estimates at every step of the pipeline.

---

## 📋 Validation Components

### 1. Experimental Design Validation (`R/validate_experimental_design.R`)

**Purpose:** Validates that data matches experimental design specifications

**Checks:**
- ✅ **Difficulty Level Assignments**
  - Standard trials have `isOddball == 0`
  - Hard/Easy trials have `isOddball == 1`
  - Stimulus levels match difficulty assignments
  - No mixing of Standard and Easy/Hard conditions

- ✅ **Response-Side Coding**
  - `dec_upper` contains only 0, 1, or NA
  - Response labels match `dec_upper` coding
  - Standard trials show expected ~89% "same" bias
  - Easy trials have higher accuracy than Hard trials

- ✅ **RT Ranges**
  - All RTs within [0.25, 3.0] seconds
  - Easy trials faster than Hard trials
  - RT distributions by difficulty level

- ✅ **Effort Conditions**
  - Valid effort condition levels
  - Grip force matches effort condition (0.05 vs 0.40)

- ✅ **Task Consistency**
  - Valid task levels (ADT, VDT)
  - Task distribution checks

- ✅ **Subject Consistency**
  - Subject ID validation
  - Trial counts per subject
  - Flag subjects with suspiciously few trials

---

### 2. DDM Parameter Validation (`R/validate_ddm_parameters.R`)

**Purpose:** Validates that DDM parameter estimates are realistic and consistent with data

**Checks:**
- ✅ **Convergence Diagnostics**
  - Rhat ≤ 1.01
  - Bulk ESS ≥ 400
  - Tail ESS ≥ 400
  - No divergent transitions

- ✅ **Drift Rate (v)**
  - Within expected range [-3.0, 5.0]
  - Standard trials have v ≈ 0 (within [-0.5, 0.5])
  - Difficulty effects in expected direction

- ✅ **Boundary Separation (a/bs)**
  - Within expected range [log(0.5), log(3.0)]
  - Close to typical value log(1.7) for older adults
  - Reasonable for experimental design

- ✅ **Non-Decision Time (t₀/ndt)**
  - Within expected range [log(0.10), log(0.50)]
  - **CRITICAL:** Less than minimum RT (impossible otherwise!)
  - Close to typical value log(0.23) for response-signal design

- ✅ **Starting-Point Bias (z)**
  - Within expected range [-2.0, 2.0] on logit scale
  - **CRITICAL:** Matches data distribution
    - If data shows 89% "same", bias should be ~0.11 (not 0.567!)
  - Direction matches data (bias < 0.5 if data shows "same" bias)
  - Standard trial bias consistent with response proportions

---

## 🔄 Integration Points

### Data Preparation Scripts

**`01_data_preprocessing/r/prepare_ddm_only_data.R`**
- Runs comprehensive validation after data preparation
- Creates validation log file
- Continues even if issues found (with warnings)
- Stops if critical errors detected

**`01_data_preprocessing/r/prepare_ddm_pupil_data.R`**
- Same validation as DDM-only script
- Additional checks for pupil feature columns

### Model Fitting Scripts

**`04_computational_modeling/drift_diffusion/fit_primary_vza.R`**
- Runs parameter validation after model fitting
- Checks convergence diagnostics
- Validates all DDM parameters
- Creates separate validation log file

**`04_computational_modeling/drift_diffusion/fit_standard_bias_only.R`**
- Same validation as primary model
- Additional focus on bias parameter validation

---

## 🚨 Critical Checks

### 1. Standard Trials Response Distribution
**Check:** Standard trials should show ~85-90% "same" responses  
**Why:** This is a fundamental constraint - if violated, coding is wrong  
**Action:** Stop pipeline if this fails

### 2. Bias Parameter vs Data
**Check:** Bias estimate must match data distribution  
**Example:** If data shows 89% "same", bias should be ~0.11 (not 0.567!)  
**Why:** Mathematically impossible otherwise  
**Action:** Flag as critical error

### 3. NDT < Minimum RT
**Check:** Non-decision time must be less than minimum RT  
**Why:** NDT cannot exceed RT by definition  
**Action:** Stop model fitting if this fails

### 4. Difficulty Level Consistency
**Check:** Standard trials have `isOddball=0`, Hard/Easy have `isOddball=1`  
**Why:** Ensures correct experimental condition assignment  
**Action:** Flag mismatches for review

### 5. Easy vs Hard Accuracy
**Check:** Easy trials must have higher accuracy than Hard trials  
**Why:** Experimental design constraint  
**Action:** Flag if violated (indicates coding error)

---

## 📊 Validation Output

### Log Files

**Data Preparation:**
- `logs/validation_YYYYMMDD_HHMMSS.log` - Experimental design validation
- `logs/ddm_only_data_prep_YYYYMMDD_HHMMSS.log` - Data prep log

**Model Fitting:**
- `logs/param_validation_primary_vza_YYYYMMDD_HHMMSS.log` - Parameter validation
- `logs/fit_primary_vza_YYYYMMDD_HHMMSS.log` - Model fitting log

### Console Output

All validations print to console with:
- ✓ Green checkmarks for passed checks
- ✗ Red X marks for failed checks
- ⚠ Yellow warnings for issues that don't stop pipeline

---

## 🔍 Usage Examples

### Validate Data File
```r
source("R/validate_experimental_design.R")
result <- validate_ddm_data("data/analysis_ready/bap_ddm_only_ready.csv", 
                            "logs/validation.log")
```

### Validate Model Parameters
```r
source("R/validate_ddm_parameters.R")
fit <- readRDS("output/models/primary_vza.rds")
data <- read_csv("data/analysis_ready/bap_ddm_only_ready.csv")
result <- validate_ddm_model(fit, data, "logs/param_validation.log")
```

### Standalone Validation Script
```bash
# Validate data file
Rscript R/validate_experimental_design.R data/analysis_ready/bap_ddm_only_ready.csv logs/validation.log

# Validate model parameters
Rscript R/validate_ddm_parameters.R output/models/primary_vza.rds data/analysis_ready/bap_ddm_only_ready.csv logs/param_validation.log
```

---

## ✅ Validation Checklist

Before running models, ensure:

- [ ] Data preparation validation passes
- [ ] Standard trials show ~89% "same" responses
- [ ] Difficulty levels correctly assigned
- [ ] RT ranges are realistic
- [ ] Effort conditions match grip force
- [ ] Response-side coding verified (`dec_upper` correct)

After model fitting, verify:

- [ ] Convergence diagnostics pass (Rhat ≤ 1.01, ESS ≥ 400)
- [ ] NDT < minimum RT
- [ ] Bias estimate matches data distribution
- [ ] Standard trial drift ≈ 0
- [ ] Boundary separation reasonable (~1.7)
- [ ] No divergent transitions

---

## 🎓 Best Practices

1. **Always check validation logs** before proceeding
2. **Fix critical errors** before model fitting
3. **Review warnings** - they may indicate issues
4. **Compare parameter estimates** to expected ranges
5. **Validate bias estimates** match data distributions
6. **Check convergence** before interpreting results

---

## 📚 Related Documentation

- `NEXT_STEPS_AFTER_FIX.md` - Implementation guide
- `PIPELINE_STRUCTURE_GUIDE.md` - Pipeline architecture
- `CRITICAL_CODING_ISSUES.md` - Technical analysis

---

**This validation system ensures professional-grade quality control at every step of the pipeline.**

