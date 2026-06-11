#!/bin/bash
# =========================================================================
# Download DDM refit run from GCP VM to local Mac
# =========================================================================
# IMPORTANT: Run this script on your LOCAL Mac (not on the GCP VM).
#            Open Terminal on your Mac, cd to the project, then run.
#
# Usage:
#   ./scripts/download_gcp_run.sh [RUN_ID]
#
# If RUN_ID is omitted, uses 20260213_023734 (from your GCP run).
#
# Prerequisites:
#   - gcloud CLI installed and configured on your Mac, OR
#   - SSH access to the GCP VM
#
# Set these before running (or edit below):
#   GCP_VM       - VM name (for gcloud) or user@host (for scp)
#   GCP_ZONE     - e.g. us-central1-a (for gcloud)
#   GCP_REMOTE   - Base path on VM, e.g. /home/mdast003/Feb2026
# =========================================================================

set -e

RUN_ID="${1:-20260213_023734}"
LOCAL_BASE="/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/output/ddm_refits/runs"
REMOTE_RUN="output/ddm_refits/runs/${RUN_ID}"

# Detect if running on GCP VM (wrong machine)
if [ ! -d "/Users/mohdasti" ] && [ "$(whoami)" = "mdast003" ]; then
  echo "ERROR: This script must run on your LOCAL Mac, not on the GCP VM."
  echo ""
  echo "On your Mac, open Terminal and run:"
  echo "  cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM"
  echo "  ./scripts/download_gcp_run.sh ${RUN_ID}"
  echo ""
  echo "To create a tarball on GCP for manual download, run instead:"
  echo "  cd ~/Feb2026 && tar -czvf ddm_run_${RUN_ID}.tar.gz output/ddm_refits/runs/${RUN_ID}"
  echo "  # Then download ddm_run_${RUN_ID}.tar.gz via RStudio Files pane or gcloud scp"
  exit 1
fi

# --- Configure your GCP connection (choose one method) ---

# Option A: gcloud compute scp (recommended if using GCP)
GCP_VM="${GCP_VM:-lcanalysis-mdast}"      # Your VM name from `gcloud compute instances list`
GCP_ZONE="${GCP_ZONE:-us-central1-a}"     # Your VM zone
GCP_USER="${GCP_USER:-mdast003}"
GCP_REMOTE_BASE="${GCP_REMOTE_BASE:-/home/mdast003/Feb2026}"

# Option B: Direct scp (if you have SSH config or IP)
# SCP_HOST="${SCP_HOST:-mdast003@EXTERNAL_IP}"  # Replace EXTERNAL_IP

# --- Create local directory ---
mkdir -p "${LOCAL_BASE}"

echo "Downloading run ${RUN_ID} from GCP..."
echo "  Remote: ${GCP_REMOTE_BASE}/${REMOTE_RUN}"
echo "  Local:  ${LOCAL_BASE}/${RUN_ID}"
echo ""

# --- Download using gcloud ---
if command -v gcloud &>/dev/null; then
  echo "Using gcloud compute scp..."
  gcloud compute scp --recurse \
    "${GCP_VM}:${GCP_REMOTE_BASE}/${REMOTE_RUN}" \
    "${LOCAL_BASE}/" \
    --zone="${GCP_ZONE}"
  echo ""
  echo "✓ Downloaded to ${LOCAL_BASE}/${RUN_ID}"
  exit 0
fi

# --- Fallback: scp (requires SCP_HOST to be set) ---
if [ -n "${SCP_HOST}" ]; then
  echo "Using scp..."
  scp -r "${SCP_HOST}:${GCP_REMOTE_BASE}/${REMOTE_RUN}" "${LOCAL_BASE}/"
  echo ""
  echo "✓ Downloaded to ${LOCAL_BASE}/${RUN_ID}"
  exit 0
fi

echo "ERROR: Neither gcloud nor SCP_HOST configured."
echo ""
echo "To use gcloud:"
echo "  1. Install gcloud CLI and run: gcloud auth login"
echo "  2. Set GCP_VM and GCP_ZONE (run: gcloud compute instances list)"
echo "  3. Example: GCP_ZONE=us-central1-a ./scripts/download_gcp_run.sh ${RUN_ID}"
echo ""
echo "To use scp:"
echo "  1. Get your VM's external IP: gcloud compute instances describe INSTANCE --format='get(networkInterfaces[0].accessConfigs[0].natIP)'"
echo "  2. Run: SCP_HOST=mdast003@EXTERNAL_IP ./scripts/download_gcp_run.sh ${RUN_ID}"
exit 1
