# DDM Chapter Integration into 7-Step Pipeline

## Overview

The comprehensive DDM chapter report (`reports/chap3_ddm_results.qmd`) and supporting extraction utilities have been successfully integrated into the 7-step pipeline. This document explains how the new components fit into the existing workflow.

**Recent Updates (v1.2.0)**: The chapter now includes a complete "Pupil-DDM Integration" section with posterior correlation analyses, robustness checks, and publication-ready figures. See `scripts/02_statistical_analysis/06_pupil_ddm_integration.R` and `07_pupil_ddm_finalize.R` for the analysis pipeline.

## Integration Summary

### Step 7: Manuscript Generation (Updated)

**Entry Point**: `Rscript 07_manuscript/render_ddm_chapter.R`

**What it does**:
1. Runs all extraction scripts (`R/run_extract_all.R`) to generate tables and summaries
2. Renders the comprehensive Quarto report (`reports/chap3_ddm_results.qmd`) to HTML and DOCX

**Outputs**:
- `reports/chap3_ddm_results.html` - Interactive HTML report
- `reports/chap3_ddm_results.docx` - Word document for manuscript
- `output/publish/*.csv` - All extracted tables (QA, manipulation checks, LOO, PPC, contrasts, etc.)

## New Components

### 1. Extraction Scripts (`R/extract_*.R`)

These scripts extract and format analysis results into publication-ready tables:

- **`R/extract_design_qa.R`**: Design and data quality assurance
  - Trial exclusions by reason
  - Subject inclusion statistics
  - Decision coding audit
  - MVC compliance checks

- **`R/extract_manip_checks.R`**: Manipulation checks independent of DDM
  - Accuracy GLMM (difficulty × task)
  - RT LMM (median RT by difficulty × task)

- **`R/extract_ppc_gates.R`**: Posterior predictive check summaries
  - PPC gate summary (% flagged cells)
  - Per-cell detail tables

- **`R/extract_loo_summary.R`**: Model comparison summary
  - LOO-CV results (ELPD, ΔELPD, stacking/PBMA weights)
  - Pareto-k diagnostics

- **`R/extract_params_and_contrasts.R`**: Parameter estimates and contrasts
  - Fixed effects summary (mean, 95% CrI, Rhat, ESS)
  - Posterior contrasts with directional probabilities and ROPE

- **`R/extract_ppc_heatmap_tables.R`**: PPC residual tables
  - Wide and long format tables for heatmap visualization

### 2. Master Runner (`R/run_extract_all.R`)

Executes all extraction scripts in sequence and verifies outputs. Run this before rendering the report to ensure all tables are up-to-date.

### 3. Comprehensive Report (`reports/chap3_ddm_results.qmd`)

The final Quarto report integrates:

- **Design & Data QA**: Trial exclusions, subject inclusion, decision coding, MVC compliance
- **Manipulation Checks**: GLMM and LMM results independent of DDM
- **Model Specification**: Formulas, priors, sampling controls
- **Model Comparison**: LOO-CV results with figures
- **Fixed Effects & Contrasts**: Forest plots, summary tables, directional probabilities
- **Posterior Predictive Checks**: Subject-wise, unconditional, conditional PPCs with figures
- **Interpretation**: APA-ready prose summarizing key findings
- **Ethics & Data Availability**: IRB, sample size justification, repository links
- **Limitations**: Comprehensive discussion of model limitations and future directions

### 4. Helper Utilities (`R/_helpers_extract.R`)

Common functions used by all extraction scripts:
- Path management
- Safe CSV reading
- Clean writing utilities
- Decision column standardization

## Pipeline Flow

```
Step 1-6: [Existing pipeline steps]
    ↓
Step 7: Manuscript Generation
    ├── Run extraction scripts (R/run_extract_all.R)
    │   ├── extract_design_qa.R → output/publish/qa_*.csv
    │   ├── extract_manip_checks.R → output/publish/checks_*.csv
    │   ├── extract_ppc_gates.R → output/publish/ppc_*.csv
    │   ├── extract_loo_summary.R → output/publish/loo_*.csv
    │   ├── extract_params_and_contrasts.R → output/publish/table_*.csv
    │   └── extract_ppc_heatmap_tables.R → output/publish/ppc_heatmap_*.csv
    │
    └── Render Quarto report (reports/chap3_ddm_results.qmd)
        ├── Reads all output/publish/*.csv files
        ├── Includes figures from output/figures/*.pdf
        └── Generates HTML and DOCX outputs
```

## Usage

### Generate Complete Report

```bash
# Run step 7 (extracts all tables and renders report)
Rscript 07_manuscript/render_ddm_chapter.R

# Or run extraction and rendering separately:
Rscript R/run_extract_all.R
Rscript R/render_chap3_report.R
```

### Individual Extraction

```bash
# Run specific extraction scripts as needed
Rscript R/extract_design_qa.R
Rscript R/extract_manip_checks.R
# ... etc
```

## File Organization

```
modeling-pupil-DDM/
├── R/                                    # Extraction utilities
│   ├── _helpers_extract.R               # Common helpers
│   ├── extract_*.R                       # Individual extraction scripts
│   ├── run_extract_all.R                 # Master runner
│   ├── table_*.R                         # Table-specific scripts
│   └── render_chap3_report.R            # Report renderer
│
├── reports/                              # Final reports
│   └── chap3_ddm_results.qmd             # Comprehensive DDM chapter
│
├── output/
│   ├── figures/                         # All PDF figures
│   └── publish/                         # Published tables (CSV, MD)
│       ├── qa_*.csv                      # QA tables
│       ├── checks_*.csv                 # Manipulation checks
│       ├── loo_*.csv                    # LOO comparison
│       ├── table_*.csv                  # Fixed effects & contrasts
│       └── ppc_*.csv                    # PPC summaries
│
└── 07_manuscript/
    └── render_ddm_chapter.R             # Step 7 entry point
```

## Integration with Existing Pipeline

The new components **do not break** the existing 7-step pipeline:

1. **Steps 1-6**: Unchanged - existing scripts continue to work
2. **Step 7**: Enhanced - now includes comprehensive report generation
3. **Backward compatibility**: All existing scripts and outputs remain functional

## Benefits

1. **Reproducibility**: All tables and figures are auto-generated from analysis outputs
2. **Consistency**: Single source of truth for all manuscript tables
3. **Efficiency**: One command generates the complete report
4. **Transparency**: Full audit trail from data to manuscript
5. **Dissertation-ready**: The QMD file serves as the final chapter for your dissertation

## Future Enhancements

When you add pupil data:
1. The QMD template can be extended with pupil-specific sections
2. New extraction scripts can be added following the same pattern
3. The report structure accommodates additional analyses seamlessly

## Notes

- The QMD report is designed to be the **final product** for your dissertation
- All extraction scripts follow a consistent pattern for easy extension
- The report auto-reads CSV files, so updates propagate automatically
- Figures are referenced via robust path resolution that works from any directory


