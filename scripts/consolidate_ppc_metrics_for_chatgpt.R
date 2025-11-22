# =========================================================================
# CONSOLIDATE PPC METRICS FOR CHATGPT
# =========================================================================
# Consolidates 38 CSV files from output/ppc/metrics into < 8 files
# without losing any data or content
# =========================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
})

# Create temp directory for consolidated files
temp_dir <- "output/ppc/metrics/consolidated_for_chatgpt"
dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)

cat("================================================================================\n")
cat("CONSOLIDATING PPC METRICS FOR CHATGPT\n")
cat("================================================================================\n")
cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# =========================================================================
# 1. ALL PPC METRICS (Main summary - already exists)
# =========================================================================

if (file.exists("output/ppc/metrics/ppc_metrics_all_models.csv")) {
  file.copy("output/ppc/metrics/ppc_metrics_all_models.csv", 
            paste0(temp_dir, "/01_all_ppc_metrics.csv"), overwrite = TRUE)
  cat("✓ Created: 01_all_ppc_metrics.csv\n")
  cat("  (Main PPC metrics: accuracy, QP RMSE, KS stats, CAF RMSE, flags)\n\n")
} else {
  # If it doesn't exist, create it by combining all _ppc_metrics.csv files
  metric_files <- list.files("output/ppc/metrics", pattern = "_ppc_metrics\\.csv$", full.names = TRUE)
  if (length(metric_files) > 0) {
    all_metrics <- rbindlist(lapply(metric_files, function(f) {
      dt <- fread(f)
      dt$model <- gsub("_ppc_metrics\\.csv$", "", basename(f))
      dt
    }), fill = TRUE)
    fwrite(all_metrics, paste0(temp_dir, "/01_all_ppc_metrics.csv"))
    cat("✓ Created: 01_all_ppc_metrics.csv (combined from per-model files)\n\n")
  }
}

# =========================================================================
# 2. ALL EMPIRICAL QUANTILES
# =========================================================================

emp_files <- list.files("output/ppc/metrics", pattern = "_empirical_qs\\.csv$", full.names = TRUE)
if (length(emp_files) > 0) {
  all_emp <- rbindlist(lapply(emp_files, function(f) {
    dt <- fread(f)
    dt$model <- gsub("_empirical_qs\\.csv$", "", basename(f))
    dt
  }), fill = TRUE)
  fwrite(all_emp, paste0(temp_dir, "/02_all_empirical_quantiles.csv"))
  cat("✓ Created: 02_all_empirical_quantiles.csv\n")
  cat("  (Empirical RT quantiles: 10th, 30th, 50th, 70th, 90th by condition)\n\n")
}

# =========================================================================
# 3. ALL QP DETAIL
# =========================================================================

qp_files <- list.files("output/ppc/metrics", pattern = "_qp_detail\\.csv$", full.names = TRUE)
if (length(qp_files) > 0) {
  all_qp <- rbindlist(lapply(qp_files, function(f) {
    dt <- fread(f)
    dt$model <- gsub("_qp_detail\\.csv$", "", basename(f))
    dt
  }), fill = TRUE)
  fwrite(all_qp, paste0(temp_dir, "/03_all_qp_detail.csv"))
  cat("✓ Created: 03_all_qp_detail.csv\n")
  cat("  (Quantile-probability detail: empirical vs predicted RT quantiles)\n\n")
}

# =========================================================================
# 4. ALL CAF EMPIRICAL
# =========================================================================

caf_files <- list.files("output/ppc/metrics", pattern = "_caf_empirical\\.csv$", full.names = TRUE)
if (length(caf_files) > 0) {
  all_caf <- rbindlist(lapply(caf_files, function(f) {
    dt <- fread(f)
    dt$model <- gsub("_caf_empirical\\.csv$", "", basename(f))
    dt
  }), fill = TRUE)
  fwrite(all_caf, paste0(temp_dir, "/04_all_caf_empirical.csv"))
  cat("✓ Created: 04_all_caf_empirical.csv\n")
  cat("  (Conditional accuracy function: accuracy by RT bins)\n\n")
}

# =========================================================================
# 5. TOP 10 WORST-FITTING CELLS
# =========================================================================

