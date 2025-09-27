#!/usr/bin/env Rscript
# =========================================================================
# BAP DDM PIPELINE - MAIN ENTRY POINT
# =========================================================================
# This is the main entry point for the BAP DDM analysis pipeline
# It provides easy access to all pipeline functionality
# =========================================================================

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Default to simple pipeline
pipeline_type <- "simple"
skip_heavy <- FALSE
force_rerun <- FALSE
detailed_logging <- FALSE

# Parse arguments
for (arg in args) {
    if (arg == "--advanced") {
        pipeline_type <- "advanced"
    } else if (arg == "--logging") {
        detailed_logging <- TRUE
    } else if (arg == "--skip-heavy") {
        skip_heavy <- TRUE
    } else if (arg == "--force-rerun") {
        force_rerun <- TRUE
    } else if (arg == "--help") {
        cat("BAP DDM Analysis Pipeline - Main Entry Point\n\n")
        cat("Usage: Rscript run_pipeline.R [options]\n\n")
        cat("Options:\n")
        cat("  --advanced      Run advanced pipeline (with full dependency checking)\n")
        cat("  --logging       Run with detailed logging and performance monitoring\n")
        cat("  --skip-heavy    Skip computationally intensive models\n")
        cat("  --force-rerun   Force rerun all analyses (ignore existing files)\n")
        cat("  --help          Show this help message\n\n")
        cat("Examples:\n")
        cat("  Rscript run_pipeline.R                           # Simple pipeline\n")
        cat("  Rscript run_pipeline.R --logging                 # With detailed logging\n")
        cat("  Rscript run_pipeline.R --advanced                # Advanced pipeline\n")
        cat("  Rscript run_pipeline.R --logging --skip-heavy    # Logging with skip heavy models\n")
        cat("  Rscript run_pipeline.R --force-rerun             # Force rerun everything\n\n")
        cat("For status checking:\n")
        cat("  Rscript scripts/utilities/pipeline_status.R\n\n")
        cat("For log analysis:\n")
        cat("  Rscript scripts/utilities/analyze_pipeline_logs.R\n")
        quit(status = 0)
    }
}

# Build command based on options
if (detailed_logging) {
    script_path <- "scripts/core/run_bap_analysis_with_logging.R"
} else if (pipeline_type == "advanced") {
    script_path <- "scripts/core/run_complete_bap_pipeline.R"
} else {
    script_path <- "scripts/core/run_bap_analysis.R"
}

# Build arguments
cmd_args <- character(0)
if (skip_heavy) {
    cmd_args <- c(cmd_args, "--skip-heavy")
}
if (force_rerun) {
    cmd_args <- c(cmd_args, "--force-rerun")
}

# Execute the pipeline
cat("================================================================================\n")
cat("BAP DDM ANALYSIS PIPELINE\n")
cat("================================================================================\n")
cat("Running:", script_path, "\n")
if (length(cmd_args) > 0) {
    cat("Arguments:", paste(cmd_args, collapse = " "), "\n")
}
cat("Timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("================================================================================\n\n")

# Execute the script
result <- system2("Rscript", c(script_path, cmd_args), stdout = "", stderr = "")

if (result == 0) {
    cat("\n================================================================================\n")
    cat("✅ PIPELINE COMPLETED SUCCESSFULLY!\n")
    cat("================================================================================\n")
} else {
    cat("\n================================================================================\n")
    cat("❌ PIPELINE FAILED!\n")
    cat("================================================================================\n")
    quit(status = result)
}
