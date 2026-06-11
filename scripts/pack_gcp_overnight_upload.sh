#!/usr/bin/env bash
# Pack scripts + partial pupil artifacts for GCP overnight upload.
# Run on LOCAL Mac from repo root:
#   bash scripts/pack_gcp_overnight_upload.sh
#   gcloud compute scp gcp_overnight_upload.tar.gz lcanalysis-mdast:~/Feb2026/ --zone=us-central1-a

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUNDLE="gcp_overnight_upload.tar.gz"

echo "Packing GCP overnight bundle..."

# Core scripts (always)
FILES=(
  scripts/gcp_overnight_pupil_pipeline.R
  scripts/run_gcp_overnight_detached.sh
  scripts/fit_pupil_ddm_models.R
  scripts/postprocess_pupil_ddm_models.R
  scripts/build_ddm_pupil_ready_data.R
  scripts/build_pupil_trial_features.R
  scripts/sync_pupil_to_publish.R
  scripts/check_vm_capabilities.R
  scripts/pack_pupil_ddm_for_download.sh
  docs/GCP_OVERNIGHT_PUPIL_RUN.md
)

# Optional local artifacts (resume primary fits)
OPTIONAL=(
  output/ddm_pupil/ddm_pupil_ready_thr0.20_probe_onset_locked.csv
  output/ddm_pupil/models/model_0_behavioral.rds
  output/ddm_pupil/models/model_1_pupil_bias.rds
  output/pupil/pupil_trial_features.csv
  data/analysis_ready/ch3_triallevel.csv
)

TAR_ARGS=()
for f in "${FILES[@]}"; do
  if [[ -f "$f" ]]; then
    TAR_ARGS+=("$f")
  else
    echo "  MISSING required: $f" >&2
    exit 1
  fi
done

for f in "${OPTIONAL[@]}"; do
  if [[ -f "$f" ]]; then
    TAR_ARGS+=("$f")
    echo "  + including $f"
  else
    echo "  - skip (not local): $f"
  fi
done

tar -czvf "$BUNDLE" "${TAR_ARGS[@]}"

echo ""
echo "Created: $ROOT/$BUNDLE ($(du -h "$BUNDLE" | cut -f1))"
echo ""
echo "Upload:"
echo "  gcloud compute scp $BUNDLE lcanalysis-mdast:~/Feb2026/ --zone=us-central1-a"
echo ""
echo "On VM:"
echo "  cd ~/Feb2026 && tar -xzvf gcp_overnight_upload.tar.gz"
echo "  bash scripts/run_gcp_overnight_detached.sh"
