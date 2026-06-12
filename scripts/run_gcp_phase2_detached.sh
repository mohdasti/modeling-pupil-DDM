#!/usr/bin/env bash
# Detached launcher for phase-2 GCP pipeline (tmux).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SESSION="manuscript_phase2"
RUN_ID="${DDM_RUN_ID:-20260226_092110}"
LOG_DIR="$ROOT/output/ddm_refits/runs/$RUN_ID/logs"
LOG="$LOG_DIR/gcp_phase2_master.log"
STATUS="$LOG_DIR/gcp_phase2_status.txt"
mkdir -p "$LOG_DIR"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] launcher — START (tmux spawning R pipeline)" >> "$STATUS"

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Session $SESSION already running. Attach: tmux attach -t $SESSION"
  echo "Status: $STATUS"
  exit 0
fi

tmux new-session -d -s "$SESSION" \
  "cd '$ROOT' && DDM_RUN_ID=$RUN_ID Rscript scripts/gcp_manuscript_phase2_pipeline.R 2>&1 | tee -a '$LOG'"

echo "Started tmux session: $SESSION"
echo "Monitor (live log):  tail -f $LOG"
echo "Monitor (step status): tail -f $STATUS"
echo "Attach:              tmux attach -t $SESSION"
