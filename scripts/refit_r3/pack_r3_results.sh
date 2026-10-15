#!/usr/bin/env bash
# Pack an R3 run on the VM for download.
#
#   cd ~/Feb2026 && bash scripts/refit_r3/pack_r3_results.sh            # latest run, without model rds
#   INCLUDE_MODELS=true bash scripts/refit_r3/pack_r3_results.sh         # also models/*.rds

set -euo pipefail

ROOT="${PROJECT_ROOT:-$HOME/Feb2026}"
cd "$ROOT"

RUNS="output/ddm_refits/runs"
RUN_ID="${R3_RUN_ID:-$(cat "$RUNS/r3_latest_run_id.txt")}"
RUN="$RUNS/$RUN_ID"
[[ -d "$RUN" ]] || { echo "No run dir $RUN" >&2; exit 1; }

ARCHIVE="gcp_${RUN_ID}_results.tar.gz"
PATHS=("$RUN/tables" "$RUN/loo" "$RUN/logs")
if [[ "${INCLUDE_MODELS:-false}" == "true" ]]; then
  PATHS+=("$RUN/models")
fi

tar -czvf "$ARCHIVE" "${PATHS[@]}"
echo "Created: $ROOT/$ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"
echo "Summary inside: $RUN/tables/r3_summary.md"
