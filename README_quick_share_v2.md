# Quick-Share v2 Generation

This directory contains scripts to generate a compact QC export for sharing.

## Quick Start

```bash
# Generate the CSVs
Rscript R/quick_share_v2_generate.R

# Generate the HTML report
quarto render reports/pupil_qc_slim.qmd
```

Or use the Makefile (if available):

```bash
make quick-share-v2
```

## Outputs

The script generates `quick_share_v2/` with:

1. **01_file_provenance.csv** - Input files processed, sizes, git hash
2. **02_design_expected_vs_observed.csv** - Design compliance
3. **03_trials_per_subject_task_ses.csv** - Trial counts per subject/task/session
4. **04_run_level_counts.csv** - Run-level statistics
5. **05_window_validity_summary.csv** - Window validity distributions
6. **06_gate_pass_rates_by_threshold.csv** - Gate pass rates
7. **07_bias_checks_key_gates.csv** - Bias check coefficients (or "behavior not merged")
8. **08_prestim_dip_summary.csv** - Prestim/baseline failure diagnostics
9. **README_quick_share_v2.md** - Detailed documentation

## Requirements

- R packages: `dplyr`, `readr`, `purrr`, `stringr`, `tidyr`, `yaml`, `data.table`, `broom`
- Quarto (for HTML report)
- Config file: `config/data_paths.yaml` (copy from `config/data_paths.yaml.example`)

## Notes

- All trial counts use `n_distinct(trial_index)` to avoid double-counting
- Trial identity: `(sub, task, ses_key, run_key, trial_index)`
- Windows are relative to squeeze onset at t=0
- Script processes files one at a time to avoid memory issues

