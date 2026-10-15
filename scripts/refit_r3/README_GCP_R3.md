# R3 behavioral refit on GCP

Fits M0–M3 (wiener, 8 chains × 3000 iter) on the canonical 0.20 s data, runs PSIS-LOO with moment matching and capped reloo, writes `loo_compare` plus pointwise forensics, and refits the primary model at the 0.15 s and 0.25 s cue-locked cutoffs.
Everything is written to `output/ddm_refits/runs/r3_<timestamp>/`. Nothing under `runs/20260226_092110/` is written.

## VM

- Recommended: **n2-standard-16 or larger** (16 vCPU, 64 GB RAM). Each LOO holds about 1.7 GB of log-likelihood, and the 8 chains run in parallel.
- On 16 vCPU: 8 chains × 2 threads. Roughly 1–2 h per fit, 6 fits in total. LOO, moment matching and reloo add a few hours. Expect about **10–16 h** in total.
- On 8 vCPU it still works (8 chains × 1 thread, about 1.5× slower).

## 1. Pack (Mac)

```bash
cd ~/Documents/GitHub/modeling-pupil-DDM
bash scripts/refit_r3/pack_r3_upload.sh
```

This produces `gcp_r3_refit_upload.tar.gz`, which contains the script, the launch, preflight and pack helpers, the canonical additive `.rds` (source of the 17,857-row data), `ddm_ready_data_unthresholded.csv` (source for the 0.15/0.25 cutoffs), and `md5sums.txt`.

## 2. Upload

Posit Files pane: upload to `~/Feb2026/`.

## 3. Extract, preflight, launch (VM terminal)

```bash
cd ~/Feb2026
tar -xzvf gcp_r3_refit_upload.tar.gz
bash scripts/refit_r3/preflight_r3.sh        # packages, md5, ~5 min smoke test in /tmp
bash scripts/refit_r3/run_r3_detached.sh     # tmux session r3_refit
```

Monitor:

```bash
tmux attach -t r3_refit                      # detach: Ctrl-b d
RUN=output/ddm_refits/runs/$(cat output/ddm_refits/runs/r3_latest_run_id.txt)
tail -f $RUN/logs/r3_status.txt
```

Resume after an interruption. Finished fits and LOOs are cached and reused:

```bash
RESUME=true bash scripts/refit_r3/run_r3_detached.sh
```

Optional environment variables: `R3_CORES`, `R3_THREADS`, `R3_LOO_CORES`, `R3_RELOO=0` (skip reloo), `R3_RELOO_MAX` (default 5; reloo is skipped if more points remain), `R3_STAGES=fit,loo,compare,sens,summary`.

## 4. Download

```bash
bash scripts/refit_r3/pack_r3_results.sh                      # tables + loo + logs
INCLUDE_MODELS=true bash scripts/refit_r3/pack_r3_results.sh  # + model rds (large)
```

Download `gcp_r3_<timestamp>_results.tar.gz` from the Files pane.

## 5. After download (Mac)

```bash
tar -xzvf gcp_r3_*_results.tar.gz
```

The main output is `output/ddm_refits/runs/r3_<timestamp>/tables/r3_summary.md`.
