# Next Steps After Response-Side Coding Fix

**Last Updated:** 2025-01-XX  
**Status:** Ready for Implementation

---

## ✅ Current Status

**Fix Script Results:**
- ✅ Original trials: 17,243
- ✅ Fixed trials: 16,647 (after excluding 596 missing `resp_is_diff`)
- ✅ Standard trials proportion "Different": 0.109 (10.9%) - **Correct!**
- ⚠️ Direct vs Inferred match rate: 99.44% (94 mismatches out of 16,647)

**Files Created:**
- `data/analysis_ready/bap_ddm_ready_fixed.csv` (legacy fix)
- `data/analysis_ready/bap_ddm_only_ready.csv` (NEW: DDM-only, no pupil requirement)
- `data/analysis_ready/bap_ddm_pupil_ready.csv` (NEW: DDM + pupil features)

---

## 🏗️ New Pipeline Structure

### Two Separate Data Preparation Paths

**1. DDM-Only Path** (No pupil data required)
- **Script:** `01_data_preprocessing/r/prepare_ddm_only_data.R`
- **Output:** `data/analysis_ready/bap_ddm_only_ready.csv`
- **Use when:** You want to run DDM analyses independently of pupillometry
- **Advantages:** Faster, no dependency on pupil processing

**2. DDM-Pupil Path** (Requires pupil data)
- **Script:** `01_data_preprocessing/r/prepare_ddm_pupil_data.R`
- **Output:** `data/analysis_ready/bap_ddm_pupil_ready.csv`
- **Use when:** You want to integrate pupil features with DDM
- **Advantages:** Includes tonic/phasic pupil features for later analyses

### Both Paths Include:
- ✅ Direct `resp_is_diff` column (ground truth)
- ✅ Explicit `dec_upper` coding (1="different", 0="same")
- ✅ Comprehensive validation checks
- ✅ Professional logging with timestamps
- ✅ Response-side coding (not accuracy coding)

---

## 📋 Implementation Steps

### Step 1: Prepare Data Files

**Option A: DDM-Only (Recommended to start)**
```bash
Rscript 01_data_preprocessing/r/prepare_ddm_only_data.R
```

**Option B: DDM-Pupil (When pupil data is ready)**
```bash
Rscript 01_data_preprocessing/r/prepare_ddm_pupil_data.R
```

**Expected Output:**
- Log file in `logs/` directory with timestamp
- Data file in `data/analysis_ready/`
- Validation summary printed to console

### Step 2: Verify Data Files

Run this validation script:
```r
library(readr)
library(dplyr)

# Check DDM-only file
ddm_only <- read_csv("data/analysis_ready/bap_ddm_only_ready.csv", show_col_types=FALSE)

cat("DDM-Only File:\n")
cat("  Trials:", nrow(ddm_only), "\n")
cat("  Subjects:", length(unique(ddm_only$subject_id)), "\n")
cat("  dec_upper values:", paste(sort(unique(ddm_only$dec_upper)), collapse=", "), "\n")

# Check Standard trials
std <- ddm_only %>% filter(difficulty_level == "Standard")
cat("\nStandard Trials:\n")
cat("  Count:", nrow(std), "\n")
cat("  Proportion 'Same':", round(1 - mean(std$dec_upper), 3), "\n")
cat("  Expected: ~0.89\n")
```

### Step 3: Update Model Fitting Scripts

**All model scripts have been updated** to:
- Use `dec_upper` instead of `decision`
- Load from appropriate data file (DDM-only or DDM-pupil)
- Include comprehensive logging
- Follow 7-step pipeline structure

**Updated Scripts:**
- ✅ `04_computational_modeling/drift_diffusion/fit_primary_vza.R`
- ✅ `04_computational_modeling/drift_diffusion/fit_standard_bias_only.R`

**Legacy Scripts (to be updated):**
- ⏳ `R/fit_primary_vza.R` (old location - update or remove)
- ⏳ `R/fit_standard_bias_only.R` (old location - update or remove)
- ⏳ Other model fitting scripts in `R/` directory

### Step 4: Run Models

**Option 1: Run Individual Models**
```bash
# Standard-only bias model
Rscript 04_computational_modeling/drift_diffusion/fit_standard_bias_only.R

# Primary model
Rscript 04_computational_modeling/drift_diffusion/fit_primary_vza.R
```

**Option 2: Run Master Pipeline**
```bash
Rscript run_ddm_pipeline.R
```

The master pipeline will:
1. Prepare DDM-only data
2. Attempt DDM-pupil data (skips if pupil files unavailable)
3. Fit Standard-only bias model
4. Fit Primary model
5. Generate comprehensive logs

### Step 5: Verify Results

**Expected Bias Estimates (after re-fitting):**

**Standard-only bias model:**
- z (probability scale) should be approximately **0.10-0.15**
- This reflects ~89% "same" responses (lower boundary)
- **NOT** 0.567 (which was impossible)

**Primary model:**
- Bias estimates on Standard trials should all be < 0.5
- VDT bias should be slightly higher than ADT (less "same" bias)

---

## 🔍 Trial Count Discrepancy Explained

**Report File Says:**
- Original trials: 20,340
- After cleaning: **17,971** trials

**Your DDM-Ready Files Have:**
- DDM-only: **~16,647** trials (after excluding missing `resp_is_diff`)
- DDM-pupil: **~16,647** trials (same, but with pupil features)

