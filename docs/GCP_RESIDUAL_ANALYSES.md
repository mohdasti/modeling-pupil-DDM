# GCP Residual Manuscript Analyses

Resolves remaining **computable** ambiguities after primary + truncated pupil-DDM fits.

## What this run does

| Step | Analysis | Resolves | Runtime (est.) |
|------|----------|----------|----------------|
| 1 | **Difficulty-only LOO** (`fit_ddm_difficultyonly.R`) | Appendix A1 TODO: show difficulty-only row in LOO table (vs additive) | ~2–4 h |
| 2 | **PPC regen** (`sync_publish` → `export_ppc_primary_diagnostic` → `make_publish_gate`) | Appendix A3 figure–table parity, max-KS / gate consistency with run `20260226_092110` | 1–3 h |
| 3 | **Cavanagh pupil → boundary ($a$)** on Decision-Response AUC | Intro/methods gap: was pupil→$a$ tested? | ~1 h |
| 4 | **Cavanagh pupil → boundary** on Truncated Decision-Response AUC | Same test under narrower TEPR window | ~1 h |
| 5 | **`pupil_loo_all_models.csv`** | Single LOO table: m0–m3 + boundary (both windows) | seconds |

**Prerequisites on VM** (you already have these from prior runs):

- `output/ddm_refits/runs/20260226_092110/` (behavioral canonical run)
- `output/ddm_pupil/` with nested models m0–m3 + ready CSV with `pupil_w1p3_z`
- `output/ddm_pupil_w1p3/` (truncated nested models — already completed)

**Not included** (dissertation-scale, not a patch):

- Mixture / $s_v$ DDM (Chapter 2 scope)
- Non-motor effort manipulation (new data collection)

---

## Step 1 — Pack on Mac

```bash
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM
bash scripts/pack_gcp_residual_analyses_upload.sh
```

Creates **`gcp_residual_analyses_upload.tar.gz`** (~small; scripts only).

---

## Step 2 — Upload to VM

Posit Files → upload to **`~/Feb2026/`**

---

## Step 3 — Extract and launch on VM

```bash
cd ~/Feb2026
tar -xzvf gcp_residual_analyses_upload.tar.gz
chmod +x scripts/run_gcp_residual_detached.sh
bash scripts/run_gcp_residual_detached.sh
```

Monitor:

```bash
tmux attach -t manuscript_residual
# or
tail -f output/ddm_pupil/logs/gcp_residual_status.txt
```

### Skip options

```bash
# Boundary + pupil LOO only (if PPC + difficulty-only already done)
SKIP_PPC=true SKIP_DIFFICULTY_ONLY=true bash scripts/run_gcp_residual_detached.sh

# PPC only (skip models)
SKIP_BOUNDARY=true SKIP_BOUNDARY_W1P3=true SKIP_DIFFICULTY_ONLY=true bash scripts/run_gcp_residual_detached.sh
```

---

## Step 4 — Download results

On VM:

```bash
bash scripts/pack_gcp_residual_results_for_download.sh
```

Download **`gcp_residual_results_YYYYMMDD.tar.gz`** via Posit Files.

Extract on Mac into repo root:

```bash
cd /Users/mohdasti/Documents/GitHub/modeling-pupil-DDM
tar -xzvf ~/Downloads/gcp_residual_results_YYYYMMDD.tar.gz
```

---

## Step 5 — After download (Mac)

1. Re-render: `quarto render reports/chap3_ddm_results.qmd --to pdf`
2. We will update QMD prose for:
   - **Option C** intro (align with fitted models including pupil→$a$)
   - Cavanagh boundary results in §3.3 / Appendix A5
   - PPC appendix if numbers shifted

---

## Key output paths

```
output/publish/
  table3_ppc_primary_subjectwise_censored.csv   # Appendix A3
  ppc_gate_summary.csv

output/ddm_refits/runs/20260226_092110/loo/
  loo_difficultyonly_primary_thr.rds

output/ddm_pupil_boundary/
  models/model_1p_pupil_boundary.rds
  tables/pupil_boundary_loo_summary.csv
  tables/pupil_boundary_key_terms.csv

output/ddm_pupil_boundary_w1p3/
  (same structure, truncated TEPR)

output/ddm_pupil/tables/
  pupil_loo_all_models.csv          # merged LOO
  pupil_loo_window_comparison.csv   # refreshed if w1p3 present
```

---

## Terminology (manuscript)

| Internal (scripts) | Reader-facing |
|--------------------|---------------|
| `ddm_pupil_boundary` | Cavanagh-style pupil → boundary model |
| `pupil_metric_primary_z` | Decision-Response AUC (0.3–3.3 s post-probe) |
| `pupil_w1p3_z` | Truncated Decision-Response AUC (0.3–1.3 s post-probe) |
| `model_1p_pupil_boundary` | Pupil → $a$ (boundary separation) extension |

Do **not** use W3.0 / W1.3 / w1p3 in manuscript prose.
