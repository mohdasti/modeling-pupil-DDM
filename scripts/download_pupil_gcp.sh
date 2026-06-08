#!/bin/bash
# Download pupil-DDM results tarball from GCP VM to local project
# Run on LOCAL Mac.
#
# Usage:
#   ./scripts/download_pupil_gcp.sh [remote_tarball_name]
#
# Default remote file: ~/Feb2026/pupil_ddm_results.tar.gz
# Create that file on GCP first (see docs/GCP_PUPIL_FIT_GUIDE.md).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GCP_VM="${GCP_VM:-lcanalysis-mdast}"
GCP_ZONE="${GCP_ZONE:-us-central1-a}"
GCP_REMOTE_BASE="${GCP_REMOTE_BASE:-/home/mdast003/Feb2026}"
REMOTE_TAR="${1:-pupil_ddm_results.tar.gz}"
LOCAL_TAR="${ROOT}/${REMOTE_TAR}"

echo "Downloading ${GCP_REMOTE_BASE}/${REMOTE_TAR} ..."
gcloud compute scp \
  "${GCP_VM}:${GCP_REMOTE_BASE}/${REMOTE_TAR}" \
  "${LOCAL_TAR}" \
  --zone="${GCP_ZONE}"

echo ""
echo "Extracting into project root..."
tar -xzvf "${LOCAL_TAR}" -C "${ROOT}"

echo ""
echo "✓ Done. Check:"
echo "  ls output/ddm_pupil/models/"
echo "  ls output/ddm_pupil/tables/"
echo ""
echo "Then render:"
echo "  cd reports && quarto render chap3_ddm_results.qmd"
