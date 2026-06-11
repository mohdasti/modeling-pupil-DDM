#!/usr/bin/env bash
# Run Cavanagh pupil→boundary fit + postprocess with safely quoted env vars.
# Usage:
#   bash scripts/run_pupil_boundary_env.sh boundary_primary \
#     output/ddm_pupil_boundary pupil_metric_primary_z output/ddm_pupil \
#     output/ddm_pupil/logs/boundary_primary.log

set -euo pipefail

STEP_NAME="${1:?step name}"
OUTPUT_BASE="${2:?output base}"
PUPIL_Z_COL="${3:?pupil z col}"
BASELINE_LOO_DIR="${4:?baseline loo dir}"
LOG_FILE="${5:?log file}"

ROOT="${PROJECT_ROOT:-$HOME/Feb2026}"
cd "$ROOT"
mkdir -p "$(dirname "$LOG_FILE")"

export PUPIL_OUTPUT_BASE="$OUTPUT_BASE"
export PUPIL_Z_COL="$PUPIL_Z_COL"
export PUPIL_BASELINE_LOO_DIR="$BASELINE_LOO_DIR"
export PUPIL_REFIT="${PUPIL_REFIT:-on_change}"

{
  echo "=== $STEP_NAME fit $(date -Iseconds) ==="
  Rscript scripts/fit_pupil_boundary_model.R
  echo "=== $STEP_NAME postprocess $(date -Iseconds) ==="
  Rscript scripts/postprocess_pupil_boundary_model.R
} >> "$LOG_FILE" 2>&1

echo "$STEP_NAME OK — log: $LOG_FILE"
