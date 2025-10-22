# =========================================================================
# BAP COMPLETE ANALYSIS PIPELINE (BULLETPROOF VERSION)
# =========================================================================
cat("--- INITIALIZING PIPELINE ---\n")
suppressPackageStartupMessages({
    library(dplyr)
    library(readr)
    library(purrr)
    library(tidyr)
    library(ggplot2)
})
suppressPackageStartupMessages({
    library(brms)
})
cat("SUCCESS: All packages loaded. 'brms' has priority.\n")
source(file.path(getwd(), "config", "paths_config.R"))
log_file <- file.path(OUTPUT_PATHS$logs, get_timestamped_filename("BAP_Analysis_Log", "md"))
log_message <- function(message, level = "INFO") {
    log_entry <- sprintf("[%s] [%s] %s\n", format(Sys.time(), "%H:%M:%S"), level, message)
    cat(log_entry)
    write(log_entry, file = log_file, append = TRUE)
}
write_header <- function(title) {
    header <- paste0("\n\n## ", title, "\n", paste(rep("=", nchar(title) + 3), collapse = ""), "\n")
    cat(header)
    write(header, file = log_file, append = TRUE)
}
write_header("BAP ANALYSIS PIPELINE START")
log_message(sprintf("Pipeline started at %s.", Sys.time()), "START")
write_header("STEP 1: Data Processing, QC, and Visualization")
tryCatch({
    source(file.path(SCRIPT_PATHS$processing, "01_process_and_qc.R"))
    log_message("Step 1 completed successfully.")
}, error = function(e) {
    log_message(paste("FATAL ERROR in Step 1:", e$message), "ERROR")
    stop("Pipeline stopped due to a fatal error during data processing.")
})
write_header("STEP 2: DDM Statistical Modeling")
tryCatch({
    source(file.path(SCRIPT_PATHS$analysis, "02_ddm_analysis.R"))
    log_message("Step 2 completed successfully.")
}, error = function(e) {
    log_message(paste("ERROR in Step 2:", e$message), "ERROR")
})
write_header("PIPELINE COMPLETE")
log_message(sprintf("Pipeline finished at %s.", Sys.time()), "COMPLETE")
cat(sprintf("\nAnalysis complete. Check the comprehensive log file for details:\n%s\n", log_file))