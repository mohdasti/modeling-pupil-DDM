#!/usr/bin/env Rscript
# =========================================================================
# VM CAPABILITY CHECK FOR GCP / RSTUDIO CLOUD
# =========================================================================
# Run this on your GCP VM to see computational resources.
# Use the output to tune N_CHAINS, cores, and threads in ddm_refit_gcp.R
# =========================================================================

cat("================================================================================\n")
cat("VM CAPABILITY REPORT\n")
cat("================================================================================\n")
cat("Timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# CPU
n_cores <- parallel::detectCores()
cat("CPU CORES (detectCores):", n_cores, "\n")

# Logical vs physical (on Linux, often 2x logical)
# Sys.getenv("NCPU") or /proc/cpuinfo can help on Linux
if (Sys.info()["sysname"] == "Linux") {
  nproc <- tryCatch(
    as.integer(system("nproc 2>/dev/null", intern = TRUE)),
    error = function(e) NA
  )
  if (!is.na(nproc)) cat("CPU (nproc):", nproc, "\n")
}

# Memory (approximate)
mem_info <- tryCatch({
  if (Sys.info()["sysname"] == "Linux") {
    x <- system("free -m 2>/dev/null | head -2", intern = TRUE)
    if (length(x) > 0) paste(x, collapse = "\n") else "run: free -m"
  } else if (Sys.info()["sysname"] == "Darwin") {
    x <- system("vm_stat 2>/dev/null", intern = TRUE)
    if (length(x) > 0) paste(x, collapse = "\n") else "run: vm_stat"
  } else {
    "Memory info not available"
  }
}, error = function(e) "Memory info not available")
cat("\nMEMORY:\n")
cat(mem_info, "\n\n")

# R memory limit (if set)
r_mem_limit <- tryCatch({
  if (requireNamespace("pryr", quietly = TRUE)) {
    paste(format(pryr::mem_limit(), scientific = FALSE), "bytes")
  } else {
    "(install 'pryr' for mem_limit)"
  }
}, error = function(e) "unknown")
cat("R memory limit:", r_mem_limit, "\n")

# Disk
cat("\nDISK:\n")
if (Sys.info()["sysname"] == "Linux") {
  df_out <- tryCatch(system("df -h . 2>/dev/null", intern = TRUE), error = function(e) NULL)
  if (!is.null(df_out)) cat(paste(df_out, collapse = "\n"), "\n")
}

# R version and key packages
cat("\nR & PACKAGES:\n")
cat("R version:", R.version.string, "\n")
cat("brms:", tryCatch(as.character(packageVersion("brms")), error = function(e) "not installed"), "\n")
cat("cmdstanr:", tryCatch(as.character(packageVersion("cmdstanr")), error = function(e) "not installed"), "\n")
cmdstan_path <- tryCatch(cmdstanr::cmdstan_path(), error = function(e) "not found")
cat("CmdStan path:", cmdstan_path, "\n")

# Recommended settings for DDM refit
cat("\n================================================================================\n")
cat("RECOMMENDED DDM REFIT SETTINGS FOR THIS VM\n")
cat("================================================================================\n")
n_chains_rec <- min(4, max(2, n_cores - 2))  # Leave 2 cores for system
n_threads_rec <- max(1, floor((n_cores - n_chains_rec) / n_chains_rec))
cat("N_CHAINS:", n_chains_rec, "(use min(4, cores-2) to leave headroom)\n")
cat("cores (parallel chains):", n_chains_rec, "\n")
cat("threads per chain:", n_chains_rec, "×", n_threads_rec, "=", n_chains_rec * n_threads_rec, "total threads\n")
cat("\nTo apply: set env vars before running ddm_refit_gcp.R:\n")
cat("  export DDM_N_CHAINS=", n_chains_rec, "\n", sep = "")
cat("  export DDM_THREADS_PER_CHAIN=", n_threads_rec, "\n", sep = "")
cat("================================================================================\n")
