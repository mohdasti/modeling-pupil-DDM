#!/usr/bin/env bash
# Pack residual-analysis scripts for manual upload to GCP (Posit Files pane).
#
#   bash scripts/pack_gcp_residual_analyses_upload.sh
#
# Upload gcp_residual_analyses_upload.tar.gz to ~/Feb2026/ on the VM, then:
#   tar -xzvf gcp_residual_analyses_upload.tar.gz
#   bash scripts/run_gcp_residual_detached.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUNDLE="gcp_residual_analyses_upload.tar.gz"

REQUIRED=(
  scripts/gcp_residual_analyses_pipeline.R
  scripts/run_gcp_residual_detached.sh
  scripts/run_gcp_residual_resume.sh
  scripts/run_pupil_boundary_env.sh
  scripts/run_boundary_only.sh
  scripts/fit_ddm_difficultyonly.R
  scripts/fit_pupil_boundary_model.R
  scripts/postprocess_pupil_boundary_model.R
  scripts/build_pupil_extended_loo_table.R
  scripts/sync_publish_from_run.R
  scripts/R/export_ppc_primary_diagnostic.R
  scripts/R/make_publish_gate.R
  scripts/pack_gcp_residual_results_for_download.sh
  docs/GCP_RESIDUAL_ANALYSES.md
)

TAR_ARGS=()
for f in "${REQUIRED[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: missing $f" >&2
    exit 1
  fi
  TAR_ARGS+=("$f")
done

tar -czvf "$BUNDLE" "${TAR_ARGS[@]}"

echo ""
echo "Created: $ROOT/$BUNDLE ($(du -h "$BUNDLE" | cut -f1))"
echo ""
echo "Upload to VM ~/Feb2026/ then:"
echo "  tar -xzvf gcp_residual_analyses_upload.tar.gz"
echo "  chmod +x scripts/run_gcp_residual_detached.sh scripts/run_gcp_residual_resume.sh"
echo "  bash scripts/run_gcp_residual_resume.sh   # if difficulty-only + PPC already done"
