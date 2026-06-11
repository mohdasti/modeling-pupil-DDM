#!/usr/bin/env Rscript
# Quick VM specs for GCP / local machines

cat("\n=== VM / Machine Specs ===\n\n")

# CPU
cat("CPU cores (parallel::detectCores()):", parallel::detectCores(), "\n")
cat("CPU cores (logical):", parallel::detectCores(logical = TRUE), "\n\n")

# Memory
if (Sys.info()["sysname"] == "Linux") {
  tryCatch({
    x <- readLines("/proc/meminfo", n = 1)
    # MemTotal:       13229184 kB -> extract number (in kB)
    num_kb <- as.numeric(regmatches(x, regexpr("[0-9]+", x)))
    total_gb <- num_kb / 1e6
    cat("RAM total:", round(total_gb, 1), "GB\n")
  }, error = function(e) cat("RAM: (could not read)\n"))
} else if (Sys.info()["sysname"] == "Darwin") {
  tryCatch({
    x <- system2("sysctl", "-n hw.memsize", stdout = TRUE)
    cat("RAM total:", round(as.numeric(x) / 1e9, 1), "GB\n")
  }, error = function(e) cat("RAM: (could not read)\n"))
} else {
  cat("RAM:", round(memory.limit() / 1024, 1), "MB (Windows)\n")
}

# CmdStan (for brms)
cmdstan_ok <- tryCatch({
  if (requireNamespace("cmdstanr", quietly = TRUE)) cmdstanr::cmdstan_version() else NULL
}, error = function(e) NULL)
cat("CmdStan:", if (is.null(cmdstan_ok)) "not found" else paste("OK, version", cmdstan_ok), "\n\n")

# R version
cat("R version:", R.version.string, "\n")
cat("Platform:", R.version$platform, "\n\n")

cat("=== Done ===\n")
