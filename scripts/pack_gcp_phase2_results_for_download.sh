#!/usr/bin/env bash
# Pack phase-2 outputs for download from GCP VM.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
RUN_ID="${DDM_RUN_ID:-20260226_092110}"
STAMP="$(date +%Y%m%d)"
BUNDLE="gcp_phase2_results_${STAMP}.tar.gz"

tar -czvf "$BUNDLE" \
  "output/ddm_refits/runs/${RUN_ID}/tables/h1_h2_contrasts_by_cutoff.csv" \
  "output/ddm_refits/runs/${RUN_ID}/tables/convergence_primary_extended.csv" \
  "output/ddm_refits/runs/${RUN_ID}/models/additive__probe_onset_locked__thr0.15.rds" \
  "output/ddm_refits/runs/${RUN_ID}/models/additive__probe_onset_locked__thr0.25.rds" \
  "output/publish/ppc_cells_midbody.csv" \
  "output/publish/publish_gate_primary_censored.csv" \
  "output/ddm_refits/runs/${RUN_ID}/logs/gcp_phase2_status.txt" \
  2>/dev/null || true

echo "Created: $ROOT/$BUNDLE"
echo "Download via Posit Files, extract into repo root on Mac."
