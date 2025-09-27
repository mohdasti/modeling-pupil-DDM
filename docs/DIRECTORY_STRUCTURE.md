# BAP DDM Pipeline - Directory Structure

## 📁 **ORGANIZED DIRECTORY STRUCTURE**

The BAP DDM pipeline has been reorganized into a clean, logical structure for better maintainability and usability.

```
BAP_DDM/
├── run_pipeline.R                    # Main entry point for all pipelines
├── config/                          # Configuration files
│   ├── paths_config.R               # Path configurations
│   └── pipeline_config.R            # Pipeline settings
├── data/                            # Data files
│   ├── analysis_ready/              # Processed analysis-ready data
│   │   ├── BAP_analysis_ready_BEHAVIORAL_full.csv
│   │   ├── BAP_analysis_ready_PUPIL_full.csv
│   │   ├── BAP_trialwise_pupil_features.csv
│   │   └── BAP_trialwise_pupil_features_alternative_windows.csv
│   └── LC Aging Subject Data master spreadsheet - *.csv  # Individual differences data
├── scripts/                         # All analysis scripts
│   ├── core/                        # Core pipeline scripts
│   │   ├── run_bap_analysis.R       # Simple pipeline
│   │   ├── run_bap_analysis_with_logging.R  # Pipeline with detailed logging
│   │   ├── run_complete_bap_pipeline.R      # Advanced pipeline
│   │   ├── run_analysis.R           # Core model fitting
│   │   └── run_extended_analysis.R  # Extended analyses
│   ├── advanced/                    # Advanced analysis scripts
│   │   ├── between_person_analysis_individual_differences.R
│   │   ├── fit_hierarchical_ddm_pupillometry.R
│   │   ├── fit_hierarchical_ddm_sequential_dependencies.R
│   │   ├── fit_hierarchical_lba_pupillometry.R
│   │   └── mediation_analysis_effort_pupillometry.R
│   ├── utilities/                   # Utility and helper scripts
│   │   ├── analyze_pipeline_logs.R  # Log analysis tool
│   │   ├── create_pupillometry_features.R
│   │   ├── create_publication_figures_and_manuscript.R
│   │   ├── data_integration.R
│   │   ├── extract_model_results.R
│   │   ├── logging_system.R         # Comprehensive logging framework
│   │   ├── pipeline_status.R        # Status checker
│   │   └── analyze_phasic_timing_sensitivity.R
│   ├── legacy/                      # Legacy and deprecated scripts
│   │   ├── comprehensive_model_extraction.R
│   │   ├── comprehensive_visualizations.R
│   │   ├── create_additional_publication_plots.R
│   │   ├── create_publication_plots.R
│   │   ├── create_truly_comprehensive_report.R
│   │   ├── create_ultimate_summary.R
│   │   └── robust_model_extraction.R
│   ├── 01_data_processing/          # Data processing scripts
│   │   └── 01_process_and_qc.R
│   └── 02_statistical_analysis/     # Statistical analysis scripts
│       └── 02_ddm_analysis.R
├── output/                          # All pipeline outputs
│   ├── models/                      # Fitted model objects (.rds files)
│   ├── results/                     # Analysis results and reports
│   ├── figures/                     # Generated plots and visualizations
│   │   ├── comprehensive_analysis/  # Comprehensive analysis plots
│   │   ├── publication_manuscript/  # Publication-ready figures
│   │   ├── between_person_analysis/ # Individual differences plots
│   │   ├── mediation_analysis/      # Mediation analysis plots
│   │   ├── hddm_pupillometry/       # HDDM pupillometry plots
│   │   ├── lba_analysis/            # LBA analysis plots
│   │   ├── sequential_dependencies/ # Sequential dependencies plots
│   │   └── timing_sensitivity/      # Timing sensitivity plots
│   └── logs/                        # Execution logs and summaries
└── docs/                            # Documentation
    ├── DIRECTORY_STRUCTURE.md       # This file
    ├── PIPELINE_README.md           # Main pipeline documentation
    ├── LOGGING_SYSTEM_DOCUMENTATION.md  # Logging system guide
    ├── PIPELINE_ORGANIZATION_SUMMARY.md # Organization summary
    └── COMPREHENSIVE_LOGGING_SUMMARY.md # Logging summary
```

---

## 🎯 **DIRECTORY PURPOSES**

