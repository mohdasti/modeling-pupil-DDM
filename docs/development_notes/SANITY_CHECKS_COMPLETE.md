# Sanity Checks & Validation System - Complete

**Date:** 2025-01-XX  
**Status:** ✅ Ready for Use

---

## 🎉 Summary

A comprehensive validation and sanity check system has been implemented throughout the DDM pipeline. Every step now includes professional-grade checks to ensure:

1. ✅ **Data integrity** - No mixing of conditions, correct coding
2. ✅ **Experimental design consistency** - Conditions match specifications
3. ✅ **Realistic DDM parameters** - Parameters match data reality
4. ✅ **Mathematical consistency** - No impossible values

---

## 🔍 Validation Components

### 1. Experimental Design Validation (`R/validate_experimental_design.R`)

**Checks at Data Preparation:**

- ✅ **Difficulty Level Assignments**
  - Standard trials have `isOddball == 0` (no oddball)
  - Hard/Easy trials have `isOddball == 1` (oddball present)
  - Stimulus levels match difficulty assignments
  - **CRITICAL:** No mixing of Standard and Easy/Hard conditions

- ✅ **Response-Side Coding**
  - `dec_upper` contains only 0, 1, or NA
  - Response labels match `dec_upper` coding
  - Standard trials show expected ~89% "same" bias
  - Easy trials have higher accuracy than Hard trials

- ✅ **RT Ranges**
  - All RTs within [0.25, 3.0] seconds
  - Easy trials faster than Hard trials (experimental constraint)
  - RT distributions by difficulty level

- ✅ **Effort Conditions**
  - Valid effort condition levels (Low_5_MVC, High_40_MVC)
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

**Checks After Model Fitting:**

- ✅ **Convergence Diagnostics**
  - Rhat ≤ 1.01
  - Bulk ESS ≥ 400
  - Tail ESS ≥ 400
  - No divergent transitions

- ✅ **Drift Rate (v)**
  - Within expected range [-3.0, 5.0]
  - **CRITICAL:** Standard trials have v ≈ 0 (within [-0.5, 0.5])
  - Difficulty effects in expected direction

- ✅ **Boundary Separation (a/bs)**
  - Within expected range [log(0.5), log(3.0)]
  - Close to typical value log(1.7) for older adults

- ✅ **Non-Decision Time (t₀/ndt)**
  - Within expected range [log(0.10), log(0.50)]
  - **CRITICAL:** Less than minimum RT (impossible otherwise!)
  - Close to typical value log(0.23) for response-signal design

- ✅ **Starting-Point Bias (z)**
  - Within expected range [-2.0, 2.0] on logit scale
  - **CRITICAL:** Matches data distribution
    - If data shows 89% "same", bias should be ~0.11 (NOT 0.567!)
  - Direction matches data (bias < 0.5 if data shows "same" bias)
  - Standard trial bias consistent with response proportions

---

## 🚨 Critical Sanity Checks

### 1. Standard Trials Response Distribution
**Check:** Standard trials should show ~85-90% "same" responses  
**Why:** Fundamental experimental constraint  
**Action:** **STOP** pipeline if this fails

### 2. Bias Parameter vs Data
**Check:** Bias estimate must match data distribution  
**Example:** If data shows 89% "same", bias should be ~0.11 (not 0.567!)  
**Why:** Mathematically impossible otherwise  
**Action:** **FLAG** as critical error

### 3. NDT < Minimum RT
**Check:** Non-decision time must be less than minimum RT  
**Why:** NDT cannot exceed RT by definition  
**Action:** **STOP** model fitting if this fails

### 4. Difficulty Level Consistency
**Check:** Standard trials have `isOddball=0`, Hard/Easy have `isOddball=1`  
**Why:** Ensures correct experimental condition assignment  
**Action:** **FLAG** mismatches for review

### 5. Easy vs Hard Accuracy
**Check:** Easy trials must have higher accuracy than Hard trials  
**Why:** Experimental design constraint  
**Action:** **FLAG** if violated (indicates coding error)

### 6. Easy vs Hard RT
**Check:** Easy trials must be faster than Hard trials  
**Why:** Easier discriminations = faster responses  
**Action:** **FLAG** if violated

---

## 📊 Integration Points

### Data Preparation Scripts

**`01_data_preprocessing/r/prepare_ddm_only_data.R`**
- ✅ Runs comprehensive validation after data preparation
- ✅ Creates validation log file: `logs/validation_YYYYMMDD_HHMMSS.log`
- ✅ Continues even if issues found (with warnings)
- ✅ **STOPS** if critical errors detected

**`01_data_preprocessing/r/prepare_ddm_pupil_data.R`**
- ✅ Same validation as DDM-only script
- ✅ Additional checks for pupil feature columns

### Model Fitting Scripts

