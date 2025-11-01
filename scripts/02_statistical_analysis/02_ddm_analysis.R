# =========================================================================
# SCRIPT 2: DDM STATISTICAL MODELING (FULLY EXPLICIT & FINAL VERSION)
# =========================================================================

# Ensure required packages and paths are available when running standalone
suppressPackageStartupMessages({
    library(dplyr)
    library(readr)
    library(purrr)
    library(brms)
})
if (!exists("DATA_PATHS") || !exists("OUTPUT_PATHS")) {
    config_dir <- file.path(getwd(), "config")
    candidate_configs <- c(
        file.path(config_dir, "paths_config.R"),
        file.path(config_dir, "pipeline_config.R"),
        file.path(config_dir, "paths_config.R.example")
    )
    loaded <- FALSE
    for (cfg in candidate_configs) {
        if (file.exists(cfg)) {
            try({ source(cfg); loaded <- TRUE }, silent = TRUE)
        }
        if (loaded && exists("DATA_PATHS") && exists("OUTPUT_PATHS")) break
    }
    if (!loaded || !exists("DATA_PATHS") || !exists("OUTPUT_PATHS")) {
        # Fallback minimal defaults inside repo
        DATA_PATHS <- list(
            analysis_ready = "data/analysis_ready",
            behavioral_file = "data/analysis_ready/BAP_analysis_ready_BEHAVIORAL.csv",
            pupil_file = "data/analysis_ready/BAP_analysis_ready_PUPIL.csv"
        )
        OUTPUT_PATHS <- list(
            base = "output",
            models = "output/models",
            results = "output/results",
            figures = "output/figures",
            logs = "output/logs"
        )
    }
}
if (!exists("log_message")) {
    log_message <- function(message, level = "INFO") {
        cat(sprintf("[%s] [%s] %s\n", format(Sys.time(), "%H:%M:%S"), level, message))
    }
}
dir.create(OUTPUT_PATHS$models, recursive = TRUE, showWarnings = FALSE)

log_message("DDM analysis (Step 2) initiated.", "INIT")
log_message("--- Loading & Preparing Datasets ---", "SUB-STEP")
choose_first_existing <- function(paths) {
    for (p in paths) {
        if (!is.null(p) && file.exists(p)) return(p)
    }
    return(NA_character_)
}
behavioral_candidates <- c(
    if (!is.null(DATA_PATHS$behavioral_data)) DATA_PATHS$behavioral_data else NA_character_,
    file.path(DATA_PATHS$analysis_ready, "BAP_analysis_ready_BEHAVIORAL.csv"),
    file.path(DATA_PATHS$analysis_ready, "behavioral_data.csv"),
    file.path("data/analysis_ready", "BAP_analysis_ready_BEHAVIORAL.csv"),
    file.path("data/analysis_ready", "behavioral_data.csv"),
    file.path("data/analysis_ready", "bap_ddm_ready.csv")
)
pupil_candidates <- c(
    if (!is.null(DATA_PATHS$pupil_data)) DATA_PATHS$pupil_data else NA_character_,
    file.path(DATA_PATHS$analysis_ready, "BAP_analysis_ready_PUPIL.csv"),
    file.path(DATA_PATHS$analysis_ready, "pupil_data.csv"),
    file.path("data/analysis_ready", "BAP_analysis_ready_PUPIL.csv"),
    file.path("data/analysis_ready", "pupil_data.csv"),
    file.path("data/analysis_ready", "bap_ddm_ready.csv")
)
behavioral_file <- choose_first_existing(behavioral_candidates)
pupil_file <- choose_first_existing(pupil_candidates)
if (is.na(behavioral_file)) {
    stop(paste0(
        "Could not find a behavioral data file. Tried: ",
        paste(behavioral_candidates[!is.na(behavioral_candidates)], collapse = ", ")
    ))
}
if (is.na(pupil_file)) {
    stop(paste0(
        "Could not find a pupil data file. Tried: ",
        paste(pupil_candidates[!is.na(pupil_candidates)], collapse = ", ")
    ))
}
log_message(paste("Using behavioral data:", behavioral_file))
log_message(paste("Using pupil data:", pupil_file))
ddm_data_behav <- readr::read_csv(behavioral_file, show_col_types = FALSE)
ddm_data_pupil <- readr::read_csv(pupil_file, show_col_types = FALSE)

# Harmonize column names/types for behavioral data
if (!"rt" %in% names(ddm_data_behav) && "resp1RT" %in% names(ddm_data_behav)) ddm_data_behav$rt <- ddm_data_behav$resp1RT
ddm_data_behav$rt <- suppressWarnings(as.numeric(ddm_data_behav$rt))
if (!"accuracy" %in% names(ddm_data_behav) && "iscorr" %in% names(ddm_data_behav)) ddm_data_behav$accuracy <- ddm_data_behav$iscorr
if (!"subject_id" %in% names(ddm_data_behav) && "sub" %in% names(ddm_data_behav)) ddm_data_behav$subject_id <- as.character(ddm_data_behav$sub)
if (!"task" %in% names(ddm_data_behav) && "task_behav" %in% names(ddm_data_behav)) ddm_data_behav$task <- ddm_data_behav$task_behav
if (!"difficulty_level" %in% names(ddm_data_behav)) {
    if ("stimulus_condition" %in% names(ddm_data_behav)) {
        ddm_data_behav$difficulty_level <- ifelse(ddm_data_behav$stimulus_condition == "Standard", "Easy",
                                           ifelse(ddm_data_behav$stimulus_condition == "Oddball", "Hard", NA_character_))
    } else {
        ddm_data_behav$difficulty_level <- NA_character_
    }
}

