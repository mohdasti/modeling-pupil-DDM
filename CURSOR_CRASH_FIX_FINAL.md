# Cursor Crash Issue - Complete Solution

## 🐛 Root Cause

**Problem:** Cursor was crashing due to trying to index/search large brms model files (6.5MB `.rds` files).

**Why this happens:**
- Cursor's AI features try to index all files in the workspace
- Large binary `.rds` files from brms models are 1-6MB each
- Opening/searching these files loads them into memory
- Multiple large files → memory exhaustion → Cursor crash

## ✅ Complete Solution

### 1. Created `.cursorignore` File

**Location:** Project root directory

**Purpose:** Tells Cursor to **completely ignore** certain files/types, preventing them from being indexed.

**What's excluded:**
- All `.rds` files (brms model outputs)
- Entire `output/` directory
- Large data files (`.csv`, `.mat`, `.h5`)
- Temporary log files
- Compiled Stan models
- Old backup files

**Result:** Cursor no longer tries to index these files → no crashes.

### 2. Safe Runner Scripts

Three scripts to run DDM analysis **outside** of Cursor:

#### `run_ddm_no_cursor.sh` (Recommended)
- Runs in background with resource limits
- Prevents system sleep
- Isolated from Cursor

#### `run_ddm_in_terminal.sh`
- Opens separate Terminal window
- 100% isolated from Cursor

#### `MONITOR_ANALYSIS.sh`
- Check if analysis is running
- View progress
- Process monitoring

### 3. Fixed Paths

Updated `run_ddm_no_cursor.sh` to use correct Rscript path:
- **Before:** `/usr/bin/Rscript` (didn't exist)
- **After:** `/usr/local/bin/Rscript` (correct location)

---

## 🚀 How to Use

### Step 1: Restart Cursor

**CRITICAL:** You MUST restart Cursor for `.cursorignore` to take effect!

```bash
# Quit Cursor completely
Cmd+Q

# Reopen Cursor
# Open the project
```

### Step 2: Run Analysis Safely

```bash
# Use the safe background runner
./run_ddm_no_cursor.sh

# Monitor progress
./MONITOR_ANALYSIS.sh
```

### Step 3: Let It Run

- Keep Mac plugged into power
- Analysis takes 3-6 hours
- You can close Cursor terminal, but keep Terminal app running
- Check status anytime with `./MONITOR_ANALYSIS.sh`

---

## 📋 What Changed

### Files Created:
- `.cursorignore` - Prevents indexing large files
- `run_ddm_no_cursor.sh` - Safe background runner
- `run_ddm_in_terminal.sh` - Separate terminal runner
- `MONITOR_ANALYSIS.sh` - Status checker
- `QUICK_START_ANALYSIS.md` - User guide
- `SUMMARY_CURSOR_CRASH_FIX.md` - Technical details
- `CURSOR_CRASH_FIX_FINAL.md` - This file

### Files Modified:
- `run_ddm_no_cursor.sh` - Fixed Rscript path
- No changes to analysis scripts needed

### Files Existing:
- `output/models/*.rds` - Existing model files (now ignored by Cursor)

---

## ⚠️ Important Notes

### DO:
- ✅ Restart Cursor after creating `.cursorignore`
- ✅ Use `run_ddm_no_cursor.sh` for heavy analysis
- ✅ Keep Mac plugged in for full sleep prevention
- ✅ Monitor with `MONITOR_ANALYSIS.sh`
- ✅ Let analysis run undisturbed

### DON'T:
- ❌ Open `.rds` files directly in Cursor
- ❌ Run `02_ddm_analysis.R` directly in Cursor terminal
- ❌ Browse the `output/` directory in Cursor
- ❌ Try to edit large model files
- ❌ Kill analysis mid-sampling

### Safe to Do in Cursor:
- ✅ Edit R scripts (`.R` files)
- ✅ Edit Markdown documentation
- ✅ View data files (small CSVs)
- ✅ Write documentation
- ✅ Commit to git

---

## 🔍 Verification

### Check if `.cursorignore` is Working

After restarting Cursor, you should notice:
- No more crashes when opening the project
- `output/` directory doesn't slow down file browser
- Search/find in files doesn't scan `.rds` files
- Cursor feels more responsive

### Check Analysis Status

```bash
# See if analysis is running
./MONITOR_ANALYSIS.sh

# Should show:
# ✅ Analysis is RUNNING (PID: XXXXX)
#    Started: [timestamp]
#    CPU time: [duration]
```

### Check Results

After completion:
```bash
ls -lh output/models/*.rds

# Should see model files
# Model1_Baseline.rds
# Model2_Force.rds
# etc.
```

---

## 🎉 Summary

**Problem:** Cursor crashes when opening project with large `.rds` files

**Root Cause:** Cursor indexing/searching large binary model files

**Solution:** 
1. `.cursorignore` prevents indexing
2. Safe runner scripts prevent crashes during analysis
3. Fixed Rscript paths

**Result:** 
- Cursor stable and responsive
- Analysis runs safely in background
- No crashes

---

## 📚 Additional Resources

- **Quick Start:** `QUICK_START_ANALYSIS.md`
- **Technical Details:** `SUMMARY_CURSOR_CRASH_FIX.md`
- **Running Analysis:** `README_RUNNING_ANALYSIS.md`

---

## 🆘 Troubleshooting

### Still crashing?

1. **Restart Cursor completely** (Cmd+Q, wait 10 seconds, reopen)
2. **Check `.cursorignore` exists:** `ls -la .cursorignore`
3. **Verify file is in repo root** (not in a subdirectory)
4. **Check if there are other large files** not covered by `.cursorignore`

### Analysis not starting?

1. **Check Rscript path:** `which Rscript`
2. **Check permissions:** `chmod +x run_ddm_no_cursor.sh`
3. **Try separate terminal:** `./run_ddm_in_terminal.sh`

### Need to see analysis output?

Don't open `.rds` files in Cursor! Use R:

```r
library(brms)
model <- readRDS("output/models/Model1_Baseline.rds")
summary(model)
plot(model)
```

---

**Key Takeaway:** `.cursorignore` is like `.gitignore` but for Cursor's AI features. It tells Cursor "don't try to understand these files" → prevents crashes from large binary files.










