# R/run_extract_all.R
# Master runner: executes all extraction scripts and prints checklist
# Run once and go make tea

# Set working directory if needed
if (basename(getwd()) == "R") {
  setwd("..")
}

scr <- c(
  "R/extract_design_qa.R",
  "R/extract_manip_checks.R",
  "R/extract_ppc_gates.R",
  "R/extract_loo_summary.R",
  "R/extract_params_and_contrasts.R",
  "R/extract_ppc_heatmap_tables.R"
)

cat("========================================\n")
cat("Running all extraction scripts...\n")
cat("========================================\n\n")

for (s in scr) {
  message(">> Running ", s)
  tryCatch({
    source(s, local = TRUE)
    cat("  ✓ Completed\n\n")
  }, error = function(e) {
    cat("  ✗ ERROR:", conditionMessage(e), "\n\n")
  })
}

cat("\n========================================\n")
cat("=== READY FOR MANUSCRIPT ===\n")
cat("========================================\n\n")
cat("Generated files:\n\n")

files <- c(
  "* output/publish/qa_summary.md",
  "* output/publish/qa_trial_exclusions.csv",
  "* output/publish/qa_decision_coding_audit.csv",
  "* output/publish/qa_subject_inclusion.csv",
  "* output/publish/qa_subject_cell_counts.csv",
  "* output/publish/qa_mvc_compliance.csv",
  "* output/publish/checks_accuracy_glmm.csv",
  "* output/publish/checks_rt_lmm.csv",
  "* output/publish/loo_summary_clean.csv",
  "* output/publish/loo_summary.md",
  "* output/publish/ppc_gate_summary.md",
  "* output/publish/ppc_gate_summary.csv",
  "* output/publish/ppc_cells_detail.csv",
  "* output/publish/table_fixed_effects.csv",
  "* output/publish/table_effect_contrasts.csv",
  "* output/publish/ppc_heatmap_wide.csv",
  "* output/publish/ppc_heatmap_long.csv"
)

# Check which files exist
for (f in files) {
  file_path <- gsub("^\\* ", "", f)
  if (file.exists(file_path)) {
    cat(f, " ✓\n")
  } else {
    cat(f, " ✗ (missing)\n")
  }
}

cat("\n========================================\n")
cat("Extraction complete!\n")
cat("========================================\n")


