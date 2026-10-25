#!/bin/bash
# Run the r12 extract, the effort t-tests, and the pupil fits. The fits are the long step.
set -euo pipefail
cd "$(dirname "$0")/../.."
STAMP=$(date +%Y%m%d_%H%M%S)
nohup bash -c "
set -euo pipefail
cd \"$(pwd)\"
Rscript scripts/r12/extract_m2_r11.R
Rscript scripts/r12/compute_effort_ttests.R
Rscript scripts/r12/fit_pupil_r12.R
RUN=\$(tr -d '[:space:]' < output/ddm_refits/runs/r12_latest_run_id.txt)
tar -czf \"r12_results_${STAMP}.tar.gz\" \\
  \"output/ddm_refits/runs/\${RUN}\" \\
  m2_r11_interactions.csv \\
  output/ddm_refits/runs/r12_effort_ttests
" > r12_run.log 2>&1 &
echo "r12 started, pid $!. Log: r12_run.log"
