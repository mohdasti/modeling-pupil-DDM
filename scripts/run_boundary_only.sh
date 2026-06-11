#!/usr/bin/env bash
# Boundary fits only (skip difficulty-only, PPC, already done).
#
#   cd ~/Feb2026
#   bash scripts/run_boundary_only.sh

set -euo pipefail

ROOT="${PROJECT_ROOT:-$HOME/Feb2026}"
cd "$ROOT"
chmod +x scripts/run_pupil_boundary_env.sh

LOGDIR="$ROOT/output/ddm_pupil/logs"
mkdir -p "$LOGDIR"

bash scripts/run_pupil_boundary_env.sh boundary_primary \
  output/ddm_pupil_boundary pupil_metric_primary_z output/ddm_pupil \
  "$LOGDIR/boundary_primary.log"

bash scripts/run_pupil_boundary_env.sh boundary_w1p3 \
  output/ddm_pupil_boundary_w1p3 pupil_w1p3_z output/ddm_pupil_w1p3 \
  "$LOGDIR/boundary_w1p3.log"

Rscript scripts/build_pupil_extended_loo_table.R | tee -a "$LOGDIR/boundary_only.log"

echo "Done. Pack with: bash scripts/pack_gcp_residual_results_for_download.sh"
