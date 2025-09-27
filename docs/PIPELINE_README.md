# Modeling Pupil-DDM Pipeline Documentation

This document provides detailed information about the Modeling Pupil-DDM analysis pipeline, including methodology, implementation details, and usage instructions.

## 🧠 Overview

The Modeling Pupil-DDM pipeline integrates pupillometry data with behavioral measures to understand the relationship between brain arousal and decision-making processes using drift diffusion models (DDM). The pipeline demonstrates advanced computational modeling techniques and multi-language programming skills.

## 📊 Pipeline Architecture

### 1. Data Preprocessing (`01_data_preprocessing/`)

#### MATLAB Scripts (`matlab/`)
- **`BAP_Pupillometry_Pipeline.m`**: Main pupillometry preprocessing pipeline
- **`BAP_eyetrackFlat_ADT.m`**: Eye-tracking data flattening for auditory tasks
- **`BAP_eyetrackFlat_ADT_corrected.m`**: Corrected version with improved error handling
- **`timing_sanity_check.m`**: Timing validation and sanity checks

#### Python Scripts (`python/`)
- **`analyze_behavioral_data.py`**: Behavioral data analysis and quality control
- **`create_flat_files_interactive.py`**: Interactive data flattening tool
- **`examine_mat_files.py`**: MATLAB file examination and validation
- **`downsample_and_process.py`**: Data downsampling and processing
- **`check_data_structure.py`**: Data structure validation

#### R Scripts (`r/`)
- **`BAP_Complete_Pipeline_Automated.R`**: Automated end-to-end pipeline
- **`Create merged flat file.R`**: Data merging and integration
- **`QC_of_merged_files.R`**: Quality control and validation
- **`Pupil_plots.R`**: Pupillometry visualization
- **`Phase_B.R`**: Statistical modeling phase
- **`Exploratory RT analysis.R`**: Exploratory reaction time analysis

### 2. Pupillometry Analysis (`02_pupillometry_analysis/`)

#### Feature Extraction
- **Tonic Arousal**: Baseline pupil diameter measures
- **Phasic Arousal**: Event-related pupil responses
- **Peak Detection**: Automatic peak detection and quantification
- **Area Under Curve**: Integrated response measures

#### Quality Control
- **Data Validation**: Comprehensive data quality assessment
- **Outlier Detection**: Statistical outlier identification
- **Missing Data Handling**: Imputation and exclusion strategies
- **Artifact Detection**: Blink and saccade detection

#### Visualization
- **Event-Related Plots**: Time-locked pupil responses
- **Individual Differences**: Subject-level variability plots
- **Quality Metrics**: Data quality visualization
- **Summary Statistics**: Descriptive statistics plots

### 3. Behavioral Analysis (`03_behavioral_analysis/`)

#### Reaction Time Analysis
- **Distribution Analysis**: RT distribution modeling
- **Outlier Detection**: Statistical outlier identification
- **Condition Effects**: Task condition comparisons
- **Individual Differences**: Subject-level variability

#### Accuracy Analysis
- **Performance Metrics**: Accuracy and error rate analysis
- **Condition Effects**: Task condition comparisons
- **Individual Differences**: Subject-level variability
- **Error Analysis**: Error type and pattern analysis

#### Mixed-Effects Models
- **Linear Mixed Models**: RT and accuracy modeling
- **Random Effects**: Subject-level random effects
- **Fixed Effects**: Task condition and arousal effects
- **Model Comparison**: AIC/BIC-based model selection

### 4. Computational Modeling (`04_computational_modeling/`)

#### Drift Diffusion Models
- **Hierarchical DDM**: Subject-level and trial-level parameters
- **Bayesian Inference**: Stan-based parameter estimation
- **Parameter Recovery**: Model validation and recovery
- **Convergence Diagnostics**: MCMC convergence assessment

#### Model Comparison
- **AIC/BIC Comparison**: Information criterion-based selection
- **Cross-Validation**: Model validation techniques
- **Parameter Estimation**: Robust parameter estimation
- **Uncertainty Quantification**: Parameter uncertainty assessment

#### Integration with Pupillometry
- **Arousal-DDM Link**: Connecting arousal measures to DDM parameters
- **Individual Differences**: Subject-level parameter variability
- **Trial-Level Effects**: Trial-by-trial parameter estimation
- **Robustness Checks**: Sensitivity analysis and validation

