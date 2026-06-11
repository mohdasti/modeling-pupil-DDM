#!/usr/bin/env bash
# Launch residual GCP analyses in tmux (survives Posit logout).
#
#   cd ~/Feb2026
#   bash scripts/run_gcp_residual_detached.sh
#
# Watch:
#   tmux attach -t manuscript_residual
#   tail -f output/ddm_pupil/logs/gcp_residual_status.txt

set -euo pipefail

ROOT="${PROJECT_ROOT:-$HOME/Feb2026}"
cd "$ROOT"

SESSION="manuscript_residual"
LOG="${ROOT}/output/ddm_pupil/logs/gcp_residual_console.log"
mkdir -p "$(dirname "$LOG")"

export DDM_RUN_ID="${DDM_RUN_ID:-20260226_092110}"
export PUPIL_REFIT="${PUPIL_REFIT:-on_change}"

CMD="cd '$ROOT' && Rscript scripts/gcp_residual_analyses_pipeline.R 2>&1 | tee -a '$LOG'"

if command -v tmux >/dev/null 2>&1; then
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "Session '$SESSION' already running. Attach: tmux attach -t $SESSION"
    exit 1
  fi
  tmux new-session -d -s "$SESSION" "$CMD"
  echo "Started tmux session: $SESSION"
  echo "  attach: tmux attach -t $SESSION"
else
  nohup bash -c "$CMD" > "${LOG}.nohup" 2>&1 &
  echo "Started nohup (PID $!)"
fi

echo "Status: tail -f output/ddm_pupil/logs/gcp_residual_status.txt"
