# GCP Overnight Pupil-DDM Run

Complete primary pupil models (if needed), regenerate tables, and run **truncated AUC (w1p3)** sensitivity — detached from Posit logout.

## Known VM configuration

| Setting | Value |
|---------|--------|
| VM | `lcanalysis-mdast` |
| User | `mdast003` |
| Zone | `us-central1-a` |
| Project root | `/home/mdast003/Feb2026` |
| Behavioral run (on VM) | `output/ddm_refits/runs/20260226_092110/` |
| MCMC | 4×2000 iter, `adapt_delta=0.95`, cmdstanr |

Start VM if stopped:

```bash
gcloud compute instances start lcanalysis-mdast --zone=us-central1-a
```

---

## Step 1 — Pack on Mac

```bash
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM
bash scripts/pack_gcp_overnight_upload.sh
```

Includes updated scripts. Optionally bundles local `model_0`/`model_1` and pupil CSV if present.

---

## Step 2 — Upload

```bash
gcloud compute scp gcp_overnight_upload.tar.gz \
  lcanalysis-mdast:~/Feb2026/ --zone=us-central1-a
```

---

## Step 3 — Extract on VM (Posit terminal)

```bash
cd ~/Feb2026
tar -xzvf gcp_overnight_upload.tar.gz
chmod +x scripts/run_gcp_overnight_detached.sh
```

**Prerequisite on VM:** behavioral run folder and pupil source data should already be there from Feb refit. If `output/pupil/pupil_trial_features.csv` or `data/analysis_ready/ch3_triallevel.csv` is missing, upload one of them or set `REBUILD_PUPIL_DATA=yes` only after those exist.

---

## Step 4 — Launch detached (survives logout)

```bash
cd ~/Feb2026
bash scripts/run_gcp_overnight_detached.sh
```

This uses **tmux** if available (recommended on Posit):

| Action | Command |
|--------|---------|
| Watch live | `tmux attach -t pupil_overnight` |
| Detach | `Ctrl+B` then `D` |
| Tail log | `tail -f output/ddm_pupil/logs/gcp_overnight_console.log` |
| Step checklist | `tail -f output/ddm_pupil/logs/gcp_overnight_status.txt` |

If tmux is missing, the script falls back to **nohup** and writes PID to `output/ddm_pupil/logs/gcp_overnight.pid`.

**You can close Posit / log out** once tmux/nohup starts.

---

## What runs overnight (~3–6 h if m2–m3 + w1p3)

1. VM capability check  
2. Rebuild pupil join **only if** `pupil_w1p3_z` missing from ready CSV  
3. **Primary window (w3):** fit models 0–3 → postprocess → sync to `output/pupil_ddm/`  
4. **Truncated window (w1p3):** same 4 models in `output/ddm_pupil_w1p3/`  
5. Write `output/ddm_pupil/tables/pupil_loo_window_comparison.csv`

`PUPIL_REFIT=on_change` (default) reuses existing `.rds` on disk.

Force full refit:

```bash
PUPIL_REFIT=always bash scripts/run_gcp_overnight_detached.sh
```

Skip w1p3 (primary only):

```bash
SKIP_W1P3=true bash scripts/run_gcp_overnight_detached.sh
```

---

## Step 5 — Morning: verify on VM

```bash
cd ~/Feb2026
cat output/ddm_pupil/logs/gcp_overnight_status.txt | tail -20
ls -la output/ddm_pupil/models/
ls -la output/ddm_pupil/tables/
ls -la output/ddm_pupil_w1p3/models/ 2>/dev/null || echo "w1p3 skipped or failed"
```

Expected primary tables:

- `pupil_loo_summary.csv`
- `pupil_effects_key_terms.csv`
- `pupil_convergence_summary.csv`
- `model_info.csv`

---

## Step 6 — Pack & download

On VM:

```bash
cd ~/Feb2026
bash scripts/pack_pupil_ddm_for_download.sh
```

Download via Posit Files pane **or** Mac:

```bash
gcloud compute scp \
  lcanalysis-mdast:~/Feb2026/pupil_ddm_results_*.tar.gz \
  ~/Downloads/ --zone=us-central1-a
```

Extract locally:

```bash
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM
tar -xzvf ~/Downloads/pupil_ddm_results_YYYYMMDD.tar.gz
quarto render reports/chap3_ddm_results.qmd --to pdf
```

Also download w1p3 folder if present:

```bash
gcloud compute scp --recurse \
  lcanalysis-mdast:~/Feb2026/output/ddm_pupil_w1p3 \
  output/ --zone=us-central1-a
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Session already running | `tmux attach -t pupil_overnight` or `tmux kill-session -t pupil_overnight` |
| Job died after logout | Re-run `run_gcp_overnight_detached.sh`; `on_change` skips finished models |
| `cog_auc_w1p3` missing | Upload fresh `ch3_triallevel.csv`; `REBUILD_PUPIL_DATA=yes` |
| Out of disk | `df -h ~`; delete old Stan temp in `/tmp` |

---

## Environment reference

```bash
export DDM_RUN_ID=20260226_092110
export PUPIL_REFIT=on_change      # on_change | always
export REBUILD_PUPIL_DATA=auto    # auto | yes
export SKIP_W1P3=false            # true to skip truncated sensitivity
export PROJECT_ROOT=$HOME/Feb2026
```