# Harmonize column names/types for pupil data
if (!"rt" %in% names(ddm_data_pupil) && "resp1RT" %in% names(ddm_data_pupil)) ddm_data_pupil$rt <- ddm_data_pupil$resp1RT
ddm_data_pupil$rt <- suppressWarnings(as.numeric(ddm_data_pupil$rt))
if (!"accuracy" %in% names(ddm_data_pupil) && "iscorr" %in% names(ddm_data_pupil)) ddm_data_pupil$accuracy <- ddm_data_pupil$iscorr
if (!"subject_id" %in% names(ddm_data_pupil) && "sub" %in% names(ddm_data_pupil)) ddm_data_pupil$subject_id <- as.character(ddm_data_pupil$sub)
if (!"task" %in% names(ddm_data_pupil) && "task_behav" %in% names(ddm_data_pupil)) ddm_data_pupil$task <- ddm_data_pupil$task_behav
if (!"difficulty_level" %in% names(ddm_data_pupil)) {
    if ("stimulus_condition" %in% names(ddm_data_pupil)) {
        ddm_data_pupil$difficulty_level <- ifelse(ddm_data_pupil$stimulus_condition == "Standard", "Easy",
                                           ifelse(ddm_data_pupil$stimulus_condition == "Oddball", "Hard", NA_character_))
    } else {
        ddm_data_pupil$difficulty_level <- NA_character_
    }
}

# Map alternative pupil columns to required names if needed
get_first_col <- function(df, candidates) {
    for (nm in candidates) {
        if (nm %in% names(df)) return(df[[nm]])
    }
    return(NULL)
}
if (!"tonic_arousal" %in% names(ddm_data_pupil)) {
    tonic_candidate <- get_first_col(ddm_data_pupil, c("tonic_arousal", "pupil_baseline", "pupil_baseline_z"))
    if (!is.null(tonic_candidate)) {
        ddm_data_pupil$tonic_arousal <- as.numeric(tonic_candidate)
        log_message("Mapped tonic_arousal from available pupil baseline column", "INFO")
    }
}
if (!"effort_arousal_change" %in% names(ddm_data_pupil)) {
    effort_candidate <- get_first_col(ddm_data_pupil, c("effort_arousal_change", "pupil_evoked", "pupil_evoked_z", "pupil_mean", "pupil_mean_z"))
    if (!is.null(effort_candidate)) {
        ddm_data_pupil$effort_arousal_change <- as.numeric(effort_candidate)
        log_message("Mapped effort_arousal_change from available evoked/mean pupil column", "INFO")
    }
}
PUPIL_FEATURES_AVAILABLE <- all(c("tonic_arousal", "effort_arousal_change") %in% names(ddm_data_pupil))

    ddm_data_behav <- ddm_data_behav %>%
    dplyr::filter(rt >= 0.2 & rt <= 3.0) %>%
    dplyr::mutate(
        response = as.integer(accuracy),
        effort_condition = as.factor(effort_condition),
        difficulty_level = as.factor(difficulty_level),
        subject_id = as.factor(subject_id),
        task = as.factor(task),
        # Create decision variable for wiener family (1 for correct, 0 for incorrect)
        decision = ifelse(accuracy == 1, 1, 0)
    )
