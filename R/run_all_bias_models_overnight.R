# R/run_all_bias_models_overnight.R

# Master script to run all 5 bias model prompts overnight
# Run this in RStudio or via: Rscript R/run_all_bias_models_overnight.R

# Setup: ensure we're in the project root
# Try multiple strategies to find project root
find_project_root <- function() {
  current <- getwd()
  
  # Strategy 1: If we're in R/ subdirectory, go up one level
  if (basename(current) == "R") {
    return(normalizePath(".."))
  }
  
  # Strategy 2: Look for project markers (R/ directory, .git, etc.)
  markers <- c("R/00_build_decision_upper_diff.R", ".git", "data/analysis_ready")
  for (marker in markers) {
    if (file.exists(marker)) {
      return(current)
    }
  }
  
  # Strategy 3: Go up directories looking for markers
  max_depth <- 5
  path <- current
  for (i in 1:max_depth) {
    markers_found <- sapply(markers, function(m) file.exists(file.path(path, m)))
    if (any(markers_found)) {
      return(path)
    }
    path <- dirname(path)
    if (path == dirname(path)) break  # Reached filesystem root
  }
  
  # Strategy 4: Try common project location
  project_path <- file.path(Sys.getenv("HOME"), "Documents", "GitHub", "modeling-pupil-DDM", "modeling-pupil-DDM")
  if (file.exists(project_path)) {
    return(project_path)
  }
  
  # If all else fails, return current directory
  return(current)
}

project_root <- find_project_root()
if (getwd() != project_root) {
  cat("Changing working directory to project root:\n")
  cat("  From:", getwd(), "\n")
  cat("  To:  ", project_root, "\n")
  setwd(project_root)
}
cat("Working directory:", getwd(), "\n")

# Create log file
log_file <- paste0("output/logs/bias_models_run_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log")
dir.create(dirname(log_file), recursive = TRUE, showWarnings = FALSE)

# Logging function
log_msg <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_line <- paste0("[", timestamp, "] [", level, "] ", msg, "\n")
  cat(log_line)
  write(log_line, file = log_file, append = TRUE)
}

# Error handler
run_script <- function(script_path, script_name) {
  log_msg(paste0("=", strrep("=", 70)))
  log_msg(paste0("Starting: ", script_name))
  log_msg(paste0("Script: ", script_path))
  log_msg(paste0("=", strrep("=", 70)))
  
  start_time <- Sys.time()
  
  tryCatch({
    source(script_path, local = TRUE)
    elapsed <- difftime(Sys.time(), start_time, units = "mins")
    log_msg(paste0("✓ Completed: ", script_name, " (", round(elapsed, 2), " minutes)"))
    return(TRUE)
  }, error = function(e) {
    elapsed <- difftime(Sys.time(), start_time, units = "mins")
    log_msg(paste0("✗ FAILED: ", script_name, " (", round(elapsed, 2), " minutes)"), "ERROR")
    log_msg(paste0("Error message: ", conditionMessage(e)), "ERROR")
    log_msg(paste0("Error traceback:"), "ERROR")
    traceback_msg <- paste(capture.output(traceback()), collapse = "\n")
    log_msg(traceback_msg, "ERROR")
    return(FALSE)
  })
}

# Main execution
log_msg("=", strrep("=", 70))
log_msg("BIAS MODELS OVERNIGHT RUN")
log_msg("=", strrep("=", 70))
log_msg(paste0("Start time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
log_msg(paste0("Working directory: ", getwd()))
log_msg(paste0("Log file: ", log_file))

# Scripts to run in order
scripts <- list(
  list(
    path = "R/00_build_decision_upper_diff.R",
    name = "PROMPT 1: Build response-side decision boundary"
  ),
  list(
    path = "R/fit_standard_bias_only.R",
    name = "PROMPT 2: Standard-only bias calibration (v≈0)"
  ),
  list(
    path = "R/fit_joint_vza_standard_constrained.R",
    name = "PROMPT 3: Joint model with Standard drift constrained"
  ),
  list(
    path = "R/summarize_bias_and_compare.R",
    name = "PROMPT 4: Summarize and compare both models"
  ),
  list(
    path = "R/ppc_joint_minimal.R",
    name = "PROMPT 5: Minimal PPC for joint model"
  )
)

# Track results
results <- list()
overall_start <- Sys.time()

# Run each script
for (i in seq_along(scripts)) {
  script <- scripts[[i]]
  
  log_msg("")
  log_msg(paste0(">>> STEP ", i, "/", length(scripts), " <<<"))
  
  success <- run_script(script$path, script$name)
  
  results[[i]] <- list(
    step = i,
    name = script$name,
    success = success,
    timestamp = Sys.time()
  )
  
  if (!success) {
    log_msg("")
    log_msg("=", strrep("=", 70))
    log_msg("STOPPING: Previous step failed. Remaining steps will not run.")
    log_msg("=", strrep("=", 70))
    break
  }
  
  # Brief pause between steps
  if (i < length(scripts)) {
    log_msg("Waiting 10 seconds before next step...")
    Sys.sleep(10)
  }
}

# Final summary
overall_elapsed <- difftime(Sys.time(), overall_start, units = "hours")

log_msg("")
log_msg("=", strrep("=", 70))
log_msg("FINAL SUMMARY")
log_msg("=", strrep("=", 70))
log_msg(paste0("Total elapsed time: ", round(overall_elapsed, 2), " hours"))
log_msg("")

for (i in seq_along(results)) {
  res <- results[[i]]
  status <- if (res$success) "✓ SUCCESS" else "✗ FAILED"
  log_msg(paste0("Step ", res$step, ": ", status, " - ", res$name))
}

log_msg("")
log_msg(paste0("End time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
log_msg("=", strrep("=", 70))

# Print summary to console
cat("\n")
cat("=", strrep("=", 70), "\n")
cat("RUN COMPLETE\n")
cat("=", strrep("=", 70), "\n")
cat("Log file:", log_file, "\n")
cat("Total time:", round(overall_elapsed, 2), "hours\n")
cat("\nResults:\n")
for (i in seq_along(results)) {
  res <- results[[i]]
  status <- if (res$success) "✓" else "✗"
  cat(sprintf("  %s Step %d: %s\n", status, res$step, res$name))
}
cat("\n")

