# R/run_bias_models_step_by_step.R

# Alternative: Run steps individually with checkpoints
# Useful if you want to run some steps manually or resume after a failure

# Setup: ensure we're in the project root
if (basename(getwd()) == "R") {
  setwd("..")
}

# Checkpoint file to track progress
checkpoint_file <- "output/logs/bias_models_checkpoint.RData"

# Function to save checkpoint
save_checkpoint <- function(step, script_name) {
  checkpoint <- list(
    last_step = step,
    last_script = script_name,
    timestamp = Sys.time()
  )
  dir.create(dirname(checkpoint_file), recursive = TRUE, showWarnings = FALSE)
  save(checkpoint, file = checkpoint_file)
  cat("Checkpoint saved: Step", step, "-", script_name, "\n")
}

# Function to load checkpoint
load_checkpoint <- function() {
  if (file.exists(checkpoint_file)) {
    load(checkpoint_file)
    return(checkpoint)
  }
  return(NULL)
}

# Scripts to run
scripts <- list(
  list(
    path = "R/00_build_decision_upper_diff.R",
    name = "PROMPT 1: Build response-side decision boundary",
    required = TRUE
  ),
  list(
    path = "R/fit_standard_bias_only.R",
    name = "PROMPT 2: Standard-only bias calibration (v≈0)",
    required = TRUE,
    checkpoint = "output/publish/fit_standard_bias_only.rds"
  ),
  list(
    path = "R/fit_joint_vza_standard_constrained.R",
    name = "PROMPT 3: Joint model with Standard drift constrained",
    required = TRUE,
    checkpoint = "output/publish/fit_joint_vza_stdconstrained.rds"
  ),
  list(
    path = "R/summarize_bias_and_compare.R",
    name = "PROMPT 4: Summarize and compare both models",
    required = FALSE,
    depends_on = c(2, 3)
  ),
  list(
    path = "R/ppc_joint_minimal.R",
    name = "PROMPT 5: Minimal PPC for joint model",
    required = FALSE,
    depends_on = 3
  )
)

# Check which steps to run
checkpoint <- load_checkpoint()
start_from <- 1

if (!is.null(checkpoint)) {
  cat("Found checkpoint from:", format(checkpoint$timestamp, "%Y-%m-%d %H:%M:%S"), "\n")
  cat("Last completed step:", checkpoint$last_step, "-", checkpoint$last_script, "\n")
  response <- readline("Resume from checkpoint? (y/n): ")
  if (tolower(response) == "y") {
    start_from <- checkpoint$last_step + 1
    cat("Resuming from step", start_from, "\n")
  } else {
    cat("Starting from beginning\n")
  }
}

# Run scripts
for (i in start_from:length(scripts)) {
  script <- scripts[[i]]
  
  cat("\n")
  cat("=", strrep("=", 70), "\n")
  cat("STEP", i, "/", length(scripts), ":", script$name, "\n")
  cat("=", strrep("=", 70), "\n")
  
  # Check dependencies
  if (!is.null(script$depends_on)) {
    deps_met <- TRUE
    for (dep in script$depends_on) {
      if (dep < i) {
        dep_script <- scripts[[dep]]
        if (!is.null(dep_script$checkpoint)) {
          if (!file.exists(dep_script$checkpoint)) {
            cat("WARNING: Dependency not met. Step", dep, "output not found:", dep_script$checkpoint, "\n")
            deps_met <- FALSE
          }
        }
      }
    }
    if (!deps_met) {
      cat("Skipping step", i, "due to unmet dependencies\n")
      next
    }
  }
  
  # Check if checkpoint exists (skip if already done)
  if (!is.null(script$checkpoint) && file.exists(script$checkpoint)) {
    cat("Checkpoint exists:", script$checkpoint, "\n")
    response <- readline("Skip this step? (y/n): ")
    if (tolower(response) == "y") {
      cat("Skipping step", i, "\n")
      save_checkpoint(i, script$name)
      next
    }
  }
  
  # Run script
  start_time <- Sys.time()
  tryCatch({
    source(script$path, local = TRUE)
    elapsed <- difftime(Sys.time(), start_time, units = "mins")
    cat("\n✓ Completed in", round(elapsed, 2), "minutes\n")
    save_checkpoint(i, script$name)
  }, error = function(e) {
    elapsed <- difftime(Sys.time(), start_time, units = "mins")
    cat("\n✗ FAILED after", round(elapsed, 2), "minutes\n")
    cat("Error:", conditionMessage(e), "\n")
    if (script$required) {
      cat("This step is REQUIRED. Stopping.\n")
      stop("Required step failed")
    } else {
      cat("This step is optional. Continuing...\n")
    }
  })
  
  # Brief pause
  if (i < length(scripts)) {
    cat("Waiting 5 seconds before next step...\n")
    Sys.sleep(5)
  }
}

cat("\n")
cat("=", strrep("=", 70), "\n")
cat("ALL STEPS COMPLETE\n")
cat("=", strrep("=", 70), "\n")

