#!/usr/bin/env Rscript
# ==============================================================================
# Package Pupil-DDM Outputs for Review
# ==============================================================================
# Purpose: Copy all pupil-DDM outputs to a review bundle directory and print
#          a comprehensive checklist for verification.
#
# Output: output/_review_bundle/pupil_ddm/
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(here)
})

cat("\n")
cat(strrep("=", 80), "\n")
cat("PACKAGE PUPIL-DDM OUTPUTS FOR REVIEW\n")
cat(strrep("=", 80), "\n\n")

# ==============================================================================
# Setup paths
# ==============================================================================

SOURCE_BASE <- here::here("output", "ddm_pupil")
BUNDLE_BASE <- here::here("output", "_review_bundle", "pupil_ddm")

# Create bundle directories
BUNDLE_TABLES <- file.path(BUNDLE_BASE, "tables")
BUNDLE_FIGS <- file.path(BUNDLE_BASE, "figs")
BUNDLE_LOGS <- file.path(BUNDLE_BASE, "logs")

for (dir in c(BUNDLE_BASE, BUNDLE_TABLES, BUNDLE_FIGS, BUNDLE_LOGS)) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
}

cat("Source directory:", SOURCE_BASE, "\n")
cat("Bundle directory:", BUNDLE_BASE, "\n\n")

# ==============================================================================
# Copy files
# ==============================================================================

cat("Copying files...\n\n")

# Copy tables
cat("1. Tables (CSV files):\n")
source_tables <- file.path(SOURCE_BASE, "tables")
if (dir.exists(source_tables)) {
  csv_files <- list.files(source_tables, pattern = "\\.csv$", full.names = TRUE)
  
  if (length(csv_files) > 0) {
    for (f in csv_files) {
      dest <- file.path(BUNDLE_TABLES, basename(f))
      file.copy(f, dest, overwrite = TRUE)
      cat("   ✓", basename(f), "\n")
    }
    cat("   Total:", length(csv_files), "CSV files copied\n\n")
  } else {
    cat("   (No CSV files found)\n\n")
  }
} else {
  cat("   (Source tables directory does not exist)\n\n")
}

# Copy figures
cat("2. Figures (PNG files):\n")
source_figs <- file.path(SOURCE_BASE, "figs")
if (dir.exists(source_figs)) {
  png_files <- list.files(source_figs, pattern = "\\.png$", full.names = TRUE)
  
  if (length(png_files) > 0) {
    for (f in png_files) {
      dest <- file.path(BUNDLE_FIGS, basename(f))
      file.copy(f, dest, overwrite = TRUE)
      cat("   ✓", basename(f), "\n")
    }
    cat("   Total:", length(png_files), "PNG files copied\n\n")
  } else {
    cat("   (No PNG files found)\n\n")
  }
} else {
  cat("   (Source figs directory does not exist)\n\n")
}

# Copy logs
cat("3. Logs (LOG files):\n")
source_logs <- file.path(SOURCE_BASE, "logs")
if (dir.exists(source_logs)) {
  log_files <- list.files(source_logs, pattern = "\\.log$", full.names = TRUE)
  
  if (length(log_files) > 0) {
    for (f in log_files) {
      dest <- file.path(BUNDLE_LOGS, basename(f))
      file.copy(f, dest, overwrite = TRUE)
      cat("   ✓", basename(f), "\n")
    }
    cat("   Total:", length(log_files), "LOG files copied\n\n")
  } else {
    cat("   (No LOG files found)\n\n")
  }
} else {
  cat("   (Source logs directory does not exist)\n\n")
}

# ==============================================================================
# Verification checklist
# ==============================================================================

cat(strrep("=", 80), "\n")
cat("VERIFICATION CHECKLIST\n")
cat(strrep("=", 80), "\n\n")

# Check 1: Confirm all files exist
cat("CHECK 1: Confirm all files exist\n")
cat(strrep("-", 80), "\n")

all_files <- c(
  list.files(BUNDLE_TABLES, full.names = TRUE),
  list.files(BUNDLE_FIGS, full.names = TRUE),
  list.files(BUNDLE_LOGS, full.names = TRUE)
)

