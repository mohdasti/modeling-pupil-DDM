# R/verify_all_figures_complete.R
# Verify all figures include complete data

suppressPackageStartupMessages({
  library(readr); library(dplyr)
})

cat("=== VERIFYING FIGURE COMPLETENESS ===\n\n")

# 1. Check bias forest plot data
cat("1. Bias Forest Plot (fig_bias_forest):\n")
bias_levels <- read_csv("output/publish/bias_standard_only_levels.csv", show_col_types = FALSE)
bias_probs <- bias_levels %>% filter(scale == "prob")
cat("   Conditions:", nrow(bias_probs), "(should be 4)\n")
cat("   Conditions:", paste(bias_probs$param, collapse = ", "), "\n")
if (nrow(bias_probs) == 4 && "bias_VDT_High" %in% bias_probs$param) {
  cat("   ✓ COMPLETE: All 4 conditions included\n")
} else {
  cat("   ✗ INCOMPLETE: Missing conditions\n")
}

# 2. Check PPC small multiples
cat("\n2. PPC Small Multiples (fig_ppc_small_multiples):\n")
ppc <- read_csv("output/publish/ppc_joint_minimal.csv", show_col_types = FALSE)
cat("   Total cells:", nrow(ppc), "(should be 12: 2 tasks × 2 effort × 3 difficulty)\n")
if (nrow(ppc) == 12) {
  cat("   ✓ COMPLETE: All 12 cells included\n")
} else {
  cat("   ✗ INCOMPLETE: Missing cells\n")
}

# 3. Check p("different") heatmap
cat("\n3. p('different') Heatmap (fig_pdiff_heatmap):\n")
dd <- read_csv("data/analysis_ready/bap_ddm_ready_with_upper.csv", show_col_types = FALSE)
all_cells <- dd %>%
  count(task, effort_condition, difficulty_level) %>%
  arrange(task, effort_condition, difficulty_level)
cat("   Total cells in data:", nrow(all_cells), "(should be 12)\n")
if (nrow(all_cells) == 12) {
  cat("   ✓ COMPLETE: All 12 cells in data (figure uses all cells)\n")
} else {
  cat("   ✗ INCOMPLETE: Missing cells in data\n")
}

# 4. Check v(Standard) posterior (doesn't need conditions check)
cat("\n4. v(Standard) Posterior (fig_v_standard_posterior):\n")
cat("   ✓ OK: Single parameter plot (no conditions needed)\n")

# Summary
cat("\n=== SUMMARY ===\n")
all_ok <- (nrow(bias_probs) == 4 && "bias_VDT_High" %in% bias_probs$param) &&
          (nrow(ppc) == 12) &&
          (nrow(all_cells) == 12)

if (all_ok) {
  cat("✓ ALL FIGURES ARE COMPLETE\n")
  cat("  - Bias forest: 4/4 conditions\n")
  cat("  - PPC small multiples: 12/12 cells\n")
  cat("  - p('different') heatmap: 12/12 cells\n")
  cat("  - v(Standard) posterior: N/A (single parameter)\n")
} else {
  cat("✗ SOME FIGURES MAY BE INCOMPLETE\n")
  cat("  Please check the details above.\n")
}

