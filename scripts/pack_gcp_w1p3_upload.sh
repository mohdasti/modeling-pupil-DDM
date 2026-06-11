#!/usr/bin/env bash
# Pack w1p3 pupil sensitivity upload for manual GCP transfer (Posit Files pane).
# Run on Mac from repo root:
#   bash scripts/pack_gcp_w1p3_upload.sh
#
# Upload gcp_w1p3_upload.tar.gz to ~/Feb2026/ on the VM, then follow
# docs/GCP_W1P3_MANUAL_UPLOAD.md

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUNDLE="gcp_w1p3_upload.tar.gz"
STAMP="$(date +%Y%m%d)"

echo "=== Packing w1p3 GCP manual upload bundle ==="

CH3="data/pupil_processed/analysis_ready/ch3_triallevel.csv"
if [[ ! -f "$CH3" ]]; then
  echo "ERROR: Missing $CH3" >&2
  echo "Run: Rscript scripts/REGENERATE_CH3_FEATURES.R" >&2
  exit 1
fi

W1P3_N=$(Rscript -e "d<-read.csv('$CH3'); cat(sum(!is.na(d[['cog_auc_w1p3']])))")
if [[ "${W1P3_N:-0}" -lt 1000 ]]; then
  echo "ERROR: cog_auc_w1p3 has only ${W1P3_N} non-NA values in $CH3" >&2
  echo "Re-run REGENERATE_CH3_FEATURES.R (needs make_quick_share_v7 coalesce fix)." >&2
  exit 1
fi
echo "  ✓ ch3_triallevel.csv: cog_auc_w1p3 non-NA = ${W1P3_N}"

REQUIRED=(
  scripts/make_quick_share_v7.R
  scripts/build_pupil_trial_features.R
  scripts/build_ddm_pupil_ready_data.R
  scripts/fit_pupil_ddm_models.R
  scripts/postprocess_pupil_ddm_models.R
  scripts/apply_w1p3_on_vm.sh
  docs/GCP_W1P3_MANUAL_UPLOAD.md
)

TAR_ARGS=()
for f in "${REQUIRED[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: Missing required file: $f" >&2
    exit 1
  fi
  TAR_ARGS+=("$f")
done
TAR_ARGS+=("$CH3")

tar -czvf "$BUNDLE" "${TAR_ARGS[@]}"

BYTES=$(wc -c < "$BUNDLE" | tr -d ' ')
echo ""
echo "Created: $ROOT/$BUNDLE ($(du -h "$BUNDLE" | cut -f1))"
echo "Built:   ${STAMP}"
echo "cog_auc_w1p3 non-NA in bundle: ${W1P3_N}"
echo ""
echo "Manual upload:"
echo "  1. Posit / RStudio Files → upload to ~/Feb2026/"
echo "  2. Terminal on VM:"
echo "       cd ~/Feb2026"
echo "       tar -xzvf gcp_w1p3_upload.tar.gz"
echo "       bash scripts/apply_w1p3_on_vm.sh"
echo ""
echo "Full instructions: docs/GCP_W1P3_MANUAL_UPLOAD.md"
