# R/run_steps_3_and_5_only.R
# Run only Step 3 (Joint model) and Step 5 (PPC) - the two that failed

# Setup: ensure we're in the project root
if (basename(getwd()) == "R") {
  setwd("..")
}

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
log_file <- paste0("output/logs/steps_3_and_5_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log")
dir.create(dirname(log_file), recursive = TRUE, showWarnings = FALSE)

log_msg <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_line <- paste0("[", timestamp, "] [", level, "] ", msg, "\n")
  cat(log_line)
  write(log_line, file = log_file, append = TRUE)
}

run_script_safe <- function(script_path, script_name) {
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
    traceback_msg <- paste(capture.output(traceback()), collapse = "\n")
    log_msg(traceback_msg, "ERROR")
    return(FALSE)
  })
}

# Main execution
log_msg("=", strrep("=", 70))
log_msg("RUNNING STEPS 3 AND 5 ONLY")
log_msg("=", strrep("=", 70))
log_msg(paste0("Start time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
log_msg(paste0("Working directory: ", getwd()))
log_msg(paste0("Log file: ", log_file))

# Check prerequisites
log_msg("")
log_msg("Checking prerequisites...")
if (!file.exists("data/analysis_ready/bap_ddm_ready_with_upper.csv")) {
  log_msg("✗ Missing: data/analysis_ready/bap_ddm_ready_with_upper.csv", "ERROR")
  stop("Step 1 must be completed first")
}
log_msg("✓ Step 1 output exists")

if (!file.exists("output/publish/fit_standard_bias_only.rds")) {
  log_msg("✗ Missing: output/publish/fit_standard_bias_only.rds", "ERROR")
  stop("Step 2 must be completed first")
}
log_msg("✓ Step 2 output exists")

# Run Step 3
log_msg("")
log_msg(">>> STEP 3: Joint Model <<<")
success_3 <- run_script_safe(
  "R/fit_joint_vza_standard_constrained.R",
  "Step 3: Joint model with Standard drift constrained"
)

if (!success_3) {
  log_msg("Step 3 failed. Step 5 requires Step 3, so skipping Step 5.", "WARN")
} else {
  # Run Step 5 (only if Step 3 succeeded)
  log_msg("")
  log_msg("Waiting 10 seconds before Step 5...")
  Sys.sleep(10)
  
  log_msg("")
  log_msg(">>> STEP 5: PPC for Joint Model <<<")
  success_5 <- run_script_safe(
    "R/ppc_joint_minimal.R",
    "Step 5: Minimal PPC for joint model"
  )
}

# Final summary
log_msg("")
log_msg("=", strrep("=", 70))
log_msg("FINAL SUMMARY")
log_msg("=", strrep("=", 70))
log_msg(paste0("Step 3: ", if(success_3) "✓ SUCCESS" else "✗ FAILED"))
if (success_3) {
  log_msg(paste0("Step 5: ", if(exists("success_5") && success_5) "✓ SUCCESS" else "✗ FAILED"))
} else {
  log_msg("Step 5: ○ SKIPPED (Step 3 failed)")
}
log_msg(paste0("End time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
log_msg("=", strrep("=", 70))

cat("\n")
cat("=", strrep("=", 70), "\n")
cat("RUN COMPLETE\n")
cat("=", strrep("=", 70), "\n")
cat("Log file:", log_file, "\n")
cat("\nResults:\n")
cat("  Step 3:", if(success_3) "✓ SUCCESS" else "✗ FAILED", "\n")
if (success_3) {
  cat("  Step 5:", if(exists("success_5") && success_5) "✓ SUCCESS" else "✗ FAILED", "\n")
} else {
  cat("  Step 5: ○ SKIPPED\n")
}
cat("\n")

