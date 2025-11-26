#!/usr/bin/env Rscript
# =========================================================================
# RE-RUN ONLY FAILED MODELS WITH FIXES
# =========================================================================
# Identifies failed models from logs and re-runs them with fixes applied
# =========================================================================

cat("================================================================================\n")
cat("RE-RUNNING FAILED MODELS WITH FIXES\n")
cat("================================================================================\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

library(brms)
library(dplyr)
library(readr)

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
        effort_condition = as.factor(effort_condition),
        decision = ifelse(iscorr == 1, 1, 0)
    )

cat("[", format(Sys.time(), "%H:%M:%S"), "] Data loaded:", nrow(ddm_data), "trials\n")
cat("  effort_condition:", length(unique(ddm_data$effort_condition)), "level(s)\n")
cat("  difficulty_level:", length(unique(ddm_data$difficulty_level)), "level(s)\n")
cat("  task:", length(unique(ddm_data$task)), "level(s)\n\n")

# Check factor levels
effort_levels <- length(unique(stats::na.omit(ddm_data$effort_condition)))
task_levels <- length(unique(stats::na.omit(ddm_data$task)))

# =========================================================================
# STANDARDIZED PRIORS (WITHOUT b PRIORS FOR INTERCEPT-ONLY PARAMS)
# =========================================================================

base_priors <- c(
    prior(normal(0, 1), class = "Intercept"),
    prior(normal(0, 0.5), class = "b"),
    prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
    prior(normal(log(0.35), 0.25), class = "Intercept", dpar = "ndt"),
    prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
    prior(student_t(3, 0, 0.5), class = "sd")
)

# =========================================================================
# MODELS TO FIX (ONLY THOSE THAT FAILED)
# =========================================================================

models_to_fix <- list()

# Model3_Difficulty - Fix priors (remove b priors)
models_to_fix[["Model3_Difficulty"]] <- list(
    formula = bf(rt | dec(decision) ~ difficulty_level + (1|subject_id),
                 bs ~ 1 + (1|subject_id),
                 ndt ~ 1 + (1|subject_id),
                 bias ~ 1 + (1|subject_id)),
    priors = base_priors,  # No b priors for intercept-only params
    skip = FALSE
)

# Model7_Task - Fix priors
models_to_fix[["Model7_Task"]] <- list(
    formula = bf(rt | dec(decision) ~ task + (1|subject_id),
                 bs ~ 1 + (1|subject_id),
                 ndt ~ 1 + (1|subject_id),
                 bias ~ 1 + (1|subject_id)),
    priors = base_priors,
    skip = task_levels < 2
)

# Skip models requiring effort (only 1 level available)
if (effort_levels < 2) {
    cat("[", format(Sys.time(), "%H:%M:%S"), "] ⚠️  Skipping effort models (only", effort_levels, "level available)\n")
    cat("    Skipped: Model2_Force, Model4_Additive, Model5_Interaction, Model10_Param_v_bs\n\n")
}

# =========================================================================
# RE-RUN MODELS
# =========================================================================

cat("[", format(Sys.time(), "%H:%M:%S"), "] Re-running failed models with fixes...\n\n")

models_dir <- "output/models"
min_rt <- min(ddm_data$rt, na.rm = TRUE)
init_ndt <- log(min_rt * 0.3)

for (model_name in names(models_to_fix)) {
    model_spec <- models_to_fix[[model_name]]
    
    if (model_spec$skip) {
        cat("[", format(Sys.time(), "%H:%M:%S"), "] ⚠️  Skipping", model_name, "(insufficient factor levels)\n")
        next
    }
    
    model_file <- file.path(models_dir, paste0(model_name, ".rds"))
    
    # Check if already exists and is valid
    if (file.exists(model_file)) {
        tryCatch({
            test <- readRDS(model_file)
            if (inherits(test, "brmsfit")) {
                cat("[", format(Sys.time(), "%H:%M:%S"), "] ✅", model_name, "already exists, skipping\n")
                next
            }
        }, error = function(e) {
            cat("[", format(Sys.time(), "%H:%M:%S"), "] ⚠️", model_name, "file invalid, re-fitting...\n")
        })
    }
    
    cat("[", format(Sys.time(), "%H:%M:%S"), "] Fitting", model_name, "...\n")
    
    tryCatch({
        start_time <- Sys.time()
        
        model <- brm(
            formula = model_spec$formula,
            data = ddm_data,
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
        cat("[", format(Sys.time(), "%H:%M:%S"), "] ✅", model_name, "complete (", round(elapsed, 1), "minutes)\n\n")
        
    }, error = function(e) {
        elapsed <- difftime(Sys.time(), start_time, units = "mins")
        cat("[", format(Sys.time(), "%H:%M:%S"), "] ❌", model_name, "failed (", round(elapsed, 1), "minutes):\n")
        cat("   ", e$message, "\n\n")
    })
}

cat("================================================================================\n")
cat("✅ RE-RUN COMPLETE\n")
cat("================================================================================\n")
cat("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Check output/models/ for results\n")
cat("================================================================================\n")
















