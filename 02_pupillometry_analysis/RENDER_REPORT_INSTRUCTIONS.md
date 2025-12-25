# How to Render the Pupil Data Report

## Quick Copy-Paste Code for RStudio Console

Copy and paste this code directly into your RStudio console:

```r
# Set working directory to project root
setwd("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")

# Render the report
quarto::quarto_render("02_pupillometry_analysis/generate_pupil_data_report.qmd")
```

## Alternative: Using the Script File

You can also source the provided script:

```r
source("02_pupillometry_analysis/render_report.R")
```

## What This Will Do

1. **Execute all code chunks** in the Quarto document
2. **Generate CSV files** in `data/qc/`:
   - `gate_trial_counts_validation.csv`
   - `gate_overlap_matrix.csv`
   - `gate_subject_diagnostics.csv`
   - `recommended_thresholds_by_gate.csv`
   - `event_invalidity_stratified_by_gate.csv` (if event data available)
   - And other QC files

3. **Generate plot files** in `figures/`:
   - `gate_jaccard_heatmap.png`
   - `gate_pass_rate_correlation.png`
   - `threshold_retention_curves.png`
   - `threshold_subject_dropout.png`
   - `threshold_sensitivity_*.png`
   - And other figures

4. **Create HTML report**: `02_pupillometry_analysis/generate_pupil_data_report.html`

## Prerequisites

- **Quarto** must be installed: https://quarto.org/docs/get-started/
- **R packages** required by the report (will be installed automatically if missing)
- **Data files** must be available at paths specified in the YAML header

## Troubleshooting

If you get an error about Quarto not found:
```r
# Check if quarto is installed
quarto::quarto_path()

# If empty, install Quarto from: https://quarto.org/docs/get-started/
```

If you need to override parameters:
```r
quarto::quarto_render(
  "02_pupillometry_analysis/generate_pupil_data_report.qmd",
  execute_params = list(
    processed_dir = "/path/to/your/processed/data",
    behavioral_file = "/path/to/your/behavioral.csv"
  )
)
```

## Expected Runtime

- **First run**: 5-15 minutes (depending on data size)
- **Subsequent runs**: 3-10 minutes (cached data speeds things up)

## Output Location

- **HTML Report**: `02_pupillometry_analysis/generate_pupil_data_report.html`
- **CSV Files**: `data/qc/*.csv`
- **Figures**: `figures/*.png`



