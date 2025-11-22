# Quick Start: Running DDM Analysis

## ⚠️ IMPORTANT: Avoid Cursor Crashes

**Never run `02_ddm_analysis.R` directly in Cursor!** 
- The Stan compilation is extremely CPU-intensive
- It will freeze or crash Cursor
- Always use one of the safe runner scripts below

---

## 🚀 Recommended Method

### Option 1: Background Run (Best for Long Sessions)

```bash
# Start analysis in background with sleep prevention
./run_ddm_no_cursor.sh

# Monitor progress anytime
./MONITOR_ANALYSIS.sh

# Or watch live
tail -f ddm_analysis_*.log
```

**Advantages:**
- ✅ Prevents system sleep
- ✅ Safe for Cursor
- ✅ Can close terminal after starting
- ✅ Automatic logging

---

### Option 2: Separate Terminal Window

```bash
# Opens completely separate Terminal window
./run_ddm_in_terminal.sh
```

**Advantages:**
- ✅ 100% isolated from Cursor
- ✅ Visual progress in separate window
- ✅ Can't accidentally crash Cursor

---

## 📊 Monitoring Your Analysis

### Check if Running
```bash
./MONITOR_ANALYSIS.sh
```

### View Latest Progress
```bash
tail -50 ddm_analysis_*.log
```

### Watch Live Updates
```bash
tail -f ddm_analysis_*.log
```

### Stop Analysis (if needed)
```bash
kill $(cat ddm_analysis.pid)
```

---

## ⏱️ Expected Duration

- **Each model:** 20-40 minutes
- **Total models:** 9 (behavioral only) or 11 (with pupil)
- **Total time:** 3-6 hours

**Note:** With `file_refit = "on_change"`, completed models won't re-run.

---

## 🔍 Checking Results

After analysis completes:

```bash
# Check output directory
ls -lh output/models/

# Should see .rds files for each model
# Example: Model1_Baseline.rds, Model2_Force.rds, etc.
```

---

## ❓ Troubleshooting

### Analysis not running
```bash
# Check if process exists
ps aux | grep Rscript | grep 02_ddm

# Restart with safe script
./run_ddm_no_cursor.sh
```

### System went to sleep
```bash
# Make sure you're plugged in for full sleep prevention
# Or use caffeinate manually
caffeinate -d -i -m -s -t 21600  # Keep awake for 6 hours
```

### Want to resume interrupted analysis
```bash
# Models already completed won't re-run
# Just restart with same script
./run_ddm_no_cursor.sh
```

---

## 📝 Summary

**DO:**
- ✅ Use `run_ddm_no_cursor.sh` or `run_ddm_in_terminal.sh`
- ✅ Monitor with `MONITOR_ANALYSIS.sh`
- ✅ Keep Mac plugged in for full sleep prevention
- ✅ Let it run for several hours undisturbed

**DON'T:**
- ❌ Run `02_ddm_analysis.R` directly in Cursor
- ❌ Run multiple analyses simultaneously
- ❌ Kill processes mid-sampling (let chains complete)











