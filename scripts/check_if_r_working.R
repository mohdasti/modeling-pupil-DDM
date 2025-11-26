# Quick check: Is the PPC script actually running?
# Run this in a NEW R console window

cat("\n")
cat("================================================================================\n")
cat("CHECKING IF PPC SCRIPT IS ACTUALLY WORKING\n")
cat("================================================================================\n\n")

# Check if output directory has any files
ppc_dir <- "output/ppc"
if (dir.exists(ppc_dir)) {
  files <- list.files(ppc_dir, full.names = TRUE)
  if (length(files) > 0) {
    cat("✓ Output directory exists with", length(files), "files:\n")
    for (f in files) {
      file_info <- file.info(f)
      cat("  -", basename(f), 
          "(size:", format(file_info$size, big.mark = ","), "bytes,",
          "modified:", format(file_info$mtime, "%H:%M:%S"), ")\n")
    }
    cat("\n⚠️  If files were modified recently, script IS working!\n")
  } else {
    cat("⚠️  Output directory exists but is empty\n")
    cat("   This means script hasn't saved anything yet (normal for first model)\n")
  }
} else {
  cat("⚠️  Output directory doesn't exist yet\n")
  cat("   This is normal if script is still on first model\n")
}

cat("\n")
cat("NEXT STEPS:\n")
cat("1. Open Activity Monitor (Mac) → find R/RStudio process\n")
cat("2. Check CPU % - should be >30% if actively computing\n")
cat("3. Check Memory - should be stable/increasing\n")
cat("4. If CPU <10% for extended period → may be stuck\n")
cat("\n")
cat("DECISION:\n")
cat("  - If CPU >30%: WAIT (it's working, just slow)\n")
cat("  - If CPU <10%: CONSIDER aborting and using version with 50 draws\n")
cat("\n")