### **Root Level**
- **`run_pipeline.R`**: Main entry point for all pipeline executions
- **`config/`**: Configuration files for paths and settings
- **`data/`**: All data files (raw and processed)
- **`scripts/`**: All analysis scripts organized by function
- **`output/`**: All pipeline outputs organized by type
- **`docs/`**: All documentation and guides

### **Scripts Organization**

#### **`scripts/core/`** - Core Pipeline Scripts
- **Main pipeline runners** with different levels of complexity
- **Core model fitting** scripts
- **Essential analysis** workflows

#### **`scripts/advanced/`** - Advanced Analysis Scripts
- **Hierarchical models** (DDM, LBA)
- **Individual differences** analysis
- **Mediation analysis**
- **Sequential dependencies**

#### **`scripts/utilities/`** - Utility and Helper Scripts
- **Logging system** and analysis tools
- **Feature extraction** utilities
- **Visualization** and reporting tools
- **Status checking** and monitoring

#### **`scripts/legacy/`** - Legacy and Deprecated Scripts
- **Old analysis** scripts (kept for reference)
- **Superseded** functionality
- **Historical** versions

### **Output Organization**

#### **`output/models/`** - Model Objects
- **Fitted models** (.rds files)
- **Convergence diagnostics**
- **Parameter estimates**

#### **`output/results/`** - Analysis Results
- **Statistical results** (.csv files)
- **Reports** (.md files)
- **Summary statistics**

#### **`output/figures/`** - Visualizations
- **Publication-ready** plots
- **Diagnostic** plots
- **Analysis-specific** visualizations

#### **`output/logs/`** - Execution Logs
- **Detailed execution** logs
- **Performance metrics**
- **Error reports**

---

## 🚀 **USAGE PATTERNS**

### **Quick Access**
```bash
# Main entry point (recommended)
Rscript run_pipeline.R

# With options
Rscript run_pipeline.R --logging --skip-heavy
```

### **Direct Script Access**
```bash
# Core pipeline
Rscript scripts/core/run_bap_analysis.R

# Advanced pipeline with logging
Rscript scripts/core/run_bap_analysis_with_logging.R

# Individual analyses
Rscript scripts/advanced/fit_hierarchical_ddm_pupillometry.R
Rscript scripts/utilities/create_pupillometry_features.R
```

### **Status and Monitoring**
```bash
# Check pipeline status
Rscript scripts/utilities/pipeline_status.R

# Analyze logs
Rscript scripts/utilities/analyze_pipeline_logs.R
```

---

## 🔧 **MAINTENANCE**

### **Adding New Scripts**
- **Core functionality**: Add to `scripts/core/`
- **Advanced analyses**: Add to `scripts/advanced/`
- **Utilities**: Add to `scripts/utilities/`
- **Update pipeline configs** to include new scripts

### **Organizing Outputs**
- **Models**: Save to `output/models/`
- **Results**: Save to `output/results/`
- **Figures**: Save to `output/figures/` (create subdirectories as needed)
- **Logs**: Save to `output/logs/`

### **Documentation**
- **User guides**: Add to `docs/`
- **Update this file** when structure changes
- **Keep README files** current

---

## ✅ **BENEFITS OF THIS STRUCTURE**

### **1. Clarity**
- **Clear separation** of concerns
- **Logical grouping** of related files
- **Easy navigation** for new users

### **2. Maintainability**
- **Modular organization** makes updates easier
- **Legacy code** is clearly separated
- **Configuration** is centralized

### **3. Scalability**
- **Easy to add** new analyses
- **Clear patterns** for organization
- **Flexible structure** for growth

### **4. Usability**
- **Single entry point** (`run_pipeline.R`)
- **Multiple access methods** for different needs
- **Clear documentation** for each component

---

## 📋 **MIGRATION NOTES**

### **What Changed**
- **Scripts moved** from flat structure to organized subdirectories
- **Documentation consolidated** into `docs/`
- **New main entry point** created (`run_pipeline.R`)
- **Path references updated** in pipeline scripts

### **What Stayed the Same**
- **Data structure** unchanged
- **Output structure** unchanged
- **Core functionality** unchanged
- **All existing analyses** still work

### **Backward Compatibility**
- **Old scripts** preserved in `scripts/legacy/`
- **All outputs** remain in same locations
- **Configuration files** unchanged
- **Data files** unchanged

---

**This organized structure makes the BAP DDM pipeline more professional, maintainable, and user-friendly while preserving all existing functionality!** 🎉
