# Modeling Pupil-DDM: Computational Modeling of Pupillometry and Decision-Making

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![R](https://img.shields.io/badge/R-4.0+-blue.svg)](https://www.r-project.org/)
[![Python](https://img.shields.io/badge/Python-3.8+-green.svg)](https://www.python.org/)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2020a+-orange.svg)](https://www.mathworks.com/products/matlab.html)

A comprehensive computational modeling pipeline integrating pupillometry, behavioral data, and drift diffusion models (DDM) to understand the relationship between brain arousal and decision-making processes.

## 🧠 Overview

This repository showcases advanced computational modeling techniques for analyzing the relationship between pupillometry (a proxy for brain arousal) and decision-making processes using drift diffusion models. The pipeline demonstrates expertise in:

- **Multi-language Programming**: R, Python, and MATLAB integration
- **Hierarchical Bayesian Modeling**: Advanced statistical modeling with brms and Stan
- **Computational Neuroscience**: Drift diffusion models and decision-making theory
- **Data Science**: Comprehensive data preprocessing, quality control, and visualization
- **Reproducible Research**: Automated pipelines with comprehensive logging and documentation

## 🚀 Key Features

### Computational Modeling
- **Hierarchical Drift Diffusion Models**: Subject-level and trial-level parameter estimation
- **Bayesian Inference**: Stan-based modeling with brms for robust parameter estimation
- **Model Comparison**: AIC/BIC-based model selection and multiverse analysis
- **Robustness Checks**: VIF analysis, outlier detection, and sensitivity analysis

### Data Analysis Pipeline
- **Pupillometry Processing**: Event-related pupil response extraction and feature engineering
- **Behavioral Modeling**: Mixed-effects models for reaction time and accuracy
- **Statistical Analysis**: Mediation analysis, individual differences, and correlation analysis
- **Quality Control**: Comprehensive data validation and preprocessing

### Advanced Programming
- **Automated Workflows**: End-to-end analysis pipelines with error handling
- **Multi-language Integration**: Seamless R-Python-MATLAB workflow
- **Cloud Deployment**: Google Cloud Platform integration for scalable computing
- **Reproducibility**: Version control, comprehensive logging, and documentation

## ℹ️ About

This repository mirrors a working 7-step pipeline (01–07) from the BAP_DDM project into a clean, public-friendly structure. It provides:
- A standardized seven-stage directory layout
- Wrapper scripts inside stage folders that call core logic under `scripts/`
- Selected, non-sensitive outputs (figures, tables, summaries) for demonstration

Raw data are not included. Use the wrapper scripts (under `02_` and `03_`) or call the core runners in `scripts/` directly.

## 📁 Repository Structure

```
modeling-pupil-DDM/
├── README.md                           # This file
├── requirements.txt                    # Python dependencies
├── environment.yml                     # Conda environment
├── .gitignore                          # Git ignore rules
├── LICENSE                             # GPL-3.0 License
│
├── 01_data_preprocessing/              # Data cleaning and preparation
│   ├── matlab/                         # MATLAB preprocessing scripts
│   ├── python/                         # Python data analysis scripts
│   └── r/                              # R data processing scripts
│
├── 02_pupillometry_analysis/           # Pupillometry-specific analysis
│   ├── feature_extraction/             # Pupil feature extraction
│   ├── quality_control/                # Data quality assessment
│   └── visualization/                  # Pupillometry plots
│
├── 03_behavioral_analysis/             # Behavioral data analysis
│   ├── reaction_time/                  # RT analysis and modeling
│   ├── accuracy/                       # Accuracy analysis
│   └── mixed_effects/                  # Mixed-effects models
│
├── 04_computational_modeling/          # DDM and computational models
│   ├── drift_diffusion/                # DDM implementation
│   ├── hierarchical_bayesian/          # Bayesian modeling
│   └── model_comparison/               # Model selection and comparison
│
├── 05_statistical_analysis/            # Advanced statistical analysis
│   ├── mediation/                      # Mediation analysis
│   ├── individual_differences/         # Between-person analysis
│   └── robustness/                     # Sensitivity and robustness checks
│
├── 06_visualization/                   # Data visualization
│   ├── publication_figures/            # Manuscript-ready figures
│   ├── interactive_plots/              # Interactive visualizations
│   └── summary_plots/                  # Analysis summary plots
│
├── 07_manuscript/                      # Manuscript preparation
│   ├── main_text/                      # Main manuscript content
│   ├── supplementary/                  # Supplementary materials
│   └── tables/                         # Analysis tables
│
├── config/                             # Configuration files
│   ├── paths_config.R                  # File path configurations
│   ├── pipeline_config.R               # Pipeline settings
│   └── model_config.yaml               # Model parameters
│
├── scripts/                            # Mirrored core analysis scripts
│   ├── core/                           # Main model/analysis runners
│   ├── 01_data_processing/             # Data processing & QC
│   ├── 02_statistical_analysis/        # Statistical modeling
│   ├── advanced/                       # Advanced analyses
│   └── utilities/                      # Helpers (integration, extraction)
│
├── tests/                              # Unit tests
│   ├── test_data_processing.py         # Data processing tests
│   ├── test_models.R                   # Model fitting tests
│   └── test_visualization.py           # Visualization tests
│
└── docs/                               # Documentation
    ├── pipeline_README.md              # Pipeline documentation
    ├── model_documentation.md          # DDM implementation details
    └── api_reference.md                # Function documentation
```

## 🛠️ Installation

### Prerequisites

- **R** (≥ 4.0.0) with required packages
- **Python** (≥ 3.8) with scientific computing libraries
- **MATLAB** (≥ R2020a) for preprocessing
- **Git** for version control

### Quick Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/modeling-pupil-DDM.git
   cd modeling-pupil-DDM
   ```

2. **Set up Python environment**:
   ```bash
   # Using conda (recommended)
   conda env create -f environment.yml
   conda activate modeling-pupil-ddm

   # Or using pip
   pip install -r requirements.txt
   ```

3. **Install R packages**:
   ```r
   # Run the R setup script
   Rscript scripts/setup/install_r_packages.R
   ```

## 🚀 Quick Start

### Run Complete Pipeline

```bash
# Basic pipeline
Rscript 04_computational_modeling/run_pipeline.R

# Advanced pipeline with logging
Rscript 04_computational_modeling/run_pipeline.R --advanced --logging

# Skip computationally intensive models
Rscript 04_computational_modeling/run_pipeline.R --skip-heavy
```

### Run Individual Analyses

```bash
# Data preprocessing
python 01_data_preprocessing/python/analyze_behavioral_data.py

# Pupillometry analysis
Rscript 02_pupillometry_analysis/feature_extraction/run_feature_extraction.R

# Behavioral analysis
Rscript 03_behavioral_analysis/reaction_time/run_rt_analysis.R

# DDM modeling
Rscript scripts/core/run_analysis.R

# Statistical analysis
Rscript scripts/02_statistical_analysis/02_ddm_analysis.R

# Generate figures
Rscript scripts/create_condition_effects_forest_plot.R
```

## 🔬 Key Methodological Contributions

### Drift Diffusion Modeling
- **Hierarchical Bayesian DDM**: Subject-level and trial-level parameter estimation using Stan
- **Pupillometry Integration**: Linking arousal measures to decision parameters
- **Robustness Checks**: Comprehensive sensitivity analysis and model validation

### Statistical Approaches
- **Mixed-Effects Models**: Accounting for individual differences with lme4 and brms
- **Mediation Analysis**: Understanding causal pathways between arousal and behavior
- **Multiverse Analysis**: Testing analysis robustness across different approaches

### Data Processing
- **Automated Pipeline**: End-to-end analysis automation with comprehensive logging
- **Quality Control**: Comprehensive data validation and preprocessing
- **Reproducibility**: Version control, documentation, and cloud deployment

## 📊 Analysis Pipeline

### 1. Data Preprocessing
- **MATLAB**: Raw pupillometry data preprocessing and cleaning
- **Python**: Behavioral data analysis and quality control
- **R**: Data merging and preparation for analysis

### 2. Pupillometry Analysis
- Event-related pupil response extraction
- Tonic and phasic arousal feature computation
- Data quality assessment and validation

### 3. Behavioral Analysis
- Reaction time distribution analysis
- Accuracy modeling with mixed-effects models
- Individual differences assessment

### 4. Computational Modeling
- Hierarchical drift diffusion models
- Bayesian parameter estimation
- Model comparison and selection

### 5. Statistical Analysis
- Mediation analysis
- Between-person differences
- Robustness and sensitivity checks

### 6. Visualization
- Publication-ready figures
- Interactive plots
- Analysis summaries

## 🧭 Seven-Step Pipeline (Directory → Primary Entry)

1. 01_data_preprocessing → `python 01_data_preprocessing/python/analyze_behavioral_data.py`
2. 02_pupillometry_analysis → `Rscript 02_pupillometry_analysis/feature_extraction/run_feature_extraction.R`
3. 03_behavioral_analysis → `Rscript 03_behavioral_analysis/reaction_time/run_rt_analysis.R`
4. 04_computational_modeling → `Rscript scripts/core/run_analysis.R`
5. 05_statistical_analysis → `Rscript scripts/02_statistical_analysis/02_ddm_analysis.R`
6. 06_visualization → `Rscript scripts/create_condition_effects_forest_plot.R`
7. 07_manuscript → curated outputs in `07_manuscript/`

## 🧪 Testing

Run the test suite to ensure everything works correctly:

```bash
# Python tests
python -m pytest tests/test_data_processing.py -v

# R tests
Rscript tests/test_models.R

# Integration tests
bash scripts/utilities/run_integration_tests.sh
```

## 📚 Documentation

- **[Pipeline Documentation](docs/pipeline_README.md)**: Detailed pipeline description
- **[Model Documentation](docs/model_documentation.md)**: DDM implementation details
- **[API Reference](docs/api_reference.md)**: Function documentation
- **[Tutorials](docs/tutorials/)**: Step-by-step guides

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup
```bash
# Fork and clone the repository
git clone https://github.com/yourusername/modeling-pupil-DDM.git
cd modeling-pupil-DDM

# Create a development branch
git checkout -b feature/your-feature-name

# Make your changes and test
python -m pytest tests/
Rscript tests/test_models.R

# Submit a pull request
git push origin feature/your-feature-name
```

## 📄 License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0) – see the [LICENSE](LICENSE) file for details. By contributing, you agree that your contributions will be licensed under GPL-3.0.

## 🙏 Acknowledgments

- **Research Team**: Collaborators and research assistants
- **Open Source**: R, Python, and MATLAB communities
- **Funding**: Research grants and institutional support

## 📞 Contact

- **Lead Researcher**: [Mohammad Dastgheib](mailto:mdast003@ucr.edu)
- **Institution**: UC Riverside
- **Project Page**: [Project Website]

## 📊 Citation

If you use this code in your research, please cite:

```bibtex
@software{modeling_pupil_ddm,
  title={Modeling Pupil-DDM: Computational Modeling of Pupillometry and Decision-Making},
  author={[Your Name]},
  year={2024},
  url={https://github.com/yourusername/modeling-pupil-DDM},
  note={Computational modeling pipeline for pupillometry and behavioral analysis}
}
```

## 🔄 Version History

- **v1.0.0** (2024-01-01): Initial release with complete pipeline
- **v0.9.0** (2023-12-01): Beta release with core functionality
- **v0.8.0** (2023-11-01): Alpha release with basic features

---

**Note**: This repository contains research code demonstrating advanced computational modeling techniques. While we strive for accuracy and reproducibility, please verify results and adapt code for your specific use case.
