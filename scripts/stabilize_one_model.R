# =========================================================================
# STABILIZE ONE MODEL (SAFE, INCREMENTAL)
# =========================================================================
# Run this to stabilize ONE model at a time
# Usage: source("scripts/stabilize_one_model.R")
#   - Then follow prompts to select which model
# =========================================================================

library(brms)
library(dplyr)
library(readr)
library(posterior)

# =========================================================================
# CONFIGURATION
# =========================================================================

MODELS_TO_STABILIZE <- list(
  "Model1_Baseline" = list(
    formula = bf(
      rt | dec(decision) ~ 1 + (1|subject_id),
      bs ~ 1 + (1|subject_id),
      ndt ~ 1,
      bias ~ 1 + (1|subject_id)
    ),
    priors = c(
      prior(normal(0, 1), class = "Intercept"),
      prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
      prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
      prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
      prior(student_t(3, 0, 0.5), class = "sd")
    )
  ),
  "Model2_Force" = list(
    formula = bf(
      rt | dec(decision) ~ effort_condition + (1|subject_id),
      bs ~ 1 + (1|subject_id),
      ndt ~ 1,
      bias ~ 1 + (1|subject_id)
    ),
    priors = c(
      prior(normal(0, 1), class = "Intercept"),
      prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
      prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
      prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
      prior(student_t(3, 0, 0.5), class = "sd"),
      prior(normal(0, 0.5), class = "b")
    )
  ),
  "Model7_Task" = list(
    formula = bf(
      rt | dec(decision) ~ task + (1|subject_id),
      bs ~ 1 + (1|subject_id),
      ndt ~ 1,
      bias ~ 1 + (1|subject_id)
    ),
    priors = c(
      prior(normal(0, 1), class = "Intercept"),
      prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
      prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
      prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
      prior(student_t(3, 0, 0.5), class = "sd"),
      prior(normal(0, 0.5), class = "b")
    )
  ),
  "Model8_Task_Additive" = list(
    formula = bf(
      rt | dec(decision) ~ effort_condition + difficulty_level + task + (1|subject_id),
      bs ~ 1 + (1|subject_id),
      ndt ~ 1,
      bias ~ 1 + (1|subject_id)
    ),
    priors = c(
      prior(normal(0, 1), class = "Intercept"),
      prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
      prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
      prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
      prior(student_t(3, 0, 0.5), class = "sd"),
      prior(normal(0, 0.5), class = "b")
    )
  )
)

# =========================================================================
# HELPER FUNCTIONS
# =========================================================================

stabilized_init <- function() {
  list(
    Intercept = rnorm(1, 0, 0.5),
    Intercept_bs = log(1.3),
    Intercept_ndt = log(0.18),
    Intercept_bias = 0,
    sd_subject_id__Intercept = runif(1, 0.1, 0.3),
    sd_subject_id__bs_Intercept = runif(1, 0.05, 0.15),
    sd_subject_id__bias_Intercept = runif(1, 0.05, 0.15)
  )
}

load_existing_diagnostics <- function() {
  csv_file <- "output/diagnostics/convergence_report.csv"
  if (file.exists(csv_file)) {
    return(read.csv(csv_file, stringsAsFactors = FALSE))
  }
  return(data.frame(
    model = character(),
    max_rhat = numeric(),
    min_ess_ratio = numeric(),
    min_ess_bulk = numeric(),
    min_ess_tail = numeric(),
    converged = logical(),
    fit_time_minutes = numeric(),
    completed_at = character(),
    stringsAsFactors = FALSE
  ))
}

save_diagnostics <- function(diagnostic_df) {
  csv_file <- "output/diagnostics/convergence_report.csv"
  write.csv(diagnostic_df, file = csv_file, row.names = FALSE)
  cat("✓ Diagnostics saved to:", csv_file, "\n")
}

append_to_log <- function(log_file, message) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste0("[", timestamp, "] ", message, "\n")
  write(log_entry, file = log_file, append = TRUE)
  cat(log_entry)
}

# =========================================================================
# SETUP
# =========================================================================

cat("\n")
cat("================================================================================\n")
cat("STABILIZE ONE MODEL (SAFE MODE)\n")
cat("================================================================================\n\n")

# Set working directory
if (!file.exists("output/models")) {
  if (file.exists("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")) {
    setwd("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")
  }
}

