#!/usr/bin/env bash
# Pack phase-2 manuscript analysis scripts for GCP upload.
#
#   bash scripts/pack_gcp_phase2_upload.sh
#
# Upload gcp_phase2_upload.tar.gz to ~/Feb2026/ on the VM, then:
#   tar -xzvf gcp_phase2_upload.tar.gz
#   chmod +x scripts/run_gcp_phase2_detached.sh
#   bash scripts/run_gcp_phase2_detached.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BUNDLE="gcp_phase2_upload.tar.gz"

REQUIRED=(
  scripts/gcp_manuscript_phase2_pipeline.R
  scripts/run_gcp_phase2_detached.sh
  scripts/check_brms_preflight.R
  scripts/fix_rstan_vm.R
  scripts/fit_sensitivity_additive_thresholds.R
  scripts/export_h1_h2_by_rt_cutoff.R
  scripts/R/extract_convergence_extended.R
  scripts/R/export_ppc_primary_diagnostic.R
  scripts/R/make_publish_gate.R
  scripts/pack_gcp_phase2_results_for_download.sh
  docs/GCP_PHASE2_MANUSCRIPT.md
)

OPTIONAL=(
  output/ddm_refits/runs/20260226_092110/tables/convergence_primary_extended.csv
)

TAR_ARGS=()
for f in "${REQUIRED[@]}"; do
  [[ -f "$f" ]] || { echo "ERROR: missing $f" >&2; exit 1; }
  TAR_ARGS+=("$f")
done
for f in "${OPTIONAL[@]}"; do
  [[ -f "$f" ]] && TAR_ARGS+=("$f")
done

COPYFILE_DISABLE=1 tar -czvf "$BUNDLE" "${TAR_ARGS[@]}"
echo ""
echo "Created: $ROOT/$BUNDLE ($(du -h "$BUNDLE" | cut -f1))"
echo ""
echo "Upload to VM ~/Feb2026/ then:"
echo "  tar -xzvf gcp_phase2_upload.tar.gz"
echo "  bash scripts/run_gcp_phase2_detached.sh"
