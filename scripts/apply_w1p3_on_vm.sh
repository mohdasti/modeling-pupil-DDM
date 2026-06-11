#!/usr/bin/env bash
# Apply w1p3 upload on GCP VM: rebuild pupil join, verify, optionally fit w1p3 models.
# Run from ~/Feb2026 after extracting gcp_w1p3_upload.tar.gz:
#   bash scripts/apply_w1p3_on_vm.sh          # rebuild + verify only
#   bash scripts/apply_w1p3_on_vm.sh --fit    # also launch w1p3 MCMC (long)

set -euo pipefail

ROOT="${PROJECT_ROOT:-$HOME/Feb2026}"
cd "$ROOT"

DO_FIT=false
if [[ "${1:-}" == "--fit" ]]; then
  DO_FIT=true
fi

echo "=== w1p3 apply script ==="
echo "ROOT: $ROOT"
echo ""

CH3="data/pupil_processed/analysis_ready/ch3_triallevel.csv"
if [[ ! -f "$CH3" ]]; then
  echo "ERROR: $CH3 not found. Extract gcp_w1p3_upload.tar.gz in $ROOT first." >&2
  exit 1
fi

W1P3_N=$(Rscript -e "d<-read.csv('$CH3'); cat(sum(!is.na(d[['cog_auc_w1p3']])))")
echo "Source cog_auc_w1p3 non-NA: $W1P3_N"
if [[ "${W1P3_N:-0}" -lt 1000 ]]; then
  echo "ERROR: Source file still missing w1p3 values." >&2
  exit 1
fi

echo ""
echo "Step 1/3: build_pupil_trial_features.R"
Rscript scripts/build_pupil_trial_features.R

echo ""
echo "Step 2/3: build_ddm_pupil_ready_data.R"
Rscript scripts/build_ddm_pupil_ready_data.R

echo ""
echo "Step 3/3: verify ready CSV"
Rscript -e '
d <- read.csv("output/ddm_pupil/ddm_pupil_ready_thr0.20_probe_onset_locked.csv")
n_pri <- sum(!is.na(d$pupil_metric_primary_z))
n_w1 <- sum(!is.na(d$pupil_w1p3_z))
cat("pupil_metric_primary_z non-NA:", n_pri, "\n")
cat("pupil_w1p3_z non-NA:", n_w1, "\n")
if (n_w1 < 1000) stop("pupil_w1p3_z still too sparse — check build logs")
'

echo ""
echo "✓ Rebuild OK. Ready for w1p3 fits."

if [[ "$DO_FIT" == true ]]; then
  echo ""
  echo "Starting w1p3 fit + postprocess (several hours)..."
  export PUPIL_OUTPUT_BASE=output/ddm_pupil_w1p3
  export PUPIL_Z_COL=pupil_w1p3_z
  export PUPIL_METRIC_LABEL="Truncated AUC (w1p3, 0.3-1.3 s)"
  Rscript scripts/fit_pupil_ddm_models.R
  PUPIL_OUTPUT_BASE=output/ddm_pupil_w1p3 Rscript scripts/postprocess_pupil_ddm_models.R
  echo "✓ Fit complete. Pack download: bash scripts/pack_pupil_ddm_for_download.sh"
else
  echo ""
  echo "To fit models, run:"
  echo "  export PUPIL_OUTPUT_BASE=output/ddm_pupil_w1p3"
  echo "  export PUPIL_Z_COL=pupil_w1p3_z"
  echo "  export PUPIL_METRIC_LABEL=\"Truncated AUC (w1p3, 0.3-1.3 s)\""
  echo "  Rscript scripts/fit_pupil_ddm_models.R"
  echo "  PUPIL_OUTPUT_BASE=output/ddm_pupil_w1p3 Rscript scripts/postprocess_pupil_ddm_models.R"
  echo ""
  echo "Or: bash scripts/apply_w1p3_on_vm.sh --fit"
fi
