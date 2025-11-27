# Bias Models Resume Script

## Overview

The resume script (`R/resume_bias_models.R`) intelligently checks which steps are already completed and only runs missing steps. This allows you to safely run the analysis multiple times, resume after interruptions, or re-run specific steps.

## Quick Start

### Option 1: Run from RStudio
```r
source("run_resume_bias_models.R")
```

### Option 2: Run from Terminal
```bash
Rscript run_resume_bias_models.R
```

### Option 3: Run directly
```r
source("R/resume_bias_models.R")
```

## What It Does

The script checks for completion of each step by looking for output files:

1. **Step 1: Build decision boundary**
   - Checkpoint: `data/analysis_ready/bap_ddm_ready_with_upper.csv`
   - Required: ✅ Yes

2. **Step 2: Standard-only bias model**
   - Checkpoint: `output/publish/fit_standard_bias_only.rds`
   - Required: ✅ Yes
   - Estimated time: ~30-60 minutes

3. **Step 3: Joint model**
   - Checkpoint: `output/publish/fit_joint_vza_stdconstrained.rds`
   - Required: ❌ No (optional)
   - Estimated time: ~60-90 minutes
   - Note: May fail due to initialization issues

4. **Step 4: Summarize models**
   - Checkpoint: Multiple CSV files in `output/publish/`
   - Required: ❌ No (optional)
   - Depends on: Step 2 (and Step 3 if available)
   - Estimated time: ~2-5 minutes

5. **Step 5: PPC for joint model**
   - Checkpoint: `output/publish/ppc_joint_minimal.csv`
   - Required: ❌ No (optional)
   - Depends on: Step 3
   - Estimated time: ~10-20 minutes

## Features

- ✅ **Smart resume**: Automatically skips completed steps
- ✅ **Dependency checking**: Only runs steps when dependencies are met
- ✅ **Error handling**: Continues on optional step failures
- ✅ **Logging**: Detailed log file in `output/logs/`
- ✅ **Safe to re-run**: Can be executed multiple times

## Example Output

```
Checking completed steps...
✓ Step 1 already completed: Step 1: Build response-side decision boundary
✓ Step 2 already completed: Step 2: Standard-only bias calibration (v≈0)
○ Step 3 not completed: Step 3: Joint model with Standard drift constrained
○ Step 4 not completed: Step 4: Summarize and compare both models
○ Step 5 not completed: Step 5: Minimal PPC for joint model

Completed: 2/5 steps

>>> STEP 3/5 <<<
Running: Step 3: Joint model with Standard drift constrained
...
```

## Log Files

Log files are saved to `output/logs/bias_models_resume_YYYYMMDD_HHMMSS.log` with:
- Timestamp for each action
- Success/failure status
- Error messages (if any)
- Execution time for each step

## Troubleshooting

### Step 3 (Joint Model) Fails

This is expected - the joint model has initialization issues. The Standard-only model (Step 2) is sufficient for bias identification.

**Solution**: The script will continue and complete Steps 4 and 5 (if Step 3 completes) or just Step 4 (if Step 3 fails).

### Step 4 Fails Because Joint Model Missing

Step 4 is designed to work with only the Standard-only model. It will:
- Extract fixed effects from Standard-only model
- Extract bias parameters
- Compute LOO (if possible)
- Skip joint model comparisons

### Want to Re-run a Step?

Delete the checkpoint file and run the resume script again:
```r
# Re-run Step 2
file.remove("output/publish/fit_standard_bias_only.rds")
source("run_resume_bias_models.R")
```

## Current Status

Based on last check:
- ✅ Step 1: Completed
- ✅ Step 2: Completed  
- ○ Step 3: Needs run (optional)
- ○ Step 4: Needs run (will work with Step 2 only)
- ○ Step 5: Needs run (depends on Step 3)

## Running Overnight

The script is designed to run unattended:

1. **Start before leaving:**
   ```r
   source("run_resume_bias_models.R")
   ```

2. **Check log file in the morning:**
   ```bash
   tail -100 output/logs/bias_models_resume_*.log
   ```

3. **Check results:**
   ```r
   # Check what was created
   list.files("output/publish", pattern = "bias|standard|joint", full.names = TRUE)
   ```

## Notes

- The script will automatically detect the project root
- All paths are relative to project root
- Log files are timestamped for easy tracking
- The script is idempotent (safe to run multiple times)

