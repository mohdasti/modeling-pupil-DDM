#!/usr/bin/env bash
# Launch the R3 behavioral refit in tmux (survives Posit logout).
#
#   cd ~/Feb2026
#   bash scripts/refit_r3/run_r3_detached.sh            # new run r3_<timestamp>
#   RESUME=true bash scripts/refit_r3/run_r3_detached.sh  # continue the latest r3 run
#
# Watch:
#   tmux attach -t r3_refit
#   tail -f output/ddm_refits/runs/$(cat output/ddm_refits/runs/r3_latest_run_id.txt)/logs/r3_status.txt

set -euo pipefail

ROOT="${PROJECT_ROOT:-$HOME/Feb2026}"
cd "$ROOT"

SESSION="r3_refit"
RUNS="output/ddm_refits/runs"

if [[ "${RESUME:-false}" == "true" ]]; then
  if [[ -z "${R3_RUN_ID:-}" ]]; then
    if [[ ! -f "$RUNS/r3_latest_run_id.txt" ]]; then
      echo "RESUME=true but $RUNS/r3_latest_run_id.txt not found; set R3_RUN_ID." >&2
      exit 1
    fi
    R3_RUN_ID="$(cat "$RUNS/r3_latest_run_id.txt")"
  fi
else
  R3_RUN_ID="${R3_RUN_ID:-r3_$(date +%Y%m%d_%H%M%S)}"
fi
export R3_RUN_ID

mkdir -p "$RUNS/$R3_RUN_ID/logs"
echo "$R3_RUN_ID" > "$RUNS/r3_latest_run_id.txt"
LOG="$RUNS/$R3_RUN_ID/logs/r3_console.log"

ENV_VARS="R3_RUN_ID='$R3_RUN_ID'"
for v in R3_STAGES R3_CORES R3_THREADS R3_LOO_CORES R3_RELOO R3_RELOO_MAX R3_RHAT_MAX R3_ESS_MIN; do
  if [[ -n "${!v:-}" ]]; then
    ENV_VARS="$ENV_VARS $v='${!v}'"
  fi
done

CMD="cd '$ROOT' && env $ENV_VARS Rscript scripts/refit_r3/refit_behavioral_r3.R 2>&1 | tee -a '$LOG'"

if command -v tmux >/dev/null 2>&1; then
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "Session '$SESSION' already running. Attach: tmux attach -t $SESSION" >&2
    exit 1
  fi
  tmux new-session -d -s "$SESSION" "$CMD"
  echo "Started tmux session '$SESSION' for run $R3_RUN_ID"
  echo "  attach: tmux attach -t $SESSION"
else
  nohup bash -c "$CMD" > "${LOG}.nohup" 2>&1 &
  echo "Started nohup (PID $!) for run $R3_RUN_ID"
fi

echo "  status: tail -f $RUNS/$R3_RUN_ID/logs/r3_status.txt"