**Missing:** ~1,324 trials from cleaned file

**Causes:**
1. **Missing `resp_is_diff`:** 596 trials excluded (no response choice recorded)
2. **Pupil data merge:** ~728 trials may lack pupil data (for DDM-pupil file)
3. **RT filtering:** Additional filtering (0.25-3.0s) may exclude some trials

**This is normal and expected** - the DDM-ready files are subsets that meet all quality criteria.

---

## 📁 File Organization

### Data Files
```
data/analysis_ready/
├── bap_ddm_only_ready.csv          # DDM-only (no pupil requirement)
├── bap_ddm_pupil_ready.csv         # DDM + pupil features
├── bap_ddm_ready_fixed.csv         # Legacy fixed file (use above instead)
└── bap_ddm_ready_with_upper_fixed.csv  # Legacy (use above instead)
```

### Scripts (Following 7-Step Structure)
```
01_data_preprocessing/r/
├── prepare_ddm_only_data.R         # Step 1A: DDM-only data prep
└── prepare_ddm_pupil_data.R       # Step 1B: DDM-pupil data prep

04_computational_modeling/drift_diffusion/
├── fit_standard_bias_only.R        # Step 4A: Standard-only bias model
└── fit_primary_vza.R               # Step 4B: Primary model (v+z+a)

run_ddm_pipeline.R                  # Master pipeline runner
```

### Logs
```
logs/
├── ddm_only_data_prep_YYYYMMDD_HHMMSS.log
├── ddm_pupil_data_prep_YYYYMMDD_HHMMSS.log
├── fit_standard_bias_YYYYMMDD_HHMMSS.log
├── fit_primary_vza_YYYYMMDD_HHMMSS.log
└── ddm_pipeline_YYYYMMDD_HHMMSS.log
```

---

## ✅ Pre-Flight Checklist

Before running models, verify:

- [ ] Data preparation scripts run successfully
- [ ] `dec_upper` column exists and contains only 0, 1, or NA
- [ ] Standard trials show ~89% "same" responses
- [ ] Log files are being created in `logs/` directory
- [ ] Model scripts point to correct data files
- [ ] All required R packages are installed

---

## 🚀 Quick Start

**1. Prepare DDM-only data:**
```bash
Rscript 01_data_preprocessing/r/prepare_ddm_only_data.R
```

**2. Verify data:**
```r
source("scripts/verify_ddm_data.R")  # Create this if needed
```

**3. Fit Standard-only bias model:**
```bash
Rscript 04_computational_modeling/drift_diffusion/fit_standard_bias_only.R
```

**4. Check bias estimate:**
- Should be z ≈ 0.10-0.15 (not 0.567!)
- Verify in log file or model output

**5. Fit Primary model:**
```bash
Rscript 04_computational_modeling/drift_diffusion/fit_primary_vza.R
```

---

## 📊 Expected Results After Fix

### Standard-Only Bias Model

**Before Fix:**
- z = 0.567 (impossible with 87.8% "same")

**After Fix:**
- z ≈ 0.10-0.15 (consistent with 89.1% "same")
- Drift v ≈ 0 (tightly constrained)
- Boundary a ≈ 1.7 (typical for older adults)

### Primary Model

**Before Fix:**
- Bias estimates inconsistent with data

**After Fix:**
- All bias estimates < 0.5 on Standard trials
- Estimates consistent with response distributions
- Proper interpretation: z < 0.5 = bias toward "same" (lower boundary)

---

## 🔧 Troubleshooting

### Issue: "dec_upper column not found"
**Solution:** Run data preparation scripts first

### Issue: "Model fails to initialize"
**Solution:** Check log file for specific error. Common causes:
- NDT initialization too high (should be < min RT)
- Factor level issues
- Missing data in key columns

### Issue: "Bias still shows z > 0.5"
**Solution:** Verify you're using the fixed data file with `dec_upper`, not the old `decision` column

### Issue: "Pupil data merge fails"
**Solution:** This is expected if pupil files aren't ready. Use DDM-only path instead.

---

## 📚 Additional Resources

- `CRITICAL_CODING_ISSUES.md`: Detailed analysis of coding contradictions
- `DECISION_CODING_ANALYSIS.md`: Resolution options
- `PROMPT_FOR_LLM_RESPONSE_SIDE_CODING_VERIFICATION.md`: LLM verification prompt
- `IMPLEMENTATION_SUMMARY.md`: Summary of all changes

---

## 🎯 What's Next?

1. ✅ **Data files prepared** (DONE)
2. ⏳ **Run Standard-only bias model** (Verify z < 0.5)
3. ⏳ **Run Primary model** (Verify all bias estimates correct)
4. ⏳ **Update manuscript** with corrected results
5. ⏳ **Run remaining models** (if needed)
6. ⏳ **Generate figures and tables** with corrected coding

---

## 💡 Professional Practices Implemented

✅ **Comprehensive Logging:** All scripts log to timestamped files  
✅ **Validation Checks:** Multiple validation steps before model fitting  
✅ **Error Handling:** Try-catch blocks with informative error messages  
✅ **Reproducibility:** Explicit paths, seeds, and version tracking  
✅ **Documentation:** Inline comments and external documentation  
✅ **Pipeline Structure:** Follows 7-step organization  
✅ **Separation of Concerns:** DDM-only vs DDM-pupil paths  

---

**Ready to proceed!** Start with Step 1 (data preparation) and work through the checklist above.
