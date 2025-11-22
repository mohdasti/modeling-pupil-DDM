# =========================================================================
# MODEL VERIFICATION SCRIPT
# =========================================================================
# Loads and checks all DDM models for convergence and errors
# =========================================================================

cat("\n")
cat("================================================================================\n")
cat("DDM MODEL VERIFICATION\n")
cat("================================================================================\n")
cat("Checking all fitted models...\n\n")

# Load required libraries
library(brms)
library(dplyr)

# Set working directory if needed
if (!file.exists("output/models")) {
  if (file.exists("scripts")) {
    # Already in project root
  } else {
    # Try to find project root
    if (file.exists("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")) {
      setwd("/Users/mohdasti/Documents/GitHub/modeling-pupil-DDM/modeling-pupil-DDM")
    }
  }
}

# Get all model files
model_files <- list.files("output/models", pattern = "\\.rds$", full.names = TRUE)
model_names <- basename(model_files) %>% 
  gsub("\\.rds$", "", .) %>%
  sort()

cat("Found", length(model_names), "model files\n\n")

# Main models (non-task-specific)
main_models <- model_names[!grepl("_ADT$|_VDT$", model_names) & 
                           !grepl("_TEST|_NO_NDT|_NoEffort", model_names)]
main_models <- main_models[grepl("^Model", main_models)]

cat("Main models to verify:", length(main_models), "\n")
cat(paste(main_models, collapse = ", "), "\n\n")

# Verification results
verification_results <- data.frame(
  model_name = character(),
  loaded = logical(),
  converged = logical(),
  rhat_max = numeric(),
  ess_min = numeric(),
  errors = character(),
  warnings = character(),
  stringsAsFactors = FALSE
)

# Check each main model
cat("================================================================================\n")
cat("VERIFICATION RESULTS\n")
cat("================================================================================\n\n")

for (model_name in main_models) {
  cat("\n--- Checking", model_name, "---\n")
  
  model_file <- paste0("output/models/", model_name, ".rds")
  
  if (!file.exists(model_file)) {
    cat("❌ File not found:", model_file, "\n")
    verification_results <- rbind(verification_results, data.frame(
      model_name = model_name,
      loaded = FALSE,
      converged = FALSE,
      rhat_max = NA,
      ess_min = NA,
      errors = "File not found",
      warnings = "",
      stringsAsFactors = FALSE
    ))
    next
  }
  
  # Try to load the model
  tryCatch({
    model <- readRDS(model_file)
    cat("✅ Model loaded successfully\n")
    
    # Check convergence
    summary_info <- summary(model)
    
    # Extract R-hat (should be < 1.01 for good convergence)
    if ("fit" %in% names(model)) {
      rhats <- brms::rhat(model)
      rhat_max <- max(rhats, na.rm = TRUE)
      cat("   Max R-hat:", sprintf("%.4f", rhat_max), 
          ifelse(rhat_max < 1.01, "✅", ifelse(rhat_max < 1.05, "⚠️", "❌")), "\n")
      
      # Extract ESS (effective sample size)
      ess <- brms::neff_ratio(model)
      ess_min <- min(ess, na.rm = TRUE)
      cat("   Min ESS ratio:", sprintf("%.4f", ess_min),
          ifelse(ess_min > 0.1, "✅", "⚠️"), "\n")
      
      converged <- (rhat_max < 1.05) & (ess_min > 0.05)
      
      verification_results <- rbind(verification_results, data.frame(
        model_name = model_name,
        loaded = TRUE,
        converged = converged,
        rhat_max = rhat_max,
        ess_min = ess_min,
        errors = "",
        warnings = ifelse(!converged, "Convergence issues detected", ""),
        stringsAsFactors = FALSE
      ))
      
      if (converged) {
        cat("   Status: ✅ Converged\n")
      } else {
        cat("   Status: ⚠️  Convergence issues\n")
      }
      
    } else {
      cat("   ⚠️  Cannot extract convergence diagnostics\n")
      verification_results <- rbind(verification_results, data.frame(
        model_name = model_name,
        loaded = TRUE,
        converged = NA,
        rhat_max = NA,
        ess_min = NA,
        errors = "",
        warnings = "Cannot extract diagnostics",
        stringsAsFactors = FALSE
      ))
    }
    
  }, error = function(e) {
    cat("❌ Error loading model:", e$message, "\n")
    verification_results <- rbind(verification_results, data.frame(
      model_name = model_name,
      loaded = FALSE,
      converged = FALSE,
      rhat_max = NA,
      ess_min = NA,
      errors = e$message,
      warnings = "",
      stringsAsFactors = FALSE
    ))
  })
}

# Summary
cat("\n")
cat("================================================================================\n")
cat("SUMMARY\n")
cat("================================================================================\n\n")

cat("Total models checked:", nrow(verification_results), "\n")
cat("Successfully loaded:", sum(verification_results$loaded, na.rm = TRUE), "\n")
cat("Converged:", sum(verification_results$converged, na.rm = TRUE), "\n")
cat("Issues:", sum(!verification_results$converged | is.na(verification_results$converged), na.rm = TRUE), "\n\n")

# Save results
write.csv(verification_results, 
          file = "model_verification_results.csv",
          row.names = FALSE)

cat("✅ Verification results saved to: model_verification_results.csv\n\n")

# Display table
cat("Detailed Results:\n")
print(verification_results)

cat("\n")
cat("================================================================================\n")
cat("VERIFICATION COMPLETE\n")
cat("================================================================================\n\n")








