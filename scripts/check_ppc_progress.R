# =========================================================================
# QUICK CHECK: Is PPC Script Actually Working?
# =========================================================================
# Run this in a NEW R session while the main script is running
# =========================================================================

cat("\n")
cat("================================================================================\n")
cat("CHECKING IF PPC SCRIPT IS PROGRESSING\n")
cat("================================================================================\n\n")

# Check if output directory exists and has any files
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
  } else {
    cat("⚠️  Output directory exists but is empty (script hasn't saved anything yet)\n")
  }
} else {
  cat("⚠️  Output directory doesn't exist yet (script may still be in early stages)\n")
}

cat("\n")

# Check system resources
cat("System Resource Check:\n")
cat("  CPU usage: Run 'top' or Activity Monitor to check\n")
cat("  Memory: Check if R is using significant RAM\n")
cat("  Disk: Check if output files are being written\n\n")

cat("================================================================================\n")
cat("RECOMMENDATIONS:\n")
cat("================================================================================\n\n")

cat("1. CHECK R PROCESS:\n")
cat("   - Open Activity Monitor (Mac) or Task Manager\n")
cat("   - Find R/RStudio process\n")
cat("   - Check CPU %: Should be >50% if actively computing\n")
cat("   - Check Memory: Should be stable/increasing\n\n")

cat("2. CHECK CONSOLE OUTPUT:\n")
cat("   - Look for any error messages\n")
cat("   - Check if cursor is blinking (active)\n")
cat("   - Try pressing Enter to see if R responds\n\n")

cat("3. TIME DECISION:\n")
cat("   - If CPU >50% and memory stable: WAIT (it's working)\n")
cat("   - If CPU <10% and no disk activity: MAY BE STUCK\n")
cat("   - If 90+ minutes with no output files: CONSIDER ABORTING\n\n")

cat("4. SAFE ABORT:\n")
cat("   - Press Ctrl+C in RStudio\n")
cat("   - Restart with optimized version (100 draws)\n\n")

cat("================================================================================\n\n")