# Create output directories
dir.create("output/diagnostics", recursive = TRUE, showWarnings = FALSE)
dir.create("output/logs", recursive = TRUE, showWarnings = FALSE)

# Create log file
log_file <- paste0("output/logs/stabilize_models_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log")
cat("Log file:", log_file, "\n\n")

append_to_log(log_file, "=== STABILIZATION SESSION STARTED ===")

# Load data
cat("Loading data...\n")
data_file <- "data/analysis_ready/bap_ddm_ready.csv"
if (!file.exists(data_file)) {
  stop("Data file not found: ", data_file)
}

data <- read_csv(data_file, show_col_types = FALSE)

# Harmonize columns
if (!"rt" %in% names(data) && "resp1RT" %in% names(data)) {
  data$rt <- data$resp1RT
}
data$rt <- suppressWarnings(as.numeric(data$rt))
if (!"accuracy" %in% names(data) && "iscorr" %in% names(data)) {
  data$accuracy <- data$iscorr
}
if (!"subject_id" %in% names(data) && "sub" %in% names(data)) {
  data$subject_id <- as.character(data$sub)
}
if (!"task" %in% names(data) && "task_behav" %in% names(data)) {
  data$task <- data$task_behav
}

ddm_data <- data %>%
  filter(rt >= 0.25 & rt <= 3.0) %>%
  mutate(
    response = as.integer(accuracy),
    effort_condition = as.factor(effort_condition),
    difficulty_level = as.factor(difficulty_level),
    subject_id = as.factor(subject_id),
    task = as.factor(task),
    decision = ifelse(accuracy == 1, 1, 0)
  )

cat("✓ Data loaded:", nrow(ddm_data), "trials\n\n")
append_to_log(log_file, paste0("Data loaded: ", nrow(ddm_data), " trials"))

# Load existing diagnostics
existing_diag <- load_existing_diagnostics()
completed_models <- existing_diag$model[!is.na(existing_diag$fit_time_minutes)]

# Show status
cat("================================================================================\n")
cat("MODEL STATUS\n")
cat("================================================================================\n")
for (model_name in names(MODELS_TO_STABILIZE)) {
  status <- if (model_name %in% completed_models) {
    converged <- existing_diag$converged[existing_diag$model == model_name]
    paste0("✓ COMPLETED (converged: ", ifelse(converged, "YES", "NO"), ")")
  } else {
    "⏳ PENDING"
  }
  cat(sprintf("  %-25s %s\n", model_name, status))
}
cat("================================================================================\n\n")

# Select model to fit
# Allow passing model number as global variable or argument
MODEL_NUM <- if (exists("STABILIZE_MODEL_NUM")) STABILIZE_MODEL_NUM else NULL

if (is.null(MODEL_NUM)) {
  cat("Which model would you like to stabilize?\n")
  cat("Options:\n")
  for (i in seq_along(MODELS_TO_STABILIZE)) {
    model_name <- names(MODELS_TO_STABILIZE)[i]
    status <- if (model_name %in% completed_models) "[COMPLETED]" else "[PENDING]"
    cat(sprintf("  %d. %s %s\n", i, model_name, status))
  }
  cat("\n")
  cat("METHOD 1: Enter model number when prompted\n")
  cat("METHOD 2: Set STABILIZE_MODEL_NUM <- 1 (or 2,3,4) before sourcing\n")
  cat("METHOD 3: Auto-select first pending model\n")
  cat("\n")
  
  # Try to read user input
  if (interactive()) {
    cat("Enter model number (1-4), or press Enter for first pending: ")
    user_input <- readline()
    if (user_input == "" || trimws(user_input) == "") {
      # Auto-select first pending
      pending_models <- names(MODELS_TO_STABILIZE)[!names(MODELS_TO_STABILIZE) %in% completed_models]
      if (length(pending_models) == 0) {
        cat("✓ All models already completed!\n")
        q()
      }
      selected_num <- which(names(MODELS_TO_STABILIZE) == pending_models[1])
      cat(sprintf("Auto-selected first pending: %s (model %d)\n\n", pending_models[1], selected_num))
    } else {
      selected_num <- as.integer(user_input)
      if (is.na(selected_num) || selected_num == 0) {
        cat("Exiting.\n")
        q()
      }
      if (selected_num < 1 || selected_num > length(MODELS_TO_STABILIZE)) {
        stop("Invalid selection. Must be 1-4.")
      }
    }
  } else {
    # Non-interactive: auto-select first pending
    pending_models <- names(MODELS_TO_STABILIZE)[!names(MODELS_TO_STABILIZE) %in% completed_models]
    if (length(pending_models) == 0) {
      cat("✓ All models already completed!\n")
      q()
    }
    selected_num <- which(names(MODELS_TO_STABILIZE) == pending_models[1])
    cat(sprintf("Non-interactive mode: Auto-selected first pending: %s (model %d)\n\n", pending_models[1], selected_num))
  }
} else {
  selected_num <- MODEL_NUM
  if (selected_num < 1 || selected_num > length(MODELS_TO_STABILIZE)) {
    stop("Invalid MODEL_NUM. Must be 1-4.")
  }
  cat(sprintf("Using MODEL_NUM=%d: %s\n\n", selected_num, names(MODELS_TO_STABILIZE)[selected_num]))
}

