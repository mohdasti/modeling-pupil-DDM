# =========================================================================
# GENERATE INCREMENTAL DIAGNOSTICS REPORT
# =========================================================================
# Run this after each model to see updated progress
# Usage: source("scripts/generate_incremental_report.R")
# =========================================================================

library(readr)
library(knitr)

cat("\n")
cat("================================================================================\n")
cat("INCREMENTAL DIAGNOSTICS REPORT\n")
cat("================================================================================\n")
cat("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Load diagnostics
csv_file <- "output/diagnostics/convergence_report.csv"
if (!file.exists(csv_file)) {
  cat("⚠️  No diagnostics file found. Run stabilization script first.\n")
  q()
}

diag <- read.csv(csv_file, stringsAsFactors = FALSE)

# Summary stats
n_total <- length(c("Model1_Baseline", "Model2_Force", "Model7_Task", "Model8_Task_Additive"))
n_completed <- sum(!is.na(diag$fit_time_minutes))
n_converged <- sum(diag$converged, na.rm = TRUE)
n_pending <- n_total - n_completed

cat("PROGRESS SUMMARY\n")
cat("----------------------------------------------------------------------\n")
cat(sprintf("Total models:        %d\n", n_total))
cat(sprintf("Completed:           %d\n", n_completed))
cat(sprintf("  ✓ Converged:       %d\n", n_converged))
cat(sprintf("  ⚠️  Failed conv:   %d\n", n_completed - n_converged))
cat(sprintf("Pending:             %d\n", n_pending))
cat("----------------------------------------------------------------------\n\n")

# Detailed table
cat("DETAILED RESULTS\n")
cat("----------------------------------------------------------------------\n")
cat(sprintf("%-25s %8s %10s %12s %10s %10s\n", 
            "Model", "Status", "R-hat", "ESS Ratio", "Time (min)", "Converged"))
cat("----------------------------------------------------------------------\n")

for (i in 1:nrow(diag)) {
  row <- diag[i, ]
  
  if (is.na(row$fit_time_minutes)) {
    status <- "ERROR"
    rhat_str <- "N/A"
    ess_str <- "N/A"
    time_str <- "N/A"
    conv_str <- "N/A"
  } else {
    status <- "DONE"
    rhat_str <- sprintf("%.4f", row$max_rhat)
    ess_str <- sprintf("%.4f", row$min_ess_ratio)
    time_str <- sprintf("%.1f", row$fit_time_minutes)
    conv_str <- ifelse(row$converged, "✓ YES", "✗ NO")
  }
  
  cat(sprintf("%-25s %8s %10s %12s %10s %10s\n",
              row$model, status, rhat_str, ess_str, time_str, conv_str))
}

cat("----------------------------------------------------------------------\n\n")

# Convergence warnings
failed_models <- diag[!diag$converged & !is.na(diag$fit_time_minutes), ]
if (nrow(failed_models) > 0) {
  cat("⚠️  CONVERGENCE WARNINGS\n")
  cat("----------------------------------------------------------------------\n")
  for (i in 1:nrow(failed_models)) {
    row <- failed_models[i, ]
    cat(sprintf("%s:\n", row$model))
    cat(sprintf("  R-hat: %.4f (threshold: 1.05) %s\n", 
                row$max_rhat, ifelse(row$max_rhat > 1.05, "❌", "✓")))
    cat(sprintf("  ESS ratio: %.4f (threshold: 0.1) %s\n", 
                row$min_ess_ratio, ifelse(row$min_ess_ratio < 0.1, "❌", "✓")))
    cat("\n")
  }
}

# Pending models
all_models <- c("Model1_Baseline", "Model2_Force", "Model7_Task", "Model8_Task_Additive")
completed_names <- diag$model[!is.na(diag$fit_time_minutes)]
pending <- setdiff(all_models, completed_names)

if (length(pending) > 0) {
  cat("⏳ PENDING MODELS\n")
  cat("----------------------------------------------------------------------\n")
  for (model in pending) {
    cat(sprintf("  - %s\n", model))
  }
  cat("\n")
  cat("Run: source('scripts/stabilize_one_model.R')\n")
  cat("     Then select the model number to stabilize next.\n\n")
}

# Save markdown report
report_file <- "output/diagnostics/incremental_report.md"
cat("GENERATING MARKDOWN REPORT...\n")

md_content <- paste0(
  "# Incremental Stabilization Report\n\n",
  "**Generated:** ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n",
  "## Progress Summary\n\n",
  "- **Total models:** ", n_total, "\n",
  "- **Completed:** ", n_completed, "\n",
  "- **Converged:** ", n_converged, "\n",
  "- **Pending:** ", n_pending, "\n\n",
  "## Detailed Results\n\n",
  "| Model | Status | R-hat | ESS Ratio | Time (min) | Converged |\n",
  "|-------|--------|-------|-----------|------------|-----------|\n"
)

for (i in 1:nrow(diag)) {
  row <- diag[i, ]
  if (is.na(row$fit_time_minutes)) {
    md_content <- paste0(md_content, 
      "| ", row$model, " | ERROR | N/A | N/A | N/A | N/A |\n")
  } else {
    md_content <- paste0(md_content,
      "| ", row$model, " | DONE | ", 
      sprintf("%.4f", row$max_rhat), " | ",
      sprintf("%.4f", row$min_ess_ratio), " | ",
      sprintf("%.1f", row$fit_time_minutes), " | ",
      ifelse(row$converged, "✓ YES", "✗ NO"), " |\n")
  }
}

writeLines(md_content, report_file)
cat("✓ Report saved to:", report_file, "\n\n")

cat("================================================================================\n")
cat("Report complete!\n")
cat("================================================================================\n\n")









