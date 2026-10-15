#!/usr/bin/env bash
# Preflight for the R3 refit on the VM: packages, CmdStan, inputs, md5, resources.
# Then a ~5-minute smoke test (subset data, tiny sampler) into /tmp.
#
#   cd ~/Feb2026 && bash scripts/refit_r3/preflight_r3.sh
#   SKIP_SMOKE=true bash scripts/refit_r3/preflight_r3.sh

set -euo pipefail

ROOT="${PROJECT_ROOT:-$HOME/Feb2026}"
cd "$ROOT"

echo "== Resources =="
echo "cores: $(nproc 2>/dev/null || sysctl -n hw.ncpu)"
free -g 2>/dev/null | head -2 || true
df -h . | tail -1

echo ""
echo "== Inputs and md5 =="
CANON="output/ddm_refits/runs/20260226_092110/models/additive__probe_onset_locked__thr0.20.rds"
if [[ -f "$CANON" ]]; then
  echo "canonical:  $(md5sum "$CANON")"
else
  echo "canonical:  MISSING on VM (script will use the bundled copy)"
fi
(cd scripts/refit_r3/inputs && md5sum -c md5sums.txt)

echo ""
echo "== R packages =="
Rscript -e '
pk <- c("brms","cmdstanr","posterior","loo","dplyr","readr","tibble","rstan")
for (p in pk) cat(sprintf("%-10s %s\n", p, if (requireNamespace(p, quietly=TRUE)) as.character(packageVersion(p)) else "MISSING"))
cat("CmdStan   ", tryCatch(as.character(cmdstanr::cmdstan_version()), error=function(e) "MISSING"), "\n")
'

if [[ "${SKIP_SMOKE:-false}" != "true" ]]; then
  echo ""
  echo "== Smoke test (subset, 2 chains x 60 iterations; writes to /tmp/r3_smoke) =="
  mkdir -p /tmp/r3_smoke
  R3_SMOKE=1 R3_OUT_ROOT=/tmp/r3_smoke R3_CORES=2 R3_THREADS=1 R3_LOO_CORES=2 \
    Rscript scripts/refit_r3/refit_behavioral_r3.R > /tmp/r3_smoke/smoke_console.log 2>&1 \
    && echo "SMOKE OK: $(cat /tmp/r3_smoke/r3_smoke_latest_run_id.txt)" \
    || { echo "SMOKE FAILED; see /tmp/r3_smoke/smoke_console.log"; tail -30 /tmp/r3_smoke/smoke_console.log; exit 1; }
  RUN="/tmp/r3_smoke/$(cat /tmp/r3_smoke/r3_smoke_latest_run_id.txt)"
  grep -E "FAILED" "$RUN/logs/r3_status.txt" && { echo "Smoke run logged failures above."; exit 1; } || true
  echo "Smoke summary: $RUN/tables/r3_summary.md"
fi
