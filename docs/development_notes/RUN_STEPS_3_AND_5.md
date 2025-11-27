# Running Steps 3 and 5 Only

## Quick Start

Run this in RStudio:

```r
source("R/run_steps_3_and_5_only.R")
```

Or from terminal:

```bash
Rscript R/run_steps_3_and_5_only.R
```

## What Was Fixed

### Step 3 (Joint Model)
- **Error:** `object 'q5' not found`
- **Fix:** Changed `q5, q95` to `~quantile(.x, probs = c(0.05, 0.95))` in `summarise_draws()`

### Step 5 (PPC)
- **Error:** `'is_nonstd' variable not found`
- **Fix:** Added `is_nonstd` variable to data before generating predictions (matches model formula)

## What Will Happen

1. **Check prerequisites** (Steps 1 and 2 must be completed)
2. **Run Step 3** (Joint model - may take 60-90 minutes)
3. **If Step 3 succeeds**, run Step 5 (PPC - ~10-20 minutes)
4. **If Step 3 fails**, skip Step 5

## Expected Output

- Log file: `output/logs/steps_3_and_5_YYYYMMDD_HHMMSS.log`
- Step 3 output: `output/publish/fit_joint_vza_stdconstrained.rds`
- Step 5 output: `output/publish/ppc_joint_minimal.csv`

## Check Results

```r
# Check if Step 3 completed
file.exists("output/publish/fit_joint_vza_stdconstrained.rds")

# Check if Step 5 completed
file.exists("output/publish/ppc_joint_minimal.csv")

# View log
tail -50 output/logs/steps_3_and_5_*.log
```

## Notes

- Step 3 may still fail due to initialization issues (this is expected)
- If Step 3 fails, Step 5 will be skipped automatically
- The Standard-only model (Step 2) is sufficient for bias identification
- Step 3 is optional but provides joint model comparison