models_to_run <- names(MODELS_TO_STABILIZE)[selected_num]

# =========================================================================
# STABILIZATION FUNCTION
# =========================================================================

stabilize_single_model <- function(model_name, spec, data, log_file) {
  cat("\n")
  cat("================================================================================\n")
  cat("STABILIZING:", model_name, "\n")
  cat("================================================================================\n")
  cat("Started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
  
  append_to_log(log_file, paste0("=== STARTING: ", model_name, " ==="))
  
  # Clean memory
  gc(verbose = FALSE)
  
  # Validate priors
  cat("Validating priors...\n")
  tryCatch({
    validation_result <- validate_prior(spec$formula, data = data, prior = spec$priors)
    if (is.null(validation_result) || length(validation_result) == 0) {
      cat("✓ Priors validated\n")
      append_to_log(log_file, paste0(model_name, ": Priors validated"))
    } else {
      cat("⚠️  Prior validation warnings (continuing anyway)\n")
      append_to_log(log_file, paste0(model_name, ": Prior validation warnings (benign)"))
    }
  }, error = function(e) {
    cat("⚠️  PRIOR VALIDATION ERROR (continuing):", e$message, "\n")
    append_to_log(log_file, paste0(model_name, ": Prior validation error (continuing)"))
  })
  
  # Fit model
  cat("\nFitting model (LIGHTWEIGHT MODE)...\n")
  cat("  Iterations: 3000 (warmup: 1500)\n")
  cat("  Chains: 2, Cores: 1\n")
  cat("  adapt_delta: 0.95, max_treedepth: 12\n\n")
  
  append_to_log(log_file, paste0(model_name, ": Starting fit (3000 iter, 2 chains, 1 core)"))
  
  fit_start <- Sys.time()
  
  fit <- brm(
    formula = spec$formula,
    data = data,
    family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
    prior = spec$priors,
    chains = 2,
    iter = 3000,
    warmup = 1500,
    cores = 1,
    init = stabilized_init,
    control = list(adapt_delta = 0.95, max_treedepth = 12),
    backend = "cmdstanr",
    file = file.path("output/models", model_name),
    file_refit = "always",
    refresh = 200,
    seed = 123
  )
  
  fit_elapsed <- difftime(Sys.time(), fit_start, units = "mins")
  cat("✓ Model fitted (took", round(as.numeric(fit_elapsed), 1), "minutes)\n\n")
  
  append_to_log(log_file, paste0(model_name, ": Fit completed (", round(as.numeric(fit_elapsed), 1), " minutes)"))
  
  # Clean memory
  gc(verbose = FALSE)
  
  # Convergence checks
  cat("Checking convergence...\n")
  
  rhat_values <- rhat(fit)
  max_rhat <- max(rhat_values, na.rm = TRUE)
  
  ess_ratios <- neff_ratio(fit)
  min_ess_ratio <- min(ess_ratios, na.rm = TRUE)
  
  ess_bulk <- ess_bulk(fit)
  ess_tail <- ess_tail(fit)
  min_ess_bulk <- min(ess_bulk, na.rm = TRUE)
  min_ess_tail <- min(ess_tail, na.rm = TRUE)
  
  cat("  Max R-hat:", round(max_rhat, 4), "\n")
  cat("  Min ESS ratio:", round(min_ess_ratio, 4), "\n")
  cat("  Min ESS (bulk):", round(min_ess_bulk, 0), "\n")
  cat("  Min ESS (tail):", round(min_ess_tail, 0), "\n")
  
  converged <- (max_rhat <= 1.05 && min_ess_ratio >= 0.1)
  
  if (converged) {
    cat("\n✓ CONVERGENCE: PASSED\n")
    append_to_log(log_file, paste0(model_name, ": Convergence PASSED"))
  } else {
    cat("\n⚠️  CONVERGENCE: FAILED\n")
    cat("  Max R-hat:", max_rhat, "(threshold: 1.05)\n")
    cat("  Min ESS ratio:", min_ess_ratio, "(threshold: 0.1)\n")
    append_to_log(log_file, paste0(model_name, ": Convergence FAILED (R-hat=", round(max_rhat, 4), ", ESS=", round(min_ess_ratio, 4), ")"))
  }
  
  # Return diagnostics (without fit object)
  list(
    model_name = model_name,
    max_rhat = max_rhat,
    min_ess_ratio = min_ess_ratio,
    min_ess_bulk = min_ess_bulk,
    min_ess_tail = min_ess_tail,
    converged = converged,
    fit_time_minutes = as.numeric(fit_elapsed),
    completed_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  )
}

# =========================================================================
# PROCESS MODELS
# =========================================================================

for (model_name in models_to_run) {
  if (model_name %in% completed_models) {
    cat("\n⏭️  Skipping", model_name, "(already completed)\n")
    next
  }
  
  spec <- MODELS_TO_STABILIZE[[model_name]]
  
  tryCatch({
    diag <- stabilize_single_model(model_name, spec, ddm_data, log_file)
    
    # Load existing diagnostics and append
    existing_diag <- load_existing_diagnostics()
    
    # Remove old entry if exists
    existing_diag <- existing_diag[existing_diag$model != model_name, ]
    
    # Add new entry
    new_row <- data.frame(
      model = diag$model_name,
      max_rhat = diag$max_rhat,
      min_ess_ratio = diag$min_ess_ratio,
      min_ess_bulk = diag$min_ess_bulk,
      min_ess_tail = diag$min_ess_tail,
      converged = diag$converged,
      fit_time_minutes = diag$fit_time_minutes,
      completed_at = diag$completed_at,
      stringsAsFactors = FALSE
    )
    
    updated_diag <- rbind(existing_diag, new_row)
    updated_diag <- updated_diag[order(updated_diag$model), ]
    
    save_diagnostics(updated_diag)
    append_to_log(log_file, paste0(model_name, ": Diagnostics saved"))
    
    # Clean memory before next model
    gc(verbose = FALSE)
    
    cat("\n✅ Model", model_name, "completed and saved!\n")
    cat("   Log:", log_file, "\n")
    cat("   Diagnostics:", "output/diagnostics/convergence_report.csv", "\n\n")
    
    # Brief pause
    Sys.sleep(2)
    
  }, error = function(e) {
    cat("\n❌ ERROR fitting", model_name, ":", e$message, "\n\n")
    append_to_log(log_file, paste0(model_name, ": ERROR - ", e$message))
    
    # Save error in diagnostics
    existing_diag <- load_existing_diagnostics()
    existing_diag <- existing_diag[existing_diag$model != model_name, ]
    
    error_row <- data.frame(
      model = model_name,
      max_rhat = NA,
      min_ess_ratio = NA,
      min_ess_bulk = NA,
      min_ess_tail = NA,
      converged = FALSE,
      fit_time_minutes = NA,
      completed_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      stringsAsFactors = FALSE
    )
    
    updated_diag <- rbind(existing_diag, error_row)
    updated_diag <- updated_diag[order(updated_diag$model), ]
    save_diagnostics(updated_diag)
    
    gc(verbose = FALSE)
  })
}

# Final summary
cat("\n")
cat("================================================================================\n")
cat("SESSION COMPLETE\n")
cat("================================================================================\n")

final_diag <- load_existing_diagnostics()
n_completed <- sum(!is.na(final_diag$fit_time_minutes))
n_converged <- sum(final_diag$converged, na.rm = TRUE)

cat("Completed:", n_completed, "of", length(MODELS_TO_STABILIZE), "models\n")
cat("Converged:", n_converged, "models\n")
cat("Log file:", log_file, "\n")
cat("Diagnostics:", "output/diagnostics/convergence_report.csv", "\n\n")

append_to_log(log_file, paste0("=== SESSION COMPLETE (", n_completed, "/", length(MODELS_TO_STABILIZE), " models) ==="))

