# R/extract_ppc_gates.R
# Compute % flagged and list worst cells using thresholds
# Export CSV + MD

source("R/_helpers_extract.R")

suppressPackageStartupMessages({
  library(dplyr)
})

# Set working directory if needed
if (basename(getwd()) == "R") {
  setwd("..")
}

# Prefer unconditional if available, otherwise use main
ppc <- safe_read_csv(PPC_UNCOND) %||% safe_read_csv(PPC_MAIN)

# Expected columns: task, effort_condition, difficulty_level, qp_rmse_max, ks_mean_max
# Check for alternative column names
if (!all(c("qp_rmse_max", "ks_mean_max") %in% names(ppc))) {
  # Try alternative names
  if ("qp_rmse" %in% names(ppc) && !"qp_rmse_max" %in% names(ppc)) {
    ppc$qp_rmse_max <- ppc$qp_rmse
  }
  if ("ks_mean" %in% names(ppc) && !"ks_mean_max" %in% names(ppc)) {
    ppc$ks_mean_max <- ppc$ks_mean
  }
}

stopifnot(all(c("task", "effort_condition", "difficulty_level") %in% names(ppc)))
stopifnot(any(c("qp_rmse_max", "qp_rmse") %in% names(ppc)))
stopifnot(any(c("ks_mean_max", "ks_mean") %in% names(ppc)))

# Use available column names
qp_col <- if ("qp_rmse_max" %in% names(ppc)) "qp_rmse_max" else "qp_rmse"
ks_col <- if ("ks_mean_max" %in% names(ppc)) "ks_mean_max" else "ks_mean"

# Thresholds
th_qp_warn <- 0.09
th_qp_fail <- 0.12
th_ks_warn <- 0.15
th_ks_fail <- 0.20

ppc2 <- ppc |>
  mutate(
    qp_flag = .data[[qp_col]] > th_qp_fail,
    ks_flag = .data[[ks_col]] > th_ks_fail,
    any_flag = qp_flag | ks_flag
  )

gate <- ppc2 |>
  summarise(
    n_cells = n(),
    pct_flagged = mean(any_flag, na.rm = TRUE) * 100,
    max_qp = max(.data[[qp_col]], na.rm = TRUE),
    max_ks = max(.data[[ks_col]], na.rm = TRUE),
    .groups = "drop"
  )

write_clean(ppc2, "output/publish/ppc_cells_detail.csv")
write_clean(gate, "output/publish/ppc_gate_summary.csv")

# Create markdown summary
md <- paste0(
  "## PPC Gate\n",
  "- Cells: ", gate$n_cells, "\n",
  "- % flagged: ", sprintf("%.1f", gate$pct_flagged), "%\n",
  "- Max QP RMSE: ", sprintf("%.3f", gate$max_qp), " (fail>", th_qp_fail, ")\n",
  "- Max KS: ", sprintf("%.3f", gate$max_ks), " (fail>", th_ks_fail, ")\n"
)

writeLines(md, "output/publish/ppc_gate_summary.md")
message("✓ PPC gate metrics written.")

cat("\n✓ PPC gate extraction complete.\n")
cat("  Generated files:\n")
cat("    - output/publish/ppc_cells_detail.csv\n")
cat("    - output/publish/ppc_gate_summary.csv\n")
cat("    - output/publish/ppc_gate_summary.md\n")
cat("\n  Summary:\n")
cat("    - Cells: ", gate$n_cells, "\n")
cat("    - % flagged: ", sprintf("%.1f", gate$pct_flagged), "%\n")
cat("    - Max QP RMSE: ", sprintf("%.3f", gate$max_qp), "\n")
cat("    - Max KS: ", sprintf("%.3f", gate$max_ks), "\n")


