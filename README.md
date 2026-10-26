# modeling-pupil-DDM

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![DOI](https://zenodo.org/badge/1065131176.svg)](https://doi.org/10.5281/zenodo.18205122)
[![R](https://img.shields.io/badge/R-4.0+-blue.svg)](https://www.r-project.org/)
[![Quarto](https://img.shields.io/badge/Quarto-1.7+-0F4C75?logo=quarto&logoColor=white)](https://quarto.org/)
[![Release](https://img.shields.io/github/v/release/mohdasti/modeling-pupil-DDM?include_prereleases&label=Pre-publication)](https://github.com/mohdasti/modeling-pupil-DDM/releases/tag/Pre-publication)

Hierarchical Bayesian drift-diffusion modeling with concurrent pupillometry. Older adults judged whether two tones or two visual patterns were the same or different while holding a handgrip at low (5% MVC) or high (40% MVC) force. This repository holds the Chapter 3 analysis, the current chapter source, and the figure scripts for the BAP effort–decision project.

The chapter on `master` is [`reports/chap3_revised.qmd`](reports/chap3_revised.qmd): *Physical Effort Shifts the Decision Criterion, Not Evidence Quality, in Older Adults*. The June 2026 [`Pre-publication`](https://github.com/mohdasti/modeling-pupil-DDM/releases/tag/Pre-publication) release, archived on [Zenodo](https://doi.org/10.5281/zenodo.18205122), is an earlier checkpoint. Its report is [`reports/chap3_ddm_results.qmd`](reports/chap3_ddm_results.qmd) and its fits are run `20260226_092110`. Those numbers are superseded. The refit history is in [`docs/ch3_analysis_decision_record.md`](docs/ch3_analysis_decision_record.md).

Raw trial data and large `.rds` fits are not in git.

---

## Current chapter

| Item | Value |
|------|--------|
| **Source** | [`reports/chap3_revised.qmd`](reports/chap3_revised.qmd) |
| **Helpers** | [`R/ch3_report_helpers.R`](R/ch3_report_helpers.R) |
| **References** | [`reports/references.bib`](reports/references.bib) |
| **Tables and inline numbers** | `output/ddm_refits/runs/final_20261016/tables/final/` |
| **Figures** | `output/ddm_refits/runs/final_20261016/figures/final/` |
| **Behavioral sample** | 17,857 trials, 67 participants. Primary model M4. Unaffected by the pupil time-axis error. |
| **Pupil sample to cite** | r12 (`r12_20261025_204146`): 6,299 trials, 51 participants. |

High effort shifted evidence accumulation toward "same" responses. It did not reduce evidence quality overall, and it did not meaningfully change boundary separation or the starting point. Pupil responses during the decision were larger on trials with wider boundaries. No pupil measure taken before the decision predicted boundary separation. Cite the rendered chapter for the estimates. The decision record's earlier "cite r8" section is superseded by the 2026-10-25 note at the end of that file.

**Do not cite r8, r9, or r10 pupil results.** Those fits used a compressed time axis (`invalid_time_axis`). Behavioral models from the same period are unaffected. A dilation-speed filter and a re-fit of the affected pupil models are deferred to the journal version. The dissertation uses r12.

The manuscript is the default render. The dissertation adds the behavioral mixed-effects models, the extended supplement, and the analysis-provenance section. Pass `-M dissertation:true` for that pair.

Rendered copies in `reports/`:

| File | Version |
|------|---------|
| `chap3_revised.pdf`, `chap3_revised.docx` | Manuscript |
| `chap3_revised_dissertation.pdf`, `chap3_revised_dissertation.docx` | Dissertation |

---

## Rendering the chapter

From the repository root, with `inline_values.rds` and the chapter figures already in `tables/final/` and `figures/final/`:

```bash
quarto render reports/chap3_revised.qmd --to docx
quarto render reports/chap3_revised.qmd --to pdf

quarto render reports/chap3_revised.qmd --to docx \
  -M dissertation:true --output chap3_revised_dissertation.docx
quarto render reports/chap3_revised.qmd --to pdf \
  -M dissertation:true --output chap3_revised_dissertation.pdf
```

Render the manuscript PDF last. Quarto can remove `reports/chap3_revised.pdf` when a later format of the same input is rendered. The dissertation `--output` files are written at the repository root; move them into `reports/`.

The chapter reads every CSV in `params$tables_dir` and `inline_values.rds`. It does not refit models. The `pupil_run` field in the qmd YAML is not the cited pupil run. The cited pupil numbers are the r12 values stored in `inline_values.rds`.

Figure scripts for the current panels live in [`scripts/final/F_figures.R`](scripts/final/F_figures.R). That file still contains an older pupil time-course data path, so do not run the whole script to refresh the chapter figures.

---

## What is versioned

| Tracked in git | Local or VM only (`.gitignore`) |
|----------------|----------------------------------|
| `reports/chap3_revised.qmd`, helpers, `references.bib` | `*.rds` model objects |
| Manuscript and dissertation `.docx` | `*.pdf`, including the chapter PDFs |
| `T10b_convergence_display.csv` | Other tables under `output/` |
| Decision record | Raw BAP files and `data/analysis_ready/` |
| | Quarto caches and HTML libraries (`reports/*_cache/`, `reports/*_files/`) and `reports/*.tex` |
| | Upload archives in `archive/bundles/` |

---

## Repository layout

```
modeling-pupil-DDM/
├── README.md
├── START_HERE.md                      # older pipeline steps; not the chapter
├── QUICK_START_MATLAB.md              # older MATLAB setup
├── reports/chap3_revised.qmd          # current chapter
├── reports/references.bib
├── reports/chap3_ddm_results.qmd      # June 2026 checkpoint; do not cite
├── R/ch3_report_helpers.R             # chapter tables and formatters
├── scripts/final/                     # export, inline values, figure script
├── docs/ch3_analysis_decision_record.md
├── archive/
│   ├── notes/                         # January 2025 organization summaries and audit notes
│   └── bundles/                       # local GCP uploads; gitignored
├── output/ddm_refits/runs/final_20261016/
│   ├── tables/final/                  # what the chapter reads
│   └── figures/final/
├── 06_visualization/publication_figures/  # pre-publication fig1–fig5
└── data/                              # analysis-ready files; large inputs gitignored
```

Numbered folders (`01_`–`07_`) and the Makefile targets (`make report`, `make all`) are the older pipeline. They do not build the current chapter. [`START_HERE.md`](START_HERE.md) and [`QUICK_START_MATLAB.md`](QUICK_START_MATLAB.md) belong to that pipeline.

---

## Installation

**Prerequisites:** R ≥ 4.0 and [Quarto](https://quarto.org/). A TeX installation with XeLaTeX is required for the PDF. The manuscript font is STIX Two Text.

```bash
git clone https://github.com/mohdasti/modeling-pupil-DDM.git
cd modeling-pupil-DDM

conda env create -f environment.yml
Rscript scripts/setup/install_r_packages.R
cp config/paths_config.R.example config/paths_config.R
```

**Core R packages:** `brms`, `tidyverse`, `tidybayes`, `ggplot2`, `patchwork`, `here`, `knitr`, `gt`, `kableExtra`.

Fitting the models requires the trial tables and a machine with Stan. Those fits are not part of rendering the chapter. GCP notes for earlier runs: [`docs/GCP_PUPIL_FIT_GUIDE.md`](docs/GCP_PUPIL_FIT_GUIDE.md), [`docs/GCP_UPLOAD_GUIDE.md`](docs/GCP_UPLOAD_GUIDE.md).

---

## Documentation

| Doc | Purpose |
|-----|---------|
| [`docs/ch3_analysis_decision_record.md`](docs/ch3_analysis_decision_record.md) | Which run to cite, and why r8–r10 pupil results are invalid |
| [`docs/DDM_CHAPTER_INTEGRATION.md`](docs/DDM_CHAPTER_INTEGRATION.md) | Earlier QMD integration notes |
| [`docs/GCP_PUPIL_FIT_GUIDE.md`](docs/GCP_PUPIL_FIT_GUIDE.md) | Fitting on a GCP VM |
| [`docs/GCP_UPLOAD_GUIDE.md`](docs/GCP_UPLOAD_GUIDE.md) | Moving run artifacts on and off the VM |
| [`06_visualization/publication_figures/README.md`](06_visualization/publication_figures/README.md) | Pre-publication figure scripts |
| [`START_HERE.md`](START_HERE.md) | Older step-by-step pipeline, before the current chapter |
| [`archive/README.md`](archive/README.md) | Where superseded notes and local uploads were moved |

---

## Citation & contact

**Software (Zenodo):** [10.5281/zenodo.18205122](https://doi.org/10.5281/zenodo.18205122) (concept) · [10.5281/zenodo.20621752](https://doi.org/10.5281/zenodo.20621752) (the June 2026 `Pre-publication` snapshot, not the chapter now on `master`)

```bibtex
@software{modeling_pupil_ddm,
  title  = {modeling-pupil-DDM: Hierarchical DDM and pupillometry in older adults under physical effort},
  author = {Dastgheib, Mohammad},
  year   = {2026},
  url    = {https://github.com/mohdasti/modeling-pupil-DDM},
  doi    = {10.5281/zenodo.20621752},
  note   = {Release Pre-publication (June 2026); concept DOI 10.5281/zenodo.18205122}
}
```

**Contact:** Mohammad Dastgheib · [mdast003@ucr.edu](mailto:mdast003@ucr.edu) · UC Riverside

**License:** [GPL-3.0](LICENSE)

---

## Version history

| Version | Date | Notes |
|---------|------|-------|
| **Chapter on master** | 2026-10 | `reports/chap3_revised.qmd` is the chapter. Behavioral results from `final_20261016` (M4; 17,857 trials, 67 participants). Pupil results from r12 (6,299 trials, 51 participants). r8–r10 pupil results are invalid. Quarto caches are not tracked. |
| Pre-publication | 2026-06 | Tag `Pre-publication`: run `20260226_092110` and `reports/chap3_ddm_results.qmd`. Superseded for citation. |
| v1.3.1 | 2026-06-05 | Consolidated main figures `fig1`–`fig5`; `manuscript_paths.R` |
| v1.3.0 | 2026-06-04 | Centralized `colors_manuscript.R`; `manuscript_palette/` versioning |
| v1.2.0 | 2024-12 | Early pupil–DDM integration scripts |
| v1.0.0 | 2024-01 | Initial public pipeline |

---

This is research code for a dissertation chapter. After cloning, confirm that `output/ddm_refits/runs/final_20261016/tables/final/inline_values.rds` and the figures in `figures/final/` are present before rendering.