### 5. Statistical Analysis (`05_statistical_analysis/`)

#### Mediation Analysis
- **Causal Pathways**: Understanding arousal-behavior relationships
- **Bootstrap Methods**: Non-parametric inference
- **Effect Decomposition**: Direct and indirect effects
- **Sensitivity Analysis**: Robustness to assumptions

#### Individual Differences
- **Between-Person Analysis**: Subject-level differences
- **Correlation Analysis**: Trait-level relationships
- **Factor Analysis**: Dimensionality reduction
- **Clustering**: Subject grouping and classification

#### Robustness Checks
- **Sensitivity Analysis**: Parameter sensitivity assessment
- **Outlier Handling**: Robust statistical methods
- **Model Validation**: Cross-validation and bootstrapping
- **Assumption Testing**: Statistical assumption validation

### 6. Visualization (`06_visualization/`)

#### Publication Figures
- **Manuscript-Ready Plots**: High-quality publication figures
- **Multi-Panel Figures**: Complex multi-panel visualizations
- **Statistical Plots**: Effect plots and confidence intervals
- **Model Diagnostics**: Model validation plots

#### Interactive Plots
- **Web-Based Visualizations**: Interactive web plots
- **Exploratory Analysis**: Interactive data exploration
- **Model Exploration**: Interactive model parameter exploration
- **Data Quality**: Interactive quality assessment

#### Summary Plots
- **Analysis Summaries**: Comprehensive analysis summaries
- **Pipeline Overview**: End-to-end pipeline visualization
- **Quality Metrics**: Data and model quality visualization
- **Results Overview**: Key findings visualization

## 🔧 Technical Implementation

### Programming Languages

#### R
- **Primary Language**: Statistical analysis and modeling
- **Key Packages**: brms, lme4, ggplot2, dplyr, tidyr
- **Bayesian Modeling**: Stan integration via brms
- **Data Visualization**: ggplot2 and extensions

#### Python
- **Data Processing**: Scientific computing and data manipulation
- **Key Libraries**: pandas, numpy, scipy, matplotlib, seaborn
- **Machine Learning**: scikit-learn, tensorflow, torch
- **Cloud Integration**: Google Cloud Platform integration

#### MATLAB
- **Signal Processing**: Pupillometry data preprocessing
- **Key Toolboxes**: Signal Processing, Statistics, Machine Learning
- **Data Export**: Integration with R and Python workflows
- **Quality Control**: Automated quality assessment

### Software Architecture

#### Modular Design
- **Independent Modules**: Each analysis step is modular
- **Configurable Parameters**: Easy parameter modification
- **Error Handling**: Robust error handling and recovery
- **Logging**: Comprehensive logging and monitoring

#### Data Flow
- **Raw Data**: MATLAB preprocessing
- **Processed Data**: Python quality control
- **Analysis Ready**: R statistical analysis
- **Results**: Multi-format output generation

#### Quality Assurance
- **Automated Testing**: Unit and integration tests
- **Validation**: Data and model validation
- **Documentation**: Comprehensive code documentation
- **Reproducibility**: Version control and environment management

## 📈 Key Methodological Contributions

### Drift Diffusion Modeling
- **Hierarchical Structure**: Subject-level and trial-level parameters
- **Bayesian Inference**: Robust parameter estimation with uncertainty
- **Pupillometry Integration**: Linking arousal measures to decision parameters
- **Model Validation**: Comprehensive model validation and recovery

### Statistical Approaches
- **Mixed-Effects Models**: Accounting for individual differences
- **Mediation Analysis**: Understanding causal pathways
- **Robustness Checks**: Sensitivity analysis and validation
- **Multiverse Analysis**: Testing analysis robustness

### Data Processing
- **Automated Pipeline**: End-to-end analysis automation
- **Quality Control**: Comprehensive data validation
- **Multi-language Integration**: Seamless R-Python-MATLAB workflow
- **Cloud Deployment**: Scalable cloud computing integration

## 🚀 Usage Instructions

### Quick Start

1. **Set up environment**:
   ```bash
   conda env create -f environment.yml
   conda activate modeling-pupil-ddm
   ```

