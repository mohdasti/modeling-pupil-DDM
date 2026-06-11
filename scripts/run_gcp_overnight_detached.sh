#!/usr/bin/env bash
# Start the overnight pupil pipeline detached from Posit/RStudio logout.
#
# Run ON THE GCP VM (Posit terminal), from project root:
#   cd ~/Feb2026
#   bash scripts/run_gcp_overnight_detached.sh
#
# Survives logout via tmux (preferred) or nohup fallback.

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$HOME/Feb2026}"
SESSION="${GCP_SESSION:-pupil_overnight}"
DDM_RUN_ID="${DDM_RUN_ID:-20260226_092110}"
PUPIL_REFIT="${PUPIL_REFIT:-on_change}"
LOG_DIR="${PROJECT_ROOT}/output/ddm_pupil/logs"
LOG_FILE="${LOG_DIR}/gcp_overnight_console.log"
PID_FILE="${LOG_DIR}/gcp_overnight.pid"

mkdir -p "${LOG_DIR}"
cd "${PROJECT_ROOT}"

RUN_CMD="cd '${PROJECT_ROOT}' && \
  export DDM_RUN_ID='${DDM_RUN_ID}' && \
  export PUPIL_REFIT='${PUPIL_REFIT}' && \
  export REBUILD_PUPIL_DATA='${REBUILD_PUPIL_DATA:-auto}' && \
  Rscript scripts/gcp_overnight_pupil_pipeline.R 2>&1 | tee -a '${LOG_FILE}'; \
  echo \"\$(date -Iseconds) EXIT:\$?\" >> '${LOG_FILE}'"

echo "================================================================================"
echo "GCP OVERNIGHT PUPIL PIPELINE (detached)"
echo "================================================================================"
echo "Project:  ${PROJECT_ROOT}"
echo "Run ID:   ${DDM_RUN_ID}"
echo "Refit:    ${PUPIL_REFIT}  (on_change skips finished .rds)"
echo "Log:      ${LOG_FILE}"
echo "Status:   ${LOG_DIR}/gcp_overnight_status.txt"
echo ""

if command -v tmux >/dev/null 2>&1; then
  if tmux has-session -t "${SESSION}" 2>/dev/null; then
    echo "WARNING: tmux session '${SESSION}' already exists."
    echo "  Attach:  tmux attach -t ${SESSION}"
    echo "  Or kill: tmux kill-session -t ${SESSION}"
    exit 1
  fi
  tmux new-session -d -s "${SESSION}" "bash -lc $(printf '%q' "${RUN_CMD}")"
  echo "Started in tmux session: ${SESSION}"
  echo ""
  echo "  Attach (watch live):   tmux attach -t ${SESSION}"
  echo "  Detach (keep running): Ctrl+B then D"
  echo "  Tail log:              tail -f ${LOG_FILE}"
  echo "  Step status:           tail -f ${LOG_DIR}/gcp_overnight_status.txt"
else
  echo "tmux not found — using nohup (still survives logout)."
  nohup bash -lc "${RUN_CMD}" >> "${LOG_FILE}" 2>&1 &
  echo $! > "${PID_FILE}"
  echo "PID: $(cat "${PID_FILE}")"
  echo "  Tail log:    tail -f ${LOG_FILE}"
  echo "  Check proc:  ps -p $(cat "${PID_FILE}")"
fi

echo ""
echo "When finished, pack for download:"
echo "  bash scripts/pack_pupil_ddm_for_download.sh"
echo "================================================================================"
