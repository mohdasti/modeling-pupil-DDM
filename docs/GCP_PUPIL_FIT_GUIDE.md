# GCP: Pupil-DDM Fit (resume after local crash)

Use the same VM and layout as the **Feb 2026 behavioral refit** (`run_id = 20260226_092110`).

## Known GCP configuration (from repo + prior session)

| Setting | Value |
|---------|--------|
| VM name | `lcanalysis-mdast` |
| User | `mdast003` |
| Zone (default in scripts) | `us-central1-a` |
| Project root on VM | `/home/mdast003/Feb2026` |
| Behavioral run (completed) | `output/ddm_refits/runs/20260226_092110/` |
| MCMC (pupil script) | 4 chains × 2000 iter (1000 warmup), `adapt_delta=0.95` |
| Backend | `cmdstanr` |

If `2026-02-27 02:21:31` is the timestamp you remember, that aligns with the **`20260226_092110`** behavioral run on this VM (not a separate run folder).

**Verify VM is up** (on your Mac):

```bash
gcloud compute instances list
gcloud compute instances describe lcanalysis-mdast --zone=us-central1-a \
  --format="get(machineType,status)"
```

Recommended: **≥ 8 vCPU, ≥ 32 GB RAM** (same class as behavioral refit). Start the VM if stopped:

```bash
gcloud compute instances start lcanalysis-mdast --zone=us-central1-a
```

---

## Local state before upload (Jun 7)

| Artifact | Status |
|----------|--------|
| `output/ddm_pupil/ddm_pupil_ready_thr0.20_probe_onset_locked.csv` | OK — **17,857** trials (cue-locked threshold) |
| `model_0_behavioral.rds` | Done (~31 min) |
| `model_1_pupil_bias.rds` | Done (~25 min) |
| `model_2_pupil_bias_drift.rds` | **Missing** (crash) |
| `model_3_pupil_difficulty_interaction.rds` | Not started |
| `output/ddm_pupil/tables/*.csv` | Empty / stale — regenerate on GCP after fit |

---

## Step 1 — Pack on your Mac

```bash
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM

tar -czvf pupil_gcp_upload.tar.gz \
  scripts/fit_pupil_ddm_models.R \
  scripts/postprocess_pupil_ddm_models.R \
  scripts/build_ddm_pupil_ready_data.R \
  output/ddm_pupil/ddm_pupil_ready_thr0.20_probe_onset_locked.csv \
  output/ddm_pupil/models/model_0_behavioral.rds \
  output/ddm_pupil/models/model_1_pupil_bias.rds
```

---

## Step 2 — Upload to GCP

```bash
gcloud compute scp pupil_gcp_upload.tar.gz \
  lcanalysis-mdast:~/Feb2026/ --zone=us-central1-a
```

SSH / RStudio on VM:

```bash
gcloud compute ssh lcanalysis-mdast --zone=us-central1-a
# or open RStudio Server in browser if configured
```

On VM:

```bash
cd ~/Feb2026
tar -xzvf pupil_gcp_upload.tar.gz
mkdir -p output/ddm_pupil/models
```

---

## Step 3 — Fit on GCP (resume models 2 & 3)

In R on the VM:

```r
setwd("/home/mdast003/Feb2026")

# Sanity check
source("scripts/check_vm_capabilities.R")

Sys.setenv(DDM_RUN_ID = "20260226_092110")
Sys.setenv(PUPIL_REFIT = "on_change")   # reuses model_0 & model_1 from disk

source("scripts/fit_pupil_ddm_models.R")          # ~1 hr (m2 + m3)
source("scripts/postprocess_pupil_ddm_models.R")  # ~5–15 min
```

**Run in `screen` or `tmux`** so disconnect does not kill the job:

```bash
screen -S pupil
cd ~/Feb2026 && Rscript -e 'Sys.setenv(DDM_RUN_ID="20260226_092110", PUPIL_REFIT="on_change"); source("scripts/fit_pupil_ddm_models.R"); source("scripts/postprocess_pupil_ddm_models.R")'
# Detach: Ctrl+A then D
```

---

## Step 4 — Pack results on GCP

```bash
cd ~/Feb2026
tar -czvf pupil_ddm_results_$(date +%Y%m%d).tar.gz \
  output/ddm_pupil/models \
  output/ddm_pupil/tables \
  output/ddm_pupil/figs \
  output/ddm_pupil/logs \
  output/ddm_refits/runs/20260226_092110/models/pupil_interaction__probe_onset_locked__thr0.20.rds
```

---

## Step 5 — Download to Mac

```bash
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM

gcloud compute scp \
  lcanalysis-mdast:~/Feb2026/pupil_ddm_results_*.tar.gz \
  . --zone=us-central1-a

tar -xzvf pupil_ddm_results_*.tar.gz
```

---

## Step 6 — Render manuscript locally

```r
setwd("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM")
quarto::quarto_render("reports/chap3_ddm_results.qmd")
```

---

## What I need from you

1. **Confirm VM still exists** — output of `gcloud compute instances list`
2. **Confirm zone** — if not `us-central1-a`, tell me (or set `GCP_ZONE`)
3. **Can you SSH / RStudio on the VM?** — same access as Feb 26
4. **Optional:** machine type if you changed it since behavioral refit

If the VM was deleted, create a new one (Ubuntu 22.04, **n2-standard-8** or larger, 100 GB disk), install R + cmdstanr + brms, clone/copy `~/Feb2026`, then follow steps above.

---

## Expected outputs (for §3.3)

- `output/ddm_pupil/tables/pupil_effects_key_terms.csv`
- `output/ddm_pupil/tables/pupil_convergence_summary.csv`
- `output/ddm_pupil/tables/pupil_loo_summary.csv` (report k and N only)
- `output/ddm_pupil/tables/model_info.csv` — all models `n_trials ≈ 12287`
- 4× `output/ddm_pupil/models/model_*.rds`
