# Main manuscript figures

Five consolidated main figures plus supplementary content.

## Setup (complete)

| Item | Location |
|------|----------|
| Shared colors | `R/colors_manuscript.R` |
| Model/data paths | `06_visualization/publication_figures/manuscript_paths.R` |
| Coefficient audit | `06_visualization/publication_figures/coef_name_audit.txt` |
| Figure outputs | `output/figures/manuscript/` |
| Figure scripts | `06_visualization/publication_figures/fig*.R` |

## Run order

```r
source(here("06_visualization", "publication_figures", "fig1_design_schematic.R"))
source(here("06_visualization", "publication_figures", "fig2_central_result.R"))
source(here("06_visualization", "publication_figures", "fig3_parameter_forest.R"))
source(here("06_visualization", "publication_figures", "fig4_temporal_dynamics.R"))
source(here("06_visualization", "publication_figures", "fig5_individual_differences.R"))
```

## Path placeholders (resolved)

| Placeholder | Resolved path |
|-------------|---------------|
| `PATH_TO_PRIMARY_MODEL.rds` | `output/ddm_refits/runs/20260226_092110/models/additive__probe_onset_locked__thr0.20.rds` |
| `PATH_TO_FATIGUE_MODEL.rds` | `output/publish/fit_exploratory_fatigue_trajectory.rds` |
| `PATH_TO_HISTORY_MODEL.rds` | `output/publish/fit_exploratory_choice_history_hist.rds` |
| `PATH_TO_WSLS_MODEL.rds` | `output/publish/fit_exploratory_choice_history_wsls.rds` |
| `PATH_TO_BEHAVIORAL_DATA.csv` | `data/ddm_ready_data_unthresholded.csv` |

## Packages

All required except **ggtext** — install before running figure scripts:

```r
install.packages("ggtext")
```

## Constraints

- Do not edit `scripts/core/`, `reports/`, or numbered pipeline dirs (01–05, 07).
- Do not re-run brms fits — only read existing `.rds` files.
- Do not hardcode posterior estimates — extract from draws.
- Do not change hex values in `colors_manuscript.R`.
