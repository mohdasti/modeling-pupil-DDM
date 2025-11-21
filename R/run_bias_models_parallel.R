# R/run_bias_models_parallel.R

# Run independent steps in parallel (Steps 2 and 3 can run simultaneously)
# Steps 1, 4, and 5 must run sequentially

# Setup: ensure we're in the project root
if (basename(getwd()) == "R") {
  setwd("..")
}

suppressPackageStartupMessages({
  library(parallel)
  library(doParallel)
})

# Logging function
log_msg <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat("[", timestamp, "] ", msg, "\n", sep = "")
}

log_msg("=", strrep("=", 70))
log_msg("BIAS MODELS PARALLEL RUN")
log_msg("=", strrep("=", 70))

# Step 1: Build decision boundary (quick, must run first)
log_msg("")
log_msg(">>> STEP 1: Build response-side decision boundary <<<")
start_time <- Sys.time()
tryCatch({
  source("R/00_build_decision_upper_diff.R", local = TRUE)
  elapsed <- difftime(Sys.time(), start_time, units = "mins")
  log_msg(paste0("✓ Step 1 completed in ", round(elapsed, 2), " minutes"))
}, error = function(e) {
  stop("Step 1 failed: ", conditionMessage(e))
})

# Steps 2 and 3: Run in parallel (both are model fits)
log_msg("")
log_msg(">>> STEPS 2 & 3: Running model fits in parallel <<<")
log_msg("This will use 2 CPU cores (one per model)")

# Check available cores
n_cores <- detectCores()
log_msg(paste0("Available cores: ", n_cores))
if (n_cores < 2) {
  log_msg("WARNING: Less than 2 cores available. Parallel execution may be slow.")
}

# Create cluster
cl <- makeCluster(2)
registerDoParallel(cl)

# Run both model fits
log_msg("Starting parallel execution...")
start_time <- Sys.time()

results <- foreach(
  i = 1:2,
  .packages = c("brms", "cmdstanr", "dplyr", "readr", "posterior"),
  .errorhandling = "stop"
) %dopar% {
  if (basename(getwd()) == "R") setwd("..")
  
  if (i == 1) {
    # Step 2: Standard-only bias model
    source("R/fit_standard_bias_only.R", local = TRUE)
    return(list(step = 2, name = "Standard-only bias model", success = TRUE))
  } else {
    # Step 3: Joint model
    source("R/fit_joint_vza_standard_constrained.R", local = TRUE)
    return(list(step = 3, name = "Joint model", success = TRUE))
  }
}

stopCluster(cl)

elapsed <- difftime(Sys.time(), start_time, units = "hours")
log_msg(paste0("✓ Steps 2 & 3 completed in ", round(elapsed, 2), " hours"))

# Step 4: Summarize (depends on steps 2 and 3)
log_msg("")
log_msg(">>> STEP 4: Summarize and compare both models <<<")
start_time <- Sys.time()
tryCatch({
  source("R/summarize_bias_and_compare.R", local = TRUE)
  elapsed <- difftime(Sys.time(), start_time, units = "mins")
  log_msg(paste0("✓ Step 4 completed in ", round(elapsed, 2), " minutes"))
}, error = function(e) {
  warning("Step 4 failed: ", conditionMessage(e))
})

# Step 5: PPC (depends on step 3)
log_msg("")
log_msg(">>> STEP 5: Minimal PPC for joint model <<<")
start_time <- Sys.time()
tryCatch({
  source("R/ppc_joint_minimal.R", local = TRUE)
  elapsed <- difftime(Sys.time(), start_time, units = "mins")
  log_msg(paste0("✓ Step 5 completed in ", round(elapsed, 2), " minutes"))
}, error = function(e) {
  warning("Step 5 failed: ", conditionMessage(e))
})

log_msg("")
log_msg("=", strrep("=", 70))
log_msg("ALL STEPS COMPLETE")
log_msg("=", strrep("=", 70))

