# =========================================================================
# SCRIPT 2: DDM STATISTICAL MODELING (FULLY EXPLICIT & FINAL VERSION)
# =========================================================================
log_message("DDM analysis (Step 2) initiated.", "INIT")
log_message("--- Loading & Preparing Datasets ---", "SUB-STEP")
behavioral_file <- file.path(DATA_PATHS$analysis_ready, "BAP_analysis_ready_BEHAVIORAL.csv")
ddm_data_behav <- readr::read_csv(behavioral_file, show_col_types = FALSE)
pupil_file <- file.path(DATA_PATHS$analysis_ready, "BAP_analysis_ready_PUPIL.csv")
ddm_data_pupil <- readr::read_csv(pupil_file, show_col_types = FALSE)
    ddm_data_behav <- ddm_data_behav %>%
    dplyr::filter(rt >= 0.15 & rt <= 3.0, difficulty_level != "Standard") %>%
    dplyr::mutate(
        response = as.integer(accuracy),
        effort_condition = as.factor(effort_condition),
        difficulty_level = as.factor(difficulty_level),
        subject_id = as.factor(subject_id),
        # Create decision variable for wiener family (1 for correct, 0 for incorrect)
        decision = ifelse(accuracy == 1, 1, 0)
    )
ddm_data_pupil <- ddm_data_pupil %>%
    dplyr::filter(rt >= 0.15 & rt <= 3.0, difficulty_level != "Standard") %>%
    dplyr::mutate(
        response = as.integer(accuracy),
        effort_condition = as.factor(effort_condition),
        difficulty_level = as.factor(difficulty_level),
        subject_id = as.factor(subject_id),
        # Create decision variable for wiener family (1 for correct, 0 for incorrect)
        decision = ifelse(accuracy == 1, 1, 0),
        tonic_arousal_scaled = scale(tonic_arousal)[,1],
        effort_arousal_scaled = scale(effort_arousal_change)[,1]
    )
log_message("SUCCESS: Data loading and preparation complete.", "INFO")
log_message(sprintf("Final datasets ready: BEHAVIORAL (%d trials), PUPIL (%d trials).", nrow(ddm_data_behav), nrow(ddm_data_pupil)))
create_ddm_models <- function() {
    common_priors <- c(
        prior(normal(0, 1.5), class = "Intercept"),
        prior(normal(0, 1), class = "b"),
        prior(exponential(1), class = "sd")
    )
    models <- list(
        "Model1_Baseline"     = list(dataType = "behavioral", formula = brms::bf(rt | dec(decision) ~ 1 + (1|subject_id))),
        "Model2_Force"        = list(dataType = "behavioral", formula = brms::bf(rt | dec(decision) ~ effort_condition + (1|subject_id))),
        "Model3_Difficulty"   = list(dataType = "behavioral", formula = brms::bf(rt | dec(decision) ~ difficulty_level + (1|subject_id))),
        "Model4_Additive"     = list(dataType = "behavioral", formula = brms::bf(rt | dec(decision) ~ effort_condition + difficulty_level + (1|subject_id))),
        "Model5_Interaction"  = list(dataType = "behavioral", formula = brms::bf(rt | dec(decision) ~ effort_condition * difficulty_level + (1|subject_id))),
        "Model6_Pupillometry" = list(dataType = "pupil",      formula = brms::bf(rt | dec(decision) ~ effort_arousal_scaled + tonic_arousal_scaled + (1|subject_id)))
    )
    final_models <- purrr::map(models, ~ .x %>% purrr::list_modify(priors = common_priors))
    return(final_models)
}
fit_ddm_model <- function(spec, data, model_name) {
    # Now using proper wiener family for DDM models
    brm(
        formula = spec$formula, data = data, family = wiener(link_bs = "log", link_ndt = "log"),
        prior = spec$priors, chains = 4, iter = 2000, warmup = 1000, cores = 4,
        backend = "cmdstanr", file = file.path(OUTPUT_PATHS$models, model_name), file_refit = "on_change"
    )
}
model_specs <- create_ddm_models()
for (model_name in names(model_specs)) {
    spec <- model_specs[[model_name]]
    data_to_use <- if (spec$dataType == "pupil") ddm_data_pupil else ddm_data_behav
    tryCatch({
        log_message(paste("--- FITTING:", model_name, "---"), "MODEL")
        fit_ddm_model(spec, data_to_use, model_name)
        log_message(sprintf("SUCCESS: %s fitted.", model_name), "SUCCESS")
    }, error = function(e) {
        log_message(sprintf("FAILED to fit %s: %s", model_name, e$message), "ERROR")
    })
}