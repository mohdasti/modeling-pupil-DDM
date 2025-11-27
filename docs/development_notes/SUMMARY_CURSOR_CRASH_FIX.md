# Cursor Crash Issue - Summary & Solution

## 🐛 Problem Identified

**Symptom:** Cursor freezes or crashes when running `02_ddm_analysis.R`

**Root Cause:**
- `brms` Wiener models compile massive C++ code via Stan
- With `cores = 4`, this creates 4 parallel compilation processes
- Each compilation uses 500MB-2GB RAM and 100% CPU
- Total: 2-8GB RAM + 400% CPU usage
- This overwhelms Cursor's renderer/process limits
- Result: Cursor hangs or crashes

**Additional Issues:**
- System sleep aborts the analysis mid-run
- No easy way to monitor background progress
- Hard to know if analysis is still running

---

## ✅ Solutions Implemented

### 1. Safe Background Runner (`run_ddm_no_cursor.sh`)

**Features:**
- Limits thread usage to prevent resource exhaustion
- Uses `caffeinate` to prevent system sleep
- Runs in background with `nohup`
- Saves PID for monitoring
- Creates timestamped logs

**Usage:**
```bash
./run_ddm_no_cursor.sh
./MONITOR_ANALYSIS.sh  # Check status anytime
```

### 2. Separate Terminal Runner (`run_ddm_in_terminal.sh`)

**Features:**
- Opens completely separate Terminal window
- 100% isolated from Cursor processes
- Visual progress display
- Cannot impact Cursor at all

**Usage:**
```bash
./run_ddm_in_terminal.sh
```

### 3. Monitoring Script (`MONITOR_ANALYSIS.sh`)

**Features:**
- Check if analysis is running
- View process status (PID, CPU time, start time)
- Show recent log entries
- Works without knowing specific log filename

**Usage:**
```bash
./MONITOR_ANALYSIS.sh
```

### 4. Documentation

**Files:**
- `QUICK_START_ANALYSIS.md` - User guide
- `README_RUNNING_ANALYSIS.md` - Detailed documentation
- `SUMMARY_CURSOR_CRASH_FIX.md` - This file

---

## 🎯 Recommended Workflow

### First Time Setup
```bash
# Ensure scripts are executable
chmod +x *.sh

# Review quick start guide
cat QUICK_START_ANALYSIS.md
```

### Running Analysis
```bash
# Start analysis (keep Mac plugged in!)
./run_ddm_no_cursor.sh

# In another terminal, monitor
./MONITOR_ANALYSIS.sh

# Or watch live
tail -f ddm_analysis_*.log
```

### After Starting
- Leave your Mac plugged into power
- Analysis runs for 3-6 hours
- You can close terminals but keep Mac awake
- Check status anytime with `./MONITOR_ANALYSIS.sh`

---

## 📊 Technical Details

### Resource Limits Applied
```bash
export OMP_NUM_THREADS=1    # OpenMP threads
export MKL_NUM_THREADS=1    # Intel Math Kernel
export NUMEXPR_NUM_THREADS=1 # NumExpr threads
```

These prevent background libraries from spawning too many threads.

### Sleep Prevention
```bash
caffeinate -d -i -m  # Prevent display/idle/disk sleep
# Note: -s (system sleep) only works when plugged in
```

### Process Isolation
```bash
nohup Rscript ... > log 2>&1 &  # Detach from terminal
PID=$!                           # Save PID for monitoring
```

---

## ⚠️ Important Notes

### DO:
- ✅ Always use `run_ddm_no_cursor.sh` or `run_ddm_in_terminal.sh`
- ✅ Keep Mac plugged in for full sleep prevention
- ✅ Let analysis run undisturbed
- ✅ Monitor with `MONITOR_ANALYSIS.sh`
- ✅ Completed models won't re-run (safe to restart)

### DON'T:
- ❌ Run `02_ddm_analysis.R` directly in Cursor
- ❌ Run multiple analyses simultaneously
- ❌ Kill processes mid-sampling
- ❌ Unplug Mac during analysis

---

## 🔍 Verification

### Check Analysis is Running
```bash
./MONITOR_ANALYSIS.sh

# Should show:
# ✅ Analysis is RUNNING (PID: XXXXX)
#    Started: ...
#    CPU time: ...
```

### Check Results
```bash
# After completion, should see:
ls -lh output/models/*.rds

# Expected files:
# Model1_Baseline.rds
# Model2_Force.rds
# Model3_Difficulty.rds
# ... (9 behavioral models total)
```

---

## 📝 Changes to Analysis Script

The `02_ddm_analysis.R` script was already optimized:

1. ✅ **NDT Random Effects Removed**: Prevents initialization explosions
2. ✅ **Defensive Prior Builder**: Avoids "argument 5 is empty" errors
3. ✅ **Safe Initialization**: Conservative NDT values
4. ✅ **Prior Validation**: Catches mismatches early
5. ✅ **Factor Level Checks**: Skips models with insufficient data
6. ✅ **File Refit**: `on_change` prevents unnecessary re-runs

No changes needed to the R script - only to HOW we run it.

---

## 🎉 Summary

**Problem:** Cursor crashes due to resource exhaustion
**Solution:** Run analysis outside Cursor using safe background scripts
**Result:** Stable, monitorable, sleep-resistant analysis pipeline

**Key Insight:** Heavy computation (brms/Stan) should never run in IDE context.
Always use separate processes for long-running analyses.

