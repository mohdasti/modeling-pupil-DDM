# Generating the Comprehensive Pupil Data Report

## Overview

This directory contains a Quarto (`.qmd`) file that generates a comprehensive HTML report documenting all pupil data in the BAP study. The report includes:

- Data inventory (files per subject)
- Subject-level statistics (trials, runs, data availability)
- Quality control summaries
- Feature extraction summaries (AUC metrics)
- Methods and thresholds documentation
- Visualizations (including pupil waveform plots)

## Prerequisites

1. **Quarto**: Make sure Quarto is installed. Check with:
   ```bash
   quarto --version
   ```

2. **R Packages**: The following R packages are required:
   - `dplyr`, `tidyr`, `readr`, `purrr`
   - `ggplot2`
   - `knitr`, `kableExtra`
   - `DT`, `patchwork`

   Install missing packages with:
   ```r
   install.packages(c("dplyr", "tidyr", "readr", "purrr", "ggplot2", 
                      "knitr", "kableExtra", "DT", "patchwork"))
   ```

3. **Data Files**: 
   - Analysis-ready data should exist in `data/analysis_ready/`
   - If not, run the full pipeline first:
     ```r
     source("02_pupillometry_analysis/run_full_pupillometry_pipeline.R")
     ```

## Generating the Report

### Method 1: From R/RStudio

1. Open R or RStudio
2. Navigate to the project root directory
3. Run:
   ```r
   quarto::quarto_render("02_pupillometry_analysis/generate_pupil_data_report.qmd")
   ```

### Method 2: From Command Line

1. Navigate to the project root directory
2. Run:
   ```bash
   quarto render 02_pupillometry_analysis/generate_pupil_data_report.qmd
   ```

### Method 3: From RStudio

1. Open the `.qmd` file in RStudio
2. Click the "Render" button (or press `Ctrl+Shift+K` / `Cmd+Shift+K`)

## Output

The report will be generated as:
- **HTML file**: `02_pupillometry_analysis/generate_pupil_data_report.html`

Open this file in a web browser to view the report.

## Report Contents

The generated report includes:

1. **Data Inventory**
   - List of all flat files (raw and merged)
   - File sizes and modification dates
   - Subject-level file summaries

2. **Sample-Level Data Statistics**
   - Summary of sample-level data structure
   - Data availability by file

3. **Analysis-Ready Data Statistics**
   - Subject-level statistics (trials, runs, conditions)
   - Overall trial statistics
   - Trial distributions by task, effort, and difficulty

4. **Quality Control Summary**
   - Quality metrics distributions
   - Quality thresholds (80% valid data)
   - Quality plots

5. **Feature Extraction Summary**
   - Total AUC and Cognitive AUC statistics
   - AUC by condition
   - Missing data patterns

6. **Methods and Thresholds**
   - Baseline correction method
   - AUC calculation method (Zenon et al. 2014)
   - Quality thresholds
   - Difficulty and effort mapping
   - Trial structure and timing

7. **Visualizations**
   - Quality distribution plots
   - Pupil waveform plots (if available)

8. **Data Flow Summary**
   - Pipeline stages
   - Filtering steps
   - Output file locations

## Customization

To customize the report:

1. **Edit the QMD file**: `02_pupillometry_analysis/generate_pupil_data_report.qmd`
   - Modify sections, add/remove content
   - Adjust figure sizes, table formats
   - Change themes or styling

2. **Add sections**: Add new R code chunks to include additional analyses or visualizations

3. **Modify paths**: Update the configuration section at the top if your data paths differ

## Troubleshooting

### Error: "Analysis-ready files not found"

**Solution**: Run the full pipeline first:
```r
source("02_pupillometry_analysis/run_full_pupillometry_pipeline.R")
```

### Error: "Package not found"

**Solution**: Install missing packages:
```r
install.packages("package_name")
```

### Error: "Waveform plots not found"

**Solution**: Generate waveform plots:
```r
source("02_pupillometry_analysis/visualization/plot_pupil_waveforms.R")
```

Or the report will attempt to generate them automatically if data is available.

### Error: "Quarto not found"

**Solution**: Install Quarto from https://quarto.org/

## Related Files

- **Prompt Document**: `02_pupillometry_analysis/PUPIL_DATA_REPORT_PROMPT.md`
  - Comprehensive documentation of all files, methods, and thresholds
  - Use this as reference when customizing the report

- **Pipeline Scripts**: See `02_pupillometry_analysis/README.md` for pipeline documentation

## Notes

- The report is generated dynamically from the current data
- Re-run the report after adding new data or updating the pipeline
- The report includes both summary statistics and detailed tables
- All visualizations are embedded in the HTML output



