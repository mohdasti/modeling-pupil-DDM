# Running DDM Analysis in RStudio

## 🚀 Quick Start

### Method 1: Source the Script (Recommended)

1. **Open `run_ddm_in_rstudio.R` in RStudio**
2. **Click "Source" button** (or Cmd+Shift+S on Mac)
3. **Watch the console** for real-time progress

The script will:
- ✅ Display progress in RStudio console
- ✅ Save detailed log to timestamped file
- ✅ Show elapsed time every model
- ✅ Catch and report errors without stopping
- ✅ Save completion summary

### Method 2: Run in Console

```r
# In RStudio console:
source("run_ddm_in_rstudio.R")
```

---

## 📊 What You'll See

### In RStudio Console:

```
================================================================================
DDM ANALYSIS - RSTUDIO EXECUTION
================================================================================
Started: 2024-11-01 18:30:45
================================================================================

Log file: ddm_analysis_rstudio_20241101_183045.log
Working directory: /path/to/your/project

[18:30:45] [INFO] Loading required packages...
[18:30:46] [INFO] ✅ All packages loaded successfully
[18:30:46] [INFO] Loading configuration from config/pipeline_config.R
[18:30:46] [INFO] ✅ Configuration loaded
[18:30:46] [INFO] Starting data loading and preparation...
[18:30:46] [INFO] ✅ Found behavioral data: data/analysis_ready/bap_ddm_ready.csv
[18:30:46] [INFO]    File size: 15.23 MB
[18:30:47] [INFO] ✅ Loaded 17243 rows of behavioral data
...
[18:30:50] [INFO] FITTING MODEL: Model1_Baseline
[18:30:50] [INFO] ⏱️  Elapsed time: 0.1 minutes
...
```

### Progress Monitoring:

Every 30 seconds, you'll see:
- Elapsed time
- Current model being fit
- Success/failure status
- Duration per model

---

## 📝 Log Files Created

### 1. Live Log File
- **Name:** `ddm_analysis_rstudio_YYYYMMDD_HHMMSS.log`
- **Contains:** Everything shown in console + timestamps
- **Use:** Track progress if RStudio closes

### 2. Summary File
- **Name:** `ddm_analysis_summary_YYYYMMDD_HHMMSS.csv`
- **Contains:** List of models and completion status
- **Use:** Quick check of what completed/failed

---

## ⏱️ Expected Duration

- **Per model:** 20-40 minutes
- **Total (9 models):** 3-6 hours
- **With save points:** Models save as they complete

---

## 🛑 If Something Goes Wrong

### RStudio Crashes?
1. Check the log file: `ddm_analysis_rstudio_*.log`
2. See which models completed
3. Re-run the script - completed models won't re-fit (using `file_refit="on_change"`)

### Want to Stop Early?
- Press Esc or Ctrl+C in console
- Already-completed models are saved
- Log file shows progress up to interruption

### Memory Issues?
- Close other RStudio tabs
- Close other applications
- Consider running fewer models at once

---

## 🔍 Monitoring While Running

### Option 1: Watch Console
- Keep RStudio console visible
- Progress updates appear automatically

### Option 2: Tail the Log File
Open a Terminal and run:
```bash
# Replace YYYYMMDD_HHMMSS with your timestamp
tail -f ddm_analysis_rstudio_YYYYMMDD_HHMMSS.log
```

### Option 3: Check Model Files
```bash
# See which models are done
ls -lht output/models/*.rds | head
```

---

## ✅ After Completion

### Check Results:
```r
# In RStudio console:
library(brms)

# List completed models
list.files("output/models", pattern = "\\.rds$")

# Load a specific model
model1 <- readRDS("output/models/Model1_Baseline.rds")
summary(model1)
plot(model1)
```

### View Summary:
```r
# Check completion status
summary_file <- list.files(".", pattern = "ddm_analysis_summary.*\\.csv$", full.names = TRUE)
summary_file <- summary_file[length(summary_file)]  # Most recent
read.csv(summary_file)
```

---

## 🆘 Troubleshooting

### "File not found" errors
```r
# Check your working directory
getwd()

# Should be project root (where scripts/ folder is)
# If not, set it:
setwd("/path/to/modeling-pupil-DDM/modeling-pupil-DDM")
```

### "Package not found" errors
```r
# Install missing packages
install.packages(c("brms", "cmdstanr", "readr", "dplyr", "purrr"))

# May also need to install/recompile Stan
install.packages("cmdstanr")
cmdstanr::install_cmdstan()
```

### Models taking too long
- This is normal - each model takes 20-40 minutes
- Be patient
- Check logs for progress
- Completed models won't re-run

---

## 📋 Advantages of RStudio vs Terminal

### RStudio:
✅ Visual progress in console
✅ Can pause/resume
✅ Better error messages
✅ Integrated environment
✅ Can run other code while analysis runs
⚠️ Keep RStudio open the whole time

### Terminal (run_ddm_no_cursor.sh):
✅ Can close terminal after starting
✅ Sleep-resistant with caffeinate
✅ Background execution
⚠️ Less visible progress

**Recommendation:** Use RStudio if you can keep it open. Use Terminal if you need to close/lock your Mac.

---

## 🔄 Running Multiple Times

The script is **idempotent** - safe to run multiple times:
- Completed models are skipped
- Only new/failed models are re-fit
- Log files are timestamped (won't overwrite)
- Save points prevent loss of progress

---

**Need Help?** Check the log files for detailed error messages!










