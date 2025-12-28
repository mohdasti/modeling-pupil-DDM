# R/resume_bias_models.R

# Smart resume script: checks what's already done and only runs missing steps
# Can be run multiple times safely - will skip completed steps

# Setup: ensure we're in the project root
if (basename(getwd()) == "R") {
  setwd("..")
}

# Find project root
find_project_root <- function() {
  current <- getwd()
  if (basename(current) == "R") {
    return(normalizePath(".."))
  }
  markers <- c("R/00_build_decision_upper_diff.R", ".git", "data/analysis_ready")
  for (marker in markers) {
    if (file.exists(marker)) {
      return(normalizePath(current))
    }
  }
  project_path <- file.path(Sys.getenv("HOME"), "Documents", "GitHub", "modeling-pupil-DDM", "modeling-pupil-DDM")
  if (dir.exists(project_path)) {
    return(normalizePath(project_path))
  }
  return(normalizePath(current))
}

project_root <- find_project_root()
if (getwd() != project_root) {
  cat("Changing to project root:", project_root, "\n")
  setwd(project_root)
}

# Create log file
log_file <- paste0("output/logs/bias_models_resume_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log")
dir.create(dirname(log_file), recursive = TRUE, showWarnings = FALSE)

# Logging function
log_msg <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_line <- paste0("[", timestamp, "] [", level, "] ", msg, "\n")
  cat(log_line)
  write(log_line, file = log_file, append = TRUE)
}

# Check if step is already completed
is_completed <- function(step_info) {
  if (!is.null(step_info$checkpoint)) {
    return(file.exists(step_info$checkpoint))
  }
  return(FALSE)
}

# Run script with error handling
run_script_safe <- function(script_path, script_name, required = TRUE) {
  log_msg(paste0("=", strrep("=", 70)))
  log_msg(paste0("Running: ", script_name))
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
    log_msg(paste0("Error: ", conditionMessage(e)), "ERROR")
    if (required) {
      log_msg("This step is REQUIRED. Stopping.", "ERROR")
      return(FALSE)
    } else {
      log_msg("This step is optional. Continuing...", "WARN")
      return(FALSE)
    }
  })
}

# Define steps with checkpoints
steps <- list(
  list(
    path = "R/00_build_decision_upper_diff.R",
    name = "Step 1: Build response-side decision boundary",
    checkpoint = "data/analysis_ready/bap_ddm_ready_with_upper.csv",
    required = TRUE
  ),
  list(
    path = "R/fit_standard_bias_only.R",
    name = "Step 2: Standard-only bias calibration (v≈0)",
    checkpoint = "output/publish/fit_standard_bias_only.rds",
    required = TRUE
  ),
  list(
    path = "R/fit_joint_vza_standard_constrained.R",
    name = "Step 3: Joint model with Standard drift constrained",
    checkpoint = "output/publish/fit_joint_vza_stdconstrained.rds",
    required = FALSE  # Optional - Standard-only model is sufficient
  ),
  list(
    path = "R/summarize_bias_and_compare.R",
    name = "Step 4: Summarize and compare both models",
    checkpoint = NULL,  # No single checkpoint - check for output files
    required = FALSE,
    depends_on = c(2)  # Only needs Step 2
  ),
  list(
    path = "R/ppc_joint_minimal.R",
    name = "Step 5: Minimal PPC for joint model",
    checkpoint = "output/publish/ppc_joint_minimal.csv",
    required = FALSE,
    depends_on = 3  # Needs Step 3
  )
)

# Check dependencies
check_dependencies <- function(step_info) {
  if (is.null(step_info$depends_on)) {
    return(TRUE)
  }
  for (dep_idx in step_info$depends_on) {
    dep_step <- steps[[dep_idx]]
    if (!is_completed(dep_step)) {
      log_msg(paste0("Dependency not met: Step ", dep_idx, " (", dep_step$name, ")"), "WARN")
      return(FALSE)
    }
  }
  return(TRUE)
}

# Main execution
log_msg("=", strrep("=", 70))
log_msg("BIAS MODELS RESUME SCRIPT")
log_msg("=", strrep("=", 70))
log_msg(paste0("Start time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
log_msg(paste0("Working directory: ", getwd()))
log_msg(paste0("Log file: ", log_file))

# Check what's already done
log_msg("")
log_msg("Checking completed steps...")
completed_steps <- c()
for (i in seq_along(steps)) {
  step <- steps[[i]]
  if (is_completed(step)) {
    completed_steps <- c(completed_steps, i)
    log_msg(paste0("✓ Step ", i, " already completed: ", step$name))
  } else {
    log_msg(paste0("○ Step ", i, " not completed: ", step$name))
  }
}

log_msg("")
log_msg(paste0("Completed: ", length(completed_steps), "/", length(steps), " steps"))
log_msg("")

# Run missing steps
overall_start <- Sys.time()
results <- list()

for (i in seq_along(steps)) {
  step <- steps[[i]]
  
  # Skip if already completed
  if (i %in% completed_steps) {
    log_msg(paste0("Skipping Step ", i, " (already completed)"))
    results[[i]] <- list(
      step = i,
      name = step$name,
      success = TRUE,
      skipped = TRUE,
      timestamp = Sys.time()
    )
    next
  }
  
  # Check dependencies
  if (!check_dependencies(step)) {
    log_msg(paste0("Skipping Step ", i, " (dependencies not met)"))
    results[[i]] <- list(
      step = i,
      name = step$name,
      success = FALSE,
      skipped = TRUE,
      reason = "Dependencies not met",
      timestamp = Sys.time()
    )
    next
  }
  
  # Run step
  log_msg("")
  log_msg(paste0(">>> STEP ", i, "/", length(steps), " <<<"))
  
  success <- run_script_safe(step$path, step$name, step$required)
  
  results[[i]] <- list(
    step = i,
    name = step$name,
    success = success,
    skipped = FALSE,
    timestamp = Sys.time()
  )
  
  if (!success && step$required) {
    log_msg("")
    log_msg("=", strrep("=", 70))
    log_msg("STOPPING: Required step failed.")
    log_msg("=", strrep("=", 70))
    break
  }
  
  # Brief pause between steps
  if (i < length(steps)) {
    log_msg("Waiting 5 seconds before next step...")
    Sys.sleep(5)
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
  if (is.null(res)) next
  
  if (!is.null(res$skipped) && res$skipped) {
    status <- if (res$success) "○ SKIPPED (already done)" else paste0("○ SKIPPED (", res$reason, ")")
  } else {
    status <- if (res$success) "✓ SUCCESS" else "✗ FAILED"
  }
  log_msg(paste0("Step ", res$step, ": ", status, " - ", res$name))
}

log_msg("")
log_msg(paste0("End time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
log_msg("=", strrep("=", 70))

# Print summary to console
cat("\n")
cat("=", strrep("=", 70), "\n")
cat("RESUME COMPLETE\n")
cat("=", strrep("=", 70), "\n")
cat("Log file:", log_file, "\n")
cat("Total time:", round(overall_elapsed, 2), "hours\n")
cat("\nResults:\n")
for (i in seq_along(results)) {
  res <- results[[i]]
  if (is.null(res)) next
  if (!is.null(res$skipped) && res$skipped) {
    status <- "○"
  } else {
    status <- if (res$success) "✓" else "✗"
  }
  cat(sprintf("  %s Step %d: %s\n", status, res$step, res$name))
}
cat("\n")

