# =========================================================================
# PPC PUBLISH READOUT
# =========================================================================
# Combines PPC metrics with convergence diagnostics to create a model
# readiness summary for publication
# =========================================================================

suppressPackageStartupMessages({ 
  library(data.table)
  library(dplyr)
})

# Create output directory
dir.create("output/ppc", recursive = TRUE, showWarnings = FALSE)

# Load data
root <- "output/ppc/metrics/consolidated_for_chatgpt"

cat("Loading PPC metrics...\n")
ppc     <- fread(file.path(root, "01_all_ppc_metrics.csv"))
summ    <- fread(file.path(root, "06_summary_by_model.csv"))
worst10 <- fread(file.path(root, "05_top10_worst_fitting_cells.csv"))

cat("Loading convergence diagnostics...\n")
conv <- fread("output/diagnostics/convergence_summary_all.csv")

# Apply the agreed thresholds
ACC_TOL <- 0.05
QP_TOL_S <- 0.09
KS_TOL <- 0.15
CAF_TOL <- 0.07

cat("Applying thresholds and computing flags...\n")
ppc[, any_flag := (abs(emp_acc - pred_acc_mean) > ACC_TOL) |
                     (qp_rmse_max > QP_TOL_S) |
                     (ks_mean_max > KS_TOL) |
                     (caf_rmse > CAF_TOL)]

# Model readiness summary
cat("Creating readiness summary...\n")
readiness <- ppc %>%
  group_by(model) %>%
  summarise(
    n_cells = n(),
    pct_flagged = mean(any_flag) * 100,
    mean_abs_dacc = mean(abs(emp_acc - pred_acc_mean), na.rm = TRUE),
    mean_qp_rmse  = mean(qp_rmse_max, na.rm = TRUE),
    max_ks        = max(ks_mean_max, na.rm = TRUE),
    mean_caf_rmse = mean(caf_rmse, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(
    conv %>% 
      select(model, max_rhat, min_bulk_ESS_ratio, min_tail_ESS_ratio, n_divergences) %>%
      rename(
        min_bulk_ess_ratio = min_bulk_ESS_ratio,
        min_tail_ess_ratio = min_tail_ESS_ratio,
        divergences = n_divergences
      ),
    by = "model"
  )

# Write outputs
cat("Writing outputs...\n")
fwrite(readiness, "output/ppc/publish_readout_readiness.csv")
fwrite(worst10,  "output/ppc/publish_readout_worst10.csv")

cat("\n================================================================================\n")
cat("COMPLETE\n")
cat("================================================================================\n")
cat("Wrote:\n")
cat("  - output/ppc/publish_readout_readiness.csv\n")
cat("  - output/ppc/publish_readout_worst10.csv\n\n")

# Print summary
cat("Model Readiness Summary:\n")
print(readiness)
cat("\n")

message("Wrote publish_readout_readiness.csv and publish_readout_worst10.csv")