if (length(all_files) > 0) {
  cat("Total files in bundle:", length(all_files), "\n\n")
  
  cat("Tables directory:\n")
  table_files <- list.files(BUNDLE_TABLES)
  if (length(table_files) > 0) {
    for (f in table_files) {
      cat("  ✓", f, "\n")
    }
  } else {
    cat("  (No files)\n")
  }
  cat("\n")
  
  cat("Figures directory:\n")
  fig_files <- list.files(BUNDLE_FIGS)
  if (length(fig_files) > 0) {
    for (f in fig_files) {
      cat("  ✓", f, "\n")
    }
  } else {
    cat("  (No files)\n")
  }
  cat("\n")
  
  cat("Logs directory:\n")
  log_files <- list.files(BUNDLE_LOGS)
  if (length(log_files) > 0) {
    for (f in log_files) {
      cat("  ✓", f, "\n")
    }
  } else {
    cat("  (No files)\n")
  }
  cat("\n")
} else {
  cat("WARNING: No files found in bundle!\n\n")
}

# Check 2: Print first 5 rows of each CSV
cat("\n")
cat("CHECK 2: Preview CSV files (first 5 rows)\n")
cat(strrep("-", 80), "\n\n")

csv_files <- list.files(BUNDLE_TABLES, pattern = "\\.csv$", full.names = TRUE)

if (length(csv_files) > 0) {
  for (csv_file in csv_files) {
    cat("File:", basename(csv_file), "\n")
    
    tryCatch({
      df <- read_csv(csv_file, show_col_types = FALSE)
      cat("  Dimensions:", nrow(df), "rows ×", ncol(df), "columns\n")
      cat("  Columns:", paste(names(df), collapse = ", "), "\n")
      
      if (nrow(df) > 0) {
        cat("  First 5 rows:\n")
        print(head(df, 5))
      } else {
        cat("  (Empty file)\n")
      }
      cat("\n")
    }, error = function(e) {
      cat("  ERROR reading file:", e$message, "\n\n")
    })
  }
} else {
  cat("(No CSV files to preview)\n\n")
}

# Check 3: Print model names from pupil_loo_summary.csv
cat("\n")
cat("CHECK 3: Model names from pupil_loo_summary.csv\n")
cat(strrep("-", 80), "\n\n")

loo_file <- file.path(BUNDLE_TABLES, "pupil_loo_summary.csv")

if (file.exists(loo_file)) {
  tryCatch({
    loo_data <- read_csv(loo_file, show_col_types = FALSE)
    
    if ("model_name" %in% names(loo_data)) {
      model_names <- unique(loo_data$model_name)
      cat("Models found:\n")
      for (i in seq_along(model_names)) {
        cat("  ", i, ".", model_names[i], "\n")
      }
      cat("\nTotal models:", length(model_names), "\n")
    } else if ("model" %in% names(loo_data)) {
      model_names <- unique(loo_data$model)
      cat("Models found:\n")
      for (i in seq_along(model_names)) {
        cat("  ", i, ".", model_names[i], "\n")
      }
      cat("\nTotal models:", length(model_names), "\n")
    } else {
      cat("WARNING: No 'model_name' or 'model' column found\n")
      cat("Available columns:", paste(names(loo_data), collapse = ", "), "\n")
    }
  }, error = function(e) {
    cat("ERROR reading pupil_loo_summary.csv:", e$message, "\n")
  })
} else {
  cat("File not found: pupil_loo_summary.csv\n")
  cat("This file will be created after running fit_pupil_ddm_models.R\n")
  cat("and the postprocessing script.\n")
}

cat("\n")

# ==============================================================================
# Summary
# ==============================================================================

cat(strrep("=", 80), "\n")
cat("SUMMARY\n")
cat(strrep("=", 80), "\n\n")

cat("Bundle location:", BUNDLE_BASE, "\n")
cat("Total files packaged:", length(all_files), "\n\n")

cat("Contents:\n")
cat("  Tables:", length(list.files(BUNDLE_TABLES)), "files\n")
cat("  Figures:", length(list.files(BUNDLE_FIGS)), "files\n")
cat("  Logs:", length(list.files(BUNDLE_LOGS)), "files\n\n")

if (length(all_files) > 0) {
  cat("✓ Review bundle created successfully!\n")
} else {
  cat("⚠ WARNING: Bundle is empty. Run pupil-DDM pipeline first:\n")
  cat("  1. Rscript scripts/fit_pupil_ddm_models.R\n")
  cat("  2. Rscript scripts/postprocess_pupil_ddm_results.R (to be created)\n")
  cat("  3. Rscript scripts/package_pupil_outputs_for_review.R\n")
}

cat("\n")
cat(strrep("=", 80), "\n\n")