**`04_computational_modeling/drift_diffusion/fit_primary_vza.R`**
- ✅ Runs parameter validation after model fitting
- ✅ Checks convergence diagnostics
- ✅ Validates all DDM parameters
- ✅ Creates validation log: `logs/param_validation_primary_vza_YYYYMMDD_HHMMSS.log`

**`04_computational_modeling/drift_diffusion/fit_standard_bias_only.R`**
- ✅ Same validation as primary model
- ✅ Additional focus on bias parameter validation
- ✅ Creates validation log: `logs/param_validation_standard_bias_YYYYMMDD_HHMMSS.log`

---

## 📋 Validation Output

### Log Files Created

**Data Preparation:**
- `logs/validation_YYYYMMDD_HHMMSS.log` - Experimental design validation
- `logs/ddm_only_data_prep_YYYYMMDD_HHMMSS.log` - Data prep log
- `logs/ddm_pupil_data_prep_YYYYMMDD_HHMMSS.log` - Pupil data prep log

**Model Fitting:**
- `logs/param_validation_primary_vza_YYYYMMDD_HHMMSS.log` - Parameter validation
- `logs/fit_primary_vza_YYYYMMDD_HHMMSS.log` - Model fitting log
- `logs/fit_standard_bias_YYYYMMDD_HHMMSS.log` - Bias model log

### Console Output

All validations print to console with:
- ✓ **Green checkmarks** for passed checks
- ✗ **Red X marks** for failed checks
- ⚠ **Yellow warnings** for issues that don't stop pipeline

---

## 🔧 Usage

### Automatic (Integrated)

Validation runs automatically when you run:
```bash
# Data preparation
Rscript 01_data_preprocessing/r/prepare_ddm_only_data.R

# Model fitting
Rscript 04_computational_modeling/drift_diffusion/fit_primary_vza.R
```

### Manual (Standalone)

```r
# Validate data file
source("R/validate_experimental_design.R")
result <- validate_ddm_data("data/analysis_ready/bap_ddm_only_ready.csv", 
                            "logs/validation.log")

# Validate model parameters
source("R/validate_ddm_parameters.R")
fit <- readRDS("output/models/primary_vza.rds")
data <- read_csv("data/analysis_ready/bap_ddm_only_ready.csv")
result <- validate_ddm_model(fit, data, "logs/param_validation.log")
```

### Command Line

```bash
# Validate data file
Rscript R/validate_experimental_design.R data/analysis_ready/bap_ddm_only_ready.csv logs/validation.log

# Validate model parameters
Rscript R/validate_ddm_parameters.R output/models/primary_vza.rds data/analysis_ready/bap_ddm_only_ready.csv logs/param_validation.log
```

---

## ✅ Pre-Flight Checklist

**Before Running Data Preparation:**
- [ ] Raw behavioral data file exists
- [ ] Column names match expected format
- [ ] `resp_is_diff` column present

**After Data Preparation:**
- [ ] Validation log created
- [ ] Standard trials show ~89% "same" responses
- [ ] Difficulty levels correctly assigned
- [ ] RT ranges are realistic
- [ ] Effort conditions match grip force
- [ ] Response-side coding verified (`dec_upper` correct)

**Before Model Fitting:**
- [ ] Data file validation passed
- [ ] All required columns present
- [ ] Factor levels correct

**After Model Fitting:**
- [ ] Convergence diagnostics pass (Rhat ≤ 1.01, ESS ≥ 400)
- [ ] NDT < minimum RT
- [ ] Bias estimate matches data distribution
- [ ] Standard trial drift ≈ 0
- [ ] Boundary separation reasonable (~1.7)
- [ ] No divergent transitions

---

## 🎓 Best Practices

1. **Always check validation logs** before proceeding to next step
2. **Fix critical errors** before model fitting
3. **Review warnings** - they may indicate issues
4. **Compare parameter estimates** to expected ranges
5. **Validate bias estimates** match data distributions
6. **Check convergence** before interpreting results
7. **Keep all log files** for reproducibility

---

## 📚 Related Documentation

- `VALIDATION_SYSTEM_SUMMARY.md` - Detailed validation system documentation
- `NEXT_STEPS_AFTER_FIX.md` - Implementation guide
- `PIPELINE_STRUCTURE_GUIDE.md` - Pipeline architecture
- `CRITICAL_CODING_ISSUES.md` - Technical analysis

---

## 🎯 What's Protected

The validation system ensures:

✅ **No condition mixing** - Standard and Easy/Hard trials correctly separated  
✅ **Correct coding** - Response-side coding matches data reality  
✅ **Realistic parameters** - DDM parameters within expected ranges  
✅ **Mathematical consistency** - No impossible values (e.g., NDT > RT)  
✅ **Data-model match** - Parameter estimates match data distributions  
✅ **Experimental constraints** - Easy > Hard accuracy, Easy < Hard RT  

---

**The pipeline is now production-ready with professional-grade validation at every step!**

**Ready to run in RStudio with confidence!** 🚀

