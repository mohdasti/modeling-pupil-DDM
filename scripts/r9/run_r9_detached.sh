#!/usr/bin/env bash
# Fit the 15 pupil models on the r9 QC sample, then extract slope tables.
# Does not fit behavioral models.
#
#   cd ~/Feb2026
#   bash scripts/r9/run_r9_detached.sh
#
# Copy data/analysis_ready/r9/ up first. The run directory is
# output/ddm_refits/runs/r9_<timestamp>/. Sampler settings match r8:
# 8 chains, 3000 iterations, 1500 warmup, adapt_delta 0.95,
# max_treedepth 12, seed 2026.
# Bring back the run directory. T7/T8/T9, F5, and the inline keys are
# exported on the laptop after that, because they archive the r8 files
# in final_20261016.

set -euo pipefail
ROOT="${PROJECT_ROOT:-$HOME/Feb2026}"
cd "$ROOT"
if pgrep -f "scripts/r8/C_refit_pupil.R" >/dev/null 2>&1; then
  echo "A pupil refit is already running. Not starting a second one." >&2
  exit 1
fi
if [[ ! -f data/analysis_ready/r9/ddm_pupil_r9.csv ]]; then
  echo "Missing data/analysis_ready/r9/ddm_pupil_r9.csv. Copy the r9 sample up first." >&2
  exit 1
fi
mkdir -p output/diagnostics/pupil_rebuild
LOG="output/diagnostics/pupil_rebuild/r9_console.log"
setsid nohup bash -c "
  echo \$\$ > output/diagnostics/pupil_rebuild/r9.pid
  cd '$ROOT'
  export PUPIL_CSV=data/analysis_ready/r9/ddm_pupil_r9.csv
  export PUPIL_RUN_PREFIX=r9
  Rscript scripts/r8/C_refit_pupil.R
  Rscript scripts/r9/extract_r9.R
" >> "$LOG" 2>&1 < /dev/null &
sleep 1
echo "Started detached r9 pupil refit (pid $(cat output/diagnostics/pupil_rebuild/r9.pid))"
echo "  log: $LOG"
echo "  run id file: output/ddm_refits/runs/r9_latest_run_id.txt"
