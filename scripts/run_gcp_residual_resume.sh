#!/usr/bin/env bash
# Resume residual pipeline after difficulty-only + PPC already completed.
#
#   cd ~/Feb2026
#   bash scripts/run_gcp_residual_resume.sh

set -euo pipefail

export SKIP_DIFFICULTY_ONLY=true
export SKIP_PPC=true

exec bash scripts/run_gcp_residual_detached.sh
