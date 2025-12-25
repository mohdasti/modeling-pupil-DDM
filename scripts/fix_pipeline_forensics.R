#!/usr/bin/env Rscript

# ============================================================================
# FIX PIPELINE: Add ses to MATLAB output, fix R merger, fix QMD
# ============================================================================

cat("=== FIXING PIPELINE FORENSICS ===\n\n")

cat("FINDINGS:\n")
cat("1. MATLAB outputs run but NOT ses (flat files have no ses column)\n")
cat("2. R merger tries to get ses from behavioral but behavioral has session_num, not ses\n")
cat("3. Merged files end up with ses=NA\n")
cat("4. QMD needs to add ses but doesn't have source - may infer incorrectly\n")
cat("5. Run gets overwritten somewhere (run=ses bug)\n\n")

cat("SOLUTION:\n")
cat("1. MATLAB: Add ses column to flat files (extract from filename)\n")
cat("2. R merger: Map session_num -> ses in behavioral data\n")
cat("3. QMD: Preserve ses from merged files, add assertions\n\n")

cat("Creating fix patches...\n")

# Create markdown report with findings
findings <- tibble(
  finding = c(
    "NO ses==1 contamination",
    "MATLAB doesn't output ses",
    "R merger doesn't map session_num->ses",
    "Merged files have ses=NA",
    "QMD may infer ses incorrectly",
    "Run gets overwritten (run=ses bug)"
  ),
  evidence = c(
    "BAP_cleaned has only ses 2-3",
    "Flat files have no ses column",
    "Behavioral has session_num, merger looks for ses",
    "All merged files have ses=NA",
    "QMD needs ses but source is unclear",
    "TRIALLEVEL has run values 2-3 (matching ses)"
  ),
  fix_location = c(
    "N/A - no contamination",
    "MATLAB line 543: add ses column",
    "R merger line 80-102: map session_num->ses",
    "R merger line 267: fix ses assignment",
    "QMD line 6157-6160: preserve ses from merged",
    "QMD line 6160 or 825: check run preservation"
  ),
  priority = c(
    "N/A",
    "HIGH",
    "HIGH",
    "HIGH",
    "CRITICAL",
    "CRITICAL"
  )
)

write_csv(findings, "data/qc/pipeline_forensics/findings_and_fixes.csv")
cat("✓ Saved findings\n\n")

cat("Next: Implement fixes in MATLAB, R, and QMD\n")

