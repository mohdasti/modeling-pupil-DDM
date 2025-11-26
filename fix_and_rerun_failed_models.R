#!/usr/bin/env Rscript
# =========================================================================
# FIX AND RE-RUN FAILED MODELS ONLY
# =========================================================================
# Identifies failed models and re-runs them with fixes
# =========================================================================

cat("================================================================================\n")
cat("FIX AND RE-RUN FAILED MODELS\n")
cat("================================================================================\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

library(brms)
library(dplyr)
library(readr)
library(purrr)

# =========================================================================
# LOAD DATA
# =========================================================================

cat("[", format(Sys.time(), "%H:%M:%S"), "] Loading data...\n")
ddm_data <- read_csv("data/analysis_ready/bap_ddm_ready.csv", show_col_types = FALSE) %>%
    filter(!is.na(rt), !is.na(iscorr), rt >= 0.2, rt <= 3.0) %>%
    mutate(
        subject_id = as.factor(subject_id),
        task = as.factor(task),
        difficulty_level = as.factor(difficulty_level),
        # Fix effort_condition - check if we have multiple levels
        effort_condition = if("effort_condition" %in% names(.)) {
            if(length(unique(.$effort_condition)) > 1) {
                as.factor(effort_condition)
            } else {
                # Only one level, create a dummy level or exclude models that need it
                as.factor(rep("Single", nrow(.)))
            }
        } else {
            as.factor(rep("Unknown", nrow(.)))
        },
        decision = ifelse(iscorr == 1, 1, 0)
    )

cat("[", format(Sys.time(), "%H:%M:%S"), "] Data loaded:", nrow(ddm_data), "trials\n")
cat("  effort_condition levels:", length(unique(ddm_data$effort_condition)), "\n")
cat("  difficulty_level levels:", length(unique(ddm_data$difficulty_level)), "\n")
cat("  task levels:", length(unique(ddm_data$task)), "\n\n")

# =========================================================================
# STANDARDIZED PRIORS
# =========================================================================

priors_std <- c(
    prior(normal(0, 1), class = "Intercept"),
    prior(normal(0, 0.5), class = "b"),
    prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
    prior(normal(0, 0.20), class = "b", dpar = "bs"),
    prior(normal(log(0.35), 0.25), class = "Intercept", dpar = "ndt"),
    prior(normal(0, 0.15), class = "b", dpar = "ndt"),
    prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
    prior(normal(0, 0.3), class = "b", dpar = "bias"),
    prior(student_t(3, 0, 0.5), class = "sd")
)

# =========================================================================
# IDENTIFY FAILED MODELS
# =========================================================================

cat("[", format(Sys.time(), "%H:%M:%S"), "] Checking which models exist...\n")
models_dir <- "output/models"
existing_models <- list.files(models_dir, pattern = "\\.rds$", full.names = TRUE)
existing_names <- gsub("\\.rds$", "", basename(existing_models))

cat("Existing models:", length(existing_models), "\n")
cat("  ", paste(existing_names, collapse = ", "), "\n\n")

# Define all models we want to fit
all_models <- list(
    "Model1_Baseline" = list(
        formula = bf(rt | dec(decision) ~ 1 + (1|subject_id),
                     bs ~ 1 + (1|subject_id),
                     ndt ~ 1 + (1|subject_id),
                     bias ~ 1 + (1|subject_id)),
        priors = priors_std[c(1, 3, 5, 7, 9)],  # Intercept-only priors
        use_effort = FALSE
    ),
    "Model3_Difficulty" = list(
        formula = bf(rt | dec(decision) ~ difficulty_level + (1|subject_id),
                     bs ~ 1 + (1|subject_id),
                     ndt ~ 1 + (1|subject_id),
                     bias ~ 1 + (1|subject_id)),
        priors = priors_std,
        use_effort = FALSE
    ),
    "Model7_Task" = list(
        formula = bf(rt | dec(decision) ~ task + (1|subject_id),
                     bs ~ 1 + (1|subject_id),
                     ndt ~ 1 + (1|subject_id),
                     bias ~ 1 + (1|subject_id)),
        priors = priors_std,
        use_effort = FALSE
    )
)

# Check if effort_condition has multiple levels
has_multiple_effort <- length(unique(ddm_data$effort_condition)) > 1

if (has_multiple_effort) {
    all_models[["Model2_Force"]] <- list(
        formula = bf(rt | dec(decision) ~ effort_condition + (1|subject_id),
                     bs ~ 1 + (1|subject_id),
                     ndt ~ 1 + (1|subject_id),
                     bias ~ 1 + (1|subject_id)),
        priors = priors_std,
        use_effort = TRUE
    )
    all_models[["Model4_Additive"]] <- list(
        formula = bf(rt | dec(decision) ~ effort_condition + difficulty_level + (1|subject_id),
                     bs ~ 1 + (1|subject_id),
                     ndt ~ 1 + (1|subject_id),
                     bias ~ 1 + (1|subject_id)),
        priors = priors_std,
        use_effort = TRUE
    )
}

# =========================================================================
# RE-RUN FAILED MODELS
# =========================================================================

cat("[", format(Sys.time(), "%H:%M:%S"), "] Re-running failed models...\n\n")

for (model_name in names(all_models)) {
    model_file <- file.path(models_dir, paste0(model_name, ".rds"))
    model_spec <- all_models[[model_name]]
    
    # Check if model already exists and is valid
    if (file.exists(model_file)) {
        tryCatch({
            test_model <- readRDS(model_file)
            if (inherits(test_model, "brmsfit")) {
                cat("[", format(Sys.time(), "%H:%M:%S"), "] ✅", model_name, "already exists and is valid, skipping\n")
                next
            }
        }, error = function(e) {
            cat("[", format(Sys.time(), "%H:%M:%S"), "] ⚠️", model_name, "file exists but invalid, re-fitting...\n")
        })
    }
    
    cat("[", format(Sys.time(), "%H:%M:%S"), "] Fitting", model_name, "...\n")
    
    # Filter data if needed
    data_to_use <- ddm_data
    if (model_spec$use_effort && !has_multiple_effort) {
        cat("  ⚠️ Skipping (requires multiple effort levels)\n")
        next
    }
    
    # Set better initial values
    min_rt <- min(data_to_use$rt, na.rm = TRUE)
    init_ndt <- log(min_rt * 0.3)
    
    tryCatch({
        start_time <- Sys.time()
        
        model <- brm(
            formula = model_spec$formula,
            data = data_to_use,
            family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
            prior = model_spec$priors,
            chains = 4,
            cores = 4,
            iter = 2000,
            warmup = 1000,
            seed = 12345,
            init = function() {
                list(
                    Intercept = rnorm(1, 0, 0.5),
                    bs_Intercept = log(runif(1, 1.0, 2.0)),
                    ndt_Intercept = init_ndt,
                    bias_Intercept = rnorm(1, 0, 0.3)
                )
            },
            control = list(adapt_delta = 0.95, max_treedepth = 12),
            file = model_file,
            file_refit = "on_change",
            refresh = 100
        )
        
        elapsed <- difftime(Sys.time(), start_time, units = "mins")
        cat("[", format(Sys.time(), "%H:%M:%S"), "] ✅", model_name, "complete (took", round(elapsed, 1), "minutes)\n\n")
        
    }, error = function(e) {
        elapsed <- difftime(Sys.time(), start_time, units = "mins")
        cat("[", format(Sys.time(), "%H:%M:%S"), "] ❌", model_name, "failed (after", round(elapsed, 1), "minutes):\n")
        cat("   Error:", e$message, "\n\n")
    })
}

cat("================================================================================\n")
cat("✅ RE-RUN COMPLETE\n")
cat("================================================================================\n")
cat("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Check output/models/ for results\n")
cat("================================================================================\n")
















