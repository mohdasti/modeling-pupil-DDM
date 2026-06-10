# modeling-pupil-DDM

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![DOI](https://zenodo.org/badge/1065131176.svg)](https://doi.org/10.5281/zenodo.18205122)
[![R](https://img.shields.io/badge/R-4.0+-blue.svg)](https://www.r-project.org/)
[![Quarto](https://img.shields.io/badge/Quarto-1.7+-0F4C75?logo=quarto&logoColor=white)](https://quarto.org/)
[![Release](https://img.shields.io/github/v/release/mohdasti/modeling-pupil-DDM?include_prereleases&label=Pre-publication)](https://github.com/mohdasti/modeling-pupil-DDM/releases/tag/Pre-publication)

Hierarchical Bayesian drift-diffusion modeling (DDM) with concurrent pupillometry in older adults performing auditory/visual change-detection under low vs. high isometric handgrip (5% vs. 40% MVC). This repo holds the **Chapter 3 analysis pipeline**, manuscript source, and figure scripts for the BAP effort–arousal–decision project.

> **Pre-publication checkpoint:** GitHub release [`Pre-publication`](https://github.com/mohdasti/modeling-pupil-DDM/releases/tag/Pre-publication) on `master` (June 2026; archived on [Zenodo](https://doi.org/10.5281/zenodo.18205122)). Raw trial data and large `.rds` fits are **not** in git; see [Reproducing results](#reproducing-results).

---

## Study & current results (primary run)

| Item | Value |
|------|--------|
| **Primary run ID** | `20260226_092110` |
| **RT convention** | Probe-onset–locked; cue-locked RT ≥ 0.20 s exclusion |
| **Behavioral *N*** | 17,857 trials · 67 participants |
| **Primary model** | Additive difficulty + effort on *v* and *a*; effort + task on *z*; *t₀* intercept-only |
| **Pupil subset *N*** | 12,287 trials · 59 participants (same-*N* nested pupil models) |

**Registered hypotheses (primary additive model):**

| Hypothesis | Result (link scale) |
|------------|---------------------|
| **H1** effort → drift *v* | Supported — β ≈ −0.057, 95% CrI excludes 0 |
| **H2** effort → boundary *a* | Directionally positive but ROPE-negligible (100% mass within ±0.05 log-scale ROPE); not interpreted as strategic caution |
| **H4** effort → bias *z* | Near-zero null — CrI spans 0 |
| **H3** effort → *t₀* | Not testable in primary model (response-signal design) |
| **Pupil → *v* / *z*** | Near-zero coefficients; same-*N* LOO shows no predictive gain; measurement-limited under sustained grip |

Full prose, tables, and appendix diagnostics: [`reports/chap3_ddm_results.qmd`](reports/chap3_ddm_results.qmd) → render to HTML/PDF.

---

## Reproducing results

### Minimal path (manuscript only)

If you already have fitted models and tables on disk (from a colleague, GCP download, or prior local run):

```bash
git clone https://github.com/mohdasti/modeling-pupil-DDM.git
cd modeling-pupil-DDM

# Ensure run_dir tables exist (download from GCP or prior local run), then sync publish PPC/QA exports:
DDM_RUN_ID=20260226_092110 Rscript scripts/sync_publish_from_run.R
DDM_RUN_ID=20260226_092110 Rscript scripts/R/make_publish_gate.R
Rscript scripts/regenerate_task_sensitivity_table.R

# Regenerate five main figures (requires .rds paths in manuscript_paths.R)
Rscript 06_visualization/publication_figures/fig2_central_result.R   # or all fig1–fig5

# Render Chapter 3 report (reads DDM tables from params$run_dir in the QMD)
quarto render reports/chap3_ddm_results.qmd
```

Outputs: `reports/chap3_ddm_results.html` (and PDF/DOCX if configured).

### Full path (from trial-level data)

1. **Behavioral DDM refit** — primary run under `output/ddm_refits/runs/20260226_092110/` (see `scripts/ddm_refit_gcp.R` for GCP workflow). After each refit, sync publish artifacts and PPC gates:
   ```bash
   DDM_RUN_ID=20260226_092110 Rscript scripts/sync_publish_from_run.R
   DDM_RUN_ID=20260226_092110 Rscript scripts/R/make_publish_gate.R
   Rscript scripts/regenerate_task_sensitivity_table.R
   ```
   The QMD reads DDM tables from `params$run_dir` only; `output/publish/` holds PPC/QA/exploratory exports (see `output/publish/ddm_run_manifest.csv`).
2. **Pupil trial table** — `scripts/build_ddm_pupil_ready_data.R` → merged behavioral + pupil features.
3. **Pupil-DDM fits** — `scripts/fit_pupil_ddm_models.R` (nested m0–m3 on pupil subset).
4. **Postprocess** — `scripts/postprocess_pupil_ddm_models.R` → `output/ddm_pupil/tables/`.
5. **Pack for transfer** — `scripts/pack_pupil_ddm_for_download.sh` (VM → local).

GCP details: [`docs/GCP_PUPIL_FIT_GUIDE.md`](docs/GCP_PUPIL_FIT_GUIDE.md), [`docs/GCP_UPLOAD_GUIDE.md`](docs/GCP_UPLOAD_GUIDE.md).

### What is (and is not) versioned

| Tracked in git | Local / GCP only (`.gitignore`) |
|----------------|----------------------------------|
| QMD, R scripts, configs | `*.rds` model objects |
| `output/figures/manuscript_palette/` (supplementary PNG/PDF) | `output/ddm_refits/runs/*/models/` |
| | `output/ddm_refits/runs/*/tables/` (sync via `scripts/sync_publish_from_run.R`) |
| | `output/publish/` (PPC/QA exports; regenerate after each refit) |
| | Raw BAP behavioral/pupil files |

---

## Key paths

```
output/ddm_refits/runs/20260226_092110/
├── models/additive__probe_onset_locked__thr0.20.rds   # primary behavioral fit
├── models/pupil_interaction__probe_onset_locked__thr0.20.rds
└── tables/                                            # fixef, LOO, contrasts, PPC

output/ddm_pupil/tables/
├── pupil_loo_summary.csv
├── pupil_effects_key_terms.csv
├── model_info.csv
└── pupil_fixef_link_scale_pupil_only.csv

reports/chap3_ddm_results.qmd                          # Chapter 3 manuscript (Quarto)
06_visualization/publication_figures/                  # fig1–fig5 scripts
R/colors_manuscript.R                                  # shared palette
```

---

## Manuscript figures

Two tiers:

| Tier | Scripts | Output | In QMD |
|------|---------|--------|--------|
| **Main** (5 multi-panel) | `06_visualization/publication_figures/fig{1–5}_*.R` | `output/figures/manuscript/` | `main_fig()` |
| **Supplementary** | `scripts/R/fig_*.R`, `scripts/render_manuscript_figures.R` | `output/figures/manuscript_palette/` | `fig_path()` / appendix |

```bash
# Run each main figure script (paths in manuscript_paths.R)
Rscript 06_visualization/publication_figures/fig1_design_schematic.R
Rscript 06_visualization/publication_figures/fig2_central_result.R
Rscript 06_visualization/publication_figures/fig3_parameter_forest.R
Rscript 06_visualization/publication_figures/fig4_temporal_dynamics.R
Rscript 06_visualization/publication_figures/fig5_individual_differences.R

# Supplementary batch
Rscript scripts/render_manuscript_figures.R
```

| Figure | Content |
|--------|---------|
| Fig 1 | Trial timeline, DDM schematic, predictor map |
| Fig 2 | Drift/boundary by difficulty × effort; H1/H2 effort posteriors |
| Fig 3 | Effort + difficulty contrast forests |
| Fig 4 | Fatigue trajectories + choice-history coefficients |
| Fig 5 | Brinley plot, paired drift, caterpillar |

See [`06_visualization/publication_figures/README.md`](06_visualization/publication_figures/README.md).

---

## Pupil-linked DDM (nested trial-level models)

Four models on the **same** pupil-available trial set:

1. **m0** — behavioral baseline (no pupil)
2. **m1** — pupil → bias *z*
3. **m2** — pupil → drift *v* + bias *z*
4. **m3** — pupil × difficulty on *v*

```bash
Rscript scripts/fit_pupil_ddm_models.R          # fit (long; use GCP VM)
Rscript scripts/postprocess_pupil_ddm_models.R  # LOO, tables, figures
```

Interpretation framing: [`docs/OPUS_PUPIL_FRAMING_PACKET.md`](docs/OPUS_PUPIL_FRAMING_PACKET.md).

---

## Repository layout (abbreviated)

```
modeling-pupil-DDM/
├── reports/chap3_ddm_results.qmd      # Chapter 3 Quarto source
├── 06_visualization/publication_figures/  # Main fig scripts + manuscript_paths.R
├── R/colors_manuscript.R              # Manuscript color system
├── scripts/
│   ├── sync_publish_from_run.R        # copy run_dir tables → output/publish + manifest
│   ├── regenerate_task_sensitivity_table.R
│   ├── fit_pupil_ddm_models.R
│   ├── postprocess_pupil_ddm_models.R
│   ├── build_ddm_pupil_ready_data.R
│   ├── ddm_refit_gcp.R
│   ├── render_manuscript_figures.R
│   └── R/                             # Supplementary fig + extract scripts (incl. make_publish_gate.R)
├── output/
│   ├── ddm_refits/runs/20260226_092110/
│   ├── ddm_pupil/
│   ├── figures/manuscript_palette/    # tracked supplementary figures
│   └── publish/                       # audit & publish tables
├── docs/                              # GCP guides, integration notes, framing packet
├── 01_data_preprocessing/ … 07_manuscript/   # staged pipeline wrappers
└── data/                              # analysis-ready CSVs (large files gitignored)
```

Numbered folders (`01_`–`07_`) are thin wrappers around `scripts/`; canonical logic lives in `scripts/`.

---

## Installation

**Prerequisites:** R ≥ 4.0, [Quarto](https://quarto.org/), optional Python/MATLAB for upstream preprocessing.

```bash
git clone https://github.com/mohdasti/modeling-pupil-DDM.git
cd modeling-pupil-DDM

conda env create -f environment.yml   # or: pip install -r requirements.txt
Rscript scripts/setup/install_r_packages.R   # if present
```

**Core R packages:** `brms`, `tidyverse`, `tidybayes`, `ggplot2`, `patchwork`, `here`, `knitr`, `gt`, `kableExtra`, `quarto`.

Copy path templates before first local run:

```bash
cp config/paths_config.R.example config/paths_config.R   # edit for your machine
```

---

## Quality assurance

After a behavioral refit or before rendering the manuscript:

```bash
DDM_RUN_ID=20260226_092110 Rscript scripts/sync_publish_from_run.R
DDM_RUN_ID=20260226_092110 Rscript scripts/R/make_publish_gate.R
Rscript scripts/regenerate_task_sensitivity_table.R
quarto render reports/chap3_ddm_results.qmd
```

Check `output/publish/ddm_run_manifest.csv` — `run_id` must match `params$run_dir` in the QMD.

Legacy design/audit scripts (optional):

```bash
Rscript scripts/R/audit_design_coding.R   # → output/publish/audit/
```

---

## Documentation

| Doc | Purpose |
|-----|---------|
| [`docs/OPUS_PUPIL_FRAMING_PACKET.md`](docs/OPUS_PUPIL_FRAMING_PACKET.md) | Pupil Results §3.3 framing + key numbers |
| [`docs/GCP_PUPIL_FIT_GUIDE.md`](docs/GCP_PUPIL_FIT_GUIDE.md) | Fit pupil models on GCP VM |
| [`docs/GCP_UPLOAD_GUIDE.md`](docs/GCP_UPLOAD_GUIDE.md) | Upload/download run artifacts |
| [`docs/DDM_CHAPTER_INTEGRATION.md`](docs/DDM_CHAPTER_INTEGRATION.md) | QMD integration notes |
| [`docs/PIPELINE_README.md`](docs/PIPELINE_README.md) | Legacy pipeline overview |
| [`06_visualization/publication_figures/README.md`](06_visualization/publication_figures/README.md) | Main figure paths & run order |

---

## Makefile (optional shortcuts)

```bash
make help      # list targets
make report    # generate reports / tables
make all       # full pipeline (if configured)
```

---

## Citation & contact

**Software (Zenodo):** [10.5281/zenodo.18205122](https://doi.org/10.5281/zenodo.18205122)

```bibtex
@software{modeling_pupil_ddm,
  title  = {modeling-pupil-DDM: Hierarchical DDM and pupillometry in older adults under physical effort},
  author = {Dastgheib, Mohammad},
  year   = {2026},
  url    = {https://github.com/mohdasti/modeling-pupil-DDM},
  doi    = {10.5281/zenodo.18205122},
  note   = {Release Pre-publication (June 2026); concept DOI 10.5281/zenodo.18205122}
}
```

**Contact:** Mohammad Dastgheib · [mdast003@ucr.edu](mailto:mdast003@ucr.edu) · UC Riverside

**License:** [GPL-3.0](LICENSE)

---

## Version history

| Version | Date | Notes |
|---------|------|-------|
| **Pre-publication** | 2026-06 | `Pre-publication` tag: canonical run `20260226_092110`, Chapter 3 consistency fixes, publish sync workflow, H2 ROPE framing |
| Pre-publication (v1) | 2026-06 | Tag on `c46f8e9`: pupil-DDM Phase B complete, §3.3 prose, Opus audit fixes |
| v1.3.1 | 2026-06-05 | Consolidated main figures `fig1`–`fig5`; `manuscript_paths.R` |
| v1.3.0 | 2026-06-04 | Centralized `colors_manuscript.R`; `manuscript_palette/` versioning |
| v1.2.0 | 2024-12 | Early pupil–DDM integration scripts; Chapter 3 QMD expansion |
| v1.0.0 | 2024-01 | Initial public pipeline |

---

**Note:** This is research code for a dissertation chapter moving toward journal submission. Verify paths and model artifacts after clone; regenerate fits or obtain `output/ddm_refits/` and `output/ddm_pupil/` from the release maintainer if needed.
