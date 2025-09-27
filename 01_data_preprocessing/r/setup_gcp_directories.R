# =========================================================================
# BAP GCP DIRECTORY SETUP SCRIPT
# =========================================================================
# 
# This script creates the clean directory structure for GCP deployment
# Run this first to set up the organized folder structure
# =========================================================================

# Create main directory structure
cat("Creating BAP GCP directory structure...\n")

# Main directories
dirs <- c(
    "data/raw/behavioral",
    "data/raw/pupillometry", 
    "data/processed/flat_files",
    "data/processed/merged_files",
    "data/analysis_ready",
    "scripts/01_data_processing",
    "scripts/02_data_preparation", 
    "scripts/03_statistical_analysis",
    "scripts/04_model_capture",
    "scripts/05_pipeline",
    "output/logs",
    "output/figures/quality_control",
    "output/figures/timecourse_plots", 
    "output/figures/statistical_plots",
    "output/figures/exploratory_plots",
    "output/models",
    "output/results",
    "config"
)

# Create directories
for(dir in dirs) {
    if(!dir.exists(dir)) {
        dir.create(dir, recursive = TRUE)
        cat("Created:", dir, "\n")
    } else {
        cat("Exists:", dir, "\n")
    }
}

# Create README file
readme_content <- "# BAP Pupillometry Analysis Project

## Directory Structure

### Data
- `data/raw/`: Raw data files
  - `behavioral/`: Behavioral CSV files
  - `pupillometry/`: Raw .mat files
- `data/processed/`: Processed data files
  - `flat_files/`: Processed pupillometry CSV files
  - `merged_files/`: Merged behavioral + pupillometry files
- `data/analysis_ready/`: Final datasets for analysis

### Scripts
- `scripts/01_data_processing/`: Data merging and QC
- `scripts/02_data_preparation/`: Data preparation and visualization
- `scripts/03_statistical_analysis/`: Statistical modeling
- `scripts/04_model_capture/`: Model output capture
- `scripts/05_pipeline/`: Automated pipeline scripts

### Output
- `output/logs/`: Analysis logs and reports
- `output/figures/`: All generated plots
- `output/models/`: Saved model files
- `output/results/`: Final results and summaries

### Config
- `config/`: Configuration files

## Usage
1. Upload raw data to `data/raw/`
2. Run `scripts/05_pipeline/run_analysis.R`
3. Check results in `output/`

## File Organization
This structure ensures clean separation of:
- Raw data (never modified)
- Processed data (intermediate files)
- Analysis scripts (organized by purpose)
- Output files (organized by type)
"

writeLines(readme_content, "README.md")
cat("Created README.md\n")

cat("\n=== DIRECTORY STRUCTURE CREATED ===\n")
cat("Next steps:\n")
cat("1. Upload raw data files to data/raw/\n")
cat("2. Upload R scripts to scripts/\n")
cat("3. Run the analysis pipeline\n")
