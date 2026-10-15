#!/usr/bin/env bash
# Pack the R3 refit for manual upload to the GCP VM (run on the Mac).
#
#   bash scripts/refit_r3/pack_r3_upload.sh
#
# Upload gcp_r3_refit_upload.tar.gz to ~/Feb2026/ on the VM, then:
#   tar -xzvf gcp_r3_refit_upload.tar.gz
#   bash scripts/refit_r3/preflight_r3.sh
#   bash scripts/refit_r3/run_r3_detached.sh
#
# The bundle never contains paths under output/ddm_refits/runs/20260226_092110,
# so extracting it cannot overwrite the canonical run on the VM.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BUNDLE="gcp_r3_refit_upload.tar.gz"
INPUTS="scripts/refit_r3/inputs"
CANON_RDS="output/ddm_refits/runs/20260226_092110/models/additive__probe_onset_locked__thr0.20.rds"
SOURCE_CSV="data/ddm_ready_data_unthresholded.csv"

for f in "$CANON_RDS" "$SOURCE_CSV"; do
  [[ -f "$f" ]] || { echo "ERROR: missing $f" >&2; exit 1; }
done

mkdir -p "$INPUTS"
cp -p "$CANON_RDS" "$INPUTS/"
cp -p "$SOURCE_CSV" "$INPUTS/"
(
  cd "$INPUTS"
  if command -v md5sum >/dev/null 2>&1; then
    md5sum additive__probe_onset_locked__thr0.20.rds ddm_ready_data_unthresholded.csv > md5sums.txt
  else
    for f in additive__probe_onset_locked__thr0.20.rds ddm_ready_data_unthresholded.csv; do
      echo "$(md5 -q "$f")  $f"
    done > md5sums.txt
  fi
)

REQUIRED=(
  scripts/refit_r3/refit_behavioral_r3.R
  scripts/refit_r3/run_r3_detached.sh
  scripts/refit_r3/preflight_r3.sh
  scripts/refit_r3/pack_r3_results.sh
  scripts/refit_r3/README_GCP_R3.md
  "$INPUTS/additive__probe_onset_locked__thr0.20.rds"
  "$INPUTS/ddm_ready_data_unthresholded.csv"
  "$INPUTS/md5sums.txt"
)
for f in "${REQUIRED[@]}"; do
  [[ -f "$f" ]] || { echo "ERROR: missing $f" >&2; exit 1; }
done

COPYFILE_DISABLE=1 tar -czvf "$BUNDLE" "${REQUIRED[@]}"

echo ""
echo "Created: $ROOT/$BUNDLE ($(du -h "$BUNDLE" | cut -f1))"
cat "$INPUTS/md5sums.txt"
echo ""
echo "On the VM (~/Feb2026):"
echo "  tar -xzvf $BUNDLE"
echo "  bash scripts/refit_r3/preflight_r3.sh"
echo "  bash scripts/refit_r3/run_r3_detached.sh"
