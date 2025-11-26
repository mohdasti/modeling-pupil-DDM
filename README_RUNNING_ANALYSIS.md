# Running DDM Analysis - Sleep Prevention Guide

## Problem
When your Mac goes to sleep, R processes get paused or terminated, aborting long-running analyses.

## Solution: Background Script with Sleep Prevention

### Quick Start

```bash
# Start analysis (prevents sleep, runs in background)
./run_ddm_analysis_background.sh

# Check status anytime
./MONITOR_ANALYSIS.sh

# View live log
tail -f ddm_analysis_background.log
```

---

## How It Works

The `run_ddm_analysis_background.sh` script:
1. Uses `caffeinate` to prevent system sleep
   - `-d`: Prevent display sleep
   - `-i`: Prevent system idle sleep  
   - `-m`: Prevent disk idle sleep
   - `-s`: Prevent system sleep (requires AC power)

2. Uses `nohup` to survive terminal closure

3. Runs in background and saves PID for monitoring

---

## Monitoring Commands

### Check if running
```bash
./MONITOR_ANALYSIS.sh
# OR
ps -p $(cat ddm_analysis.pid)
```

### View live log
```bash
tail -f ddm_analysis_background.log
```

### View last N lines
```bash
tail -50 ddm_analysis_background.log
```

### Stop analysis (if needed)
```bash
kill $(cat ddm_analysis.pid)
# OR
pkill -f "02_ddm_analysis"
```

---

## Alternative: Using `screen` (if installed)

If you prefer `screen`:

```bash
# Start screen session
screen -S ddm_analysis

# Run analysis
Rscript scripts/02_statistical_analysis/02_ddm_analysis.R

# Detach: Press Ctrl+A, then D
# Reattach: screen -r ddm_analysis
```

**Note:** `screen` won't prevent sleep, only keeps process running in detached session.

---

## Alternative: Using `tmux` (if installed)

```bash
# Start tmux session
tmux new -s ddm_analysis

# Run analysis
Rscript scripts/02_statistical_analysis/02_ddm_analysis.R

# Detach: Press Ctrl+B, then D
# Reattach: tmux attach -t ddm_analysis
```

---

## Important Notes

1. **AC Power Required**: The `-s` flag (prevent system sleep) only works when Mac is plugged in. On battery, the system may still sleep.

2. **Energy Settings**: You may want to adjust System Preferences → Energy Saver to extend sleep time while plugged in.

3. **Long Analyses**: For very long analyses (hours/days), consider:
   - Running on a server/cloud instance
   - Using batch job scheduler
   - Breaking into smaller chunks

---

## Troubleshooting

### Analysis stopped
1. Check if process exists: `./MONITOR_ANALYSIS.sh`
2. Check log for errors: `tail -100 ddm_analysis_background.log`
3. Restart if needed: `./run_ddm_analysis_background.sh`

### Can't prevent sleep
- Make sure Mac is plugged into AC power
- Check System Preferences → Energy Saver
- Try running without `-s` flag (still prevents idle sleep)

### Want to allow sleep but keep process
- Use `screen` or `tmux` instead
- Or remove `caffeinate` from script and just use `nohup`
