2. **Install R packages**:
   ```r
   Rscript scripts/setup/install_r_packages.R
   ```

3. **Run complete pipeline**:
   ```bash
   Rscript 04_computational_modeling/run_pipeline.R
   ```

### Individual Analysis Steps

1. **Data preprocessing**:
   ```bash
   # MATLAB preprocessing
   matlab -r "run('01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m')"
   
   # Python quality control
   python 01_data_preprocessing/python/analyze_behavioral_data.py
   
   # R data integration
   Rscript 01_data_preprocessing/r/Create\ merged\ flat\ file.R
   ```

2. **Pupillometry analysis**:
   ```r
   Rscript 02_pupillometry_analysis/feature_extraction/extract_pupil_features.R
   ```

3. **Behavioral analysis**:
   ```r
   Rscript 03_behavioral_analysis/reaction_time/rt_analysis.R
   ```

4. **Computational modeling**:
   ```r
   Rscript 04_computational_modeling/drift_diffusion/fit_hierarchical_ddm.R
   ```

5. **Statistical analysis**:
   ```r
   Rscript 05_statistical_analysis/mediation/mediation_analysis.R
   ```

6. **Visualization**:
   ```r
   Rscript 06_visualization/publication_figures/create_manuscript_figures.R
   ```

### Configuration

1. **Copy configuration files**:
   ```bash
   cp config/paths_config.R.example config/paths_config.R
   cp config/model_config.yaml.example config/model_config.yaml
   ```

2. **Modify paths and parameters**:
   - Update file paths in `config/paths_config.R`
   - Adjust model parameters in `config/model_config.yaml`

### Advanced Usage

1. **Custom analysis**:
   - Modify individual scripts for specific analyses
   - Add new analysis modules
   - Customize visualization parameters

2. **Cloud deployment**:
   - Use Google Cloud Platform integration
   - Scale analysis for large datasets
   - Implement distributed computing

3. **Reproducibility**:
   - Use version control for all changes
   - Document analysis parameters
   - Save intermediate results

## 🔍 Troubleshooting

### Common Issues

1. **Package installation problems**:
   - Check R and Python versions
   - Update package repositories
   - Use conda for package management

2. **Data loading errors**:
   - Verify file paths and formats
   - Check data file integrity
   - Validate data structure

3. **Model convergence issues**:
   - Adjust MCMC parameters
   - Check data quality
   - Validate model specification

4. **Memory issues**:
   - Use chunked processing
   - Implement data streaming
   - Optimize memory usage

### Getting Help

1. **Check documentation**: Review this guide and function documentation
2. **Run tests**: Use the test suite to identify issues
3. **Check logs**: Review analysis logs for error messages
4. **GitHub issues**: Report bugs and request features

## 📚 References

### Key Papers
- Drift Diffusion Models: Ratcliff & McKoon (2008)
- Pupillometry: Beatty & Lucero-Wagoner (2000)
- Bayesian Modeling: Gelman et al. (2013)
- Mixed-Effects Models: Bates et al. (2015)

### Software Documentation
- **R**: [R Documentation](https://www.r-project.org/)
- **Python**: [Python Documentation](https://docs.python.org/)
- **MATLAB**: [MATLAB Documentation](https://www.mathworks.com/help/)
- **Stan**: [Stan Documentation](https://mc-stan.org/)

### Tutorials and Guides
- **Bayesian Modeling**: [Statistical Rethinking](https://xcelab.net/rm/statistical-rethinking/)
- **Mixed-Effects Models**: [Mixed-Effects Models in R](https://bbolker.github.io/mixedmodels-misc/)
- **Data Visualization**: [ggplot2 Book](https://ggplot2-book.org/)

## 🎯 Future Development

### Planned Features
- **Real-time Analysis**: Live data processing capabilities
- **Advanced Models**: Additional computational models
- **Cloud Integration**: Enhanced cloud deployment
- **Interactive Tools**: Web-based analysis tools

### Contribution Opportunities
- **Bug Fixes**: Identify and fix issues
- **New Features**: Add new analysis methods
- **Documentation**: Improve documentation
- **Testing**: Add test coverage

---

**Note**: This documentation is continuously updated. Please check for the latest version and report any issues or suggestions for improvement.