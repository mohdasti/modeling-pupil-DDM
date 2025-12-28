# R/extract_ppc_heatmap_tables.R
# Produce wide and long tables for heatmap figure (KS and QP)
# Feeds quick visuals and a 1-row gate

source("R/_helpers_extract.R")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

# Set working directory if needed
if (basename(getwd()) == "R") {
  setwd("..")
}

# Prefer unconditional if available, otherwise use main
ppc <- safe_read_csv(PPC_UNCOND) %||% safe_read_csv(PPC_MAIN)

# Check for alternative column names
if (!all(c("ks_mean_max", "qp_rmse_max") %in% names(ppc))) {
  # Try alternative names
  if ("ks_mean" %in% names(ppc) && !"ks_mean_max" %in% names(ppc)) {
    ppc$ks_mean_max <- ppc$ks_mean
  }
  if ("qp_rmse" %in% names(ppc) && !"qp_rmse_max" %in% names(ppc)) {
    ppc$qp_rmse_max <- ppc$qp_rmse
  }
}

# Ensure required columns exist
stopifnot(all(c("task", "effort_condition", "difficulty_level") %in% names(ppc)))
stopifnot(any(c("ks_mean_max", "ks_mean") %in% names(ppc)))
stopifnot(any(c("qp_rmse_max", "qp_rmse") %in% names(ppc)))

# Use available column names
ks_col <- if ("ks_mean_max" %in% names(ppc)) "ks_mean_max" else "ks_mean"
qp_col <- if ("qp_rmse_max" %in% names(ppc)) "qp_rmse_max" else "qp_rmse"

# Long format (for heatmap plotting)
heat_long <- ppc |>
  transmute(
    task,
    effort_condition,
    difficulty_level,
    KS = .data[[ks_col]],
    QP = .data[[qp_col]]
  ) |>
  pivot_longer(cols = c(KS, QP), names_to = "metric", values_to = "value")

write_clean(heat_long, "output/publish/ppc_heatmap_long.csv")
cat("✓ Long format written.\n")

# Wide format (for quick reference table)
heat_wide <- ppc |>
  select(
    task,
    effort_condition,
    difficulty_level,
    ks_mean_max = all_of(ks_col),
    qp_rmse_max = all_of(qp_col)
  )

write_clean(heat_wide, "output/publish/ppc_heatmap_wide.csv")
cat("✓ Wide format written.\n")

message("✓ PPC heatmap tables written.")

cat("\n✓ PPC heatmap extraction complete.\n")
cat("  Generated files:\n")
cat("    - output/publish/ppc_heatmap_long.csv (for plotting)\n")
cat("    - output/publish/ppc_heatmap_wide.csv (for reference)\n")
cat("\n  Summary:\n")
cat("    - Cells: ", nrow(ppc), "\n")
cat("    - Metrics: KS, QP\n")


