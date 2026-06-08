#!/bin/bash
# Pack and upload pupil-DDM resume bundle to GCP VM
# Run on LOCAL Mac from project root.
#
# Usage:
#   ./scripts/upload_pupil_gcp.sh
#
# Env overrides:
#   GCP_VM, GCP_ZONE, GCP_REMOTE_BASE (see download_gcp_run.sh)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GCP_VM="${GCP_VM:-lcanalysis-mdast}"
GCP_ZONE="${GCP_ZONE:-us-central1-a}"
GCP_REMOTE_BASE="${GCP_REMOTE_BASE:-/home/mdast003/Feb2026}"
BUNDLE="pupil_gcp_upload.tar.gz"

echo "Packing pupil GCP upload bundle..."
tar -czvf "$BUNDLE" \
  scripts/fit_pupil_ddm_models.R \
  scripts/postprocess_pupil_ddm_models.R \
  scripts/build_ddm_pupil_ready_data.R \
  output/ddm_pupil/ddm_pupil_ready_thr0.20_probe_onset_locked.csv \
  output/ddm_pupil/models/model_0_behavioral.rds \
  output/ddm_pupil/models/model_1_pupil_bias.rds

echo ""
echo "Uploading to ${GCP_VM}:${GCP_REMOTE_BASE}/ ..."
gcloud compute scp "$BUNDLE" "${GCP_VM}:${GCP_REMOTE_BASE}/" --zone="${GCP_ZONE}"

echo ""
echo "✓ Uploaded. On the VM run:"
echo "  cd ${GCP_REMOTE_BASE}"
echo "  tar -xzvf ${BUNDLE}"
echo "  mkdir -p output/ddm_pupil/models"
echo "  Rscript -e 'Sys.setenv(DDM_RUN_ID=\"20260226_092110\", PUPIL_REFIT=\"on_change\"); source(\"scripts/fit_pupil_ddm_models.R\"); source(\"scripts/postprocess_pupil_ddm_models.R\")'"
