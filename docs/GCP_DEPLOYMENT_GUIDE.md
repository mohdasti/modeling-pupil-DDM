# =========================================================================
# BAP GCP DEPLOYMENT GUIDE
# =========================================================================
# 
# Complete guide for deploying BAP pupillometry analysis to Google Cloud Platform
# =========================================================================

## 🚀 **STEP 1: SETUP DIRECTORY STRUCTURE**

First, run the directory setup script in your GCP environment:

```r
# In your GCP R session
source("setup_gcp_directories.R")
```

This will create the clean directory structure:
```
BAP_DDM/
├── BAP_DDM.Rproj
├── README.md
├── data/
│   ├── raw/
│   │   ├── behavioral/
│   │   └── pupillometry/
│   ├── processed/
│   │   ├── flat_files/
│   │   └── merged_files/
│   └── analysis_ready/
├── scripts/
│   ├── 01_data_processing/
│   ├── 02_data_preparation/
│   ├── 03_statistical_analysis/
│   ├── 04_model_capture/
│   └── 05_pipeline/
├── output/
│   ├── logs/
│   ├── figures/
│   ├── models/
│   └── results/
└── config/
```

## 📁 **STEP 2: UPLOAD FILES**

### Upload Raw Data:
1. **Behavioral data**: Upload `bap_trial_data_grip_type1.csv` to `data/raw/behavioral/`
   - This file now includes integrated pupillometry data
   - Contains all behavioral and pupillometry variables in one file
2. **Pupillometry data**: Upload all `.mat` files to `data/raw/pupillometry/` (optional, for reference)

### Upload Processed Data:
1. **Flat files**: This directory is no longer needed since pupillometry is integrated
   - The new behavioral data file contains all necessary information
2. **Merged files**: This directory will be **created automatically** by the pipeline
   - You don't upload anything here initially
   - The pipeline will create merged files here when it runs

### Upload Scripts:
1. **Configuration**: Upload `config/paths_config.R`
2. **Data processing**: Upload scripts to `scripts/01_data_processing/`
   - `create_merged_flat_file.R` - Updated for new integrated data structure
   - `qc_of_merged_files.R` - Updated for new data structure with integrated pupillometry
3. **Data preparation**: Upload scripts to `scripts/02_data_preparation/`
   - `pupil_plots.R` - Creates visualizations and prepares data for analysis
4. **Statistical analysis**: Upload scripts to `scripts/03_statistical_analysis/`
   - `phase_b.R` - Fits DDM and mixed effects models
   - `exploratory_rt_analysis.R` - Distributional modeling and correlations
5. **Model capture**: Upload scripts to `scripts/04_model_capture/`
   - `enhanced_model_capture.R` - Captures and interprets model outputs
6. **Pipeline**: Upload scripts to `scripts/05_pipeline/`
   - `complete_pipeline_automated.R` - Main pipeline orchestration
   - `run_analysis.R` - Simple execution script

**Note**: All scripts have been updated to work with the new integrated data structure where pupillometry data is included in the behavioral CSV file.

## 🔧 **STEP 3: INSTALL REQUIRED PACKAGES**

In your GCP R session, install the required packages:

```r
# Install required packages
install.packages(c(
    "dplyr", "readr", "ggplot2", "tidyr", "purrr", "stringr",
    "gridExtra", "viridis", "grid", "cowplot", "brms", "bayesplot",
    "lme4", "lmerTest", "corrplot", "gghalves", "survival", "survminer"
))
```

## 🎯 **STEP 4: RUN THE ANALYSIS**

Simply run the main execution script:

```r
# Run the complete pipeline
source("scripts/05_pipeline/run_analysis.R")
```

## 📊 **STEP 5: CHECK RESULTS**

After the analysis completes, check the results in:

- **Logs**: `output/logs/BAP_Analysis_Log_YYYY-MM-DD_HH-MM-SS.md`
- **Figures**: `output/figures/` (organized by type)
- **Models**: `output/models/` (saved .rds files)
- **Results**: `output/results/` (summary files)

## 🔍 **STEP 6: VERIFY OUTPUT**

The pipeline will create:

1. **Comprehensive Log File**: Self-contained research report
2. **Quality Control Reports**: Data validation results
3. **Statistical Models**: DDM and mixed effects models
4. **Visualizations**: Timecourse plots, statistical plots
5. **Summary Files**: CSV summaries for easy access

## 📋 **FILE ORGANIZATION**

### Data Flow:
```
Raw Data → Processed Data → Merged Data → Analysis Ready → Results
```

### Script Organization:
```
01_data_processing/ → 02_data_preparation/ → 03_statistical_analysis/ → Output
```

### Output Organization:
```
logs/ → Comprehensive research logs
figures/ → Organized by analysis type
models/ → Saved statistical models
results/ → Summary files and reports
```

## 🛠️ **TROUBLESHOOTING**

### Common Issues:

1. **Missing files**: Ensure all raw data files are uploaded to correct directories
2. **Package errors**: Install all required packages before running
3. **Path errors**: Check that `config/paths_config.R` is properly sourced
4. **Memory issues**: GCP provides more memory than local machines

### Error Recovery:

- Check the log file for detailed error messages
- Each step is isolated, so you can restart from any point
- All intermediate files are saved for debugging

## 📈 **BENEFITS OF GCP DEPLOYMENT**

1. **Scalability**: Handle larger datasets with more memory
2. **Reproducibility**: Clean, organized structure
3. **Collaboration**: Easy to share and collaborate
4. **Performance**: Faster processing with cloud resources
5. **Backup**: Automatic cloud backup of results

## 🎉 **SUCCESS INDICATORS**

The analysis is successful when you see:

- ✅ "PIPELINE COMPLETED SUCCESSFULLY" message
- ✅ Comprehensive log file generated
- ✅ All output directories populated
- ✅ No error messages in the log
- ✅ Model files saved (.rds files)
- ✅ Figures generated (.png/.pdf files)

## 📞 **SUPPORT**

If you encounter issues:

1. Check the log file for detailed error messages
2. Verify all files are in correct directories
3. Ensure all packages are installed
4. Check that paths are correctly configured

The pipeline is designed to be robust and provide detailed feedback for troubleshooting.
