# Bias Models Overnight Runner Scripts

Three scripts to run the 5 bias model prompts overnight in RStudio.

## Scripts Overview

### 1. `run_all_bias_models_overnight.R` (Recommended for fully automated run)
**Best for**: Fully automated overnight run with logging

- Runs all 5 steps sequentially
- Comprehensive logging to `output/logs/`
- Stops on first failure (prevents wasting time)
- Shows progress and final summary
- **Run in RStudio**: Source the file or run `source("R/run_all_bias_models_overnight.R")`

**Estimated time**: 
- Step 1: ~1 minute
- Step 2: ~2-4 hours (Standard-only model)
- Step 3: ~3-6 hours (Joint model)
- Step 4: ~5-10 minutes
- Step 5: ~10-30 minutes
- **Total: ~5-10 hours**

### 2. `run_bias_models_step_by_step.R` (Recommended for manual control)
**Best for**: Manual control, resuming after failures, checking progress

- Interactive prompts for each step
- Checkpoint system (saves progress)
- Can skip steps that already completed
- Can resume from last checkpoint
- Checks dependencies before running
- **Run in RStudio**: Source the file interactively

**Use when**:
- You want to monitor progress
- You need to stop and resume later
- You want to skip steps that already completed

### 3. `run_bias_models_parallel.R` (Fastest, but requires 2+ cores)
**Best for**: Fastest execution if you have multiple CPU cores

- Runs Steps 2 & 3 in parallel (saves ~2-4 hours)
- Requires 2+ CPU cores
- Steps 1, 4, 5 run sequentially
- **Run in RStudio**: Source the file

**Use when**:
- You have 2+ CPU cores available
- You want fastest execution
- You're okay with higher CPU usage

## Steps Overview

1. **PROMPT 1**: Build response-side decision boundary (`00_build_decision_upper_diff.R`)
   - Quick (~1 min)
   - Creates `bap_ddm_ready_with_upper.csv`

2. **PROMPT 2**: Standard-only bias calibration (`fit_standard_bias_only.R`)
   - Long (~2-4 hours)
   - Creates `fit_standard_bias_only.rds`

3. **PROMPT 3**: Joint model with Standard drift constrained (`fit_joint_vza_standard_constrained.R`)
   - Long (~3-6 hours)
   - Creates `fit_joint_vza_stdconstrained.rds`

4. **PROMPT 4**: Summarize and compare (`summarize_bias_and_compare.R`)
   - Quick (~5-10 min)
   - Depends on Steps 2 & 3
   - Creates summary CSVs

5. **PROMPT 5**: Minimal PPC (`ppc_joint_minimal.R`)
   - Medium (~10-30 min)
   - Depends on Step 3
   - Creates `ppc_joint_minimal.csv`

## How to Run in RStudio

### Option A: Fully Automated (Recommended)
```r
# In RStudio, open and source:
source("R/run_all_bias_models_overnight.R")
```

### Option B: Interactive Step-by-Step
```r
# In RStudio, open and source:
source("R/run_bias_models_step_by_step.R")
# Follow prompts for each step
```

### Option C: Parallel (Fastest)
```r
# In RStudio, open and source:
source("R/run_bias_models_parallel.R")
```

## Before Running

1. **Ensure data file exists**: `data/analysis_ready/bap_ddm_ready.csv`
2. **Install required packages**: `brms`, `cmdstanr`, `posterior`, `loo`, `dplyr`, `readr`
3. **Check Stan/CmdStan**: Make sure CmdStan is installed and working
4. **Free up memory**: Close other R sessions if needed
5. **Check disk space**: Models can be large (~100-500 MB each)

## Monitoring Progress

- **Logs**: Check `output/logs/bias_models_run_YYYYMMDD_HHMMSS.log`
- **Checkpoints**: Check `output/logs/bias_models_checkpoint.RData` (step-by-step script)
- **Model files**: Check if `.rds` files are being created in `output/publish/`
- **RStudio Console**: Watch for progress messages

## Troubleshooting

### If a step fails:
1. Check the log file for error messages
2. For step-by-step script: You can resume from checkpoint
3. For overnight script: Fix the issue and re-run (it will skip completed steps if outputs exist)

### If models are taking too long:
- Check `adapt_delta` and `max_treedepth` in model scripts
- Consider reducing `iter` and `warmup` for testing
- Check CPU/memory usage

### If you run out of memory:
- Close other applications
- Reduce `ndraws` in PPC script
- Run steps individually instead of all at once

## Expected Output Files

After successful completion, you should have:

1. `data/analysis_ready/bap_ddm_ready_with_upper.csv`
2. `output/publish/fit_standard_bias_only.rds`
3. `output/publish/fit_joint_vza_stdconstrained.rds`
4. `output/publish/fixed_effects_standard_bias_only.csv`
5. `output/publish/fixed_effects_joint_vza_stdconstrained.csv`
6. `output/publish/v_standard_joint.csv`
7. `output/publish/bias_standard_bias_only.csv`
8. `output/publish/bias_joint_vza_stdconstrained.csv`
9. `output/publish/loo_standard_bias_only.csv` (if LOO computed)
10. `output/publish/loo_joint_vza_stdconstrained.csv` (if LOO computed)
11. `output/publish/ppc_joint_minimal.csv`

## Notes

- **RStudio**: Keep RStudio open during execution
- **Sleep mode**: Prevent computer from sleeping (models need to run continuously)
- **Power**: Keep computer plugged in if laptop
- **Time**: Start before you go to sleep - models will run 5-10 hours

