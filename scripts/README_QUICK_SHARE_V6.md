# Quick-Share v6 Pipeline

## Overview

Complete, reproducible pipeline for generating AUC features, waveform summaries, and QC outputs for dissertation Chapters 2 and 3.

## Quick Start

```bash
Rscript scripts/make_quick_share_v6.R
```

## Prerequisites

1. **Input files:**
   - `quick_share_v5/analysis/ch2_analysis_ready.csv`
   - `quick_share_v5/analysis/ch3_ddm_ready.csv`
   - `quick_share_v4/merged/BAP_triallevel_merged_v2.csv`
   - Flat CSV files in `BAP_processed/` (or path in `config/data_paths.yaml`)

2. **R packages:**
   - `dplyr`, `readr`, `purrr`, `stringr`, `tidyr`, `yaml`, `here`, `data.table`, `ggplot2`

## Outputs

All outputs are written to `quick_share_v6/`:

- **merged/**: `BAP_triallevel_merged_v3.csv` (full trial-level merge with AUC)
- **analysis/**: Ch2/Ch3 analysis-ready CSVs with AUC features
- **waveforms/**: Condition-mean waveform CSVs (50Hz for Ch2, 250Hz for Ch3)
- **qc/**: QC tables (missingness, timing coverage, gate pass rates)
- **figs/**: PNG plots (gate rates, AUC distributions, waveforms)

## Pipeline Steps

1. **Load inputs** (Ch2/Ch3 base datasets, merged v2)
2. **Compute AUC features** from sample-level flat files
3. **Merge AUC** into trial-level merged dataset (v3)
4. **Join AUC** to Ch2/Ch3 analysis-ready datasets
5. **Generate waveform summaries** (condition means)
6. **Generate QC outputs** (missingness, timing, gates)
7. **Generate plots** (PNG format)
8. **Print final summary** (coverage, counts, recommendations)

## Runtime

Expected: **10-20 minutes** (depends on number of flat files)

## Key Features

- **No giant merged files**: Processes flat files one at a time
- **PTB timing support**: Uses PTB event timestamps when available, defaults otherwise
- **Compact outputs**: All CSVs < 20MB, HTML report < 15MB
- **Reproducible**: Single script, deterministic outputs

## AUC Definitions

- **Total AUC**: Baseline-corrected (B0) from trial onset (0) to response-window start
- **Cognitive AUC**: Target-locked baseline-corrected (B1) from (target_onset + 0.3s) to response-window start
- **Exclusion**: Requires ≥10 valid samples in each baseline window

## Event Timing

- **Preferred**: PTB-derived timestamps (`trial_start_time_ptb`, `target_onset_time_ptb`, `resp1_start_time_ptb`)
- **Fallback**: Fixed offsets (target_onset = 4.35s, resp_start = 4.70s)

See `quick_share_v6/qc/timing_event_time_coverage.csv` for coverage details.

## Troubleshooting

**Error: "Missing merged v2 file"**
- Run `scripts/make_merged_quickshare_v4.R` first

**Error: "No flat CSV files found"**
- Check `config/data_paths.yaml` or set `PUPIL_PROCESSED_DIR` environment variable

**Low AUC availability**
- Check `quick_share_v6/qc/auc_missingness_reasons.csv` for reasons
- Ensure baseline windows have ≥10 valid samples

**Large file sizes**
- Waveform CSVs should be compact (condition means only)
- If files > 20MB, check for duplicate rows or unnecessary columns

## Next Steps

1. Review QC outputs in `quick_share_v6/qc/`
2. Load analysis-ready datasets for modeling
3. Use waveform CSVs for plotting
4. Render HTML report: `quarto render reports/slim_qc_report_v6.qmd`