if (file.exists("output/ppc/metrics/ppc_top10_cells.csv")) {
  file.copy("output/ppc/metrics/ppc_top10_cells.csv", 
            paste0(temp_dir, "/05_top10_worst_fitting_cells.csv"), overwrite = TRUE)
  cat("✓ Created: 05_top10_worst_fitting_cells.csv\n")
  cat("  (Top 10 worst-fitting cells across all models)\n\n")
} else {
  # Create from consolidated metrics if available
  if (file.exists(paste0(temp_dir, "/01_all_ppc_metrics.csv"))) {
    all_metrics <- fread(paste0(temp_dir, "/01_all_ppc_metrics.csv"))
    top10 <- all_metrics %>%
      arrange(desc(composite_score)) %>%
      slice_head(n = 10)
    fwrite(top10, paste0(temp_dir, "/05_top10_worst_fitting_cells.csv"))
    cat("✓ Created: 05_top10_worst_fitting_cells.csv (extracted from consolidated metrics)\n\n")
  }
}

# =========================================================================
# 6. SUMMARY BY MODEL
# =========================================================================

if (file.exists(paste0(temp_dir, "/01_all_ppc_metrics.csv"))) {
  all_metrics <- fread(paste0(temp_dir, "/01_all_ppc_metrics.csv"))
  summary_by_model <- all_metrics %>%
    group_by(model) %>%
    summarise(
      n_cells = n(),
      n_flagged = sum(any_flag, na.rm = TRUE),
      pct_flagged = round(100 * mean(any_flag, na.rm = TRUE), 1),
      mean_acc_diff = round(mean(acc_abs_diff, na.rm = TRUE), 4),
      mean_qp_rmse = round(mean(qp_rmse_max, na.rm = TRUE), 4),
      mean_ks_stat = round(mean(ks_mean_max, na.rm = TRUE), 4),
      mean_caf_rmse = round(mean(caf_rmse, na.rm = TRUE), 4),
      mean_composite = round(mean(composite_score, na.rm = TRUE), 2),
      max_composite = round(max(composite_score, na.rm = TRUE), 2),
      .groups = "drop"
    ) %>%
    arrange(desc(mean_composite))
  fwrite(summary_by_model, paste0(temp_dir, "/06_summary_by_model.csv"))
  cat("✓ Created: 06_summary_by_model.csv\n")
  cat("  (Summary statistics by model: % flagged, mean errors, etc.)\n\n")
}

# =========================================================================
# 7. FLAGGED CELLS ONLY (for quick review)
# =========================================================================

if (file.exists(paste0(temp_dir, "/01_all_ppc_metrics.csv"))) {
  all_metrics <- fread(paste0(temp_dir, "/01_all_ppc_metrics.csv"))
  flagged_cells <- all_metrics %>%
    filter(any_flag == TRUE) %>%
    arrange(desc(composite_score))
  fwrite(flagged_cells, paste0(temp_dir, "/07_flagged_cells_only.csv"))
  cat("✓ Created: 07_flagged_cells_only.csv\n")
  cat("  (All cells with any flag = TRUE, sorted by worst fit)\n\n")
}

# =========================================================================
# SUMMARY
# =========================================================================

cat("================================================================================\n")
cat("CONSOLIDATION COMPLETE\n")
cat("================================================================================\n")
cat(sprintf("Files created in: %s\n\n", temp_dir))

consolidated_files <- list.files(temp_dir, pattern = "\\.csv$", full.names = FALSE)
cat(sprintf("Total files: %d (down from 38)\n\n", length(consolidated_files)))

cat("Files to share with ChatGPT:\n")
cat("  1. 01_all_ppc_metrics.csv - Main PPC metrics (all models, all cells)\n")
cat("  2. 02_all_empirical_quantiles.csv - Empirical RT quantiles\n")
cat("  3. 03_all_qp_detail.csv - Quantile-probability detail\n")
cat("  4. 04_all_caf_empirical.csv - Conditional accuracy function data\n")
cat("  5. 05_top10_worst_fitting_cells.csv - Top 10 worst-fitting cells\n")
cat("  6. 06_summary_by_model.csv - Summary statistics by model\n")
cat("  7. 07_flagged_cells_only.csv - All flagged cells (quick review)\n\n")

cat("All data preserved - no information lost!\n")
cat("Each file includes a 'model' column to filter by model if needed.\n\n")

# Show file sizes
cat("File sizes:\n")
for (f in sort(consolidated_files)) {
  file_path <- paste0(temp_dir, "/", f)
  if (file.exists(file_path)) {
    size_kb <- round(file.size(file_path) / 1024, 1)
    cat(sprintf("  %s: %.1f KB\n", f, size_kb))
  }
}
cat("\n")

cat("================================================================================\n")
cat("COMPLETE\n")
cat("================================================================================\n")






