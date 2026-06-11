#!/bin/bash
# =========================================================================
# Pack DDM refit run for download (run this ON the GCP VM)
# =========================================================================
# Run this on the GCP VM to create a tarball you can download.
#
# Usage (on GCP VM):
#   cd ~/Feb2026
#   ./scripts/pack_run_for_download.sh [RUN_ID]
#
# Creates: ~/Feb2026/ddm_run_RUN_ID.tar.gz
# Download via RStudio Files pane, or from your Mac:
#   gcloud compute scp mdast003@lcanalysis-mdast:~/Feb2026/ddm_run_20260213_023734.tar.gz . --zone=YOUR_ZONE
# =========================================================================

RUN_ID="${1:-20260213_023734}"
PROJECT_ROOT="${2:-$HOME/Feb2026}"
RUN_PATH="output/ddm_refits/runs/${RUN_ID}"
OUTPUT_TAR="${PROJECT_ROOT}/ddm_run_${RUN_ID}.tar.gz"

cd "${PROJECT_ROOT}" || exit 1

if [ ! -d "${RUN_PATH}" ]; then
  echo "ERROR: Run directory not found: ${RUN_PATH}"
  echo "Available runs:"
  ls -la output/ddm_refits/runs/ 2>/dev/null || echo "  (none)"
  exit 1
fi

echo "Packing ${RUN_PATH} -> ${OUTPUT_TAR}"
tar -czvf "${OUTPUT_TAR}" "${RUN_PATH}"
echo ""
echo "Done. File size: $(du -h "${OUTPUT_TAR}" | cut -f1)"
echo ""
echo "To download from your Mac:"
echo "  gcloud compute scp mdast003@lcanalysis-mdast:${OUTPUT_TAR} /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/ --zone=YOUR_ZONE"
echo ""
echo "Then extract locally:"
echo "  cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM"
echo "  tar -xzvf ddm_run_${RUN_ID}.tar.gz"
echo "  # This creates output/ddm_refits/runs/${RUN_ID}/"
