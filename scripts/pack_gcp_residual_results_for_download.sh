#!/usr/bin/env bash
# Pack residual analysis outputs on GCP VM for download.
#
#   cd ~/Feb2026 && bash scripts/pack_gcp_residual_results_for_download.sh

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$HOME/Feb2026}"
STAMP="$(date +%Y%m%d)"
ARCHIVE="gcp_residual_results_${STAMP}.tar.gz"
MANIFEST="gcp_residual_results_${STAMP}_manifest.txt"

cd "$PROJECT_ROOT"

DIRS=(
  output/publish
  output/ddm_pupil_boundary
  output/ddm_pupil_boundary_w1p3
)

FILES=(
  output/ddm_pupil/tables/pupil_loo_all_models.csv
  output/ddm_pupil/tables/pupil_loo_window_comparison.csv
  output/ddm_pupil/logs/gcp_residual_status.txt
  output/ddm_pupil/logs/gcp_residual_master.log
)

RUN_ID="${DDM_RUN_ID:-20260226_092110}"
RUN_LOO="output/ddm_refits/runs/${RUN_ID}/loo/loo_difficultyonly_primary_thr.rds"
if [[ -f "$RUN_LOO" ]]; then
  FILES+=("$RUN_LOO")
fi

{
  echo "GCP residual analyses download manifest"
  echo "Generated: $(date -Iseconds)"
  echo ""
} > "$MANIFEST"

TAR_ARGS=()
for d in "${DIRS[@]}"; do
  if [[ -d "$d" ]]; then
    TAR_ARGS+=("$d")
    echo "DIR OK: $d" >> "$MANIFEST"
  else
    echo "DIR SKIP: $d" >> "$MANIFEST"
  fi
done

for f in "${FILES[@]}"; do
  if [[ -f "$f" ]]; then
    TAR_ARGS+=("$f")
    echo "FILE OK: $f" >> "$MANIFEST"
  else
    echo "FILE SKIP: $f" >> "$MANIFEST"
  fi
done

if [[ ${#TAR_ARGS[@]} -eq 0 ]]; then
  echo "Nothing to pack." >&2
  exit 1
fi

tar -czvf "$ARCHIVE" "${TAR_ARGS[@]}"
echo "Created: $PROJECT_ROOT/$ARCHIVE"
echo "Manifest: $MANIFEST"
