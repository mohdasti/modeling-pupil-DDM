# Project Structure Overview

**Last Updated**: January 3, 2025  
**Purpose**: Chapter 3 Dissertation Repository (DDM with Pupil Predictors)

## Directory Organization

### Root Level
```
modeling-pupil-DDM/
├── README.md                    # Main project documentation
├── ORGANIZATION_SUMMARY.md      # Organization details
├── CLEANUP_SUMMARY.md          # Cleanup documentation
├── PROJECT_STRUCTURE.md        # This file
├── CONTRIBUTING.md              # Contribution guidelines
├── START_HERE.md               # Quick start guide
├── QUICK_START_MATLAB.md       # MATLAB setup guide
├── LICENSE                      # GPL-3.0 License
├── Makefile                     # Build automation
├── requirements.txt            # Python dependencies
├── environment.yml             # Conda environment
└── modeling-pupil-DDM.Rproj    # RStudio project file
```

### Core Pipeline (7-Step Structure)
```
├── 01_data_preprocessing/      # Step 1: Data cleaning
├── 02_pupillometry_analysis/   # Step 2: Pupil feature extraction
├── 03_behavioral_analysis/     # Step 3: Behavioral modeling
├── 04_computational_modeling/  # Step 4: DDM model fitting
├── 05_statistical_analysis/   # Step 5: Statistical tests
├── 06_visualization/           # Step 6: Figure generation
└── 07_manuscript/              # Step 7: Report generation
```

### Data Organization
```
data/
├── pupil_processed/            # ✅ Current processed data (primary)
│   ├── analysis_ready/        # Chapter-specific datasets
│   ├── merged/                 # Full merged datasets
│   ├── qc/                     # Quality control summaries
│   └── README.md               # Data documentation
├── analysis_ready/             # Additional analysis-ready data
├── derived/                    # Derived datasets
├── intermediate/               # Intermediate processing files
├── qc/                         # Historical QC outputs (reference)
└── raw/                        # Raw data (not in repo)
```

### Scripts Organization
```
scripts/
├── make_quick_share_v7.R       # Data processing pipeline
├── 01_data_processing/         # Data processing scripts
├── 02_statistical_analysis/    # Statistical analysis
│   ├── 06_pupil_ddm_integration.R
│   └── 07_pupil_ddm_finalize.R
├── core/                       # Core pipeline scripts
├── advanced/                   # Advanced analyses
├── utilities/                  # Helper functions
└── [other subdirectories]     # Additional script categories
```

### Output Organization
```
output/
├── model_comp/                 # Model comparison results
├── models/                     # Fitted model objects
├── figures/                    # Generated figures
├── tables/                     # Analysis tables
├── results/                    # Statistical results
├── ppc/                        # Posterior predictive checks
├── publish/                    # Publication-ready outputs
└── archive/                    # Archived outputs
```

### Reports
```
reports/
├── pupil_data_report_advisor.qmd    # ✅ Primary data quality report
├── chap3_ddm_results.qmd            # ✅ Chapter 3 DDM results
└── [rendered HTML/PDF outputs]
```

### Chapter 2 Materials (Portable Package)
```
chapter2_materials/
├── data/                       # Chapter 2 analysis-ready data
├── docs/                       # Chapter 2 documentation
├── scripts/                    # Chapter 2 scripts
├── reports/                    # Chapter 2 reports
└── README.md                   # Usage guide
```

### Archive
```
archive/
├── old_reports/                # Old report versions
├── old_scripts/                # Old script versions
└── old_quick_share/            # Old quick_share versions (v2-v6)
```

### Documentation
```
docs/
├── development_notes/          # Development documentation
├── [pipeline guides]           # Various documentation files
└── [other docs]                # Additional documentation
```

## Key Principles

1. **Clear Separation**: Chapter 2 materials separate from Chapter 3
2. **Current Data**: `data/pupil_processed/` is the primary data source
3. **Archive Policy**: Old versions moved to archive, not deleted
4. **Clean Root**: Minimal files in root directory
5. **Consolidated Outputs**: No duplicate directories
6. **Documentation**: README files in key directories

## Data Flow

```
Raw Data → Preprocessing → Pupil Processing → Analysis-Ready Data
                                                      ↓
                                            Chapter 2 / Chapter 3
                                                      ↓
                                            DDM Modeling → Results
```

## Current Status

✅ **Clean Structure** - All files properly organized  
✅ **No Duplicates** - Consolidated duplicate directories  
✅ **Clear Separation** - Chapter 2 and Chapter 3 materials separated  
✅ **Proper Archives** - Old versions archived appropriately  
✅ **Documentation** - README files in place  

## Maintenance

- **Regular Cleanup**: Review and archive old outputs periodically
- **Documentation Updates**: Keep README files current
- **Archive Policy**: Move to archive rather than delete
- **Structure Consistency**: Maintain 7-step pipeline structure

