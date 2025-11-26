# Run Pipeline Steps Individually

**Why?** Running all steps at once can be too heavy for RStudio. Run them step-by-step instead.

---

## 🎯 Quick Start: Run Steps One at a Time

### Step 1: Prepare Data (REQUIRED FIRST)

```r
source("01_data_preprocessing/r/prepare_ddm_only_data.R")
```

**What it does:**
- Loads raw behavioral data
- Creates DDM-ready dataset
- Validates data integrity
- Creates `data/analysis_ready/bap_ddm_only_ready.csv`

**Time:** ~1-2 minutes

---

### Step 2: Verify Data (RECOMMENDED)

```r
source("scripts/verify_ddm_data.R")
```

**What it does:**
- Checks data file exists
- Verifies `dec_upper` coding
- Validates Standard trial distributions

**Time:** ~5 seconds

---

### Step 3: Behavioral Analysis (OPTIONAL but Recommended)

```r
source("03_behavioral_analysis/reaction_time/run_rt_analysis.R")
```

**What it does:**
- Creates RT distribution plots
- Sanity checks
- Diagnostic visualizations

**Time:** ~1-2 minutes

---

### Step 4A: Fit Standard-Only Bias Model (RECOMMENDED FIRST)

```r
source("04_computational_modeling/drift_diffusion/fit_standard_bias_only.R")
```

**What it does:**
- Fits DDM to Standard trials only
- Estimates bias parameter
- Validates parameter estimates

**Time:** ~30-60 minutes

**Prerequisite:** Step 1 must complete successfully

---

### Step 4B: Fit Primary Model (REQUIRED)

```r
source("04_computational_modeling/drift_diffusion/fit_primary_vza.R")
```

**What it does:**
- Fits full hierarchical DDM model
- Estimates drift, boundary, bias, NDT
- Validates all parameters

**Time:** ~30-60 minutes

**Prerequisite:** Step 1 must complete successfully

---

## 📋 Recommended Order for First Run

1. **Step 1:** Prepare data
   ```r
   source("01_data_preprocessing/r/prepare_ddm_only_data.R")
   ```

2. **Verify:** Check data is ready
   ```r
   source("scripts/verify_ddm_data.R")
   ```

3. **Step 3:** Behavioral checks (optional)
   ```r
   source("03_behavioral_analysis/reaction_time/run_rt_analysis.R")
   ```

4. **Step 4A:** Fit Standard bias model
   ```r
   source("04_computational_modeling/drift_diffusion/fit_standard_bias_only.R")
   ```
   
   **Wait for this to finish before proceeding!**

5. **Step 4B:** Fit Primary model
   ```r
   source("04_computational_modeling/drift_diffusion/fit_primary_vza.R")
   ```

---

## 💡 Tips

1. **Run steps in separate R sessions** if memory is an issue
2. **Check logs** after each step in `logs/` directory
3. **Verify outputs** exist before running next step
4. **Take breaks** between model fitting steps (they're long!)

---

## 🔍 Check What Was Created

After each step, verify outputs:

**After Step 1:**
- `data/analysis_ready/bap_ddm_only_ready.csv` exists

**After Step 4A:**
- `output/models/standard_bias_only.rds` exists

**After Step 4B:**
- `output/models/primary_vza.rds` exists

---

## 📝 Example Workflow

```r
# Morning: Prepare data
source("01_data_preprocessing/r/prepare_ddm_only_data.R")
source("scripts/verify_ddm_data.R")

# Afternoon: Fit Standard bias model (run and go do something else)
source("04_computational_modeling/drift_diffusion/fit_standard_bias_only.R")

# Later: Fit Primary model (run and go do something else)
source("04_computational_modeling/drift_diffusion/fit_primary_vza.R")

# Next day: Statistical analysis and visualization
source("scripts/02_statistical_analysis/02_ddm_analysis.R")
source("scripts/02_statistical_analysis/create_results_visualizations.R")
```

---

**Much safer than running everything at once!** 🚀

