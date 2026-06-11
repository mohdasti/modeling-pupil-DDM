#!/usr/bin/env bash
# One-line fix for DATA_FILE ordering bug on GCP VM.
# Run from ~/Feb2026:
#   bash scripts/patch_fit_pupil_data_file.sh

set -euo pipefail
F="scripts/fit_pupil_ddm_models.R"
[[ -f "$F" ]] || { echo "Missing $F — run from project root"; exit 1; }

if grep -q '^DATA_FILE <- Sys.getenv' "$F" && \
   awk '/^LOG_DIR /{l=NR} /^DATA_FILE /{d=NR} END{exit !(d>0 && l>0 && d<NR && d<80)}' "$F"; then
  echo "Already patched (DATA_FILE defined before log_msg)."
  exit 0
fi

cp "$F" "${F}.bak.$(date +%Y%m%d_%H%M%S)"

python3 << 'PY'
from pathlib import Path
p = Path("scripts/fit_pupil_ddm_models.R")
text = p.read_text()
block = '''
DATA_FILE <- Sys.getenv(
  "PUPIL_DATA_FILE",
  here::here("output", "ddm_pupil", "ddm_pupil_ready_thr0.20_probe_onset_locked.csv")
)
'''
needle = 'LOG_DIR <- file.path(OUTPUT_BASE, "logs")\n\nfor (dir in c(MODELS_DIR'
if needle in text and "DATA_FILE <- Sys.getenv" not in text.split("for (dir in c(MODELS_DIR)")[0]:
    text = text.replace(needle, 'LOG_DIR <- file.path(OUTPUT_BASE, "logs")\n' + block + '\nfor (dir in c(MODELS_DIR')
# Remove duplicate DATA_FILE block in Step 1 if present
dup = '''log_msg("STEP 1: Loading data...")

DATA_FILE <- Sys.getenv(
  "PUPIL_DATA_FILE",
  here::here("output", "ddm_pupil", "ddm_pupil_ready_thr0.20_probe_onset_locked.csv")
)

if (!file.exists(DATA_FILE))'''
repl = '''log_msg("STEP 1: Loading data...")

if (!file.exists(DATA_FILE))'''
text = text.replace(dup, repl)
p.write_text(text)
print("Patched", p)
PY

echo "Done. Re-run: bash scripts/run_gcp_overnight_detached.sh"
