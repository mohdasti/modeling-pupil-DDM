# Consolidate PPC metrics files for sharing with ChatGPT
# Combines 38 files into 5-6 consolidated files

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
})

# Create temp directory for consolidated files
temp_dir <- "output/ppc/metrics/consolidated_for_chatgpt"
dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)

cat("Consolidating PPC metrics files...\n")

# 1. All PPC metrics (main summary) - already exists but let's verify
if (file.exists("output/ppc/metrics/ppc_metrics_all_models.csv")) {
  file.copy("output/ppc/metrics/ppc_metrics_all_models.csv", 
            paste0(temp_dir, "/01_all_ppc_metrics.csv"), overwrite = TRUE)
  cat("✓ Created: 01_all_ppc_metrics.csv\n")
} else {
  # Combine all *_ppc_metrics.csv files
  metric_files <- list.files("output/ppc/metrics", pattern = "_ppc_metrics\\.csv$", full.names = TRUE)
  if (length(metric_files) > 0) {
    all_metrics <- rbindlist(lapply(metric_files, function(f) {
      dt <- fread(f)
      dt$model <- gsub("_ppc_metrics\\.csv$", "", basename(f))
      dt
    }), fill = TRUE)
    fwrite(all_metrics, paste0(temp_dir, "/01_all_ppc_metrics.csv"))
    cat("✓ Created: 01_all_ppc_metrics.csv\n")
  }
}

# 2. All empirical quantiles
emp_files <- list.files("output/ppc/metrics", pattern = "_empirical_qs\\.csv$", full.names = TRUE)
if (length(emp_files) > 0) {
  all_emp <- rbindlist(lapply(emp_files, function(f) {
    dt <- fread(f)
    dt$model <- gsub("_empirical_qs\\.csv$", "", basename(f))
    dt
  }), fill = TRUE)
  fwrite(all_emp, paste0(temp_dir, "/02_all_empirical_quantiles.csv"))
  cat("✓ Created: 02_all_empirical_quantiles.csv\n")
}

# 3. All QP detail
qp_files <- list.files("output/ppc/metrics", pattern = "_qp_detail\\.csv$", full.names = TRUE)
if (length(qp_files) > 0) {
  all_qp <- rbindlist(lapply(qp_files, function(f) {
    dt <- fread(f)
    dt$model <- gsub("_qp_detail\\.csv$", "", basename(f))
    dt
  }), fill = TRUE)
  fwrite(all_qp, paste0(temp_dir, "/03_all_qp_detail.csv"))
  cat("✓ Created: 03_all_qp_detail.csv\n")
}

# 4. All CAF empirical
caf_files <- list.files("output/ppc/metrics", pattern = "_caf_empirical\\.csv$", full.names = TRUE)
if (length(caf_files) > 0) {
  all_caf <- rbindlist(lapply(caf_files, function(f) {
    dt <- fread(f)
    dt$model <- gsub("_caf_empirical\\.csv$", "", basename(f))
    dt
  }), fill = TRUE)
  fwrite(all_caf, paste0(temp_dir, "/04_all_caf_empirical.csv"))
  cat("✓ Created: 04_all_caf_empirical.csv\n")
}

# 5. Top 10 cells (already exists)
if (file.exists("output/ppc/metrics/ppc_top10_cells.csv")) {
  file.copy("output/ppc/metrics/ppc_top10_cells.csv", 
            paste0(temp_dir, "/05_top10_worst_fitting_cells.csv"), overwrite = TRUE)
  cat("✓ Created: 05_top10_worst_fitting_cells.csv\n")
}

# 6. Summary statistics by model
if (file.exists("output/ppc/metrics/ppc_metrics_all_models.csv")) {
  all_metrics <- fread("output/ppc/metrics/ppc_metrics_all_models.csv")
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
      .groups = "drop"
    ) %>%
    arrange(desc(mean_composite))
  fwrite(summary_by_model, paste0(temp_dir, "/06_summary_by_model.csv"))
  cat("✓ Created: 06_summary_by_model.csv\n")
}

cat("\n✅ Consolidation complete!\n")
cat(sprintf("Files created in: %s\n", temp_dir))
cat("\nFiles to share with ChatGPT:\n")
cat("  1. 01_all_ppc_metrics.csv - Main PPC metrics (all models, all cells)\n")
cat("  2. 02_all_empirical_quantiles.csv - Empirical RT quantiles\n")
cat("  3. 03_all_qp_detail.csv - Quantile-probability detail\n")
cat("  4. 04_all_caf_empirical.csv - Conditional accuracy function data\n")
cat("  5. 05_top10_worst_fitting_cells.csv - Top 10 worst-fitting cells\n")
cat("  6. 06_summary_by_model.csv - Summary statistics by model\n")
cat("\nTotal: 6 files (down from 38)\n")






