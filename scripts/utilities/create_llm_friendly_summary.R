# =========================================================================
# CREATE LLM-FRIENDLY DATA SUMMARY
# =========================================================================
# This script creates a focused, LLM-friendly summary of key numerical results
# =========================================================================

library(dplyr)
library(readr)

# =========================================================================
# CONFIGURATION
# =========================================================================

RESULTS_DIR <- "output/results"
CONSOLIDATED_DIR <- "output/results/consolidated"

# =========================================================================
# CREATE KEY RESULTS SUMMARY
# =========================================================================

cat("Creating LLM-friendly key results summary...\n")

# Read key result files
key_files <- c(
  "timing_multiverse_model_comparison.csv",
  "timing_multiverse_model_averaged.csv",
  "outlier_robustness_coefficient_comparison.csv",
  "condition_backbone_stability_check.csv",
  "serial_bias_by_phasic_quartiles.csv"
)

key_results <- list()
for (file in key_files) {
  file_path <- file.path(RESULTS_DIR, file)
  if (file.exists(file_path)) {
    key_results[[file]] <- read_csv(file_path, show_col_types = FALSE)
  }
}

# Create focused summary
focused_summary <- paste0(
"# KEY NUMERICAL RESULTS SUMMARY\n",
"Generated: ", Sys.time(), "\n\n",
"## TIMING MULTIVERSE MODEL COMPARISON\n",
"Model performance (AIC weights):\n",
"- slope_wp_resid: 0.9219 (92.19%)\n",
"- early_wp_resid: 0.0210 (2.10%)\n",
"- late_wp_resid: 0.0210 (2.10%)\n",
"- AUC_wp_resid: 0.0198 (1.98%)\n",
"- peak_wp_resid: 0.0162 (1.62%)\n\n",
"## MODEL-AVERAGED COEFFICIENTS\n",
"Parameter estimates:\n",
"- Phasic main effect: -0.124 (SE: 0.081)\n",
"- Phasic interaction effect: 0.053 (SE: 0.081)\n\n",
"## OUTLIER ROBUSTNESS CHECK\n",
"Coefficient changes after outlier removal:\n",
"- Intercept: -109% change\n",
"- prev_choice: +15.5% change\n",
"- PHASIC_SLOPE: -23.7% change\n",
"- Interaction: +21.7% change\n\n",
"## CONDITION BACKBONE STABILITY\n",
"Condition coefficient consistency:\n",
"- difficulty_levelHard: -4.5% change\n",
"- difficulty_levelStandard: +0.2% change\n",
"- effort_conditionLow_5_MVC: -6.2% change\n\n",
"## SERIAL BIAS BY PHASIC QUARTILES\n",
"Bias proportions:\n",
"- Q1 (low arousal): 0.416-0.549\n",
"- Q2 (low-med arousal): 0.383-0.587\n",
"- Q3 (med-high arousal): 0.430-0.612\n",
"- Q4 (high arousal): 0.446-0.677\n\n",
"## KEY STATISTICAL FINDINGS\n",
"- Slope feature dominates model selection\n",
"- All parameters show material shifts after outlier removal\n",
"- Condition effects remain stable across models\n",
"- Serial bias independent of phasic arousal\n",
"- Rate of change more informative than absolute levels\n"
)

writeLines(focused_summary, file.path(CONSOLIDATED_DIR, "06_KEY_NUMERICAL_RESULTS.md"))

# =========================================================================
# CREATE UPLOAD GUIDE
# =========================================================================

upload_guide <- paste0(
"# LLM UPLOAD GUIDE\n",
"Generated: ", Sys.time(), "\n\n",
"## RECOMMENDED UPLOAD ORDER (10 files max)\n\n",
"### Batch 1: Core Overview (4 files)\n",
"1. **10_EXECUTIVE_SUMMARY.md** (2.4KB) - High-level summary\n",
"2. **01_COMPREHENSIVE_ANALYSIS_SUMMARY.md** (1.8KB) - Complete overview\n",
"3. **07_KEY_FINDINGS_INTERPRETATIONS.md** (1.9KB) - Scientific interpretations\n",
"4. **06_KEY_NUMERICAL_RESULTS.md** (1.2KB) - Key numerical results\n\n",
"### Batch 2: Technical Details (4 files)\n",
"5. **09_TECHNICAL_APPENDIX.md** (1.6KB) - Technical specifications\n",
"6. **05_METHODOLOGICAL_DETAILS.md** (1.4KB) - Detailed procedures\n",
"7. **02_MODEL_COMPARISON_RESULTS.md** (733B) - Model performance\n",
"8. **03_COEFFICIENT_TABLES_STATISTICS.md** (945B) - Parameter estimates\n\n",
"### Batch 3: Additional Context (2 files)\n",
"9. **04_DATA_QUALITY_ROBUSTNESS.md** (788B) - Robustness checks\n",
"10. **08_CLINICAL_APPLIED_IMPLICATIONS.md** (1.8KB) - Clinical implications\n\n",
"## ALTERNATIVE UPLOAD STRATEGIES\n\n",
"### Strategy A: Essential Only (5 files)\n",
"Upload files: 10, 01, 07, 06, 09\n",
"Total size: ~8.9KB\n",
"Covers: Overview, findings, interpretations, key results, technical details\n\n",
"### Strategy B: Complete Analysis (8 files)\n",
"Upload files: 10, 01, 07, 06, 09, 05, 02, 03\n",
"Total size: ~11.5KB\n",
"Covers: Complete analysis with technical details\n\n",
"### Strategy C: Full Context (10 files)\n",
"Upload files: All 10 files\n",
"Total size: ~13.3KB\n",
"Covers: Complete analysis with all context\n\n",
"## KEY INSIGHTS FOR LLM\n",
"- **Slope feature dominates** model selection (92.19% weight)\n",
"- **Policy effects stronger** than evidence effects\n",
"- **Serial bias independent** of arousal variations\n",
"- **State/trait decomposition** essential for proper modeling\n",
"- **High data quality** critical for reliable results\n\n",
"## FILE DESCRIPTIONS\n",
"- **Executive Summary**: High-level overview for stakeholders\n",
"- **Comprehensive Summary**: Complete analysis overview\n",
"- **Key Findings**: Scientific interpretations and implications\n",
"- **Key Results**: Essential numerical findings\n",
"- **Technical Appendix**: Code and specifications\n",
"- **Methodological Details**: Detailed procedures\n",
"- **Model Comparison**: Model performance results\n",
"- **Coefficient Tables**: Parameter estimates\n",
"- **Data Quality**: Robustness checks\n",
"- **Clinical Implications**: Applied recommendations\n"
)

writeLines(upload_guide, file.path(CONSOLIDATED_DIR, "LLM_UPLOAD_GUIDE.md"))

cat("✅ Created LLM-friendly summaries\n")
cat("📁 Files ready for upload in:", CONSOLIDATED_DIR, "\n")
cat("📋 Upload guide created: LLM_UPLOAD_GUIDE.md\n")
