# GCP RStudio Cloud: Files to Upload

Run the DDM refit pipeline on Google Cloud Platform (RStudio Cloud). Upload these files before running the script.

---

## Option A: Minimal (recommended)

**One file** — the pre-built DDM-ready data. No need to rebuild from raw.

| File | Path on your machine |
|------|----------------------|
| DDM-ready data (unthresholded) | `data/ddm_ready_data_unthresholded.csv` |

**Upload to GCP:** Place in `data/ddm_ready_data_unthresholded.csv` (relative to project root).

---

## Option B: Rebuild from raw

If you want to regenerate the DDM-ready data on GCP:

| File | Path on your machine |
|------|----------------------|
| Raw behavioral trial data | `data/bap_beh_trialdata_v3.csv` **or** `/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v3.csv` |

**Note:** `bap_beh_trialdata_v3.csv` is not in the repo. It typically lives in the LC-BAP project. Copy it into `data/` before upload.

**Steps:**
1. Run `scripts/build_ddm_ready_data_unthresholded.R` first (creates `data/ddm_ready_data_unthresholded.csv`)
2. Then run `scripts/ddm_refit_gcp.R`

---

## Required project structure on GCP

Ensure this structure exists in your GCP project root:

```
your_project_root/
├── data/
│   └── ddm_ready_data_unthresholded.csv   # required
├── R/
│   └── utils/
│       └── logging_validation.R           # required (part of repo)
├── scripts/
│   ├── ddm_refit_gcp.R
│   └── check_vm_capabilities.R
└── output/                                 # created automatically
```

---

## Quick reference: absolute paths

| Purpose | Absolute path |
|---------|----------------|
| DDM-ready data (in repo) | `modeling-pupil-DDM/data/ddm_ready_data_unthresholded.csv` |
| Raw behavioral (if used) | `modeling-pupil-DDM/data/bap_beh_trialdata_v3.csv` or external LC-BAP path |
| Logging utility | `modeling-pupil-DDM/R/utils/logging_validation.R` |

---

## Running on GCP

1. **Check VM capabilities** (optional, to tune settings):
   ```r
   source("scripts/check_vm_capabilities.R")
   ```

2. **Run the DDM refit**:
   - From RStudio: open `scripts/ddm_refit_gcp.R` and click *Source* or *Run All*
   - From terminal: `Rscript scripts/ddm_refit_gcp.R`

3. **Optional env vars** (set before running):
   ```bash
   export DDM_GCP_PROJECT_ROOT="/path/to/modeling-pupil-DDM"
   export DDM_N_CHAINS=4
   export DDM_THREADS_PER_CHAIN=2
   ```

4. **Outputs** are written to `output/ddm_refits/runs/<run_id>/`.
