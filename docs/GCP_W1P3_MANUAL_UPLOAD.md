# Manual GCP Upload: w1p3 Pupil Sensitivity

Use this when you **cannot** `gcloud scp` from your Mac. Upload via the Posit/RStudio **Files** pane instead.

## What’s in the bundle

| File | Purpose |
|------|---------|
| `data/pupil_processed/analysis_ready/ch3_triallevel.csv` | Trial-level pupil features with **`cog_auc_w1p3`** (~9,099 non-NA) |
| `scripts/make_quick_share_v7.R` | Merge fix (w1p3 no longer dropped on join) |
| `scripts/build_pupil_trial_features.R` | Rebuild `output/pupil/pupil_trial_features.csv` |
| `scripts/build_ddm_pupil_ready_data.R` | Rebuild DDM pupil-ready CSV with `pupil_w1p3_z` |
| `scripts/fit_pupil_ddm_models.R` | Fit 4 nested w1p3 models |
| `scripts/postprocess_pupil_ddm_models.R` | LOO + key-effects tables |
| `scripts/apply_w1p3_on_vm.sh` | One-command rebuild (+ optional `--fit`) |

## Step 1 — Create bundle on Mac

```bash
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM
bash scripts/pack_gcp_w1p3_upload.sh
```

Output: **`gcp_w1p3_upload.tar.gz`** in the repo root (~7–8 MB).

## Step 2 — Upload to VM (manual)

1. Open Posit / RStudio on `lcanalysis-mdast` (`~/Feb2026`).
2. Files pane → navigate to **`Feb2026`** (project root).
3. **Upload** `gcp_w1p3_upload.tar.gz` (drag-and-drop or Upload button).

## Step 3 — Extract on VM

In the Posit terminal:

```bash
cd ~/Feb2026
tar -xzvf gcp_w1p3_upload.tar.gz
chmod +x scripts/apply_w1p3_on_vm.sh
```

This places files at:

- `~/Feb2026/data/pupil_processed/analysis_ready/ch3_triallevel.csv`
- Updated scripts under `~/Feb2026/scripts/`

## Step 4 — Rebuild pupil join (required)

```bash
cd ~/Feb2026
bash scripts/apply_w1p3_on_vm.sh
```

Expected verification output:

```
pupil_metric_primary_z non-NA: ~12287
pupil_w1p3_z non-NA: ~12000+   # NOT 0
```

## Step 5 — Fit w1p3 models (long; ~3–6 h)

**Option A — same script with fit flag:**

```bash
bash scripts/apply_w1p3_on_vm.sh --fit
```

**Option B — manual (use tmux if you log out):**

```bash
export PUPIL_OUTPUT_BASE=output/ddm_pupil_w1p3
export PUPIL_Z_COL=pupil_w1p3_z
export PUPIL_METRIC_LABEL="Truncated AUC (w1p3, 0.3-1.3 s)"

Rscript scripts/fit_pupil_ddm_models.R
PUPIL_OUTPUT_BASE=output/ddm_pupil_w1p3 Rscript scripts/postprocess_pupil_ddm_models.R
```

Fit log must show **`Trials with valid pupil: ~12000+`**, not 0.

## Step 6 — Download results to Mac

On VM:

```bash
bash scripts/pack_pupil_ddm_for_download.sh
```

Download the resulting tarball via the Files pane, extract into your local repo under `output/ddm_pupil_w1p3/`.

Optional window comparison:

```bash
Rscript -e '
lp <- read.csv("output/ddm_pupil/tables/pupil_loo_summary.csv")
lw <- read.csv("output/ddm_pupil_w1p3/tables/pupil_loo_summary.csv")
lp$tepr_window <- "w3_primary"
lw$tepr_window <- "w1p3_truncated"
write.csv(rbind(lp, lw),
  "output/ddm_pupil/tables/pupil_loo_window_comparison.csv", row.names=FALSE)
'
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `pupil_w1p3_z non-NA: 0` after rebuild | Re-upload bundle; confirm source `cog_auc_w1p3 non-NA` > 1000 on VM |
| `cog_auc_w1p3 present: FALSE` in features | Old `ch3_triallevel.csv`; re-extract tarball |
| Postprocess writes to primary folder | Set `PUPIL_OUTPUT_BASE=output/ddm_pupil_w1p3` on **both** fit and postprocess |
| Fit finishes in &lt;1 s | Empty data — do not proceed; fix Step 4 first |
