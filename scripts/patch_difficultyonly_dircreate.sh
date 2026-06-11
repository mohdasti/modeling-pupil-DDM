#!/usr/bin/env bash
# Hotfix on VM: dir.create() must not receive a length-2 path vector.
# Run from ~/Feb2026 after uploading fixed fit_ddm_difficultyonly.R, or apply inline:
#
#   cd ~/Feb2026
#   bash scripts/patch_difficultyonly_dircreate.sh

set -euo pipefail
F="scripts/fit_ddm_difficultyonly.R"
if [[ ! -f "$F" ]]; then
  echo "Missing $F — upload fixed script from Mac first." >&2
  exit 1
fi
if grep -q 'dir.create(c(MODELS_DIR, LOO_DIR)' "$F"; then
  sed -i.bak 's/dir.create(c(MODELS_DIR, LOO_DIR), recursive = TRUE, showWarnings = FALSE)/dir.create(MODELS_DIR, recursive = TRUE, showWarnings = FALSE)\ndir.create(LOO_DIR, recursive = TRUE, showWarnings = FALSE)/' "$F"
  echo "Patched $F (backup: ${F}.bak)"
else
  echo "Already patched or layout changed — no edit needed."
fi
