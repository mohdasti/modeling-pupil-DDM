# GCP Phase-2 Manuscript Analyses

Closes reviewer gaps **7–8** plus **tail ESS** in Table 10.

## What this run does

| Step | Script | Output | Runtime (est.) |
|------|--------|--------|----------------|
| 1 | `extract_convergence_extended.R` | `convergence_primary_extended.csv` (tail ESS) | seconds |
| 2 | `fit_sensitivity_additive_thresholds.R` | additive models at 0.15 / 0.25 s (+ export) | ~1.5 h each (0.20 skipped if present) |
| 3 | `export_ppc_primary_diagnostic.R` | `ppc_cells_midbody.csv` | 1–2 h |
| 4 | `make_publish_gate.R` | `publish_gate_primary_censored.csv` with tail ESS | seconds |

**Prerequisites:** canonical run `20260226_092110`, `data/ddm_ready_data_unthresholded.csv`, primary additive model at thr 0.20, **working `rstan` + `brms` + `cmdstanr`** on the VM.

### If preflight fails with `class_model_base` / Rcpp errors

This means `rstan` was compiled for a different R/Rcpp version. On the VM:

```bash
cd ~/Feb2026
Rscript scripts/fix_rstan_vm.R
Rscript scripts/check_brms_preflight.R   # should exit 0
```

Then restart the pipeline (kill old tmux session if needed):

```bash
tmux kill-session -t manuscript_phase2 2>/dev/null || true
bash scripts/run_gcp_phase2_detached.sh
```

The upload tarball may include pre-computed `convergence_primary_extended.csv` from Mac; the pipeline skips re-extracting it when that file is present.

## Upload & run

```bash
# Mac
bash scripts/pack_gcp_phase2_upload.sh

# VM (after upload to ~/Feb2026/)
tar -xzvf gcp_phase2_upload.tar.gz
chmod +x scripts/run_gcp_phase2_detached.sh
bash scripts/run_gcp_phase2_detached.sh
# Step status (appears once R starts; launcher also creates the file):
tail -f output/ddm_refits/runs/20260226_092110/logs/gcp_phase2_status.txt
# Full live log (works immediately):
tail -f output/ddm_refits/runs/20260226_092110/logs/gcp_phase2_master.log
```

### Skip options

```bash
# Only fit sensitivity (PPC already done)
SKIP_PPC_MIDBODY=true bash scripts/run_gcp_phase2_detached.sh

# Only PPC + gate (sensitivity already done)
SKIP_SENSITIVITY_ADDITIVE=true bash scripts/run_gcp_phase2_detached.sh
```

## Download

```bash
bash scripts/pack_gcp_phase2_results_for_download.sh
```

Extract tarball into repo root, then:

```bash
quarto render reports/chap3_ddm_results.qmd --to pdf
```

## Mac-only (no GCP)

```bash
DDM_RUN_ID=20260226_092110 Rscript scripts/R/extract_convergence_extended.R
DDM_RUN_ID=20260226_092110 Rscript scripts/export_h1_h2_by_rt_cutoff.R   # 0.20 only until fits done
DDM_RUN_ID=20260226_092110 Rscript scripts/R/export_ppc_primary_diagnostic.R
DDM_RUN_ID=20260226_092110 Rscript scripts/R/make_publish_gate.R
```