# Enforce consistent task levels globally so per-task splits retain both levels
if (all(unique(na.omit(ddm_data_behav$task)) %in% c("ADT","VDT"))) {
    ddm_data_behav$task <- factor(ddm_data_behav$task, levels = c("ADT","VDT"))
}
if (PUPIL_FEATURES_AVAILABLE) {
    ddm_data_pupil <- ddm_data_pupil %>%
        dplyr::filter(rt >= 0.2 & rt <= 3.0) %>%
        dplyr::mutate(
            response = as.integer(accuracy),
            effort_condition = as.factor(effort_condition),
            difficulty_level = as.factor(difficulty_level),
            subject_id = as.factor(subject_id),
            task = as.factor(task),
            # Create decision variable for wiener family (1 for correct, 0 for incorrect)
            decision = ifelse(accuracy == 1, 1, 0),
            tonic_arousal_scaled = scale(tonic_arousal)[,1],
            effort_arousal_scaled = scale(effort_arousal_change)[,1]
        )
    if (all(unique(na.omit(ddm_data_pupil$task)) %in% c("ADT","VDT"))) {
        ddm_data_pupil$task <- factor(ddm_data_pupil$task, levels = c("ADT","VDT"))
    }
} else {
    log_message("Pupillometry features not found; skipping pupil-based models.", "WARN")
}
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
        # Sensitivity: include task main effect and interactions
        "Model7_Task"          = list(dataType = "behavioral", formula = brms::bf(rt | dec(decision) ~ task + (1|subject_id))),
        "Model8_Task_Additive" = list(dataType = "behavioral", formula = brms::bf(rt | dec(decision) ~ effort_condition + difficulty_level + task + (1|subject_id))),
        "Model9_Task_Intx"     = list(dataType = "behavioral", formula = brms::bf(rt | dec(decision) ~ task * effort_condition + task * difficulty_level + (1|subject_id)))
    )
    # Add parameterized Wiener model estimating both v and bs (and simple ndt)
    param_bf <- brms::bf(
        rt | dec(decision) ~ effort_condition + difficulty_level + (1|subject_id),
        bs ~ effort_condition + difficulty_level + (1|subject_id),
        ndt ~ 1 + (1|subject_id)
    )
    models[["Model10_Param_v_bs"]] <- list(dataType = "behavioral", formula = param_bf)
    if (PUPIL_FEATURES_AVAILABLE) {
        models <- c(
            models,
            list(
                "Model6_Pupillometry"  = list(dataType = "pupil", formula = brms::bf(rt | dec(decision) ~ effort_arousal_scaled + tonic_arousal_scaled + (1|subject_id))),
                "Model6a_Pupil_Task"   = list(dataType = "pupil", formula = brms::bf(rt | dec(decision) ~ effort_arousal_scaled + tonic_arousal_scaled + task + (1|subject_id)))
            )
        )
    }
    final_models <- purrr::map(models, ~ .x %>% purrr::list_modify(priors = common_priors))
    # Override priors for baseline (no b parameters present)
    final_models[["Model1_Baseline"]]$priors <- c(
        prior(normal(0, 1.5), class = "Intercept"),
        prior(exponential(1), class = "sd")
    )
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
    if (spec$dataType == "pupil" && !PUPIL_FEATURES_AVAILABLE) {
        log_message(paste("Skipping", model_name, "(pupil features unavailable)"), "WARN")
        next
    }
    data_to_use <- if (spec$dataType == "pupil") ddm_data_pupil else ddm_data_behav
    tryCatch({
        log_message(paste("--- FITTING:", model_name, "---"), "MODEL")
        fit_ddm_model(spec, data_to_use, model_name)
        log_message(sprintf("SUCCESS: %s fitted.", model_name), "SUCCESS")
    }, error = function(e) {
        log_message(sprintf("FAILED to fit %s: %s", model_name, e$message), "ERROR")
    })
}

# Optional: run all models separately for each task (ADT/VDT)
RUN_PER_TASK_ANALYSES <- TRUE
if (RUN_PER_TASK_ANALYSES) {
    tasks_available <- unique(ddm_data_behav$task)
    log_message(paste("Per-task analyses enabled. Global task levels:", paste(levels(ddm_data_behav$task), collapse=",")))
    for (task_level in tasks_available) {
        ddm_behav_task <- ddm_data_behav %>% dplyr::filter(task == task_level)
        ddm_pupil_task <- if (PUPIL_FEATURES_AVAILABLE) ddm_data_pupil %>% dplyr::filter(task == task_level) else NULL
        log_message(paste("Subset:", task_level, "| behav levels:", paste(levels(ddm_behav_task$task), collapse=","),
                          "| pupil levels:", if (!is.null(ddm_pupil_task)) paste(levels(ddm_pupil_task$task), collapse=",") else "(no pupil)"))
        for (model_name in names(model_specs)) {
            spec <- model_specs[[model_name]]
            if (spec$dataType == "pupil" && !PUPIL_FEATURES_AVAILABLE) {
                log_message(paste("Skipping", model_name, "for", task_level, "(pupil features unavailable)"), "WARN")
                next
            }
            # If per-task subset contains a single observed task level, skip models containing 'task'
            observed_task_levels <- length(unique(stats::na.omit(ddm_behav_task$task)))
            if (observed_task_levels < 2) {
                formula_str <- paste0(deparse(spec$formula), collapse = "")
                if (grepl("task", formula_str, fixed = TRUE)) {
                    log_message(paste("Skipping", model_name, "for", task_level, "(contains 'task' term but only one observed task level)"), "WARN")
                    next
                }
            }
            data_to_use <- if (spec$dataType == "pupil") ddm_pupil_task else ddm_behav_task
            tryCatch({
                log_message(paste("--- FITTING (", task_level, "):", model_name, "---"), "MODEL")
                fit_ddm_model(spec, data_to_use, paste0(model_name, "_", task_level))
                log_message(sprintf("SUCCESS: %s (%s) fitted.", model_name, task_level), "SUCCESS")
            }, error = function(e) {
                log_message(sprintf("FAILED to fit %s (%s): %s", model_name, task_level, e$message), "ERROR")
            })
        }
    }
}