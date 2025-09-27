# =========================================================================
# BAP DDM PIPELINE CONFIGURATION
# =========================================================================
# Centralized configuration for the BAP DDM analysis pipeline
# =========================================================================

# Pipeline execution options
PIPELINE_OPTIONS <- list(
    # Execution control
    force_rerun = FALSE,           # Force rerun all analyses
    skip_heavy_models = FALSE,     # Skip computationally intensive models
    parallel_execution = TRUE,     # Use parallel processing where possible
    save_intermediate = TRUE,      # Save intermediate results
    
    # Timeouts (in seconds)
    default_timeout = 3600,        # 1 hour default timeout
    heavy_model_timeout = 7200,    # 2 hours for heavy models
    quick_analysis_timeout = 1800, # 30 minutes for quick analyses
    
    # File age thresholds (in hours)
    recent_file_threshold = 24,    # Consider files recent if < 24 hours old
    model_cache_threshold = 168    # Cache models for 1 week
)

# Data paths
DATA_PATHS <- list(
    # Input data
    behavioral_data = "data/analysis_ready/BAP_analysis_ready_BEHAVIORAL_full.csv",
    pupil_data = "data/analysis_ready/BAP_analysis_ready_PUPIL_full.csv",
    pupil_features = "data/analysis_ready/BAP_trialwise_pupil_features.csv",
    
    # Flat files for pupillometry processing
    flat_files_dir = "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
)

# Output paths
OUTPUT_PATHS <- list(
    # Base directories
    base = "output",
    models = "output/models",
    results = "output/results",
    figures = "output/figures",
    logs = "output/logs",
    
    # Specific subdirectories
    figures_publication = "output/figures/publication_manuscript",
    figures_diagnostics = "output/figures/diagnostics",
    results_comprehensive = "output/results/comprehensive_analysis"
)

# Script paths
SCRIPT_PATHS <- list(
    # Base directory
    base = "scripts",
    
    # Core analysis scripts
    data_processing = "scripts/01_data_processing",
    feature_extraction = "scripts/02_statistical_analysis",
    
    # Main analysis scripts
    core_models = "scripts/run_analysis.R",
    pupillometry_features = "scripts/create_pupillometry_features.R",
    
    # Advanced analysis scripts
    hddm_pupillometry = "scripts/fit_hierarchical_ddm_pupillometry.R",
    between_person = "scripts/between_person_analysis_individual_differences.R",
    mediation = "scripts/mediation_analysis_effort_pupillometry.R",
    timing_sensitivity = "scripts/analyze_phasic_timing_sensitivity.R",
    lba_models = "scripts/fit_hierarchical_lba_pupillometry.R",
    
    # Visualization and reporting scripts
    publication_figures = "scripts/create_publication_figures_and_manuscript.R",
    model_extraction = "scripts/robust_model_extraction.R"
)

# Model specifications
MODEL_SPECS <- list(
    # Core models (required)
    core_models = c(
        "Model2_Force.rds",
        "Model3_Difficulty.rds",
        "Model4_Additive.rds",
        "Model5_Interaction.rds",
        "Model6_Pupillometry.rds"
    ),
    
    # Advanced models (optional)
    advanced_models = c(
        "HDDM_Pupillometry_Final.rds",
        "BetweenPerson_Boundary_Model.rds",
        "Mediation_Effort_Tonic.rds",
        "HDDM_Early_Window.rds",
        "LBA_Proxy_LogRT_Model.rds"
    ),
    
    # Convergence criteria
    convergence = list(
        rhat_threshold = 1.02,
        ess_threshold = 100,
        max_treedepth_threshold = 15,
        adapt_delta_threshold = 0.95
    )
)

# Analysis dependencies
ANALYSIS_DEPENDENCIES <- list(
    # Core models depend on behavioral data
    core_models = c("behavioral_data"),
    
    # Pupillometry models depend on pupil features
    hddm_pupillometry = c("pupil_features"),
    between_person = c("pupil_features"),
    mediation = c("pupil_features"),
    timing_sensitivity = c("pupil_features"),
    lba_models = c("pupil_features"),
    
    # Visualization depends on models
    publication_figures = c("core_models", "hddm_pupillometry"),
    model_extraction = c("core_models")
)

# Expected outputs
EXPECTED_OUTPUTS <- list(
    # Required outputs
    required = c(
        "output/models/Model2_Force.rds",
        "output/models/Model3_Difficulty.rds",
        "output/models/Model4_Additive.rds",
        "output/models/Model5_Interaction.rds",
        "output/models/Model6_Pupillometry.rds",
        "output/figures/publication_manuscript/timing_schematic.png",
        "output/results/COMPREHENSIVE_BAP_DDM_ANALYSIS_COMPLETE.md"
    ),
    
    # Optional outputs
    optional = c(
        "output/models/HDDM_Pupillometry_Final.rds",
        "output/models/BetweenPerson_Boundary_Model.rds",
        "output/models/Mediation_Effort_Tonic.rds",
        "output/results/BetweenPerson_Analysis_Results.csv",
        "output/results/Mediation_Analysis_Results.csv"
    )
)

# Performance monitoring
PERFORMANCE_MONITORING <- list(
    # Memory limits (in MB)
    max_memory = 8000,
    
    # CPU limits
    max_cores = 4,
    
    # Disk space monitoring
    min_disk_space_gb = 5,
    
    # Logging
    log_level = "INFO",
    log_file = "output/logs/pipeline.log"
)

# Export all configurations
PIPELINE_CONFIG <- list(
    options = PIPELINE_OPTIONS,
    data_paths = DATA_PATHS,
    output_paths = OUTPUT_PATHS,
    script_paths = SCRIPT_PATHS,
    model_specs = MODEL_SPECS,
    dependencies = ANALYSIS_DEPENDENCIES,
    expected_outputs = EXPECTED_OUTPUTS,
    performance = PERFORMANCE_MONITORING
)

# Make configuration available globally
if (exists("PIPELINE_CONFIG")) {
    cat("Pipeline configuration loaded successfully\n")
}
