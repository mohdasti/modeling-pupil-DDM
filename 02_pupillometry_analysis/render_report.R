# ============================================================================
# RENDER QUARTO REPORT
# ============================================================================
# Run this script in RStudio console to render the pupil data report
# This will generate the HTML report and all CSV/plot outputs

# Set working directory to project root
setwd("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")

# Check if quarto is available
if (!requireNamespace("quarto", quietly = TRUE)) {
  stop("Quarto package not installed. Install with: install.packages('quarto')")
}

# Check if quarto command-line tool is available
if (!quarto::quarto_path() == "") {
  cat("Quarto found at:", quarto::quarto_path(), "\n")
} else {
  cat("⚠ Warning: Quarto command-line tool not found in PATH.\n")
  cat("  You may need to install Quarto: https://quarto.org/docs/get-started/\n")
}

# Path to the qmd file
qmd_file <- "02_pupillometry_analysis/generate_pupil_data_report.qmd"

# Check if file exists
if (!file.exists(qmd_file)) {
  stop("Report file not found: ", qmd_file)
}

cat("\n")
cat(paste0(rep("=", 70), collapse = ""), "\n")
cat("RENDERING PUPIL DATA REPORT\n")
cat(paste0(rep("=", 70), collapse = ""), "\n")
cat("File:", qmd_file, "\n")
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("\n")

# Render the report
# This will:
# 1. Execute all code chunks
# 2. Generate all CSV files in data/qc/
# 3. Generate all plots in figures/
# 4. Create the HTML report
tryCatch({
  quarto::quarto_render(
    input = qmd_file,
    output_format = "html",
    execute_params = list(
      # You can override params here if needed
      # processed_dir = "/path/to/processed",
      # behavioral_file = "/path/to/behavioral.csv"
    )
  )
  
  cat("\n")
  cat(paste0(rep("=", 70), collapse = ""), "\n")
  cat("✓ REPORT RENDERED SUCCESSFULLY\n")
  cat(paste0(rep("=", 70), collapse = ""), "\n")
  cat("Completed at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
  cat("\n")
  cat("Output files:\n")
  cat("- HTML report:", gsub("\\.qmd$", ".html", qmd_file), "\n")
  cat("- CSV files: data/qc/*.csv\n")
  cat("- Figures: figures/*.png\n")
  cat("\n")
  
}, error = function(e) {
  cat("\n")
  cat(paste0(rep("=", 70), collapse = ""), "\n")
  cat("✗ RENDERING FAILED\n")
  cat(paste0(rep("=", 70), collapse = ""), "\n")
  cat("Error:", conditionMessage(e), "\n")
  cat("\n")
  stop(e)
})

