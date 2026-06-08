#!/bin/bash
# Pack pupil-DDM outputs on the GCP VM into one tarball for Posit download.
#
# Run ON THE VM (Posit terminal), from anywhere:
#   bash ~/Feb2026/scripts/pack_pupil_ddm_for_download.sh
#
# Or:
#   cd ~/Feb2026 && bash scripts/pack_pupil_ddm_for_download.sh
#
# Creates:
#   ~/Feb2026/pupil_ddm_results_YYYYMMDD.tar.gz
#   ~/Feb2026/pupil_ddm_results_YYYYMMDD_manifest.txt
#
# On your Mac after downloading the .tar.gz via Posit Files:
#   cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM
#   tar -xzvf ~/Downloads/pupil_ddm_results_YYYYMMDD.tar.gz

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$HOME/Feb2026}"
RUN_ID="${DDM_RUN_ID:-20260226_092110}"
STAMP="$(date +%Y%m%d)"
ARCHIVE_NAME="pupil_ddm_results_${STAMP}.tar.gz"
MANIFEST_NAME="pupil_ddm_results_${STAMP}_manifest.txt"

cd "${PROJECT_ROOT}"

PUPIL_BASE="output/ddm_pupil"
RUN_INTERACTION="output/ddm_refits/runs/${RUN_ID}/models/pupil_interaction__probe_onset_locked__thr0.20.rds"

# Required outputs (relative to PROJECT_ROOT)
REQUIRED_PATHS=(
  "${PUPIL_BASE}/models/model_0_behavioral.rds"
  "${PUPIL_BASE}/models/model_1_pupil_bias.rds"
  "${PUPIL_BASE}/models/model_2_pupil_bias_drift.rds"
  "${PUPIL_BASE}/models/model_3_pupil_difficulty_interaction.rds"
  "${PUPIL_BASE}/tables/pupil_effects_key_terms.csv"
  "${PUPIL_BASE}/tables/pupil_loo_summary.csv"
  "${PUPIL_BASE}/tables/pupil_convergence_summary.csv"
  "${PUPIL_BASE}/tables/model_info.csv"
  "${PUPIL_BASE}/tables/pupil_fixef_link_scale.csv"
  "${PUPIL_BASE}/figs/fig_pupil_bias_effect.png"
  "${PUPIL_BASE}/figs/fig_pupil_drift_effect.png"
  "${PUPIL_BASE}/logs/fit_pupil_ddm_models.log"
  "${PUPIL_BASE}/logs/postprocess_pupil_ddm_models.log"
  "${RUN_INTERACTION}"
)

# Directories to include wholesale (skip macOS AppleDouble files)
INCLUDE_DIRS=(
  "${PUPIL_BASE}/models"
  "${PUPIL_BASE}/tables"
  "${PUPIL_BASE}/figs"
  "${PUPIL_BASE}/logs"
)

echo "================================================================================"
echo "PACK PUPIL-DDM RESULTS FOR DOWNLOAD"
echo "================================================================================"
echo "Project root: ${PROJECT_ROOT}"
echo "Run ID:       ${RUN_ID}"
echo ""

# --- Manifest: list everything we care about ---
{
  echo "Pupil-DDM download manifest"
  echo "Generated: $(date -Iseconds)"
  echo "Project root: ${PROJECT_ROOT}"
  echo "Run ID: ${RUN_ID}"
  echo ""
  echo "=== Required files ==="
} > "${MANIFEST_NAME}"

missing=0
for rel in "${REQUIRED_PATHS[@]}"; do
  if [[ -f "${rel}" ]]; then
    size="$(du -h "${rel}" | cut -f1)"
    printf "  OK   %-8s  %s\n" "${size}" "${rel}"
    printf "OK\t%s\t%s\n" "${size}" "${rel}" >> "${MANIFEST_NAME}"
  else
    printf "  MISS              %s\n" "${rel}"
    printf "MISS\t\t%s\n" "${rel}" >> "${MANIFEST_NAME}"
    missing=$((missing + 1))
  fi
done

echo ""
echo "=== Optional tables (included if present) ==="
{
  echo ""
  echo "=== Optional tables ==="
} >> "${MANIFEST_NAME}"

shopt -s nullglob
for opt in \
  "${PUPIL_BASE}/tables/pupil_fixef_link_scale_pupil_only.csv" \
  "${PUPIL_BASE}/tables/pupil_predicted_bias_by_condition.csv" \
  "${PUPIL_BASE}/tables/pupil_predicted_drift_by_condition.csv"
do
  if [[ -f "${opt}" ]]; then
    size="$(du -h "${opt}" | cut -f1)"
    printf "  OK   %-8s  %s\n" "${size}" "${opt}"
    printf "OK\t%s\t%s\n" "${size}" "${opt}" >> "${MANIFEST_NAME}"
  fi
done
shopt -u nullglob

echo ""
if [[ "${missing}" -gt 0 ]]; then
  echo "WARNING: ${missing} required file(s) missing. Archive will still be created"
  echo "         from available directories, but download may be incomplete."
  echo ""
fi

# --- Build file list for tar (exclude ._* junk from Mac uploads) ---
TAR_LIST="$(mktemp)"
trap 'rm -f "${TAR_LIST}"' EXIT

for dir in "${INCLUDE_DIRS[@]}"; do
  if [[ -d "${dir}" ]]; then
    find "${dir}" -type f ! -name '._*' ! -name '.DS_Store' >> "${TAR_LIST}"
  else
    echo "WARNING: directory missing: ${dir}"
  fi
done

if [[ -f "${RUN_INTERACTION}" ]]; then
  echo "${RUN_INTERACTION}" >> "${TAR_LIST}"
fi

# Deduplicate paths
sort -u "${TAR_LIST}" -o "${TAR_LIST}"

n_files="$(wc -l < "${TAR_LIST}" | tr -d ' ')"
total_bytes="$(awk '{print $0}' "${TAR_LIST}" | xargs -r du -cb 2>/dev/null | tail -1 | cut -f1 || echo 0)"
total_human="$(numfmt --to=iec-i --suffix=B "${total_bytes}" 2>/dev/null || echo "${total_bytes} bytes")"

{
  echo ""
  echo "=== Archive contents (${n_files} files, ~${total_human}) ==="
  cat "${TAR_LIST}"
} >> "${MANIFEST_NAME}"

echo "Creating archive (${n_files} files, ~${total_human})..."
tar -czvf "${ARCHIVE_NAME}" -T "${TAR_LIST}"

archive_size="$(du -h "${ARCHIVE_NAME}" | cut -f1)"

echo ""
echo "================================================================================"
echo "DONE"
echo "================================================================================"
echo ""
echo "Download THESE two files from Posit Files pane:"
echo "  ${PROJECT_ROOT}/${ARCHIVE_NAME}"
echo "  ${PROJECT_ROOT}/${MANIFEST_NAME}   (optional checklist)"
echo ""
echo "Archive size: ${archive_size}"
echo ""
echo "On your Mac, extract into the repo root:"
echo "  cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM"
echo "  tar -xzvf ~/Downloads/${ARCHIVE_NAME}"
echo ""
echo "Verify:"
echo "  ls output/ddm_pupil/models/"
echo "  ls output/ddm_pupil/tables/"
echo ""
echo "Then render:"
echo "  quarto render reports/chap3_ddm_results.qmd"
echo ""

if [[ "${missing}" -gt 0 ]]; then
  exit 1
fi
